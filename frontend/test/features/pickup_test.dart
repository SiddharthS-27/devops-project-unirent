import 'dart:async';
import 'dart:typed_data';

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

class FakePhotoPicker implements PhotoPicker {
  @override
  Future<List<Uint8List>> pick(PhotoSource source, {required int max}) async =>
      [img.encodeJpg(img.Image(width: 20, height: 20))];
}

/// An approved booking where Asha rents [listing] from its owner.
MockBooking ashaRents(MockServer server, int listing) {
  final db = server.db;
  final l = db.listings[mockListingId(listing)]!;
  final now = DateTime.now().toUtc();
  final b = MockBooking(
    id: 'b-asha-$listing',
    listingId: l.id,
    kind: l.kind,
    renterId: db.accountByEmail(asha)!.id,
    ownerId: l.ownerId,
    amountPaise: l.kind == TradeKind.rent ? 40000 : l.salePricePaise!,
    createdAt: now.subtract(const Duration(hours: 2)),
    startAt: l.kind == TradeKind.rent ? now : null,
    endAt: l.kind == TradeKind.rent ? now.add(const Duration(days: 1)) : null,
    status: BookingStatus.approved,
  )..decidedAt = now.subtract(const Duration(hours: 1));
  return db.bookings[b.id] = b;
}

void addPhoto(MockBooking b, TradeRole side, [MockPhase p = MockPhase.pickup]) {
  b.photos
      .putIfAbsent((p, side), () => [])
      .add(
        MockPhoto(id: 'k-$side', key: 'k-$side', url: 'mock://photo/777777'),
      );
}

