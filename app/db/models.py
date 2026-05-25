"""SQLAlchemy ORM models for OCEN.

Tables
------
schedules   — calendar events
work_notes  — structured work-related notes attached to a schedule
reminders   — reminder jobs with sent/pending status
"""

from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(DeclarativeBase):
    pass


class Schedule(Base):
    """A calendar event with optional geographic coordinates."""

    __tablename__ = "schedules"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    start_time = Column(DateTime, nullable=False, index=True)
    end_time = Column(DateTime, nullable=False, index=True)
    location = Column(String(500), nullable=True)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    notes = Column(Text, nullable=True)
    is_work = Column(Boolean, default=False, nullable=False)
    created_by = Column(String(50), nullable=False)   # role: secretary | driver
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    work_notes = relationship(
        "WorkNote", back_populates="schedule", cascade="all, delete-orphan"
    )
    reminders = relationship(
        "Reminder", back_populates="schedule", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Schedule id={self.id} title={self.title!r} start={self.start_time}>"


class WorkNote(Base):
    """A work-related note linked to a specific schedule."""

    __tablename__ = "work_notes"

    id = Column(Integer, primary_key=True, index=True)
    schedule_id = Column(Integer, ForeignKey("schedules.id"), nullable=False, index=True)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    schedule = relationship("Schedule", back_populates="work_notes")

    def __repr__(self) -> str:
        return f"<WorkNote id={self.id} schedule_id={self.schedule_id}>"


class Reminder(Base):
    """A scheduled reminder message for the executive."""

    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True)
    schedule_id = Column(Integer, ForeignKey("schedules.id"), nullable=False, index=True)
    remind_at = Column(DateTime, nullable=False, index=True)
    sent = Column(Boolean, default=False, nullable=False)
    sent_at = Column(DateTime, nullable=True)

    schedule = relationship("Schedule", back_populates="reminders")

    def __repr__(self) -> str:
        return f"<Reminder id={self.id} remind_at={self.remind_at} sent={self.sent}>"
