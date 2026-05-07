from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel

from services.supabase_service import (
    add_user_coins,
    ensure_user_profile,
    get_auth_email,
    set_user_premium,
)

router = APIRouter()

ALLOWED_COIN_AMOUNTS = {1000, 2000, 3000}


class PremiumUpdateRequest(BaseModel):
    premium: bool


class CoinChargeRequest(BaseModel):
    amount: int


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


async def _require_email(authorization: str | None) -> str:
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


@router.get("/user/me")
async def get_my_profile(authorization: str | None = Header(default=None)):
    email = await _require_email(authorization)
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
    authorization: str | None = Header(default=None),
):
    email = await _require_email(authorization)
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
    authorization: str | None = Header(default=None),
):
    if payload.amount not in ALLOWED_COIN_AMOUNTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="충전 금액은 1000, 2000, 3000만 가능합니다",
        )

    email = await _require_email(authorization)
    try:
        return await add_user_coins(email, payload.amount)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error
