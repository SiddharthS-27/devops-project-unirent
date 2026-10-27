// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: contracts/openapi.json. Regenerate with:
//   dart run tool/generate_api.dart

import '../transport.dart';
import 'models.dart';

/// Typed access to every UniRent API operation, grouped by tag.
class UniRentApi {
  UniRentApi(ApiTransport transport)
    : admin = AdminApi(transport),
      auth = AuthApi(transport),
      bookings = BookingsApi(transport),
      devices = DevicesApi(transport),
      health = HealthApi(transport),
      help = HelpApi(transport),
      listings = ListingsApi(transport),
      payments = PaymentsApi(transport),
      profiles = ProfilesApi(transport),
      reviews = ReviewsApi(transport),
      search = SearchApi(transport),
      staff = StaffApi(transport);

  final AdminApi admin;
  final AuthApi auth;
  final BookingsApi bookings;
  final DevicesApi devices;
  final HealthApi health;
  final HelpApi help;
  final ListingsApi listings;
  final PaymentsApi payments;
  final ProfilesApi profiles;
  final ReviewsApi reviews;
  final SearchApi search;
  final StaffApi staff;
}

class AdminApi {
  AdminApi(this._transport);

  final ApiTransport _transport;

  /// Overrule
  ///
  /// Replace a moderator's ruling. Its effects are reversed where possible.
  ///
  /// `POST /api/v1/admin/appeals/{appeal_id}/overrule`
  Future<AppealDetail> overrule(String appealId, RulingIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/admin/appeals/${Uri.encodeComponent(appealId)}/overrule',
      body: body.toJson(),
    );
    return AppealDetail.fromJson(json as Map<String, Object?>);
  }

  /// Audit Log
  ///
  /// `GET /api/v1/admin/audit-log`
  Future<AuditEntryOutPage> auditLog({
    String? actorId,
    String? target,
    String? cursor,
    int? limit,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/admin/audit-log',
      query: {
        'actor_id': ?actorId,
        'target': ?target,
        'cursor': ?cursor,
        'limit': ?limit?.toString(),
      },
    );
    return AuditEntryOutPage.fromJson(json as Map<String, Object?>);
  }

  /// Get Clock
  ///
  /// `GET /api/v1/admin/clock`
  Future<ClockOut> getClock() async {
    final json = await _transport.send('GET', '/api/v1/admin/clock');
    return ClockOut.fromJson(json as Map<String, Object?>);
  }

  /// Set Clock
  ///
  /// Staging only: move the clock forward for the demo (for example to an overdue rental).
  ///
  /// `POST /api/v1/admin/clock`
  Future<ClockOut> setClock(ClockIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/admin/clock',
      body: body.toJson(),
    );
    return ClockOut.fromJson(json as Map<String, Object?>);
  }

  /// Metrics
  ///
  /// `GET /api/v1/admin/metrics`
  Future<MetricsOut> metrics() async {
    final json = await _transport.send('GET', '/api/v1/admin/metrics');
    return MetricsOut.fromJson(json as Map<String, Object?>);
  }

  /// List Moderators
  ///
  /// `GET /api/v1/admin/moderators`
  Future<List<StaffAccountOut>> listModerators() async {
    final json = await _transport.send('GET', '/api/v1/admin/moderators');
    return (json as List<Object?>)
        .map((e0) => StaffAccountOut.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Create Moderator
  ///
  /// Create a moderator with a temporary password they replace on first login.
  ///
  /// `POST /api/v1/admin/moderators`
  Future<StaffAccountOut> createModerator(ModeratorCreate body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/admin/moderators',
      body: body.toJson(),
    );
    return StaffAccountOut.fromJson(json as Map<String, Object?>);
  }

  /// Deactivate Moderator
  ///
  /// `POST /api/v1/admin/moderators/{account_id}/deactivate`
  Future<StaffAccountOut> deactivateModerator(String accountId) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/admin/moderators/${Uri.encodeComponent(accountId)}/deactivate',
    );
    return StaffAccountOut.fromJson(json as Map<String, Object?>);
  }
}

class AuthApi {
  AuthApi(this._transport);

  final ApiTransport _transport;

  /// Logout
  ///
  /// `POST /api/v1/auth/logout`
  Future<void> logout(RefreshRequest body) async {
    await _transport.send('POST', '/api/v1/auth/logout', body: body.toJson());
  }

