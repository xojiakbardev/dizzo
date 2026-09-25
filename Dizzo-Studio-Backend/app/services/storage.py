"""Cloudflare R2 object storage (S3 API).

The browser uploads straight to R2 with a presigned PUT; the backend never
proxies file bytes. R2 enforces the signed Content-Type and Content-Length,
so a presigned URL cannot be used to upload a different type or a bigger
file than the one that was validated here.
"""

import asyncio
from dataclasses import dataclass
from functools import lru_cache

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from app.core.config import get_settings

PRESIGN_TTL_SECONDS = get_settings().presign_ttl_seconds


@dataclass(frozen=True)
class StoredObject:
    size_bytes: int
    content_type: str


class R2Storage:
    def __init__(self, *, account_id: str, access_key_id: str, secret_access_key: str, bucket: str, public_base_url: str):
        self._bucket = bucket
        self._public_base_url = public_base_url.rstrip("/")
        self._client = boto3.client(
            "s3",
            endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key,
            region_name="auto",
            config=Config(signature_version="s3v4"),
        )

    def presign_put(self, key: str, *, content_type: str, size_bytes: int) -> str:
        # Signing only — no network round trip.
        return self._client.generate_presigned_url(
            "put_object",
            Params={"Bucket": self._bucket, "Key": key, "ContentType": content_type, "ContentLength": size_bytes},
            ExpiresIn=PRESIGN_TTL_SECONDS,
        )

    def public_url(self, key: str) -> str:
        return f"{self._public_base_url}/{key}"

    async def head(self, key: str) -> StoredObject | None:
        try:
            response = await asyncio.to_thread(self._client.head_object, Bucket=self._bucket, Key=key)
        except ClientError as exc:
            if exc.response["Error"]["Code"] in ("404", "NoSuchKey", "NotFound"):
                return None
            raise
        return StoredObject(size_bytes=response["ContentLength"], content_type=response["ContentType"])

    async def read_range(self, key: str, start: int, length: int) -> bytes:
        response = await asyncio.to_thread(
            self._client.get_object, Bucket=self._bucket, Key=key, Range=f"bytes={start}-{start + length - 1}"
        )
        return await asyncio.to_thread(response["Body"].read)

    async def read(self, key: str) -> bytes:
        response = await asyncio.to_thread(self._client.get_object, Bucket=self._bucket, Key=key)
        return await asyncio.to_thread(response["Body"].read)

    async def put_bytes(self, key: str, body: bytes, content_type: str) -> None:
        await asyncio.to_thread(self._client.put_object, Bucket=self._bucket, Key=key, Body=body, ContentType=content_type)

    async def copy(self, source_key: str, target_key: str) -> None:
        await asyncio.to_thread(
            self._client.copy_object,
            Bucket=self._bucket,
            Key=target_key,
            CopySource={"Bucket": self._bucket, "Key": source_key},
        )

    async def delete(self, key: str) -> None:
        await asyncio.to_thread(self._client.delete_object, Bucket=self._bucket, Key=key)


@lru_cache
def get_storage() -> R2Storage:
    settings = get_settings()
    required = {
        "R2_ACCOUNT_ID": settings.r2_account_id,
        "R2_ACCESS_KEY_ID": settings.r2_access_key_id,
        "R2_SECRET_ACCESS_KEY": settings.r2_secret_access_key,
        "R2_BUCKET": settings.r2_bucket,
        "R2_PUBLIC_BASE_URL": settings.r2_public_base_url,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise RuntimeError(f"R2 is not configured, set: {', '.join(missing)}")
    return R2Storage(
        account_id=settings.r2_account_id,
        access_key_id=settings.r2_access_key_id,
        secret_access_key=settings.r2_secret_access_key,
        bucket=settings.r2_bucket,
        public_base_url=settings.r2_public_base_url,
    )
