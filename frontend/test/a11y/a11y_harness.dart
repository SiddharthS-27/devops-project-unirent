import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_appeal_handlers.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';

import '../helpers/booking_helpers.dart';
import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const karan = 'karan@college.edu';
const dev = 'dev@college.edu';
const moderator = 'moderator@unirent.in';
const seededRequest = '00000000-0000-4000-d000-000000000001';

/// A key screen: who is signed in (null: nobody) and where they are.
class A11yScreen {
  const A11yScreen(this.name, this.email, this.setup);

  final String name;
  final String? email;

  /// Prepares mock data; returns the location to open (null: stay put).
  final String? Function(MockServer server) setup;
}

/// Karan's request for Asha's bike, approved: the pickup checklist.
String pickupBooking(MockServer server) {
  final now = DateTime.now().toUtc();
  server.db.bookings[seededRequest]!
    ..status = BookingStatus.approved
    ..decidedAt = now
    ..startAt = now.add(const Duration(hours: 1))
    ..endAt = now.add(const Duration(hours: 9));
  return Routes.booking(seededRequest);
}

/// Karan has Asha's bike and has started the return.
String returnBooking(MockServer server) {
  final now = DateTime.now().toUtc();
  server.db.bookings[seededRequest]!
    ..status = BookingStatus.returning
    ..decidedAt = now.subtract(const Duration(days: 1))
    ..startAt = now.subtract(const Duration(days: 1))
    ..endAt = now.add(const Duration(hours: 1))
    ..pickupCompletedAt = now.subtract(const Duration(days: 1))
    ..returnStartedAt = now;
  return Routes.booking(seededRequest);
}

/// A finished rental of Dev's DSLR by Asha, waiting for her review.
String reviewBooking(MockServer server) {
  final now = DateTime.now().toUtc();
  final b = MockBooking(
    id: 'b-rev',
    listingId: mockListingId(1),
    kind: TradeKind.rent,
    renterId: server.db.accountByEmail(asha)!.id,
    ownerId: server.db.accountByEmail(dev)!.id,
    amountPaise: 40000,
    createdAt: now.subtract(const Duration(days: 3)),
    startAt: now.subtract(const Duration(days: 2)),
    endAt: now.subtract(const Duration(days: 1)),
    status: BookingStatus.awaitingReviews,
  )..pickupCompletedAt = now.subtract(const Duration(days: 2));
  server.db.bookings[b.id] = b;
  return Routes.bookingReview(b.id);
}

/// An open appeal on Asha's returned DSLR rental.
MockAppeal openAppeal(MockServer server) {
  final now = DateTime.now().toUtc();
  final b =
      MockBooking(
          id: 'b-dslr',
          listingId: mockListingId(1),
          kind: TradeKind.rent,
          renterId: server.db.accountByEmail(asha)!.id,
          ownerId: server.db.accountByEmail(dev)!.id,
          amountPaise: 40000,
          createdAt: now.subtract(const Duration(days: 2)),
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.subtract(const Duration(hours: 1)),
          status: BookingStatus.inAppeal,
        )
        ..pickupCompletedAt = now.subtract(const Duration(days: 1))
        ..returnCompletedAt = now.subtract(const Duration(minutes: 20))
        ..frozenLateFeePaise = 0
        ..damagePaise = 150000
        ..damageDescription = 'Cracked lens hood';
  server.db.bookings[b.id] = b;
  final appeal = MockAppeal(
    id: 'appeal-1',
    bookingId: b.id,
    filedById: b.renterId,
    filedBy: TradeRole.renter,
    reason: AppealReason.damageDispute,
    notes: 'The hood was cracked before I picked it up.',
    photoKeys: const [],
    previousStatus: BookingStatus.returning,
    createdAt: now,
  );
  server.db.appeals[appeal.id] = appeal;
  server.db.accountByEmail(moderator)!.mustChangePassword = false;
  return appeal;
}

final keyScreens = <A11yScreen>[
  A11yScreen('sign-in', null, (_) => null),
  A11yScreen('home', asha, (_) => null),
  A11yScreen('search', asha, (_) => Routes.search),
  A11yScreen('listing detail', asha, (_) => Routes.listing(mockListingId(1))),
  const A11yScreen('booking: pickup checklist', karan, pickupBooking),
  const A11yScreen('booking: return checklist', asha, returnBooking),
  const A11yScreen('review', asha, reviewBooking),
  A11yScreen('help', asha, (_) => Routes.help),
  A11yScreen('staff appeals queue', moderator, (s) {
    openAppeal(s);
    return null;
  }),
  A11yScreen(
    'staff appeal detail',
    moderator,
    (s) => Routes.staffAppeal(openAppeal(s).id),
  ),
];

