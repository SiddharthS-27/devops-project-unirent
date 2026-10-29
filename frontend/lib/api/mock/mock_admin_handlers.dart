import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_listings.dart';
import 'mock_server.dart';
import 'mock_staff_handlers.dart';

class MockAuditEntry {
  MockAuditEntry({
    required this.id,
    required this.at,
    required this.action,
    this.actorId,
    this.actorRole,
    this.target,
    this.details = const {},
  });

  final int id;
  final DateTime at;
  final String action;
  final String? actorId;
  final String? actorRole;
  final String? target;
  final Map<String, Object?> details;
}

/// Records a staff action in the read-only audit log (backend `audit.record`).
void mockAudit(
  MockDb db,
  MockAccount? actor,
  String action,
  String? target, [
  Map<String, Object?> details = const {},
]) {
  db.auditLog.add(
    MockAuditEntry(
      id: db.auditLog.length + 1,
      at: db.clock().toUtc(),
      action: action,
      actorId: actor?.id,
      actorRole: actor?.role,
      target: target,
      details: details,
    ),
  );
}

class MockReconciliationRun {
  MockReconciliationRun({
    required this.id,
    required this.day,
    required this.triggeredBy,
    required this.startedAt,
    required this.totals,
    this.mismatches = const [],
  }) : finishedAt = startedAt.add(const Duration(seconds: 4));

  final String id;
  final DateTime day;
  final String triggeredBy;
  final DateTime startedAt;
  final DateTime finishedAt;
  final Map<String, Object?> totals;
  final List<MismatchOut> mismatches;
  ReconciliationReportStatus status = ReconciliationReportStatus.done;
}

/// The IST calendar day of [instant], as a UTC midnight date.
DateTime _istDay(DateTime instant) {
  final ist = instant.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(ist.year, ist.month, ist.day);
}

/// Two past nightly runs, one of which found a mismatch, so Reports has
/// something to show.
void seedReconciliation(MockDb db) {
  final now = db.clock().toUtc();
  final today = _istDay(now);
  for (final (n, mismatches) in [
    (1, const <MismatchOut>[]),
    (
      2,
      const [
        MismatchOut(
          kind: 'amount_differs',
          reference: 'pay_MockDemo0002',
          paymentId: '00000000-0000-4000-f000-000000000002',
          ledgerAmountPaise: 40000,
          razorpayAmountPaise: 38000,
          ledgerStatus: 'captured',
          razorpayStatus: 'captured',
        ),
      ],
    ),
  ]) {
    final run = MockReconciliationRun(
      id: '00000000-0000-4000-f100-00000000000$n',
      day: today.subtract(Duration(days: n)),
      triggeredBy: 'nightly',
      startedAt: today
          .subtract(Duration(days: n - 1))
          .subtract(const Duration(hours: 3, minutes: 30)),
      totals: {
        'payments_checked': 6 - n,
        'razorpay_payments': 6 - n,
        'refunds_checked': 1,
        'settlements': 0,
        'settlements_available': false,
        'mismatches': mismatches.length,
      },
      mismatches: mismatches,
    );
    db.reconciliationRuns[run.id] = run;
  }
}

Map<String, MockHandler> adminHandlers(MockDb db) {
  final h = _AdminHandlers(db);
  return {
    'GET /api/v1/admin/metrics': h.metrics,
    'GET /api/v1/admin/audit-log': h.auditLog,
    'GET /api/v1/admin/reconciliation/runs': h.runs,
    'GET /api/v1/admin/reconciliation/runs/{run_id}': h.report,
    'POST /api/v1/admin/reconciliation/run': h.runNow,
    'GET /api/v1/admin/late-fee-rule': h.lateFeeRules,
    'POST /api/v1/admin/late-fee-rule': h.setLateFeeRule,
    'GET /api/v1/admin/moderators': h.moderators,
    'POST /api/v1/admin/moderators': h.createModerator,
    'POST /api/v1/admin/appeals/{appeal_id}/overrule': h.overrule,
  };
}

class _AdminHandlers {
  _AdminHandlers(this.db);

  final MockDb db;

  DateTime get now => db.clock().toUtc();

  MockAccount _admin(MockRequest r) => mockStaff(db, r, adminOnly: true);

