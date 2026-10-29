import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../booking_actions.dart';

/// The renter starts the return when they meet the owner.
class StartReturnButton extends ConsumerStatefulWidget {
  const StartReturnButton({super.key, required this.booking});

  final BookingOut booking;

  @override
  ConsumerState<StartReturnButton> createState() => _StartReturnButtonState();
}

class _StartReturnButtonState extends ConsumerState<StartReturnButton>
    with BookingActionRunner {
  Future<void> _start() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start the return?'),
        content: Text(
          'Do this when you’re with the owner at '
          '${widget.booking.listing.pickupPoint}. You’ll both add photos, '
          'then you type the owner’s code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start return'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await runAction(
      'return',
      (key) => ref
          .read(apiProvider)
          .bookings
          .startReturn(widget.booking.id, idempotencyKey: key),
      bookingId: widget.booking.id,
      done: 'Return started',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Start the return',
      icon: Icons.assignment_return_outlined,
      isLoading: busyAction == 'return',
      onPressed: _start,
    );
  }
}
