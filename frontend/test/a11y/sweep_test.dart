import 'package:flutter_test/flutter_test.dart';

import 'a11y_harness.dart';

/// A lighter pass over the remaining screens: tap targets, labels and
/// contrast in both themes, and layout at the largest text scale.
void main() {
  for (final screen in otherScreens) {
    group(screen.name, () {
      for (final dark in [false, true]) {
        testWidgets('meets the guidelines (${dark ? 'dark' : 'light'})', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          if (dark) useDarkTheme(tester);
          await openScreen(tester, screen);
          await eachScreenful(tester, () async {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          });
          semantics.dispose();
        });
      }

      testWidgets('lays out at text scale 2.0', (tester) async {
        useTextScale(tester, 2);
        await openScreen(tester, screen);
        await eachScreenful(tester, () async {});
      });
    });
  }
}
