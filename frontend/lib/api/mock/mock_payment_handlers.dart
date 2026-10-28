import '../generated/models.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_server.dart';

/// Payment routes of the mock backend (verify and cash marking).
Map<String, MockHandler> paymentHandlers(MockDb db) {
  final h = _PaymentHandlers(db);
  return {
    'GET /api/v1/payments/{payment_id}': h.get,
    'POST /api/v1/payments/{payment_id}/verify': h.verify,
    'POST /api/v1/payments/{payment_id}/mark-cash-paid': h.markCashPaid,
    'GET /api/v1/payments/history': h.history,
    'POST /api/v1/refunds/{refund_id}/mark-done': h.markRefundDone,
  };
}

/// The signature the mock "Razorpay" signs Checkout results with.
String mockCheckoutSignature(String orderId, String paymentId) =>
    'sig_${orderId}_$paymentId';

MockPayment? mockFindPayment(MockDb db, {String? id, String? orderId}) {
  for (final b in db.bookings.values) {
    for (final p in b.payments) {
      if ((id != null && p.id == id) ||
          (orderId != null && p.orderId == orderId)) {
        return p;
      }
    }
  }
  return null;
}

/// Acts as the payer completing Checkout for [orderId], like the Razorpay
/// simulator's `/sim/orders/{order_id}/pay`.
Map<String, Object?> mockSimulatePayment(
  MockDb db,
  String orderId, {
  required bool fail,
}) {
  final payment = mockFindPayment(db, orderId: orderId);
  if (payment == null) {
    return {
      'error': {'code': 'BAD_REQUEST_ERROR', 'description': 'order not found'},
    };
  }
  final razorpayId = 'pay_${db.nextId().substring(24)}';
  if (fail) {
    // The payment.failed webhook marks it failed.
    if (payment.status == PaymentStatus.pending) {
      payment.status = PaymentStatus.failed;
    }
    return {
      'error': {
        'code': 'BAD_REQUEST_ERROR',
        'description': 'Payment declined by bank',
        'metadata': {'payment_id': razorpayId, 'order_id': orderId},
      },
    };
  }
  payment.razorpayPaymentId = razorpayId;
  return {
    'razorpay_payment_id': razorpayId,
    'razorpay_order_id': orderId,
    'razorpay_signature': mockCheckoutSignature(orderId, razorpayId),
  };
}

class _PaymentHandlers {
  _PaymentHandlers(this.db) : views = MockBookingViews(db);

  final MockDb db;
  final MockBookingViews views;

  MockPayment _payment(MockRequest r, MockAccount viewer) {
    final p = mockFindPayment(db, id: r.pathParams['payment_id']);
    if (p == null || (p.payerId != viewer.id && p.payeeId != viewer.id)) {
      throw const MockApiError(404, 'NOT_FOUND', 'Payment not found');
    }
    return p;
  }

  MockResponse get(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    return MockResponse.json(views.paymentOut(_payment(r, viewer)).toJson());
  }

  MockResponse verify(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    final p = _payment(r, viewer);
    if (p.payerId != viewer.id) {
      throw const MockApiError(404, 'NOT_FOUND', 'Payment not found');
    }
    final body = mockParse(r, VerifyIn.fromJson);
    if (p.method != PaymentMethod.upi || p.orderId != body.razorpayOrderId) {
      throw const MockApiError(
        422,
        'ORDER_MISMATCH',
        "That order doesn't belong to this payment",
      );
    }
    final expected = mockCheckoutSignature(
      body.razorpayOrderId,
      body.razorpayPaymentId,
    );
    if (body.razorpaySignature != expected) {
      throw const MockApiError(
        400,
        'INVALID_SIGNATURE',
        'The payment signature is not valid',
      );
    }
    if (!p.isPaid) {
      p
        ..status = PaymentStatus.captured
        ..razorpayPaymentId = body.razorpayPaymentId
        ..capturedAt = db.clock().toUtc();
    }
    return MockResponse.json(views.paymentOut(p).toJson());
  }

  RefundOut _refundOut(MockPayment p, MockRefund x) => RefundOut(
    id: x.id,
    paymentId: p.id,
    amountPaise: x.amountPaise,
    method: x.method,
    status: x.status,
    createdAt: x.createdAt,
    processedAt: x.processedAt,
  );

