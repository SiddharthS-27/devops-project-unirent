import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import '../bookings/booking_providers.dart';
import '../payouts/payout_gate.dart';
import 'listing_providers.dart';
import 'widgets/listing_tiles.dart';

/// The Listings tab: the student's own listings, by status.
class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key});

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen> {
  ListingStatus _status = ListingStatus.active;
  bool _checkingPayout = false;

  /// New listings need a ready payout account; check before the form.
  Future<void> _addListing() async {
    setState(() => _checkingPayout = true);
    final PayoutAccountOut payout;
    try {
      payout = await ref.read(apiProvider).payments.getPayoutAccount();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _checkingPayout = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _checkingPayout = false);
    if (payout.ready) {
      await context.push(Routes.newListing);
    } else {
      await showPayoutRequiredDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(myListingsProvider(_status));
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkingPayout ? null : _addListing,
        icon: _checkingPayout
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Add listing'),
      ),
      body: Column(
        children: [
          const _RequestsWaiting(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: SegmentedButton<ListingStatus>(
              segments: const [
                ButtonSegment(
                  value: ListingStatus.active,
                  label: Text('Active'),
                ),
                ButtonSegment(
                  value: ListingStatus.paused,
                  label: Text('Paused'),
                ),
                ButtonSegment(value: ListingStatus.sold, label: Text('Sold')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.single),
            ),
          ),
          Expanded(
            child: listings.when(
              loading: () => const LoadingState(),
              error: (error, _) => ErrorState(
                message: friendlyMessage(error),
                onRetry: () => ref.invalidate(myListingsProvider(_status)),
              ),
              data: (items) => items.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(myListingsProvider(_status).future),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screen,
                          0,
                          AppSpacing.screen,
                          96, // Clear of the floating button.
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) => ListingTile(
                          listing: items[i],
                          onTap: () =>
                              context.push(Routes.listing(items[i].id)),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => switch (_status) {
    ListingStatus.paused => const EmptyState(
      icon: Icons.pause_circle_outline,
      title: 'Nothing paused',
      message: 'Pause a listing to hide it from search for a while.',
    ),
    ListingStatus.sold => const EmptyState(
      icon: Icons.sell_outlined,
      title: 'Nothing sold yet',
    ),
    _ => const EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No listings yet',
      message: 'List something to rent out or sell to students on campus.',
    ),
  };
}

/// "3 booking requests waiting" when the owner has any.
class _RequestsWaiting extends ConsumerWidget {
  const _RequestsWaiting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(incomingRequestsProvider(null)).value?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.screen,
        AppSpacing.screen,
        0,
      ),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ListTile(
          leading: Icon(Icons.inbox_outlined, color: scheme.onPrimaryContainer),
          title: Text(
            count == 1
                ? '1 booking request waiting'
                : '$count booking requests waiting',
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
          onTap: () => context.push(Routes.incomingRequests),
        ),
      ),
    );
  }
}
