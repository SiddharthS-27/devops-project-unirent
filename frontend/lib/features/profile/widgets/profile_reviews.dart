import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';
import '../../reviews/review_format.dart';
import '../../reviews/review_providers.dart';

/// Someone's revealed reviews, as a lender or as a renter.
class ProfileReviews extends ConsumerStatefulWidget {
  const ProfileReviews({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<ProfileReviews> createState() => _ProfileReviewsState();
}

class _ProfileReviewsState extends ConsumerState<ProfileReviews> {
  TrustRole _role = TrustRole.lender;
  final _more = <ReviewOut>[];
  String? _cursor;
  bool _loadingMore = false;

  void _switch(TrustRole role) => setState(() {
    _role = role;
    _more.clear();
    _cursor = null;
  });

  Future<void> _loadMore(String cursor) async {
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(apiProvider)
          .reviews
          .reviewsOf(widget.accountId, role: _role, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _more.addAll(page.items);
        _cursor = page.nextCursor ?? '';
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = ref.watch(profileReviewsProvider((widget.accountId, _role)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Reviews', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<TrustRole>(
          segments: const [
            ButtonSegment(value: TrustRole.lender, label: Text('As lender')),
            ButtonSegment(value: TrustRole.renter, label: Text('As renter')),
          ],
          selected: {_role},
          onSelectionChanged: (s) => _switch(s.single),
        ),
        const SizedBox(height: AppSpacing.sm),
        first.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(friendlyMessage(error)),
          data: (page) {
            final items = [...page.items, ..._more];
            final next = _cursor ?? page.nextCursor;
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No reviews yet.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in items) _ReviewTile(review: r),
                if (next != null && next.isNotEmpty)
                  TextButton(
                    onPressed: _loadingMore ? null : () => _loadMore(next),
                    child: const Text('Show more'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ReviewOut review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.reviewerName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StarRatingDisplay(rating: review.overall),
            ],
          ),
          Text(
            '${reviewTypeLabel(review.reviewType)} · '
            '${formatIstDate(review.createdAt)}',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(review.comment),
          const Divider(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
