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

from fastapi import FastAPI, HTTPException, Query
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
    """Initialise the database schema, load flight data, and start scheduler."""
    from app.db import engine, get_db_session
    from app.db.models import Base, Flight
    from app.scheduler.reminders import start_scheduler

    logger.info("Creating database tables if not present…")
    Base.metadata.create_all(bind=engine)

    logger.info("Loading flight schedule data if needed…")
    _load_flights_if_empty(get_db_session, Flight)

    logger.info("Starting background reminder scheduler…")
    start_scheduler()


def _load_flights_if_empty(get_db_session, Flight) -> None:  # noqa: N803
    """Bulk-load flight data from CSV or JSON files on first startup."""
    import glob as glob_module
    import json

    db = get_db_session()
    try:
        if db.query(Flight).first() is not None:
            logger.info("Flight table already populated — skipping load.")
            return

        base_dir = os.path.join(os.path.dirname(__file__), "..", "FlightSchedule", "data")
        csv_path = os.path.join(base_dir, "vietnam_flights_2026.csv")
        rows: list[dict] = []

        if os.path.exists(csv_path):
            try:
                import pandas as pd  # type: ignore
                df = pd.read_csv(csv_path)
                df["status"] = "scheduled"  # projected rows — treat as scheduled
                rows = df.to_dict(orient="records")
                logger.info("Loaded %d flights from CSV.", len(rows))
            except Exception as exc:
                logger.warning("Failed to read CSV: %s", exc)

        if not rows:
            # Fallback: load from daily JSON files
            pattern = os.path.join(base_dir, "????-??-??.json")
            for path in sorted(glob_module.glob(pattern)):
                try:
                    with open(path, encoding="utf-8") as f:
                        day_flights = json.load(f)
                    rows.extend(day_flights)
                except Exception as exc:
                    logger.warning("Skipping %s: %s", path, exc)
            if rows:
                logger.info("Loaded %d flights from daily JSON files.", len(rows))

        if not rows:
            logger.info("No flight data files found — flight table left empty.")
            return

        # Bulk insert in batches of 500
        batch: list[Flight] = []
        for r in rows:
            batch.append(Flight(
                date=str(r.get("date", "")),
                airline=str(r.get("airline", "")),
                flight_number=str(r.get("flight_number", "")),
                from_iata=str(r.get("from_iata", "")),
                to_iata=str(r.get("to_iata", "")),
                from_name=str(r.get("from_name", "") or ""),
                to_name=str(r.get("to_name", "") or ""),
                dep_time=str(r.get("dep_time", "")),
                arr_time=str(r.get("arr_time", "")),
                status="scheduled",
            ))
            if len(batch) >= 500:
                db.bulk_save_objects(batch)
                db.commit()
                batch = []
        if batch:
            db.bulk_save_objects(batch)
            db.commit()

        total = db.query(Flight).count()
        logger.info("Flight table ready — %d rows.", total)
    except Exception as exc:
        logger.error("Error loading flights: %s", exc)
        db.rollback()
    finally:
        db.close()


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


# ---------------------------------------------------------------------------
# Flight REST API  (consumed by the Flutter mobile app)
# ---------------------------------------------------------------------------


@app.get("/flights")
async def list_flights(
    from_: Optional[str] = Query(None, alias="from"),
    to: Optional[str] = Query(None, alias="to"),
    date: Optional[str] = Query(None),
) -> list:
    """Return flights matching a route and date.

    Query params:
      from  — departure IATA code (e.g. HAN)
      to    — arrival IATA code   (e.g. SGN)
      date  — YYYY-MM-DD or "today"

    All params are optional — omit to return all flights (use sparingly).
    """
    from app.db import get_db_session
    from app.db.models import Flight

    resolved_date = date
    if date and date.lower() == "today":
        resolved_date = datetime.now().strftime("%Y-%m-%d")

    db = get_db_session()
    try:
        query = db.query(Flight)
        if from_:
            query = query.filter(Flight.from_iata == from_.upper())
        if to:
            query = query.filter(Flight.to_iata == to.upper())
        if resolved_date:
            query = query.filter(Flight.date == resolved_date)
        flights = query.order_by(Flight.dep_time).all()

        return [
            {
                "id": f.id,
                "date": f.date,
                "airline": f.airline,
                "flight_number": f.flight_number,
                "from_iata": f.from_iata,
                "to_iata": f.to_iata,
                "from_name": f.from_name,
                "to_name": f.to_name,
                "dep_time": f.dep_time,
                "arr_time": f.arr_time,
                "status": "scheduled",  # always scheduled for projected data
            }
            for f in flights
        ]
    finally:
        db.close()


@app.get("/flights/routes")
async def list_flight_routes() -> list:
    """Return all unique domestic routes available in the flight dataset."""
    from app.db import get_db_session
    from app.db.models import Flight

    db = get_db_session()
    try:
        rows = (
            db.query(
                Flight.from_iata,
                Flight.to_iata,
                Flight.from_name,
                Flight.to_name,
            )
            .distinct(Flight.from_iata, Flight.to_iata)
            .order_by(Flight.from_iata, Flight.to_iata)
            .all()
        )
        return [
            {
                "from_iata": r.from_iata,
                "to_iata": r.to_iata,
                "from_name": r.from_name or "",
                "to_name": r.to_name or "",
            }
            for r in rows
        ]
    finally:
        db.close()