  /// Sign In With Microsoft
  ///
  /// Exchange a Microsoft ID token for UniRent tokens. Creates the account on first sign-in.
  ///
  /// `POST /api/v1/auth/microsoft`
  Future<TokenPair> signInWithMicrosoft(MicrosoftSignIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/auth/microsoft',
      body: body.toJson(),
    );
    return TokenPair.fromJson(json as Map<String, Object?>);
  }

  /// Mock Microsoft Token
  ///
  /// Development only: a signed stand-in for a Microsoft ID token.
  ///
  /// `POST /api/v1/auth/microsoft/mock-token`
  Future<MockTokenOut> mockMicrosoftToken(MockTokenRequest body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/auth/microsoft/mock-token',
      body: body.toJson(),
    );
    return MockTokenOut.fromJson(json as Map<String, Object?>);
  }

  /// Verify Phone
  ///
  /// Save the phone number from a verified Firebase phone ID token.
  ///
  /// `POST /api/v1/auth/phone`
  Future<PhoneOut> verifyPhone(PhoneVerify body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/auth/phone',
      body: body.toJson(),
    );
    return PhoneOut.fromJson(json as Map<String, Object?>);
  }

  /// Mock Phone Token
  ///
  /// Development only: stands in for Firebase. The code is always 123456.
  ///
  /// `POST /api/v1/auth/phone/mock-token`
  Future<PhoneMockTokenOut> mockPhoneToken(PhoneMockTokenRequest body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/auth/phone/mock-token',
      body: body.toJson(),
    );
    return PhoneMockTokenOut.fromJson(json as Map<String, Object?>);
  }

  /// Refresh
  ///
  /// Rotate a refresh token. Using one twice signs out every device of that sign-in.
  ///
  /// `POST /api/v1/auth/refresh`
  Future<TokenPair> refresh(RefreshRequest body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/auth/refresh',
      body: body.toJson(),
    );
    return TokenPair.fromJson(json as Map<String, Object?>);
  }

  /// Staff Login
  ///
  /// Moderator and admin login. While `must_change_password` is true, the token
  /// only works for /auth/staff/password.
  ///
  /// `POST /api/v1/auth/staff/login`
  Future<TokenPair> staffLogin(StaffLogin body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/auth/staff/login',
      body: body.toJson(),
    );
    return TokenPair.fromJson(json as Map<String, Object?>);
  }

  /// Staff Change Password
  ///
  /// Set a new password; also how a new moderator replaces the temporary one.
  ///
  /// `POST /api/v1/auth/staff/password`
  Future<TokenPair> staffChangePassword(StaffPasswordChange body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/auth/staff/password',
      body: body.toJson(),
    );
    return TokenPair.fromJson(json as Map<String, Object?>);
  }
}

class BookingsApi {
  BookingsApi(this._transport);

  final ApiTransport _transport;

  /// List Bookings
  ///
  /// My bookings as renter or buyer, or as owner or seller (incoming requests).
  ///
  /// `GET /api/v1/bookings`
  Future<BookingSummaryPage> listBookings({
    TradeRole? role,
    BookingGroup? group,
    String? listingId,
    String? cursor,
    int? limit,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/bookings',
      query: {
        'role': ?role?.json,
        'group': ?group?.json,
        'listing_id': ?listingId,
        'cursor': ?cursor,
        'limit': ?limit?.toString(),
      },
    );
    return BookingSummaryPage.fromJson(json as Map<String, Object?>);
  }

