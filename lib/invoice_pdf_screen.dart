import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'autocare_money.dart';

class InvoicePdfScreen extends StatefulWidget {
  final String jobId;

  const InvoicePdfScreen({super.key, required this.jobId});

  @override
  State<InvoicePdfScreen> createState() => _InvoicePdfScreenState();
}

class _InvoicePdfScreenState extends State<InvoicePdfScreen> {
  late Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _buildPdf();
  }

  String _date(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Date unavailable';
    }

    return _formatDate(timestamp.toDate());
  }

  String _formatDate(DateTime date) {
    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${date.year}-'
        '${two(date.month)}-'
        '${two(date.day)} '
        '${two(date.hour)}:'
        '${two(date.minute)}';
  }

  pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildPdf() async {
    final database = FirebaseFirestore.instance;

    // Fetch current server data before exporting.
    const serverOnly = GetOptions(source: Source.server);

    final invoiceSnapshot = await database
        .collection('invoices')
        .doc(widget.jobId)
        .get(serverOnly);

    final invoice = invoiceSnapshot.data();

    if (invoice == null) {
      throw StateError('Invoice not found.');
    }

    final usageSnapshot = await database
        .collection('partUsage')
        .where('jobId', isEqualTo: widget.jobId)
        .get(serverOnly);

    final paymentSnapshot = await database
        .collection('payments')
        .doc(widget.jobId)
        .get(serverOnly);

    final payment = paymentSnapshot.data();
    final paid = payment != null;

    final usageDocuments = usageSnapshot.docs.toList();

    usageDocuments.sort((a, b) {
      return (a.data()['partName'] as String).compareTo(
        b.data()['partName'] as String,
      );
    });

    final partsTotal = usageDocuments.fold<int>(0, (total, document) {
      return total + (document.data()['totalCents'] as int);
    });

    final labourTotal = invoice['labourCents'] as int;
    final invoicePartsTotal = invoice['partsCents'] as int;
    final grandTotal = invoice['grandTotalCents'] as int;

    if (partsTotal != invoicePartsTotal ||
        labourTotal + invoicePartsTotal != grandTotal) {
      throw StateError(
        'Invoice totals do not match the recorded service details.',
      );
    }

    // Fonts are downloaded on first use and cached by the package.
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final sinhalaFont = await PdfGoogleFonts.notoSansSinhalaRegular();

    final document = pw.Document(
      title: 'AutoCare Invoice AC-${widget.jobId}',
      author: 'AutoCare',
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        fontFallback: [sinhalaFont],
      ),
    );

    final coffee = PdfColor.fromHex('#3C312B');
    final gold = PdfColor.fromHex('#F7B22C');
    final paperAccent = PdfColor.fromHex('#F4EBDD');

    final exportedAt = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 100,

        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Exported: ${_formatDate(exportedAt)}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} '
                    'of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },

        build: (context) {
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: coffee,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AUTOCARE',
                        style: pw.TextStyle(
                          color: gold,
                          fontSize: 27,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Vehicle Service Invoice',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: gold,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      paid ? 'PAID' : 'UNPAID',
                      style: pw.TextStyle(
                        color: coffee,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            pw.Text(
              'Invoice: AC-${widget.jobId}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 6),

            pw.Text(
              'Issued: ${_date(invoice['createdAt'] as Timestamp?)}',
              style: const pw.TextStyle(fontSize: 10),
            ),

            pw.SizedBox(height: 22),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: paperAccent,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BILL TO',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    invoice['customerName'] as String,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Phone: ${invoice['customerPhone']}'),
                  pw.SizedBox(height: 5),
                  pw.Text('Vehicle: ${invoice['registration']}'),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            pw.Text(
              'PARTS USED',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 12),

            if (usageDocuments.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Text('No spare parts were used for this service.'),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Part', 'Qty', 'Unit price', 'Amount'],
                data: usageDocuments.map((document) {
                  final data = document.data();

                  return [
                    data['partName'] as String,
                    '${data['quantity']}',
                    money(data['unitPriceCents'] as int),
                    money(data['totalCents'] as int),
                  ];
                }).toList(),
                headerDecoration: pw.BoxDecoration(color: coffee),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.all(9),
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(0.7),
                  2: const pw.FlexColumnWidth(1.7),
                  3: const pw.FlexColumnWidth(1.7),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),

            pw.SizedBox(height: 22),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 280,
                child: pw.Column(
                  children: [
                    _totalRow('Labour charges', money(labourTotal)),
                    _totalRow('Spare parts', money(invoicePartsTotal)),
                    pw.Divider(color: PdfColors.grey500),
                    pw.Container(
                      color: paperAccent,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: _totalRow('TOTAL', money(grandTotal), bold: true),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 24),

            if (payment != null) ...[
              pw.Text(
                'PAYMENT DETAILS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Method: ${payment['method']}'),
              pw.SizedBox(height: 5),
              pw.Text(
                'Received: '
                '${_date(payment['createdAt'] as Timestamp?)}',
              ),
              if ((payment['reference'] as String).isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text('Reference: ${payment['reference']}'),
              ],
            ],

            pw.SizedBox(height: 24),

            pw.Text(
              'Thank you for choosing AutoCare.',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 6),

            pw.Text(
              'Payment status reflects the records available '
              'at the time of export.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  void _retry() {
    setState(() {
      _pdfFuture = _buildPdf();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filename = 'AutoCare_Invoice_${widget.jobId}.pdf';

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice PDF')),
      body: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;

            final message = error is StateError
                ? '${error.message}'
                : 'Unable to create PDF. '
                      'Check your internet connection and permissions.';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 52),
                    const SizedBox(height: 16),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your invoice PDF...'),
                ],
              ),
            );
          }

          final bytes = snapshot.data!;

          return PdfPreview(
            build: (_) async => bytes,
            pdfFileName: filename,
            initialPageFormat: PdfPageFormat.a4,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            maxPageWidth: 760,
            onError: (context, error) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Unable to display the PDF preview.',
                    textAlign: TextAlign.center,
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
