"""Database engine, session factory, and dependency helper.

Supports both PostgreSQL (production / Docker) and SQLite (local dev).

Set the DATABASE_URL environment variable to switch:
  PostgreSQL: postgresql://ocen:ocen_password@localhost:5432/ocen_db
  SQLite:     sqlite:///./ocen.db
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL: str = os.getenv(
    "DATABASE_URL",
    "sqlite:///./ocen.db",   # safe default for local development
)

# SQLite requires different engine settings than PostgreSQL
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},  # needed for multi-threaded FastAPI
    )
else:
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,   # reconnect after server-side timeout
        pool_size=5,
        max_overflow=10,
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    """FastAPI dependency that yields a DB session and closes it on exit."""
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_db_session() -> Session:
    """Return a plain session for non-FastAPI callers (e.g. scheduler jobs)."""
    return SessionLocal()