  MockResponse metrics(MockRequest r) {
    _admin(r);
    final byState = <String, int>{};
    for (final b in db.bookings.values) {
      byState.update(b.status.json, (n) => n + 1, ifAbsent: () => 1);
    }
    // Finished UPI attempts in the last 30 days that were captured.
    final since = now.subtract(const Duration(days: 30));
    var captured = 0;
    var failed = 0;
    for (final b in db.bookings.values) {
      for (final p in b.payments) {
        if (p.method != PaymentMethod.upi || p.createdAt.isBefore(since)) {
          continue;
        }
        switch (p.status) {
          case PaymentStatus.failed:
            failed++;
          case PaymentStatus.captured ||
              PaymentStatus.refunded ||
              PaymentStatus.partlyRefunded:
            captured++;
          default:
        }
      }
    }
    final total = captured + failed;
    return MockResponse.json(
      MetricsOut(
        activeListings: db.listings.values
            .where((l) => l.status == ListingStatus.active)
            .length,
        bookingsByState: byState,
        paymentSuccessRate: total == 0
            ? null
            : (captured / total * 10000).round() / 10000,
        openDisputes: db.appeals.values
            .where((a) => a.status == AppealStatus.open)
            .length,
        overdueCount: byState['overdue'] ?? 0,
        students: db.profiles.length,
        completedTrades: byState['completed'] ?? 0,
      ).toJson(),
    );
  }

  MockResponse auditLog(MockRequest r) {
    _admin(r);
    final actor = r.query['actor_id']?.toString();
    final target = r.query['target']?.toString();
    final before = int.tryParse(r.query['cursor']?.toString() ?? '');
    final limit = (int.tryParse(r.query['limit']?.toString() ?? '') ?? 50)
        .clamp(1, 200);
    final rows = db.auditLog.reversed
        .where(
          (e) =>
              (actor == null || e.actorId == actor) &&
              (target == null || e.target == target) &&
              (before == null || e.id < before),
        )
        .take(limit)
        .toList();
    return MockResponse.json(
      AuditEntryOutPage(
        items: [
          for (final e in rows)
            AuditEntryOut(
              id: e.id,
              at: e.at,
              actorId: e.actorId,
              actorRole: e.actorRole,
              action: e.action,
              target: e.target,
              details: e.details,
            ),
        ],
        nextCursor: rows.length == limit ? '${rows.last.id}' : null,
      ).toJson(),
    );
  }

  ReconciliationRunOut _runOut(MockReconciliationRun x) => ReconciliationRunOut(
    id: x.id,
    day: x.day,
    triggeredBy: x.triggeredBy,
    status: x.status,
    totals: x.totals,
    startedAt: x.startedAt,
    finishedAt: x.finishedAt,
  );

  ReconciliationReport _report(MockReconciliationRun x) => ReconciliationReport(
    id: x.id,
    day: x.day,
    triggeredBy: x.triggeredBy,
    status: x.status,
    totals: x.totals,
    startedAt: x.startedAt,
    finishedAt: x.finishedAt,
    mismatches: x.mismatches,
  );

  MockResponse runs(MockRequest r) {
    _admin(r);
    final runs = db.reconciliationRuns.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return MockResponse.json([
      for (final x in runs.take(60)) _runOut(x).toJson(),
    ]);
  }

  MockResponse report(MockRequest r) {
    _admin(r);
    final x = db.reconciliationRuns[r.pathParams['run_id']];
    if (x == null) {
      throw const MockApiError(
        404,
        'NOT_FOUND',
        'Reconciliation run not found',
      );
    }
    return MockResponse.json(_report(x).toJson());
  }

  /// Checks the ledger for one IST day. The mock has no Razorpay side, so
  /// it counts that day's payments and finds nothing wrong.
  MockResponse runNow(MockRequest r) {
    final admin = _admin(r);
    final body = mockParse(r, ReconciliationRunIn.fromJson);
    final day = body.day ?? _istDay(now).subtract(const Duration(days: 1));
    var payments = 0;
    var refunds = 0;
    for (final b in db.bookings.values) {
      for (final p in b.payments) {
        if (p.method == PaymentMethod.upi && _istDay(p.createdAt) == day) {
          payments++;
          refunds += p.refunds.length;
        }
      }
    }
    final run = MockReconciliationRun(
      id: db.nextId(),
      day: DateTime.utc(day.year, day.month, day.day),
      triggeredBy: admin.id,
      startedAt: now,
      totals: {
        'payments_checked': payments,
        'razorpay_payments': payments,
        'refunds_checked': refunds,
        'settlements': 0,
        'settlements_available': false,
        'mismatches': 0,
      },
    );
    db.reconciliationRuns[run.id] = run;
    mockAudit(
      db,
      admin,
      'admin.reconciliation_run',
      'reconciliation:${run.id}',
    );
    return MockResponse.json(_report(run).toJson());
  }

  // ---- late-fee rule ----------------------------------------------------------

  List<LateFeeRuleVersion> get _versions => [
    mockSeedLateFeeRule(now),
    ...db.lateFeeRules,
  ];

  MockResponse lateFeeRules(MockRequest r) {
    _admin(r);
    return MockResponse.json([for (final v in _versions.reversed) v.toJson()]);
  }

