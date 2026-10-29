import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../features/reviews/pending_reviews.dart';
import 'error_messages.dart';
import 'push_service.dart';

/// Where the user is in the app lifecycle. Drives routing.
enum SessionStatus {
  /// Checking stored tokens on app start.
  restoring,

  /// Stored tokens exist but `/me` couldn't be reached.
  restoreFailed,
  signedOut,

  /// Staff signed in with a temporary password and must set a new one.
  passwordChange,
  onboarding,
  student,
  moderator,
  admin;

  bool get isStaff => this == moderator || this == admin;
}

enum OnboardingStep { profile, phone, terms, notifications }

/// The current session, derived from `GET /me`.
@immutable
class Session {
  const Session(
    this.status, {
    this.me,
    this.onboardingStep,
    this.staffEmail,
    this.error,
  });

  /// Session for a signed-in account. Students who haven't finished
  /// onboarding land on the first incomplete step; [notificationsPending]
  /// adds the (client-only) notifications step after the terms.
  factory Session.fromMe(MeOut me, {bool notificationsPending = false}) {
    switch (me.account.role) {
      case 'admin':
        return Session(SessionStatus.admin, me: me);
      case 'moderator':
        return Session(SessionStatus.moderator, me: me);
    }
    final o = me.onboarding;
    final step = !o.profileComplete
        ? OnboardingStep.profile
        : !o.phoneVerified
        ? OnboardingStep.phone
        : !o.termsAccepted
        ? OnboardingStep.terms
        : notificationsPending
        ? OnboardingStep.notifications
        : null;
    return step == null
        ? Session(SessionStatus.student, me: me)
        : Session(SessionStatus.onboarding, me: me, onboardingStep: step);
  }

  static const restoring = Session(SessionStatus.restoring);
  static const signedOut = Session(SessionStatus.signedOut);

  final SessionStatus status;
  final MeOut? me;
  final OnboardingStep? onboardingStep;

  /// Staff email awaiting a password change.
  final String? staffEmail;

  /// Why restoring failed.
  final String? error;
}

/// Owns sign-in, sign-out and the session derived from `/me`.
class SessionNotifier extends Notifier<Session> {
  @override
  Session build() => Session.restoring;

  ApiClient get _client => ref.read(apiClientProvider);
  UniRentApi get _api => _client.api;

  /// The temporary password, kept in memory only until it is replaced.
  String? _staffPassword;

  /// Restores the session from stored tokens on app start.
  Future<void> restore() async {
    state = Session.restoring;
    if (await _client.tokens.current() == null) {
      state = Session.signedOut;
      return;
    }
    try {
      await refreshMe();
      if (state.status
          case SessionStatus.student ||
              SessionStatus.moderator ||
              SessionStatus.admin) {
        unawaited(_syncPush());
      }
    } on ApiException catch (e) {
      if (e.isConnectivityProblem) {
        state = Session(SessionStatus.restoreFailed, error: friendlyMessage(e));
      } else {
        await _client.clearSession();
        state = Session.signedOut;
      }
    }
  }

  Future<void> _syncPush() async {
    try {
      await ref.read(pushServiceProvider).syncIfPermitted();
    } on Object catch (error) {
      debugPrint('Push token sync failed: $error');
    }
  }

  /// Reloads `/me` and moves the session to match it.
  Future<MeOut> refreshMe() async {
    final me = await _api.profiles.getMe();
    state = Session.fromMe(me);
    if (state.status == SessionStatus.student) {
      await ref.read(pendingReviewsProvider.notifier).refresh();
    }
    return me;
  }

  /// Exchanges a Microsoft ID token (real or mock) for a session.
  Future<void> signInWithMicrosoft(String idToken) async {
    final pair = await _api.auth.signInWithMicrosoft(
      MicrosoftSignIn(idToken: idToken),
    );
    await _client.saveSession(pair);
    await refreshMe();
  }

  Future<void> staffLogin(String email, String password) async {
    final pair = await _api.auth.staffLogin(
      StaffLogin(email: email, password: password),
    );
    if (pair.account.mustChangePassword) {
      _staffPassword = password;
      state = Session(
        SessionStatus.passwordChange,
        staffEmail: pair.account.email,
      );
      return;
    }
    await _client.saveSession(pair);
    await refreshMe();
  }

  /// Replaces the temporary password after [staffLogin].
  Future<void> changeStaffPassword(String newPassword) async {
    final email = state.staffEmail;
    final current = _staffPassword;
    if (email == null || current == null) {
      state = Session.signedOut;
      return;
    }
    final pair = await _api.auth.staffChangePassword(
      StaffPasswordChange(
        email: email,
        currentPassword: current,
        newPassword: newPassword,
      ),
    );
    _staffPassword = null;
    await _client.saveSession(pair);
    await refreshMe();
  }

  void cancelPasswordChange() {
    _staffPassword = null;
    state = Session.signedOut;
  }

  /// After accepting the terms, show the notifications step before home.
  void termsAccepted(MeOut me) {
    state = Session.fromMe(me, notificationsPending: true);
  }

  /// Ends onboarding after the notifications step.
  void finishOnboarding() {
    final me = state.me;
    if (me != null) state = Session.fromMe(me);
  }

  /// Unregisters push, revokes the refresh token and forgets the session.
  /// Failures along the way don't stop the user from signing out.
  Future<void> signOut() async {
    final tokens = await _client.tokens.current();
    try {
      await ref.read(pushServiceProvider).unregister();
    } on Object catch (error) {
      debugPrint('Push token removal failed: $error');
    }
    if (tokens != null) {
      try {
        await _api.auth.logout(
          RefreshRequest(refreshToken: tokens.refreshToken),
        );
      } on ApiException catch (error) {
        debugPrint('Logout failed: $error');
      }
    }
    await _client.clearSession();
    _staffPassword = null;
    ref.read(pendingReviewsProvider.notifier).clear();
    state = Session.signedOut;
  }

  /// Called when token refresh failed and the tokens were already cleared.
  void sessionExpired() => state = Session.signedOut;

  /// Sets the session directly. For tests and previews only.
  @visibleForTesting
  void debugSet(Session session) => state = session;
}

final sessionProvider = NotifierProvider<SessionNotifier, Session>(
  SessionNotifier.new,
);
