import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/ui/ui.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';

/// An active rental: Asha has Dev's DSLR (₹400/day, ₹60/hr) until [endIn].
MockBooking ashaHasDslr(
  MockServer server, {
  Duration endIn = const Duration(hours: 2, minutes: 5),
}) {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final b = MockBooking(
    id: 'b-active',
    listingId: mockListingId(1),
    kind: TradeKind.rent,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: db.accountByEmail('dev@college.edu')!.id,
    amountPaise: 40000,
    createdAt: now.subtract(const Duration(days: 1)),
    startAt: now.subtract(const Duration(hours: 22)),
    endAt: now.add(endIn),
    status: BookingStatus.active,
  )..pickupCompletedAt = now.subtract(const Duration(hours: 22));
  // Clear the DSLR's seeded booked slot so extensions aren't refused.
  db.listings[b.listingId]!.unavailable.clear();
  return db.bookings[b.id] = b;
}

/// An active rental of Asha's bike to Karan (Asha is the owner).
MockBooking karanHasAshasBike(MockServer server) {
  final b = server.db.bookings['00000000-0000-4000-d000-000000000001']!;
  final now = DateTime.now().toUtc();
  b
    ..status = BookingStatus.active
    ..startAt = now.subtract(const Duration(hours: 1))
    ..endAt = now.add(const Duration(hours: 3))
    ..pickupCompletedAt = now.subtract(const Duration(hours: 1));
  // Meera's overlapping request no longer matters.
  server.db.bookings.remove('00000000-0000-4000-d000-000000000002');
  return b;
}

MockExtension extension(
  MockBooking b, {
  Duration more = const Duration(days: 1),
}) {
  final e = MockExtension(
    id: 'ext-1',
    newEndAt: b.endAt!.add(more),
    amountPaise: 40000,
    createdAt: DateTime.now().toUtc(),
  );
  b.extensions.add(e);
  return e;
}

Future<TestApp> open(
  WidgetTester tester,
  MockServer server,
  String id, {
  String email = asha,
}) async {
  final app = await pumpSignedIn(tester, email, server: server);
  unawaited(app.router.push(Routes.booking(id)));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('renter sees time left and asks for more time', (tester) async {
    final server = MockServer();
    final b = ashaHasDslr(server);
    final app = await open(tester, server, b.id);

    expect(find.text('Return the item on time'), findsOneWidget);
    expect(find.textContaining('Return by'), findsOneWidget);
    expect(find.textContaining('Time left: 2h'), findsOneWidget);

    await app.tapText('Ask for more time');
    // Date, then time (IST); the default is a day later.
    await app.tapText('OK');
    await app.tapText('OK');

    final e = b.extensions.single;
    expect(e.status, ExtensionStatus.requested);
    expect(e.newEndAt.difference(b.endAt!).inMinutes, closeTo(24 * 60, 1));
    expect(e.amountPaise, 40000);
    expect(find.text('Waiting for the owner about more time'), findsOneWidget);
    expect(find.text('Ask for more time'), findsNothing);
    expect(find.text('You can ask again once the owner answers.'), findsOne);
  });

  testWidgets('owner approves extra time; the end time moves', (tester) async {
    final server = MockServer();
    final b = karanHasAshasBike(server);
    final oldEnd = b.endAt!;
    final oldAmount = b.amountPaise;
    final e = extension(b, more: const Duration(hours: 2));
    final app = await open(tester, server, b.id);

    expect(find.text('Approve or decline more time'), findsOneWidget);
    await app.tap(find.widgetWithText(FilledButton, 'Approve'));

    expect(e.status, ExtensionStatus.approved);
    expect(b.endAt, oldEnd.add(const Duration(hours: 2)));
    expect(b.amountPaise, oldAmount + e.amountPaise);
    expect(find.text('Approved · not paid yet'), findsOneWidget);
    expect(find.text('Rental in progress'), findsOneWidget);
  });

  testWidgets('owner declines extra time', (tester) async {
    final server = MockServer();
    final b = karanHasAshasBike(server);
    final e = extension(b);
    final app = await open(tester, server, b.id);
    await app.tap(find.widgetWithText(OutlinedButton, 'Decline'));
    expect(e.status, ExtensionStatus.declined);
    expect(find.text('Declined'), findsOneWidget);
  });

  testWidgets('renter pays for approved extra time by UPI', (tester) async {
    final server = MockServer();
    final b = ashaHasDslr(server);
    extension(b).status = ExtensionStatus.approved;
    final app = await open(tester, server, b.id);

    expect(find.text('Pay for the extra time'), findsOneWidget);
    await app.tapText('Pay ₹400');
    await app.tapText('UPI');
    await app.tapText('Pay ₹400'); // in the Simulated UPI sheet

    final payment = b.paymentFor(PaymentPurpose.extension, 'ext-1')!;
    expect(payment.status, PaymentStatus.captured);
    expect(find.text('Approved · paid'), findsOneWidget);
    expect(find.text('Return the item on time'), findsOneWidget);
  });

  testWidgets('renter chooses to pay for extra time in cash at return', (
    tester,
  ) async {
    final server = MockServer();
    final b = ashaHasDslr(server);
    final e = extension(b)..status = ExtensionStatus.approved;
    final app = await open(tester, server, b.id);

    await app.tapText('Pay ₹400');
    expect(find.text('Added to what you pay at the return'), findsOneWidget);
    await app.tapText('Cash');

    expect(e.payInCashAtReturn, isTrue);
    expect(b.payments, isEmpty);
    expect(find.text('Approved · pay in cash at return'), findsOneWidget);
    expect(find.text('Return the item on time'), findsOneWidget);
    expect(b.cashExtensionsPaise, 40000);
  });

  test(
    'extension rules: one at a time, later than the end, free slot',
    () async {
      final server = MockServer();
      final b = ashaHasDslr(server);
      final renter = ApiClient(
        config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
        tokenStore: MemoryTokenStore(tokensFor(server, asha)),
        mockServer: server,
      );
      final owner = ApiClient(
        config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
        tokenStore: MemoryTokenStore(tokensFor(server, 'dev@college.edu')),
        mockServer: server,
      );
      Matcher code(String c) =>
          throwsA(isA<ApiException>().having((e) => e.code, 'code', c));

      await expectLater(
        renter.api.bookings.requestExtension(
          b.id,
          ExtensionIn(newEndAt: b.endAt!.subtract(const Duration(hours: 1))),
          idempotencyKey: 'a',
        ),
        code('EXTENSION_TOO_SHORT'),
      );
      final ext = await renter.api.bookings.requestExtension(
        b.id,
        ExtensionIn(newEndAt: b.endAt!.add(const Duration(hours: 5))),
        idempotencyKey: 'b',
      );
      await expectLater(
        renter.api.bookings.requestExtension(
          b.id,
          ExtensionIn(newEndAt: b.endAt!.add(const Duration(hours: 6))),
          idempotencyKey: 'c',
        ),
        code('EXTENSION_PENDING'),
      );

      // Someone booked the next slot meanwhile.
      server.db.listings[b.listingId]!.unavailable.add(
        BlockedSlot(
          startAt: b.endAt!.add(const Duration(hours: 1)),
          endAt: b.endAt!.add(const Duration(hours: 3)),
        ),
      );
      await expectLater(
        owner.api.bookings.approveExtension(b.id, ext.id, idempotencyKey: 'd'),
        code('SLOT_TAKEN'),
      );
    },
  );

  test('countdown formatting helper', () {
    expect(formatCountdown(const Duration(hours: 2, minutes: 5)), '2h 5m 0s');
  });
}
