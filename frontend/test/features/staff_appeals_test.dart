import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_appeal_handlers.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const dev = 'dev@college.edu';
const moderator = 'moderator@unirent.in';

/// Asha returned Dev's DSLR, paid ₹400 rent by UPI, disputes the ₹1,500
/// damage charge and appealed with one extra photo.
(MockBooking, MockAppeal) dslrAppeal(
  MockServer server, {
  Duration age = Duration.zero,
}) {
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
          status: BookingStatus.inAppeal,
        )
        ..pickupCompletedAt = now.subtract(const Duration(days: 1))
        ..returnStartedAt = now.subtract(const Duration(minutes: 30))
        ..returnCompletedAt = now.subtract(const Duration(minutes: 20))
        ..frozenLateFeePaise = 0
        ..damagePaise = 150000
        ..damageDescription = 'Cracked lens hood';
  for (final side in [TradeRole.renter, TradeRole.owner]) {
    b.photos[(MockPhase.pickup, side)] = [
      MockPhoto(id: 'p-$side', key: 'p-$side', url: 'mock://photo/123456'),
    ];
  }
  b.payments.add(
    MockPayment(
        id: 'pay-rent',
        bookingId: b.id,
        purpose: PaymentPurpose.rent,
        method: PaymentMethod.upi,
        amountPaise: 40000,
        items: const [],
        createdAt: now.subtract(const Duration(days: 1)),
        payerId: b.renterId,
        payeeId: b.ownerId,
      )
      ..status = PaymentStatus.captured
      ..capturedAt = now.subtract(const Duration(days: 1)),
  );
  db.bookings[b.id] = b;
  final appeal = MockAppeal(
    id: 'appeal-dslr',
    bookingId: b.id,
    filedById: b.renterId,
    filedBy: TradeRole.renter,
    reason: AppealReason.damageDispute,
    notes: 'The hood was cracked before I picked it up.',
    photoKeys: ['appeal/x/1.jpg'],
    previousStatus: BookingStatus.returning,
    createdAt: now.subtract(age),
  );
  db.appeals[appeal.id] = appeal;
  return (b, appeal);
}

Future<TestApp> asModerator(WidgetTester tester, MockServer server) {
  server.db.accountByEmail(moderator)!.mustChangePassword = false;
  return pumpSignedIn(tester, moderator, server: server);
}

Future<void> confirm(TestApp app, String label) => app.tap(
  find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  ),
);

void main() {
  testWidgets('a moderator sees only the moderator tabs', (tester) async {
    final app = await asModerator(tester, MockServer());
    expect(app.location, Routes.staffHome);
    expect(find.byType(Tab), findsNWidgets(5));
    expect(find.text('Reports'), findsNothing);
    expect(find.text('No open appeals'), findsOneWidget);
  });

  testWidgets('a moderator reviews an appeal and rules on it', (tester) async {
    final server = MockServer();
    final (b, appeal) = dslrAppeal(server);
    final devAccount = server.db.accountByEmail(dev)!;
    final devTrust = devAccount.lenderScore!;
    final app = await asModerator(tester, server);

    expect(
      find.textContaining('Damage or late-fee dispute · Asha Verma'),
      findsOneWidget,
    );
    await app.tap(
      find.textContaining('Damage or late-fee dispute · Asha Verma'),
    );
    expect(app.location, Routes.staffAppeal(appeal.id));
    expect(
      find.text('The hood was cracked before I picked it up.'),
      findsOneWidget,
    );
    expect(find.textContaining('Filed by Asha Verma (renter)'), findsOneWidget);
    expect(find.text('Pickup (2)'), findsOneWidget);
    expect(find.text('Return (0)'), findsOneWidget);
    expect(find.text('Added to the appeal (1)'), findsOneWidget);
    expect(find.text('Damage: Cracked lens hood'), findsOneWidget);
    expect(find.text('₹1,500'), findsWidgets);

    await app.tapText('Rule on this appeal');
    await app.tapText('Send ruling');
    expect(
      find.text('Explain the ruling (at least 5 characters)'),
      findsOneWidget,
    );

    await app.enterField('Summary', 'Pickup photos show the crack already.');
    await app.enterField('Damage charge the renter owes', '0');
    await app.enterField('Refund to the renter', '100');
    await app.tapText('Trust penalty');
    await app.tapText('Dev Patel (owner)');
    await app.enterField('Points', '5');
    await app.tapText('Send ruling');
    expect(find.textContaining('•  Damage charge set to ₹0'), findsOneWidget);
    expect(find.textContaining('•  Refund ₹100 to the renter'), findsOneWidget);
    expect(
      find.textContaining('5 points off Dev Patel (owner)’s lender trust'),
      findsOneWidget,
    );
    await confirm(app, 'Send ruling');

    expect(app.location, Routes.staffAppeal(appeal.id));
    expect(find.text('Ruling sent to both sides.'), findsOneWidget);
    expect(find.text('Rule on this appeal'), findsNothing);
    expect(find.text('Pickup photos show the crack already.'), findsOneWidget);
    expect(find.text('Refund ₹100 to the renter'), findsOneWidget);

    expect(appeal.status, AppealStatus.ruled);
    expect(b.status, BookingStatus.returning);
    expect(b.damagePaise, 0);
    expect(b.payments.single.refunds.single.amountPaise, 10000);
    expect(devAccount.lenderScore, devTrust - 5);
    expect(server.db.rulings.single.body.trustPenalty!.role, TrustRole.lender);

    await app.tap(find.byType(BackButton));
    expect(find.text('No open appeals'), findsOneWidget);
    await app.tapText('Ruled');
    expect(
      find.textContaining('Damage or late-fee dispute · Asha Verma'),
      findsOneWidget,
    );
  });

  testWidgets('the server’s refusal keeps the ruling form', (tester) async {
    final server = MockServer();
    final (b, appeal) = dslrAppeal(server);
    final app = await asModerator(tester, server);
    app.router.go(Routes.staffAppealRule(appeal.id));
    await tester.pumpAndSettle();

    await app.enterField('Summary', 'Refund everything and ban the owner.');
    await app.enterField('Refund to the renter', '500');
    await app.tapText('Suspend or ban an account');
    await app.tapText('Dev Patel (owner)');
    await app.tapText('Ban');
    await app.tapText('Send ruling');
    expect(find.textContaining('•  Dev Patel (owner) banned'), findsOneWidget);
    await confirm(app, 'Send ruling');

    expect(
      find.textContaining('That refund is more than was paid'),
      findsOneWidget,
    );
    expect(app.location, Routes.staffAppealRule(appeal.id));
    expect(appeal.status, AppealStatus.open);
    expect(server.db.accountByEmail(dev)!.status, 'active');

    await app.enterField('Refund to the renter', '400');
    await app.tapText('Send ruling');
    await confirm(app, 'Send ruling');
    expect(appeal.status, AppealStatus.ruled);
    expect(server.db.accountByEmail(dev)!.status, 'banned');
    expect(b.payments.single.status, PaymentStatus.refunded);
  });

  testWidgets('students can’t open the staff appeals', (tester) async {
    final server = MockServer();
    final (_, appeal) = dslrAppeal(server);
    final app = await pumpSignedIn(tester, asha, server: server);
    app.router.go(Routes.staffAppeal(appeal.id));
    await tester.pumpAndSettle();
    expect(app.location, Routes.home);
  });
}
