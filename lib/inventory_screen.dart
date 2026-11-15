import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Convert LKR text into integer cents.
int? parsePartPrice(String value) {
  final text = value.trim();

  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }

  final pieces = text.split('.');
  final whole = int.parse(pieces[0]);

  final fraction = pieces.length == 2
      ? int.parse(pieces[1].padRight(2, '0'))
      : 0;

  final cents = whole * 100 + fraction;

  return cents <= 100000000 ? cents : null;
}

String formatPartPrice(int cents) {
  return '${cents ~/ 100}.'
      '${(cents % 100).toString().padLeft(2, '0')}';
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _parts;

  String _query = '';
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();

    _parts = FirebaseFirestore.instance
        .collection('spareParts')
        .orderBy('name')
        .snapshots();
  }

  String _compact(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  }

  bool _matchesSearch(String partCode, Map<String, dynamic> data) {
    if (_query.isEmpty) return true;

    final name = (data['name']?.toString() ?? '').toLowerCase();
    final code = partCode.toLowerCase();

    if (name.contains(_query) || code.contains(_query)) {
      return true;
    }

    final compactQuery = _compact(_query);

    return compactQuery.isNotEmpty && _compact(partCode).contains(compactQuery);
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _query = '';
      _lowStockOnly = false;
    });
  }

  void _openAddPart() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AddPartScreen()));
  }

  void _openEditPart(QueryDocumentSnapshot<Map<String, dynamic>> part) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EditPartScreen(partCode: part.id, initialData: part.data()),
      ),
    );
  }

  void _openRestock(QueryDocumentSnapshot<Map<String, dynamic>> part) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RestockDialog(
        reference: part.reference,
        name: part.data()['name'] as String,
      ),
    );
  }

  Widget _partCard(QueryDocumentSnapshot<Map<String, dynamic>> part) {
    final data = part.data();

    final stock = data['stock'] as int;
    final minimum = data['minStock'] as int;
    final lowStock = stock <= minimum;
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: colors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['name'] as String,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit part details',
                  onPressed: () => _openEditPart(part),
                  icon: Icon(Icons.edit_outlined, color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Code: ${part.id}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              'Unit price: LKR '
              '${formatPartPrice(data['unitPriceCents'] as int)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Available: $stock • Minimum: $minimum'),
            if (lowStock) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: stock == 0 ? colors.error : colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stock == 0 ? 'OUT OF STOCK' : 'LOW STOCK',
                    style: TextStyle(
                      color: stock == 0 ? colors.error : colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openRestock(part),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add Stock'),
                ),
                TextButton.icon(
                  onPressed: () => _openEditPart(part),
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  label: const Text('Edit Details'),
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spare Parts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPart,
        icon: const Icon(Icons.add),
        label: const Text('Add Part'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search part name or code',
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
          SwitchListTile.adaptive(
            title: const Text('Low stock only'),
            subtitle: const Text('At or below the minimum stock level'),
            value: _lowStockOnly,
            onChanged: (value) {
              setState(() => _lowStockOnly = value);
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _parts,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Unable to load parts. '
                        'Check your connection and Firestore rules.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allParts = snapshot.data!.docs;

                if (allParts.isEmpty) {
                  return const Center(
                    child: Text('No parts yet. Tap Add Part.'),
                  );
                }

                final lowStockCount = allParts.where((part) {
                  final data = part.data();

                  return (data['stock'] as int) <= (data['minStock'] as int);
                }).length;

                final visibleParts = allParts.where((part) {
                  final data = part.data();

                  final matchesStock =
                      !_lowStockOnly ||
                      (data['stock'] as int) <= (data['minStock'] as int);

                  return matchesStock && _matchesSearch(part.id, data);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Text(
                        '${visibleParts.length} of ${allParts.length} parts'
                        ' • $lowStockCount low stock',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: visibleParts.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off, size: 48),
                                    const SizedBox(height: 14),
                                    const Text('No parts match these filters.'),
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
                              itemCount: visibleParts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _partCard(visibleParts[index]);
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

// Keep this public screen available to existing navigation.
class AddPartScreen extends StatelessWidget {
  const AddPartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PartFormScreen();
  }
}

class EditPartScreen extends StatelessWidget {
  final String partCode;
  final Map<String, dynamic> initialData;

  const EditPartScreen({
    super.key,
    required this.partCode,
    required this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return _PartFormScreen(partCode: partCode, initialData: initialData);
  }
}

class _PartFormScreen extends StatefulWidget {
  final String? partCode;
  final Map<String, dynamic>? initialData;

  const _PartFormScreen({this.partCode, this.initialData});

  @override
  State<_PartFormScreen> createState() => _PartFormScreenState();
}

class _PartFormScreenState extends State<_PartFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _minimum;

  late final Map<String, dynamic> _originalDetails;

  bool _saving = false;

  bool get _editing => widget.partCode != null;

  @override
  void initState() {
    super.initState();

    final data = widget.initialData ?? <String, dynamic>{};

    _originalDetails = {
      'name': data['name'],
      'unitPriceCents': data['unitPriceCents'],
      'minStock': data['minStock'],
    };

    _code = TextEditingController(text: widget.partCode ?? '');
    _name = TextEditingController(text: data['name']?.toString() ?? '');

    _price = TextEditingController(
      text: _editing ? formatPartPrice(data['unitPriceCents'] as int) : '',
    );

    _stock = TextEditingController(text: (data['stock'] ?? 0).toString());

    _minimum = TextEditingController(text: (data['minStock'] ?? 5).toString());
  }

  String? _quantityValidator(String? value) {
    final text = value?.trim() ?? '';
    final quantity = int.tryParse(text);

    if (!RegExp(r'^\d+$').hasMatch(text) ||
        quantity == null ||
        quantity < 0 ||
        quantity > 1000000) {
      return 'Enter a whole number from 0 to 1000000.';
    }

    return null;
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final code = _code.text.trim().toUpperCase();
    final name = _name.text.trim();
    final price = parsePartPrice(_price.text)!;
    final minimum = int.parse(_minimum.text.trim());

    final details = <String, dynamic>{
      'name': name,
      'unitPriceCents': price,
      'minStock': minimum,
    };

    if (_editing &&
        details.entries.every(
          (entry) => entry.value == _originalDetails[entry.key],
        )) {
      Navigator.of(context).pop();
      return;
    }

    final openingStock = _editing ? 0 : int.parse(_stock.text.trim());

    final reference = FirebaseFirestore.instance
        .collection('spareParts')
        .doc(_editing ? widget.partCode! : code);

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.runTransaction<void>((
        transaction,
      ) async {
        final snapshot = await transaction.get(reference);

        if (_editing) {
          final current = snapshot.data();

          if (current == null) {
            throw const _InventoryException(
              'This part no longer exists. '
              'Go back and reopen the inventory.',
            );
          }

          // Stock may change independently while this form is open.
          // Only detect conflicts in the details being edited.
          final changedElsewhere = _originalDetails.entries.any(
            (entry) => current[entry.key] != entry.value,
          );

          if (changedElsewhere) {
            throw const _InventoryException(
              'Part details changed on another device. '
              'Go back and reopen Edit to load the latest details.',
            );
          }

          transaction.update(reference, {
            ...details,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          if (snapshot.exists) {
            throw const _InventoryException(
              'This part code already exists. '
              'Use Edit Details or Add Stock instead.',
            );
          }

          transaction.set(reference, {
            ...details,
            'stock': openingStock,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) return;

      _message(_editing ? 'Part details updated.' : 'Part added successfully.');

      Navigator.of(context).pop();
    } on _InventoryException catch (error) {
      _message(error.message);
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Permission denied. Check the published spareParts rules.'
            : 'Unable to save part. Check your connection and try again.',
      );
    } catch (_) {
      _message('Unable to save part. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType keyboard = TextInputType.text,
    int? maxLength,
    String? hint,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        readOnly: readOnly,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline, size: 19)
              : null,
        ),
        validator: validator,
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _minimum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit Spare Part' : 'Add Spare Part'),
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
                            ? Icons.edit_note_outlined
                            : Icons.inventory_2_outlined,
                        size: 46,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _editing ? 'Update part details' : 'Add a spare part',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _editing
                            ? 'Update the selling price and stock alert level.'
                            : 'Set up a part and its opening stock.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),
                      _field(
                        controller: _code,
                        label: 'Part code',
                        hint: 'Example: OIL-FILTER-01',
                        maxLength: 30,
                        readOnly: _editing,
                        validator: (value) {
                          final code = value?.trim().toUpperCase() ?? '';

                          return RegExp(r'^[A-Z0-9_-]{1,30}$').hasMatch(code)
                              ? null
                              : 'Use letters, numbers, - or _ only.';
                        },
                      ),
                      _field(
                        controller: _name,
                        label: 'Part name',
                        maxLength: 100,
                        validator: (value) {
                          return value == null || value.trim().isEmpty
                              ? 'Enter a part name.'
                              : null;
                        },
                      ),
                      _field(
                        controller: _price,
                        label: 'Selling price per unit (LKR)',
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          return parsePartPrice(value ?? '') == null
                              ? 'Enter 0–1000000, with up to 2 decimals.'
                              : null;
                        },
                      ),
                      if (!_editing)
                        _field(
                          controller: _stock,
                          label: 'Opening stock quantity',
                          keyboard: TextInputType.number,
                          validator: _quantityValidator,
                        ),
                      _field(
                        controller: _minimum,
                        label: 'Minimum stock alert level',
                        keyboard: TextInputType.number,
                        validator: _quantityValidator,
                      ),
                      if (_editing) ...[
                        Text(
                          'Use Add Stock on the inventory page to receive '
                          'stock. Existing part usage records keep their '
                          'original names and prices.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : _editing
                              ? 'Save Changes'
                              : 'Save Part',
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

class _RestockDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> reference;
  final String name;

  const _RestockDialog({required this.reference, required this.name});

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();

  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final quantity = int.parse(_quantity.text.trim());

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.runTransaction<void>((
        transaction,
      ) async {
        final snapshot = await transaction.get(widget.reference);
        final data = snapshot.data();

        if (data == null) {
          throw const _InventoryException('Part not found.');
        }

        final nextStock = (data['stock'] as int) + quantity;

        if (nextStock > 1000000) {
          throw const _InventoryException('Maximum stock is 1000000 units.');
        }

        transaction.update(widget.reference, {
          'stock': nextStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } on _InventoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.code == 'permission-denied'
            ? 'Permission denied. Check inventory rules.'
            : 'Check your connection and try again.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to add stock.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Add Stock'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.name),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _quantity,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity received',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final quantity = int.tryParse(text);

                    return !RegExp(r'^\d+$').hasMatch(text) ||
                            quantity == null ||
                            quantity < 1 ||
                            quantity > 100000
                        ? 'Enter a whole number from 1 to 100000.'
                        : null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Add Stock'),
          ),
        ],
      ),
    );
  }
}

class _InventoryException implements Exception {
  final String message;

  const _InventoryException(this.message);
}
