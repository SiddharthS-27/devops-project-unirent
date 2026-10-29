"""Timer kinds the booking lifecycle schedules. The rules that run when one
fires live with the operations they belong to."""

REQUEST_EXPIRY = "request_expiry"
PICKUP_REMINDER = "pickup_reminder"
RETURN_REMINDER = "return_reminder"
OVERDUE_START = "overdue_start"
OVERDUE_ALERT = "overdue_alert"
ESCALATION_UNLOCK = "escalation_unlock"
STALLED_PROCEED = "stalled_proceed"
REVIEW_RELEASE = "review_release"
SALE_APPEAL_CLOSE = "sale_appeal_close"
