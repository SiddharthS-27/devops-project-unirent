import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_listings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/listings/photos/photo_picker.dart';
import 'package:unirent/features/listings/photos/photo_processing.dart';
import 'package:unirent/ui/ui.dart';

import '../helpers/test_app.dart';

const asha = 'asha@college.edu';
const karan = 'karan@college.edu';

class FakePhotoPicker implements PhotoPicker {
  @override
  Future<List<Uint8List>> pick(PhotoSource source, {required int max}) async =>
      [img.encodeJpg(img.Image(width: 20, height: 20))];
}

/// Asha has Dev's DSLR (₹400 rent), ending [endIn] from now (negative: late).
MockBooking ashaHasDslr(
  MockServer server, {
  required Duration endIn,
  BookingStatus status = BookingStatus.active,
}) {
  final db = server.db;
  final now = DateTime.now().toUtc();
  final b = MockBooking(
    id: 'b-dslr',
    listingId: mockListingId(1),
    kind: TradeKind.rent,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: db.accountByEmail('dev@college.edu')!.id,
    amountPaise: 40000,
    createdAt: now.subtract(const Duration(days: 2)),
    startAt: now.subtract(const Duration(days: 1)),
    endAt: now.add(endIn),
    status: status,
  )..pickupCompletedAt = now.subtract(const Duration(days: 1));
  if (status == BookingStatus.returning) b.returnStartedAt = now;
  return db.bookings[b.id] = b;
}

/// Karan has Asha's bike (Asha is the owner).
MockBooking karanHasBike(
  MockServer server, {
  required Duration endIn,
  BookingStatus status = BookingStatus.active,
}) {
  final now = DateTime.now().toUtc();
  final b = server.db.bookings['00000000-0000-4000-d000-000000000001']!
    ..status = status
    ..startAt = now.subtract(const Duration(days: 1))
    ..endAt = now.add(endIn)
    ..pickupCompletedAt = now.subtract(const Duration(days: 1));
  if (status == BookingStatus.returning) b.returnStartedAt = now;
  server.db.bookings.remove('00000000-0000-4000-d000-000000000002');
  return b;
}

void addPhoto(MockBooking b, TradeRole side) {
  b.photos
      .putIfAbsent((MockPhase.returnPhase, side), () => [])
      .add(
        MockPhoto(id: 'r-$side', key: 'r-$side', url: 'mock://photo/888888'),
      );
}

ApiClient clientFor(MockServer server, String email) => ApiClient(
  config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
  tokenStore: MemoryTokenStore(tokensFor(server, email)),
  mockServer: server,
);

Future<TestApp> open(
  WidgetTester tester,
  MockServer server,
  String id,
  FakePushService push,
) async {
  final app = await pumpSignedIn(
    tester,
    asha,
    server: server,
    push: push,
    overrides: [
      photoPickerProvider.overrideWithValue(FakePhotoPicker()),
      photoProcessorProvider.overrideWithValue(
        (bytes) async => prepareListingPhoto(bytes),
      ),
    ],
  );
  unawaited(app.router.push(Routes.booking(id)));
  await tester.pumpAndSettle();
  return app;
}

Future<void> pushUpdate(WidgetTester t, FakePushService p, String id) async {
  p.receivedPushes.add(Uri.parse('unirent://bookings/$id'));
  await t.pumpAndSettle();
}

ChecklistStepState stepState(WidgetTester tester, String title) => tester
    .widget<ChecklistStep>(find.widgetWithText(ChecklistStep, title).first)
    .state;

Future<void> tapStep(TestApp app, String title, String action) => app.tap(
  find
      .descendant(
        of: find.widgetWithText(ChecklistStep, title).first,
        matching: find.text(action),
      )
      .last,
);

Future<void> confirm(TestApp app, String label) => app.tap(
  find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  ),
);

