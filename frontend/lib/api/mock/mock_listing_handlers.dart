import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_listings.dart';
import 'mock_server.dart';

/// Maximum photos per listing (mirrors the backend).
const mockMaxPhotos = 8;

/// Listing, search and home routes of the mock backend.
Map<String, MockHandler> listingHandlers(MockDb db) {
  final h = _ListingHandlers(db);
  return {
    'GET /api/v1/categories': h.categories,
    'GET /api/v1/home': h.home,
    'GET /api/v1/search': h.search,
    'GET /api/v1/search/suggest': h.suggest,
    'GET /api/v1/listings/{listing_id}': h.getListing,
    'POST /api/v1/listings/{listing_id}/pause': h.pause,
    'POST /api/v1/listings/{listing_id}/resume': h.resume,
    'GET /api/v1/assets/{asset_id}': h.getAsset,
    'GET /api/v1/listings/mine': h.mine,
    'GET /api/v1/assets/mine': h.myAssets,
    'POST /api/v1/listings': h.create,
    'PATCH /api/v1/listings/{listing_id}': h.update,
    'POST /api/v1/listings/{listing_id}/photos': h.addPhoto,
    'DELETE /api/v1/listings/{listing_id}/photos/{photo_id}': h.deletePhoto,
    'POST /api/v1/uploads/photos': h.presignUpload,
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

  // ---- detail ---------------------------------------------------------------

  MockListing _listing(MockRequest r) {
    final listing = db.listings[r.pathParams['listing_id']];
    if (listing == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Listing not found');
    }
    return listing;
  }

  MockListing _ownListing(MockRequest r, MockAccount viewer) {
    final listing = _listing(r);
    if (listing.ownerId != viewer.id) {
      throw const MockApiError(403, 'FORBIDDEN', "You can't do that");
    }
    return listing;
  }

  /// Serial numbers are masked to the last 4 characters for others.
  static String? _maskSerial(String? serial, {required bool reveal}) {
    if (serial == null || reveal || serial.length <= 4) return serial;
    return '${'•' * (serial.length - 4)}${serial.substring(serial.length - 4)}';
  }

  AssetOut asset(MockAsset a, MockAccount viewer) => AssetOut(
    id: a.id,
    ownerId: a.ownerId,
    condition: a.condition,
    manufactureDate: a.manufactureDate,
    serialNumber: _maskSerial(
      a.serialNumber,
      reveal: a.ownerId == viewer.id || viewer.isStaff,
    ),
    rentalCount: a.rentalCount,
    history: a.history,
  );

  ListingDetail detail(MockListing l, MockAccount viewer) {
    final owner = db.accounts[l.ownerId]!;
    final mine = l.ownerId == viewer.id;
    final a = db.assets[l.assetId]!;
    return ListingDetail(
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
      createdAt: l.createdAt,
      description: l.description,
      condition: a.condition,
      manufactureDate: a.manufactureDate,
      photos: [for (final p in l.photos) PhotoOut(id: p.id, url: p.url)],
      asset: asset(a, viewer),
      lateFeeRule: l.kind == TradeKind.rent
          ? mockLateFeeRule(db.clock().toUtc())
          : null,
      unavailable: l.unavailable,
      isMine: mine,
      canEdit: mine && !l.locked,
      pendingRequestCount: mine ? l.pendingRequestCount : null,
      owner: OwnerCard(
        accountId: owner.id,
        fullName: _name(owner),
        photoUrl: null,
        lenderTrust: owner.lenderScore,
        isNew: owner.lenderScore == null,
        lenderRating: owner.lenderRating,
        cancellationCount: owner.cancellationCount,
        phone: owner.phone,
      ),
    );
  }

  MockResponse getListing(MockRequest r) {
    final viewer = _account(r);
    return MockResponse.json(detail(_listing(r), viewer).toJson());
  }

  MockResponse pause(MockRequest r) {
    final viewer = _account(r);
    final listing = _ownListing(r, viewer);
    if (listing.status != ListingStatus.active) {
      throw const MockApiError(
        409,
        'LISTING_NOT_ACTIVE',
        'Only active listings can be paused',
      );
    }
    listing.status = ListingStatus.paused;
    return MockResponse.json(detail(listing, viewer).toJson());
  }

  MockResponse resume(MockRequest r) {
    final viewer = _account(r);
    final listing = _ownListing(r, viewer);
    if (listing.status != ListingStatus.paused) {
      throw const MockApiError(
        409,
        'LISTING_NOT_PAUSED',
        'Only paused listings can be resumed',
      );
    }
    listing.status = ListingStatus.active;
    return MockResponse.json(detail(listing, viewer).toJson());
  }

  MockResponse getAsset(MockRequest r) {
    final viewer = _account(r);
    final a = db.assets[r.pathParams['asset_id']];
    if (a == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Asset not found');
    }
    return MockResponse.json(asset(a, viewer).toJson());
  }

  // ---- owner: my listings, create, edit, photos -----------------------------

  MockResponse mine(MockRequest r) {
    final viewer = _account(r);
    final status = _enum(r.query['status'], ListingStatus.fromJson);
    final mine =
        db.listings.values
            .where(
              (l) =>
                  l.ownerId == viewer.id &&
                  (status == null || l.status == status),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MockResponse.json([for (final l in mine) card(l).toJson()]);
  }

  MockResponse myAssets(MockRequest r) {
    final viewer = _account(r);
    return MockResponse.json([
      for (final a in db.assets.values)
        if (a.ownerId == viewer.id) asset(a, viewer).toJson(),
    ]);
  }

  /// Checks that [key] was presigned for [owner] and its bytes uploaded.
  void _confirmUpload(String key, MockAccount owner) {
    if (db.uploadOwners[key] != owner.id) {
      throw const MockApiError(
        422,
        'INVALID_PHOTO',
        "That photo upload isn't yours",
      );
    }
    if (!db.uploadedKeys.contains(key)) {
      throw const MockApiError(
        422,
        'PHOTO_NOT_UPLOADED',
        'Upload the photo before confirming it',
      );
    }
  }

  MockPhoto _photoFor(String listingId, String key) {
    final colour = (key.hashCode & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return MockPhoto(id: db.nextId(), key: key, url: 'mock://photo/$colour');
  }

  static void _checkLength(String field, String? value, int min, int max) {
    if (value == null) return;
    if (value.trim().length < min || value.length > max) {
      throw mockValidation(field, 'Must be $min-$max characters');
    }
  }

  static void _checkPrices(int? hour, int? day, int? sale) {
    for (final (field, value) in [
      ('price_per_hour_paise', hour),
      ('price_per_day_paise', day),
      ('sale_price_paise', sale),
    ]) {
      if (value != null && value <= 0) {
        throw mockValidation(field, 'Must be greater than 0');
      }
    }
  }

  MockResponse create(MockRequest r) {
    final viewer = _account(r);
    final profile = db.profiles[viewer.id];
    if (viewer.role != 'student' ||
        profile == null ||
        viewer.phoneVerifiedAt == null) {
      throw const MockApiError(
        403,
        'ONBOARDING_INCOMPLETE',
        'Finish setting up your profile first',
      );
    }
    final body = mockParse(r, ListingCreate.fromJson);
    _checkLength('title', body.title, 3, 120);
    _checkLength('description', body.description, 0, 2000);
    _checkLength('pickup_point', body.pickupPoint, 2, 200);
    _checkLength('serial_number', body.serialNumber, 0, 100);
    _checkPrices(
      body.pricePerHourPaise,
      body.pricePerDayPaise,
      body.salePricePaise,
    );
    final keys = body.photoKeys;
    if (keys.isEmpty || keys.length > mockMaxPhotos) {
      throw mockValidation('photo_keys', 'Add 1-$mockMaxPhotos photos');
    }
    final isRent = body.kind == TradeKind.rent;
    if (isRent &&
        body.pricePerHourPaise == null &&
        body.pricePerDayPaise == null) {
      throw mockValidation('', 'rent listings need an hourly or daily price');
    }
    if (!isRent && body.salePricePaise == null) {
      throw mockValidation('', 'sale listings need a price');
    }
    if (!viewer.payoutReady) {
      throw const MockApiError(
        409,
        'PAYOUT_ACCOUNT_REQUIRED',
        'Link a Razorpay account before your first listing',
      );
    }
    for (final key in keys) {
      _confirmUpload(key, viewer);
    }

    final now = db.clock().toUtc();
    final assetId = body.assetId ?? db.nextId();
    final existing = db.assets[assetId];
    if (body.assetId != null &&
        (existing == null || existing.ownerId != viewer.id)) {
      throw const MockApiError(404, 'NOT_FOUND', 'Asset not found');
    }
    final a =
        existing ??
        (db.assets[assetId] = MockAsset(
          id: assetId,
          ownerId: viewer.id,
          condition: body.condition,
        ));
    a
      ..condition = body.condition
      ..manufactureDate = body.manufactureDate ?? a.manufactureDate
      ..serialNumber = body.serialNumber ?? a.serialNumber
      ..history.add(
        AssetHistoryEntry(
          at: now,
          kind: AssetEventKind.listed,
          summary: 'Listed by ${_name(viewer)}',
        ),
      );

    final id = db.nextId();
    final listing = db.listings[id] = MockListing(
      id: id,
      ownerId: viewer.id,
      assetId: a.id,
      kind: body.kind,
      title: body.title.trim(),
      description: body.description,
      category: body.category,
      pickupPoint: body.pickupPoint.trim(),
      pricePerHourPaise: isRent ? body.pricePerHourPaise : null,
      pricePerDayPaise: isRent ? body.pricePerDayPaise : null,
      salePricePaise: isRent ? null : body.salePricePaise,
      createdAt: now,
      photos: [for (final key in keys) _photoFor(id, key)],
    );
    return MockResponse(201, detail(listing, viewer).toJson());
  }

  MockListing _editable(MockRequest r, MockAccount viewer) {
    final listing = _ownListing(r, viewer);
    if (listing.status == ListingStatus.sold ||
        listing.status == ListingStatus.removed) {
      throw MockApiError(
        409,
        'LISTING_CLOSED',
        'This listing is ${listing.status.json}',
      );
    }
    if (listing.locked) {
      throw const MockApiError(
        409,
        'LISTING_LOCKED',
        'A booking is approved or active; edit after it ends',
      );
    }
    return listing;
  }

  MockResponse update(MockRequest r) {
    final viewer = _account(r);
    final listing = _editable(r, viewer);
    final body = mockParse(r, ListingUpdate.fromJson);
    _checkLength('title', body.title, 3, 120);
    _checkLength('description', body.description, 0, 2000);
    _checkLength('pickup_point', body.pickupPoint, 2, 200);
    _checkLength('serial_number', body.serialNumber, 0, 100);
    _checkPrices(
      body.pricePerHourPaise,
      body.pricePerDayPaise,
      body.salePricePaise,
    );
    if (listing.kind == TradeKind.rent && body.salePricePaise != null) {
      throw const MockApiError(
        422,
        'INVALID_PRICE',
        'Rent listings have no sale price',
      );
    }
    if (listing.kind == TradeKind.sale &&
        (body.pricePerHourPaise != null || body.pricePerDayPaise != null)) {
      throw const MockApiError(
        422,
        'INVALID_PRICE',
        'Sale listings have one fixed price',
      );
    }
    final a = db.assets[listing.assetId]!;
    listing
      ..title = body.title?.trim() ?? listing.title
      ..description = body.description ?? listing.description
      ..category = body.category ?? listing.category
      ..pickupPoint = body.pickupPoint?.trim() ?? listing.pickupPoint
      ..pricePerHourPaise = body.pricePerHourPaise ?? listing.pricePerHourPaise
      ..pricePerDayPaise = body.pricePerDayPaise ?? listing.pricePerDayPaise
      ..salePricePaise = body.salePricePaise ?? listing.salePricePaise;
    a
      ..condition = body.condition ?? a.condition
      ..manufactureDate = body.manufactureDate ?? a.manufactureDate
      ..serialNumber = body.serialNumber ?? a.serialNumber;
    return MockResponse.json(detail(listing, viewer).toJson());
  }

  MockResponse addPhoto(MockRequest r) {
    final viewer = _account(r);
    final listing = _editable(r, viewer);
    final key = mockParse(r, PhotoAdd.fromJson).objectKey;
    if (listing.photos.length >= mockMaxPhotos) {
      throw const MockApiError(
        422,
        'TOO_MANY_PHOTOS',
        'A listing can have up to $mockMaxPhotos photos',
      );
    }
    _confirmUpload(key, viewer);
    final photo = _photoFor(listing.id, key);
    listing.photos.add(photo);
    return MockResponse(201, PhotoOut(id: photo.id, url: photo.url).toJson());
  }

  MockResponse deletePhoto(MockRequest r) {
    final viewer = _account(r);
    final listing = _editable(r, viewer);
    final id = r.pathParams['photo_id'];
    final index = listing.photos.indexWhere((p) => p.id == id);
    if (index < 0) {
      throw const MockApiError(404, 'NOT_FOUND', 'Photo not found');
    }
    if (listing.photos.length == 1) {
      throw const MockApiError(
        409,
        'LAST_PHOTO',
        'A listing needs at least one photo',
      );
    }
    listing.photos.removeAt(index);
    return const MockResponse.noContent();
  }

  MockResponse presignUpload(MockRequest r) {
    final viewer = _account(r);
    final body = mockParse(r, UploadRequest.fromJson);
    final ext = switch (body.contentType) {
      PhotoContentType.imagePng => 'png',
      PhotoContentType.imageWebp => 'webp',
      _ => 'jpg',
    };
    final key = '${body.purpose.json}/${viewer.id}/${db.nextId()}.$ext';
    db.uploadOwners[key] = viewer.id;
    return MockResponse.json(
      UploadOut(
        objectKey: key,
        uploadUrl: 'mock://upload/$key',
        headers: {'Content-Type': body.contentType.json},
        expiresAt: db.clock().toUtc().add(const Duration(minutes: 15)),
      ).toJson(),
    );
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
