"""Tests for the artifact half of POST /api/v1/sync.

Artifacts are geotagged archaeology photos; their binaries stay on the
device, so only metadata (path, GPS, Gemini analysis JSON) round-trips
through this endpoint, alongside free-text user comments.

There is no GET /artifacts route, so assertions read state back through
the sync response itself: a sync with no `last_sync_at` returns every
server-side row for the caller.
"""

from datetime import datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.artifact import Artifact, ArtifactComment
from app.models.note import Note
from app.models.user import User


def _artifact_item(
    artifact_id: str,
    note_id: str | None = None,
    image_path: str = "/local/photos/sherd.jpg",
    latitude: float | None = 41.3111,
    longitude: float | None = 69.2797,
    analysis_result: str | None = None,
    captured_at: datetime | None = None,
    updated_at: datetime | None = None,
    is_deleted: bool = False,
):
    timestamp = updated_at or datetime.utcnow()
    return {
        "id": artifact_id,
        "note_id": note_id,
        "image_path": image_path,
        "latitude": latitude,
        "longitude": longitude,
        "analysis_result": analysis_result,
        "captured_at": (captured_at or timestamp).isoformat(),
        "updated_at": timestamp.isoformat(),
        "is_deleted": is_deleted,
    }


def _comment_item(
    comment_id: str,
    artifact_id: str,
    body: str = "Wheel-thrown, likely 11th century.",
    created_at: datetime | None = None,
    updated_at: datetime | None = None,
    is_deleted: bool = False,
):
    timestamp = updated_at or datetime.utcnow()
    return {
        "id": comment_id,
        "artifact_id": artifact_id,
        "body": body,
        "created_at": (created_at or timestamp).isoformat(),
        "updated_at": timestamp.isoformat(),
        "is_deleted": is_deleted,
    }


async def _pull(client: AsyncClient, headers: dict) -> dict:
    """Re-sync with an empty payload to read back everything the server holds."""
    response = await client.post("/api/v1/sync", json={}, headers=headers)
    assert response.status_code == 200
    return response.json()


# --------------------------------------------------------------------------
# Backward compatibility
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_without_any_artifact_keys_still_succeeds(
    client: AsyncClient, auth_headers: dict
):
    """Hard requirement: clients predating artifacts send only notes/folders.

    Both new request fields must be optional, and both new response fields
    must still be present (empty) so the shape stays predictable.
    """
    response = await client.post(
        "/api/v1/sync", json={"notes": [], "folders": []}, headers=auth_headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["artifacts"] == []
    assert body["artifact_comments"] == []


@pytest.mark.asyncio
async def test_sync_with_a_completely_empty_body_succeeds(
    client: AsyncClient, auth_headers: dict
):
    response = await client.post("/api/v1/sync", json={}, headers=auth_headers)

    assert response.status_code == 200
    assert response.json()["artifacts"] == []


# --------------------------------------------------------------------------
# Upload / persistence
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_persists_a_new_artifact_and_its_comment(
    client: AsyncClient, auth_headers: dict
):
    """A comment may reference an artifact uploaded in the *same* request --
    the router syncs artifacts before comments precisely so this resolves.
    """
    response = await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [_artifact_item("artifact-1")],
            "artifact_comments": [_comment_item("comment-1", "artifact-1")],
        },
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert [a["id"] for a in body["artifacts"]] == ["artifact-1"]
    assert [c["id"] for c in body["artifact_comments"]] == ["comment-1"]

    # And they survive the request, rather than only echoing back.
    persisted = await _pull(client, auth_headers)
    assert [a["id"] for a in persisted["artifacts"]] == ["artifact-1"]
    assert [c["id"] for c in persisted["artifact_comments"]] == ["comment-1"]


@pytest.mark.asyncio
async def test_sync_round_trips_every_artifact_metadata_field(
    client: AsyncClient, auth_headers: dict
):
    captured_at = datetime(2026, 5, 4, 9, 30, 0)
    analysis = '{"material": "ceramic", "confidence": 0.87}'

    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item(
                    "artifact-full",
                    image_path="/local/photos/full.jpg",
                    latitude=39.6547,
                    longitude=66.9597,
                    analysis_result=analysis,
                    captured_at=captured_at,
                )
            ]
        },
        headers=auth_headers,
    )

    artifact = (await _pull(client, auth_headers))["artifacts"][0]
    assert artifact["image_path"] == "/local/photos/full.jpg"
    assert artifact["latitude"] == pytest.approx(39.6547)
    assert artifact["longitude"] == pytest.approx(66.9597)
    assert artifact["analysis_result"] == analysis
    assert datetime.fromisoformat(artifact["captured_at"]) == captured_at
    # created_at is server-assigned and only exists on the response side.
    assert artifact["created_at"] is not None


