"""Alembic environment.

Runs migrations with the *synchronous* psycopg2 driver even though the app
itself uses asyncpg. Migrations are short, one-shot and single-threaded, so
async buys nothing here and sync keeps this file simple. psycopg2-binary is
already a dependency.
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, inspect, pool, text

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


def _adopt_pre_alembic_database(connection) -> None:
    """Stamp a database whose tables predate Alembic, so `upgrade` can run.

    `init_db()` calls `Base.metadata.create_all()` on every app start, so
    production's tables were created without Alembic ever recording a
    version. `upgrade head` then starts from scratch at 0001 and dies on
    "relation \"users\" already exists" -- which is why 0002 (the `revision`
    columns) and 0003 never landed, and why every /sync 500'd.

    0001 describes exactly what create_all already built, so recording it as
    applied is truthful, not a shortcut: the remaining migrations are the ones
    that genuinely still need to run.

    Deliberately keyed on `users` rather than any table: it exists in 0001 and
    in no later migration, so its presence means "this database predates
    Alembic" and never "a later migration half-ran".
    """
    tables = set(inspect(connection).get_table_names())
    if "alembic_version" in tables or "users" not in tables:
        return

    connection.execute(
        text(
            "CREATE TABLE alembic_version ("
            "version_num VARCHAR(32) NOT NULL, "
            "CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num))"
        )
    )
    connection.execute(
        text("INSERT INTO alembic_version (version_num) VALUES ('0001')")
    )
    connection.commit()


def run_migrations_online() -> None:
    section = config.get_section(config.config_ini_section) or {}
    section["sqlalchemy.url"] = _sync_url()

    connectable = engine_from_config(
        section,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        _adopt_pre_alembic_database(connection)

        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()

        # SQLAlchemy 2.0 rolls back whatever is still open when a connection
        # from `connect()` closes. Without this the whole upgrade reports
        # success, logs every "Running upgrade" line, and leaves the database
        # exactly as it was -- which is indistinguishable from migrations that
        # never ran, and is how this went unnoticed.
        connection.commit()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
