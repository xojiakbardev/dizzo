from typing import Any

import httpx

from bot.i18n import telegram_language


class APIClient:
    def __init__(self, base_url: str, bot_token: str) -> None:
        self.client = httpx.AsyncClient(base_url=base_url.rstrip("/"), timeout=10)
        self.bot_token = bot_token

    async def close(self) -> None:
        await self.client.aclose()

    async def upsert_user(self, user: Any) -> None:
        await self.client.post(
            "/auth/telegram/bot",
            headers={"X-Bot-Token": self.bot_token},
            json={
                "telegram_id": user.id,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "username": user.username,
                "language": telegram_language(user.language_code),
            },
        )

    async def language(self, telegram_id: int) -> str | None:
        """The language of the account behind this chat; None when it has
        none, or the API can't say (the bot then goes by Telegram's)."""
        try:
            response = await self.client.post(
                "/auth/telegram/language/",
                headers={"X-Bot-Token": self.bot_token},
                json={"telegram_id": telegram_id},
            )
            return response.json().get("language")
        except (httpx.HTTPError, ValueError, AttributeError):
            return None

    async def link_telegram(self, token: str, telegram_id: int) -> dict:
        """Consumes a profile page's deep-link token, linking this chat's
        Telegram id to the account that requested it."""
        response = await self.client.post(
            "/auth/telegram/link/",
            headers={"X-Bot-Token": self.bot_token},
            json={"token": token, "telegram_id": telegram_id},
        )
        try:
            return response.json()
        except ValueError:
            return {"ok": False, "reason": "error"}

    async def confirm_app_login(self, token: str, user: Any) -> dict:
        """Confirms the mobile app's sign-in code for this Telegram user."""
        response = await self.client.post(
            "/auth/telegram/app-login/confirm/",
            headers={"X-Bot-Token": self.bot_token},
            json={
                "token": token,
                "telegram_id": user.id,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "username": user.username,
                "language": telegram_language(user.language_code),
            },
        )
        try:
            return response.json()
        except ValueError:
            return {"ok": False, "reason": "error"}

    async def cancel_app_login(self, token: str) -> dict:
        """Cancels the mobile app's sign-in code (the app's poll then gets 410)."""
        response = await self.client.post(
            "/auth/telegram/app-login/cancel/",
            headers={"X-Bot-Token": self.bot_token},
            json={"token": token},
        )
        try:
            return response.json()
        except ValueError:
            return {"ok": False, "reason": "error"}

    async def moderate_gallery(self, item_id: int, action: str, telegram_id: int) -> dict:
        """Approves or rejects a gallery showcase item via moderator verification."""
        try:
            response = await self.client.post(
                "/admin/gallery/telegram-moderate/",
                headers={"X-Bot-Token": self.bot_token},
                json={"item_id": item_id, "action": action, "telegram_id": telegram_id},
            )
            return response.json()
        except (httpx.HTTPError, ValueError):
            return {"ok": False, "reason": "error", "message": "Serverga ulanishda xatolik"}

