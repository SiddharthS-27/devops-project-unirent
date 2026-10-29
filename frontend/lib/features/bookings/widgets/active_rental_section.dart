import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../../payments/payment_flow.dart';
import '../booking_actions.dart';
import '../booking_format.dart';
import '../booking_providers.dart';
import 'ist_date_time_field.dart';
import 'start_return_button.dart';

/// While the item is out: time left (from the server's clock) and extra
/// time requests, approvals and payments.
class ActiveRentalSection extends ConsumerStatefulWidget {
  const ActiveRentalSection({super.key, required this.booking});

  final BookingOut booking;

  static bool appliesTo(BookingOut b) =>
      b.kind == TradeKind.rent &&
      b.endAt != null &&
      (b.status == BookingStatus.active || b.status == BookingStatus.overdue);

  @override
  ConsumerState<ActiveRentalSection> createState() =>
      _ActiveRentalSectionState();
}

class _ActiveRentalSectionState extends ConsumerState<ActiveRentalSection>
    with BookingActionRunner {
  late final _payments = PaymentFlow(ref);

  BookingOut get booking => widget.booking;
  bool get isRenter => booking.role == BookingViewerRole.renter;
  bool get isOwner => booking.role == BookingViewerRole.owner;

  bool _paid(ExtensionOut e) => switch (e.payment?.status) {
    PaymentStatus.captured || PaymentStatus.markedPaid => true,
    _ => false,
  };

  Future<void> _askForMoreTime() async {
    final end = booking.endAt!;
    final picked = await pickIstDateTime(
      context,
      initial: end.add(const Duration(days: 1)),
      first: end,
      last: end.add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    if (!picked.isAfter(end.add(const Duration(minutes: 59)))) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Pick a time at least an hour after the end time.'),
          ),
        );
      return;
    }
    await runAction(
      'extend',
      (key) => ref
          .read(apiProvider)
          .bookings
          .requestExtension(
            booking.id,
            ExtensionIn(newEndAt: picked),
            idempotencyKey: key,
          ),
      bookingId: booking.id,
      done: 'Asked for more time until ${formatIstDateTime(picked)}',
    );
  }

  Future<void> _decide(ExtensionOut e, {required bool approve}) async {
    final bookings = ref.read(apiProvider).bookings;
    await runAction(
      approve ? 'approve-${e.id}' : 'decline-${e.id}',
      (key) => approve
          ? bookings.approveExtension(booking.id, e.id, idempotencyKey: key)
          : bookings.declineExtension(booking.id, e.id, idempotencyKey: key),
      bookingId: booking.id,
      done: approve ? 'More time approved' : 'More time declined',
    );
  }

  Future<void> _pay(ExtensionOut e) async {
    setState(() => busyAction = 'pay-${e.id}');
    try {
      final changed = await _payments.pay(
        context,
        amountPaise: e.amountPaise,
        what: 'the extra time',
        cash: CashOption.atReturn,
        start: (method, key) async {
          final updated = await ref
              .read(apiProvider)
              .bookings
              .payExtension(
                booking.id,
                e.id,
                PaymentStartIn(method: method),
                idempotencyKey: key,
              );
          return method == PaymentMethod.cash ? null : updated.payment;
        },
      );
      if (changed) refreshBooking(booking.id);
    } finally {
      if (mounted) setState(() => busyAction = null);
    }
  }

  String _extensionStatus(ExtensionOut e) => switch (e.status) {
    ExtensionStatus.requested => 'Waiting for the owner',
    ExtensionStatus.declined => 'Declined',
    ExtensionStatus.approved when _paid(e) => 'Approved · paid',
    ExtensionStatus.approved when e.payInCashAtReturn =>
      'Approved · pay in cash at return',
    ExtensionStatus.approved => 'Approved · not paid yet',
    _ => 'Updated',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = booking.endAt!;
    final offset = ref.read(serverClockProvider).offset;
    final pending = booking.extensions.any(
      (e) => e.status == ExtensionStatus.requested,
    );
    final busy = busyAction != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Rental', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Return by ${formatIstDateTime(end)}',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Countdown(
                target: end,
                serverOffset: offset,
                label: 'Time left:',
                overdueLabel: 'Late by',
                style: theme.textTheme.headlineSmall,
                onElapsed: () => refreshBooking(booking.id),
              ),
            ],
          ),
        ),
        if (booking.extensions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('More time', style: theme.textTheme.titleSmall),
          for (final e in booking.extensions.reversed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Until ${formatIstDateTime(e.newEndAt)} · '
                      '${formatMoney(e.amountPaise)}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(_extensionStatus(e), style: theme.textTheme.bodySmall),
                    if (isOwner && e.status == ExtensionStatus.requested) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton.secondary(
                              label: 'Decline',
                              onPressed: busy
                                  ? null
                                  : () => _decide(e, approve: false),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              label: 'Approve',
                              isLoading: busyAction == 'approve-${e.id}',
                              onPressed: busy
                                  ? null
                                  : () => _decide(e, approve: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isRenter &&
                        e.status == ExtensionStatus.approved &&
                        !_paid(e) &&
                        !e.payInCashAtReturn) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Pay ${formatMoney(e.amountPaise)}',
                        // Disabled while paying; the sheets show progress.
                        onPressed: busy ? null : () => _pay(e),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        if (isRenter && booking.status == BookingStatus.active) ...[
          const SizedBox(height: AppSpacing.lg),
          StartReturnButton(booking: booking),
        ],
        if (isRenter && booking.status == BookingStatus.active && !pending) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton.secondary(
            label: 'Ask for more time',
            icon: Icons.more_time,
            isLoading: busyAction == 'extend',
            onPressed: busy ? null : _askForMoreTime,
          ),
        ],
        if (pending && isRenter)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'You can ask again once the owner answers.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (booking.startAt != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'Booked ${periodLabel(booking.startAt!, end)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
