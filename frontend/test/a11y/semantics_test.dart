import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/features/bookings/widgets/ist_date_time_field.dart';
import 'package:unirent/ui/ui.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  ),
);

SemanticsData dataOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

void main() {
  testWidgets('a one-time code is read digit by digit', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const OtpDisplay(code: '482913'));
    expect(find.bySemanticsLabel('Code 4 8 2 9 1 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('code entry is one labelled text field', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const OtpEntry());
    final data = dataOf(tester, find.bySemanticsLabel('One-time code'));
    expect(data.flagsCollection.isTextField, isTrue);
    semantics.dispose();
  });

  testWidgets('code entry fits its boxes at large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = TextEditingController(text: '123456');
    addTearDown(controller.dispose);
    await pump(tester, OtpEntry(controller: controller));
    expect(tester.takeException(), isNull);
  });

  test('countdowns are spoken with whole words', () {
    expect(
      spokenCountdown(const Duration(minutes: 4, seconds: 5)),
      '4 minutes 5 seconds',
    );
    expect(spokenCountdown(const Duration(seconds: 1)), '1 second');
    expect(
      spokenCountdown(const Duration(days: 1, hours: 2, seconds: 9)),
      '1 day 2 hours',
    );
    expect(spokenCountdown(Duration.zero), '0 seconds');
  });

  testWidgets('a countdown reads its units in full', (tester) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.utc(2026, 10, 27, 12);
    await pump(
      tester,
      Countdown(
        target: now.add(const Duration(minutes: 4, seconds: 5)),
        clock: () => now,
        label: 'Expires in',
      ),
    );
    expect(find.text('Expires in 4m 5s'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Expires in 4 minutes 5 seconds'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('ratings and trust read as sentences', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      const Column(
        children: [
          StarRatingDisplay(rating: 4.46, count: 3),
          TrustBadge(score: 82),
          TrustBadge(score: null),
        ],
      ),
    );
    expect(
      find.bySemanticsLabel('Rated 4.5 out of 5 from 3 ratings'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Trust score 82 out of 100'), findsOneWidget);
    expect(
      find.bySemanticsLabel('New member, no trust score yet'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a star input says its value and labels each star', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    int? picked;
    await pump(
      tester,
      StarRatingInput(
        label: 'Communication',
        value: 3,
        onChanged: (v) => picked = v,
      ),
    );
    final group = dataOf(tester, find.bySemanticsLabel('Communication'));
    expect(group.value, '3 of 5 stars');
    await tester.tap(find.byTooltip('4 stars'));
    expect(picked, 4);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('a date field can be activated by a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pump(
      tester,
      IstDateTimeField(
        label: 'Start',
        value: DateTime.utc(2026, 10, 27, 6),
        onTap: () => taps++,
      ),
    );
    final finder = find.bySemanticsLabel(RegExp('^Start, '));
    expect(dataOf(tester, finder).hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel(RegExp('^Start, ')));
    await tester.pump();
    expect(taps, 1);
    semantics.dispose();
  });
}