  /// Request Booking
  ///
  /// Request to rent or buy. Expires if the owner doesn't answer in 24 hours.
  ///
  /// `POST /api/v1/bookings`
  Future<BookingOut> requestBooking(
    BookingCreate body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Quote
  ///
  /// The request summary: total rent, the late-fee rule and the grace period.
  ///
  /// `GET /api/v1/bookings/quote`
  Future<QuoteOut> quote({
    required String listingId,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/bookings/quote',
      query: {
        'listing_id': listingId,
        'start_at': ?startAt?.toUtc().toIso8601String(),
        'end_at': ?endAt?.toUtc().toIso8601String(),
      },
    );
    return QuoteOut.fromJson(json as Map<String, Object?>);
  }

  /// Get Booking
  ///
  /// `GET /api/v1/bookings/{booking_id}`
  Future<BookingOut> getBooking(String bookingId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}',
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// File Appeal
  ///
  /// Handover photos attach automatically.
  ///
  /// `POST /api/v1/bookings/{booking_id}/appeals`
  Future<AppealOut> fileAppeal(
    String bookingId,
    AppealCreate body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/appeals',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return AppealOut.fromJson(json as Map<String, Object?>);
  }

  /// Approve
  ///
  /// Owner approves. Overlapping pending requests are auto-declined.
  ///
  /// `POST /api/v1/bookings/{booking_id}/approve`
  Future<BookingOut> approve(
    String bookingId, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/approve',
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Cancel
  ///
  /// Either side, after approval and before the pickup OTP. The note goes to the other side.
  ///
  /// `POST /api/v1/bookings/{booking_id}/cancel`
  Future<BookingOut> cancel(
    String bookingId,
    CancelIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/cancel',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Rate Cancellation
  ///
  /// `POST /api/v1/bookings/{booking_id}/cancellation-rating`
  Future<BookingOut> rateCancellation(
    String bookingId,
    CancellationRatingIn body,
  ) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/cancellation-rating',
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Record Damage Charge
  ///
  /// Owner records the charge both sides agreed on. Either side may appeal instead.
  ///
  /// `POST /api/v1/bookings/{booking_id}/damage-charge`
  Future<BookingOut> recordDamageCharge(
    String bookingId,
    DamageChargeIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/damage-charge',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Decline
  ///
  /// `POST /api/v1/bookings/{booking_id}/decline`
  Future<BookingOut> decline(
    String bookingId,
    DeclineIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/decline',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Escalate
  ///
  /// Owner, one hour or more into overdue.
  ///
  /// `POST /api/v1/bookings/{booking_id}/escalate`
  Future<BookingOut> escalate(String bookingId, EscalateIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/escalate',
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Request Extension
  ///
  /// `POST /api/v1/bookings/{booking_id}/extensions`
  Future<ExtensionOut> requestExtension(
    String bookingId,
    ExtensionIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/extensions',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return ExtensionOut.fromJson(json as Map<String, Object?>);
  }

  /// Approve Extension
  ///
  /// `POST /api/v1/bookings/{booking_id}/extensions/{extension_id}/approve`
  Future<ExtensionOut> approveExtension(
    String bookingId,
    String extensionId, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/extensions/${Uri.encodeComponent(extensionId)}/approve',
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return ExtensionOut.fromJson(json as Map<String, Object?>);
  }

  /// Decline Extension
  ///
  /// `POST /api/v1/bookings/{booking_id}/extensions/{extension_id}/decline`
  Future<ExtensionOut> declineExtension(
    String bookingId,
    String extensionId, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/extensions/${Uri.encodeComponent(extensionId)}/decline',
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return ExtensionOut.fromJson(json as Map<String, Object?>);
  }

  /// Pay Extension
  ///
  /// UPI now, or cash, which is added to the charges at return.
  ///
  /// `POST /api/v1/bookings/{booking_id}/extensions/{extension_id}/payment`
  Future<PaymentOut> payExtension(
    String bookingId,
    String extensionId,
    PaymentStartIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/extensions/${Uri.encodeComponent(extensionId)}/payment',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return PaymentOut.fromJson(json as Map<String, Object?>);
  }

  /// Pickup Otp
  ///
  /// Renter's phone shows this code once photos and payment are done.
  ///
  /// `POST /api/v1/bookings/{booking_id}/pickup/otp`
  Future<OtpOut> pickupOtp(String bookingId) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/pickup/otp',
    );
    return OtpOut.fromJson(json as Map<String, Object?>);
  }

  /// Verify Pickup Otp
  ///
  /// Owner types the renter's code. The rental becomes Active (a sale completes).
  ///
  /// `POST /api/v1/bookings/{booking_id}/pickup/otp/verify`
  Future<BookingOut> verifyPickupOtp(
    String bookingId,
    OtpIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/pickup/otp/verify',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Pickup Payment
  ///
  /// Renter pays rent (or the sale price): UPI opens Razorpay Checkout; cash waits
  /// for the owner to mark it received.
  ///
  /// `POST /api/v1/bookings/{booking_id}/pickup/payment`
  Future<PaymentOut> pickupPayment(
    String bookingId,
    PaymentStartIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/pickup/payment',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return PaymentOut.fromJson(json as Map<String, Object?>);
  }

  /// Pickup Photos
  ///
  /// `POST /api/v1/bookings/{booking_id}/pickup/photos`
  Future<BookingOut> pickupPhotos(String bookingId, PhotosIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/pickup/photos',
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Proceed
  ///
  /// Owner closes the return once charges are paid. Reviews open.
  ///
  /// `POST /api/v1/bookings/{booking_id}/proceed`
  Future<BookingOut> proceed(
    String bookingId, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/proceed',
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Return Otp
  ///
  /// Owner's phone shows this code after both sides' return photos.
  ///
  /// `POST /api/v1/bookings/{booking_id}/return/otp`
  Future<OtpOut> returnOtp(String bookingId) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/return/otp',
    );
    return OtpOut.fromJson(json as Map<String, Object?>);
  }

  /// Verify Return Otp
  ///
  /// Renter types the owner's code, confirming the item is back.
  ///
  /// `POST /api/v1/bookings/{booking_id}/return/otp/verify`
  Future<BookingOut> verifyReturnOtp(
    String bookingId,
    OtpIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/return/otp/verify',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Pay Return Charges
  ///
  /// Late fee, damage charge and any cash extensions, itemised.
  ///
  /// `POST /api/v1/bookings/{booking_id}/return/payment`
  Future<PaymentOut> payReturnCharges(
    String bookingId,
    PaymentStartIn body, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/return/payment',
      headers: {'Idempotency-Key': idempotencyKey},
      body: body.toJson(),
    );
    return PaymentOut.fromJson(json as Map<String, Object?>);
  }

  /// Return Photos
  ///
  /// `POST /api/v1/bookings/{booking_id}/return/photos`
  Future<BookingOut> returnPhotos(String bookingId, PhotosIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/return/photos',
      body: body.toJson(),
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Start Return
  ///
  /// `POST /api/v1/bookings/{booking_id}/return/start`
  Future<BookingOut> startReturn(
    String bookingId, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/return/start',
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }

  /// Review Form
  ///
  /// `GET /api/v1/bookings/{booking_id}/review-form`
  Future<ReviewForm> reviewForm(String bookingId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/review-form',
    );
    return ReviewForm.fromJson(json as Map<String, Object?>);
  }

  /// Submit Review
  ///
  /// Blind: hidden until both sides submit or 24 hours pass.
  ///
  /// `POST /api/v1/bookings/{booking_id}/reviews`
  Future<ReviewState> submitReview(String bookingId, ReviewIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/reviews',
      body: body.toJson(),
    );
    return ReviewState.fromJson(json as Map<String, Object?>);
  }

  /// Withdraw
  ///
  /// `POST /api/v1/bookings/{booking_id}/withdraw`
  Future<BookingOut> withdraw(
    String bookingId, {
    required String idempotencyKey,
  }) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/withdraw',
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return BookingOut.fromJson(json as Map<String, Object?>);
  }
}

class DevicesApi {
  DevicesApi(this._transport);

  final ApiTransport _transport;

  /// Register Push Token
  ///
  /// Register this device for push. Call after every sign-in and token refresh.
  ///
  /// `POST /api/v1/devices/push-tokens`
  Future<void> registerPushToken(PushTokenIn body) async {
    await _transport.send(
      'POST',
      '/api/v1/devices/push-tokens',
      body: body.toJson(),
    );
  }

  /// Remove Push Token
  ///
  /// Stop pushes to this device, for example on sign-out.
  ///
  /// `DELETE /api/v1/devices/push-tokens/{token}`
  Future<void> removePushToken(String token) async {
    await _transport.send(
      'DELETE',
      '/api/v1/devices/push-tokens/${Uri.encodeComponent(token)}',
    );
  }
}

class HealthApi {
  HealthApi(this._transport);

  final ApiTransport _transport;

  /// Server Time
  ///
  /// The server clock. Countdowns use it so phones with a wrong clock still agree.
  ///
  /// `GET /api/v1/time`
  Future<ServerTime> serverTime() async {
    final json = await _transport.send('GET', '/api/v1/time');
    return ServerTime.fromJson(json as Map<String, Object?>);
  }

  /// Healthz
  ///
  /// The process is up. Says nothing about its dependencies.
  ///
  /// `GET /healthz`
  Future<Map<String, String>> healthz() async {
    final json = await _transport.send('GET', '/healthz');
    return (json as Map<String, Object?>).map(
      (k0, v0) => MapEntry(k0, v0! as String),
    );
  }

  /// Readyz
  ///
  /// Ready to serve: the database and Redis both answer.
  ///
  /// `GET /readyz`
  Future<Object?> readyz() async {
    return _transport.send('GET', '/readyz');
  }
}

class HelpApi {
  HelpApi(this._transport);

  final ApiTransport _transport;

  /// Chat
  ///
  /// The help bot answers only general questions about how UniRent works.
  ///
  /// `POST /api/v1/help/chat`
  Future<ChatReply> chat(ChatIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/help/chat',
      body: body.toJson(),
    );
    return ChatReply.fromJson(json as Map<String, Object?>);
  }

  /// Faqs
  ///
  /// `GET /api/v1/help/faqs`
  Future<List<FaqOut>> faqs() async {
    final json = await _transport.send('GET', '/api/v1/help/faqs');
    return (json as List<Object?>)
        .map((e0) => FaqOut.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Handoff
  ///
  /// Talk to a moderator: opens a support thread holding the chat transcript.
  ///
  /// `POST /api/v1/help/handoff`
  Future<SupportThreadOut> handoff(HandoffIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/help/handoff',
      body: body.toJson(),
    );
    return SupportThreadOut.fromJson(json as Map<String, Object?>);
  }

  /// My Threads
  ///
  /// `GET /api/v1/support/threads`
  Future<List<SupportThreadSummary>> myThreads() async {
    final json = await _transport.send('GET', '/api/v1/support/threads');
    return (json as List<Object?>)
        .map((e0) => SupportThreadSummary.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// My Thread
  ///
  /// `GET /api/v1/support/threads/{thread_id}`
  Future<SupportThreadOut> myThread(String threadId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/support/threads/${Uri.encodeComponent(threadId)}',
    );
    return SupportThreadOut.fromJson(json as Map<String, Object?>);
  }

  /// Post Message
  ///
  /// `POST /api/v1/support/threads/{thread_id}/messages`
  Future<SupportMessage> postMessage(
    String threadId,
    SupportMessageIn body,
  ) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/support/threads/${Uri.encodeComponent(threadId)}/messages',
      body: body.toJson(),
    );
    return SupportMessage.fromJson(json as Map<String, Object?>);
  }
}

class ListingsApi {
  ListingsApi(this._transport);

  final ApiTransport _transport;

  /// My Assets
  ///
  /// Items you own, including ones you bought, so you can relist them.
  ///
  /// `GET /api/v1/assets/mine`
  Future<List<AssetOut>> myAssets() async {
    final json = await _transport.send('GET', '/api/v1/assets/mine');
    return (json as List<Object?>)
        .map((e0) => AssetOut.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Get Asset
  ///
  /// `GET /api/v1/assets/{asset_id}`
  Future<AssetOut> getAsset(String assetId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/assets/${Uri.encodeComponent(assetId)}',
    );
    return AssetOut.fromJson(json as Map<String, Object?>);
  }

  /// Categories
  ///
  /// `GET /api/v1/categories`
  Future<List<CategoryOut>> categories() async {
    final json = await _transport.send('GET', '/api/v1/categories');
    return (json as List<Object?>)
        .map((e0) => CategoryOut.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Create Listing
  ///
  /// Publish a listing. Needs a linked payout account.
  ///
  /// `POST /api/v1/listings`
  Future<ListingDetail> createListing(ListingCreate body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/listings',
      body: body.toJson(),
    );
    return ListingDetail.fromJson(json as Map<String, Object?>);
  }

  /// My Listings
  ///
  /// `GET /api/v1/listings/mine`
  Future<List<ListingCard>> myListings({ListingStatus? status}) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/listings/mine',
      query: {'status': ?status?.json},
    );
    return (json as List<Object?>)
        .map((e0) => ListingCard.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Get Listing
  ///
  /// `GET /api/v1/listings/{listing_id}`
  Future<ListingDetail> getListing(String listingId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/listings/${Uri.encodeComponent(listingId)}',
    );
    return ListingDetail.fromJson(json as Map<String, Object?>);
  }

  /// Update Listing
  ///
  /// Refused while a booking is approved or active (price and terms are locked).
  ///
  /// `PATCH /api/v1/listings/{listing_id}`
  Future<ListingDetail> updateListing(
    String listingId,
    ListingUpdate body,
  ) async {
    final json = await _transport.send(
      'PATCH',
      '/api/v1/listings/${Uri.encodeComponent(listingId)}',
      body: body.toJson(),
    );
    return ListingDetail.fromJson(json as Map<String, Object?>);
  }

  /// Pause Listing
  ///
  /// `POST /api/v1/listings/{listing_id}/pause`
  Future<ListingDetail> pauseListing(String listingId) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/listings/${Uri.encodeComponent(listingId)}/pause',
    );
    return ListingDetail.fromJson(json as Map<String, Object?>);
  }

  /// Add Listing Photo
  ///
  /// `POST /api/v1/listings/{listing_id}/photos`
  Future<PhotoOut> addListingPhoto(String listingId, PhotoAdd body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/listings/${Uri.encodeComponent(listingId)}/photos',
      body: body.toJson(),
    );
    return PhotoOut.fromJson(json as Map<String, Object?>);
  }

