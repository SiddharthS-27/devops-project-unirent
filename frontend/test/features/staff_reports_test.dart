import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/staff/staff_tab.dart';

import '../helpers/test_app.dart';

const admin = 'admin@unirent.in';
const moderator = 'moderator@unirent.in';

Future<TestApp> asAdmin(WidgetTester tester, MockServer server) async {
  final app = await pumpSignedIn(tester, admin, server: server);
  app.router.go(StaffTab.reports.path);
  await tester.pumpAndSettle();
  return app;
}

void addUpi(MockServer server, PaymentStatus status, String id) {
  final b = server.db.bookings.values.first;
  b.payments.add(
    MockPayment(
      id: id,
      bookingId: b.id,
      purpose: PaymentPurpose.rent,
      method: PaymentMethod.upi,
      amountPaise: 10000,
      items: const [],
      createdAt: DateTime.now().toUtc(),
      payerId: b.renterId,
      payeeId: b.ownerId,
    )..status = status,
  );
}

void main() {
  testWidgets('metrics include the UPI success rate', (tester) async {
    final server = MockServer();
    for (var i = 0; i < 3; i++) {
      addUpi(server, PaymentStatus.captured, 'ok-$i');
    }
    addUpi(server, PaymentStatus.failed, 'bad');
    addUpi(server, PaymentStatus.created, 'unfinished');
    await asAdmin(tester, server);

    expect(find.bySemanticsLabel('UPI success rate: 75%'), findsOneWidget);
    expect(find.bySemanticsLabel('Students: 4'), findsOneWidget);
    expect(find.text('Bookings by state'), findsOneWidget);
    expect(find.text('Requested'), findsOneWidget);
  });

  testWidgets('reconciliation runs, mismatches and running one now', (
    tester,
  ) async {
    final server = MockServer();
    final app = await asAdmin(tester, server);
    await app.tapText('Reconciliation');
    expect(find.textContaining('1 mismatch'), findsOneWidget);
    expect(find.textContaining('0 mismatches'), findsOneWidget);

    await app.tap(find.textContaining('1 mismatch'));
    expect(find.text('Amounts differ'), findsOneWidget);
    expect(find.text('pay_MockDemo0002'), findsOneWidget);
    expect(find.text('Ledger: ₹400, captured'), findsOneWidget);
    expect(find.text('Razorpay: ₹380, captured'), findsOneWidget);
    await app.tap(find.byType(BackButton));

    await app.tapText('Run reconciliation now');
    await app.tapText('OK');
    expect(app.location, startsWith('/staff/reports/runs/'));
    expect(find.text('None: the ledger agrees with Razorpay.'), findsOneWidget);
    expect(server.db.reconciliationRuns, hasLength(3));
    expect(server.db.auditLog.last.action, 'admin.reconciliation_run');
  });

  testWidgets('the audit log lists staff actions, newest first', (
    tester,
  ) async {
    final server = MockServer();
    server.db.accountByEmail(moderator)!.mustChangePassword = false;
    // A moderator removes a listing.
    final mod = await pumpSignedIn(tester, moderator, server: server);
    final listing = server.db.listings.values.first;
    await tester.runAsync(
      () => mod.container
          .read(apiProvider)
          .staff
          .removeListing(listing.id, const ReasonIn(reason: 'Spam listing')),
    );

    final app = await asAdmin(tester, server);
    await app.tapText('Audit log');
    expect(find.text('Removed a listing'), findsOneWidget);
    expect(find.textContaining('reason: Spam listing'), findsOneWidget);
    expect(find.textContaining('listing:${listing.id}'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'listing:nothing');
    await app.tap(find.byTooltip('Filter'));
    expect(find.text('No audit entries'), findsOneWidget);
  });

  testWidgets('moderators can’t open Reports', (tester) async {
    final server = MockServer();
    server.db.accountByEmail(moderator)!.mustChangePassword = false;
    final app = await pumpSignedIn(tester, moderator, server: server);
    app.router.go(Routes.staffReports);
    await tester.pumpAndSettle();
    expect(app.location, Routes.staffHome);
  });
}
