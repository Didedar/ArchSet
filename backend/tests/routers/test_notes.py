"""Tests for /api/v1/notes: CRUD, soft/hard delete, and per-user isolation."""

import pytest
from httpx import AsyncClient

from app.models.note import Note
from app.models.user import User


@pytest.mark.asyncio
async def test_create_note_returns_the_created_note(client: AsyncClient, auth_headers: dict):
    response = await client.post(
        "/api/v1/notes",
        json={"title": "Test dig", "content": "Found pottery shards."},
        headers=auth_headers,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Test dig"
    assert body["content"] == "Found pottery shards."
    assert body["is_deleted"] is False
    assert "id" in body


@pytest.mark.asyncio
async def test_create_note_honors_a_client_supplied_id(client: AsyncClient, auth_headers: dict):
    response = await client.post(
        "/api/v1/notes",
        json={"id": "client-generated-id", "title": "Offline note"},
        headers=auth_headers,
    )

    assert response.status_code == 201
    assert response.json()["id"] == "client-generated-id"


@pytest.mark.asyncio
async def test_create_note_requires_auth(client: AsyncClient):
    response = await client.post("/api/v1/notes", json={"title": "No auth"})

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_list_notes_returns_only_the_current_users_notes(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict
):
    await client.post("/api/v1/notes", json={"title": "Mine"}, headers=auth_headers)
    await client.post("/api/v1/notes", json={"title": "Theirs"}, headers=other_auth_headers)

    response = await client.get("/api/v1/notes", headers=auth_headers)

    assert response.status_code == 200
    titles = [note["title"] for note in response.json()]
    assert titles == ["Mine"]


@pytest.mark.asyncio
async def test_list_notes_excludes_soft_deleted_by_default(
    client: AsyncClient, auth_headers: dict
):
    create = await client.post("/api/v1/notes", json={"title": "Deleted"}, headers=auth_headers)
    note_id = create.json()["id"]
    await client.delete(f"/api/v1/notes/{note_id}", headers=auth_headers)

    response = await client.get("/api/v1/notes", headers=auth_headers)

    assert response.json() == []


@pytest.mark.asyncio
async def test_list_notes_include_deleted_shows_soft_deleted_notes(
    client: AsyncClient, auth_headers: dict
):
    create = await client.post("/api/v1/notes", json={"title": "Deleted"}, headers=auth_headers)
    note_id = create.json()["id"]
    await client.delete(f"/api/v1/notes/{note_id}", headers=auth_headers)

    response = await client.get("/api/v1/notes?include_deleted=true", headers=auth_headers)

    assert len(response.json()) == 1
    assert response.json()[0]["is_deleted"] is True


@pytest.mark.asyncio
async def test_list_notes_filters_by_folder_id(client: AsyncClient, auth_headers: dict):
    folder = await client.post("/api/v1/folders", json={"name": "Trench A"}, headers=auth_headers)
    folder_id = folder.json()["id"]
    await client.post(
        "/api/v1/notes",
        json={"title": "In folder", "folder_id": folder_id},
        headers=auth_headers,
    )
    await client.post("/api/v1/notes", json={"title": "Uncategorized"}, headers=auth_headers)

    response = await client.get(f"/api/v1/notes?folder_id={folder_id}", headers=auth_headers)

    assert [n["title"] for n in response.json()] == ["In folder"]


@pytest.mark.asyncio
async def test_get_note_returns_404_for_missing_note(client: AsyncClient, auth_headers: dict):
    response = await client.get("/api/v1/notes/does-not-exist", headers=auth_headers)

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_get_note_returns_404_for_another_users_note(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict
):
    create = await client.post(
        "/api/v1/notes", json={"title": "Private"}, headers=other_auth_headers
    )
    note_id = create.json()["id"]

    response = await client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_note_changes_only_provided_fields(client: AsyncClient, auth_headers: dict):
    create = await client.post(
        "/api/v1/notes",
        json={"title": "Original", "content": "Original content"},
        headers=auth_headers,
    )
    note_id = create.json()["id"]

    response = await client.put(
        f"/api/v1/notes/{note_id}",
        json={"title": "Updated"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["title"] == "Updated"
    assert body["content"] == "Original content"


@pytest.mark.asyncio
async def test_update_note_returns_404_for_missing_note(client: AsyncClient, auth_headers: dict):
    response = await client.put(
        "/api/v1/notes/does-not-exist",
        json={"title": "Updated"},
        headers=auth_headers,
    )

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_delete_note_soft_deletes_by_default(client: AsyncClient, auth_headers: dict):
    create = await client.post("/api/v1/notes", json={"title": "To delete"}, headers=auth_headers)
    note_id = create.json()["id"]

    response = await client.delete(f"/api/v1/notes/{note_id}", headers=auth_headers)
    assert response.status_code == 204

    get_response = await client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)
    assert get_response.json()["is_deleted"] is True


@pytest.mark.asyncio
async def test_delete_note_hard_delete_removes_the_row(
    client: AsyncClient, auth_headers: dict, db_session
):
    create = await client.post("/api/v1/notes", json={"title": "To purge"}, headers=auth_headers)
    note_id = create.json()["id"]

    response = await client.delete(
        f"/api/v1/notes/{note_id}?hard_delete=true", headers=auth_headers
    )
    assert response.status_code == 204

    from sqlalchemy import select

    result = await db_session.execute(select(Note).where(Note.id == note_id))
    assert result.scalar_one_or_none() is None


@pytest.mark.asyncio
async def test_delete_note_returns_404_for_another_users_note(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict
):
    create = await client.post(
        "/api/v1/notes", json={"title": "Private"}, headers=other_auth_headers
    )
    note_id = create.json()["id"]

    response = await client.delete(f"/api/v1/notes/{note_id}", headers=auth_headers)

    assert response.status_code == 404
