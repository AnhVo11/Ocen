"""In-memory session state management for the WhatsApp bot.

Each sender phone number gets its own Session object that moves through the
state machine states.  Sessions expire after SESSION_TTL seconds of
inactivity and are reset to IDLE automatically.
"""

import time
from enum import Enum
from typing import Any, Dict

# Sessions older than this (seconds of inactivity) are auto-reset
SESSION_TTL: int = 3600  # 1 hour


class SessionState(str, Enum):
    """Ordered states in the schedule-creation flow."""

    IDLE = "IDLE"
    AWAITING_TITLE = "AWAITING_TITLE"
    AWAITING_DATE = "AWAITING_DATE"
    AWAITING_TIME = "AWAITING_TIME"
    AWAITING_LOCATION = "AWAITING_LOCATION"
    AWAITING_NOTES = "AWAITING_NOTES"
    CONFIRMING = "CONFIRMING"


class Session:
    """Holds transient state for one WhatsApp sender during schedule creation."""

    def __init__(self, phone: str) -> None:
        self.phone = phone
        self.state: SessionState = SessionState.IDLE
        self.data: Dict[str, Any] = {}        # collected fields for the new event
        self.last_activity: float = time.monotonic()

    def reset(self) -> None:
        """Return session to idle and discard all collected data."""
        self.state = SessionState.IDLE
        self.data = {}
        self.last_activity = time.monotonic()

    def touch(self) -> None:
        """Update the last-activity timestamp to prevent expiry."""
        self.last_activity = time.monotonic()

    @property
    def is_expired(self) -> bool:
        """True if the session has been idle longer than SESSION_TTL."""
        return (
            self.state != SessionState.IDLE
            and time.monotonic() - self.last_activity > SESSION_TTL
        )


# Module-level in-process store — sufficient for single-instance deployments.
# For multi-process/Kubernetes deployments, replace with Redis-backed sessions.
_sessions: Dict[str, Session] = {}


def get_session(phone: str) -> Session:
    """Return the session for ``phone``, creating it if it doesn't exist.

    Expired sessions are silently reset to IDLE before being returned.

    Parameters
    ----------
    phone:
        Sender's WhatsApp number, e.g. ``"whatsapp:+84901234567"``.
    """
    if phone not in _sessions:
        _sessions[phone] = Session(phone)

    session = _sessions[phone]
    if session.is_expired:
        session.reset()

    session.touch()
    return session


def clear_session(phone: str) -> None:
    """Reset the session for ``phone`` to IDLE, discarding any in-progress data."""
    if phone in _sessions:
        _sessions[phone].reset()