MockPayment cashPayment(MockBooking b) => MockPayment(
  id: 'cash-1',
  bookingId: b.id,
  purpose: b.handoverPurpose,
  method: PaymentMethod.cash,
  amountPaise: b.amountPaise,
  items: const [],
  createdAt: DateTime.now().toUtc(),
  payerId: b.renterId,
  payeeId: b.ownerId,
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

/// The other side acted on the server: a push makes the screen refetch.
Future<void> pushUpdate(
  WidgetTester tester,
  FakePushService push,
  String id,
) async {
  push.receivedPushes.add(Uri.parse('unirent://bookings/$id'));
  await tester.pumpAndSettle();
}

ChecklistStepState stepState(WidgetTester tester, String title) => tester
    .widget<ChecklistStep>(find.widgetWithText(ChecklistStep, title))
    .state;

Future<void> tapStepAction(TestApp app, String title, String action) => app.tap(
  find.descendant(
    of: find.widgetWithText(ChecklistStep, title),
    matching: find.text(action),
  ),
);

void main() {
  testWidgets('renter: photos, UPI through Checkout, then the code', (
    tester,
  ) async {
    final server = MockServer();
    final push = FakePushService();
    final b = ashaRents(server, 1); // Dev's DSLR; Dev can take UPI
    final app = await open(tester, server, b.id, push);

    expect(find.text('Upload pickup photos'), findsOneWidget);
    expect(stepState(tester, 'Payment'), ChecklistStepState.locked);
    expect(stepState(tester, 'Show your code'), ChecklistStepState.locked);

    await tapStepAction(app, 'Your photos', 'Add photos');
    await app.tapText('Choose from gallery');
    expect(b.photos[(MockPhase.pickup, TradeRole.renter)], hasLength(1));
    expect(find.text('Waiting for their photos'), findsOneWidget);
    expect(stepState(tester, 'Your photos'), ChecklistStepState.done);

    addPhoto(b, TradeRole.owner);
    await pushUpdate(tester, push, b.id);
    expect(stepState(tester, 'Payment'), ChecklistStepState.available);

    await tapStepAction(app, 'Payment', 'Pay');
    await app.tapText('UPI');
    expect(find.text('Simulated UPI'), findsOneWidget);
    await app.tapText('Pay ₹400');

    final payment = b.payments.single;
    expect(payment.method, PaymentMethod.upi);
    expect(payment.status, PaymentStatus.captured);
    expect(find.text('Paid ₹400'), findsOneWidget);
    expect(stepState(tester, 'Payment'), ChecklistStepState.done);
    expect(find.text('Show your code to the owner'), findsOneWidget);

    await tapStepAction(app, 'Show your code', 'Show code');
    final first = b.otps[MockPhase.pickup]!.code;
    expect(
      find.text('${first.substring(0, 3)} ${first.substring(3)}'),
      findsOneWidget,
    );
    expect(find.textContaining('Expires in'), findsOneWidget);

    await tapStepAction(app, 'Show your code', 'New code');
    final second = b.otps[MockPhase.pickup]!.code;
    expect(
      find.text('${second.substring(0, 3)} ${second.substring(3)}'),
      findsOneWidget,
    );
  });

  testWidgets('a declined UPI payment can be tried again', (tester) async {
    final server = MockServer();
    final push = FakePushService();
    final b = ashaRents(server, 1);
    addPhoto(b, TradeRole.renter);
    addPhoto(b, TradeRole.owner);
    final app = await open(tester, server, b.id, push);

    await tapStepAction(app, 'Payment', 'Pay');
    await app.tapText('UPI');
    await app.tapText('Decline payment');
    expect(find.textContaining('Payment declined by bank'), findsOneWidget);
    expect(b.payments.single.status, PaymentStatus.failed);
    expect(stepState(tester, 'Payment'), ChecklistStepState.available);

    await tapStepAction(app, 'Payment', 'Pay');
    await app.tapText('UPI');
    await app.tapText('Pay ₹400');
    expect(b.paymentFor(PaymentPurpose.rent)!.isPaid, isTrue);
  });

  testWidgets('UPI unavailable: pay in cash instead', (tester) async {
    final server = MockServer();
    final push = FakePushService();
    final b = ashaRents(server, 2); // Karan's GoPro; no payout account
    addPhoto(b, TradeRole.renter);
    addPhoto(b, TradeRole.owner);
    final app = await open(tester, server, b.id, push);

    await tapStepAction(app, 'Payment', 'Pay');
    await app.tapText('UPI');
    expect(find.text('UPI isn’t available for this owner'), findsOneWidget);
    await app.tapText('Pay in cash');

    final payment = b.payments.single;
    expect(payment.method, PaymentMethod.cash);
    expect(payment.isPaid, isFalse);
    expect(find.text('Waiting for cash to be marked'), findsOneWidget);
  });

  testWidgets('owner: confirm cash, then type the renter’s code', (
    tester,
  ) async {
    final server = MockServer();
    final push = FakePushService();
    const id = '00000000-0000-4000-d000-000000000001'; // Karan rents her bike
    final b = server.db.bookings[id]!..status = BookingStatus.approved;
    addPhoto(b, TradeRole.renter);
    addPhoto(b, TradeRole.owner);
    b.payments.add(cashPayment(b));
    final app = await open(tester, server, id, push);

    expect(find.text('Mark cash received'), findsWidgets);
    await tapStepAction(app, 'Payment', 'Mark cash received');
    await app.tapText('I have the cash');
    expect(b.payments.single.status, PaymentStatus.markedPaid);
    expect(
      stepState(tester, 'Enter the renter’s code'),
      ChecklistStepState.available,
    );

    // Karan shows a code on his phone.
    b.otps[MockPhase.pickup] = MockOtp(
      '482913',
      DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );
    await app.enterOtp('000000');
    expect(
      find.text('That code isn’t right. Check it and try again.'),
      findsOneWidget,
    );
    await app.enterOtp('482913');

    expect(b.status, BookingStatus.active);
    expect(find.text('Rental started'), findsOneWidget);
    expect(find.text('Rental in progress'), findsOneWidget);
  });

  testWidgets('owner: five wrong tries, then ask for a new code', (
    tester,
  ) async {
    final server = MockServer();
    final push = FakePushService();
    const id = '00000000-0000-4000-d000-000000000001';
    final b = server.db.bookings[id]!..status = BookingStatus.approved;
    addPhoto(b, TradeRole.renter);
    addPhoto(b, TradeRole.owner);
    b.payments.add(cashPayment(b)..status = PaymentStatus.markedPaid);
    b.otps[MockPhase.pickup] = MockOtp(
      '482913',
      DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );
    final app = await open(tester, server, id, push);

    for (var i = 0; i < 5; i++) {
      await app.enterOtp('00000$i');
    }
    await app.enterOtp('482913');
    expect(
      find.text('Too many tries for this code. Ask the renter for a new one.'),
      findsOneWidget,
    );
    expect(b.status, BookingStatus.approved);

    // An expired code is refused too.
    b.otps[MockPhase.pickup] = MockOtp(
      '111111',
      DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    await app.enterOtp('111111');
    expect(
      find.text('That code expired. Ask the renter for a new one.'),
      findsOneWidget,
    );
  });

  test('a sale handover moves to reviews and sells the listing', () async {
    final server = MockServer();
    final b = ashaRents(server, 4); // Meera's cycle, for sale
    addPhoto(b, TradeRole.renter);
    addPhoto(b, TradeRole.owner);
    b.payments.add(cashPayment(b)..status = PaymentStatus.markedPaid);
    final renter = ApiClient(
      config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
      tokenStore: MemoryTokenStore(tokensFor(server, asha)),
      mockServer: server,
    );
    final owner = ApiClient(
      config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
      tokenStore: MemoryTokenStore(tokensFor(server, 'meera@college.edu')),
      mockServer: server,
    );
    final code = await renter.api.bookings.pickupOtp(b.id);
    final done = await owner.api.bookings.verifyPickupOtp(
      b.id,
      OtpIn(code: code.code),
      idempotencyKey: 'k',
    );
    expect(done.status, BookingStatus.awaitingReviews);
    expect(server.db.listings[b.listingId]!.status, ListingStatus.sold);
  });
}
