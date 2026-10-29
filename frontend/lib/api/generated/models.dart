// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: contracts/openapi.json. Regenerate with:
//   dart run tool/generate_api.dart

import 'package:flutter/foundation.dart' show immutable;

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum AccountRestriction {
  suspended('suspended'),
  banned('banned'),

  /// A value added to the API after this client was built.
  unknown('');

  const AccountRestriction(this.json);

  /// The wire value.
  final String json;

  static AccountRestriction fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum AccountStatus {
  active('active'),
  suspended('suspended'),
  banned('banned'),

  /// A value added to the API after this client was built.
  unknown('');

  const AccountStatus(this.json);

  /// The wire value.
  final String json;

  static AccountStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum AppealFilter {
  open('open'),
  ruled('ruled'),
  all('all'),

  /// A value added to the API after this client was built.
  unknown('');

  const AppealFilter(this.json);

  /// The wire value.
  final String json;

  static AppealFilter fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum AppealReason {
  damageDispute('damage_dispute'),
  itemMismatch('item_mismatch'),
  other('other'),

  /// A value added to the API after this client was built.
  unknown('');

  const AppealReason(this.json);

  /// The wire value.
  final String json;

  static AppealReason fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum AppealStatus {
  open('open'),
  ruled('ruled'),
  overruled('overruled'),

  /// A value added to the API after this client was built.
  unknown('');

  const AppealStatus(this.json);

  /// The wire value.
  final String json;

  static AppealStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum AssetEventKind {
  listed('listed'),
  rented('rented'),
  returned('returned'),
  sold('sold'),
  damageCharge('damage_charge'),

  /// A value added to the API after this client was built.
  unknown('');

  const AssetEventKind(this.json);

  /// The wire value.
  final String json;

  static AssetEventKind fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum BookingGroup {
  pending('pending'),
  upcoming('upcoming'),
  active('active'),
  past('past'),
  cancelled('cancelled'),

  /// A value added to the API after this client was built.
  unknown('');

  const BookingGroup(this.json);

  /// The wire value.
  final String json;

  static BookingGroup fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum BookingStatus {
  requested('requested'),
  approved('approved'),
  declined('declined'),
  withdrawn('withdrawn'),
  expired('expired'),
  cancelled('cancelled'),
  active('active'),
  overdue('overdue'),
  returning('returning'),
  inAppeal('in_appeal'),
  awaitingReviews('awaiting_reviews'),
  completed('completed'),

  /// A value added to the API after this client was built.
  unknown('');

  const BookingStatus(this.json);

  /// The wire value.
  final String json;

  static BookingStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum BookingViewerRole {
  renter('renter'),
  owner('owner'),
  staff('staff'),

  /// A value added to the API after this client was built.
  unknown('');

  const BookingViewerRole(this.json);

  /// The wire value.
  final String json;

  static BookingViewerRole fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ChatAction {
  seeFaqs('see_faqs'),
  talkToModerator('talk_to_moderator'),

  /// A value added to the API after this client was built.
  unknown('');

  const ChatAction(this.json);

  /// The wire value.
  final String json;

  static ChatAction fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ChatReplyKind {
  answer('answer'),
  fallback('fallback'),

  /// A value added to the API after this client was built.
  unknown('');

  const ChatReplyKind(this.json);

  /// The wire value.
  final String json;

  static ChatReplyKind fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum DevicePlatform {
  android('android'),
  ios('ios'),

  /// A value added to the API after this client was built.
  unknown('');

  const DevicePlatform(this.json);

  /// The wire value.
  final String json;

  static DevicePlatform fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum Direction {
  paid('paid'),
  received('received'),

  /// A value added to the API after this client was built.
  unknown('');

  const Direction(this.json);

  /// The wire value.
  final String json;

  static Direction fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum EscalationKind {
  overdue('overdue'),
  stalledProceed('stalled_proceed'),
  ownerEscalated('owner_escalated'),

  /// A value added to the API after this client was built.
  unknown('');

  const EscalationKind(this.json);

  /// The wire value.
  final String json;

  static EscalationKind fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ExtensionStatus {
  requested('requested'),
  approved('approved'),
  declined('declined'),

  /// A value added to the API after this client was built.
  unknown('');

  const ExtensionStatus(this.json);

  /// The wire value.
  final String json;

  static ExtensionStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum HandoverPhase {
  pickup('pickup'),
  returnValue('return'),

  /// A value added to the API after this client was built.
  unknown('');

  const HandoverPhase(this.json);

  /// The wire value.
  final String json;

  static HandoverPhase fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ItemCondition {
  newValue('new'),
  likeNew('like_new'),
  good('good'),
  fair('fair'),
  poor('poor'),

  /// A value added to the API after this client was built.
  unknown('');

  const ItemCondition(this.json);

  /// The wire value.
  final String json;

  static ItemCondition fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ListingCategory {
  electronics('electronics'),
  cameras('cameras'),
  cycles('cycles'),
  books('books'),
  instruments('instruments'),
  sports('sports'),
  hostel('hostel'),
  events('events'),
  other('other'),

  /// A value added to the API after this client was built.
  unknown('');

  const ListingCategory(this.json);

  /// The wire value.
  final String json;

  static ListingCategory fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ListingStatus {
  active('active'),
  paused('paused'),
  sold('sold'),
  removed('removed'),

  /// A value added to the API after this client was built.
  unknown('');

  const ListingStatus(this.json);

  /// The wire value.
  final String json;

  static ListingStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum MessageAuthor {
  user('user'),
  bot('bot'),
  moderator('moderator'),

  /// A value added to the API after this client was built.
  unknown('');

  const MessageAuthor(this.json);

  /// The wire value.
  final String json;

  static MessageAuthor fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum PaymentMethod {
  upi('upi'),
  cash('cash'),

  /// A value added to the API after this client was built.
  unknown('');

  const PaymentMethod(this.json);

  /// The wire value.
  final String json;

  static PaymentMethod fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum PaymentPurpose {
  rent('rent'),
  extension('extension'),
  returnCharges('return_charges'),
  sale('sale'),

  /// A value added to the API after this client was built.
  unknown('');

  const PaymentPurpose(this.json);

  /// The wire value.
  final String json;

  static PaymentPurpose fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum PaymentStatus {
  created('created'),
  pending('pending'),
  captured('captured'),
  failed('failed'),
  markedPaid('marked_paid'),
  refunded('refunded'),
  partlyRefunded('partly_refunded'),

  /// A value added to the API after this client was built.
  unknown('');

  const PaymentStatus(this.json);

  /// The wire value.
  final String json;

  static PaymentStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum PayoutAccountOutStatus {
  none('none'),
  created('created'),
  underReview('under_review'),
  needsClarification('needs_clarification'),
  activated('activated'),
  suspended('suspended'),

  /// A value added to the API after this client was built.
  unknown('');

  const PayoutAccountOutStatus(this.json);

  /// The wire value.
  final String json;

  static PayoutAccountOutStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum PhotoContentType {
  imageJpeg('image/jpeg'),
  imagePng('image/png'),
  imageWebp('image/webp'),

  /// A value added to the API after this client was built.
  unknown('');

  const PhotoContentType(this.json);

  /// The wire value.
  final String json;

  static PhotoContentType fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ReconciliationReportStatus {
  running('running'),
  done('done'),
  failed('failed'),

  /// A value added to the API after this client was built.
  unknown('');

  const ReconciliationReportStatus(this.json);

  /// The wire value.
  final String json;

  static ReconciliationReportStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum RefundOutStatus {
  pending('pending'),
  processed('processed'),
  failed('failed'),
  cashPending('cash_pending'),
  cashDone('cash_done'),

  /// A value added to the API after this client was built.
  unknown('');

  const RefundOutStatus(this.json);

  /// The wire value.
  final String json;

  static RefundOutStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ResidenceType {
  hostel('hostel'),
  dayScholar('day_scholar'),

  /// A value added to the API after this client was built.
  unknown('');

  const ResidenceType(this.json);

  /// The wire value.
  final String json;

  static ResidenceType fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ReviewType {
  renter('renter'),
  lender('lender'),
  renterSale('renter_sale'),
  lenderSale('lender_sale'),
  cancellation('cancellation'),

  /// A value added to the API after this client was built.
  unknown('');

  const ReviewType(this.json);

  /// The wire value.
  final String json;

  static ReviewType fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum RiskFlagKind {
  overdueReturns('overdue_returns'),
  cancellations('cancellations'),
  disputes('disputes'),
  lowTrust('low_trust'),

  /// A value added to the API after this client was built.
  unknown('');

  const RiskFlagKind(this.json);

  /// The wire value.
  final String json;

  static RiskFlagKind fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum SearchSort {
  trust('trust'),
  newest('newest'),
  priceAsc('price_asc'),
  priceDesc('price_desc'),

  /// A value added to the API after this client was built.
  unknown('');

  const SearchSort(this.json);

  /// The wire value.
  final String json;

  static SearchSort fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum ThreadStatus {
  open('open'),
  closed('closed'),

  /// A value added to the API after this client was built.
  unknown('');

  const ThreadStatus(this.json);

  /// The wire value.
  final String json;

  static ThreadStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum TimelineStepState {
  done('done'),
  current('current'),
  upcoming('upcoming'),
  skipped('skipped'),

  /// A value added to the API after this client was built.
  unknown('');

  const TimelineStepState(this.json);

  /// The wire value.
  final String json;

  static TimelineStepState fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum TradeKind {
  rent('rent'),
  sale('sale'),

  /// A value added to the API after this client was built.
  unknown('');

  const TradeKind(this.json);

  /// The wire value.
  final String json;

  static TradeKind fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum TradeRole {
  renter('renter'),
  owner('owner'),

  /// A value added to the API after this client was built.
  unknown('');

  const TradeRole(this.json);

  /// The wire value.
  final String json;

  static TradeRole fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum TranscriptAuthor {
  user('user'),
  bot('bot'),

  /// A value added to the API after this client was built.
  unknown('');

  const TranscriptAuthor(this.json);

  /// The wire value.
  final String json;

  static TranscriptAuthor fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum TrustRole {
  lender('lender'),
  renter('renter'),

  /// A value added to the API after this client was built.
  unknown('');

  const TrustRole(this.json);

  /// The wire value.
  final String json;

  static TrustRole fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum UploadPurpose {
  profile('profile'),
  listing('listing'),
  handover('handover'),
  appeal('appeal'),

  /// A value added to the API after this client was built.
  unknown('');

  const UploadPurpose(this.json);

  /// The wire value.
  final String json;

  static UploadPurpose fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

enum WebhookAckStatus {
  processed('processed'),
  duplicate('duplicate'),
  ignored('ignored'),

  /// A value added to the API after this client was built.
  unknown('');

  const WebhookAckStatus(this.json);

  /// The wire value.
  final String json;

  static WebhookAckStatus fromJson(String json) =>
      values.firstWhere((v) => v.json == json, orElse: () => unknown);
}

/// One of [ProfileCounterparty], [ProfileOwn], [ProfilePublic], [ProfileStaff],
/// discriminated by `view`.
@immutable
sealed class ProfileView {
  const ProfileView();

  factory ProfileView.fromJson(Map<String, Object?> json) =>
      switch (json['view']) {
        'counterparty' => ProfileCounterparty.fromJson(json),
        'own' => ProfileOwn.fromJson(json),
        'public' => ProfilePublic.fromJson(json),
        'staff' => ProfileStaff.fromJson(json),
        final other => throw FormatException('Unknown ProfileView: $other'),
      };

  String get view;

  String get accountId;

  int get cancellationCount;

  int get completedTrades;

  String get department;

  String get fullName;

  bool get isNew;

  TrustSummary get lender;

  DateTime get memberSince;

  String? get phone;

  String? get photoUrl;

  TrustSummary get renter;

  int get year;

  Map<String, Object?> toJson();
}

@immutable
class AccountAction {
  const AccountAction({required this.accountId, required this.status});

  factory AccountAction.fromJson(Map<String, Object?> json) => AccountAction(
    accountId: json['account_id'] as String,
    status: AccountRestriction.fromJson(json['status'] as String),
  );

  final String accountId;

  final AccountRestriction status;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'status': status.json,
  };
}

@immutable
class AccountOut {
  const AccountOut({
    required this.email,
    required this.id,
    this.mustChangePassword = false,
    required this.role,
    required this.status,
  });

  factory AccountOut.fromJson(Map<String, Object?> json) => AccountOut(
    email: json['email'] as String,
    id: json['id'] as String,
    mustChangePassword: json['must_change_password'] == null
        ? false
        : json['must_change_password'] as bool,
    role: json['role'] as String,
    status: json['status'] as String,
  );

  final String email;

  final String id;

  final bool mustChangePassword;

  final String role;

  final String status;

  Map<String, Object?> toJson() => {
    'email': email,
    'id': id,
    'must_change_password': mustChangePassword,
    'role': role,
    'status': status,
  };
}

@immutable
class AccountSummary {
  const AccountSummary({
    required this.email,
    required this.id,
    required this.role,
    required this.status,
  });

  factory AccountSummary.fromJson(Map<String, Object?> json) => AccountSummary(
    email: json['email'] as String,
    id: json['id'] as String,
    role: json['role'] as String,
    status: json['status'] as String,
  );

  final String email;

  final String id;

  final String role;

  final String status;

  Map<String, Object?> toJson() => {
    'email': email,
    'id': id,
    'role': role,
    'status': status,
  };
}

@immutable
class AppealCreate {
  const AppealCreate({
    required this.notes,
    this.photoKeys,
    required this.reason,
  });

  factory AppealCreate.fromJson(Map<String, Object?> json) => AppealCreate(
    notes: json['notes'] as String,
    photoKeys: json['photo_keys'] == null
        ? null
        : (json['photo_keys'] as List<Object?>)
              .map((e0) => e0! as String)
              .toList(),
    reason: AppealReason.fromJson(json['reason'] as String),
  );

  final String notes;

  final List<String>? photoKeys;

  final AppealReason reason;

  Map<String, Object?> toJson() => {
    'notes': notes,
    'photo_keys': ?photoKeys,
    'reason': reason.json,
  };
}

@immutable
class AppealDetail {
  const AppealDetail({
    required this.appeal,
    required this.booking,
    required this.extraPhotos,
    required this.pickupPhotos,
    required this.returnPhotos,
    required this.rulings,
  });

  factory AppealDetail.fromJson(Map<String, Object?> json) => AppealDetail(
    appeal: AppealOut.fromJson(json['appeal'] as Map<String, Object?>),
    booking: BookingOut.fromJson(json['booking'] as Map<String, Object?>),
    extraPhotos: (json['extra_photos'] as List<Object?>)
        .map((e0) => PhotoOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    pickupPhotos: (json['pickup_photos'] as List<Object?>)
        .map((e0) => PhotoOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    returnPhotos: (json['return_photos'] as List<Object?>)
        .map((e0) => PhotoOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    rulings: (json['rulings'] as List<Object?>)
        .map((e0) => RulingOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
  );

  final AppealOut appeal;

  final BookingOut booking;

  final List<PhotoOut> extraPhotos;

  final List<PhotoOut> pickupPhotos;

  final List<PhotoOut> returnPhotos;

  final List<RulingOut> rulings;

  Map<String, Object?> toJson() => {
    'appeal': appeal.toJson(),
    'booking': booking.toJson(),
    'extra_photos': extraPhotos.map((e0) => e0.toJson()).toList(),
    'pickup_photos': pickupPhotos.map((e0) => e0.toJson()).toList(),
    'return_photos': returnPhotos.map((e0) => e0.toJson()).toList(),
    'rulings': rulings.map((e0) => e0.toJson()).toList(),
  };
}

@immutable
class AppealOut {
  const AppealOut({
    required this.bookingId,
    required this.createdAt,
    required this.filedBy,
    required this.id,
    required this.notes,
    required this.reason,
    required this.status,
  });

  factory AppealOut.fromJson(Map<String, Object?> json) => AppealOut(
    bookingId: json['booking_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    filedBy: TradeRole.fromJson(json['filed_by'] as String),
    id: json['id'] as String,
    notes: json['notes'] as String,
    reason: json['reason'] as String,
    status: AppealStatus.fromJson(json['status'] as String),
  );

  final String bookingId;

  final DateTime createdAt;

  final TradeRole filedBy;

  final String id;

  final String notes;

  final String reason;

  final AppealStatus status;

  Map<String, Object?> toJson() => {
    'booking_id': bookingId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'filed_by': filedBy.json,
    'id': id,
    'notes': notes,
    'reason': reason,
    'status': status.json,
  };
}

@immutable
class AppealRef {
  const AppealRef({required this.id, required this.status});

  factory AppealRef.fromJson(Map<String, Object?> json) => AppealRef(
    id: json['id'] as String,
    status: AppealStatus.fromJson(json['status'] as String),
  );

  final String id;

  final AppealStatus status;

  Map<String, Object?> toJson() => {'id': id, 'status': status.json};
}

@immutable
class AppealSummary {
  const AppealSummary({
    required this.bookingId,
    required this.createdAt,
    required this.filedByName,
    required this.id,
    required this.kind,
    required this.listingTitle,
    required this.reason,
    required this.status,
  });

  factory AppealSummary.fromJson(Map<String, Object?> json) => AppealSummary(
    bookingId: json['booking_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    filedByName: json['filed_by_name'] as String,
    id: json['id'] as String,
    kind: TradeKind.fromJson(json['kind'] as String),
    listingTitle: json['listing_title'] as String,
    reason: json['reason'] as String,
    status: AppealStatus.fromJson(json['status'] as String),
  );

  final String bookingId;

  final DateTime createdAt;

  final String filedByName;

  final String id;

  final TradeKind kind;

  final String listingTitle;

  final String reason;

  final AppealStatus status;

  Map<String, Object?> toJson() => {
    'booking_id': bookingId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'filed_by_name': filedByName,
    'id': id,
    'kind': kind.json,
    'listing_title': listingTitle,
    'reason': reason,
    'status': status.json,
  };
}

@immutable
class AssetHistoryEntry {
  const AssetHistoryEntry({
    this.amountPaise,
    required this.at,
    required this.kind,
    this.photos,
    required this.summary,
  });

  factory AssetHistoryEntry.fromJson(Map<String, Object?> json) =>
      AssetHistoryEntry(
        amountPaise: (json['amount_paise'] as num?)?.toInt(),
        at: DateTime.parse(json['at'] as String),
        kind: AssetEventKind.fromJson(json['kind'] as String),
        photos: json['photos'] == null
            ? null
            : (json['photos'] as List<Object?>)
                  .map((e0) => PhotoOut.fromJson(e0! as Map<String, Object?>))
                  .toList(),
        summary: json['summary'] as String,
      );

  final int? amountPaise;

  final DateTime at;

  final AssetEventKind kind;

  final List<PhotoOut>? photos;

  final String summary;

  Map<String, Object?> toJson() => {
    'amount_paise': ?amountPaise,
    'at': at.toUtc().toIso8601String(),
    'kind': kind.json,
    'photos': ?photos?.map((e0) => e0.toJson()).toList(),
    'summary': summary,
  };
}

@immutable
class AssetOut {
  const AssetOut({
    required this.category,
    required this.condition,
    required this.description,
    required this.history,
    required this.id,
    required this.listingId,
    required this.listingStatus,
    required this.manufactureDate,
    required this.ownerId,
    required this.photoUrl,
    required this.rentalCount,
    required this.serialNumber,
    required this.title,
  });

  factory AssetOut.fromJson(Map<String, Object?> json) => AssetOut(
    category: ListingCategory.fromJson(json['category'] as String),
    condition: ItemCondition.fromJson(json['condition'] as String),
    description: json['description'] as String,
    history: (json['history'] as List<Object?>)
        .map((e0) => AssetHistoryEntry.fromJson(e0! as Map<String, Object?>))
        .toList(),
    id: json['id'] as String,
    listingId: json['listing_id'] as String?,
    listingStatus: json['listing_status'] == null
        ? null
        : ListingStatus.fromJson(json['listing_status'] as String),
    manufactureDate: json['manufacture_date'] == null
        ? null
        : DateTime.parse(json['manufacture_date'] as String),
    ownerId: json['owner_id'] as String,
    photoUrl: json['photo_url'] as String?,
    rentalCount: (json['rental_count'] as num).toInt(),
    serialNumber: json['serial_number'] as String?,
    title: json['title'] as String,
  );

  final ListingCategory category;

  final ItemCondition condition;

  final String description;

  final List<AssetHistoryEntry> history;

  final String id;

  /// The current owner's latest listing of the item, if they listed it
  final String? listingId;

  final ListingStatus? listingStatus;

  final DateTime? manufactureDate;

  final String ownerId;

  /// Cover photo of the latest listing
  final String? photoUrl;

  final int rentalCount;

  /// Masked to the last 4 characters except for the owner and staff
  final String? serialNumber;

  /// From the item's latest listing
  final String title;

  Map<String, Object?> toJson() => {
    'category': category.json,
    'condition': condition.json,
    'description': description,
    'history': history.map((e0) => e0.toJson()).toList(),
    'id': id,
    'listing_id': listingId,
    'listing_status': listingStatus?.json,
    'manufacture_date': manufactureDate == null
        ? null
        : _formatDate(manufactureDate!),
    'owner_id': ownerId,
    'photo_url': photoUrl,
    'rental_count': rentalCount,
    'serial_number': serialNumber,
    'title': title,
  };
}

@immutable
class AuditEntryOut {
  const AuditEntryOut({
    required this.action,
    required this.actorId,
    required this.actorRole,
    required this.at,
    required this.details,
    required this.id,
    required this.target,
  });

  factory AuditEntryOut.fromJson(Map<String, Object?> json) => AuditEntryOut(
    action: json['action'] as String,
    actorId: json['actor_id'] as String?,
    actorRole: json['actor_role'] as String?,
    at: DateTime.parse(json['at'] as String),
    details: Map<String, Object?>.of(json['details'] as Map<String, Object?>),
    id: (json['id'] as num).toInt(),
    target: json['target'] as String?,
  );

  final String action;

  final String? actorId;

  final String? actorRole;

  final DateTime at;

  final Map<String, Object?> details;

  final int id;

  final String? target;

  Map<String, Object?> toJson() => {
    'action': action,
    'actor_id': actorId,
    'actor_role': actorRole,
    'at': at.toUtc().toIso8601String(),
    'details': details,
    'id': id,
    'target': target,
  };
}

@immutable
class AuditEntryOutPage {
  const AuditEntryOutPage({required this.items, this.nextCursor});

  factory AuditEntryOutPage.fromJson(Map<String, Object?> json) =>
      AuditEntryOutPage(
        items: (json['items'] as List<Object?>)
            .map((e0) => AuditEntryOut.fromJson(e0! as Map<String, Object?>))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );

  final List<AuditEntryOut> items;

  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': items.map((e0) => e0.toJson()).toList(),
    'next_cursor': ?nextCursor,
  };
}

@immutable
class BlockedSlot {
  const BlockedSlot({required this.endAt, required this.startAt});

  factory BlockedSlot.fromJson(Map<String, Object?> json) => BlockedSlot(
    endAt: DateTime.parse(json['end_at'] as String),
    startAt: DateTime.parse(json['start_at'] as String),
  );

  final DateTime endAt;

  final DateTime startAt;

  Map<String, Object?> toJson() => {
    'end_at': endAt.toUtc().toIso8601String(),
    'start_at': startAt.toUtc().toIso8601String(),
  };
}

@immutable
class BookingCreate {
  const BookingCreate({this.endAt, required this.listingId, this.startAt});

  factory BookingCreate.fromJson(Map<String, Object?> json) => BookingCreate(
    endAt: json['end_at'] == null
        ? null
        : DateTime.parse(json['end_at'] as String),
    listingId: json['listing_id'] as String,
    startAt: json['start_at'] == null
        ? null
        : DateTime.parse(json['start_at'] as String),
  );

  /// Rent only
  final DateTime? endAt;

  final String listingId;

  /// Rent only
  final DateTime? startAt;

  Map<String, Object?> toJson() => {
    'end_at': ?endAt?.toUtc().toIso8601String(),
    'listing_id': listingId,
    'start_at': ?startAt?.toUtc().toIso8601String(),
  };
}

@immutable
class BookingOut {
  const BookingOut({
    required this.amountPaise,
    required this.appeal,
    required this.canAppeal,
    required this.canCancel,
    required this.canEscalate,
    required this.cancellation,
    required this.charges,
    required this.createdAt,
    required this.endAt,
    required this.escalationAvailableAt,
    required this.extensions,
    required this.id,
    required this.kind,
    required this.lateFeeRule,
    required this.listing,
    required this.nextAction,
    required this.overdueSince,
    required this.owner,
    required this.payments,
    required this.pickup,
    required this.renter,
    required this.returnHandover,
    required this.reviews,
    required this.role,
    required this.serverNow,
    required this.startAt,
    required this.status,
    required this.timeline,
  });

  factory BookingOut.fromJson(Map<String, Object?> json) => BookingOut(
    amountPaise: (json['amount_paise'] as num).toInt(),
    appeal: json['appeal'] == null
        ? null
        : AppealRef.fromJson(json['appeal'] as Map<String, Object?>),
    canAppeal: json['can_appeal'] as bool,
    canCancel: json['can_cancel'] as bool,
    canEscalate: json['can_escalate'] as bool,
    cancellation: json['cancellation'] == null
        ? null
        : CancellationInfo.fromJson(
            json['cancellation'] as Map<String, Object?>,
          ),
    charges: json['charges'] == null
        ? null
        : Charges.fromJson(json['charges'] as Map<String, Object?>),
    createdAt: DateTime.parse(json['created_at'] as String),
    endAt: json['end_at'] == null
        ? null
        : DateTime.parse(json['end_at'] as String),
    escalationAvailableAt: json['escalation_available_at'] == null
        ? null
        : DateTime.parse(json['escalation_available_at'] as String),
    extensions: (json['extensions'] as List<Object?>)
        .map((e0) => ExtensionOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    id: json['id'] as String,
    kind: TradeKind.fromJson(json['kind'] as String),
    lateFeeRule: json['late_fee_rule'] == null
        ? null
        : LateFeeRuleOut.fromJson(
            json['late_fee_rule'] as Map<String, Object?>,
          ),
    listing: ListingCard.fromJson(json['listing'] as Map<String, Object?>),
    nextAction: json['next_action'] == null
        ? null
        : NextAction.fromJson(json['next_action'] as Map<String, Object?>),
    overdueSince: json['overdue_since'] == null
        ? null
        : DateTime.parse(json['overdue_since'] as String),
    owner: ProfileView.fromJson(json['owner'] as Map<String, Object?>),
    payments: (json['payments'] as List<Object?>)
        .map((e0) => PaymentOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    pickup: json['pickup'] == null
        ? null
        : Handover.fromJson(json['pickup'] as Map<String, Object?>),
    renter: ProfileView.fromJson(json['renter'] as Map<String, Object?>),
    returnHandover: json['return'] == null
        ? null
        : Handover.fromJson(json['return'] as Map<String, Object?>),
    reviews: json['reviews'] == null
        ? null
        : ReviewState.fromJson(json['reviews'] as Map<String, Object?>),
    role: BookingViewerRole.fromJson(json['role'] as String),
    serverNow: DateTime.parse(json['server_now'] as String),
    startAt: json['start_at'] == null
        ? null
        : DateTime.parse(json['start_at'] as String),
    status: BookingStatus.fromJson(json['status'] as String),
    timeline: (json['timeline'] as List<Object?>)
        .map((e0) => TimelineStep.fromJson(e0! as Map<String, Object?>))
        .toList(),
  );

  /// Rent or sale price, locked at approval
  final int amountPaise;

  final AppealRef? appeal;

  final bool canAppeal;

  final bool canCancel;

  final bool canEscalate;

  final CancellationInfo? cancellation;

  final Charges? charges;

  final DateTime createdAt;

  final DateTime? endAt;

  final DateTime? escalationAvailableAt;

  final List<ExtensionOut> extensions;

  final String id;

  final TradeKind kind;

  final LateFeeRuleOut? lateFeeRule;

  final ListingCard listing;

  final NextAction? nextAction;

  final DateTime? overdueSince;

  final ProfileView owner;

  final List<PaymentOut> payments;

  final Handover? pickup;

  final ProfileView renter;

  final Handover? returnHandover;

  final ReviewState? reviews;

  final BookingViewerRole role;

  final DateTime serverNow;

  final DateTime? startAt;

  final BookingStatus status;

  final List<TimelineStep> timeline;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'appeal': appeal?.toJson(),
    'can_appeal': canAppeal,
    'can_cancel': canCancel,
    'can_escalate': canEscalate,
    'cancellation': cancellation?.toJson(),
    'charges': charges?.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'end_at': endAt?.toUtc().toIso8601String(),
    'escalation_available_at': escalationAvailableAt?.toUtc().toIso8601String(),
    'extensions': extensions.map((e0) => e0.toJson()).toList(),
    'id': id,
    'kind': kind.json,
    'late_fee_rule': lateFeeRule?.toJson(),
    'listing': listing.toJson(),
    'next_action': nextAction?.toJson(),
    'overdue_since': overdueSince?.toUtc().toIso8601String(),
    'owner': owner.toJson(),
    'payments': payments.map((e0) => e0.toJson()).toList(),
    'pickup': pickup?.toJson(),
    'renter': renter.toJson(),
    'return': returnHandover?.toJson(),
    'reviews': reviews?.toJson(),
    'role': role.json,
    'server_now': serverNow.toUtc().toIso8601String(),
    'start_at': startAt?.toUtc().toIso8601String(),
    'status': status.json,
    'timeline': timeline.map((e0) => e0.toJson()).toList(),
  };
}

@immutable
class BookingSummary {
  const BookingSummary({
    required this.amountPaise,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.endAt,
    required this.id,
    required this.kind,
    required this.listingId,
    required this.listingPhotoUrl,
    required this.listingTitle,
    required this.nextAction,
    required this.role,
    required this.startAt,
    required this.status,
    required this.updatedAt,
  });

  factory BookingSummary.fromJson(Map<String, Object?> json) => BookingSummary(
    amountPaise: (json['amount_paise'] as num).toInt(),
    counterpartyId: json['counterparty_id'] as String,
    counterpartyName: json['counterparty_name'] as String,
    endAt: json['end_at'] == null
        ? null
        : DateTime.parse(json['end_at'] as String),
    id: json['id'] as String,
    kind: TradeKind.fromJson(json['kind'] as String),
    listingId: json['listing_id'] as String,
    listingPhotoUrl: json['listing_photo_url'] as String?,
    listingTitle: json['listing_title'] as String,
    nextAction: json['next_action'] == null
        ? null
        : NextAction.fromJson(json['next_action'] as Map<String, Object?>),
    role: TradeRole.fromJson(json['role'] as String),
    startAt: json['start_at'] == null
        ? null
        : DateTime.parse(json['start_at'] as String),
    status: BookingStatus.fromJson(json['status'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  final int amountPaise;

  final String counterpartyId;

  final String counterpartyName;

  final DateTime? endAt;

  final String id;

  final TradeKind kind;

  final String listingId;

  final String? listingPhotoUrl;

  final String listingTitle;

  final NextAction? nextAction;

  final TradeRole role;

  final DateTime? startAt;

  final BookingStatus status;

  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'counterparty_id': counterpartyId,
    'counterparty_name': counterpartyName,
    'end_at': endAt?.toUtc().toIso8601String(),
    'id': id,
    'kind': kind.json,
    'listing_id': listingId,
    'listing_photo_url': listingPhotoUrl,
    'listing_title': listingTitle,
    'next_action': nextAction?.toJson(),
    'role': role.json,
    'start_at': startAt?.toUtc().toIso8601String(),
    'status': status.json,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

@immutable
class BookingSummaryPage {
  const BookingSummaryPage({required this.items, this.nextCursor});

  factory BookingSummaryPage.fromJson(Map<String, Object?> json) =>
      BookingSummaryPage(
        items: (json['items'] as List<Object?>)
            .map((e0) => BookingSummary.fromJson(e0! as Map<String, Object?>))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );

  final List<BookingSummary> items;

  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': items.map((e0) => e0.toJson()).toList(),
    'next_cursor': ?nextCursor,
  };
}

@immutable
class CancelIn {
  const CancelIn({required this.note});

  factory CancelIn.fromJson(Map<String, Object?> json) =>
      CancelIn(note: json['note'] as String);

  /// Sent to the other side
  final String note;

  Map<String, Object?> toJson() => {'note': note};
}

@immutable
class CancellationInfo {
  const CancellationInfo({
    required this.at,
    required this.by,
    required this.note,
    required this.ratingDue,
  });

  factory CancellationInfo.fromJson(Map<String, Object?> json) =>
      CancellationInfo(
        at: DateTime.parse(json['at'] as String),
        by: TradeRole.fromJson(json['by'] as String),
        note: json['note'] as String,
        ratingDue: json['rating_due'] as bool,
      );

  final DateTime at;

  final TradeRole by;

  final String note;

  /// True when you should now rate the canceller
  final bool ratingDue;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'by': by.json,
    'note': note,
    'rating_due': ratingDue,
  };
}

@immutable
class CancellationRatingIn {
  const CancellationRatingIn({required this.comment, required this.stars});

  factory CancellationRatingIn.fromJson(Map<String, Object?> json) =>
      CancellationRatingIn(
        comment: json['comment'] as String,
        stars: (json['stars'] as num).toInt(),
      );

  final String comment;

  final int stars;

  Map<String, Object?> toJson() => {'comment': comment, 'stars': stars};
}

@immutable
class CategoryOut {
  const CategoryOut({required this.key, required this.label});

  factory CategoryOut.fromJson(Map<String, Object?> json) => CategoryOut(
    key: ListingCategory.fromJson(json['key'] as String),
    label: json['label'] as String,
  );

  final ListingCategory key;

  final String label;

  Map<String, Object?> toJson() => {'key': key.json, 'label': label};
}

/// What the renter owes at return. The late fee is live while unpaid.
@immutable
class Charges {
  const Charges({
    required this.cashExtensionsPaise,
    required this.damageDescription,
    required this.damagePaise,
    required this.lateFeePaise,
    required this.overdueMinutes,
    required this.paid,
    required this.payment,
    required this.totalPaise,
  });

  factory Charges.fromJson(Map<String, Object?> json) => Charges(
    cashExtensionsPaise: (json['cash_extensions_paise'] as num).toInt(),
    damageDescription: json['damage_description'] as String?,
    damagePaise: (json['damage_paise'] as num).toInt(),
    lateFeePaise: (json['late_fee_paise'] as num).toInt(),
    overdueMinutes: (json['overdue_minutes'] as num).toInt(),
    paid: json['paid'] as bool,
    payment: json['payment'] == null
        ? null
        : PaymentOut.fromJson(json['payment'] as Map<String, Object?>),
    totalPaise: (json['total_paise'] as num).toInt(),
  );

  final int cashExtensionsPaise;

  final String? damageDescription;

  final int damagePaise;

  final int lateFeePaise;

  final int overdueMinutes;

  final bool paid;

  final PaymentOut? payment;

  final int totalPaise;

  Map<String, Object?> toJson() => {
    'cash_extensions_paise': cashExtensionsPaise,
    'damage_description': damageDescription,
    'damage_paise': damagePaise,
    'late_fee_paise': lateFeePaise,
    'overdue_minutes': overdueMinutes,
    'paid': paid,
    'payment': payment?.toJson(),
    'total_paise': totalPaise,
  };
}

@immutable
class ChatIn {
  const ChatIn({required this.message});

  factory ChatIn.fromJson(Map<String, Object?> json) =>
      ChatIn(message: json['message'] as String);

  final String message;

  Map<String, Object?> toJson() => {'message': message};
}

/// Either an answer from the FAQs, or a fallback offering the FAQs and a moderator.
@immutable
class ChatReply {
  const ChatReply({
    this.actions,
    this.faqId,
    required this.kind,
    required this.text,
  });

  factory ChatReply.fromJson(Map<String, Object?> json) => ChatReply(
    actions: json['actions'] == null
        ? null
        : (json['actions'] as List<Object?>)
              .map((e0) => ChatAction.fromJson(e0! as String))
              .toList(),
    faqId: json['faq_id'] as String?,
    kind: ChatReplyKind.fromJson(json['kind'] as String),
    text: json['text'] as String,
  );

  final List<ChatAction>? actions;

  final String? faqId;

  final ChatReplyKind kind;

  final String text;

  Map<String, Object?> toJson() => {
    'actions': ?actions?.map((e0) => e0.json).toList(),
    'faq_id': ?faqId,
    'kind': kind.json,
    'text': text,
  };
}

@immutable
class ClockIn {
  const ClockIn({required this.offsetMinutes});

  factory ClockIn.fromJson(Map<String, Object?> json) =>
      ClockIn(offsetMinutes: (json['offset_minutes'] as num).toInt());

  final int offsetMinutes;

  Map<String, Object?> toJson() => {'offset_minutes': offsetMinutes};
}

@immutable
class ClockOut {
  const ClockOut({required this.now, required this.offsetMinutes});

  factory ClockOut.fromJson(Map<String, Object?> json) => ClockOut(
    now: DateTime.parse(json['now'] as String),
    offsetMinutes: (json['offset_minutes'] as num).toInt(),
  );

  final DateTime now;

  final int offsetMinutes;

  Map<String, Object?> toJson() => {
    'now': now.toUtc().toIso8601String(),
    'offset_minutes': offsetMinutes,
  };
}

@immutable
class DamageChargeIn {
  const DamageChargeIn({required this.amountPaise, required this.description});

  factory DamageChargeIn.fromJson(Map<String, Object?> json) => DamageChargeIn(
    amountPaise: (json['amount_paise'] as num).toInt(),
    description: json['description'] as String,
  );

  final int amountPaise;

  final String description;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'description': description,
  };
}

@immutable
class DeclineIn {
  const DeclineIn({this.reason});

  factory DeclineIn.fromJson(Map<String, Object?> json) =>
      DeclineIn(reason: json['reason'] as String?);

  final String? reason;

  Map<String, Object?> toJson() => {'reason': ?reason};
}

@immutable
class DueTimer {
  const DueTimer({
    required this.dueAt,
    required this.id,
    required this.kind,
    required this.refId,
  });

  factory DueTimer.fromJson(Map<String, Object?> json) => DueTimer(
    dueAt: DateTime.parse(json['due_at'] as String),
    id: json['id'] as String,
    kind: json['kind'] as String,
    refId: json['ref_id'] as String,
  );

  final DateTime dueAt;

  final String id;

  final String kind;

  final String refId;

  Map<String, Object?> toJson() => {
    'due_at': dueAt.toUtc().toIso8601String(),
    'id': id,
    'kind': kind,
    'ref_id': refId,
  };
}

@immutable
class DueTimers {
  const DueTimers({required this.timers});

  factory DueTimers.fromJson(Map<String, Object?> json) => DueTimers(
    timers: (json['timers'] as List<Object?>)
        .map((e0) => DueTimer.fromJson(e0! as Map<String, Object?>))
        .toList(),
  );

  final List<DueTimer> timers;

  Map<String, Object?> toJson() => {
    'timers': timers.map((e0) => e0.toJson()).toList(),
  };
}

@immutable
class EscalateIn {
  const EscalateIn({this.note});

  factory EscalateIn.fromJson(Map<String, Object?> json) =>
      EscalateIn(note: json['note'] as String?);

  final String? note;

  Map<String, Object?> toJson() => {'note': ?note};
}

@immutable
class EscalationOut {
  const EscalationOut({
    required this.booking,
    required this.kind,
    required this.note,
    required this.ownerName,
    required this.ownerPhone,
    required this.renterId,
    required this.renterName,
    required this.renterPhone,
    required this.renterResidence,
    required this.since,
  });

  factory EscalationOut.fromJson(Map<String, Object?> json) => EscalationOut(
    booking: BookingSummary.fromJson(json['booking'] as Map<String, Object?>),
    kind: EscalationKind.fromJson(json['kind'] as String),
    note: json['note'] as String?,
    ownerName: json['owner_name'] as String,
    ownerPhone: json['owner_phone'] as String?,
    renterId: json['renter_id'] as String,
    renterName: json['renter_name'] as String,
    renterPhone: json['renter_phone'] as String?,
    renterResidence: json['renter_residence'] == null
        ? null
        : Residence.fromJson(json['renter_residence'] as Map<String, Object?>),
    since: DateTime.parse(json['since'] as String),
  );

  final BookingSummary booking;

  final EscalationKind kind;

  final String? note;

  final String ownerName;

  final String? ownerPhone;

  final String renterId;

  final String renterName;

  final String? renterPhone;

  final Residence? renterResidence;

  final DateTime since;

  Map<String, Object?> toJson() => {
    'booking': booking.toJson(),
    'kind': kind.json,
    'note': note,
    'owner_name': ownerName,
    'owner_phone': ownerPhone,
    'renter_id': renterId,
    'renter_name': renterName,
    'renter_phone': renterPhone,
    'renter_residence': renterResidence?.toJson(),
    'since': since.toUtc().toIso8601String(),
  };
}

@immutable
class ExtensionIn {
  const ExtensionIn({required this.newEndAt});

  factory ExtensionIn.fromJson(Map<String, Object?> json) =>
      ExtensionIn(newEndAt: DateTime.parse(json['new_end_at'] as String));

  final DateTime newEndAt;

  Map<String, Object?> toJson() => {
    'new_end_at': newEndAt.toUtc().toIso8601String(),
  };
}

@immutable
class ExtensionOut {
  const ExtensionOut({
    required this.amountPaise,
    required this.createdAt,
    required this.id,
    required this.newEndAt,
    required this.payInCashAtReturn,
    required this.payment,
    required this.status,
  });

  factory ExtensionOut.fromJson(Map<String, Object?> json) => ExtensionOut(
    amountPaise: (json['amount_paise'] as num).toInt(),
    createdAt: DateTime.parse(json['created_at'] as String),
    id: json['id'] as String,
    newEndAt: DateTime.parse(json['new_end_at'] as String),
    payInCashAtReturn: json['pay_in_cash_at_return'] as bool,
    payment: json['payment'] == null
        ? null
        : PaymentOut.fromJson(json['payment'] as Map<String, Object?>),
    status: ExtensionStatus.fromJson(json['status'] as String),
  );

  final int amountPaise;

  final DateTime createdAt;

  final String id;

  final DateTime newEndAt;

  final bool payInCashAtReturn;

  final PaymentOut? payment;

  final ExtensionStatus status;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'created_at': createdAt.toUtc().toIso8601String(),
    'id': id,
    'new_end_at': newEndAt.toUtc().toIso8601String(),
    'pay_in_cash_at_return': payInCashAtReturn,
    'payment': payment?.toJson(),
    'status': status.json,
  };
}

@immutable
class FaqOut {
  const FaqOut({
    required this.answer,
    required this.id,
    required this.question,
    required this.topic,
  });

  factory FaqOut.fromJson(Map<String, Object?> json) => FaqOut(
    answer: json['answer'] as String,
    id: json['id'] as String,
    question: json['question'] as String,
    topic: json['topic'] as String,
  );

  final String answer;

  final String id;

  final String question;

  final String topic;

  Map<String, Object?> toJson() => {
    'answer': answer,
    'id': id,
    'question': question,
    'topic': topic,
  };
}

@immutable
class FireResult {
  const FireResult({required this.fired, required this.outcome});

  factory FireResult.fromJson(Map<String, Object?> json) => FireResult(
    fired: json['fired'] as bool,
    outcome: json['outcome'] as String,
  );

  final bool fired;

  final String outcome;

  Map<String, Object?> toJson() => {'fired': fired, 'outcome': outcome};
}

@immutable
class HTTPValidationError {
  const HTTPValidationError({this.detail});

  factory HTTPValidationError.fromJson(Map<String, Object?> json) =>
      HTTPValidationError(
        detail: json['detail'] == null
            ? null
            : (json['detail'] as List<Object?>)
                  .map(
                    (e0) =>
                        ValidationError.fromJson(e0! as Map<String, Object?>),
                  )
                  .toList(),
      );

  final List<ValidationError>? detail;

  Map<String, Object?> toJson() => {
    'detail': ?detail?.map((e0) => e0.toJson()).toList(),
  };
}

@immutable
class HandoffIn {
  const HandoffIn({this.bookingId, required this.message, this.transcript});

  factory HandoffIn.fromJson(Map<String, Object?> json) => HandoffIn(
    bookingId: json['booking_id'] as String?,
    message: json['message'] as String,
    transcript: json['transcript'] == null
        ? null
        : (json['transcript'] as List<Object?>)
              .map((e0) => TranscriptLine.fromJson(e0! as Map<String, Object?>))
              .toList(),
  );

  final String? bookingId;

  /// What the user needs
  final String message;

  final List<TranscriptLine>? transcript;

  Map<String, Object?> toJson() => {
    'booking_id': ?bookingId,
    'message': message,
    'transcript': ?transcript?.map((e0) => e0.toJson()).toList(),
  };
}

@immutable
class Handover {
  const Handover({
    required this.otpReady,
    required this.otpShownBy,
    required this.otpVerifiedAt,
    required this.owner,
    required this.phase,
    required this.renter,
  });

  factory Handover.fromJson(Map<String, Object?> json) => Handover(
    otpReady: json['otp_ready'] as bool,
    otpShownBy: TradeRole.fromJson(json['otp_shown_by'] as String),
    otpVerifiedAt: json['otp_verified_at'] == null
        ? null
        : DateTime.parse(json['otp_verified_at'] as String),
    owner: HandoverSide.fromJson(json['owner'] as Map<String, Object?>),
    phase: HandoverPhase.fromJson(json['phase'] as String),
    renter: HandoverSide.fromJson(json['renter'] as Map<String, Object?>),
  );

  /// Photos and payment are done; the code can be shown
  final bool otpReady;

  final TradeRole otpShownBy;

  final DateTime? otpVerifiedAt;

  final HandoverSide owner;

  final HandoverPhase phase;

  final HandoverSide renter;

  Map<String, Object?> toJson() => {
    'otp_ready': otpReady,
    'otp_shown_by': otpShownBy.json,
    'otp_verified_at': otpVerifiedAt?.toUtc().toIso8601String(),
    'owner': owner.toJson(),
    'phase': phase.json,
    'renter': renter.toJson(),
  };
}

@immutable
class HandoverSide {
  const HandoverSide({required this.done, required this.photos});

  factory HandoverSide.fromJson(Map<String, Object?> json) => HandoverSide(
    done: json['done'] as bool,
    photos: (json['photos'] as List<Object?>)
        .map((e0) => PhotoOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
  );

  final bool done;

  final List<PhotoOut> photos;

  Map<String, Object?> toJson() => {
    'done': done,
    'photos': photos.map((e0) => e0.toJson()).toList(),
  };
}

@immutable
class HomeOut {
  const HomeOut({
    required this.categories,
    required this.recent,
    required this.savedSearchMatches,
  });

  factory HomeOut.fromJson(Map<String, Object?> json) => HomeOut(
    categories: (json['categories'] as List<Object?>)
        .map((e0) => CategoryOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    recent: (json['recent'] as List<Object?>)
        .map((e0) => ListingCard.fromJson(e0! as Map<String, Object?>))
        .toList(),
    savedSearchMatches: (json['saved_search_matches'] as List<Object?>)
        .map((e0) => ListingCard.fromJson(e0! as Map<String, Object?>))
        .toList(),
  );

  final List<CategoryOut> categories;

  final List<ListingCard> recent;

  final List<ListingCard> savedSearchMatches;

  Map<String, Object?> toJson() => {
    'categories': categories.map((e0) => e0.toJson()).toList(),
    'recent': recent.map((e0) => e0.toJson()).toList(),
    'saved_search_matches': savedSearchMatches
        .map((e0) => e0.toJson())
        .toList(),
  };
}

@immutable
class LateFeeRuleOut {
  const LateFeeRuleOut({
    required this.baseFeePaise,
    required this.effectiveFrom,
    required this.graceMinutes,
    required this.hourlyPercentBp,
    required this.id,
  });

  factory LateFeeRuleOut.fromJson(Map<String, Object?> json) => LateFeeRuleOut(
    baseFeePaise: (json['base_fee_paise'] as num).toInt(),
    effectiveFrom: DateTime.parse(json['effective_from'] as String),
    graceMinutes: (json['grace_minutes'] as num).toInt(),
    hourlyPercentBp: (json['hourly_percent_bp'] as num).toInt(),
    id: json['id'] as String,
  );

  final int baseFeePaise;

  final DateTime effectiveFrom;

  final int graceMinutes;

  /// Basis points of the rent per hour: 200 = 2%
  final int hourlyPercentBp;

  final String id;

  Map<String, Object?> toJson() => {
    'base_fee_paise': baseFeePaise,
    'effective_from': effectiveFrom.toUtc().toIso8601String(),
    'grace_minutes': graceMinutes,
    'hourly_percent_bp': hourlyPercentBp,
    'id': id,
  };
}

@immutable
class ListingCard {
  const ListingCard({
    required this.category,
    required this.createdAt,
    required this.id,
    required this.kind,
    required this.owner,
    required this.photoUrl,
    required this.pickupPoint,
    required this.pricePerDayPaise,
    required this.pricePerHourPaise,
    required this.salePricePaise,
    required this.status,
    required this.title,
  });

  factory ListingCard.fromJson(Map<String, Object?> json) => ListingCard(
    category: ListingCategory.fromJson(json['category'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    id: json['id'] as String,
    kind: TradeKind.fromJson(json['kind'] as String),
    owner: OwnerSummary.fromJson(json['owner'] as Map<String, Object?>),
    photoUrl: json['photo_url'] as String?,
    pickupPoint: json['pickup_point'] as String,
    pricePerDayPaise: (json['price_per_day_paise'] as num?)?.toInt(),
    pricePerHourPaise: (json['price_per_hour_paise'] as num?)?.toInt(),
    salePricePaise: (json['sale_price_paise'] as num?)?.toInt(),
    status: ListingStatus.fromJson(json['status'] as String),
    title: json['title'] as String,
  );

  final ListingCategory category;

  final DateTime createdAt;

  final String id;

  final TradeKind kind;

  final OwnerSummary owner;

  final String? photoUrl;

  final String pickupPoint;

  final int? pricePerDayPaise;

  final int? pricePerHourPaise;

  final int? salePricePaise;

  final ListingStatus status;

  final String title;

  Map<String, Object?> toJson() => {
    'category': category.json,
    'created_at': createdAt.toUtc().toIso8601String(),
    'id': id,
    'kind': kind.json,
    'owner': owner.toJson(),
    'photo_url': photoUrl,
    'pickup_point': pickupPoint,
    'price_per_day_paise': pricePerDayPaise,
    'price_per_hour_paise': pricePerHourPaise,
    'sale_price_paise': salePricePaise,
    'status': status.json,
    'title': title,
  };
}

@immutable
class ListingCardPage {
  const ListingCardPage({required this.items, this.nextCursor});

  factory ListingCardPage.fromJson(Map<String, Object?> json) =>
      ListingCardPage(
        items: (json['items'] as List<Object?>)
            .map((e0) => ListingCard.fromJson(e0! as Map<String, Object?>))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );

  final List<ListingCard> items;

  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': items.map((e0) => e0.toJson()).toList(),
    'next_cursor': ?nextCursor,
  };
}

@immutable
class ListingCreate {
  const ListingCreate({
    this.assetId,
    required this.category,
    required this.condition,
    this.description = '',
    required this.kind,
    this.manufactureDate,
    required this.photoKeys,
    required this.pickupPoint,
    this.pricePerDayPaise,
    this.pricePerHourPaise,
    this.salePricePaise,
    this.serialNumber,
    required this.title,
  });

  factory ListingCreate.fromJson(Map<String, Object?> json) => ListingCreate(
    assetId: json['asset_id'] as String?,
    category: ListingCategory.fromJson(json['category'] as String),
    condition: ItemCondition.fromJson(json['condition'] as String),
    description: json['description'] == null
        ? ''
        : json['description'] as String,
    kind: TradeKind.fromJson(json['kind'] as String),
    manufactureDate: json['manufacture_date'] == null
        ? null
        : DateTime.parse(json['manufacture_date'] as String),
    photoKeys: (json['photo_keys'] as List<Object?>)
        .map((e0) => e0! as String)
        .toList(),
    pickupPoint: json['pickup_point'] as String,
    pricePerDayPaise: (json['price_per_day_paise'] as num?)?.toInt(),
    pricePerHourPaise: (json['price_per_hour_paise'] as num?)?.toInt(),
    salePricePaise: (json['sale_price_paise'] as num?)?.toInt(),
    serialNumber: json['serial_number'] as String?,
    title: json['title'] as String,
  );

  /// Relist an item you already own (for example one you bought)
  final String? assetId;

  final ListingCategory category;

  final ItemCondition condition;

  final String description;

  final TradeKind kind;

  final DateTime? manufactureDate;

  final List<String> photoKeys;

  final String pickupPoint;

  final int? pricePerDayPaise;

  final int? pricePerHourPaise;

  final int? salePricePaise;

  final String? serialNumber;

  final String title;

  Map<String, Object?> toJson() => {
    'asset_id': ?assetId,
    'category': category.json,
    'condition': condition.json,
    'description': description,
    'kind': kind.json,
    'manufacture_date': ?manufactureDate == null
        ? null
        : _formatDate(manufactureDate!),
    'photo_keys': photoKeys,
    'pickup_point': pickupPoint,
    'price_per_day_paise': ?pricePerDayPaise,
    'price_per_hour_paise': ?pricePerHourPaise,
    'sale_price_paise': ?salePricePaise,
    'serial_number': ?serialNumber,
    'title': title,
  };
}

@immutable
class ListingDetail {
  const ListingDetail({
    required this.asset,
    required this.canEdit,
    required this.category,
    required this.condition,
    required this.createdAt,
    required this.description,
    required this.id,
    required this.isMine,
    required this.kind,
    required this.lateFeeRule,
    required this.manufactureDate,
    required this.owner,
    this.pendingRequestCount,
    required this.photoUrl,
    required this.photos,
    required this.pickupPoint,
    required this.pricePerDayPaise,
    required this.pricePerHourPaise,
    required this.salePricePaise,
    required this.status,
    required this.title,
    required this.unavailable,
  });

  factory ListingDetail.fromJson(Map<String, Object?> json) => ListingDetail(
    asset: AssetOut.fromJson(json['asset'] as Map<String, Object?>),
    canEdit: json['can_edit'] as bool,
    category: ListingCategory.fromJson(json['category'] as String),
    condition: ItemCondition.fromJson(json['condition'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    description: json['description'] as String,
    id: json['id'] as String,
    isMine: json['is_mine'] as bool,
    kind: TradeKind.fromJson(json['kind'] as String),
    lateFeeRule: json['late_fee_rule'] == null
        ? null
        : LateFeeRuleOut.fromJson(
            json['late_fee_rule'] as Map<String, Object?>,
          ),
    manufactureDate: json['manufacture_date'] == null
        ? null
        : DateTime.parse(json['manufacture_date'] as String),
    owner: OwnerCard.fromJson(json['owner'] as Map<String, Object?>),
    pendingRequestCount: (json['pending_request_count'] as num?)?.toInt(),
    photoUrl: json['photo_url'] as String?,
    photos: (json['photos'] as List<Object?>)
        .map((e0) => PhotoOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    pickupPoint: json['pickup_point'] as String,
    pricePerDayPaise: (json['price_per_day_paise'] as num?)?.toInt(),
    pricePerHourPaise: (json['price_per_hour_paise'] as num?)?.toInt(),
    salePricePaise: (json['sale_price_paise'] as num?)?.toInt(),
    status: ListingStatus.fromJson(json['status'] as String),
    title: json['title'] as String,
    unavailable: (json['unavailable'] as List<Object?>)
        .map((e0) => BlockedSlot.fromJson(e0! as Map<String, Object?>))
        .toList(),
  );

  final AssetOut asset;

  /// False while a booking is approved or active
  final bool canEdit;

  final ListingCategory category;

  final ItemCondition condition;

  final DateTime createdAt;

  final String description;

  final String id;

  final bool isMine;

  final TradeKind kind;

  /// Shown on every rent listing
  final LateFeeRuleOut? lateFeeRule;

  final DateTime? manufactureDate;

  final OwnerCard owner;

  /// Owner only
  final int? pendingRequestCount;

  final String? photoUrl;

  final List<PhotoOut> photos;

  final String pickupPoint;

  final int? pricePerDayPaise;

  final int? pricePerHourPaise;

  final int? salePricePaise;

  final ListingStatus status;

  final String title;

  /// Approved bookings block these slots
  final List<BlockedSlot> unavailable;

  Map<String, Object?> toJson() => {
    'asset': asset.toJson(),
    'can_edit': canEdit,
    'category': category.json,
    'condition': condition.json,
    'created_at': createdAt.toUtc().toIso8601String(),
    'description': description,
    'id': id,
    'is_mine': isMine,
    'kind': kind.json,
    'late_fee_rule': lateFeeRule?.toJson(),
    'manufacture_date': manufactureDate == null
        ? null
        : _formatDate(manufactureDate!),
    'owner': owner.toJson(),
    'pending_request_count': ?pendingRequestCount,
    'photo_url': photoUrl,
    'photos': photos.map((e0) => e0.toJson()).toList(),
    'pickup_point': pickupPoint,
    'price_per_day_paise': pricePerDayPaise,
    'price_per_hour_paise': pricePerHourPaise,
    'sale_price_paise': salePricePaise,
    'status': status.json,
    'title': title,
    'unavailable': unavailable.map((e0) => e0.toJson()).toList(),
  };
}

/// Any field; refused while a booking is approved or active.
@immutable
class ListingUpdate {
  const ListingUpdate({
    this.category,
    this.condition,
    this.description,
    this.manufactureDate,
    this.pickupPoint,
    this.pricePerDayPaise,
    this.pricePerHourPaise,
    this.salePricePaise,
    this.serialNumber,
    this.title,
  });

  factory ListingUpdate.fromJson(Map<String, Object?> json) => ListingUpdate(
    category: json['category'] == null
        ? null
        : ListingCategory.fromJson(json['category'] as String),
    condition: json['condition'] == null
        ? null
        : ItemCondition.fromJson(json['condition'] as String),
    description: json['description'] as String?,
    manufactureDate: json['manufacture_date'] == null
        ? null
        : DateTime.parse(json['manufacture_date'] as String),
    pickupPoint: json['pickup_point'] as String?,
    pricePerDayPaise: (json['price_per_day_paise'] as num?)?.toInt(),
    pricePerHourPaise: (json['price_per_hour_paise'] as num?)?.toInt(),
    salePricePaise: (json['sale_price_paise'] as num?)?.toInt(),
    serialNumber: json['serial_number'] as String?,
    title: json['title'] as String?,
  );

  final ListingCategory? category;

  final ItemCondition? condition;

  final String? description;

  final DateTime? manufactureDate;

  final String? pickupPoint;

  final int? pricePerDayPaise;

  final int? pricePerHourPaise;

  final int? salePricePaise;

  final String? serialNumber;

  final String? title;

  Map<String, Object?> toJson() => {
    'category': ?category?.json,
    'condition': ?condition?.json,
    'description': ?description,
    'manufacture_date': ?manufactureDate == null
        ? null
        : _formatDate(manufactureDate!),
    'pickup_point': ?pickupPoint,
    'price_per_day_paise': ?pricePerDayPaise,
    'price_per_hour_paise': ?pricePerHourPaise,
    'sale_price_paise': ?salePricePaise,
    'serial_number': ?serialNumber,
    'title': ?title,
  };
}

@immutable
class MeOut {
  const MeOut({
    required this.account,
    required this.currentTermsVersion,
    required this.onboarding,
    required this.profile,
  });

  factory MeOut.fromJson(Map<String, Object?> json) => MeOut(
    account: AccountSummary.fromJson(json['account'] as Map<String, Object?>),
    currentTermsVersion: json['current_terms_version'] as String,
    onboarding: Onboarding.fromJson(json['onboarding'] as Map<String, Object?>),
    profile: json['profile'] == null
        ? null
        : ProfileOwn.fromJson(json['profile'] as Map<String, Object?>),
  );

  final AccountSummary account;

  final String currentTermsVersion;

  final Onboarding onboarding;

  final ProfileOwn? profile;

  Map<String, Object?> toJson() => {
    'account': account.toJson(),
    'current_terms_version': currentTermsVersion,
    'onboarding': onboarding.toJson(),
    'profile': profile?.toJson(),
  };
}

@immutable
class MetricsOut {
  const MetricsOut({
    required this.activeListings,
    required this.bookingsByState,
    required this.completedTrades,
    required this.openDisputes,
    required this.overdueCount,
    required this.paymentSuccessRate,
    required this.students,
  });

  factory MetricsOut.fromJson(Map<String, Object?> json) => MetricsOut(
    activeListings: (json['active_listings'] as num).toInt(),
    bookingsByState: (json['bookings_by_state'] as Map<String, Object?>).map(
      (k0, v0) => MapEntry(k0, (v0! as num).toInt()),
    ),
    completedTrades: (json['completed_trades'] as num).toInt(),
    openDisputes: (json['open_disputes'] as num).toInt(),
    overdueCount: (json['overdue_count'] as num).toInt(),
    paymentSuccessRate: (json['payment_success_rate'] as num?)?.toDouble(),
    students: (json['students'] as num).toInt(),
  );

  final int activeListings;

  final Map<String, int> bookingsByState;

  final int completedTrades;

  final int openDisputes;

  final int overdueCount;

  /// Last 30 days, 0-1
  final double? paymentSuccessRate;

  final int students;

  Map<String, Object?> toJson() => {
    'active_listings': activeListings,
    'bookings_by_state': bookingsByState,
    'completed_trades': completedTrades,
    'open_disputes': openDisputes,
    'overdue_count': overdueCount,
    'payment_success_rate': paymentSuccessRate,
    'students': students,
  };
}

@immutable
class MicrosoftSignIn {
  const MicrosoftSignIn({required this.idToken});

  factory MicrosoftSignIn.fromJson(Map<String, Object?> json) =>
      MicrosoftSignIn(idToken: json['id_token'] as String);

  final String idToken;

  Map<String, Object?> toJson() => {'id_token': idToken};
}

@immutable
class MismatchOut {
  const MismatchOut({
    required this.kind,
    required this.ledgerAmountPaise,
    required this.ledgerStatus,
    required this.paymentId,
    required this.razorpayAmountPaise,
    required this.razorpayStatus,
    required this.reference,
  });

  factory MismatchOut.fromJson(Map<String, Object?> json) => MismatchOut(
    kind: json['kind'] as String,
    ledgerAmountPaise: (json['ledger_amount_paise'] as num?)?.toInt(),
    ledgerStatus: json['ledger_status'] as String?,
    paymentId: json['payment_id'] as String?,
    razorpayAmountPaise: (json['razorpay_amount_paise'] as num?)?.toInt(),
    razorpayStatus: json['razorpay_status'] as String?,
    reference: json['reference'] as String,
  );

  final String kind;

  final int? ledgerAmountPaise;

  final String? ledgerStatus;

  final String? paymentId;

  final int? razorpayAmountPaise;

  final String? razorpayStatus;

  final String reference;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'ledger_amount_paise': ledgerAmountPaise,
    'ledger_status': ledgerStatus,
    'payment_id': paymentId,
    'razorpay_amount_paise': razorpayAmountPaise,
    'razorpay_status': razorpayStatus,
    'reference': reference,
  };
}

@immutable
class MockTokenOut {
  const MockTokenOut({required this.idToken});

  factory MockTokenOut.fromJson(Map<String, Object?> json) =>
      MockTokenOut(idToken: json['id_token'] as String);

  final String idToken;

  Map<String, Object?> toJson() => {'id_token': idToken};
}

@immutable
class MockTokenRequest {
  const MockTokenRequest({required this.email, this.name});

  factory MockTokenRequest.fromJson(Map<String, Object?> json) =>
      MockTokenRequest(
        email: json['email'] as String,
        name: json['name'] as String?,
      );

  final String email;

  final String? name;

  Map<String, Object?> toJson() => {'email': email, 'name': ?name};
}

@immutable
class ModeratorCreate {
  const ModeratorCreate({
    required this.email,
    required this.name,
    required this.temporaryPassword,
  });

  factory ModeratorCreate.fromJson(Map<String, Object?> json) =>
      ModeratorCreate(
        email: json['email'] as String,
        name: json['name'] as String,
        temporaryPassword: json['temporary_password'] as String,
      );

  final String email;

  final String name;

  final String temporaryPassword;

  Map<String, Object?> toJson() => {
    'email': email,
    'name': name,
    'temporary_password': temporaryPassword,
  };
}

/// The one thing due next, for the action card.
@immutable
class NextAction {
  const NextAction({
    required this.byMe,
    required this.key,
    required this.label,
  });

  factory NextAction.fromJson(Map<String, Object?> json) => NextAction(
    byMe: json['by_me'] as bool,
    key: json['key'] as String,
    label: json['label'] as String,
  );

  /// False when waiting for the other side
  final bool byMe;

  final String key;

  final String label;

  Map<String, Object?> toJson() => {'by_me': byMe, 'key': key, 'label': label};
}

@immutable
class Onboarding {
  const Onboarding({
    required this.complete,
    required this.phoneVerified,
    required this.profileComplete,
    required this.termsAccepted,
  });

  factory Onboarding.fromJson(Map<String, Object?> json) => Onboarding(
    complete: json['complete'] as bool,
    phoneVerified: json['phone_verified'] as bool,
    profileComplete: json['profile_complete'] as bool,
    termsAccepted: json['terms_accepted'] as bool,
  );

  final bool complete;

  final bool phoneVerified;

  final bool profileComplete;

  final bool termsAccepted;

  Map<String, Object?> toJson() => {
    'complete': complete,
    'phone_verified': phoneVerified,
    'profile_complete': profileComplete,
    'terms_accepted': termsAccepted,
  };
}

@immutable
class OtpIn {
  const OtpIn({required this.code});

  factory OtpIn.fromJson(Map<String, Object?> json) =>
      OtpIn(code: json['code'] as String);

  final String code;

  Map<String, Object?> toJson() => {'code': code};
}

/// Shown on one phone, typed into the other. Valid 15 minutes, 5 tries.
@immutable
class OtpOut {
  const OtpOut({required this.code, required this.expiresAt});

  factory OtpOut.fromJson(Map<String, Object?> json) => OtpOut(
    code: json['code'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );

  final String code;

  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
    'code': code,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
}

@immutable
class OwnerCard {
  const OwnerCard({
    required this.accountId,
    required this.cancellationCount,
    required this.fullName,
    required this.isNew,
    required this.lenderRating,
    required this.lenderTrust,
    required this.phone,
    required this.photoUrl,
  });

  factory OwnerCard.fromJson(Map<String, Object?> json) => OwnerCard(
    accountId: json['account_id'] as String,
    cancellationCount: (json['cancellation_count'] as num).toInt(),
    fullName: json['full_name'] as String,
    isNew: json['is_new'] as bool,
    lenderRating: (json['lender_rating'] as num?)?.toDouble(),
    lenderTrust: (json['lender_trust'] as num?)?.toInt(),
    phone: json['phone'] as String?,
    photoUrl: json['photo_url'] as String?,
  );

  final String accountId;

  final int cancellationCount;

  final String fullName;

  final bool isNew;

  final double? lenderRating;

  /// Null while the owner is New
  final int? lenderTrust;

  /// For the Call button
  final String? phone;

  final String? photoUrl;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'cancellation_count': cancellationCount,
    'full_name': fullName,
    'is_new': isNew,
    'lender_rating': lenderRating,
    'lender_trust': lenderTrust,
    'phone': phone,
    'photo_url': photoUrl,
  };
}

@immutable
class OwnerSummary {
  const OwnerSummary({
    required this.accountId,
    required this.fullName,
    required this.isNew,
    required this.lenderTrust,
    required this.photoUrl,
  });

  factory OwnerSummary.fromJson(Map<String, Object?> json) => OwnerSummary(
    accountId: json['account_id'] as String,
    fullName: json['full_name'] as String,
    isNew: json['is_new'] as bool,
    lenderTrust: (json['lender_trust'] as num?)?.toInt(),
    photoUrl: json['photo_url'] as String?,
  );

  final String accountId;

  final String fullName;

  final bool isNew;

  /// Null while the owner is New
  final int? lenderTrust;

  final String? photoUrl;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'full_name': fullName,
    'is_new': isNew,
    'lender_trust': lenderTrust,
    'photo_url': photoUrl,
  };
}

@immutable
class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.amountPaise,
    required this.bookingId,
    required this.capturedAt,
    required this.checkout,
    required this.counterpartyId,
    required this.createdAt,
    required this.direction,
    required this.id,
    required this.items,
    required this.method,
    required this.purpose,
    required this.refundedPaise,
    required this.refunds,
    required this.status,
  });

  factory PaymentHistoryItem.fromJson(Map<String, Object?> json) =>
      PaymentHistoryItem(
        amountPaise: (json['amount_paise'] as num).toInt(),
        bookingId: json['booking_id'] as String,
        capturedAt: json['captured_at'] == null
            ? null
            : DateTime.parse(json['captured_at'] as String),
        checkout: json['checkout'] == null
            ? null
            : RazorpayCheckout.fromJson(
                json['checkout'] as Map<String, Object?>,
              ),
        counterpartyId: json['counterparty_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        direction: Direction.fromJson(json['direction'] as String),
        id: json['id'] as String,
        items: (json['items'] as List<Object?>)
            .map((e0) => PaymentItem.fromJson(e0! as Map<String, Object?>))
            .toList(),
        method: PaymentMethod.fromJson(json['method'] as String),
        purpose: PaymentPurpose.fromJson(json['purpose'] as String),
        refundedPaise: (json['refunded_paise'] as num).toInt(),
        refunds: (json['refunds'] as List<Object?>)
            .map((e0) => RefundOut.fromJson(e0! as Map<String, Object?>))
            .toList(),
        status: PaymentStatus.fromJson(json['status'] as String),
      );

  final int amountPaise;

  final String bookingId;

  final DateTime? capturedAt;

  /// UPI only, while pending
  final RazorpayCheckout? checkout;

  final String counterpartyId;

  final DateTime createdAt;

  final Direction direction;

  final String id;

  final List<PaymentItem> items;

  final PaymentMethod method;

  final PaymentPurpose purpose;

  final int refundedPaise;

  final List<RefundOut> refunds;

  final PaymentStatus status;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'booking_id': bookingId,
    'captured_at': capturedAt?.toUtc().toIso8601String(),
    'checkout': checkout?.toJson(),
    'counterparty_id': counterpartyId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'direction': direction.json,
    'id': id,
    'items': items.map((e0) => e0.toJson()).toList(),
    'method': method.json,
    'purpose': purpose.json,
    'refunded_paise': refundedPaise,
    'refunds': refunds.map((e0) => e0.toJson()).toList(),
    'status': status.json,
  };
}

@immutable
class PaymentHistoryPage {
  const PaymentHistoryPage({required this.items, this.nextCursor});

  factory PaymentHistoryPage.fromJson(Map<String, Object?> json) =>
      PaymentHistoryPage(
        items: (json['items'] as List<Object?>)
            .map(
              (e0) => PaymentHistoryItem.fromJson(e0! as Map<String, Object?>),
            )
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );

  final List<PaymentHistoryItem> items;

  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': items.map((e0) => e0.toJson()).toList(),
    'next_cursor': ?nextCursor,
  };
}

@immutable
class PaymentItem {
  const PaymentItem({required this.amountPaise, required this.label});

  factory PaymentItem.fromJson(Map<String, Object?> json) => PaymentItem(
    amountPaise: (json['amount_paise'] as num).toInt(),
    label: json['label'] as String,
  );

  final int amountPaise;

  final String label;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'label': label,
  };
}

@immutable
class PaymentOut {
  const PaymentOut({
    required this.amountPaise,
    required this.capturedAt,
    required this.checkout,
    required this.createdAt,
    required this.id,
    required this.items,
    required this.method,
    required this.purpose,
    required this.status,
  });

  factory PaymentOut.fromJson(Map<String, Object?> json) => PaymentOut(
    amountPaise: (json['amount_paise'] as num).toInt(),
    capturedAt: json['captured_at'] == null
        ? null
        : DateTime.parse(json['captured_at'] as String),
    checkout: json['checkout'] == null
        ? null
        : RazorpayCheckout.fromJson(json['checkout'] as Map<String, Object?>),
    createdAt: DateTime.parse(json['created_at'] as String),
    id: json['id'] as String,
    items: (json['items'] as List<Object?>)
        .map((e0) => PaymentItem.fromJson(e0! as Map<String, Object?>))
        .toList(),
    method: PaymentMethod.fromJson(json['method'] as String),
    purpose: PaymentPurpose.fromJson(json['purpose'] as String),
    status: PaymentStatus.fromJson(json['status'] as String),
  );

  final int amountPaise;

  final DateTime? capturedAt;

  /// UPI only, while pending
  final RazorpayCheckout? checkout;

  final DateTime createdAt;

  final String id;

  final List<PaymentItem> items;

  final PaymentMethod method;

  final PaymentPurpose purpose;

  final PaymentStatus status;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'captured_at': capturedAt?.toUtc().toIso8601String(),
    'checkout': checkout?.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'id': id,
    'items': items.map((e0) => e0.toJson()).toList(),
    'method': method.json,
    'purpose': purpose.json,
    'status': status.json,
  };
}

@immutable
class PaymentStartIn {
  const PaymentStartIn({required this.method});

  factory PaymentStartIn.fromJson(Map<String, Object?> json) =>
      PaymentStartIn(method: PaymentMethod.fromJson(json['method'] as String));

  final PaymentMethod method;

  Map<String, Object?> toJson() => {'method': method.json};
}

/// Sent to Razorpay to create the linked account; never stored by UniRent.
@immutable
class PayoutAccountIn {
  const PayoutAccountIn({
    required this.accountNumber,
    required this.beneficiaryName,
    required this.email,
    required this.ifsc,
    required this.legalName,
    required this.phone,
  });

  factory PayoutAccountIn.fromJson(Map<String, Object?> json) =>
      PayoutAccountIn(
        accountNumber: json['account_number'] as String,
        beneficiaryName: json['beneficiary_name'] as String,
        email: json['email'] as String,
        ifsc: json['ifsc'] as String,
        legalName: json['legal_name'] as String,
        phone: json['phone'] as String,
      );

  final String accountNumber;

  final String beneficiaryName;

  final String email;

  final String ifsc;

  final String legalName;

  final String phone;

  Map<String, Object?> toJson() => {
    'account_number': accountNumber,
    'beneficiary_name': beneficiaryName,
    'email': email,
    'ifsc': ifsc,
    'legal_name': legalName,
    'phone': phone,
  };
}

@immutable
class PayoutAccountOut {
  const PayoutAccountOut({
    this.razorpayAccountId,
    required this.ready,
    required this.status,
    this.updatedAt,
  });

  factory PayoutAccountOut.fromJson(Map<String, Object?> json) =>
      PayoutAccountOut(
        razorpayAccountId: json['razorpay_account_id'] as String?,
        ready: json['ready'] as bool,
        status: PayoutAccountOutStatus.fromJson(json['status'] as String),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String),
      );

  final String? razorpayAccountId;

  /// True when listings can be posted
  final bool ready;

  final PayoutAccountOutStatus status;

  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
    'razorpay_account_id': ?razorpayAccountId,
    'ready': ready,
    'status': status.json,
    'updated_at': ?updatedAt?.toUtc().toIso8601String(),
  };
}

@immutable
class PenaltyIn {
  const PenaltyIn({
    required this.points,
    required this.reason,
    required this.role,
  });

  factory PenaltyIn.fromJson(Map<String, Object?> json) => PenaltyIn(
    points: (json['points'] as num).toInt(),
    reason: json['reason'] as String,
    role: TrustRole.fromJson(json['role'] as String),
  );

  final int points;

  final String reason;

  final TrustRole role;

  Map<String, Object?> toJson() => {
    'points': points,
    'reason': reason,
    'role': role.json,
  };
}

@immutable
class PenaltyOut {
  const PenaltyOut({
    required this.at,
    required this.by,
    required this.points,
    required this.reason,
    required this.role,
  });

  factory PenaltyOut.fromJson(Map<String, Object?> json) => PenaltyOut(
    at: DateTime.parse(json['at'] as String),
    by: json['by'] as String,
    points: (json['points'] as num).toInt(),
    reason: json['reason'] as String,
    role: TrustRole.fromJson(json['role'] as String),
  );

  final DateTime at;

  final String by;

  final int points;

  final String reason;

  final TrustRole role;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'by': by,
    'points': points,
    'reason': reason,
    'role': role.json,
  };
}

@immutable
class PhoneMockTokenOut {
  const PhoneMockTokenOut({required this.firebaseIdToken});

  factory PhoneMockTokenOut.fromJson(Map<String, Object?> json) =>
      PhoneMockTokenOut(firebaseIdToken: json['firebase_id_token'] as String);

  final String firebaseIdToken;

  Map<String, Object?> toJson() => {'firebase_id_token': firebaseIdToken};
}

@immutable
class PhoneMockTokenRequest {
  const PhoneMockTokenRequest({required this.code, required this.phone});

  factory PhoneMockTokenRequest.fromJson(Map<String, Object?> json) =>
      PhoneMockTokenRequest(
        code: json['code'] as String,
        phone: json['phone'] as String,
      );

  final String code;

  final String phone;

  Map<String, Object?> toJson() => {'code': code, 'phone': phone};
}

@immutable
class PhoneOut {
  const PhoneOut({required this.phone, required this.phoneVerifiedAt});

  factory PhoneOut.fromJson(Map<String, Object?> json) => PhoneOut(
    phone: json['phone'] as String,
    phoneVerifiedAt: DateTime.parse(json['phone_verified_at'] as String),
  );

  final String phone;

  final DateTime phoneVerifiedAt;

  Map<String, Object?> toJson() => {
    'phone': phone,
    'phone_verified_at': phoneVerifiedAt.toUtc().toIso8601String(),
  };
}

@immutable
class PhoneVerify {
  const PhoneVerify({required this.firebaseIdToken});

  factory PhoneVerify.fromJson(Map<String, Object?> json) =>
      PhoneVerify(firebaseIdToken: json['firebase_id_token'] as String);

  final String firebaseIdToken;

  Map<String, Object?> toJson() => {'firebase_id_token': firebaseIdToken};
}

@immutable
class PhotoAdd {
  const PhotoAdd({required this.objectKey});

  factory PhotoAdd.fromJson(Map<String, Object?> json) =>
      PhotoAdd(objectKey: json['object_key'] as String);

  final String objectKey;

  Map<String, Object?> toJson() => {'object_key': objectKey};
}

@immutable
class PhotoOut {
  const PhotoOut({required this.id, required this.url});

  factory PhotoOut.fromJson(Map<String, Object?> json) =>
      PhotoOut(id: json['id'] as String, url: json['url'] as String);

  final String id;

  final String url;

  Map<String, Object?> toJson() => {'id': id, 'url': url};
}

@immutable
class PhotosIn {
  const PhotosIn({required this.objectKeys});

  factory PhotosIn.fromJson(Map<String, Object?> json) => PhotosIn(
    objectKeys: (json['object_keys'] as List<Object?>)
        .map((e0) => e0! as String)
        .toList(),
  );

  final List<String> objectKeys;

  Map<String, Object?> toJson() => {'object_keys': objectKeys};
}

/// The other side of an approved booking also sees where to find them.
@immutable
class ProfileCounterparty extends ProfileView {
  const ProfileCounterparty({
    required this.accountId,
    required this.cancellationCount,
    required this.completedTrades,
    required this.department,
    required this.fullName,
    required this.isNew,
    required this.lender,
    required this.memberSince,
    required this.phone,
    required this.photoUrl,
    required this.renter,
    required this.residence,
    required this.year,
  });

  factory ProfileCounterparty.fromJson(Map<String, Object?> json) =>
      ProfileCounterparty(
        accountId: json['account_id'] as String,
        cancellationCount: (json['cancellation_count'] as num).toInt(),
        completedTrades: (json['completed_trades'] as num).toInt(),
        department: json['department'] as String,
        fullName: json['full_name'] as String,
        isNew: json['is_new'] as bool,
        lender: TrustSummary.fromJson(json['lender'] as Map<String, Object?>),
        memberSince: DateTime.parse(json['member_since'] as String),
        phone: json['phone'] as String?,
        photoUrl: json['photo_url'] as String?,
        renter: TrustSummary.fromJson(json['renter'] as Map<String, Object?>),
        residence: Residence.fromJson(
          json['residence'] as Map<String, Object?>,
        ),
        year: (json['year'] as num).toInt(),
      );

  @override
  final String accountId;

  @override
  final int cancellationCount;

  @override
  final int completedTrades;

  @override
  final String department;

  @override
  final String fullName;

  /// Fewer than 5 completed trades: show the New badge
  @override
  final bool isNew;

  @override
  final TrustSummary lender;

  @override
  final DateTime memberSince;

  @override
  final String? phone;

  @override
  final String? photoUrl;

  @override
  final TrustSummary renter;

  final Residence residence;

  @override
  String get view => 'counterparty';

  @override
  final int year;

  @override
  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'cancellation_count': cancellationCount,
    'completed_trades': completedTrades,
    'department': department,
    'full_name': fullName,
    'is_new': isNew,
    'lender': lender.toJson(),
    'member_since': memberSince.toUtc().toIso8601String(),
    'phone': phone,
    'photo_url': photoUrl,
    'renter': renter.toJson(),
    'residence': residence.toJson(),
    'view': view,
    'year': year,
  };
}

/// Everything on the onboarding form. The college email comes from sign-in.
@immutable
class ProfileIn {
  const ProfileIn({
    required this.department,
    required this.fullName,
    this.homeAddress,
    this.hostelName,
    this.photoKey,
    required this.residenceType,
    required this.rollNumber,
    this.roomNumber,
    required this.year,
  });

  factory ProfileIn.fromJson(Map<String, Object?> json) => ProfileIn(
    department: json['department'] as String,
    fullName: json['full_name'] as String,
    homeAddress: json['home_address'] as String?,
    hostelName: json['hostel_name'] as String?,
    photoKey: json['photo_key'] as String?,
    residenceType: ResidenceType.fromJson(json['residence_type'] as String),
    rollNumber: json['roll_number'] as String,
    roomNumber: json['room_number'] as String?,
    year: (json['year'] as num).toInt(),
  );

  final String department;

  final String fullName;

  final String? homeAddress;

  final String? hostelName;

  /// From POST /uploads/photos
  final String? photoKey;

  final ResidenceType residenceType;

  final String rollNumber;

  final String? roomNumber;

  final int year;

  Map<String, Object?> toJson() => {
    'department': department,
    'full_name': fullName,
    'home_address': ?homeAddress,
    'hostel_name': ?hostelName,
    'photo_key': ?photoKey,
    'residence_type': residenceType.json,
    'roll_number': rollNumber,
    'room_number': ?roomNumber,
    'year': year,
  };
}

@immutable
class ProfileOwn extends ProfileView {
  const ProfileOwn({
    required this.accountId,
    required this.cancellationCount,
    required this.completedTrades,
    required this.department,
    required this.email,
    required this.fullName,
    required this.isNew,
    required this.lender,
    required this.memberSince,
    required this.phone,
    required this.photoKey,
    required this.photoUrl,
    required this.renter,
    required this.residence,
    required this.rollNumber,
    required this.status,
    required this.year,
  });

  factory ProfileOwn.fromJson(Map<String, Object?> json) => ProfileOwn(
    accountId: json['account_id'] as String,
    cancellationCount: (json['cancellation_count'] as num).toInt(),
    completedTrades: (json['completed_trades'] as num).toInt(),
    department: json['department'] as String,
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    isNew: json['is_new'] as bool,
    lender: TrustSummary.fromJson(json['lender'] as Map<String, Object?>),
    memberSince: DateTime.parse(json['member_since'] as String),
    phone: json['phone'] as String?,
    photoKey: json['photo_key'] as String?,
    photoUrl: json['photo_url'] as String?,
    renter: TrustSummary.fromJson(json['renter'] as Map<String, Object?>),
    residence: Residence.fromJson(json['residence'] as Map<String, Object?>),
    rollNumber: json['roll_number'] as String,
    status: json['status'] as String,
    year: (json['year'] as num).toInt(),
  );

  @override
  final String accountId;

  @override
  final int cancellationCount;

  @override
  final int completedTrades;

  @override
  final String department;

  final String email;

  @override
  final String fullName;

  /// Fewer than 5 completed trades: show the New badge
  @override
  final bool isNew;

  @override
  final TrustSummary lender;

  @override
  final DateTime memberSince;

  @override
  final String? phone;

  final String? photoKey;

  @override
  final String? photoUrl;

  @override
  final TrustSummary renter;

  final Residence residence;

  final String rollNumber;

  final String status;

  @override
  String get view => 'own';

  @override
  final int year;

  @override
  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'cancellation_count': cancellationCount,
    'completed_trades': completedTrades,
    'department': department,
    'email': email,
    'full_name': fullName,
    'is_new': isNew,
    'lender': lender.toJson(),
    'member_since': memberSince.toUtc().toIso8601String(),
    'phone': phone,
    'photo_key': photoKey,
    'photo_url': photoUrl,
    'renter': renter.toJson(),
    'residence': residence.toJson(),
    'roll_number': rollNumber,
    'status': status,
    'view': view,
    'year': year,
  };
}

/// What everyone sees.
@immutable
class ProfilePublic extends ProfileView {
  const ProfilePublic({
    required this.accountId,
    required this.cancellationCount,
    required this.completedTrades,
    required this.department,
    required this.fullName,
    required this.isNew,
    required this.lender,
    required this.memberSince,
    required this.phone,
    required this.photoUrl,
    required this.renter,
    required this.year,
  });

  factory ProfilePublic.fromJson(Map<String, Object?> json) => ProfilePublic(
    accountId: json['account_id'] as String,
    cancellationCount: (json['cancellation_count'] as num).toInt(),
    completedTrades: (json['completed_trades'] as num).toInt(),
    department: json['department'] as String,
    fullName: json['full_name'] as String,
    isNew: json['is_new'] as bool,
    lender: TrustSummary.fromJson(json['lender'] as Map<String, Object?>),
    memberSince: DateTime.parse(json['member_since'] as String),
    phone: json['phone'] as String?,
    photoUrl: json['photo_url'] as String?,
    renter: TrustSummary.fromJson(json['renter'] as Map<String, Object?>),
    year: (json['year'] as num).toInt(),
  );

  @override
  final String accountId;

  @override
  final int cancellationCount;

  @override
  final int completedTrades;

  @override
  final String department;

  @override
  final String fullName;

  /// Fewer than 5 completed trades: show the New badge
  @override
  final bool isNew;

  @override
  final TrustSummary lender;

  @override
  final DateTime memberSince;

  @override
  final String? phone;

  @override
  final String? photoUrl;

  @override
  final TrustSummary renter;

  @override
  String get view => 'public';

  @override
  final int year;

  @override
  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'cancellation_count': cancellationCount,
    'completed_trades': completedTrades,
    'department': department,
    'full_name': fullName,
    'is_new': isNew,
    'lender': lender.toJson(),
    'member_since': memberSince.toUtc().toIso8601String(),
    'phone': phone,
    'photo_url': photoUrl,
    'renter': renter.toJson(),
    'view': view,
    'year': year,
  };
}

@immutable
class ProfileStaff extends ProfileView {
  const ProfileStaff({
    required this.accountId,
    required this.cancellationCount,
    required this.completedTrades,
    required this.department,
    required this.email,
    required this.fullName,
    required this.isNew,
    required this.lender,
    required this.memberSince,
    required this.phone,
    required this.photoUrl,
    required this.renter,
    required this.residence,
    required this.rollNumber,
    required this.status,
    required this.year,
  });

  factory ProfileStaff.fromJson(Map<String, Object?> json) => ProfileStaff(
    accountId: json['account_id'] as String,
    cancellationCount: (json['cancellation_count'] as num).toInt(),
    completedTrades: (json['completed_trades'] as num).toInt(),
    department: json['department'] as String,
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    isNew: json['is_new'] as bool,
    lender: TrustSummary.fromJson(json['lender'] as Map<String, Object?>),
    memberSince: DateTime.parse(json['member_since'] as String),
    phone: json['phone'] as String?,
    photoUrl: json['photo_url'] as String?,
    renter: TrustSummary.fromJson(json['renter'] as Map<String, Object?>),
    residence: Residence.fromJson(json['residence'] as Map<String, Object?>),
    rollNumber: json['roll_number'] as String,
    status: json['status'] as String,
    year: (json['year'] as num).toInt(),
  );

  @override
  final String accountId;

  @override
  final int cancellationCount;

  @override
  final int completedTrades;

  @override
  final String department;

  final String email;

  @override
  final String fullName;

  /// Fewer than 5 completed trades: show the New badge
  @override
  final bool isNew;

  @override
  final TrustSummary lender;

  @override
  final DateTime memberSince;

  @override
  final String? phone;

  @override
  final String? photoUrl;

  @override
  final TrustSummary renter;

  final Residence residence;

  final String rollNumber;

  final String status;

  @override
  String get view => 'staff';

  @override
  final int year;

  @override
  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'cancellation_count': cancellationCount,
    'completed_trades': completedTrades,
    'department': department,
    'email': email,
    'full_name': fullName,
    'is_new': isNew,
    'lender': lender.toJson(),
    'member_since': memberSince.toUtc().toIso8601String(),
    'phone': phone,
    'photo_url': photoUrl,
    'renter': renter.toJson(),
    'residence': residence.toJson(),
    'roll_number': rollNumber,
    'status': status,
    'view': view,
    'year': year,
  };
}

@immutable
class PushTokenIn {
  const PushTokenIn({required this.platform, required this.token});

  factory PushTokenIn.fromJson(Map<String, Object?> json) => PushTokenIn(
    platform: DevicePlatform.fromJson(json['platform'] as String),
    token: json['token'] as String,
  );

  final DevicePlatform platform;

  final String token;

  Map<String, Object?> toJson() => {'platform': platform.json, 'token': token};
}

@immutable
class PushTokensOut {
  const PushTokensOut({required this.tokens});

  factory PushTokensOut.fromJson(Map<String, Object?> json) => PushTokensOut(
    tokens: (json['tokens'] as List<Object?>)
        .map((e0) => e0! as String)
        .toList(),
  );

  final List<String> tokens;

  Map<String, Object?> toJson() => {'tokens': tokens};
}

/// The request summary: what the renter will pay, before sending.
@immutable
class QuoteOut {
  const QuoteOut({
    required this.amountPaise,
    required this.endAt,
    required this.hours,
    required this.kind,
    required this.lateFeeRule,
    required this.listingId,
    required this.startAt,
  });

  factory QuoteOut.fromJson(Map<String, Object?> json) => QuoteOut(
    amountPaise: (json['amount_paise'] as num).toInt(),
    endAt: json['end_at'] == null
        ? null
        : DateTime.parse(json['end_at'] as String),
    hours: (json['hours'] as num?)?.toInt(),
    kind: TradeKind.fromJson(json['kind'] as String),
    lateFeeRule: json['late_fee_rule'] == null
        ? null
        : LateFeeRuleOut.fromJson(
            json['late_fee_rule'] as Map<String, Object?>,
          ),
    listingId: json['listing_id'] as String,
    startAt: json['start_at'] == null
        ? null
        : DateTime.parse(json['start_at'] as String),
  );

  final int amountPaise;

  final DateTime? endAt;

  final int? hours;

  final TradeKind kind;

  final LateFeeRuleOut? lateFeeRule;

  final String listingId;

  final DateTime? startAt;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'end_at': endAt?.toUtc().toIso8601String(),
    'hours': hours,
    'kind': kind.json,
    'late_fee_rule': lateFeeRule?.toJson(),
    'listing_id': listingId,
    'start_at': startAt?.toUtc().toIso8601String(),
  };
}

/// Everything Razorpay Checkout needs to open.
@immutable
class RazorpayCheckout {
  const RazorpayCheckout({
    required this.amountPaise,
    this.currency = 'INR',
    required this.description,
    required this.keyId,
    required this.name,
    required this.orderId,
    this.prefillContact,
    this.prefillEmail,
  });

  factory RazorpayCheckout.fromJson(Map<String, Object?> json) =>
      RazorpayCheckout(
        amountPaise: (json['amount_paise'] as num).toInt(),
        currency: json['currency'] == null ? 'INR' : json['currency'] as String,
        description: json['description'] as String,
        keyId: json['key_id'] as String,
        name: json['name'] as String,
        orderId: json['order_id'] as String,
        prefillContact: json['prefill_contact'] as String?,
        prefillEmail: json['prefill_email'] as String?,
      );

  final int amountPaise;

  final String currency;

  final String description;

  final String keyId;

  final String name;

  final String orderId;

  final String? prefillContact;

  final String? prefillEmail;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'currency': currency,
    'description': description,
    'key_id': keyId,
    'name': name,
    'order_id': orderId,
    'prefill_contact': ?prefillContact,
    'prefill_email': ?prefillEmail,
  };
}

@immutable
class ReasonIn {
  const ReasonIn({required this.reason});

  factory ReasonIn.fromJson(Map<String, Object?> json) =>
      ReasonIn(reason: json['reason'] as String);

  final String reason;

  Map<String, Object?> toJson() => {'reason': reason};
}

@immutable
class ReconciliationReport {
  const ReconciliationReport({
    required this.day,
    required this.finishedAt,
    required this.id,
    required this.mismatches,
    required this.startedAt,
    required this.status,
    required this.totals,
    required this.triggeredBy,
  });

  factory ReconciliationReport.fromJson(Map<String, Object?> json) =>
      ReconciliationReport(
        day: DateTime.parse(json['day'] as String),
        finishedAt: json['finished_at'] == null
            ? null
            : DateTime.parse(json['finished_at'] as String),
        id: json['id'] as String,
        mismatches: (json['mismatches'] as List<Object?>)
            .map((e0) => MismatchOut.fromJson(e0! as Map<String, Object?>))
            .toList(),
        startedAt: DateTime.parse(json['started_at'] as String),
        status: ReconciliationReportStatus.fromJson(json['status'] as String),
        totals: Map<String, Object?>.of(json['totals'] as Map<String, Object?>),
        triggeredBy: json['triggered_by'] as String,
      );

  final DateTime day;

  final DateTime? finishedAt;

  final String id;

  final List<MismatchOut> mismatches;

  final DateTime startedAt;

  final ReconciliationReportStatus status;

  final Map<String, Object?> totals;

  final String triggeredBy;

  Map<String, Object?> toJson() => {
    'day': _formatDate(day),
    'finished_at': finishedAt?.toUtc().toIso8601String(),
    'id': id,
    'mismatches': mismatches.map((e0) => e0.toJson()).toList(),
    'started_at': startedAt.toUtc().toIso8601String(),
    'status': status.json,
    'totals': totals,
    'triggered_by': triggeredBy,
  };
}

@immutable
class ReconciliationRunIn {
  const ReconciliationRunIn({this.day});

  factory ReconciliationRunIn.fromJson(Map<String, Object?> json) =>
      ReconciliationRunIn(
        day: json['day'] == null ? null : DateTime.parse(json['day'] as String),
      );

  /// The IST day to check; yesterday by default
  final DateTime? day;

  Map<String, Object?> toJson() => {
    'day': ?day == null ? null : _formatDate(day!),
  };
}

@immutable
class ReconciliationRunOut {
  const ReconciliationRunOut({
    required this.day,
    required this.finishedAt,
    required this.id,
    required this.startedAt,
    required this.status,
    required this.totals,
    required this.triggeredBy,
  });

  factory ReconciliationRunOut.fromJson(Map<String, Object?> json) =>
      ReconciliationRunOut(
        day: DateTime.parse(json['day'] as String),
        finishedAt: json['finished_at'] == null
            ? null
            : DateTime.parse(json['finished_at'] as String),
        id: json['id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        status: ReconciliationReportStatus.fromJson(json['status'] as String),
        totals: Map<String, Object?>.of(json['totals'] as Map<String, Object?>),
        triggeredBy: json['triggered_by'] as String,
      );

  final DateTime day;

  final DateTime? finishedAt;

  final String id;

  final DateTime startedAt;

  final ReconciliationReportStatus status;

  final Map<String, Object?> totals;

  final String triggeredBy;

  Map<String, Object?> toJson() => {
    'day': _formatDate(day),
    'finished_at': finishedAt?.toUtc().toIso8601String(),
    'id': id,
    'started_at': startedAt.toUtc().toIso8601String(),
    'status': status.json,
    'totals': totals,
    'triggered_by': triggeredBy,
  };
}

@immutable
class RefreshRequest {
  const RefreshRequest({required this.refreshToken});

  factory RefreshRequest.fromJson(Map<String, Object?> json) =>
      RefreshRequest(refreshToken: json['refresh_token'] as String);

  final String refreshToken;

  Map<String, Object?> toJson() => {'refresh_token': refreshToken};
}

@immutable
class RefundOut {
  const RefundOut({
    required this.amountPaise,
    required this.createdAt,
    required this.id,
    required this.method,
    required this.paymentId,
    required this.processedAt,
    required this.status,
  });

  factory RefundOut.fromJson(Map<String, Object?> json) => RefundOut(
    amountPaise: (json['amount_paise'] as num).toInt(),
    createdAt: DateTime.parse(json['created_at'] as String),
    id: json['id'] as String,
    method: PaymentMethod.fromJson(json['method'] as String),
    paymentId: json['payment_id'] as String,
    processedAt: json['processed_at'] == null
        ? null
        : DateTime.parse(json['processed_at'] as String),
    status: RefundOutStatus.fromJson(json['status'] as String),
  );

  final int amountPaise;

  final DateTime createdAt;

  final String id;

  final PaymentMethod method;

  final String paymentId;

  final DateTime? processedAt;

  final RefundOutStatus status;

  Map<String, Object?> toJson() => {
    'amount_paise': amountPaise,
    'created_at': createdAt.toUtc().toIso8601String(),
    'id': id,
    'method': method.json,
    'payment_id': paymentId,
    'processed_at': processedAt?.toUtc().toIso8601String(),
    'status': status.json,
  };
}

@immutable
class Residence {
  const Residence({
    required this.homeAddress,
    required this.hostelName,
    required this.roomNumber,
    required this.type,
  });

  factory Residence.fromJson(Map<String, Object?> json) => Residence(
    homeAddress: json['home_address'] as String?,
    hostelName: json['hostel_name'] as String?,
    roomNumber: json['room_number'] as String?,
    type: ResidenceType.fromJson(json['type'] as String),
  );

  final String? homeAddress;

  final String? hostelName;

  final String? roomNumber;

  final ResidenceType type;

  Map<String, Object?> toJson() => {
    'home_address': homeAddress,
    'hostel_name': hostelName,
    'room_number': roomNumber,
    'type': type.json,
  };
}

@immutable
class ReviewForm {
  const ReviewForm({
    required this.counterpartyId,
    required this.counterpartyName,
    required this.parameters,
    required this.reviewType,
  });

  factory ReviewForm.fromJson(Map<String, Object?> json) => ReviewForm(
    counterpartyId: json['counterparty_id'] as String,
    counterpartyName: json['counterparty_name'] as String,
    parameters: (json['parameters'] as List<Object?>)
        .map((e0) => ReviewParameter.fromJson(e0! as Map<String, Object?>))
        .toList(),
    reviewType: ReviewType.fromJson(json['review_type'] as String),
  );

  final String counterpartyId;

  final String counterpartyName;

  final List<ReviewParameter> parameters;

  final ReviewType reviewType;

  Map<String, Object?> toJson() => {
    'counterparty_id': counterpartyId,
    'counterparty_name': counterpartyName,
    'parameters': parameters.map((e0) => e0.toJson()).toList(),
    'review_type': reviewType.json,
  };
}

@immutable
class ReviewIn {
  const ReviewIn({required this.comment, required this.ratings});

  factory ReviewIn.fromJson(Map<String, Object?> json) => ReviewIn(
    comment: json['comment'] as String,
    ratings: (json['ratings'] as Map<String, Object?>).map(
      (k0, v0) => MapEntry(k0, (v0! as num).toInt()),
    ),
  );

  final String comment;

  /// Parameter key to 1-5 stars
  final Map<String, int> ratings;

  Map<String, Object?> toJson() => {'comment': comment, 'ratings': ratings};
}

@immutable
class ReviewOut {
  const ReviewOut({
    required this.bookingId,
    required this.comment,
    required this.createdAt,
    required this.id,
    required this.overall,
    required this.ratings,
    required this.reviewType,
    required this.reviewerId,
    required this.reviewerName,
  });

  factory ReviewOut.fromJson(Map<String, Object?> json) => ReviewOut(
    bookingId: json['booking_id'] as String,
    comment: json['comment'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    id: json['id'] as String,
    overall: (json['overall'] as num).toDouble(),
    ratings: (json['ratings'] as Map<String, Object?>).map(
      (k0, v0) => MapEntry(k0, (v0! as num).toInt()),
    ),
    reviewType: ReviewType.fromJson(json['review_type'] as String),
    reviewerId: json['reviewer_id'] as String,
    reviewerName: json['reviewer_name'] as String,
  );

  final String bookingId;

  final String comment;

  final DateTime createdAt;

  final String id;

  final double overall;

  final Map<String, int> ratings;

  final ReviewType reviewType;

  final String reviewerId;

  final String reviewerName;

  Map<String, Object?> toJson() => {
    'booking_id': bookingId,
    'comment': comment,
    'created_at': createdAt.toUtc().toIso8601String(),
    'id': id,
    'overall': overall,
    'ratings': ratings,
    'review_type': reviewType.json,
    'reviewer_id': reviewerId,
    'reviewer_name': reviewerName,
  };
}

@immutable
class ReviewOutPage {
  const ReviewOutPage({required this.items, this.nextCursor});

  factory ReviewOutPage.fromJson(Map<String, Object?> json) => ReviewOutPage(
    items: (json['items'] as List<Object?>)
        .map((e0) => ReviewOut.fromJson(e0! as Map<String, Object?>))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
  );

  final List<ReviewOut> items;

  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': items.map((e0) => e0.toJson()).toList(),
    'next_cursor': ?nextCursor,
  };
}

@immutable
class ReviewParameter {
  const ReviewParameter({required this.key, required this.label});

  factory ReviewParameter.fromJson(Map<String, Object?> json) =>
      ReviewParameter(
        key: json['key'] as String,
        label: json['label'] as String,
      );

  final String key;

  final String label;

  Map<String, Object?> toJson() => {'key': key, 'label': label};
}

@immutable
class ReviewState {
  const ReviewState({
    required this.mineSubmitted,
    required this.releaseAt,
    required this.revealed,
    required this.theirsSubmitted,
  });

  factory ReviewState.fromJson(Map<String, Object?> json) => ReviewState(
    mineSubmitted: json['mine_submitted'] as bool,
    releaseAt: json['release_at'] == null
        ? null
        : DateTime.parse(json['release_at'] as String),
    revealed: json['revealed'] as bool,
    theirsSubmitted: json['theirs_submitted'] as bool,
  );

  final bool mineSubmitted;

  final DateTime? releaseAt;

  final bool revealed;

  final bool theirsSubmitted;

  Map<String, Object?> toJson() => {
    'mine_submitted': mineSubmitted,
    'release_at': releaseAt?.toUtc().toIso8601String(),
    'revealed': revealed,
    'theirs_submitted': theirsSubmitted,
  };
}

@immutable
class RiskFlag {
  const RiskFlag({
    required this.count,
    required this.kind,
    required this.windowDays,
  });

  factory RiskFlag.fromJson(Map<String, Object?> json) => RiskFlag(
    count: (json['count'] as num).toInt(),
    kind: RiskFlagKind.fromJson(json['kind'] as String),
    windowDays: (json['window_days'] as num?)?.toInt(),
  );

  final int count;

  final RiskFlagKind kind;

  final int? windowDays;

  Map<String, Object?> toJson() => {
    'count': count,
    'kind': kind.json,
    'window_days': windowDays,
  };
}

/// Any combination of outcomes. The booking then moves on to reviews.
@immutable
class RulingIn {
  const RulingIn({
    this.accountAction,
    this.chargePaise,
    this.refundPaise,
    this.removeListing = false,
    required this.summary,
    this.trustPenalty,
  });

  factory RulingIn.fromJson(Map<String, Object?> json) => RulingIn(
    accountAction: json['account_action'] == null
        ? null
        : AccountAction.fromJson(
            json['account_action'] as Map<String, Object?>,
          ),
    chargePaise: (json['charge_paise'] as num?)?.toInt(),
    refundPaise: (json['refund_paise'] as num?)?.toInt(),
    removeListing: json['remove_listing'] == null
        ? false
        : json['remove_listing'] as bool,
    summary: json['summary'] as String,
    trustPenalty: json['trust_penalty'] == null
        ? null
        : TrustPenalty.fromJson(json['trust_penalty'] as Map<String, Object?>),
  );

  final AccountAction? accountAction;

  /// Damage charge the renter owes
  final int? chargePaise;

  /// Refund to the renter or buyer
  final int? refundPaise;

  final bool removeListing;

  /// Sent to both sides
  final String summary;

  final TrustPenalty? trustPenalty;

  Map<String, Object?> toJson() => {
    'account_action': ?accountAction?.toJson(),
    'charge_paise': ?chargePaise,
    'refund_paise': ?refundPaise,
    'remove_listing': removeListing,
    'summary': summary,
    'trust_penalty': ?trustPenalty?.toJson(),
  };
}

@immutable
class RulingOut {
  const RulingOut({
    this.accountAction,
    this.chargePaise,
    required this.id,
    this.overrules,
    this.refundPaise,
    this.removeListing = false,
    required this.ruledAt,
    required this.ruledBy,
    required this.summary,
    this.trustPenalty,
  });

  factory RulingOut.fromJson(Map<String, Object?> json) => RulingOut(
    accountAction: json['account_action'] == null
        ? null
        : AccountAction.fromJson(
            json['account_action'] as Map<String, Object?>,
          ),
    chargePaise: (json['charge_paise'] as num?)?.toInt(),
    id: json['id'] as String,
    overrules: json['overrules'] as String?,
    refundPaise: (json['refund_paise'] as num?)?.toInt(),
    removeListing: json['remove_listing'] == null
        ? false
        : json['remove_listing'] as bool,
    ruledAt: DateTime.parse(json['ruled_at'] as String),
    ruledBy: json['ruled_by'] as String,
    summary: json['summary'] as String,
    trustPenalty: json['trust_penalty'] == null
        ? null
        : TrustPenalty.fromJson(json['trust_penalty'] as Map<String, Object?>),
  );

  final AccountAction? accountAction;

  /// Damage charge the renter owes
  final int? chargePaise;

  final String id;

  final String? overrules;

  /// Refund to the renter or buyer
  final int? refundPaise;

  final bool removeListing;

  final DateTime ruledAt;

  final String ruledBy;

  /// Sent to both sides
  final String summary;

  final TrustPenalty? trustPenalty;

  Map<String, Object?> toJson() => {
    'account_action': ?accountAction?.toJson(),
    'charge_paise': ?chargePaise,
    'id': id,
    'overrules': ?overrules,
    'refund_paise': ?refundPaise,
    'remove_listing': removeListing,
    'ruled_at': ruledAt.toUtc().toIso8601String(),
    'ruled_by': ruledBy,
    'summary': summary,
    'trust_penalty': ?trustPenalty?.toJson(),
  };
}

@immutable
class SavedSearchIn {
  const SavedSearchIn({
    this.category,
    this.kind,
    this.maxPricePaise,
    this.minPricePaise,
    this.name,
    this.q,
  });

  factory SavedSearchIn.fromJson(Map<String, Object?> json) => SavedSearchIn(
    category: json['category'] == null
        ? null
        : ListingCategory.fromJson(json['category'] as String),
    kind: json['kind'] == null
        ? null
        : TradeKind.fromJson(json['kind'] as String),
    maxPricePaise: (json['max_price_paise'] as num?)?.toInt(),
    minPricePaise: (json['min_price_paise'] as num?)?.toInt(),
    name: json['name'] as String?,
    q: json['q'] as String?,
  );

  final ListingCategory? category;

  final TradeKind? kind;

  final int? maxPricePaise;

  final int? minPricePaise;

  final String? name;

  final String? q;

  Map<String, Object?> toJson() => {
    'category': ?category?.json,
    'kind': ?kind?.json,
    'max_price_paise': ?maxPricePaise,
    'min_price_paise': ?minPricePaise,
    'name': ?name,
    'q': ?q,
  };
}

@immutable
class SavedSearchMatch {
  const SavedSearchMatch({
    required this.accountId,
    required this.name,
    required this.savedSearchId,
  });

  factory SavedSearchMatch.fromJson(Map<String, Object?> json) =>
      SavedSearchMatch(
        accountId: json['account_id'] as String,
        name: json['name'] as String?,
        savedSearchId: json['saved_search_id'] as String,
      );

  final String accountId;

  final String? name;

  final String savedSearchId;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'name': name,
    'saved_search_id': savedSearchId,
  };
}

@immutable
class SavedSearchMatches {
  const SavedSearchMatches({
    required this.listingId,
    required this.matches,
    required this.title,
  });

  factory SavedSearchMatches.fromJson(Map<String, Object?> json) =>
      SavedSearchMatches(
        listingId: json['listing_id'] as String,
        matches: (json['matches'] as List<Object?>)
            .map((e0) => SavedSearchMatch.fromJson(e0! as Map<String, Object?>))
            .toList(),
        title: json['title'] as String,
      );

  final String listingId;

  final List<SavedSearchMatch> matches;

  final String title;

  Map<String, Object?> toJson() => {
    'listing_id': listingId,
    'matches': matches.map((e0) => e0.toJson()).toList(),
    'title': title,
  };
}

@immutable
class SavedSearchOut {
  const SavedSearchOut({
    this.category,
    required this.createdAt,
    required this.id,
    this.kind,
    this.maxPricePaise,
    this.minPricePaise,
    this.name,
    required this.newMatchCount,
    this.q,
  });

  factory SavedSearchOut.fromJson(Map<String, Object?> json) => SavedSearchOut(
    category: json['category'] == null
        ? null
        : ListingCategory.fromJson(json['category'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    id: json['id'] as String,
    kind: json['kind'] == null
        ? null
        : TradeKind.fromJson(json['kind'] as String),
    maxPricePaise: (json['max_price_paise'] as num?)?.toInt(),
    minPricePaise: (json['min_price_paise'] as num?)?.toInt(),
    name: json['name'] as String?,
    newMatchCount: (json['new_match_count'] as num).toInt(),
    q: json['q'] as String?,
  );

  final ListingCategory? category;

  final DateTime createdAt;

  final String id;

  final TradeKind? kind;

  final int? maxPricePaise;

  final int? minPricePaise;

  final String? name;

  final int newMatchCount;

  final String? q;

  Map<String, Object?> toJson() => {
    'category': ?category?.json,
    'created_at': createdAt.toUtc().toIso8601String(),
    'id': id,
    'kind': ?kind?.json,
    'max_price_paise': ?maxPricePaise,
    'min_price_paise': ?minPricePaise,
    'name': ?name,
    'new_match_count': newMatchCount,
    'q': ?q,
  };
}

@immutable
class ServerTime {
  const ServerTime({required this.now});

  factory ServerTime.fromJson(Map<String, Object?> json) =>
      ServerTime(now: DateTime.parse(json['now'] as String));

  /// Server time (UTC). The app derives its clock offset
  final DateTime now;

  Map<String, Object?> toJson() => {'now': now.toUtc().toIso8601String()};
}

@immutable
class StaffAccountOut {
  const StaffAccountOut({
    required this.createdAt,
    required this.email,
    required this.id,
    required this.lastLoginAt,
    required this.name,
    required this.role,
    required this.status,
  });

  factory StaffAccountOut.fromJson(Map<String, Object?> json) =>
      StaffAccountOut(
        createdAt: DateTime.parse(json['created_at'] as String),
        email: json['email'] as String,
        id: json['id'] as String,
        lastLoginAt: json['last_login_at'] == null
            ? null
            : DateTime.parse(json['last_login_at'] as String),
        name: json['name'] as String?,
        role: json['role'] as String,
        status: json['status'] as String,
      );

  final DateTime createdAt;

  final String email;

  final String id;

  final DateTime? lastLoginAt;

  final String? name;

  final String role;

  final String status;

  Map<String, Object?> toJson() => {
    'created_at': createdAt.toUtc().toIso8601String(),
    'email': email,
    'id': id,
    'last_login_at': lastLoginAt?.toUtc().toIso8601String(),
    'name': name,
    'role': role,
    'status': status,
  };
}

@immutable
class StaffLogin {
  const StaffLogin({required this.email, required this.password});

  factory StaffLogin.fromJson(Map<String, Object?> json) => StaffLogin(
    email: json['email'] as String,
    password: json['password'] as String,
  );

  final String email;

  final String password;

  Map<String, Object?> toJson() => {'email': email, 'password': password};
}

@immutable
class StaffPasswordChange {
  const StaffPasswordChange({
    required this.currentPassword,
    required this.email,
    required this.newPassword,
  });

  factory StaffPasswordChange.fromJson(Map<String, Object?> json) =>
      StaffPasswordChange(
        currentPassword: json['current_password'] as String,
        email: json['email'] as String,
        newPassword: json['new_password'] as String,
      );

  final String currentPassword;

  final String email;

  final String newPassword;

  Map<String, Object?> toJson() => {
    'current_password': currentPassword,
    'email': email,
    'new_password': newPassword,
  };
}

@immutable
class StaffUserDetail {
  const StaffUserDetail({
    required this.bookings,
    required this.email,
    required this.penalties,
    required this.profile,
    required this.riskFlags,
    required this.status,
  });

  factory StaffUserDetail.fromJson(Map<String, Object?> json) =>
      StaffUserDetail(
        bookings: (json['bookings'] as List<Object?>)
            .map((e0) => BookingSummary.fromJson(e0! as Map<String, Object?>))
            .toList(),
        email: json['email'] as String,
        penalties: (json['penalties'] as List<Object?>)
            .map((e0) => PenaltyOut.fromJson(e0! as Map<String, Object?>))
            .toList(),
        profile: json['profile'] == null
            ? null
            : ProfileStaff.fromJson(json['profile'] as Map<String, Object?>),
        riskFlags: (json['risk_flags'] as List<Object?>)
            .map((e0) => RiskFlag.fromJson(e0! as Map<String, Object?>))
            .toList(),
        status: json['status'] as String,
      );

  final List<BookingSummary> bookings;

  final String email;

  final List<PenaltyOut> penalties;

  final ProfileStaff? profile;

  final List<RiskFlag> riskFlags;

  final String status;

  Map<String, Object?> toJson() => {
    'bookings': bookings.map((e0) => e0.toJson()).toList(),
    'email': email,
    'penalties': penalties.map((e0) => e0.toJson()).toList(),
    'profile': profile?.toJson(),
    'risk_flags': riskFlags.map((e0) => e0.toJson()).toList(),
    'status': status,
  };
}

@immutable
class StaffUserRow {
  const StaffUserRow({
    required this.accountId,
    required this.email,
    required this.fullName,
    required this.lenderTrust,
    required this.renterTrust,
    required this.riskFlags,
    required this.status,
  });

  factory StaffUserRow.fromJson(Map<String, Object?> json) => StaffUserRow(
    accountId: json['account_id'] as String,
    email: json['email'] as String,
    fullName: json['full_name'] as String?,
    lenderTrust: (json['lender_trust'] as num?)?.toInt(),
    renterTrust: (json['renter_trust'] as num?)?.toInt(),
    riskFlags: (json['risk_flags'] as List<Object?>)
        .map((e0) => RiskFlag.fromJson(e0! as Map<String, Object?>))
        .toList(),
    status: json['status'] as String,
  );

  final String accountId;

  final String email;

  final String? fullName;

  final int? lenderTrust;

  final int? renterTrust;

  final List<RiskFlag> riskFlags;

  final String status;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'email': email,
    'full_name': fullName,
    'lender_trust': lenderTrust,
    'renter_trust': renterTrust,
    'risk_flags': riskFlags.map((e0) => e0.toJson()).toList(),
    'status': status,
  };
}

@immutable
class StaffUserRowPage {
  const StaffUserRowPage({required this.items, this.nextCursor});

  factory StaffUserRowPage.fromJson(Map<String, Object?> json) =>
      StaffUserRowPage(
        items: (json['items'] as List<Object?>)
            .map((e0) => StaffUserRow.fromJson(e0! as Map<String, Object?>))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );

  final List<StaffUserRow> items;

  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': items.map((e0) => e0.toJson()).toList(),
    'next_cursor': ?nextCursor,
  };
}

@immutable
class StatusChangeIn {
  const StatusChangeIn({required this.reason, required this.status});

  factory StatusChangeIn.fromJson(Map<String, Object?> json) => StatusChangeIn(
    reason: json['reason'] as String,
    status: AccountStatus.fromJson(json['status'] as String),
  );

  final String reason;

  final AccountStatus status;

  Map<String, Object?> toJson() => {'reason': reason, 'status': status.json};
}

@immutable
class Suggestion {
  const Suggestion({
    required this.category,
    required this.kind,
    required this.listingId,
    required this.title,
  });

  factory Suggestion.fromJson(Map<String, Object?> json) => Suggestion(
    category: ListingCategory.fromJson(json['category'] as String),
    kind: TradeKind.fromJson(json['kind'] as String),
    listingId: json['listing_id'] as String,
    title: json['title'] as String,
  );

  final ListingCategory category;

  final TradeKind kind;

  final String listingId;

  final String title;

  Map<String, Object?> toJson() => {
    'category': category.json,
    'kind': kind.json,
    'listing_id': listingId,
    'title': title,
  };
}

@immutable
class SupportMessage {
  const SupportMessage({
    required this.at,
    required this.author,
    required this.authorName,
    required this.body,
    required this.id,
  });

  factory SupportMessage.fromJson(Map<String, Object?> json) => SupportMessage(
    at: DateTime.parse(json['at'] as String),
    author: MessageAuthor.fromJson(json['author'] as String),
    authorName: json['author_name'] as String?,
    body: json['body'] as String,
    id: json['id'] as String,
  );

  final DateTime at;

  final MessageAuthor author;

  final String? authorName;

  final String body;

  final String id;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'author': author.json,
    'author_name': authorName,
    'body': body,
    'id': id,
  };
}

@immutable
class SupportMessageIn {
  const SupportMessageIn({required this.body});

  factory SupportMessageIn.fromJson(Map<String, Object?> json) =>
      SupportMessageIn(body: json['body'] as String);

  final String body;

  Map<String, Object?> toJson() => {'body': body};
}

@immutable
class SupportThreadOut {
  const SupportThreadOut({
    required this.accountId,
    required this.bookingId,
    required this.createdAt,
    required this.id,
    required this.messages,
    required this.status,
    required this.subject,
    required this.updatedAt,
  });

  factory SupportThreadOut.fromJson(Map<String, Object?> json) =>
      SupportThreadOut(
        accountId: json['account_id'] as String,
        bookingId: json['booking_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        id: json['id'] as String,
        messages: (json['messages'] as List<Object?>)
            .map((e0) => SupportMessage.fromJson(e0! as Map<String, Object?>))
            .toList(),
        status: ThreadStatus.fromJson(json['status'] as String),
        subject: json['subject'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String accountId;

  final String? bookingId;

  final DateTime createdAt;

  final String id;

  final List<SupportMessage> messages;

  final ThreadStatus status;

  final String subject;

  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'booking_id': bookingId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'id': id,
    'messages': messages.map((e0) => e0.toJson()).toList(),
    'status': status.json,
    'subject': subject,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

@immutable
class SupportThreadSummary {
  const SupportThreadSummary({
    required this.accountId,
    required this.accountName,
    required this.bookingId,
    required this.id,
    required this.lastMessageAt,
    required this.status,
    required this.subject,
    required this.unanswered,
  });

  factory SupportThreadSummary.fromJson(Map<String, Object?> json) =>
      SupportThreadSummary(
        accountId: json['account_id'] as String,
        accountName: json['account_name'] as String?,
        bookingId: json['booking_id'] as String?,
        id: json['id'] as String,
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
        status: ThreadStatus.fromJson(json['status'] as String),
        subject: json['subject'] as String,
        unanswered: json['unanswered'] as bool,
      );

  final String accountId;

  final String? accountName;

  final String? bookingId;

  final String id;

  final DateTime lastMessageAt;

  final ThreadStatus status;

  final String subject;

  final bool unanswered;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'account_name': accountName,
    'booking_id': bookingId,
    'id': id,
    'last_message_at': lastMessageAt.toUtc().toIso8601String(),
    'status': status.json,
    'subject': subject,
    'unanswered': unanswered,
  };
}

@immutable
class TermsIn {
  const TermsIn({required this.version});

  factory TermsIn.fromJson(Map<String, Object?> json) =>
      TermsIn(version: json['version'] as String);

  /// The terms version the student read and accepted
  final String version;

  Map<String, Object?> toJson() => {'version': version};
}

@immutable
class TimelineStep {
  const TimelineStep({
    this.at,
    required this.key,
    required this.label,
    required this.state,
  });

  factory TimelineStep.fromJson(Map<String, Object?> json) => TimelineStep(
    at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
    key: json['key'] as String,
    label: json['label'] as String,
    state: TimelineStepState.fromJson(json['state'] as String),
  );

  final DateTime? at;

  final String key;

  final String label;

  final TimelineStepState state;

  Map<String, Object?> toJson() => {
    'at': ?at?.toUtc().toIso8601String(),
    'key': key,
    'label': label,
    'state': state.json,
  };
}

@immutable
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.account,
    required this.expiresIn,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory TokenPair.fromJson(Map<String, Object?> json) => TokenPair(
    accessToken: json['access_token'] as String,
    account: AccountOut.fromJson(json['account'] as Map<String, Object?>),
    expiresIn: (json['expires_in'] as num).toInt(),
    refreshToken: json['refresh_token'] as String,
    tokenType: json['token_type'] == null
        ? 'bearer'
        : json['token_type'] as String,
  );

  final String accessToken;

  final AccountOut account;

  /// Access token lifetime in seconds
  final int expiresIn;

  final String refreshToken;

  final String tokenType;

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'account': account.toJson(),
    'expires_in': expiresIn,
    'refresh_token': refreshToken,
    'token_type': tokenType,
  };
}

@immutable
class TranscriptLine {
  const TranscriptLine({required this.author, required this.text});

  factory TranscriptLine.fromJson(Map<String, Object?> json) => TranscriptLine(
    author: TranscriptAuthor.fromJson(json['author'] as String),
    text: json['text'] as String,
  );

  final TranscriptAuthor author;

  final String text;

  Map<String, Object?> toJson() => {'author': author.json, 'text': text};
}

@immutable
class TrustPenalty {
  const TrustPenalty({
    required this.accountId,
    required this.points,
    required this.role,
  });

  factory TrustPenalty.fromJson(Map<String, Object?> json) => TrustPenalty(
    accountId: json['account_id'] as String,
    points: (json['points'] as num).toInt(),
    role: TrustRole.fromJson(json['role'] as String),
  );

  final String accountId;

  final int points;

  final TrustRole role;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'points': points,
    'role': role.json,
  };
}

@immutable
class TrustSummary {
  const TrustSummary({this.rating, this.reviewCount = 0, this.score});

  factory TrustSummary.fromJson(Map<String, Object?> json) => TrustSummary(
    rating: (json['rating'] as num?)?.toDouble(),
    reviewCount: json['review_count'] == null
        ? 0
        : (json['review_count'] as num).toInt(),
    score: (json['score'] as num?)?.toInt(),
  );

  /// Average overall rating, 1-5
  final double? rating;

  final int reviewCount;

  /// 0-100; null until 5 completed trades
  final int? score;

  Map<String, Object?> toJson() => {
    'rating': ?rating,
    'review_count': reviewCount,
    'score': ?score,
  };
}

/// PUT the image bytes to upload_url with these headers, then confirm the
/// object_key with the endpoint for what the photo belongs to.
@immutable
class UploadOut {
  const UploadOut({
    required this.expiresAt,
    required this.headers,
    required this.objectKey,
    required this.uploadUrl,
  });

  factory UploadOut.fromJson(Map<String, Object?> json) => UploadOut(
    expiresAt: DateTime.parse(json['expires_at'] as String),
    headers: (json['headers'] as Map<String, Object?>).map(
      (k0, v0) => MapEntry(k0, v0! as String),
    ),
    objectKey: json['object_key'] as String,
    uploadUrl: json['upload_url'] as String,
  );

  final DateTime expiresAt;

  final Map<String, String> headers;

  String get method => 'PUT';

  final String objectKey;

  final String uploadUrl;

  Map<String, Object?> toJson() => {
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'headers': headers,
    'method': method,
    'object_key': objectKey,
    'upload_url': uploadUrl,
  };
}

@immutable
class UploadRequest {
  const UploadRequest({
    this.contentType = PhotoContentType.imageJpeg,
    required this.purpose,
  });

  factory UploadRequest.fromJson(Map<String, Object?> json) => UploadRequest(
    contentType: json['content_type'] == null
        ? PhotoContentType.imageJpeg
        : PhotoContentType.fromJson(json['content_type'] as String),
    purpose: UploadPurpose.fromJson(json['purpose'] as String),
  );

  final PhotoContentType contentType;

  final UploadPurpose purpose;

  Map<String, Object?> toJson() => {
    'content_type': contentType.json,
    'purpose': purpose.json,
  };
}

@immutable
class ValidationError {
  const ValidationError({
    this.ctx,
    this.input,
    required this.loc,
    required this.msg,
    required this.type,
  });

  factory ValidationError.fromJson(Map<String, Object?> json) =>
      ValidationError(
        ctx: json['ctx'] == null
            ? null
            : Map<String, Object?>.of(json['ctx'] as Map<String, Object?>),
        input: json['input'],
        loc: List<Object?>.of(json['loc'] as List<Object?>),
        msg: json['msg'] as String,
        type: json['type'] as String,
      );

  final Map<String, Object?>? ctx;

  final Object? input;

  final List<Object?> loc;

  final String msg;

  final String type;

  Map<String, Object?> toJson() => {
    'ctx': ?ctx,
    'input': input,
    'loc': loc,
    'msg': msg,
    'type': type,
  };
}

/// What Razorpay Checkout returns to the app on success.
@immutable
class VerifyIn {
  const VerifyIn({
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
  });

  factory VerifyIn.fromJson(Map<String, Object?> json) => VerifyIn(
    razorpayOrderId: json['razorpay_order_id'] as String,
    razorpayPaymentId: json['razorpay_payment_id'] as String,
    razorpaySignature: json['razorpay_signature'] as String,
  );

  final String razorpayOrderId;

  final String razorpayPaymentId;

  final String razorpaySignature;

  Map<String, Object?> toJson() => {
    'razorpay_order_id': razorpayOrderId,
    'razorpay_payment_id': razorpayPaymentId,
    'razorpay_signature': razorpaySignature,
  };
}

@immutable
class WebhookAck {
  const WebhookAck({required this.status});

  factory WebhookAck.fromJson(Map<String, Object?> json) =>
      WebhookAck(status: WebhookAckStatus.fromJson(json['status'] as String));

  final WebhookAckStatus status;

  Map<String, Object?> toJson() => {'status': status.json};
}
