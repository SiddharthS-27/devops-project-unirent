import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import 'listing_format.dart';
import 'listing_providers.dart';
import 'widgets/owner_card.dart';
import 'widgets/photo_carousel.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(listingDetailProvider(listingId));
    return listing.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(listingDetailProvider(listingId)),
        ),
      ),
      data: (detail) => _ListingDetailView(detail: detail),
    );
  }
}

class _ListingDetailView extends ConsumerStatefulWidget {
  const _ListingDetailView({required this.detail});

  final ListingDetail detail;

  @override
  ConsumerState<_ListingDetailView> createState() => _ListingDetailViewState();
}

class _ListingDetailViewState extends ConsumerState<_ListingDetailView> {
  bool _busy = false;

  ListingDetail get detail => widget.detail;

  bool get _isRent => detail.kind == TradeKind.rent;

  Future<void> _setPaused(bool pause) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final listings = ref.read(apiProvider).listings;
      final updated = pause
          ? await listings.pauseListing(detail.id)
          : await listings.resumeListing(detail.id);
      ref
        ..invalidate(listingDetailProvider(updated.id))
        ..invalidate(myListingsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pause
                ? 'Listing paused. It no longer shows in search.'
                : 'Listing is live again.',
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(phoneCallerProvider)(phone);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Couldn’t start a call. The number is $phone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = detail.owner.phone;
    const gap = SizedBox(height: AppSpacing.xl);

    return Scaffold(
      appBar: AppBar(title: Text(detail.isMine ? 'Your listing' : 'Listing')),
      bottomNavigationBar: _bottomBar(),
      body: ListView(
        children: [
          PhotoCarousel(photos: detail.photos, category: detail.category),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(detail: detail),
                if (detail.isMine && (detail.pendingRequestCount ?? 0) > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _PendingRequests(count: detail.pendingRequestCount!),
                ],
                if (detail.description.isNotEmpty) ...[
                  gap,
                  const _SectionTitle('About this item'),
                  Text(detail.description, style: theme.textTheme.bodyLarge),
                ],
                if (_isRent) ...[
                  if (detail.lateFeeRule case final rule?) ...[
                    gap,
                    const _SectionTitle('Late returns'),
                    Text(lateFeeText(rule)),
                  ],
                  gap,
                  const _SectionTitle('Availability'),
                  _Availability(slots: detail.unavailable),
                ],
                gap,
                const _SectionTitle('Item details'),
                _AssetDetails(asset: detail.asset),
                gap,
                _SectionTitle(_isRent ? 'Lent by' : 'Sold by'),
                OwnerCardView(
                  owner: detail.owner,
                  onCall: !detail.isMine && phone != null
                      ? () => _call(phone)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _bottomBar() {
    final Widget content;
    if (detail.isMine) {
      final paused = detail.status == ListingStatus.paused;
      final canToggle = paused || detail.status == ListingStatus.active;
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!detail.canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'You can’t edit this listing while a booking is approved or '
                'active.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: detail.canEdit && !_busy
                      ? () => context.push(Routes.listingEdit(detail.id))
                      : null,
                ),
              ),
              if (canToggle) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton.secondary(
                    label: paused ? 'Resume' : 'Pause',
                    icon: paused
                        ? Icons.play_arrow_outlined
                        : Icons.pause_outlined,
                    isLoading: _busy,
                    onPressed: () => _setPaused(!paused),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    } else if (detail.status == ListingStatus.active) {
      content = AppButton(
        label: _isRent ? 'Request to rent' : 'Request to buy',
        onPressed: () => context.push(Routes.listingRequest(detail.id)),
      );
    } else {
      return null;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        child: content,
      ),
    );
  }
}

/// "₹50 after a 30-minute grace period, plus 2% of the rent per hour late."
String lateFeeText(LateFeeRuleOut rule) {
  final grace = rule.graceMinutes;
  final graceText = grace % 60 == 0 && grace >= 60
      ? '${grace ~/ 60}-hour'
      : '$grace-minute';
  final percent = NumberFormat('0.##').format(rule.hourlyPercentBp / 100);
  return 'If you return late, you pay ${formatMoney(rule.baseFeePaise)} once '
      'the $graceText grace period is over, plus $percent% of the rent for '
      'every hour after that.';
}

String _statusLabel(ListingStatus status) => switch (status) {
  ListingStatus.active => 'Active',
  ListingStatus.paused => 'Paused',
  ListingStatus.sold => 'Sold',
  ListingStatus.removed => 'Removed',
  ListingStatus.unknown => 'Unavailable',
};

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.status != ListingStatus.active) ...[
          Chip(label: Text(_statusLabel(detail.status))),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(detail.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          priceLabel(
            kind: detail.kind,
            perHourPaise: detail.pricePerHourPaise,
            perDayPaise: detail.pricePerDayPaise,
            salePaise: detail.salePricePaise,
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${tradeKindLabel(detail.kind)} · ${categoryLabel(detail.category)}',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: AppSizes.iconSm,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text('Pickup: ${detail.pickupPoint}', style: muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingRequests extends StatelessWidget {
  const _PendingRequests({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        count == 1
            ? '1 booking request is waiting for you'
            : '$count booking requests are waiting for you',
        style: TextStyle(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// "Tue, 28 Oct, 10:00 AM – 6:00 PM" (IST), spanning days when needed.
String slotLabel(BlockedSlot slot) {
  final start = toIst(slot.startAt);
  final end = toIst(slot.endAt);
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  final from =
      '${formatIstShortDate(slot.startAt)}, ${formatIstTime(slot.startAt)}';
  final to = sameDay
      ? formatIstTime(slot.endAt)
      : '${formatIstShortDate(slot.endAt)}, ${formatIstTime(slot.endAt)}';
  return '$from – $to';
}

class _Availability extends StatelessWidget {
  const _Availability({required this.slots});

  final List<BlockedSlot> slots;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Text('No bookings yet, so it’s free whenever you need it.');
    }
    final sorted = [...slots]..sort((a, b) => a.startAt.compareTo(b.startAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Already booked at these times:'),
        const SizedBox(height: AppSpacing.xs),
        for (final slot in sorted)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(slotLabel(slot)),
          ),
      ],
    );
  }
}

IconData _historyIcon(AssetEventKind kind) => switch (kind) {
  AssetEventKind.listed => Icons.storefront_outlined,
  AssetEventKind.rented => Icons.outbox_outlined,
  AssetEventKind.returned => Icons.move_to_inbox_outlined,
  AssetEventKind.sold => Icons.sell_outlined,
  AssetEventKind.damageCharge => Icons.report_outlined,
  AssetEventKind.unknown => Icons.history,
};

class _AssetDetails extends StatelessWidget {
  const _AssetDetails({required this.asset});

  final AssetOut asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final made = asset.manufactureDate;
    final rows = <(String, String)>[
      ('Condition', conditionLabel(asset.condition)),
      if (made != null) ('Made', DateFormat('MMM yyyy', 'en_US').format(made)),
      if (asset.serialNumber case final serial?) ('Serial number', serial),
      (
        'Rented',
        asset.rentalCount == 1 ? 'Once' : '${asset.rentalCount} times',
      ),
    ];
    final history = [...asset.history]..sort((a, b) => b.at.compareTo(a.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Text(value)),
              ],
            ),
          ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('History', style: theme.textTheme.titleSmall),
          for (final entry in history)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_historyIcon(entry.kind)),
              title: Text(entry.summary),
              subtitle: Text(formatIstDate(entry.at)),
              trailing: entry.amountPaise == null
                  ? null
                  : Text(formatMoney(entry.amountPaise!)),
            ),
        ],
      ],
    );
  }
}
