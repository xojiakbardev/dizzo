"""Deletes the uploads nothing uses any more, from R2 and from the database.
What "nothing uses" means is worked out in app/services/media_cleanup.py.

    python -m app.scripts.cleanup_media --dry-run       # report only, deletes nothing
    python -m app.scripts.cleanup_media                 # do it
    python -m app.scripts.cleanup_media --only guests --limit 500

Run it dry first — after any change to the models, always: it prints what
each pass would take and how much space that is. Deleting from R2 cannot be
undone.

The three retention windows are settings (app/core/config.py), so they can
be widened from .env without touching the code:
PENDING_UPLOAD_TTL_HOURS (24), GUEST_MEDIA_TTL_DAYS (7),
ORPHAN_MEDIA_TTL_DAYS (30).

Scheduling: once a day, off peak, from the host's crontab. The API process
stays a web server — there is no scheduler in the app and this needs none:

    17 4 * * * cd /srv/dizzo && docker compose exec -T backend \\
        python -m app.scripts.cleanup_media >> /var/log/dizzo-cleanup.log 2>&1

A run that is killed halfway is safe to repeat: it commits in batches and
deleting an object that is already gone does nothing.
"""

from __future__ import annotations

import argparse
import asyncio

from app import models  # noqa: F401  (every model registered before the queries run)
from app.db.session import async_session_factory
from app.services.media_cleanup import BATCH, PASSES, Report, sweep
from app.services.storage import get_storage


def line(name: str, report: Report) -> str:
    mb = report.bytes / (1024 * 1024)
    failed = f", {report.failed} kept (bucket error)" if report.failed else ""
    sample = "".join(f"\n    {key}" for key in report.sample)
    more = "\n    …" if report.rows > len(report.sample) else ""
    return f"{name:<8} {report.rows:>6} files  {mb:>9.1f} MB{failed}{sample}{more}"


async def main(*, dry_run: bool, passes: list[str], batch: int, limit: int | None) -> None:
    storage = get_storage()
    async with async_session_factory() as session:
        reports = await sweep(session, storage, dry_run=dry_run, passes=passes, batch=batch, limit=limit)
    print("would delete:" if dry_run else "deleted:")
    for name in passes:
        print(line(name, reports[name]))
    total = sum(r.rows for r in reports.values())
    space = sum(r.bytes for r in reports.values()) / (1024 * 1024)
    print(f"{'total':<8} {total:>6} files  {space:>9.1f} MB")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Delete unused uploads from R2 and the database")
    parser.add_argument("--dry-run", action="store_true", help="report what would go, delete nothing")
    parser.add_argument("--only", default=",".join(PASSES), help=f"passes to run, comma separated ({', '.join(PASSES)})")
    parser.add_argument("--batch", type=int, default=BATCH, help="rows read and committed at a time")
    parser.add_argument("--limit", type=int, default=None, help="stop each pass after this many files")
    args = parser.parse_args()

    chosen = [name.strip() for name in args.only.split(",") if name.strip()]
    unknown = [name for name in chosen if name not in PASSES]
    if unknown:
        parser.error(f"unknown pass: {', '.join(unknown)} (known: {', '.join(PASSES)})")

    asyncio.run(main(dry_run=args.dry_run, passes=chosen, batch=args.batch, limit=args.limit))
