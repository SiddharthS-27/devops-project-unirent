"""Which event notifies whom, with what text, and which screen it opens.
Follows the Notifications table in the product plan."""

from collections.abc import Callable

from unirent_workers.push import Push, PushDelivery

Rule = Callable[[dict], list[Push]]


def _rupees(paise: int | None) -> str:
    return (
        f"₹{(paise or 0) / 100:,.0f}" if (paise or 0) % 100 == 0 else f"₹{(paise or 0) / 100:,.2f}"
    )


def _booking_link(p: dict) -> str:
    return f"unirent://bookings/{p['booking_id']}"


def _to(account_ids: list[str | None], title: str, body: str, link: str) -> list[Push]:
    return [Push(a, title, body, link) for a in dict.fromkeys(account_ids) if a]


def _other_side(p: dict, actor_role_key: str = "by") -> str:
    return p["owner_id"] if p.get(actor_role_key) == "renter" else p["renter_id"]


def _decided(p: dict) -> list[Push]:
    title = {
        "approved": "Request approved",
        "declined": "Request declined",
        "auto_declined": "Request declined",
        "expired": "Request expired",
    }[p["decision"]]
    body = {
        "approved": f"{p['listing_title']}: arrange the pickup with the owner.",
        "declined": f"{p['listing_title']} isn't available for you.",
        "auto_declined": f"{p['listing_title']} was booked by someone else for those dates.",
        "expired": f"The owner didn't answer your request for {p['listing_title']} in 24 hours.",
    }[p["decision"]]
    return _to([p["renter_id"]], title, body, _booking_link(p))


def _booking(title: str, body: str, *who: str) -> Rule:
    def rule(p: dict) -> list[Push]:
        ids = [p.get(f"{w}_id") for w in who]
        return _to(ids, title, body.format(**p), _booking_link(p))

    return rule


RULES: dict[str, Rule] = {
    "BookingRequested": _booking("New request", "{requester_name} wants {listing_title}.", "owner"),
    "BookingDecided": _decided,
    "BookingWithdrawn": _booking(
        "Request withdrawn", "The request for {listing_title} was withdrawn.", "owner"
    ),
    "BookingCancelled": lambda p: _to(
        [_other_side(p, "cancelled_by")],
        "Booking cancelled",
        f"{p['listing_title']}: {p['note']}",
        _booking_link(p),
    ),
    "PickupReminderDue": _booking(
        "Pickup in an hour", "{listing_title} at {pickup_point}.", "renter", "owner"
    ),
    "PickupCompleted": lambda p: _to(
        [p["renter_id"], p["owner_id"]],
        "Rental started" if p.get("kind", "rent") == "rent" else "Sale complete",
        f"{p['listing_title']} has been handed over.",
        _booking_link(p),
    ),
    "ExtensionRequested": _booking(
        "Extension requested", "More time with {listing_title} was requested.", "owner"
    ),
    "ExtensionDecided": lambda p: _to(
        [p["renter_id"]],
        "Extension approved" if p["decision"] == "approved" else "Extension declined",
        f"{p['listing_title']}",
        _booking_link(p),
    ),
    "ReturnReminderDue": _booking(
        "Return in an hour", "{listing_title} is due back soon.", "renter"
    ),
    "RentalOverdue": lambda p: _to(
        [p["renter_id"], p["owner_id"]],
        "Rental overdue",
        f"{p['listing_title']} is overdue. Late fee so far: {_rupees(p.get('late_fee_paise'))}.",
        _booking_link(p),
    ),
    "OverdueEscalationAvailable": _booking(
        "You can escalate", "{listing_title} is an hour overdue. Moderators can help.", "owner"
    ),
    "ReturnCompleted": _booking(
        "Item returned", "{listing_title} is back with its owner.", "renter", "owner"
    ),
    "DamageChargeRecorded": lambda p: _to(
        [p["renter_id"]],
        "Damage charge recorded",
        f"{_rupees(p.get('amount_paise'))} for {p['listing_title']}. Pay it or appeal.",
        _booking_link(p),
    ),
    "ReviewPending": _booking(
        "Review waiting", "Rate your {listing_title} trade to continue.", "renter", "owner"
    ),
    "ReviewsRevealed": _booking(
        "Reviews revealed", "See what the other side said about {listing_title}.", "renter", "owner"
    ),
    "AppealFiled": lambda p: _to(
        [p.get("renter_id"), p.get("owner_id"), *p.get("moderator_ids", [])],
        "Appeal filed",
        f"An appeal was filed on {p['listing_title']}.",
        _booking_link(p),
    ),
    "AppealRuled": _booking(
        "Appeal ruled", "A moderator ruled on {listing_title}.", "renter", "owner"
    ),
    "RulingOverruled": _booking(
        "Ruling changed", "The admin changed the ruling on {listing_title}.", "renter", "owner"
    ),
    "SupportReplyPosted": lambda p: _to(
        [p["account_id"]],
        "Moderator replied",
        p.get("preview", "You have a reply in Help."),
        f"unirent://help/threads/{p['thread_id']}",
    ),
    "AccountStatusChanged": lambda p: (
        _to(
            [p["account_id"]],
            {"suspended": "Account suspended", "banned": "Account banned"}.get(
                p["status"], "Account updated"
            ),
            p.get("reason", ""),
            "unirent://profile",
        )
        if p["status"] in ("suspended", "banned", "active")
        else []
    ),
    "PaymentCaptured": lambda p: _to(
        [p["payer_id"], p["payee_id"]],
        "Payment received",
        f"{_rupees(p['amount_paise'])} paid by UPI.",
        _booking_link(p),
    ),
    "CashMarkedPaid": lambda p: _to(
        [p["payer_id"], p["payee_id"]],
        "Cash marked paid",
        f"{_rupees(p['amount_paise'])} in cash confirmed.",
        _booking_link(p),
    ),
    "PaymentFailed": lambda p: _to(
        [p["payer_id"]],
        "Payment failed",
        "Your UPI payment didn't go through. Try again.",
        _booking_link(p),
    ),
    "RefundIssued": lambda p: _to(
        [p["payer_id"], p["payee_id"]],
        "Refund issued",
        f"{_rupees(p['amount_paise'])} refunded after a ruling.",
        _booking_link(p),
    ),
}

PUSH_TOPICS = ["bookings.events", "moderation.events", "payments.events"]


def pushes_for(event: dict) -> list[Push]:
    rule = RULES.get(event["type"])
    return rule(event["payload"]) if rule else []


def make_handler(delivery: PushDelivery):
    async def handle(event: dict) -> None:
        for push in pushes_for(event):
            await delivery.deliver(push)

    return handle
