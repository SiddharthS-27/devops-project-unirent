import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/college_email_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/staff_password_screen.dart';
import '../features/auth/staff_sign_in_screen.dart';
import '../features/bookings/booking_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/bookings/incoming_requests_screen.dart';
import '../features/bookings/request_screen.dart';
import '../features/help/help_screen.dart';
import '../features/home/home_screen.dart';
import '../features/listings/listing_detail_screen.dart';
import '../features/listings/listing_form_screen.dart';
import '../features/listings/listings_screen.dart';
import '../features/onboarding/notifications_screen.dart';
import '../features/onboarding/phone_screen.dart';
import '../features/onboarding/profile_form_screen.dart';
import '../features/onboarding/terms_screen.dart';
import '../features/payouts/payout_account_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/saved_searches_screen.dart';
import '../features/search/search_filters.dart';
import '../features/search/search_results_screen.dart';
import '../features/staff/staff_section_screen.dart';
import '../features/staff/staff_shell.dart';
import '../features/staff/staff_tab.dart';
import 'not_found_screen.dart';
import 'routes.dart';
import 'session.dart';
import 'splash_screen.dart';
import 'student_shell.dart';

/// The app router. Session changes re-run [redirectFor] without rebuilding
/// the router, so navigation state survives sign-in and role changes.
final routerProvider = Provider<GoRouter>((ref) {
  final sessionChanges = ValueNotifier(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => sessionChanges.value = next);

  final router = GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    refreshListenable: sessionChanges,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionProvider), state.uri),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.signInWithEmail,
        builder: (context, state) => const CollegeEmailSignInScreen(),
      ),
      GoRoute(
        path: Routes.staffSignIn,
        builder: (context, state) => const StaffSignInScreen(),
      ),
      GoRoute(
        path: Routes.staffPassword,
        builder: (context, state) => const StaffPasswordScreen(),
      ),
      GoRoute(
        path: Routes.onboardingProfile,
        builder: (context, state) => const ProfileFormScreen(),
      ),
      GoRoute(
        path: Routes.onboardingPhone,
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: Routes.onboardingTerms,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: Routes.onboardingNotifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Shared by the Bookings and Listings tabs, so it lives on the root
      // navigator above the shell rather than inside one branch.
      GoRoute(
        path: '/bookings/:id',
        builder: (context, state) =>
            BookingScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (context, state) =>
            ListingDetailScreen(listingId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                ListingFormScreen(listingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'request',
            builder: (context, state) =>
                RequestScreen(listingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'requests',
            builder: (context, state) =>
                IncomingRequestsScreen(listingId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.payoutAccount,
        builder: (context, state) => const PayoutAccountScreen(),
      ),
      GoRoute(
        path: Routes.help,
        builder: (context, state) => const HelpScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'saved',
                    builder: (context, state) => const SavedSearchesScreen(),
                  ),
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => SearchResultsScreen(
                      // A new key per URL, so a different search starts fresh.
                      key: ValueKey(state.uri.toString()),
                      initial: SearchFilters.fromQuery(
                        state.uri.queryParameters,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.bookings,
                builder: (context, state) => const BookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.listings,
                builder: (context, state) => const ListingsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const ListingFormScreen(),
                  ),
                  GoRoute(
                    path: 'requests',
                    builder: (context, state) => const IncomingRequestsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // One branch per staff section; the shell hides admin-only tabs from
      // moderators and redirects keep them out of those routes.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => StaffShell(navigationShell: shell),
        branches: [
          for (final tab in StaffTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (context, state) => StaffSectionScreen(tab: tab),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    sessionChanges.dispose();
  });
  return router;
});
