import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../../bookings/booking_format.dart';

/// "92.5%" for a 0-1 rate, or a dash when there's no data yet.
String percentLabel(double? rate) {
  if (rate == null) return '–';
  final pct = rate * 100;
  return pct == pct.roundToDouble()
      ? '${pct.round()}%'
      : '${pct.toStringAsFixed(1)}%';
}

String bookingStateLabel(String state) {
  final status = BookingStatus.fromJson(state);
  return status == BookingStatus.unknown
      ? state.replaceAll('_', ' ')
      : bookingStatusLabel(status);
}

String mismatchKindLabel(String kind) => switch (kind) {
  'missing_in_razorpay' => 'Missing at Razorpay',
  'missing_in_ledger' => 'Missing in the ledger',
  'amount_differs' => 'Amounts differ',
  'status_differs' => 'Statuses differ',
  'transfer_missing' => 'Transfer missing',
  'refund_differs' => 'Refund differs',
  'ledger_incomplete' => 'Ledger incomplete',
  _ => kind.replaceAll('_', ' '),
};

String runStatusLabel(ReconciliationReportStatus s) => switch (s) {
  ReconciliationReportStatus.running => 'Running',
  ReconciliationReportStatus.done => 'Done',
  ReconciliationReportStatus.failed => 'Failed',
  ReconciliationReportStatus.unknown => 'Unknown',
};

String totalLabel(String key) => switch (key) {
  'payments_checked' => 'Payments checked',
  'razorpay_payments' => 'Razorpay payments',
  'refunds_checked' => 'Refunds checked',
  'settlements' => 'Settlements',
  'settlements_available' => 'Settlement report available',
  'mismatches' => 'Mismatches',
  _ => key.replaceAll('_', ' '),
};

String totalValue(Object? v) => switch (v) {
  true => 'Yes',
  false => 'No',
  null => '–',
  _ => '$v',
};

/// "26 Oct 2026" for a reconciliation day (a calendar date, not an instant).
String dayLabel(DateTime day) =>
    formatIstDate(DateTime.utc(day.year, day.month, day.day, 6));

String auditActionLabel(String action) => switch (action) {
  'moderation.ruling' => 'Ruled on an appeal',
  'admin.overrule' => 'Overruled a ruling',
  'moderation.trust_penalty' => 'Trust penalty',
  'moderation.listing_removed' => 'Removed a listing',
  'moderation.review_removed' => 'Removed a review',
  'account.status_changed' => 'Changed account status',
  'support.reply' => 'Replied to support',
  'support.close' => 'Closed a support chat',
  'admin.late_fee_rule_set' => 'Set the late-fee rule',
  'admin.moderator_created' => 'Created a moderator',
  'admin.reconciliation_run' => 'Ran reconciliation',
  'admin.clock_set' => 'Moved the staging clock',
  _ => action,
};
