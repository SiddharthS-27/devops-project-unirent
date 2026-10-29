import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../../help/widgets/message_bubble.dart';
import '../staff_providers.dart';

/// A student's support conversation: reply in the same chat, or close it.
class StaffThreadScreen extends ConsumerStatefulWidget {
  const StaffThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<StaffThreadScreen> createState() => _StaffThreadScreenState();
}

class _StaffThreadScreenState extends ConsumerState<StaffThreadScreen> {
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _show(ScaffoldMessengerState messenger, String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .staff
          .supportReply(widget.threadId, SupportMessageIn(body: text));
      _reply.clear();
    } catch (error) {
      _show(messenger, friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    ref.invalidate(staffThreadProvider(widget.threadId));
  }

  Future<void> _close() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this conversation?'),
        content: const Text(
          'The student can’t reply any more; they can start a new one from '
          'Help.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close conversation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).staff.closeThread(widget.threadId);
      _show(messenger, 'Conversation closed.');
    } catch (error) {
      _show(messenger, friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    ref.invalidate(staffThreadProvider(widget.threadId));
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(staffThreadProvider(widget.threadId));
    final open = thread.value?.status == ThreadStatus.open;
    return Scaffold(
      appBar: AppBar(
        title: Text(thread.value?.subject ?? 'Conversation'),
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(Routes.staffSupport)),
        actions: [
          if (open)
            IconButton(
              tooltip: 'Close conversation',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _busy ? null : _close,
            ),
        ],
      ),
      body: thread.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(staffThreadProvider(widget.threadId)),
        ),
        data: (t) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(staffThreadProvider(widget.threadId).future),
                child: ListView(
                  reverse: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final m in t.messages.reversed)
                      MessageBubble(
                        key: ValueKey(m.id),
                        label: messageAuthorLabel(
                          m.author,
                          m.authorName,
                          viewerIsStaff: true,
                        ),
                        body: m.body,
                        at: m.at,
                        mine: m.author == MessageAuthor.moderator,
                      ),
                    if (t.bookingId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'About booking ${t.bookingId}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (t.status == ThreadStatus.closed)
              const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'This conversation is closed.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              MessageComposer(
                controller: _reply,
                hint: 'Reply to the student',
                sending: _busy,
                maxLength: 2000,
                onSend: _send,
              ),
          ],
        ),
      ),
    );
  }
}
