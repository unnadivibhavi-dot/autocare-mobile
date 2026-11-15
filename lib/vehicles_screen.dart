import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'bookings_screen.dart';
import 'job_cards_screen.dart';
import 'inventory_screen.dart';
import 'service_history_screen.dart';

enum _ReminderFilter { all, overdue, dueSoon, notSet }

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _savingReminders = <String>{};

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vehicles;
  Timer? _clock;

  String _query = '';
  String? _brandFilter;
  _ReminderFilter _reminderFilter = _ReminderFilter.all;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _vehicles = FirebaseFirestore.instance
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots();

    // Refresh date badges if the app stays open overnight.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _query = '';
      _brandFilter = null;
      _reminderFilter = _ReminderFilter.all;
    });
  }

  String _normaliseRegistration(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s-]'), '');
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;

    final registration = (data['registration']?.toString() ?? '').toLowerCase();
    final brand = (data['brand']?.toString() ?? '').toLowerCase();
    final model = (data['model']?.toString() ?? '').toLowerCase();

    if ('$registration $brand $model'.contains(_query)) {
      return true;
    }

    final compactQuery = _normaliseRegistration(_query);

    return compactQuery.isNotEmpty &&
        _normaliseRegistration(registration).contains(compactQuery);
  }

  // Dates are stored at UTC midnight as calendar dates.
  // This keeps the chosen service day stable across time zones.
  DateTime? _serviceDate(Map<String, dynamic> data) {
    final value = data['nextServiceDate'];

    if (value is! Timestamp) return null;

    final date = value.toDate().toUtc();
    return DateTime.utc(date.year, date.month, date.day);
  }

  int? _daysUntil(Map<String, dynamic> data) {
    final serviceDate = _serviceDate(data);
    if (serviceDate == null) return null;

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    return serviceDate.difference(today).inDays;
  }

  bool _matchesReminder(Map<String, dynamic> data) {
    final days = _daysUntil(data);

    switch (_reminderFilter) {
      case _ReminderFilter.all:
        return true;
      case _ReminderFilter.overdue:
        return days != null && days < 0;
      case _ReminderFilter.dueSoon:
        return days != null && days >= 0 && days <= 30;
      case _ReminderFilter.notSet:
        return days == null;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _reminderStatus(Map<String, dynamic> data) {
    final days = _daysUntil(data);

    if (days == null) return 'No service date set';
    if (days < 0) {
      final count = -days;
      return '$count ${count == 1 ? 'day' : 'days'} overdue';
    }
    if (days == 0) return 'Service due today';
    if (days == 1) return 'Service due tomorrow';
    if (days <= 30) return 'Due soon • in $days days';

    return 'Upcoming • in $days days';
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveReminder(String vehicleId, DateTime? date) async {
    if (_savingReminders.contains(vehicleId)) return;

    setState(() => _savingReminders.add(vehicleId));

    try {
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicleId)
          .update({
            'nextServiceDate': date == null
                ? FieldValue.delete()
                : Timestamp.fromDate(
                    DateTime.utc(date.year, date.month, date.day),
                  ),
            'reminderUpdatedAt': FieldValue.serverTimestamp(),
          });

      _message(
        date == null ? 'Service reminder removed.' : 'Next service date saved.',
      );
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Unable to save. Check the published vehicle reminder rules.'
            : 'Unable to save the reminder. Please try again.',
      );
    } catch (_) {
      _message('Unable to save the reminder. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _savingReminders.remove(vehicleId));
      }
    }
  }

  Future<void> _pickServiceDate(
    String vehicleId,
    Map<String, dynamic> data,
  ) async {
    if (_savingReminders.contains(vehicleId)) return;

    final now = DateTime.now();
    final current = _serviceDate(data);

    final initial = current == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime(current.year, current.month, current.day);

    final firstYear = initial.year < 2000 ? initial.year : 2000;
    final lastYear = initial.year > now.year + 20
        ? initial.year
        : now.year + 20;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(firstYear),
      lastDate: DateTime(lastYear, 12, 31),
      helpText: 'Next service date',
      confirmText: 'Save date',
    );

    if (!mounted || picked == null) return;

    await _saveReminder(vehicleId, picked);
  }

  Future<void> _removeReminder(String vehicleId, String registration) async {
    if (_savingReminders.contains(vehicleId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove reminder?'),
        content: Text('Remove the next service date for $registration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await _saveReminder(vehicleId, null);
  }

  Widget _reminderPanel(QueryDocumentSnapshot<Map<String, dynamic>> vehicle) {
    final data = vehicle.data();
    final date = _serviceDate(data);
    final days = _daysUntil(data);
    final colors = Theme.of(context).colorScheme;
    final overdue = days != null && days < 0;
    final saving = _savingReminders.contains(vehicle.id);

    final statusColor = overdue
        ? colors.error
        : date == null
        ? colors.onSurfaceVariant
        : colors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overdue
                    ? Icons.notification_important_outlined
                    : Icons.event_available_outlined,
                color: statusColor,
                size: 23,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date == null
                          ? 'Next service'
                          : 'Next service • ${_formatDate(date)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _reminderStatus(data),
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: saving
                    ? null
                    : () => _pickServiceDate(vehicle.id, data),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(date == null ? 'Set date' : 'Change date'),
              ),
              if (date != null)
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () => _removeReminder(
                          vehicle.id,
                          data['registration']?.toString() ?? 'vehicle',
                        ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(QueryDocumentSnapshot<Map<String, dynamic>> vehicle) {
    final data = vehicle.data();
    final registration = data['registration']?.toString() ?? '';
    final brand = data['brand']?.toString() ?? '';
    final model = data['model']?.toString() ?? '';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  child: Icon(
                    Icons.directions_car_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registration,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$brand $model'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _reminderPanel(vehicle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _open(
                      VehicleBookingsScreen(
                        vehicleId: vehicle.id,
                        registration: registration,
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_outlined, size: 20),
                  label: const Text('Bookings'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    _open(
                      JobCardsScreen(
                        vehicleId: vehicle.id,
                        registration: registration,
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 20),
                  label: const Text('Job Cards'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _open(
                      ServiceHistoryScreen(
                        vehicleId: vehicle.id,
                        registration: registration,
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 20),
                  label: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          IconButton(
            tooltip: 'Spare Parts Inventory',
            onPressed: () => _open(const InventoryScreen()),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const AddVehicleScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Vehicle number, brand or model',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _vehicles,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Unable to load vehicles. '
                        'Check your connection and permissions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allVehicles = snapshot.data!.docs;

                if (allVehicles.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No vehicles yet.\nTap Add Vehicle to begin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final brands = <String, String>{};

                for (final vehicle in allVehicles) {
                  final brand = (vehicle.data()['brand']?.toString() ?? '')
                      .trim();

                  if (brand.isNotEmpty) {
                    brands.putIfAbsent(brand.toLowerCase(), () => brand);
                  }
                }

                final brandKeys = brands.keys.toList()..sort();

                final effectiveBrand = brands.containsKey(_brandFilter)
                    ? _brandFilter
                    : null;

                final overdueCount = allVehicles.where((vehicle) {
                  final days = _daysUntil(vehicle.data());
                  return days != null && days < 0;
                }).length;

                final dueSoonCount = allVehicles.where((vehicle) {
                  final days = _daysUntil(vehicle.data());
                  return days != null && days >= 0 && days <= 30;
                }).length;

                final notSetCount = allVehicles.where((vehicle) {
                  return _serviceDate(vehicle.data()) == null;
                }).length;

                final visibleVehicles = allVehicles.where((vehicle) {
                  final data = vehicle.data();
                  final brand = (data['brand']?.toString() ?? '')
                      .trim()
                      .toLowerCase();

                  return (effectiveBrand == null || brand == effectiveBrand) &&
                      _matchesSearch(data) &&
                      _matchesReminder(data);
                }).toList();

                // Show the most urgent dates first in reminder filters.
                if (_reminderFilter == _ReminderFilter.overdue ||
                    _reminderFilter == _ReminderFilter.dueSoon) {
                  visibleVehicles.sort((a, b) {
                    return _serviceDate(a.data())!
                        .compareTo(_serviceDate(b.data())!);
                  });
                }

                Widget reminderChip(String label, _ReminderFilter filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _reminderFilter == filter,
                      onSelected: (_) {
                        setState(() => _reminderFilter = filter);
                      },
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          reminderChip('All', _ReminderFilter.all),
                          reminderChip(
                            'Overdue ($overdueCount)',
                            _ReminderFilter.overdue,
                          ),
                          reminderChip(
                            'Due soon ($dueSoonCount)',
                            _ReminderFilter.dueSoon,
                          ),
                          reminderChip(
                            'Not set ($notSetCount)',
                            _ReminderFilter.notSet,
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('All brands'),
                              selected: effectiveBrand == null,
                              onSelected: (_) {
                                setState(() => _brandFilter = null);
                              },
                            ),
                          ),
                          ...brandKeys.map((key) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(brands[key]!),
                                selected: effectiveBrand == key,
                                onSelected: (_) {
                                  setState(() => _brandFilter = key);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                      child: Text(
                        '${visibleVehicles.length} of '
                        '${allVehicles.length} vehicles\n'
                        'Due soon: today through the next 30 days. '
                        'Reminder counts cover all vehicles.',
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                    ),
                    Expanded(
                      child: visibleVehicles.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off, size: 48),
                                    const SizedBox(height: 14),
                                    const Text('No matching vehicles.'),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _clearFilters,
                                      child: const Text(
                                        'Clear search & filters',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                110,
                              ),
                              itemCount: visibleVehicles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                return _vehicleCard(visibleVehicles[index]);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _registration = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();

  final _vehicleRef = FirebaseFirestore.instance.collection('vehicles').doc();

  late final Future<QuerySnapshot<Map<String, dynamic>>> _customers;

  String? _customerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _customers = FirebaseFirestore.instance
        .collection('customers')
        .orderBy('name')
        .get();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _vehicleRef.set({
        'customerId': _customerId!,
        'registration': _registration.text.trim().toUpperCase(),
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
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
                ? 'Check vehicle rules, your UID and selected customer.'
                : 'Unable to save vehicle. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save vehicle. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required int maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLength: maxLength,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          return value == null || value.trim().isEmpty ? 'Enter $label.' : null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _registration.dispose();
    _brand.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Vehicle'),
          automaticallyImplyLeading: !_saving,
        ),
        body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _customers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Unable to load customers. '
                    'Check your connection and permissions, '
                    'then reopen this screen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final customers = snapshot.data!.docs;

            if (customers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Add a customer before registering a vehicle.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return SafeArea(
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
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle owner',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: customers.map((customer) {
                              final data = customer.data();

                              return DropdownMenuItem<String>(
                                value: customer.id,
                                child: Text(
                                  '${data['name']} — ${data['phone']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() => _customerId = value);
                                  },
                            validator: (value) {
                              return value == null
                                  ? 'Select a customer.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _field(
                            controller: _registration,
                            label: 'Vehicle registration number',
                            maxLength: 30,
                          ),
                          _field(
                            controller: _brand,
                            label: 'Brand',
                            maxLength: 60,
                          ),
                          _field(
                            controller: _model,
                            label: 'Model',
                            maxLength: 60,
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Saving...' : 'Save Vehicle'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
