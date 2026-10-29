import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../staff_providers.dart';

/// Chats handed off from the help bot, latest activity first.
class SupportInboxScreen extends ConsumerStatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  ConsumerState<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends ConsumerState<SupportInboxScreen> {
  ThreadStatus _status = ThreadStatus.open;

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(supportInboxProvider(_status));
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SegmentedButton<ThreadStatus>(
              segments: const [
                ButtonSegment(value: ThreadStatus.open, label: Text('Open')),
                ButtonSegment(
                  value: ThreadStatus.closed,
                  label: Text('Closed'),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.single),
            ),
          ),
          Expanded(
            child: threads.when(
              loading: () => const LoadingState(),
              error: (error, _) => ErrorState(
                message: friendlyMessage(error),
                onRetry: () => ref.invalidate(supportInboxProvider(_status)),
              ),
              data: (threads) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(supportInboxProvider(_status).future),
                child: threads.isEmpty
                    ? ListView(
                        children: [
                          EmptyState(
                            icon: Icons.support_agent_outlined,
                            title: _status == ThreadStatus.open
                                ? 'No open conversations'
                                : 'No closed conversations',
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: threads.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final t = threads[i];
                          return ListTile(
                            leading: Icon(
                              t.unanswered && t.status == ThreadStatus.open
                                  ? Icons.mark_chat_unread_outlined
                                  : Icons.chat_bubble_outline,
                            ),
                            title: Text(
                              t.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${t.accountName ?? 'Student'} · '
                              '${formatIstDateTime(t.lastMessageAt)}',
                            ),
                            trailing:
                                t.unanswered && t.status == ThreadStatus.open
                                ? const Chip(label: Text('Needs reply'))
                                : null,
                            onTap: () async {
                              await context.push(Routes.staffThread(t.id));
                              ref.invalidate(supportInboxProvider);
                            },
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