@pytest.mark.asyncio
async def test_sync_accepts_an_artifact_without_coordinates_or_analysis(
    client: AsyncClient, auth_headers: dict
):
    """GPS may be unavailable and analysis may not have run yet."""
    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item(
                    "artifact-bare", latitude=None, longitude=None, analysis_result=None
                )
            ]
        },
        headers=auth_headers,
    )

    artifact = (await _pull(client, auth_headers))["artifacts"][0]
    assert artifact["latitude"] is None
    assert artifact["longitude"] is None
    assert artifact["analysis_result"] is None


@pytest.mark.asyncio
async def test_sync_drops_a_new_artifact_that_is_already_deleted(
    client: AsyncClient, auth_headers: dict
):
    """Mirrors notes/folders: no point materialising a tombstone row for
    something the server never had.
    """
    await client.post(
        "/api/v1/sync",
        json={"artifacts": [_artifact_item("ghost-artifact", is_deleted=True)]},
        headers=auth_headers,
    )

    assert (await _pull(client, auth_headers))["artifacts"] == []


@pytest.mark.asyncio
async def test_sync_drops_a_new_comment_that_is_already_deleted(
    client: AsyncClient, auth_headers: dict
):
    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [_artifact_item("artifact-1")],
            "artifact_comments": [
                _comment_item("ghost-comment", "artifact-1", is_deleted=True)
            ],
        },
        headers=auth_headers,
    )

    assert (await _pull(client, auth_headers))["artifact_comments"] == []


# --------------------------------------------------------------------------
# Last-write-wins conflict resolution
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_updates_an_artifact_when_client_version_is_newer(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/old.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item(
                    "artifact-1",
                    image_path="/client/new.jpg",
                    updated_at=now + timedelta(hours=1),
                )
            ]
        },
        headers=auth_headers,
    )

    artifact = (await _pull(client, auth_headers))["artifacts"][0]
    assert artifact["image_path"] == "/client/new.jpg"


@pytest.mark.asyncio
async def test_sync_ignores_an_artifact_when_client_version_is_older(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    """Last-write-wins: a stale client write loses silently, no error."""
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/authoritative.jpg",
            latitude=1.0,
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    response = await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item(
                    "artifact-1",
                    image_path="/client/stale.jpg",
                    latitude=99.0,
                    updated_at=now - timedelta(hours=1),
                )
            ]
        },
        headers=auth_headers,
    )

    assert response.status_code == 200
    artifact = (await _pull(client, auth_headers))["artifacts"][0]
    assert artifact["image_path"] == "/server/authoritative.jpg"
    assert artifact["latitude"] == pytest.approx(1.0)


@pytest.mark.asyncio
async def test_sync_ignores_an_artifact_whose_updated_at_exactly_matches(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    """The comparison is strictly greater-than, so an identical timestamp
    is treated as "already synced" rather than as a new write.
    """
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/original.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item("artifact-1", image_path="/client/same-time.jpg", updated_at=now)
            ]
        },
        headers=auth_headers,
    )

    artifact = (await _pull(client, auth_headers))["artifacts"][0]
    assert artifact["image_path"] == "/server/original.jpg"


