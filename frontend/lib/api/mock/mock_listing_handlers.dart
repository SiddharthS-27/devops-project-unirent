import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_listings.dart';
import 'mock_server.dart';

/// Listing, search and home routes of the mock backend.
Map<String, MockHandler> listingHandlers(MockDb db) {
  final h = _ListingHandlers(db);
  return {
    'GET /api/v1/categories': h.categories,
    'GET /api/v1/home': h.home,
    'GET /api/v1/search': h.search,
    'GET /api/v1/search/suggest': h.suggest,
  };
}

const mockCategoryLabels = {
  ListingCategory.electronics: 'Electronics',
  ListingCategory.cameras: 'Cameras',
  ListingCategory.cycles: 'Cycles',
  ListingCategory.books: 'Books & stationery',
  ListingCategory.instruments: 'Instruments',
  ListingCategory.sports: 'Sports',
  ListingCategory.hostel: 'Hostel essentials',
  ListingCategory.events: 'Events & fests',
  ListingCategory.other: 'Other',
};

/// Query filters shared by search and saved searches.
class MockSearchFilter {
  const MockSearchFilter({
    this.q,
    this.category,
    this.kind,
    this.minPricePaise,
    this.maxPricePaise,
    this.availableFrom,
    this.availableTo,
  });

  final String? q;
  final ListingCategory? category;
  final TradeKind? kind;
  final int? minPricePaise;
  final int? maxPricePaise;
  final DateTime? availableFrom;
  final DateTime? availableTo;

  bool matches(MockListing l) {
    final query = q?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      final text = '${l.title} ${l.description}'.toLowerCase();
      if (!query.split(RegExp(r'\s+')).every(text.contains)) return false;
    }
    if (category != null && l.category != category) return false;
    if (kind != null && l.kind != kind) return false;
    final price = l.headlinePricePaise;
    if (minPricePaise != null && price < minPricePaise!) return false;
    if (maxPricePaise != null && price > maxPricePaise!) return false;
    final from = availableFrom;
    final to = availableTo;
    if (from != null || to != null) {
      if (l.kind != TradeKind.rent) return false;
      final start = from ?? DateTime.utc(1970);
      final end = to ?? DateTime.utc(9999);
      final blocked = l.unavailable.any(
        (s) => s.startAt.isBefore(end) && s.endAt.isAfter(start),
      );
      if (blocked) return false;
    }
    return true;
  }
}

class _ListingHandlers {
  _ListingHandlers(this.db);

  final MockDb db;

  MockAccount _account(MockRequest r) => mockAuthenticate(db, r);

  String _name(MockAccount a) =>
      db.profiles[a.id]?.data.fullName ?? a.name ?? a.email;

  OwnerSummary _ownerSummary(String accountId) {
    final owner = db.accounts[accountId]!;
    return OwnerSummary(
      accountId: owner.id,
      fullName: _name(owner),
      photoUrl: null,
      lenderTrust: owner.lenderScore,
      isNew: owner.lenderScore == null,
    );
  }

  ListingCard card(MockListing l) => ListingCard(
    id: l.id,
    kind: l.kind,
    status: l.status,
    title: l.title,
    category: l.category,
    pricePerHourPaise: l.pricePerHourPaise,
    pricePerDayPaise: l.pricePerDayPaise,
    salePricePaise: l.salePricePaise,
    photoUrl: l.photos.firstOrNull?.url,
    pickupPoint: l.pickupPoint,
    owner: _ownerSummary(l.ownerId),
    createdAt: l.createdAt,
  );

  Iterable<MockListing> get _active =>
      db.listings.values.where((l) => l.status == ListingStatus.active);

  List<CategoryOut> _categories() => [
    for (final MapEntry(:key, :value) in mockCategoryLabels.entries)
      CategoryOut(key: key, label: value),
  ];

  MockResponse categories(MockRequest r) {
    _account(r);
    return MockResponse.json([for (final c in _categories()) c.toJson()]);
  }

