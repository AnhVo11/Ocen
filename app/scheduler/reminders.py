"""APScheduler-based reminder dispatch.

Reminder timing rules
---------------------
* Travel-required events (inter-city): remind at T-24h and T-3h
* Local events (same city / no travel): remind at T-30min

All reminders are sent as WhatsApp messages to the executive's number via
Twilio.  Each reminder is also recorded in the ``reminders`` DB table so the
scheduler can survive restarts by reloading pending reminders on startup.
"""

import logging
import os
from datetime import datetime, timedelta

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.jobstores.memory import MemoryJobStore

logger = logging.getLogger(__name__)

# Module-level scheduler — started once when the FastAPI app starts
_scheduler = BackgroundScheduler(
    jobstores={"default": MemoryJobStore()},
    job_defaults={"coalesce": True, "max_instances": 1, "misfire_grace_time": 300},
)


def start_scheduler() -> None:
    """Start the background scheduler (idempotent)."""
    if not _scheduler.running:
        _scheduler.start()
        logger.info("APScheduler started.")
        _reload_pending_reminders()


def stop_scheduler() -> None:
    """Gracefully shut down the background scheduler."""
    if _scheduler.running:
        _scheduler.shutdown(wait=False)
        logger.info("APScheduler stopped.")


def _reload_pending_reminders() -> None:
    """Re-register any unsent reminders from the DB on startup.

    This prevents reminder loss if the process was restarted before all
    reminders fired.
    """
    from app.db import get_db_session
    from app.db.crud import get_pending_reminders, get_schedule_by_id

    executive_number = os.getenv("EXECUTIVE_WHATSAPP", "")
    if not executive_number:
        logger.warning("EXECUTIVE_WHATSAPP not set — reminders will not be dispatched.")
        return

    db = get_db_session()
    try:
        now = datetime.utcnow()
        pending = get_pending_reminders(db, as_of=datetime(9999, 1, 1))
        for reminder in pending:
            if reminder.remind_at <= now:
                # Already overdue — fire immediately
                _fire_reminder(reminder.id, reminder.schedule_id, executive_number)
            else:
                _schedule_job(reminder.id, reminder.schedule_id, executive_number, reminder.remind_at)
        logger.info("Reloaded %d pending reminder(s) from DB.", len(pending))
    finally:
        db.close()


def schedule_event_reminders(db, schedule, *, needs_travel: bool) -> None:
    """Create DB reminder records and register APScheduler jobs for an event.

    Parameters
    ----------
    db:
        Active SQLAlchemy session.
    schedule:
        Persisted ``Schedule`` ORM model with ``id`` and ``start_time``.
    needs_travel:
        True when the executive needs to travel between this event and the
        previous one (triggers 24h + 3h reminders instead of 30min).
    """
    from app.db.crud import create_reminder

    executive_number = os.getenv("EXECUTIVE_WHATSAPP", "")
    if not executive_number:
        logger.warning("EXECUTIVE_WHATSAPP not set — skipping reminder scheduling.")
        return

    now = datetime.utcnow()
    fire_times: list[datetime] = []

    if needs_travel:
        fire_times.append(schedule.start_time - timedelta(hours=24))
        fire_times.append(schedule.start_time - timedelta(hours=3))
    else:
        fire_times.append(schedule.start_time - timedelta(minutes=30))

    for fire_at in fire_times:
        if fire_at <= now:
            logger.debug(
                "Reminder fire time %s is in the past for schedule %d — skipping.",
                fire_at,
                schedule.id,
            )
            continue
        reminder = create_reminder(db, schedule.id, fire_at)
        _schedule_job(reminder.id, schedule.id, executive_number, fire_at)
        logger.info(
            "Scheduled reminder id=%d for schedule '%s' at %s.",
            reminder.id,
            schedule.title,
            fire_at.isoformat(),
        )


def _schedule_job(
    reminder_id: int, schedule_id: int, executive_number: str, fire_at: datetime
) -> None:
    """Register a single APScheduler date-trigger job."""
    job_id = f"reminder_{reminder_id}"
    # Avoid duplicate jobs if called multiple times (e.g. on reload)
    if _scheduler.get_job(job_id):
        return
    _scheduler.add_job(
        _fire_reminder,
        trigger="date",
        run_date=fire_at,
        args=[reminder_id, schedule_id, executive_number],
        id=job_id,
    )


def _fire_reminder(
    reminder_id: int, schedule_id: int, executive_number: str
) -> None:
    """Fetch the schedule, compose a message, send it, and mark as sent.

    This function is called by APScheduler in a background thread.
    """
    from app.db import get_db_session
    from app.db.crud import get_schedule_by_id, mark_reminder_sent
    from app.integrations.whatsapp import send_whatsapp_message

    db = get_db_session()
    try:
        schedule = get_schedule_by_id(db, schedule_id)
        if not schedule:
            logger.error("Reminder %d: schedule %d not found.", reminder_id, schedule_id)
            return

        message = _compose_reminder_message(schedule)
        send_whatsapp_message(to=executive_number, body=message)
        mark_reminder_sent(db, reminder_id)
        logger.info(
            "Sent reminder id=%d for schedule '%s' to %s.",
            reminder_id,
            schedule.title,
            executive_number,
        )
    except Exception as exc:
        logger.exception(
            "Failed to send reminder id=%d for schedule %d: %s",
            reminder_id,
            schedule_id,
            exc,
        )
    finally:
        db.close()


def _compose_reminder_message(schedule) -> str:
    """Build a human-readable reminder message for the executive.

    Parameters
    ----------
    schedule:
        ``Schedule`` ORM model.

    Returns
    -------
    str
        Formatted WhatsApp message.
    """
    minutes_until = (schedule.start_time - datetime.utcnow()).total_seconds() / 60

    if minutes_until >= 60:
        time_label = f"{int(minutes_until / 60)} giờ nữa"
    else:
        time_label = f"{int(minutes_until)} phút nữa"

    location_line = f"\n📍 *Địa điểm:* {schedule.location}" if schedule.location else ""
    work_tag = "\n📊 _(Sự kiện công việc)_" if schedule.is_work else ""

    return (
        f"⏰ *Nhắc nhở lịch — {time_label}*\n\n"
        f"📌 *{schedule.title}*\n"
        f"🕐 {schedule.start_time.strftime('%H:%M')} – "
        f"{schedule.end_time.strftime('%H:%M')} "
        f"({schedule.start_time.strftime('%d/%m/%Y')})"
        f"{location_line}"
        f"{work_tag}"
    )
