"""Database engine, session factory, and dependency helper."""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL: str = os.getenv(
    "DATABASE_URL",
    "postgresql://ocen:ocen_password@localhost:5432/ocen_db",
)

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
