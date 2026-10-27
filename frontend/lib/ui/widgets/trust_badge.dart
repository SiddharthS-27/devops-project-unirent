import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum TrustBand { high, medium, low }

/// Band for a 0-100 trust score: 80+ high, 50-79 medium, below 50 low.
TrustBand trustBandFor(int score) {
  if (score >= 80) return TrustBand.high;
  if (score >= 50) return TrustBand.medium;
  return TrustBand.low;
}

/// Pill showing a user's trust score coloured by band, or "New" when the
/// user has no score yet.
class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key, required this.score});

  /// 0-100, or null for users without enough history.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final score = this.score?.clamp(0, 100);

    final (Color background, Color foreground) = switch (score == null
        ? null
        : trustBandFor(score)) {
      null => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      TrustBand.high => (status.successContainer, status.onSuccessContainer),
      TrustBand.medium => (status.warningContainer, status.onWarningContainer),
      TrustBand.low => (status.dangerContainer, status.onDangerContainer),
    };

    return Semantics(
      label: score == null
          ? 'New member, no trust score yet'
          : 'Trust score $score out of 100',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  score == null
                      ? Icons.fiber_new_outlined
                      : Icons.verified_user,
                  size: AppSizes.iconSm,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  score == null ? 'New' : '$score',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
