import 'package:cloud_firestore/cloud_firestore.dart';

class AutoCareService {
  static final db = FirebaseFirestore.instance;

  // Create one Job Card per confirmed booking.
  static Future<void> createJob(String bookingId) async {
    final jobRef = db.collection('jobCards').doc(bookingId);

    final bookingRef = db.collection('bookings').doc(bookingId);

    await db.runTransaction<void>((transaction) async {
      final job = await transaction.get(jobRef);
      final booking = await transaction.get(bookingRef);

      if (job.exists) return;

      final data = booking.data();

      if (data == null || data['status'] != 'confirmed') {
        throw StateError('Confirm this booking first.');
      }

      transaction.set(jobRef, {
        'bookingId': bookingId,
        'vehicleId': data['vehicleId'],
        'serviceType': data['serviceType'],
        'notes': data['notes'] ?? '',
        'labourCents': 0,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Save job details or move the job to its next stage.
  static Future<void> saveJob({
    required String jobId,
    required String expectedStatus,
    required String nextStatus,
    required String notes,
    required int labourCents,
    required Timestamp expectedRevision,
  }) async {
    final reference = db.collection('jobCards').doc(jobId);

    await db.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (data == null ||
          data['status'] != expectedStatus ||
          data['updatedAt'] != expectedRevision) {
        throw StateError(
          'This job changed. Reopen it to load the latest details.',
        );
      }

      final allowed =
          (expectedStatus == 'open' &&
              ['open', 'in_progress'].contains(nextStatus)) ||
          (expectedStatus == 'in_progress' &&
              ['in_progress', 'completed'].contains(nextStatus));

      if (!allowed) {
        throw StateError('Completed jobs cannot be edited.');
      }

      transaction.update(reference, {
        'notes': notes,
        'labourCents': labourCents,
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Record part usage, deduct stock and update the job total together.
  static Future<void> usePart({
    required String usageId,
    required String jobId,
    required String partId,
    required int quantity,
    required int expectedUnitPrice,
  }) async {
    if (quantity < 1 || quantity > 10000) {
      throw StateError('Quantity must be between 1 and 10000.');
    }

    final usageRef = db.collection('partUsage').doc(usageId);
    final jobRef = db.collection('jobCards').doc(jobId);
    final partRef = db.collection('spareParts').doc(partId);

    await db.runTransaction<void>((transaction) async {
      final existingUsage = await transaction.get(usageRef);
      final job = await transaction.get(jobRef);
      final part = await transaction.get(partRef);

      // A retry with the same usage ID cannot deduct stock twice.
      if (existingUsage.exists) return;

      final jobData = job.data();
      final partData = part.data();

      if (jobData == null ||
          !['open', 'in_progress'].contains(jobData['status'])) {
        throw StateError('Parts can only be added to an open or active job.');
      }

      if (partData == null) {
        throw StateError('This part no longer exists.');
      }

      if (partData['unitPriceCents'] != expectedUnitPrice) {
        throw StateError(
          'The part price changed. Close this form and select it again.',
        );
      }

      final availableStock = partData['stock'] as int;

      if (availableStock < quantity) {
        throw StateError('Only $availableStock units are available.');
      }

      final unitPrice = partData['unitPriceCents'] as int;
      final usageTotal = unitPrice * quantity;

      final previousTotal = (jobData['partsTotalCents'] as int?) ?? 0;

      if (usageTotal > 10000000000 ||
          previousTotal + usageTotal > 10000000000) {
        throw StateError('The parts total exceeds the supported limit.');
      }

      transaction.set(usageRef, {
        'jobId': jobId,
        'partId': partId,
        'partName': partData['name'],
        'quantity': quantity,
        'unitPriceCents': unitPrice,
        'totalCents': usageTotal,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(partRef, {
        'stock': availableStock - quantity,
        'lastUsageId': usageId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(jobRef, {
        'partsTotalCents': previousTotal + usageTotal,
        'lastUsageId': usageId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Create one immutable invoice per completed job.
  static Future<void> createInvoice(String jobId) async {
    final invoiceRef = db.collection('invoices').doc(jobId);
    final jobRef = db.collection('jobCards').doc(jobId);

    await db.runTransaction<void>((transaction) async {
      final invoice = await transaction.get(invoiceRef);
      final job = await transaction.get(jobRef);

      if (invoice.exists) return;

      final jobData = job.data();

      if (jobData == null || jobData['status'] != 'completed') {
        throw StateError('Complete this job before creating its invoice.');
      }

      final vehicle = await transaction.get(
        db.collection('vehicles').doc(jobData['vehicleId'] as String),
      );

      final vehicleData = vehicle.data();

      if (vehicleData == null) {
        throw StateError('Vehicle record not found.');
      }

      final customer = await transaction.get(
        db.collection('customers').doc(vehicleData['customerId'] as String),
      );

      final customerData = customer.data();

      if (customerData == null) {
        throw StateError('Customer record not found.');
      }

      final labourTotal = jobData['labourCents'] as int;

      final partsTotal = (jobData['partsTotalCents'] as int?) ?? 0;

      transaction.set(invoiceRef, {
        'jobId': jobId,
        'vehicleId': jobData['vehicleId'],
        'registration': vehicleData['registration'],
        'customerId': vehicleData['customerId'],
        'customerName': customerData['name'],
        'customerPhone': customerData['phone'],
        'labourCents': labourTotal,
        'partsCents': partsTotal,
        'grandTotalCents': labourTotal + partsTotal,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Record one full payment per invoice.
  // This records money already received; it does not charge a card.
  static Future<void> recordPayment({
    required String invoiceId,
    required String method,
    required String reference,
  }) async {
    final paymentRef = db.collection('payments').doc(invoiceId);
    final invoiceRef = db.collection('invoices').doc(invoiceId);

    await db.runTransaction<void>((transaction) async {
      final payment = await transaction.get(paymentRef);
      final invoice = await transaction.get(invoiceRef);

      if (payment.exists) {
        throw StateError('This invoice is already paid.');
      }

      final data = invoice.data();

      if (data == null) {
        throw StateError('Invoice not found.');
      }

      transaction.set(paymentRef, {
        'invoiceId': invoiceId,
        'amountCents': data['grandTotalCents'],
        'method': method,
        'reference': reference,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

// Convert errors into messages shown in the app.
String operationError(Object error) {
  if (error is StateError) {
    return '${error.message}';
  }

  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Permission denied. Publish the supplied rules '
          'using your account UID.';
    }

    if (error.code == 'unavailable') {
      return 'Check your internet connection and retry.';
    }

    return 'Operation failed (${error.code}). Please retry.';
  }

  return 'Unable to complete the operation. Please try again.';
}
