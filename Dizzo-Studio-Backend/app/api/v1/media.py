"""File uploads to R2.

Flow: POST /media/uploads/ validates the file and returns a presigned PUT
URL -> the browser PUTs the bytes straight to R2 -> POST /media/{id}/complete/
checks the object is really there and marks it ready. Guests may upload
design images (rate limited per IP); POST /media/claim/ moves them into the
user's own prefix after login.
"""

import io
import struct
import warnings
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from PIL import Image
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ALL_STAFF_ROLES, client_ip, get_current_user, optional_user, require_roles
from app.core.config import get_settings
from app.core.i18n import _
from app.db.session import get_db
from app.models.media import Media
from app.models.user import User
from app.schemas.media import ClaimRequest, MediaOut, UploadRequest, UploadTicket
from app.services.storage import PRESIGN_TTL_SECONDS, R2Storage, get_storage
from app.services.thumbnails import make_thumbnails, wants_thumbnails

router = APIRouter(prefix="/media", tags=["media"])

settings = get_settings()

IMAGE_TYPES = settings.image_types
GLB_TYPES = settings.glb_types
MB = settings.mb
GUEST_UPLOADS_PER_HOUR = settings.guest_uploads_per_hour
UPLOADS_PER_HOUR = settings.uploads_per_hour
GUEST_PREFIX = settings.guest_prefix


@dataclass(frozen=True)
class PurposeRules:
    types: dict[str, str]
    max_bytes: int
    guests_allowed: bool
    # Which roles may upload this kind of file; empty means any signed-in
    # customer. Spelled out per purpose rather than one "admin only" flag,
    # because the two staff-only purposes do not want the same people.
    roles: tuple[str, ...] = ()


PURPOSES = {
    "design": PurposeRules(types=IMAGE_TYPES, max_bytes=settings.upload_max_mb_design * MB, guests_allowed=True),
    # Shop pictures. Every staff role may upload one: branch staff and
    # moderators submit gallery showcases, and a showcase's pictures are
    # catalog media (app/api/v1/admin_gallery.py images_of).
    "catalog": PurposeRules(
        types=IMAGE_TYPES, max_bytes=settings.upload_max_mb_catalog * MB, guests_allowed=False, roles=ALL_STAFF_ROLES,
    ),
    # 3D models for "model" shapes: the catalog's backbone, so only the
    # people who own the catalog may replace one. The admin UI also checks
    # triangles and texture sizes before uploading; here the header is
    # verified on complete.
    "model": PurposeRules(
        types=GLB_TYPES, max_bytes=settings.upload_max_mb_model * MB, guests_allowed=False, roles=("super_admin", "admin"),
    ),
    # Print files of a cart item: one PNG per area and method at the
    # method's DPI. Checked pixel by pixel when the item is added to the cart.
    "print": PurposeRules(types={"image/png": "png"}, max_bytes=settings.upload_max_mb_print * MB, guests_allowed=False),
    # User profile pictures (avatars)
    "avatar": PurposeRules(types=IMAGE_TYPES, max_bytes=5 * MB, guests_allowed=False),
}


def glb_header_error(header: bytes, size_bytes: int) -> str | None:
    """A binary glTF starts with magic "glTF", version 2 and the file length."""
    if len(header) < 12 or header[:4] != b"glTF":
        return "Fayl GLB emas"
    version, length = struct.unpack_from("<II", header, 4)
    if version != 2:
        return _("Faqat glTF 2.0 qo'llab-quvvatlanadi (fayl versiyasi {version})", version=version)
    if length != size_bytes:
        return "GLB fayl buzilgan: sarlavhadagi uzunlik fayl hajmiga teng emas"
    return None


# What an uploaded file's bytes must be for the type it was declared as.
PIL_FORMATS = {"image/png": "PNG", "image/jpeg": "JPEG", "image/webp": "WEBP"}
PDF_MAGIC = b"%PDF-"


def image_content_error(content_type: str, data: bytes) -> str | None:
    """None when `data` is an intact image of the declared type (Pillow
    identifies it and verify() finds nothing broken, without decoding it)."""
    expected = PIL_FORMATS[content_type]
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as image:
                if image.format != expected:
                    return _("Fayl {format} rasm emas", format=expected)
                image.verify()
    except (OSError, SyntaxError, ValueError, struct.error, Image.DecompressionBombError):
        return "Rasm fayli buzilgan yoki o'qib bo'lmadi"
    return None


