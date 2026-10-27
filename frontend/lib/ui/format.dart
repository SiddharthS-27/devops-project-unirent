import 'package:intl/intl.dart';

/// India Standard Time offset. IST has no daylight saving, so a fixed offset
/// is exact and avoids a timezone database dependency.
const Duration istOffset = Duration(hours: 5, minutes: 30);

final NumberFormat _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Formats an amount in integer paise as rupees with Indian digit grouping.
///
/// Whole-rupee amounts omit the decimals: `123400` → `₹1,234`,
/// `1250` → `₹12.50`, `1234567800` → `₹1,23,45,678`.
String formatMoney(int paise) {
  final abs = paise.abs();
  final rupees = _rupees.format(abs ~/ 100);
  final remainder = abs % 100;
  final fraction = remainder == 0
      ? ''
      : '.${remainder.toString().padLeft(2, '0')}';
  return '${paise < 0 ? '-' : ''}$rupees$fraction';
}

/// Converts an instant to IST wall-clock time.
///
/// The result is a UTC-flagged [DateTime] whose fields (hour, day, ...) read
/// as IST; use it only for display, never for arithmetic against real
/// instants.
DateTime toIst(DateTime instant) => instant.toUtc().add(istOffset);

/// The instant corresponding to an IST wall-clock time.
DateTime fromIst(
  int year, [
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
  int second = 0,
]) {
  return DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
  ).subtract(istOffset);
}

final DateFormat _date = DateFormat('d MMM yyyy', 'en_US');
final DateFormat _shortDate = DateFormat('EEE, d MMM', 'en_US');
final DateFormat _time = DateFormat('h:mm a', 'en_US');

/// `27 Oct 2026`, in IST.
String formatIstDate(DateTime instant) => _date.format(toIst(instant));

/// `Tue, 27 Oct`, in IST.
String formatIstShortDate(DateTime instant) =>
    _shortDate.format(toIst(instant));

/// `3:05 PM`, in IST.
String formatIstTime(DateTime instant) => _time.format(toIst(instant));

/// `27 Oct 2026, 3:05 PM`, in IST.
String formatIstDateTime(DateTime instant) =>
    '${formatIstDate(instant)}, ${formatIstTime(instant)}';
