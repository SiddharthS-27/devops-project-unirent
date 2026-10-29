import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../staff_format.dart';
import 'appeal_providers.dart';

/// Appeals: the open ones oldest first, or past rulings.
class AppealsQueueScreen extends ConsumerStatefulWidget {
  const AppealsQueueScreen({super.key});

  @override
  ConsumerState<AppealsQueueScreen> createState() => _AppealsQueueScreenState();
}

class _AppealsQueueScreenState extends ConsumerState<AppealsQueueScreen> {
  AppealFilter _filter = AppealFilter.open;

  @override
  Widget build(BuildContext context) {
    final appeals = ref.watch(staffAppealsProvider(_filter));
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
            child: SegmentedButton<AppealFilter>(
              segments: const [
                ButtonSegment(value: AppealFilter.open, label: Text('Open')),
                ButtonSegment(value: AppealFilter.ruled, label: Text('Ruled')),
                ButtonSegment(value: AppealFilter.all, label: Text('All')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.single),
            ),
          ),
          Expanded(
            child: appeals.when(
              loading: () => const LoadingState(),
              error: (error, _) => ErrorState(
                message: friendlyMessage(error),
                onRetry: () => ref.invalidate(staffAppealsProvider(_filter)),
              ),
              data: (appeals) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(staffAppealsProvider(_filter).future),
                child: appeals.isEmpty
                    ? ListView(
                        children: [
                          EmptyState(
                            icon: Icons.gavel_outlined,
                            title: _filter == AppealFilter.open
                                ? 'No open appeals'
                                : 'No appeals yet',
                            message: _filter == AppealFilter.open
                                ? 'New appeals show up here, oldest first.'
                                : null,
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: appeals.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _AppealTile(appeal: appeals[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppealTile extends ConsumerWidget {
  const _AppealTile({required this.appeal});

  final AppealSummary appeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = appeal;
    return ListTile(
      leading: Icon(
        a.kind == TradeKind.sale
            ? Icons.sell_outlined
            : Icons.schedule_outlined,
      ),
      title: Text(a.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${appealReasonLabel(a.reason)} · ${a.filedByName}\n'
        'Filed ${formatIstDateTime(a.createdAt)}',
      ),
      isThreeLine: true,
      trailing: Chip(label: Text(appealStatusLabel(a.status))),
      onTap: () async {
        await context.push(Routes.staffAppeal(a.id));
        ref.invalidate(staffAppealsProvider);
      },
    );
  }
}
