"""Tutorial videos: what an admin sends and what the site gets back."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from pydantic import AfterValidator, BaseModel, BeforeValidator, Field

from app.schemas.catalog import Strict
from app.schemas.design import MediaId
from app.schemas.i18n import TUTORIAL_FIELDS, Translations


def _strip(value: object) -> object:
    return value.strip() if isinstance(value, str) else value


def _blank_to_none(value: object) -> object:
    value = _strip(value)
    return value or None if isinstance(value, str) else value


def _http_url(value: str | None) -> str | None:
    if value is not None and not value.lower().startswith(("https://", "http://")):
        raise ValueError("Video havolasi http:// yoki https:// bilan boshlanishi kerak")
    return value


Title = Annotated[str, BeforeValidator(_strip), Field(min_length=1, max_length=120)]
VideoUrl = Annotated[
    Annotated[str, Field(max_length=500)] | None, BeforeValidator(_blank_to_none), AfterValidator(_http_url)
]
Pixels = Annotated[int, Field(ge=1, le=20000)]
TutorialTranslations = Translations(TUTORIAL_FIELDS)


class TutorialIn(Strict):
    title: Title
    cover_media_id: MediaId
    cover_width: Pixels | None = None
    cover_height: Pixels | None = None
    video_url: VideoUrl = None
    is_published: bool = False
    translations: TutorialTranslations | None = None


class TutorialPatch(Strict):
    """Only the fields sent change; `video_url` sent as null or blank clears it.
    A new `cover_media_id` resets the cover size to what is sent with it."""

    title: Title | None = None
    cover_media_id: MediaId | None = None
    cover_width: Pixels | None = None
    cover_height: Pixels | None = None
    video_url: VideoUrl = None
    is_published: bool | None = None
    translations: TutorialTranslations | None = None


class TutorialOrder(Strict):
    ids: list[int] = Field(max_length=1000)


class TutorialPublic(BaseModel):
    id: int
    title: str
    cover_url: str
    cover_width: int | None
    cover_height: int | None
    video_url: str | None


class TutorialOut(TutorialPublic):
    cover_media_id: str
    sort_order: int
    is_published: bool
    created_at: datetime
    translations: dict = {}
