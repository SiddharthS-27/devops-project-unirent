import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/push_service.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import 'help_providers.dart';
import 'widgets/message_bubble.dart';

/// A conversation with the moderators; their replies arrive here.
class SupportThreadScreen extends ConsumerStatefulWidget {
  const SupportThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<SupportThreadScreen> createState() =>
      _SupportThreadScreenState();
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(apiProvider)
          .help
          .postMessage(widget.threadId, SupportMessageIn(body: text));
      _reply.clear();
    } catch (error) {
      // A closed conversation shows as closed once reloaded.
      if (error is! ApiException || error.code != 'THREAD_CLOSED') {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    // Shows the new message, or that the conversation was closed.
    ref.invalidate(supportThreadProvider(widget.threadId));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pushReceivedProvider, (_, next) {
      final link = next.value?.link;
      if (link != null &&
          deepLinkToLocation(link)?.path ==
              Routes.helpThread(widget.threadId)) {
        ref.invalidate(supportThreadProvider(widget.threadId));
      }
    });
    final thread = ref.watch(supportThreadProvider(widget.threadId));
    return Scaffold(
      appBar: AppBar(
        title: Text(thread.value?.subject ?? 'Conversation'),
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(Routes.help)),
      ),
      body: thread.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(supportThreadProvider(widget.threadId)),
        ),
        data: (t) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(supportThreadProvider(widget.threadId).future),
                child: ListView(
                  reverse: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (t.status != ThreadStatus.closed &&
                        t.messages.lastOrNull?.author !=
                            MessageAuthor.moderator)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'A moderator will reply here. We’ll notify you.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    for (final m in t.messages.reversed)
                      MessageBubble(
                        key: ValueKey(m.id),
                        label: messageAuthorLabel(
                          m.author,
                          m.authorName,
                          viewerIsStaff: false,
                        ),
                        body: m.body,
                        at: m.at,
                        mine: m.author == MessageAuthor.user,
                        highlight: m.author == MessageAuthor.moderator,
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (t.status == ThreadStatus.closed)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'This conversation is closed. Ask the bot or start a '
                        'new conversation from Help.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton.secondary(
                        label: 'Back to Help',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(Routes.help),
                      ),
                    ],
                  ),
                ),
              )
            else
              MessageComposer(
                controller: _reply,
                hint: 'Reply to the moderator',
                sending: _sending,
                maxLength: 2000,
                onSend: _send,
              ),
          ],
        ),
      ),
    );
  }
}
