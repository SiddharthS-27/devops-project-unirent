import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';

/// After buying, the buyer can appeal for 48 hours if the item isn't as
/// described.
class AppealWindowNote extends StatelessWidget {
  const AppealWindowNote({super.key, required this.booking});

  final BookingOut booking;

  static bool appliesTo(BookingOut b) =>
      b.kind == TradeKind.sale &&
      b.role == BookingViewerRole.renter &&
      b.canAppeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Not what was described?',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'You can appeal for 48 hours after the handover. A moderator '
            'looks at the photos and decides.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  context.push(Routes.helpFor(bookingId: booking.id)),
              child: const Text('Get help with this purchase'),
            ),
          ),
        ],
      ),
    );
  }
}
