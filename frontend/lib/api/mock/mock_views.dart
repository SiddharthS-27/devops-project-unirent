import '../generated/models.dart';
import 'mock_bookings.dart';
import 'mock_db.dart';
import 'mock_server.dart';

/// Fewer completed trades than this shows the New badge (backend rule).
const mockNewBadgeTrades = 5;

/// The full profile of [account] as its owner sees it.
ProfileOwn mockOwnProfile(MockDb db, MockAccount account) {
  final p = db.profiles[account.id]!.data;
  return ProfileOwn(
    accountId: account.id,
    fullName: p.fullName,
    photoUrl: null,
    photoKey: p.photoKey,
    department: p.department,
    year: p.year,
    phone: account.phone,
    lender: TrustSummary(
      score: account.lenderScore,
      rating: account.lenderRating,
      reviewCount: account.completedTrades,
    ),
    renter: TrustSummary(
      score: account.renterScore,
      rating: account.renterRating,
      reviewCount: account.renterReviews,
    ),
    isNew: account.completedTrades < mockNewBadgeTrades,
    completedTrades: account.completedTrades,
    cancellationCount: account.cancellationCount,
    memberSince: account.createdAt,
    residence: Residence(
      type: p.residenceType,
      hostelName: p.hostelName,
      roomNumber: p.roomNumber,
      homeAddress: p.homeAddress,
    ),
    email: account.email,
    rollNumber: p.rollNumber,
    status: account.status,
  );
}

/// True when the two share a booking that is approved or later.
bool mockIsCounterparty(MockDb db, String a, String b) =>
    db.bookings.values.any(
      (bk) =>
          mockHoldsSlot.contains(bk.status) &&
          ((bk.renterId == a && bk.ownerId == b) ||
              (bk.renterId == b && bk.ownerId == a)),
    );

/// [subjectId]'s profile as [viewer] may see it: everything for themselves
/// and staff, residence for a counterparty after approval, else public.
ProfileView mockProfileFor(MockDb db, String subjectId, MockAccount viewer) {
  final account = db.accounts[subjectId];
  if (account == null || db.profiles[subjectId] == null) {
    throw const MockApiError(404, 'NOT_FOUND', 'Profile not found');
  }
  final own = mockOwnProfile(db, account);
  if (viewer.id == subjectId) return own;
  if (viewer.isStaff) {
    return ProfileStaff(
      accountId: own.accountId,
      fullName: own.fullName,
      photoUrl: own.photoUrl,
      department: own.department,
      year: own.year,
      phone: own.phone,
      lender: own.lender,
      renter: own.renter,
      isNew: own.isNew,
      completedTrades: own.completedTrades,
      cancellationCount: own.cancellationCount,
      memberSince: own.memberSince,
      residence: own.residence,
      email: own.email,
      rollNumber: own.rollNumber,
      status: own.status,
    );
  }
  if (mockIsCounterparty(db, viewer.id, subjectId)) {
    return ProfileCounterparty(
      accountId: own.accountId,
      fullName: own.fullName,
      photoUrl: own.photoUrl,
      department: own.department,
      year: own.year,
      phone: own.phone,
      lender: own.lender,
      renter: own.renter,
      isNew: own.isNew,
      completedTrades: own.completedTrades,
      cancellationCount: own.cancellationCount,
      memberSince: own.memberSince,
      residence: own.residence,
    );
  }
  return ProfilePublic(
    accountId: own.accountId,
    fullName: own.fullName,
    photoUrl: own.photoUrl,
    department: own.department,
    year: own.year,
    phone: own.phone,
    lender: own.lender,
    renter: own.renter,
    isNew: own.isNew,
    completedTrades: own.completedTrades,
    cancellationCount: own.cancellationCount,
    memberSince: own.memberSince,
  );
}