def pdf_content_error(data: bytes) -> str | None:
    return None if data.startswith(PDF_MAGIC) else "Fayl PDF emas"


async def content_error(media: Media, storage: R2Storage) -> str | None:
    if media.content_type in GLB_TYPES:
        return glb_header_error(await storage.read_range(media.key, 0, 12), media.size_bytes)
    if media.content_type == "application/pdf":
        return pdf_content_error(await storage.read_range(media.key, 0, len(PDF_MAGIC)))
    if media.content_type in PIL_FORMATS:
        return image_content_error(media.content_type, await storage.read(media.key))
    return "Bu fayl turi qabul qilinmaydi"


def media_out(media: Media, storage: R2Storage) -> MediaOut:
    return MediaOut(
        id=media.id,
        url=storage.public_url(media.key),
        purpose=media.purpose,
        content_type=media.content_type,
        size_bytes=media.size_bytes,
        status=media.status,
        guest=media.owner_id is None and media.purpose == "design",
    )


def object_key(purpose: str, media_id: str, ext: str, user: User | None) -> str:
    """The R2 object key (its folder + name) for an upload. The bucket is
    laid out by what the file is, so its path says where it belongs:

        catalog/<id>.<ext>          shop images the admin manages — product,
                                    variant, category, gallery, tutorial and
                                    review pictures (these get WebP thumbnails)
        models/<id>.glb             3D models for "model" shapes
        templates/<id>.<ext>        the design-template library
        designs/guests/<id>.<ext>   a signed-out visitor's uploaded picture
                                    (moved under designs/u<id>/ when they sign in)
        designs/u<id>/<id>.<ext>    a signed-in user's saved design pictures
        prints/u<id>/<id>.png       a cart item's print-ready files
        avatars/u<id>/<id>.<ext>    a user's profile picture

    Only NEW uploads use this; existing objects keep the key stored on their
    Media row, so changing the layout never moves or breaks old files.
    """
    if purpose == "catalog":
        return f"catalog/{media_id}.{ext}"
    if purpose == "model":
        return f"models/{media_id}.{ext}"
    if purpose == "print":
        return f"prints/u{user.id}/{media_id}.{ext}"
    if purpose == "avatar":
        return f"avatars/u{user.id}/{media_id}.{ext}"
    if user is None:
        return f"{GUEST_PREFIX}{media_id}.{ext}"
    return f"designs/u{user.id}/{media_id}.{ext}"


