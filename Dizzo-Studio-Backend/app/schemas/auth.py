from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: str | None = None
    first_name: str = ""
    last_name: str = ""
    full_name: str = ""
    phone_number: str = ""
    avatar: str | None = None
    role: str = "customer"
    is_staff: bool = False
    is_active: bool = True
    is_super_admin: bool = False
    branch_id: int | None = None
    branch_name: str | None = None
    telegram_linked: bool = False
    telegram_linked_at: str | None = None
    language: str = "uz"
    created_at: str | None = None
    updated_at: str | None = None


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AuthResponse(TokenPair):
    user: UserOut


class LoginRequest(BaseModel):
    email: EmailStr
    # No min_length here (unlike Register/SetCredentials/AdminUserCreate,
    # which are the actual password-creation paths where an 8-char policy
    # belongs) — login just checks whatever password is already on file,
    # including ones created before this policy existed or via a script.
    password: str = Field(max_length=128)


class RegisterRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=150)
    last_name: str = Field(default="", max_length=150)
    phone_number: str = Field(default="", max_length=32)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str | None = None


class SetCredentialsRequest(BaseModel):
    """Lets an OAuth-only user (no email/password yet) add email+password login."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class GoogleLoginRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None


class TelegramOidcLoginRequest(BaseModel):
    id_token: str = Field(min_length=20)


class TelegramLoginRequest(BaseModel):
    model_config = ConfigDict(extra="allow")
    init_data: str | None = None
    id: int | None = None
    first_name: str | None = None
    last_name: str | None = None
    username: str | None = None
    photo_url: str | None = None
    auth_date: int | None = None
    hash: str | None = None


class BotUpsertRequest(BaseModel):
    telegram_id: int
    first_name: str | None = None
    last_name: str | None = None
    username: str | None = None
    photo_url: str | None = None
    # From the Telegram app's language: an account the bot creates starts in it.
    language: Literal["uz", "ru", "en"] | None = None


class BotLanguageRequest(BaseModel):
    telegram_id: int


class TelegramAppLoginConfirmRequest(BotUpsertRequest):
    token: str = Field(min_length=1, max_length=64)


class ProductOut(BaseModel):
    id: int
    name: str
    slug: str
    category: str
    description: str
    available_sizes: list = Field(default_factory=list)
    available_colors: list = Field(default_factory=list)
    has_size_variants: bool = False
    has_color_variants: bool = False
    is_active: bool = True
    sort_order: int = 0
    variants: list[dict[str, Any]] = Field(default_factory=list)


class AdminUserCreateRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    first_name: str = Field(default="", max_length=150)
    last_name: str = Field(default="", max_length=150)
    role: str = Field(default="customer")
    branch_id: int | None = None
    is_staff: bool = False


class AdminUserRoleUpdateRequest(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    phone_number: str | None = None
    role: str | None = None
    branch_id: int | None = None
    is_staff: bool | None = None
    is_active: bool | None = None


class ProfileUpdateRequest(BaseModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=150)
    last_name: str | None = Field(default=None, max_length=150)
    phone_number: str | None = Field(default=None, max_length=32)
    avatar: str | None = None
    # The language the site and the Telegram messages use for this user.
    language: Literal["uz", "ru", "en"] | None = None
