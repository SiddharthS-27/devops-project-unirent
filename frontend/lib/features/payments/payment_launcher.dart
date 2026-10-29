import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../api/api.dart';
import '../../app/env.dart';
import '../../ui/ui.dart';

/// What Checkout handed back.
sealed class CheckoutResult {
  const CheckoutResult();
}

/// Paid: send these to `/payments/{id}/verify`.
class CheckoutPaid extends CheckoutResult {
  const CheckoutPaid({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

class CheckoutFailed extends CheckoutResult {
  const CheckoutFailed(this.message);

  final String message;
}

class CheckoutCancelled extends CheckoutResult {
  const CheckoutCancelled();
}

/// Takes the payer through a Razorpay UPI checkout.
abstract interface class PaymentLauncher {
  Future<CheckoutResult> pay(BuildContext context, RazorpayCheckout checkout);
}

/// Real Razorpay Checkout via razorpay_flutter.
class RazorpayCheckoutLauncher implements PaymentLauncher {
  @override
  Future<CheckoutResult> pay(
    BuildContext context,
    RazorpayCheckout checkout,
  ) async {
    final razorpay = Razorpay();
    final result = Completer<CheckoutResult>();
    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        if (result.isCompleted) return;
        final (order, payment, signature) = (
          r.orderId,
          r.paymentId,
          r.signature,
        );
        result.complete(
          order == null || payment == null || signature == null
              ? const CheckoutFailed('Razorpay didn’t confirm the payment.')
              : CheckoutPaid(
                  orderId: order,
                  paymentId: payment,
                  signature: signature,
                ),
        );
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        if (result.isCompleted) return;
        result.complete(
          r.code == Razorpay.PAYMENT_CANCELLED
              ? const CheckoutCancelled()
              : CheckoutFailed(r.message ?? 'The payment didn’t go through.'),
        );
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {
        if (!result.isCompleted) {
          result.complete(
            const CheckoutFailed('Pay with UPI; wallets aren’t supported.'),
          );
        }
      });
    try {
      razorpay.open({
        'key': checkout.keyId,
        'order_id': checkout.orderId,
        'amount': checkout.amountPaise,
        'currency': checkout.currency,
        'name': checkout.name,
        'description': checkout.description,
        'prefill': {
          'email': ?checkout.prefillEmail,
          'contact': ?checkout.prefillContact,
        },
        'method': {'upi': true},
      });
      return await result.future;
    } finally {
      razorpay.clear();
    }
  }
}

/// Completes an order on a Razorpay simulator: returns what Checkout would
/// hand the app (`razorpay_*` fields) or an `{"error": ...}` body.
typedef SimulatePayment =
    Future<Map<String, Object?>> Function(String orderId, {required bool fail});

/// Calls the local simulator (`RAZORPAY_SIM_URL`).
SimulatePayment httpSimulator(String baseUrl) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  return (orderId, {required fail}) async {
    final response = await dio.post<Map<String, Object?>>(
      '/sim/orders/${Uri.encodeComponent(orderId)}/pay',
      data: fail ? {'outcome': 'failed'} : <String, Object?>{},
    );
    return response.data ?? const {};
  };
}

/// A "Simulated UPI" sheet standing in for Checkout in development.
class SimulatedUpiLauncher implements PaymentLauncher {
  SimulatedUpiLauncher(this.simulate);

  final SimulatePayment simulate;

  @override
  Future<CheckoutResult> pay(
    BuildContext context,
    RazorpayCheckout checkout,
  ) async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SimulatedUpiSheet(checkout: checkout),
    );
    if (choice == null) return const CheckoutCancelled();
    try {
      final body = await simulate(checkout.orderId, fail: !choice);
      return switch (body) {
        {
          'razorpay_order_id': final String order,
          'razorpay_payment_id': final String payment,
          'razorpay_signature': final String signature,
        } =>
          CheckoutPaid(
            orderId: order,
            paymentId: payment,
            signature: signature,
          ),
        {'error': {'description': final String description}} => CheckoutFailed(
          description,
        ),
        _ => const CheckoutFailed('The payment didn’t go through.'),
      };
    } on DioException {
      return const CheckoutFailed('Couldn’t reach the payment simulator.');
    }
  }
}

class _SimulatedUpiSheet extends StatelessWidget {
  const _SimulatedUpiSheet({required this.checkout});

  final RazorpayCheckout checkout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Simulated UPI', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Development build: no real money moves.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(checkout.description),
            Text(
              formatMoney(checkout.amountPaise),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Pay ${formatMoney(checkout.amountPaise)}',
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: 'Decline payment',
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

final paymentLauncherProvider = Provider<PaymentLauncher>((ref) {
  final mock = ref.watch(mockServerProvider);
  if (mock != null) return SimulatedUpiLauncher(mock.simulatePayment);
  final env = ref.watch(appEnvProvider);
  return switch (env.razorpayMode) {
    RazorpayMode.checkout => RazorpayCheckoutLauncher(),
    RazorpayMode.sim => SimulatedUpiLauncher(httpSimulator(env.razorpaySimUrl)),
  };
});
