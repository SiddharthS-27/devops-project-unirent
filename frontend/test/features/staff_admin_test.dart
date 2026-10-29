import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/staff/staff_tab.dart';

import '../helpers/test_app.dart';
import 'staff_appeals_test.dart' show asModerator, confirm, dslrAppeal;

const admin = 'admin@unirent.in';

Future<TestApp> asAdmin(
  WidgetTester tester,
  MockServer server,
  String location,
) async {
  final app = await pumpSignedIn(tester, admin, server: server);
  app.router.go(location);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('late-fee rule: current, history and a new version', (
    tester,
  ) async {
    final server = MockServer();
    final app = await asAdmin(tester, server, StaffTab.lateFeeRule.path);
    expect(find.text('In force: version 1'), findsOneWidget);
    expect(
      find.text(
        '30-minute grace period, then ₹50 plus 2% of the rent for every '
        'further hour.',
      ),
      findsWidgets,
    );

    await app.tapText('Set a new version');
    await app.enterField('Grace period', '60');
    await app.enterField('Base fee', '100');
    await app.enterField('Hourly charge', '');
    await confirm(app, 'Put in force');
    expect(find.text('Enter a percentage from 0 to 100'), findsOneWidget);
    await app.enterField('Hourly charge', '2.5');
    await confirm(app, 'Put in force');

    expect(find.text('Version 2 is now in force.'), findsOneWidget);
    expect(find.text('In force: version 2'), findsOneWidget);
    const v2 =
        '60-minute grace period, then ₹100 plus 2.5% of the rent for every '
        'further hour.';
    expect(find.text(v2), findsNWidgets(2)); // current card and history
    expect(find.byType(CircleAvatar), findsNWidgets(2));
    final rule = mockLateFeeRule(DateTime.now().toUtc(), server.db);
    expect(rule.graceMinutes, 60);
    expect(rule.hourlyPercentBp, 250);
    expect(server.db.auditLog.last.action, 'admin.late_fee_rule_set');
  });

  testWidgets('moderators: list and add one', (tester) async {
    final server = MockServer();
    final app = await asAdmin(tester, server, StaffTab.moderators.path);
    expect(find.text('Campus Moderator'), findsOneWidget);

    await app.tapText('Add moderator');
    await confirm(app, 'Add');
    expect(find.text('Enter their name'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await app.enterField('Name', 'Ravi Kumar');
    await app.enterField('Email', 'moderator@unirent.in');
    await app.enterField('Temporary password', 'welcome-ravi-1');
    await confirm(app, 'Add');
    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );

    await app.enterField('Email', 'ravi@unirent.in');
    await confirm(app, 'Add');
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.textContaining('Never signed in'), findsWidgets);
    final ravi = server.db.accountByEmail('ravi@unirent.in')!;
    expect(ravi.role, 'moderator');
    expect(ravi.mustChangePassword, isTrue);
    expect(ravi.password, 'welcome-ravi-1');
  });

  testWidgets('the admin overrules a ruling; its effects are reversed', (
    tester,
  ) async {
    final server = MockServer();
    final (b, appeal) = dslrAppeal(server);
    final dev = server.db.accountByEmail('dev@college.edu')!;
    final devTrust = dev.lenderScore!;

    // A moderator penalises and bans Dev.
    var app = await asModerator(tester, server);
    app.router.go(Routes.staffAppealRule(appeal.id));
    await tester.pumpAndSettle();
    await app.enterField('Summary', 'The owner caused the damage.');
    await app.tapText('Trust penalty');
    await app.tapText('Dev Patel (owner)');
    await app.enterField('Points', '10');
    await app.tapText('Remove the listing');
    await app.tapText('Suspend or ban an account');
    await app.tapText('Dev Patel (owner)');
    await app.tapText('Ban');
    await app.tapText('Send ruling');
    await confirm(app, 'Send ruling');
    expect(dev.status, 'banned');
    expect(dev.lenderScore, devTrust - 10);
    expect(server.db.listings[b.listingId]!.status, ListingStatus.removed);
    // Moderators can't overrule.
    expect(find.text('Overrule this ruling'), findsNothing);

    app = await asAdmin(tester, server, Routes.staffAppeal(appeal.id));
    await app.tapText('Overrule this ruling');
    expect(app.location, Routes.staffAppealOverrule(appeal.id));
    expect(
      find.textContaining('This replaces the latest ruling'),
      findsOneWidget,
    );
    await app.enterField('Summary', 'Photos show normal wear; refund ₹100.');
    await app.enterField('Refund to the renter', '100');
    await app.tapText('Send ruling');
    expect(find.text('Replace the ruling?'), findsOneWidget);
    await confirm(app, 'Send ruling');

    expect(find.text('New ruling sent to both sides.'), findsOneWidget);
    expect(app.location, Routes.staffAppeal(appeal.id));
    expect(find.textContaining('Overruling by the admin'), findsOneWidget);
    expect(find.text('Overruled'), findsOneWidget);
    expect(appeal.status, AppealStatus.overruled);
    expect(dev.status, 'active');
    expect(dev.lenderScore, devTrust);
    expect(server.db.listings[b.listingId]!.status, ListingStatus.paused);
    expect(b.payments.single.refunds.single.amountPaise, 10000);
    expect(server.db.rulings.last.overrules, server.db.rulings.first.id);
    expect(server.db.auditLog.last.action, 'admin.overrule');
  });
}
