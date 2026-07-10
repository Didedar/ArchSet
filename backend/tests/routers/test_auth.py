"""Tests for /api/v1/auth: register, login, refresh, me."""

import pytest
from httpx import AsyncClient

from app.models.user import User
from app.utils.security import create_access_token, create_refresh_token


@pytest.mark.asyncio
async def test_register_creates_a_user(client: AsyncClient):
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": "new@example.com", "password": "password123"},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "new@example.com"
    assert "id" in body
    assert "password" not in body
    assert "password_hash" not in body


@pytest.mark.asyncio
async def test_register_rejects_duplicate_email(client: AsyncClient, test_user: User):
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": test_user.email, "password": "password123"},
    )

    assert response.status_code == 400
    assert "already registered" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_register_rejects_short_password(client: AsyncClient):
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": "new@example.com", "password": "short"},
    )

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_login_returns_tokens_for_correct_credentials(
    client: AsyncClient, test_user: User
):
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": test_user.email, "password": "password123"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]
    assert body["refresh_token"]


@pytest.mark.asyncio
async def test_login_rejects_wrong_password(client: AsyncClient, test_user: User):
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": test_user.email, "password": "wrong-password"},
    )

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_rejects_unknown_email(client: AsyncClient):
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@example.com", "password": "password123"},
    )

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_refresh_issues_a_new_token_pair(client: AsyncClient, test_user: User):
    refresh_token = create_refresh_token(data={"sub": test_user.id})

    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]


@pytest.mark.asyncio
async def test_refresh_rejects_an_access_token_used_as_refresh_token(
    client: AsyncClient, test_user: User
):
    access_token = create_access_token(data={"sub": test_user.id})

    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": access_token}
    )

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_refresh_rejects_garbage_token(client: AsyncClient):
    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": "not-a-real-token"}
    )

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_me_returns_the_authenticated_user(
    client: AsyncClient, test_user: User, auth_headers: dict
):
    response = await client.get("/api/v1/auth/me", headers=auth_headers)

    assert response.status_code == 200
    assert response.json()["email"] == test_user.email


@pytest.mark.asyncio
async def test_me_requires_a_token(client: AsyncClient):
    response = await client.get("/api/v1/auth/me")

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_me_rejects_an_invalid_token(client: AsyncClient):
    response = await client.get(
        "/api/v1/auth/me", headers={"Authorization": "Bearer not-a-real-token"}
    )

    assert response.status_code == 401
