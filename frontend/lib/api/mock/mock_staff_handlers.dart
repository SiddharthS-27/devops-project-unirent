import '../generated/models.dart';
import 'mock_appeal_handlers.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_listings.dart';
import 'mock_server.dart';
import 'mock_views.dart';

class MockRuling {
  MockRuling({
    required this.id,
    required this.appealId,
    required this.ruledBy,
    required this.ruledAt,
    required this.body,
    this.overrules,
  });

  final String id;
  final String appealId;
  final String ruledBy;
  final DateTime ruledAt;
  final RulingIn body;
  final String? overrules;
}

class MockTrustPenalty {
  MockTrustPenalty({
    required this.id,
    required this.accountId,
    required this.role,
    required this.points,
    required this.reason,
    required this.by,
    required this.at,
    this.rulingId,
  });

  final String id;
  final String accountId;
  final TrustRole role;
  final int points;
  final String reason;
  final String by;
  final DateTime at;
  final String? rulingId;
  DateTime? revokedAt;
}

/// The caller, who must be a moderator or the admin.
MockAccount mockStaff(MockDb db, MockRequest r, {bool adminOnly = false}) {
  final account = mockAuthenticate(db, r);
  if (adminOnly ? account.role != 'admin' : !account.isStaff) {
    throw const MockApiError(
      403,
      'ROLE_NOT_ALLOWED',
      "Your role can't do this",
    );
  }
  return account;
}

/// Takes [points] off the account's [role] trust (the mock keeps scores as
/// plain numbers; the backend recomputes them).
void mockApplyPenalty(MockDb db, MockTrustPenalty p, {bool undo = false}) {
  final account = db.accounts[p.accountId];
  if (account == null) return;
  int? shift(int? score) => score == null
      ? null
      : (score + (undo ? p.points : -p.points)).clamp(0, 100);
  if (p.role == TrustRole.lender) {
    account.lenderScore = shift(account.lenderScore);
  } else {
    account.renterScore = shift(account.renterScore);
  }
}

Map<String, MockHandler> staffHandlers(MockDb db) {
  final h = MockStaffHandlers(db);
  return {
    'GET /api/v1/staff/appeals': h.appealsQueue,
    'GET /api/v1/staff/appeals/{appeal_id}': h.appeal,
    'POST /api/v1/staff/appeals/{appeal_id}/ruling': h.rule,
  };
}

class MockStaffHandlers {
  MockStaffHandlers(this.db) : views = MockBookingViews(db);

  final MockDb db;
  final MockBookingViews views;

  DateTime get now => db.clock().toUtc();

  String _name(String accountId) =>
      db.profiles[accountId]?.data.fullName ??
      db.accounts[accountId]?.name ??
      'Student';

  MockAppeal _appeal(MockRequest r) {
    final a = db.appeals[r.pathParams['appeal_id']];
    if (a == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Appeal not found');
    }
    return a;
  }

  MockResponse appealsQueue(MockRequest r) {
    mockStaff(db, r);
    final filter = AppealFilter.fromJson(
      r.query['status']?.toString() ?? 'open',
    );
    final rows =
        db.appeals.values
            .where(
              (a) => switch (filter) {
                AppealFilter.open => a.status == AppealStatus.open,
                AppealFilter.ruled => a.status != AppealStatus.open,
                _ => true,
              },
            )
            .toList()
          ..sort(
            (a, b) => filter == AppealFilter.open
                ? a.createdAt.compareTo(b.createdAt)
                : b.createdAt.compareTo(a.createdAt),
          );
    return MockResponse.json([
      for (final a in rows)
        AppealSummary(
          id: a.id,
          bookingId: a.bookingId,
          kind: db.bookings[a.bookingId]!.kind,
          listingTitle: db.listings[db.bookings[a.bookingId]!.listingId]!.title,
          reason: a.reason.json,
          status: a.status,
          filedByName: _name(a.filedById),
          createdAt: a.createdAt,
        ).toJson(),
    ]);
  }

  AppealDetail detail(MockAppeal a, MockAccount viewer) {
    final b = db.bookings[a.bookingId]!;
    List<PhotoOut> photos(MockPhase phase) => [
      for (final side in [TradeRole.renter, TradeRole.owner])
        for (final p in b.photos[(phase, side)] ?? const <MockPhoto>[])
          PhotoOut(id: p.key, url: p.url),
    ];
    return AppealDetail(
      appeal: mockAppealOut(a),
      booking: views.out(b, viewer),
      pickupPhotos: photos(MockPhase.pickup),
      returnPhotos: photos(MockPhase.returnPhase),
      extraPhotos: [
        for (final k in a.photoKeys) PhotoOut(id: k, url: mockPhotoUrlFor(k)!),
      ],
      rulings: [
        for (final x in db.rulings.where((x) => x.appealId == a.id))
          RulingOut(
            id: x.id,
            ruledBy: x.ruledBy,
            ruledAt: x.ruledAt,
            overrules: x.overrules,
            summary: x.body.summary,
            chargePaise: x.body.chargePaise,
            refundPaise: x.body.refundPaise,
            trustPenalty: x.body.trustPenalty,
            removeListing: x.body.removeListing,
            accountAction: x.body.accountAction,
          ),
      ],
    );
  }

