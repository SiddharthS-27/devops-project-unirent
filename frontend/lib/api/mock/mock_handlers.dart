import 'dart:convert';

import '../generated/models.dart';
import 'mock_appeal_handlers.dart';
import 'mock_booking_handlers.dart';
import 'mock_db.dart';
import 'mock_help_handlers.dart';
import 'mock_listing_handlers.dart';
import 'mock_payment_handlers.dart';
import 'mock_payout_handlers.dart';
import 'mock_review_handlers.dart';
import 'mock_server.dart';
import 'mock_staff_handlers.dart';
import 'mock_views.dart';

/// Every route the mock backend answers. Add new endpoints here as the app
/// starts using them; anything missing answers 501 like the real backend.
Map<String, MockHandler> mockHandlers(MockDb db) {
  final h = _Handlers(db);
  return {
    ...listingHandlers(db),
    ...bookingHandlers(db),
    ...appealHandlers(db),
    ...paymentHandlers(db),
    ...reviewHandlers(db),
    ...helpHandlers(db),
    ...staffHandlers(db),
    ...payoutHandlers(db),
    'POST /api/v1/auth/microsoft/mock-token': h.microsoftMockToken,
    'POST /api/v1/auth/microsoft': h.microsoftSignIn,
    'POST /api/v1/auth/refresh': h.refresh,
    'POST /api/v1/auth/logout': h.logout,
    'POST /api/v1/auth/staff/login': h.staffLogin,
    'POST /api/v1/auth/staff/password': h.staffChangePassword,
    'POST /api/v1/auth/phone/mock-token': h.phoneMockToken,
    'POST /api/v1/auth/phone': h.verifyPhone,
    'GET /api/v1/me': h.me,
    'PUT /api/v1/me/profile': h.putProfile,
    'POST /api/v1/me/terms': h.acceptTerms,
    'GET /api/v1/profiles/{account_id}': h.profile,
    'POST /api/v1/devices/push-tokens': h.registerPushToken,
    'DELETE /api/v1/devices/push-tokens/{token}': h.removePushToken,
    'GET /api/v1/time': h.time,
  };
}

const _minPasswordLength = 10;

/// A 401 in the backend's shape.
MockApiError mockUnauthenticated([
  String code = 'UNAUTHENTICATED',
  String message = 'Sign in again',
]) => MockApiError(401, code, message);

/// A 422 for one field, in the backend's shape.
MockApiError mockValidation(String field, String message) =>
    MockApiError(422, 'VALIDATION_ERROR', 'The request is not valid', [
      {'field': field, 'message': message},
    ]);

/// Decodes a request body with the generated model, turning shape errors
/// into the backend's 422.
T mockParse<T>(MockRequest r, T Function(Map<String, Object?>) fromJson) {
  try {
    return fromJson(r.json);
  } on TypeError {
    throw const MockApiError(
      422,
      'VALIDATION_ERROR',
      'The request is not valid',
    );
  }
}

/// The signed-in account, enforcing the same token rules as the backend.
MockAccount mockAuthenticate(MockDb db, MockRequest r) {
  final token = r.bearerToken;
  if (token == null) throw mockUnauthenticated();
  if (db.expiredAccessTokens.contains(token)) {
    throw mockUnauthenticated('TOKEN_EXPIRED', 'The access token has expired');
  }
  final account = db.accounts[db.accessTokens[token]];
  if (account == null) {
    throw mockUnauthenticated('INVALID_TOKEN', 'The access token is not valid');
  }
  if (account.mustChangePassword) {
    throw const MockApiError(
      403,
      'PASSWORD_CHANGE_REQUIRED',
      'Set a new password first',
    );
  }
  if (account.status == 'banned') {
    throw mockUnauthenticated('ACCOUNT_DISABLED', "This account can't sign in");
  }
  return account;
}

class _Handlers {
  _Handlers(this.db);

  final MockDb db;

  DateTime get _now => db.clock().toUtc();

  MockAccount _account(MockRequest r) => mockAuthenticate(db, r);

  // ---- auth -----------------------------------------------------------------

  MockResponse microsoftMockToken(MockRequest r) {
    final body = mockParse(r, MockTokenRequest.fromJson);
    final claims = {'email': body.email.toLowerCase(), 'name': body.name};
    final token = base64Url.encode(utf8.encode(jsonEncode(claims)));
    return MockResponse.json(MockTokenOut(idToken: 'mock-ms.$token').toJson());
  }

