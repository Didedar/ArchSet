"""Tests for /api/v1/folders: CRUD, soft/hard delete, and note reassignment."""

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.folder import Folder


@pytest.mark.asyncio
async def test_create_folder_returns_the_created_folder(client: AsyncClient, auth_headers: dict):
    response = await client.post(
        "/api/v1/folders", json={"name": "Trench A"}, headers=auth_headers
    )

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Trench A"
    assert body["color"] == "#E8B731"
    assert body["is_deleted"] is False


@pytest.mark.asyncio
async def test_create_folder_honors_a_client_supplied_id_and_color(
    client: AsyncClient, auth_headers: dict
):
    response = await client.post(
        "/api/v1/folders",
        json={"id": "client-id", "name": "Trench B", "color": "#FF0000"},
        headers=auth_headers,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["id"] == "client-id"
    assert body["color"] == "#FF0000"


@pytest.mark.asyncio
async def test_create_folder_requires_auth(client: AsyncClient):
    response = await client.post("/api/v1/folders", json={"name": "No auth"})

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_folder_requires_a_name(client: AsyncClient, auth_headers: dict):
    response = await client.post("/api/v1/folders", json={}, headers=auth_headers)

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_list_folders_returns_only_the_current_users_folders(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict
):
    await client.post("/api/v1/folders", json={"name": "Mine"}, headers=auth_headers)
    await client.post("/api/v1/folders", json={"name": "Theirs"}, headers=other_auth_headers)

    response = await client.get("/api/v1/folders", headers=auth_headers)

    assert [f["name"] for f in response.json()] == ["Mine"]


@pytest.mark.asyncio
async def test_list_folders_excludes_soft_deleted_by_default(
    client: AsyncClient, auth_headers: dict
):
    create = await client.post("/api/v1/folders", json={"name": "Deleted"}, headers=auth_headers)
    folder_id = create.json()["id"]
    await client.delete(f"/api/v1/folders/{folder_id}", headers=auth_headers)

    response = await client.get("/api/v1/folders", headers=auth_headers)

    assert response.json() == []


@pytest.mark.asyncio
async def test_list_folders_include_deleted_shows_soft_deleted_folders(
    client: AsyncClient, auth_headers: dict
):
    create = await client.post("/api/v1/folders", json={"name": "Deleted"}, headers=auth_headers)
    folder_id = create.json()["id"]
    await client.delete(f"/api/v1/folders/{folder_id}", headers=auth_headers)

    response = await client.get("/api/v1/folders?include_deleted=true", headers=auth_headers)

    assert len(response.json()) == 1
    assert response.json()[0]["is_deleted"] is True


@pytest.mark.asyncio
async def test_get_folder_returns_404_for_missing_folder(client: AsyncClient, auth_headers: dict):
    response = await client.get("/api/v1/folders/does-not-exist", headers=auth_headers)

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_get_folder_returns_404_for_another_users_folder(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict
):
    create = await client.post(
        "/api/v1/folders", json={"name": "Private"}, headers=other_auth_headers
    )
    folder_id = create.json()["id"]

    response = await client.get(f"/api/v1/folders/{folder_id}", headers=auth_headers)

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_folder_changes_only_provided_fields(
    client: AsyncClient, auth_headers: dict
):
    create = await client.post(
        "/api/v1/folders",
        json={"name": "Original", "color": "#111111"},
        headers=auth_headers,
    )
    folder_id = create.json()["id"]

    response = await client.put(
        f"/api/v1/folders/{folder_id}", json={"name": "Renamed"}, headers=auth_headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Renamed"
    assert body["color"] == "#111111"


@pytest.mark.asyncio
async def test_update_folder_returns_404_for_missing_folder(
    client: AsyncClient, auth_headers: dict
):
    response = await client.put(
        "/api/v1/folders/does-not-exist", json={"name": "Renamed"}, headers=auth_headers
    )

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_delete_folder_soft_deletes_by_default(client: AsyncClient, auth_headers: dict):
    create = await client.post("/api/v1/folders", json={"name": "To delete"}, headers=auth_headers)
    folder_id = create.json()["id"]

    response = await client.delete(f"/api/v1/folders/{folder_id}", headers=auth_headers)
    assert response.status_code == 204

    get_response = await client.get(f"/api/v1/folders/{folder_id}", headers=auth_headers)
    assert get_response.json()["is_deleted"] is True


@pytest.mark.asyncio
async def test_delete_folder_hard_delete_removes_the_row(
    client: AsyncClient, auth_headers: dict, db_session
):
    create = await client.post("/api/v1/folders", json={"name": "To purge"}, headers=auth_headers)
    folder_id = create.json()["id"]

    response = await client.delete(
        f"/api/v1/folders/{folder_id}?hard_delete=true", headers=auth_headers
    )
    assert response.status_code == 204

    result = await db_session.execute(select(Folder).where(Folder.id == folder_id))
    assert result.scalar_one_or_none() is None


@pytest.mark.asyncio
async def test_delete_folder_reassigns_its_notes_to_all_notes(
    client: AsyncClient, auth_headers: dict
):
    folder = await client.post("/api/v1/folders", json={"name": "Trench A"}, headers=auth_headers)
    folder_id = folder.json()["id"]
    note = await client.post(
        "/api/v1/notes",
        json={"title": "In folder", "folder_id": folder_id},
        headers=auth_headers,
    )
    note_id = note.json()["id"]

    response = await client.delete(f"/api/v1/folders/{folder_id}", headers=auth_headers)
    assert response.status_code == 204

    get_note = await client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)
    assert get_note.json()["folder_id"] is None


@pytest.mark.asyncio
async def test_delete_folder_returns_404_for_another_users_folder(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict
):
    create = await client.post(
        "/api/v1/folders", json={"name": "Private"}, headers=other_auth_headers
    )
    folder_id = create.json()["id"]

    response = await client.delete(f"/api/v1/folders/{folder_id}", headers=auth_headers)

    assert response.status_code == 404
