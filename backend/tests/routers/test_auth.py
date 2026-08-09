"""Tests for /api/v1/auth: register, login, refresh, me, delete."""

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.artifact import Artifact, ArtifactComment
from app.models.folder import Folder
from app.models.note import Note
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


@pytest.mark.asyncio
async def test_delete_account_removes_the_user(
    client: AsyncClient, test_user: User, auth_headers: dict
):
    response = await client.delete("/api/v1/auth/me", headers=auth_headers)

    assert response.status_code == 204


@pytest.mark.asyncio
async def test_delete_account_revokes_the_access_token(
    client: AsyncClient, test_user: User, auth_headers: dict
):
    delete_response = await client.delete("/api/v1/auth/me", headers=auth_headers)
    assert delete_response.status_code == 204

    response = await client.get("/api/v1/auth/me", headers=auth_headers)

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_delete_account_requires_a_token(client: AsyncClient):
    response = await client.delete("/api/v1/auth/me")

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_delete_account_does_not_affect_other_users(
    client: AsyncClient,
    test_user: User,
    auth_headers: dict,
    other_user: User,
    other_auth_headers: dict,
):
    response = await client.delete("/api/v1/auth/me", headers=auth_headers)
    assert response.status_code == 204

    response = await client.get("/api/v1/auth/me", headers=other_auth_headers)
    assert response.status_code == 200
    assert response.json()["email"] == other_user.email


@pytest.mark.asyncio
async def test_delete_account_cascades_to_folders_notes_artifacts_and_comments(
    client: AsyncClient,
    test_user: User,
    auth_headers: dict,
    db_session: AsyncSession,
):
    folder = Folder(user_id=test_user.id, name="Trench A")
    db_session.add(folder)
    await db_session.commit()
    await db_session.refresh(folder)

    note = Note(
        user_id=test_user.id,
        folder_id=folder.id,
        title="Day 1",
        content="Context 42",
    )
    db_session.add(note)
    await db_session.commit()

    artifact = Artifact(user_id=test_user.id, image_path="finds/necklace.jpg")
    db_session.add(artifact)
    await db_session.commit()
    await db_session.refresh(artifact)

    comment = ArtifactComment(
        artifact_id=artifact.id,
        user_id=test_user.id,
        body="Found near the north wall.",
    )
    db_session.add(comment)
    await db_session.commit()

    response = await client.delete("/api/v1/auth/me", headers=auth_headers)
    assert response.status_code == 204

    remaining_folders = await db_session.execute(
        select(Folder).where(Folder.user_id == test_user.id)
    )
    remaining_notes = await db_session.execute(
        select(Note).where(Note.user_id == test_user.id)
    )
    remaining_artifacts = await db_session.execute(
        select(Artifact).where(Artifact.user_id == test_user.id)
    )
    remaining_comments = await db_session.execute(
        select(ArtifactComment).where(ArtifactComment.user_id == test_user.id)
    )
    assert remaining_folders.scalar_one_or_none() is None
    assert remaining_notes.scalar_one_or_none() is None
    assert remaining_artifacts.scalar_one_or_none() is None
    assert remaining_comments.scalar_one_or_none() is None