@pytest.mark.asyncio
async def test_sync_ignores_a_comment_when_client_version_is_older(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    db_session.add(
        ArtifactComment(
            id="comment-1",
            artifact_id="artifact-1",
            user_id=test_user.id,
            body="Server body",
            created_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    await client.post(
        "/api/v1/sync",
        json={
            "artifact_comments": [
                _comment_item(
                    "comment-1",
                    "artifact-1",
                    body="Stale body",
                    updated_at=now - timedelta(hours=1),
                )
            ]
        },
        headers=auth_headers,
    )

    comment = (await _pull(client, auth_headers))["artifact_comments"][0]
    assert comment["body"] == "Server body"


@pytest.mark.asyncio
async def test_sync_updates_a_comment_when_client_version_is_newer(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    db_session.add(
        ArtifactComment(
            id="comment-1",
            artifact_id="artifact-1",
            user_id=test_user.id,
            body="Server body",
            created_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    await client.post(
        "/api/v1/sync",
        json={
            "artifact_comments": [
                _comment_item(
                    "comment-1",
                    "artifact-1",
                    body="Corrected body",
                    updated_at=now + timedelta(hours=1),
                )
            ]
        },
        headers=auth_headers,
    )

    comment = (await _pull(client, auth_headers))["artifact_comments"][0]
    assert comment["body"] == "Corrected body"


# --------------------------------------------------------------------------
# Soft deletes
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_marking_an_artifact_deleted_soft_deletes_it_on_the_server(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item("artifact-1", updated_at=now + timedelta(hours=1), is_deleted=True)
            ]
        },
        headers=auth_headers,
    )

    # Soft delete: the row is still returned so other devices learn about it.
    artifact = (await _pull(client, auth_headers))["artifacts"][0]
    assert artifact["id"] == "artifact-1"
    assert artifact["is_deleted"] is True


@pytest.mark.asyncio
async def test_sync_marking_a_comment_deleted_soft_deletes_it_on_the_server(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    db_session.add(
        ArtifactComment(
            id="comment-1",
            artifact_id="artifact-1",
            user_id=test_user.id,
            body="To retract",
            created_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    await client.post(
        "/api/v1/sync",
        json={
            "artifact_comments": [
                _comment_item(
                    "comment-1", "artifact-1", updated_at=now + timedelta(hours=1), is_deleted=True
                )
            ]
        },
        headers=auth_headers,
    )

    comment = (await _pull(client, auth_headers))["artifact_comments"][0]
    assert comment["is_deleted"] is True


# --------------------------------------------------------------------------
# Dangling references
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_artifact_referencing_an_unknown_note_is_stored_unattached(
    client: AsyncClient, auth_headers: dict
):
    """A dangling note_id must degrade to NULL, not blow up the insert with
    a foreign-key violation that would fail the entire sync.
    """
    response = await client.post(
        "/api/v1/sync",
        json={"artifacts": [_artifact_item("artifact-1", note_id="no-such-note")]},
        headers=auth_headers,
    )

    assert response.status_code == 200
    artifact = response.json()["artifacts"][0]
    assert artifact["id"] == "artifact-1"
    assert artifact["note_id"] is None


@pytest.mark.asyncio
async def test_sync_artifact_keeps_note_id_when_the_note_arrives_in_the_same_request(
    client: AsyncClient, auth_headers: dict
):
    """Notes are synced before artifacts, so a note created in this very
    payload is already resolvable by the time the artifact is written.
    """
    now = datetime.utcnow()
    response = await client.post(
        "/api/v1/sync",
        json={
            "notes": [
                {
                    "id": "note-1",
                    "title": "Trench B",
                    "content": "",
                    "date": now.isoformat(),
                    "updated_at": now.isoformat(),
                    "is_deleted": False,
                }
            ],
            "artifacts": [_artifact_item("artifact-1", note_id="note-1")],
        },
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["artifacts"][0]["note_id"] == "note-1"


@pytest.mark.asyncio
async def test_sync_artifact_referencing_another_users_note_is_stored_unattached(
    client: AsyncClient, auth_headers: dict, other_user: User, db_session: AsyncSession
):
    """The note exists, but not for this caller -- treated the same as a
    dangling reference so one user can never attach to another's note.
    """
    db_session.add(Note(id="foreign-note", user_id=other_user.id, title="Theirs"))
    await db_session.commit()

    response = await client.post(
        "/api/v1/sync",
        json={"artifacts": [_artifact_item("artifact-1", note_id="foreign-note")]},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["artifacts"][0]["note_id"] is None


@pytest.mark.asyncio
async def test_sync_updating_an_artifact_with_an_unknown_note_id_clears_the_link(
    client: AsyncClient, auth_headers: dict, test_user: User, db_session: AsyncSession
):
    now = datetime.utcnow()
    db_session.add(Note(id="note-1", user_id=test_user.id, title="Trench B"))
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            note_id="note-1",
            image_path="/server/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    response = await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item(
                    "artifact-1", note_id="vanished-note", updated_at=now + timedelta(hours=1)
                )
            ]
        },
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["artifacts"][0]["note_id"] is None


@pytest.mark.asyncio
async def test_sync_comment_for_an_unknown_artifact_is_skipped_without_failing(
    client: AsyncClient, auth_headers: dict
):
    """One unresolvable comment must not take the whole sync down -- the
    rest of the payload still lands.
    """
    response = await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [_artifact_item("artifact-1")],
            "artifact_comments": [
                _comment_item("orphan-comment", "no-such-artifact"),
                _comment_item("good-comment", "artifact-1"),
            ],
        },
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert [c["id"] for c in body["artifact_comments"]] == ["good-comment"]
    assert [a["id"] for a in body["artifacts"]] == ["artifact-1"]


@pytest.mark.asyncio
async def test_sync_comment_for_another_users_artifact_is_skipped(
    client: AsyncClient, auth_headers: dict, other_user: User, db_session: AsyncSession
):
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="foreign-artifact",
            user_id=other_user.id,
            image_path="/theirs/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    response = await client.post(
        "/api/v1/sync",
        json={"artifact_comments": [_comment_item("comment-1", "foreign-artifact")]},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["artifact_comments"] == []


# --------------------------------------------------------------------------
# Incremental pull
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_omits_artifacts_unchanged_since_last_sync(
    client: AsyncClient, auth_headers: dict
):
    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [_artifact_item("artifact-1")],
            "artifact_comments": [_comment_item("comment-1", "artifact-1")],
        },
        headers=auth_headers,
    )
    future_cutoff = (datetime.utcnow() + timedelta(days=1)).isoformat()

    response = await client.post(
        "/api/v1/sync", json={"last_sync_at": future_cutoff}, headers=auth_headers
    )

    assert response.json()["artifacts"] == []
    assert response.json()["artifact_comments"] == []


@pytest.mark.asyncio
async def test_sync_returns_artifacts_changed_since_last_sync(
    client: AsyncClient, auth_headers: dict
):
    past_cutoff = (datetime.utcnow() - timedelta(days=1)).isoformat()

    response = await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [_artifact_item("artifact-1")],
            "artifact_comments": [_comment_item("comment-1", "artifact-1")],
            "last_sync_at": past_cutoff,
        },
        headers=auth_headers,
    )

    assert [a["id"] for a in response.json()["artifacts"]] == ["artifact-1"]
    assert [c["id"] for c in response.json()["artifact_comments"]] == ["comment-1"]


# --------------------------------------------------------------------------
# User isolation
# --------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_never_returns_another_users_artifacts_or_comments(
    client: AsyncClient,
    auth_headers: dict,
    other_auth_headers: dict,
):
    await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [_artifact_item("owner-artifact")],
            "artifact_comments": [_comment_item("owner-comment", "owner-artifact")],
        },
        headers=auth_headers,
    )

    intruder = await _pull(client, other_auth_headers)

    assert intruder["artifacts"] == []
    assert intruder["artifact_comments"] == []


