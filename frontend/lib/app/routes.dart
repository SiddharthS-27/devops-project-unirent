import '../features/search/search_filters.dart';
import '../features/staff/staff_tab.dart';
import 'session.dart';

/// Route paths, so screens never hard-code location strings.
abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signInWithEmail = '/sign-in/email';
  static const staffSignIn = '/staff-sign-in';
  static const staffPassword = '/staff-sign-in/password';

  static const onboardingProfile = '/onboarding/profile';
  static const onboardingPhone = '/onboarding/phone';
  static const onboardingTerms = '/onboarding/terms';
  static const onboardingNotifications = '/onboarding/notifications';

  static String onboarding(OnboardingStep step) => switch (step) {
    OnboardingStep.profile => onboardingProfile,
    OnboardingStep.phone => onboardingPhone,
    OnboardingStep.terms => onboardingTerms,
    OnboardingStep.notifications => onboardingNotifications,
  };

  static const home = '/home';
  static const search = '/home/search';

  /// The results screen for [filters].
  static String searchFor(SearchFilters filters) {
    final query = filters.toQuery();
    return Uri(
      path: search,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String listing(String id) => '/listing/${Uri.encodeComponent(id)}';
  static String listingEdit(String id) => '${listing(id)}/edit';
  static String listingRequest(String id) => '${listing(id)}/request';
  static const bookings = '/bookings';
  static const listings = '/listings';
  static const newListing = '/listings/new';
  static const payoutAccount = '/payout-account';
  static const profile = '/profile';
  static const help = '/help';

  static String booking(String id) => '/bookings/${Uri.encodeComponent(id)}';

  static final String staffHome = StaffTab.appeals.path;
}

/// Custom URL scheme for deep links, e.g. `unirent://bookings/42`.
const deepLinkScheme = 'unirent';

/// Maps a custom-scheme deep link to an app path.
///
/// In `unirent://bookings/42` the first path segment parses as the URI host,
/// so it is folded back into the path: `/bookings/42`. Returns null for
/// ordinary in-app locations.
Uri? deepLinkToLocation(Uri uri) {
  if (uri.scheme != deepLinkScheme) return null;
  final segments = [
    if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((s) => s.isNotEmpty),
  ];
  return Uri(
    path: '/${segments.join('/')}',
    query: uri.hasQuery ? uri.query : null,
  );
}

bool _isUnder(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

const _signedOutRoutes = {
  Routes.signIn,
  Routes.signInWithEmail,
  Routes.staffSignIn,
};

/// Where [session] may not be at [uri], the location to send them instead;
/// null when the location is allowed.
String? redirectFor(Session session, Uri uri) {
  final deepLink = deepLinkToLocation(uri);
  if (deepLink != null) {
    return redirectFor(session, deepLink) ?? deepLink.toString();
  }

  final path = uri.path;
  switch (session.status) {
    case SessionStatus.restoring:
    case SessionStatus.restoreFailed:
      if (path == Routes.splash) return null;
      // Remember where the user was going (e.g. a deep link) for later.
      final from = path == '/' ? null : uri.toString();
      return Uri(
        path: Routes.splash,
        queryParameters: from == null ? null : {'from': from},
      ).toString();

    case SessionStatus.signedOut:
      return _signedOutRoutes.contains(path) ? null : Routes.signIn;

    case SessionStatus.passwordChange:
      return path == Routes.staffPassword ? null : Routes.staffPassword;

    case SessionStatus.onboarding:
      final target = Routes.onboarding(session.onboardingStep!);
      return path == target ? null : target;

    case SessionStatus.student:
      if (path == Routes.splash) return _resume(session, uri) ?? Routes.home;
      final outsideStudentArea =
          path == '/' ||
          _signedOutRoutes.contains(path) ||
          _isUnder(path, Routes.staffSignIn) ||
          _isUnder(path, '/onboarding') ||
          _isUnder(path, '/staff');
      return outsideStudentArea ? Routes.home : null;

    case SessionStatus.moderator:
    case SessionStatus.admin:
      if (path == Routes.splash) {
        return _resume(session, uri) ?? Routes.staffHome;
      }
      if (!_isUnder(path, '/staff')) return Routes.staffHome;
      final tab = StaffTab.forPath(path);
      if (tab == null || !tab.isVisibleTo(session.status)) {
        return Routes.staffHome;
      }
      return null;
  }
}

/// The `from` location saved on the splash screen, if [session] may go there.
String? _resume(Session session, Uri splash) {
  final from = splash.queryParameters['from'];
  if (from == null) return null;
  final target = Uri.parse(from);
  return redirectFor(session, target) == null ? from : null;
}
