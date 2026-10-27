import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Placeholder; payout linking comes in the next step.
class PayoutAccountScreen extends StatelessWidget {
  const PayoutAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout account')),
      body: const EmptyState(
        icon: Icons.account_balance_outlined,
        title: 'Link your payout account',
        message: 'Linking a bank account through Razorpay is coming soon.',
      ),
    );
  }
}
