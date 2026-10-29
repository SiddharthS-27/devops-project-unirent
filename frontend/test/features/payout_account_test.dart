import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/payouts/payout_validation.dart';

import '../helpers/test_app.dart';

const karan = 'karan@college.edu'; // no payout account yet

Future<TestApp> openPayoutFromProfile(
  WidgetTester tester, {
  String email = karan,
  MockServer? server,
}) async {
  final app = await pumpSignedIn(tester, email, server: server);
  await app.tap(find.widgetWithText(NavigationDestination, 'Profile'));
  await app.tapText('Payout account');
  expect(app.location, Routes.payoutAccount);
  return app;
}

String fieldText(String label) => find
    .widgetWithText(TextFormField, label)
    .evaluate()
    .map((e) => (e.widget as TextFormField).controller!.text)
    .single;

void main() {
  testWidgets('link an account, then follow it to activation', (tester) async {
    final server = MockServer();
    final app = await openPayoutFromProfile(tester, server: server);

    expect(find.text('How payouts work'), findsOneWidget);
    expect(find.textContaining('aren’t stored by UniRent'), findsOneWidget);
    // Known details are prefilled; bank details are not.
    expect(fieldText('Email'), karan);
    expect(fieldText('Mobile number'), '9876500002');
    expect(fieldText('Legal name'), 'Karan Mehta');
    expect(fieldText('Bank account number'), isEmpty);

    await app.enterField('Bank account number', '12345');
    await app.enterField('Confirm account number', '12346');
    await app.enterField('IFSC', 'sbin123');
    await app.tapText('Link account');
    expect(find.text('Account numbers have 9 to 18 digits'), findsOneWidget);
    expect(find.text('The account numbers don’t match'), findsOneWidget);
    expect(find.text('Enter a valid IFSC, e.g. SBIN0001234'), findsOneWidget);
    expect(fieldText('IFSC'), 'SBIN123', reason: 'typed in upper case');

    await app.enterField('Bank account number', '001234567890');
    await app.enterField('Confirm account number', '001234567890');
    await app.enterField('IFSC', 'HDFC0001234');
    await app.tapText('Link account');

    final account = server.db.accountByEmail(karan)!;
    expect(account.payoutStatus, PayoutAccountOutStatus.created);
    expect(find.text('Submitted to Razorpay'), findsOneWidget);
    expect(find.text('Link your bank account'), findsNothing);

    await app.tapText('Check status');
    expect(find.text('Under review'), findsOneWidget);
    await app.tapText('Check status');
    expect(find.text('Ready to receive payments'), findsOneWidget);
    expect(find.text('Check status'), findsNothing);
    expect(account.payoutReady, isTrue);

    // Listing is unlocked now.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await app.tap(find.widgetWithText(NavigationDestination, 'Listings'));
    await app.tapText('Add listing');
    expect(app.location, Routes.newListing);
  });

  testWidgets('an activated account shows its status, no form', (tester) async {
    await openPayoutFromProfile(tester, email: 'asha@college.edu');
    expect(find.text('Ready to receive payments'), findsOneWidget);
    expect(find.textContaining('acc_MockAsha0001'), findsOneWidget);
    expect(find.text('Link your bank account'), findsNothing);
  });

  testWidgets('a suspended account explains and allows relinking', (
    tester,
  ) async {
    final server = MockServer();
    server.db.accountByEmail(karan)!
      ..payoutStatus = PayoutAccountOutStatus.suspended
      ..razorpayAccountId = 'acc_Old';
    await openPayoutFromProfile(tester, server: server);
    expect(find.text('Payouts suspended'), findsOneWidget);
    expect(find.text('Link your bank account'), findsOneWidget);
  });

  test('payout validators mirror the backend', () {
    expect(PayoutValidators.ifsc('SBIN0001234'), isNull);
    expect(PayoutValidators.ifsc('SBIN1001234'), isNotNull); // 5th must be 0
    expect(PayoutValidators.ifsc('sbin0001234'), isNotNull);
    expect(PayoutValidators.accountNumber('12345678'), isNotNull);
    expect(PayoutValidators.accountNumber('123456789'), isNull);
    expect(PayoutValidators.accountNumber('1' * 19), isNotNull);
    expect(PayoutValidators.mobile('5876543210'), isNotNull);
    expect(PayoutValidators.mobile('9876543210'), isNull);
    expect(PayoutValidators.name('A', 'x'), isNotNull);
    expect(PayoutValidators.email('a@b.co'), isNull);
  });
}
