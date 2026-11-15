import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'autocare_money.dart';
import 'autocare_service.dart';
import 'invoice_screen.dart';
import 'workshop_reports_screen.dart';

enum _ReportPeriod { all, today, month, custom }

class BillingDashboardScreen extends StatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  State<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends State<BillingDashboardScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _invoices;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _payments;

  _ReportPeriod _period = _ReportPeriod.all;
  DateTimeRange? _customRange;
  bool _unpaidOnly = false;

  @override
  void initState() {
    super.initState();

    _invoices = AutoCareService.db.collection('invoices').snapshots();
    _payments = AutoCareService.db.collection('payments').snapshots();
  }

  int _cents(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    return null;
  }

  String _formatDate(DateTime value) {
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

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  bool _inPeriod(dynamic value) {
    if (_period == _ReportPeriod.all) return true;

    final date = _date(value);
    if (date == null) return false;

    final now = DateTime.now();

    late final DateTime start;
    late final DateTime end;

    switch (_period) {
      case _ReportPeriod.all:
        return true;

      case _ReportPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day + 1);
        break;

      case _ReportPeriod.month:
        start = DateTime(now.year, now.month);
        end = DateTime(now.year, now.month + 1);
        break;

      case _ReportPeriod.custom:
        final range = _customRange;
        if (range == null) return false;

        start = DateTime(range.start.year, range.start.month, range.start.day);

        end = DateTime(range.end.year, range.end.month, range.end.day + 1);
        break;
    }

    return !date.isBefore(start) && date.isBefore(end);
  }

  String get _periodLabel {
    final now = DateTime.now();

    switch (_period) {
      case _ReportPeriod.all:
        return 'All time';

      case _ReportPeriod.today:
        return _formatDate(now);

      case _ReportPeriod.month:
        return 'Month starting '
            '${_formatDate(DateTime(now.year, now.month))}';

      case _ReportPeriod.custom:
        final range = _customRange;
        if (range == null) return 'Custom dates';

        return '${_formatDate(range.start)} — '
            '${_formatDate(range.end)}';
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 10, 12, 31),
      initialDateRange:
          _customRange ??
          DateTimeRange(start: DateTime(today.year, today.month), end: today),
      helpText: 'Select report dates',
      saveText: 'Apply',
    );

    if (!mounted || picked == null) return;

    setState(() {
      _customRange = picked;
      _period = _ReportPeriod.custom;
    });
  }

  void _openWorkshopReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WorkshopReportsScreen()),
    );
  }

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _metric({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    bool prominent = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: prominent ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: prominent ? colors.primary : colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodFilters() {
    Widget chip(String text, _ReportPeriod period) {
      return ChoiceChip(
        label: Text(text),
        selected: _period == period,
        onSelected: (_) {
          if (period == _ReportPeriod.custom) {
            _pickDates();
          } else {
            setState(() => _period = period);
          }
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('All time', _ReportPeriod.all),
        chip('Today', _ReportPeriod.today),
        chip('This month', _ReportPeriod.month),
        chip('Custom dates', _ReportPeriod.custom),
      ],
    );
  }

  Widget _workshopReportsCard() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Icon(
          Icons.analytics_outlined,
          color: colors.primary,
          size: 30,
        ),
        title: const Text(
          'Workshop Reports',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Completed jobs and low stock'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openWorkshopReports,
      ),
    );
  }

  Widget _invoiceTile(
    QueryDocumentSnapshot<Map<String, dynamic>> invoice,
    bool paid,
  ) {
    final data = invoice.data();
    final colors = Theme.of(context).colorScheme;
    final createdAt = _date(data['createdAt']);

    final registration = data['registration']?.toString() ?? 'Vehicle';

    final customer = data['customerName']?.toString() ?? 'Customer';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Icon(Icons.receipt_long_outlined, color: colors.primary),
        title: Text(
          '$registration • $customer',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(money(_cents(data['grandTotalCents']))),
              const SizedBox(height: 4),
              Text(
                createdAt == null
                    ? 'Invoice date unavailable'
                    : _formatDate(createdAt),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                paid ? 'PAID' : 'UNPAID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: paid ? colors.primary : colors.error,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => InvoiceScreen(jobId: invoice.id),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Reports'),
        actions: [
          IconButton(
            tooltip: 'Workshop Reports',
            onPressed: _openWorkshopReports,
            icon: const Icon(Icons.analytics_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _invoices,
        builder: (context, invoiceSnapshot) {
          if (invoiceSnapshot.hasError) {
            return _error(
              'Unable to load invoices. Check your connection '
              'and Firestore permissions.',
            );
          }

          if (!invoiceSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _payments,
            builder: (context, paymentSnapshot) {
              if (paymentSnapshot.hasError) {
                return _error(
                  'Unable to load payments. Check your connection '
                  'and Firestore permissions.',
                );
              }

              if (!paymentSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final invoices = invoiceSnapshot.data!.docs;

              final payments = {
                for (final document in paymentSnapshot.data!.docs)
                  document.id: document.data(),
              };

              final periodPayments = payments.values
                  .where((payment) => _inPeriod(payment['createdAt']))
                  .toList();

              final received = periodPayments.fold<int>(
                0,
                (total, payment) => total + _cents(payment['amountCents']),
              );

              final periodInvoices = invoices
                  .where((invoice) => _inPeriod(invoice.data()['createdAt']))
                  .toList();

              final invoiced = periodInvoices.fold<int>(
                0,
                (total, invoice) =>
                    total + _cents(invoice.data()['grandTotalCents']),
              );

              final periodUnpaid = periodInvoices
                  .where((invoice) => !payments.containsKey(invoice.id))
                  .toList();

              final allUnpaid = invoices
                  .where((invoice) => !payments.containsKey(invoice.id))
                  .toList();

              final outstanding = allUnpaid.fold<int>(
                0,
                (total, invoice) =>
                    total + _cents(invoice.data()['grandTotalCents']),
              );

              final paidCount = periodInvoices.length - periodUnpaid.length;

              final visibleInvoices =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
                    _unpaidOnly ? periodUnpaid : periodInvoices,
                  );

              visibleInvoices.sort((a, b) {
                final first = _date(a.data()['createdAt']);
                final second = _date(b.data()['createdAt']);

                return (second?.millisecondsSinceEpoch ?? 0).compareTo(
                  first?.millisecondsSinceEpoch ?? 0,
                );
              });

              final undatedCount =
                  invoices
                      .where(
                        (invoice) => _date(invoice.data()['createdAt']) == null,
                      )
                      .length +
                  payments.values
                      .where((payment) => _date(payment['createdAt']) == null)
                      .length;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const Text(
                          'Your billing overview',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Track payments and keep invoices organised.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        _workshopReportsCard(),
                        const SizedBox(height: 20),
                        _periodFilters(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.date_range_outlined,
                              size: 17,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _periodLabel,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _metric(
                          title: 'PAYMENTS RECEIVED',
                          value: money(received),
                          description:
                              '${periodPayments.length} payments '
                              'received in this period',
                          icon: Icons.account_balance_wallet_outlined,
                          prominent: true,
                        ),
                        const SizedBox(height: 12),
                        _metric(
                          title: 'INVOICED IN THIS PERIOD',
                          value: money(invoiced),
                          description:
                              '${periodInvoices.length} invoices • '
                              '$paidCount paid • '
                              '${periodUnpaid.length} unpaid now',
                          icon: Icons.receipt_long_outlined,
                        ),
                        const SizedBox(height: 12),
                        _metric(
                          title: 'TOTAL OUTSTANDING • ALL TIME',
                          value: money(outstanding),
                          description:
                              '${allUnpaid.length} unpaid invoices '
                              'across all dates',
                          icon: Icons.pending_actions_outlined,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Payments use the payment date. Invoices use '
                          'the invoice date. Paid status shows the '
                          'current status. Dates use your device time.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (_period != _ReportPeriod.all &&
                            undatedCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '$undatedCount records without a date are '
                            'excluded from date-filtered results. '
                            'Select All time to include them.',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        const Text(
                          'Invoices',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Unpaid invoices only'),
                          subtitle: const Text(
                            'Applies to the selected invoice dates',
                          ),
                          value: _unpaidOnly,
                          onChanged: (value) {
                            setState(() => _unpaidOnly = value);
                          },
                        ),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                  if (visibleInvoices.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 36,
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 42),
                            SizedBox(height: 12),
                            Text(
                              'No invoices for these filters.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final invoice = visibleInvoices[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _invoiceTile(
                              invoice,
                              payments.containsKey(invoice.id),
                            ),
                          );
                        }, childCount: visibleInvoices.length),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
