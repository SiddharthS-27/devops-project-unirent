import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import 'handoff_sheet.dart';
import 'help_providers.dart';
import 'widgets/message_bubble.dart';

enum HelpTab { ask, faqs, chats }

/// Help: ask the bot, browse the FAQs, or talk to a moderator.
///
/// Opened from a booking, [bookingId] is attached to any conversation
/// started here.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key, this.bookingId, this.initialTab = HelpTab.ask});

  final String? bookingId;
  final HelpTab initialTab;

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: HelpTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _talkToModerator() async {
    final router = GoRouter.of(context);
    final thread = await showHandoffSheet(
      context,
      transcript: ref.read(helpChatProvider).transcript,
      bookingId: widget.bookingId,
    );
    if (thread == null || !mounted) return;
    ref.invalidate(myThreadsProvider);
    _tabs.index = HelpTab.chats.index;
    await router.push(Routes.helpThread(thread.id));
    if (mounted) ref.invalidate(myThreadsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Ask'),
            Tab(text: 'FAQs'),
            Tab(text: 'Your chats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AskTab(
            onSeeFaqs: () => _tabs.animateTo(HelpTab.faqs.index),
            onTalkToModerator: _talkToModerator,
          ),
          _FaqsTab(onTalkToModerator: _talkToModerator),
          _ChatsTab(onTalkToModerator: _talkToModerator),
        ],
      ),
    );
  }
}

class _AskTab extends ConsumerStatefulWidget {
  const _AskTab({required this.onSeeFaqs, required this.onTalkToModerator});

  final VoidCallback onSeeFaqs;
  final VoidCallback onTalkToModerator;

  @override
  ConsumerState<_AskTab> createState() => _AskTabState();
}

class _AskTabState extends ConsumerState<_AskTab> {
  final _message = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || ref.read(helpChatProvider).sending) return;
    final messenger = ScaffoldMessenger.of(context);
    _message.clear();
    try {
      await ref
          .read(helpChatProvider.notifier)
          .ask(text.length > 500 ? text.substring(0, 500) : text);
    } catch (error) {
      if (!mounted) return;
      _message.text = text;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(helpChatProvider);
    final lastBot = chat.lines.lastIndexWhere(
      (l) => l.author == TranscriptAuthor.bot,
    );
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            reverse: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final (i, line) in chat.lines.indexed.toList().reversed)
                MessageBubble(
                  label: line.author == TranscriptAuthor.user
                      ? 'You'
                      : 'UniRent bot',
                  body: line.text,
                  mine: line.author == TranscriptAuthor.user,
                  footer: i == lastBot
                      ? _ReplyActions(
                          actions: line.reply?.actions ?? const [],
                          onSeeFaqs: widget.onSeeFaqs,
                          onTalkToModerator: widget.onTalkToModerator,
                        )
                      : null,
                ),
              MessageBubble(
                label: 'UniRent bot',
                body:
                    'Hi! Ask me how renting, buying, fees or appeals work on '
                    'UniRent. For anything about your own booking, talk to a '
                    'moderator.',
                mine: false,
                footer: chat.lines.isEmpty
                    ? _ReplyActions(
                        actions: const [
                          ChatAction.seeFaqs,
                          ChatAction.talkToModerator,
                        ],
                        onSeeFaqs: widget.onSeeFaqs,
                        onTalkToModerator: widget.onTalkToModerator,
                      )
                    : null,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        MessageComposer(
          controller: _message,
          hint: 'Ask a question',
          sending: chat.sending,
          maxLength: 500,
          onSend: _send,
        ),
      ],
    );
  }
}

class _ReplyActions extends StatelessWidget {
  const _ReplyActions({
    required this.actions,
    required this.onSeeFaqs,
    required this.onTalkToModerator,
  });

  final List<ChatAction> actions;
  final VoidCallback onSeeFaqs;
  final VoidCallback onTalkToModerator;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final action in actions)
        switch (action) {
          ChatAction.seeFaqs => ActionChip(
            avatar: const Icon(Icons.list_alt_outlined),
            label: const Text('See FAQs'),
            onPressed: onSeeFaqs,
          ),
          ChatAction.talkToModerator => ActionChip(
            avatar: const Icon(Icons.support_agent_outlined),
            label: const Text('Talk to a moderator'),
            onPressed: onTalkToModerator,
          ),
          ChatAction.unknown => null,
        },
    ].nonNulls.toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: chips,
      ),
    );
  }
}

String faqTopicLabel(String topic) => switch (topic) {
  'booking' => 'Booking and pickup',
  'fees' => 'Fees',
  'payments' => 'Payments and refunds',
  'trust' => 'Trust and reviews',
  'disputes' => 'Damage and appeals',
  'listing' => 'Listing your items',
  'privacy' => 'Privacy and safety',
  '' => 'Other',
  _ => '${topic[0].toUpperCase()}${topic.substring(1)}',
};

class _FaqsTab extends ConsumerWidget {
  const _FaqsTab({required this.onTalkToModerator});

  final VoidCallback onTalkToModerator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(faqsProvider);
    return faqs.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyMessage(error),
        onRetry: () => ref.invalidate(faqsProvider),
      ),
      data: (faqs) {
        final byTopic = <String, List<FaqOut>>{};
        for (final faq in faqs) {
          byTopic.putIfAbsent(faq.topic, () => []).add(faq);
        }
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            if (faqs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('There are no FAQs yet.'),
              ),
            for (final MapEntry(key: topic, value: entries)
                in byTopic.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    faqTopicLabel(topic),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
              for (final faq in entries)
                ExpansionTile(
                  key: ValueKey(faq.id),
                  title: Text(faq.question),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  children: [Text(faq.answer)],
                ),
            ],
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton.secondary(
                label: 'Still stuck? Talk to a moderator',
                icon: Icons.support_agent_outlined,
                onPressed: onTalkToModerator,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Where a conversation stands, for the list of chats.
String threadStatusLabel(SupportThreadSummary t) => switch (t.status) {
  ThreadStatus.closed => 'Closed',
  _ when t.unanswered => 'Waiting for a moderator',
  _ => 'Moderator replied',
};

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab({required this.onTalkToModerator});

  final VoidCallback onTalkToModerator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(myThreadsProvider);
    return threads.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyMessage(error),
        onRetry: () => ref.invalidate(myThreadsProvider),
      ),
      data: (threads) => threads.isEmpty
          ? EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message:
                  'When you talk to a moderator, the conversation and their '
                  'replies appear here.',
              action: AppButton.primary(
                label: 'Talk to a moderator',
                expand: false,
                onPressed: onTalkToModerator,
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(myThreadsProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: threads.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = threads[i];
                  return ListTile(
                    leading: Icon(
                      t.status == ThreadStatus.closed
                          ? Icons.check_circle_outline
                          : t.unanswered
                          ? Icons.schedule
                          : Icons.mark_chat_unread_outlined,
                    ),
                    title: Text(
                      t.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${threadStatusLabel(t)} · '
                      '${formatIstDateTime(t.lastMessageAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push(Routes.helpThread(t.id));
                      ref.invalidate(myThreadsProvider);
                    },
                  );
                },
              ),
            ),
    );
  }
}
