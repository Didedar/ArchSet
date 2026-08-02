"""Dig-site membership endpoints.

Only the owner changes the roster -- that is the one thing separating an owner
from a member, since there are no other roles by design.
"""

from datetime import datetime

import pytest
from httpx import AsyncClient

from app.models.folder import Folder
from app.models.membership import FolderMember
from app.models.note import Note


def _folder(folder_id: str, owner_id: str) -> Folder:
    return Folder(
        id=folder_id,
        user_id=owner_id,
        name="Раскоп 3",
        color="#E8B731",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        is_deleted=False,
    )


@pytest.mark.asyncio
async def test_the_owner_can_invite_by_email(
    client: AsyncClient, db_session, test_user, other_user, auth_headers
):
    db_session.add(_folder("f1", test_user.id))
    await db_session.commit()

    response = await client.post(
        "/api/v1/folders/f1/members",
        json={"email": other_user.email},
        headers=auth_headers,
    )

    assert response.status_code == 201
    assert response.json()["email"] == other_user.email


@pytest.mark.asyncio
async def test_a_member_cannot_invite_others(
    client: AsyncClient, db_session, test_user, other_user, auth_headers
):
    """Growing the team is the owner's call alone."""
    db_session.add(_folder("f1", other_user.id))
    db_session.add(FolderMember(folder_id="f1", user_id=test_user.id))
    await db_session.commit()

    response = await client.post(
        "/api/v1/folders/f1/members",
        json={"email": "someone@example.com"},
        headers=auth_headers,
    )

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_inviting_an_unknown_email_is_a_clear_404(
    client: AsyncClient, db_session, test_user, auth_headers
):
    db_session.add(_folder("f1", test_user.id))
    await db_session.commit()

    response = await client.post(
        "/api/v1/folders/f1/members",
        json={"email": "nobody@example.com"},
        headers=auth_headers,
    )

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_inviting_twice_is_idempotent(
    client: AsyncClient, db_session, test_user, other_user, auth_headers
):
    """A double tap in a tent with bad signal must not create two rows or an
    error the UI has to explain."""
    db_session.add(_folder("f1", test_user.id))
    await db_session.commit()
    body = {"email": other_user.email}

    first = await client.post(
        "/api/v1/folders/f1/members", json=body, headers=auth_headers
    )
    second = await client.post(
        "/api/v1/folders/f1/members", json=body, headers=auth_headers
    )

    assert first.status_code == 201
    assert second.status_code == 201
    listed = await client.get("/api/v1/folders/f1/members", headers=auth_headers)
    assert len(listed.json()) == 1


@pytest.mark.asyncio
async def test_a_stranger_cannot_list_members(
    client: AsyncClient, db_session, test_user, other_user, auth_headers
):
    db_session.add(_folder("f1", other_user.id))
    await db_session.commit()

    response = await client.get("/api/v1/folders/f1/members", headers=auth_headers)

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_revoking_access_leaves_the_members_notes_untouched(
    client: AsyncClient, db_session, test_user, other_user, auth_headers
):
    """Spec section 4. Losing access must never destroy what someone wrote."""
    db_session.add(_folder("f1", test_user.id))
    db_session.add(FolderMember(folder_id="f1", user_id=other_user.id))
    db_session.add(
        Note(
            id="n1",
            user_id=other_user.id,
            folder_id="f1",
            title="Слой 2",
            content="their work",
            date=datetime.utcnow(),
            updated_at=datetime.utcnow(),
            is_deleted=False,
        )
    )
    await db_session.commit()

    response = await client.delete(
        f"/api/v1/folders/f1/members/{other_user.id}", headers=auth_headers
    )

    assert response.status_code == 204
    note = await db_session.get(Note, "n1")
    assert note is not None, "revoking access must never delete a note"
    assert note.content == "their work"


@pytest.mark.asyncio
async def test_a_revoked_member_stops_receiving_the_folder(
    client: AsyncClient, db_session, test_user, other_user, auth_headers,
    other_auth_headers
):
    """The access rule and the roster must agree: removing the row is what
    actually stops the data flowing."""
    db_session.add(_folder("f1", test_user.id))
    db_session.add(FolderMember(folder_id="f1", user_id=other_user.id))
    await db_session.commit()

    before = await client.post(
        "/api/v1/sync",
        json={"notes": [], "folders": [], "last_sync_at": None},
        headers=other_auth_headers,
    )
    assert [f["id"] for f in before.json()["folders"]] == ["f1"]

    await client.delete(
        f"/api/v1/folders/f1/members/{other_user.id}", headers=auth_headers
    )

    after = await client.post(
        "/api/v1/sync",
        json={"notes": [], "folders": [], "last_sync_at": None},
        headers=other_auth_headers,
    )
    assert [f["id"] for f in after.json()["folders"]] == []
