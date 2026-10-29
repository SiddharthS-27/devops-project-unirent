import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/ui/ui.dart' as ui;

import '../helpers/booking_helpers.dart';
import '../helpers/test_app.dart';

// Two phones on one mock backend: each step pumps the app as whoever acts.
const asha = 'asha@college.edu';
const dev = 'dev@college.edu';
const meera = 'meera@college.edu';
const karan = 'karan@college.edu';

String bookingIdFrom(TestApp app) {
  expect(app.location, startsWith('/bookings/'));
  return app.location.split('/').last;
}

Future<String> requestAs(
  WidgetTester tester,
  MockServer server,
  String email,
  String listingId,
) async {
  final app = await as(
    tester,
    server,
    email,
    location: Routes.listingRequest(listingId),
  );
  await app.tapText('Send request');
  return bookingIdFrom(app);
}

ui.TimelineStepState? timelineState(WidgetTester tester, String title) => tester
    .widget<ui.StatusTimeline>(find.byType(ui.StatusTimeline))
    .steps
    .where((s) => s.title == title)
    .firstOrNull
    ?.state;

/// Rates every parameter [stars] and submits [comment].
Future<void> rateAll(TestApp app, int stars, String comment) async {
  final inputs = find.byType(ui.StarRatingInput);
  final count = inputs.evaluate().length;
  for (var i = 0; i < count; i++) {
    await app.tap(
      find
          .descendant(
            of: inputs.at(i),
            matching: find.byTooltip(stars == 1 ? '1 star' : '$stars stars'),
          )
          .first,
    );
  }
  await app.enterField('Comment', comment);
  await app.tapText('Submit review');
}

