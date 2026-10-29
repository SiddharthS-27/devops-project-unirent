import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_listing_handlers.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/home/home_screen.dart';
import 'package:unirent/features/listings/widgets/listing_tiles.dart';
import 'package:unirent/features/search/search_filters.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';

/// Records the `q` of every suggest request.
List<String> recordSuggestCalls(MockServer server) {
  final calls = <String>[];
  final suggest = listingHandlers(server.db)['GET /api/v1/search/suggest']!;
  server.on('GET /api/v1/search/suggest', (request) {
    calls.add(request.query['q']! as String);
    return suggest(request);
  });
  return calls;
}

List<ListingCard> shownListings(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListingTile>(find.byType(ListingTile)))
    tile.listing,
];

Future<void> searchFor(TestApp app, String text) async {
  await app.tester.enterText(find.byType(TextField).first, text);
  await app.tester.testTextInput.receiveAction(TextInputAction.search);
  await app.tester.pumpAndSettle();
}

void main() {
  testWidgets('home shows categories and recently listed', (tester) async {
    final app = await pumpSignedIn(tester, asha);
    expect(app.location, Routes.home);
    expect(find.text('Browse categories'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Cameras'), findsOneWidget);
    expect(find.text('Recently listed'), findsOneWidget);
    expect(find.byType(ListingTile), findsWidgets);
    expect(find.text('New for your saved searches'), findsNothing);
  });

  testWidgets('home shows new matches for saved searches', (tester) async {
    final server = MockServer();
    final viewer = server.db.accountByEmail(asha)!;
    server.db.savedSearches['s1'] = MockSavedSearch(
      id: 's1',
      accountId: viewer.id,
      name: 'Cameras',
      category: ListingCategory.cameras,
      createdAt: DateTime.utc(2020),
    );
    await pumpSignedIn(tester, asha, server: server);

    expect(find.text('New for your saved searches'), findsOneWidget);
    final cards = tester.widgetList<ListingMiniCard>(
      find.byType(ListingMiniCard),
    );
    expect(cards, isNotEmpty);
    expect(
      cards.every((c) => c.listing.category == ListingCategory.cameras),
      isTrue,
    );
  });

  testWidgets('a category shortcut opens filtered results', (tester) async {
    final app = await pumpSignedIn(tester, asha);
    await app.tap(find.widgetWithText(ActionChip, 'Cycles'));
    expect(app.location, '${Routes.search}?category=cycles');
    final shown = shownListings(tester);
    expect(shown, isNotEmpty);
    expect(shown.every((l) => l.category == ListingCategory.cycles), isTrue);
  });

  testWidgets('type-ahead is debounced and opens a suggestion', (tester) async {
    final server = MockServer();
    final calls = recordSuggestCalls(server);
    final app = await pumpSignedIn(tester, asha, server: server);
    final field = find.byType(TextField).first;

    await tester.enterText(field, 'c');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'ca');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'cam');
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, isEmpty, reason: 'still typing');

    await tester.pump(suggestDebounce);
    await tester.pumpAndSettle();
    expect(calls, ['cam']);
    expect(find.text('Search for “cam”'), findsOneWidget);
    expect(find.text('GoPro Hero 9 action camera'), findsOneWidget);

    await app.tapText('GoPro Hero 9 action camera');
    expect(app.location, startsWith('/listing/'));
  });

  testWidgets('results sort by price and filter by category, kind, price', (
    tester,
  ) async {
    final app = await pumpSignedIn(tester, asha);
    await app.tap(find.widgetWithText(ActionChip, 'Cameras'));

    // Default sort: most trusted owner first (Dev 92, Karan 64).
    var shown = shownListings(tester);
    expect(shown.first.owner.fullName, 'Dev Patel');

    await app.tap(find.byTooltip('Sort'));
    await app.tapText('Price: low to high');
    shown = shownListings(tester);
    expect(shown.first.title, 'GoPro Hero 9 action camera');

    await app.tap(find.byTooltip('Filters'));
    await app.tap(find.byType(DropdownButtonFormField<ListingCategory?>));
    await app.tapText('Books & stationery');
    await app.tapText('Rent');
    await app.enterField('Max price', '100');
    await app.tapText('Show results');

    shown = shownListings(tester);
    expect(shown.map((l) => l.title), [
      'Engineering drawing kit with mini drafter',
    ]);
    expect(find.widgetWithText(InputChip, 'Books & stationery'), findsOne);
    expect(find.widgetWithText(InputChip, 'Rent'), findsOne);
    expect(find.widgetWithText(InputChip, 'Up to ₹100'), findsOne);

    // Removing the price filter brings back the pricier rentals.
    await app.tap(find.byTooltip('Remove Up to ₹100 filter'));
    expect(find.widgetWithText(InputChip, 'Up to ₹100'), findsNothing);
    expect(shownListings(tester), hasLength(1)); // still only one rental book
  });

  testWidgets('results scroll through every page', (tester) async {
    final server = MockServer();
    final dev = server.db.accountByEmail('dev@college.edu')!;
    for (var i = 0; i < 30; i++) {
      server.db.listings['extra-$i'] = MockListing(
        id: 'extra-$i',
        ownerId: dev.id,
        assetId: 'asset-$i',
        kind: TradeKind.sale,
        title: 'Spiral notebook #$i',
        category: ListingCategory.books,
        pickupPoint: 'Stationery shop',
        salePricePaise: 5000 + i,
        createdAt: DateTime.utc(2026, 1, 1, i),
      );
    }
    final cursors = <Object?>[];
    final search = listingHandlers(server.db)['GET /api/v1/search']!;
    server.on('GET /api/v1/search', (request) {
      cursors.add(request.query['cursor']);
      return search(request);
    });

    final app = await pumpSignedIn(tester, asha, server: server);
    await searchFor(app, 'notebook');
    expect(app.location, '${Routes.search}?q=notebook');
    expect(cursors, [null]);

    await tester.scrollUntilVisible(
      find.text('Spiral notebook #29'),
      500,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    expect(cursors, [null, '20']);
    expect(find.text('Spiral notebook #29'), findsOneWidget);
  });

  testWidgets('no results shows an empty state', (tester) async {
    final app = await pumpSignedIn(tester, asha);
    await searchFor(app, 'unicorn');
    expect(find.text('No matches'), findsOneWidget);
  });

  group('SearchFilters', () {
    test('round-trips through URL query parameters', () {
      final filters = SearchFilters(
        q: 'cycle',
        category: ListingCategory.cycles,
        kind: TradeKind.rent,
        minPricePaise: 5000,
        maxPricePaise: 20000,
        availableFrom: DateTime.utc(2026, 11, 2),
        availableTo: DateTime.utc(2026, 11, 4),
        sort: SearchSort.priceAsc,
      );
      final query = filters.toQuery();
      expect(query['available_from'], '2026-11-02');
      expect(SearchFilters.fromQuery(query), filters);
      expect(filters.activeCount, 4);
    });

    test('dates cover whole IST days', () {
      final filters = SearchFilters(
        availableFrom: DateTime.utc(2026, 11, 2),
        availableTo: DateTime.utc(2026, 11, 2),
      );
      expect(filters.availableFromInstant, DateTime.utc(2026, 11, 1, 18, 30));
      expect(filters.availableToInstant, DateTime.utc(2026, 11, 2, 18, 30));
    });

    test('choosing "buy" drops rental dates; default sort is omitted', () {
      final filters = SearchFilters(
        availableFrom: DateTime.utc(2026, 11, 2),
      ).copyWith(kind: TradeKind.sale);
      expect(filters.hasDates, isFalse);
      expect(filters.toQuery(), {'kind': 'sale'});
    });
  });
}
