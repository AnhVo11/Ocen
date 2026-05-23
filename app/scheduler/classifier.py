"""Bilingual (Vietnamese / English) work-event classifier.

Uses a keyword-matching approach rather than a model so it runs offline with
zero latency and no external dependencies. The keyword list covers typical
executive vocabulary in both languages.
"""

import re
from typing import FrozenSet

# ---------------------------------------------------------------------------
# Keyword lists
# ---------------------------------------------------------------------------

_VIETNAMESE_KEYWORDS: FrozenSet[str] = frozenset(
    {
        "khách hàng",
        "hợp đồng",
        "họp",
        "báo cáo",
        "dự án",
        "bàn giao",
        "đối tác",
        "công việc",
        "deadline",
        "phê duyệt",
        "tài chính",
        "ngân sách",
        "hội nghị",
        "thương lượng",
        "ký kết",
        "thanh toán",
        "kiểm toán",
        "chiến lược",
    }
)

_ENGLISH_KEYWORDS: FrozenSet[str] = frozenset(
    {
        "client",
        "contract",
        "meeting",
        "report",
        "deliverable",
        "project",
        "handover",
        "partner",
        "deadline",
        "approval",
        "finance",
        "budget",
        "invoice",
        "proposal",
        "conference",
        "negotiation",
        "signing",
        "payment",
        "audit",
        "strategy",
        "board",
        "stakeholder",
    }
)

_ALL_KEYWORDS: FrozenSet[str] = _VIETNAMESE_KEYWORDS | _ENGLISH_KEYWORDS


def is_work_related(text: str) -> bool:
    """Return True if ``text`` contains at least one work-related keyword.

    The check is case-insensitive and matches whole words for English keywords
    to avoid false positives (e.g. "client" should not match "clientele" in the
    middle of a word).  Vietnamese multi-word phrases are matched as substrings
    because word boundaries behave differently with Unicode.

    Parameters
    ----------
    text:
        Arbitrary input — event title, notes, or a combination.

    Returns
    -------
    bool
    """
    if not text:
        return False

    lower_text = text.lower()

    # Multi-word Vietnamese phrases: substring match is fine
    for kw in _VIETNAMESE_KEYWORDS:
        if kw in lower_text:
            return True

    # English single-word keywords: whole-word match to reduce false positives
    for kw in _ENGLISH_KEYWORDS:
        if re.search(r"\b" + re.escape(kw) + r"\b", lower_text):
            return True

    return False
