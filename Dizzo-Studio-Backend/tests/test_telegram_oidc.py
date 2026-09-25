import gzip
import json
import time

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.core.config import Settings
from app.services import oauth

CLIENT_ID = "987654321"


@pytest.fixture
def telegram(monkeypatch: pytest.MonkeyPatch):
    """Telegram's OIDC as it behaves live: the JWKS arrives gzipped whatever
    the request asks for. Returns (sign, fetch count)."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    jwk = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(key.public_key()))
    body = gzip.compress(json.dumps({"keys": [{**jwk, "kid": "oidc-1", "alg": "RS256", "use": "sig"}]}).encode())
    fetches = []

    def handler(request: httpx.Request) -> httpx.Response:
        fetches.append(request.url)
        return httpx.Response(200, content=body, headers={"content-type": "application/json", "content-encoding": "gzip"})

    real_client = httpx.AsyncClient
    monkeypatch.setattr(oauth.httpx, "AsyncClient", lambda **kw: real_client(transport=httpx.MockTransport(handler), **kw))
    monkeypatch.setattr(oauth, "get_settings", lambda: Settings(jwt_secret_key="x" * 40, telegram_oidc_client_id=CLIENT_ID))
    monkeypatch.setattr(oauth, "_telegram_jwks", None)

    def sign(kid: str = "oidc-1", aud: str = CLIENT_ID) -> str:
        now = int(time.time())
        claims = {"sub": "42", "aud": aud, "iss": "https://oauth.telegram.org", "iat": now, "exp": now + 60, "name": "Aziza"}
        return jwt.encode(claims, key, algorithm="RS256", headers={"kid": kid})

    return sign, fetches


@pytest.mark.asyncio
async def test_a_telegram_token_is_verified_against_the_gzipped_jwks(telegram) -> None:
    sign, fetches = telegram

    first = await oauth.verify_telegram_oidc_token(sign())
    second = await oauth.verify_telegram_oidc_token(sign())

    assert first is not None and first["sub"] == "42" and second is not None
    assert len(fetches) == 1  # the key set is kept between logins


@pytest.mark.asyncio
async def test_bad_telegram_tokens_are_refused(telegram) -> None:
    sign, fetches = telegram

    assert await oauth.verify_telegram_oidc_token(sign(aud="someone-else")) is None
    assert await oauth.verify_telegram_oidc_token(sign(kid="unknown")) is None
    assert await oauth.verify_telegram_oidc_token("not-a-jwt") is None
    assert len(fetches) == 1  # an unknown key right after a fetch doesn't fetch again


@pytest.mark.asyncio
async def test_a_telegram_login_brings_the_verified_phone(session_factory, monkeypatch: pytest.MonkeyPatch) -> None:
    from app.services import auth

    claims = {"sub": "77", "name": "Aziza Karimova", "given_name": "Aziza", "family_name": "Karimova",
              "phone_number": "998901234567", "phone_number_verified": True}

    async def verified(_token: str) -> dict:
        return dict(claims)

    monkeypatch.setattr(auth, "verify_telegram_oidc_token", verified)
    async with session_factory() as session:
        user = await auth.authenticate_telegram_oidc(session, "token")
        assert (user.first_name, user.last_name, user.phone_number) == ("Aziza", "Karimova", "+998901234567")

        # A phone the customer set themselves is never replaced.
        user.phone_number = "+998711112233"
        await session.commit()
        again = await auth.authenticate_telegram_oidc(session, "token")
        assert again.phone_number == "+998711112233"

    # An unverified phone isn't taken.
    claims.update(sub="78", phone_number_verified=False)
    async with session_factory() as session:
        other = await auth.authenticate_telegram_oidc(session, "token")
        assert other.phone_number == ""
