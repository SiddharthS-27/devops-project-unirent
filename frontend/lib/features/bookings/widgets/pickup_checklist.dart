import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';
import '../../payments/payment_flow.dart';
import '../booking_actions.dart';
import '../booking_providers.dart';
import '../handover_photos.dart';

/// The handover checklist after approval: photos from both sides, payment,
/// then the code. Each step unlocks only from the server's state.
class PickupChecklist extends ConsumerStatefulWidget {
  const PickupChecklist({super.key, required this.booking});

  final BookingOut booking;

  static bool appliesTo(BookingOut b) =>
      b.status == BookingStatus.approved &&
      b.pickup != null &&
      b.role != BookingViewerRole.staff;

  @override
  ConsumerState<PickupChecklist> createState() => _PickupChecklistState();
}

class _PickupChecklistState extends ConsumerState<PickupChecklist>
    with BookingActionRunner {
  late final _payments = PaymentFlow(ref);
  final _otp = TextEditingController();
  OtpOut? _code;
  String? _otpError;

  BookingOut get booking => widget.booking;
  Handover get pickup => booking.pickup!;
  bool get isRenter => booking.role == BookingViewerRole.renter;
  bool get isSale => booking.kind == TradeKind.sale;

  PaymentPurpose get _purpose =>
      isSale ? PaymentPurpose.sale : PaymentPurpose.rent;

  /// The live payment for the handover, if one was started.
  PaymentOut? get _payment => booking.payments
      .where((p) => p.purpose == _purpose && p.status != PaymentStatus.failed)
      .lastOrNull;

  bool get _paid => switch (_payment?.status) {
    PaymentStatus.captured || PaymentStatus.markedPaid => true,
    _ => false,
  };

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  void _refresh() => refreshBooking(booking.id, listingId: booking.listing.id);

  Future<void> _addPhotos() async {
    setState(() => busyAction = 'photos');
    try {
      final keys = await pickAndUploadHandoverPhotos(context, ref);
      if (keys == null || !mounted) return;
      await runAction(
        'photos',
        (_) => ref
            .read(apiProvider)
            .bookings
            .pickupPhotos(booking.id, PhotosIn(objectKeys: keys)),
        bookingId: booking.id,
        done: 'Photos added',
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      }
    } finally {
      if (mounted) setState(() => busyAction = null);
    }
  }

  Future<void> _pay() async {
    setState(() => busyAction = 'pay');
    try {
      final changed = await _payments.pay(
        context,
        amountPaise: booking.amountPaise,
        what: isSale ? 'the item' : 'the rent',
        start: (method, key) => ref
            .read(apiProvider)
            .bookings
            .pickupPayment(
              booking.id,
              PaymentStartIn(method: method),
              idempotencyKey: key,
            ),
      );
      if (changed) _refresh();
    } finally {
      if (mounted) setState(() => busyAction = null);
    }
  }

  Future<void> _markCash(PaymentOut payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark cash received?'),
        content: Text(
          'Only confirm once you have ${formatMoney(payment.amountPaise)} '
          'in hand.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I have the cash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await runAction(
      'cash',
      (_) => ref.read(apiProvider).payments.markCashPaid(payment.id),
      bookingId: booking.id,
      done: 'Cash marked as received',
    );
  }

  Future<void> _showCode() async {
    final code = await runAction(
      'code',
      (_) => ref.read(apiProvider).bookings.pickupOtp(booking.id),
      bookingId: booking.id,
    );
    if (code != null && mounted) setState(() => _code = code);
  }

  Future<void> _verify(String code) async {
    setState(() => _otpError = null);
    final action = actionFor('verify');
    setState(() => busyAction = 'verify');
    try {
      await ref
          .read(apiProvider)
          .bookings
          .verifyPickupOtp(
            booking.id,
            OtpIn(code: code),
            idempotencyKey: action.key,
          );
      action.reset();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(isSale ? 'Handover complete' : 'Rental started'),
            ),
          );
      }
      _refresh();
    } on ApiException catch (error) {
      if (!error.isConnectivityProblem) action.reset();
      _otp.clear();
      if (mounted) {
        setState(
          () => _otpError = switch (error.code) {
            'WRONG_CODE' => 'That code isn’t right. Check it and try again.',
            'CODE_EXPIRED' =>
              'That code expired. Ask the renter for a new one.',
            'RATE_LIMITED' =>
              'Too many tries for this code. Ask the renter for a new one.',
            'STEP_LOCKED' => 'Ask the renter to show their code first.',
            _ => friendlyMessage(error),
          },
        );
      }
    } finally {
      if (mounted) setState(() => busyAction = null);
    }
  }

  ChecklistStepState _state({required bool done, required bool available}) =>
      done
      ? ChecklistStepState.done
      : available
      ? ChecklistStepState.available
      : ChecklistStepState.locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = isRenter ? pickup.renter : pickup.owner;
    final theirs = isRenter ? pickup.owner : pickup.renter;
    final other = isRenter ? 'owner' : 'renter';
    final photosDone = pickup.renter.done && pickup.owner.done;
    final payment = _payment;
    final cashPending =
        payment != null && payment.method == PaymentMethod.cash && !_paid;
    final verified = pickup.otpVerifiedAt != null;
    final busy = busyAction != null;

    String paymentSubtitle() {
      if (_paid) {
        return payment!.method == PaymentMethod.cash
            ? 'Paid in cash'
            : 'Paid by UPI';
      }
      if (!photosDone) return 'After both of you add photos';
      if (cashPending) {
        return isRenter
            ? 'Hand over the cash; the owner confirms it'
            : 'The renter is paying ${formatMoney(payment.amountPaise)} in cash';
      }
      return isRenter
          ? '${formatMoney(booking.amountPaise)} by UPI or cash'
          : 'Waiting for the renter to pay';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            isSale ? 'Handover' : 'Pickup',
            style: theme.textTheme.titleMedium,
          ),
        ),
        ChecklistStep(
          title: 'Your photos',
          subtitle: mine.done
              ? '${mine.photos.length} added'
              : 'Photograph the item before it changes hands',
          state: _state(done: mine.done, available: true),
          actionLabel: busyAction == 'photos' ? 'Uploading…' : 'Add photos',
          onAction: busy ? null : _addPhotos,
        ),
        ChecklistStep(
          title: 'The $other’s photos',
          subtitle: theirs.done
              ? '${theirs.photos.length} added'
              : 'Waiting for the $other',
          state: _state(done: theirs.done, available: false),
        ),
        ChecklistStep(
          title: 'Payment',
          subtitle: paymentSubtitle(),
          state: _state(
            done: _paid,
            available: photosDone && (isRenter ? !cashPending : cashPending),
          ),
          actionLabel: isRenter
              ? 'Pay'
              : cashPending
              ? 'Mark cash received'
              : null,
          onAction: busy
              ? null
              : isRenter
              ? _pay
              : cashPending
              ? () => _markCash(payment)
              : null,
        ),
        ChecklistStep(
          title: isRenter ? 'Show your code' : 'Enter the renter’s code',
          subtitle: verified
              ? 'Handover confirmed'
              : pickup.otpReady
              ? (isRenter
                    ? 'The owner types it to confirm the handover'
                    : 'Ask the renter for the code on their screen')
              : 'After the payment',
          state: _state(done: verified, available: pickup.otpReady),
          actionLabel: isRenter && pickup.otpReady
              ? (_code == null ? 'Show code' : 'New code')
              : null,
          onAction: busy ? null : _showCode,
        ),
        if (pickup.otpReady && !verified) ...[
          const SizedBox(height: AppSpacing.md),
          if (isRenter && _code != null)
            Center(
              child: OtpDisplay(
                code: _code!.code,
                expiresAt: _code!.expiresAt,
                serverOffset: ref.read(serverClockProvider).offset,
              ),
            ),
          if (!isRenter)
            Center(
              child: OtpEntry(
                controller: _otp,
                enabled: busyAction != 'verify',
                errorText: _otpError,
                onCompleted: _verify,
              ),
            ),
        ],
      ],
    );
  }
}
