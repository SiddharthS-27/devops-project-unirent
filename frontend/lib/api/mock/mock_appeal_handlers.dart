import '../generated/models.dart';
import 'mock_booking_handlers.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_handlers.dart';
import 'mock_server.dart';

const _maxAppealPhotos = 8;

class MockAppeal {
  MockAppeal({
    required this.id,
    required this.bookingId,
    required this.filedById,
    required this.filedBy,
    required this.reason,
    required this.notes,
    required this.photoKeys,
    required this.previousStatus,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String filedById;
  final TradeRole filedBy;
  final AppealReason reason;
  final String notes;
  final List<String> photoKeys;

  /// Where the booking goes back to once ruled.
  final BookingStatus previousStatus;
  final DateTime createdAt;
  AppealStatus status = AppealStatus.open;
}

/// The booking's latest appeal.
MockAppeal? mockLatestAppeal(MockDb db, String bookingId) => db.appeals.values
    .where((a) => a.bookingId == bookingId)
    .fold<MockAppeal?>(
      null,
      (latest, a) => latest == null || !a.createdAt.isBefore(latest.createdAt)
          ? a
          : latest,
    );

/// Backend `appeals.can_file`: either side once a rental's return is done,
/// or the buyer within 48 hours of a sale's handover; not while an appeal
/// is open.
bool mockCanAppeal(MockDb db, MockBooking b, TradeRole? role, DateTime now) {
  if (role == null) return false;
  if (mockLatestAppeal(db, b.id)?.status == AppealStatus.open) return false;
  if (b.kind == TradeKind.rent) {
    return b.status == BookingStatus.returning && b.returnCompletedAt != null;
  }
  final handedOver = b.pickupCompletedAt;
  return role == TradeRole.renter &&
      handedOver != null &&
      now.difference(handedOver) < const Duration(hours: 48) &&
      const {
        BookingStatus.awaitingReviews,
        BookingStatus.completed,
      }.contains(b.status);
}

AppealOut mockAppealOut(MockAppeal a) => AppealOut(
  id: a.id,
  bookingId: a.bookingId,
  status: a.status,
  reason: a.reason.json,
  notes: a.notes,
  filedBy: a.filedBy,
  createdAt: a.createdAt,
);

Map<String, MockHandler> appealHandlers(MockDb db) {
  final h = MockBookingHandlers(db);
  return {
    'POST /api/v1/bookings/{booking_id}/appeals': h.idempotent((r) {
      final actor = h.account(r);
      final b = h.booking(r, actor);
      final role = b.roleOf(actor.id);
      if (role == null) {
        throw const MockApiError(
          403,
          'NOT_YOUR_STEP',
          'Only the two sides can appeal',
        );
      }
      if (!mockCanAppeal(db, b, role, h.now)) {
        throw const MockApiError(
          409,
          'APPEAL_NOT_OPEN',
          "This booking can't be appealed now",
        );
      }
      final body = mockParse(r, AppealCreate.fromJson);
      if (body.reason == AppealReason.unknown) {
        throw mockValidation('reason', 'Input should be a known reason');
      }
      if (body.notes.length < 5 || body.notes.length > 2000) {
        throw mockValidation('notes', 'Must be 5-2000 characters');
      }
      final keys = body.photoKeys ?? const [];
      if (keys.length > _maxAppealPhotos) {
        throw mockValidation('photo_keys', 'At most 8 photos');
      }
      for (final key in keys) {
        if (db.uploadOwners[key] != actor.id || !key.startsWith('appeal/')) {
          throw const MockApiError(
            422,
            'INVALID_PHOTO',
            "That photo upload isn't yours",
          );
        }
        if (!db.uploadedKeys.contains(key)) {
          throw const MockApiError(
            422,
            'PHOTO_NOT_UPLOADED',
            'Upload the photo before confirming it',
          );
        }
      }
      final appeal = MockAppeal(
        id: db.nextId(),
        bookingId: b.id,
        filedById: actor.id,
        filedBy: role,
        reason: body.reason,
        notes: body.notes,
        photoKeys: [...keys],
        previousStatus: b.status,
        createdAt: h.now,
      );
      db.appeals[appeal.id] = appeal;
      h.moveTo(b, BookingStatus.inAppeal);
      return MockResponse(201, mockAppealOut(appeal).toJson());
    }),
  };
}
