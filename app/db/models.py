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
    Index,
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


class Flight(Base):
    """A domestic Vietnam flight from the scraped schedule dataset.

    Populated on startup from FlightSchedule/data/vietnam_flights_2026.csv
    (or daily JSON files if the CSV hasn't been built yet).
    Treated as read-only — not modified by the REST API.
    """

    __tablename__ = "flights"

    id = Column(Integer, primary_key=True, autoincrement=True)
    date = Column(String(10), nullable=False)          # "YYYY-MM-DD"
    airline = Column(String(100), nullable=False)      # "Vietnam Airlines"
    flight_number = Column(String(20), nullable=False) # "VN123"
    from_iata = Column(String(4), nullable=False)      # "HAN"
    to_iata = Column(String(4), nullable=False)        # "SGN"
    from_name = Column(String(200), nullable=True)
    to_name = Column(String(200), nullable=True)
    dep_time = Column(String(5), nullable=False)       # "HH:MM"
    arr_time = Column(String(5), nullable=False)       # "HH:MM"
    status = Column(String(20), nullable=False, default="scheduled")

    __table_args__ = (
        Index("ix_flights_route_date", "date", "from_iata", "to_iata"),
    )

    def __repr__(self) -> str:
        return (
            f"<Flight {self.flight_number} {self.from_iata}→{self.to_iata}"
            f" {self.date} {self.dep_time}>"
        )
