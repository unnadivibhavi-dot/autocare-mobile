import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'autocare_money.dart';
import 'autocare_service.dart';
import 'parts_usage_screen.dart';
import 'invoice_screen.dart';
import 'billing_dashboard_screen.dart';

class JobCardsScreen extends StatefulWidget {
  final String vehicleId;
  final String registration;

  const JobCardsScreen({
    super.key,
    required this.vehicleId,
    required this.registration,
  });

  @override
  State<JobCardsScreen> createState() => _JobCardsScreenState();
}

class _JobCardsScreenState extends State<JobCardsScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _bookings;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobs;

  String? _creatingId;

  @override
  void initState() {
    super.initState();

    _bookings = AutoCareService.db
        .collection('bookings')
        .where('vehicleId', isEqualTo: widget.vehicleId)
        .snapshots();

    _jobs = AutoCareService.db
        .collection('jobCards')
        .where('vehicleId', isEqualTo: widget.vehicleId)
        .snapshots();
  }

  void _openJob(String jobId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobCardDetailsScreen(
          jobId: jobId,
          registration: widget.registration,
        ),
      ),
    );
  }

  Future<void> _createJob(String bookingId) async {
    if (_creatingId != null) return;

    setState(() => _creatingId = bookingId);

    try {
      await AutoCareService.createJob(bookingId);

      if (!mounted) return;

      _openJob(bookingId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(operationError(error))));
    } finally {
      if (mounted) {
        setState(() => _creatingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.registration} Jobs'),
        actions: [
          IconButton(
            tooltip: 'Billing & Payments',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BillingDashboardScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _bookings,
        builder: (context, bookingSnapshot) {
          if (bookingSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load bookings. Check permissions.'),
            );
          }

          if (!bookingSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = bookingSnapshot.data!.docs.where((doc) {
            return doc.data()['status'] == 'confirmed';
          }).toList();

          bookings.sort((a, b) {
            final first = a.data()['scheduledAt'] as Timestamp;
            final second = b.data()['scheduledAt'] as Timestamp;

            return second.compareTo(first);
          });

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _jobs,
            builder: (context, jobSnapshot) {
              if (jobSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load jobs. Check rules.'),
                );
              }

              if (!jobSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final jobs = {
                for (final doc in jobSnapshot.data!.docs) doc.id: doc.data(),
              };

              if (bookings.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No confirmed bookings yet.\n'
                      'Confirm a booking before creating a Job Card.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  final data = booking.data();
                  final job = jobs[booking.id];

                  final scheduled = (data['scheduledAt'] as Timestamp).toDate();

                  final dateLabel = MaterialLocalizations.of(context)
                      .formatMediumDate(scheduled);

                  final timeLabel = TimeOfDay.fromDateTime(scheduled)
                      .format(context);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            data['serviceType'] as String,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text('$dateLabel • $timeLabel'),

                          const SizedBox(height: 12),

                          Text(
                            job == null
                                ? 'Ready to create a Job Card'
                                : (job['status'] as String)
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),

                          if (job != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Labour: '
                              '${money(job['labourCents'] as int)}',
                            ),
                            Text(
                              'Parts: '
                              '${money((job['partsTotalCents'] as int?) ?? 0)}',
                            ),
                          ],

                          const SizedBox(height: 16),

                          FilledButton.icon(
                            onPressed: _creatingId != null
                                ? null
                                : () {
                                    if (job == null) {
                                      _createJob(booking.id);
                                    } else {
                                      _openJob(booking.id);
                                    }
                                  },
                            icon: const Icon(Icons.assignment_outlined),
                            label: Text(
                              _creatingId == booking.id
                                  ? 'Creating...'
                                  : job == null
                                  ? 'Create Job Card'
                                  : 'View Job Card',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class JobCardDetailsScreen extends StatefulWidget {
  final String jobId;
  final String registration;

  const JobCardDetailsScreen({
    super.key,
    required this.jobId,
    required this.registration,
  });

  @override
  State<JobCardDetailsScreen> createState() => _JobCardDetailsScreenState();
}

class _JobCardDetailsScreenState extends State<JobCardDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _labour = TextEditingController();

  late Future<void> _loaded;
  late Timestamp _revision;

  String _status = 'open';
  String _service = '';

  int _partsTotal = 0;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loaded = _loadJob();
  }

  Future<void> _loadJob() async {
    final snapshot = await AutoCareService.db
        .collection('jobCards')
        .doc(widget.jobId)
        .get();

    final data = snapshot.data();

    if (data == null) {
      throw StateError('Job Card not found.');
    }

    if (!mounted) return;

    _status = data['status'] as String;
    _service = data['serviceType'] as String;
    _partsTotal = (data['partsTotalCents'] as int?) ?? 0;
    _revision = data['updatedAt'] as Timestamp;

    _notes.text = data['notes'] as String;

    final labourCents = data['labourCents'] as int;

    _labour.text =
        '${labourCents ~/ 100}.'
        '${(labourCents % 100).toString().padLeft(2, '0')}';
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      _loaded = _loadJob();
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveJob(String nextStatus) async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }

    final labourCents = parseMoney(_labour.text)!;

    if (nextStatus == 'completed') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Complete This Job?'),
            content: const Text(
              'Labour, notes and parts will be locked. '
              'Check that every used part has been recorded.',
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
                child: const Text('Complete Job'),
              ),
            ],
          );
        },
      );

      if (accepted != true || !mounted) return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      await AutoCareService.saveJob(
        jobId: widget.jobId,
        expectedStatus: _status,
        nextStatus: nextStatus,
        notes: _notes.text.trim(),
        labourCents: labourCents,
        expectedRevision: _revision,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      _message(operationError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openParts() async {
    if (_saving) return;

    if (_status != 'completed') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Open Parts Usage?'),
            content: const Text(
              'If you changed notes or labour, use Save Details first. '
              'Continuing will discard unsaved changes on this screen.',
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
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (accepted != true || !mounted) return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartsUsageScreen(jobId: widget.jobId),
      ),
    );

    _reload();
  }

  Future<void> _openInvoice() async {
    if (_saving) return;

    final total = (parseMoney(_labour.text) ?? 0) + _partsTotal;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create or View Invoice'),
          content: Text(
            'Create the final invoice for labour plus parts: '
            '${money(total)}.\n\n'
            'An existing invoice will be opened without changes.',
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
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted) return;

    setState(() => _saving = true);

    try {
      await AutoCareService.createInvoice(widget.jobId);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InvoiceScreen(jobId: widget.jobId),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _message(operationError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _labour.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Job Card'),
          automaticallyImplyLeading: !_saving,
        ),
        body: FutureBuilder<void>(
          future: _loaded,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unable to load Job Card. '
                        'Check your connection and permissions.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final completed = _status == 'completed';

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.registration,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(_service),

                          const SizedBox(height: 12),

                          Text(
                            _status.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),

                          const SizedBox(height: 24),

                          TextFormField(
                            controller: _notes,
                            enabled: !_saving && !completed,
                            minLines: 4,
                            maxLines: 8,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              labelText: 'Service / technician notes',
                              alignLabelWithHint: true,
                            ),
                          ),

                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _labour,
                            enabled: !_saving && !completed,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Labour charges (LKR)',
                            ),
                            validator: (value) {
                              return parseMoney(value ?? '') == null
                                  ? 'Enter 0–1000000 with up to 2 decimals.'
                                  : null;
                            },
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Parts total: ${money(_partsTotal)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),

                          const SizedBox(height: 14),

                          OutlinedButton.icon(
                            onPressed: _saving ? null : _openParts,
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: Text(
                              completed
                                  ? 'View Parts Used'
                                  : 'Manage Parts Used',
                            ),
                          ),

                          const SizedBox(height: 18),

                          if (!completed) ...[
                            FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _saveJob(_status),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save Details'),
                            ),

                            const SizedBox(height: 12),

                            OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      _saveJob(
                                        _status == 'open'
                                            ? 'in_progress'
                                            : 'completed',
                                      );
                                    },
                              icon: Icon(
                                _status == 'open'
                                    ? Icons.play_arrow
                                    : Icons.check_circle_outline,
                              ),
                              label: Text(
                                _status == 'open'
                                    ? 'Start Job'
                                    : 'Complete Job',
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Completed job: notes, charges '
                              'and usage are locked.',
                            ),
                            const SizedBox(height: 16),

                            FilledButton.icon(
                              onPressed: _saving ? null : _openInvoice,
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Create / View Invoice'),
                            ),
                          ],

                          if (_saving) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