  /// Delete Listing Photo
  ///
  /// `DELETE /api/v1/listings/{listing_id}/photos/{photo_id}`
  Future<void> deleteListingPhoto(String listingId, String photoId) async {
    await _transport.send(
      'DELETE',
      '/api/v1/listings/${Uri.encodeComponent(listingId)}/photos/${Uri.encodeComponent(photoId)}',
    );
  }

  /// Resume Listing
  ///
  /// `POST /api/v1/listings/{listing_id}/resume`
  Future<ListingDetail> resumeListing(String listingId) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/listings/${Uri.encodeComponent(listingId)}/resume',
    );
    return ListingDetail.fromJson(json as Map<String, Object?>);
  }

  /// Presign Photo Upload
  ///
  /// A presigned URL to upload one photo straight to storage. Resize to at most
  /// 1600 px first, then confirm the object_key where the photo belongs.
  ///
  /// `POST /api/v1/uploads/photos`
  Future<UploadOut> presignPhotoUpload(UploadRequest body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/uploads/photos',
      body: body.toJson(),
    );
    return UploadOut.fromJson(json as Map<String, Object?>);
  }
}

class PaymentsApi {
  PaymentsApi(this._transport);

  final ApiTransport _transport;

  /// Get Payout Account
  ///
  /// `GET /api/v1/payouts/account`
  Future<PayoutAccountOut> getPayoutAccount() async {
    final json = await _transport.send('GET', '/api/v1/payouts/account');
    return PayoutAccountOut.fromJson(json as Map<String, Object?>);
  }

