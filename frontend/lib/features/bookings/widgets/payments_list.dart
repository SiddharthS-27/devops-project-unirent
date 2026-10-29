import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../booking_format.dart';

/// Payments made on a booking, newest first.
class PaymentsList extends StatelessWidget {
  const PaymentsList({super.key, required this.payments});

  final List<PaymentOut> payments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...payments]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      children: [
        for (final p in sorted)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              p.method == PaymentMethod.cash
                  ? Icons.payments_outlined
                  : Icons.qr_code_2,
            ),
            title: Text(paymentPurposeLabel(p.purpose)),
            subtitle: Text(
              [
                if (p.method == PaymentMethod.cash) 'Cash' else 'UPI',
                paymentStatusLabel(p.status),
                if (p.capturedAt case final at?) formatIstDateTime(at),
              ].join(' · '),
            ),
            trailing: Text(
              formatMoney(p.amountPaise),
              style: theme.textTheme.titleSmall,
            ),
          ),
      ],
    );
  }
}
