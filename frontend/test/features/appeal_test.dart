import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';

import '../helpers/booking_helpers.dart';

const asha = 'asha@college.edu';
const dev = 'dev@college.edu';
const meera = 'meera@college.edu';

/// Asha has returned Dev's DSLR; they haven't settled the charges yet.
MockBooking returnedDslr(MockServer server) {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final b =
      MockBooking(
          id: 'b-dslr',
          listingId: mockListingId(1),
          kind: TradeKind.rent,
          renterId: db.accountByEmail(asha)!.id,
          ownerId: db.accountByEmail(dev)!.id,
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
  return db.bookings[b.id] = b;
}

MockBooking boughtCycle(MockServer server) {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final b = MockBooking(
    id: 'b-sale',
    listingId: mockListingId(4),
    kind: TradeKind.sale,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: db.accountByEmail(meera)!.id,
    amountPaise: 450000,
    createdAt: now.subtract(const Duration(days: 3)),
    status: BookingStatus.completed,
  )..pickupCompletedAt = now.subtract(const Duration(hours: 2));
  return db.bookings[b.id] = b;
}

Finder reason(String label) =>
    find.widgetWithText(RadioListTile<AppealReason>, label);

void main() {
  testWidgets('either side files an appeal on a returned rental, with photos', (
    tester,
  ) async {
    final server = MockServer();
    final b = returnedDslr(server);
    var app = await openBookingAs(tester, server, asha, b.id);
    expect(find.text('Can’t agree on the charges?'), findsOneWidget);
    await app.tapText('File an appeal');
    expect(app.location, Routes.bookingAppeal(b.id));
    expect(reason('We can’t agree on the damage or late fee'), findsOneWidget);
    expect(reason('The item isn’t what was listed'), findsOneWidget);
    expect(reason('Something else'), findsOneWidget);

    await app.tapText('File appeal');
    expect(find.text('Choose what went wrong'), findsOneWidget);
    expect(
      find.text('Describe what happened (at least 5 characters)'),
      findsOneWidget,
    );
    expect(server.db.appeals, isEmpty);

    await app.tap(reason('We can’t agree on the damage or late fee'));
    await app.enterField(
      'Details',
      'The hood was already cracked at pickup; see my photos.',
    );
    await app.tapText('Add photos');
    await app.tapText('Choose from gallery');
    expect(find.text('Photo 1'), findsOneWidget);
    await app.tapText('Add photos');
    await app.tapText('Choose from gallery');
    await app.tap(find.byTooltip('Remove photo 1'));
    expect(find.text('Photo 1'), findsOneWidget);
    expect(find.text('Photo 2'), findsNothing);

    await app.tapText('File appeal');
    expect(app.location, Routes.booking(b.id));
    expect(
      find.text('Appeal filed. A moderator will look at it.'),
      findsOneWidget,
    );
    expect(find.text('Appeal under review'), findsOneWidget);
    expect(find.text('File an appeal'), findsNothing);
    expect(find.textContaining('In appeal'), findsOneWidget);

    final appeal = server.db.appeals.values.single;
    expect(appeal.reason, AppealReason.damageDispute);
    expect(appeal.filedBy, TradeRole.renter);
    expect(appeal.previousStatus, BookingStatus.returning);
    expect(appeal.photoKeys.single, startsWith('appeal/'));
    expect(b.status, BookingStatus.inAppeal);

    // The owner sees it too, and can't file a second one meanwhile.
    app = await openBookingAs(tester, server, dev, b.id);
    expect(find.text('Appeal under review'), findsOneWidget);
    expect(find.text('File an appeal'), findsNothing);

    // Once ruled the booking is back in returning: the ruling shows and
    // either side may appeal again.
    appeal.status = AppealStatus.ruled;
    b.status = BookingStatus.returning;
    app = await openBookingAs(tester, server, dev, b.id);
    expect(find.text('Appeal ruled'), findsOneWidget);
    await app.tapText('File an appeal');
    // The owner's reasons: no "not what was listed".
    expect(reason('We can’t agree on the damage or late fee'), findsOneWidget);
    expect(reason('The item isn’t what was listed'), findsNothing);
  });

  testWidgets('a buyer appeals a purchase that isn’t as described', (
    tester,
  ) async {
    final server = MockServer();
    final b = boughtCycle(server);
    final app = await as(tester, server, asha);
    // From a link: the booking sits under the form.
    app.router.go(Routes.bookingAppeal(b.id));
    await tester.pumpAndSettle();
    expect(reason('We can’t agree on the damage or late fee'), findsNothing);
    await app.tap(reason('The item isn’t what was listed'));
    await app.enterField('Details', 'The gears don’t shift at all.');
    await app.tapText('File appeal');

    expect(b.status, BookingStatus.inAppeal);
    expect(server.db.appeals.values.single.reason, AppealReason.itemMismatch);
    expect(server.db.appeals.values.single.photoKeys, isEmpty);
    expect(app.location, Routes.booking(b.id));
    expect(find.text('Appeal under review'), findsOneWidget);
  });

  testWidgets('a booking that can’t be appealed says so', (tester) async {
    final server = MockServer();
    final b = returnedDslr(server)..returnCompletedAt = null;
    await as(tester, server, asha, location: Routes.bookingAppeal(b.id));
    expect(find.text('This booking can’t be appealed now'), findsOneWidget);
    expect(find.text('File appeal'), findsNothing);
  });
}
