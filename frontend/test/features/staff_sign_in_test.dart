import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/auth/staff_password_screen.dart';

import '../helpers/test_app.dart';

Future<void> staffSignIn(TestApp app, String email, String password) async {
  await app.tapText('Staff sign in');
  expect(app.location, Routes.staffSignIn);
  await app.enterField('Email', email);
  await app.enterField('Password', password);
  await app.tap(find.widgetWithText(FilledButton, 'Sign in'));
}

void main() {
  testWidgets('a new moderator must replace the temporary password', (
    tester,
  ) async {
    final app = await pumpTestApp(tester);
    await staffSignIn(app, 'moderator@unirent.in', 'temporary-password');
    expect(app.location, Routes.staffPassword);

    await app.enterField('New password', 'short');
    await app.enterField('Confirm new password', 'short');
    await app.tapText('Save password');
    expect(find.text('Use at least 10 characters'), findsOneWidget);

    await app.enterField('New password', 'a-long-new-passphrase');
    await app.enterField('Confirm new password', 'a-different-passphrase');
    await app.tapText('Save password');
    expect(find.text('The passwords don’t match'), findsOneWidget);

    await app.enterField('Confirm new password', 'a-long-new-passphrase');
    await app.tapText('Save password');
    expect(app.location, Routes.staffHome);
    expect(find.byType(Tab), findsNWidgets(5));

    final moderator = app.server.db.accountByEmail('moderator@unirent.in')!;
    expect(moderator.mustChangePassword, isFalse);
    expect(moderator.password, 'a-long-new-passphrase');
  });

  testWidgets('cancelling the password change signs out', (tester) async {
    final app = await pumpTestApp(tester);
    await staffSignIn(app, 'moderator@unirent.in', 'temporary-password');
    await app.tap(find.byType(CloseButton));
    expect(app.location, Routes.signIn);
  });

  testWidgets('an admin lands on the staff console with eight tabs', (
    tester,
  ) async {
    final app = await pumpTestApp(tester);
    await staffSignIn(app, 'admin@unirent.in', 'admin-password');
    expect(app.location, Routes.staffHome);
    expect(find.byType(Tab), findsNWidgets(8));
  });

  testWidgets('wrong credentials show an error', (tester) async {
    final app = await pumpTestApp(tester);
    await staffSignIn(app, 'admin@unirent.in', 'wrong-password');
    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(app.location, Routes.staffSignIn);
  });

  test('staff password rules mirror the backend', () {
    const email = 'moderator@unirent.in';
    expect(validateStaffPassword('short', email: email), isNotNull);
    expect(validateStaffPassword('moderator@unirent', email: email), isNotNull);
    expect(
      validateStaffPassword('correct-horse-battery', email: email),
      isNull,
    );
  });
}
