import '../../api/api.dart';

/// Labels for review parameters (the form sends them too; these cover
/// reviews shown later, which carry only keys).
const reviewParameterLabels = {
  'item_care': 'Item care',
  'return_punctuality': 'Return punctuality',
  'communication': 'Communication',
  'item_matches_description': 'Item matches description',
  'item_condition': 'Item condition',
  'handover_punctuality': 'Handover punctuality',
  'payment_promptness': 'Payment promptness',
  'overall': 'Overall',
};

String reviewParameterLabel(String key) =>
    reviewParameterLabels[key] ??
    key
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

String reviewTypeLabel(ReviewType type) => switch (type) {
  ReviewType.renter => 'As a renter',
  ReviewType.lender => 'As a lender',
  ReviewType.renterSale => 'As a buyer',
  ReviewType.lenderSale => 'As a seller',
  ReviewType.cancellation => 'Cancellation',
  ReviewType.unknown => 'Review',
};