  MockResponse appeal(MockRequest r) {
    final viewer = mockStaff(db, r);
    return MockResponse.json(detail(_appeal(r), viewer).toJson());
  }

  RulingIn _rulingBody(MockRequest r, MockBooking b) {
    final body = mockParse(r, RulingIn.fromJson);
    if (body.summary.length < 5 || body.summary.length > 2000) {
      throw mockValidation('summary', 'Must be 5-2000 characters');
    }
    if ((body.chargePaise ?? 0) < 0) {
      throw mockValidation('charge_paise', 'Must be 0 or more');
    }
    if (body.refundPaise != null && body.refundPaise! <= 0) {
      throw mockValidation('refund_paise', 'Must be more than 0');
    }
    final points = body.trustPenalty?.points;
    if (points != null && (points < 1 || points > 50)) {
      throw mockValidation('trust_penalty.points', 'Must be 1-50');
    }
    final parties = {b.renterId, b.ownerId};
    for (final target in [
      body.trustPenalty?.accountId,
      body.accountAction?.accountId,
    ]) {
      if (target != null && !parties.contains(target)) {
        throw const MockApiError(
          422,
          'NOT_A_PARTY',
          'Rulings apply to the two sides of this booking',
        );
      }
    }
    return body;
  }

  /// The ruling's effects (backend `appeals._apply`).
  void apply(MockBooking b, MockRuling ruling, MockAccount staff) {
    final body = ruling.body;
    if (body.chargePaise != null &&
        b.kind == TradeKind.rent &&
        b.proceededAt == null) {
      b
        ..damagePaise = body.chargePaise!
        ..damageDescription = body.summary;
    }
    final refund = body.refundPaise;
    if (refund != null) {
      final purposes = b.kind == TradeKind.rent
          ? [PaymentPurpose.returnCharges, PaymentPurpose.rent]
          : [PaymentPurpose.sale];
      MockPayment? payment;
      var left = 0;
      for (final purpose in purposes) {
        final p = b.paymentFor(purpose);
        if (p == null || !p.isPaid) continue;
        final refunded = p.refunds
            .where((x) => x.status != RefundOutStatus.failed)
            .fold(0, (sum, x) => sum + x.amountPaise);
        if (p.amountPaise - refunded > 0) {
          payment = p;
          left = p.amountPaise - refunded;
          break;
        }
      }
      if (payment == null || refund > left) {
        throw const MockApiError(
          422,
          'REFUND_TOO_LARGE',
          "There isn't that much paid to refund",
        );
      }
      final cash = payment.method == PaymentMethod.cash;
      payment.refunds.add(
        MockRefund(
          id: db.nextId(),
          amountPaise: refund,
          method: payment.method,
          createdAt: now,
          status: cash
              ? RefundOutStatus.cashPending
              : RefundOutStatus.processed,
        )..processedAt = cash ? null : now,
      );
      if (!cash) {
        payment.status = payment.refundedPaise >= payment.amountPaise
            ? PaymentStatus.refunded
            : PaymentStatus.partlyRefunded;
      }
    }
    final penalty = body.trustPenalty;
    if (penalty != null) {
      final p = MockTrustPenalty(
        id: db.nextId(),
        accountId: penalty.accountId,
        role: penalty.role,
        points: penalty.points,
        reason: body.summary,
        by: staff.id,
        at: now,
        rulingId: ruling.id,
      );
      db.trustPenalties.add(p);
      mockApplyPenalty(db, p);
    }
    if (body.removeListing) {
      final listing = db.listings[b.listingId];
      if (listing != null &&
          const {
            ListingStatus.active,
            ListingStatus.paused,
          }.contains(listing.status)) {
        listing
          ..status = ListingStatus.removed
          ..removedReason = body.summary;
      }
    }
    final action = body.accountAction;
    if (action != null) {
      db.accounts[action.accountId]?.status = action.status.json;
    }
  }

  MockResponse rule(MockRequest r) {
    final staff = mockStaff(db, r);
    final a = _appeal(r);
    if (a.status != AppealStatus.open) {
      throw const MockApiError(
        409,
        'APPEAL_RULED',
        'This appeal already has a ruling',
      );
    }
    final b = db.bookings[a.bookingId]!;
    final ruling = MockRuling(
      id: db.nextId(),
      appealId: a.id,
      ruledBy: staff.id,
      ruledAt: now,
      body: _rulingBody(r, b),
    );
    apply(b, ruling, staff);
    db.rulings.add(ruling);
    a.status = AppealStatus.ruled;
    b
      ..status = b.kind == TradeKind.rent
          ? BookingStatus.returning
          : a.previousStatus
      ..updatedAt = now;
    return MockResponse.json(detail(a, staff).toJson());
  }
}
