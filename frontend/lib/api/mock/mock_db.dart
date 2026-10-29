import '../generated/models.dart';
import 'mock_appeal_handlers.dart' show MockAppeal;
import 'mock_booking_handlers.dart' show seedBookings;
import 'mock_bookings.dart';
import 'mock_help_handlers.dart' show MockSupportThread;
import 'mock_listings.dart';
import 'mock_review_handlers.dart' show MockReview;
import 'mock_server.dart';
import 'mock_staff_handlers.dart' show MockRuling, MockTrustPenalty;

/// Terms version the mock backend expects (mirrors the backend constant).
const mockTermsVersion = '2026-10';

/// Only emails at this domain may sign in with Microsoft.
const mockCollegeDomain = 'college.edu';

/// The code the mock phone verification accepts.
const mockOtpCode = '123456';

class MockAccount {
  MockAccount({
    required this.id,
    required this.email,
    required this.role,
    this.status = 'active',
    this.password,
    this.mustChangePassword = false,
    this.name,
    this.phone,
    this.phoneVerifiedAt,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String role;
  String status;
  String? password;
  bool mustChangePassword;
  String? name;
  String? phone;
  DateTime? phoneVerifiedAt;
  final DateTime createdAt;

  /// Lender trust score; null while the user is New.
  int? lenderScore;
  double? lenderRating;
  int completedTrades = 0;
  int cancellationCount = 0;

  /// Renter-side trust; null while the user is New.
  int? renterScore;
  double? renterRating;
  int renterReviews = 0;

  /// Razorpay linked account state; listings need it `activated`.
  PayoutAccountOutStatus payoutStatus = PayoutAccountOutStatus.none;
  String? razorpayAccountId;
  DateTime? payoutUpdatedAt;

  bool get payoutReady => payoutStatus == PayoutAccountOutStatus.activated;

  bool get isStaff => role == 'moderator' || role == 'admin';
}

class MockProfile {
  MockProfile({required this.data, this.termsVersion});

  ProfileIn data;
  String? termsVersion;
}

/// The mock backend's in-memory state.
class MockDb {
  MockDb({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  /// A database with a few ready-made accounts:
  ///
  /// - `admin@unirent.in` / `admin-password` (admin)
  /// - `moderator@unirent.in` / `temporary-password` (moderator, must change
  ///   password on first sign-in)
  /// - `asha@college.edu` (student, fully onboarded; phone +919876500001)
  /// - `karan@`, `meera@` (New owner) and `dev@college.edu`: more students
  ///
  /// plus ~20 listings across every category (see `seedListings`).
  factory MockDb.seeded({DateTime Function()? clock}) {
    final db = MockDb(clock: clock);
    final now = db.clock().toUtc();
    db
      ..addAccount(
        MockAccount(
          id: '00000000-0000-4000-8000-000000000001',
          email: 'admin@unirent.in',
          role: 'admin',
          name: 'UniRent Admin',
          password: 'admin-password',
          createdAt: now.subtract(const Duration(days: 120)),
        ),
      )
      ..addAccount(
        MockAccount(
          id: '00000000-0000-4000-8000-000000000002',
          email: 'moderator@unirent.in',
          role: 'moderator',
          name: 'Campus Moderator',
          password: 'temporary-password',
          mustChangePassword: true,
          createdAt: now.subtract(const Duration(days: 30)),
        ),
      );
    final asha = db.addAccount(
      MockAccount(
        id: '00000000-0000-4000-8000-000000000101',
        email: 'asha@college.edu',
        role: 'student',
        name: 'Asha Verma',
        phone: '+919876500001',
        phoneVerifiedAt: now.subtract(const Duration(days: 60)),
        createdAt: now.subtract(const Duration(days: 60)),
      ),
    );
    db.profiles[asha.id] = MockProfile(
      data: const ProfileIn(
        fullName: 'Asha Verma',
        rollNumber: '21CS1042',
        department: 'Computer Science',
        year: 3,
        residenceType: ResidenceType.hostel,
        hostelName: 'Ganga Hostel',
        roomNumber: 'B-214',
      ),
      termsVersion: mockTermsVersion,
    );
    seedListings(db);
    seedBookings(db);
    return db;
  }

  final DateTime Function() clock;

  final accounts = <String, MockAccount>{};
  final profiles = <String, MockProfile>{};

  /// Access token → account id.
  final accessTokens = <String, String>{};

  /// Access tokens that now answer 401 TOKEN_EXPIRED.
  final expiredAccessTokens = <String>{};

  /// Live refresh token → account id.
  final refreshTokens = <String, String>{};

  /// Refresh tokens already exchanged (a reuse revokes the session).
  final usedRefreshTokens = <String>{};

  /// Push token → account id.
  final pushTokens = <String, String>{};

  final listings = <String, MockListing>{};
  final assets = <String, MockAsset>{};
  final savedSearches = <String, MockSavedSearch>{};

  /// Presigned upload keys → the account that requested them.
  final uploadOwners = <String, String>{};

  /// Keys whose bytes were PUT to their upload URL.
  final uploadedKeys = <String>{};

  final bookings = <String, MockBooking>{};
  final reviews = <MockReview>[];
  final supportThreads = <String, MockSupportThread>{};
  final appeals = <String, MockAppeal>{};
  final rulings = <MockRuling>[];
  final trustPenalties = <MockTrustPenalty>[];

  /// Replayed responses by `account:Idempotency-Key`.
  final idempotentResponses = <String, MockResponse>{};

  int _sequence = 0;

  /// Number of successful refreshes, for tests.
  int refreshCount = 0;

  MockAccount addAccount(MockAccount account) => accounts[account.id] = account;

  MockAccount? accountByEmail(String email) {
    final lower = email.toLowerCase();
    return accounts.values.where((a) => a.email == lower).firstOrNull;
  }

  String nextId() {
    _sequence++;
    final suffix = _sequence.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-9000-$suffix';
  }

  /// Issues a new token pair for [account].
  TokenPair issueTokens(MockAccount account) {
    _sequence++;
    final access = 'mock-access-$_sequence';
    final refresh = 'mock-refresh-$_sequence';
    accessTokens[access] = account.id;
    refreshTokens[refresh] = account.id;
    return TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: 900,
      account: AccountOut(
        id: account.id,
        email: account.email,
        role: account.role,
        status: account.status,
        mustChangePassword: account.mustChangePassword,
      ),
    );
  }

  /// Makes every current access token answer 401 TOKEN_EXPIRED.
  void expireAccessTokens() => expiredAccessTokens.addAll(accessTokens.keys);
}
