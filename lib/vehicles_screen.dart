import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'bookings_screen.dart';
import 'job_cards_screen.dart';
import 'inventory_screen.dart';
import 'service_history_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vehicles;

  String _query = '';
  String? _brandFilter;

  @override
  void initState() {
    super.initState();

    _vehicles = FirebaseFirestore.instance
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _query = '';
      _brandFilter = null;
    });
  }

  String _normaliseRegistration(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s-]'), '');
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;

    final registration = (data['registration'] as String? ?? '').toLowerCase();

    final brand = (data['brand'] as String? ?? '').toLowerCase();

    final model = (data['model'] as String? ?? '').toLowerCase();

    final combined = '$registration $brand $model';

    if (combined.contains(_query)) return true;

    // CAA1234 also matches CAA-1234.
    final compactQuery = _normaliseRegistration(_query);

    return compactQuery.isNotEmpty &&
        _normaliseRegistration(registration).contains(compactQuery);
  }

  @override
  void dispose() {
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
            onPressed: () {
              _open(const InventoryScreen());
            },
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _open(const AddVehicleScreen());
        },
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
                setState(() {
                  _query = value.trim().toLowerCase();
                });
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
                        'No vehicles yet.\n'
                        'Tap Add Vehicle to begin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // One filter per brand, ignoring capitalisation.
                final brands = <String, String>{};

                for (final vehicle in allVehicles) {
                  final brand = (vehicle.data()['brand'] as String? ?? '')
                      .trim();

                  if (brand.isNotEmpty) {
                    brands.putIfAbsent(brand.toLowerCase(), () => brand);
                  }
                }

                final brandKeys = brands.keys.toList()..sort();

                final effectiveBrand = brands.containsKey(_brandFilter)
                    ? _brandFilter
                    : null;

                final visibleVehicles = allVehicles.where((vehicle) {
                  final data = vehicle.data();

                  final brand = (data['brand'] as String? ?? '')
                      .trim()
                      .toLowerCase();

                  final matchesBrand =
                      effectiveBrand == null || brand == effectiveBrand;

                  return matchesBrand && _matchesSearch(data);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('All brands'),
                              selected: effectiveBrand == null,
                              onSelected: (_) {
                                setState(() {
                                  _brandFilter = null;
                                });
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
                                  setState(() {
                                    _brandFilter = key;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      child: Text(
                        '${visibleVehicles.length} of '
                        '${allVehicles.length} vehicles',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                    Expanded(
                      child: visibleVehicles.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off, size: 48),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No matching vehicles.',
                                      textAlign: TextAlign.center,
                                    ),
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
                                100,
                              ),
                              itemCount: visibleVehicles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final vehicle = visibleVehicles[index];

                                final data = vehicle.data();

                                final registration =
                                    data['registration'] as String? ?? '';

                                final brand = data['brand'] as String? ?? '';

                                final model = data['model'] as String? ?? '';

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 25,
                                              child: Icon(
                                                Icons.directions_car_outlined,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                size: 27,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    registration,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text('$brand $model'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 20),

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
                                              icon: const Icon(
                                                Icons.event_outlined,
                                                size: 20,
                                              ),
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
                                              icon: const Icon(
                                                Icons.assignment_outlined,
                                                size: 20,
                                              ),
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
                                              icon: const Icon(
                                                Icons.history_rounded,
                                                size: 20,
                                              ),
                                              label: const Text('History'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
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
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

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
      if (mounted) {
        setState(() => _saving = false);
      }
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
                                    setState(() {
                                      _customerId = value;
                                    });
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
