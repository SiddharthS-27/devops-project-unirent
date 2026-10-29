import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_db.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/onboarding/phone_screen.dart';
import 'package:unirent/features/onboarding/profile_validation.dart';

import '../helpers/test_app.dart';

Future<void> signInWithEmail(TestApp app, String email) async {
  await app.tapText('Continue with college Microsoft account');
  expect(app.location, Routes.signInWithEmail);
  await app.enterField('College email', email);
  await app.tapText('Continue');
}

Future<void> fillHostelProfile(TestApp app) async {
  await app.enterField('Full name', 'Ravi Kumar');
  await app.enterField('Roll number', '22EE0007');
  await app.enterField('Department', 'Electrical');
  await app.tap(find.byType(DropdownButtonFormField<int>));
  await app.tapText('Year 2');
  await app.enterField('Hostel name', 'Kaveri');
  await app.enterField('Room number', 'A-101');
}

Future<void> verifyPhone(TestApp app, String number) async {
  await app.enterField('Mobile number', number);
  await app.tapText('Send code');
  await app.enterOtp(mockOtpCode);
}

void main() {
  testWidgets('a new student onboards from sign-in to home', (tester) async {
    final app = await pumpTestApp(tester);
    expect(app.location, Routes.signIn);

    await signInWithEmail(app, 'ravi@college.edu');
    expect(app.location, Routes.onboardingProfile);
    expect(find.text('Add photo (optional)'), findsOneWidget);

    await fillHostelProfile(app);
    await app.tapText('Save and continue');
    expect(app.location, Routes.onboardingPhone);

    await app.enterField('Mobile number', '9800000001');
    await app.tapText('Send code');
    expect(find.textContaining('+919800000001'), findsOneWidget);

    await app.enterOtp('000000');
    expect(
      find.text('That code isn’t right. Check the SMS and try again.'),
      findsOneWidget,
    );
    expect(app.location, Routes.onboardingPhone);

    await app.enterOtp(mockOtpCode);
    expect(app.location, Routes.onboardingTerms);

    await app.tap(find.byType(CheckboxListTile));
    await app.tapText('Accept and continue');
    expect(app.location, Routes.onboardingNotifications);
    expect(find.textContaining('aren’t configured'), findsOneWidget);

    await app.tapText('Continue');
    expect(app.location, Routes.home);

    final account = app.server.db.accountByEmail('ravi@college.edu')!;
    final profile = app.server.db.profiles[account.id]!;
    expect(profile.data.fullName, 'Ravi Kumar');
    expect(profile.data.year, 2);
    expect(profile.data.residenceType, ResidenceType.hostel);
    expect(profile.termsVersion, mockTermsVersion);
    expect(account.phone, '+919800000001');
  });

  testWidgets('notifications step registers push when available', (
    tester,
  ) async {
    final push = FakePushService(isAvailable: true);
    final server = MockServer();
    final account = addStudent(server, 'push@college.edu');
    final app = await pumpTestApp(
      tester,
      server: server,
      push: push,
      storedTokens: tokensFor(server, account.email),
    );

    await fillHostelProfile(app);
    await app.tapText('Save and continue');
    await verifyPhone(app, '9800000002');
    await app.tap(find.byType(CheckboxListTile));
    await app.tapText('Accept and continue');

    await app.tapText('Turn on notifications');
    expect(push.enableCalls, 1);
    expect(app.location, Routes.home);
  });

  testWidgets('profile form validates like the backend', (tester) async {
    final server = MockServer();
    final account = addStudent(server, 'form@college.edu');
    final app = await pumpTestApp(
      tester,
      server: server,
      storedTokens: tokensFor(server, account.email),
    );
    expect(app.location, Routes.onboardingProfile);

    await app.tapText('Save and continue');
    for (final message in [
      'Enter your full name',
      'Enter your roll number',
      'Enter your department',
      'Select your year (1-6)',
      'Enter your hostel name',
      'Enter your room number',
    ]) {
      expect(find.text(message), findsOneWidget, reason: message);
    }

    await app.enterField('Full name', 'R');
    await app.tap(find.text('Day scholar'));
    await app.tapText('Save and continue');
    expect(find.text('Enter at least 2 characters'), findsOneWidget);
    expect(find.text('Enter your home address'), findsOneWidget);
    expect(find.text('Enter your hostel name'), findsNothing);

    expect(server.db.profiles[account.id], isNull);
    expect(app.location, Routes.onboardingProfile);
  });

  testWidgets('a number owned by someone else gets a friendly error', (
    tester,
  ) async {
    final server = MockServer();
    final account = addStudent(server, 'dup@college.edu');
    final app = await pumpTestApp(
      tester,
      server: server,
      storedTokens: tokensFor(server, account.email),
    );
    await fillHostelProfile(app);
    await app.tapText('Save and continue');

    // The seeded student already owns this number.
    await verifyPhone(app, '9876500001');
    expect(find.textContaining('already linked'), findsOneWidget);
    expect(app.location, Routes.onboardingPhone);
  });

  testWidgets('rejects emails outside the college domain', (tester) async {
    final app = await pumpTestApp(tester);
    await signInWithEmail(app, 'someone@gmail.com');
    expect(find.textContaining('Use your college email'), findsOneWidget);
    expect(app.location, Routes.signInWithEmail);
  });

  group('validators', () {
    test('profile fields', () {
      expect(ProfileValidators.fullName('  '), 'Enter your full name');
      expect(ProfileValidators.fullName('A'), 'Enter at least 2 characters');
      expect(ProfileValidators.fullName('Al'), isNull);
      expect(ProfileValidators.fullName('x' * 201), contains('200'));
      expect(ProfileValidators.rollNumber('x' * 51), contains('50'));
      expect(ProfileValidators.year(0), isNotNull);
      expect(ProfileValidators.year(7), isNotNull);
      expect(ProfileValidators.year(6), isNull);
      expect(ProfileValidators.roomNumber('x' * 21), contains('20'));
      expect(ProfileValidators.homeAddress('x' * 501), contains('500'));
    });

    test('Indian mobile numbers', () {
      expect(validateIndianMobile('9876543210'), isNull);
      expect(validateIndianMobile('5876543210'), isNotNull);
      expect(validateIndianMobile('987654321'), isNotNull);
    });
  });
}
