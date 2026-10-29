import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import 'admin_providers.dart';
import 'report_format.dart';

/// One reconciliation run: its totals and every mismatch found.
class ReconciliationReportScreen extends ConsumerWidget {
  const ReconciliationReportScreen({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reconciliationReportProvider(runId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          report.value == null
              ? 'Reconciliation'
              : 'Reconciliation ${dayLabel(report.value!.day)}',
        ),
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(Routes.staffReports)),
      ),
      body: report.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(reconciliationReportProvider(runId)),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              [
                runStatusLabel(r.status),
                'started ${formatIstDateTime(r.startedAt)}',
                if (r.finishedAt case final f?) 'finished ${formatIstTime(f)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final t in r.totals.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    Expanded(child: Text(totalLabel(t.key))),
                    Text(totalValue(t.value)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text('Mismatches', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (r.mismatches.isEmpty)
              const Text('None: the ledger agrees with Razorpay.'),
            for (final m in r.mismatches)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mismatchKindLabel(m.kind),
                        style: theme.textTheme.titleSmall,
                      ),
                      SelectableText(m.reference),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ledger: ${_side(m.ledgerAmountPaise, m.ledgerStatus)}',
                      ),
                      Text(
                        'Razorpay: '
                        '${_side(m.razorpayAmountPaise, m.razorpayStatus)}',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _side(int? amount, String? status) {
    final parts = [if (amount != null) formatMoney(amount), ?status];
    return parts.isEmpty ? 'not found' : parts.join(', ');
  }
}
