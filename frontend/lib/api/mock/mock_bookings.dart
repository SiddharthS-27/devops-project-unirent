import '../generated/models.dart';
import 'mock_appeal_handlers.dart';
import 'mock_db.dart';
import 'mock_listing_handlers.dart' show mockListingCard;
import 'mock_listings.dart';
import 'mock_review_handlers.dart';
import 'mock_views.dart';

// The mock booking lifecycle mirrors backend/app/modules/bookings: the same
// statuses, timeline steps, next-action keys and pricing rules.

/// Approved and every later status hold the rental slot.
const mockHoldsSlot = {
  BookingStatus.approved,
  BookingStatus.active,
  BookingStatus.overdue,
  BookingStatus.returning,
  BookingStatus.inAppeal,
  BookingStatus.awaitingReviews,
  BookingStatus.completed,
};

const mockBookingGroups = {
  BookingGroup.pending: {BookingStatus.requested},
  BookingGroup.upcoming: {BookingStatus.approved},
  BookingGroup.active: {
    BookingStatus.active,
    BookingStatus.overdue,
    BookingStatus.returning,
    BookingStatus.inAppeal,
    BookingStatus.awaitingReviews,
  },
  BookingGroup.past: {
    BookingStatus.completed,
    BookingStatus.declined,
    BookingStatus.withdrawn,
    BookingStatus.expired,
  },
  BookingGroup.cancelled: {BookingStatus.cancelled},
};

const mockMinRentalHours = 1;
const mockMaxRentalDays = 30;
const mockOtpTtl = Duration(minutes: 15);
const mockOtpMaxTries = 5;
const mockEscalationAfter = Duration(hours: 1);

/// Whole hours, rounded up.
int mockRentalHours(DateTime start, DateTime end) =>
    (end.difference(start).inSeconds / 3600).ceil();

/// The cheapest mix of the listing's rates (backend `rent_for`).
int mockRentFor(MockListing l, int hours) {
  final day = l.pricePerDayPaise;
  final hour = l.pricePerHourPaise;
  if (day != null && hour != null) {
    final days = hours ~/ 24;
    final rest = hours % 24;
    final partial = rest * hour;
    return days * day + (partial < day ? partial : day);
  }
  if (day != null) return (hours / 24).ceil() * day;
  return hours * (hour ?? 0);
}

/// The late fee for [overdueMinutes] past the end (backend `calculate`).
int mockLateFee(LateFeeRuleOut rule, int rentPaise, int overdueMinutes) {
  final pastGrace = overdueMinutes - rule.graceMinutes;
  if (pastGrace <= 0) return 0;
  final hours = pastGrace ~/ 60;
  final hourly = rentPaise * rule.hourlyPercentBp * hours ~/ 10000;
  final fee = rule.baseFeePaise + hourly;
  return ((fee + 50) ~/ 100) * 100;
}

enum MockPhase { pickup, returnPhase }

class MockPayment {
  MockPayment({
    required this.id,
    required this.bookingId,
    required this.purpose,
    required this.method,
    required this.amountPaise,
    required this.items,
    required this.createdAt,
    required this.payerId,
    required this.payeeId,
    this.ref,
    this.orderId,
  });

  final String id;
  final String bookingId;
  final PaymentPurpose purpose;

  /// Extension id for extension payments.
  final String? ref;
  final PaymentMethod method;
  final int amountPaise;
  final List<PaymentItem> items;
  final DateTime createdAt;
  final String payerId;
  final String payeeId;
  final String? orderId;
  PaymentStatus status = PaymentStatus.pending;
  DateTime? capturedAt;

  /// Set when the payer completed (simulated) Checkout; captured on verify.
  String? razorpayPaymentId;

  final refunds = <MockRefund>[];

  bool get isPaid =>
      status == PaymentStatus.captured || status == PaymentStatus.markedPaid;

