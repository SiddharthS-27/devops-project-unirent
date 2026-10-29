import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';

final lateFeeHistoryProvider =
    FutureProvider.autoDispose<List<LateFeeRuleVersion>>(
      (ref) => ref.watch(apiProvider).payments.lateFeeRuleHistory(),
    );

String _percent(int bp) {
  final pct = bp / 100;
  return pct == pct.roundToDouble() ? '${pct.round()}%' : '$pct%';
}

/// The rule in words, as renters see it.
String lateFeeRuleSummary(LateFeeRuleVersion r) =>
    '${r.graceMinutes}-minute grace period, then '
    '${formatMoney(r.baseFeePaise)} plus ${_percent(r.hourlyPercentBp)} of '
    'the rent for every further hour.';

/// The late-fee rule in force, its history, and setting a new version.
class LateFeeRuleScreen extends ConsumerWidget {
  const LateFeeRuleScreen({super.key});

  Future<void> _setNew(
    BuildContext context,
    WidgetRef ref,
    LateFeeRuleVersion current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final rule = await showDialog<LateFeeRuleIn>(
      context: context,
      builder: (context) => _RuleDialog(current: current),
    );
    if (rule == null) return;
    try {
      final saved = await ref.read(apiProvider).payments.setLateFeeRule(rule);
      ref.invalidate(lateFeeHistoryProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Version ${saved.version} is now in force.')),
        );
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(lateFeeHistoryProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: history.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(lateFeeHistoryProvider),
        ),
        data: (versions) {
          final current = versions.firstOrNull;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(lateFeeHistoryProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                if (current != null) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'In force: version ${current.version}',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Since ${formatIstDateTime(current.effectiveFrom)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(lateFeeRuleSummary(current)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.primary(
                    label: 'Set a new version',
                    icon: Icons.edit_outlined,
                    onPressed: () => _setNew(context, ref, current),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'A new version applies to bookings approved from then '
                    'on; earlier bookings keep their rule.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text('History', style: theme.textTheme.titleMedium),
                ),
                for (final v in versions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${v.version}')),
                    title: Text(lateFeeRuleSummary(v)),
                    subtitle: Text(
                      'From ${formatIstDateTime(v.effectiveFrom)}',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({required this.current});

  final LateFeeRuleVersion current;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _grace = TextEditingController(
    text: '${widget.current.graceMinutes}',
  );
  late final _base = TextEditingController(
    text: '${widget.current.baseFeePaise ~/ 100}',
  );
  late final _percent = TextEditingController(
    text: (widget.current.hourlyPercentBp / 100).toString().replaceFirst(
      RegExp(r'\.0$'),
      '',
    ),
  );

  @override
  void dispose() {
    _grace.dispose();
    _base.dispose();
    _percent.dispose();
    super.dispose();
  }

  String? _range(String? v, num max, String what) {
    final n = num.tryParse(v ?? '');
    return n == null || n < 0 || n > max ? 'Enter $what from 0 to $max' : null;
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: const Text('New late-fee rule'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _grace,
                label: 'Grace period',
                suffix: const Text('minutes'),
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                validator: (v) => _range(v, 1440, 'minutes'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _base,
                label: 'Base fee',
                prefixText: '₹',
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                validator: (v) => _range(v, 10000, 'an amount'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _percent,
                label: 'Hourly charge',
                helperText: 'Percent of the rent per hour after the grace',
                suffix: const Text('%'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (v) => _range(v, 100, 'a percentage'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              LateFeeRuleIn(
                graceMinutes: int.parse(_grace.text),
                baseFeePaise: int.parse(_base.text) * 100,
                hourlyPercentBp: (num.parse(_percent.text) * 100).round(),
              ),
            );
          },
          child: const Text('Put in force'),
        ),
      ],
    );
  }
}
