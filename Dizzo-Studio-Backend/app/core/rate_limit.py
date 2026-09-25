"""Client IP and a small in-memory rate limiter for the auth endpoints.

The limiter keeps sliding windows in this process's memory. The API runs a
single uvicorn worker (Dockerfile CMD), so that is the whole picture; with
several workers or hosts each would count on its own and the effective
limit would multiply — move the counters to Redis/the database then.
Counters are lost on restart, which only ever lets someone try again early.

Limits are per client IP (generous: Uzbek mobile carriers put many
customers behind one address) and per account (email, provider id or user
id), so neither spraying one account from many IPs nor many accounts from
one IP gets far.
"""

from __future__ import annotations

import ipaddress
import time
from collections import deque
from dataclasses import dataclass
from functools import lru_cache

from fastapi import HTTPException, Request, status

from app.core.config import get_settings


@lru_cache(maxsize=16)
def _networks(spec: tuple[str, ...]) -> tuple[ipaddress.IPv4Network | ipaddress.IPv6Network, ...]:
    return tuple(ipaddress.ip_network(item, strict=False) for item in spec)


def _is_trusted(ip: str, networks: tuple) -> bool:
    try:
        address = ipaddress.ip_address(ip)
    except ValueError:
        return False
    return any(address in network for network in networks)


def _valid_ip(value: str) -> str | None:
    value = value.strip()
    try:
        return str(ipaddress.ip_address(value))
    except ValueError:
        return None


def client_ip(request: Request) -> str:
    """The socket peer, unless that peer is a trusted proxy: then the address
    the proxy reports (CF-Connecting-IP, else the nearest untrusted
    X-Forwarded-For hop, else X-Real-IP)."""
    peer = request.client.host if request.client else ""
    networks = _networks(tuple(get_settings().trusted_proxy_networks))
    if not networks or not _is_trusted(peer, networks):
        return peer
    if cf_ip := _valid_ip(request.headers.get("cf-connecting-ip", "")):
        return cf_ip
    forwarded = [hop for hop in (request.headers.get("x-forwarded-for") or "").split(",") if hop.strip()]
    for hop in reversed(forwarded):
        ip = _valid_ip(hop)
        if ip is None:
            break
        if not _is_trusted(ip, networks):
            return ip
    if real_ip := _valid_ip(request.headers.get("x-real-ip", "")):
        return real_ip
    return peer


@dataclass(frozen=True)
class Limit:
    hits: int
    seconds: int


# scope -> (per IP, per account)
LIMITS: dict[str, tuple[Limit, Limit]] = {
    # Per account: failed passwords only (see api/v1/auth.login), so a
    # stranger can't lock the owner out by trying.
    "login": (Limit(30, 300), Limit(10, 900)),
    "register": (Limit(10, 3600), Limit(5, 3600)),
    "refresh": (Limit(120, 300), Limit(30, 300)),
    "oauth": (Limit(30, 300), Limit(10, 300)),
    "password": (Limit(20, 900), Limit(5, 900)),
}

TOO_MANY = "Juda ko'p urinish. Birozdan keyin qayta urinib ko'ring."


class RateLimiter:
    MAX_KEYS = 50_000

    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = {}

    def _window(self, key: str, limit: Limit, now: float) -> deque[float]:
        window = self._hits.get(key)
        if window is None:
            if len(self._hits) >= self.MAX_KEYS:
                self._prune(now)
            window = self._hits[key] = deque()
        while window and window[0] <= now - limit.seconds:
            window.popleft()
        return window

    def _prune(self, now: float) -> None:
        longest = max(max(pair[0].seconds, pair[1].seconds) for pair in LIMITS.values())
        for key in [k for k, w in self._hits.items() if not w or w[-1] <= now - longest]:
            del self._hits[key]
        if len(self._hits) >= self.MAX_KEYS:  # still full of live keys: forget the oldest half
            for key in list(self._hits)[: self.MAX_KEYS // 2]:
                del self._hits[key]

    def retry_after(self, key: str, limit: Limit) -> int | None:
        """Seconds until `key` may go again, None if it may go now."""
        now = time.monotonic()
        window = self._window(key, limit, now)
        if len(window) < limit.hits:
            return None
        return max(1, int(window[0] + limit.seconds - now) + 1)

    def add(self, key: str, limit: Limit) -> None:
        now = time.monotonic()
        self._window(key, limit, now).append(now)

    def reset(self, key: str) -> None:
        self._hits.pop(key, None)


def limiter_for(request: Request) -> RateLimiter:
    state = request.app.state
    if not hasattr(state, "rate_limiter"):
        state.rate_limiter = RateLimiter()
    return state.rate_limiter


def _refuse(retry: int) -> HTTPException:
    return HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=TOO_MANY, headers={"Retry-After": str(retry)})


def check(request: Request, scope: str, account: str | None = None, *, count_account: bool = True) -> None:
    """Counts this request against the scope's IP limit (and the account
    limit, when `account` is given and `count_account`); 429 once over."""
    if not get_settings().rate_limit_enabled:
        return
    limiter = limiter_for(request)
    ip_limit, account_limit = LIMITS[scope]
    keys = [(f"{scope}:ip:{client_ip(request)}", ip_limit)]
    if account:
        keys.append((account_key(scope, account), account_limit))
    for key, limit in keys:
        if (retry := limiter.retry_after(key, limit)) is not None:
            raise _refuse(retry)
    limiter.add(*keys[0])
    if account and count_account:
        limiter.add(*keys[1])


def account_key(scope: str, account: str) -> str:
    return f"{scope}:acct:{account.strip().lower()}"


def count_failure(request: Request, scope: str, account: str) -> None:
    if get_settings().rate_limit_enabled:
        limiter_for(request).add(account_key(scope, account), LIMITS[scope][1])
