import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../../listings/widgets/listing_photo.dart';
import '../booking_format.dart';

/// A booking in a list: item, other person, when, amount and what's next.
class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.booking, required this.onTap});

  final BookingSummary booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final action = booking.nextAction;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 72,
            child: ListingPhoto(
              url: booking.listingPhotoUrl,
              category: ListingCategory.other,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.listingTitle,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${booking.role == TradeRole.renter ? 'From' : 'To'} '
                  '${booking.counterpartyName} · '
                  '${formatMoney(booking.amountPaise)}',
                  style: muted,
                ),
                Text(
                  bookingWhen(booking.kind, booking.startAt, booking.endAt),
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (action != null)
                  Text(
                    action.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: action.byMe ? scheme.primary : scheme.onSurface,
                    ),
                  )
                else
                  Text(bookingStatusLabel(booking.status), style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
