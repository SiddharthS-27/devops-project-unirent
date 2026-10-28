import 'dart:async';

import '../generated/models.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_listings.dart';
import 'mock_server.dart';

/// Booking routes of the mock backend.
Map<String, MockHandler> bookingHandlers(MockDb db) {
  final h = MockBookingHandlers(db);
  return {
    'GET /api/v1/bookings/quote': h.quote,
    'POST /api/v1/bookings': h.idempotent(h.request),
    'GET /api/v1/bookings': h.list,
    'GET /api/v1/bookings/{booking_id}': h.get,
    'POST /api/v1/bookings/{booking_id}/approve': h.idempotent(h.approve),
    'POST /api/v1/bookings/{booking_id}/decline': h.idempotent(h.decline),
    'POST /api/v1/bookings/{booking_id}/withdraw': h.idempotent(h.withdraw),
    'POST /api/v1/bookings/{booking_id}/cancel': h.idempotent(h.cancel),
    'POST /api/v1/bookings/{booking_id}/cancellation-rating':
        h.rateCancellation,
  };
}

class MockBookingHandlers {
  MockBookingHandlers(this.db) : views = MockBookingViews(db);

  final MockDb db;
  final MockBookingViews views;

  DateTime get now => db.clock().toUtc();

  MockAccount account(MockRequest r) => mockAuthenticate(db, r);

  /// Requires an `Idempotency-Key` and replays the first response for a
  /// repeated key, like the backend.
  MockHandler idempotent(MockHandler handler) => (r) async {
    final key = r.headers.entries
        .where((e) => e.key.toLowerCase() == 'idempotency-key')
        .map((e) => e.value)
        .firstOrNull;
    if (key is! String || key.isEmpty) {
      throw mockValidation('Idempotency-Key', 'Field required');
    }
    final cacheKey = '${account(r).id}:${r.method} ${r.path}:$key';
    final cached = db.idempotentResponses[cacheKey];
    if (cached != null) return cached;
    final MockResponse response;
    try {
      response = await handler(r);
    } on MockApiError catch (e) {
      return e.toResponse(); // Errors aren't replayed.
    }
    db.idempotentResponses[cacheKey] = response;
    return response;
  };

  MockBooking booking(MockRequest r, MockAccount viewer) {
    final b = db.bookings[r.pathParams['booking_id']];
    if (b == null || (b.roleOf(viewer.id) == null && !viewer.isStaff)) {
      throw const MockApiError(404, 'NOT_FOUND', 'Booking not found');
    }
    return b;
  }

  static void requireParty(MockBooking b, MockAccount actor, TradeRole role) {
    if (b.roleOf(actor.id) != role) {
      throw MockApiError(
        403,
        'NOT_YOUR_STEP',
        'Only the ${role == TradeRole.owner ? 'owner' : 'renter'} can do this',
      );
    }
  }

  static void requireStatus(MockBooking b, Set<BookingStatus> statuses) {
    if (!statuses.contains(b.status)) {
      throw MockApiError(
        409,
        'BOOKING_STATE',
        'This booking is ${b.status.json.replaceAll('_', ' ')}',
        {'status': b.status.json},
      );
    }
  }

  void moveTo(MockBooking b, BookingStatus status) {
    b
      ..status = status
      ..updatedAt = now;
  }

  MockResponse view(MockBooking b, MockAccount viewer, {int status = 200}) =>
      MockResponse(status, views.out(b, viewer).toJson());

  // ---- pricing ---------------------------------------------------------------

  MockListing _listing(String? id) {
    final listing = db.listings[id];
    if (listing == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Listing not found');
    }
    return listing;
  }

