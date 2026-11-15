import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'autocare_money.dart';
import 'invoice_screen.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final String registration;

  const ServiceHistoryScreen({
    super.key,
    required this.vehicleId,
    required this.registration,
  });

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobs;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _invoices;

  String? _expandedJobId;

  @override
  void initState() {
    super.initState();

    _jobs = FirebaseFirestore.instance
        .collection('jobCards')
        .where('vehicleId', isEqualTo: widget.vehicleId)
        .snapshots();

    _invoices = FirebaseFirestore.instance
        .collection('invoices')
        .where('vehicleId', isEqualTo: widget.vehicleId)
        .snapshots();
  }

  Timestamp? _completedAt(Map<String, dynamic> data) {
    return data['updatedAt'] as Timestamp? ?? data['createdAt'] as Timestamp?;
  }

  String _dateLabel(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Date unavailable';
    }

    final date = timestamp.toDate();

    final day = MaterialLocalizations.of(context).formatMediumDate(date);

    final time = TimeOfDay.fromDateTime(date).format(context);

    return '$day • $time';
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _jobs,
        builder: (context, jobSnapshot) {
          if (jobSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load service history. '
                  'Check your connection and permissions.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!jobSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final completedJobs = jobSnapshot.data!.docs.where((job) {
            return job.data()['status'] == 'completed';
          }).toList();

          completedJobs.sort((a, b) {
            final first = _completedAt(a.data())?.millisecondsSinceEpoch ?? 0;

            final second = _completedAt(b.data())?.millisecondsSinceEpoch ?? 0;

            return second.compareTo(first);
          });

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _invoices,
            builder: (context, invoiceSnapshot) {
              final invoiceDataAvailable =
                  invoiceSnapshot.hasData && !invoiceSnapshot.hasError;

              final invoices = <String, Map<String, dynamic>>{};

              if (invoiceDataAvailable) {
                for (final document in invoiceSnapshot.data!.docs) {
                  invoices[document.id] = document.data();
                }
              }

              final totalInvoiced = invoices.values.fold<int>(0, (
                total,
                invoice,
              ) {
                return total + (invoice['grandTotalCents'] as int);
              });

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.registration,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Completed services and their recorded costs.',
                      ),

                      const SizedBox(height: 22),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _summaryItem(
                                icon: Icons.build_circle_outlined,
                                label: 'Completed services',
                                value: '${completedJobs.length}',
                              ),

                              const SizedBox(height: 20),

                              _summaryItem(
                                icon: Icons.receipt_long_outlined,
                                label: 'Total invoiced',
                                value: invoiceDataAvailable
                                    ? money(totalInvoiced)
                                    : invoiceSnapshot.hasError
                                    ? 'Unavailable'
                                    : 'Loading...',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Total invoiced includes paid and unpaid invoices.',
                        style: TextStyle(fontSize: 12),
                      ),

                      const SizedBox(height: 24),

                      if (completedJobs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.history_rounded, size: 58),
                              SizedBox(height: 16),
                              Text(
                                'No completed services yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Complete a Job Card to add it '
                                'to this vehicle’s history.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                      ...completedJobs.map((job) {
                        final data = job.data();

                        final labour = data['labourCents'] as int;

                        final parts = (data['partsTotalCents'] as int?) ?? 0;

                        final invoice = invoices[job.id];

                        final expanded = _expandedJobId == job.id;

                        final duration =
                            MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 250);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.all(18),
                                  leading: CircleAvatar(
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                  title: Text(
                                    data['serviceType'] as String,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Completed: '
                                      '${_dateLabel(_completedAt(data))}'
                                      '\nJob total: '
                                      '${money(labour + parts)}',
                                    ),
                                  ),
                                  isThreeLine: true,
                                  trailing: Icon(
                                    expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _expandedJobId = expanded ? null : job.id;
                                    });
                                  },
                                ),

                                AnimatedSize(
                                  duration: duration,
                                  curve: Curves.easeInOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: expanded
                                      ? Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            18,
                                            0,
                                            18,
                                            20,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const Divider(),

                                              const SizedBox(height: 12),

                                              const Text(
                                                'SERVICE NOTES',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1,
                                                ),
                                              ),

                                              const SizedBox(height: 8),

                                              Text(
                                                (data['notes'] as String)
                                                        .trim()
                                                        .isEmpty
                                                    ? 'No notes recorded.'
                                                    : data['notes'] as String,
                                              ),

                                              const SizedBox(height: 20),

                                              _costRow('Labour', money(labour)),

                                              _costRow('Parts', money(parts)),

                                              _costRow(
                                                'Recorded job total',
                                                money(labour + parts),
                                                bold: true,
                                              ),

                                              const SizedBox(height: 18),

                                              const Text(
                                                'PARTS USED',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1,
                                                ),
                                              ),

                                              const SizedBox(height: 10),

                                              _HistoryParts(jobId: job.id),

                                              const SizedBox(height: 20),

                                              if (!invoiceDataAvailable)
                                                Text(
                                                  invoiceSnapshot.hasError
                                                      ? 'Invoice details '
                                                            'unavailable.'
                                                      : 'Loading invoice '
                                                            'details...',
                                                )
                                              else if (invoice == null)
                                                const Text(
                                                  'No invoice has been '
                                                  'created for this '
                                                  'service yet.',
                                                )
                                              else
                                                FilledButton.icon(
                                                  onPressed: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            InvoiceScreen(
                                                              jobId: job.id,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.receipt_long_outlined,
                                                  ),
                                                  label: const Text(
                                                    'View Invoice & '
                                                    'Payment',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox(
                                          width: double.infinity,
                                          height: 0,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
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

  Widget _costRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryParts extends StatefulWidget {
  final String jobId;

  const _HistoryParts({required this.jobId});

  @override
  State<_HistoryParts> createState() => _HistoryPartsState();
}

class _HistoryPartsState extends State<_HistoryParts> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _parts;

  @override
  void initState() {
    super.initState();

    _parts = FirebaseFirestore.instance
        .collection('partUsage')
        .where('jobId', isEqualTo: widget.jobId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _parts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load parts used.');
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final documents = snapshot.data!.docs;

        if (documents.isEmpty) {
          return const Text('No parts were recorded for this service.');
        }

        return Column(
          children: documents.map((document) {
            final data = document.data();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['partName'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data['quantity']} × '
                          '${money(data['unitPriceCents'] as int)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(money(data['totalCents'] as int)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
