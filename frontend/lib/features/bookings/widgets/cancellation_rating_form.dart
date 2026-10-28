import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../booking_actions.dart';

/// Stars and a comment for the other side's cancellation.
class CancellationRatingForm extends ConsumerStatefulWidget {
  const CancellationRatingForm({super.key, required this.booking});

  final BookingOut booking;

  @override
  ConsumerState<CancellationRatingForm> createState() =>
      _CancellationRatingFormState();
}

class _CancellationRatingFormState extends ConsumerState<CancellationRatingForm>
    with BookingActionRunner {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  int? _stars;
  bool _submitted = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate() || _stars == null) return;
    await runAction(
      'rate',
      (_) => ref
          .read(apiProvider)
          .bookings
          .rateCancellation(
            widget.booking.id,
            CancellationRatingIn(stars: _stars!, comment: _comment.text.trim()),
          ),
      bookingId: widget.booking.id,
      done: 'Thanks for rating',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StarRatingInput(
            value: _stars,
            label: 'Cancellation rating',
            onChanged: busyAction == null
                ? (stars) => setState(() => _stars = stars)
                : null,
          ),
          if (_submitted && _stars == null)
            Text(
              'Choose 1 to 5 stars',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _comment,
            label: 'Comment',
            hint: 'e.g. Told me early, no problem',
            maxLines: 2,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v?.trim().length ?? 0) < 2 ? 'Write a short comment' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Submit rating',
            isLoading: busyAction == 'rate',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
