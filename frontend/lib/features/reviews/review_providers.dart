import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';

final reviewFormProvider = FutureProvider.autoDispose
    .family<ReviewForm, String>(
      (ref, bookingId) => ref.watch(apiProvider).bookings.reviewForm(bookingId),
    );

/// First page of someone's revealed reviews in one role.
final profileReviewsProvider = FutureProvider.autoDispose
    .family<ReviewOutPage, (String, TrustRole)>(
      (ref, key) =>
          ref.watch(apiProvider).reviews.reviewsOf(key.$1, role: key.$2),
    );