@pytest.mark.asyncio
async def test_sync_with_another_users_artifact_id_is_skipped_not_crashed(
    client: AsyncClient,
    auth_headers: dict,
    other_auth_headers: dict,
    other_user: User,
    db_session: AsyncSession,
):
    """An artifact id the caller may not touch is ignored, and the sync succeeds.

    This previously pinned the opposite -- an unhandled IntegrityError -- and
    called it a robustness gap in its own docstring. Sharing turned the gap
    into a real failure: a member keeps someone else's finds in their local
    copy, and after access is revoked every sync died on the primary key,
    taking the person's own unrelated notes and photos down with it.

    What is NOT being changed is the security property: the other user's row
    is still never read or overwritten. Only the failure mode is -- skipped
    instead of crashing the whole batch. Notes and folders were fixed first;
    this brings artifacts into line.
    """
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="victim-artifact",
            user_id=other_user.id,
            image_path="/theirs/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    response = await client.post(
        "/api/v1/sync",
        json={
            "artifacts": [
                _artifact_item(
                    "victim-artifact",
                    image_path="/hijacked.jpg",
                    updated_at=now + timedelta(hours=1),
                )
            ]
        },
        headers=auth_headers,
    )

    assert response.status_code == 200, response.text
    assert response.json()["artifacts"] == [], "it must not be handed back either"

    victim = await db_session.get(Artifact, "victim-artifact")
    await db_session.refresh(victim)
    assert victim.user_id == other_user.id
    assert victim.image_path == "/theirs/photo.jpg", "never overwritten"
