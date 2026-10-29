import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_help_handlers.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';

import '../helpers/booking_helpers.dart';
import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const bookingId = '00000000-0000-4000-d000-000000000001';

Future<void> ask(TestApp app, String question) async {
  await app.tester.enterText(
    find.widgetWithText(TextField, 'Ask a question'),
    question,
  );
  await send(app);
}

/// Taps Send without `ensureVisible`, which would swipe the Help tabs.
Future<void> send(TestApp app) async {
  await app.tester.tap(find.byTooltip('Send'));
  await app.tester.pumpAndSettle();
}

MockSupportThread onlyThread(MockServer server) =>
    server.db.supportThreads.values.single;

void main() {
  testWidgets('FAQs are grouped by topic with the late-fee rule filled in', (
    tester,
  ) async {
    final app = await as(tester, MockServer(), asha, location: Routes.help);
    await app.tapText('FAQs');

    expect(find.text('Booking and pickup'), findsOneWidget);
    expect(find.text('Fees'), findsOneWidget);
    await app.tapText('What is the late fee?');
    expect(find.textContaining('-minute grace period'), findsOneWidget);
    expect(find.textContaining('{late_fee_rule}'), findsNothing);
  });

  testWidgets('the bot answers from the FAQs, or falls back with actions', (
    tester,
  ) async {
    final app = await as(tester, MockServer(), asha, location: Routes.help);

    await ask(app, 'How do I rent an item?');
    expect(find.text('How do I rent an item?'), findsOneWidget);
    expect(find.textContaining('tap Request to rent'), findsOneWidget);

    await ask(app, 'What is the weather like on campus today?');
    expect(find.text(mockChatFallback), findsOneWidget);
    expect(find.text('See FAQs'), findsOneWidget);
    expect(find.text('Talk to a moderator'), findsOneWidget);

    await app.tapText('See FAQs');
    expect(find.text('How does pickup work?'), findsOneWidget);
  });

  testWidgets('handoff opens a conversation with the chat; replies arrive in '
      'the same thread', (tester) async {
    final server = MockServer();
    final push = FakePushService();
    final app = await as(
      tester,
      server,
      asha,
      push: push,
      location: Routes.helpFor(bookingId: bookingId),
    );
    await ask(app, 'Can you check my refund for the bike?');
    await app.tapText('Talk to a moderator');

    await app.tapText('Send to a moderator');
    expect(
      find.text('Tell the moderator what you need help with.'),
      findsOneWidget,
    );
    await app.enterField(
      'What do you need help with?',
      'My refund has not arrived yet',
    );
    await app.tapText('Send to a moderator');

    final thread = onlyThread(server);
    expect(app.location, Routes.helpThread(thread.id));
    expect(thread.bookingId, bookingId);
    expect(thread.subject, 'My refund has not arrived yet');
    expect(
      [for (final m in thread.messages) m.author],
      [MessageAuthor.user, MessageAuthor.bot, MessageAuthor.user],
    );
    expect(find.text('Can you check my refund for the bike?'), findsOneWidget);
    expect(find.text(thread.messages[1].body), findsOneWidget);
    expect(find.text('My refund has not arrived yet'), findsWidgets);
    expect(find.textContaining('A moderator will reply here'), findsOneWidget);

    // A moderator replies; the push refreshes the open thread.
    mockStaffReply(
      server.db,
      thread,
      server.db.accountByEmail('moderator@unirent.in')!,
      'It was sent this morning, check your bank app.',
    );
    push.receivedPushes.add(Uri.parse('unirent://help/threads/${thread.id}'));
    await tester.pumpAndSettle();
    expect(
      find.text('It was sent this morning, check your bank app.'),
      findsOneWidget,
    );
    expect(find.textContaining('Moderator'), findsWidgets);
    expect(find.textContaining('A moderator will reply here'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Reply to the moderator'),
      'Got it, thanks!',
    );
    await send(app);
    expect(find.text('Got it, thanks!'), findsOneWidget);
    expect(thread.messages.last.body, 'Got it, thanks!');
    expect(thread.unanswered, isTrue);

    // Back in Help, the conversation is listed.
    await app.tap(find.byType(BackButton));
    expect(find.text('My refund has not arrived yet'), findsOneWidget);
    expect(find.textContaining('Waiting for a moderator'), findsOneWidget);
  });

  testWidgets('a closed conversation can no longer be answered', (
    tester,
  ) async {
    final server = MockServer();
    final app = await as(tester, server, asha, location: Routes.help);
    await app.tapText('Your chats');
    expect(find.text('No conversations yet'), findsOneWidget);
    await app.tap(find.widgetWithText(FilledButton, 'Talk to a moderator'));
    await app.enterField('What do you need help with?', 'Account question');
    await app.tapText('Send to a moderator');
    final thread = onlyThread(server);
    expect(find.text('Account question'), findsWidgets);

    // Closed by a moderator while the student was typing.
    thread.status = ThreadStatus.closed;
    await tester.enterText(
      find.widgetWithText(TextField, 'Reply to the moderator'),
      'One more thing',
    );
    await send(app);
    expect(find.textContaining('This conversation is closed.'), findsWidgets);
    expect(
      find.widgetWithText(TextField, 'Reply to the moderator'),
      findsNothing,
    );
    expect(thread.messages, hasLength(1));

    await app.tapText('Back to Help');
    expect(find.textContaining('Closed'), findsOneWidget);
  });
}
