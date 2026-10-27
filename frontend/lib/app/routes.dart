import '../features/staff/staff_tab.dart';
import 'session.dart';

/// Route paths, so screens never hard-code location strings.
abstract final class Routes {
  static const signIn = '/sign-in';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingPhone = '/onboarding/phone';
  static const onboardingTerms = '/onboarding/terms';
  static const onboardingNotifications = '/onboarding/notifications';

  static const home = '/home';
  static const bookings = '/bookings';
  static const listings = '/listings';
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

/// Where [session] may not be at [uri], the location to send them instead;
/// null when the location is allowed.
String? redirectFor(SessionStatus session, Uri uri) {
  final deepLink = deepLinkToLocation(uri);
  if (deepLink != null) {
    return redirectFor(session, deepLink) ?? deepLink.toString();
  }

  final path = uri.path;
  switch (session) {
    case SessionStatus.signedOut:
      return path == Routes.signIn ? null : Routes.signIn;

    case SessionStatus.onboarding:
      return _isUnder(path, '/onboarding') ? null : Routes.onboardingProfile;

    case SessionStatus.student:
      final outsideStudentArea =
          path == '/' ||
          path == Routes.signIn ||
          _isUnder(path, '/onboarding') ||
          _isUnder(path, '/staff');
      return outsideStudentArea ? Routes.home : null;

    case SessionStatus.moderator:
    case SessionStatus.admin:
      if (!_isUnder(path, '/staff')) return Routes.staffHome;
      final tab = StaffTab.forPath(path);
      if (tab == null || !tab.isVisibleTo(session)) return Routes.staffHome;
      return null;
  }
}
