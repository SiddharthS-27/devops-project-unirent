import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/bookings/widgets/booking_tile.dart';
import 'package:unirent/features/listings/listing_providers.dart';
import 'package:unirent/ui/ui.dart' as ui;

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
final gopro = mockListingId(2); // Karan's
const karanBikeRequest = '00000000-0000-4000-d000-000000000001';

/// A booking where Asha rents Karan's GoPro.
MockBooking ashaRentsGopro(
  MockServer server, {
  String id = 'b-asha-gopro',
  BookingStatus status = BookingStatus.requested,
  Duration startIn = const Duration(days: 1),
}) {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final start = now.add(startIn);
  final b = MockBooking(
    id: id,
    listingId: gopro,
    kind: TradeKind.rent,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: db.accountByEmail('karan@college.edu')!.id,
    amountPaise: 35000,
    createdAt: now.subtract(const Duration(hours: 1)),
    startAt: start,
    endAt: start.add(const Duration(days: 1)),
    status: status,
  );
  return db.bookings[id] = b;
}

Future<TestApp> openBooking(
  WidgetTester tester,
  String id, {
  MockServer? server,
  List<String>? calls,
  FakePushService? push,
}) async {
  final app = await pumpSignedIn(
    tester,
    asha,
    server: server,
    push: push,
    overrides: [
      phoneCallerProvider.overrideWithValue((phone) async {
        calls?.add(phone);
        return true;
      }),
    ],
  );
  unawaited(app.router.push(Routes.booking(id)));
  await tester.pumpAndSettle();
  return app;
}

ui.TimelineStepState? timelineState(WidgetTester tester, String title) => tester
    .widget<ui.StatusTimeline>(find.byType(ui.StatusTimeline))
    .steps
    .where((s) => s.title == title)
    .firstOrNull
    ?.state;

