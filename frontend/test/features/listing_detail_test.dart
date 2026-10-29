import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/listings/listing_detail_screen.dart';
import 'package:unirent/features/listings/listing_format.dart';
import 'package:unirent/features/listings/listing_providers.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
final dslr = mockListingId(1); // Dev's camera, rent, booked slot, serial
final ashaBike = mockListingId(3); // Asha's own rental
final meeraCycle = mockListingId(4); // for sale
final meeraGuitar = mockListingId(7); // owner is New

Future<TestApp> openListing(
  WidgetTester tester,
  String id, {
  MockServer? server,
  List<String>? calls,
}) async {
  final app = await pumpSignedIn(
    tester,
    asha,
    server: server,
    overrides: [
      phoneCallerProvider.overrideWithValue((phone) async {
        calls?.add(phone);
        return true;
      }),
    ],
  );
  unawaited(app.router.push(Routes.listing(id)));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('a rental shows prices, fees, availability, item and owner', (
    tester,
  ) async {
    final calls = <String>[];
    final app = await openListing(tester, dslr, calls: calls);

    expect(find.text('Canon EOS 1500D DSLR with 18-55mm lens'), findsOne);
    expect(find.text('₹400/day · ₹60/hr'), findsOneWidget);
    expect(find.textContaining('Central library entrance'), findsOneWidget);

    // Late-fee rule with grace period.
    expect(find.text('Late returns'), findsOneWidget);
    expect(find.textContaining('₹50'), findsOneWidget);
    expect(find.textContaining('30-minute grace period'), findsOneWidget);
    expect(find.textContaining('2% of the rent'), findsOneWidget);

    // Booked slot, in IST.
    expect(find.text('Already booked at these times:'), findsOneWidget);
    expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);

    // Asset: masked serial and history.
    expect(find.textContaining('1209'), findsOneWidget);
    expect(find.text('CN1500D-77341209'), findsNothing);
    expect(find.text('Like new'), findsOneWidget);
    expect(find.text('Listed by Dev Patel'), findsOneWidget);
    expect(find.text('Returned on time'), findsOneWidget);

    // Owner card.
    expect(find.text('Dev Patel'), findsOneWidget);
    expect(find.text('92'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('No cancellations'), findsOneWidget);

    await app.tapText('Call Dev');
    expect(calls, ['+919876500004']);

    await app.tapText('Request to rent');
    expect(app.location, Routes.listingRequest(dslr));
    expect(find.widgetWithText(AppBar, 'Request to rent'), findsOneWidget);
    expect(find.text('Send request'), findsOneWidget);
  });

  testWidgets('a sale listing asks to buy and has no late fees', (
    tester,
  ) async {
    await openListing(tester, meeraCycle);
    expect(find.text('₹4,500'), findsOneWidget);
    expect(find.text('Request to buy'), findsOneWidget);
    expect(find.text('Late returns'), findsNothing);
    expect(find.text('Availability'), findsNothing);
  });

  testWidgets('a New owner gets the New badge and no rating', (tester) async {
    await openListing(tester, meeraGuitar);
    expect(find.text('New'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(
      find.text('No bookings yet, so it’s free whenever you need it.'),
      findsOneWidget,
    );
  });

  testWidgets('owners can pause and resume their listing', (tester) async {
    // Two seeded requests (Karan and Meera) are waiting on the bike.
    final server = MockServer();
    final app = await openListing(tester, ashaBike, server: server);

    expect(find.text('Your listing'), findsOneWidget);
    expect(find.text('2 booking requests are waiting for you'), findsOne);
    expect(find.text('Request to rent'), findsNothing);
    expect(find.textContaining('Call'), findsNothing);

    await app.tap(find.widgetWithText(OutlinedButton, 'Pause'));
    expect(server.db.listings[ashaBike]!.status, ListingStatus.paused);
    expect(find.widgetWithText(Chip, 'Paused'), findsOneWidget);

    await app.tap(find.widgetWithText(OutlinedButton, 'Resume'));
    expect(server.db.listings[ashaBike]!.status, ListingStatus.active);
    expect(find.widgetWithText(Chip, 'Paused'), findsNothing);

    await app.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    expect(app.location, Routes.listingEdit(ashaBike));
  });

  testWidgets('editing is blocked while a booking is active', (tester) async {
    final server = MockServer();
    server.db.listings[ashaBike]!.locked = true;
    await openListing(tester, ashaBike, server: server);
    expect(find.textContaining('can’t edit this listing'), findsOneWidget);
    final edit = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Edit'),
    );
    expect(edit.onPressed, isNull);
  });

  testWidgets('a missing listing shows a friendly error', (tester) async {
    await openListing(tester, 'missing');
    expect(find.text('This isn’t available any more.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  test('late fee text covers hour-long grace periods and fractions', () {
    final rule = LateFeeRuleOut(
      id: 'r',
      graceMinutes: 60,
      baseFeePaise: 2500,
      hourlyPercentBp: 250,
      effectiveFrom: DateTime.utc(2026),
    );
    expect(lateFeeText(rule), contains('₹25'));
    expect(lateFeeText(rule), contains('1-hour grace period'));
    expect(lateFeeText(rule), contains('2.5% of the rent'));
  });

  test('slot labels are in IST and collapse same-day ranges', () {
    final slot = BlockedSlot(
      startAt: DateTime.utc(2026, 10, 28, 4, 30), // 10:00 AM IST
      endAt: DateTime.utc(2026, 10, 28, 12, 30), // 6:00 PM IST
    );
    expect(slotLabel(slot), 'Wed, 28 Oct, 10:00 AM – 6:00 PM');
  });
}
