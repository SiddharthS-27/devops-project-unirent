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
