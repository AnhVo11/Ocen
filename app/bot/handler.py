"""WhatsApp message handler — state machine for schedule creation.

Flow (per sender)
-----------------
IDLE
  → (trigger: "thêm" / "new" / …)
AWAITING_TITLE
  → (user sends event title)
AWAITING_DATE
  → (user sends date in DD/MM/YYYY)
AWAITING_TIME
  → (user sends time range HH:MM - HH:MM)
AWAITING_LOCATION
  → (user sends venue / address)
AWAITING_NOTES
  → (user sends notes or "-" to skip)
CONFIRMING
  → "Có" → run conflict check + travel feasibility → save → schedule reminders → IDLE
  → "Không" → IDLE

Role routing
------------
* executive  → read-only; bot replies with a notice message
* secretary / driver → full schedule-creation access
"""

import logging
import re
from datetime import date, datetime, time
from typing import Optional, Tuple

from app.bot.responses import (
    ASK_DATE,
    ASK_LOCATION,
    ASK_NOTES,
    ASK_TIME,
    ASK_TITLE,
    CANCELLED_MESSAGE,
    CONFIRM_TEMPLATE,
    CONFLICT_WARNING,
    ERROR_MESSAGE,
    EXECUTIVE_ONLY_MESSAGE,
    HELP_MESSAGE,
    LIST_HEADER,
    NO_EVENTS_MESSAGE,
    SAVED_MESSAGE,
    TRAVEL_WARNING,
    UNKNOWN_USER_MESSAGE,
    WELCOME_MESSAGE,
)
from app.bot.sessions import SessionState, clear_session, get_session
from app.db import get_db_session
from app.db import crud
from app.scheduler.classifier import is_work_related
from app.scheduler.conflict import check_conflict
from app.scheduler.reminders import schedule_event_reminders

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Date / time parsing helpers
# ---------------------------------------------------------------------------

_DATE_FORMATS = [
    "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d",
    "%d/%m/%y", "%d-%m-%y",
    "%d.%m.%Y", "%d %m %Y",
]

_TIME_FORMATS = ["%H:%M", "%I:%M %p", "%I:%M%p"]


def parse_date(text: str) -> Optional[date]:
    """Parse common date formats used in Vietnam (DD/MM/YYYY preferred).

    Parameters
    ----------
    text:
        Raw date string from the user.

    Returns
    -------
    date or None
    """
    text = text.strip()
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    return None


def _parse_single_time(text: str) -> Optional[time]:
    """Parse a single time value such as ``"14:30"`` or ``"9h00"``."""
    # Normalise Vietnamese "h" separator: 14h30 → 14:30, 9h → 9:00
    text = re.sub(r"(\d{1,2})h(\d{2})", r"\1:\2", text.strip())
    text = re.sub(r"(\d{1,2})h\b", r"\1:00", text)
    for fmt in _TIME_FORMATS:
        try:
            return datetime.strptime(text.strip(), fmt).time()
        except ValueError:
            continue
    return None


def parse_time_range(text: str) -> Tuple[Optional[time], Optional[time]]:
    """Parse a time range like ``"09:00 - 17:00"`` or ``"9h – 17h30"``.

    Returns
    -------
    tuple[time, time] or (None, None)
        Start and end time, or ``(None, None)`` if parsing fails.
    """
    # Normalise Vietnamese h-notation before regex
    normalised = re.sub(r"(\d{1,2})h(\d{2})", r"\1:\2", text)
    normalised = re.sub(r"(\d{1,2})h\b", r"\1:00", normalised)

    pattern = (
        r"(\d{1,2}:\d{2}(?:\s*[APap][Mm])?)"   # start time
        r"\s*[-–to]+\s*"                         # separator
        r"(\d{1,2}:\d{2}(?:\s*[APap][Mm])?)"    # end time
    )
    match = re.search(pattern, normalised)
    if match:
        start_t = _parse_single_time(match.group(1))
        end_t = _parse_single_time(match.group(2))
        if start_t and end_t:
            return start_t, end_t
    return None, None


# ---------------------------------------------------------------------------
# Global command keywords
# ---------------------------------------------------------------------------

_CANCEL_WORDS = {"cancel", "hủy", "thoát", "quit", "exit"}
_HELP_WORDS = {"help", "giúp đỡ", "hướng dẫn"}
_LIST_WORDS = {"list", "danh sách", "lịch"}
_NEW_WORDS = {"new", "thêm", "add", "tạo", "schedule", "lịch mới"}
_YES_WORDS = {"yes", "có", "y", "đồng ý", "ok", "xác nhận", "confirm"}
_NO_WORDS = {"no", "không", "n", "hủy bỏ"}
_SKIP_WORDS = {"skip", "bỏ qua", "-", "none", "không có"}


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


