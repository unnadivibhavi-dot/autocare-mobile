import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Money is stored as integer cents.
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
  return '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _parts;
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();

    _parts = FirebaseFirestore.instance
        .collection('spareParts')
        .orderBy('name')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spare Parts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddPartScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Part'),
      ),
      body: Column(
        children: [
          SwitchListTile(
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
                        'Unable to load parts. Check your '
                        'connection and Firestore rules.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final parts = snapshot.data!.docs.where((doc) {
                  final data = doc.data();

                  return !_lowStockOnly ||
                      (data['stock'] as int) <= (data['minStock'] as int);
                }).toList();

                if (parts.isEmpty) {
                  return Center(
                    child: Text(
                      _lowStockOnly
                          ? 'No low-stock parts.'
                          : 'No parts yet. Tap Add Part.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: parts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final part = parts[index];
                    final data = part.data();

                    final stock = data['stock'] as int;
                    final minimum = data['minStock'] as int;
                    final lowStock = stock <= minimum;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color: Theme.of(context).colorScheme.primary,
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
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Code: ${part.id}'),
                            const SizedBox(height: 8),
                            Text(
                              'Unit price: LKR '
                              '${formatPartPrice(data['unitPriceCents'] as int)}',
                            ),
                            const SizedBox(height: 8),
                            Text('Available: $stock   •   Minimum: $minimum'),
                            if (lowStock) ...[
                              const SizedBox(height: 12),
                              Text(
                                stock == 0 ? 'OUT OF STOCK' : 'LOW STOCK',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => _RestockDialog(
                                    reference: part.reference,
                                    name: data['name'] as String,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_box_outlined),
                              label: const Text('Add Stock'),
                            ),
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

class AddPartScreen extends StatefulWidget {
  const AddPartScreen({super.key});

  @override
  State<AddPartScreen> createState() => _AddPartScreenState();
}

class _AddPartScreenState extends State<AddPartScreen> {
  final _formKey = GlobalKey<FormState>();

  final _code = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _minimum = TextEditingController(text: '5');

  bool _saving = false;

  String? _quantityValidator(String? value) {
    final quantity = int.tryParse(value?.trim() ?? '');

    if (quantity == null || quantity < 0 || quantity > 1000000) {
      return 'Enter a whole number from 0 to 1000000.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final code = _code.text.trim().toUpperCase();
    final name = _name.text.trim();
    final price = parsePartPrice(_price.text)!;
    final stock = int.parse(_stock.text.trim());
    final minimum = int.parse(_minimum.text.trim());

    setState(() => _saving = true);

    final reference = FirebaseFirestore.instance
        .collection('spareParts')
        .doc(code);

    try {
      await FirebaseFirestore.instance.runTransaction<void>((
        transaction,
      ) async {
        final existing = await transaction.get(reference);

        if (existing.exists) {
          throw StateError(
            'This part code already exists. Use Add Stock instead.',
          );
        }

        transaction.set(reference, {
          'name': name,
          'unitPriceCents': price,
          'stock': stock,
          'minStock': minimum,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } on StateError catch (error) {
      if (!mounted) return;
      _message('${error.message}');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _message(
        error.code == 'permission-denied'
            ? 'Check your UID and spareParts rules.'
            : 'Unable to save part. Check your connection.',
      );
    } catch (_) {
      if (!mounted) return;
      _message('Unable to save part. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType keyboard = TextInputType.text,
    int? maxLength,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        maxLength: maxLength,
        decoration: InputDecoration(labelText: label, hintText: hint),
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
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Spare Part'),
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
                      _field(
                        controller: _code,
                        label: 'Part code',
                        hint: 'Example: OIL-FILTER-01',
                        maxLength: 30,
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
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save Part'),
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
          throw StateError('Part not found.');
        }

        final nextStock = (data['stock'] as int) + quantity;

        if (nextStock > 1000000) {
          throw StateError('Maximum stock is 1000000 units.');
        }

        transaction.update(widget.reference, {
          'stock': nextStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } on StateError catch (error) {
      if (mounted) setState(() => _error = '${error.message}');
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.code == 'permission-denied'
              ? 'Permission denied. Check inventory rules.'
              : 'Check your connection and try again.';
        });
      }
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
        content: Form(
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
                  final quantity = int.tryParse(value?.trim() ?? '');

                  return quantity == null || quantity < 1 || quantity > 100000
                      ? 'Enter a whole number from 1 to 100000.'
                      : null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
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
