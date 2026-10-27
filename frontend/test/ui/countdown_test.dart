import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/ui/ui.dart';

import 'test_harness.dart';

void main() {
  group('formatCountdown', () {
    test('drops leading zero units', () {
      expect(formatCountdown(const Duration(seconds: 45)), '45s');
      expect(formatCountdown(const Duration(minutes: 4, seconds: 5)), '4m 5s');
      expect(formatCountdown(const Duration(hours: 1)), '1h 0m 0s');
      expect(
        formatCountdown(
          const Duration(days: 2, hours: 3, minutes: 4, seconds: 5),
        ),
        '2d 3h 4m 5s',
      );
    });

    test('ignores the sign', () {
      expect(formatCountdown(const Duration(seconds: -90)), '1m 30s');
    });
  });

  group('Countdown', () {
    late DateTime now;
    DateTime clock() => now;

    setUp(() => now = DateTime.utc(2026, 10, 27, 12));

    testWidgets('ticks every second', (tester) async {
      await tester.pumpWidget(
        themed(
          Countdown(
            target: now.add(const Duration(hours: 1, minutes: 1, seconds: 5)),
            label: 'Return in',
            clock: clock,
          ),
        ),
      );
      expect(find.text('Return in 1h 1m 5s'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Return in 1h 1m 4s'), findsOneWidget);

      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Return in 1h 0m 59s'), findsOneWidget);
    });

    testWidgets('applies the server clock offset', (tester) async {
      // Server is 30s ahead of the device, so 30s less remains.
      await tester.pumpWidget(
        themed(
          Countdown(
            target: now.add(const Duration(minutes: 2)),
            serverOffset: const Duration(seconds: 30),
            clock: clock,
          ),
        ),
      );
      expect(find.text('1m 30s'), findsOneWidget);
    });

    testWidgets('switches to the overdue style past the target', (
      tester,
    ) async {
      var elapsed = 0;
      await tester.pumpWidget(
        themed(
          Countdown(
            target: now.add(const Duration(seconds: 1)),
            clock: clock,
            onElapsed: () => elapsed++,
          ),
        ),
      );
      expect(find.text('1s'), findsOneWidget);

      now = now.add(const Duration(seconds: 91));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Overdue by 1m 30s'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Overdue by 1m 30s'));
      expect(text.style?.color, AppTheme.light().colorScheme.error);
      expect(elapsed, 1);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(elapsed, 1);
    });
  });

  testWidgets('OtpDisplay shows the code and its expiry', (tester) async {
    var now = DateTime.utc(2026, 10, 27, 12);
    await tester.pumpWidget(
      themed(
        OtpDisplay(
          code: '482913',
          expiresAt: now.add(const Duration(minutes: 5)),
          clock: () => now,
        ),
      ),
    );
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Expires in 5m 0s'), findsOneWidget);

    now = now.add(const Duration(minutes: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Code expired'), findsOneWidget);
  });
}
