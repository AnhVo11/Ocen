"""FastAPI application entry point.

Endpoints
---------
POST /webhook/whatsapp   — Twilio WhatsApp webhook (form-encoded)
GET  /health             — Liveness check for Docker / load balancer
GET  /schedules          — JSON list of all schedules (admin use)

Startup / Shutdown
------------------
On startup: create DB tables (if absent) and start APScheduler.
On shutdown: stop APScheduler gracefully.
"""

import logging
import os

from fastapi import FastAPI, Form, Response, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="OCEN — WhatsApp Scheduling Assistant",
    description="Smart scheduling bot for a Vietnamese executive via WhatsApp.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


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
# Webhook
# ---------------------------------------------------------------------------


@app.post("/webhook/whatsapp", response_class=Response)
async def whatsapp_webhook(
    From: str = Form(..., description="Sender WhatsApp number (Twilio format)"),
    Body: str = Form(..., description="Message text"),
) -> Response:
    """Receive an inbound WhatsApp message from Twilio and reply with TwiML.

    Twilio sends a POST with application/x-www-form-urlencoded body containing
    at minimum ``From`` and ``Body``.  We reply with TwiML so Twilio can
    forward the response back to the sender as a WhatsApp message.

    Parameters
    ----------
    From:
        Sender number, e.g. ``"whatsapp:+84901234567"``.
    Body:
        Text of the inbound message.

    Returns
    -------
    Response
        TwiML ``<Response><Message>…</Message></Response>`` with
        ``Content-Type: text/xml``.
    """
    logger.info("Inbound WhatsApp from %s: %r", From, Body[:80])

    from app.bot.handler import handle_message

    try:
        reply = await handle_message(From, Body)
    except Exception:
        logger.exception("Uncaught error in handle_message")
        reply = "❌ Lỗi hệ thống. Vui lòng thử lại sau."

    # Escape XML special characters in the reply body
    safe_reply = (
        reply
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )

    twiml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        "<Response>"
        f"<Message>{safe_reply}</Message>"
        "</Response>"
    )
    return Response(content=twiml, media_type="text/xml")


# ---------------------------------------------------------------------------
# Utility endpoints
# ---------------------------------------------------------------------------


@app.get("/health")
async def health_check() -> dict:
    """Return 200 OK with basic process info — used by Docker health checks."""
    return {"status": "ok", "service": "ocen-bot"}


@app.get("/schedules")
async def list_schedules() -> list:
    """Return all schedules as JSON (for admin / debugging purposes).

    Requires SECRET_KEY header for minimal auth.
    """
    from fastapi import Header
    from app.db import get_db_session
    from app.db.crud import get_all_schedules

    db = get_db_session()
    try:
        schedules = get_all_schedules(db)
        return [
            {
                "id": s.id,
                "title": s.title,
                "start_time": s.start_time.isoformat(),
                "end_time": s.end_time.isoformat(),
                "location": s.location,
                "is_work": s.is_work,
                "created_by": s.created_by,
            }
            for s in schedules
        ]
    finally:
        db.close()