void main() {
  testWidgets('renter view of a pending request', (tester) async {
    final server = MockServer();
    final b = ashaRentsGopro(server);
    final calls = <String>[];
    final app = await openBooking(tester, b.id, server: server, calls: calls);

    expect(find.text('GoPro Hero 9 action camera'), findsOneWidget);
    expect(find.text('Waiting for the owner'), findsOneWidget);
    expect(
      find.text('The owner has 24 hours to approve or decline.'),
      findsOneWidget,
    );
    expect(timelineState(tester, 'Requested'), ui.TimelineStepState.current);
    expect(timelineState(tester, 'Pickup'), ui.TimelineStepState.upcoming);

    // Owner card: lender trust, phone, but no residence before approval.
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Karan Mehta'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    await app.tapText('Call Karan');
    expect(calls, ['+919876500002']);

    await app.tap(find.byTooltip('Help'));
    expect(app.location, Routes.helpFor(bookingId: 'b-asha-gopro'));
  });

  testWidgets('owner approves from the card; residence then shows', (
    tester,
  ) async {
    final server = MockServer();
    final app = await openBooking(tester, karanBikeRequest, server: server);
    expect(find.text('Approve or decline the request'), findsOneWidget);
    expect(find.text('Renter'), findsOneWidget);
    expect(find.text('58'), findsOneWidget); // Karan's renter trust

    await app.tap(find.widgetWithText(FilledButton, 'Approve'));
    expect(
      server.db.bookings[karanBikeRequest]!.status,
      BookingStatus.approved,
    );
    expect(find.text('Upload pickup photos'), findsOneWidget);
    expect(timelineState(tester, 'Approved'), ui.TimelineStepState.done);
    expect(timelineState(tester, 'Pickup'), ui.TimelineStepState.current);
    expect(find.text('Narmada Hostel, room C-12'), findsOneWidget);
  });

  testWidgets('payments are listed with method, status and time', (
    tester,
  ) async {
    final server = MockServer();
    final b = ashaRentsGopro(server, status: BookingStatus.approved);
    b.payments.add(
      MockPayment(
          id: 'p1',
          bookingId: b.id,
          purpose: PaymentPurpose.rent,
          method: PaymentMethod.upi,
          amountPaise: 35000,
          items: const [PaymentItem(label: 'Rent', amountPaise: 35000)],
          createdAt: DateTime.utc(2026, 10, 27, 9, 35),
          payerId: b.renterId,
          payeeId: b.ownerId,
        )
        ..status = PaymentStatus.captured
        ..capturedAt = DateTime.utc(2026, 10, 27, 9, 35),
    );
    await openBooking(tester, b.id, server: server);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('UPI · Paid · 27 Oct 2026, 3:05 PM'), findsOneWidget);
    expect(find.text('₹350'), findsWidgets);
  });

  testWidgets('an ended booking shows how it ended and no next step', (
    tester,
  ) async {
    final server = MockServer();
    final b = ashaRentsGopro(server, status: BookingStatus.declined);
    await openBooking(tester, b.id, server: server);
    expect(timelineState(tester, 'Declined'), ui.TimelineStepState.current);
    expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
    expect(find.byIcon(Icons.hourglass_empty), findsNothing);
  });

  testWidgets('a push about the open booking refetches it', (tester) async {
    final server = MockServer();
    final b = ashaRentsGopro(server);
    final push = FakePushService();
    await openBooking(tester, b.id, server: server, push: push);
    expect(find.text('Waiting for the owner'), findsOneWidget);

    // The owner approves elsewhere; a push arrives.
    b
      ..status = BookingStatus.approved
      ..decidedAt = DateTime.now().toUtc();
    push.receivedPushes.add(Uri.parse('unirent://bookings/${b.id}'));
    await tester.pumpAndSettle();
    expect(find.text('Upload pickup photos'), findsOneWidget);
  });

  testWidgets('tapping a notification opens its booking', (tester) async {
    final server = MockServer();
    final b = ashaRentsGopro(server);
    final push = FakePushService();
    final app = await pumpSignedIn(tester, asha, server: server, push: push);
    push.openedPushes.add(Uri.parse('unirent://bookings/${b.id}'));
    await tester.pumpAndSettle();
    expect(app.location, Routes.booking(b.id));
    expect(find.text('Waiting for the owner'), findsOneWidget);
  });

  group('Bookings tab', () {
    List<String> titles(WidgetTester tester) => [
      for (final t in tester.widgetList<BookingTile>(find.byType(BookingTile)))
        t.booking.listingTitle,
    ];

    testWidgets('groups and sides', (tester) async {
      final server = MockServer();
      ashaRentsGopro(server, id: 'b-pending');
      final app = await pumpSignedIn(tester, asha, server: server);
      await app.tap(find.widgetWithText(NavigationDestination, 'Bookings'));

      // Active is the first tab shown; nothing is active yet.
      expect(find.text('Nothing here'), findsOneWidget);
      await app.tap(find.widgetWithText(Tab, 'Pending'));
      expect(titles(tester), ['GoPro Hero 9 action camera']);
      expect(find.text('Waiting for the owner'), findsOneWidget);

      await app.tapText('Lending & selling');
      expect(titles(tester), hasLength(3)); // seeded requests to Asha
      expect(find.text('Approve or decline the request'), findsNWidgets(3));
    });

    testWidgets('long lists load more on request', (tester) async {
      final server = MockServer();
      for (var i = 0; i < 25; i++) {
        ashaRentsGopro(
          server,
          id: 'b$i',
          status: BookingStatus.completed,
          startIn: Duration(days: -30 - i),
        );
      }
      final app = await pumpSignedIn(tester, asha, server: server);
      await app.tap(find.widgetWithText(NavigationDestination, 'Bookings'));
      await app.tap(find.widgetWithText(Tab, 'Past'));
      final list = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.text('Show more'),
        400,
        scrollable: list.first,
      );
      await app.tapText('Show more');
      // All 25 are loaded and there is nothing further to fetch.
      await tester.drag(list.first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.text('Show more'), findsNothing);
      expect(find.byType(BookingTile), findsWidgets);
    });
  });
}
