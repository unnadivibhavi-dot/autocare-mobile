import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();

    final day = MaterialLocalizations.of(context).formatMediumDate(date);

    final time = TimeOfDay.fromDateTime(date).format(context);

    return '$day • $time';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF91D8AC);
      case 'cancelled':
        return const Color(0xFFFFABA5);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Future<void> _changeStatus(
    DocumentReference<Map<String, dynamic>> reference,
    String nextStatus,
  ) async {
    if (_updatingId != null) return;

    final isCancel = nextStatus == 'cancelled';

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isCancel ? 'Cancel booking?' : 'Confirm booking?'),
          content: Text(
            isCancel
                ? 'The booking will remain in the history as cancelled.'
                : 'Mark this service appointment as confirmed?',
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
              child: Text(isCancel ? 'Cancel Booking' : 'Confirm'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted || _updatingId != null) return;

    setState(() => _updatingId = reference.id);

    try {
      await FirebaseFirestore.instance.runTransaction<void>((
        transaction,
      ) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw StateError('This booking no longer exists.');
        }

        final currentStatus = data['status'] as String?;

        final canConfirm =
            currentStatus == 'pending' && nextStatus == 'confirmed';

        final canCancel =
            (currentStatus == 'pending' || currentStatus == 'confirmed') &&
            nextStatus == 'cancelled';

        if (!canConfirm && !canCancel) {
          throw StateError(
            'The booking status has changed. Please check the list.',
          );
        }

        if (canConfirm) {
          final scheduledAt = data['scheduledAt'] as Timestamp;

          if (!scheduledAt.toDate().isAfter(DateTime.now())) {
            throw StateError('A past appointment cannot be confirmed.');
          }
        }

        transaction.update(reference, {
          'status': nextStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCancel ? 'Booking cancelled.' : 'Booking confirmed.'),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${error.message}')));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Update denied. Check your booking rules and account.'
                : 'Unable to update booking. Check your connection.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update booking. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
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
          // Status filters
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
                        'Unable to load bookings. Check your '
                        'connection and Firestore rules.',
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
                  final aDate = a.data()['scheduledAt'] as Timestamp;
                  final bDate = b.data()['scheduledAt'] as Timestamp;

                  return bDate.compareTo(aDate);
                });

                if (bookings.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filter == 'all'
                            ? 'No bookings yet.\nTap New Booking to begin.'
                            : 'No $_filter bookings.',
                        textAlign: TextAlign.center,
                      ),
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

                    final service = data['serviceType'] as String;
                    final notes = data['notes'] as String;
                    final scheduledAt = data['scheduledAt'] as Timestamp;
                    final status = data['status'] as String;

                    final busy = _updatingId == booking.id;
                    final actionsEnabled = _updatingId == null;

                    final canConfirm =
                        status == 'pending' &&
                        scheduledAt.toDate().isAfter(DateTime.now());

                    final canCancel =
                        status == 'pending' || status == 'confirmed';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.event_available_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    service,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(_formatDate(scheduledAt)),
                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: _statusColor(status)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),

                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(notes),
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
                                      onPressed: actionsEnabled
                                          ? () => _changeStatus(
                                              booking.reference,
                                              'confirmed',
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 19,
                                      ),
                                      label: const Text('Confirm'),
                                    ),
                                  if (canCancel)
                                    OutlinedButton.icon(
                                      onPressed: actionsEnabled
                                          ? () => _changeStatus(
                                              booking.reference,
                                              'cancelled',
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        size: 19,
                                      ),
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
}

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
  final _notesController = TextEditingController();

  final _bookingRef = FirebaseFirestore.instance.collection('bookings').doc();

  static const _services = [
    'Full Service',
    'Oil Change',
    'Vehicle Inspection',
    'Brake Service',
    'Other Repair',
  ];

  String? _service;
  DateTime? _scheduledAt;
  bool _saving = false;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final previous = _scheduledAt;

    final initialDate = previous != null && !previous.isBefore(today)
        ? previous
        : now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(now.year + 2, 12, 31),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: previous == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(previous),
    );

    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future date and time.')),
      );
      return;
    }

    setState(() => _scheduledAt = selected);
  }

  Future<void> _saveBooking() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final scheduledAt = _scheduledAt;

    if (scheduledAt == null || !scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future date and time.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _bookingRef.set({
        'vehicleId': widget.vehicleId,
        'serviceType': _service!,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Check your UID, booking rules and selected date.'
                : 'Unable to save booking. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save booking. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _scheduledAt;

    final dateLabel = selected == null
        ? 'Select date and time'
        : '${MaterialLocalizations.of(context).formatMediumDate(selected)}'
              ' • ${TimeOfDay.fromDateTime(selected).format(context)}';

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
                constraints: const BoxConstraints(maxWidth: 480),
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
                      const Text('Schedule a service for this vehicle.'),
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
                        onPressed: _saving ? null : _pickDateTime,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(dateLabel),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(18),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _notesController,
                        enabled: !_saving,
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Describe any vehicle problems...',
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _saving ? null : _saveBooking,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.event_available_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save Booking'),
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
