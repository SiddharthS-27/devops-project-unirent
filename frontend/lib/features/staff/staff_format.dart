import '../../api/api.dart';

/// An appeal reason as staff read it.
String appealReasonLabel(String reason) => switch (reason) {
  'damage_dispute' => 'Damage or late-fee dispute',
  'item_mismatch' => 'Item not as described',
  'other' => 'Other',
  _ => reason.replaceAll('_', ' '),
};

String appealStatusLabel(AppealStatus status) => switch (status) {
  AppealStatus.open => 'Open',
  AppealStatus.ruled => 'Ruled',
  AppealStatus.overruled => 'Overruled',
  AppealStatus.unknown => 'Unknown',
};

String tradeRoleLabel(TradeRole role, TradeKind kind) => switch (role) {
  TradeRole.renter => kind == TradeKind.sale ? 'buyer' : 'renter',
  TradeRole.owner => kind == TradeKind.sale ? 'seller' : 'owner',
  TradeRole.unknown => 'student',
};

String riskFlagLabel(RiskFlag f) => switch (f.kind) {
  RiskFlagKind.overdueReturns =>
    '${f.count} overdue returns in ${f.windowDays ?? 30} days',
  RiskFlagKind.cancellations =>
    '${f.count} cancellations in ${f.windowDays ?? 30} days',
  RiskFlagKind.disputes => '${f.count} disputes in ${f.windowDays ?? 30} days',
  RiskFlagKind.lowTrust => 'Trust score ${f.count}',
  RiskFlagKind.unknown => 'Flagged',
};

String accountStatusLabel(String status) => switch (status) {
  'active' => 'Active',
  'suspended' => 'Suspended',
  'banned' => 'Banned',
  _ => status,
};

String escalationKindLabel(EscalationKind kind) => switch (kind) {
  EscalationKind.overdue => 'Overdue',
  EscalationKind.ownerEscalated => 'Escalated by the owner',
  EscalationKind.stalledProceed => 'Proceed stalled',
  EscalationKind.unknown => 'Escalation',
};

String listingStatusLabel(ListingStatus status) => switch (status) {
  ListingStatus.active => 'Active',
  ListingStatus.paused => 'Paused',
  ListingStatus.sold => 'Sold',
  ListingStatus.removed => 'Removed',
  ListingStatus.unknown => 'Unknown',
};
