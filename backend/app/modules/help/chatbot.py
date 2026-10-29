"""The help bot. Deterministic, no AI model: it normalises the message, scores
each FAQ by keyword overlap and trigram similarity, and answers only when the
best score clears a threshold. Otherwise it offers the FAQs or a moderator."""

import re

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import current_late_fee_rule

from app.modules.help.models import Faq
from app.modules.help.schemas import ChatReply, FaqOut

THRESHOLD = 0.35
KEYWORD_WEIGHT = 0.7
SIMILARITY_WEIGHT = 0.3
FALLBACK = (
    "I can only answer general questions about how UniRent works. Have a look at the FAQs, or "
    "talk to a moderator."
)
_WORD = re.compile(r"[a-z0-9]+")
ACTIONS = ("see_faqs", "talk_to_moderator")


def normalise(message: str) -> list[str]:
    words = _WORD.findall(message.lower())
    return [w[:-1] if len(w) > 3 and w.endswith("s") else w for w in words]


def keyword_score(words: list[str], keywords: list[str]) -> float:
    """Share of the message's meaningful words that are this FAQ's keywords,
    saturating after two hits."""
    stems = {k[:-1] if len(k) > 3 and k.endswith("s") else k for k in keywords}
    hits = sum(1 for w in set(words) if w in stems)
    return min(1.0, hits / 2)


async def _late_fee_text() -> str:
    rule = await current_late_fee_rule()
    base = rule.base_fee_paise / 100
    percent = rule.hourly_percent_bp / 100
    return (
        f"After the end time there is a {rule.grace_minutes}-minute grace period. Then a late "
        f"fee of ₹{base:g} applies, plus {percent:g}% of the booking's rent for every further hour."
    )


async def answer(session: AsyncSession, message: str) -> ChatReply:
    words = normalise(message)
    similarity = func.similarity(Faq.question, message)
    rows = (await session.execute(select(Faq, similarity).order_by(Faq.position))).all()
    best, best_score = None, 0.0
    for faq, trigram in rows:
        score = KEYWORD_WEIGHT * keyword_score(words, faq.keywords) + SIMILARITY_WEIGHT * float(
            trigram
        )
        if score > best_score:
            best, best_score = faq, score
    if best is None or best_score < THRESHOLD:
        return ChatReply(kind="fallback", text=FALLBACK, actions=list(ACTIONS))
    text = best.answer
    if "{late_fee_rule}" in text:
        text = text.replace("{late_fee_rule}", await _late_fee_text())
    return ChatReply(kind="answer", text=text, faq_id=best.id, actions=list(ACTIONS))


async def faqs(session: AsyncSession) -> list[FaqOut]:
    """The FAQ page, with the current late-fee rule written into its answer."""
    late = await _late_fee_text()
    rows = await session.scalars(select(Faq).order_by(Faq.position))
    return [
        FaqOut(
            id=f.id,
            question=f.question,
            answer=f.answer.replace("{late_fee_rule}", late),
            topic=f.topic,
        )
        for f in rows
    ]
