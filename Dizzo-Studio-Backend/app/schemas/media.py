from typing import Literal

from pydantic import BaseModel, Field

MediaPurpose = Literal["design", "catalog", "model", "print", "avatar"]


class UploadRequest(BaseModel):
    purpose: MediaPurpose
    content_type: str = Field(max_length=100)
    size_bytes: int = Field(gt=0)


class UploadTicket(BaseModel):
    id: str
    upload_url: str
    upload_method: Literal["PUT"] = "PUT"
    # Must be sent exactly as given — R2 checks them against the signature.
    upload_headers: dict[str, str]
    url: str
    expires_in: int


class MediaOut(BaseModel):
    id: str
    url: str
    purpose: MediaPurpose
    content_type: str
    size_bytes: int
    status: Literal["pending", "ready"]
    # Uploaded without an account: lives under tmp/ until claimed after login.
    guest: bool


class ClaimRequest(BaseModel):
    ids: list[str] = Field(min_length=1, max_length=100)
