import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../booking_actions.dart';
import 'cancellation_rating_form.dart';

/// One-line explanations for next-action keys; unknown keys show the label.
const nextActionHints = {
  'waiting_owner': 'The owner has 24 hours to approve or decline.',
  'decide_request':
      'Approving fixes the price and dates and declines overlapping requests.',
  'upload_pickup_photos':
      'Photograph the item at pickup so you both have a record.',
  'waiting_pickup_photos': 'They need to add their pickup photos.',
  'pay': 'Pay the rent by UPI or hand over cash.',
  'waiting_cash_mark': 'The owner needs to confirm they got the cash.',
  'mark_cash_received': 'Confirm once you have the cash in hand.',
  'waiting_payment': 'The renter is paying.',
  'show_otp': 'The owner types this code to confirm the handover.',
  'enter_otp': 'Ask the renter for the code on their screen.',
  'rate_cancellation': 'Tell others how the cancellation went.',
  'decide_extension': 'The renter asked to keep the item longer.',
  'waiting_extension': 'The owner will approve or decline.',
  'pay_extension': 'Pay for the extra time, or choose cash at return.',
  'return_on_time': 'Bring it back by the end time to avoid late fees.',
  'rental_active': 'The item is with the renter.',
  'return_now': 'Late fees are adding up. Return the item now.',
  'escalate': 'The return is over an hour late. Moderators can step in.',
  'waiting_return': 'The renter hasn’t returned the item yet.',
  'upload_return_photos': 'Photograph the item as you return it.',
  'waiting_return_photos': 'The renter is adding return photos.',
  'inspect_item': 'Check the item and add your photos.',
  'waiting_inspection': 'The owner is checking the item.',
  'show_return_otp': 'The renter types this code to confirm the return.',
  'enter_return_otp': 'Ask the owner for the code on their screen.',
  'pay_charges': 'Pay the late fee, damage or extra-time charges.',
  'record_damage_or_wait': 'Record any damage, or wait for the payment.',
  'proceed': 'Everything is settled. Tap Proceed to finish.',
  'waiting_proceed': 'The owner will finish the rental.',
  'waiting_ruling': 'A moderator is reviewing the appeal.',
  'write_review':
      'Reviews are blind: they see yours after reviewing you, or 24 hours '
      'after the first review.',
  'waiting_review': 'Both reviews show once they review you.',
};

/// Purchase wording for hints whose rental text mentions rent or owners.
const _saleHints = {
  'decide_request':
      'Approving fixes the price and declines the other requests for it.',
  'pay': 'Pay for the item by UPI or hand over cash.',
  'waiting_cash_mark': 'The seller needs to confirm they got the cash.',
  'waiting_payment': 'The buyer is paying.',
  'show_otp': 'The seller types this code to confirm the handover.',
  'enter_otp': 'Ask the buyer for the code on their screen.',
};

/// The hint for [key], worded for a sale when [kind] is one.
String? nextActionHint(String key, TradeKind kind) =>
    (kind == TradeKind.sale ? _saleHints[key] : null) ?? nextActionHints[key];

/// The single card telling this user what happens next, with the controls
/// for that step.
class NextActionCard extends ConsumerStatefulWidget {
  const NextActionCard({super.key, required this.booking});

  final BookingOut booking;

  @override
  ConsumerState<NextActionCard> createState() => _NextActionCardState();
}

class _NextActionCardState extends ConsumerState<NextActionCard>
    with BookingActionRunner {
  BookingOut get booking => widget.booking;

  Future<void> _decide({required bool approve}) async {
    final bookings = ref.read(apiProvider).bookings;
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) => const _DeclineReasonDialog(),
      );
      if (reason == null) return;
    }
    await runAction(
      approve ? 'approve' : 'decline',
      (key) => approve
          ? bookings.approve(booking.id, idempotencyKey: key)
          : bookings.decline(
              booking.id,
              DeclineIn(reason: reason!.isEmpty ? null : reason),
              idempotencyKey: key,
            ),
      bookingId: booking.id,
      listingId: booking.listing.id,
      done: approve ? 'Request approved' : 'Request declined',
    );
  }

  /// Controls for the current step, if this card has any.
  Widget? _controls(String key) => switch (key) {
    'decide_request' => Row(
      children: [
        Expanded(
          child: AppButton.secondary(
            label: 'Decline',
            onPressed: busyAction == null
                ? () => _decide(approve: false)
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppButton(
            label: 'Approve',
            isLoading: busyAction == 'approve',
            onPressed: () => _decide(approve: true),
          ),
        ),
      ],
    ),
    'rate_cancellation' => CancellationRatingForm(booking: booking),
    'write_review' => AppButton(
      label: 'Write your review',
      icon: Icons.rate_review_outlined,
      onPressed: () => context.push(Routes.bookingReview(booking.id)),
    ),
    'waiting_review' when booking.reviews?.releaseAt != null => Text(
      'Or on ${formatIstDateTime(booking.reviews!.releaseAt!)} at the latest.',
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final action = booking.nextAction;
    if (action == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppSurfaces.of(context).accent;
    final mine = action.byMe;
    final hint = nextActionHint(action.key, booking.kind);
    final controls = _controls(action.key);
    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mine ? Icons.touch_app_outlined : Icons.hourglass_empty,
                size: AppSizes.iconMd - 2,
                color: mine ? accent : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  action.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mine ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (controls != null) ...[
            const SizedBox(height: AppSpacing.lg),
            controls,
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      label: mine ? 'Your next step' : 'Waiting on the other side',
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: mine ? scheme.surface : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: mine ? Border.all(color: scheme.outlineVariant) : null,
        ),
        child: mine
            ? Stack(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: body,
                  ),
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: ColoredBox(color: accent),
                  ),
                ],
              )
            : body,
      ),
    );
  }
}

class _DeclineReasonDialog extends StatefulWidget {
  const _DeclineReasonDialog();

  @override
  State<_DeclineReasonDialog> createState() => _DeclineReasonDialogState();
}

class _DeclineReasonDialogState extends State<_DeclineReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline this request?'),
      content: AppTextField(
        controller: _reason,
        label: 'Reason (optional)',
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}
