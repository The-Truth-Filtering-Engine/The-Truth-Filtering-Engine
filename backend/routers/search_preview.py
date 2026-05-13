"""
Search preview and search history endpoints.

Endpoints:
  GET    /api/search/preview
  GET    /api/search/recent
  POST   /api/search/recent
  DELETE /api/search/recent/{id}
  DELETE /api/search/recent
"""

from __future__ import annotations

import asyncio
import os
import re
import unicodedata

import httpx
from fastapi import APIRouter, Header, HTTPException, Path, Query, status
from pydantic import BaseModel

from services.supabase_service import get_auth_email

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY", "")
)

router = APIRouter(prefix="/api/search", tags=["search-preview"])

_SCORE = {
    "restaurant_exact": 100,
    "menu_exact": 90,
    "restaurant_prefix": 80,
    "menu_prefix": 70,
    "restaurant_partial": 60,
    "menu_partial": 50,
    "review_keyword": 30,
    "issue_tag": 25,
}

_PREVIEW_LIMIT = 3
_SUGGESTION_LIMIT = 5
_ISSUE_CHIP_LIMIT = 3
_HISTORY_LIMIT = 20
_VALID_CLICKED_TYPES = {"menu", "restaurant", "issue", "quick_preview"}


class SearchRecentRequest(BaseModel):
    query: str
    clickedType: str
    clickedId: str | None = None
    clickedLabel: str | None = None
    restaurantId: str | None = None
    menuId: str | None = None


def _headers(prefer: str = "") -> dict[str, str]:
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    return headers


def _require_supabase() -> None:
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase 설정이 없습니다",
        )


def _normalize(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text).casefold().strip()
    return re.sub(r"\s+", " ", normalized)


def _match_key(text: str) -> str:
    return re.sub(r"\s+", "", _normalize(text))


def _match_score(
    query_norm: str,
    target: str,
    exact_score: int,
    prefix_score: int,
    partial_score: int,
) -> int:
    query_key = _match_key(query_norm)
    target_key = _match_key(target)
    if not query_key or not target_key:
        return 0
    if query_key == target_key:
        return exact_score
    if target_key.startswith(query_key):
        return prefix_score
    if query_key in target_key:
        return partial_score
    return 0


def _format_price(price: int | None, price_label: str | None) -> str:
    if price_label:
        return price_label
    if price is None:
        return "가격 문의"
    return f"{price:,}원"


def _postgrest_in(values: list[str]) -> str:
    safe_values = []
    for value in values:
        text = str(value).strip()
        if not text:
            continue
        safe_values.append('"' + text.replace('"', "") + '"')
    return f"in.({','.join(safe_values)})"


async def _get_auth_email_required(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer 인증 토큰이 필요합니다",
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer 인증 토큰이 필요합니다",
        )

    email = await get_auth_email(token.strip())
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 인증 토큰입니다",
        )
    return email


async def _fetch_active_issue_keywords(client: httpx.AsyncClient) -> list[dict]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/search_issue_keywords",
        headers=_headers(),
        params={
            "is_active": "eq.true",
            "order": "base_score.desc",
            "select": "id,label,keyword,aliases,review_keywords,base_score",
        },
        timeout=5,
    )
    if response.status_code != 200:
        return []
    return response.json() or []


async def _fetch_menus_by_query(
    client: httpx.AsyncClient,
    query: str,
) -> list[dict]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/restaurant_menus",
        headers=_headers(),
        params={
            "name": f"ilike.*{query}*",
            "order": "is_best.desc,name.asc",
            "limit": str(_SUGGESTION_LIMIT * 3),
            "select": (
                "id,restaurant_id,restaurant_name,name,price,price_label,"
                "image_url,is_best"
            ),
        },
        timeout=5,
    )
    if response.status_code != 200:
        return []
    return response.json() or []


async def _fetch_review_keyword_stats(
    client: httpx.AsyncClient,
    restaurant_ids: list[str],
    issue_keyword_ids: list[str],
) -> list[dict]:
    if not restaurant_ids or not issue_keyword_ids:
        return []

    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/restaurant_review_keyword_stats",
        headers=_headers(),
        params={
            "restaurant_id": _postgrest_in(restaurant_ids),
            "issue_keyword_id": _postgrest_in(issue_keyword_ids),
            "select": (
                "restaurant_id,issue_keyword_id,positive_count,total_count"
            ),
        },
        timeout=5,
    )
    if response.status_code != 200:
        return []
    return response.json() or []


async def _fetch_recent_history(
    client: httpx.AsyncClient,
    email: str,
) -> list[dict]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/user_search_histories",
        headers={
            **_headers(),
            "Range": f"0-{_HISTORY_LIMIT - 1}",
            "Range-Unit": "items",
        },
        params={
            "user_email": f"eq.{email}",
            "order": "created_at.desc",
            "select": (
                "id,query,clicked_type,clicked_id,clicked_label,"
                "restaurant_id,menu_id,created_at"
            ),
        },
        timeout=5,
    )
    if response.status_code not in (200, 206):
        return []
    return response.json() or []


