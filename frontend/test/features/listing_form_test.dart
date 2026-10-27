import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/listings/listing_validation.dart';
import 'package:unirent/features/listings/photos/photo_picker.dart';
import 'package:unirent/features/listings/photos/photo_processing.dart';
import 'package:unirent/features/listings/widgets/listing_tiles.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
final ashaBike = mockListingId(3); // two photos, rent

Uint8List jpeg(int width, int height) =>
    img.encodeJpg(img.Image(width: width, height: height));

class FakePhotoPicker implements PhotoPicker {
  int calls = 0;

  @override
  Future<List<Uint8List>> pick(PhotoSource source, {required int max}) async {
    calls++;
    return [jpeg(40, 30)];
  }
}

List<Override> photoOverrides(FakePhotoPicker picker) => [
  photoPickerProvider.overrideWithValue(picker),
  // In-process: isolates don't finish under the widget-test clock.
  photoProcessorProvider.overrideWithValue(
    (bytes) async => prepareListingPhoto(bytes),
  ),
];

Future<TestApp> signIn(
  WidgetTester tester, {
  String email = asha,
  MockServer? server,
}) => pumpSignedIn(
  tester,
  email,
  server: server,
  overrides: photoOverrides(FakePhotoPicker()),
);

Future<void> openListingsTab(TestApp app) =>
    app.tap(find.widgetWithText(NavigationDestination, 'Listings'));

Future<void> addPhoto(TestApp app) async {
  await app.tapText('Add photo');
  await app.tapText('Choose from gallery');
}

Future<void> choose<T>(TestApp app, String option) async {
  await app.tap(find.byType(DropdownButtonFormField<T>));
  await app.tapText(option);
}

