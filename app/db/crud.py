"""Database CRUD operations.

All functions accept a SQLAlchemy Session as their first argument and are
intentionally synchronous to keep the calling code straightforward.
"""

from datetime import datetime
from typing import List, Optional

from sqlalchemy import and_
from sqlalchemy.orm import Session

from .models import Reminder, Schedule, WorkNote


# ---------------------------------------------------------------------------
# Schedule
# ---------------------------------------------------------------------------


def create_schedule(
    db: Session,
    *,
    title: str,
    start_time: datetime,
    end_time: datetime,
    location: Optional[str],
    lat: Optional[float],
    lng: Optional[float],
    notes: Optional[str],
    is_work: bool,
    created_by: str,
) -> Schedule:
    """Persist a new schedule and return the created row."""
    schedule = Schedule(
        title=title,
        start_time=start_time,
        end_time=end_time,
        location=location,
        lat=lat,
        lng=lng,
        notes=notes,
        is_work=is_work,
        created_by=created_by,
    )
    db.add(schedule)
    db.commit()
    db.refresh(schedule)
    return schedule


def get_schedule_by_id(db: Session, schedule_id: int) -> Optional[Schedule]:
    """Return a schedule by primary key, or None if not found."""
    return db.query(Schedule).filter(Schedule.id == schedule_id).first()


def get_schedules_in_range(
    db: Session, start: datetime, end: datetime
) -> List[Schedule]:
    """Return all schedules whose time range overlaps [start, end)."""
    return (
        db.query(Schedule)
        .filter(and_(Schedule.start_time < end, Schedule.end_time > start))
        .order_by(Schedule.start_time)
        .all()
    )


def get_all_schedules(db: Session) -> List[Schedule]:
    """Return all schedules ordered by start time (oldest first)."""
    return db.query(Schedule).order_by(Schedule.start_time).all()


def update_schedule(db: Session, schedule_id: int, **kwargs) -> Optional[Schedule]:
    """Update arbitrary fields on a schedule. Returns updated row or None."""
    schedule = get_schedule_by_id(db, schedule_id)
    if not schedule:
        return None
    for key, value in kwargs.items():
        setattr(schedule, key, value)
    db.commit()
    db.refresh(schedule)
    return schedule


def delete_schedule(db: Session, schedule_id: int) -> bool:
    """Delete a schedule and its related records. Returns True if deleted."""
    schedule = get_schedule_by_id(db, schedule_id)
    if not schedule:
        return False
    db.delete(schedule)
    db.commit()
    return True


# ---------------------------------------------------------------------------
# WorkNote
# ---------------------------------------------------------------------------


def create_work_note(db: Session, schedule_id: int, content: str) -> WorkNote:
    """Attach a work note to a schedule."""
    note = WorkNote(schedule_id=schedule_id, content=content)
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


def get_work_notes_for_schedule(db: Session, schedule_id: int) -> List[WorkNote]:
    """Return all work notes for a given schedule."""
    return (
        db.query(WorkNote)
        .filter(WorkNote.schedule_id == schedule_id)
        .order_by(WorkNote.created_at)
        .all()
    )


# ---------------------------------------------------------------------------
# Reminder
# ---------------------------------------------------------------------------


def create_reminder(
    db: Session, schedule_id: int, remind_at: datetime
) -> Reminder:
    """Create a pending reminder for a schedule."""
    reminder = Reminder(schedule_id=schedule_id, remind_at=remind_at)
    db.add(reminder)
    db.commit()
    db.refresh(reminder)
    return reminder


def get_pending_reminders(db: Session, as_of: datetime) -> List[Reminder]:
    """Return all unsent reminders whose fire time is at or before `as_of`."""
    return (
        db.query(Reminder)
        .filter(and_(Reminder.sent == False, Reminder.remind_at <= as_of))
        .all()
    )


def mark_reminder_sent(db: Session, reminder_id: int) -> None:
    """Mark a reminder as sent and record the timestamp."""
    reminder = db.query(Reminder).filter(Reminder.id == reminder_id).first()
    if reminder:
        reminder.sent = True
        reminder.sent_at = datetime.utcnow()
        db.commit()