def _score_issue_chips(
    query_norm: str,
    issue_keywords: list[dict],
) -> list[dict]:
    query_key = _match_key(query_norm)
    results = []

    for keyword in issue_keywords:
        candidates = [keyword.get("keyword", "")]
        aliases = keyword.get("aliases") or []
        if isinstance(aliases, list):
            candidates.extend(aliases)

        matched = any(
            candidate_key in query_key or query_key in candidate_key
            for candidate_key in (_match_key(str(item)) for item in candidates)
            if candidate_key
        )
        if not matched:
            continue

        results.append(
            {
                "id": keyword.get("id", ""),
                "label": keyword.get("label", ""),
                "keyword": keyword.get("keyword", ""),
                "score": keyword.get("base_score", _SCORE["issue_tag"]),
            }
        )

    results.sort(key=lambda item: item["score"], reverse=True)
    return results[:_ISSUE_CHIP_LIMIT]


def _score_menus(
    query_norm: str,
    menus: list[dict],
    review_stats: dict[str, int],
) -> list[dict]:
    scored = []

    for menu in menus:
        name_score = _match_score(
            query_norm,
            menu.get("name", ""),
            exact_score=_SCORE["menu_exact"],
            prefix_score=_SCORE["menu_prefix"],
            partial_score=_SCORE["menu_partial"],
        )
        if name_score == 0:
            continue

        review_bonus = min(
            review_stats.get(menu.get("restaurant_id", ""), 0),
            _SCORE["review_keyword"],
        )
        scored.append({"menu": menu, "score": name_score + review_bonus})

    scored.sort(key=lambda item: item["score"], reverse=True)
    return scored


def _build_suggestions(
    query_norm: str,
    menus: list[dict],
    review_stats: dict[str, int],
) -> dict:
    scored_menus = _score_menus(query_norm, menus, review_stats)

    menu_suggestions = [
        {
            "id": str(item["menu"].get("id", "")),
            "name": item["menu"].get("name", ""),
            "matchedText": query_norm,
            "score": item["score"],
        }
        for item in scored_menus[:_SUGGESTION_LIMIT]
    ]

    seen_restaurant_ids: set[str] = set()
    restaurant_suggestions = []
    for item in scored_menus:
        restaurant_id = item["menu"].get("restaurant_id", "")
        if not restaurant_id or restaurant_id in seen_restaurant_ids:
            continue

        seen_restaurant_ids.add(restaurant_id)
        restaurant_suggestions.append(
            {
                "id": restaurant_id,
                "name": item["menu"].get("restaurant_name") or restaurant_id,
                "score": item["score"],
            }
        )
        if len(restaurant_suggestions) >= _SUGGESTION_LIMIT:
            break

    return {
        "menus": menu_suggestions,
        "restaurants": restaurant_suggestions,
    }


def _menu_match_reason(query_norm: str, menu_name: str) -> str:
    name_score = _match_score(
        query_norm,
        menu_name,
        exact_score=_SCORE["menu_exact"],
        prefix_score=_SCORE["menu_prefix"],
        partial_score=_SCORE["menu_partial"],
    )
    if name_score == _SCORE["menu_exact"]:
        return "메뉴명 완전일치"
    if name_score == _SCORE["menu_prefix"]:
        return "메뉴명 앞부분 일치"
    return "메뉴명 부분일치"


def _build_quick_previews(
    query_norm: str,
    menus: list[dict],
    review_stats: dict[str, int],
) -> list[dict]:
    scored_menus = _score_menus(query_norm, menus, review_stats)
    best_by_restaurant: dict[str, dict] = {}

    for item in scored_menus:
        menu = item["menu"]
        restaurant_id = menu.get("restaurant_id", "")
        score = item["score"]
        current = best_by_restaurant.get(restaurant_id)
        if restaurant_id and (current is None or score > current["score"]):
            best_by_restaurant[restaurant_id] = item

    ranked = sorted(
        best_by_restaurant.values(),
        key=lambda item: item["score"],
        reverse=True,
    )[:_PREVIEW_LIMIT]

    previews = []
    for item in ranked:
        menu = item["menu"]
        price = menu.get("price")
        restaurant_id = menu.get("restaurant_id", "")
        restaurant_name = menu.get("restaurant_name") or restaurant_id
        menu_name = menu.get("name", "")

        previews.append(
            {
                "restaurantId": restaurant_id,
                "restaurantName": restaurant_name,
                "menuId": str(menu.get("id", "")),
                "menuName": menu_name,
                "price": price,
                "priceLabel": _format_price(price, menu.get("price_label")),
                "imageUrl": menu.get("image_url"),
                "score": item["score"],
                "matchReason": _menu_match_reason(query_norm, menu_name),
            }
        )

    return previews


