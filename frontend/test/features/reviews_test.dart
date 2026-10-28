import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_review_handlers.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/app/session.dart';
import 'package:unirent/ui/ui.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const dev = 'dev@college.edu';

/// A finished rental of Dev's DSLR by Asha, waiting for reviews.
MockBooking awaitingReviews(
  MockServer server, {
  TradeKind kind = TradeKind.rent,
}) {
  final now = DateTime.now().toUtc();
  final b = MockBooking(
    id: 'b-rev',
    listingId: mockListingId(kind == TradeKind.rent ? 1 : 16),
    kind: kind,
    renterId: server.db.accountByEmail(asha)!.id,
    ownerId: server.db.accountByEmail(dev)!.id,
    amountPaise: 40000,
    createdAt: now.subtract(const Duration(days: 3)),
    startAt: kind == TradeKind.rent
        ? now.subtract(const Duration(days: 2))
        : null,
    endAt: kind == TradeKind.rent
        ? now.subtract(const Duration(days: 1))
        : null,
    status: BookingStatus.awaitingReviews,
  )..pickupCompletedAt = now.subtract(const Duration(days: 2));
  return server.db.bookings[b.id] = b;
}

MockReview review(
  MockBooking b, {
  required String by,
  required MockServer server,
  DateTime? at,
  String comment = 'Lovely to deal with',
}) {
  final reviewer = server.db.accountByEmail(by)!;
  final ownerReviews = reviewer.id == b.ownerId;
  return MockReview(
    id: 'r-$by',
    bookingId: b.id,
    reviewerId: reviewer.id,
    revieweeId: ownerReviews ? b.renterId : b.ownerId,
    revieweeRole: ownerReviews ? TrustRole.renter : TrustRole.lender,
    type: ownerReviews ? ReviewType.renter : ReviewType.lender,
    ratings: ownerReviews
        ? const {'item_care': 5, 'return_punctuality': 4, 'communication': 5}
        : const {
            'item_matches_description': 4,
            'item_condition': 4,
            'handover_punctuality': 5,
            'communication': 5,
          },
    comment: comment,
    createdAt: at ?? DateTime.now().toUtc(),
  );
}

ApiClient clientFor(MockServer server, String email) => ApiClient(
  config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
  tokenStore: MemoryTokenStore(tokensFor(server, email)),
  mockServer: server,
);

Future<void> rateEverything(TestApp app, int stars) async {
  final inputs = find.byType(StarRatingInput);
  for (var i = 0; i < inputs.evaluate().length; i++) {
    await app.tap(
      find.descendant(
        of: inputs.at(i),
        matching: find.byTooltip('$stars stars'),
      ),
    );
  }
}