void main() {
  testWidgets('add a rental: validation, photo upload, publish', (
    tester,
  ) async {
    final server = MockServer();
    final app = await signIn(tester, server: server);
    await openListingsTab(app);
    await app.tapText('Add listing');
    expect(app.location, Routes.newListing);

    await app.tapText('Publish listing');
    for (final message in [
      'Add at least one photo',
      'Enter a title',
      'Choose a category',
      'Choose the condition',
      'Set an hourly or a daily price',
      'Where should people collect it?',
    ]) {
      expect(find.text(message), findsOneWidget, reason: message);
    }

    await addPhoto(app);
    expect(server.db.uploadedKeys, hasLength(1));
    expect(find.text('1 of 8 · the first photo is the cover'), findsOne);

    await app.enterField('Title', 'Trek road bike');
    await choose<ListingCategory>(app, 'Cycles');
    await choose<ItemCondition>(app, 'Good');
    await app.enterField('Per day', '150');
    await app.enterField('Pickup point', 'Ganga Hostel gate');
    await app.tapText('Publish listing');

    final created = server.db.listings.values.singleWhere(
      (l) => l.title == 'Trek road bike',
    );
    expect(app.location, Routes.listing(created.id));
    expect(created.ownerId, server.db.accountByEmail(asha)!.id);
    expect(created.pricePerDayPaise, 15000);
    expect(created.pricePerHourPaise, isNull);
    expect(created.photos, hasLength(1));
    expect(created.category, ListingCategory.cycles);
    expect(find.text('₹150/day'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Trek road bike'), findsOneWidget);
  });

  testWidgets('selling asks for one fixed price', (tester) async {
    final app = await signIn(tester);
    await openListingsTab(app);
    await app.tapText('Add listing');
    await app.tapText('Sell');
    expect(find.widgetWithText(TextFormField, 'Price'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Per hour'), findsNothing);
    await app.tapText('Publish listing');
    expect(find.text('Set a price above ₹0'), findsOneWidget);
  });

  testWidgets('without a payout account, adding sends you to link one', (
    tester,
  ) async {
    final app = await signIn(tester, email: 'karan@college.edu');
    await openListingsTab(app);
    await app.tapText('Add listing');
    expect(find.text('Link your payout account first'), findsOneWidget);
    await app.tapText('Link account');
    expect(app.location, Routes.payoutAccount);
  });

  testWidgets('a payout problem at publish time shows the same prompt', (
    tester,
  ) async {
    final server = MockServer();
    final app = await signIn(tester, server: server);
    await openListingsTab(app);
    await app.tapText('Add listing');
    await addPhoto(app);
    await app.enterField('Title', 'Desk fan');
    await choose<ListingCategory>(app, 'Hostel essentials');
    await choose<ItemCondition>(app, 'Fair');
    await app.enterField('Per day', '20');
    await app.enterField('Pickup point', 'Ganga Hostel');

    server.db.accountByEmail(asha)!.payoutStatus =
        PayoutAccountOutStatus.suspended;
    await app.tapText('Publish listing');
    expect(find.text('Link your payout account first'), findsOneWidget);
    await app.tapText('Not now');
    expect(app.location, Routes.newListing);
  });

  testWidgets('edit a listing’s details', (tester) async {
    final server = MockServer();
    final app = await signIn(tester, server: server);
    unawaited(app.router.push(Routes.listing(ashaBike)));
    await tester.pumpAndSettle();
    await app.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    expect(app.location, Routes.listingEdit(ashaBike));
    expect(find.text('Hercules 21-gear mountain bike'), findsOneWidget);

    await app.enterField('Title', 'Hercules MTB (21 gears)');
    await app.enterField('Per day', '90');
    await app.tapText('Save changes');

    expect(app.location, Routes.listing(ashaBike));
    final listing = server.db.listings[ashaBike]!;
    expect(listing.title, 'Hercules MTB (21 gears)');
    expect(listing.pricePerDayPaise, 9000);
    expect(find.text('Hercules MTB (21 gears)'), findsOneWidget);
  });

  testWidgets('edit photos: add, remove, and keep at least one', (
    tester,
  ) async {
    final server = MockServer();
    final app = await signIn(tester, server: server);
    unawaited(app.router.push(Routes.listingEdit(ashaBike)));
    await tester.pumpAndSettle();
    final photos = server.db.listings[ashaBike]!.photos;
    expect(photos, hasLength(2));

    await app.tap(find.byTooltip('Remove photo').first);
    expect(photos, hasLength(1));

    await app.tap(find.byTooltip('Remove photo'));
    expect(photos, hasLength(1));
    expect(find.textContaining('needs at least one photo'), findsOneWidget);

    await addPhoto(app);
    expect(photos, hasLength(2));
  });

  testWidgets('a listing with an active booking can’t be edited', (
    tester,
  ) async {
    final server = MockServer();
    server.db.listings[ashaBike]!.locked = true;
    final app = await signIn(tester, server: server);
    unawaited(app.router.push(Routes.listingEdit(ashaBike)));
    await tester.pumpAndSettle();
    expect(find.textContaining('can’t edit this listing'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('my listings filter by status', (tester) async {
    final app = await signIn(tester);
    await openListingsTab(app);
    List<String> titles() => [
      for (final t in tester.widgetList<ListingTile>(find.byType(ListingTile)))
        t.listing.title,
    ];
    expect(titles(), contains('Hercules 21-gear mountain bike'));
    expect(titles(), isNot(contains('Mini fridge (45 L)')));

    await app.tapText('Paused');
    expect(titles(), ['Mini fridge (45 L)']);
    await app.tapText('Sold');
    expect(titles(), ['HC Verma Concepts of Physics (Vol 1 & 2)']);
  });

  group('photo processing', () {
    test('shrinks the longest side to 1600 px and re-encodes as JPEG', () {
      final out = img.decodeJpg(prepareListingPhoto(jpeg(3200, 1000)))!;
      expect(out.width, 1600);
      expect(out.height, 500);

      final tall = img.decodeJpg(prepareListingPhoto(jpeg(900, 2400)))!;
      expect(tall.height, 1600);
      expect(tall.width, 600);
    });

    test('leaves small photos at their size', () {
      final png = img.encodePng(img.Image(width: 800, height: 600));
      final out = img.decodeJpg(prepareListingPhoto(png))!;
      expect((out.width, out.height), (800, 600));
    });

    test('rejects files that aren’t images', () {
      expect(
        () => prepareListingPhoto(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  test('listing validators mirror the backend', () {
    expect(ListingValidators.title('ab'), isNotNull);
    expect(ListingValidators.title('abc'), isNull);
    expect(ListingValidators.pickupPoint('x'), isNotNull);
    expect(ListingValidators.rentPrices('', ''), isNotNull);
    expect(ListingValidators.rentPrices('20', ''), isNull);
    expect(ListingValidators.optionalPrice('0'), isNotNull);
    expect(ListingValidators.paiseFromRupees('150'), 15000);
    expect(ListingValidators.photoCount(0), isNotNull);
    expect(ListingValidators.photoCount(9), isNotNull);
    expect(ListingValidators.photoCount(8), isNull);
  });
}
