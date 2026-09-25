"""Writes the WebP thumbnails (app/services/thumbnails.py) of every catalog
picture that has none yet.

    python -m app.scripts.backfill_thumbnails [--force]
"""

import asyncio
import sys

from sqlalchemy import select

from app.db.session import async_session_factory
from app.models.media import Media
from app.services.storage import get_storage
from app.services.thumbnails import WIDTHS, make_thumbnails, thumb_key, wants_thumbnails


async def main(force: bool) -> None:
    storage = get_storage()
    async with async_session_factory() as session:
        rows = (await session.execute(select(Media).where(Media.status == "ready"))).scalars().all()
    keys = [m.key for m in rows if wants_thumbnails(m.key, m.content_type)]
    made = 0
    for key in keys:
        if not force and await storage.head(thumb_key(key, WIDTHS[-1])) is not None:
            continue
        await make_thumbnails(storage, key)
        made += 1
    print(f"catalog pictures: {len(keys)}, thumbnails written: {made}")


if __name__ == "__main__":
    asyncio.run(main("--force" in sys.argv))
