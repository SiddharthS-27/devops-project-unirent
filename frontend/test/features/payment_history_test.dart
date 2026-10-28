import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';

import '../helpers/booking_helpers.dart';
import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const karanBikeRequest = '00000000-0000-4000-d000-000000000001';

MockPayment pay(
  MockBooking b, {
  required String id,
  required PaymentPurpose purpose,
  required PaymentMethod method,
  required int amount,
  required PaymentStatus status,
  required DateTime at,
  List<PaymentItem> items = const [],
}) {
  final p =
      MockPayment(
          id: id,
          bookingId: b.id,
          purpose: purpose,
          method: method,
          amountPaise: amount,
          items: items,
          createdAt: at,
          payerId: b.renterId,
          payeeId: b.ownerId,
        )
        ..status = status
        ..capturedAt = at;
  b.payments.add(p);
  return p;
}

/// Asha rented Dev's DSLR (paid by UPI) and Karan rented her bike (paid her
/// in cash, then return charges with a cash refund still to hand back).
({MockServer server, MockRefund refund, MockPayment charges}) seeded() {
  final server = MockServer();
  final db = server.db;
  final rental = db.bookings['b-dslr'] = MockBooking(
    id: 'b-dslr',
    listingId: mockListingId(1),
    kind: TradeKind.rent,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: db.accountByEmail('dev@college.edu')!.id,
    amountPaise: 40000,
    createdAt: DateTime.utc(2026, 10, 20),
    status: BookingStatus.completed,
  );
  pay(
    rental,
    id: 'p-dslr',
    purpose: PaymentPurpose.rent,
    method: PaymentMethod.upi,
    amount: 40000,
    status: PaymentStatus.captured,
    at: DateTime.utc(2026, 10, 20, 9, 35),
  );
  final bike = db.bookings[karanBikeRequest]!..status = BookingStatus.completed;
  pay(
    bike,
    id: 'p-bike',
    purpose: PaymentPurpose.rent,
    method: PaymentMethod.cash,
    amount: 8000,
    status: PaymentStatus.markedPaid,
    at: DateTime.utc(2026, 10, 22, 4, 30),
  );
  final charges = pay(
    bike,
    id: 'p-charges',
    purpose: PaymentPurpose.returnCharges,
    method: PaymentMethod.cash,
    amount: 15000,
    status: PaymentStatus.markedPaid,
    at: DateTime.utc(2026, 10, 23, 4, 30),
    items: const [
      PaymentItem(label: 'Late fee', amountPaise: 5000),
      PaymentItem(label: 'Damage charge', amountPaise: 10000),
    ],
  );
  final refund = MockRefund(
    id: 'refund-1',
    amountPaise: 5000,
    method: PaymentMethod.cash,
    createdAt: DateTime.utc(2026, 10, 24),
    status: RefundOutStatus.cashPending,
  );
  charges.refunds.add(refund);
  return (server: server, refund: refund, charges: charges);
}

void main() {
  testWidgets('paid and received, with names, methods and items', (
    tester,
  ) async {
    final s = seeded();
    final app = await as(tester, s.server, asha, location: Routes.profile);
    await app.tapText('Payment history');
    expect(app.location, Routes.paymentHistory);

    expect(find.text('Rent · to Dev Patel'), findsOneWidget);
    expect(find.text('−₹400'), findsOneWidget);
    expect(find.text('UPI · Paid · 20 Oct 2026, 3:05 PM'), findsOneWidget);

    expect(find.text('Rent · from Karan Mehta'), findsOneWidget);
    expect(find.text('+₹80'), findsOneWidget);
    expect(find.text('Return charges · from Karan Mehta'), findsOneWidget);
    expect(find.text('Late fee: ₹50'), findsOneWidget);
    expect(find.text('Damage charge: ₹100'), findsOneWidget);
  });

  testWidgets('the owner marks a cash refund as handed back', (tester) async {
    final s = seeded();
    final app = await as(
      tester,
      s.server,
      asha,
      location: Routes.paymentHistory,
    );
    expect(find.text('Refund ₹50 · To hand back in cash'), findsOneWidget);

    await app.tapText('Mark refund handed back');
    await confirmDialog(app, 'I handed it back');
    expect(s.refund.status, RefundOutStatus.cashDone);
    expect(s.charges.status, PaymentStatus.partlyRefunded);
    expect(find.text('Refund ₹50 · Handed back in cash'), findsOneWidget);
    expect(find.text('Mark refund handed back'), findsNothing);
  });

  testWidgets('the payer sees the refund but can’t mark it', (tester) async {
    final s = seeded();
    await as(
      tester,
      s.server,
      'karan@college.edu',
      location: Routes.paymentHistory,
    );
    expect(
      find.text('Refund ₹50 · The owner hands it back in cash'),
      findsOneWidget,
    );
    expect(find.text('Mark refund handed back'), findsNothing);
  });

  testWidgets('a row opens its booking', (tester) async {
    final s = seeded();
    final app = await as(
      tester,
      s.server,
      asha,
      location: Routes.paymentHistory,
    );
    await app.tapText('Rent · to Dev Patel');
    expect(app.location, Routes.booking('b-dslr'));
  });

  testWidgets('long histories load more', (tester) async {
    final s = seeded();
    final rental = s.server.db.bookings['b-dslr']!;
    for (var i = 0; i < 25; i++) {
      pay(
        rental,
        id: 'extra-$i',
        purpose: PaymentPurpose.extension,
        method: PaymentMethod.upi,
        amount: 1000,
        status: PaymentStatus.captured,
        at: DateTime.utc(2026, 9, 1).add(Duration(hours: i)),
      );
    }
    final app = await as(
      tester,
      s.server,
      asha,
      location: Routes.paymentHistory,
    );
    final list = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Show more'),
      500,
      scrollable: list.first,
    );
    await app.tapText('Show more');
    await tester.drag(list.first, const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(find.text('Show more'), findsNothing);
  });

  test('only the payee marks a refund done', () async {
    final s = seeded();
    final payer = ApiClient(
      config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
      tokenStore: MemoryTokenStore(tokensFor(s.server, 'karan@college.edu')),
      mockServer: s.server,
    );
    await expectLater(
      payer.api.payments.markCashRefunded('refund-1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NOT_FOUND')),
    );
    final page = await payer.api.payments.paymentHistory();
    expect(page.items.every((p) => p.direction == Direction.paid), isTrue);
  });
}
