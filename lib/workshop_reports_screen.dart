import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'autocare_money.dart';
import 'autocare_service.dart';
import 'inventory_screen.dart';
import 'invoice_screen.dart';

class WorkshopReportsScreen extends StatefulWidget {
  const WorkshopReportsScreen({super.key});

  @override
  State<WorkshopReportsScreen> createState() => _WorkshopReportsScreenState();
}

class _WorkshopReportsScreenState extends State<WorkshopReportsScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobs;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _parts;

  String _period = 'All time';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();

    _jobs = AutoCareService.db.collection('jobCards').snapshots();
    _parts = AutoCareService.db.collection('spareParts').snapshots();
  }

  int _number(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  bool _matchesPeriod(dynamic value) {
    if (_period == 'All time') return true;

    final date = _date(value);
    if (date == null) return false;

    final now = DateTime.now();
    late final DateTime start;
    late final DateTime end;

    if (_period == 'Today') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day + 1);
    } else if (_period == 'This month') {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    } else {
      final range = _range;
      if (range == null) return false;

      start = DateTime(range.start.year, range.start.month, range.start.day);

      end = DateTime(range.end.year, range.end.month, range.end.day + 1);
    }

    return !date.isBefore(start) && date.isBefore(end);
  }

  Future<void> _selectPeriod(String period) async {
    if (period != 'Custom') {
      setState(() => _period = period);
      return;
    }

    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      initialDateRange:
          _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month),
            end: DateTime(now.year, now.month, now.day),
          ),
      helpText: 'Select job creation dates',
      saveText: 'Apply',
    );

    if (!mounted || picked == null) return;

    setState(() {
      _range = picked;
      _period = 'Custom';
    });
  }

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _summary({
    required IconData icon,
    required String title,
    required int count,
    required String description,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: colors.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  void _openInventory() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const InventoryScreen()));
  }

  Widget _partTile(QueryDocumentSnapshot<Map<String, dynamic>> part) {
    final data = part.data();
    final stock = _number(data['stock']);
    final minimum = _number(data['minStock']);
    final colors = Theme.of(context).colorScheme;
    final outOfStock = stock <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(
            outOfStock
                ? Icons.inventory_2_outlined
                : Icons.warning_amber_rounded,
            color: outOfStock ? colors.error : colors.primary,
          ),
          title: Text(
            data['name']?.toString() ?? part.id,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'Code: ${part.id}\n'
              'Available: $stock • Minimum: $minimum\n'
              '${outOfStock ? 'OUT OF STOCK' : 'LOW STOCK'}',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openInventory,
        ),
      ),
    );
  }

  Widget _jobTile(QueryDocumentSnapshot<Map<String, dynamic>> job) {
    final data = job.data();
    final createdAt = _date(data['createdAt']);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(Icons.task_alt, color: colors.primary),
          title: Text(
            data['serviceType']?.toString() ?? 'Vehicle service',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'Job: ${job.id}\n'
              'Created: ${createdAt == null ? 'Date unavailable' : _formatDate(createdAt)}\n'
              'Labour: ${money(_number(data['labourCents']))}',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InvoiceScreen(jobId: job.id),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Workshop Reports')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _jobs,
        builder: (context, jobSnapshot) {
          if (jobSnapshot.hasError) {
            return _error(
              'Unable to load job cards. Check your connection '
              'and Firestore permissions.',
            );
          }

          if (!jobSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _parts,
            builder: (context, partSnapshot) {
              if (partSnapshot.hasError) {
                return _error(
                  'Unable to load spare parts. Check your connection '
                  'and Firestore permissions.',
                );
              }

              if (!partSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final jobs = jobSnapshot.data!.docs;

              final completed = jobs.where((job) {
                final data = job.data();

                return data['status'] == 'completed' &&
                    _matchesPeriod(data['createdAt']);
              }).toList();

              completed.sort((a, b) {
                final first = _date(a.data()['createdAt']);
                final second = _date(b.data()['createdAt']);

                return (second?.millisecondsSinceEpoch ?? 0).compareTo(
                  first?.millisecondsSinceEpoch ?? 0,
                );
              });

              final lowStock = partSnapshot.data!.docs.where((part) {
                final data = part.data();

                return _number(data['stock']) <= _number(data['minStock']);
              }).toList();

              lowStock.sort((a, b) {
                final stockComparison = _number(a.data()['stock'])
                    .compareTo(_number(b.data()['stock']));

                if (stockComparison != 0) return stockComparison;

                return (a.data()['name'] ?? a.id)
                    .toString()
                    .toLowerCase()
                    .compareTo(
                      (b.data()['name'] ?? b.id).toString().toLowerCase(),
                    );
              });

              final undatedCompleted = jobs.where((job) {
                final data = job.data();

                return data['status'] == 'completed' &&
                    _date(data['createdAt']) == null;
              }).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                children: [
                  const Text(
                    'Keep your workshop on track',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review completed jobs and parts that need attention.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 22),
                  _summary(
                    icon: Icons.inventory_2_outlined,
                    title: 'Parts needing attention',
                    count: lowStock.length,
                    description: 'Current stock • independent of date filter',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Low stock',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _openInventory,
                        child: const Text('Inventory'),
                      ),
                    ],
                  ),
                  if (lowStock.isEmpty)
                    _empty('All parts are above their minimum stock level.')
                  else
                    ...lowStock.map(_partTile),
                  const SizedBox(height: 24),
                  const Text(
                    'Completed jobs',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shows currently completed jobs, filtered by the date '
                    'the job card was created.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final period in [
                        'All time',
                        'Today',
                        'This month',
                        'Custom',
                      ])
                        ChoiceChip(
                          label: Text(period),
                          selected: _period == period,
                          onSelected: (_) => _selectPeriod(period),
                        ),
                    ],
                  ),
                  if (_period == 'Custom' && _range != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        '${_formatDate(_range!.start)} — '
                        '${_formatDate(_range!.end)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _summary(
                    icon: Icons.task_alt,
                    title: 'Completed jobs',
                    count: completed.length,
                    description: 'Job creation period: $_period',
                  ),
                  if (_period != 'All time' && undatedCompleted > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '$undatedCompleted completed jobs have no creation '
                        'date. Select All time to include them.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (completed.isEmpty)
                    _empty('No completed jobs for these dates.')
                  else
                    ...completed.map(_jobTile),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
