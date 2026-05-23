"""Alembic migration environment.

Reads DATABASE_URL from the environment (via python-dotenv) so migrations can
run both locally and inside Docker without editing alembic.ini.

Usage
-----
    alembic revision --autogenerate -m "add column"
    alembic upgrade head
    alembic downgrade -1
"""

import os
import sys
from logging.config import fileConfig

from alembic import context
from dotenv import load_dotenv
from sqlalchemy import engine_from_config, pool

# Make the project root importable so `from app.db.models import Base` works
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

load_dotenv()

# ---------------------------------------------------------------------------
# Alembic Config object — gives access to alembic.ini values
# ---------------------------------------------------------------------------

config = context.config

# Override sqlalchemy.url from environment so we never hard-code credentials
database_url = os.getenv(
    "DATABASE_URL", "postgresql://ocen:ocen_password@localhost:5432/ocen_db"
)
config.set_main_option("sqlalchemy.url", database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# ---------------------------------------------------------------------------
# Import metadata for autogenerate support
# ---------------------------------------------------------------------------

from app.db.models import Base  # noqa: E402

target_metadata = Base.metadata


# ---------------------------------------------------------------------------
# Migration runners
# ---------------------------------------------------------------------------


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (no live DB connection needed).

    This generates SQL scripts that can be reviewed and applied manually.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode (requires a live DB connection)."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,        # detect column type changes
            compare_server_default=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
