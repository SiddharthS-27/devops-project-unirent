/// Client-side checks matching the backend's `ListingCreate` rules.
abstract final class ListingValidators {
  static const maxPhotos = 8;

  static String? title(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter a title';
    if (t.length < 3) return 'Use at least 3 characters';
    if (t.length > 120) return 'Keep the title under 120 characters';
    return null;
  }

  static String? description(String? v) =>
      (v?.length ?? 0) > 2000 ? 'Keep it under 2000 characters' : null;

  static String? pickupPoint(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Where should people collect it?';
    if (t.length < 2) return 'Use at least 2 characters';
    if (t.length > 200) return 'Keep it under 200 characters';
    return null;
  }

  static String? serialNumber(String? v) =>
      (v?.trim().length ?? 0) > 100 ? 'Keep it under 100 characters' : null;

  static String? required<T>(T? value, String message) =>
      value == null ? message : null;

  /// Rupees as typed (digits only) → paise; null when empty.
  static int? paiseFromRupees(String? text) {
    final rupees = int.tryParse(text?.trim() ?? '');
    return rupees == null ? null : rupees * 100;
  }

  /// An optional positive amount in rupees.
  static String? optionalPrice(String? v) {
    if ((v?.trim() ?? '').isEmpty) return null;
    final paise = paiseFromRupees(v);
    return paise == null || paise <= 0 ? 'Enter an amount above ₹0' : null;
  }

  /// Rentals need an hourly or a daily price.
  static String? rentPrices(String? hourly, String? daily) {
    final h = paiseFromRupees(hourly);
    final d = paiseFromRupees(daily);
    return (h == null || h <= 0) && (d == null || d <= 0)
        ? 'Set an hourly or a daily price'
        : null;
  }

  static String? salePrice(String? v) {
    final paise = paiseFromRupees(v);
    return paise == null || paise <= 0 ? 'Set a price above ₹0' : null;
  }

  static String? photoCount(int count) {
    if (count == 0) return 'Add at least one photo';
    if (count > maxPhotos) return 'Use up to $maxPhotos photos';
    return null;
  }
}
