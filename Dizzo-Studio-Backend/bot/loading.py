"""The Dizzo loading sticker (the site's loader, bot/assets/loading.webm):
sent while the bot works on something, and removed when it's done."""
import asyncio
import time
from contextlib import asynccontextmanager, suppress
from pathlib import Path

from aiogram.exceptions import TelegramAPIError
from aiogram.types import FSInputFile, Message

STICKER = Path(__file__).parent / "assets" / "loading.webm"
MIN_SECONDS = 1.2  # a quick job still shows the animation, not a flash

_file_id: str | None = None  # uploaded once, then sent by id


@asynccontextmanager
async def loading(message: Message):
    """`async with loading(message): ...` — the sticker shows until the block ends."""
    global _file_id
    sent = None
    started = time.monotonic()
    with suppress(TelegramAPIError, OSError):
        sent = await message.answer_sticker(_file_id or FSInputFile(STICKER))
        if sent.sticker:
            _file_id = sent.sticker.file_id
    try:
        yield
    finally:
        if sent:
            await asyncio.sleep(max(0.0, MIN_SECONDS - (time.monotonic() - started)))
            with suppress(TelegramAPIError):
                await sent.delete()
