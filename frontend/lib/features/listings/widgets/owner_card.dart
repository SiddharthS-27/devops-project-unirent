import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';

/// The owner's name, trust, rating and cancellations, with a Call button.
class OwnerCardView extends StatelessWidget {
  const OwnerCardView({super.key, required this.owner, this.onCall});

  final OwnerCard owner;

  /// Shown as a Call button when set.
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = owner.lenderRating;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final cancellations = owner.cancellationCount;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(owner.fullName.isEmpty ? '?' : owner.fullName[0]),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(owner.fullName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TrustBadge(
                          score: owner.isNew ? null : owner.lenderTrust,
                        ),
                        if (rating != null) StarRatingDisplay(rating: rating),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            cancellations == 0
                ? 'No cancellations'
                : cancellations == 1
                ? '1 cancellation'
                : '$cancellations cancellations',
            style: muted,
          ),
          if (onCall != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'Call ${owner.fullName.split(' ').first}',
              icon: Icons.call_outlined,
              onPressed: onCall,
            ),
          ],
        ],
      ),
    );
  }
}
