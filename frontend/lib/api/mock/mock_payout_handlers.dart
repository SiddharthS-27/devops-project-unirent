import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_server.dart';

/// Payout (Razorpay linked account) routes of the mock backend.
Map<String, MockHandler> payoutHandlers(MockDb db) {
  final h = _PayoutHandlers(db);
  return {'GET /api/v1/payouts/account': h.get};
}

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
}
