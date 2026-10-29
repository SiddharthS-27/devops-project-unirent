import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/env.dart';
import '../../app/error_messages.dart';
import '../../app/firebase_setup.dart';

/// A verification in progress for [phone].
class PhoneCodeRequest {
  const PhoneCodeRequest(
    this.phone, {
    this.verificationId,
    this.resendToken,
    this.verifiedIdToken,
  });

  /// E.164, e.g. +919876543210.
  final String phone;
  final String? verificationId;
  final int? resendToken;

  /// Set when the platform verified the number without a code (Android
  /// auto-retrieval).
  final String? verifiedIdToken;
}

/// Proves the user owns a phone number and returns a Firebase ID token for
/// `POST /auth/phone`.
abstract interface class PhoneVerifier {
  /// Sends an SMS code (or re-sends it when [previous] is given).
  Future<PhoneCodeRequest> sendCode(String phone, {PhoneCodeRequest? previous});

  /// Checks [code] and returns the Firebase ID token.
  Future<String> confirm(PhoneCodeRequest request, String code);
}

/// The backend's mock: no SMS is sent and the code is always 123456.
class MockPhoneVerifier implements PhoneVerifier {
  MockPhoneVerifier(this._api);

  final UniRentApi _api;

  @override
  Future<PhoneCodeRequest> sendCode(
    String phone, {
    PhoneCodeRequest? previous,
  }) async => PhoneCodeRequest(phone);

  @override
  Future<String> confirm(PhoneCodeRequest request, String code) async {
    final token = await _api.auth.mockPhoneToken(
      PhoneMockTokenRequest(phone: request.phone, code: code),
    );
    return token.firebaseIdToken;
  }
}

class FirebasePhoneVerifier implements PhoneVerifier {
  FirebasePhoneVerifier([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<PhoneCodeRequest> sendCode(
    String phone, {
    PhoneCodeRequest? previous,
  }) {
    final result = Completer<PhoneCodeRequest>();
    unawaited(
      _auth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: previous?.resendToken,
        verificationCompleted: (credential) async {
          if (result.isCompleted) return;
          try {
            final token = await _idToken(credential);
            if (!result.isCompleted) {
              result.complete(PhoneCodeRequest(phone, verifiedIdToken: token));
            }
          } on Object catch (error) {
            if (!result.isCompleted) result.completeError(error);
          }
        },
        verificationFailed: (error) {
          if (!result.isCompleted) result.completeError(_friendly(error));
        },
        codeSent: (verificationId, resendToken) {
          if (!result.isCompleted) {
            result.complete(
              PhoneCodeRequest(
                phone,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      ),
    );
    return result.future;
  }

  @override
  Future<String> confirm(PhoneCodeRequest request, String code) async {
    final verificationId = request.verificationId;
    if (verificationId == null) {
      throw const UserFacingException('Request a new code and try again.');
    }
    try {
      return await _idToken(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
    } on FirebaseAuthException catch (error) {
      throw _friendly(error);
    }
  }

  Future<String> _idToken(PhoneAuthCredential credential) async {
    final user = (await _auth.signInWithCredential(credential)).user;
    final token = await user?.getIdToken();
    // The Firebase session is only needed for this token.
    await _auth.signOut();
    if (token == null) {
      throw const UserFacingException('Verification failed. Try again.');
    }
    return token;
  }

  static UserFacingException _friendly(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-verification-code' => const UserFacingException(
        'That code isn’t right. Check the SMS and try again.',
        code: 'WRONG_CODE',
      ),
      'invalid-phone-number' => const UserFacingException(
        'That phone number doesn’t look right.',
      ),
      'session-expired' || 'code-expired' => const UserFacingException(
        'The code expired. Request a new one.',
      ),
      'too-many-requests' => const UserFacingException(
        'Too many attempts. Please try again later.',
      ),
      _ => const UserFacingException('Verification failed. Please try again.'),
    };
  }
}

/// Used when Firebase phone auth is selected but Firebase isn't set up.
class UnavailablePhoneVerifier implements PhoneVerifier {
  const UnavailablePhoneVerifier();

  static const _error = UserFacingException(
    'Phone verification isn’t configured in this build.',
  );

  @override
  Future<PhoneCodeRequest> sendCode(
    String phone, {
    PhoneCodeRequest? previous,
  }) => Future.error(_error);

  @override
  Future<String> confirm(PhoneCodeRequest request, String code) =>
      Future.error(_error);
}

final phoneVerifierProvider = Provider<PhoneVerifier>((ref) {
  if (ref.watch(appEnvProvider).phoneAuthMode == PhoneAuthMode.mock) {
    return MockPhoneVerifier(ref.watch(apiProvider));
  }
  return ref.watch(firebaseReadyProvider)
      ? FirebasePhoneVerifier()
      : const UnavailablePhoneVerifier();
});
