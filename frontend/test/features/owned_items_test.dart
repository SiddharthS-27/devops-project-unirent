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
const meera = 'meera@college.edu';
final cycleListing = mockListingId(4); // Meera's, for sale

ApiClient clientFor(MockServer server, String email) => ApiClient(
  config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
  tokenStore: MemoryTokenStore(tokensFor(server, email)),
  mockServer: server,
);

/// Asha buys Meera's cycle through the API: photos, cash, code.
Future<String> ashaBuysCycle(MockServer server) async {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final b = db.bookings['b-buy'] = MockBooking(
    id: 'b-buy',
    listingId: cycleListing,
    kind: TradeKind.sale,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: db.accountByEmail(meera)!.id,
    amountPaise: 450000,
    createdAt: now,
    status: BookingStatus.approved,
  );
  for (final side in [TradeRole.renter, TradeRole.owner]) {
    b.photos[(MockPhase.pickup, side)] = [
      MockPhoto(id: 'p-$side', key: 'p-$side', url: 'mock://photo/111111'),
    ];
  }
  b.payments.add(
    MockPayment(
      id: 'cash',
      bookingId: b.id,
      purpose: PaymentPurpose.sale,
      method: PaymentMethod.cash,
      amountPaise: 450000,
      items: const [],
      createdAt: now,
      payerId: b.renterId,
      payeeId: b.ownerId,
    )..status = PaymentStatus.markedPaid,
  );
  final code = await clientFor(server, asha).api.bookings.pickupOtp(b.id);
  await clientFor(server, meera).api.bookings.verifyPickupOtp(
    b.id,
    OtpIn(code: code.code),
    idempotencyKey: 'k',
  );
  return db.listings[cycleListing]!.assetId;
}

Finder itemCard(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card));

void main() {
  testWidgets('own items with their listing state', (tester) async {
    final server = MockServer();
    final app = await as(tester, server, asha, location: Routes.profile);
    await app.tapText('Items you own');
    expect(app.location, Routes.ownedItems);

    Finder chipIn(String title, String label) => find.descendant(
      of: itemCard(title),
      matching: find.widgetWithText(Chip, label),
    );
    expect(chipIn('Hercules 21-gear mountain bike', 'Listed'), findsOne);
    expect(chipIn('Mini fridge (45 L)', 'Paused'), findsOne);
    expect(
      chipIn('HC Verma Concepts of Physics (Vol 1 & 2)', 'Sold'),
      findsOne,
    );
    expect(
      find.descendant(
        of: itemCard('Hercules 21-gear mountain bike'),
        matching: find.text('Relist'),
      ),
      findsNothing,
    );

    await app.tapText('Hercules 21-gear mountain bike');
    expect(app.location, Routes.listing(mockListingId(3)));
  });

  testWidgets('a bought item can be relisted with its details', (tester) async {
    final server = MockServer();
    final assetId = (await tester.runAsync(() => ashaBuysCycle(server)))!;
    expect(
      server.db.assets[assetId]!.ownerId,
      server.db.accountByEmail(asha)!.id,
    );

    final app = await as(tester, server, asha, location: Routes.ownedItems);
    final card = itemCard('Btwin city cycle with basket');
    expect(
      find.descendant(of: card, matching: find.text('Not listed')),
      findsOneWidget,
    );
    await app.tap(
      find.descendant(of: card, matching: find.text('History (2)')),
    );
    expect(find.text('Sold'), findsWidgets);

    await app.tap(find.descendant(of: card, matching: find.text('Relist')));
    expect(app.location, Routes.relist(assetId));
    expect(find.widgetWithText(AppBar, 'Relist item'), findsOneWidget);
    expect(find.text('Btwin city cycle with basket'), findsOneWidget);
    expect(find.text('Cycles'), findsOneWidget);

    await app.tapText('Add photo');
    await app.tapText('Choose from gallery');
    await app.enterField('Per day', '60');
    await app.enterField('Pickup point', 'Ganga Hostel gate');
    await app.tapText('Publish listing');

    final relisted = server.db.listings.values.singleWhere(
      (l) =>
          l.assetId == assetId &&
          l.ownerId == server.db.accountByEmail(asha)!.id,
    );
    expect(relisted.title, 'Btwin city cycle with basket');
    expect(relisted.category, ListingCategory.cycles);
    expect(relisted.pricePerDayPaise, 6000);
    expect(app.location, Routes.listing(relisted.id));
  });

  test('asset fields and relist rules', () async {
    final server = MockServer();
    final assetId = await ashaBuysCycle(server);
    final buyer = clientFor(server, asha);

    final bought = await buyer.api.listings.getAsset(assetId);
    expect(bought.title, 'Btwin city cycle with basket');
    expect(bought.category, ListingCategory.cycles);
    expect(bought.photoUrl, isNotNull);
    expect(bought.listingId, isNull); // the latest listing was Meera's
    expect(bought.listingStatus, isNull);

    final mine = await buyer.api.listings.myAssets();
    expect(mine.map((a) => a.id), contains(assetId));
    final seller = await clientFor(server, meera).api.listings.myAssets();
    expect(seller.map((a) => a.id), isNot(contains(assetId)));

    // An item with a live listing can't be listed again.
    final bike = server.db.listings[mockListingId(3)]!;
    server.db.uploadOwners['k1'] = server.db.accountByEmail(asha)!.id;
    server.db.uploadedKeys.add('k1');
    await expectLater(
      buyer.api.listings.createListing(
        ListingCreate(
          kind: TradeKind.rent,
          title: 'Bike again',
          category: ListingCategory.cycles,
          condition: ItemCondition.good,
          pickupPoint: 'Gate',
          photoKeys: const ['k1'],
          pricePerDayPaise: 5000,
          assetId: bike.assetId,
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'ASSET_ALREADY_LISTED',
        ),
      ),
    );
  });
}
