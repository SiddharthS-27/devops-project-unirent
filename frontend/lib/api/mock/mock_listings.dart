import '../generated/models.dart';
import 'mock_db.dart';
import 'mock_listing_handlers.dart' show MockSearchFilter;

/// A photo stored by the mock backend. [url] uses the `mock://photo/<rgb>`
/// scheme, which the app renders as a coloured placeholder.
class MockPhoto {
  MockPhoto({required this.id, required this.key, required this.url});

  final String id;
  final String key;
  final String url;
}

class MockAsset {
  MockAsset({
    required this.id,
    required this.ownerId,
    required this.condition,
    this.manufactureDate,
    this.serialNumber,
    this.rentalCount = 0,
    List<AssetHistoryEntry>? history,
  }) : history = history ?? [];

  final String id;
  String ownerId;
  ItemCondition condition;
  DateTime? manufactureDate;
  String? serialNumber;
  int rentalCount;
  final List<AssetHistoryEntry> history;
}

class MockListing {
  MockListing({
    required this.id,
    required this.ownerId,
    required this.assetId,
    required this.kind,
    required this.title,
    required this.category,
    required this.pickupPoint,
    required this.createdAt,
    this.status = ListingStatus.active,
    this.description = '',
    this.pricePerHourPaise,
    this.pricePerDayPaise,
    this.salePricePaise,
    List<MockPhoto>? photos,
    List<BlockedSlot>? unavailable,
    this.pendingRequestCount = 0,
    this.locked = false,
  }) : photos = photos ?? [],
       unavailable = unavailable ?? [];

  final String id;
  final String ownerId;
  final String assetId;
  TradeKind kind;
  ListingStatus status;

  /// Why staff removed it.
  String? removedReason;
  String title;
  String description;
  ListingCategory category;
  String pickupPoint;
  int? pricePerHourPaise;
  int? pricePerDayPaise;
  int? salePricePaise;
  final DateTime createdAt;
  final List<MockPhoto> photos;
  final List<BlockedSlot> unavailable;
  int pendingRequestCount;

  /// True while a booking is approved or active (edits are refused).
  bool locked;

  /// The price search filters and sorts on: the sale price, else the daily
  /// price, else the hourly price.
  int get headlinePricePaise =>
      salePricePaise ?? pricePerDayPaise ?? pricePerHourPaise ?? 0;
}

class MockSavedSearch {
  MockSavedSearch({
    required this.id,
    required this.accountId,
    required this.createdAt,
    this.name,
    this.q,
    this.category,
    this.kind,
    this.minPricePaise,
    this.maxPricePaise,
  });

  final String id;
  final String accountId;
  final DateTime createdAt;
  final String? name;
  final String? q;
  final ListingCategory? category;
  final TradeKind? kind;
  final int? minPricePaise;
  final int? maxPricePaise;

  /// When the user last listed their saved searches; new-match counts are
  /// relative to it (null means [createdAt]).
  DateTime? lastViewedAt;

  MockSearchFilter get filter => MockSearchFilter(
    q: q,
    category: category,
    kind: kind,
    minPricePaise: minPricePaise,
    maxPricePaise: maxPricePaise,
  );
}

/// The late-fee rule shown on rent listings.
/// The first late-fee rule version, in force since 90 days before [now].
LateFeeRuleVersion mockSeedLateFeeRule(DateTime now) => LateFeeRuleVersion(
  id: '00000000-0000-4000-a000-000000000001',
  version: 1,
  graceMinutes: 30,
  baseFeePaise: 5000,
  hourlyPercentBp: 200,
  effectiveFrom: now.subtract(const Duration(days: 90)),
);

/// The late-fee rule in force: the admin's latest version, else the seed.
LateFeeRuleOut mockLateFeeRule(DateTime now, MockDb db) {
  final rule = db.lateFeeRules.lastOrNull ?? mockSeedLateFeeRule(now);
  return LateFeeRuleOut(
    id: rule.id,
    graceMinutes: rule.graceMinutes,
    baseFeePaise: rule.baseFeePaise,
    hourlyPercentBp: rule.hourlyPercentBp,
    effectiveFrom: rule.effectiveFrom,
  );
}

const _descriptions = {
  ListingCategory.cameras:
      'Works perfectly, battery holds a full day of shooting. Comes with '
      'charger, strap and a 64 GB card. Please handle the lens with care.',
  ListingCategory.cycles:
      'Well maintained, tyres replaced last month. Lock and key included. '
      'Great for getting between hostels and the academic block.',
  ListingCategory.books:
      'Clean copies with a few pencil notes in the margins. Perfect for '
      'first-year exams.',
  ListingCategory.instruments:
      'Good tone, recently tuned. Soft case included. Ideal for practice or '
      'a college fest performance.',
  ListingCategory.sports:
      'Used for a season of inter-hostel matches, everything in good shape.',
  ListingCategory.hostel: 'Handy for hostel life. Clean and in working order.',
  ListingCategory.events:
      'Perfect for fests, farewells and interviews. Collect a day before '
      'your event.',
  ListingCategory.electronics:
      'Fully working, with original charger/accessories where applicable.',
  ListingCategory.other: 'In good condition. Message me with any questions.',
};