  /// Refunds that have reached the payer.
  int get refundedPaise => refunds
      .where(
        (r) =>
            r.status == RefundOutStatus.processed ||
            r.status == RefundOutStatus.cashDone,
      )
      .fold(0, (sum, r) => sum + r.amountPaise);
}

class MockRefund {
  MockRefund({
    required this.id,
    required this.amountPaise,
    required this.method,
    required this.createdAt,
    this.status = RefundOutStatus.pending,
  });

  final String id;
  final int amountPaise;
  final PaymentMethod method;
  final DateTime createdAt;
  RefundOutStatus status;
  DateTime? processedAt;
}

class MockExtension {
  MockExtension({
    required this.id,
    required this.newEndAt,
    required this.amountPaise,
    required this.createdAt,
  });

  final String id;
  final DateTime newEndAt;
  final int amountPaise;
  final DateTime createdAt;
  ExtensionStatus status = ExtensionStatus.requested;
  bool payInCashAtReturn = false;
}

class MockCancellation {
  MockCancellation({required this.by, required this.note, required this.at});

  final TradeRole by;
  final String note;
  final DateTime at;
  int? ratingStars;
  String? ratingComment;
  DateTime? ratedAt;
}

class MockOtp {
  MockOtp(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;
  int tries = 0;
  bool used = false;
}

class MockBooking {
  MockBooking({
    required this.id,
    required this.listingId,
    required this.kind,
    required this.renterId,
    required this.ownerId,
    required this.amountPaise,
    required this.createdAt,
    this.startAt,
    this.endAt,
    this.status = BookingStatus.requested,
  }) : updatedAt = createdAt;

  final String id;
  final String listingId;
  final TradeKind kind;
  final String renterId;
  final String ownerId;
  DateTime? startAt;
  DateTime? endAt;
  int amountPaise;
  final DateTime createdAt;
  BookingStatus status;
  DateTime updatedAt;
  DateTime? decidedAt;
  String? declineReason;
  DateTime? pickupCompletedAt;
  DateTime? returnStartedAt;
  DateTime? returnCompletedAt;
  DateTime? proceededAt;
  DateTime? completedAt;
  DateTime? overdueSince;
  DateTime? escalatedAt;
  String? escalationNote;

  /// Frozen when the item is back; null means "still counting".
  int? frozenLateFeePaise;
  int damagePaise = 0;
  String? damageDescription;

  final photos = <(MockPhase, TradeRole), List<MockPhoto>>{};
  final payments = <MockPayment>[];
  final extensions = <MockExtension>[];
  final otps = <MockPhase, MockOtp>{};
  MockCancellation? cancellation;

  TradeRole? roleOf(String accountId) => accountId == renterId
      ? TradeRole.renter
      : accountId == ownerId
      ? TradeRole.owner
      : null;

  bool hasPhotos(MockPhase phase, TradeRole side) =>
      photos[(phase, side)]?.isNotEmpty ?? false;

  PaymentPurpose get handoverPurpose =>
      kind == TradeKind.rent ? PaymentPurpose.rent : PaymentPurpose.sale;

  /// The latest non-failed payment for [purpose] (and [ref]).
  MockPayment? paymentFor(PaymentPurpose purpose, [String? ref]) => payments
      .where(
        (p) =>
            p.purpose == purpose &&
            p.ref == ref &&
            p.status != PaymentStatus.failed,
      )
      .lastOrNull;

