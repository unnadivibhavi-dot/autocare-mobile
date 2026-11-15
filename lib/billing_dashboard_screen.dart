import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'autocare_money.dart';
import 'autocare_service.dart';
import 'invoice_screen.dart';

class BillingDashboardScreen extends StatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  State<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends State<BillingDashboardScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _invoices;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _payments;

  bool _unpaidOnly = false;

  @override
  void initState() {
    super.initState();

    _invoices = AutoCareService.db.collection('invoices').snapshots();

    _payments = AutoCareService.db.collection('payments').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Payments')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _invoices,
        builder: (context, invoiceSnapshot) {
          if (invoiceSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load invoices. Check permissions.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!invoiceSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _payments,
            builder: (context, paymentSnapshot) {
              if (paymentSnapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Unable to load payments. Check permissions.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!paymentSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final invoices = invoiceSnapshot.data!.docs.toList();

              final payments = {
                for (final document in paymentSnapshot.data!.docs)
                  document.id: document.data(),
              };

              final totalReceived = payments.values.fold<int>(0, (
                total,
                payment,
              ) {
                return total + (payment['amountCents'] as int);
              });

              final unpaidInvoices = invoices.where((invoice) {
                return !payments.containsKey(invoice.id);
              }).toList();

              final outstandingAmount = unpaidInvoices.fold<int>(0, (
                total,
                invoice,
              ) {
                return total + (invoice.data()['grandTotalCents'] as int);
              });

              final paidCount = invoices.length - unpaidInvoices.length;

              final visibleInvoices = _unpaidOnly ? unpaidInvoices : invoices;

              visibleInvoices.sort((a, b) {
                final firstDate = a.data()['createdAt'] as Timestamp?;

                final secondDate = b.data()['createdAt'] as Timestamp?;

                return (secondDate?.millisecondsSinceEpoch ?? 0).compareTo(
                  firstDate?.millisecondsSinceEpoch ?? 0,
                );
              });

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'TOTAL PAYMENTS RECEIVED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          money(totalReceived),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Outstanding: ${money(outstandingAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),

                        const SizedBox(height: 6),

                        Text('${unpaidInvoices.length} unpaid invoices'),

                        const SizedBox(height: 6),

                        Text(
                          'Total invoices: ${invoices.length}'
                          ' • Paid: $paidCount',
                        ),
                      ],
                    ),
                  ),

                  SwitchListTile(
                    title: const Text('Unpaid invoices only'),
                    value: _unpaidOnly,
                    onChanged: (value) {
                      setState(() => _unpaidOnly = value);
                    },
                  ),

                  Expanded(
                    child: visibleInvoices.isEmpty
                        ? const Center(child: Text('No invoices to display.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: visibleInvoices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final invoice = visibleInvoices[index];
                              final data = invoice.data();

                              final paid = payments.containsKey(invoice.id);

                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: const Icon(
                                    Icons.receipt_long_outlined,
                                  ),
                                  title: Text(
                                    '${data['registration']}'
                                    ' • ${data['customerName']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${money(data['grandTotalCents'] as int)}'
                                    '\n${paid ? 'PAID' : 'UNPAID'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            InvoiceScreen(jobId: invoice.id),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
