import 'dart:async';

import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_faqs.dart';
import 'mock_handlers.dart';
import 'mock_listings.dart';
import 'mock_server.dart';
import 'mock_views.dart';

/// Help bot reply when no FAQ matches well enough (backend `FALLBACK`).
const mockChatFallback =
    'I can only answer general questions about how UniRent works. Have a '
    'look at the FAQs, or talk to a moderator.';
const _threshold = 0.35;
const _subjectLength = 80;

class MockSupportMessage {
  MockSupportMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.at,
    this.authorId,
  });

  final String id;
  final MessageAuthor author;
  final String? authorId;
  final String body;
  final DateTime at;
}

class MockSupportThread {
  MockSupportThread({
    required this.id,
    required this.accountId,
    required this.subject,
    required this.createdAt,
    this.bookingId,
  }) : updatedAt = createdAt;

  final String id;
  final String accountId;
  final String? bookingId;
  final String subject;
  final DateTime createdAt;
  DateTime updatedAt;
  ThreadStatus status = ThreadStatus.open;

  /// True until a moderator replies to the latest user message.
  bool unanswered = true;
  final messages = <MockSupportMessage>[];
}

List<String> _normalise(String message) => [
  for (final w in RegExp('[a-z0-9]+').allMatches(message.toLowerCase()))
    w[0]!.length > 3 && w[0]!.endsWith('s')
        ? w[0]!.substring(0, w[0]!.length - 1)
        : w[0]!,
];

double _keywordScore(List<String> words, List<String> keywords) {
  final stems = {
    for (final k in keywords)
      k.length > 3 && k.endsWith('s') ? k.substring(0, k.length - 1) : k,
  };
  final hits = words.toSet().where(stems.contains).length;
  return hits / 2 > 1 ? 1 : hits / 2;
}

/// Word overlap standing in for Postgres trigram similarity.
double _similarity(String question, String message) {
  final a = _normalise(question).toSet();
  final b = _normalise(message).toSet();
  if (a.isEmpty || b.isEmpty) return 0;
  return a.intersection(b).length / a.union(b).length;
}

String _lateFeeText(MockDb db) {
  final rule = mockLateFeeRule(db.clock().toUtc());
  final base = rule.baseFeePaise / 100;
  final percent = rule.hourlyPercentBp / 100;
  String n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
  return 'After the end time there is a ${rule.graceMinutes}-minute grace '
      'period. Then a late fee of ₹${n(base)} applies, plus ${n(percent)}% '
      "of the booking's rent for every further hour.";
}

String _faqId(int i) =>
    '00000000-0000-4000-e000-${(i + 1).toString().padLeft(12, '0')}';

Map<String, MockHandler> helpHandlers(MockDb db) {
  final h = _HelpHandlers(db);
  return {
    'GET /api/v1/help/faqs': h.faqs,
    'POST /api/v1/help/chat': h.chat,
    'POST /api/v1/help/handoff': h.handoff,
    'GET /api/v1/support/threads': h.myThreads,
    'GET /api/v1/support/threads/{thread_id}': h.myThread,
    'POST /api/v1/support/threads/{thread_id}/messages': h.post,
  };
}

/// A thread as its API view (shared with the staff handlers).
SupportThreadOut mockThreadOut(MockDb db, MockSupportThread t) =>
    SupportThreadOut(
      id: t.id,
      accountId: t.accountId,
      bookingId: t.bookingId,
      subject: t.subject,
      status: t.status,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
      messages: [for (final m in t.messages) mockMessageOut(db, m)],
    );

SupportMessage mockMessageOut(MockDb db, MockSupportMessage m) {
  final author = m.authorId == null ? null : db.accounts[m.authorId];
  return SupportMessage(
    id: m.id,
    author: m.author,
    authorName: author == null
        ? null
        : db.profiles[author.id]?.data.fullName ?? author.name,
    body: m.body,
    at: m.at,
  );
}

class _HelpHandlers {
  _HelpHandlers(this.db);

  final MockDb db;

  DateTime get now => db.clock().toUtc();

  String _answer(String text) =>
      text.replaceAll('{late_fee_rule}', _lateFeeText(db));

  MockResponse faqs(MockRequest r) {
    mockAuthenticate(db, r);
    return MockResponse.json([
      for (final (i, (topic, question, answer, _)) in mockFaqs.indexed)
        FaqOut(
          id: _faqId(i),
          topic: topic,
          question: question,
          answer: _answer(answer),
        ).toJson(),
    ]);
  }

