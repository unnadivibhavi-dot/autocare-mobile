import 'package:cloud_firestore/cloud_firestore.dart';

// One appointment slot.
class BookingSlot {
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final bool isBooked;
  final bool isPast;

  const BookingSlot({
    required this.startAtUtc,
    required this.endAtUtc,
    required this.isBooked,
    required this.isPast,
  });

  bool get isAvailable => !isBooked && !isPast;

  String get label {
    final localStart = startAtUtc.add(BookingSlotService.sriLankaOffset);

    final localEnd = endAtUtc.add(BookingSlotService.sriLankaOffset);

    return '${BookingSlotService.formatClock(localStart)}'
        ' – ${BookingSlotService.formatClock(localEnd)}';
  }

  String get statusLabel {
    if (isPast) return 'Past';
    if (isBooked) return 'Booked';

    return 'Available';
  }
}

class BookingSlotService {
  static final _database = FirebaseFirestore.instance;

  // Sri Lanka uses UTC +05:30.
  static const sriLankaOffset = Duration(hours: 5, minutes: 30);

  static const openingHour = 9;
  static const closingHour = 17;

  static const slotDuration = Duration(hours: 1);

  // Current date/time represented using Sri Lankan clock values.
  static DateTime nowInSriLanka() {
    return DateTime.now().toUtc().add(sriLankaOffset);
  }

  // Date carrier for Flutter's date picker.
  static DateTime todayInSriLanka() {
    final now = nowInSriLanka();

    return DateTime(now.year, now.month, now.day);
  }

  static String formatClock(DateTime clockTime) {
    final suffix = clockTime.hour >= 12 ? 'PM' : 'AM';

    var hour = clockTime.hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    final minute = clockTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute $suffix';
  }

  // Convert a Sri Lankan calendar date/hour into a UTC instant.
  static DateTime _slotStartUtc(DateTime selectedDate, int hour) {
    return DateTime.utc(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      hour,
    ).subtract(sriLankaOffset);
  }

  // Deterministic identifier for later slot reservations.
  static String reservationId(DateTime startAtUtc) {
    return 'slot_${startAtUtc.toUtc().millisecondsSinceEpoch}';
  }

  static bool isValidSlotStart(DateTime start) {
    final local = start.toUtc().add(sriLankaOffset);

    return local.hour >= openingHour &&
        local.hour < closingHour &&
        local.minute == 0 &&
        local.second == 0 &&
        local.millisecond == 0 &&
        local.microsecond == 0;
  }

  static bool _overlaps({
    required DateTime firstStart,
    required DateTime firstEnd,
    required DateTime secondStart,
    required DateTime secondEnd,
  }) {
    // Back-to-back appointments are allowed.
    // Example: 9–10 and 10–11 do not overlap.
    return firstStart.isBefore(secondEnd) && secondStart.isBefore(firstEnd);
  }

  static Future<List<BookingSlot>> loadSlots(DateTime selectedDate) async {
    // Read current server data, rather than relying on cached bookings.
    final snapshot = await _database
        .collection('bookings')
        .where('status', isEqualTo: 'confirmed')
        .get(const GetOptions(source: Source.server));

    final confirmedStarts = <DateTime>[];

    for (final document in snapshot.docs) {
      final data = document.data();
      final scheduledAt = data['scheduledAt'];

      if (scheduledAt is Timestamp) {
        confirmedStarts.add(scheduledAt.toDate().toUtc());
      }
    }

    final nowUtc = DateTime.now().toUtc();
    final slots = <BookingSlot>[];

    for (var hour = openingHour; hour < closingHour; hour++) {
      final start = _slotStartUtc(selectedDate, hour);

      final end = start.add(slotDuration);

      final booked = confirmedStarts.any((bookingStart) {
        // Existing bookings do not contain service duration.
        // For this first version, treat each as one hour.
        final bookingEnd = bookingStart.add(slotDuration);

        return _overlaps(
          firstStart: start,
          firstEnd: end,
          secondStart: bookingStart,
          secondEnd: bookingEnd,
        );
      });

      slots.add(
        BookingSlot(
          startAtUtc: start,
          endAtUtc: end,
          isBooked: booked,
          isPast: !start.isAfter(nowUtc),
        ),
      );
    }

    return slots;
  }
}