async def handle_message(from_number: str, body: str) -> str:
    """Process an incoming WhatsApp message and return the reply text.

    Parameters
    ----------
    from_number:
        Sender's WhatsApp number, e.g. ``"whatsapp:+84901234567"``.
    body:
        Raw text of the message.

    Returns
    -------
    str
        Reply to send back via Twilio.
    """
    body = body.strip()
    lower = body.lower()

    db = get_db_session()
    try:
        contact = crud.get_contact_by_whatsapp(db, from_number)
        if not contact:
            return UNKNOWN_USER_MESSAGE

        if contact.role == "executive":
            return EXECUTIVE_ONLY_MESSAGE

        # --- secretary / driver flow ---
        session = get_session(from_number)

        # Global commands are handled regardless of current state
        if lower in _CANCEL_WORDS:
            clear_session(from_number)
            return CANCELLED_MESSAGE
        if lower in _HELP_WORDS:
            return HELP_MESSAGE
        if lower in _LIST_WORDS:
            return _format_schedule_list(db)

        # Route to the correct state handler
        if session.state == SessionState.IDLE:
            return _handle_idle(session, lower)

        if session.state == SessionState.AWAITING_TITLE:
            return _handle_awaiting_title(session, body)

        if session.state == SessionState.AWAITING_DATE:
            return _handle_awaiting_date(session, body)

        if session.state == SessionState.AWAITING_TIME:
            return _handle_awaiting_time(session, body)

        if session.state == SessionState.AWAITING_LOCATION:
            return await _handle_awaiting_location(session, body)

        if session.state == SessionState.AWAITING_NOTES:
            return _handle_awaiting_notes(session, body, lower)

        if session.state == SessionState.CONFIRMING:
            return await _handle_confirming(session, lower, db, contact, from_number)

        # Should never reach here — safety net
        clear_session(from_number)
        return WELCOME_MESSAGE

    except Exception:
        logger.exception("Unhandled error processing message from %s", from_number)
        return ERROR_MESSAGE
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Per-state handlers
# ---------------------------------------------------------------------------


def _handle_idle(session, lower: str) -> str:
    if lower in _NEW_WORDS:
        session.state = SessionState.AWAITING_TITLE
        return ASK_TITLE
    return WELCOME_MESSAGE


def _handle_awaiting_title(session, body: str) -> str:
    session.data["title"] = body
    session.state = SessionState.AWAITING_DATE
    return ASK_DATE


def _handle_awaiting_date(session, body: str) -> str:
    parsed = parse_date(body)
    if not parsed:
        return (
            "⚠️ Không nhận được định dạng ngày. "
            "Vui lòng nhập theo định dạng DD/MM/YYYY "
            "(ví dụ: *25/05/2026*)."
        )
    session.data["date"] = parsed
    session.state = SessionState.AWAITING_TIME
    return ASK_TIME


def _handle_awaiting_time(session, body: str) -> str:
    start_t, end_t = parse_time_range(body)
    if not start_t or not end_t:
        return (
            "⚠️ Không nhận được định dạng giờ. "
            "Vui lòng nhập theo định dạng HH:MM - HH:MM "
            "(ví dụ: *09:00 - 17:00*)."
        )
    event_date: date = session.data["date"]
    session.data["start_time"] = datetime.combine(event_date, start_t)
    session.data["end_time"] = datetime.combine(event_date, end_t)
    session.state = SessionState.AWAITING_LOCATION
    return ASK_LOCATION


async def _handle_awaiting_location(session, body: str) -> str:
    session.data["location"] = body
    # Attempt geocoding — failure is non-fatal
    try:
        from app.integrations.googlemaps import geocode_location, get_googlemaps_client
        gmaps = get_googlemaps_client()
        coords = geocode_location(gmaps, body)
        if coords:
            session.data["lat"], session.data["lng"] = coords
        else:
            session.data["lat"] = session.data["lng"] = None
    except Exception as exc:
        logger.warning("Geocoding skipped for %r: %s", body, exc)
        session.data["lat"] = session.data["lng"] = None

    session.state = SessionState.AWAITING_NOTES
    return ASK_NOTES


