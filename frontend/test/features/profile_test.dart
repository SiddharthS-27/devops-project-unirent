import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_review_handlers.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/listings/listing_providers.dart';
import 'package:unirent/ui/ui.dart';

import '../helpers/booking_helpers.dart';
import '../helpers/test_app.dart';

const asha = 'asha@college.edu';

void addRevealedReview(
  MockServer server, {
  required String about,
  required String by,
  required TrustRole role,
  ReviewType type = ReviewType.lender,
  String comment = 'Smooth handover',
}) {
  final now = DateTime.now().toUtc();
  server.db.reviews.add(
    MockReview(
      id: 'r-$by-$type',
      bookingId: 'b',
      reviewerId: server.db.accountByEmail(by)!.id,
      revieweeId: server.db.accountByEmail(about)!.id,
      revieweeRole: role,
      type: type,
      ratings: const {'communication': 5, 'item_condition': 4},
      comment: comment,
      createdAt: now,
    )..revealedAt = now,
  );
}

TrustBadge badgeAt(WidgetTester tester, int index) =>
    tester.widgetList<TrustBadge>(find.byType(TrustBadge)).elementAt(index);

void main() {
  testWidgets('own profile: trust both ways, trades, reviews by role', (
    tester,
  ) async {
    final server = MockServer();
    addRevealedReview(
      server,
      about: asha,
      by: 'dev@college.edu',
      role: TrustRole.lender,
    );
    addRevealedReview(
      server,
      about: asha,
      by: 'karan@college.edu',
      role: TrustRole.renter,
      type: ReviewType.cancellation,
      comment: 'Cancelled late',
    );
    final app = await pumpSignedIn(tester, asha, server: server);
    await app.tap(find.widgetWithText(NavigationDestination, 'Profile'));

    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.text('Computer Science · Year 3'), findsOneWidget);
    expect(find.text('asha@college.edu'), findsOneWidget);
    expect(badgeAt(tester, 0).score, 86); // lender
    expect(badgeAt(tester, 1).score, 88); // renter
    expect(find.text('12 completed trades'), findsOneWidget);
    expect(find.text('0 cancellations'), findsOneWidget);

    expect(find.text('Smooth handover'), findsOneWidget);
    expect(find.text('Dev Patel'), findsOneWidget);
    await app.tapText('As renter');
    expect(find.text('Cancelled late'), findsOneWidget);
    expect(find.textContaining('Cancellation ·'), findsOneWidget);
  });

  testWidgets('edit profile, including a new photo', (tester) async {
    final server = MockServer();
    final app = await as(tester, server, asha, location: Routes.profile);
    await app.tapText('Edit profile');
    expect(app.location, Routes.editProfile);
    expect(find.text('Computer Science'), findsOneWidget);

    await app.tapText('Add photo (optional)');
    await app.tapText('Choose from gallery');
    expect(find.text('Change photo'), findsOneWidget);
    await app.enterField('Department', 'Mechanical');
    await app.tapText('Save changes');

    final profile = server.db.profiles[server.db.accountByEmail(asha)!.id]!;
    expect(profile.data.department, 'Mechanical');
    expect(profile.data.photoKey, startsWith('profile/'));
    expect(app.location, Routes.profile);
    expect(find.text('Mechanical · Year 3'), findsOneWidget);
    expect(find.text('Profile updated'), findsOneWidget);
  });

  testWidgets('owner’s public profile from a listing, with Call', (
    tester,
  ) async {
    final calls = <String>[];
    final app = await pumpSignedIn(
      tester,
      asha,
      overrides: [
        phoneCallerProvider.overrideWithValue((phone) async {
          calls.add(phone);
          return true;
        }),
      ],
    );
    unawaited(app.router.push(Routes.listing(mockListingId(1))));
    await tester.pumpAndSettle();
    await app.tap(find.text('Dev Patel').first);

    expect(app.location, startsWith('/people/'));
    expect(find.text('Mechanical · Year 2'), findsOneWidget);
    expect(badgeAt(tester, 0).score, 92);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    await app.tapText('Call Dev');
    expect(calls, ['+919876500004']);
  });

  testWidgets('a requester’s profile shows residence once approved', (
    tester,
  ) async {
    final server = MockServer();
    final app = await as(
      tester,
      server,
      asha,
      location: Routes.incomingRequests,
    );
    await app.tap(find.text('Karan Mehta'));
    expect(app.location, startsWith('/people/'));
    expect(find.text('Narmada Hostel, room C-12'), findsNothing);

    server.db.bookings['00000000-0000-4000-d000-000000000001']!.status =
        BookingStatus.approved;
    final again = await as(
      tester,
      server,
      asha,
      location: Routes.person(
        server.db.accountByEmail('karan@college.edu')!.id,
      ),
    );
    expect(again.location, startsWith('/people/'));
    expect(find.text('Narmada Hostel, room C-12'), findsOneWidget);
  });

  testWidgets('a New member', (tester) async {
    final server = MockServer();
    final meera = server.db.accountByEmail('meera@college.edu')!.id;
    await as(tester, server, asha, location: Routes.person(meera));
    expect(badgeAt(tester, 0).score, isNull);
    expect(find.text('New'), findsNWidgets(2));
    expect(find.textContaining('after 5 completed trades'), findsOneWidget);
    expect(find.text('No reviews yet.'), findsOneWidget);
  });

  test('profile photos must be uploaded by you', () async {
    final server = MockServer();
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
      tokenStore: MemoryTokenStore(tokensFor(server, asha)),
      mockServer: server,
    );
    final me = await client.api.profiles.getMe();
    final p = me.profile!;
    await expectLater(
      client.api.profiles.putProfile(
        ProfileIn(
          fullName: p.fullName,
          rollNumber: p.rollNumber,
          department: p.department,
          year: p.year,
          residenceType: p.residence.type,
          hostelName: p.residence.hostelName,
          roomNumber: p.residence.roomNumber,
          photoKey: 'profile/someone-else.jpg',
        ),
      ),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INVALID_PHOTO'),
      ),
    );
  });
}
