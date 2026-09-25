from functools import lru_cache

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

LOCAL_ORIGINS = ("http://localhost:3000", "http://127.0.0.1:3000")
# The committed default. A production server that still signs tokens with it
# signs tokens anyone holding this source can forge, so it must not boot.
PLACEHOLDER_JWT_SECRET = "change-me-in-local"
MIN_JWT_SECRET_LENGTH = 32
PRODUCTION_ENVIRONMENTS = ("production", "prod")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Dizzo API"
    environment: str = "development"
    # Turns on /api/docs + /api/openapi.json and the localhost CORS origins.
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8000
    database_url: str = "sqlite+aiosqlite:///./dizzo.db"
    redis_url: str = ""

    # Only usable outside production: see check_production_hardening below.
    jwt_secret_key: str = PLACEHOLDER_JWT_SECRET
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30

    cookie_secure: bool = False
    cookie_domain: str | None = None
    cookie_samesite: str = "lax"

    # Production origins only; the localhost ones below are added when DEBUG.
    cors_allowed_origins: str = ""
    frontend_url: str = "http://localhost:3000"

    google_client_id: str = ""
    google_client_secret: str = ""
    # The Flutter app's Android and iOS OAuth client ids, comma separated:
    # native Google sign-in hands back id_tokens whose `aud` is one of these,
    # not the web client id.
    google_mobile_client_ids: str = ""

    telegram_bot_token: str = ""
    telegram_bot_username: str = ""
    telegram_webapp_url: str = "http://localhost:3000"
    telegram_oidc_client_id: str = ""
    bot_api_url: str = "http://localhost:8000/api"
    bot_token: str = ""

    # Click Payment configuration (Merchant / Shop-API)
    click_service_id: str = ""
    click_merchant_id: str = ""
    click_secret_key: str = ""
    click_merchant_user_id: str = ""

    # Delivery providers configuration (Yandex Delivery B2B & BTS)
    yandex_delivery_oauth_token: str = ""
    yandex_delivery_api_url: str = "https://b2b.taxi.yandex.net"
    delivery_estimated_days_yandex: str = "2–3 kun"
    delivery_estimated_days_bts: str = "3–4 kun"
    yandex_delivery_default_cost: int = 25000
    bts_delivery_default_cost: int = 35000
    dizzo_warehouse_lat: float = 41.311081
    dizzo_warehouse_lon: float = 69.240562
    dizzo_warehouse_address: str = "Toshkent shahri, Yunusobod tumani, Dizzo ishlab chiqarish markazi"

    media_root: str = "./media"
    media_url: str = "/media"

    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket: str = ""
    r2_public_base_url: str = ""
    # Client IP (rate limits, guest upload quota): CF-Connecting-IP /
    # X-Forwarded-For / X-Real-IP are believed only when the socket peer is
    # one of TRUSTED_PROXIES (comma separated IPs or CIDRs). BEHIND_PROXY=true
    # (the older switch) trusts loopback and private networks, which is where
    # the host nginx reaches the container from.
    behind_proxy: bool = False
    trusted_proxies: str = ""
    # In-memory, per process (the API runs one uvicorn worker): see
    # app/core/rate_limit.py.
    rate_limit_enabled: bool = True
    # A refresh token that was just rotated still works for this long, so two
    # tabs refreshing at once don't log each other out.
    refresh_reuse_grace_seconds: int = 30

    mb: int = 1024 * 1024
    image_types: dict[str, str] = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp"}
    glb_types: dict[str, str] = {"model/gltf-binary": "glb"}
    guest_uploads_per_hour: int = 30
    # Where a signed-out visitor's design uploads land (moved under
    # designs/u<id>/ once they sign in). See object_key in api/v1/media.py.
    guest_prefix: str = "designs/guests/"
    presign_ttl_seconds: int = 600
    upload_max_mb_design: int = 10
    upload_max_mb_catalog: int = 15
    upload_max_mb_model: int = 20
    upload_max_mb_print: int = 60
    # The design-template library (a template's image is copied here when it
    # is added to the library). See object_key in api/v1/media.py.
    library_prefix: str = "templates/"
    # A signed-in account's own hourly upload quota. Without it, signing up
    # (free, no email check) is all it takes to walk past the guest limit
    # above; generous enough that a real session never meets it — a save
    # sends five views plus the print files.
    uploads_per_hour: int = 120

    # How long an unused upload is kept before app/scripts/cleanup_media.py
    # deletes it from R2 and the database. Nothing the database still points
    # at is ever touched, whatever its age; these windows only decide when a
    # file that nothing uses stops being worth paying for.
    #
    # A day for an upload that never finished: the presigned URL itself dies
    # after ten minutes (presign_ttl_seconds), so this is pure slack for a
    # slow phone, a retry or a clock that disagrees.
    pending_upload_ttl_hours: int = 24
    # A week for a signed-out visitor's picture that no sign-in ever claimed.
    # The guest's design lives in their browser, so this is how long they may
    # take to come back and register before their work stops following them.
    guest_media_ttl_days: int = 7
    # A month for anything else nothing references any more (an image dropped
    # from a design, the print files of a cart item that became an order and
    # was cleared). Long, because this pass is the one that reasons about the
    # whole reference graph and a month is cheap insurance against a mistake.
    orphan_media_ttl_days: int = 30
    telegram_link_token_ttl_seconds: int = 60
    telegram_app_login_ttl_seconds: int = 300
    telegram_app_logins_per_hour: int = 30

    @property
    def is_production(self) -> bool:
        return self.environment.strip().lower() in PRODUCTION_ENVIRONMENTS

    @model_validator(mode="after")
    def check_production_hardening(self) -> "Settings":
        """A production boot refuses the unsafe defaults rather than running
        with them: the committed JWT secret (or a short one), cookies without
        Secure, and DEBUG (which opens /api/docs and the localhost origins)."""
        if not self.is_production:
            return self
        secret = (self.jwt_secret_key or "").strip()
        problems: list[str] = []
        if not secret or secret == PLACEHOLDER_JWT_SECRET:
            problems.append("JWT_SECRET_KEY o'rnatilmagan (standart qiymat ishlatilmoqda)")
        elif len(secret) < MIN_JWT_SECRET_LENGTH:
            problems.append(f"JWT_SECRET_KEY kamida {MIN_JWT_SECRET_LENGTH} ta belgidan iborat bo'lishi kerak")
        if not self.cookie_secure:
            problems.append("COOKIE_SECURE=true bo'lishi kerak")
        if self.debug:
            problems.append("DEBUG=false bo'lishi kerak")
        if problems:
            raise ValueError("Ishlab chiqarish (production) sozlamalari xavfsiz emas: " + "; ".join(problems))
        return self

    @field_validator("cors_allowed_origins", mode="before")
    @classmethod
    def normalize_cors(cls, value: object) -> str:
        if isinstance(value, list):
            return ",".join(str(item) for item in value)
        return str(value)

    @property
    def cors_origins(self) -> list[str]:
        origins = [item.strip() for item in self.cors_allowed_origins.split(",") if item.strip()]
        if self.debug:
            origins += [o for o in LOCAL_ORIGINS if o not in origins]
        return origins

    @property
    def trusted_proxy_networks(self) -> list[str]:
        networks = [item.strip() for item in self.trusted_proxies.split(",") if item.strip()]
        if self.behind_proxy:
            networks += ["127.0.0.0/8", "::1/128", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7"]
        return networks

    @property
    def google_audiences(self) -> list[str]:
        """Every client id a Google token may be issued for: web first, then mobile."""
        ids = [self.google_client_id, *self.google_mobile_client_ids.split(",")]
        return [item.strip() for item in ids if item.strip()]

    @property
    def effective_bot_token(self) -> str:
        return self.telegram_bot_token or self.bot_token


@lru_cache
def get_settings() -> Settings:
    return Settings()
