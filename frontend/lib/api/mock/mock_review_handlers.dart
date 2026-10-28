import 'dart:async';

import '../generated/models.dart';
import 'mock_booking_handlers.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_server.dart';
import 'mock_views.dart';

/// Review parameters per review type (backend `PARAMETERS`).
const mockReviewParameters = {
  ReviewType.renter: [
    ('item_care', 'Item care'),
    ('return_punctuality', 'Return punctuality'),
    ('communication', 'Communication'),
  ],
  ReviewType.lender: [
    ('item_matches_description', 'Item matches description'),
    ('item_condition', 'Item condition'),
    ('handover_punctuality', 'Handover punctuality'),
    ('communication', 'Communication'),
  ],
  ReviewType.renterSale: [
    ('handover_punctuality', 'Handover punctuality'),
    ('payment_promptness', 'Payment promptness'),
    ('communication', 'Communication'),
  ],
  ReviewType.lenderSale: [
    ('item_matches_description', 'Item matches description'),
    ('item_condition', 'Item condition'),
    ('handover_punctuality', 'Handover punctuality'),
    ('communication', 'Communication'),
  ],
};

/// Reviews stay hidden until both are in, or this long after the first.
const mockReviewReleaseAfter = Duration(hours: 24);

class MockReview {
  MockReview({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.revieweeRole,
    required this.type,
    required this.ratings,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final TrustRole revieweeRole;
  final ReviewType type;
  final Map<String, int> ratings;
  final String comment;
  final DateTime createdAt;
  DateTime? revealedAt;

  double get overall {
    final mean = ratings.values.fold(0, (a, b) => a + b) / ratings.length;
    return (mean * 100).round() / 100;
  }
}

/// The owner rates the renter; the renter rates the owner (as lender).
ReviewType mockReviewTypeFor(MockBooking b, TradeRole reviewerRole) {
  final rent = b.kind == TradeKind.rent;
  if (reviewerRole == TradeRole.owner) {
    return rent ? ReviewType.renter : ReviewType.renterSale;
  }
  return rent ? ReviewType.lender : ReviewType.lenderSale;
}

List<MockReview> mockReviewsOf(MockDb db, String bookingId) =>
    db.reviews.where((r) => r.bookingId == bookingId).toList();

ReviewState? mockReviewState(MockDb db, MockBooking b, String viewerId) {
  if (!const {
    BookingStatus.awaitingReviews,
    BookingStatus.completed,
    BookingStatus.inAppeal,
  }.contains(b.status)) {
    return null;
  }
  final reviews = mockReviewsOf(db, b.id);
  final first = reviews.isEmpty
      ? null
      : reviews.map((r) => r.createdAt).reduce((a, c) => a.isBefore(c) ? a : c);
  return ReviewState(
    mineSubmitted: reviews.any((r) => r.reviewerId == viewerId),
    theirsSubmitted: reviews.any((r) => r.reviewerId != viewerId),
    revealed: reviews.any((r) => r.revealedAt != null),
    releaseAt: first != null && b.status == BookingStatus.awaitingReviews
        ? first.add(mockReviewReleaseAfter)
        : null,
  );
}

/// Shows whatever reviews are in and completes the booking; updates both
/// sides' trust (a simple running average in the mock).
void mockRevealReviews(MockDb db, MockBooking b) {
  if (b.status != BookingStatus.awaitingReviews) return;
  final now = db.clock().toUtc();
  for (final r in mockReviewsOf(db, b.id)) {
    if (r.revealedAt != null) continue;
    r.revealedAt = now;
    final reviewee = db.accounts[r.revieweeId]!;
    if (r.revieweeRole == TrustRole.lender) {
      final n = reviewee.completedTrades;
      reviewee.lenderRating =
          ((reviewee.lenderRating ?? r.overall) * n + r.overall) / (n + 1);
    } else {
      final n = reviewee.renterReviews;
      reviewee
        ..renterRating =
            ((reviewee.renterRating ?? r.overall) * n + r.overall) / (n + 1)
        ..renterReviews = n + 1;
    }
  }
  db.accounts[b.renterId]!.completedTrades++;
  db.accounts[b.ownerId]!.completedTrades++;
  b
    ..status = BookingStatus.completed
    ..completedAt = now
    ..updatedAt = now;
}

/// The 24-hour release (what the backend's timer does).
void mockApplyReviewRelease(MockDb db, MockBooking b) {
  final state = mockReviewState(db, b, '');
  final release = state?.releaseAt;
  if (release != null && !db.clock().toUtc().isBefore(release)) {
    mockRevealReviews(db, b);
  }
}

Map<String, MockHandler> reviewHandlers(MockDb db) {
  final h = _ReviewHandlers(db);
  return {
    'GET /api/v1/bookings/{booking_id}/review-form': h.form,
    'POST /api/v1/bookings/{booking_id}/reviews': h.submit,
    'GET /api/v1/me/pending-reviews': h.pending,
    'GET /api/v1/profiles/{account_id}/reviews': h.reviewsOf,
  };
}

class _ReviewHandlers {
  _ReviewHandlers(this.db)
    : bookings = MockBookingHandlers(db),
      views = MockBookingViews(db);

  final MockDb db;
  final MockBookingHandlers bookings;
  final MockBookingViews views;

  DateTime get now => db.clock().toUtc();

  (MockBooking, TradeRole) _reviewable(MockRequest r, MockAccount actor) {
    final b = bookings.booking(r, actor);
    final role = b.roleOf(actor.id);
    if (role == null) {
      throw const MockApiError(
        403,
        'NOT_YOUR_STEP',
        'Only the two sides review',
      );
    }
    if (b.status != BookingStatus.awaitingReviews) {
      throw const MockApiError(
        409,
        'BOOKING_STATE',
        "Reviews aren't open for this booking",
      );
    }
    return (b, role);
  }

  MockResponse form(MockRequest r) {
    final actor = mockAuthenticate(db, r);
    final (b, role) = _reviewable(r, actor);
    final type = mockReviewTypeFor(b, role);
    final otherId = role == TradeRole.renter ? b.ownerId : b.renterId;
    return MockResponse.json(
      ReviewForm(
        reviewType: type,
        parameters: [
          for (final (key, label) in mockReviewParameters[type]!)
            ReviewParameter(key: key, label: label),
        ],
        counterpartyId: otherId,
        counterpartyName: mockOwnProfile(db, db.accounts[otherId]!).fullName,
      ).toJson(),
    );
  }

  FutureOr<MockResponse> submit(MockRequest r) {
    final actor = mockAuthenticate(db, r);
    final (b, role) = _reviewable(r, actor);
    final existing = mockReviewsOf(db, b.id);
    if (existing.any((x) => x.reviewerId == actor.id)) {
      throw const MockApiError(
        409,
        'ALREADY_REVIEWED',
        'You already reviewed this',
      );
    }
    final body = mockParse(r, ReviewIn.fromJson);
    final type = mockReviewTypeFor(b, role);
    final expected = {for (final (k, _) in mockReviewParameters[type]!) k};
    if (body.ratings.keys.toSet().length != expected.length ||
        !body.ratings.keys.toSet().containsAll(expected)) {
      throw MockApiError(422, 'INVALID_RATINGS', 'Rate every parameter', {
        'expected': expected.toList()..sort(),
      });
    }
    if (body.ratings.values.any((v) => v < 1 || v > 5)) {
      throw const MockApiError(
        422,
        'INVALID_RATINGS',
        'Ratings are 1 to 5 stars',
      );
    }
    if (body.comment.trim().length < 2 || body.comment.length > 1000) {
      throw mockValidation('comment', 'Must be 2-1000 characters');
    }
    final reviewer = role;
    db.reviews.add(
      MockReview(
        id: db.nextId(),
        bookingId: b.id,
        reviewerId: actor.id,
        revieweeId: reviewer == TradeRole.renter ? b.ownerId : b.renterId,
        revieweeRole: reviewer == TradeRole.renter
            ? TrustRole.lender
            : TrustRole.renter,
        type: type,
        ratings: body.ratings,
        comment: body.comment.trim(),
        createdAt: now,
      ),
    );
    b.updatedAt = now;
    if (existing.isNotEmpty) mockRevealReviews(db, b);
    return MockResponse.json(mockReviewState(db, b, actor.id)!.toJson());
  }

  MockResponse pending(MockRequest r) {
    final actor = mockAuthenticate(db, r);
    final waiting = db.bookings.values.where((b) {
      bookings.applyTimers(b);
      final role = b.roleOf(actor.id);
      return role != null &&
          b.status == BookingStatus.awaitingReviews &&
          !mockReviewsOf(db, b.id).any((x) => x.reviewerId == actor.id);
    });
    return MockResponse.json([
      for (final b in waiting) views.summary(b, b.roleOf(actor.id)!).toJson(),
    ]);
  }

  /// Revealed reviews of someone in one role, newest first.
  MockResponse reviewsOf(MockRequest r) {
    mockAuthenticate(db, r);
    final id = r.pathParams['account_id'];
    final role = TrustRole.fromJson(r.query['role'] as String? ?? 'lender');
    final items =
        db.reviews
            .where(
              (x) =>
                  x.revieweeId == id &&
                  x.revieweeRole == role &&
                  x.revealedAt != null,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final offset = int.tryParse('${r.query['cursor'] ?? 0}') ?? 0;
    final limit = int.tryParse('${r.query['limit'] ?? 20}') ?? 20;
    final page = items.skip(offset).take(limit).toList();
    final next = offset + page.length;
    return MockResponse.json(
      ReviewOutPage(
        items: [
          for (final x in page)
            ReviewOut(
              id: x.id,
              reviewType: x.type,
              overall: x.overall,
              ratings: x.ratings,
              comment: x.comment,
              reviewerId: x.reviewerId,
              reviewerName: mockOwnProfile(
                db,
                db.accounts[x.reviewerId]!,
              ).fullName,
              createdAt: x.createdAt,
            ),
        ],
        nextCursor: next < items.length ? '$next' : null,
      ).toJson(),
    );
  }
}
