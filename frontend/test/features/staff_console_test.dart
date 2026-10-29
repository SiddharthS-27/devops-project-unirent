import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_help_handlers.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/staff/staff_tab.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const karan = 'karan@college.edu';
const moderator = 'moderator@unirent.in';

Future<TestApp> asModerator(WidgetTester tester, MockServer server) {
  server.db.accountByEmail(moderator)!.mustChangePassword = false;
  return pumpSignedIn(tester, moderator, server: server);
}

Future<void> openTab(TestApp app, StaffTab tab) async {
  app.router.go(tab.path);
  await app.tester.pumpAndSettle();
}

Future<void> confirm(TestApp app, String label) => app.tap(
  find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  ),
);

/// Asha asked for help a while ago.
MockSupportThread ashaThread(MockServer server) {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final ashaId = db.accountByEmail(asha)!.id;
  final t = MockSupportThread(
    id: 'thread-1',
    accountId: ashaId,
    subject: 'My refund has not arrived',
    createdAt: now.subtract(const Duration(hours: 1)),
  );
  t.messages.add(
    MockSupportMessage(
      id: 'm-1',
      author: MessageAuthor.user,
      authorId: ashaId,
      body: 'My refund has not arrived',
      at: t.createdAt,
    ),
  );
  return db.supportThreads[t.id] = t;
}

void main() {
  testWidgets('support: reply in the same chat, then close it', (tester) async {
    final server = MockServer();
    final t = ashaThread(server);
    final app = await asModerator(tester, server);
    await openTab(app, StaffTab.support);
    expect(find.text('My refund has not arrived'), findsOneWidget);
    expect(find.text('Needs reply'), findsOneWidget);

    await app.tapText('My refund has not arrived');
    expect(app.location, Routes.staffThread(t.id));
    expect(find.textContaining('Asha Verma'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextField, 'Reply to the student'),
      'It was sent this morning.',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('It was sent this morning.'), findsOneWidget);
    expect(t.messages.last.author, MessageAuthor.moderator);
    expect(t.unanswered, isFalse);

    await app.tap(find.byTooltip('Close conversation'));
    await confirm(app, 'Close conversation');
    expect(find.text('This conversation is closed.'), findsOneWidget);
    expect(t.status, ThreadStatus.closed);
    expect(
      find.widgetWithText(TextField, 'Reply to the student'),
      findsNothing,
    );

    await app.tap(find.byType(BackButton));
    expect(find.text('No open conversations'), findsOneWidget);
    await app.tapText('Closed');
    expect(find.text('My refund has not arrived'), findsOneWidget);
  });

  testWidgets('escalations show who to visit; risk flags list students', (
    tester,
  ) async {
    final server = MockServer();
    final now = DateTime.now().toUtc();
    // Karan has Asha's bike and is three hours late.
    server.db.bookings['00000000-0000-4000-d000-000000000001']!
      ..status = BookingStatus.active
      ..startAt = now.subtract(const Duration(days: 1))
      ..endAt = now.subtract(const Duration(hours: 3))
      ..pickupCompletedAt = now.subtract(const Duration(days: 1));
    server.db.accountByEmail(karan)!.renterScore = 20;

    final app = await asModerator(tester, server);
    await openTab(app, StaffTab.escalations);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Hercules 21-gear mountain bike'), findsOneWidget);
    expect(find.text('Karan Mehta (renter)'), findsOneWidget);
    expect(find.textContaining('Narmada Hostel, room C-12'), findsOneWidget);
    expect(find.byTooltip('Call Karan Mehta'), findsOneWidget);
    expect(find.text('Asha Verma (owner)'), findsOneWidget);

    await app.tapText('Risk flags');
    expect(find.text('Trust score 20'), findsOneWidget);
    await app.tapText('Karan Mehta');
    expect(app.location, Routes.staffUser(server.db.accountByEmail(karan)!.id));
    expect(find.text('Trust score 20'), findsOneWidget);
    expect(find.text('Roll number 22XX002'), findsOneWidget);
  });

  testWidgets('users: search, suspend with a reason, restore, penalise', (
    tester,
  ) async {
    final server = MockServer();
    final karanAccount = server.db.accountByEmail(karan)!;
    final app = await asModerator(tester, server);
    await openTab(app, StaffTab.users);
    expect(find.text('Asha Verma'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'karan');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Asha Verma'), findsNothing);
    await app.tapText('Karan Mehta');

    await app.tapText('Suspend');
    await confirm(app, 'Suspend');
    expect(find.text('Give a reason (at least 3 characters)'), findsOneWidget);
    await app.enterField('Reason', 'Three late returns this month');
    await confirm(app, 'Suspend');
    expect(find.text('Account suspended.'), findsOneWidget);
    expect(karanAccount.status, 'suspended');
    expect(find.widgetWithText(Chip, 'Suspended'), findsOneWidget);

    await app.tapText('Restore account');
    await app.enterField('Reason', 'Talked it through');
    await confirm(app, 'Restore');
    expect(karanAccount.status, 'active');
    expect(find.text('Suspend'), findsOneWidget);

    final before = karanAccount.renterScore!;
    await app.tapText('Trust penalty');
    await app.enterField('Points', '8');
    await app.enterField('Reason', 'Rude to the owner');
    await confirm(app, 'Apply');
    expect(find.text('8 points off renter trust'), findsOneWidget);
    expect(karanAccount.renterScore, before - 8);
  });

  testWidgets('listings: remove one with a reason', (tester) async {
    final server = MockServer();
    final app = await asModerator(tester, server);
    await openTab(app, StaffTab.listings);
    const title = 'GoPro Hero 9 action camera';
    expect(find.text(title), findsOneWidget);

    await app.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, title),
        matching: find.text('Remove'),
      ),
    );
    await app.enterField('Reason', 'Counterfeit item');
    await confirm(app, 'Remove');
    expect(find.text('Listing removed.'), findsOneWidget);
    final listing = server.db.listings.values.firstWhere(
      (l) => l.title == title,
    );
    expect(listing.status, ListingStatus.removed);
    expect(listing.removedReason, 'Counterfeit item');

    await app.tap(find.widgetWithText(ChoiceChip, 'Removed'));
    expect(find.text(title), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, title),
        matching: find.text('Remove'),
      ),
      findsNothing,
    );
  });
}
