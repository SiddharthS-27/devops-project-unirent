import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_server.dart';

ApiClient mockClient([MockServer? server]) => ApiClient(
  config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
  tokenStore: MemoryTokenStore(),
  mockServer: server ?? MockServer(),
);

Matcher throwsApiCode(String code) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

void main() {
  test('a new student goes through onboarding', () async {
    final client = mockClient();
    final auth = client.api.auth;

    final idToken = await auth.mockMicrosoftToken(
      const MockTokenRequest(email: 'new.student@college.edu', name: 'Ravi'),
    );
    final pair = await auth.signInWithMicrosoft(
      MicrosoftSignIn(idToken: idToken.idToken),
    );
    expect(pair.account.role, 'student');
    await client.saveSession(pair);

    var me = await client.api.profiles.getMe();
    expect(me.profile, isNull);
    expect(me.onboarding.complete, isFalse);

    final profile = await client.api.profiles.putProfile(
      const ProfileIn(
        fullName: 'Ravi Kumar',
        rollNumber: '22EE0007',
        department: 'Electrical',
        year: 2,
        residenceType: ResidenceType.hostel,
        hostelName: 'Kaveri',
        roomNumber: 'A-101',
      ),
    );
    expect(profile.residence.type, ResidenceType.hostel);

    await expectLater(
      auth.mockPhoneToken(
        const PhoneMockTokenRequest(phone: '+919800000001', code: '000000'),
      ),
      throwsApiCode('WRONG_CODE'),
    );
    final phoneToken = await auth.mockPhoneToken(
      const PhoneMockTokenRequest(phone: '+919800000001', code: '123456'),
    );
    final phone = await auth.verifyPhone(
      PhoneVerify(firebaseIdToken: phoneToken.firebaseIdToken),
    );
    expect(phone.phone, '+919800000001');

    me = await client.api.profiles.acceptTerms(
      TermsIn(version: me.currentTermsVersion),
    );
    expect(me.onboarding.complete, isTrue);
    expect(me.profile?.phone, '+919800000001');
  });

  test('rejects emails outside the college domain', () async {
    final auth = mockClient().api.auth;
    final idToken = await auth.mockMicrosoftToken(
      const MockTokenRequest(email: 'someone@gmail.com'),
    );
    await expectLater(
      auth.signInWithMicrosoft(MicrosoftSignIn(idToken: idToken.idToken)),
      throwsApiCode('EMAIL_DOMAIN_NOT_ALLOWED'),
    );
  });

  test('a phone owned by another account is refused', () async {
    final client = mockClient();
    final auth = client.api.auth;
    final idToken = await auth.mockMicrosoftToken(
      const MockTokenRequest(email: 'other@college.edu'),
    );
    await client.saveSession(
      await auth.signInWithMicrosoft(MicrosoftSignIn(idToken: idToken.idToken)),
    );
    // The seeded student already owns this number.
    final token = await auth.mockPhoneToken(
      const PhoneMockTokenRequest(phone: '+919876500001', code: '123456'),
    );
    await expectLater(
      auth.verifyPhone(PhoneVerify(firebaseIdToken: token.firebaseIdToken)),
      throwsApiCode('PHONE_IN_USE'),
    );
  });

  test('profile validation mirrors the backend', () async {
    final client = mockClient();
    final auth = client.api.auth;
    final idToken = await auth.mockMicrosoftToken(
      const MockTokenRequest(email: 'v@college.edu'),
    );
    await client.saveSession(
      await auth.signInWithMicrosoft(MicrosoftSignIn(idToken: idToken.idToken)),
    );
    await expectLater(
      client.api.profiles.putProfile(
        const ProfileIn(
          fullName: 'Vee',
          rollNumber: '1',
          department: 'Civil',
          year: 2,
          residenceType: ResidenceType.hostel,
        ),
      ),
      throwsApiCode('VALIDATION_ERROR'),
    );
  });

  test('a new moderator must change the temporary password', () async {
    final client = mockClient();
    final auth = client.api.auth;

    await expectLater(
      auth.staffLogin(
        const StaffLogin(email: 'moderator@unirent.in', password: 'nope'),
      ),
      throwsApiCode('INVALID_CREDENTIALS'),
    );

    final pair = await auth.staffLogin(
      const StaffLogin(
        email: 'moderator@unirent.in',
        password: 'temporary-password',
      ),
    );
    expect(pair.account.mustChangePassword, isTrue);
    await client.saveSession(pair);
    await expectLater(
      client.api.profiles.getMe(),
      throwsApiCode('PASSWORD_CHANGE_REQUIRED'),
    );

    await expectLater(
      auth.staffChangePassword(
        const StaffPasswordChange(
          email: 'moderator@unirent.in',
          currentPassword: 'temporary-password',
          newPassword: 'short',
        ),
      ),
      throwsApiCode('WEAK_PASSWORD'),
    );
    final changed = await auth.staffChangePassword(
      const StaffPasswordChange(
        email: 'moderator@unirent.in',
        currentPassword: 'temporary-password',
        newPassword: 'a-much-longer-passphrase',
      ),
    );
    expect(changed.account.mustChangePassword, isFalse);
    await client.saveSession(changed);
    final me = await client.api.profiles.getMe();
    expect(me.account.role, 'moderator');
  });

  test('push tokens, server time and profiles', () async {
    final server = MockServer();
    final client = mockClient(server);
    final auth = client.api.auth;
    final idToken = await auth.mockMicrosoftToken(
      const MockTokenRequest(email: 'asha@college.edu'),
    );
    await client.saveSession(
      await auth.signInWithMicrosoft(MicrosoftSignIn(idToken: idToken.idToken)),
    );

    await client.api.devices.registerPushToken(
      const PushTokenIn(
        token: 'fcm-token-123456',
        platform: DevicePlatform.android,
      ),
    );
    expect(server.db.pushTokens, contains('fcm-token-123456'));
    await client.api.devices.removePushToken('fcm-token-123456');
    expect(server.db.pushTokens, isEmpty);

    final time = await client.api.health.serverTime();
    expect(time.now.isUtc, isTrue);

    final me = await client.api.profiles.getMe();
    final view = await client.api.profiles.getProfile(me.account.id);
    expect(view, isA<ProfileOwn>());
    expect(view.fullName, 'Asha Verma');
  });

  test('unrouted endpoints answer 501 like the backend', () async {
    await expectLater(
      mockClient().api.listings.categories(),
      throwsApiCode('NOT_IMPLEMENTED'),
    );
  });
}
