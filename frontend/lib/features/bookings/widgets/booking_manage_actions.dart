import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../booking_actions.dart';

/// Withdraw a pending request, or cancel an approved booking with a note.
class BookingManageActions extends ConsumerStatefulWidget {
  const BookingManageActions({super.key, required this.booking});

  final BookingOut booking;

  /// Whether there is anything to show for [booking].
  static bool appliesTo(BookingOut b) =>
      b.canCancel ||
      (b.role == BookingViewerRole.renter &&
          b.status == BookingStatus.requested);

  @override
  ConsumerState<BookingManageActions> createState() =>
      _BookingManageActionsState();
}

class _BookingManageActionsState extends ConsumerState<BookingManageActions>
    with BookingActionRunner {
  BookingOut get booking => widget.booking;

  String get _otherName {
    final other = booking.role == BookingViewerRole.renter
        ? booking.owner
        : booking.renter;
    return other.fullName.split(' ').first;
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw your request?'),
        content: const Text('The owner won’t be able to approve it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await runAction(
      'withdraw',
      (key) => ref
          .read(apiProvider)
          .bookings
          .withdraw(booking.id, idempotencyKey: key),
      bookingId: booking.id,
      listingId: booking.listing.id,
      done: 'Request withdrawn',
    );
  }

  Future<void> _cancel() async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => CancelBookingDialog(otherName: _otherName),
    );
    if (note == null) return;
    await runAction(
      'cancel',
      (key) => ref
          .read(apiProvider)
          .bookings
          .cancel(booking.id, CancelIn(note: note), idempotencyKey: key),
      bookingId: booking.id,
      listingId: booking.listing.id,
      done: 'Booking cancelled',
    );
  }

  @override
  Widget build(BuildContext context) {
    final withdraw =
        booking.role == BookingViewerRole.renter &&
        booking.status == BookingStatus.requested;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (withdraw)
          AppButton.secondary(
            label: 'Withdraw request',
            icon: Icons.undo,
            isLoading: busyAction == 'withdraw',
            onPressed: _withdraw,
          ),
        if (booking.canCancel)
          AppButton.secondary(
            label: 'Cancel booking',
            icon: Icons.event_busy_outlined,
            isLoading: busyAction == 'cancel',
            onPressed: _cancel,
          ),
      ],
    );
  }
}

/// Asks why the booking is being cancelled; returns the note.
class CancelBookingDialog extends StatefulWidget {
  const CancelBookingDialog({super.key, required this.otherName});

  final String otherName;

  @override
  State<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<CancelBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel this booking?'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.otherName} will see your note and rate the '
              'cancellation. Cancellations show on your profile.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _note,
              label: 'Why are you cancelling?',
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v?.trim().length ?? 0) < 5
                  ? 'Write at least 5 characters'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep booking'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _note.text.trim());
            }
          },
          child: const Text('Cancel booking'),
        ),
      ],
    );
  }
}
