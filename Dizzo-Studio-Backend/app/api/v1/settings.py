"""System settings endpoints for super admin dashboard."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, is_super_admin
from app.db.session import get_db
from app.models.setting import SystemSetting
from app.models.user import User

router = APIRouter(prefix="/admin/settings", tags=["admin-settings"])


class SettingItemOut(BaseModel):
    key: str
    value: str
    description: str | None = None
    created_at: datetime
    updated_at: datetime


class SettingCreateOrUpdateIn(BaseModel):
    key: str
    value: str
    description: str | None = None


class SettingValueUpdateIn(BaseModel):
    value: str
    description: str | None = None


@router.get("", response_model=list[SettingItemOut])
async def list_settings(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[SettingItemOut]:
    if not is_super_admin(user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Ruxsat yo'q")

    rows = (await session.execute(select(SystemSetting).order_by(SystemSetting.key))).scalars().all()

    # Seed default telegram_moderator_group_id if not present yet
    if not any(r.key == "telegram_moderator_group_id" for r in rows):
        default_setting = SystemSetting(
            key="telegram_moderator_group_id",
            value="",
            description="Telegram Moderator Guruhi Chat ID si (xabarnoma va tasdiqlash uchun)",
        )
        session.add(default_setting)
        await session.commit()
        await session.refresh(default_setting)
        rows = (await session.execute(select(SystemSetting).order_by(SystemSetting.key))).scalars().all()

    return [
        SettingItemOut(
            key=row.key,
            value=row.value,
            description=row.description,
            created_at=row.created_at or datetime.utcnow(),
            updated_at=row.updated_at or datetime.utcnow(),
        )
        for row in rows
    ]


@router.post("", response_model=SettingItemOut, status_code=status.HTTP_201_CREATED)
async def create_or_update_setting(
    payload: SettingCreateOrUpdateIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SettingItemOut:
    if not is_super_admin(user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Faqat superadmin sozlamalarni o'zgartira oladi")

    key = payload.key.strip()
    if not key:
        raise HTTPException(status_code=422, detail="Sozlama kaliti bo'sh bo'lishi mumkin emas")

    setting = await session.get(SystemSetting, key)
    if not setting:
        setting = SystemSetting(
            key=key,
            value=payload.value.strip(),
            description=payload.description.strip() if payload.description else None,
        )
        session.add(setting)
    else:
        setting.value = payload.value.strip()
        if payload.description is not None:
            setting.description = payload.description.strip() or None

    await session.commit()
    await session.refresh(setting)

    return SettingItemOut(
        key=setting.key,
        value=setting.value,
        description=setting.description,
        created_at=setting.created_at,
        updated_at=setting.updated_at,
    )


@router.patch("/{key}", response_model=SettingItemOut)
async def update_single_setting(
    key: str,
    payload: SettingValueUpdateIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SettingItemOut:
    if not is_super_admin(user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Faqat superadmin sozlamalarni o'zgartira oladi")

    setting = await session.get(SystemSetting, key)
    if not setting:
        raise HTTPException(status_code=404, detail="Sozlama topilmadi")

    setting.value = payload.value.strip()
    if payload.description is not None:
        setting.description = payload.description.strip() or None

    await session.commit()
    await session.refresh(setting)

    return SettingItemOut(
        key=setting.key,
        value=setting.value,
        description=setting.description,
        created_at=setting.created_at,
        updated_at=setting.updated_at,
    )


@router.delete("/{key}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_setting(
    key: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not is_super_admin(user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Faqat superadmin sozlamalarni o'chira oladi")

    setting = await session.get(SystemSetting, key)
    if setting:
        await session.delete(setting)
        await session.commit()
