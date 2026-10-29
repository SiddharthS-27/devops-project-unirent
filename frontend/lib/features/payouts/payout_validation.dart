/// Client-side checks matching the backend's `PayoutAccountIn`.
abstract final class PayoutValidators {
  static String? name(String? v, String missing) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return missing;
    if (t.length < 2) return 'Use at least 2 characters';
    if (t.length > 120) return 'Keep it under 120 characters';
    return null;
  }

  static String? email(String? v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
      ? null
      : 'Enter a valid email address';

  /// 10-digit Indian mobile number, without +91.
  static String? mobile(String? v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
      ? null
      : 'Enter a 10-digit mobile number';

  static String? accountNumber(String? v) =>
      RegExp(r'^\d{9,18}$').hasMatch(v ?? '')
      ? null
      : 'Account numbers have 9 to 18 digits';

  static String? ifsc(String? v) =>
      RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v ?? '')
      ? null
      : 'Enter a valid IFSC, e.g. SBIN0001234';
}