  int overdueMinutes(DateTime now) {
    final end = endAt;
    if (end == null) return 0;
    final minutes = now.difference(end).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  int liveLateFee(DateTime now) {
    final frozen = frozenLateFeePaise;
    if (frozen != null) return frozen;
    if (kind != TradeKind.rent) return 0;
    return mockLateFee(mockLateFeeRule(now), amountPaise, overdueMinutes(now));
  }

  /// Approved extensions not paid by UPI: owed at the return (backend
  /// `unpaid_cash_extensions`).
  int get cashExtensionsPaise => extensions
      .where(
        (e) =>
            e.status == ExtensionStatus.approved &&
            !(paymentFor(PaymentPurpose.extension, e.id)?.isPaid ?? false),
      )
      .fold(0, (sum, e) => sum + e.amountPaise);

  DateTime? get escalationAvailableAt => overdueSince?.add(mockEscalationAfter);

  bool canEscalate(DateTime now) {
    final at = escalationAvailableAt;
    return status == BookingStatus.overdue && at != null && !now.isBefore(at);
  }
}

/// Builds the API views of mock bookings.
class MockBookingViews {
  MockBookingViews(this.db);

  final MockDb db;

  DateTime get now => db.clock().toUtc();

  static const _rentSteps = [
    ('requested', 'Requested'),
    ('approved', 'Approved'),
    ('pickup', 'Pickup'),
    ('active', 'Rental active'),
    ('return', 'Return'),
    ('proceed', 'Charges and Proceed'),
    ('reviews', 'Reviews'),
    ('completed', 'Completed'),
  ];
  static const _saleSteps = [
    ('requested', 'Requested'),
    ('approved', 'Approved'),
    ('pickup', 'Handover'),
    ('reviews', 'Reviews'),
    ('completed', 'Completed'),
  ];
  static const _currentStep = {
    BookingStatus.requested: 'requested',
    BookingStatus.approved: 'pickup',
    BookingStatus.active: 'active',
    BookingStatus.overdue: 'active',
    BookingStatus.returning: 'return',
    BookingStatus.inAppeal: 'proceed',
    BookingStatus.awaitingReviews: 'reviews',
    BookingStatus.completed: 'completed',
  };
  static const _ended = {
    BookingStatus.declined: 'Declined',
    BookingStatus.withdrawn: 'Withdrawn',
    BookingStatus.expired: 'Expired',
    BookingStatus.cancelled: 'Cancelled',
  };

  List<TimelineStep> timeline(MockBooking b) {
    final steps = b.kind == TradeKind.rent ? _rentSteps : _saleSteps;
    final endedLabel = _ended[b.status];
    if (endedLabel != null) {
      final reached = b.status == BookingStatus.cancelled
          ? 'approved'
          : 'requested';
      final out = <TimelineStep>[];
      for (final (key, label) in steps) {
        out.add(
          TimelineStep(key: key, label: label, state: TimelineStepState.done),
        );
        if (key == reached) break;
      }
      out.add(
        TimelineStep(
          key: b.status.json,
          label: endedLabel,
          state: TimelineStepState.current,
          at: b.updatedAt,
        ),
      );
      return out;
    }
    final keys = [for (final (k, _) in steps) k];
    var index = keys.indexOf(_currentStep[b.status]!);
    // A sale has no "proceed" step; its appeal comes after the handover.
    if (index < 0) index = keys.indexOf('reviews');
    if (b.status == BookingStatus.completed) index = keys.length;
    final stamps = {
      'requested': b.createdAt,
      'approved': b.decidedAt,
      'pickup': b.pickupCompletedAt,
      'return': b.returnCompletedAt,
      'proceed': b.proceededAt,
      'completed': b.completedAt,
    };
    return [
      for (final (i, (key, label)) in steps.indexed)
        TimelineStep(
          key: key,
          label: label,
          state: i < index
              ? TimelineStepState.done
              : i == index
              ? TimelineStepState.current
              : TimelineStepState.upcoming,
          at: i < index ? stamps[key] : null,
        ),
    ];
  }

  static NextAction _action(String key, String label, bool byMe) =>
      NextAction(key: key, label: label, byMe: byMe);

