import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../app/session.dart';
import '../../../ui/ui.dart' hide TimelineStep, TimelineStepState;
import '../../../ui/widgets/status_timeline.dart' as ui;
import '../../bookings/booking_format.dart';
import '../../bookings/widgets/payments_list.dart';
import '../staff_format.dart';
import '../widgets/photo_grid.dart';
import 'appeal_providers.dart';

/// One appeal with everything needed to rule: the booking, both sides,
/// charges and payments, the handover photos, notes and past rulings.
class AppealDetailScreen extends ConsumerWidget {
  const AppealDetailScreen({super.key, required this.appealId});

  final String appealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(staffAppealProvider(appealId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeal'),
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(Routes.staffHome)),
      ),
      body: detail.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(staffAppealProvider(appealId)),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(staffAppealProvider(appealId).future),
          child: _AppealDetailBody(
            detail: d,
            isAdmin: ref.watch(sessionProvider).status == SessionStatus.admin,
          ),
        ),
      ),
    );
  }
}

/// Words for a ruling's outcomes, e.g. "Refund ₹200 to the renter".
List<String> rulingOutcomes(RulingOut r, BookingOut b) {
  String name(String accountId) => accountId == b.renter.accountId
      ? '${b.renter.fullName} (${tradeRoleLabel(TradeRole.renter, b.kind)})'
      : accountId == b.owner.accountId
      ? '${b.owner.fullName} (${tradeRoleLabel(TradeRole.owner, b.kind)})'
      : 'Another account';
  final renter = tradeRoleLabel(TradeRole.renter, b.kind);
  return [
    if (r.chargePaise case final charge?)
      'Damage charge set to ${formatMoney(charge)}',
    if (r.refundPaise case final refund?)
      'Refund ${formatMoney(refund)} to the $renter',
    if (r.trustPenalty case final p?)
      '${p.points} points off ${name(p.accountId)}’s '
          '${p.role == TrustRole.lender ? 'lender' : 'renter'} trust',
    if (r.removeListing) 'Listing removed',
    if (r.accountAction case final a?)
      '${name(a.accountId)} '
          '${a.status == AccountRestriction.banned ? 'banned' : 'suspended'}',
  ];
}

class _AppealDetailBody extends StatelessWidget {
  const _AppealDetailBody({required this.detail, required this.isAdmin});

  final AppealDetail detail;

  /// Only the admin can overrule a ruling.
  final bool isAdmin;

  ui.TimelineStepState _state(TimelineStepState s) => switch (s) {
    TimelineStepState.done ||
    TimelineStepState.skipped => ui.TimelineStepState.done,
    TimelineStepState.current => ui.TimelineStepState.current,
    _ => ui.TimelineStepState.upcoming,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = detail.appeal;
    final b = detail.booking;
    final filer = a.filedBy == TradeRole.owner ? b.owner : b.renter;
    const gap = SizedBox(height: AppSpacing.xl);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );
    final charges = b.charges;
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
                    child: Text(
                      b.listing.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text(appealStatusLabel(a.status))),
                ],
              ),
              Text(
                '${b.kind == TradeKind.sale ? 'Sale' : 'Rental'} · '
                '${formatMoney(b.amountPaise)} · '
                '${bookingStatusLabel(b.status)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                appealReasonLabel(a.reason),
                style: theme.textTheme.titleSmall,
              ),
              Text(
                'Filed by ${filer.fullName} '
                '(${tradeRoleLabel(a.filedBy, b.kind)}) on '
                '${formatIstDateTime(a.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(a.notes),
            ],
          ),
        ),
        if (a.status != AppealStatus.open && isAdmin) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton.secondary(
            label: 'Overrule this ruling',
            icon: Icons.swap_horiz,
            onPressed: () => context.push(Routes.staffAppealOverrule(a.id)),
          ),
        ],
        if (a.status == AppealStatus.open) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Rule on this appeal',
            icon: Icons.gavel_outlined,
            onPressed: () => context.push(Routes.staffAppealRule(a.id)),
          ),
        ],
        gap,
        header('The two sides'),
        for (final (role, p) in [
          (TradeRole.renter, b.renter),
          (TradeRole.owner, b.owner),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(p.fullName),
            subtitle: Text(
              [
                'The ${tradeRoleLabel(role, b.kind)}',
                ?p.phone,
                'Trust ${(role == TradeRole.owner ? p.lender : p.renter).score ?? '–'}',
              ].join(' · '),
            ),
          ),
        if (charges != null) ...[
          gap,
          header('Charges at return'),
          _Line('Late fee', formatMoney(charges.lateFeePaise)),
          _Line(
            charges.damageDescription == null
                ? 'Damage'
                : 'Damage: ${charges.damageDescription}',
            formatMoney(charges.damagePaise),
          ),
          if (charges.cashExtensionsPaise > 0)
            _Line(
              'Extensions paid in cash',
              formatMoney(charges.cashExtensionsPaise),
            ),
          _Line(
            charges.paid ? 'Total (paid)' : 'Total (unpaid)',
            formatMoney(charges.totalPaise),
          ),
        ],
        if (b.payments.isNotEmpty) ...[
          gap,
          header('Payments'),
          PaymentsList(payments: b.payments),
        ],
        gap,
        header('Photos'),
        PhotoGrid(
          title: 'Pickup',
          photos: detail.pickupPhotos,
          category: b.listing.category,
        ),
        const SizedBox(height: AppSpacing.md),
        PhotoGrid(
          title: 'Return',
          photos: detail.returnPhotos,
          category: b.listing.category,
        ),
        const SizedBox(height: AppSpacing.md),
        PhotoGrid(
          title: 'Added to the appeal',
          photos: detail.extraPhotos,
          category: b.listing.category,
        ),
        if (detail.rulings.isNotEmpty) ...[
          gap,
          header('Rulings'),
          for (final r in detail.rulings) ...[
            _RulingCard(ruling: r, booking: b),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        gap,
        header('Progress'),
        ui.StatusTimeline(
          steps: [
            for (final s in b.timeline)
              ui.TimelineStep(
                title: s.label,
                state: _state(s.state),
                subtitle: s.at == null ? null : formatIstDateTime(s.at!),
              ),
          ],
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}

class _RulingCard extends StatelessWidget {
  const _RulingCard({required this.ruling, required this.booking});

  final RulingOut ruling;
  final BookingOut booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomes = rulingOutcomes(ruling, booking);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ruling.overrules == null ? 'Ruling' : 'Overruling by the admin'}'
            ' · ${formatIstDateTime(ruling.ruledAt)}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(ruling.summary),
          if (outcomes.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          for (final o in outcomes)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(o)),
              ],
            ),
          if (outcomes.isEmpty)
            Text('No other action', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
