import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';

/// Trust as a lender and as a renter, with trades and cancellations.
class TrustSection extends StatelessWidget {
  const TrustSection({super.key, required this.profile});

  final ProfileView profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget row(String label, TrustSummary t) {
      final rating = t.rating;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(width: 96, child: Text(label, style: muted)),
            TrustBadge(score: profile.isNew ? null : t.score),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: rating == null
                  ? Text('No ratings yet', style: muted)
                  : StarRatingDisplay(rating: rating, count: t.reviewCount),
            ),
          ],
        ),
      );
    }

    final trades = profile.completedTrades;
    final cancellations = profile.cancellationCount;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('As a lender', profile.lender),
          row('As a renter', profile.renter),
          const Divider(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                trades == 1 ? '1 completed trade' : '$trades completed trades',
              ),
              Text(
                cancellations == 1
                    ? '1 cancellation'
                    : '$cancellations cancellations',
              ),
              Text(
                'Member since ${formatIstDate(profile.memberSince)}',
                style: muted,
              ),
            ],
          ),
          if (profile.isNew) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'New members get a trust score after 5 completed trades.',
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}
