import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/bookings/booking_format.dart';
import 'package:unirent/ui/ui.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
final dslr = mockListingId(1);
final gopro = mockListingId(2); // Karan's: ₹50/hr, ₹350/day
final ashaBike = mockListingId(3);
final meeraCycle = mockListingId(4); // sale ₹4,500
const karanBikeRequest = '00000000-0000-4000-d000-000000000001';
const meeraBikeRequest = '00000000-0000-4000-d000-000000000002';
const devCalculatorRequest = '00000000-0000-4000-d000-000000000003';

Future<TestApp> openRequest(
  WidgetTester tester,
  String listingId, {
  MockServer? server,
}) async {
  final app = await pumpSignedIn(tester, asha, server: server);
  unawaited(app.router.push(Routes.listingRequest(listingId)));
  await tester.pumpAndSettle();
  return app;
}

Finder cardOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(AppCard));

Finder buttonIn(Finder card, String label) =>
    find.descendant(of: card, matching: find.text(label));

void main() {
  group('requesting', () {
    testWidgets('rent: quote for the default period, then send', (
      tester,
    ) async {
      final server = MockServer();
      final app = await openRequest(tester, gopro, server: server);

      expect(find.widgetWithText(AppBar, 'Request to rent'), findsOneWidget);
      expect(find.text('Times are in IST.'), findsOneWidget);
      expect(find.text('Rent for 1 day'), findsOneWidget);
      expect(find.text('₹350'), findsOneWidget);
      expect(find.textContaining('grace period'), findsOneWidget);

      await app.tapText('Send request');
      final booking = server.db.bookings.values.singleWhere(
        (b) => b.listingId == gopro,
      );
      expect(booking.status, BookingStatus.requested);
      expect(booking.amountPaise, 35000);
      expect(booking.renterId, server.db.accountByEmail(asha)!.id);
      expect(booking.endAt!.difference(booking.startAt!).inHours, 24);
      expect(app.location, Routes.booking(booking.id));
      expect(find.text('Request sent to Karan Mehta'), findsOneWidget);
    });

    testWidgets('sale: confirm the price and send without dates', (
      tester,
    ) async {
      final server = MockServer();
      final app = await openRequest(tester, meeraCycle, server: server);
      expect(find.widgetWithText(AppBar, 'Request to buy'), findsOneWidget);
      expect(find.text('From'), findsNothing);
      expect(find.text('₹4,500'), findsOneWidget);

      await app.tapText('Send request');
      final booking = server.db.bookings.values.singleWhere(
        (b) => b.listingId == meeraCycle,
      );
      expect(booking.kind, TradeKind.sale);
      expect(booking.startAt, isNull);
      expect(booking.amountPaise, 450000);
    });

    testWidgets('an open request for the same item is refused', (tester) async {
      final server = MockServer();
      final app = await openRequest(tester, meeraCycle, server: server);
      await app.tapText('Send request');
      unawaited(app.router.push(Routes.listingRequest(meeraCycle)));
      await tester.pumpAndSettle();
      await app.tapText('Send request');
      expect(
        find.text('You already have an open request for this item.'),
        findsOneWidget,
      );
      expect(
        server.db.bookings.values.where((b) => b.listingId == meeraCycle),
        hasLength(1),
      );
    });

    testWidgets('booked times are refused with a clear message', (
      tester,
    ) async {
      final server = MockServer();
      final now = DateTime.now().toUtc();
      server.db.listings[dslr]!.unavailable
        ..clear()
        ..add(
          BlockedSlot(startAt: now, endAt: now.add(const Duration(days: 10))),
        );
      final app = await openRequest(tester, dslr, server: server);
      expect(find.text('Already booked:'), findsOneWidget);
      await app.tapText('Send request');
      expect(
        find.text('Those times are already booked. Pick different times.'),
        findsOneWidget,
      );
    });
  });

  group('incoming requests', () {
    testWidgets('owners see requesters with trust and approve one', (
      tester,
    ) async {
      final server = MockServer();
      final app = await pumpSignedIn(tester, asha, server: server);
      await app.tap(find.widgetWithText(NavigationDestination, 'Listings'));
      expect(find.text('3 booking requests waiting'), findsOneWidget);

      await app.tapText('3 booking requests waiting');
      expect(app.location, Routes.incomingRequests);

      final karan = cardOf('Karan Mehta');
      expect(
        find.descendant(of: karan, matching: find.text('58')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: karan, matching: find.text('2 cancellations')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardOf('Meera Iyer'), matching: find.text('New')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardOf('Dev Patel'), matching: find.text('90')),
        findsOneWidget,
      );

      await app.tap(buttonIn(karan, 'Approve'));
      expect(
        server.db.bookings[karanBikeRequest]!.status,
        BookingStatus.approved,
      );
      // Meera wanted overlapping times.
      final meera = server.db.bookings[meeraBikeRequest]!;
      expect(meera.status, BookingStatus.declined);
      expect(meera.declineReason, contains('Another request'));
      expect(find.text('Karan Mehta'), findsNothing);
      expect(find.text('Meera Iyer'), findsNothing);
      expect(find.text('Dev Patel'), findsOneWidget);
    });

    testWidgets('decline with a reason', (tester) async {
      final server = MockServer();
      final app = await pumpSignedIn(tester, asha, server: server);
      unawaited(app.router.push(Routes.incomingRequests));
      await tester.pumpAndSettle();

      await app.tap(buttonIn(cardOf('Dev Patel'), 'Decline'));
      await app.enterField('Reason (optional)', 'I need it that week');
      await app.tap(find.widgetWithText(FilledButton, 'Decline'));
      final dev = server.db.bookings[devCalculatorRequest]!;
      expect(dev.status, BookingStatus.declined);
      expect(dev.declineReason, 'I need it that week');
      expect(find.text('Dev Patel'), findsNothing);
    });

    testWidgets('a listing’s banner opens just its requests', (tester) async {
      final app = await pumpSignedIn(tester, asha);
      unawaited(app.router.push(Routes.listing(ashaBike)));
      await tester.pumpAndSettle();
      await app.tapText('2 booking requests are waiting for you');
      expect(app.location, Routes.listingRequests(ashaBike));
      expect(find.text('Karan Mehta'), findsOneWidget);
      expect(find.text('Meera Iyer'), findsOneWidget);
      expect(find.text('Dev Patel'), findsNothing);
    });
  });

  group('mock booking rules', () {
    ApiClient client(MockServer server) => ApiClient(
      config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
      tokenStore: MemoryTokenStore(),
      mockServer: server,
    );

    Future<ApiClient> signedIn(MockServer server) async {
      final c = client(server);
      final token = await c.api.auth.mockMicrosoftToken(
        const MockTokenRequest(email: asha),
      );
      await c.saveSession(
        await c.api.auth.signInWithMicrosoft(
          MicrosoftSignIn(idToken: token.idToken),
        ),
      );
      return c;
    }

    test('a retried request with the same key creates one booking', () async {
      final server = MockServer();
      final c = await signedIn(server);
      const body = BookingCreate(
        listingId: '00000000-0000-4000-b000-000000000004',
      );
      final first = await c.api.bookings.requestBooking(
        body,
        idempotencyKey: 'tap-1',
      );
      final again = await c.api.bookings.requestBooking(
        body,
        idempotencyKey: 'tap-1',
      );
      expect(again.id, first.id);
      expect(
        server.db.bookings.values.where((b) => b.listingId == meeraCycle),
        hasLength(1),
      );
    });

    test('quotes validate the period', () async {
      final c = await signedIn(MockServer());
      final now = DateTime.now().toUtc();
      Matcher code(String c) =>
          throwsA(isA<ApiException>().having((e) => e.code, 'code', c));
      await expectLater(
        c.api.bookings.quote(
          listingId: gopro,
          startAt: now.subtract(const Duration(hours: 2)),
          endAt: now.add(const Duration(hours: 2)),
        ),
        code('START_IN_PAST'),
      );
      await expectLater(
        c.api.bookings.quote(
          listingId: gopro,
          startAt: now.add(const Duration(hours: 1)),
          endAt: now.add(const Duration(days: 40)),
        ),
        code('PERIOD_TOO_LONG'),
      );
      await expectLater(
        c.api.bookings.quote(
          listingId: meeraCycle,
          startAt: now.add(const Duration(hours: 1)),
          endAt: now.add(const Duration(hours: 3)),
        ),
        code('NO_PERIOD_FOR_SALE'),
      );
    });

    test('rent uses the cheapest mix of rates', () {
      final l = MockListing(
        id: 'l',
        ownerId: 'o',
        assetId: 'a',
        kind: TradeKind.rent,
        title: 't',
        category: ListingCategory.other,
        pickupPoint: 'p',
        createdAt: DateTime.utc(2026),
        pricePerHourPaise: 5000,
        pricePerDayPaise: 35000,
      );
      final start = DateTime.utc(2026, 1, 1);
      expect(
        mockRentalHours(start, start.add(const Duration(minutes: 130))),
        3,
      );
      expect(mockRentFor(l, 3), 15000);
      expect(mockRentFor(l, 23), 35000); // capped at a day
      expect(mockRentFor(l, 26), 45000); // a day plus 2 hours
    });
  });

  test('booking formatting', () {
    expect(durationLabel(3), '3 hours');
    expect(durationLabel(24), '1 day');
    expect(durationLabel(49), '2 days 1 hour');
    expect(
      periodLabel(
        DateTime.utc(2026, 10, 28, 4, 30),
        DateTime.utc(2026, 10, 28, 12, 30),
      ),
      'Wed, 28 Oct, 10:00 AM – 6:00 PM',
    );
    // 10:20 IST → the start of 12:00 IST.
    expect(
      nextIstHour(DateTime.utc(2026, 10, 28, 4, 50), plusHours: 2),
      DateTime.utc(2026, 10, 28, 6, 30),
    );
  });
}
