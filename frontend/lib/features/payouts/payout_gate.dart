import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';

/// Explains why a payout account is needed and offers to link one.
Future<void> showPayoutRequiredDialog(BuildContext context) async {
  final link = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.account_balance_outlined),
      title: const Text('Link your payout account first'),
      content: const Text(
        'Rent and sale payments go straight to your bank account through '
        'Razorpay. Link an account once, then you can list items.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Link account'),
        ),
      ],
    ),
  );
  if (link == true && context.mounted) {
    await context.push(Routes.payoutAccount);
  }
}