  MockResponse setLateFeeRule(MockRequest r) {
    final admin = _admin(r);
    final body = mockParse(r, LateFeeRuleIn.fromJson);
    if (body.graceMinutes < 0 || body.graceMinutes > 24 * 60) {
      throw mockValidation('grace_minutes', 'Must be 0-1440');
    }
    if (body.baseFeePaise < 0 || body.baseFeePaise > 1000000) {
      throw mockValidation('base_fee_paise', 'Must be 0-1000000');
    }
    if (body.hourlyPercentBp < 0 || body.hourlyPercentBp > 10000) {
      throw mockValidation('hourly_percent_bp', 'Must be 0-10000');
    }
    final rule = LateFeeRuleVersion(
      id: db.nextId(),
      version: _versions.last.version + 1,
      graceMinutes: body.graceMinutes,
      baseFeePaise: body.baseFeePaise,
      hourlyPercentBp: body.hourlyPercentBp,
      effectiveFrom: now,
    );
    db.lateFeeRules.add(rule);
    mockAudit(
      db,
      admin,
      'admin.late_fee_rule_set',
      'late_fee_rule:${rule.id}',
      body.toJson(),
    );
    return MockResponse(201, rule.toJson());
  }

  // ---- moderators -------------------------------------------------------------

  StaffAccountOut _staffOut(MockAccount a) => StaffAccountOut(
    id: a.id,
    email: a.email,
    name: a.name,
    role: a.role,
    status: a.status,
    createdAt: a.createdAt,
    lastLoginAt: a.lastLoginAt,
  );

  MockResponse moderators(MockRequest r) {
    _admin(r);
    final mods = db.accounts.values.where((a) => a.role == 'moderator').toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return MockResponse.json([for (final a in mods) _staffOut(a).toJson()]);
  }

  MockResponse createModerator(MockRequest r) {
    final admin = _admin(r);
    final body = mockParse(r, ModeratorCreate.fromJson);
    final email = body.email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw mockValidation('email', 'Not a valid email address');
    }
    if (body.name.trim().isEmpty || body.name.length > 200) {
      throw mockValidation('name', 'Must be 1-200 characters');
    }
    if (body.temporaryPassword.isEmpty || body.temporaryPassword.length > 200) {
      throw mockValidation('temporary_password', 'Must be 1-200 characters');
    }
    if (db.accountByEmail(email) != null) {
      throw const MockApiError(
        409,
        'EMAIL_IN_USE',
        'An account with this email already exists',
      );
    }
    final account = db.addAccount(
      MockAccount(
        id: db.nextId(),
        email: email,
        role: 'moderator',
        name: body.name.trim(),
        password: body.temporaryPassword,
        mustChangePassword: true,
        createdAt: now,
      ),
    );
    mockAudit(db, admin, 'admin.moderator_created', 'account:${account.id}');
    return MockResponse(201, _staffOut(account).toJson());
  }

  // ---- overrule -----------------------------------------------------------------

  /// Replaces the latest ruling, reversing what can be reversed (a refund
  /// already paid stays paid), like backend `appeals.overrule`.
  MockResponse overrule(MockRequest r) {
    final admin = _admin(r);
    final staff = MockStaffHandlers(db);
    final appeal = db.appeals[r.pathParams['appeal_id']];
    if (appeal == null) {
      throw const MockApiError(404, 'NOT_FOUND', 'Appeal not found');
    }
    if (appeal.status == AppealStatus.open) {
      throw const MockApiError(
        409,
        'APPEAL_OPEN',
        'There is no ruling to overrule yet',
      );
    }
    final b = db.bookings[appeal.bookingId]!;
    final body = staff.rulingBody(r, b);
    final previous = db.rulings
        .where((x) => x.appealId == appeal.id)
        .fold<MockRuling?>(
          null,
          (last, x) =>
              last == null || !x.ruledAt.isBefore(last.ruledAt) ? x : last,
        );
    if (previous != null) {
      for (final p in db.trustPenalties) {
        if (p.rulingId == previous.id && p.revokedAt == null) {
          p.revokedAt = now;
          mockApplyPenalty(db, p, undo: true);
        }
      }
      final action = previous.body.accountAction;
      if (action != null) db.accounts[action.accountId]?.status = 'active';
      if (previous.body.removeListing) {
        final listing = db.listings[b.listingId];
        if (listing != null && listing.status == ListingStatus.removed) {
          listing
            ..status = ListingStatus.paused
            ..removedReason = null;
        }
      }
    }
    final ruling = MockRuling(
      id: db.nextId(),
      appealId: appeal.id,
      ruledBy: admin.id,
      ruledAt: now,
      body: body,
      overrules: previous?.id,
    );
    staff.apply(b, ruling, admin);
    db.rulings.add(ruling);
    appeal.status = AppealStatus.overruled;
    b.updatedAt = now;
    mockAudit(
      db,
      admin,
      'admin.overrule',
      'appeal:${appeal.id}',
      body.toJson(),
    );
    return MockResponse.json(staff.detail(appeal, admin).toJson());
  }
}
