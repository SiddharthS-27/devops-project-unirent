/// Client-side checks matching the backend's `ProfileIn` constraints, so
/// most mistakes are caught before the request.
abstract final class ProfileValidators {
  static String? _text(
    String? value, {
    required String missing,
    required int max,
    int min = 1,
    String? tooShort,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return missing;
    if (text.length < min) return tooShort ?? missing;
    if (text.length > max) return 'Keep this under $max characters';
    return null;
  }

  static String? fullName(String? v) => _text(
    v,
    missing: 'Enter your full name',
    min: 2,
    max: 200,
    tooShort: 'Enter at least 2 characters',
  );

  static String? rollNumber(String? v) =>
      _text(v, missing: 'Enter your roll number', max: 50);

  static String? department(String? v) =>
      _text(v, missing: 'Enter your department', max: 100);

  static String? year(int? v) =>
      v == null || v < 1 || v > 6 ? 'Select your year (1-6)' : null;

  static String? hostelName(String? v) =>
      _text(v, missing: 'Enter your hostel name', max: 100);

  static String? roomNumber(String? v) =>
      _text(v, missing: 'Enter your room number', max: 20);

  static String? homeAddress(String? v) =>
      _text(v, missing: 'Enter your home address', max: 500);
}