void main() {
  testWidgets('full rental with UPI: request to reviews', (tester) async {
    final server = MockServer();
    final dslr = mockListingId(1);
    server.db.listings[dslr]!.unavailable.clear();

    // Asha asks to rent Dev's camera for a day.
    final id = await requestAs(tester, server, asha, dslr);
    final b = server.db.bookings[id]!;
    expect(b.status, BookingStatus.requested);

    // Dev approves and adds his pickup photos.
    var app = await openBookingAs(tester, server, dev, id);
    expect(find.text('Approve or decline the request'), findsOneWidget);
    await app.tap(find.widgetWithText(FilledButton, 'Approve'));
    expect(b.status, BookingStatus.approved);
    await addPhotosVia(app, 'Your photos');
    expect(find.text('Waiting for their photos'), findsOneWidget);

    // Asha adds hers, pays by UPI and shows her code.
    app = await openBookingAs(tester, server, asha, id);
    await addPhotosVia(app, 'Your photos');
    expect(find.text('Pay by UPI or cash'), findsOneWidget);
    await tapStep(app, 'Payment', 'Pay');
    await app.tapText('UPI');
    await app.tapText('Pay ₹400');
    expect(b.paymentFor(PaymentPurpose.rent)!.status, PaymentStatus.captured);
    await tapStep(app, 'Show your code', 'Show code');
    final pickupCode = shownCode(tester);

    // Dev types it: the rental starts.
    app = await openBookingAs(tester, server, dev, id);
    await app.enterOtp(pickupCode);
    expect(b.status, BookingStatus.active);
    expect(find.text('Rental in progress'), findsOneWidget);

    // Asha wants another day; Dev approves; she pays by UPI.
    app = await openBookingAs(tester, server, asha, id);
    expect(find.textContaining('Time left:'), findsOneWidget);
    await app.tapText('Ask for more time');
    await app.tapText('OK');
    await app.tapText('OK');
    app = await openBookingAs(tester, server, dev, id);
    await app.tap(find.widgetWithText(FilledButton, 'Approve'));
    expect(b.extensions.single.status, ExtensionStatus.approved);
    app = await openBookingAs(tester, server, asha, id);
    expect(find.text('Pay for the extra time'), findsOneWidget);
    await app.tap(find.widgetWithText(FilledButton, 'Pay ₹400'));
    await app.tapText('UPI');
    await app.tapText('Pay ₹400');
    expect(
      b.paymentFor(PaymentPurpose.extension, b.extensions.single.id)!.isPaid,
      isTrue,
    );

    // The return: Asha starts it and adds photos.
    await app.tap(find.widgetWithText(FilledButton, 'Start the return'));
    await confirmDialog(app, 'Start return');
    await addPhotosVia(app, 'Renter’s return photos');

    // Dev inspects and shows his code.
    app = await openBookingAs(tester, server, dev, id);
    await addPhotosVia(app, 'Owner’s inspection photos');
    await tapStep(app, 'Show your code', 'Show code');
    final returnCode = shownCode(tester);

    // Asha types it; nothing is owed (on time, extension paid).
    app = await openBookingAs(tester, server, asha, id);
    await app.enterOtp(returnCode);
    expect(b.returnCompletedAt, isNotNull);
    expect(find.text('Waiting for the owner to finish'), findsOneWidget);

    // Dev proceeds: reviews open, and reviewing is compulsory.
    app = await openBookingAs(tester, server, dev, id);
    await tapStep(app, 'Proceed', 'Proceed');
    await confirmDialog(app, 'Proceed');
    expect(b.status, BookingStatus.awaitingReviews);
    expect(b.amountPaise, 80000); // rent + extension
    expect(app.location, Routes.bookingReview(id));
    expect(find.text('How was Asha Verma?'), findsOneWidget);
    await rateAll(app, 5, 'Careful with the camera, on time');

    // Dev's review is in but hidden; Asha is sent to hers on sign-in.
    expect(find.text('Waiting for their review'), findsOneWidget);
    expect(timelineState(tester, 'Reviews'), ui.TimelineStepState.current);
    app = await as(tester, server, asha);
    expect(app.location, Routes.bookingReview(id));
    await rateAll(app, 4, 'Great camera, quick handover');

    // Both in: revealed, completed.
    expect(b.status, BookingStatus.completed);
    expect(find.text('Their review of you'), findsOneWidget);
    expect(find.text('“Careful with the camera, on time”'), findsOneWidget);
    expect(find.text('“Great camera, quick handover”'), findsOneWidget);
    final asset = server.db.assets[server.db.listings[dslr]!.assetId]!;
    expect(asset.history.last.kind, AssetEventKind.returned);
  });

  testWidgets('sale paid in cash: request to reviews', (tester) async {
    final server = MockServer();
    final cycle = mockListingId(4); // Meera's, ₹4,500, no payout account
    final id = await requestAs(tester, server, asha, cycle);
    final b = server.db.bookings[id]!;

    var app = await openBookingAs(tester, server, meera, id);
    await app.tap(find.widgetWithText(FilledButton, 'Approve'));
    await addPhotosVia(app, 'Your photos');

    app = await openBookingAs(tester, server, asha, id);
    expect(find.text('Handover'), findsWidgets);
    await addPhotosVia(app, 'Your photos');
    await tapStep(app, 'Payment', 'Pay');
    await app.tapText('Cash');
    expect(find.text('Waiting for cash to be marked'), findsOneWidget);

    app = await openBookingAs(tester, server, meera, id);
    await tapStep(app, 'Payment', 'Mark cash received');
    await confirmDialog(app, 'I have the cash');
    expect(b.payments.single.status, PaymentStatus.markedPaid);
    expect(find.text('Enter the renter\'s code'), findsOneWidget);

    app = await openBookingAs(tester, server, asha, id);
    await tapStep(app, 'Show your code', 'Show code');
    final code = shownCode(tester);

    app = await openBookingAs(tester, server, meera, id);
    await app.enterOtp(code);
    expect(b.status, BookingStatus.awaitingReviews);
    expect(server.db.listings[cycle]!.status, ListingStatus.sold);
  });

  testWidgets('owner cancels after approval; the renter rates it', (
    tester,
  ) async {
    final server = MockServer();
    final id = await requestAs(tester, server, asha, mockListingId(2));
    final b = server.db.bookings[id]!;

    var app = await openBookingAs(tester, server, karan, id);
    await app.tap(find.widgetWithText(FilledButton, 'Approve'));
    await app.tapText('Cancel booking');
    await app.enterField('Why are you cancelling?', 'The battery died, sorry');
    await confirmDialog(app, 'Cancel booking');
    expect(b.status, BookingStatus.cancelled);

    app = await openBookingAs(tester, server, asha, id);
    expect(find.text('Karan Mehta cancelled'), findsOneWidget);
    expect(find.text('“The battery died, sorry”'), findsOneWidget);
    await app.tap(find.byTooltip('3 stars'));
    await app.enterField('Comment', 'Last-minute, but polite');
    await app.tapText('Submit rating');
    expect(b.cancellation!.ratingStars, 3);
    expect(find.text('Submit rating'), findsNothing);
  });

  testWidgets('late return: fee frozen at return, paid in cash', (
    tester,
  ) async {
    final server = MockServer();
    final now = DateTime.now().toUtc();
    final b = server.db.bookings['b-late'] = MockBooking(
      id: 'b-late',
      listingId: mockListingId(1),
      kind: TradeKind.rent,
      renterId: server.db.accountByEmail(asha)!.id,
      ownerId: server.db.accountByEmail(dev)!.id,
      amountPaise: 40000,
      createdAt: now.subtract(const Duration(days: 2)),
      startAt: now.subtract(const Duration(days: 1)),
      endAt: now.subtract(const Duration(hours: 3)),
      status: BookingStatus.active,
    )..pickupCompletedAt = now.subtract(const Duration(days: 1));

    var app = await openBookingAs(tester, server, asha, b.id);
    expect(b.status, BookingStatus.overdue);
    expect(find.text('Late fee so far: ₹66'), findsOneWidget);
    await app.tap(find.widgetWithText(FilledButton, 'Start the return'));
    await confirmDialog(app, 'Start return');
    await addPhotosVia(app, 'Renter’s return photos');

    app = await openBookingAs(tester, server, dev, b.id);
    await addPhotosVia(app, 'Owner’s inspection photos');
    await tapStep(app, 'Show your code', 'Show code');
    final code = shownCode(tester);

    app = await openBookingAs(tester, server, asha, b.id);
    await app.enterOtp(code);
    expect(b.frozenLateFeePaise, 6600);
    await tapStep(app, 'Charges', 'Pay');
    await app.tapText('Cash');

    app = await openBookingAs(tester, server, dev, b.id);
    expect(find.text('Late fee'), findsOneWidget);
    await tapStep(app, 'Charges', 'Mark cash received');
    await confirmDialog(app, 'I have the cash');
    await tapStep(app, 'Proceed', 'Proceed');
    await confirmDialog(app, 'Proceed');
    expect(b.status, BookingStatus.awaitingReviews);
  });
}
