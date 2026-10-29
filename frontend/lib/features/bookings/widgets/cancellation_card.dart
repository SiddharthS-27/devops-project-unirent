import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';

/// Who cancelled, when, and the note they left.
class CancellationCard extends StatelessWidget {
  const CancellationCard({super.key, required this.booking});

  final BookingOut booking;

  @override
  Widget build(BuildContext context) {
    final c = booking.cancellation!;
    final theme = Theme.of(context);
    final byMe = switch (booking.role) {
      BookingViewerRole.renter => c.by == TradeRole.renter,
      BookingViewerRole.owner => c.by == TradeRole.owner,
      _ => false,
    };
    final canceller = c.by == TradeRole.owner ? booking.owner : booking.renter;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_outlined, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  byMe ? 'You cancelled' : '${canceller.fullName} cancelled',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(formatIstDateTime(c.at), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text('“${c.note}”', style: theme.textTheme.bodyLarge),
          if (byMe) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'They’ve been asked to rate the cancellation.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
