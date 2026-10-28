import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../review_format.dart';
import '../review_providers.dart';

/// Both sides' reviews for a booking, once revealed.
///
/// Reviews don't carry their booking id, so this shows the newest revealed
/// review between the two people in the booking's roles.
class BookingReviews extends StatelessWidget {
  const BookingReviews({super.key, required this.booking});

  final BookingOut booking;

  static bool appliesTo(BookingOut b) =>
      (b.reviews?.revealed ?? false) && b.role != BookingViewerRole.staff;

  @override
  Widget build(BuildContext context) {
    final isRenter = booking.role == BookingViewerRole.renter;
    final me = isRenter ? booking.renter : booking.owner;
    final other = isRenter ? booking.owner : booking.renter;
    final myRole = isRenter ? TrustRole.renter : TrustRole.lender;
    final theirRole = isRenter ? TrustRole.lender : TrustRole.renter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Reviews',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewCard(
          title: 'Their review of you',
          subject: me.accountId,
          role: myRole,
          reviewer: other.accountId,
          missing: '${other.fullName.split(' ').first} didn’t leave a review.',
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewCard(
          title: 'Your review of them',
          subject: other.accountId,
          role: theirRole,
          reviewer: me.accountId,
          missing: 'You didn’t leave a review.',
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({
    required this.title,
    required this.subject,
    required this.role,
    required this.reviewer,
    required this.missing,
  });

  final String title;
  final String subject;
  final TrustRole role;
  final String reviewer;
  final String missing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final page = ref.watch(profileReviewsProvider((subject, role)));
    return AppCard(
      child: page.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Couldn’t load this review.'),
        data: (p) {
          final review = p.items
              .where((r) => r.reviewerId == reviewer)
              .firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              if (review == null)
                Text(missing, style: theme.textTheme.bodyMedium)
              else ...[
                StarRatingDisplay(rating: review.overall),
                const SizedBox(height: AppSpacing.xs),
                for (final MapEntry(:key, :value) in review.ratings.entries)
                  Text(
                    '${reviewParameterLabel(key)}: $value/5',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text('“${review.comment}”', style: theme.textTheme.bodyLarge),
                Text(
                  formatIstDate(review.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
