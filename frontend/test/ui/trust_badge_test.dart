import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/ui/ui.dart';

import 'test_harness.dart';

Color? badgeColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(TrustBadge),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  test('trustBandFor uses 80 and 50 as band boundaries', () {
    expect(trustBandFor(100), TrustBand.high);
    expect(trustBandFor(80), TrustBand.high);
    expect(trustBandFor(79), TrustBand.medium);
    expect(trustBandFor(50), TrustBand.medium);
    expect(trustBandFor(49), TrustBand.low);
    expect(trustBandFor(0), TrustBand.low);
  });

  final cases = <int, Color>{
    92: StatusColors.light.successContainer,
    65: StatusColors.light.warningContainer,
    20: StatusColors.light.dangerContainer,
  };
  cases.forEach((score, colour) {
    testWidgets('score $score shows the number in its band colour', (
      tester,
    ) async {
      await tester.pumpWidget(themed(TrustBadge(score: score)));
      expect(find.text('$score'), findsOneWidget);
      expect(badgeColor(tester), colour);
      expect(
        find.bySemanticsLabel('Trust score $score out of 100'),
        findsOneWidget,
      );
    });
  });

  testWidgets('null score shows a New badge', (tester) async {
    await tester.pumpWidget(themed(const TrustBadge(score: null)));
    expect(find.text('New'), findsOneWidget);
    expect(badgeColor(tester), AppTheme.light().colorScheme.secondaryContainer);
    expect(
      find.bySemanticsLabel('New member, no trust score yet'),
      findsOneWidget,
    );
  });

  testWidgets('out-of-range scores are clamped', (tester) async {
    await tester.pumpWidget(themed(const TrustBadge(score: 140)));
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('uses dark status colours in the dark theme', (tester) async {
    await tester.pumpWidget(
      themed(const TrustBadge(score: 90), theme: AppTheme.dark()),
    );
    expect(badgeColor(tester), StatusColors.dark.successContainer);
  });
}