/// Asha's DSLR rental of Dev's camera, returned: she can appeal.
String appealableBooking(MockServer server) {
  final now = DateTime.now().toUtc();
  final b =
      MockBooking(
          id: 'b-ret',
          listingId: mockListingId(1),
          kind: TradeKind.rent,
          renterId: server.db.accountByEmail(asha)!.id,
          ownerId: server.db.accountByEmail(dev)!.id,
          amountPaise: 40000,
          createdAt: now.subtract(const Duration(days: 2)),
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.subtract(const Duration(hours: 1)),
          status: BookingStatus.returning,
        )
        ..pickupCompletedAt = now.subtract(const Duration(days: 1))
        ..returnStartedAt = now.subtract(const Duration(minutes: 30))
        ..returnCompletedAt = now.subtract(const Duration(minutes: 20))
        ..frozenLateFeePaise = 0
        ..damagePaise = 150000
        ..damageDescription = 'Cracked lens hood';
  server.db.bookings[b.id] = b;
  return Routes.booking(b.id);
}

/// Every other screen, checked by the wider sweep.
final otherScreens = <A11yScreen>[
  A11yScreen('staff sign-in', null, (_) => Routes.staffSignIn),
  A11yScreen('email sign-in', null, (_) => Routes.signInWithEmail),
  A11yScreen('saved searches', asha, (_) => Routes.savedSearches),
  A11yScreen('bookings', karan, (_) => Routes.bookings),
  A11yScreen('listings', asha, (_) => Routes.listings),
  A11yScreen('new listing', asha, (_) => Routes.newListing),
  A11yScreen('incoming requests', asha, (_) => Routes.incomingRequests),
  A11yScreen(
    'request to rent',
    karan,
    (_) => Routes.listingRequest(mockListingId(1)),
  ),
  A11yScreen('profile', asha, (_) => Routes.profile),
  A11yScreen('edit profile', asha, (_) => Routes.editProfile),
  A11yScreen('payment history', asha, (_) => Routes.paymentHistory),
  A11yScreen('items you own', asha, (_) => Routes.ownedItems),
  A11yScreen('public profile', asha, (s) {
    return Routes.person(s.db.accountByEmail(dev)!.id);
  }),
  A11yScreen('payout account', asha, (_) => Routes.payoutAccount),
  const A11yScreen('booking: appeal card', asha, appealableBooking),
  A11yScreen('appeal form', asha, (s) {
    appealableBooking(s);
    return Routes.bookingAppeal('b-ret');
  }),
  A11yScreen('staff ruling form', moderator, (s) {
    return Routes.staffAppealRule(openAppeal(s).id);
  }),
  A11yScreen('staff support', moderator, (s) {
    openAppeal(s);
    return Routes.staffSupport;
  }),
  A11yScreen('staff escalations', moderator, (s) {
    openAppeal(s);
    return '/staff/escalations';
  }),
  A11yScreen('staff users', moderator, (s) {
    openAppeal(s);
    return Routes.staffUsers;
  }),
  A11yScreen('staff user detail', moderator, (s) {
    openAppeal(s);
    return Routes.staffUser(s.db.accountByEmail(karan)!.id);
  }),
  A11yScreen('staff listings', moderator, (s) {
    openAppeal(s);
    return '/staff/listings';
  }),
  A11yScreen('admin reports', 'admin@unirent.in', (_) => Routes.staffReports),
  A11yScreen(
    'admin reconciliation report',
    'admin@unirent.in',
    (_) =>
        Routes.staffReconciliationRun('00000000-0000-4000-f100-000000000002'),
  ),
  A11yScreen(
    'admin late-fee rule',
    'admin@unirent.in',
    (_) => '/staff/late-fee',
  ),
  A11yScreen(
    'admin moderators',
    'admin@unirent.in',
    (_) => '/staff/moderators',
  ),
];

/// Opens [screen] on a 360x780 phone.
Future<TestApp> openScreen(WidgetTester tester, A11yScreen screen) async {
  final server = MockServer();
  final location = screen.setup(server);
  final app = screen.email == null
      ? await pumpTestApp(tester, server: server)
      : await as(tester, server, screen.email!, location: location);
  if (screen.email == null && location != null) {
    app.router.go(location);
  }
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  await tester.pumpAndSettle();
  return app;
}

/// Uses the dark theme until the test ends.
void useDarkTheme(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Scales text by [factor] until the test ends.
void useTextScale(WidgetTester tester, double factor) {
  tester.platformDispatcher.textScaleFactorTestValue = factor;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The screen's main vertical scrollable (the one with most to scroll).
ScrollableState? mainScrollable(WidgetTester tester) {
  ScrollableState? best;
  for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    if (state.axisDirection != AxisDirection.down &&
        state.axisDirection != AxisDirection.up) {
      continue;
    }
    if (!state.position.hasContentDimensions) continue;
    if (best == null ||
        state.position.maxScrollExtent > best.position.maxScrollExtent) {
      best = state;
    }
  }
  return best;
}

/// Runs [check] on each screenful, scrolling down through the screen.
Future<void> eachScreenful(
  WidgetTester tester,
  Future<void> Function() check,
) async {
  await check();
  for (var i = 0; i < 12; i++) {
    final scrollable = mainScrollable(tester);
    if (scrollable == null) return;
    final position = scrollable.position;
    if (position.pixels >= position.maxScrollExtent) return;
    position.jumpTo(
      (position.pixels + position.viewportDimension * 0.8).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await tester.pumpAndSettle();
    await check();
  }
}
