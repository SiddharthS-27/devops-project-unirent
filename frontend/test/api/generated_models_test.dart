import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/api/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

/// JSON → model → JSON must be lossless.
void expectRoundTrip<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?>) fromJson,
  Map<String, Object?> Function(T) toJson,
) {
  // Through a real encode/decode, as on the wire.
  final decoded =
      jsonDecode(jsonEncode(toJson(fromJson(json)))) as Map<String, Object?>;
  expect(decoded, json);
}

void main() {
  test('BookingOut round-trips, including unions and "return"', () {
    final json = _fixture('booking_out.json');
    expectRoundTrip(json, BookingOut.fromJson, (b) => b.toJson());

    final booking = BookingOut.fromJson(json);
    expect(booking.returnHandover?.phase, HandoverPhase.returnValue);
    expect(booking.owner, isA<ProfilePublic>());
    expect(booking.renter, isA<ProfileCounterparty>());
    expect(booking.role, BookingViewerRole.owner);
    expect(booking.startAt, DateTime.utc(2026, 10, 27, 9, 30));
    expect(booking.startAt?.isUtc, isTrue);
  });

  test('MeOut round-trips with and without a profile', () {
    final booking = _fixture('booking_out.json');
    // Reuse a full own-profile shape from the counterparty fixture.
    final profile = {
      ...(booking['renter']! as Map<String, Object?>),
      'view': 'own',
      'email': 'asha@college.edu',
      'roll_number': '21CS1042',
      'status': 'active',
      'photo_key': null,
    };
    final me = {
      'account': {
        'id': 'a1',
        'email': 'asha@college.edu',
        'role': 'student',
        'status': 'active',
      },
      'profile': profile,
      'onboarding': {
        'profile_complete': true,
        'phone_verified': false,
        'terms_accepted': false,
        'complete': false,
      },
      'current_terms_version': '2026-10',
    };
    expectRoundTrip(me, MeOut.fromJson, (m) => m.toJson());
    expect(MeOut.fromJson(me).profile?.view, 'own');

    final noProfile = {...me, 'profile': null};
    expectRoundTrip(noProfile, MeOut.fromJson, (m) => m.toJson());
  });

  test('ProfileView dispatches on "view" and exposes shared fields', () {
    final json = {
      ...(_fixture('booking_out.json')['owner']! as Map<String, Object?>),
    };
    final ProfileView view = ProfileView.fromJson(json);
    expect(view, isA<ProfilePublic>());
    expect(view.fullName, 'full_name-value');
    expect(view.toJson()['view'], 'public');

    expect(
      () => ProfileView.fromJson({...json, 'view': 'martian'}),
      throwsFormatException,
    );
  });

  test('defaults apply to missing optional fields', () {
    final pair = TokenPair.fromJson(const {
      'access_token': 'a',
      'refresh_token': 'r',
      'expires_in': 900,
      'account': {
        'id': 'x',
        'email': 'admin@unirent.in',
        'role': 'admin',
        'status': 'active',
      },
    });
    expect(pair.tokenType, 'bearer');
    expect(pair.account.mustChangePassword, isFalse);
    expect(const TrustSummary().reviewCount, 0);
  });

  test('optional nulls are omitted, required nulls are sent', () {
    const profile = ProfileIn(
      fullName: 'Asha Verma',
      rollNumber: '21CS1042',
      department: 'CSE',
      year: 3,
      residenceType: ResidenceType.dayScholar,
      homeAddress: '12 MG Road',
    );
    expect(profile.toJson(), {
      'department': 'CSE',
      'full_name': 'Asha Verma',
      'home_address': '12 MG Road',
      'residence_type': 'day_scholar',
      'roll_number': '21CS1042',
      'year': 3,
    });

    final residence = Residence.fromJson(const {
      'type': 'hostel',
      'hostel_name': 'Ganga',
      'room_number': 'B-2',
      'home_address': null,
    });
    expect(residence.toJson(), containsPair('home_address', null));
  });

  test('unknown enum values decode to unknown instead of throwing', () {
    expect(BookingStatus.fromJson('teleported'), BookingStatus.unknown);
    expect(BookingStatus.fromJson('in_appeal'), BookingStatus.inAppeal);
    expect(ItemCondition.newValue.json, 'new');
  });

  test('pages decode their items', () {
    final page = ReviewOutPage.fromJson(const {'items': <Object?>[]});
    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });
}
