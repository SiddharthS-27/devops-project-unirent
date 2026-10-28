import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import '../bookings/booking_providers.dart';
import 'pending_reviews.dart';
import 'review_providers.dart';

/// The blind review of the other side. Compulsory: until it's in, Home and
/// search come back here.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(reviewFormProvider(bookingId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        leading: context.canPop()
            ? null
            : BackButton(
                onPressed: () => context.go(Routes.booking(bookingId)),
              ),
      ),
      body: form.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(reviewFormProvider(bookingId)),
        ),
        data: (f) => _ReviewForm(bookingId: bookingId, form: f),
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.bookingId, required this.form});

  final String bookingId;
  final ReviewForm form;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  final _ratings = <String, int>{};
  bool _submitted = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _allRated =>
      widget.form.parameters.every((p) => _ratings.containsKey(p.key));

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || !_allRated) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final state = await ref
          .read(apiProvider)
          .bookings
          .submitReview(
            widget.bookingId,
            ReviewIn(ratings: Map.of(_ratings), comment: _comment.text.trim()),
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              state.revealed
                  ? 'Thanks! Both reviews are now visible.'
                  : 'Thanks! You’ll see both reviews once they review you.',
            ),
          ),
        );
      await _leave(router);
    } on ApiException catch (error) {
      if (error.code == 'ALREADY_REVIEWED' || error.code == 'BOOKING_STATE') {
        await _leave(router);
        return;
      }
      if (mounted) {
        setState(
          () => _error = error.code == 'INVALID_RATINGS'
              ? 'Rate every item from 1 to 5 stars.'
              : friendlyMessage(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(GoRouter router) async {
    ref.invalidate(bookingProvider(widget.bookingId));
    await ref.read(pendingReviewsProvider.notifier).refresh();
    router.go(Routes.booking(widget.bookingId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = widget.form;
    final gated = ref
        .watch(pendingReviewsProvider)
        .any((b) => b.id == widget.bookingId);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (gated) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text(
                'Reviews keep UniRent trustworthy. Review this booking to '
                'carry on browsing.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            'How was ${f.counterpartyName}?',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Reviews are blind: they see yours only after reviewing you, or '
            '24 hours after the first review.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          // One child for all parameters: error lines appearing inside it
          // mustn't shift the list's later children (that would recreate
          // the comment field and drop its error).
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in f.parameters) ...[
                Text(p.label, style: theme.textTheme.titleSmall),
                StarRatingInput(
                  value: _ratings[p.key],
                  label: p.label,
                  onChanged: _busy
                      ? null
                      : (stars) => setState(() => _ratings[p.key] = stars),
                ),
                if (_submitted && !_ratings.containsKey(p.key))
                  Text(
                    'Choose 1 to 5 stars',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
          AppTextField(
            controller: _comment,
            label: 'Comment',
            hint: 'What should others know?',
            maxLines: 3,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v?.trim().length ?? 0) < 2 ? 'Write a short comment' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineError(_error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Submit review',
            isLoading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