  NextAction? nextAction(MockBooking b, TradeRole? role) {
    if (role == null) return null;
    final other = role == TradeRole.renter ? TradeRole.owner : TradeRole.renter;
    final renter = role == TradeRole.renter;
    switch (b.status) {
      case BookingStatus.cancelled:
        final c = b.cancellation;
        if (c != null && c.by != role && c.ratedAt == null) {
          return _action(
            'rate_cancellation',
            'Read the reason and rate the cancellation',
            true,
          );
        }
        return null;
      case BookingStatus.requested:
        return renter
            ? _action('waiting_owner', 'Waiting for the owner', false)
            : _action('decide_request', 'Approve or decline the request', true);
      case BookingStatus.approved:
        if (!b.hasPhotos(MockPhase.pickup, role)) {
          return _action('upload_pickup_photos', 'Upload pickup photos', true);
        }
        if (!b.hasPhotos(MockPhase.pickup, other)) {
          return _action(
            'waiting_pickup_photos',
            'Waiting for their photos',
            false,
          );
        }
        final payment = b.paymentFor(b.handoverPurpose);
        if (payment == null || !payment.isPaid) {
          final cash = payment?.method == PaymentMethod.cash;
          if (renter) {
            return cash
                ? _action(
                    'waiting_cash_mark',
                    'Waiting for cash to be marked',
                    false,
                  )
                : _action('pay', 'Pay by UPI or cash', true);
          }
          return cash
              ? _action('mark_cash_received', 'Mark cash received', true)
              : _action('waiting_payment', 'Waiting for payment', false);
        }
        return renter
            ? _action('show_otp', 'Show your code to the owner', true)
            : _action('enter_otp', 'Enter the renter\'s code', true);
      case BookingStatus.active:
        final pending = b.extensions
            .where((e) => e.status == ExtensionStatus.requested)
            .firstOrNull;
        if (pending != null) {
          return renter
              ? _action(
                  'waiting_extension',
                  'Waiting for the owner about more time',
                  false,
                )
              : _action(
                  'decide_extension',
                  'Approve or decline more time',
                  true,
                );
        }
        final unpaid = b.extensions.any(
          (e) =>
              e.status == ExtensionStatus.approved &&
              !e.payInCashAtReturn &&
              !(b.paymentFor(PaymentPurpose.extension, e.id)?.isPaid ?? false),
        );
        if (unpaid && renter) {
          return _action('pay_extension', 'Pay for the extra time', true);
        }
        return renter
            ? _action('return_on_time', 'Return the item on time', false)
            : _action('rental_active', 'Rental in progress', false);
      case BookingStatus.returning:
        return _returnAction(b, role);
      case BookingStatus.awaitingReviews:
        final mine = mockReviewsOf(
          db,
          b.id,
        ).any((r) => r.reviewerId == (renter ? b.renterId : b.ownerId));
        return mine
            ? _action('waiting_review', 'Waiting for their review', false)
            : _action(
                'write_review',
                'Review the other side to continue',
                true,
              );
      case BookingStatus.inAppeal:
        return _action(
          'waiting_ruling',
          'Waiting for the moderators to rule',
          false,
        );
      case BookingStatus.overdue:
        if (renter) {
          return _action('return_now', 'Overdue: return the item now', true);
        }
        if (b.escalatedAt == null && b.canEscalate(now)) {
          return _action(
            'escalate',
            'You can escalate to the moderators',
            true,
          );
        }
        return _action('waiting_return', 'Waiting for the return', false);
      default:
        return null;
    }
  }

