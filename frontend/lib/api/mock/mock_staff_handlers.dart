import '../generated/models.dart';
import 'mock_admin_handlers.dart';
import 'mock_appeal_handlers.dart';
import 'mock_booking_handlers.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_help_handlers.dart';
import 'mock_listing_handlers.dart' show mockListingCard;
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
    'GET /api/v1/staff/support/threads': h.supportInbox,
    'GET /api/v1/staff/support/threads/{thread_id}': h.supportThread,
    'POST /api/v1/staff/support/threads/{thread_id}/messages': h.supportReply,
    'POST /api/v1/staff/support/threads/{thread_id}/close': h.closeThread,
    'GET /api/v1/staff/escalations': h.escalations,
    'GET /api/v1/staff/users': h.users,
    'GET /api/v1/staff/users/{account_id}': h.user,
    'POST /api/v1/staff/users/{account_id}/status': h.setStatus,
    'POST /api/v1/staff/users/{account_id}/trust-penalty': h.trustPenalty,
    'GET /api/v1/staff/listings': h.listings,
    'POST /api/v1/staff/listings/{listing_id}/remove': h.removeListing,
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
    mockAudit(
      db,
      staff,
      'moderation.ruling',
      'appeal:${a.id}',
      ruling.body.toJson(),
    );
    a.status = AppealStatus.ruled;
    b
      ..status = b.kind == TradeKind.rent
          ? BookingStatus.returning
          : a.previousStatus
      ..updatedAt = now;
    return MockResponse.json(detail(a, staff).toJson());
  }

  // ---- support ---------------------------------------------------------------

  MockSupportThread _thread(MockRequest r) {
    final t = db.supportThreads[r.pathParams['thread_id']];
    if (t == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Conversation not found');
    }
    return t;
  }

  MockResponse supportInbox(MockRequest r) {
    mockStaff(db, r);
    final status = ThreadStatus.fromJson(
      r.query['status']?.toString() ?? 'open',
    );
    final threads =
        db.supportThreads.values.where((t) => t.status == status).toList()
          ..sort((a, b) => b.messages.last.at.compareTo(a.messages.last.at));
    return MockResponse.json([
      for (final t in threads)
        SupportThreadSummary(
          id: t.id,
          accountId: t.accountId,
          accountName: db.profiles[t.accountId]?.data.fullName,
          bookingId: t.bookingId,
          subject: t.subject,
          status: t.status,
          lastMessageAt: t.messages.last.at,
          unanswered: t.unanswered,
        ).toJson(),
    ]);
  }

  MockResponse supportThread(MockRequest r) {
    mockStaff(db, r);
    return MockResponse.json(mockThreadOut(db, _thread(r)).toJson());
  }

  MockResponse supportReply(MockRequest r) {
    final staff = mockStaff(db, r);
    final t = _thread(r);
    if (t.status == ThreadStatus.closed) {
      throw const MockApiError(
        409,
        'THREAD_CLOSED',
        'This conversation is closed; start a new one',
      );
    }
    final body = mockParse(r, SupportMessageIn.fromJson).body;
    if (body.trim().isEmpty || body.length > 2000) {
      throw mockValidation('body', 'Must be 1-2000 characters');
    }
    final m = mockStaffReply(db, t, staff, body);
    mockAudit(db, staff, 'support.reply', 'support_thread:${t.id}');
    return MockResponse(201, mockMessageOut(db, m).toJson());
  }

  MockResponse closeThread(MockRequest r) {
    final staff = mockStaff(db, r);
    final t = _thread(r)
      ..status = ThreadStatus.closed
      ..updatedAt = now;
    mockAudit(db, staff, 'support.close', 'support_thread:${t.id}');
    return MockResponse.json(mockThreadOut(db, t).toJson());
  }

  // ---- escalations and risk flags -------------------------------------------

  MockResponse escalations(MockRequest r) {
    final staff = mockStaff(db, r);
    final bookings = MockBookingHandlers(db);
    for (final b in db.bookings.values) {
      bookings.applyTimers(b);
    }
    final overdue =
        db.bookings.values
            .where(
              (b) =>
                  b.status == BookingStatus.overdue &&
                  (b.escalatedAt != null ||
                      !b.overdueSince!.isAfter(
                        now.subtract(const Duration(hours: 1)),
                      )),
            )
            .toList()
          ..sort((a, b) => a.overdueSince!.compareTo(b.overdueSince!));
    final stalled =
        db.bookings.values
            .where(
              (b) =>
                  b.status == BookingStatus.returning &&
                  b.proceededAt == null &&
                  b.returnCompletedAt != null &&
                  !b.returnCompletedAt!.isAfter(
                    now.subtract(const Duration(hours: 24)),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => a.returnCompletedAt!.compareTo(b.returnCompletedAt!),
          );
    EscalationOut out(MockBooking b, EscalationKind kind) {
      final renter = mockProfileFor(db, b.renterId, staff);
      final owner = mockProfileFor(db, b.ownerId, staff);
      return EscalationOut(
        booking: views.summary(b, TradeRole.owner),
        kind: kind,
        since: switch (kind) {
          EscalationKind.ownerEscalated => b.escalatedAt!,
          EscalationKind.overdue => b.overdueSince!,
          _ => b.returnCompletedAt!,
        },
        renterId: b.renterId,
        renterName: renter.fullName,
        renterPhone: renter.phone,
        renterResidence: renter is ProfileStaff ? renter.residence : null,
        ownerName: owner.fullName,
        ownerPhone: owner.phone,
        note: b.escalationNote,
      );
    }

    return MockResponse.json([
      for (final b in overdue)
        out(
          b,
          b.escalatedAt != null
              ? EscalationKind.ownerEscalated
              : EscalationKind.overdue,
        ).toJson(),
      for (final b in stalled) out(b, EscalationKind.stalledProceed).toJson(),
    ]);
  }

  /// Backend `oversight.risk_flags`.
  List<RiskFlag> riskFlags(String accountId) {
    final since = now.subtract(const Duration(days: 30));
    final overdue = db.bookings.values
        .where(
          (b) =>
              b.renterId == accountId &&
              b.overdueSince != null &&
              !b.overdueSince!.isBefore(since),
        )
        .length;
    final cancellations = db.bookings.values.where((b) {
      final c = b.cancellation;
      if (c == null || c.at.isBefore(since)) return false;
      return (c.by == TradeRole.renter ? b.renterId : b.ownerId) == accountId;
    }).length;
    final disputes = db.appeals.values.where((a) {
      final b = db.bookings[a.bookingId];
      return b != null &&
          !a.createdAt.isBefore(since) &&
          (b.renterId == accountId || b.ownerId == accountId);
    }).length;
    final account = db.accounts[accountId];
    final scores = [?account?.lenderScore, ?account?.renterScore];
    final lowest = scores.isEmpty
        ? null
        : scores.reduce((a, b) => a < b ? a : b);
    return [
      if (overdue >= 3)
        RiskFlag(
          kind: RiskFlagKind.overdueReturns,
          count: overdue,
          windowDays: 30,
        ),
      if (cancellations >= 3)
        RiskFlag(
          kind: RiskFlagKind.cancellations,
          count: cancellations,
          windowDays: 30,
        ),
      if (disputes >= 2)
        RiskFlag(kind: RiskFlagKind.disputes, count: disputes, windowDays: 30),
      if (lowest != null && lowest < 30)
        RiskFlag(kind: RiskFlagKind.lowTrust, count: lowest, windowDays: null),
    ];
  }

  // ---- users -----------------------------------------------------------------

  StaffUserRow _row(MockAccount a) => StaffUserRow(
    accountId: a.id,
    fullName: db.profiles[a.id]?.data.fullName,
    email: a.email,
    status: a.status,
    lenderTrust: a.lenderScore,
    renterTrust: a.renterScore,
    riskFlags: riskFlags(a.id),
  );

  MockResponse users(MockRequest r) {
    mockStaff(db, r);
    final q = r.query['q']?.toString().trim().toLowerCase() ?? '';
    final flagged = r.query['flagged']?.toString() == 'true';
    final students =
        db.accounts.values.where((a) => a.role == 'student').toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<MockAccount> ids;
    if (flagged) {
      ids = students.where((a) => riskFlags(a.id).isNotEmpty).toList()
        ..sort((a, b) {
          final byCount = riskFlags(
            b.id,
          ).length.compareTo(riskFlags(a.id).length);
          return byCount != 0 ? byCount : a.id.compareTo(b.id);
        });
    } else {
      bool profileMatch(MockAccount a) {
        final p = db.profiles[a.id]?.data;
        if (p == null) return false;
        return q.isEmpty ||
            p.fullName.toLowerCase().contains(q) ||
            p.rollNumber.toLowerCase().contains(q);
      }

      ids = students.where(profileMatch).toList();
      if (q.isNotEmpty && (q.contains('@') || ids.isEmpty)) {
        ids += [
          for (final a in students)
            if (!ids.contains(a) && a.email.toLowerCase().contains(q)) a,
        ];
      }
    }
    final offset = int.tryParse(r.query['cursor']?.toString() ?? '') ?? 0;
    final limit = (int.tryParse(r.query['limit']?.toString() ?? '') ?? 20)
        .clamp(1, 50);
    final page = ids.skip(offset).take(limit).toList();
    return MockResponse.json(
      StaffUserRowPage(
        items: [for (final a in page) _row(a)],
        nextCursor: ids.length > offset + limit ? '${offset + limit}' : null,
      ).toJson(),
    );
  }

  MockAccount _student(MockRequest r) {
    final a = db.accounts[r.pathParams['account_id']];
    if (a == null || a.role != 'student') {
      throw const MockApiError(404, 'NOT_FOUND', 'User not found');
    }
    return a;
  }

  StaffUserDetail userDetail(MockAccount a, MockAccount staff) {
    final profile = db.profiles[a.id] == null
        ? null
        : mockProfileFor(db, a.id, staff);
    final bookings = [
      for (final b in db.bookings.values)
        if (b.renterId == a.id)
          views.summary(b, TradeRole.renter)
        else if (b.ownerId == a.id)
          views.summary(b, TradeRole.owner),
    ]..sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
    final penalties =
        db.trustPenalties
            .where((p) => p.accountId == a.id && p.revokedAt == null)
            .toList()
          ..sort((x, y) => y.at.compareTo(x.at));
    return StaffUserDetail(
      profile: profile is ProfileStaff ? profile : null,
      email: a.email,
      status: a.status,
      bookings: bookings,
      riskFlags: riskFlags(a.id),
      penalties: [
        for (final p in penalties)
          PenaltyOut(
            role: p.role,
            points: p.points,
            reason: p.reason,
            by: p.by,
            at: p.at,
          ),
      ],
    );
  }

  MockResponse user(MockRequest r) {
    final staff = mockStaff(db, r);
    return MockResponse.json(userDetail(_student(r), staff).toJson());
  }

  static void _checkReason(String reason) {
    if (reason.trim().length < 3 || reason.length > 1000) {
      throw mockValidation('reason', 'Must be 3-1000 characters');
    }
  }

  MockResponse setStatus(MockRequest r) {
    final staff = mockStaff(db, r);
    final a = _student(r);
    final body = mockParse(r, StatusChangeIn.fromJson);
    _checkReason(body.reason);
    if (body.status == AccountStatus.unknown) {
      throw mockValidation('status', 'Input should be a known status');
    }
    a.status = body.status.json;
    mockAudit(db, staff, 'account.status_changed', 'account:${a.id}', {
      'status': body.status.json,
      'reason': body.reason,
    });
    return MockResponse.json(userDetail(a, staff).toJson());
  }

  MockResponse trustPenalty(MockRequest r) {
    final staff = mockStaff(db, r);
    final a = _student(r);
    final body = mockParse(r, PenaltyIn.fromJson);
    _checkReason(body.reason);
    if (body.points < 1 || body.points > 50) {
      throw mockValidation('points', 'Must be 1-50');
    }
    final p = MockTrustPenalty(
      id: db.nextId(),
      accountId: a.id,
      role: body.role,
      points: body.points,
      reason: body.reason,
      by: staff.id,
      at: now,
    );
    db.trustPenalties.add(p);
    mockApplyPenalty(db, p);
    mockAudit(
      db,
      staff,
      'moderation.trust_penalty',
      'account:${a.id}',
      body.toJson(),
    );
    return MockResponse.json(userDetail(a, staff).toJson());
  }

  // ---- listings --------------------------------------------------------------

  MockResponse listings(MockRequest r) {
    mockStaff(db, r);
    final status = r.query['status'] == null
        ? null
        : ListingStatus.fromJson(r.query['status'].toString());
    final q = r.query['q']?.toString().trim().toLowerCase() ?? '';
    final rows =
        db.listings.values
            .where(
              (l) =>
                  (status == null || l.status == status) &&
                  (q.isEmpty || l.title.toLowerCase().contains(q)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final offset = int.tryParse(r.query['cursor']?.toString() ?? '') ?? 0;
    final limit = (int.tryParse(r.query['limit']?.toString() ?? '') ?? 20)
        .clamp(1, 50);
    final page = rows.skip(offset).take(limit).toList();
    return MockResponse.json(
      ListingCardPage(
        items: [for (final l in page) mockListingCard(db, l)],
        nextCursor: rows.length > offset + limit ? '${offset + limit}' : null,
      ).toJson(),
    );
  }

  MockResponse removeListing(MockRequest r) {
    final staff = mockStaff(db, r);
    final l = db.listings[r.pathParams['listing_id']];
    if (l == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Listing not found');
    }
    final reason = mockParse(r, ReasonIn.fromJson).reason;
    _checkReason(reason);
    l
      ..status = ListingStatus.removed
      ..removedReason = reason;
    mockAudit(db, staff, 'moderation.listing_removed', 'listing:${l.id}', {
      'reason': reason,
    });
    return MockResponse.json(mockListingCard(db, l).toJson());
  }
}
