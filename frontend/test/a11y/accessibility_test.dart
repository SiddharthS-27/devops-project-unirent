import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_harness.dart';

Future<void> meetsAll(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  for (final screen in keyScreens) {
    group(screen.name, () {
      testWidgets('meets the guidelines (light)', (tester) async {
        final semantics = tester.ensureSemantics();
        await openScreen(tester, screen);
        await eachScreenful(tester, () => meetsAll(tester));
        semantics.dispose();
      });

      testWidgets('meets the guidelines (dark)', (tester) async {
        final semantics = tester.ensureSemantics();
        useDarkTheme(tester);
        await openScreen(tester, screen);
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          Brightness.dark,
        );
        await eachScreenful(tester, () => meetsAll(tester));
        semantics.dispose();
      });

      for (final scale in [1.3, 2.0]) {
        testWidgets('lays out at text scale $scale', (tester) async {
          useTextScale(tester, scale);
          // Overflow errors fail the test with the offending widget.
          await openScreen(tester, screen);
          await eachScreenful(tester, () async {});
        });
      }
    });
  }
}