def _history_row_to_response(row: dict) -> dict:
    return {
        "id": str(row.get("id", "")),
        "query": row.get("query", ""),
        "clickedType": row.get("clicked_type", ""),
        "clickedId": row.get("clicked_id"),
        "clickedLabel": row.get("clicked_label") or "",
        "restaurantId": row.get("restaurant_id"),
        "menuId": row.get("menu_id"),
        "createdAt": row.get("created_at"),
    }


async def _fetch_parallel(
    client: httpx.AsyncClient,
    query_norm: str,
) -> tuple[list[dict], list[dict]]:
    issue_task = asyncio.create_task(_fetch_active_issue_keywords(client))
    menu_task = asyncio.create_task(_fetch_menus_by_query(client, query_norm))
    return await asyncio.gather(issue_task, menu_task)


@router.get("/preview")
async def get_search_preview(
    query: str = Query(..., min_length=1, max_length=100),
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    authorization: str | None = Header(default=None),
):
    _require_supabase()
    await _get_auth_email_required(authorization)

    query_norm = _normalize(query)
    if not query_norm:
        raise HTTPException(status_code=400, detail="검색어가 비어 있습니다")

    async with httpx.AsyncClient() as client:
        issue_keywords, menus = await _fetch_parallel(client, query_norm)
        restaurant_ids = list(
            {menu.get("restaurant_id", "") for menu in menus if menu.get("restaurant_id")}
        )
        issue_ids = [keyword["id"] for keyword in issue_keywords if keyword.get("id")]
        stats_rows = await _fetch_review_keyword_stats(
            client,
            restaurant_ids,
            issue_ids,
        )

    review_stats: dict[str, int] = {}
    for row in stats_rows:
        restaurant_id = row.get("restaurant_id", "")
        review_stats[restaurant_id] = review_stats.get(restaurant_id, 0) + (
            row.get("positive_count") or 0
        )

    return {
        "query": query,
        "issueChips": _score_issue_chips(query_norm, issue_keywords),
        "suggestions": _build_suggestions(query_norm, menus, review_stats),
        "quickPreviews": _build_quick_previews(query_norm, menus, review_stats),
    }


@router.get("/recent")
async def get_recent_history(
    authorization: str | None = Header(default=None),
):
    _require_supabase()
    email = await _get_auth_email_required(authorization)

    async with httpx.AsyncClient() as client:
        items = await _fetch_recent_history(client, email)

    return {"items": [_history_row_to_response(item) for item in items]}


@router.post("/recent", status_code=status.HTTP_201_CREATED)
async def save_recent_history(
    body: SearchRecentRequest,
    authorization: str | None = Header(default=None),
):
    _require_supabase()
    email = await _get_auth_email_required(authorization)
    query = body.query.strip()

    if not query:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="검색어가 비어 있습니다",
        )
    if body.clickedType not in _VALID_CLICKED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="clickedType은 menu, restaurant, issue, quick_preview 중 하나여야 합니다",
        )

    row = {
        "user_email": email,
        "query": query,
        "clicked_type": body.clickedType,
        "clicked_id": body.clickedId,
        "clicked_label": body.clickedLabel,
        "restaurant_id": body.restaurantId,
        "menu_id": body.menuId,
    }
    row = {key: value for key, value in row.items() if value is not None}

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/user_search_histories",
            headers=_headers("return=representation"),
            json=row,
            timeout=5,
        )

    if response.status_code not in (200, 201):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="검색 기록 저장 실패",
        )

    created = response.json() if response.text else []
    return _history_row_to_response(created[0]) if created else {}


@router.delete("/recent/{history_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_recent_history_item(
    history_id: str = Path(...),
    authorization: str | None = Header(default=None),
):
    _require_supabase()
    email = await _get_auth_email_required(authorization)

    async with httpx.AsyncClient() as client:
        response = await client.delete(
            f"{SUPABASE_URL}/rest/v1/user_search_histories",
            headers=_headers(),
            params={
                "id": f"eq.{history_id}",
                "user_email": f"eq.{email}",
            },
            timeout=5,
        )

    if response.status_code not in (200, 204):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="검색 기록 삭제 실패",
        )


@router.delete("/recent", status_code=status.HTTP_204_NO_CONTENT)
async def delete_all_recent_history(
    authorization: str | None = Header(default=None),
):
    _require_supabase()
    email = await _get_auth_email_required(authorization)

    async with httpx.AsyncClient() as client:
        response = await client.delete(
            f"{SUPABASE_URL}/rest/v1/user_search_histories",
            headers=_headers(),
            params={"user_email": f"eq.{email}"},
            timeout=5,
        )

    if response.status_code not in (200, 204):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="검색 기록 전체 삭제 실패",
        )
