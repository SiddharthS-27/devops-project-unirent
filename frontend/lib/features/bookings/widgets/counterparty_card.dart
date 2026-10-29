import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../booking_format.dart';

/// The other side of a booking: trust for their role, rating, phone (Call)
/// and, once the booking is approved, where they stay.
class CounterpartyCard extends StatelessWidget {
  const CounterpartyCard({
    super.key,
    required this.profile,
    required this.isOwner,
    this.isSale = false,
    this.onCall,
  });

  final ProfileView profile;

  /// Whether [profile] is the owner (shows lender trust) or the renter.
  final bool isOwner;

  /// Labels the sides seller and buyer instead of owner and renter.
  final bool isSale;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trust = isOwner ? profile.lender : profile.renter;
    final rating = trust.rating;
    final residence = switch (profile) {
      ProfileCounterparty(:final residence) => residenceLabel(residence),
      ProfileStaff(:final residence) => residenceLabel(residence),
      _ => null,
    };
    final cancellations = profile.cancellationCount;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch ((isOwner, isSale)) {
              (true, false) => 'Owner',
              (false, false) => 'Renter',
              (true, true) => 'Seller',
              (false, true) => 'Buyer',
            },
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: () => context.push(Routes.person(profile.accountId)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    profile.fullName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconSm,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TrustBadge(score: profile.isNew ? null : trust.score),
              if (rating != null)
                StarRatingDisplay(rating: rating, count: trust.reviewCount),
              Text(
                cancellations == 1
                    ? '1 cancellation'
                    : '$cancellations cancellations',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (residence != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.home_outlined, size: AppSizes.iconSm),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(residence)),
              ],
            ),
          ],
          if (onCall != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'Call ${profile.fullName.split(' ').first}',
              icon: Icons.call_outlined,
              onPressed: onCall,
            ),
          ],
        ],
      ),
    );
  }
}