  MockResponse home(MockRequest r) {
    final viewer = _account(r);
    final recent = _active.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MockResponse.json(
      HomeOut(
        categories: _categories(),
        recent: [for (final l in recent.take(10)) card(l)],
        savedSearchMatches: savedSearchMatches(viewer),
      ).toJson(),
    );
  }

  /// Active listings by others that match one of [viewer]'s saved
  /// searches and were listed since that search was last viewed.
  List<ListingCard> savedSearchMatches(MockAccount viewer) {
    final matched = <MockListing>{};
    for (final s in db.savedSearches.values) {
      if (s.accountId != viewer.id) continue;
      final since = s.lastViewedAt ?? s.createdAt;
      matched.addAll(
        _active.where(
          (l) =>
              l.ownerId != viewer.id &&
              l.createdAt.isAfter(since) &&
              s.filter.matches(l),
        ),
      );
    }
    final sorted = matched.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [for (final l in sorted) card(l)];
  }

  static T? _enum<T>(Object? raw, T Function(String) parse) =>
      raw is String && raw.isNotEmpty ? parse(raw) : null;

  static int? _int(Object? raw) => raw == null ? null : int.tryParse('$raw');

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  MockResponse search(MockRequest r) {
    _account(r);
    final query = r.query;
    final filter = MockSearchFilter(
      q: query['q'] as String?,
      category: _enum(query['category'], ListingCategory.fromJson),
      kind: _enum(query['kind'], TradeKind.fromJson),
      minPricePaise: _int(query['min_price_paise']),
      maxPricePaise: _int(query['max_price_paise']),
      availableFrom: _date(query['available_from']),
      availableTo: _date(query['available_to']),
    );
    final sort = _enum(query['sort'], SearchSort.fromJson) ?? SearchSort.trust;
    final results = _active.where(filter.matches).toList();

    // New owners rank at the campus median trust score.
    final scores = [
      for (final a in db.accounts.values)
        if (a.lenderScore != null) a.lenderScore!,
    ]..sort();
    final median = scores.isEmpty ? 50 : scores[scores.length ~/ 2];
    int trust(MockListing l) => db.accounts[l.ownerId]!.lenderScore ?? median;

    results.sort(
      (a, b) => switch (sort) {
        SearchSort.newest => b.createdAt.compareTo(a.createdAt),
        SearchSort.priceAsc => a.headlinePricePaise.compareTo(
          b.headlinePricePaise,
        ),
        SearchSort.priceDesc => b.headlinePricePaise.compareTo(
          a.headlinePricePaise,
        ),
        _ => trust(b).compareTo(trust(a)),
      },
    );

    final offset = _int(query['cursor']) ?? 0;
    final limit = (_int(query['limit']) ?? 20).clamp(1, 50);
    final page = results.skip(offset).take(limit).toList();
    final next = offset + page.length;
    return MockResponse.json(
      ListingCardPage(
        items: [for (final l in page) card(l)],
        nextCursor: next < results.length ? '$next' : null,
      ).toJson(),
    );
  }

  MockResponse suggest(MockRequest r) {
    _account(r);
    final q = (r.query['q'] as String? ?? '').trim().toLowerCase();
    if (q.isEmpty) {
      throw mockValidation('q', 'String should have at least 1 character');
    }
    final hits =
        _active.where((l) => l.title.toLowerCase().contains(q)).toList()
          ..sort((a, b) {
            // Prefix matches first.
            final ap = a.title.toLowerCase().startsWith(q) ? 0 : 1;
            final bp = b.title.toLowerCase().startsWith(q) ? 0 : 1;
            return ap != bp ? ap - bp : a.title.compareTo(b.title);
          });
    return MockResponse.json([
      for (final l in hits.take(8))
        Suggestion(
          listingId: l.id,
          title: l.title,
          category: l.category,
          kind: l.kind,
        ).toJson(),
    ]);
  }
}