  MockResponse microsoftSignIn(MockRequest r) {
    final body = mockParse(r, MicrosoftSignIn.fromJson);
    final Map<String, Object?> claims;
    try {
      if (!body.idToken.startsWith('mock-ms.')) throw const FormatException();
      final payload = body.idToken.substring('mock-ms.'.length);
      claims =
          jsonDecode(utf8.decode(base64Url.decode(payload)))
              as Map<String, Object?>;
    } on FormatException {
      throw mockUnauthenticated(
        'INVALID_ID_TOKEN',
        'The ID token is not valid',
      );
    }
    final email = claims['email']! as String;
    if (!email.endsWith('@$mockCollegeDomain')) {
      throw const MockApiError(
        403,
        'EMAIL_DOMAIN_NOT_ALLOWED',
        'Only @$mockCollegeDomain accounts can sign in',
      );
    }
    final account =
        db.accountByEmail(email) ??
        db.addAccount(
          MockAccount(
            id: db.nextId(),
            email: email,
            role: 'student',
            name: claims['name'] as String?,
            createdAt: _now,
          ),
        );
    if (account.isStaff) {
      throw const MockApiError(
        409,
        'EMAIL_IN_USE',
        'This email belongs to another account',
      );
    }
    if (account.status == 'banned') {
      throw const MockApiError(403, 'ACCOUNT_BANNED', 'This account is banned');
    }
    return MockResponse.json(db.issueTokens(account).toJson());
  }

  MockResponse refresh(MockRequest r) {
    final token = mockParse(r, RefreshRequest.fromJson).refreshToken;
    if (db.usedRefreshTokens.contains(token)) {
      // Reuse means the token leaked: revoke everything for that account.
      final accountId = db.refreshTokens.remove(token);
      db.refreshTokens.removeWhere((_, id) => id == accountId);
      throw mockUnauthenticated('REFRESH_TOKEN_REUSED');
    }
    final accountId = db.refreshTokens.remove(token);
    final account = db.accounts[accountId];
    if (account == null) throw mockUnauthenticated('INVALID_REFRESH_TOKEN');
    db
      ..usedRefreshTokens.add(token)
      ..refreshCount += 1;
    return MockResponse.json(db.issueTokens(account).toJson());
  }

  MockResponse logout(MockRequest r) {
    final token = mockParse(r, RefreshRequest.fromJson).refreshToken;
    db.refreshTokens.remove(token);
    return const MockResponse.noContent();
  }

  MockAccount _staffAuthenticate(String email, String password) {
    final account = db.accountByEmail(email);
    if (account == null || !account.isStaff || account.password != password) {
      throw const MockApiError(
        401,
        'INVALID_CREDENTIALS',
        'Wrong email or password',
      );
    }
    return account;
  }

  MockResponse staffLogin(MockRequest r) {
    final body = mockParse(r, StaffLogin.fromJson);
    final account = _staffAuthenticate(body.email, body.password);
    return MockResponse.json(db.issueTokens(account).toJson());
  }

  MockResponse staffChangePassword(MockRequest r) {
    final body = mockParse(r, StaffPasswordChange.fromJson);
    final account = _staffAuthenticate(body.email, body.currentPassword);
    final next = body.newPassword;
    if (next == body.currentPassword) {
      throw const MockApiError(
        422,
        'WEAK_PASSWORD',
        'Choose a different password',
      );
    }
    if (next.length < _minPasswordLength) {
      throw const MockApiError(
        422,
        'WEAK_PASSWORD',
        'Use at least $_minPasswordLength characters',
      );
    }
    if (account.email.contains(next.toLowerCase())) {
      throw const MockApiError(
        422,
        'WEAK_PASSWORD',
        "The password can't contain your email",
      );
    }
    account
      ..password = next
      ..mustChangePassword = false;
    db.accessTokens.removeWhere((_, id) => id == account.id);
    db.refreshTokens.removeWhere((_, id) => id == account.id);
    return MockResponse.json(db.issueTokens(account).toJson());
  }

