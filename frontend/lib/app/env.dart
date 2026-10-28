import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthMode {
  /// Ask for a college email and use the backend's mock Microsoft tokens.
  mock,

  /// Real Microsoft sign-in (authorization code + PKCE).
  microsoft,
}

enum PhoneAuthMode {
  /// The backend's mock phone tokens (the code is always 123456).
  mock,

  /// Firebase phone authentication (needs `USE_FIREBASE=true`).
  firebase,
}

enum RazorpayMode {
  /// Real Razorpay Checkout (razorpay_flutter) with test or live keys.
  checkout,

  /// A "Simulated UPI" sheet that pays through the local Razorpay simulator.
  sim,
}

/// Build-time configuration from `--dart-define`s. Mock modes are the
/// default in debug builds, real ones in release builds.
class AppEnv {
  const AppEnv({
    this.authMode = AuthMode.mock,
    this.phoneAuthMode = PhoneAuthMode.mock,
    this.useFirebase = false,
    this.msTenantId = '',
    this.msClientId = '',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseProjectId = '',
    this.firebaseSenderId = '',
    this.razorpayMode = RazorpayMode.sim,
    this.razorpaySimUrl = 'http://10.0.2.2:8090',
  });

  factory AppEnv.fromEnvironment() {
    const authMode = String.fromEnvironment('AUTH_MODE');
    const phoneMode = String.fromEnvironment('PHONE_AUTH_MODE');
    const razorpayMode = String.fromEnvironment('RAZORPAY_MODE');
    return AppEnv(
      authMode: switch (authMode) {
        'mock' => AuthMode.mock,
        'microsoft' => AuthMode.microsoft,
        _ => kDebugMode ? AuthMode.mock : AuthMode.microsoft,
      },
      phoneAuthMode: switch (phoneMode) {
        'mock' => PhoneAuthMode.mock,
        'firebase' => PhoneAuthMode.firebase,
        _ => kDebugMode ? PhoneAuthMode.mock : PhoneAuthMode.firebase,
      },
      useFirebase: const bool.fromEnvironment('USE_FIREBASE'),
      msTenantId: const String.fromEnvironment('MS_TENANT_ID'),
      msClientId: const String.fromEnvironment('MS_CLIENT_ID'),
      firebaseApiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      firebaseAppId: const String.fromEnvironment('FIREBASE_APP_ID'),
      firebaseProjectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      firebaseSenderId: const String.fromEnvironment('FIREBASE_SENDER_ID'),
      razorpayMode: switch (razorpayMode) {
        'checkout' => RazorpayMode.checkout,
        'sim' => RazorpayMode.sim,
        _ => kDebugMode ? RazorpayMode.sim : RazorpayMode.checkout,
      },
      razorpaySimUrl: const String.fromEnvironment(
        'RAZORPAY_SIM_URL',
        defaultValue: 'http://10.0.2.2:8090',
      ),
    );
  }

  final AuthMode authMode;
  final PhoneAuthMode phoneAuthMode;
  final bool useFirebase;
  final String msTenantId;
  final String msClientId;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseProjectId;
  final String firebaseSenderId;
  final RazorpayMode razorpayMode;
  final String razorpaySimUrl;
}

final appEnvProvider = Provider<AppEnv>((ref) => AppEnv.fromEnvironment());