  /// Link Payout Account
  ///
  /// Link a Razorpay account to receive UPI payments. Required before listing.
  ///
  /// `POST /api/v1/payouts/account`
  Future<PayoutAccountOut> linkPayoutAccount(PayoutAccountIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/payouts/account',
      body: body.toJson(),
    );
    return PayoutAccountOut.fromJson(json as Map<String, Object?>);
  }

  /// Refresh Payout Account
  ///
  /// Ask Razorpay for the latest activation status.
  ///
  /// `POST /api/v1/payouts/account/refresh`
  Future<PayoutAccountOut> refreshPayoutAccount() async {
    final json = await _transport.send(
      'POST',
      '/api/v1/payouts/account/refresh',
    );
    return PayoutAccountOut.fromJson(json as Map<String, Object?>);
  }
}

class ProfilesApi {
  ProfilesApi(this._transport);

  final ApiTransport _transport;

  /// Get Me
  ///
  /// The signed-in account, its profile and what is left of onboarding.
  ///
  /// `GET /api/v1/me`
  Future<MeOut> getMe() async {
    final json = await _transport.send('GET', '/api/v1/me');
    return MeOut.fromJson(json as Map<String, Object?>);
  }

  /// Put Profile
  ///
  /// Create or edit the profile. Every field is editable; the email isn't on it.
  ///
  /// `PUT /api/v1/me/profile`
  Future<ProfileOwn> putProfile(ProfileIn body) async {
    final json = await _transport.send(
      'PUT',
      '/api/v1/me/profile',
      body: body.toJson(),
    );
    return ProfileOwn.fromJson(json as Map<String, Object?>);
  }

