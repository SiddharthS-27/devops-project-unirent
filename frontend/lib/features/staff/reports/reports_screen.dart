import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../widgets/paged_list.dart';
import 'admin_providers.dart';
import 'report_format.dart';

enum _Section { metrics, reconciliation, audit }

/// The admin's reports: platform metrics, payment reconciliation and the
/// audit log.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Section _section = _Section.metrics;

  @override
  Widget build(BuildContext context) {
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
            child: SegmentedButton<_Section>(
              segments: const [
                ButtonSegment(value: _Section.metrics, label: Text('Metrics')),
                ButtonSegment(
                  value: _Section.reconciliation,
                  label: Text('Reconciliation'),
                ),
                ButtonSegment(value: _Section.audit, label: Text('Audit log')),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.single),
            ),
          ),
          Expanded(
            child: switch (_section) {
              _Section.metrics => const _Metrics(),
              _Section.reconciliation => const _Reconciliation(),
              _Section.audit => const _AuditLog(),
            },
          ),
        ],
      ),
    );
  }
}

class _Metrics extends ConsumerWidget {
  const _Metrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(metricsProvider);
    final theme = Theme.of(context);
    return metrics.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyMessage(error),
        onRetry: () => ref.invalidate(metricsProvider),
      ),
      data: (m) {
        final states = m.bookingsByState.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return RefreshIndicator(
          onRefresh: () => ref.refresh(metricsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _StatStrip(
                stats: [
                  _Stat(
                    'UPI success rate',
                    percentLabel(m.paymentSuccessRate),
                    hint: 'Last 30 days',
                  ),
                  _Stat('Students', '${m.students}'),
                  _Stat('Active listings', '${m.activeListings}'),
                  _Stat('Completed trades', '${m.completedTrades}'),
                  _Stat('Overdue now', '${m.overdueCount}'),
                  _Stat('Open disputes', '${m.openDisputes}'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  'Bookings by state',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (states.isEmpty)
                Text('No bookings yet', style: theme.textTheme.bodySmall),
              for (final e in states)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    children: [
                      Expanded(child: Text(bookingStateLabel(e.key))),
                      Text('${e.value}'),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Headline figures as one card split by rules, two to a row.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final rule = Theme.of(context).colorScheme.outlineVariant;
    final rows = <List<_Stat>>[
      for (var i = 0; i < stats.length; i += 2)
        stats.sublist(i, (i + 2).clamp(0, stats.length)),
    ];
    return AppCard(
      padding: EdgeInsets.zero,
      semanticContainer: false,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const Divider(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < rows[r].length; c++) ...[
                    if (c > 0) VerticalDivider(width: 1, color: rule),
                    Expanded(child: rows[r][c]),
                  ],
                  if (rows[r].length == 1) const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // A missing figure is a small grey dash, never a dash at value size.
    final missing = value == '–' || value == '-' || value == '—';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: missing
                  ? theme.textTheme.bodyLarge?.copyWith(color: muted)
                  : theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
            ),
            if (hint != null)
              Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Reconciliation extends ConsumerStatefulWidget {
  const _Reconciliation();

  @override
  ConsumerState<_Reconciliation> createState() => _ReconciliationState();
}

class _ReconciliationState extends ConsumerState<_Reconciliation> {
  bool _running = false;

  Future<void> _run() async {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final day = await showDatePicker(
      context: context,
      helpText: 'Day to check (IST)',
      initialDate: yesterday,
      firstDate: yesterday.subtract(const Duration(days: 365)),
      lastDate: yesterday.add(const Duration(days: 1)),
    );
    if (day == null || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    try {
      final report = await ref
          .read(apiProvider)
          .payments
          .runReconciliationNow(
            ReconciliationRunIn(
              day: DateTime.utc(day.year, day.month, day.day),
            ),
          );
      ref.invalidate(reconciliationRunsProvider);
      await router.push(Routes.staffReconciliationRun(report.id));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(reconciliationRunsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppButton.secondary(
            label: 'Run reconciliation now',
            icon: Icons.sync,
            isLoading: _running,
            onPressed: _run,
          ),
        ),
        Expanded(
          child: runs.when(
            loading: () => const LoadingState(),
            error: (error, _) => ErrorState(
              message: friendlyMessage(error),
              onRetry: () => ref.invalidate(reconciliationRunsProvider),
            ),
            data: (runs) => RefreshIndicator(
              onRefresh: () => ref.refresh(reconciliationRunsProvider.future),
              child: runs.isEmpty
                  ? ListView(
                      children: const [
                        EmptyState(
                          icon: Icons.sync,
                          title: 'No reconciliation runs yet',
                          message: 'A run checks every night at 02:00 IST.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: runs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final run = runs[i];
                        final mismatches = run.totals['mismatches'];
                        final bad = mismatches is int && mismatches > 0;
                        return ListTile(
                          leading: Icon(
                            run.status == ReconciliationReportStatus.failed ||
                                    bad
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color:
                                run.status ==
                                        ReconciliationReportStatus.failed ||
                                    bad
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                          title: Text(dayLabel(run.day)),
                          subtitle: Text(
                            [
                              runStatusLabel(run.status),
                              if (mismatches is int)
                                mismatches == 1
                                    ? '1 mismatch'
                                    : '$mismatches mismatches',
                              run.triggeredBy == 'nightly'
                                  ? 'Nightly'
                                  : 'Run by an admin',
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            Routes.staffReconciliationRun(run.id),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditLog extends ConsumerStatefulWidget {
  const _AuditLog();

  @override
  ConsumerState<_AuditLog> createState() => _AuditLogState();
}

class _AuditLogState extends ConsumerState<_AuditLog> {
  final _target = TextEditingController();
  String? _filter;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _apply() => setState(() {
    final t = _target.text.trim();
    _filter = t.isEmpty ? null : t;
  });

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: _target,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _apply(),
            decoration: InputDecoration(
              hintText: 'Filter by target, e.g. account:<id>',
              prefixIcon: const Icon(Icons.filter_list),
              suffixIcon: IconButton(
                tooltip: 'Filter',
                icon: const Icon(Icons.arrow_forward),
                onPressed: _apply,
              ),
            ),
          ),
        ),
        Expanded(
          child: PagedList<AuditEntryOut>(
            queryKey: _filter ?? '',
            load: (cursor) async {
              final page = await api.admin.auditLog(
                target: _filter,
                cursor: cursor,
              );
              return (items: page.items, next: page.nextCursor);
            },
            itemBuilder: (context, e, _) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(auditActionLabel(e.action)),
              subtitle: Text(
                [
                  '${formatIstDateTime(e.at)} · '
                      '${e.actorRole ?? 'system'}',
                  ?e.target,
                  for (final d in e.details.entries)
                    '${d.key}: ${d.value is Map || d.value is List ? d.value.toString() : d.value}',
                ].join('\n'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            empty: const EmptyState(
              icon: Icons.history,
              title: 'No audit entries',
            ),
          ),
        ),
      ],
    );
  }
}
