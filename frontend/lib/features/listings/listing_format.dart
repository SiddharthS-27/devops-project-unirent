import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api.dart';
import '../../ui/ui.dart';

/// Every real category, in display order.
const listingCategories = [
  ListingCategory.electronics,
  ListingCategory.cameras,
  ListingCategory.cycles,
  ListingCategory.books,
  ListingCategory.instruments,
  ListingCategory.sports,
  ListingCategory.hostel,
  ListingCategory.events,
  ListingCategory.other,
];

String categoryLabel(ListingCategory category) => switch (category) {
  ListingCategory.electronics => 'Electronics',
  ListingCategory.cameras => 'Cameras',
  ListingCategory.cycles => 'Cycles',
  ListingCategory.books => 'Books & stationery',
  ListingCategory.instruments => 'Instruments',
  ListingCategory.sports => 'Sports',
  ListingCategory.hostel => 'Hostel essentials',
  ListingCategory.events => 'Events & fests',
  ListingCategory.other || ListingCategory.unknown => 'Other',
};

IconData categoryIcon(ListingCategory category) => switch (category) {
  ListingCategory.electronics => Icons.devices_other_outlined,
  ListingCategory.cameras => Icons.photo_camera_outlined,
  ListingCategory.cycles => Icons.pedal_bike_outlined,
  ListingCategory.books => Icons.menu_book_outlined,
  ListingCategory.instruments => Icons.music_note_outlined,
  ListingCategory.sports => Icons.sports_cricket_outlined,
  ListingCategory.hostel => Icons.bed_outlined,
  ListingCategory.events => Icons.celebration_outlined,
  ListingCategory.other || ListingCategory.unknown => Icons.category_outlined,
};

const listingConditions = [
  ItemCondition.newValue,
  ItemCondition.likeNew,
  ItemCondition.good,
  ItemCondition.fair,
  ItemCondition.poor,
];

String conditionLabel(ItemCondition condition) => switch (condition) {
  ItemCondition.newValue => 'New',
  ItemCondition.likeNew => 'Like new',
  ItemCondition.good => 'Good',
  ItemCondition.fair => 'Fair',
  ItemCondition.poor => 'Poor',
  ItemCondition.unknown => 'Not stated',
};

String tradeKindLabel(TradeKind kind) =>
    kind == TradeKind.sale ? 'For sale' : 'For rent';

/// "₹400/day · ₹60/hr" for rentals, "₹4,500" for sales.
String priceLabel({
  required TradeKind kind,
  int? perHourPaise,
  int? perDayPaise,
  int? salePaise,
}) {
  if (kind == TradeKind.sale) {
    return salePaise == null ? 'Price on request' : formatMoney(salePaise);
  }
  final parts = [
    if (perDayPaise != null) '${formatMoney(perDayPaise)}/day',
    if (perHourPaise != null) '${formatMoney(perHourPaise)}/hr',
  ];
  return parts.isEmpty ? 'Price on request' : parts.join(' · ');
}

extension ListingCardFormat on ListingCard {
  String get priceText => priceLabel(
    kind: kind,
    perHourPaise: pricePerHourPaise,
    perDayPaise: pricePerDayPaise,
    salePaise: salePricePaise,
  );
}

/// "₹50 after a 30-minute grace period, plus 2% of the rent per hour late."
String lateFeeText(LateFeeRuleOut rule) {
  final grace = rule.graceMinutes;
  final graceText = grace % 60 == 0 && grace >= 60
      ? '${grace ~/ 60}-hour'
      : '$grace-minute';
  final percent = NumberFormat('0.##').format(rule.hourlyPercentBp / 100);
  return 'If you return late, you pay ${formatMoney(rule.baseFeePaise)} once '
      'the $graceText grace period is over, plus $percent% of the rent for '
      'every hour after that.';
}
