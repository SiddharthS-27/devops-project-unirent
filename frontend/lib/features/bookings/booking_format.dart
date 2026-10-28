import '../../api/api.dart';
import '../../ui/ui.dart';

/// "3 hours", "1 day", "2 days 5 hours".
String durationLabel(int hours) {
  final days = hours ~/ 24;
  final rest = hours % 24;
  String unit(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
  return [
    if (days > 0) unit(days, 'day'),
    if (rest > 0 || days == 0) unit(rest, 'hour'),
  ].join(' ');
}

/// "Tue, 28 Oct, 10:00 AM – 6:00 PM" or across days, in IST.
String periodLabel(DateTime start, DateTime end) {
  final s = toIst(start);
  final e = toIst(end);
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  final from = '${formatIstShortDate(start)}, ${formatIstTime(start)}';
  final to = sameDay
      ? formatIstTime(end)
      : '${formatIstShortDate(end)}, ${formatIstTime(end)}';
  return '$from – $to';
}

/// The period of a rental, or "Purchase" for a sale.
String bookingWhen(TradeKind kind, DateTime? start, DateTime? end) =>
    kind == TradeKind.sale || start == null || end == null
    ? 'Purchase'
    : periodLabel(start, end);

/// The start of the IST hour [plusHours] after the current one.
DateTime nextIstHour(DateTime now, {int plusHours = 1}) {
  final ist = toIst(now);
  return fromIst(ist.year, ist.month, ist.day, ist.hour + plusHours);
}