void main() {
  testWidgets('reviewing is compulsory: Home leads back to the review', (
    tester,
  ) async {
    final server = MockServer();
    final b = awaitingReviews(server);
    final app = await pumpSignedIn(tester, asha, server: server);

    expect(app.location, Routes.bookingReview(b.id));
    expect(find.text('How was Dev Patel?'), findsOneWidget);
    expect(find.textContaining('Review this booking to carry on'), findsOne);
    // Four lender parameters for a renter's review.
    expect(find.byType(StarRatingInput), findsNWidgets(4));

    app.router.go(Routes.home);
    await tester.pumpAndSettle();
    expect(app.location, Routes.bookingReview(b.id));
    app.router.go('${Routes.search}?q=camera');
    await tester.pumpAndSettle();
    expect(app.location, Routes.bookingReview(b.id));

    // Bookings stay reachable.
    app.router.go(Routes.bookings);
    await tester.pumpAndSettle();
    expect(app.location, Routes.bookings);
  });

  testWidgets('submit: validation, then waiting, then the gate lifts', (
    tester,
  ) async {
    final server = MockServer();
    final b = awaitingReviews(server);
    final app = await pumpSignedIn(tester, asha, server: server);

    await app.tapText('Submit review');
    expect(find.text('Choose 1 to 5 stars'), findsNWidgets(4));
    expect(find.text('Write a short comment'), findsOneWidget);

    await rateEverything(app, 4);
    await app.enterField('Comment', 'Camera was spotless');
    await app.tapText('Submit review');

    final mine = server.db.reviews.single;
    expect(mine.reviewerId, b.renterId);
    expect(mine.ratings.values, everyElement(4));
    expect(app.location, Routes.booking(b.id));
    expect(find.text('Waiting for their review'), findsOneWidget);
    expect(find.textContaining('at the latest'), findsOneWidget);
    expect(b.status, BookingStatus.awaitingReviews);

    app.router.go(Routes.home);
    await tester.pumpAndSettle();
    expect(app.location, Routes.home);
  });

  testWidgets('both reviews show once the other side reviews', (tester) async {
    final server = MockServer();
    final b = awaitingReviews(server);
    server.db.reviews.add(
      review(b, by: asha, server: server, comment: 'Camera was spotless'),
    );
    final push = FakePushService();
    final app = await pumpSignedIn(tester, asha, server: server, push: push);
    unawaited(app.router.push(Routes.booking(b.id)));
    await tester.pumpAndSettle();
    expect(find.text('Their review of you'), findsNothing);

    await tester.runAsync(
      () => clientFor(server, dev).api.bookings.submitReview(
        b.id,
        const ReviewIn(
          ratings: {
            'item_care': 5,
            'return_punctuality': 5,
            'communication': 4,
          },
          comment: 'Returned it early',
        ),
      ),
    );
    push.receivedPushes.add(Uri.parse('unirent://bookings/${b.id}'));
    await tester.pumpAndSettle();

    expect(b.status, BookingStatus.completed);
    expect(find.text('Their review of you'), findsOneWidget);
    expect(find.text('“Returned it early”'), findsOneWidget);
    expect(find.text('Item care: 5/5'), findsOneWidget);
    expect(find.text('Your review of them'), findsOneWidget);
    expect(find.text('“Camera was spotless”'), findsOneWidget);
  });

  testWidgets('24 hours after the first review, it is released', (
    tester,
  ) async {
    final server = MockServer();
    final b = awaitingReviews(server);
    server.db.reviews.add(
      review(
        b,
        by: asha,
        server: server,
        at: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
      ),
    );
    final app = await pumpSignedIn(tester, asha, server: server);
    unawaited(app.router.push(Routes.booking(b.id)));
    await tester.pumpAndSettle();
    expect(b.status, BookingStatus.completed);
    expect(find.text('Dev didn’t leave a review.'), findsOneWidget);
    expect(find.text('“Lovely to deal with”'), findsOneWidget);
  });

  test('review rules', () async {
    final server = MockServer();
    final b = awaitingReviews(server);
    final renter = clientFor(server, asha);
    final form = await renter.api.bookings.reviewForm(b.id);
    expect(form.reviewType, ReviewType.lender);
    expect(form.counterpartyName, 'Dev Patel');

    try {
      await renter.api.bookings.submitReview(
        b.id,
        const ReviewIn(ratings: {'communication': 5}, comment: 'ok'),
      );
      fail('expected INVALID_RATINGS');
    } on ApiException catch (e) {
      expect(e.code, 'INVALID_RATINGS');
      expect((e.details! as Map)['expected'], hasLength(4));
    }
    await renter.api.bookings.submitReview(
      b.id,
      ReviewIn(
        ratings: {for (final p in form.parameters) p.key: 5},
        comment: 'Great',
      ),
    );
    await expectLater(
      renter.api.bookings.submitReview(
        b.id,
        ReviewIn(
          ratings: {for (final p in form.parameters) p.key: 5},
          comment: 'Again',
        ),
      ),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'ALREADY_REVIEWED'),
      ),
    );

    // Sales use their own parameters; finished bookings can't be reviewed.
    final sale = awaitingReviews(MockServer(), kind: TradeKind.sale);
    expect(mockReviewTypeFor(sale, TradeRole.owner), ReviewType.renterSale);
    expect(mockReviewTypeFor(sale, TradeRole.renter), ReviewType.lenderSale);
    b.status = BookingStatus.completed;
    await expectLater(
      clientFor(server, dev).api.bookings.reviewForm(b.id),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'BOOKING_STATE'),
      ),
    );
  });

  test('the redirect gate only covers Home and search', () {
    const student = Session(SessionStatus.student);
    String? go(String path) =>
        redirectFor(student, Uri.parse(path), pendingReviews: const ['b1']);
    expect(go('/home'), '/bookings/b1/review');
    expect(go('/home/search?q=x'), '/bookings/b1/review');
    expect(go('/bookings'), isNull);
    expect(go('/bookings/b1/review'), isNull);
    expect(go('/profile'), isNull);
    expect(redirectFor(student, Uri.parse('/home')), isNull);
  });
}