@router.post("/uploads/", response_model=UploadTicket, status_code=status.HTTP_201_CREATED)
async def create_upload(
    payload: UploadRequest,
    request: Request,
    session: AsyncSession = Depends(get_db),
    user: User | None = Depends(optional_user),
    storage: R2Storage = Depends(get_storage),
):
    rules = PURPOSES[payload.purpose]
    ext = rules.types.get(payload.content_type)
    if ext is None:
        allowed = ", ".join(sorted(rules.types))
        raise HTTPException(
            status_code=422, detail=_("Bu fayl turi qabul qilinmaydi. Ruxsat etilgan: {allowed}", allowed=allowed)
        )
    if payload.size_bytes > rules.max_bytes:
        raise HTTPException(
            status_code=422, detail=_("Fayl hajmi {size} MB dan oshmasligi kerak", size=rules.max_bytes // MB)
        )

    if user is None and not rules.guests_allowed:
        raise HTTPException(status_code=401, detail="Autentifikatsiya talab qilinadi")
    if rules.roles:
        require_roles(user, *rules.roles)

    ip = client_ip(request)
    # Both sides are capped per hour: without an account quota, registering
    # (free, unverified) would be all it takes to walk past the guest one.
    since = datetime.now(UTC) - timedelta(hours=1)
    counted = select(func.count()).select_from(Media).where(Media.created_at >= since)
    if user is None:
        recent = await session.scalar(counted.where(Media.owner_id.is_(None), Media.uploader_ip == ip))
        if recent >= GUEST_UPLOADS_PER_HOUR:
            raise HTTPException(
                status_code=429, detail="Juda ko'p yuklash. Bir soatdan keyin urinib ko'ring yoki hisobga kiring."
            )
    elif user.role not in ALL_STAFF_ROLES:
        recent = await session.scalar(counted.where(Media.owner_id == user.id))
        if recent >= UPLOADS_PER_HOUR:
            raise HTTPException(status_code=429, detail="Juda ko'p fayl yuklandi. Bir soatdan keyin urinib ko'ring.")

    media_id = str(uuid4())
    media = Media(
        id=media_id,
        key=object_key(payload.purpose, media_id, ext, user),
        purpose=payload.purpose,
        content_type=payload.content_type,
        size_bytes=payload.size_bytes,
        status="pending",
        owner_id=user.id if user else None,
        uploader_ip=ip,
    )
    session.add(media)
    await session.commit()
    return UploadTicket(
        id=media.id,
        upload_url=storage.presign_put(media.key, content_type=media.content_type, size_bytes=media.size_bytes),
        upload_headers={"Content-Type": media.content_type},
        url=storage.public_url(media.key),
        expires_in=PRESIGN_TTL_SECONDS,
    )


@router.post("/{media_id}/complete/", response_model=MediaOut)
async def complete_upload(
    media_id: str, background: BackgroundTasks, session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    media = await session.get(Media, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Fayl topilmadi")
    if media.status == "ready":
        return media_out(media, storage)

    stored = await storage.head(media.key)
    if stored is None:
        raise HTTPException(status_code=409, detail="Fayl hali yuklanmagan")
    if stored.size_bytes != media.size_bytes or stored.content_type != media.content_type:
        await storage.delete(media.key)
        raise HTTPException(status_code=422, detail="Yuklangan fayl so'ralgan fayl bilan mos kelmadi")
    # The declared type is only a claim: the bytes must be that kind of file.
    problem = await content_error(media, storage)
    if problem:
        await storage.delete(media.key)
        raise HTTPException(status_code=422, detail=problem)

    media.status = "ready"
    await session.commit()
    # Phones get the catalog's pictures as small WebP copies (after the answer).
    if wants_thumbnails(media.key, media.content_type):
        background.add_task(make_thumbnails, storage, media.key)
    return media_out(media, storage)


@router.post("/claim/", response_model=list[MediaOut])
async def claim_guest_uploads(
    payload: ClaimRequest,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    """Moves design images uploaded as a guest into the user's own prefix.
    Idempotent: media the user already owns is returned unchanged."""
    ids = list(dict.fromkeys(payload.ids))
    rows = {m.id: m for m in (await session.execute(select(Media).where(Media.id.in_(ids)))).scalars()}
    if len(rows) != len(ids):
        raise HTTPException(status_code=404, detail="Fayl topilmadi")
    for media in rows.values():
        if media.owner_id not in (None, user.id):
            raise HTTPException(status_code=403, detail="Ruxsat yo'q")
        if media.owner_id is None and (media.status != "ready" or not media.key.startswith(GUEST_PREFIX)):
            raise HTTPException(status_code=409, detail="Faqat yuklab bo'lingan mehmon fayllarini biriktirish mumkin")

    moved: list[str] = []
    for media in rows.values():
        if media.owner_id is None:
            # designs/guests/<id>.<ext> -> designs/u<id>/<id>.<ext>
            new_key = f"designs/u{user.id}/{media.key.removeprefix(GUEST_PREFIX)}"
            await storage.copy(media.key, new_key)
            moved.append(media.key)
            media.key = new_key
            media.owner_id = user.id
    await session.commit()
    # The guest copies go only after the new keys are committed. One that
    # fails to delete is left with no row naming it, which the cleanup job
    # cannot see either (it works from the database, never from a bucket
    # listing); an R2 lifecycle rule on designs/guests/ is the backstop.
    for old_key in moved:
        await storage.delete(old_key)
    return [media_out(rows[i], storage) for i in ids]


@router.get("/{media_id}/", response_model=MediaOut)
async def media_detail(media_id: str, session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage)):
    media = await session.get(Media, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Fayl topilmadi")
    return media_out(media, storage)
