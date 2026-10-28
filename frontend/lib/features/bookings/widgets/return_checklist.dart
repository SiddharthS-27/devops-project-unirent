import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';
import '../../payments/payment_flow.dart';
import '../booking_actions.dart';
import '../booking_providers.dart';
import '../handover_photos.dart';

/// The return: the renter's photos, the owner's inspection, the owner's
/// code typed by the renter, charges, and the owner's Proceed. Each step
/// unlocks from the server's state.
class ReturnChecklist extends ConsumerStatefulWidget {
  const ReturnChecklist({super.key, required this.booking});

  final BookingOut booking;

  static bool appliesTo(BookingOut b) =>
      b.status == BookingStatus.returning &&
      b.returnHandover != null &&
      b.role != BookingViewerRole.staff;

  @override
  ConsumerState<ReturnChecklist> createState() => _ReturnChecklistState();
}

class _ReturnChecklistState extends ConsumerState<ReturnChecklist>
    with BookingActionRunner {
  late final _payments = PaymentFlow(ref);
  final _otp = TextEditingController();
  OtpOut? _code;
  String? _otpError;

  BookingOut get booking => widget.booking;
  Handover get handover => booking.returnHandover!;
  bool get isRenter => booking.role == BookingViewerRole.renter;
  bool get itemBack => handover.otpVerifiedAt != null;
  Charges? get charges => booking.charges;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

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
            .returnPhotos(booking.id, PhotosIn(objectKeys: keys)),
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

  Future<void> _showCode() async {
    final code = await runAction(
      'code',
      (_) => ref.read(apiProvider).bookings.returnOtp(booking.id),
      bookingId: booking.id,
    );
    if (code != null && mounted) setState(() => _code = code);
  }

  Future<void> _verify(String code) async {
    final action = actionFor('verify');
    setState(() {
      busyAction = 'verify';
      _otpError = null;
    });
    try {
      await ref
          .read(apiProvider)
          .bookings
          .verifyReturnOtp(
            booking.id,
            OtpIn(code: code),
            idempotencyKey: action.key,
          );
      action.reset();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Return confirmed')));
      }
      refreshBooking(booking.id, listingId: booking.listing.id);
    } on ApiException catch (error) {
      if (!error.isConnectivityProblem) action.reset();
      _otp.clear();
      if (mounted) {
        setState(
          () => _otpError = switch (error.code) {
            'WRONG_CODE' => 'That code isn’t right. Check it and try again.',
            'CODE_EXPIRED' => 'That code expired. Ask the owner for a new one.',
            'RATE_LIMITED' =>
              'Too many tries for this code. Ask the owner for a new one.',
            'STEP_LOCKED' => 'Ask the owner to show their code first.',
            _ => friendlyMessage(error),
          },
        );
      }
    } finally {
      if (mounted) setState(() => busyAction = null);
    }
  }

  Future<void> _recordDamage() async {
    final damage = await showDialog<DamageChargeIn>(
      context: context,
      builder: (context) => _DamageDialog(current: charges),
    );
    if (damage == null) return;
    await runAction(
      'damage',
      (key) => ref
          .read(apiProvider)
          .bookings
          .recordDamageCharge(booking.id, damage, idempotencyKey: key),
      bookingId: booking.id,
      done: damage.amountPaise == 0
          ? 'No damage recorded'
          : 'Damage charge of ${formatMoney(damage.amountPaise)} recorded',
    );
  }

  Future<void> _pay() async {
    setState(() => busyAction = 'pay');
    try {
      final changed = await _payments.pay(
        context,
        amountPaise: charges!.totalPaise,
        what: 'the return charges',
        start: (method, key) => ref
            .read(apiProvider)
            .bookings
            .payReturnCharges(
              booking.id,
              PaymentStartIn(method: method),
              idempotencyKey: key,
            ),
      );
      if (changed) refreshBooking(booking.id);
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

  Future<void> _proceed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish this rental?'),
        content: const Text(
          'The item is back and everything is settled. You’ll both be asked '
          'to review each other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await runAction(
      'proceed',
      (key) => ref
          .read(apiProvider)
          .bookings
          .proceed(booking.id, idempotencyKey: key),
      bookingId: booking.id,
      listingId: booking.listing.id,
      done: 'Rental finished',
    );
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
    final renterDone = handover.renter.done;
    final ownerDone = handover.owner.done;
    final busy = busyAction != null;
    final c = charges;
    final payment = c?.payment;
    final settled = itemBack && (c == null || c.paid);
    final cashPending =
        payment != null &&
        payment.method == PaymentMethod.cash &&
        !(c?.paid ?? false);
    // "paid" is also true when nothing is owed; damage can still be added
    // until a charges payment has actually gone through.
    final chargesPaymentMade = switch (payment?.status) {
      PaymentStatus.captured || PaymentStatus.markedPaid => true,
      _ => false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Return', style: theme.textTheme.titleMedium),
        ),
        ChecklistStep(
          title: 'Renter’s return photos',
          subtitle: renterDone
              ? '${handover.renter.photos.length} added'
              : isRenter
              ? 'Photograph the item as you hand it back'
              : 'Waiting for the renter',
          state: _state(done: renterDone, available: isRenter),
          actionLabel: isRenter ? 'Add photos' : null,
          onAction: busy ? null : _addPhotos,
        ),
        ChecklistStep(
          title: 'Owner’s inspection photos',
          subtitle: ownerDone
              ? '${handover.owner.photos.length} added'
              : !renterDone
              ? 'After the renter’s photos'
              : isRenter
              ? 'The owner is checking the item'
              : 'Check the item and photograph its condition',
          state: _state(done: ownerDone, available: !isRenter && renterDone),
          actionLabel: isRenter ? null : 'Add photos',
          onAction: busy ? null : _addPhotos,
        ),
        ChecklistStep(
          title: isRenter ? 'Enter the owner’s code' : 'Show your code',
          subtitle: itemBack
              ? 'Return confirmed'
              : handover.otpReady
              ? (isRenter
                    ? 'Ask the owner for the code on their screen'
                    : 'The renter types it to confirm the return')
              : 'After both sets of photos',
          state: _state(done: itemBack, available: handover.otpReady),
          actionLabel: !isRenter && handover.otpReady
              ? (_code == null ? 'Show code' : 'New code')
              : null,
          onAction: busy ? null : _showCode,
        ),
        if (handover.otpReady && !itemBack) ...[
          const SizedBox(height: AppSpacing.md),
          if (!isRenter && _code != null)
            Center(
              child: OtpDisplay(
                code: _code!.code,
                expiresAt: _code!.expiresAt,
                serverOffset: ref.read(serverClockProvider).offset,
              ),
            ),
          if (isRenter)
            Center(
              child: OtpEntry(
                controller: _otp,
                enabled: busyAction != 'verify',
                errorText: _otpError,
                onCompleted: _verify,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        ChecklistStep(
          title: 'Charges',
          subtitle: !itemBack
              ? 'After the return is confirmed'
              : c == null || c.totalPaise == 0
              ? 'Nothing to pay'
              : c.paid
              ? '${formatMoney(c.totalPaise)} paid'
              : cashPending
              ? (isRenter
                    ? 'Hand over the cash; the owner confirms it'
                    : 'The renter is paying in cash')
              : '${formatMoney(c.totalPaise)} to pay',
          state: _state(done: settled, available: itemBack),
          actionLabel: !itemBack || settled
              ? null
              : isRenter
              ? (cashPending || (c?.totalPaise ?? 0) == 0 ? null : 'Pay')
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
        if (itemBack && c != null) _ChargesSummary(charges: c),
        if (itemBack && !isRenter && !chargesPaymentMade && !cashPending)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : _recordDamage,
              icon: const Icon(Icons.report_outlined),
              label: Text(
                (c?.damagePaise ?? 0) > 0
                    ? 'Change damage charge'
                    : 'Record damage',
              ),
            ),
          ),
        if (!isRenter)
          ChecklistStep(
            title: 'Proceed',
            subtitle: settled
                ? 'Finish the rental and open reviews'
                : 'Once the charges are settled',
            state: _state(done: false, available: settled),
            actionLabel: 'Proceed',
            onAction: busy ? null : _proceed,
          ),
      ],
    );
  }
}

