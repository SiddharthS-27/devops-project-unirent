import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/env.dart';
import '../../app/error_messages.dart';

/// Signs in with the user's college Microsoft account.
abstract interface class MicrosoftAuth {
  /// Runs the Microsoft sign-in and returns its ID token, or null if the
  /// user cancelled.
  Future<String?> signIn();
}

/// Authorization code + PKCE via the system browser (flutter_appauth).
class AppAuthMicrosoftAuth implements MicrosoftAuth {
  AppAuthMicrosoftAuth({
    required this.tenantId,
    required this.clientId,
    this.appAuth = const FlutterAppAuth(),
  });

  final String tenantId;
  final String clientId;
  final FlutterAppAuth appAuth;

  static const redirectUrl = 'in.unirent.app://oauthredirect';
  static const scopes = ['openid', 'profile', 'email', 'offline_access'];

  @override
  Future<String?> signIn() async {
    if (tenantId.isEmpty || clientId.isEmpty) {
      throw const UserFacingException(
        'Microsoft sign-in isn’t configured in this build.',
      );
    }
    try {
      final result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
          issuer: 'https://login.microsoftonline.com/$tenantId/v2.0',
          scopes: scopes,
          promptValues: const ['select_account'],
        ),
      );
      final idToken = result.idToken;
      if (idToken == null) {
        throw const UserFacingException(
          'Microsoft didn’t return your account details. Please try again.',
        );
      }
      return idToken;
    } on FlutterAppAuthUserCancelledException {
      return null;
    } on PlatformException {
      throw const UserFacingException(
        'Microsoft sign-in didn’t work. Please try again.',
      );
    }
  }
}

/// The real Microsoft sign-in; only used when `AUTH_MODE` isn't `mock`.
final microsoftAuthProvider = Provider<MicrosoftAuth>((ref) {
  final env = ref.watch(appEnvProvider);
  return AppAuthMicrosoftAuth(
    tenantId: env.msTenantId,
    clientId: env.msClientId,
  );
});
