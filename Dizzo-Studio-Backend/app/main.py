from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.exceptions import HTTPException as StarletteHTTPException

from app import models  # noqa: F401
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.i18n import LanguageMiddleware
from app.core.rate_limit import RateLimiter
from app.core.validation_messages import http_error_handler, validation_error_handler
from app.db.session import engine
from app.services.feed_cache import CacheInvalidationMiddleware


@asynccontextmanager
async def lifespan(_: FastAPI):
    # The schema is owned by Alembic (`alembic upgrade head` runs before the
    # server starts, see Dockerfile) — startup never creates or alters tables.
    yield
    await engine.dispose()


def create_app(*, lifespan_enabled: bool = True) -> FastAPI:
    settings = get_settings()
    application = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        # The API description is for development only.
        docs_url="/api/docs" if settings.debug else None,
        redoc_url=None,
        openapi_url="/api/openapi.json" if settings.debug else None,
        lifespan=lifespan if lifespan_enabled else None,
    )
    application.state.rate_limiter = RateLimiter()
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        # Paged lists tell the client how many there are in all.
        expose_headers=["X-Total-Count"],
        allow_headers=["*"],
    )
    # Every request runs in its language (?lang= / Accept-Language).
    application.add_middleware(LanguageMiddleware)
    # A write to the shop clears the cached public lists.
    application.add_middleware(CacheInvalidationMiddleware)
    application.add_exception_handler(RequestValidationError, validation_error_handler)
    application.add_exception_handler(StarletteHTTPException, http_error_handler)
    application.include_router(api_router, prefix="/api")

    @application.get("/api/health/")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @application.get("/health")
    async def plain_health() -> str:
        return "OK"

    return application


app = create_app()
