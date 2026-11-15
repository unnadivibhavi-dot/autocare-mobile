// Convert an LKR amount into integer cents.
// Example: 2500.50 becomes 250050.
int? parseMoney(String value) {
  final text = value.trim();

  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }

  final parts = text.split('.');

  final wholeAmount = int.parse(parts[0]);

  final decimalAmount = parts.length == 2
      ? int.parse(parts[1].padRight(2, '0'))
      : 0;

  final cents = wholeAmount * 100 + decimalAmount;

  // Maximum supported amount: LKR 1,000,000.00
  if (cents > 100000000) {
    return null;
  }

  return cents;
}

// Display integer cents as an LKR amount.
// Example: 250050 becomes LKR 2500.50.
String money(int cents) {
  final wholeAmount = cents ~/ 100;

  final decimalAmount = (cents % 100).toString().padLeft(2, '0');

  return 'LKR $wholeAmount.$decimalAmount';
}
