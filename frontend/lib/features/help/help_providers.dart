import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';

final faqsProvider = FutureProvider.autoDispose<List<FaqOut>>(
  (ref) => ref.watch(apiProvider).help.faqs(),
);

/// The student's support conversations, newest first.
final myThreadsProvider =
    FutureProvider.autoDispose<List<SupportThreadSummary>>(
      (ref) => ref.watch(apiProvider).help.myThreads(),
    );

final supportThreadProvider = FutureProvider.autoDispose
    .family<SupportThreadOut, String>(
      (ref, id) => ref.watch(apiProvider).help.myThread(id),
    );

/// One line of the help bot chat.
class ChatLine {
  const ChatLine.user(this.text) : author = TranscriptAuthor.user, reply = null;

  ChatLine.bot(ChatReply this.reply)
    : author = TranscriptAuthor.bot,
      text = reply.text;

  final TranscriptAuthor author;
  final String text;

  /// The bot's reply, for bot lines.
  final ChatReply? reply;

  bool get isFallback => reply?.kind == ChatReplyKind.fallback;
}

class HelpChatState {
  const HelpChatState({this.lines = const [], this.sending = false});

  final List<ChatLine> lines;
  final bool sending;

  /// What a moderator sees of the chat when it is handed off.
  List<TranscriptLine> get transcript => [
    for (final line
        in lines.length > 50 ? lines.sublist(lines.length - 50) : lines)
      TranscriptLine(author: line.author, text: line.text),
  ];
}

/// The help bot chat; it lasts while Help is open.
class HelpChat extends Notifier<HelpChatState> {
  @override
  HelpChatState build() => const HelpChatState();

  /// Sends [message]; throws if the bot can't be reached (the question is
  /// then taken back out so it can be resent).
  Future<void> ask(String message) async {
    final question = ChatLine.user(message);
    state = HelpChatState(lines: [...state.lines, question], sending: true);
    try {
      final reply = await ref
          .read(apiProvider)
          .help
          .chat(ChatIn(message: message));
      if (!ref.mounted) return;
      state = HelpChatState(lines: [...state.lines, ChatLine.bot(reply)]);
    } catch (_) {
      if (ref.mounted) {
        state = HelpChatState(lines: [...state.lines]..remove(question));
      }
      rethrow;
    }
  }
}

final helpChatProvider = NotifierProvider.autoDispose<HelpChat, HelpChatState>(
  HelpChat.new,
);