/// The id of the [n]th seeded listing (1-based).
String mockListingId(int n) =>
    '00000000-0000-4000-b000-${n.toString().padLeft(12, '0')}';

/// Adds three more students and a campus-sized set of listings to [db].
void seedListings(MockDb db) {
  final now = db.clock().toUtc();
  final asha = db.accountByEmail('asha@college.edu')!
    ..payoutStatus = PayoutAccountOutStatus.activated
    ..razorpayAccountId = 'acc_MockAsha0001'
    ..payoutUpdatedAt = now.subtract(const Duration(days: 30))
    ..lenderScore = 86
    ..lenderRating = 4.7
    ..completedTrades = 12
    ..renterScore = 88
    ..renterRating = 4.8
    ..renterReviews = 9;

  MockAccount student(
    String n,
    String email,
    String name,
    String phone, {
    int? score,
    double? rating,
    int trades = 0,
    int cancellations = 0,
    int? renterScore,
    double? renterRating,
    int renterReviews = 0,
  }) {
    final account = db.addAccount(
      MockAccount(
          id: '00000000-0000-4000-8000-00000000010$n',
          email: email,
          role: 'student',
          name: name,
          phone: phone,
          phoneVerifiedAt: now.subtract(const Duration(days: 40)),
          createdAt: now.subtract(const Duration(days: 40)),
        )
        ..lenderScore = score
        ..lenderRating = rating
        ..completedTrades = trades
        ..cancellationCount = cancellations
        ..renterScore = renterScore
        ..renterRating = renterRating
        ..renterReviews = renterReviews,
    );
    db.profiles[account.id] = MockProfile(
      data: ProfileIn(
        fullName: name,
        rollNumber: '22XX00$n',
        department: 'Mechanical',
        year: 2,
        residenceType: ResidenceType.hostel,
        hostelName: 'Narmada Hostel',
        roomNumber: 'C-1$n',
      ),
      termsVersion: mockTermsVersion,
    );
    return account;
  }

  final karan = student(
    '2',
    'karan@college.edu',
    'Karan Mehta',
    '+919876500002',
    score: 64,
    rating: 4.1,
    trades: 7,
    cancellations: 2,
    renterScore: 58,
    renterRating: 3.9,
    renterReviews: 6,
  );
  final meera = student(
    '3',
    'meera@college.edu',
    'Meera Iyer',
    '+919876500003',
  );
  final dev = student(
    '4',
    'dev@college.edu',
    'Dev Patel',
    '+919876500004',
    score: 92,
    rating: 4.9,
    trades: 21,
    renterScore: 90,
    renterRating: 4.9,
    renterReviews: 15,
  )..payoutStatus = PayoutAccountOutStatus.activated;

  var n = 0;
  void listing(
    MockAccount owner,
    String title,
    ListingCategory category, {
    TradeKind kind = TradeKind.rent,
    int? hour,
    int? day,
    int? sale,
    String pickup = 'Main gate',
    List<int> colors = const [0x5C6BC0],
    ListingStatus status = ListingStatus.active,
    String? serial,
    ItemCondition condition = ItemCondition.good,
    List<BlockedSlot> unavailable = const [],
    int rentals = 0,
  }) {
    n++;
    final id = mockListingId(n);
    final assetId = '00000000-0000-4000-c000-${n.toString().padLeft(12, '0')}';
    final createdAt = now.subtract(Duration(hours: 7 * n));
    db.assets[assetId] = MockAsset(
      id: assetId,
      ownerId: owner.id,
      condition: condition,
      manufactureDate: DateTime.utc(2022, (n % 12) + 1),
      serialNumber: serial,
      rentalCount: rentals,
      history: [
        AssetHistoryEntry(
          at: createdAt,
          kind: AssetEventKind.listed,
          summary: 'Listed by ${owner.name}',
        ),
        if (rentals > 0)
          AssetHistoryEntry(
            at: createdAt.add(const Duration(hours: 3)),
            kind: AssetEventKind.rented,
            summary: 'Rented for 2 days',
            amountPaise: (day ?? hour ?? 0) * 2,
          ),
        if (rentals > 0)
          AssetHistoryEntry(
            at: createdAt.add(const Duration(hours: 5)),
            kind: AssetEventKind.returned,
            summary: 'Returned on time',
          ),
      ],
    );
    db.listings[id] = MockListing(
      id: id,
      ownerId: owner.id,
      assetId: assetId,
      kind: kind,
      status: status,
      title: title,
      description: _descriptions[category]!,
      category: category,
      pickupPoint: pickup,
      pricePerHourPaise: hour,
      pricePerDayPaise: day,
      salePricePaise: sale,
      createdAt: createdAt,
      unavailable: unavailable,
      photos: [
        for (final (i, color) in colors.indexed)
          MockPhoto(
            id: '$id-p$i',
            key: 'listing/$id/$i.jpg',
            url: 'mock://photo/${color.toRadixString(16).padLeft(6, '0')}',
          ),
      ],
    );
  }

  final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
  listing(
    dev,
    'Canon EOS 1500D DSLR with 18-55mm lens',
    ListingCategory.cameras,
    hour: 6000,
    day: 40000,
    pickup: 'Central library entrance',
    colors: [0x37474F, 0x546E7A, 0x78909C],
    serial: 'CN1500D-77341209',
    condition: ItemCondition.likeNew,
    rentals: 4,
    unavailable: [
      BlockedSlot(
        startAt: tomorrow.add(const Duration(hours: 4)),
        endAt: tomorrow.add(const Duration(hours: 12)),
      ),
    ],
  );
  listing(
    karan,
    'GoPro Hero 9 action camera',
    ListingCategory.cameras,
    hour: 5000,
    day: 35000,
    pickup: 'Narmada Hostel gate',
    colors: [0x263238],
    serial: 'GPH9-55120983',
  );
  listing(
    asha,
    'Hercules 21-gear mountain bike',
    ListingCategory.cycles,
    hour: 1500,
    day: 8000,
    pickup: 'Ganga Hostel cycle stand',
    colors: [0xC62828, 0x8E24AA],
    rentals: 2,
  );
  listing(
    meera,
    'Btwin city cycle with basket',
    ListingCategory.cycles,
    kind: TradeKind.sale,
    sale: 450000,
    pickup: 'Sports complex',
    colors: [0x00897B],
  );
  listing(
    asha,
    'HC Verma Concepts of Physics (Vol 1 & 2)',
    ListingCategory.books,
    kind: TradeKind.sale,
    sale: 30000,
    pickup: 'Ganga Hostel reception',
    colors: [0xF9A825],
    status: ListingStatus.sold,
  );
  listing(
    karan,
    'Engineering drawing kit with mini drafter',
    ListingCategory.books,
    day: 3000,
    colors: [0x6D4C41],
  );
  listing(
    meera,
    'Yamaha F310 acoustic guitar',
    ListingCategory.instruments,
    day: 15000,
    pickup: 'Music club room',
    colors: [0x8D6E63, 0xA1887F],
  );
  listing(
    dev,
    'Casio CT-S300 keyboard',
    ListingCategory.instruments,
    hour: 3000,
    day: 20000,
    colors: [0x212121],
    serial: 'CTS300-00918273',
  );
  listing(
    karan,
    'SG cricket kit (bat, pads, gloves)',
    ListingCategory.sports,
    day: 12000,
    pickup: 'Cricket ground pavilion',
    colors: [0x2E7D32],
  );
  listing(
    asha,
    'Yonex badminton racquet pair',
    ListingCategory.sports,
    hour: 2000,
    day: 9000,
    pickup: 'Indoor stadium',
    colors: [0x1565C0],
  );
  listing(
    meera,
    'Prestige electric kettle 1.5 L',
    ListingCategory.hostel,
    kind: TradeKind.sale,
    sale: 60000,
    colors: [0x9E9E9E],
  );
  listing(
    dev,
    'LED study table lamp',
    ListingCategory.hostel,
    day: 2500,
    colors: [0xFFB300],
  );
  listing(
    karan,
    'JBL Bluetooth party speaker',
    ListingCategory.events,
    hour: 4000,
    day: 25000,
    pickup: 'Student activity centre',
    colors: [0xE65100],
    serial: 'JBLPB-31007714',
  );
  listing(
    meera,
    'Formal blazer (size M) for interviews',
    ListingCategory.events,
    day: 18000,
    colors: [0x283593],
  );
  listing(
    asha,
    'Casio fx-991EX scientific calculator',
    ListingCategory.electronics,
    hour: 1000,
    day: 4000,
    pickup: 'Academic block A',
    colors: [0x424242],
    serial: 'FX991EX-1209',
  );
  listing(
    dev,
    'Dell 24-inch monitor',
    ListingCategory.electronics,
    kind: TradeKind.sale,
    sale: 650000,
    colors: [0x111111],
    serial: 'DELLP24-CN0X9Y',
  );
  listing(
    karan,
    'TI-84 Plus graphing calculator',
    ListingCategory.electronics,
    day: 7000,
    colors: [0x0D47A1],
  );
  listing(
    dev,
    'Two-person camping tent',
    ListingCategory.other,
    day: 20000,
    pickup: 'Adventure club store',
    colors: [0x558B2F],
  );
  listing(
    asha,
    'Mini fridge (45 L)',
    ListingCategory.hostel,
    day: 15000,
    pickup: 'Ganga Hostel reception',
    colors: [0xECEFF1],
    status: ListingStatus.paused,
  );
}