  /// Accept Terms
  ///
  /// `POST /api/v1/me/terms`
  Future<MeOut> acceptTerms(TermsIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/me/terms',
      body: body.toJson(),
    );
    return MeOut.fromJson(json as Map<String, Object?>);
  }

  /// Get Profile
  ///
  /// Public view; residence is added for the counterparty of an approved
  /// booking, email and roll number for staff.
  ///
  /// `GET /api/v1/profiles/{account_id}`
  Future<ProfileView> getProfile(String accountId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/profiles/${Uri.encodeComponent(accountId)}',
    );
    return ProfileView.fromJson(json as Map<String, Object?>);
  }
}

class ReviewsApi {
  ReviewsApi(this._transport);

  final ApiTransport _transport;

  /// Pending Reviews
  ///
  /// Bookings waiting for my review. The app keeps the user here until they review.
  ///
  /// `GET /api/v1/me/pending-reviews`
  Future<List<BookingSummary>> pendingReviews() async {
    final json = await _transport.send('GET', '/api/v1/me/pending-reviews');
    return (json as List<Object?>)
        .map((e0) => BookingSummary.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Reviews Of
  ///
  /// Revealed reviews only.
  ///
  /// `GET /api/v1/profiles/{account_id}/reviews`
  Future<ReviewOutPage> reviewsOf(
    String accountId, {
    TrustRole? role,
    String? cursor,
    int? limit,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/profiles/${Uri.encodeComponent(accountId)}/reviews',
      query: {
        'role': ?role?.json,
        'cursor': ?cursor,
        'limit': ?limit?.toString(),
      },
    );
    return ReviewOutPage.fromJson(json as Map<String, Object?>);
  }
}

class SearchApi {
  SearchApi(this._transport);

  final ApiTransport _transport;

  /// Home
  ///
  /// Category shortcuts, recently listed, and new matches for saved searches.
  ///
  /// `GET /api/v1/home`
  Future<HomeOut> home() async {
    final json = await _transport.send('GET', '/api/v1/home');
    return HomeOut.fromJson(json as Map<String, Object?>);
  }

  /// List Saved Searches
  ///
  /// With the number of new matches since you last looked.
  ///
  /// `GET /api/v1/saved-searches`
  Future<List<SavedSearchOut>> listSavedSearches() async {
    final json = await _transport.send('GET', '/api/v1/saved-searches');
    return (json as List<Object?>)
        .map((e0) => SavedSearchOut.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Create Saved Search
  ///
  /// You get a push when a new listing matches.
  ///
  /// `POST /api/v1/saved-searches`
  Future<SavedSearchOut> createSavedSearch(SavedSearchIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/saved-searches',
      body: body.toJson(),
    );
    return SavedSearchOut.fromJson(json as Map<String, Object?>);
  }

  /// Delete Saved Search
  ///
  /// `DELETE /api/v1/saved-searches/{saved_search_id}`
  Future<void> deleteSavedSearch(String savedSearchId) async {
    await _transport.send(
      'DELETE',
      '/api/v1/saved-searches/${Uri.encodeComponent(savedSearchId)}',
    );
  }

  /// Search
  ///
  /// Active listings. Sorted by the owner's lender trust by default; New owners
  /// rank at the campus median.
  ///
  /// `GET /api/v1/search`
  Future<ListingCardPage> search({
    String? q,
    ListingCategory? category,
    TradeKind? kind,
    int? minPricePaise,
    int? maxPricePaise,
    DateTime? availableFrom,
    DateTime? availableTo,
    SearchSort? sort,
    String? cursor,
    int? limit,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/search',
      query: {
        'q': ?q,
        'category': ?category?.json,
        'kind': ?kind?.json,
        'min_price_paise': ?minPricePaise?.toString(),
        'max_price_paise': ?maxPricePaise?.toString(),
        'available_from': ?availableFrom?.toUtc().toIso8601String(),
        'available_to': ?availableTo?.toUtc().toIso8601String(),
        'sort': ?sort?.json,
        'cursor': ?cursor,
        'limit': ?limit?.toString(),
      },
    );
    return ListingCardPage.fromJson(json as Map<String, Object?>);
  }

  /// Suggest
  ///
  /// Type-ahead suggestions as the user types.
  ///
  /// `GET /api/v1/search/suggest`
  Future<List<Suggestion>> suggest({required String q}) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/search/suggest',
      query: {'q': q},
    );
    return (json as List<Object?>)
        .map((e0) => Suggestion.fromJson(e0! as Map<String, Object?>))
        .toList();
  }
}

class StaffApi {
  StaffApi(this._transport);

