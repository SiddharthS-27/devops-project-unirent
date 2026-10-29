import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import '../listings/listing_providers.dart';
import 'booking_format.dart';
import 'booking_providers.dart';

/// Requests waiting for the owner, for one listing or all of them.
class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key, this.listingId});

  final String? listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider(listingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Booking requests')),
      body: requests.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(incomingRequestsProvider(listingId)),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No requests waiting',
                message: 'New booking requests show up here.',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(incomingRequestsProvider(listingId).future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => _RequestCard(
                    request: items[i],
                    showListing: listingId == null,
                  ),
                ),
              ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request, required this.showListing});

  final BookingSummary request;
  final bool showListing;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  late final _approve = IdempotentAction(
    ref.read(idempotencyKeyFactoryProvider),
  );
  late final _decline = IdempotentAction(
    ref.read(idempotencyKeyFactoryProvider),
  );
  bool _busy = false;

  BookingSummary get request => widget.request;

  void _refreshLists() {
    ref
      ..invalidate(incomingRequestsProvider)
      ..invalidate(listingDetailProvider(request.listingId))
      ..invalidate(myBookingsProvider);
  }

  Future<void> _run(
    IdempotentAction action,
    Future<BookingOut> Function(String key) call,
    String done,
  ) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final booking = await call(action.key);
      action.reset();
      messenger.showSnackBar(
        SnackBar(
          content: Text(done),
          action: booking.status == BookingStatus.approved
              ? SnackBarAction(
                  label: 'Open',
                  onPressed: () => context.push(Routes.booking(booking.id)),
                )
              : null,
        ),
      );
      _refreshLists();
    } on ApiException catch (error) {
      if (!error.isConnectivityProblem) action.reset();
      messenger.showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      if (error.code == 'BOOKING_STATE') _refreshLists();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveRequest() => _run(
    _approve,
    (key) =>
        ref.read(apiProvider).bookings.approve(request.id, idempotencyKey: key),
    'Approved. Overlapping requests were declined.',
  );

  Future<void> _declineRequest() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _DeclineDialog(),
    );
    if (reason == null) return;
    await _run(
      _decline,
      (key) => ref
          .read(apiProvider)
          .bookings
          .decline(
            request.id,
            DeclineIn(reason: reason.isEmpty ? null : reason),
            idempotencyKey: key,
          ),
      'Request declined',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showListing) ...[
            Text(request.listingTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
          ],
          _Requester(accountId: request.counterpartyId),
          const SizedBox(height: AppSpacing.md),
          Text(
            bookingWhen(request.kind, request.startAt, request.endAt),
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            request.kind == TradeKind.sale
                ? 'Offer: ${formatMoney(request.amountPaise)}'
                : 'Rent: ${formatMoney(request.amountPaise)}',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Decline',
                  onPressed: _busy ? null : _declineRequest,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  isLoading: _busy,
                  onPressed: _approveRequest,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The requester's name with renter trust, rating and cancellations.
class _Requester extends ConsumerWidget {
  const _Requester({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileViewProvider(accountId));
    return profile.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Requester'),
      data: (p) {
        final rating = p.renter.rating;
        final cancellations = p.cancellationCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push(Routes.person(p.accountId)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(p.fullName, style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    size: AppSizes.iconSm,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TrustBadge(score: p.isNew ? null : p.renter.score),
                if (rating != null)
                  StarRatingDisplay(
                    rating: rating,
                    count: p.renter.reviewCount,
                  ),
                Text(
                  cancellations == 1
                      ? '1 cancellation'
                      : '$cancellations cancellations',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            Text(
              '${p.department}, year ${p.year}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog();

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline this request?'),
      content: AppTextField(
        controller: _reason,
        label: 'Reason (optional)',
        hint: 'e.g. I need it that day',
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}
