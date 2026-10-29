import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/ui/ui.dart';

import 'test_harness.dart';

void main() {
  group('StarRatingInput', () {
    testWidgets('reports the tapped star and fills up to the value', (
      tester,
    ) async {
      int? value;
      await tester.pumpWidget(
        themed(
          StatefulBuilder(
            builder: (context, setState) => StarRatingInput(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));

      await tester.tap(find.byTooltip('4 stars'));
      await tester.pump();

      expect(value, 4);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('1 star'));
      await tester.pump();
      expect(value, 1);
    });

    testWidgets('exposes accessible labels and touch targets', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themed(StarRatingInput(value: 3, onChanged: (_) {})),
      );

      expect(find.bySemanticsLabel(RegExp('Rating')), findsOneWidget);
      final node = tester.getSemantics(find.byType(StarRatingInput));
      expect(node.value, '3 of 5 stars');
      for (var star = 1; star <= 5; star++) {
        expect(find.byTooltip(star == 1 ? '1 star' : '$star stars'), findsOne);
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('is disabled when onChanged is null', (tester) async {
      await tester.pumpWidget(
        themed(const StarRatingInput(value: 2, onChanged: null)),
      );
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
      expect(buttons.every((b) => b.onPressed == null), isTrue);
    });
  });

  testWidgets('StarRatingDisplay rounds to half stars', (tester) async {
    await tester.pumpWidget(
      themed(const StarRatingDisplay(rating: 3.7, count: 12)),
    );
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    expect(find.text('3.5 (12)'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Rated 3.5 out of 5 from 12 ratings'),
      findsOneWidget,
    );
  });
}
