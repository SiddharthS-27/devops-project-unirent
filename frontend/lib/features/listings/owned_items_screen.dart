import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import 'listing_format.dart';
import 'listing_providers.dart';
import 'widgets/listing_photo.dart';

/// "Listed", "Paused", "Sold", "Removed" or "Not listed".
String ownedItemStatus(ListingStatus? status) => switch (status) {
  ListingStatus.active => 'Listed',
  ListingStatus.paused => 'Paused',
  ListingStatus.sold => 'Sold',
  ListingStatus.removed => 'Removed',
  _ => 'Not listed',
};

/// Whether the item's own listing is live (so it opens instead of Relist).
bool hasLiveListing(AssetOut a) =>
    a.listingId != null &&
    (a.listingStatus == ListingStatus.active ||
        a.listingStatus == ListingStatus.paused);

/// Everything you own, including things you bought, with their history.
class OwnedItemsScreen extends ConsumerWidget {
  const OwnedItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myAssetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Items you own')),
      body: items.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(myAssetsProvider),
        ),
        data: (assets) => assets.isEmpty
            ? const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Nothing here yet',
                message: 'Items you list or buy show up here.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myAssetsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  itemCount: assets.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => _OwnedItem(asset: assets[i]),
                ),
              ),
      ),
    );
  }
}

class _OwnedItem extends StatelessWidget {
  const _OwnedItem({required this.asset});

  final AssetOut asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = hasLiveListing(asset);
    final listingId = asset.listingId;
    final history = [...asset.history]..sort((a, b) => b.at.compareTo(a.at));
    final summary = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 72,
          child: ListingPhoto(
            url: asset.photoUrl,
            category: asset.category,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(asset.title, style: theme.textTheme.titleSmall),
              Text(
                categoryLabel(asset.category),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Chip(
                label: Text(ownedItemStatus(asset.listingStatus)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (live)
            // Only the summary opens the listing, so it doesn't swallow the
            // history and buttons below.
            Semantics(
              button: true,
              label:
                  '${asset.title}, ${ownedItemStatus(asset.listingStatus)}. '
                  'Open listing',
              onTap: () => context.push(Routes.listing(listingId!)),
              child: ExcludeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => context.push(Routes.listing(listingId!)),
                  child: summary,
                ),
              ),
            )
          else
            summary,
          if (!live)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => context.push(Routes.relist(asset.id)),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Relist'),
              ),
            ),
          if (history.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'History (${history.length})',
                style: theme.textTheme.bodyMedium,
              ),
              children: [
                for (final e in history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.summary),
                    subtitle: Text(formatIstDate(e.at)),
                    trailing: e.amountPaise == null
                        ? null
                        : Text(formatMoney(e.amountPaise!)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
