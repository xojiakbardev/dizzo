"""Fast cache for public lists (catalog cards, gallery feed, templates),
with Redis support and in-memory fallback.

Any change through admin or orders API invalidates the cache immediately.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
from collections.abc import Awaitable, Callable
from typing import Any

from app.core.config import get_settings

logger = logging.getLogger(__name__)

TTL_SECONDS = 120

_entries: dict[tuple, tuple[float, Any]] = {}
_locks: dict[tuple, asyncio.Lock] = {}
_redis_client = None
_redis_checked = False


def _get_redis():
    global _redis_client, _redis_checked
    if not _redis_checked:
        _redis_checked = True
        url = get_settings().redis_url
        if url:
            try:
                import redis.asyncio as aioredis
                _redis_client = aioredis.from_url(url, encoding="utf-8", decode_responses=True)
                logger.info("Redis cache enabled with %s", url)
            except Exception as e:
                logger.warning("Failed to initialize Redis client (%s), falling back to in-memory: %s", url, e)
                _redis_client = None
    return _redis_client


def _key_to_str(key: tuple) -> str:
    parts = [str(p) if not isinstance(p, (dict, list, tuple)) else json.dumps(p, sort_keys=True) for p in key]
    return f"dizzo:feed:{':'.join(parts)}"


async def cached(key: tuple, build: Callable[[], Awaitable[Any]], ttl: float = TTL_SECONDS) -> Any:
    client = _get_redis()
    redis_key = _key_to_str(key) if client else None

    # 1. Try Redis if available
    if client and redis_key:
        try:
            cached_val = await client.get(redis_key)
            if cached_val is not None:
                return json.loads(cached_val)
        except Exception as e:
            logger.debug("Redis GET error on %s: %s", redis_key, e)

    # 2. Fallback / fast in-memory check
    now = time.monotonic()
    hit = _entries.get(key)
    if hit and hit[0] > now:
        return hit[1]

    # One build at a time per key to avoid thundering herd
    lock = _locks.setdefault(key, asyncio.Lock())
    async with lock:
        # Recheck after acquiring lock
        if client and redis_key:
            try:
                cached_val = await client.get(redis_key)
                if cached_val is not None:
                    return json.loads(cached_val)
            except Exception:
                pass

        hit = _entries.get(key)
        if hit and hit[0] > time.monotonic():
            return hit[1]

        value = await build()
        _entries[key] = (time.monotonic() + ttl, value)

        # Store in Redis asynchronously
        if client and redis_key:
            try:
                await client.set(redis_key, json.dumps(value, default=str), ex=int(ttl))
            except Exception as e:
                logger.debug("Redis SET error on %s: %s", redis_key, e)

        return value


def clear() -> None:
    _entries.clear()
    client = _get_redis()
    if client:
        try:
            # Schedule asynchronous Redis flush without blocking event loop
            async def _flush_redis():
                try:
                    keys = await client.keys("dizzo:feed:*")
                    if keys:
                        await client.delete(*keys)
                except Exception as e:
                    logger.debug("Redis flush error: %s", e)

            try:
                loop = asyncio.get_running_loop()
                loop.create_task(_flush_redis())
            except RuntimeError:
                pass
        except Exception:
            pass


WRITE_PREFIXES = ("/api/admin/", "/api/orders/", "/api/checkout/", "/api/reviews/")


class CacheInvalidationMiddleware:
    def __init__(self, app: Any) -> None:
        self.app = app

    async def __call__(self, scope: dict, receive: Any, send: Any) -> None:
        if (
            scope["type"] == "http"
            and scope.get("method") not in ("GET", "HEAD", "OPTIONS")
            and scope.get("path", "").startswith(WRITE_PREFIXES)
        ):
            try:
                await self.app(scope, receive, send)
            finally:
                clear()
            return
        await self.app(scope, receive, send)
