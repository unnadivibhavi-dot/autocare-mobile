import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _customers;

  String _query = '';
  bool _sortByName = false;

  @override
  void initState() {
    super.initState();

    _customers = FirebaseFirestore.instance
        .collection('customers')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _localPhone(String value) {
    final digits = _digitsOnly(value);

    // Example: +94 71 123 4567 becomes 0711234567.
    if (digits.startsWith('94') && digits.length == 11) {
      return '0${digits.substring(2)}';
    }

    return digits;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;

    final name = (data['name'] as String? ?? '').toLowerCase();

    final email = (data['email'] as String? ?? '').toLowerCase();

    final phone = data['phone'] as String? ?? '';

    if (name.contains(_query) ||
        email.contains(_query) ||
        phone.toLowerCase().contains(_query)) {
      return true;
    }

    final isPhoneSearch = RegExp(r'^[+0-9\s()-]+$').hasMatch(_query);

    if (!isPhoneSearch) return false;

    final queryDigits = _digitsOnly(_query);

    if (queryDigits.isEmpty) return false;

    return _digitsOnly(phone).contains(queryDigits) ||
        _localPhone(phone).contains(_localPhone(_query));
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() => _query = '');
  }

  void _openAddCustomer() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AddCustomerScreen()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Customer'),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, phone or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Newest first'),
                  selected: !_sortByName,
                  onSelected: (_) {
                    setState(() => _sortByName = false);
                  },
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Name A–Z'),
                  selected: _sortByName,
                  onSelected: (_) {
                    setState(() => _sortByName = true);
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _customers,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Unable to load customers. '
                        'Check your connection and permissions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allCustomers = snapshot.data!.docs;

                if (allCustomers.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No customers yet.\n'
                        'Tap Add Customer to begin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final visibleCustomers = allCustomers.where((customer) {
                  return _matchesSearch(customer.data());
                }).toList();

                if (_sortByName) {
                  visibleCustomers.sort((a, b) {
                    final first = (a.data()['name'] as String? ?? '')
                        .trim()
                        .toLowerCase();

                    final second = (b.data()['name'] as String? ?? '')
                        .trim()
                        .toLowerCase();

                    return first.compareTo(second);
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      child: Text(
                        '${visibleCustomers.length} of '
                        '${allCustomers.length} customers',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                    Expanded(
                      child: visibleCustomers.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off, size: 48),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No matching customers.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _clearSearch,
                                      child: const Text('Clear search'),
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
                              itemCount: visibleCustomers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final data = visibleCustomers[index].data();

                                final name = data['name'] as String? ?? '';

                                final phone = data['phone'] as String? ?? '';

                                final email = data['email'] as String? ?? '';

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          child: Icon(
                                            Icons.person_outline,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),

                                        const SizedBox(width: 14),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),

                                              const SizedBox(height: 10),

                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.phone_outlined,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(phone)),
                                                ],
                                              ),

                                              if (email.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons.email_outlined,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(email),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
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

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final _customerRef = FirebaseFirestore.instance.collection('customers').doc();

  bool _saving = false;

  Future<void> _saveCustomer() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      await _customerRef.set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      final message = error.code == 'permission-denied'
          ? 'Permission denied. Check the UID in your Firestore rules.'
          : 'Unable to save customer. Please try again.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Customer'),
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
                      TextFormField(
                        controller: _nameController,
                        enabled: !_saving,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          return value == null || value.trim().isEmpty
                              ? 'Enter the customer name.'
                              : null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneController,
                        enabled: !_saving,
                        maxLength: 30,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';

                          if (phone.isEmpty) {
                            return 'Enter a phone number.';
                          }

                          final digits = phone.replaceAll(RegExp(r'\D'), '');

                          final validCharacters = RegExp(r'^\+?[0-9 ()-]+$')
                              .hasMatch(phone);

                          if (!validCharacters ||
                              digits.length < 7 ||
                              digits.length > 15) {
                            return 'Enter a valid phone number.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        enabled: !_saving,
                        maxLength: 254,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        onFieldSubmitted: (_) {
                          _saveCustomer();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isNotEmpty &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                            return 'Enter a valid email.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _saving ? null : _saveCustomer,
                        icon: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save Customer'),
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
