from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field

from services.supabase_service import (
    add_user_coins,
    add_user_bookmark,
    add_user_recent_visit,
    clear_user_recent_visits,
    ensure_user_profile,
    get_auth_email,
    get_user_recent_analyses,
    get_user_bookmarks,
    get_user_recent_visits,
    get_user_review_reactions,
    remove_user_bookmark,
    remove_user_recent_visit,
    set_user_premium,
    update_user_review_reaction,
)

router = APIRouter()

ALLOWED_COIN_AMOUNTS = {1000, 2000, 3000}
TEST_ADMIN_EMAIL = "test@example.com"
TEST_ADMIN_HEADER = "X-Temporary-Admin-Email"


class PremiumUpdateRequest(BaseModel):
    premium: bool


class CoinChargeRequest(BaseModel):
    amount: int


class BookmarkUpdateRequest(BaseModel):
    storeId: str
    store: dict = Field(default_factory=dict)


class RecentVisitUpdateRequest(BaseModel):
    reviewId: str = ""
    review: dict = Field(default_factory=dict)


class ReviewReactionUpdateRequest(BaseModel):
    reviewId: str
    reaction: Literal["like"] | None = None


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="인증 토큰이 없습니다",
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer 인증 토큰이 필요합니다",
        )

    return token.strip()


def _extract_temporary_admin_email(temporary_admin_email: str | None) -> str | None:
    email = (temporary_admin_email or "").strip().lower()
    if not email:
        return None
    if email != TEST_ADMIN_EMAIL:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="테스트 관리자 이메일이 올바르지 않습니다",
        )
    return TEST_ADMIN_EMAIL


async def _require_email(
    authorization: str | None,
    temporary_admin_email: str | None,
) -> str:
    admin_email = _extract_temporary_admin_email(temporary_admin_email)
    if admin_email:
        return admin_email

    token = _extract_bearer_token(authorization)

    try:
        email = await get_auth_email(token)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 인증 토큰입니다",
        )

    return email


async def _require_email_from_headers(
    authorization: str | None = Header(default=None),
    temporary_admin_email: str | None = Header(default=None, alias=TEST_ADMIN_HEADER),
) -> str:
    return await _require_email(authorization, temporary_admin_email)


@router.get("/user/me")
async def get_my_profile(email: str = Depends(_require_email_from_headers)):
    try:
        return await ensure_user_profile(email)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.patch("/user/me/premium")
async def update_my_premium(
    payload: PremiumUpdateRequest,
    email: str = Depends(_require_email_from_headers),
):
    try:
        return await set_user_premium(email, payload.premium)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.post("/user/me/coins")
async def charge_my_coins(
    payload: CoinChargeRequest,
    email: str = Depends(_require_email_from_headers),
):
    if payload.amount not in ALLOWED_COIN_AMOUNTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="충전 금액은 1000, 2000, 3000만 가능합니다",
        )

    try:
        return await add_user_coins(email, payload.amount)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.get("/user/me/bookmarks")
async def get_my_bookmarks(email: str = Depends(_require_email_from_headers)):
    try:
        return await get_user_bookmarks(email)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.get("/user/me/recent-analyses")
async def get_my_recent_analyses(
    email: str = Depends(_require_email_from_headers),
):
    try:
        return await get_user_recent_analyses(email)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.get("/user/me/recent-visits")
async def get_my_recent_visits(email: str = Depends(_require_email_from_headers)):
    try:
        return await get_user_recent_visits(email)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.post("/user/me/bookmarks")
async def add_my_bookmark(
    payload: BookmarkUpdateRequest,
    email: str = Depends(_require_email_from_headers),
):
    store_id = payload.storeId.strip()
    if not store_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="storeId가 필요합니다",
        )

    try:
        return await add_user_bookmark(email, store_id, payload.store)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.post("/user/me/recent-visits")
async def add_my_recent_visit(
    payload: RecentVisitUpdateRequest,
    email: str = Depends(_require_email_from_headers),
):
    review_id = payload.reviewId.strip()
    if not review_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="reviewId is required",
        )

    try:
        return await add_user_recent_visit(email, review_id, payload.review)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.delete("/user/me/recent-visits")
async def clear_my_recent_visits(
    email: str = Depends(_require_email_from_headers),
):
    try:
        return await clear_user_recent_visits(email)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.delete("/user/me/recent-visits/{review_id}")
async def delete_my_recent_visit(
    review_id: str,
    email: str = Depends(_require_email_from_headers),
):
    normalized_review_id = review_id.strip()
    if not normalized_review_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="reviewId is required",
        )

    try:
        return await remove_user_recent_visit(email, normalized_review_id)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.delete("/user/me/bookmarks/{store_id}")
async def delete_my_bookmark(
    store_id: str,
    email: str = Depends(_require_email_from_headers),
):
    normalized_store_id = store_id.strip()
    if not normalized_store_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="storeId가 필요합니다",
        )

    try:
        return await remove_user_bookmark(email, normalized_store_id)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.get("/user/me/review-reactions")
async def get_my_review_reactions(
    email: str = Depends(_require_email_from_headers),
):
    try:
        return await get_user_review_reactions(email)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


@router.put("/user/me/review-reactions")
async def update_my_review_reaction(
    payload: ReviewReactionUpdateRequest,
    email: str = Depends(_require_email_from_headers),
):
    try:
        return await update_user_review_reaction(
            email,
            payload.reviewId,
            payload.reaction,
        )
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error