  MockResponse phoneMockToken(MockRequest r) {
    final body = mockParse(r, PhoneMockTokenRequest.fromJson);
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(body.phone)) {
      throw mockValidation('phone', 'Enter the number in +91XXXXXXXXXX form');
    }
    if (body.code != mockOtpCode) {
      throw const MockApiError(400, 'WRONG_CODE', 'That code is not right');
    }
    return MockResponse.json(
      PhoneMockTokenOut(firebaseIdToken: 'mock-phone.${body.phone}').toJson(),
    );
  }

  MockResponse verifyPhone(MockRequest r) {
    final account = _account(r);
    final token = mockParse(r, PhoneVerify.fromJson).firebaseIdToken;
    if (!token.startsWith('mock-phone.+')) {
      throw const MockApiError(
        401,
        'INVALID_PHONE_TOKEN',
        'The phone token is not valid',
      );
    }
    final phone = token.substring('mock-phone.'.length);
    final owner = db.accounts.values.where((a) => a.phone == phone).firstOrNull;
    if (owner != null && owner.id != account.id) {
      throw const MockApiError(
        409,
        'PHONE_IN_USE',
        'This number belongs to another account',
      );
    }
    account
      ..phone = phone
      ..phoneVerifiedAt = _now;
    return MockResponse.json(
      PhoneOut(phone: phone, phoneVerifiedAt: _now).toJson(),
    );
  }

  // ---- profiles ---------------------------------------------------------------

  ProfileOwn _ownProfile(MockAccount account, MockProfile profile) =>
      mockOwnProfile(db, account);

  MeOut _me(MockAccount account) {
    final profile = db.profiles[account.id];
    final profileComplete = profile != null;
    final phoneVerified = account.phoneVerifiedAt != null;
    final termsAccepted = profile?.termsVersion == mockTermsVersion;
    return MeOut(
      account: AccountSummary(
        id: account.id,
        email: account.email,
        role: account.role,
        status: account.status,
      ),
      profile: profile == null ? null : _ownProfile(account, profile),
      onboarding: Onboarding(
        profileComplete: profileComplete,
        phoneVerified: phoneVerified,
        termsAccepted: termsAccepted,
        complete: profileComplete && phoneVerified && termsAccepted,
      ),
      currentTermsVersion: mockTermsVersion,
    );
  }

  MockResponse me(MockRequest r) =>
      MockResponse.json(_me(_account(r)).toJson());

  MockResponse putProfile(MockRequest r) {
    final account = _account(r);
    if (account.role != 'student') {
      throw const MockApiError(
        403,
        'STUDENTS_ONLY',
        'Only students have profiles',
      );
    }
    var data = mockParse(r, ProfileIn.fromJson);
    _validateProfile(data);
    final photoKey = data.photoKey;
    final previous = db.profiles[account.id]?.data.photoKey;
    if (photoKey != null && photoKey != previous) {
      if (db.uploadOwners[photoKey] != account.id) {
        throw const MockApiError(
          422,
          'INVALID_PHOTO',
          "That photo upload isn't yours",
        );
      }
      if (!db.uploadedKeys.contains(photoKey)) {
        throw const MockApiError(
          422,
          'PHOTO_NOT_UPLOADED',
          'Upload the photo before confirming it',
        );
      }
    }
    if (data.residenceType == ResidenceType.dayScholar) {
      data = ProfileIn(
        fullName: data.fullName,
        rollNumber: data.rollNumber,
        department: data.department,
        year: data.year,
        residenceType: data.residenceType,
        homeAddress: data.homeAddress,
        photoKey: data.photoKey,
      );
    }
    final existing = db.profiles[account.id];
    final profile = db.profiles[account.id] = MockProfile(
      data: data,
      termsVersion: existing?.termsVersion,
    );
    return MockResponse.json(_ownProfile(account, profile).toJson());
  }

  /// The backend's ProfileIn constraints.
  void _validateProfile(ProfileIn p) {
    void length(String field, String? value, int min, int max) {
      final n = value?.length ?? 0;
      if (value != null && (n < min || n > max)) {
        throw mockValidation(field, 'Must be $min-$max characters');
      }
    }

    length('full_name', p.fullName, 2, 200);
    length('roll_number', p.rollNumber, 1, 50);
    length('department', p.department, 1, 100);
    length('hostel_name', p.hostelName, 0, 100);
    length('room_number', p.roomNumber, 0, 20);
    length('home_address', p.homeAddress, 0, 500);
    if (p.year < 1 || p.year > 6) {
      throw mockValidation('year', 'Must be between 1 and 6');
    }
    final hostelGiven =
        (p.hostelName?.isNotEmpty ?? false) &&
        (p.roomNumber?.isNotEmpty ?? false);
    if (p.residenceType == ResidenceType.hostel && !hostelGiven) {
      throw mockValidation(
        '',
        'hostel students give a hostel name and room number',
      );
    }
    if (p.residenceType == ResidenceType.dayScholar &&
        !(p.homeAddress?.isNotEmpty ?? false)) {
      throw mockValidation('', 'day scholars give a home address');
    }
  }

  MockResponse acceptTerms(MockRequest r) {
    final account = _account(r);
    final version = mockParse(r, TermsIn.fromJson).version;
    if (version != mockTermsVersion) {
      throw const MockApiError(
        409,
        'TERMS_OUTDATED',
        'Read the latest terms and accept them again',
      );
    }
    final profile = db.profiles[account.id];
    if (profile == null) {
      throw const MockApiError(
        409,
        'PROFILE_REQUIRED',
        'Fill in your profile first',
      );
    }
    profile.termsVersion = version;
    return MockResponse.json(_me(account).toJson());
  }

  MockResponse profile(MockRequest r) {
    final viewer = _account(r);
    final id = r.pathParams['account_id']!;
    return MockResponse.json(mockProfileFor(db, id, viewer).toJson());
  }

  // ---- devices & time -------------------------------------------------------

  MockResponse registerPushToken(MockRequest r) {
    final account = _account(r);
    final body = mockParse(r, PushTokenIn.fromJson);
    if (body.token.length < 10) {
      throw mockValidation('token', 'Must be at least 10 characters');
    }
    db.pushTokens[body.token] = account.id;
    return const MockResponse.noContent();
  }

  MockResponse removePushToken(MockRequest r) {
    final account = _account(r);
    final token = r.pathParams['token']!;
    if (db.pushTokens[token] == account.id) db.pushTokens.remove(token);
    return const MockResponse.noContent();
  }

  MockResponse time(MockRequest r) =>
      MockResponse.json(ServerTime(now: _now).toJson());
}
