"""Tests for POST /api/v1/sync: bidirectional last-write-wins sync."""

from datetime import datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy.exc import IntegrityError


def _note_item(
    note_id: str,
    title: str = "Note",
    content: str = "Content",
    updated_at: datetime | None = None,
    is_deleted: bool = False,
):
    return {
        "id": note_id,
        "title": title,
        "content": content,
        "date": (updated_at or datetime.utcnow()).isoformat(),
        "updated_at": (updated_at or datetime.utcnow()).isoformat(),
        "is_deleted": is_deleted,
    }


def _folder_item(
    folder_id: str,
    name: str = "Folder",
    updated_at: datetime | None = None,
    is_deleted: bool = False,
):
    return {
        "id": folder_id,
        "name": name,
        "color": "#E8B731",
        "updated_at": (updated_at or datetime.utcnow()).isoformat(),
        "is_deleted": is_deleted,
    }


@pytest.mark.asyncio
async def test_sync_requires_auth(client: AsyncClient):
    response = await client.post("/api/v1/sync", json={"notes": [], "folders": []})

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_sync_creates_a_brand_new_client_note(client: AsyncClient, auth_headers: dict):
    response = await client.post(
        "/api/v1/sync",
        json={"notes": [_note_item("new-note")], "folders": []},
        headers=auth_headers,
    )

    assert response.status_code == 200
    list_response = await client.get("/api/v1/notes", headers=auth_headers)
    assert [n["id"] for n in list_response.json()] == ["new-note"]


@pytest.mark.asyncio
async def test_sync_drops_a_new_note_that_is_already_deleted(
    client: AsyncClient, auth_headers: dict
):
    """A client note that's brand new to the server AND already marked
    deleted is silently dropped rather than created -- there's no point
    creating a row just to represent a tombstone for something the server
    never had.
    """
    response = await client.post(
        "/api/v1/sync",
        json={"notes": [_note_item("ghost-note", is_deleted=True)], "folders": []},
        headers=auth_headers,
    )

    assert response.status_code == 200
    list_response = await client.get("/api/v1/notes?include_deleted=true", headers=auth_headers)
    assert list_response.json() == []


@pytest.mark.asyncio
async def test_sync_updates_an_existing_note_when_client_version_is_newer(
    client: AsyncClient, auth_headers: dict
):
    create = await client.post(
        "/api/v1/notes", json={"title": "Old title"}, headers=auth_headers
    )
    note_id = create.json()["id"]
    server_updated_at = datetime.fromisoformat(create.json()["updated_at"])
    newer = server_updated_at + timedelta(hours=1)

    await client.post(
        "/api/v1/sync",
        json={
            "notes": [_note_item(note_id, title="New title", updated_at=newer)],
            "folders": [],
        },
        headers=auth_headers,
    )

    get_response = await client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)
    assert get_response.json()["title"] == "New title"


@pytest.mark.asyncio
async def test_sync_ignores_an_existing_note_when_client_version_is_not_newer(
    client: AsyncClient, auth_headers: dict
):
    """Last-write-wins: a client update with an equal-or-older updated_at
    than what the server already has loses silently, no error returned.
    """
    create = await client.post(
        "/api/v1/notes", json={"title": "Server title"}, headers=auth_headers
    )
    note_id = create.json()["id"]
    server_updated_at = datetime.fromisoformat(create.json()["updated_at"])
    older = server_updated_at - timedelta(hours=1)

    response = await client.post(
        "/api/v1/sync",
        json={
            "notes": [_note_item(note_id, title="Stale title", updated_at=older)],
            "folders": [],
        },
        headers=auth_headers,
    )

    assert response.status_code == 200
    get_response = await client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)
    assert get_response.json()["title"] == "Server title"


@pytest.mark.asyncio
async def test_sync_marking_a_note_deleted_soft_deletes_it_on_the_server(
    client: AsyncClient, auth_headers: dict
):
    create = await client.post("/api/v1/notes", json={"title": "To delete"}, headers=auth_headers)
    note_id = create.json()["id"]
    server_updated_at = datetime.fromisoformat(create.json()["updated_at"])
    newer = server_updated_at + timedelta(hours=1)

    await client.post(
        "/api/v1/sync",
        json={
            "notes": [_note_item(note_id, updated_at=newer, is_deleted=True)],
            "folders": [],
        },
        headers=auth_headers,
    )

    get_response = await client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)
    assert get_response.json()["is_deleted"] is True


@pytest.mark.asyncio
async def test_sync_returns_server_notes_changed_since_last_sync(
    client: AsyncClient, auth_headers: dict
):
    await client.post("/api/v1/notes", json={"title": "Existing"}, headers=auth_headers)
    future_cutoff = (datetime.utcnow() + timedelta(days=1)).isoformat()

    response = await client.post(
        "/api/v1/sync",
        json={"notes": [], "folders": [], "last_sync_at": future_cutoff},
        headers=auth_headers,
    )

    assert response.json()["notes"] == []


@pytest.mark.asyncio
async def test_sync_creates_a_brand_new_client_folder(client: AsyncClient, auth_headers: dict):
    await client.post(
        "/api/v1/sync",
        json={"notes": [], "folders": [_folder_item("new-folder")]},
        headers=auth_headers,
    )

    list_response = await client.get("/api/v1/folders", headers=auth_headers)
    assert [f["id"] for f in list_response.json()] == ["new-folder"]


@pytest.mark.asyncio
async def test_sync_drops_a_new_folder_that_is_already_deleted(
    client: AsyncClient, auth_headers: dict
):
    await client.post(
        "/api/v1/sync",
        json={"notes": [], "folders": [_folder_item("ghost-folder", is_deleted=True)]},
        headers=auth_headers,
    )

    list_response = await client.get("/api/v1/folders?include_deleted=true", headers=auth_headers)
    assert list_response.json() == []


@pytest.mark.asyncio
async def test_sync_with_another_users_note_id_raises_instead_of_leaking(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict
):
    """Documents current (buggy) behavior, not desired behavior.

    sync_service.sync_notes looks up an existing note scoped to
    `Note.id == client_note.id AND Note.user_id == current_user.id`. When a
    sync payload reuses another user's note ID, that scoped lookup finds
    nothing, so the code falls into the "create new" branch and tries to
    INSERT a row whose primary key already exists (owned by someone else) --
    raising sqlalchemy.exc.IntegrityError instead of the other user's data
    ever actually being read or overwritten. Not a data leak, but an
    unhandled-crash robustness gap: flagged for a follow-up fix (e.g. skip
    silently, like the other conflict-resolution paths in this function, or
    a scoped existence check across all users) rather than fixed here, since
    it's a behavior change beyond this test suite's scope.
    """
    create = await client.post(
        "/api/v1/notes", json={"title": "Other user's note"}, headers=other_auth_headers
    )
    note_id = create.json()["id"]
    updated_at = datetime.fromisoformat(create.json()["updated_at"]) + timedelta(hours=1)

    with pytest.raises(IntegrityError, match="UNIQUE constraint failed"):
        await client.post(
            "/api/v1/sync",
            json={
                "notes": [_note_item(note_id, title="Hijacked", updated_at=updated_at)],
                "folders": [],
            },
            headers=auth_headers,
        )
