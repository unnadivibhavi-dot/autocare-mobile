import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'autocare_money.dart';
import 'autocare_service.dart';
import 'invoice_pdf_screen.dart';

class InvoiceScreen extends StatefulWidget {
  final String jobId;

  const InvoiceScreen({super.key, required this.jobId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _invoice;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _payment;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usage;

  @override
  void initState() {
    super.initState();

    _invoice = AutoCareService.db
        .collection('invoices')
        .doc(widget.jobId)
        .snapshots();

    _payment = AutoCareService.db
        .collection('payments')
        .doc(widget.jobId)
        .snapshots();

    _usage = AutoCareService.db
        .collection('partUsage')
        .where('jobId', isEqualTo: widget.jobId)
        .snapshots();
  }

  String _date(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Saving...';
    }

    return MaterialLocalizations.of(context).formatFullDate(timestamp.toDate());
  }

  Widget _amountRow(String label, String amount, {bool bold = false}) {
    final weight = bold ? FontWeight.w800 : FontWeight.normal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: weight)),
          ),
          const SizedBox(width: 12),
          Text(amount, style: TextStyle(fontWeight: weight)),
        ],
      ),
    );
  }

  void _openPdf() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoicePdfScreen(jobId: widget.jobId),
      ),
    );
  }

  Future<void> _copySummary(
    Map<String, dynamic> invoice,
    String paymentStatus,
  ) async {
    final summary =
        'AutoCare Invoice AC-${widget.jobId}\n'
        'Customer: ${invoice['customerName']}\n'
        'Vehicle: ${invoice['registration']}\n'
        'Labour: ${money(invoice['labourCents'] as int)}\n'
        'Parts: ${money(invoice['partsCents'] as int)}\n'
        'Total: ${money(invoice['grandTotalCents'] as int)}\n'
        'Status: $paymentStatus';

    try {
      await Clipboard.setData(ClipboardData(text: summary));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice summary copied.')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy invoice summary.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _invoice,
        builder: (context, invoiceSnapshot) {
          if (invoiceSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load invoice. Check permissions.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!invoiceSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoice = invoiceSnapshot.data!.data();

          if (invoice == null) {
            return const Center(child: Text('Invoice not found.'));
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _payment,
            builder: (context, paymentSnapshot) {
              final payment = paymentSnapshot.data?.data();

              final paymentStatusAvailable =
                  paymentSnapshot.hasData && !paymentSnapshot.hasError;

              final paymentStatus = !paymentStatusAvailable
                  ? 'UNAVAILABLE'
                  : payment != null
                  ? 'PAID'
                  : 'UNPAID';

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'AUTOCARE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 8),

                      SelectableText('Invoice AC-${widget.jobId}'),

                      const SizedBox(height: 4),

                      Text(_date(invoice['createdAt'] as Timestamp?)),

                      const SizedBox(height: 24),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BILL TO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Text(
                                invoice['customerName'] as String,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(invoice['customerPhone'] as String),

                              const SizedBox(height: 6),

                              Text('Vehicle: ${invoice['registration']}'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'PARTS USED',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _usage,
                        builder: (context, usageSnapshot) {
                          if (usageSnapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Unable to load part lines. '
                                'Totals are shown below.',
                              ),
                            );
                          }

                          if (!usageSnapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(),
                            );
                          }

                          final documents = usageSnapshot.data!.docs.toList();

                          documents.sort((a, b) {
                            return (a.data()['partName'] as String).compareTo(
                              b.data()['partName'] as String,
                            );
                          });

                          if (documents.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No parts used.'),
                            );
                          }

                          return Column(
                            children: documents.map((document) {
                              final data = document.data();

                              return _amountRow(
                                '${data['partName']} × '
                                '${data['quantity']}\n'
                                '${money(data['unitPriceCents'] as int)} each',
                                money(data['totalCents'] as int),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 12),
                      const Divider(),

                      _amountRow(
                        'Labour',
                        money(invoice['labourCents'] as int),
                      ),

                      _amountRow('Parts', money(invoice['partsCents'] as int)),

                      const Divider(),

                      _amountRow(
                        'TOTAL',
                        money(invoice['grandTotalCents'] as int),
                        bold: true,
                      ),

                      const SizedBox(height: 20),

                      if (paymentSnapshot.hasError)
                        const Text(
                          'Payment status unavailable. '
                          'Reopen this screen before recording payment.',
                        )
                      else if (!paymentSnapshot.hasData)
                        const LinearProgressIndicator()
                      else ...[
                        Text(
                          paymentStatus,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (payment != null) ...[
                          Text('Method: ${payment['method']}'),

                          const SizedBox(height: 6),

                          Text(
                            'Paid: '
                            '${_date(payment['createdAt'] as Timestamp?)}',
                          ),

                          if ((payment['reference'] as String).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Reference: ${payment['reference']}'),
                          ],
                        ] else
                          FilledButton.icon(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => _PaymentDialog(
                                  invoiceId: widget.jobId,
                                  amount: invoice['grandTotalCents'] as int,
                                ),
                              );
                            },
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record Full Payment'),
                          ),
                      ],

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _openPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('PDF Preview / Print / Share'),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: () => _copySummary(invoice, paymentStatus),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy Invoice Summary'),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Payment recording does not charge a card '
                        'or transfer money.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final String invoiceId;
  final int amount;

  const _PaymentDialog({required this.invoiceId, required this.amount});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _reference = TextEditingController();
  final _form = GlobalKey<FormState>();

  String? _method;
  String? _error;

  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }

    final method = _method!;
    final reference = _reference.text.trim();

    FocusScope.of(context).unfocus();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Payment Received'),
          content: Text(
            'Record ${money(widget.amount)} received by $method? '
            'This payment record cannot be edited.',
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
              child: const Text('Confirm Received'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AutoCareService.recordPayment(
        invoiceId: widget.invoiceId,
        method: method,
        reference: reference,
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
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Record Full Payment'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  money(widget.amount),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 18),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items: ['Cash', 'Card', 'Bank Transfer'].map((method) {
                    return DropdownMenuItem<String>(
                      value: method,
                      child: Text(method),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() => _method = value);
                        },
                  validator: (value) {
                    return value == null ? 'Select a payment method.' : null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _reference,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Receipt/reference (optional)',
                  ),
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
            child: Text(_saving ? 'Saving...' : 'Record Payment'),
          ),
        ],
      ),
    );
  }
}
