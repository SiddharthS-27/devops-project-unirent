import 'dart:async';
import 'dart:math';

import '../generated/models.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_listings.dart';
import 'mock_payment_handlers.dart';
import 'mock_review_handlers.dart';
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
    'POST /api/v1/bookings/{booking_id}/pickup/photos': h.pickupPhotos,
    'POST /api/v1/bookings/{booking_id}/pickup/payment': h.idempotent(
      h.pickupPayment,
    ),
    'POST /api/v1/bookings/{booking_id}/pickup/otp': h.pickupOtp,
    'POST /api/v1/bookings/{booking_id}/pickup/otp/verify': h.idempotent(
      h.verifyPickupOtp,
    ),
    'POST /api/v1/bookings/{booking_id}/extensions': h.idempotent(
      h.requestExtension,
    ),
    'POST /api/v1/bookings/{booking_id}/extensions/{extension_id}/approve': h
        .idempotent((r) => h.decideExtension(r, approve: true)),
    'POST /api/v1/bookings/{booking_id}/extensions/{extension_id}/decline': h
        .idempotent((r) => h.decideExtension(r, approve: false)),
    'POST /api/v1/bookings/{booking_id}/extensions/{extension_id}/payment': h
        .idempotent(h.payExtension),
    'POST /api/v1/bookings/{booking_id}/escalate': h.escalate,
    'POST /api/v1/bookings/{booking_id}/return/start': h.idempotent(
      h.startReturn,
    ),
    'POST /api/v1/bookings/{booking_id}/return/photos': (r) =>
        h.addPhotos(r, MockPhase.returnPhase),
    'POST /api/v1/bookings/{booking_id}/return/otp': h.returnOtp,
    'POST /api/v1/bookings/{booking_id}/return/otp/verify': h.idempotent(
      h.verifyReturnOtp,
    ),
    'POST /api/v1/bookings/{booking_id}/damage-charge': h.idempotent(
      h.recordDamage,
    ),
    'POST /api/v1/bookings/{booking_id}/return/payment': h.idempotent(
      h.payReturnCharges,
    ),
    'POST /api/v1/bookings/{booking_id}/proceed': h.idempotent(h.proceed),
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
    applyTimers(b);
    return b;
  }

  /// What the backend's timers would have done by now: unanswered requests
  /// expire after 24 hours; a rental is overdue once its end time plus the
  /// grace period has passed.
  void applyTimers(MockBooking b) {
    mockApplyReviewRelease(db, b);
    if (b.status == BookingStatus.requested &&
        now.difference(b.createdAt) > const Duration(hours: 24)) {
      moveTo(b, BookingStatus.expired);
    }
    if (b.status == BookingStatus.active) {
      final grace = Duration(minutes: mockLateFeeRule(now, db).graceMinutes);
      final overdueAt = b.endAt!.add(grace);
      if (!now.isBefore(overdueAt)) {
        moveTo(b, BookingStatus.overdue);
        b.overdueSince = overdueAt;
      }
    }
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
            ? mockLateFeeRule(now, db)
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
    db.bookings.values.forEach(applyTimers);
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
    // Cancellation ratings show among the canceller's reviews.
    db.reviews.add(
      MockReview(
        id: db.nextId(),
        bookingId: b.id,
        reviewerId: actor.id,
        revieweeId: c.by == TradeRole.owner ? b.ownerId : b.renterId,
        revieweeRole: c.by == TradeRole.owner
            ? TrustRole.lender
            : TrustRole.renter,
        type: ReviewType.cancellation,
        ratings: {'overall': body.stars},
        comment: body.comment.trim(),
        createdAt: now,
      )..revealedAt = now,
    );
    return view(b, actor);
  }

  // ---- handovers (shared by pickup and return) --------------------------------

  static const maxHandoverPhotos = 8;
  static final _random = Random();

  static BookingStatus _phaseStatus(MockPhase phase) =>
      phase == MockPhase.pickup
      ? BookingStatus.approved
      : BookingStatus.returning;

  /// The side that shows the code: the renter at pickup, the owner at return.
  static TradeRole shower(MockPhase phase) =>
      phase == MockPhase.pickup ? TradeRole.renter : TradeRole.owner;

  static MockApiError stepLocked(String message) =>
      MockApiError(409, 'STEP_LOCKED', message);

  MockResponse addPhotos(MockRequest r, MockPhase phase) {
    final actor = account(r);
    final b = booking(r, actor);
    final side = b.roleOf(actor.id);
    if (side == null) {
      throw const MockApiError(
        403,
        'NOT_YOUR_STEP',
        'Only the two sides upload handover photos',
      );
    }
    requireStatus(b, {_phaseStatus(phase)});
    if (phase == MockPhase.returnPhase &&
        side == TradeRole.owner &&
        !b.hasPhotos(phase, TradeRole.renter)) {
      throw stepLocked('The renter uploads return photos first');
    }
    final keys = mockParse(r, PhotosIn.fromJson).objectKeys;
    final list = b.photos.putIfAbsent((phase, side), () => []);
    if (keys.isEmpty || list.length + keys.length > maxHandoverPhotos) {
      throw const MockApiError(
        422,
        'TOO_MANY_PHOTOS',
        'Up to $maxHandoverPhotos photos each',
      );
    }
    for (final key in keys) {
      if (db.uploadOwners[key] != actor.id) {
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
    for (final key in keys) {
      final colour = (key.hashCode & 0xFFFFFF)
          .toRadixString(16)
          .padLeft(6, '0');
      list.add(MockPhoto(id: key, key: key, url: 'mock://photo/$colour'));
    }
    b.updatedAt = now;
    return view(b, actor);
  }

  bool pickupReady(MockBooking b) =>
      b.hasPhotos(MockPhase.pickup, TradeRole.renter) &&
      b.hasPhotos(MockPhase.pickup, TradeRole.owner) &&
      (b.paymentFor(b.handoverPurpose)?.isPaid ?? false);

  MockResponse showCode(MockRequest r, MockPhase phase, {required bool ready}) {
    final actor = account(r);
    final b = booking(r, actor);
    requireParty(b, actor, shower(phase));
    requireStatus(b, {_phaseStatus(phase)});
    if (!ready) throw stepLocked('Finish the earlier steps first');
    final code = _random.nextInt(1000000).toString().padLeft(6, '0');
    final otp = b.otps[phase] = MockOtp(code, now.add(mockOtpTtl));
    return MockResponse.json(
      OtpOut(code: otp.code, expiresAt: otp.expiresAt).toJson(),
    );
  }

  /// Checks the typed code; 5 tries per code, then a new one is needed.
  void checkCode(
    MockRequest r,
    MockBooking b,
    MockAccount actor,
    MockPhase phase,
  ) {
    final typer = shower(phase) == TradeRole.renter
        ? TradeRole.owner
        : TradeRole.renter;
    requireParty(b, actor, typer);
    requireStatus(b, {_phaseStatus(phase)});
    final otp = b.otps[phase];
    if (otp == null || otp.used) {
      throw stepLocked('Ask the other side to show their code');
    }
    if (otp.expiresAt.isBefore(now)) {
      throw const MockApiError(
        409,
        'CODE_EXPIRED',
        'The code expired; ask for a new one',
      );
    }
    if (otp.tries >= mockOtpMaxTries) {
      throw const MockApiError(
        429,
        'RATE_LIMITED',
        'Too many attempts. Please wait a moment and try again.',
      );
    }
    otp.tries++;
    if (mockParse(r, OtpIn.fromJson).code != otp.code) {
      throw const MockApiError(422, 'WRONG_CODE', 'That code is not right');
    }
    otp.used = true;
  }

  // ---- pickup ------------------------------------------------------------------

  MockResponse pickupPhotos(MockRequest r) => addPhotos(r, MockPhase.pickup);

  FutureOr<MockResponse> pickupPayment(MockRequest r) {
    final renter = account(r);
    final b = booking(r, renter);
    requireParty(b, renter, TradeRole.renter);
    requireStatus(b, {BookingStatus.approved});
    if (renter.status == 'suspended') {
      throw const MockApiError(
        403,
        'ACCOUNT_SUSPENDED',
        'Your account is suspended',
      );
    }
    if (!b.hasPhotos(MockPhase.pickup, TradeRole.renter) ||
        !b.hasPhotos(MockPhase.pickup, TradeRole.owner)) {
      throw stepLocked('Both of you upload pickup photos first');
    }
    final method = mockParse(r, PaymentStartIn.fromJson).method;
    final label = b.kind == TradeKind.rent ? 'Rent' : 'Sale price';
    final payment = mockStartPayment(
      db,
      b,
      purpose: b.handoverPurpose,
      method: method,
      amountPaise: b.amountPaise,
      items: [PaymentItem(label: label, amountPaise: b.amountPaise)],
      payerId: b.renterId,
      payeeId: b.ownerId,
    );
    b.updatedAt = now;
    return MockResponse.json(views.paymentOut(payment).toJson());
  }

  MockResponse pickupOtp(MockRequest r) {
    final actor = account(r);
    final b = booking(r, actor);
    return showCode(r, MockPhase.pickup, ready: pickupReady(b));
  }

  FutureOr<MockResponse> verifyPickupOtp(MockRequest r) {
    final owner = account(r);
    final b = booking(r, owner);
    checkCode(r, b, owner, MockPhase.pickup);
    b.pickupCompletedAt = now;
    final listing = db.listings[b.listingId]!;
    final asset = db.assets[listing.assetId];
    if (b.kind == TradeKind.rent) {
      moveTo(b, BookingStatus.active);
      asset
        ?..rentalCount += 1
        ..history.add(
          AssetHistoryEntry(
            at: now,
            kind: AssetEventKind.rented,
            summary: 'Rented out',
            amountPaise: b.amountPaise,
          ),
        );
    } else {
      moveTo(b, BookingStatus.awaitingReviews);
      listing.status = ListingStatus.sold;
      // The item and its history move to the buyer.
      asset
        ?..history.add(
          AssetHistoryEntry(
            at: now,
            kind: AssetEventKind.sold,
            summary: 'Sold',
            amountPaise: b.amountPaise,
          ),
        )
        ..ownerId = b.renterId;
    }
    return view(b, owner);
  }

  // ---- extensions ----------------------------------------------------------------

  MockExtension _extension(MockRequest r, MockBooking b) {
    final e = b.extensions
        .where((e) => e.id == r.pathParams['extension_id'])
        .firstOrNull;
    if (e == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Extension not found');
    }
    return e;
  }

  MockResponse _extensionOut(
    MockBooking b,
    MockExtension e, {
    int status = 200,
  }) => MockResponse(status, views.extensionOut(b, e).toJson());

  FutureOr<MockResponse> requestExtension(MockRequest r) {
    final renter = account(r);
    final b = booking(r, renter);
    requireParty(b, renter, TradeRole.renter);
    requireStatus(b, {BookingStatus.active});
    final newEnd = mockParse(r, ExtensionIn.fromJson).newEndAt.toUtc();
    if (!newEnd.isAfter(b.endAt!)) {
      throw const MockApiError(
        422,
        'EXTENSION_TOO_SHORT',
        'Pick a time after the current end time',
      );
    }
    if (mockRentalHours(b.startAt!, newEnd) > mockMaxRentalDays * 24) {
      throw const MockApiError(
        422,
        'PERIOD_TOO_LONG',
        'Rent for at most $mockMaxRentalDays days',
      );
    }
    if (b.extensions.any((e) => e.status == ExtensionStatus.requested)) {
      throw const MockApiError(
        409,
        'EXTENSION_PENDING',
        'Wait for the owner to answer the last request',
      );
    }
    final listing = db.listings[b.listingId]!;
    final e = MockExtension(
      id: db.nextId(),
      newEndAt: newEnd,
      amountPaise: mockRentFor(listing, mockRentalHours(b.endAt!, newEnd)),
      createdAt: now,
    );
    b
      ..extensions.add(e)
      ..updatedAt = now;
    return _extensionOut(b, e, status: 201);
  }

  FutureOr<MockResponse> decideExtension(
    MockRequest r, {
    required bool approve,
  }) {
    final owner = account(r);
    final b = booking(r, owner);
    requireParty(b, owner, TradeRole.owner);
    requireStatus(b, {BookingStatus.active});
    final e = _extension(r, b);
    if (e.status != ExtensionStatus.requested) {
      throw MockApiError(409, 'EXTENSION_DECIDED', 'Already ${e.status.json}');
    }
    if (approve) {
      final listing = db.listings[b.listingId]!;
      if (slotTaken(listing, b.endAt!, e.newEndAt, except: b.id)) {
        throw const MockApiError(
          409,
          'SLOT_TAKEN',
          'Someone else has booked that time',
        );
      }
      e.status = ExtensionStatus.approved;
      b
        ..endAt = e.newEndAt
        ..amountPaise += e.amountPaise;
    } else {
      e.status = ExtensionStatus.declined;
    }
    b.updatedAt = now;
    return _extensionOut(b, e);
  }

  /// UPI now, or cash at the return (added to the return charges).
  FutureOr<MockResponse> payExtension(MockRequest r) {
    final renter = account(r);
    final b = booking(r, renter);
    requireParty(b, renter, TradeRole.renter);
    final e = _extension(r, b);
    if (e.status != ExtensionStatus.approved) {
      throw const MockApiError(
        409,
        'EXTENSION_NOT_APPROVED',
        "The owner hasn't approved this extension",
      );
    }
    final method = mockParse(r, PaymentStartIn.fromJson).method;
    if (method == PaymentMethod.cash) {
      e.payInCashAtReturn = true;
    } else {
      mockStartPayment(
        db,
        b,
        purpose: PaymentPurpose.extension,
        ref: e.id,
        method: PaymentMethod.upi,
        amountPaise: e.amountPaise,
        items: [PaymentItem(label: 'Extension', amountPaise: e.amountPaise)],
        payerId: b.renterId,
        payeeId: b.ownerId,
      );
    }
    b.updatedAt = now;
    return _extensionOut(b, e);
  }

  // ---- overdue and return -------------------------------------------------------

  /// One hour into overdue the owner can hand the case to the moderators.
  MockResponse escalate(MockRequest r) {
    final owner = account(r);
    final b = booking(r, owner);
    requireParty(b, owner, TradeRole.owner);
    requireStatus(b, {BookingStatus.overdue});
    if (!b.canEscalate(now)) {
      throw const MockApiError(
        409,
        'ESCALATION_NOT_YET',
        'You can escalate an hour into overdue; use Help before that',
      );
    }
    final note = r.body == null ? null : mockParse(r, EscalateIn.fromJson).note;
    if (b.escalatedAt == null) {
      b
        ..escalatedAt = now
        ..escalationNote = note
        ..updatedAt = now;
    }
    return view(b, owner);
  }

  FutureOr<MockResponse> startReturn(MockRequest r) {
    final renter = account(r);
    final b = booking(r, renter);
    requireParty(b, renter, TradeRole.renter);
    requireStatus(b, {BookingStatus.active, BookingStatus.overdue});
    moveTo(b, BookingStatus.returning);
    b.returnStartedAt = now;
    return view(b, renter);
  }

  bool returnCodeReady(MockBooking b) =>
      b.hasPhotos(MockPhase.returnPhase, TradeRole.renter) &&
      b.hasPhotos(MockPhase.returnPhase, TradeRole.owner);

  MockResponse returnOtp(MockRequest r) {
    final actor = account(r);
    final b = booking(r, actor);
    return showCode(r, MockPhase.returnPhase, ready: returnCodeReady(b));
  }

  /// The renter typed the owner's code: the item is back and the late fee
  /// stops.
  FutureOr<MockResponse> verifyReturnOtp(MockRequest r) {
    final renter = account(r);
    final b = booking(r, renter);
    checkCode(r, b, renter, MockPhase.returnPhase);
    b
      ..frozenLateFeePaise = b.liveLateFee(now, db)
      ..returnCompletedAt = now
      ..updatedAt = now;
    final asset = db.assets[db.listings[b.listingId]!.assetId];
    asset?.history.add(
      AssetHistoryEntry(
        at: now,
        kind: AssetEventKind.returned,
        summary: 'Returned to the owner',
      ),
    );
    return view(b, renter);
  }

  void _requireItemBack(MockBooking b) {
    if (b.returnCompletedAt == null) {
      throw stepLocked('Confirm the return with the code first');
    }
  }

  /// The charge both sides agreed on.
  FutureOr<MockResponse> recordDamage(MockRequest r) {
    final owner = account(r);
    final b = booking(r, owner);
    requireParty(b, owner, TradeRole.owner);
    requireStatus(b, {BookingStatus.returning});
    _requireItemBack(b);
    if (b.paymentFor(PaymentPurpose.returnCharges)?.isPaid ?? false) {
      throw const MockApiError(
        409,
        'ALREADY_PAID',
        'The return charges are already paid',
      );
    }
    final body = mockParse(r, DamageChargeIn.fromJson);
    if (body.amountPaise < 0) {
      throw mockValidation('amount_paise', 'Must be 0 or more');
    }
    if (body.description.trim().length < 3 || body.description.length > 1000) {
      throw mockValidation('description', 'Must be 3-1000 characters');
    }
    b
      ..damagePaise = body.amountPaise
      ..damageDescription = body.description.trim()
      ..updatedAt = now;
    db.assets[db.listings[b.listingId]!.assetId]?.history.add(
      AssetHistoryEntry(
        at: now,
        kind: AssetEventKind.damageCharge,
        summary: body.description.trim(),
        amountPaise: body.amountPaise,
      ),
    );
    return view(b, owner);
  }

  List<PaymentItem> chargeItems(MockBooking b) => [
    for (final (label, amount) in [
      ('Late fee', b.frozenLateFeePaise ?? 0),
      ('Damage charge', b.damagePaise),
      ('Extensions paid in cash', b.cashExtensionsPaise),
    ])
      if (amount > 0) PaymentItem(label: label, amountPaise: amount),
  ];

  FutureOr<MockResponse> payReturnCharges(MockRequest r) {
    final renter = account(r);
    final b = booking(r, renter);
    requireParty(b, renter, TradeRole.renter);
    requireStatus(b, {BookingStatus.returning});
    _requireItemBack(b);
    final items = chargeItems(b);
    final total = items.fold(0, (sum, i) => sum + i.amountPaise);
    if (total == 0) {
      throw const MockApiError(409, 'NOTHING_TO_PAY', 'Nothing is owed');
    }
    final payment = mockStartPayment(
      db,
      b,
      purpose: PaymentPurpose.returnCharges,
      method: mockParse(r, PaymentStartIn.fromJson).method,
      amountPaise: total,
      items: items,
      payerId: b.renterId,
      payeeId: b.ownerId,
    );
    b.updatedAt = now;
    return MockResponse.json(views.paymentOut(payment).toJson());
  }

  /// Closes the return once everything owed is paid; reviews open.
  FutureOr<MockResponse> proceed(MockRequest r) {
    final owner = account(r);
    final b = booking(r, owner);
    requireParty(b, owner, TradeRole.owner);
    requireStatus(b, {BookingStatus.returning});
    _requireItemBack(b);
    final owed = chargeItems(b).isNotEmpty;
    final paid = b.paymentFor(PaymentPurpose.returnCharges)?.isPaid ?? false;
    if (owed && !paid) {
      throw const MockApiError(
        409,
        'CHARGES_UNPAID',
        "The renter hasn't paid the charges yet",
      );
    }
    moveTo(b, BookingStatus.awaitingReviews);
    b.proceededAt = now;
    return view(b, owner);
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
