import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/session.dart';

/// Bookings the student still has to review. Reviewing is compulsory: while
/// this is non-empty the router sends Home and search to the review.
class PendingReviewsNotifier extends Notifier<List<BookingSummary>> {
  @override
  List<BookingSummary> build() => const [];

  Future<void> refresh() async {
    if (ref.read(sessionProvider).status != SessionStatus.student) {
      state = const [];
      return;
    }
    try {
      state = await ref.read(apiProvider).reviews.pendingReviews();
    } on ApiException {
      // Keep what we had; the next refresh will catch up.
    }
  }

  void clear() => state = const [];
}

final pendingReviewsProvider =
    NotifierProvider<PendingReviewsNotifier, List<BookingSummary>>(
      PendingReviewsNotifier.new,
    );