  MockResponse chat(MockRequest r) {
    mockAuthenticate(db, r);
    final message = mockParse(r, ChatIn.fromJson).message;
    if (message.trim().isEmpty || message.length > 500) {
      throw mockValidation('message', 'Must be 1-500 characters');
    }
    final words = _normalise(message);
    var best = -1;
    var bestScore = 0.0;
    for (final (i, (_, question, _, keywords)) in mockFaqs.indexed) {
      final score =
          0.7 * _keywordScore(words, keywords) +
          0.3 * _similarity(question, message);
      if (score > bestScore) {
        best = i;
        bestScore = score;
      }
    }
    const actions = [ChatAction.seeFaqs, ChatAction.talkToModerator];
    if (best < 0 || bestScore < _threshold) {
      return MockResponse.json(
        const ChatReply(
          kind: ChatReplyKind.fallback,
          text: mockChatFallback,
          actions: actions,
        ).toJson(),
      );
    }
    return MockResponse.json(
      ChatReply(
        kind: ChatReplyKind.answer,
        text: _answer(mockFaqs[best].$3),
        faqId: _faqId(best),
        actions: actions,
      ).toJson(),
    );
  }

  /// Opens a thread holding the chat transcript, then the user's message.
  FutureOr<MockResponse> handoff(MockRequest r) {
    final account = mockAuthenticate(db, r);
    final body = mockParse(r, HandoffIn.fromJson);
    if (body.message.trim().isEmpty || body.message.length > 1000) {
      throw mockValidation('message', 'Must be 1-1000 characters');
    }
    final transcript = body.transcript ?? const [];
    if (transcript.length > 50) {
      throw mockValidation('transcript', 'At most 50 lines');
    }
    final t = MockSupportThread(
      id: db.nextId(),
      accountId: account.id,
      bookingId: body.bookingId,
      subject: body.message.length > _subjectLength
          ? body.message.substring(0, _subjectLength)
          : body.message,
      createdAt: now,
    );
    for (final (n, line) in transcript.indexed) {
      t.messages.add(
        MockSupportMessage(
          id: db.nextId(),
          author: line.author == TranscriptAuthor.bot
              ? MessageAuthor.bot
              : MessageAuthor.user,
          authorId: line.author == TranscriptAuthor.bot ? null : account.id,
          body: line.text,
          at: now.add(Duration(microseconds: n)),
        ),
      );
    }
    t.messages.add(
      MockSupportMessage(
        id: db.nextId(),
        author: MessageAuthor.user,
        authorId: account.id,
        body: body.message,
        at: now.add(Duration(microseconds: transcript.length)),
      ),
    );
    db.supportThreads[t.id] = t;
    return MockResponse(201, mockThreadOut(db, t).toJson());
  }

  MockSupportThread _mine(MockRequest r, MockAccount viewer) {
    final t = db.supportThreads[r.pathParams['thread_id']];
    if (t == null || t.accountId != viewer.id) {
      throw const MockApiError(404, 'NOT_FOUND', 'Conversation not found');
    }
    return t;
  }

  MockResponse myThreads(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    final mine =
        db.supportThreads.values.where((t) => t.accountId == viewer.id).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return MockResponse.json([
      for (final t in mine)
        SupportThreadSummary(
          id: t.id,
          accountId: t.accountId,
          accountName: mockOwnProfile(db, viewer).fullName,
          bookingId: t.bookingId,
          subject: t.subject,
          status: t.status,
          lastMessageAt: t.messages.last.at,
          unanswered: t.unanswered,
        ).toJson(),
    ]);
  }

  MockResponse myThread(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    return MockResponse.json(mockThreadOut(db, _mine(r, viewer)).toJson());
  }

  FutureOr<MockResponse> post(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    final t = _mine(r, viewer);
    if (t.status == ThreadStatus.closed) {
      throw const MockApiError(
        409,
        'THREAD_CLOSED',
        'This conversation is closed; start a new one',
      );
    }
    final body = mockParse(r, SupportMessageIn.fromJson).body;
    if (body.trim().isEmpty || body.length > 2000) {
      throw mockValidation('body', 'Must be 1-2000 characters');
    }
    final m = MockSupportMessage(
      id: db.nextId(),
      author: MessageAuthor.user,
      authorId: viewer.id,
      body: body,
      at: now,
    );
    t
      ..messages.add(m)
      ..unanswered = true
      ..updatedAt = now;
    return MockResponse(201, mockMessageOut(db, m).toJson());
  }
}

/// A moderator's reply in [thread] (backend `support.post` by staff).
MockSupportMessage mockStaffReply(
  MockDb db,
  MockSupportThread thread,
  MockAccount staff,
  String body,
) {
  final now = db.clock().toUtc();
  final m = MockSupportMessage(
    id: db.nextId(),
    author: MessageAuthor.moderator,
    authorId: staff.id,
    body: body,
    at: now,
  );
  thread
    ..messages.add(m)
    ..unanswered = false
    ..updatedAt = now;
  return m;
}
