import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/push_service.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart' hide TimelineStep, TimelineStepState;
import '../../ui/widgets/status_timeline.dart' as ui;
import '../listings/listing_providers.dart';
import '../listings/widgets/listing_photo.dart';
import 'booking_format.dart';
import 'booking_providers.dart';
import 'widgets/counterparty_card.dart';
import 'widgets/next_action_card.dart';
import 'widgets/payments_list.dart';

/// One booking, shared by the renter (Bookings tab) and owner (Listings).
class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A push about this booking means it changed: fetch it again.
    ref.listen(pushReceivedProvider, (_, next) {
      final link = next.value;
      if (link != null &&
          deepLinkToLocation(link)?.path == Routes.booking(bookingId)) {
        ref.invalidate(bookingProvider(bookingId));
      }
    });
    final booking = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        // Opened from a deep link there is nothing to pop back to.
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(Routes.bookings)),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => context.push(Routes.help),
          ),
        ],
      ),
      body: booking.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        ),
        data: (b) => RefreshIndicator(
          onRefresh: () => ref.refresh(bookingProvider(bookingId).future),
          child: _BookingView(booking: b),
        ),
      ),
    );
  }
}

class _BookingView extends ConsumerWidget {
  const _BookingView({required this.booking});

  final BookingOut booking;

  ui.TimelineStepState _state(TimelineStepState s) => switch (s) {
    TimelineStepState.done ||
    TimelineStepState.skipped => ui.TimelineStepState.done,
    TimelineStepState.current => ui.TimelineStepState.current,
    _ => ui.TimelineStepState.upcoming,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: AppSpacing.xl);
    final isRenter = booking.role == BookingViewerRole.renter;
    final other = isRenter ? booking.owner : booking.renter;
    final phone = other.phone;
    final showOther = booking.role != BookingViewerRole.staff;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        _Header(booking: booking),
        gap,
        NextActionCard(booking: booking),
        if (booking.nextAction != null) gap,
        Semantics(
          header: true,
          child: Text('Progress', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.md),
        ui.StatusTimeline(
          steps: [
            for (final s in booking.timeline)
              ui.TimelineStep(
                title: s.label,
                state: _state(s.state),
                subtitle: s.at == null ? null : formatIstDateTime(s.at!),
              ),
          ],
        ),
        if (showOther) ...[
          gap,
          CounterpartyCard(
            profile: other,
            isOwner: isRenter,
            onCall: phone == null
                ? null
                : () => ref.read(phoneCallerProvider)(phone),
          ),
        ],
        if (booking.payments.isNotEmpty) ...[
          gap,
          Semantics(
            header: true,
            child: Text('Payments', style: theme.textTheme.titleMedium),
          ),
          PaymentsList(payments: booking.payments),
        ],
        gap,
        AppButton.secondary(
          label: 'Get help with this booking',
          icon: Icons.support_agent_outlined,
          onPressed: () => context.push(Routes.help),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.booking});

  final BookingOut booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listing = booking.listing;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: () => context.push(Routes.listing(listing.id)),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 72,
            child: ListingPhoto(
              url: listing.photoUrl,
              category: listing.category,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  bookingWhen(booking.kind, booking.startAt, booking.endAt),
                  style: muted,
                ),
                Text(
                  '${formatMoney(booking.amountPaise)} · '
                  '${bookingStatusLabel(booking.status)}',
                  style: muted,
                ),
                Text('Pickup: ${listing.pickupPoint}', style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
