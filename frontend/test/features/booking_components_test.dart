import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_bookings.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/push_service.dart';
import 'package:unirent/features/bookings/booking_format.dart';
import 'package:unirent/features/bookings/widgets/booking_tile.dart';
import 'package:unirent/features/bookings/widgets/cancellation_card.dart';
import 'package:unirent/features/bookings/widgets/counterparty_card.dart';
import 'package:unirent/features/bookings/widgets/ist_date_time_field.dart';
import 'package:unirent/features/bookings/widgets/next_action_card.dart';
import 'package:unirent/features/bookings/widgets/payments_list.dart';
import 'package:unirent/features/payments/payment_launcher.dart';
import 'package:unirent/ui/ui.dart';

const karanBikeRequest = '00000000-0000-4000-d000-000000000001';

Widget host(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

/// A real BookingOut for Karan's seeded request, as [email] sees it.
BookingOut seededBooking(
  MockServer server, {
  String email = 'asha@college.edu',
  void Function(MockBooking b)? change,
}) {
  final b = server.db.bookings[karanBikeRequest]!;
  change?.call(b);
  return MockBookingViews(server.db).out(b, server.db.accountByEmail(email)!);
}

void main() {
  group('NextActionCard', () {
    testWidgets('your step is highlighted, with its hint', (tester) async {
      final booking = seededBooking(MockServer());
      await tester.pumpWidget(host(NextActionCard(booking: booking)));
      expect(find.text('Approve or decline the request'), findsOneWidget);
      expect(find.textContaining('fixes the price'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('waiting on the other side is muted', (tester) async {
      final booking = seededBooking(MockServer(), email: 'karan@college.edu');
      await tester.pumpWidget(host(NextActionCard(booking: booking)));
      expect(find.text('Waiting for the owner'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('an unknown key shows only its label', (tester) async {
      final json = seededBooking(MockServer()).toJson()
        ..['next_action'] = const NextAction(
          key: 'something_new',
          label: 'Do the new thing',
          byMe: true,
        ).toJson();
      final booking = BookingOut.fromJson(json);
      await tester.pumpWidget(host(NextActionCard(booking: booking)));
      expect(find.text('Do the new thing'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('CounterpartyCard', () {
    testWidgets('residence only in the counterparty view', (tester) async {
      final server = MockServer();
      final before = seededBooking(server);
      await tester.pumpWidget(
        host(CounterpartyCard(profile: before.renter, isOwner: false)),
      );
      expect(find.byIcon(Icons.home_outlined), findsNothing);
      expect(find.textContaining('Call'), findsNothing);

      final after = seededBooking(
        server,
        change: (b) => b.status = BookingStatus.approved,
      );
      expect(after.renter, isA<ProfileCounterparty>());
      var calls = 0;
      await tester.pumpWidget(
        host(
          CounterpartyCard(
            profile: after.renter,
            isOwner: false,
            onCall: () => calls++,
          ),
        ),
      );
      expect(find.text('Narmada Hostel, room C-12'), findsOneWidget);
      expect(find.text('Renter'), findsOneWidget);
      await tester.tap(find.text('Call Karan'));
      expect(calls, 1);
    });
  });

  testWidgets('PaymentsList shows newest first', (tester) async {
    PaymentOut payment(String id, PaymentPurpose purpose, int day) =>
        PaymentOut(
          id: id,
          purpose: purpose,
          method: PaymentMethod.cash,
          status: PaymentStatus.markedPaid,
          amountPaise: 1000,
          items: const [],
          checkout: null,
          createdAt: DateTime.utc(2026, 10, day),
          capturedAt: null,
        );
    await tester.pumpWidget(
      host(
        PaymentsList(
          payments: [
            payment('a', PaymentPurpose.rent, 1),
            payment('b', PaymentPurpose.returnCharges, 3),
          ],
        ),
      ),
    );
    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(titles, ['Return charges', 'Rent']);
    expect(find.text('Cash · Paid in cash'), findsNWidgets(2));
  });

  testWidgets('BookingTile shows the next step or the status', (tester) async {
    final server = MockServer();
    final views = MockBookingViews(server.db);
    final b = server.db.bookings[karanBikeRequest]!;
    await tester.pumpWidget(
      host(
        BookingTile(booking: views.summary(b, TradeRole.owner), onTap: () {}),
      ),
    );
    expect(find.text('Approve or decline the request'), findsOneWidget);
    expect(find.textContaining('To Karan Mehta'), findsOneWidget);

    b.status = BookingStatus.completed;
    await tester.pumpWidget(
      host(
        BookingTile(booking: views.summary(b, TradeRole.owner), onTap: () {}),
      ),
    );
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('CancellationCard names who cancelled', (tester) async {
    final server = MockServer();
    void cancel(MockBooking b) => b
      ..status = BookingStatus.cancelled
      ..cancellation = MockCancellation(
        by: TradeRole.renter,
        note: 'Exams',
        at: DateTime.utc(2026, 10, 27, 9, 35),
      );
    await tester.pumpWidget(
      host(
        CancellationCard(
          booking: seededBooking(
            server,
            email: 'karan@college.edu',
            change: cancel,
          ),
        ),
      ),
    );
    expect(find.text('You cancelled'), findsOneWidget);
    await tester.pumpWidget(
      host(CancellationCard(booking: seededBooking(server))),
    );
    expect(find.text('Karan Mehta cancelled'), findsOneWidget);
    expect(find.text('“Exams”'), findsOneWidget);
  });

  testWidgets('IstDateTimeField shows IST and reads well', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        IstDateTimeField(
          label: 'From',
          value: DateTime.utc(2026, 10, 28, 4, 30),
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Wed, 28 Oct, 10:00 AM'), findsOneWidget);
    expect(find.bySemanticsLabel('From, Wed, 28 Oct, 10:00 AM'), findsOne);
    handle.dispose();
  });

  group('SimulatedUpiLauncher', () {
    const checkout = RazorpayCheckout(
      keyId: 'k',
      orderId: 'order_1',
      amountPaise: 40000,
      name: 'UniRent',
      description: 'Rent',
    );

    Future<CheckoutResult?> run(
      WidgetTester tester,
      SimulatePayment simulate,
      String tap,
    ) async {
      CheckoutResult? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await SimulatedUpiLauncher(
                simulate,
              ).pay(context, checkout),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Simulated UPI'), findsOneWidget);
      if (tap == 'dismiss') {
        await tester.tapAt(const Offset(10, 10));
      } else {
        await tester.tap(find.text(tap));
      }
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('pay returns what Checkout would', (tester) async {
      final calls = <(String, bool)>[];
      final result = await run(tester, (order, {required fail}) async {
        calls.add((order, fail));
        return {
          'razorpay_order_id': order,
          'razorpay_payment_id': 'pay_1',
          'razorpay_signature': 'sig',
        };
      }, 'Pay ₹400');
      expect(calls, [('order_1', false)]);
      expect(result, isA<CheckoutPaid>());
      expect((result! as CheckoutPaid).paymentId, 'pay_1');
    });

    testWidgets('decline returns the bank’s reason', (tester) async {
      final result = await run(tester, (order, {required fail}) async {
        expect(fail, isTrue);
        return {
          'error': {'description': 'Payment declined by bank'},
        };
      }, 'Decline payment');
      expect(result, isA<CheckoutFailed>());
      expect((result! as CheckoutFailed).message, 'Payment declined by bank');
    });

    testWidgets('dismissing the sheet cancels', (tester) async {
      var called = false;
      final result = await run(tester, (order, {required fail}) async {
        called = true;
        return {};
      }, 'dismiss');
      expect(result, isA<CheckoutCancelled>());
      expect(called, isFalse);
    });

    testWidgets('an unreachable simulator is a failure', (tester) async {
      final result = await run(
        tester,
        (order, {required fail}) async => throw DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'down',
        ),
        'Pay ₹400',
      );
      expect(result, isA<CheckoutFailed>());
    });
  });

  test('labels and links', () {
    expect(
      bookingStatusLabel(BookingStatus.awaitingReviews),
      'Awaiting reviews',
    );
    expect(paymentStatusLabel(PaymentStatus.captured), 'Paid');
    expect(paymentPurposeLabel(PaymentPurpose.returnCharges), 'Return charges');
    expect(
      residenceLabel(
        const Residence(
          type: ResidenceType.dayScholar,
          hostelName: null,
          roomNumber: null,
          homeAddress: '12 MG Road',
        ),
      ),
      '12 MG Road',
    );
    expect(bookingWhen(TradeKind.sale, null, null), 'Purchase');
    expect(
      pushLink({'link': 'unirent://bookings/42'}),
      Uri.parse('unirent://bookings/42'),
    );
    expect(pushLink({'other': 1}), isNull);
  });
}
