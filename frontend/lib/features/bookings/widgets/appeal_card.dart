import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';

/// The booking's appeal: where it stands, and filing one while the booking
/// can be appealed.
class AppealCard extends StatelessWidget {
  const AppealCard({super.key, required this.booking});

  final BookingOut booking;

  static bool appliesTo(BookingOut b) => b.appeal != null || b.canAppeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appeal = booking.appeal;
    final (title, body) = switch (appeal?.status) {
      null => (null, null),
      AppealStatus.open => (
        'Appeal under review',
        'A moderator is looking at the handover photos and both sides’ '
            'notes. You’ll both be notified of the ruling.',
      ),
      AppealStatus.overruled => (
        'Ruling changed',
        'The admin changed the moderator’s ruling. Any refund shows under '
            'Payments.',
      ),
      _ => (
        'Appeal ruled',
        'A moderator has ruled on this booking. Any refund shows under '
            'Payments.',
      ),
    };
    final isSale = booking.kind == TradeKind.sale;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                const Icon(Icons.gavel_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(body!),
          ],
          if (title != null && booking.canAppeal)
            const Divider(height: AppSpacing.xl),
          if (booking.canAppeal) ...[
            if (title == null)
              Row(
                children: [
                  const Icon(Icons.gavel_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isSale
                          ? 'Not what was described?'
                          : 'Can’t agree on the charges?',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            if (title == null) const SizedBox(height: AppSpacing.xs),
            Text(
              isSale
                  ? 'You can appeal for 48 hours after the handover. A '
                        'moderator looks at the photos and decides.'
                  : 'Either of you can appeal before the booking moves on. '
                        'A moderator looks at the handover photos and '
                        'decides.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'File an appeal',
              icon: Icons.gavel_outlined,
              onPressed: () => context.push(Routes.bookingAppeal(booking.id)),
            ),
          ],
        ],
      ),
    );
  }
}
