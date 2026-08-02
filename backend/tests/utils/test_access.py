"""The single access rule.

Every read and write in the app derives from this, so a hole here is a hole
everywhere -- which is why it is tested directly and not only through the
endpoints that happen to use it. This project has already shipped one
cross-account leak; the whole point of routing access through one function is
that there is exactly one thing to get right.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.folder import Folder
from app.models.membership import FolderMember
from app.models.user import User
from app.utils.access import accessible_folder_ids


def _folder(folder_id: str, owner: User) -> Folder:
    from datetime import datetime

    return Folder(
        id=folder_id,
        user_id=owner.id,
        name="Раскоп 3",
        color="#E8B731",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        is_deleted=False,
    )


@pytest.mark.asyncio
async def test_an_owner_reaches_their_own_folder(
    db_session: AsyncSession, test_user: User
):
    db_session.add(_folder("f1", test_user))
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == {"f1"}


@pytest.mark.asyncio
async def test_a_member_reaches_a_folder_they_do_not_own(
    db_session: AsyncSession, test_user: User, other_user: User
):
    db_session.add(_folder("f1", other_user))
    db_session.add(FolderMember(folder_id="f1", user_id=test_user.id))
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == {"f1"}


@pytest.mark.asyncio
async def test_a_stranger_reaches_nothing(
    db_session: AsyncSession, test_user: User, other_user: User
):
    """The leak test, at its smallest. Everything else builds on this."""
    db_session.add(_folder("f1", other_user))
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == set()


@pytest.mark.asyncio
async def test_a_revoked_member_reaches_nothing(
    db_session: AsyncSession, test_user: User, other_user: User
):
    db_session.add(_folder("f1", other_user))
    membership = FolderMember(folder_id="f1", user_id=test_user.id)
    db_session.add(membership)
    await db_session.flush()

    await db_session.delete(membership)
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == set()


@pytest.mark.asyncio
async def test_owned_and_shared_are_unioned_not_replaced(
    db_session: AsyncSession, test_user: User, other_user: User
):
    """A user who both owns a site and was invited to another must reach both;
    an implementation that returned whichever query ran last would pass every
    test above and fail this one."""
    db_session.add(_folder("mine", test_user))
    db_session.add(_folder("theirs", other_user))
    db_session.add(FolderMember(folder_id="theirs", user_id=test_user.id))
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == {"mine", "theirs"}
