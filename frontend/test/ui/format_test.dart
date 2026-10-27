import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/ui/ui.dart';

void main() {
  group('formatMoney', () {
    test('omits decimals for whole rupees', () {
      expect(formatMoney(0), '₹0');
      expect(formatMoney(100), '₹1');
      expect(formatMoney(123400), '₹1,234');
    });

    test('shows two decimals when there are paise', () {
      expect(formatMoney(1250), '₹12.50');
      expect(formatMoney(5), '₹0.05');
      expect(formatMoney(123456), '₹1,234.56');
    });

    test('uses Indian digit grouping', () {
      expect(formatMoney(12345600), '₹1,23,456');
      expect(formatMoney(1234567800), '₹1,23,45,678');
    });

    test('handles negative amounts', () {
      expect(formatMoney(-1250), '-₹12.50');
      expect(formatMoney(-123400), '-₹1,234');
    });
  });

  group('IST formatting', () {
    // 2026-10-27 09:35 UTC is 15:05 IST.
    final instant = DateTime.utc(2026, 10, 27, 9, 35);

    test('formats date, time and both in IST', () {
      expect(formatIstDate(instant), '27 Oct 2026');
      expect(formatIstShortDate(instant), 'Tue, 27 Oct');
      expect(formatIstTime(instant), '3:05 PM');
      expect(formatIstDateTime(instant), '27 Oct 2026, 3:05 PM');
    });

    test('rolls over the date at IST midnight, not UTC midnight', () {
      final lateUtc = DateTime.utc(2026, 10, 27, 19, 0);
      expect(formatIstDate(lateUtc), '28 Oct 2026');
      expect(formatIstTime(lateUtc), '12:30 AM');
    });

    test('is independent of the instant being local or UTC', () {
      expect(formatIstDateTime(instant.toLocal()), formatIstDateTime(instant));
    });

    test('fromIst is the inverse of IST wall-clock formatting', () {
      final t = fromIst(2026, 10, 27, 15, 5);
      expect(t, instant);
      expect(toIst(t).hour, 15);
    });
  });
}