  /// (hours, amount) for [l] over the period (backend `pricing.quote`).
  (int?, int) price(MockListing l, DateTime? start, DateTime? end) {
    if (l.kind == TradeKind.sale) {
      if (start != null || end != null) {
        throw const MockApiError(
          422,
          'NO_PERIOD_FOR_SALE',
          'Purchases have no rental period',
        );
      }
      return (null, l.salePricePaise ?? 0);
    }
    if (start == null || end == null) {
      throw const MockApiError(
        422,
        'PERIOD_REQUIRED',
        'Pick a start and end time',
      );
    }
    if (start.isBefore(now.subtract(const Duration(minutes: 5)))) {
      throw const MockApiError(
        422,
        'START_IN_PAST',
        'The start time has passed',
      );
    }
    final hours = mockRentalHours(start, end);
    if (!end.isAfter(start) || hours < mockMinRentalHours) {
      throw const MockApiError(
        422,
        'PERIOD_TOO_SHORT',
        'Rent for at least an hour',
      );
    }
    if (hours > mockMaxRentalDays * 24) {
      throw const MockApiError(
        422,
        'PERIOD_TOO_LONG',
        'Rent for at most $mockMaxRentalDays days',
      );
    }
    return (hours, mockRentFor(l, hours));
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

  MockResponse quote(MockRequest r) {
    account(r);
    final listing = _listing(r.query['listing_id'] as String?);
    final start = _date(r.query['start_at']);
    final end = _date(r.query['end_at']);
    final (hours, amount) = price(listing, start, end);
    return MockResponse.json(
      QuoteOut(
        listingId: listing.id,
        kind: listing.kind,
        startAt: start,
        endAt: end,
        hours: hours,
        amountPaise: amount,
        lateFeeRule: listing.kind == TradeKind.rent
            ? mockLateFeeRule(now)
            : null,
      ).toJson(),
    );
  }

  /// True when an approved-or-later booking (or a seeded blocked slot)
  /// overlaps the period.
  bool slotTaken(
    MockListing l,
    DateTime start,
    DateTime end, {
    String? except,
  }) {
    final booked = db.bookings.values.any(
      (b) =>
          b.id != except &&
          b.listingId == l.id &&
          b.kind == TradeKind.rent &&
          mockHoldsSlot.contains(b.status) &&
          b.startAt!.isBefore(end) &&
          b.endAt!.isAfter(start),
    );
    final blocked = l.unavailable.any(
      (s) => s.startAt.isBefore(end) && s.endAt.isAfter(start),
    );
    return booked || blocked;
  }

  // ---- request, list, view -----------------------------------------------------

  FutureOr<MockResponse> request(MockRequest r) {
    final renter = account(r);
    if (renter.status == 'suspended') {
      throw const MockApiError(
        403,
        'ACCOUNT_SUSPENDED',
        'Your account is suspended',
      );
    }
    if (renter.role != 'student' ||
        db.profiles[renter.id] == null ||
        renter.phoneVerifiedAt == null) {
      throw const MockApiError(
        403,
        'ONBOARDING_INCOMPLETE',
        'Finish setting up your profile first',
      );
    }
    final body = mockParse(r, BookingCreate.fromJson);
    final listing = _listing(body.listingId);
    if (listing.status != ListingStatus.active) {
      throw const MockApiError(
        409,
        'LISTING_UNAVAILABLE',
        "This listing isn't available",
      );
    }
    if (listing.ownerId == renter.id) {
      throw const MockApiError(
        409,
        'OWN_LISTING',
        "You can't request your own listing",
      );
    }
    final start = body.startAt?.toUtc();
    final end = body.endAt?.toUtc();
    final (_, amount) = price(listing, start, end);
    final open = db.bookings.values.any(
      (b) =>
          b.listingId == listing.id &&
          b.renterId == renter.id &&
          (b.status == BookingStatus.requested ||
              b.status == BookingStatus.approved),
    );
    if (open) {
      throw const MockApiError(
        409,
        'REQUEST_EXISTS',
        'You already have an open request for this',
      );
    }
    if (listing.kind == TradeKind.rent && slotTaken(listing, start!, end!)) {
      throw const MockApiError(
        409,
        'SLOT_TAKEN',
        'Those dates are already booked',
      );
    }
    final id = db.nextId();
    final b = db.bookings[id] = MockBooking(
      id: id,
      listingId: listing.id,
      kind: listing.kind,
      renterId: renter.id,
      ownerId: listing.ownerId,
      amountPaise: amount,
      createdAt: now,
      startAt: start,
      endAt: end,
    );
    return view(b, renter, status: 201);
  }

  MockResponse list(MockRequest r) {
    final viewer = account(r);
    final role =
        TradeRole.fromJson(r.query['role'] as String? ?? 'renter') ==
            TradeRole.owner
        ? TradeRole.owner
        : TradeRole.renter;
    final groupRaw = r.query['group'] as String?;
    final group = groupRaw == null ? null : BookingGroup.fromJson(groupRaw);
    final listingId = r.query['listing_id'] as String?;
    final mine =
        db.bookings.values
            .where(
              (b) =>
                  (role == TradeRole.renter ? b.renterId : b.ownerId) ==
                      viewer.id &&
                  (group == null ||
                      (mockBookingGroups[group]?.contains(b.status) ??
                          false)) &&
                  (listingId == null || b.listingId == listingId),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final offset = int.tryParse('${r.query['cursor'] ?? 0}') ?? 0;
    final limit = (int.tryParse('${r.query['limit'] ?? 20}') ?? 20).clamp(
      1,
      50,
    );
    final page = mine.skip(offset).take(limit).toList();
    final next = offset + page.length;
    return MockResponse.json(
      BookingSummaryPage(
        items: [for (final b in page) views.summary(b, role)],
        nextCursor: next < mine.length ? '$next' : null,
      ).toJson(),
    );
  }

  MockResponse get(MockRequest r) {
    final viewer = account(r);
    return view(booking(r, viewer), viewer);
  }

  // ---- owner decisions -------------------------------------------------------

  FutureOr<MockResponse> approve(MockRequest r) {
    final owner = account(r);
    final b = booking(r, owner);
    requireParty(b, owner, TradeRole.owner);
    requireStatus(b, {BookingStatus.requested});
    final listing = db.listings[b.listingId]!;
    if (listing.status != ListingStatus.active) {
      throw const MockApiError(
        409,
        'LISTING_UNAVAILABLE',
        'Resume the listing before approving',
      );
    }
    if (b.kind == TradeKind.rent &&
        slotTaken(listing, b.startAt!, b.endAt!, except: b.id)) {
      throw const MockApiError(
        409,
        'SLOT_TAKEN',
        'You already approved a booking for these dates',
      );
    }
    // Terms lock at approval.
    b.amountPaise = b.kind == TradeKind.rent
        ? mockRentFor(listing, mockRentalHours(b.startAt!, b.endAt!))
        : listing.salePricePaise ?? b.amountPaise;
    moveTo(b, BookingStatus.approved);
    b.decidedAt = now;
    // Clashing requests (every other one, for a sale) are declined.
    for (final other in db.bookings.values) {
      if (other.id == b.id ||
          other.listingId != b.listingId ||
          other.status != BookingStatus.requested) {
        continue;
      }
      final clash =
          b.kind == TradeKind.sale ||
          (other.startAt!.isBefore(b.endAt!) &&
              other.endAt!.isAfter(b.startAt!));
      if (clash) {
        moveTo(other, BookingStatus.declined);
        other
          ..decidedAt = now
          ..declineReason = 'Another request for these dates was approved';
      }
    }
    return view(b, owner);
  }

  FutureOr<MockResponse> decline(MockRequest r) {
    final owner = account(r);
    final b = booking(r, owner);
    requireParty(b, owner, TradeRole.owner);
    requireStatus(b, {BookingStatus.requested});
    final body = r.body == null
        ? const DeclineIn()
        : mockParse(r, DeclineIn.fromJson);
    moveTo(b, BookingStatus.declined);
    b
      ..decidedAt = now
      ..declineReason = body.reason;
    return view(b, owner);
  }

  // ---- withdraw, cancel, rate ------------------------------------------------

  FutureOr<MockResponse> withdraw(MockRequest r) {
    final renter = account(r);
    final b = booking(r, renter);
    requireParty(b, renter, TradeRole.renter);
    requireStatus(b, {BookingStatus.requested});
    moveTo(b, BookingStatus.withdrawn);
    return view(b, renter);
  }

  /// Either side, after approval and until the handover is paid.
  FutureOr<MockResponse> cancel(MockRequest r) {
    final actor = account(r);
    final b = booking(r, actor);
    final role = b.roleOf(actor.id);
    if (role == null) {
      throw const MockApiError(
        403,
        'NOT_YOUR_STEP',
        'Only the two sides can cancel',
      );
    }
    final note = mockParse(r, CancelIn.fromJson).note;
    if (note.trim().length < 5 || note.length > 1000) {
      throw mockValidation('note', 'Must be 5-1000 characters');
    }
    requireStatus(b, {BookingStatus.approved});
    if (b.paymentFor(b.handoverPurpose)?.isPaid ?? false) {
      throw const MockApiError(
        409,
        'ALREADY_PAID',
        "It's paid for; finish the handover or ask for help",
      );
    }
    moveTo(b, BookingStatus.cancelled);
    b.cancellation = MockCancellation(by: role, note: note.trim(), at: now);
    actor.cancellationCount++;
    return view(b, actor);
  }

  MockResponse rateCancellation(MockRequest r) {
    final actor = account(r);
    final b = booking(r, actor);
    final c = b.cancellation;
    if (c == null) {
      throw const MockApiError(
        409,
        'NOT_CANCELLED',
        "This booking wasn't cancelled",
      );
    }
    final role = b.roleOf(actor.id);
    if (role == null || role == c.by) {
      throw const MockApiError(
        403,
        'NOT_YOUR_STEP',
        'The other side rates the cancellation',
      );
    }
    if (c.ratedAt != null) {
      throw const MockApiError(
        409,
        'ALREADY_RATED',
        'You already rated this cancellation',
      );
    }
    final body = mockParse(r, CancellationRatingIn.fromJson);
    if (body.stars < 1 || body.stars > 5) {
      throw mockValidation('stars', 'Must be 1-5');
    }
    if (body.comment.trim().length < 2 || body.comment.length > 1000) {
      throw mockValidation('comment', 'Must be 2-1000 characters');
    }
    c
      ..ratingStars = body.stars
      ..ratingComment = body.comment.trim()
      ..ratedAt = now;
    return view(b, actor);
  }
}

/// Seeds requests on Asha's listings so the owner views have content:
/// two overlapping requests for her bike and one for her calculator.
void seedBookings(MockDb db) {
  final now = db.clock().toUtc();
  final karan = db.accountByEmail('karan@college.edu')!;
  final meera = db.accountByEmail('meera@college.edu')!;
  final dev = db.accountByEmail('dev@college.edu')!;
  final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);

  void request(
    String id,
    int listing,
    MockAccount renter,
    DateTime start,
    DateTime end,
    Duration age,
  ) {
    final l = db.listings[mockListingId(listing)]!;
    db.bookings[id] = MockBooking(
      id: id,
      listingId: l.id,
      kind: l.kind,
      renterId: renter.id,
      ownerId: l.ownerId,
      amountPaise: mockRentFor(l, mockRentalHours(start, end)),
      createdAt: now.subtract(age),
      startAt: start,
      endAt: end,
    );
  }

  // Times are IST: tomorrow 10:00-18:00 and 12:00-20:00.
  request(
    '00000000-0000-4000-d000-000000000001',
    3,
    karan,
    tomorrow.add(const Duration(hours: 4, minutes: 30)),
    tomorrow.add(const Duration(hours: 12, minutes: 30)),
    const Duration(hours: 2),
  );
  request(
    '00000000-0000-4000-d000-000000000002',
    3,
    meera,
    tomorrow.add(const Duration(hours: 6, minutes: 30)),
    tomorrow.add(const Duration(hours: 14, minutes: 30)),
    const Duration(hours: 1),
  );
  request(
    '00000000-0000-4000-d000-000000000003',
    15,
    dev,
    tomorrow.add(const Duration(days: 1, hours: 3, minutes: 30)),
    tomorrow.add(const Duration(days: 2, hours: 3, minutes: 30)),
    const Duration(minutes: 30),
  );
}