  final ApiTransport _transport;

  /// Appeals
  ///
  /// `GET /api/v1/staff/appeals`
  Future<List<AppealSummary>> appeals({AppealFilter? status}) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/staff/appeals',
      query: {'status': ?status?.json},
    );
    return (json as List<Object?>)
        .map((e0) => AppealSummary.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Appeal
  ///
  /// `GET /api/v1/staff/appeals/{appeal_id}`
  Future<AppealDetail> appeal(String appealId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/staff/appeals/${Uri.encodeComponent(appealId)}',
    );
    return AppealDetail.fromJson(json as Map<String, Object?>);
  }

  /// Rule
  ///
  /// `POST /api/v1/staff/appeals/{appeal_id}/ruling`
  Future<AppealDetail> rule(String appealId, RulingIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/staff/appeals/${Uri.encodeComponent(appealId)}/ruling',
      body: body.toJson(),
    );
    return AppealDetail.fromJson(json as Map<String, Object?>);
  }

  /// Escalations
  ///
  /// Overdue by an hour or more, owner escalations and stalled Proceeds.
  ///
  /// `GET /api/v1/staff/escalations`
  Future<List<EscalationOut>> escalations() async {
    final json = await _transport.send('GET', '/api/v1/staff/escalations');
    return (json as List<Object?>)
        .map((e0) => EscalationOut.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Listings
  ///
  /// `GET /api/v1/staff/listings`
  Future<ListingCardPage> listings({
    ListingStatus? status,
    String? q,
    String? cursor,
    int? limit,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/staff/listings',
      query: {
        'status': ?status?.json,
        'q': ?q,
        'cursor': ?cursor,
        'limit': ?limit?.toString(),
      },
    );
    return ListingCardPage.fromJson(json as Map<String, Object?>);
  }

  /// Remove Listing
  ///
  /// `POST /api/v1/staff/listings/{listing_id}/remove`
  Future<ListingCard> removeListing(String listingId, ReasonIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/staff/listings/${Uri.encodeComponent(listingId)}/remove',
      body: body.toJson(),
    );
    return ListingCard.fromJson(json as Map<String, Object?>);
  }

  /// Remove Review
  ///
  /// `POST /api/v1/staff/reviews/{review_id}/remove`
  Future<void> removeReview(String reviewId, ReasonIn body) async {
    await _transport.send(
      'POST',
      '/api/v1/staff/reviews/${Uri.encodeComponent(reviewId)}/remove',
      body: body.toJson(),
    );
  }

  /// Support Inbox
  ///
  /// `GET /api/v1/staff/support/threads`
  Future<List<SupportThreadSummary>> supportInbox({
    ThreadStatus? status,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/staff/support/threads',
      query: {'status': ?status?.json},
    );
    return (json as List<Object?>)
        .map((e0) => SupportThreadSummary.fromJson(e0! as Map<String, Object?>))
        .toList();
  }

  /// Support Thread
  ///
  /// `GET /api/v1/staff/support/threads/{thread_id}`
  Future<SupportThreadOut> supportThread(String threadId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/staff/support/threads/${Uri.encodeComponent(threadId)}',
    );
    return SupportThreadOut.fromJson(json as Map<String, Object?>);
  }

  /// Close Thread
  ///
  /// `POST /api/v1/staff/support/threads/{thread_id}/close`
  Future<SupportThreadOut> closeThread(String threadId) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/staff/support/threads/${Uri.encodeComponent(threadId)}/close',
    );
    return SupportThreadOut.fromJson(json as Map<String, Object?>);
  }

  /// Support Reply
  ///
  /// `POST /api/v1/staff/support/threads/{thread_id}/messages`
  Future<SupportMessage> supportReply(
    String threadId,
    SupportMessageIn body,
  ) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/staff/support/threads/${Uri.encodeComponent(threadId)}/messages',
      body: body.toJson(),
    );
    return SupportMessage.fromJson(json as Map<String, Object?>);
  }

  /// Users
  ///
  /// Search users; `flagged` lists only those with risk flags.
  ///
  /// `GET /api/v1/staff/users`
  Future<StaffUserRowPage> users({
    String? q,
    bool? flagged,
    String? cursor,
    int? limit,
  }) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/staff/users',
      query: {
        'q': ?q,
        'flagged': ?flagged?.toString(),
        'cursor': ?cursor,
        'limit': ?limit?.toString(),
      },
    );
    return StaffUserRowPage.fromJson(json as Map<String, Object?>);
  }

  /// User
  ///
  /// `GET /api/v1/staff/users/{account_id}`
  Future<StaffUserDetail> user(String accountId) async {
    final json = await _transport.send(
      'GET',
      '/api/v1/staff/users/${Uri.encodeComponent(accountId)}',
    );
    return StaffUserDetail.fromJson(json as Map<String, Object?>);
  }

  /// Set Status
  ///
  /// `POST /api/v1/staff/users/{account_id}/status`
  Future<StaffUserDetail> setStatus(
    String accountId,
    StatusChangeIn body,
  ) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/staff/users/${Uri.encodeComponent(accountId)}/status',
      body: body.toJson(),
    );
    return StaffUserDetail.fromJson(json as Map<String, Object?>);
  }

  /// Trust Penalty
  ///
  /// `POST /api/v1/staff/users/{account_id}/trust-penalty`
  Future<StaffUserDetail> trustPenalty(String accountId, PenaltyIn body) async {
    final json = await _transport.send(
      'POST',
      '/api/v1/staff/users/${Uri.encodeComponent(accountId)}/trust-penalty',
      body: body.toJson(),
    );
    return StaffUserDetail.fromJson(json as Map<String, Object?>);
  }
}
