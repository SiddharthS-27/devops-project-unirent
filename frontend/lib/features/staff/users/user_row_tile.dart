import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/routes.dart';
import '../staff_format.dart';
import '../widgets/risk_flags.dart';

/// A student in a staff list; opens their details.
class UserRowTile extends StatelessWidget {
  const UserRowTile({super.key, required this.user, this.onReturn});

  final StaffUserRow user;

  /// Runs after coming back from the details (e.g. to refresh the list).
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final trust = [
      if (u.lenderTrust != null) 'Lender ${u.lenderTrust}',
      if (u.renterTrust != null) 'Renter ${u.renterTrust}',
    ];
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(u.fullName ?? u.email),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              u.email,
              if (u.status != 'active') accountStatusLabel(u.status),
              ...trust,
            ].join(' · '),
          ),
          if (u.riskFlags.isNotEmpty) RiskFlagChips(flags: u.riskFlags),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await context.push(Routes.staffUser(u.accountId));
        onReturn?.call();
      },
    );
  }
}
