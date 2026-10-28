import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../booking_actions.dart';
import '../booking_providers.dart';
import 'start_return_button.dart';

/// Shown while the item is overdue. The late fee comes from the server and
/// is refetched every minute; the app never computes it.
class OverdueBanner extends ConsumerStatefulWidget {
  const OverdueBanner({super.key, required this.booking});

  final BookingOut booking;

  static bool appliesTo(BookingOut b) =>
      b.status == BookingStatus.overdue && b.role != BookingViewerRole.staff;

  @override
  ConsumerState<OverdueBanner> createState() => _OverdueBannerState();
}

class _OverdueBannerState extends ConsumerState<OverdueBanner>
    with BookingActionRunner {
  Timer? _refresh;

  BookingOut get booking => widget.booking;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.invalidate(bookingProvider(booking.id)),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _escalate() async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => const _EscalateDialog(),
    );
    if (note == null) return;
    await runAction(
      'escalate',
      (_) => ref
          .read(apiProvider)
          .bookings
          .escalate(booking.id, EscalateIn(note: note.isEmpty ? null : note)),
      bookingId: booking.id,
      done: 'Escalated. A moderator will contact you both.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final isRenter = booking.role == BookingViewerRole.renter;
    final fee = booking.charges?.lateFeePaise ?? 0;
    final since = booking.overdueSince;
    final escalateAt = booking.escalationAvailableAt;
    final serverNow = DateTime.now().add(ref.read(serverClockProvider).offset);
    final waitingToEscalate =
        escalateAt != null && escalateAt.isAfter(serverNow);
    final onColor = status.onDangerContainer;
    final text = theme.textTheme.bodyMedium?.copyWith(color: onColor);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: status.dangerContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: onColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Overdue',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onColor,
                    ),
                  ),
                ),
              ],
            ),
            if (since != null)
              Text('Since ${formatIstDateTime(since)}', style: text),
            const SizedBox(height: AppSpacing.sm),
            Text(
              fee > 0
                  ? 'Late fee so far: ${formatMoney(fee)}'
                  : 'No late fee yet',
              style: theme.textTheme.titleLarge?.copyWith(color: onColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isRenter) ...[
              Text(
                'Return the item now. The late fee grows every hour.',
                style: text,
              ),
              const SizedBox(height: AppSpacing.md),
              StartReturnButton(booking: booking),
            ] else if (booking.canEscalate) ...[
              Text(
                'Over an hour late. Moderators can contact the renter.',
                style: text,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.destructive(
                label: 'Escalate to moderators',
                icon: Icons.flag_outlined,
                isLoading: busyAction == 'escalate',
                onPressed: _escalate,
              ),
            ] else if (waitingToEscalate)
              Text(
                'You can escalate to the moderators from '
                '${formatIstTime(escalateAt)}. Until then, call the renter '
                'or use Help.',
                style: text,
              )
            else
              Text(
                'Escalated to the moderators. They’ll contact you both.',
                style: text,
              ),
          ],
        ),
      ),
    );
  }
}

class _EscalateDialog extends StatefulWidget {
  const _EscalateDialog();

  @override
  State<_EscalateDialog> createState() => _EscalateDialogState();
}

class _EscalateDialogState extends State<_EscalateDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escalate to moderators?'),
      content: AppTextField(
        controller: _note,
        label: 'Note for the moderators (optional)',
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: const Text('Escalate'),
        ),
      ],
    );
  }
}
