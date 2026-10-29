import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_handlers.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/app/session.dart';
import 'package:unirent/features/bookings/booking_screen.dart';
import 'package:unirent/features/staff/admin/moderators_screen.dart';
import 'package:unirent/features/staff/users/users_screen.dart';

import '../helpers/test_app.dart';

MeOut meOut({
  String role = 'student',
  bool profile = true,
  bool phone = true,
  bool terms = true,
}) => MeOut(
  account: AccountSummary(
    id: 'a1',
    email: 'x@college.edu',
    role: role,
    status: 'active',
  ),
  profile: null,
  onboarding: Onboarding(
    profileComplete: profile,
    phoneVerified: phone,
    termsAccepted: terms,
    complete: profile && phone && terms,
  ),
  currentTermsVersion: '2026-10',
);

/// Delivers a deep link the way the platform embedding does.
Future<void> openDeepLink(WidgetTester tester, String link) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', {'location': link, 'state': null}),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// The app restored with stored tokens for [email].
Future<TestApp> signedInAs(
  WidgetTester tester,
  String email, {
  MockServer? server,
}) {
  final mock = server ?? MockServer();
  return pumpTestApp(
    tester,
    server: mock,
    storedTokens: tokensFor(mock, email),
  );
}

void main() {
  group('Session.fromMe', () {
    test('picks the first incomplete onboarding step', () {
      expect(
        Session.fromMe(meOut(profile: false, phone: false)).onboardingStep,
        OnboardingStep.profile,
      );
      expect(
        Session.fromMe(meOut(phone: false, terms: false)).onboardingStep,
        OnboardingStep.phone,
      );
      expect(
        Session.fromMe(meOut(terms: false)).onboardingStep,
        OnboardingStep.terms,
      );
      expect(
        Session.fromMe(meOut(), notificationsPending: true).onboardingStep,
        OnboardingStep.notifications,
      );
      expect(Session.fromMe(meOut()).status, SessionStatus.student);
    });

    test('staff roles skip onboarding', () {
      expect(
        Session.fromMe(meOut(role: 'admin', profile: false)).status,
        SessionStatus.admin,
      );
      expect(
        Session.fromMe(meOut(role: 'moderator', profile: false)).status,
        SessionStatus.moderator,
      );
    });
  });

  group('redirectFor', () {
    Uri u(String s) => Uri.parse(s);
    const student = Session(SessionStatus.student);
    const moderator = Session(SessionStatus.moderator);
    const admin = Session(SessionStatus.admin);

    test('restoring holds on the splash and remembers the target', () {
      expect(redirectFor(Session.restoring, u('/')), Routes.splash);
      expect(
        redirectFor(Session.restoring, u('/bookings/42')),
        '/splash?from=%2Fbookings%2F42',
      );
      expect(redirectFor(Session.restoring, u(Routes.splash)), isNull);
    });

    test('resumes the remembered target once signed in', () {
      final splash = u('/splash?from=%2Fbookings%2F42');
      expect(redirectFor(student, splash), '/bookings/42');
      expect(redirectFor(student, u(Routes.splash)), Routes.home);
      // A target the role may not open falls back to its start page.
      expect(redirectFor(moderator, splash), Routes.staffHome);
    });

    test('signed-out users stay on the sign-in screens', () {
      for (final path in [
        Routes.signIn,
        Routes.signInWithEmail,
        Routes.staffSignIn,
      ]) {
        expect(redirectFor(Session.signedOut, u(path)), isNull);
      }
      expect(redirectFor(Session.signedOut, u('/home')), Routes.signIn);
      expect(
        redirectFor(Session.signedOut, u('/staff/appeals')),
        Routes.signIn,
      );
    });

    test('a pending password change is the only way forward', () {
      const session = Session(SessionStatus.passwordChange);
      expect(redirectFor(session, u(Routes.staffPassword)), isNull);
      expect(redirectFor(session, u('/staff/appeals')), Routes.staffPassword);
    });

    test('onboarding pins the user to the current step', () {
      const session = Session(
        SessionStatus.onboarding,
        onboardingStep: OnboardingStep.phone,
      );
      expect(redirectFor(session, u(Routes.onboardingPhone)), isNull);
      expect(
        redirectFor(session, u(Routes.onboardingTerms)),
        Routes.onboardingPhone,
      );
      expect(redirectFor(session, u('/home')), Routes.onboardingPhone);
    });

    test('students land on home and cannot reach staff or auth routes', () {
      expect(redirectFor(student, u('/')), Routes.home);
      expect(redirectFor(student, u(Routes.signIn)), Routes.home);
      expect(redirectFor(student, u(Routes.staffSignIn)), Routes.home);
      expect(redirectFor(student, u(Routes.onboardingPhone)), Routes.home);
      expect(redirectFor(student, u('/staff/appeals')), Routes.home);
      expect(redirectFor(student, u('/bookings/42')), isNull);
    });

    test('staff stay in the staff area; admin sections are admin-only', () {
      expect(redirectFor(moderator, u('/home')), Routes.staffHome);
      expect(redirectFor(moderator, u('/staff/users')), isNull);
      for (final path in [
        '/staff/reports',
        '/staff/late-fee',
        '/staff/moderators',
      ]) {
        expect(redirectFor(moderator, u(path)), Routes.staffHome);
        expect(redirectFor(admin, u(path)), isNull);
      }
    });

    test('custom-scheme deep links map to app paths', () {
      expect(
        deepLinkToLocation(u('unirent://bookings/42')).toString(),
        '/bookings/42',
      );
      expect(deepLinkToLocation(u('/bookings/42')), isNull);
      expect(redirectFor(student, u('unirent://bookings/42')), '/bookings/42');
      expect(
        redirectFor(Session.signedOut, u('unirent://bookings/42')),
        Routes.signIn,
      );
    });
  });

  group('session restore from /me', () {
    testWidgets('no stored tokens: sign-in', (tester) async {
      final app = await pumpTestApp(tester);
      expect(app.location, Routes.signIn);
    });

    testWidgets('onboarded student: home, and push is re-synced', (
      tester,
    ) async {
      final app = await signedInAs(tester, 'asha@college.edu');
      expect(app.location, Routes.home);
      expect(app.session.me?.profile?.fullName, 'Asha Verma');
      expect(app.push.syncCalls, 1);
    });

    testWidgets('student without a profile: the profile step', (tester) async {
      final server = MockServer();
      addStudent(server, 'new@college.edu');
      final app = await signedInAs(tester, 'new@college.edu', server: server);
      expect(app.location, Routes.onboardingProfile);
    });

    testWidgets('profile but no phone: the phone step', (tester) async {
      final server = MockServer();
      final account = addStudent(server, 'nophone@college.edu');
      server.db.profiles[account.id] = server.db.profiles.values.first;
      final app = await signedInAs(
        tester,
        'nophone@college.edu',
        server: server,
      );
      expect(app.location, Routes.onboardingPhone);
    });

    testWidgets('admin: staff console', (tester) async {
      final app = await signedInAs(tester, 'admin@unirent.in');
      expect(app.location, Routes.staffHome);
    });

    testWidgets('expired access token is refreshed transparently', (
      tester,
    ) async {
      final server = MockServer();
      final tokens = tokensFor(server, 'asha@college.edu');
      server.db.expireAccessTokens();
      final app = await pumpTestApp(
        tester,
        server: server,
        storedTokens: tokens,
      );
      expect(app.location, Routes.home);
      expect(server.db.refreshCount, 1);
    });

    testWidgets('invalid stored tokens: sign-in and tokens cleared', (
      tester,
    ) async {
      final app = await pumpTestApp(
        tester,
        storedTokens: const AuthTokens(
          accessToken: 'stale-access',
          refreshToken: 'stale-refresh',
        ),
      );
      expect(app.location, Routes.signIn);
      expect(await app.tokens.read(), isNull);
    });

    testWidgets('unreachable server: retryable splash', (tester) async {
      final server = MockServer();
      final tokens = tokensFor(server, 'asha@college.edu');
      final getMe = mockHandlers(server.db)['GET /api/v1/me']!;
      var offline = true;
      server.on(
        'GET /api/v1/me',
        (request) => offline ? MockResponse.offline : getMe(request),
      );
      final app = await pumpTestApp(
        tester,
        server: server,
        storedTokens: tokens,
      );
      expect(app.location, startsWith(Routes.splash));
      expect(find.text('Couldn’t sign you in'), findsOneWidget);
      expect(await app.tokens.read(), isNotNull);

      offline = false;
      await app.tapText('Try again');
      expect(app.location, Routes.home);
    });
  });

  group('student shell', () {
    testWidgets('shows four tabs and switches between them', (tester) async {
      final app = await signedInAs(tester, 'asha@college.edu');

      expect(find.byType(NavigationDestination), findsNWidgets(4));
      for (final label in ['Home', 'Bookings', 'Listings', 'Profile']) {
        expect(
          find.widgetWithText(NavigationDestination, label),
          findsOneWidget,
        );
      }
      await app.tap(find.widgetWithText(NavigationDestination, 'Listings'));
      expect(app.location, Routes.listings);
      await app.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      expect(app.location, Routes.profile);
      expect(find.text('Asha Verma'), findsOneWidget);
    });

    testWidgets('booking screen opens from Listings and pops back', (
      tester,
    ) async {
      final app = await signedInAs(tester, 'asha@college.edu');
      await app.tap(find.widgetWithText(NavigationDestination, 'Listings'));
      expect(app.location, Routes.listings);
      // Owners reach bookings from their listings (wired up with bookings).
      unawaited(app.router.push(Routes.booking('sample')));
      await tester.pumpAndSettle();
      expect(app.location, '/bookings/sample');
      expect(find.byType(BookingScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(app.location, Routes.listings);
    });

    testWidgets('booking screen opens from the Bookings tab', (tester) async {
      final app = await signedInAs(tester, 'asha@college.edu');
      await app.tap(find.widgetWithText(NavigationDestination, 'Bookings'));
      await app.tapText('Lending & selling');
      await app.tap(find.widgetWithText(Tab, 'Pending'));
      await app.tap(find.text('Hercules 21-gear mountain bike').first);
      expect(app.location, startsWith('/bookings/'));
      expect(find.text('Approve or decline the request'), findsOneWidget);
    });

    testWidgets('unirent://bookings/{id} deep link opens the booking', (
      tester,
    ) async {
      final app = await signedInAs(tester, 'asha@college.edu');
      const id = '00000000-0000-4000-d000-000000000001'; // seeded request
      await openDeepLink(tester, 'unirent://bookings/$id');
      expect(app.location, '/bookings/$id');
      expect(find.text('Approve or decline the request'), findsOneWidget);
    });

    testWidgets('sign out revokes tokens, push and returns to sign-in', (
      tester,
    ) async {
      final server = MockServer();
      final app = await signedInAs(tester, 'asha@college.edu', server: server);
      final refresh = (await app.tokens.read())!.refreshToken;

      await app.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await app.tapText('Sign out');

      expect(app.location, Routes.signIn);
      expect(await app.tokens.read(), isNull);
      expect(app.push.unregisterCalls, 1);
      expect(server.db.refreshTokens, isNot(contains(refresh)));
    });
  });

  group('staff shell', () {
    const moderatorTabs = [
      'Appeals',
      'Support',
      'Escalations',
      'Users',
      'Listings',
    ];

    testWidgets('admin sees all eight tabs', (tester) async {
      await signedInAs(tester, 'admin@unirent.in');
      expect(find.byType(Tab), findsNWidgets(8));
      for (final label in [
        ...moderatorTabs,
        'Reports',
        'Late-fee rule',
        'Moderators',
      ]) {
        expect(find.widgetWithText(Tab, label), findsOneWidget);
      }
    });

    testWidgets('moderator sees five tabs and no admin sections', (
      tester,
    ) async {
      final server = MockServer();
      server.db.accountByEmail('moderator@unirent.in')!.mustChangePassword =
          false;
      final app = await signedInAs(
        tester,
        'moderator@unirent.in',
        server: server,
      );
      expect(find.byType(Tab), findsNWidgets(5));
      for (final label in moderatorTabs) {
        expect(find.widgetWithText(Tab, label), findsOneWidget);
      }
      app.router.go('/staff/reports');
      await tester.pumpAndSettle();
      expect(app.location, Routes.staffHome);
    });

    testWidgets('tapping a tab switches section; sign out works', (
      tester,
    ) async {
      final app = await signedInAs(tester, 'admin@unirent.in');
      await app.tap(find.widgetWithText(Tab, 'Users'));
      expect(app.location, '/staff/users');
      expect(find.byType(UsersScreen), findsOneWidget);
      await app.tap(find.widgetWithText(Tab, 'Moderators'));
      expect(app.location, '/staff/moderators');
      expect(find.byType(ModeratorsScreen), findsOneWidget);
      await app.tap(find.byTooltip('Sign out'));
      expect(app.location, Routes.signIn);
    });
  });
}
