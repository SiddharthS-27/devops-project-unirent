import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the current user is in the app lifecycle. Drives routing.
enum SessionStatus {
  signedOut,
  onboarding,
  student,
  moderator,
  admin;

  bool get isStaff => this == moderator || this == admin;
}

/// Holds the session status. For now it is set directly from UI code; it will
/// be backed by the auth API and secure token storage later.
class SessionNotifier extends Notifier<SessionStatus> {
  @override
  SessionStatus build() => SessionStatus.signedOut;

  void set(SessionStatus status) => state = status;

  void signOut() => state = SessionStatus.signedOut;
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionStatus>(
  SessionNotifier.new,
);