  NextAction _returnAction(MockBooking b, TradeRole role) {
    final renter = role == TradeRole.renter;
    if (!b.hasPhotos(MockPhase.returnPhase, TradeRole.renter)) {
      return renter
          ? _action('upload_return_photos', 'Upload return photos', true)
          : _action(
              'waiting_return_photos',
              'Waiting for the renter\'s photos',
              false,
            );
    }
    if (!b.hasPhotos(MockPhase.returnPhase, TradeRole.owner)) {
      return renter
          ? _action(
              'waiting_inspection',
              'The owner is inspecting the item',
              false,
            )
          : _action('inspect_item', 'Inspect the item and upload photos', true);
    }
    if (b.returnCompletedAt == null) {
      return renter
          ? _action('enter_return_otp', 'Enter the owner\'s code', true)
          : _action('show_return_otp', 'Show your code to the renter', true);
    }
    final c = charges(b);
    if (c != null && !c.paid) {
      final cash = c.payment?.method == PaymentMethod.cash;
      if (renter) {
        return cash
            ? _action(
                'waiting_cash_mark',
                'Waiting for cash to be marked',
                false,
              )
            : _action('pay_charges', 'Pay the charges', true);
      }
      return cash
          ? _action('mark_cash_received', 'Mark cash received', true)
          : _action(
              'record_damage_or_wait',
              'Record any damage, or wait for payment',
              true,
            );
    }
    return renter
        ? _action('waiting_proceed', 'Waiting for the owner to finish', false)
        : _action('proceed', 'Tap Proceed to finish', true);
  }

  Handover? handover(MockBooking b, MockPhase phase) {
    if (phase == MockPhase.pickup &&
        const {
          BookingStatus.requested,
          BookingStatus.declined,
          BookingStatus.withdrawn,
          BookingStatus.expired,
        }.contains(b.status)) {
      return null;
    }
    if (phase == MockPhase.returnPhase && b.returnStartedAt == null) {
      return null;
    }
    HandoverSide side(TradeRole role) {
      final photos = b.photos[(phase, role)] ?? const [];
      return HandoverSide(
        photos: [for (final p in photos) PhotoOut(id: p.id, url: p.url)],
        done: photos.isNotEmpty,
      );
    }

    final renter = side(TradeRole.renter);
    final owner = side(TradeRole.owner);
    final bool ready;
    final DateTime? verified;
    if (phase == MockPhase.pickup) {
      final paid = b.paymentFor(b.handoverPurpose)?.isPaid ?? false;
      ready = renter.done && owner.done && paid;
      verified = b.pickupCompletedAt;
    } else {
      ready = renter.done && owner.done;
      verified = b.returnCompletedAt;
    }
    return Handover(
      phase: phase == MockPhase.pickup
          ? HandoverPhase.pickup
          : HandoverPhase.returnValue,
      renter: renter,
      owner: owner,
      otpReady: ready && verified == null,
      otpShownBy: phase == MockPhase.pickup
          ? TradeRole.renter
          : TradeRole.owner,
      otpVerifiedAt: verified,
    );
  }

  Charges? charges(MockBooking b) {
    if (b.kind != TradeKind.rent || b.pickupCompletedAt == null) return null;
    final late = b.liveLateFee(now);
    final total = late + b.damagePaise + b.cashExtensionsPaise;
    if (total == 0 && b.returnStartedAt == null) return null;
    final payment = b.paymentFor(PaymentPurpose.returnCharges);
    return Charges(
      lateFeePaise: late,
      overdueMinutes: b.frozenLateFeePaise == null ? b.overdueMinutes(now) : 0,
      damagePaise: b.damagePaise,
      damageDescription: b.damageDescription,
      cashExtensionsPaise: b.cashExtensionsPaise,
      totalPaise: total,
      paid: total == 0 || (payment?.isPaid ?? false),
      payment: payment == null ? null : paymentOut(payment),
    );
  }

  PaymentOut paymentOut(MockPayment p) {
    final payer = db.accounts[p.payerId];
    final pending =
        p.method == PaymentMethod.upi &&
        (p.status == PaymentStatus.created ||
            p.status == PaymentStatus.pending);
    return PaymentOut(
      id: p.id,
      purpose: p.purpose,
      method: p.method,
      status: p.status,
      amountPaise: p.amountPaise,
      items: p.items,
      checkout: pending && p.orderId != null
          ? RazorpayCheckout(
              keyId: 'rzp_test_mock',
              orderId: p.orderId!,
              amountPaise: p.amountPaise,
              name: 'UniRent',
              description: p.items.map((i) => i.label).join(', '),
              prefillEmail: payer?.email,
              prefillContact: payer?.phone,
            )
          : null,
      createdAt: p.createdAt,
      capturedAt: p.capturedAt,
    );
  }