void main() {
  testWidgets('overdue renter: server late fee, refreshed, then return', (
    tester,
  ) async {
    final server = MockServer();
    final push = FakePushService();
    // Three hours late: ₹50 + 2% × 2 full hours past the 30-minute grace.
    final b = ashaHasDslr(server, endIn: const Duration(hours: -3));
    final app = await open(tester, server, b.id, push);

    expect(b.status, BookingStatus.overdue);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Late fee so far: ₹66'), findsOneWidget);
    expect(find.text('Overdue: return the item now'), findsOneWidget);
    expect(find.textContaining('Late by'), findsOneWidget);

    // The server's figure changes; the banner refetches each minute.
    b.amountPaise = 80000;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Late fee so far: ₹82'), findsOneWidget);

    await app.tap(find.widgetWithText(FilledButton, 'Start the return'));
    await confirm(app, 'Start return');
    expect(b.status, BookingStatus.returning);
    expect(find.text('Upload return photos'), findsOneWidget);
  });

  testWidgets('owner escalates an hour into overdue', (tester) async {
    final server = MockServer();
    final push = FakePushService();
    final b = karanHasBike(server, endIn: const Duration(hours: -2));
    final app = await open(tester, server, b.id, push);

    expect(find.text('You can escalate to the moderators'), findsOneWidget);
    await app.tapText('Escalate to moderators');
    await app.enterField(
      'Note for the moderators (optional)',
      'Not answering calls',
    );
    await confirm(app, 'Escalate');

    expect(b.escalatedAt, isNotNull);
    expect(b.escalationNote, 'Not answering calls');
    expect(find.textContaining('Escalated to the moderators'), findsOneWidget);
    expect(find.text('Waiting for the return'), findsOneWidget);
  });

  testWidgets('owner waits before escalating', (tester) async {
    final server = MockServer();
    final push = FakePushService();
    final b = karanHasBike(server, endIn: const Duration(minutes: -50));
    await open(tester, server, b.id, push);
    expect(b.status, BookingStatus.overdue);
    expect(
      find.textContaining('You can escalate to the moderators from'),
      findsOneWidget,
    );
    expect(find.text('Escalate to moderators'), findsNothing);
  });

  testWidgets('renter returns: photos, owner’s code, pay the late fee', (
    tester,
  ) async {
    final server = MockServer();
    final push = FakePushService();
    final b = ashaHasDslr(
      server,
      endIn: const Duration(hours: -3),
      status: BookingStatus.returning,
    );
    final app = await open(tester, server, b.id, push);

    expect(
      stepState(tester, 'Owner’s inspection photos'),
      ChecklistStepState.locked,
    );
    await tapStep(app, 'Renter’s return photos', 'Add photos');
    await app.tapText('Choose from gallery');
    expect(find.text('The owner is inspecting the item'), findsOneWidget);

    addPhoto(b, TradeRole.owner);
    b.otps[MockPhase.returnPhase] = MockOtp(
      '246810',
      DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );
    await pushUpdate(tester, push, b.id);
    expect(find.text('Enter the owner\'s code'), findsOneWidget);

    await app.enterOtp('246810');
    expect(b.returnCompletedAt, isNotNull);
    expect(b.frozenLateFeePaise, 6600);
    expect(find.text('Late fee'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pay the charges'), findsOneWidget);

    await tapStep(app, 'Charges', 'Pay');
    await app.tapText('UPI');
    await app.tapText('Pay ₹66');
    expect(b.paymentFor(PaymentPurpose.returnCharges)!.isPaid, isTrue);
    expect(stepState(tester, 'Charges'), ChecklistStepState.done);
    expect(find.text('Waiting for the owner to finish'), findsOneWidget);
  });

  testWidgets('owner inspects, shows the code, charges damage, proceeds', (
    tester,
  ) async {
    final server = MockServer();
    final push = FakePushService();
    final b = karanHasBike(
      server,
      endIn: const Duration(hours: 1),
      status: BookingStatus.returning,
    );
    addPhoto(b, TradeRole.renter);
    final app = await open(tester, server, b.id, push);

    expect(find.text('Inspect the item and upload photos'), findsOneWidget);
    await tapStep(app, 'Owner’s inspection photos', 'Add photos');
    await app.tapText('Choose from gallery');

    await tapStep(app, 'Show your code', 'Show code');
    final code = b.otps[MockPhase.returnPhase]!.code;
    expect(
      find.text('${code.substring(0, 3)} ${code.substring(3)}'),
      findsOneWidget,
    );

    // Karan types the code on his phone.
    // (Real async: the second client isn't driven by the widget clock.)
    await tester.runAsync(
      () => clientFor(server, karan).api.bookings.verifyReturnOtp(
        b.id,
        OtpIn(code: code),
        idempotencyKey: 'k1',
      ),
    );
    await pushUpdate(tester, push, b.id);
    expect(find.text('Tap Proceed to finish'), findsOneWidget);

    await app.tapText('Record damage');
    await app.enterField('Amount', '200');
    await app.enterField('What was damaged?', 'Scratch on the frame');
    await confirm(app, 'Save');
    expect(b.damagePaise, 20000);
    expect(find.text('Damage: Scratch on the frame'), findsOneWidget);
    expect(stepState(tester, 'Proceed'), ChecklistStepState.locked);

    // Karan pays in cash.
    await tester.runAsync(
      () => clientFor(server, karan).api.bookings.payReturnCharges(
        b.id,
        const PaymentStartIn(method: PaymentMethod.cash),
        idempotencyKey: 'k2',
      ),
    );
    await pushUpdate(tester, push, b.id);
    await tapStep(app, 'Charges', 'Mark cash received');
    await confirm(app, 'I have the cash');
    expect(stepState(tester, 'Proceed'), ChecklistStepState.available);

    await tapStep(app, 'Proceed', 'Proceed');
    await confirm(app, 'Proceed');
    expect(b.status, BookingStatus.awaitingReviews);
  });

  test('return rules', () async {
    final server = MockServer();
    final b = karanHasBike(
      server,
      endIn: const Duration(hours: 1),
      status: BookingStatus.returning,
    );
    final owner = clientFor(server, asha);
    final renter = clientFor(server, karan);
    Matcher code(String c) =>
        throwsA(isA<ApiException>().having((e) => e.code, 'code', c));

    // The owner's photos come after the renter's.
    await expectLater(
      owner.api.bookings.returnPhotos(b.id, const PhotosIn(objectKeys: ['x'])),
      code('STEP_LOCKED'),
    );
    addPhoto(b, TradeRole.renter);
    addPhoto(b, TradeRole.owner);
    final otp = await owner.api.bookings.returnOtp(b.id);
    await renter.api.bookings.verifyReturnOtp(
      b.id,
      OtpIn(code: otp.code),
      idempotencyKey: 'v',
    );
    await expectLater(
      renter.api.bookings.payReturnCharges(
        b.id,
        const PaymentStartIn(method: PaymentMethod.cash),
        idempotencyKey: 'p',
      ),
      code('NOTHING_TO_PAY'),
    );
    await owner.api.bookings.recordDamageCharge(
      b.id,
      const DamageChargeIn(amountPaise: 5000, description: 'Bent pedal'),
      idempotencyKey: 'd',
    );
    await expectLater(
      owner.api.bookings.proceed(b.id, idempotencyKey: 'pr'),
      code('CHARGES_UNPAID'),
    );
  });

  test(
    'timers: overdue after grace, escalation after an hour, expiry',
    () async {
      final server = MockServer();
      final b = karanHasBike(server, endIn: const Duration(minutes: -20));
      final owner = clientFor(server, asha);
      // Still inside the 30-minute grace period.
      expect(
        (await owner.api.bookings.getBooking(b.id)).status,
        BookingStatus.active,
      );

      b.endAt = DateTime.now().toUtc().subtract(const Duration(minutes: 45));
      final overdue = await owner.api.bookings.getBooking(b.id);
      expect(overdue.status, BookingStatus.overdue);
      expect(overdue.canEscalate, isFalse);
      await expectLater(
        owner.api.bookings.escalate(b.id, const EscalateIn()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'ESCALATION_NOT_YET',
          ),
        ),
      );

      final old = server.db.bookings['00000000-0000-4000-d000-000000000003']!;
      final stale = MockBooking(
        id: 'stale',
        listingId: old.listingId,
        kind: old.kind,
        renterId: old.renterId,
        ownerId: old.ownerId,
        amountPaise: old.amountPaise,
        createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
        startAt: old.startAt,
        endAt: old.endAt,
      );
      server.db.bookings['stale'] = stale;
      expect(
        (await owner.api.bookings.getBooking('stale')).status,
        BookingStatus.expired,
      );
    },
  );
}
