import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import '../listings/listing_format.dart';
import '../listings/listing_providers.dart';
import '../listings/widgets/listing_photo.dart';
import 'booking_format.dart';
import 'booking_providers.dart';
import 'widgets/ist_date_time_field.dart';

/// Ask to rent (pick a period) or to buy (confirm) a listing.
class RequestScreen extends ConsumerWidget {
  const RequestScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(listingDetailProvider(listingId))
        .when(
          loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorState(
              message: friendlyMessage(error),
              onRetry: () => ref.invalidate(listingDetailProvider(listingId)),
            ),
          ),
          data: (listing) => _RequestForm(listing: listing),
        );
  }
}

class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm({required this.listing});

  final ListingDetail listing;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  late DateTime _start;
  late DateTime _end;
  QuoteOut? _quote;
  Object? _quoteError;
  bool _quoting = false;
  bool _sending = false;
  String? _error;
  int _quoteGeneration = 0;
  late final IdempotentAction _send = IdempotentAction(
    ref.read(idempotencyKeyFactoryProvider),
  );

  ListingDetail get listing => widget.listing;
  bool get _isRent => listing.kind == TradeKind.rent;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = nextIstHour(now, plusHours: 2);
    // A day for items priced by the day, a few hours otherwise.
    _end = _start.add(
      Duration(hours: listing.pricePerDayPaise != null ? 24 : 3),
    );
    unawaited(_requote());
  }

  Future<void> _requote() async {
    final generation = ++_quoteGeneration;
    // A different period is a different request.
    _send.reset();
    setState(() {
      _quoting = true;
      _quoteError = null;
      _error = null;
    });
    try {
      final quote = await ref
          .read(apiProvider)
          .bookings
          .quote(
            listingId: listing.id,
            startAt: _isRent ? _start : null,
            endAt: _isRent ? _end : null,
          );
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quote = quote);
      }
    } on Object catch (error) {
      if (mounted && generation == _quoteGeneration) {
        setState(() {
          _quote = null;
          _quoteError = error;
        });
      }
    } finally {
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quoting = false);
      }
    }
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await pickIstDateTime(
      context,
      initial: start ? _start : _end,
      first: now,
      last: now.add(const Duration(days: 90)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        // Keep the same length when moving the start.
        final length = _end.difference(_start);
        _start = picked;
        _end = picked.add(length);
      } else {
        _end = picked;
      }
    });
    await _requote();
  }

  Future<void> _sendRequest() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final booking = await ref
          .read(apiProvider)
          .bookings
          .requestBooking(
            BookingCreate(
              listingId: listing.id,
              startAt: _isRent ? _start : null,
              endAt: _isRent ? _end : null,
            ),
            idempotencyKey: _send.key,
          );
      ref.invalidate(myBookingsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Request sent to ${listing.owner.fullName}')),
      );
      unawaited(router.pushReplacement(Routes.booking(booking.id)));
    } on ApiException catch (error) {
      // Retry the same tap with the same key; anything else starts afresh.
      if (!error.isConnectivityProblem) _send.reset();
      if (mounted) setState(() => _error = friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: AppSpacing.xl);
    final quote = _quote;
    final canSend = quote != null && !_quoting && _quoteError == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRent ? 'Request to rent' : 'Request to buy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          _ListingSummary(listing: listing),
          gap,
          if (_isRent) ...[
            Text('When do you need it?', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Times are in IST.', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            IstDateTimeField(
              label: 'From',
              value: _start,
              onTap: _sending ? null : () => _pick(start: true),
            ),
            const SizedBox(height: AppSpacing.md),
            IstDateTimeField(
              label: 'Until',
              value: _end,
              onTap: _sending ? null : () => _pick(start: false),
            ),
            if (listing.unavailable.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Already booked:', style: theme.textTheme.bodySmall),
              for (final slot in listing.unavailable)
                Text(
                  periodLabel(slot.startAt, slot.endAt),
                  style: theme.textTheme.bodySmall,
                ),
            ],
            gap,
          ],
          _QuoteCard(
            quote: quote,
            loading: _quoting,
            error: _quoteError,
            isRent: _isRent,
          ),
          gap,
          if (_error != null) ...[
            InlineError(_error!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            _isRent
                ? 'The owner has 24 hours to approve. You pay at pickup, by '
                      'UPI or cash.'
                : 'The owner has 24 hours to approve. You pay at the '
                      'handover, by UPI or cash.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Send request',
            isLoading: _sending,
            onPressed: canSend ? _sendRequest : null,
          ),
        ],
      ),
    );
  }
}

class _ListingSummary extends StatelessWidget {
  const _ListingSummary({required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox.square(
          dimension: 64,
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
              Text(listing.title, style: theme.textTheme.titleSmall),
              Text(
                '${listing.owner.fullName} · ${listing.pickupPoint}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.loading,
    required this.error,
    required this.isRent,
  });

  final QuoteOut? quote;
  final bool loading;
  final Object? error;
  final bool isRent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = this.error;
    if (error != null) return InlineError(friendlyMessage(error));
    final quote = this.quote;
    if (quote == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final hours = quote.hours;
    final rule = quote.lateFeeRule;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRent && hours != null
                ? 'Rent for ${durationLabel(hours)}'
                : 'Price',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                formatMoney(quote.amountPaise),
                style: theme.textTheme.headlineSmall,
              ),
              if (loading) ...[
                const SizedBox(width: AppSpacing.md),
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          if (isRent) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Final price is fixed when the owner approves.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (rule != null) ...[
            const Divider(height: AppSpacing.xl),
            Text('Late returns', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(lateFeeText(rule), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
