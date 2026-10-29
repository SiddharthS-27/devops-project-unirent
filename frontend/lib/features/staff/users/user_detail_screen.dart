import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../../bookings/booking_format.dart';
import '../staff_format.dart';
import '../staff_providers.dart';
import '../widgets/reason_dialog.dart';
import '../widgets/risk_flags.dart';

/// A student as staff see them: contact details, trust, risk flags,
/// penalties and bookings; suspend, ban, restore or penalise them.
class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _busy = false;

  Future<void> _run(
    Future<StaffUserDetail> Function() call,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await call();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
      ref.invalidate(staffUserProvider(widget.accountId));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(AccountStatus status, String name) async {
    final (title, confirm, message, done) = switch (status) {
      AccountStatus.suspended => (
        'Suspend $name?',
        'Suspend',
        'They can’t list, request or pay, but can finish open handovers.',
        'Account suspended.',
      ),
      AccountStatus.banned => (
        'Ban $name?',
        'Ban',
        'They can’t sign in any more.',
        'Account banned.',
      ),
      _ => (
        'Restore $name?',
        'Restore',
        'They can use UniRent normally again.',
        'Account restored.',
      ),
    };
    final reason = await showReasonDialog(
      context,
      title: title,
      confirmLabel: confirm,
      message: message,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref
          .read(apiProvider)
          .staff
          .setStatus(
            widget.accountId,
            StatusChangeIn(status: status, reason: reason),
          ),
      done,
    );
  }

  Future<void> _penalty() async {
    final penalty = await showDialog<PenaltyIn>(
      context: context,
      builder: (context) => const _PenaltyDialog(),
    );
    if (penalty == null || !mounted) return;
    await _run(
      () => ref.read(apiProvider).staff.trustPenalty(widget.accountId, penalty),
      'Trust penalty recorded.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(staffUserProvider(widget.accountId));
    return Scaffold(
      appBar: AppBar(
        title: Text(user.value?.profile?.fullName ?? 'Student'),
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(Routes.staffUsers)),
      ),
      body: user.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(staffUserProvider(widget.accountId)),
        ),
        data: (u) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(staffUserProvider(widget.accountId).future),
          child: _body(context, u),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, StaffUserDetail u) {
    final theme = Theme.of(context);
    final p = u.profile;
    final name = p?.fullName ?? u.email;
    const gap = SizedBox(height: AppSpacing.xl);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: theme.textTheme.titleMedium),
                  ),
                  Chip(label: Text(accountStatusLabel(u.status))),
                ],
              ),
              Text(u.email),
              if (p != null) ...[
                Text('Roll number ${p.rollNumber}'),
                Text('${p.department}, year ${p.year}'),
                if (p.phone case final phone?) Text(phone),
                if (residenceLabel(p.residence) case final where?) Text(where),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Lender trust ${p.lender.score ?? '–'} · '
                  'Renter trust ${p.renter.score ?? '–'} · '
                  '${p.completedTrades} trades · '
                  '${p.cancellationCount} cancellations',
                  style: theme.textTheme.bodySmall,
                ),
              ] else
                Text(
                  'Hasn’t set up a profile yet.',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (u.status == 'active') ...[
          AppButton.secondary(
            label: 'Suspend',
            icon: Icons.pause_circle_outline,
            onPressed: _busy
                ? null
                : () => _setStatus(AccountStatus.suspended, name),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.destructive(
            label: 'Ban',
            icon: Icons.block,
            onPressed: _busy
                ? null
                : () => _setStatus(AccountStatus.banned, name),
          ),
        ] else ...[
          AppButton.primary(
            label: 'Restore account',
            icon: Icons.restore,
            onPressed: _busy
                ? null
                : () => _setStatus(AccountStatus.active, name),
          ),
          if (u.status == 'suspended') ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton.destructive(
              label: 'Ban',
              icon: Icons.block,
              onPressed: _busy
                  ? null
                  : () => _setStatus(AccountStatus.banned, name),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton.secondary(
          label: 'Trust penalty',
          icon: Icons.trending_down,
          onPressed: _busy ? null : _penalty,
        ),
        gap,
        header('Risk flags'),
        if (u.riskFlags.isEmpty)
          Text('None', style: theme.textTheme.bodySmall)
        else
          RiskFlagChips(flags: u.riskFlags),
        gap,
        header('Trust penalties'),
        if (u.penalties.isEmpty) Text('None', style: theme.textTheme.bodySmall),
        for (final x in u.penalties)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.trending_down),
            title: Text(
              '${x.points} points off '
              '${x.role == TrustRole.lender ? 'lender' : 'renter'} trust',
            ),
            subtitle: Text('${x.reason}\n${formatIstDateTime(x.at)}'),
            isThreeLine: true,
          ),
        gap,
        header('Bookings'),
        if (u.bookings.isEmpty) Text('None', style: theme.textTheme.bodySmall),
        for (final b in u.bookings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              b.kind == TradeKind.sale
                  ? Icons.sell_outlined
                  : Icons.schedule_outlined,
            ),
            title: Text(b.listingTitle),
            subtitle: Text(
              '${tradeRoleLabel(b.role, b.kind)} with ${b.counterpartyName} · '
              '${bookingStatusLabel(b.status)} · '
              '${formatMoney(b.amountPaise)}',
            ),
          ),
      ],
    );
  }
}

class _PenaltyDialog extends StatefulWidget {
  const _PenaltyDialog();

  @override
  State<_PenaltyDialog> createState() => _PenaltyDialogState();
}

class _PenaltyDialogState extends State<_PenaltyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _points = TextEditingController(text: '10');
  final _reason = TextEditingController();
  TrustRole _role = TrustRole.renter;

  @override
  void dispose() {
    _points.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trust penalty'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TrustRole>(
                segments: const [
                  ButtonSegment(value: TrustRole.renter, label: Text('Renter')),
                  ButtonSegment(value: TrustRole.lender, label: Text('Lender')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.single),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _points,
                label: 'Points',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 50
                      ? 'Enter 1 to 50 points'
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _reason,
                label: 'Reason',
                maxLines: 3,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Give a reason (at least 3 characters)'
                    : null,
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
              PenaltyIn(
                role: _role,
                points: int.parse(_points.text),
                reason: _reason.text.trim(),
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
