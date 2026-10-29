import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';

import '../helpers/booking_helpers.dart';

const asha = 'asha@college.edu';
const meera = 'meera@college.edu';

/// Asha buying Meera's cycle (₹4,500).
MockBooking ashaBuysCycle(
  MockServer server, {
  BookingStatus status = BookingStatus.approved,
  Duration? handedOverAgo,
}) {
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
    status: status,
  );
  if (handedOverAgo != null) b.pickupCompletedAt = now.subtract(handedOverAgo);
  return db.bookings[b.id] = b;
}

void bothPhotos(MockBooking b) {
  for (final side in TradeRole.values.where((r) => r != TradeRole.unknown)) {
    b.photos[(MockPhase.pickup, side)] = [
      MockPhoto(id: 'p-$side', key: 'p-$side', url: 'mock://photo/123456'),
    ];
  }
}

void main() {
  testWidgets('a purchase reads as buyer and seller', (tester) async {
    final server = MockServer();
    final b = ashaBuysCycle(server);
    bothPhotos(b);

    var app = await openBookingAs(tester, server, asha, b.id);
    expect(find.text('Purchase'), findsWidgets);
    expect(find.text('Seller'), findsOneWidget);
    expect(find.text('Handover'), findsWidgets);
    expect(find.text('Pay for the item by UPI or hand over cash.'), findsOne);
    expect(find.text('The seller’s photos'), findsOneWidget);
    await tapStep(app, 'Payment', 'Pay');
    expect(find.text('Pay ₹4,500 for the item'), findsOneWidget);
    await app.tapText('Cash');
    expect(
      find.text(
        'Hand ₹4,500 in cash to the seller. They’ll confirm it in the app.',
      ),
      findsOneWidget,
    );

    app = await openBookingAs(tester, server, meera, b.id);
    expect(find.text('Buyer'), findsOneWidget);
    expect(find.text('The buyer is paying ₹4,500 in cash'), findsOneWidget);
    expect(find.text('Enter the buyer’s code'), findsOneWidget);
  });

  testWidgets('the buyer can appeal for 48 hours after the handover', (
    tester,
  ) async {
    final server = MockServer();
    final b = ashaBuysCycle(
      server,
      status: BookingStatus.completed,
      handedOverAgo: const Duration(hours: 1),
    );
    final app = await openBookingAs(tester, server, asha, b.id);
    expect(find.text('Not what was described?'), findsOneWidget);
    await app.tapText('Get help with this purchase');
    expect(app.location, Routes.help);

    b.pickupCompletedAt = DateTime.now().toUtc().subtract(
      const Duration(hours: 49),
    );
    await openBookingAs(tester, server, asha, b.id);
    expect(find.text('Not what was described?'), findsNothing);

    // The seller never sees it.
    b.pickupCompletedAt = DateTime.now().toUtc();
    await openBookingAs(tester, server, meera, b.id);
    expect(find.text('Not what was described?'), findsNothing);
  });

  testWidgets('sold listings: the seller can’t edit, others can’t request', (
    tester,
  ) async {
    final server = MockServer();
    final hcVerma = mockListingId(5); // Asha's, sold
    await as(tester, server, asha, location: Routes.listing(hcVerma));
    expect(find.widgetWithText(Chip, 'Sold'), findsOneWidget);
    expect(find.text('You sold this item.'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Pause'), findsNothing);

    await as(
      tester,
      server,
      'dev@college.edu',
      location: Routes.listing(hcVerma),
    );
    expect(find.text('This item has been sold.'), findsOneWidget);
    expect(find.text('Request to buy'), findsNothing);
  });
}