  /// Every payment the viewer paid or received, newest first.
  MockResponse history(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    final mine = [
      for (final b in db.bookings.values)
        for (final p in b.payments)
          if (p.payerId == viewer.id || p.payeeId == viewer.id) p,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final offset = int.tryParse('${r.query['cursor'] ?? 0}') ?? 0;
    final limit = int.tryParse('${r.query['limit'] ?? 20}') ?? 20;
    final page = mine.skip(offset).take(limit).toList();
    final next = offset + page.length;
    return MockResponse.json(
      PaymentHistoryPage(
        items: [
          for (final p in page)
            () {
              final out = views.paymentOut(p);
              final paid = p.payerId == viewer.id;
              return PaymentHistoryItem(
                id: p.id,
                bookingId: p.bookingId,
                purpose: p.purpose,
                method: p.method,
                status: p.status,
                amountPaise: p.amountPaise,
                items: p.items,
                checkout: out.checkout,
                createdAt: p.createdAt,
                capturedAt: p.capturedAt,
                direction: paid ? Direction.paid : Direction.received,
                counterpartyId: paid ? p.payeeId : p.payerId,
                refundedPaise: p.refundedPaise,
                refunds: [for (final x in p.refunds) _refundOut(p, x)],
              );
            }(),
        ],
        nextCursor: next < mine.length ? '$next' : null,
      ).toJson(),
    );
  }

  /// The payee confirms a ruled cash refund was handed back.
  MockResponse markRefundDone(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    final id = r.pathParams['refund_id'];
    for (final b in db.bookings.values) {
      for (final p in b.payments) {
        for (final x in p.refunds) {
          if (x.id != id) continue;
          if (p.payeeId != viewer.id) break;
          if (x.method != PaymentMethod.cash) {
            throw const MockApiError(
              409,
              'NOT_CASH',
              'Only cash refunds are marked as done',
            );
          }
          if (x.status == RefundOutStatus.cashPending) {
            x
              ..status = RefundOutStatus.cashDone
              ..processedAt = db.clock().toUtc();
            p.status = p.refundedPaise >= p.amountPaise
                ? PaymentStatus.refunded
                : PaymentStatus.partlyRefunded;
          }
          return MockResponse.json(_refundOut(p, x).toJson());
        }
      }
    }
    throw const MockApiError(404, 'NOT_FOUND', 'Refund not found');
  }

  MockResponse markCashPaid(MockRequest r) {
    final viewer = mockAuthenticate(db, r);
    final p = _payment(r, viewer);
    if (p.payeeId != viewer.id) {
      throw const MockApiError(404, 'NOT_FOUND', 'Payment not found');
    }
    if (p.method != PaymentMethod.cash) {
      throw const MockApiError(
        409,
        'NOT_CASH',
        'Only cash payments are marked as paid',
      );
    }
    if (p.status != PaymentStatus.markedPaid) {
      p
        ..status = PaymentStatus.markedPaid
        ..capturedAt = db.clock().toUtc();
    }
    return MockResponse.json(views.paymentOut(p).toJson());
  }
}

/// Starts (or resumes) a payment, mirroring the payments service: refused
/// when already paid; the pending one is returned for the same method and
/// replaced when the payer switches; UPI needs the payee's payout account.
MockPayment mockStartPayment(
  MockDb db,
  MockBooking b, {
  required PaymentPurpose purpose,
  required PaymentMethod method,
  required int amountPaise,
  required List<PaymentItem> items,
  required String payerId,
  required String payeeId,
  String? ref,
}) {
  if (amountPaise <= 0) {
    throw const MockApiError(422, 'INVALID_AMOUNT', 'Nothing to pay');
  }
  final live = b.paymentFor(purpose, ref);
  if (live != null) {
    if (live.isPaid) {
      throw const MockApiError(
        409,
        'ALREADY_PAID',
        'This has already been paid',
      );
    }
    if (live.method == method && live.amountPaise == amountPaise) return live;
    if (live.razorpayPaymentId != null) {
      throw const MockApiError(
        409,
        'PAYMENT_ALREADY_MADE',
        'Your UPI payment went through; refresh to see it',
      );
    }
    live.status = PaymentStatus.failed; // superseded
  }
  if (method == PaymentMethod.upi && !db.accounts[payeeId]!.payoutReady) {
    throw const MockApiError(
      409,
      'PAYEE_NOT_PAYOUT_READY',
      "The owner can't receive UPI payments; pay in cash",
    );
  }
  final id = db.nextId();
  final payment = MockPayment(
    id: id,
    bookingId: b.id,
    purpose: purpose,
    ref: ref,
    method: method,
    amountPaise: amountPaise,
    items: items,
    createdAt: db.clock().toUtc(),
    payerId: payerId,
    payeeId: payeeId,
    orderId: method == PaymentMethod.upi ? 'order_${id.substring(24)}' : null,
  );
  b.payments.add(payment);
  return payment;
}
