import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
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
}
