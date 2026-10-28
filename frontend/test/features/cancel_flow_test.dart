import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const karanBikeRequest = '00000000-0000-4000-d000-000000000001';

/// Asha rents Karan's GoPro.
MockBooking ashaRentsGopro(
  MockServer server, {
  BookingStatus status = BookingStatus.requested,
}) {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final b = MockBooking(
    id: 'b-asha-gopro',
    listingId: mockListingId(2),
    kind: TradeKind.rent,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: db.accountByEmail('karan@college.edu')!.id,
    amountPaise: 35000,
    createdAt: now.subtract(const Duration(hours: 1)),
    startAt: now.add(const Duration(days: 1)),
    endAt: now.add(const Duration(days: 2)),
    status: status,
  );
  return db.bookings[b.id] = b;
}

MockPayment paidRent(MockBooking b) => MockPayment(
  id: 'pay-${b.id}',
  bookingId: b.id,
  purpose: PaymentPurpose.rent,
  method: PaymentMethod.upi,
  amountPaise: b.amountPaise,
  items: const [],
  createdAt: DateTime.now().toUtc(),
  payerId: b.renterId,
  payeeId: b.ownerId,
)..status = PaymentStatus.captured;

Future<TestApp> open(WidgetTester tester, MockServer server, String id) async {
  final app = await pumpSignedIn(tester, asha, server: server);
  unawaited(app.router.push(Routes.booking(id)));
  await tester.pumpAndSettle();
  return app;
}

Future<void> confirmInDialog(TestApp app, String label) => app.tap(
  find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  ),
);

void main() {
  testWidgets('withdraw a pending request', (tester) async {
    final server = MockServer();
    final b = ashaRentsGopro(server);
    final app = await open(tester, server, b.id);

    await app.tapText('Withdraw request');
    expect(find.text('Withdraw your request?'), findsOneWidget);
    await confirmInDialog(app, 'Withdraw');

    expect(b.status, BookingStatus.withdrawn);
    expect(find.text('Withdraw request'), findsNothing);
    expect(find.text('Withdrawn'), findsWidgets);
  });

  testWidgets('cancel needs a note, which the other side sees', (tester) async {
    final server = MockServer();
    final b = ashaRentsGopro(server, status: BookingStatus.approved);
    final cancellationsBefore = server.db
        .accountByEmail(asha)!
        .cancellationCount;
    final app = await open(tester, server, b.id);

    await app.tapText('Cancel booking');
    expect(find.textContaining('Karan will see your note'), findsOneWidget);
    await confirmInDialog(app, 'Cancel booking');
    expect(find.text('Write at least 5 characters'), findsOneWidget);
    expect(b.status, BookingStatus.approved);

    await app.enterField('Why are you cancelling?', 'My exam moved to then');
    await confirmInDialog(app, 'Cancel booking');

    expect(b.status, BookingStatus.cancelled);
    expect(b.cancellation!.by, TradeRole.renter);
    expect(b.cancellation!.note, 'My exam moved to then');
    expect(
      server.db.accountByEmail(asha)!.cancellationCount,
      cancellationsBefore + 1,
    );
    expect(find.text('You cancelled'), findsOneWidget);
    expect(find.text('“My exam moved to then”'), findsOneWidget);
    expect(find.textContaining('asked to rate'), findsOneWidget);
    expect(find.text('Cancel booking'), findsNothing);
  });

  testWidgets('owners can cancel an approved booking too', (tester) async {
    final server = MockServer();
    final b = server.db.bookings[karanBikeRequest]!
      ..status = BookingStatus.approved;
    final app = await open(tester, server, b.id);
    await app.tapText('Cancel booking');
    await app.enterField('Why are you cancelling?', 'The bike has a flat');
    await confirmInDialog(app, 'Cancel booking');
    expect(b.cancellation!.by, TradeRole.owner);
  });

  testWidgets('the other side reads the note and rates the cancellation', (
    tester,
  ) async {
    final server = MockServer();
    final b = ashaRentsGopro(server, status: BookingStatus.cancelled)
      ..cancellation = MockCancellation(
        by: TradeRole.owner,
        note: 'The camera stopped charging, sorry',
        at: DateTime.utc(2026, 10, 27, 9, 35),
      );
    final app = await open(tester, server, b.id);

    expect(find.text('Karan Mehta cancelled'), findsOneWidget);
    expect(find.text('27 Oct 2026, 3:05 PM'), findsOneWidget);
    expect(find.text('“The camera stopped charging, sorry”'), findsOneWidget);
    expect(
      find.text('Read the reason and rate the cancellation'),
      findsOneWidget,
    );

    await app.tapText('Submit rating');
    expect(find.text('Choose 1 to 5 stars'), findsOneWidget);
    expect(find.text('Write a short comment'), findsOneWidget);

    await app.tap(find.byTooltip('4 stars'));
    await app.enterField('Comment', 'Told me early, no problem');
    await app.tapText('Submit rating');

    expect(b.cancellation!.ratingStars, 4);
    expect(b.cancellation!.ratingComment, 'Told me early, no problem');
    expect(find.text('Submit rating'), findsNothing);
    expect(find.text('Karan Mehta cancelled'), findsOneWidget);
  });

  testWidgets('a paid booking can’t be cancelled', (tester) async {
    final server = MockServer();
    final b = ashaRentsGopro(server, status: BookingStatus.approved);
    b.payments.add(paidRent(b));
    await open(tester, server, b.id);
    expect(find.text('Cancel booking'), findsNothing);
  });

  test('the API refuses to cancel a paid booking', () async {
    final server = MockServer();
    final b = ashaRentsGopro(server, status: BookingStatus.approved);
    b.payments.add(paidRent(b));
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
      tokenStore: MemoryTokenStore(tokensFor(server, asha)),
      mockServer: server,
    );
    await expectLater(
      client.api.bookings.cancel(
        b.id,
        const CancelIn(note: 'Changed my mind'),
        idempotencyKey: 'k1',
      ),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'ALREADY_PAID'),
      ),
    );
  });
}
