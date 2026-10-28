import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../ui/ui.dart';
import 'payment_launcher.dart';

/// Starts a payment for the chosen method; the key is one per tap.
typedef StartPayment =
    Future<PaymentOut> Function(PaymentMethod method, String idempotencyKey);

/// Paying for something by UPI (Razorpay) or cash.
///
/// Keys are kept per method so a retry after a network error reuses the
/// same one, while switching method starts a fresh attempt.
class PaymentFlow {
  PaymentFlow(this.ref);

  final WidgetRef ref;
  final _keys = <PaymentMethod, IdempotentAction>{};

  IdempotentAction _key(PaymentMethod method) => _keys.putIfAbsent(
    method,
    () => IdempotentAction(ref.read(idempotencyKeyFactoryProvider)),
  );

  /// Asks UPI or cash, starts the payment and, for UPI, runs Checkout and
  /// verifies it. Returns true when the booking changed.
  Future<bool> pay(
    BuildContext context, {
    required int amountPaise,
    required String what,
    required StartPayment start,
    bool allowCash = true,
  }) async {
    final method = allowCash
        ? await _chooseMethod(context, amountPaise, what)
        : PaymentMethod.upi;
    if (method == null || !context.mounted) return false;
    return payWith(context, method, start: start, amountPaise: amountPaise);
  }

  Future<bool> payWith(
    BuildContext context,
    PaymentMethod method, {
    required StartPayment start,
    required int amountPaise,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final PaymentOut payment;
    final key = _key(method);
    try {
      payment = await start(method, key.key);
    } on ApiException catch (error) {
      if (!error.isConnectivityProblem) key.reset();
      if (error.code == 'PAYEE_NOT_PAYOUT_READY' && context.mounted) {
        final cash = await _offerCash(context);
        if (cash && context.mounted) {
          return payWith(
            context,
            PaymentMethod.cash,
            start: start,
            amountPaise: amountPaise,
          );
        }
        return false;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      // Already paid or paid elsewhere: the booking has moved on.
      return error.code == 'ALREADY_PAID' ||
          error.code == 'PAYMENT_ALREADY_MADE';
    }
    key.reset();

    if (payment.method == PaymentMethod.cash) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Hand ${formatMoney(payment.amountPaise)} in cash to the owner. '
              'They’ll confirm it in the app.',
            ),
          ),
        );
      return true;
    }
    final checkout = payment.checkout;
    if (checkout == null || !context.mounted) return true;
    final result = await ref
        .read(paymentLauncherProvider)
        .pay(context, checkout);
    switch (result) {
      case CheckoutPaid(:final orderId, :final paymentId, :final signature):
        try {
          await ref
              .read(apiProvider)
              .payments
              .verifyPayment(
                payment.id,
                VerifyIn(
                  razorpayOrderId: orderId,
                  razorpayPaymentId: paymentId,
                  razorpaySignature: signature,
                ),
              );
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Paid ${formatMoney(payment.amountPaise)}'),
              ),
            );
        } on ApiException catch (error) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
        }
        return true;
      case CheckoutFailed(:final message):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Payment didn’t go through: $message')),
          );
        return true;
      case CheckoutCancelled():
        return false;
    }
  }

  Future<PaymentMethod?> _chooseMethod(
    BuildContext context,
    int amountPaise,
    String what,
  ) {
    return showModalBottomSheet<PaymentMethod>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Pay ${formatMoney(amountPaise)} for $what',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('UPI'),
              subtitle: const Text('Through Razorpay, straight to the owner'),
              onTap: () => Navigator.pop(context, PaymentMethod.upi),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Cash'),
              subtitle: const Text('Hand it over; the owner confirms it'),
              onTap: () => Navigator.pop(context, PaymentMethod.cash),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _offerCash(BuildContext context) async {
    final cash = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UPI isn’t available for this owner'),
        content: const Text(
          'They haven’t finished setting up payouts yet. You can pay in cash '
          'instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay in cash'),
          ),
        ],
      ),
    );
    return cash ?? false;
  }
}
