"""End-to-end audit of collaboration: two archaeologists, one dig site.

These deliberately drive the HTTP API the way the app does, rather than
calling services directly. Each unit was tested in isolation; what this file
checks is whether they compose into the feature that was actually asked for --
and whether the seams between them can be pried open.
"""

from datetime import datetime, timedelta

import pytest
from httpx import AsyncClient

from app.models.artifact import Artifact
from app.models.folder import Folder
from app.models.membership import FolderMember
from app.models.note import Note


def _note(note_id, title, updated_at, base_revision=None, folder_id=None):
    item = {
        "id": note_id,
        "title": title,
        "content": title,
        "date": updated_at.isoformat(),
        "updated_at": updated_at.isoformat(),
        "is_deleted": False,
    }
    if base_revision is not None:
        item["base_revision"] = base_revision
    if folder_id is not None:
        item["folder_id"] = folder_id
    return item


async def _sync(client, headers, notes=None, folders=None, last_sync_at=None):
    response = await client.post(
        "/api/v1/sync",
        json={
            "notes": notes or [],
            "folders": folders or [],
            "last_sync_at": last_sync_at.isoformat() if last_sync_at else None,
        },
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()


@pytest.fixture
async def shared_site(db_session, test_user, other_user):
    """Ivan owns 'Раскоп 3'; Maria is a member."""
    db_session.add(
        Folder(
            id="f-site",
            user_id=test_user.id,
            name="Раскоп 3",
            color="#E8B731",
            created_at=datetime(2026, 8, 1),
            updated_at=datetime(2026, 8, 1),
            is_deleted=False,
        )
    )
    db_session.add(FolderMember(folder_id="f-site", user_id=other_user.id))
    await db_session.commit()


class TestTwoArchaeologistsOneDigSite:
    @pytest.mark.asyncio
    async def test_a_member_can_add_entries_and_the_owner_receives_them(
        self, client: AsyncClient, db_session, shared_site,
        auth_headers, other_auth_headers
    ):
        """The whole point. Maria writes in Ivan's dig site; Ivan sees it."""
        await _sync(
            client,
            other_auth_headers,
            notes=[_note("n-maria", "Слой 2, керамика",
                         datetime(2026, 8, 2, 10), folder_id="f-site")],
        )

        body = await _sync(client, auth_headers)

        assert "n-maria" in [n["id"] for n in body["notes"]]

    @pytest.mark.asyncio
    async def test_a_member_can_edit_an_entry_the_owner_wrote(
        self, client: AsyncClient, db_session, shared_site,
        auth_headers, other_auth_headers
    ):
        """All members are editors -- there are no read-only roles."""
        await _sync(
            client,
            auth_headers,
            notes=[_note("n-ivan", "Слой 1", datetime(2026, 8, 2, 9),
                         folder_id="f-site")],
        )
        pulled = await _sync(client, other_auth_headers)
        revision = next(n for n in pulled["notes"] if n["id"] == "n-ivan")["revision"]

        await _sync(
            client,
            other_auth_headers,
            notes=[_note("n-ivan", "Слой 1, дополнено Марией",
                         datetime(2026, 8, 2, 11), base_revision=revision,
                         folder_id="f-site")],
        )

        note = await db_session.get(Note, "n-ivan")
        await db_session.refresh(note)
        assert note.title == "Слой 1, дополнено Марией"

    @pytest.mark.asyncio
    async def test_simultaneous_offline_edits_lose_nothing(
        self, client: AsyncClient, db_session, shared_site,
        auth_headers, other_auth_headers
    ):
        """The scenario the whole design exists for.

        Both edit the same entry from the same base revision while offline.
        One wins, the other is TOLD it conflicted so the client can fork --
        and crucially, Maria's later wall clock must not hand her the win.
        """
        await _sync(
            client,
            auth_headers,
            notes=[_note("n-shared", "Слой 2", datetime(2026, 8, 2, 9),
                         folder_id="f-site")],
        )
        pulled = await _sync(client, other_auth_headers)
        base = next(n for n in pulled["notes"] if n["id"] == "n-shared")["revision"]

        # Ivan syncs first from base.
        ivan = await _sync(
            client,
            auth_headers,
            notes=[_note("n-shared", "Версия Ивана", datetime(2026, 8, 2, 17),
                         base_revision=base, folder_id="f-site")],
        )
        assert ivan["conflicted_note_ids"] == []

        # Maria syncs from the SAME base, with a clock two hours ahead.
        maria = await _sync(
            client,
            other_auth_headers,
            notes=[_note("n-shared", "Версия Марии", datetime(2026, 8, 2, 19),
                         base_revision=base, folder_id="f-site")],
        )

        assert maria["conflicted_note_ids"] == ["n-shared"], (
            "Maria must be told she lost, or her client cannot fork and her "
            "work vanishes"
        )
        note = await db_session.get(Note, "n-shared")
        await db_session.refresh(note)
        assert note.title == "Версия Ивана", "a fast clock must not win"

        # The server's version must come back in the same response, or the
        # client has nothing to keep beside its fork.
        assert "n-shared" in [n["id"] for n in maria["notes"]]

    @pytest.mark.asyncio
    async def test_maria_forked_copy_reaches_ivan(
        self, client: AsyncClient, db_session, shared_site,
        auth_headers, other_auth_headers
    ):
        """After forking locally, Maria's copy is a NEW note. It must land in
        the shared site so Ivan can reconcile the two by hand."""
        await _sync(
            client,
            other_auth_headers,
            notes=[_note("n-fork", "Слой 2 (версия 19:42)",
                         datetime(2026, 8, 2, 19, 42), folder_id="f-site")],
        )

        body = await _sync(client, auth_headers)

        assert "n-fork" in [n["id"] for n in body["notes"]]


class TestSeamsThatCouldBePriedOpen:
    @pytest.mark.asyncio
    async def test_a_stranger_cannot_inject_a_note_into_someone_elses_folder(
        self, client: AsyncClient, db_session, test_user, other_user,
        other_auth_headers
    ):
        """The create path takes folder_id straight from the client.

        A folder nobody shared with Maria must not become a place she can
        deposit entries -- that would put her text in Ivan's dig site without
        any membership at all.
        """
        db_session.add(
            Folder(
                id="f-private",
                user_id=test_user.id,
                name="Личный раскоп",
                color="#E8B731",
                created_at=datetime(2026, 8, 1),
                updated_at=datetime(2026, 8, 1),
                is_deleted=False,
            )
        )
        await db_session.commit()

        await _sync(
            client,
            other_auth_headers,
            notes=[_note("n-injected", "Не должно попасть",
                         datetime(2026, 8, 2, 12), folder_id="f-private")],
        )

        note = await db_session.get(Note, "n-injected")
        if note is not None:
            await db_session.refresh(note)
            assert note.folder_id != "f-private", (
                "a note was filed into a folder the author has no access to"
            )

    @pytest.mark.asyncio
    async def test_a_revoked_member_cannot_keep_writing_to_the_site(
        self, client: AsyncClient, db_session, shared_site, test_user,
        other_user, auth_headers, other_auth_headers
    ):
        """Revocation has to stop writes, not merely hide reads."""
        await _sync(
            client,
            auth_headers,
            notes=[_note("n-site", "Слой 2", datetime(2026, 8, 2, 9),
                         folder_id="f-site")],
        )
        pulled = await _sync(client, other_auth_headers)
        base = next(n for n in pulled["notes"] if n["id"] == "n-site")["revision"]

        await client.delete(
            f"/api/v1/folders/f-site/members/{other_user.id}",
            headers=auth_headers,
        )

        await _sync(
            client,
            other_auth_headers,
            notes=[_note("n-site", "Правка после отзыва",
                         datetime(2026, 8, 2, 20), base_revision=base,
                         folder_id="f-site")],
        )

        note = await db_session.get(Note, "n-site")
        await db_session.refresh(note)
        assert note.title == "Слой 2", (
            "a revoked member still wrote into the dig site"
        )


class TestReceivingAnInvitation:
    """What the invitee's account actually shows after being invited.

    Reported from the field: Ivan invited Maria, and her account had neither
    the dig site nor any sign that an invitation had happened.
    """

    @pytest.mark.asyncio
    async def test_an_invitation_arrives_on_the_next_incremental_sync(
        self, client: AsyncClient, db_session, test_user, other_user,
        auth_headers, other_auth_headers
    ):
        """Being invited changes no row the invitee can see.

        The folder and its entries keep the `updated_at` they already had, so
        an incremental pull -- "what changed since I last looked?" -- answered
        "nothing" and the site never arrived. What matters to a client is what
        is newly *visible*, which is recorded on the membership, not the rows.
        """
        db_session.add(
            Folder(
                id="f-invite",
                user_id=test_user.id,
                name="Раскоп 7",
                color="#E8B731",
                created_at=datetime(2026, 8, 1),
                updated_at=datetime(2026, 8, 1),
                is_deleted=False,
            )
        )
        db_session.add(
            Note(
                id="n-before-invite",
                user_id=test_user.id,
                folder_id="f-invite",
                title="Слой 2",
                content="кость",
                date=datetime(2026, 8, 1),
                created_at=datetime(2026, 8, 1),
                updated_at=datetime(2026, 8, 1),
                is_deleted=False,
            )
        )
        await db_session.commit()

        # Maria syncs before the invitation: nothing is hers yet, and this is
        # the cutoff her client keeps sending from now on.
        first = await _sync(client, other_auth_headers)
        assert first["folders"] == []
        maria_last_sync = datetime.fromisoformat(first["sync_timestamp"])

        db_session.add(
            FolderMember(
                folder_id="f-invite",
                user_id=other_user.id,
                joined_at=maria_last_sync + timedelta(seconds=1),
            )
        )
        await db_session.commit()

        pulled = await _sync(
            client, other_auth_headers, last_sync_at=maria_last_sync
        )

        assert [f["name"] for f in pulled["folders"]] == ["Раскоп 7"], (
            "the dig site never reached the person invited into it"
        )
        assert [n["id"] for n in pulled["notes"]] == ["n-before-invite"], (
            "entries written before the invitation stayed invisible"
        )

    @pytest.mark.asyncio
    async def test_a_site_already_received_is_not_sent_again(
        self, client: AsyncClient, db_session, shared_site, auth_headers,
        other_auth_headers
    ):
        """Newly-visible is a one-time condition, not a standing exemption.

        If membership kept overriding the cutoff, every quiet sync would drag
        the whole site down the wire again.
        """
        await _sync(
            client,
            auth_headers,
            notes=[_note("n-site", "Слой 2", datetime(2026, 8, 2, 9),
                         folder_id="f-site")],
        )
        caught_up = await _sync(client, other_auth_headers)
        assert any(n["id"] == "n-site" for n in caught_up["notes"])

        quiet = await _sync(
            client,
            other_auth_headers,
            last_sync_at=datetime.fromisoformat(caught_up["sync_timestamp"]),
        )

        assert quiet["folders"] == []
        assert quiet["notes"] == []


class TestPushingSomethingYouMayNotTouch:
    """A stale row on the device must be skipped, never re-inserted.

    Notes and folders already guard this. Artifacts did not: an id that exists
    on the server but is out of this user's reach fell straight into the
    "create new" branch, and the INSERT hit the primary key. That is an
    IntegrityError, which fails the WHOLE sync batch -- so one leftover row
    stopped every unrelated note, folder and photo from ever syncing again.
    """

    @pytest.mark.asyncio
    async def test_an_artifact_out_of_reach_is_skipped_not_recreated(
        self, client: AsyncClient, db_session, test_user, other_auth_headers
    ):
        # Ivan's find, hanging off no note at all -- nothing shares it.
        db_session.add(
            Artifact(
                id="a-ivan",
                user_id=test_user.id,
                note_id=None,
                image_path="/ivan/find.jpg",
                captured_at=datetime(2026, 8, 1),
                created_at=datetime(2026, 8, 1),
                updated_at=datetime(2026, 8, 1),
                is_deleted=False,
            )
        )
        await db_session.commit()

        # Maria's device still holds that id and pushes it, alongside a note
        # of her own that has every right to be saved.
        response = await client.post(
            "/api/v1/sync",
            json={
                "notes": [_note("n-mine", "Мой слой", datetime(2026, 8, 2, 12))],
                "artifacts": [
                    {
                        "id": "a-ivan",
                        "note_id": None,
                        "image_path": "/maria/overwrite.jpg",
                        "captured_at": datetime(2026, 8, 2).isoformat(),
                        "updated_at": datetime(2026, 8, 2).isoformat(),
                        "is_deleted": False,
                    }
                ],
            },
            headers=other_auth_headers,
        )

        assert response.status_code == 200, response.text

        # Ivan's find is untouched...
        artifact = await db_session.get(Artifact, "a-ivan")
        await db_session.refresh(artifact)
        assert artifact.user_id == test_user.id
        assert artifact.image_path == "/ivan/find.jpg"

        # ...and Maria's own work was not collateral damage.
        assert await db_session.get(Note, "n-mine") is not None
