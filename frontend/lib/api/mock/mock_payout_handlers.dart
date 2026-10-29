import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_server.dart';

/// Payout (Razorpay linked account) routes of the mock backend.
Map<String, MockHandler> payoutHandlers(MockDb db) {
  final h = _PayoutHandlers(db);
  return {
    'GET /api/v1/payouts/account': h.get,
    'POST /api/v1/payouts/account': h.link,
    'POST /api/v1/payouts/account/refresh': h.refresh,
  };
}

/// Each status check moves a new account one step towards activation, so the
/// whole flow can be tried in mock mode.
const _nextStatus = {
  PayoutAccountOutStatus.created: PayoutAccountOutStatus.underReview,
  PayoutAccountOutStatus.underReview: PayoutAccountOutStatus.activated,
};

class _PayoutHandlers {
  _PayoutHandlers(this.db);

  final MockDb db;

  static PayoutAccountOut view(MockAccount a) => PayoutAccountOut(
    status: a.payoutStatus,
    ready: a.payoutReady,
    razorpayAccountId: a.razorpayAccountId,
    updatedAt: a.payoutUpdatedAt,
  );

  MockResponse get(MockRequest r) =>
      MockResponse.json(view(mockAuthenticate(db, r)).toJson());

  static void _match(String field, String value, String pattern, String msg) {
    if (!RegExp(pattern).hasMatch(value)) throw mockValidation(field, msg);
  }

  MockResponse link(MockRequest r) {
    final account = mockAuthenticate(db, r);
    if (account.role != 'student') {
      throw const MockApiError(
        403,
        'STUDENTS_ONLY',
        'Only students can do this',
      );
    }
    final body = mockParse(r, PayoutAccountIn.fromJson);
    for (final (field, value) in [
      ('legal_name', body.legalName),
      ('beneficiary_name', body.beneficiaryName),
    ]) {
      if (value.trim().length < 2 || value.length > 120) {
        throw mockValidation(field, 'Must be 2-120 characters');
      }
    }
    _match('email', body.email, r'^[^@\s]+@[^@\s]+\.[^@\s]+$', 'Invalid email');
    _match('phone', body.phone, r'^\+91[6-9]\d{9}$', 'Invalid phone');
    _match(
      'account_number',
      body.accountNumber,
      r'^\d{9,18}$',
      'Invalid account number',
    );
    _match('ifsc', body.ifsc, r'^[A-Z]{4}0[A-Z0-9]{6}$', 'Invalid IFSC');

    final existing = account.payoutStatus;
    if (existing != PayoutAccountOutStatus.none &&
        existing != PayoutAccountOutStatus.suspended) {
      throw const MockApiError(
        409,
        'PAYOUT_ACCOUNT_EXISTS',
        'You already linked a payout account',
      );
    }
    // Like the backend, the bank details go to "Razorpay" and are not kept.
    account
      ..payoutStatus = PayoutAccountOutStatus.created
      ..razorpayAccountId = 'acc_Mock${db.nextId().substring(24)}'
      ..payoutUpdatedAt = db.clock().toUtc();
    return MockResponse(201, view(account).toJson());
  }

  MockResponse refresh(MockRequest r) {
    final account = mockAuthenticate(db, r);
    if (account.payoutStatus == PayoutAccountOutStatus.none) {
      throw const MockApiError(
        404,
        'NO_PAYOUT_ACCOUNT',
        'Link a payout account first',
      );
    }
    final next = _nextStatus[account.payoutStatus];
    if (next != null) {
      account
        ..payoutStatus = next
        ..payoutUpdatedAt = db.clock().toUtc();
    }
    return MockResponse.json(view(account).toJson());
  }
}
