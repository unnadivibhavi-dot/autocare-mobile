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

    if (digits.startsWith('94') && digits.length == 11) {
      return '0${digits.substring(2)}';
    }

    return digits;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;

    final name = (data['name']?.toString() ?? '').toLowerCase();
    final email = (data['email']?.toString() ?? '').toLowerCase();
    final phone = data['phone']?.toString() ?? '';

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

  void _openEditCustomer(QueryDocumentSnapshot<Map<String, dynamic>> customer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditCustomerScreen(
          customerId: customer.id,
          initialData: customer.data(),
        ),
      ),
    );
  }

  Widget _customerCard(QueryDocumentSnapshot<Map<String, dynamic>> customer) {
    final data = customer.data();

    final name = data['name']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';
    final email = data['email']?.toString() ?? '';

    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              child: Icon(Icons.person_outline, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.phone_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(phone)),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.email_outlined, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(email)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit customer',
              onPressed: () => _openEditCustomer(customer),
              icon: Icon(Icons.edit_outlined, color: colors.primary),
            ),
          ],
        ),
      ),
    );
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
                setState(() => _query = value.trim().toLowerCase());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Newest first'),
                    selected: !_sortByName,
                    onSelected: (_) {
                      setState(() => _sortByName = false);
                    },
                  ),
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
                    final first = (a.data()['name']?.toString() ?? '')
                        .trim()
                        .toLowerCase();

                    final second = (b.data()['name']?.toString() ?? '')
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
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off, size: 48),
                                    const SizedBox(height: 14),
                                    const Text('No matching customers.'),
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
                                110,
                              ),
                              itemCount: visibleCustomers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _customerCard(visibleCustomers[index]);
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

// Keep the existing AddCustomerScreen available to other pages.
class AddCustomerScreen extends StatelessWidget {
  const AddCustomerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CustomerFormScreen();
  }
}

class EditCustomerScreen extends StatelessWidget {
  final String customerId;
  final Map<String, dynamic> initialData;

  const EditCustomerScreen({
    super.key,
    required this.customerId,
    required this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return _CustomerFormScreen(
      customerId: customerId,
      initialData: initialData,
    );
  }
}

class _CustomerFormScreen extends StatefulWidget {
  final String? customerId;
  final Map<String, dynamic>? initialData;

  const _CustomerFormScreen({this.customerId, this.initialData});

  @override
  State<_CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<_CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  late final DocumentReference<Map<String, dynamic>> _customerRef;

  late final Map<String, String> _original;

  bool _saving = false;

  bool get _editing => widget.customerId != null;

  @override
  void initState() {
    super.initState();

    final data = widget.initialData ?? <String, dynamic>{};

    _original = {
      'name': data['name']?.toString() ?? '',
      'phone': data['phone']?.toString() ?? '',
      'email': data['email']?.toString() ?? '',
    };

    _nameController = TextEditingController(text: _original['name']);
    _phoneController = TextEditingController(text: _original['phone']);
    _emailController = TextEditingController(text: _original['email']);

    final collection = FirebaseFirestore.instance.collection('customers');

    _customerRef = _editing
        ? collection.doc(widget.customerId!)
        : collection.doc();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveCustomer() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    // Capture the form once, including during transaction retries.
    final values = <String, String>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
    };

    final unchanged =
        _editing &&
        values.entries.every((entry) => entry.value == _original[entry.key]);

    if (unchanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    try {
      if (_editing) {
        await FirebaseFirestore.instance.runTransaction<void>((
          transaction,
        ) async {
          final snapshot = await transaction.get(_customerRef);

          if (!snapshot.exists) {
            throw const _CustomerEditException(
              'This customer no longer exists. '
              'Go back and refresh the customer list.',
            );
          }

          final current = snapshot.data()!;

          // Avoid overwriting edits saved from another device.
          final changedElsewhere = _original.entries.any(
            (entry) => (current[entry.key]?.toString() ?? '') != entry.value,
          );

          if (changedElsewhere) {
            throw const _CustomerEditException(
              'Customer details changed on another device. '
              'Go back and reopen Edit to load the latest details.',
            );
          }

          // Keep the same customer ID and original createdAt.
          transaction.update(_customerRef, values);
        });
      } else {
        await _customerRef.set({
          ...values,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      _showMessage(
        _editing ? 'Customer details updated.' : 'Customer added successfully.',
      );

      Navigator.of(context).pop();
    } on _CustomerEditException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error) {
      final String message;

      switch (error.code) {
        case 'permission-denied':
          message =
              'Permission denied. Check the owner UID in Firestore rules.';
          break;
        case 'unavailable':
          message =
              'Unable to reach Firebase. Check your internet and try again.';
          break;
        case 'not-found':
          message = 'This customer no longer exists.';
          break;
        default:
          message = 'Unable to save customer. Please try again.';
      }

      _showMessage(message);
    } catch (_) {
      _showMessage('Unable to save customer. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) return 'Enter a phone number.';

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final validCharacters = RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone);

    if (!validCharacters || digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email.';
    }

    return null;
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
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit Customer' : 'Add Customer'),
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
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        _editing
                            ? Icons.manage_accounts_outlined
                            : Icons.person_add_alt_1_outlined,
                        size: 48,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _editing
                            ? 'Update customer details'
                            : 'Add a new customer',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _editing
                            ? 'Keep contact details up to date.'
                            : 'Save customer contact details in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),
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
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_saving,
                        maxLength: 254,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) => _saveCustomer(),
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _validateEmail,
                      ),
                      if (_editing) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Registered vehicles stay linked to this customer. '
                          'Previously issued invoices keep their saved '
                          'customer details.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : _editing
                              ? 'Save Changes'
                              : 'Save Customer',
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

class _CustomerEditException implements Exception {
  final String message;

  const _CustomerEditException(this.message);
}
