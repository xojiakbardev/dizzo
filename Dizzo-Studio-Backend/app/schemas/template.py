"""Gallery designs (templates): ready designs an admin made in the Studio,
offered to customers on the variants they were checked against, and shown
with their pictures on the public gallery."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.schemas.catalog import Strict
from app.schemas.design import DesignDocument, MediaId
from app.schemas.i18n import TEMPLATE_FIELDS, Translations

TemplateName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
Category = Annotated[str, StringConstraints(strip_whitespace=True, max_length=60)]
VariantIds = Annotated[list[int], Field(min_length=1, max_length=50)]
GalleryImages = Annotated[list[MediaId], Field(max_length=5)]
TemplateTranslations = Translations(TEMPLATE_FIELDS)


class TemplateIn(Strict):
    name: TemplateName
    category: Category = ""
    variant_ids: VariantIds
    document: DesignDocument
    # The Studio's 3D frame of the design, uploaded by the admin.
    preview_media_id: MediaId
    # The gallery: up to five pictures (the Studio's mockups), shown when
    # `in_gallery`, in the colour `color_id`.
    images: GalleryImages | None = None
    in_gallery: bool | None = None
    color_id: int | None = None
    # Left out (null): an edited template keeps the translations it has.
    translations: TemplateTranslations | None = None


class TemplatePatch(Strict):
    name: TemplateName | None = None
    category: Category | None = None
    variant_ids: VariantIds | None = None
    is_active: bool | None = None
    sort_order: int | None = Field(default=None, ge=0, le=100000)
    images: GalleryImages | None = None
    in_gallery: bool | None = None
    color_id: int | None = None
    translations: TemplateTranslations | None = None


class TemplateOrder(Strict):
    ids: Annotated[list[int], Field(min_length=1, max_length=2000)]


class TemplateImage(BaseModel):
    media_id: str
    url: str


class Out(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class TemplateOut(Out):
    id: int
    product_id: int
    product_name: str
    product_slug: str
    name: str
    category: str
    preview_url: str
    variant_ids: list[int]
    document: DesignDocument
    is_active: bool
    sort_order: int
    images: list[TemplateImage] = []
    in_gallery: bool = False
    color_id: int | None = None
    updated_at: datetime
    translations: dict = {}


class PublicTemplate(Out):
    id: int
    name: str
    category: str
    preview_url: str
    variant_ids: list[int]  # only variants on sale
    document: DesignDocument
