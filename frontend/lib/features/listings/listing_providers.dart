import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api.dart';

final listingDetailProvider = FutureProvider.autoDispose
    .family<ListingDetail, String>(
      (ref, id) => ref.watch(apiProvider).listings.getListing(id),
    );

/// Starts a phone call; returns false if no dialer is available.
typedef PhoneCaller = Future<bool> Function(String phone);

final phoneCallerProvider = Provider<PhoneCaller>(
  (ref) =>
      (phone) => launchUrl(Uri(scheme: 'tel', path: phone)),
);

/// The signed-in user's listings with one status.
final myListingsProvider = FutureProvider.autoDispose
    .family<List<ListingCard>, ListingStatus>(
      (ref, status) =>
          ref.watch(apiProvider).listings.myListings(status: status),
    );

/// Items the user owns, including bought ones.
final myAssetsProvider = FutureProvider.autoDispose<List<AssetOut>>(
  (ref) => ref.watch(apiProvider).listings.myAssets(),
);

final assetProvider = FutureProvider.autoDispose.family<AssetOut, String>(
  (ref, id) => ref.watch(apiProvider).listings.getAsset(id),
);
