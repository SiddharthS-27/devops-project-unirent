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
  // Listings
  'NOT_FOUND': 'This isn’t available any more.',
  'LISTING_LOCKED':
      'You can’t edit this listing while a booking is approved or active.',
  'ASSET_ALREADY_LISTED':
      'This item already has a listing. Open it from Items you own.',
  'LISTING_CLOSED': 'This listing is closed and can’t be changed.',
  'INVALID_PRICE':
      'Check the prices: rentals have hourly or daily prices, '
      'sales have one fixed price.',
  'LAST_PHOTO':
      'A listing needs at least one photo. Add another before removing this '
      'one.',
  'TOO_MANY_PHOTOS': 'A listing can have up to 8 photos.',
  'INVALID_PHOTO': 'That photo didn’t upload properly. Try adding it again.',
  'PHOTO_NOT_UPLOADED':
      'That photo didn’t upload properly. Try adding it again.',
  'PAYOUT_ACCOUNT_REQUIRED':
      'Link your payout account before listing your first item.',
  'ONBOARDING_INCOMPLETE': 'Finish setting up your profile first.',
  // Saved searches
  'EMPTY_SEARCH': 'Add a search term or a filter before saving.',
  'TOO_MANY_SAVED_SEARCHES':
      'You can save up to 20 searches. Delete one to save another.',
  // Bookings
  'OWN_LISTING': 'You can’t request your own listing.',
  'REQUEST_EXISTS': 'You already have an open request for this item.',
  'SLOT_TAKEN': 'Those times are already booked. Pick different times.',
  'START_IN_PAST': 'Pick a start time in the future.',
  'PERIOD_TOO_SHORT': 'Rent for at least an hour.',
  'PERIOD_TOO_LONG': 'You can rent for at most 30 days.',
  'PERIOD_REQUIRED': 'Pick a start and end time.',
  'LISTING_UNAVAILABLE': 'This listing isn’t available right now.',
  'BOOKING_STATE': 'This booking has moved on. Pull to refresh.',
  'NOT_YOUR_STEP': 'That step is for the other person.',
  'ALREADY_PAID':
      'It’s already paid for. Finish the handover, or ask Help to sort it out.',
  'ALREADY_RATED': 'You’ve already rated this cancellation.',
  'NOT_CANCELLED': 'This booking wasn’t cancelled.',
  // Handover and payments
  'STEP_LOCKED': 'Finish the earlier steps first.',
  'CODE_EXPIRED': 'That code expired. Ask for a new one.',
  'PAYEE_NOT_PAYOUT_READY':
      'The owner can’t receive UPI payments yet. Pay in cash instead.',
  'PAYMENT_ALREADY_MADE': 'Your UPI payment went through. Refreshing…',
  'ORDER_MISMATCH':
      'We couldn’t confirm that payment. If money left your account, ask '
      'Help.',
  'INVALID_SIGNATURE':
      'We couldn’t confirm that payment. If money left your account, ask '
      'Help.',
  'NOT_CASH': 'Only cash payments are confirmed by the owner.',
  'IDEMPOTENCY_KEY_REUSED': 'Something went wrong. Please try again.',
  // Extensions
  'EXTENSION_PENDING': 'Wait for the owner to answer your last request.',
  'EXTENSION_TOO_SHORT': 'Pick a time after the current end time.',
  'EXTENSION_DECIDED': 'That request was already answered.',
  'EXTENSION_NOT_APPROVED': 'The owner hasn’t approved that extra time.',
  // Overdue and return
  'ESCALATION_NOT_YET':
      'You can escalate an hour after the item became overdue. Use Help '
      'before that.',
  'NOTHING_TO_PAY': 'Nothing is owed.',
  'CHARGES_UNPAID': 'The renter hasn’t paid the charges yet.',
  // Payouts
  'PAYOUT_ACCOUNT_EXISTS': 'You’ve already linked a payout account.',
  'NO_PAYOUT_ACCOUNT': 'Link a payout account first.',
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