  ExtensionOut extensionOut(MockBooking b, MockExtension e) {
    final payment = b.paymentFor(PaymentPurpose.extension, e.id);
    return ExtensionOut(
      id: e.id,
      newEndAt: e.newEndAt,
      status: e.status,
      amountPaise: e.amountPaise,
      payment: payment == null ? null : paymentOut(payment),
      payInCashAtReturn: e.payInCashAtReturn,
      createdAt: e.createdAt,
    );
  }

  CancellationInfo? cancellation(MockBooking b, TradeRole? role) {
    final c = b.cancellation;
    if (c == null) return null;
    return CancellationInfo(
      by: c.by,
      note: c.note,
      at: c.at,
      ratingDue: role != null && c.by != role && c.ratedAt == null,
    );
  }

  BookingOut out(MockBooking b, MockAccount viewer) {
    final role = b.roleOf(viewer.id);
    final listing = db.listings[b.listingId]!;
    return BookingOut(
      id: b.id,
      kind: b.kind,
      status: b.status,
      role: switch (role) {
        TradeRole.renter => BookingViewerRole.renter,
        TradeRole.owner => BookingViewerRole.owner,
        _ => BookingViewerRole.staff,
      },
      listing: mockListingCard(db, listing),
      renter: mockProfileFor(db, b.renterId, viewer),
      owner: mockProfileFor(db, b.ownerId, viewer),
      startAt: b.startAt,
      endAt: b.endAt,
      amountPaise: b.amountPaise,
      lateFeeRule: b.kind == TradeKind.rent ? mockLateFeeRule(now) : null,
      timeline: timeline(b),
      nextAction: nextAction(b, role),
      pickup: handover(b, MockPhase.pickup),
      returnHandover: handover(b, MockPhase.returnPhase),
      payments: [for (final p in b.payments) paymentOut(p)],
      extensions: [
        if (b.pickupCompletedAt != null)
          for (final e in b.extensions) extensionOut(b, e),
      ],
      charges: charges(b),
      cancellation: cancellation(b, role),
      appeal: switch (mockLatestAppeal(db, b.id)) {
        null => null,
        final a => AppealRef(id: a.id, status: a.status),
      },
      reviews: mockReviewState(db, b, viewer.id),
      overdueSince: b.overdueSince,
      escalationAvailableAt: b.escalationAvailableAt,
      canCancel:
          b.status == BookingStatus.approved &&
          role != null &&
          !b.payments.any(
            (p) =>
                p.isPaid &&
                (p.purpose == PaymentPurpose.rent ||
                    p.purpose == PaymentPurpose.sale),
          ),
      canEscalate:
          role == TradeRole.owner &&
          b.escalatedAt == null &&
          b.canEscalate(now),
      canAppeal: mockCanAppeal(db, b, role, now),
      serverNow: now,
      createdAt: b.createdAt,
    );
  }

  BookingSummary summary(MockBooking b, TradeRole role) {
    final otherId = role == TradeRole.renter ? b.ownerId : b.renterId;
    final other = db.accounts[otherId]!;
    final listing = db.listings[b.listingId]!;
    return BookingSummary(
      id: b.id,
      kind: b.kind,
      status: b.status,
      role: role,
      listingId: b.listingId,
      listingTitle: listing.title,
      listingPhotoUrl: listing.photos.firstOrNull?.url,
      counterpartyId: otherId,
      counterpartyName:
          db.profiles[otherId]?.data.fullName ?? other.name ?? 'UniRent user',
      startAt: b.startAt,
      endAt: b.endAt,
      amountPaise: b.amountPaise,
      nextAction: nextAction(b, role),
      updatedAt: b.updatedAt,
    );
  }
}
