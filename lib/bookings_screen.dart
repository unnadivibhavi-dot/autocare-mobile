import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_slot_service.dart';
import 'autocare_service.dart';

// Vehicle booking list
class VehicleBookingsScreen extends StatefulWidget {
  final String vehicleId;
  final String registration;

  const VehicleBookingsScreen({
    super.key,
    required this.vehicleId,
    required this.registration,
  });

  @override
  State<VehicleBookingsScreen> createState() => _VehicleBookingsScreenState();
}

class _VehicleBookingsScreenState extends State<VehicleBookingsScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _bookings;

  String _filter = 'all';
  String? _updatingId;

  @override
  void initState() {
    super.initState();

    _bookings = FirebaseFirestore.instance
        .collection('bookings')
        .where('vehicleId', isEqualTo: widget.vehicleId)
        .snapshots();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _dateLabel(Timestamp timestamp) {
    final sriLankaTime = timestamp.toDate().toUtc().add(
      BookingSlotService.sriLankaOffset,
    );

    final date = MaterialLocalizations.of(context)
        .formatMediumDate(sriLankaTime);

    final time = BookingSlotService.formatClock(sriLankaTime);

    return '$date • $time (Sri Lanka)';
  }

  Future<void> _confirmBooking(
    DocumentReference<Map<String, dynamic>> bookingRef,
    DateTime expectedStart,
  ) async {
    if (!BookingSlotService.isValidSlotStart(expectedStart)) {
      throw StateError(
        'This older booking does not use an hourly slot. '
        'Cancel it and create a new booking.',
      );
    }

    if (!expectedStart.isAfter(DateTime.now().toUtc())) {
      throw StateError('A past appointment cannot be confirmed.');
    }

    // This check also considers older confirmed bookings
    // that were created before slot reservations were added.
    final sriLankaStart = expectedStart.add(BookingSlotService.sriLankaOffset);

    final day = DateTime(
      sriLankaStart.year,
      sriLankaStart.month,
      sriLankaStart.day,
    );

    final daySlots = await BookingSlotService.loadSlots(day);

    final matchingSlots = daySlots.where((slot) {
      return slot.startAtUtc.isAtSameMomentAs(expectedStart);
    }).toList();

    if (matchingSlots.isEmpty || !matchingSlots.first.isAvailable) {
      throw StateError(
        'This time is no longer available. '
        'Choose another slot.',
      );
    }

    final database = FirebaseFirestore.instance;

    final slotRef = database
        .collection('bookingSlots')
        .doc(BookingSlotService.reservationId(expectedStart));

    await database.runTransaction<void>((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);

      final slotSnapshot = await transaction.get(slotRef);

      final booking = bookingSnapshot.data();

      if (booking == null) {
        throw StateError('Booking not found.');
      }

      if (booking['status'] != 'pending') {
        throw StateError(
          'This booking status has changed. '
          'Please check the booking list.',
        );
      }

      final currentStart = (booking['scheduledAt'] as Timestamp)
          .toDate()
          .toUtc();

      if (!currentStart.isAtSameMomentAs(expectedStart)) {
        throw StateError('The booking time changed. Please try again.');
      }

      if (!currentStart.isAfter(DateTime.now().toUtc())) {
        throw StateError('This appointment time has already passed.');
      }

      if (slotSnapshot.exists) {
        throw StateError(
          'Another booking has reserved this slot. '
          'Choose another time.',
        );
      }

      transaction.set(slotRef, {
        'bookingId': bookingRef.id,
        'startAt': Timestamp.fromDate(currentStart),
        'endAt': Timestamp.fromDate(
          currentStart.add(BookingSlotService.slotDuration),
        ),
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(bookingRef, {
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _cancelBooking(
    DocumentReference<Map<String, dynamic>> bookingRef,
    DateTime expectedStart,
  ) async {
    final database = FirebaseFirestore.instance;

    final jobRef = database.collection('jobCards').doc(bookingRef.id);

    final slotRef = database
        .collection('bookingSlots')
        .doc(BookingSlotService.reservationId(expectedStart));

    await database.runTransaction<void>((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);

      final jobSnapshot = await transaction.get(jobRef);

      final slotSnapshot = await transaction.get(slotRef);

      final booking = bookingSnapshot.data();

      if (booking == null) {
        throw StateError('Booking not found.');
      }

      if (!['pending', 'confirmed'].contains(booking['status'])) {
        throw StateError('This booking can no longer be cancelled.');
      }

      if (jobSnapshot.exists) {
        throw StateError(
          'This booking already has a Job Card '
          'and cannot be cancelled.',
        );
      }

      final currentStart = (booking['scheduledAt'] as Timestamp)
          .toDate()
          .toUtc();

      if (!currentStart.isAtSameMomentAs(expectedStart)) {
        throw StateError('The booking time changed. Please try again.');
      }

      final slot = slotSnapshot.data();

      // Only release a slot owned by this booking.
      if (slot != null && slot['bookingId'] == bookingRef.id) {
        transaction.delete(slotRef);
      }

      transaction.update(bookingRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _changeStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String nextStatus,
  ) async {
    if (_updatingId != null) return;

    final cancelling = nextStatus == 'cancelled';

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(cancelling ? 'Cancel Booking?' : 'Confirm Booking?'),
          content: Text(
            cancelling
                ? 'The booking will remain in history. '
                      'Its reserved slot will be released.'
                : 'Reserve this one-hour appointment?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(cancelling ? 'Cancel Booking' : 'Confirm'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted || _updatingId != null) {
      return;
    }

    final expectedStart = (document.data()['scheduledAt'] as Timestamp)
        .toDate()
        .toUtc();

    setState(() => _updatingId = document.id);

    try {
      if (cancelling) {
        await _cancelBooking(document.reference, expectedStart);
      } else {
        await _confirmBooking(document.reference, expectedStart);
      }

      if (!mounted) return;

      _message(
        cancelling
            ? 'Booking cancelled. Its reservation was released.'
            : 'Booking confirmed and slot reserved.',
      );
    } catch (error) {
      if (mounted) {
        _message(operationError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingId = null);
      }
    }
  }

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.registration} Bookings')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _updatingId != null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddBookingScreen(
                      vehicleId: widget.vehicleId,
                      registration: widget.registration,
                    ),
                  ),
                );
              },
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
      ),

      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('all', 'All'),
                _filterChip('pending', 'Pending'),
                _filterChip('confirmed', 'Confirmed'),
                _filterChip('cancelled', 'Cancelled'),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bookings,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Unable to load bookings. '
                        'Check your connection and permissions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bookings = snapshot.data!.docs.where((doc) {
                  return _filter == 'all' || doc.data()['status'] == _filter;
                }).toList();

                bookings.sort((a, b) {
                  return (b.data()['scheduledAt'] as Timestamp).compareTo(
                    a.data()['scheduledAt'] as Timestamp,
                  );
                });

                if (bookings.isEmpty) {
                  return Center(
                    child: Text(
                      _filter == 'all'
                          ? 'No bookings yet. Tap New Booking.'
                          : 'No $_filter bookings.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final data = booking.data();

                    final status = data['status'] as String;
                    final notes = data['notes'] as String;

                    final timestamp = data['scheduledAt'] as Timestamp;

                    final start = timestamp.toDate().toUtc();

                    final hourlySlot = BookingSlotService.isValidSlotStart(
                      start,
                    );

                    final canConfirm =
                        status == 'pending' &&
                        hourlySlot &&
                        start.isAfter(DateTime.now().toUtc());

                    final canCancel = ['pending', 'confirmed'].contains(status);

                    final busy = _updatingId == booking.id;
                    final enabled = _updatingId == null;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              data['serviceType'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(_dateLabel(timestamp)),

                            const SizedBox(height: 10),

                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(notes),
                            ],

                            if (status == 'pending' && !hourlySlot) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'This older booking uses a custom time. '
                                'Cancel and rebook using an hourly slot.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],

                            if (status == 'pending' &&
                                !start.isAfter(DateTime.now().toUtc())) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'This appointment time has passed.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],

                            if (busy) ...[
                              const SizedBox(height: 16),
                              const LinearProgressIndicator(),
                            ],

                            if (canConfirm || canCancel) ...[
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  if (canConfirm)
                                    FilledButton.icon(
                                      onPressed: enabled
                                          ? () => _changeStatus(
                                              booking,
                                              'confirmed',
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: const Text('Confirm'),
                                    ),

                                  if (canCancel)
                                    OutlinedButton.icon(
                                      onPressed: enabled
                                          ? () => _changeStatus(
                                              booking,
                                              'cancelled',
                                            )
                                          : null,
                                      icon: const Icon(Icons.cancel_outlined),
                                      label: const Text('Cancel'),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// New booking with available hourly slots.
class AddBookingScreen extends StatefulWidget {
  final String vehicleId;
  final String registration;

  const AddBookingScreen({
    super.key,
    required this.vehicleId,
    required this.registration,
  });

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  final _bookingRef = FirebaseFirestore.instance.collection('bookings').doc();

  static const _services = [
    'Full Service',
    'Oil Change',
    'Vehicle Inspection',
    'Brake Service',
    'Other Repair',
  ];

  late DateTime _selectedDay;
  late Future<List<BookingSlot>> _slotsFuture;

  String? _service;
  BookingSlot? _selectedSlot;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _selectedDay = BookingSlotService.todayInSriLanka();

    _slotsFuture = BookingSlotService.loadSlots(_selectedDay);
  }

  void _refreshSlots() {
    setState(() {
      _selectedSlot = null;
      _slotsFuture = BookingSlotService.loadSlots(_selectedDay);
    });
  }

  Future<void> _chooseDay() async {
    final today = BookingSlotService.todayInSriLanka();

    final initialDay = _selectedDay.isBefore(today) ? today : _selectedDay;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDay,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDay = picked;
      _selectedSlot = null;
      _slotsFuture = BookingSlotService.loadSlots(_selectedDay);
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    final selectedSlot = _selectedSlot;

    if (selectedSlot == null) {
      _message('Select an available time slot.');
      return;
    }

    if (!selectedSlot.startAtUtc.isAfter(DateTime.now().toUtc())) {
      _message('This time has passed. Select another slot.');
      _refreshSlots();
      return;
    }

    FocusScope.of(context).unfocus();

    final service = _service!;
    final notes = _notes.text.trim();
    final selectedDay = _selectedDay;

    setState(() => _saving = true);

    try {
      // Recheck before saving the request.
      final latestSlots = await BookingSlotService.loadSlots(selectedDay);

      final matching = latestSlots.where((slot) {
        return slot.startAtUtc.isAtSameMomentAs(selectedSlot.startAtUtc);
      }).toList();

      if (matching.isEmpty || !matching.first.isAvailable) {
        throw StateError(
          'This time is no longer available. '
          'Refresh and select another slot.',
        );
      }

      await _bookingRef.set({
        'vehicleId': widget.vehicleId,
        'serviceType': service,
        'scheduledAt': Timestamp.fromDate(selectedSlot.startAtUtc),
        'notes': notes,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        _message(operationError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _slotSelector() {
    return FutureBuilder<List<BookingSlot>>(
      future: _slotsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Unable to load availability. '
                'Check your connection and permissions.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _refreshSlots,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final slots = snapshot.data!;

        final availableCount = slots.where((slot) => slot.isAvailable).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$availableCount available slots',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: slots.map((slot) {
                final selected =
                    _selectedSlot != null &&
                    _selectedSlot!.startAtUtc.isAtSameMomentAs(slot.startAtUtc);

                return ChoiceChip(
                  label: Text(
                    '${slot.label}\n${slot.statusLabel}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: selected,
                  onSelected: _saving || !slot.isAvailable
                      ? null
                      : (_) {
                          setState(() {
                            _selectedSlot = slot;
                          });
                        },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                );
              }).toList(),
            ),

            if (availableCount == 0) ...[
              const SizedBox(height: 16),
              const Text(
                'No available slots for this day. '
                'Please choose another date.',
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(context)
        .formatMediumDate(_selectedDay);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Booking'),
          automaticallyImplyLeading: !_saving,
        ),

        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.registration,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'One-hour appointments'
                        ' • 9 AM–5 PM'
                        ' • Sri Lanka time',
                      ),

                      const SizedBox(height: 24),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Service type',
                          prefixIcon: Icon(Icons.build_outlined),
                        ),
                        items: _services.map((service) {
                          return DropdownMenuItem<String>(
                            value: service,
                            child: Text(service),
                          );
                        }).toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() => _service = value);
                              },
                        validator: (value) {
                          return value == null
                              ? 'Select a service type.'
                              : null;
                        },
                      ),

                      const SizedBox(height: 20),

                      OutlinedButton.icon(
                        onPressed: _saving ? null : _chooseDay,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(dateLabel),
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _saving ? null : _refreshSlots,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh availability'),
                        ),
                      ),

                      const SizedBox(height: 8),

                      _slotSelector(),

                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _notes,
                        enabled: !_saving,
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Describe the vehicle problem...',
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'This creates a pending request. '
                        'The appointment is reserved when confirmed.',
                        style: TextStyle(fontSize: 12),
                      ),

                      const SizedBox(height: 20),

                      FilledButton.icon(
                        onPressed: _saving || _selectedSlot == null
                            ? null
                            : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.event_available_outlined),
                        label: Text(
                          _saving ? 'Saving...' : 'Save Booking Request',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
