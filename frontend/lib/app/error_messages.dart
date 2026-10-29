import '../api/api_exception.dart';

/// An error from a non-API step (Microsoft sign-in, Firebase) with a message
/// ready to show.
class UserFacingException implements Exception {
  const UserFacingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

const _messages = {
  // Sign-in
  'EMAIL_DOMAIN_NOT_ALLOWED':
      'Use your college email address. Personal accounts can’t sign in.',
  'WRONG_TENANT': 'Sign in with your college Microsoft account.',
  'INVALID_ID_TOKEN': 'Microsoft sign-in didn’t work. Please try again.',
  'ID_TOKEN_EXPIRED': 'Microsoft sign-in timed out. Please try again.',
  'EMAIL_IN_USE': 'This email belongs to a staff account. Use staff sign in.',
  'INVALID_CREDENTIALS': 'Wrong email or password.',
  'ACCOUNT_LOCKED':
      'Too many failed attempts. Wait a few minutes and try again.',
  'ACCOUNT_BANNED': 'This account has been banned.',
  'ACCOUNT_DEACTIVATED': 'This account has been deactivated.',
  'ACCOUNT_DISABLED': 'This account can’t sign in.',
  'ACCOUNT_SUSPENDED': 'Your account is suspended.',
  'RATE_LIMITED': 'Too many attempts. Please wait a moment and try again.',
  'TRY_LATER': 'UniRent is busy right now. Please try again shortly.',
  // Phone
  'WRONG_CODE': 'That code isn’t right. Check the SMS and try again.',
  'PHONE_IN_USE':
      'This number is already linked to another UniRent account. '
      'Use a different number.',
  'INVALID_PHONE_TOKEN': 'Verification failed. Request a new code.',
  'PHONE_NOT_VERIFIED': 'Verification failed. Request a new code.',
  // Onboarding
  'TERMS_OUTDATED': 'The terms were just updated. Please review them again.',
  'PROFILE_REQUIRED': 'Fill in your profile first.',
  'STUDENTS_ONLY': 'Only students can do this.',
  // Client-side
  ApiException.networkError:
      'Can’t reach UniRent. Check your internet connection.',
  ApiException.timeout: 'UniRent is taking too long to respond. Try again.',
};

/// A message for [error] that is safe and helpful to show to the user.
String friendlyMessage(Object error) {
  return switch (error) {
    ApiException(:final code, :final message) =>
      _messages[code] ??
          (code == 'VALIDATION_ERROR' || code == 'WEAK_PASSWORD'
              ? message
              : 'Something went wrong. Please try again.'),
    UserFacingException(:final message) => message,
    _ => 'Something went wrong. Please try again.',
  };
}
