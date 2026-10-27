import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unirent/app/app.dart';
import 'package:unirent/app/router.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/app/session.dart';
import 'package:unirent/features/bookings/booking_screen.dart';
import 'package:unirent/features/staff/staff_section_screen.dart';
import 'package:unirent/features/staff/staff_tab.dart';

/// Pumps the full app with [session] and returns its container and router.
Future<(ProviderContainer, GoRouter)> pumpApp(
  WidgetTester tester, {
  SessionStatus session = SessionStatus.signedOut,
}) async {
  await tester.pumpWidget(const ProviderScope(child: UniRentApp()));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(UniRentApp)),
  );
  container.read(sessionProvider.notifier).set(session);
  await tester.pumpAndSettle();
  return (container, container.read(routerProvider));
}

/// Location of the top-most route, including pushed routes.
String location(GoRouter router) => router.state.uri.toString();

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

void main() {
  group('redirectFor', () {
    Uri u(String s) => Uri.parse(s);

    test('signed-out users can only reach sign-in', () {
      const s = SessionStatus.signedOut;
      expect(redirectFor(s, u('/')), Routes.signIn);
      expect(redirectFor(s, u('/home')), Routes.signIn);
      expect(redirectFor(s, u('/staff/appeals')), Routes.signIn);
      expect(redirectFor(s, u(Routes.signIn)), isNull);
    });

    test('onboarding users stay in onboarding', () {
      const s = SessionStatus.onboarding;
      expect(redirectFor(s, u(Routes.signIn)), Routes.onboardingProfile);
      expect(redirectFor(s, u('/home')), Routes.onboardingProfile);
      expect(redirectFor(s, u(Routes.onboardingTerms)), isNull);
    });

    test('students land on home and cannot reach staff routes', () {
      const s = SessionStatus.student;
      expect(redirectFor(s, u('/')), Routes.home);
      expect(redirectFor(s, u(Routes.signIn)), Routes.home);
      expect(redirectFor(s, u(Routes.onboardingPhone)), Routes.home);
      expect(redirectFor(s, u('/staff/appeals')), Routes.home);
      expect(redirectFor(s, u('/bookings/42')), isNull);
      expect(redirectFor(s, u('/listings')), isNull);
    });

    test('staff land on appeals and stay in the staff area', () {
      for (final s in [SessionStatus.moderator, SessionStatus.admin]) {
        expect(redirectFor(s, u('/')), '/staff/appeals');
        expect(redirectFor(s, u('/home')), '/staff/appeals');
        expect(redirectFor(s, u('/staff/users')), isNull);
      }
    });

    test('admin-only staff routes are closed to moderators', () {
      for (final path in [
        '/staff/reports',
        '/staff/late-fee',
        '/staff/moderators',
      ]) {
        expect(redirectFor(SessionStatus.moderator, u(path)), '/staff/appeals');
        expect(redirectFor(SessionStatus.admin, u(path)), isNull);
      }
    });

    test('custom-scheme deep links map to app paths', () {
      expect(
        deepLinkToLocation(u('unirent://bookings/42')).toString(),
        '/bookings/42',
      );
      expect(deepLinkToLocation(u('/bookings/42')), isNull);
      expect(
        redirectFor(SessionStatus.student, u('unirent://bookings/42')),
        '/bookings/42',
      );
      expect(
        redirectFor(SessionStatus.signedOut, u('unirent://bookings/42')),
        Routes.signIn,
      );
    });
  });

  group('router', () {
    testWidgets('signed-out users see sign-in', (tester) async {
      final (_, router) = await pumpApp(tester);
      expect(location(router), Routes.signIn);
      expect(find.text('Welcome to UniRent'), findsOneWidget);
    });

    testWidgets('debug role switcher routes each role to its start page', (
      tester,
    ) async {
      final (container, router) = await pumpApp(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'student'));
      await tester.pumpAndSettle();
      expect(location(router), Routes.home);

      container.read(sessionProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(location(router), Routes.signIn);

      await tester.tap(find.widgetWithText(OutlinedButton, 'moderator'));
      await tester.pumpAndSettle();
      expect(location(router), '/staff/appeals');

      container.read(sessionProvider.notifier).set(SessionStatus.admin);
      await tester.pumpAndSettle();
      expect(location(router), '/staff/appeals');
    });

    testWidgets('onboarding walks through every step to home', (tester) async {
      final (_, router) = await pumpApp(tester);

      await tester.tap(find.text('Continue with college account'));
      await tester.pumpAndSettle();
      expect(location(router), Routes.onboardingProfile);

      for (final (button, next) in [
        ('Continue', Routes.onboardingPhone),
        ('Continue', Routes.onboardingTerms),
        ('Accept', Routes.onboardingNotifications),
        ('Finish', Routes.home),
      ]) {
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(location(router), next);
      }
    });

    testWidgets('student shell shows four tabs and switches between them', (
      tester,
    ) async {
      final (_, router) = await pumpApp(tester, session: SessionStatus.student);

      expect(find.byType(NavigationDestination), findsNWidgets(4));
      for (final label in ['Home', 'Bookings', 'Listings', 'Profile']) {
        expect(
          find.widgetWithText(NavigationDestination, label),
          findsOneWidget,
        );
      }

      await tester.tap(find.widgetWithText(NavigationDestination, 'Listings'));
      await tester.pumpAndSettle();
      expect(location(router), Routes.listings);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      expect(location(router), Routes.profile);
    });

    testWidgets('booking screen opens from Listings and pops back to it', (
      tester,
    ) async {
      final (_, router) = await pumpApp(tester, session: SessionStatus.student);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Listings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sample booking'));
      await tester.pumpAndSettle();
      expect(location(router), '/bookings/sample');
      expect(find.byType(BookingScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(location(router), Routes.listings);
    });

    testWidgets('booking screen opens from Bookings too', (tester) async {
      final (_, router) = await pumpApp(tester, session: SessionStatus.student);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Bookings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sample booking'));
      await tester.pumpAndSettle();
      expect(location(router), '/bookings/sample');
      expect(find.text('Booking sample'), findsOneWidget);
    });

    testWidgets('unirent://bookings/{id} deep link opens the booking', (
      tester,
    ) async {
      final (_, router) = await pumpApp(tester, session: SessionStatus.student);

      await openDeepLink(tester, 'unirent://bookings/42');
      expect(location(router), '/bookings/42');
      expect(find.text('Booking 42'), findsOneWidget);
    });

    testWidgets('signing out from Profile returns to sign-in', (tester) async {
      final (_, router) = await pumpApp(tester, session: SessionStatus.student);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(location(router), Routes.signIn);
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
    const adminTabs = [
      ...moderatorTabs,
      'Reports',
      'Late-fee rule',
      'Moderators',
    ];

    testWidgets('admin sees all eight tabs', (tester) async {
      await pumpApp(tester, session: SessionStatus.admin);

      expect(find.byType(Tab), findsNWidgets(8));
      for (final label in adminTabs) {
        expect(find.widgetWithText(Tab, label), findsOneWidget);
      }
    });

    testWidgets('moderator sees five tabs and no admin sections', (
      tester,
    ) async {
      final (_, router) = await pumpApp(
        tester,
        session: SessionStatus.moderator,
      );

      expect(find.byType(Tab), findsNWidgets(5));
      for (final label in moderatorTabs) {
        expect(find.widgetWithText(Tab, label), findsOneWidget);
      }
      expect(find.widgetWithText(Tab, 'Reports'), findsNothing);

      router.go('/staff/reports');
      await tester.pumpAndSettle();
      expect(location(router), '/staff/appeals');
    });

    testWidgets('tapping a tab switches section', (tester) async {
      final (_, router) = await pumpApp(tester, session: SessionStatus.admin);

      await tester.tap(find.widgetWithText(Tab, 'Users'));
      await tester.pumpAndSettle();
      expect(location(router), '/staff/users');
      expect(
        find.byWidgetPredicate(
          (w) => w is StaffSectionScreen && w.tab == StaffTab.users,
        ),
        findsOneWidget,
      );
    });
  });
}
