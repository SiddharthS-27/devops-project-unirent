import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/search/saved_searches.dart';
import 'package:unirent/features/search/search_filters.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';

MockSavedSearch seedSaved(
  MockServer server, {
  String id = 's1',
  String? name = 'Cameras',
  ListingCategory? category = ListingCategory.cameras,
}) {
  final saved = MockSavedSearch(
    id: id,
    accountId: server.db.accountByEmail(asha)!.id,
    name: name,
    category: category,
    createdAt: DateTime.utc(2020),
  );
  return server.db.savedSearches[id] = saved;
}

Future<void> openResults(TestApp app, SearchFilters filters) async {
  unawaited(app.router.push(Routes.searchFor(filters)));
  await app.tester.pumpAndSettle();
}

void main() {
  testWidgets('save the current search from the results', (tester) async {
    final server = MockServer();
    final app = await pumpSignedIn(tester, asha, server: server);
    await openResults(
      app,
      const SearchFilters(q: 'camera', kind: TradeKind.rent),
    );

    await app.tap(find.byTooltip('Save search'));
    expect(find.text('Save this search'), findsOneWidget);
    expect(find.text('“camera” · Rent'), findsOneWidget);
    await app.enterField('Name', 'Camera for the fest');
    await app.tapText('Save');

    final saved = server.db.savedSearches.values.single;
    expect(saved.name, 'Camera for the fest');
    expect(saved.q, 'camera');
    expect(saved.kind, TradeKind.rent);
    expect(find.text('Search saved. New matches show on Home.'), findsOne);
  });

  testWidgets('an empty search can’t be saved', (tester) async {
    final server = MockServer();
    final app = await pumpSignedIn(tester, asha, server: server);
    await openResults(app, const SearchFilters());
    await app.tap(find.byTooltip('Save search'));
    expect(find.text('Add a search term or a filter first'), findsOneWidget);
    expect(server.db.savedSearches, isEmpty);
  });

  testWidgets('the limit of 20 saved searches is explained', (tester) async {
    final server = MockServer();
    for (var i = 0; i < 20; i++) {
      seedSaved(server, id: 's$i');
    }
    final app = await pumpSignedIn(tester, asha, server: server);
    await openResults(app, const SearchFilters(q: 'tent'));
    await app.tap(find.byTooltip('Save search'));
    await app.tapText('Save');
    expect(find.textContaining('You can save up to 20 searches'), findsOne);
  });

  testWidgets('saved searches show new matches until viewed', (tester) async {
    final server = MockServer();
    final saved = seedSaved(server);
    final app = await pumpSignedIn(tester, asha, server: server);

    // Home lists the matches too.
    expect(find.text('New for your saved searches'), findsOneWidget);

    await app.tap(find.byTooltip('Saved searches'));
    expect(app.location, Routes.savedSearches);
    expect(find.text('Cameras'), findsOneWidget);
    // Dev's DSLR and Karan's GoPro.
    expect(find.text('2 new'), findsOneWidget);
    expect(saved.lastViewedAt, isNotNull);

    await app.tapText('Cameras');
    expect(app.location, '${Routes.search}?category=cameras');

    // Leaving and coming back: they've been seen now.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await app.tap(find.byTooltip('Saved searches'));
    expect(find.text('2 new'), findsNothing);
  });

  testWidgets('delete a saved search', (tester) async {
    final server = MockServer();
    seedSaved(server);
    final app = await pumpSignedIn(tester, asha, server: server);
    await app.tap(find.byTooltip('Saved searches'));

    await app.tap(find.byTooltip('Delete saved search'));
    await app.tapText('Delete');
    expect(server.db.savedSearches, isEmpty);
    expect(find.text('No saved searches'), findsOneWidget);
  });

  group('helpers', () {
    test('describe and convert searches', () {
      const filters = SearchFilters(
        q: 'cycle',
        category: ListingCategory.cycles,
        kind: TradeKind.sale,
        maxPricePaise: 500000,
      );
      expect(describeSearch(filters), '“cycle” · Cycles · Buy · Up to ₹5,000');
      expect(suggestedSearchName(filters), 'cycle');
      expect(canSaveSearch(filters), isTrue);
      expect(canSaveSearch(const SearchFilters()), isFalse);

      final body = savedSearchFrom(filters, name: '  ');
      expect(body.name, isNull);
      final roundTrip = filtersFromSaved(
        SavedSearchOut(
          id: 'x',
          createdAt: DateTime.utc(2026),
          newMatchCount: 0,
          q: body.q,
          category: body.category,
          kind: body.kind,
          minPricePaise: body.minPricePaise,
          maxPricePaise: body.maxPricePaise,
        ),
      );
      expect(roundTrip, filters);
    });
  });
}
