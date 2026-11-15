import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'autocare_money.dart';
import 'autocare_service.dart';

class PartsUsageScreen extends StatefulWidget {
  final String jobId;

  const PartsUsageScreen({super.key, required this.jobId});

  @override
  State<PartsUsageScreen> createState() => _PartsUsageScreenState();
}

class _PartsUsageScreenState extends State<PartsUsageScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _job;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usage;

  @override
  void initState() {
    super.initState();

    _job = AutoCareService.db
        .collection('jobCards')
        .doc(widget.jobId)
        .snapshots();

    _usage = AutoCareService.db
        .collection('partUsage')
        .where('jobId', isEqualTo: widget.jobId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parts Used')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _job,
        builder: (context, jobSnapshot) {
          if (jobSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load job. Check permissions.'),
            );
          }

          if (!jobSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final job = jobSnapshot.data!.data();

          if (job == null) {
            return const Center(child: Text('Job Card not found.'));
          }

          final editable = ['open', 'in_progress'].contains(job['status']);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      money((job['partsTotalCents'] as int?) ?? 0),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Parts total • prices are saved at the time of use',
                    ),
                    const SizedBox(height: 16),

                    if (editable)
                      FilledButton.icon(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => _UsePartDialog(jobId: widget.jobId),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Use a Part'),
                      )
                    else
                      const Text('Completed job: part usage is locked.'),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _usage,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load part usage.'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final documents = snapshot.data!.docs.toList();

                    documents.sort((a, b) {
                      final first = a.data()['createdAt'] as Timestamp?;

                      final second = b.data()['createdAt'] as Timestamp?;

                      return (second?.millisecondsSinceEpoch ?? 0).compareTo(
                        first?.millisecondsSinceEpoch ?? 0,
                      );
                    });

                    if (documents.isEmpty) {
                      return const Center(child: Text('No parts used yet.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: documents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = documents[index].data();

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(data['partName'] as String),
                            subtitle: Text(
                              '${data['quantity']} × '
                              '${money(data['unitPriceCents'] as int)}',
                            ),
                            trailing: Text(money(data['totalCents'] as int)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UsePartDialog extends StatefulWidget {
  final String jobId;

  const _UsePartDialog({required this.jobId});

  @override
  State<_UsePartDialog> createState() => _UsePartDialogState();
}

class _UsePartDialogState extends State<_UsePartDialog> {
  final _form = GlobalKey<FormState>();

  final _quantity = TextEditingController(text: '1');

  late final Future<QuerySnapshot<Map<String, dynamic>>> _parts;

  // Keep the same ID when retrying this submission.
  final _usageId = AutoCareService.db.collection('partUsage').doc().id;

  QueryDocumentSnapshot<Map<String, dynamic>>? _selected;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _parts = AutoCareService.db.collection('spareParts').orderBy('name').get();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }

    final part = _selected!;
    final quantity = int.parse(_quantity.text.trim());

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AutoCareService.usePart(
        usageId: _usageId,
        jobId: widget.jobId,
        partId: part.id,
        quantity: quantity,
        expectedUnitPrice: part.data()['unitPriceCents'] as int,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = operationError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
        title: const Text('Use a Spare Part'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _parts,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Unable to load parts. Close and retry.');
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final parts = snapshot.data!.docs.where((part) {
                  return (part.data()['stock'] as int) > 0;
                }).toList();

                if (parts.isEmpty) {
                  return const Text(
                    'No parts in stock. '
                    'Add stock in the Parts tab first.',
                  );
                }

                return Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Part'),
                        items: parts.map((part) {
                          final data = part.data();

                          return DropdownMenuItem<String>(
                            value: part.id,
                            child: Text(
                              '${data['name']} '
                              '(${data['stock']} left)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _saving
                            ? null
                            : (id) {
                                setState(() {
                                  _selected = parts.firstWhere(
                                    (part) => part.id == id,
                                  );
                                });
                              },
                        validator: (value) {
                          return value == null ? 'Select a part.' : null;
                        },
                      ),

                      const SizedBox(height: 16),

                      if (_selected != null) ...[
                        Text(
                          'Unit price: '
                          '${money(_selected!.data()['unitPriceCents'] as int)}',
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _quantity,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        validator: (value) {
                          final quantity = int.tryParse(value?.trim() ?? '');

                          if (quantity == null ||
                              quantity < 1 ||
                              quantity > 10000) {
                            return 'Enter 1–10000 whole units.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Saving records the usage and deducts stock. '
                        'This cannot be edited here.',
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
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving || _selected == null ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Record Usage'),
          ),
        ],
      ),
    );
  }
}