/// Itemised return charges, as computed by the server.
class _ChargesSummary extends StatelessWidget {
  const _ChargesSummary({required this.charges});

  final Charges charges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, int)>[
      if (charges.lateFeePaise > 0) ('Late fee', charges.lateFeePaise),
      if (charges.damagePaise > 0)
        (
          'Damage${charges.damageDescription == null ? '' : ': ${charges.damageDescription}'}',
          charges.damagePaise,
        ),
      if (charges.cashExtensionsPaise > 0)
        ('Extra time (unpaid)', charges.cashExtensionsPaise),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxl),
      child: Column(
        children: [
          for (final (label, amount) in rows)
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(formatMoney(amount)),
              ],
            ),
          const Divider(),
          Row(
            children: [
              Expanded(child: Text('Total', style: theme.textTheme.titleSmall)),
              Text(
                formatMoney(charges.totalPaise),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The damage charge both sides agreed on.
class _DamageDialog extends StatefulWidget {
  const _DamageDialog({this.current});

  final Charges? current;

  @override
  State<_DamageDialog> createState() => _DamageDialogState();
}

class _DamageDialogState extends State<_DamageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: (widget.current?.damagePaise ?? 0) > 0
        ? '${widget.current!.damagePaise ~/ 100}'
        : '',
  );
  late final _description = TextEditingController(
    text: widget.current?.damageDescription ?? '',
  );

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record damage'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Agree the amount with the renter first. If you can’t agree, '
              'either of you can appeal from Help.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _amount,
              label: 'Amount',
              prefixText: '₹',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  int.tryParse(v ?? '') == null ? 'Enter an amount' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _description,
              label: 'What was damaged?',
              maxLines: 2,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v?.trim().length ?? 0) < 3 ? 'Describe the damage' : null,
            ),
          ],
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
              DamageChargeIn(
                amountPaise: int.parse(_amount.text) * 100,
                description: _description.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
