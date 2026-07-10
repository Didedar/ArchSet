"""Tests for /api/v1/ai/chat.

rag_service is a module-level singleton imported directly into
app.routers.ai (not DI-injected), so it can't be swapped via
app.dependency_overrides -- these tests monkeypatch the imported reference
on the router module itself instead.
"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_chat_returns_the_rag_response(client: AsyncClient, auth_headers: dict, monkeypatch):
    async def fake_chat_with_diary(user_query, chat_history, user_id):
        return "You found pottery shards on day 3."

    monkeypatch.setattr(
        "app.routers.ai.rag_service.chat_with_diary", fake_chat_with_diary
    )

    response = await client.post(
        "/api/v1/ai/chat", json={"query": "What did I find?"}, headers=auth_headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["response"] == "You found pottery shards on day 3."


@pytest.mark.asyncio
async def test_chat_rejects_an_empty_query(client: AsyncClient, auth_headers: dict):
    response = await client.post("/api/v1/ai/chat", json={"query": "   "}, headers=auth_headers)

    assert response.status_code == 400


@pytest.mark.asyncio
async def test_chat_requires_auth(client: AsyncClient):
    response = await client.post("/api/v1/ai/chat", json={"query": "What did I find?"})

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_chat_reports_an_exception_as_a_clean_failure(
    client: AsyncClient, auth_headers: dict, monkeypatch
):
    async def failing_chat_with_diary(user_query, chat_history, user_id):
        raise RuntimeError("vector store unavailable")

    monkeypatch.setattr(
        "app.routers.ai.rag_service.chat_with_diary", failing_chat_with_diary
    )

    response = await client.post(
        "/api/v1/ai/chat", json={"query": "What did I find?"}, headers=auth_headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is False
    assert "vector store unavailable" in body["error"]


@pytest.mark.asyncio
async def test_chat_forwards_history_and_user_id(
    client: AsyncClient, auth_headers: dict, test_user, monkeypatch
):
    captured = {}

    async def fake_chat_with_diary(user_query, chat_history, user_id):
        captured["user_query"] = user_query
        captured["chat_history"] = chat_history
        captured["user_id"] = user_id
        return "ok"

    monkeypatch.setattr(
        "app.routers.ai.rag_service.chat_with_diary", fake_chat_with_diary
    )

    history = [{"role": "user", "content": "Hi"}, {"role": "assistant", "content": "Hello"}]
    await client.post(
        "/api/v1/ai/chat",
        json={"query": "What did I find?", "history": history},
        headers=auth_headers,
    )

    assert captured["user_query"] == "What did I find?"
    assert captured["chat_history"] == history
    assert captured["user_id"] == test_user.id
