import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/ui/ui.dart';

import 'test_harness.dart';

void main() {
  testWidgets('fills boxes and completes after six digits', (tester) async {
    final changes = <String>[];
    String? completed;
    await tester.pumpWidget(
      themed(
        OtpEntry(onChanged: changes.add, onCompleted: (v) => completed = v),
      ),
    );

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(completed, isNull);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
    expect(completed, '123456');
    expect(changes.last, '123456');
  });

  testWidgets('accepts digits only and at most six', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(themed(OtpEntry(controller: controller)));

    await tester.enterText(find.byType(TextField), '12ab34');
    expect(controller.text, '1234');

    await tester.enterText(find.byType(TextField), '123456789');
    expect(controller.text, '123456');
  });

  testWidgets('shows the error text', (tester) async {
    await tester.pumpWidget(
      themed(const OtpEntry(errorText: 'Incorrect code')),
    );
    expect(find.text('Incorrect code'), findsOneWidget);
  });

  testWidgets('has an accessible label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themed(const OtpEntry()));
    expect(find.bySemanticsLabel('One-time code'), findsOneWidget);
    handle.dispose();
  });
}