def _handle_awaiting_notes(session, body: str, lower: str) -> str:
    session.data["notes"] = "" if lower in _SKIP_WORDS else body
    d = session.data
    confirm_msg = CONFIRM_TEMPLATE.format(
        title=d.get("title", ""),
        date=d["date"].strftime("%d/%m/%Y"),
        start=d["start_time"].strftime("%H:%M"),
        end=d["end_time"].strftime("%H:%M"),
        location=d.get("location", ""),
        notes=d.get("notes") or "(không có)",
    )
    session.state = SessionState.CONFIRMING
    return confirm_msg


async def _handle_confirming(session, lower: str, db, contact, from_number: str) -> str:
    if lower in _YES_WORDS:
        return await _confirm_and_save(session, db, contact, from_number)
    if lower in _NO_WORDS:
        clear_session(from_number)
        return CANCELLED_MESSAGE
    return "Vui lòng trả lời *Có* để xác nhận hoặc *Không* để hủy."


# ---------------------------------------------------------------------------
# Confirmation: checks + persist + reminders
# ---------------------------------------------------------------------------


async def _confirm_and_save(session, db, contact, from_number: str) -> str:
    """Run all checks, persist the schedule, schedule reminders, return summary."""
    d = session.data
    start_time: datetime = d["start_time"]
    end_time: datetime = d["end_time"]
    notes_text: str = d.get("notes", "") or ""

    # 1. Conflict detection
    existing = crud.get_schedules_in_range(db, start_time, end_time)
    conflicts = check_conflict(
        {"start_time": start_time, "end_time": end_time},
        [
            {
                "start_time": s.start_time,
                "end_time": s.end_time,
                "title": s.title,
            }
            for s in existing
        ],
    )
    conflict_note = ""
    if conflicts:
        titles = ", ".join(c["title"] for c in conflicts)
        conflict_note = CONFLICT_WARNING.format(titles=titles)

    # 2. Travel feasibility: compare against the most recent preceding event
    travel_note = ""
    needs_travel = False
    all_schedules = crud.get_all_schedules(db)
    prev_sched = next(
        (s for s in reversed(all_schedules) if s.end_time <= start_time), None
    )
    if prev_sched and prev_sched.lat is not None and d.get("lat") is not None:
        try:
            from app.integrations.googlemaps import get_googlemaps_client
            from app.integrations.amadeus import get_amadeus_client
            from app.scheduler.travel import check_travel_feasibility

            result = check_travel_feasibility(
                prev_sched, d, get_googlemaps_client(), get_amadeus_client()
            )
            if not result["feasible"]:
                travel_note = TRAVEL_WARNING.format(message=result["message"])
            needs_travel = result.get("mode") in ("flight", "none")
        except Exception as exc:
            logger.warning("Travel feasibility check failed: %s", exc)

    # 3. Work classification
    is_work = is_work_related(f"{d['title']} {notes_text}")

    # 4. Persist to DB
    schedule = crud.create_schedule(
        db,
        title=d["title"],
        start_time=start_time,
        end_time=end_time,
        location=d.get("location"),
        lat=d.get("lat"),
        lng=d.get("lng"),
        notes=notes_text or None,
        is_work=is_work,
        created_by=contact.role,
    )

    if notes_text and is_work:
        crud.create_work_note(db, schedule.id, notes_text)

    # 5. Schedule reminders
    schedule_event_reminders(db, schedule, needs_travel=needs_travel)

    # Clear session
    clear_session(from_number)

    # Build response
    parts = [SAVED_MESSAGE.format(title=d["title"])]
    if conflict_note:
        parts.append(conflict_note)
    if travel_note:
        parts.append(travel_note)
    if is_work:
        parts.append("📊 Sự kiện này được phân loại là *công việc*.")

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# List formatter
# ---------------------------------------------------------------------------


def _format_schedule_list(db) -> str:
    """Return a formatted string of upcoming schedules (max 10)."""
    all_schedules = crud.get_all_schedules(db)
    now = datetime.utcnow()
    upcoming = [s for s in all_schedules if s.end_time >= now]

    if not upcoming:
        return NO_EVENTS_MESSAGE

    lines = [LIST_HEADER]
    for sched in upcoming[:10]:
        work_tag = " 📊" if sched.is_work else ""
        lines.append(
            f"📅 *{sched.title}*{work_tag}\n"
            f"   🕐 {sched.start_time.strftime('%d/%m/%Y %H:%M')} – "
            f"{sched.end_time.strftime('%H:%M')}\n"
            f"   📍 {sched.location or 'Chưa có địa điểm'}"
        )

    return "\n\n".join(lines)
