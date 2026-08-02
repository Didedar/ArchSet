"""
Shared pytest fixtures for the backend test suite.

Import order matters here: app.services.rag_service raises ValueError at
*module import time* if GEMINI_API_KEY is unset, and app.database builds a
module-level async engine singleton from DATABASE_URL at import time too.
Both env vars (plus SECRET_KEY, so JWTs minted in tests match what
get_current_user decodes) must be set before anything under `app` is
imported for the first time -- hence they're set here, at the top of this
file, before the `from app...` imports below.
"""

import os

os.environ["GEMINI_API_KEY"] = "test-dummy-key"
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["SECRET_KEY"] = "test-secret-key"
os.environ["DEBUG"] = "False"

# rag_service.py constructs a real Gemini LLM client and GeminiEmbedding
# client at MODULE IMPORT TIME (not lazily), and llama-index's Gemini
# wrapper calls genai.get_model() -- a real network request -- inside its
# __init__ to validate the model name. A non-empty dummy API key is not
# enough to avoid this: it still reaches the network and fails there.
# Since almost everything under `app` transitively imports rag_service
# (app.main imports it directly, and most routers import app.main's app),
# these two classes must be stubbed out before rag_service is ever
# imported, so its module-level constructor calls hit a harmless fake
# instead of the real Gemini API. rag_service does `from llama_index.llms
# .google_genai import GoogleGenAI`, which binds its own local name to whatever these
# module attributes hold at that moment -- so this patch only works if it
# runs before the first `from app...` import below.
#
# LlamaSettings.llm/.embed_model setters call resolve_llm()/resolve_embed_model(),
# which need a real LLM/BaseEmbedding subclass (isinstance checks, plus real
# attributes like callback_manager that a bare MagicMock doesn't have) -- so
# instead of mocking Gemini/GeminiEmbedding's *output*, swap in llama-index's
# own built-in test doubles, which are exactly that: real, lightweight,
# network-free LLM/BaseEmbedding implementations meant for this purpose.
from llama_index.core.embeddings import MockEmbedding
from llama_index.core.llms import MockLLM

import llama_index.embeddings.google_genai as _llama_genai_embedding
import llama_index.llms.google_genai as _llama_genai_llm

_llama_genai_llm.GoogleGenAI = lambda *args, **kwargs: MockLLM()
_llama_genai_embedding.GoogleGenAIEmbedding = lambda *args, **kwargs: (
    MockEmbedding(embed_dim=8)
)

from typing import AsyncGenerator
from unittest.mock import AsyncMock, patch

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.user import User
from app.services.rag_service import rag_service
from app.utils.security import create_access_token, get_password_hash

# StaticPool keeps a single underlying connection alive for the whole engine,
# which is required for an in-memory sqlite DB to be visible across the
# multiple connections FastAPI's dependency injection opens per request --
# without it, each connection would see its own empty in-memory database.
test_engine = create_async_engine(
    "sqlite+aiosqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestSessionLocal = async_sessionmaker(
    test_engine, class_=AsyncSession, expire_on_commit=False
)


@event.listens_for(test_engine.sync_engine, "connect")
def _enable_sqlite_foreign_keys(dbapi_connection, connection_record):
    """SQLite ignores foreign keys unless PRAGMA foreign_keys=ON is set per
    connection, outside a transaction -- so it's set here on the raw DBAPI
    connection as soon as it's opened, rather than via a SQL statement
    issued through a session/transaction. Without this, tests would pass
    even when application code violates a FK (e.g. inserting a note whose
    folder_id doesn't exist yet), silently hiding bugs that a
    FK-enforcing database (Postgres in production) would reject.
    """
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


@pytest_asyncio.fixture(autouse=True)
async def _prepare_database() -> AsyncGenerator[None, None]:
    """Fresh tables for every test, so tests never see another test's data."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    async with TestSessionLocal() as session:
        yield session


@pytest_asyncio.fixture(autouse=True)
async def _stub_rag_background_tasks() -> AsyncGenerator[None, None]:
    """Prevent note create/update/delete and sync from touching the real
    ./storage vector-store directory on disk via their fire-and-forget
    BackgroundTasks calls. `rag_service` is a single shared instance
    imported by app.routers.notes, app.routers.ai, and
    app.services.sync_service alike, so patching its bound methods once
    here covers all of them regardless of which module a test exercises.

    test_rag_service.py tests the real methods directly against a fresh,
    separate RAGService() instance (not this shared singleton), so it is
    unaffected by this patch.
    """
    with (
        patch.object(rag_service, "sync_diary_to_vector_db", new_callable=AsyncMock),
        patch.object(rag_service, "delete_note_from_index", new_callable=AsyncMock),
    ):
        yield


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """An httpx client wired to the app with get_db overridden to the test DB.

    Route handlers already call db.commit() themselves (confirmed for every
    write endpoint), so the override just needs to yield the shared session
    -- no need to replicate get_db's own commit/rollback wrapper.
    """

    async def _override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> User:
    user = User(email="test@example.com", password_hash=await get_password_hash("password123"))
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def other_user(db_session: AsyncSession) -> User:
    """A second user, for tests that assert data isolation between accounts."""
    user = User(email="other@example.com", password_hash=await get_password_hash("password456"))
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def auth_headers(test_user: User) -> dict:
    token = create_access_token(data={"sub": test_user.id})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def other_auth_headers(other_user: User) -> dict:
    token = create_access_token(data={"sub": other_user.id})
    return {"Authorization": f"Bearer {token}"}
