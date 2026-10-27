import 'package:flutter/material.dart';

import '../tokens.dart';

/// Tappable 1-5 star rating. Each star is a separate button with its own
/// accessible label, so screen-reader users can pick a value directly.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
    this.label = 'Rating',
  });

  /// Current rating 1-5, or null when nothing is selected.
  final int? value;

  /// Called with the tapped star (1-5). Null disables the input.
  final ValueChanged<int>? onChanged;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final unselected = Theme.of(context).colorScheme.outline;

    return Semantics(
      container: true,
      label: label,
      value: value == null ? 'Not rated' : '$value of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            IconButton(
              tooltip: star == 1 ? '1 star' : '$star stars',
              isSelected: value != null && star <= value,
              iconSize: size,
              icon: Icon(Icons.star_border_rounded, color: unselected),
              selectedIcon: const Icon(
                Icons.star_rounded,
                color: AppColors.star,
              ),
              onPressed: onChanged == null ? null : () => onChanged!(star),
            ),
        ],
      ),
    );
  }
}

/// Read-only star display with half-star precision and an optional count.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.count,
    this.size = AppSizes.iconSm,
  });

  /// Average rating, 0-5.
  final double rating;

  /// Number of ratings, shown in brackets when given.
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounded = (rating.clamp(0, 5) * 2).round() / 2;
    final ratingText = rounded.toStringAsFixed(1);
    final countText = count == null
        ? ''
        : ' from $count ${count == 1 ? 'rating' : 'ratings'}';

    return Semantics(
      label: 'Rated $ratingText out of 5$countText',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var star = 1; star <= 5; star++)
              Icon(
                rounded >= star
                    ? Icons.star_rounded
                    : rounded >= star - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
                size: size,
                color: AppColors.star,
              ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              count == null ? ratingText : '$ratingText ($count)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
