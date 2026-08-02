"""The one place that answers "what can this user reach?".

Sharing turns roughly twenty `user_id == current_user.id` conditions across the
routers and the sync service into "owner or member". Twenty hand-edited
conditions is twenty chances to get it wrong, and this project has already
shipped a cross-account leak once -- the whole `owner_key` mechanism on the
client exists because of it.

So the rule lives here and is imported. No query is allowed to restate it.
"""

from typing import Set

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.folder import Folder
from ..models.membership import FolderMember
from ..models.user import User


async def accessible_folder_ids(db: AsyncSession, user: User) -> Set[str]:
    """Every folder id `user` may read or write: the ones they own, plus the
    ones shared with them.

    Returned as a set rather than a query so callers can use it in an `IN`
    clause without re-running two selects per collection. A dig site has a
    handful of folders, not thousands, so materialising them is cheaper than
    the correlated subquery it replaces.
    """
    owned = await db.execute(
        select(Folder.id).where(Folder.user_id == user.id)
    )
    shared = await db.execute(
        select(FolderMember.folder_id).where(FolderMember.user_id == user.id)
    )
    return set(owned.scalars().all()) | set(shared.scalars().all())
