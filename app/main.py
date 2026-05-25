"""FastAPI application entry point.

Endpoints
---------
GET  /health                 — Liveness check for Docker / load balancer
GET  /schedules              — JSON list of all schedules (mobile app sync)
POST /schedules              — Create a new schedule (from mobile app)
PUT  /schedules/{id}         — Update an existing schedule
DELETE /schedules/{id}       — Delete a schedule

Startup / Shutdown
------------------
On startup: create DB tables (if absent) and start APScheduler.
On shutdown: stop APScheduler gracefully.
"""

import logging
import os
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="OCEN — Executive Scheduling Assistant",
    description="Smart scheduling assistant for a Vietnamese executive.",
    version="0.2.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Pydantic schemas for the mobile REST API
# ---------------------------------------------------------------------------


class ScheduleCreate(BaseModel):
    title: str
    start_time: str          # ISO 8601, e.g. "2026-05-25T09:00:00"
    end_time: str
    location: Optional[str] = None
    notes: Optional[str] = None
    is_work: bool = False
    created_by: str = "app"  # "secretary" | "driver" | "app"


class ScheduleUpdate(BaseModel):
    title: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    location: Optional[str] = None
    notes: Optional[str] = None
    is_work: Optional[bool] = None


# ---------------------------------------------------------------------------
# Serialiser helper — maps ORM row → Flutter-compatible JSON
# ---------------------------------------------------------------------------


def _schedule_to_dict(s) -> dict:
    """Convert a Schedule ORM row to a dict the Flutter app can parse."""
    return {
        "id": s.id,
        "title": s.title,
        "start_time": s.start_time.isoformat(),
        "end_time": s.end_time.isoformat(),
        "location": s.location or "",
        "notes": s.notes,
        "is_work": s.is_work,
        "created_by": s.created_by,
        # Flutter-specific travel fields — not stored on backend.
        # Flutter will recompute them locally after syncing.
        "needs_travel": False,
        "travel_mode": None,
        "travel_minutes": None,
    }


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


@app.on_event("startup")
async def on_startup() -> None:
    """Initialise the database schema and start the reminder scheduler."""
    from app.db import engine
    from app.db.models import Base
    from app.scheduler.reminders import start_scheduler

    logger.info("Creating database tables if not present…")
    Base.metadata.create_all(bind=engine)

    logger.info("Starting background reminder scheduler…")
    start_scheduler()


@app.on_event("shutdown")
async def on_shutdown() -> None:
    """Shut down the reminder scheduler on process exit."""
    from app.scheduler.reminders import stop_scheduler

    stop_scheduler()


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------


@app.get("/health")
async def health_check() -> dict:
    """Return 200 OK — used by Docker health checks."""
    return {"status": "ok", "service": "ocen-bot"}


# ---------------------------------------------------------------------------
# Schedule REST API  (consumed by the Flutter mobile app)
# ---------------------------------------------------------------------------


@app.get("/schedules")
async def list_schedules() -> list:
    """Return all schedules as JSON for mobile app sync."""
    from app.db import get_db_session
    from app.db.crud import get_all_schedules

    db = get_db_session()
    try:
        schedules = get_all_schedules(db)
        return [_schedule_to_dict(s) for s in schedules]
    finally:
        db.close()


@app.post("/schedules", status_code=201)
async def create_schedule_endpoint(payload: ScheduleCreate) -> dict:
    """Create a new schedule from the mobile app.

    Returns the created schedule with its server-assigned ``id``.
    """
    from app.db import get_db_session
    from app.db.crud import create_schedule

    try:
        start_time = datetime.fromisoformat(payload.start_time)
        end_time = datetime.fromisoformat(payload.end_time)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=f"Invalid datetime format: {exc}")

    if end_time <= start_time:
        raise HTTPException(
            status_code=422, detail="end_time must be after start_time"
        )

    db = get_db_session()
    try:
        schedule = create_schedule(
            db,
            title=payload.title,
            start_time=start_time,
            end_time=end_time,
            location=payload.location,
            lat=None,
            lng=None,
            notes=payload.notes,
            is_work=payload.is_work,
            created_by=payload.created_by,
        )
        logger.info("Created schedule id=%d title=%r via REST API", schedule.id, schedule.title)
        return _schedule_to_dict(schedule)
    finally:
        db.close()


@app.put("/schedules/{schedule_id}")
async def update_schedule_endpoint(schedule_id: int, payload: ScheduleUpdate) -> dict:
    """Update an existing schedule.

    Only fields present in the request body are updated (partial update).
    """
    from app.db import get_db_session
    from app.db.crud import get_schedule_by_id, update_schedule

    db = get_db_session()
    try:
        existing = get_schedule_by_id(db, schedule_id)
        if not existing:
            raise HTTPException(status_code=404, detail="Schedule not found")

        updates: dict = {}
        if payload.title is not None:
            updates["title"] = payload.title
        if payload.start_time is not None:
            try:
                updates["start_time"] = datetime.fromisoformat(payload.start_time)
            except ValueError as exc:
                raise HTTPException(status_code=422, detail=f"Invalid start_time: {exc}")
        if payload.end_time is not None:
            try:
                updates["end_time"] = datetime.fromisoformat(payload.end_time)
            except ValueError as exc:
                raise HTTPException(status_code=422, detail=f"Invalid end_time: {exc}")
        if payload.location is not None:
            updates["location"] = payload.location
        if payload.notes is not None:
            updates["notes"] = payload.notes
        if payload.is_work is not None:
            updates["is_work"] = payload.is_work

        updated = update_schedule(db, schedule_id, **updates)
        logger.info("Updated schedule id=%d via REST API", schedule_id)
        return _schedule_to_dict(updated)
    finally:
        db.close()


@app.delete("/schedules/{schedule_id}", status_code=204)
async def delete_schedule_endpoint(schedule_id: int) -> None:
    """Delete a schedule and all its related records."""
    from app.db import get_db_session
    from app.db.crud import delete_schedule

    db = get_db_session()
    try:
        deleted = delete_schedule(db, schedule_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Schedule not found")
        logger.info("Deleted schedule id=%d via REST API", schedule_id)
    finally:
        db.close()
