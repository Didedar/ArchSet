"""Alembic environment.

Runs migrations with the *synchronous* psycopg2 driver even though the app
itself uses asyncpg. Migrations are short, one-shot and single-threaded, so
async buys nothing here and sync keeps this file simple. psycopg2-binary is
already a dependency.
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.config import get_settings
from app.database import Base

# Importing the models package registers every table on Base.metadata, which
# is what --autogenerate diffs against. Without this import Alembic would see
# an empty schema and generate a migration that drops everything.
from app import models  # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _sync_url() -> str:
    """The app's URL rewritten for psycopg2."""
    return get_settings().database_url.replace("+asyncpg", "+psycopg2")


def run_migrations_offline() -> None:
    context.configure(
        url=_sync_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    section = config.get_section(config.config_ini_section) or {}
    section["sqlalchemy.url"] = _sync_url()

    connectable = engine_from_config(
        section,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
