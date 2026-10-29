import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/ui/ui.dart';

import 'test_harness.dart';

void main() {
  group('AppButton', () {
    testWidgets('calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        themed(AppButton(label: 'Book now', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Book now'));
      expect(taps, 1);
    });

    testWidgets('is disabled and shows a spinner while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        themed(
          AppButton.destructive(
            label: 'Cancel booking',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  testWidgets('ErrorState retry calls back', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      themed(ErrorState(message: 'No connection', onRetry: () => retries++)),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('ErrorState without onRetry has no button', (tester) async {
    await tester.pumpWidget(themed(const ErrorState()));
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('EmptyState and LoadingState render', (tester) async {
    await tester.pumpWidget(
      themed(const EmptyState(title: 'No bookings yet', message: 'Browse')),
    );
    expect(find.text('No bookings yet'), findsOneWidget);

    await tester.pumpWidget(themed(const LoadingState(message: 'Loading')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('StatusTimeline renders every step', (tester) async {
    await tester.pumpWidget(
      themed(
        const StatusTimeline(
          steps: [
            TimelineStep(title: 'Requested', state: TimelineStepState.done),
            TimelineStep(
              title: 'Pickup',
              subtitle: 'Today, 4:00 PM',
              state: TimelineStepState.current,
            ),
            TimelineStep(title: 'Return', state: TimelineStepState.upcoming),
          ],
        ),
      ),
    );
    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Today, 4:00 PM'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('ChecklistStep shows the action only when available', (
    tester,
  ) async {
    var taps = 0;
    Widget step(ChecklistStepState state) => themed(
      ChecklistStep(
        title: 'Inspect item',
        state: state,
        actionLabel: 'Start',
        onAction: () => taps++,
      ),
    );

    await tester.pumpWidget(step(ChecklistStepState.locked));
    expect(find.text('Start'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.pumpWidget(step(ChecklistStepState.available));
    await tester.tap(find.text('Start'));
    expect(taps, 1);

    await tester.pumpWidget(step(ChecklistStepState.done));
    expect(find.text('Start'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('AppCard is tappable when onTap is set', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(AppCard(onTap: () => taps++, child: const Text('Card'))),
    );
    await tester.tap(find.text('Card'));
    expect(taps, 1);
  });

  testWidgets('AppTextField shows label and error', (tester) async {
    await tester.pumpWidget(
      themed(
        const SizedBox(
          width: 300,
          child: AppTextField(label: 'Phone', errorText: 'Invalid number'),
        ),
      ),
    );
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Invalid number'), findsOneWidget);
  });
}
