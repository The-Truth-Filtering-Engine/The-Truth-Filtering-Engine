"""
Search preview, trending chips, search results, and search history endpoints.

Endpoints:
  GET    /api/search/trending
  GET    /api/search/preview
  GET    /api/search/results
  GET    /api/search/recent
  POST   /api/search/recent
  DELETE /api/search/recent/{id}
  DELETE /api/search/recent
"""

from __future__ import annotations

import asyncio
import math
import os
import re
import unicodedata
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx
from fastapi import APIRouter, Header, HTTPException, Path, Query, status
from pydantic import BaseModel

from services.supabase_service import get_auth_email

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY", "")
)
KAKAO_REST_API_KEY = os.getenv("KAKAO_REST_API_KEY", "").strip()

KAKAO_KEYWORD_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"
KAKAO_CATEGORY_CODES = ("FD6", "CE7")
KAKAO_PAGE_SIZE = 15

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
_RELATED_CATEGORY_LIMIT = 3
_HISTORY_LIMIT = 20
_CACHE_TTL_DAYS = 14
_MIN_QUERY_LENGTH = 2
_VALID_CLICKED_TYPES = {"menu", "restaurant", "issue", "quick_preview"}

_DEFAULT_TRENDING_CHIPS = [
    {"id": "realtime", "label": "지금 뜨는 맛집"},
    {"id": "popular", "label": "많이 찾는 맛집"},
    {"id": "new", "label": "신상 맛집"},
    {"id": "nostalgia", "label": "추억의 맛집"},
]

_TRENDING_LABEL_ALIASES = {
    "실시간 검색 맛집": "지금 뜨는 맛집",
    "🔥 지금 뜨는 맛집": "지금 뜨는 맛집",
    "지금 뜨는 맛집": "지금 뜨는 맛집",
    "많이 찾는 맛집👍": "많이 찾는 맛집",
    "많이 찾는 맛집": "많이 찾는 맛집",
    "✨ 신상 맛집 ✨": "신상 맛집",
    "신상 맛집": "신상 맛집",
    "🕰️ 추억의 맛집": "추억의 맛집",
    "추억의 맛집": "추억의 맛집",
}

_REMOVED_TRENDING_LABELS = {
    "자연 속 맛집",
    "자연 뷰 맛집",
    "데이트 장소",
    "SNS 좋아요",
    "산수유람 맛집",
    "예쁜 카페",
    "이색 맛집",
    "지역 전통 음식",
    "고급 식당",
    "격식있는 모임",
    "TV 출연 가게",
    "TV 출연 화제의 식당",
    "동네 오래된 맛집",
}

_RELATED_KEYWORD_FALLBACK_ROWS = [
    {
        "id": "coffee-franchise-cafe",
        "group_key": "coffeebean",
        "label": "프랜차이즈 카페",
        "keyword": "프랜차이즈 카페",
        "triggers": ["커피빈", "커피빈코리아", "coffee bean", "coffeebean"],
        "is_exclusive": True,
    },
    {
        "id": "coffee-tumbler-md",
        "group_key": "coffeebean",
        "label": "텀블러MD",
        "keyword": "텀블러MD",
        "triggers": ["커피빈", "커피빈코리아", "coffee bean", "coffeebean"],
        "is_exclusive": True,
    },
    {
        "id": "coffee-americano",
        "group_key": "coffeebean",
        "label": "아메리카노",
        "keyword": "아메리카노",
        "triggers": ["커피빈", "커피빈코리아", "coffee bean", "coffeebean"],
        "is_exclusive": True,
    },
    {
        "id": "cafe-sweet-latte",
        "group_key": "cafe",
        "label": "달달한 라떼",
        "keyword": "달달한 라떼",
        "triggers": ["커피", "카페", "라떼", "디카페인", "돌체", "돌체라떼"],
        "is_exclusive": False,
    },
    {
        "id": "cafe-decaf-menu",
        "group_key": "cafe",
        "label": "디카페인 추천",
        "keyword": "디카페인 추천",
        "triggers": ["커피", "카페", "라떼", "디카페인", "돌체", "돌체라떼"],
        "is_exclusive": False,
    },
    {
        "id": "cafe-quiet-study",
        "group_key": "cafe",
        "label": "공부하기 좋은 조용한 카페",
        "keyword": "공부하기 좋은 조용한 카페",
        "triggers": ["커피", "카페", "라떼", "디카페인", "돌체", "돌체라떼"],
        "is_exclusive": False,
    },
    {
        "id": "cafe-late-night",
        "group_key": "cafe",
        "label": "늦게까지 하는 카페",
        "keyword": "늦게까지 하는 카페",
        "triggers": ["커피", "카페", "라떼", "디카페인", "돌체", "돌체라떼"],
        "is_exclusive": False,
    },
]


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
        raise HTTPException(status_code=503, detail="Supabase 설정이 없습니다")


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


def _distance_meters(
    lat1: float | None,
    lng1: float | None,
    lat2: float | None,
    lng2: float | None,
) -> int:
    if lat1 is None or lng1 is None or lat2 is None or lng2 is None:
        return 0
    radius = 6371000
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return int(2 * radius * math.asin(math.sqrt(a)))


def _as_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


async def _get_auth_email_required(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Bearer 인증 토큰이 필요합니다")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(status_code=401, detail="Bearer 인증 토큰이 필요합니다")
    email = await get_auth_email(token.strip())
    if not email:
        raise HTTPException(status_code=401, detail="유효하지 않은 인증 토큰입니다")
    return email


async def _fetch_optional_table(
    client: httpx.AsyncClient,
    table: str,
    params: dict[str, str],
) -> list[dict]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers=_headers(),
        params=params,
        timeout=5,
    )
    if response.status_code != 200:
        return []
    return response.json() or []


async def _fetch_trending_chips(client: httpx.AsyncClient) -> list[dict]:
    chips = await _fetch_optional_table(
        client,
        "trending_chips",
        {
            "is_active": "eq.true",
            "order": "sort_order.asc",
            "select": "id,label,sort_order",
        },
    )
    results = []
    seen_labels = set()
    for chip in chips:
        label = str(chip.get("label", "")).strip()
        if not label:
            continue

        label = _TRENDING_LABEL_ALIASES.get(label, label)
        if label in _REMOVED_TRENDING_LABELS or label in seen_labels:
            continue

        seen_labels.add(label)
        results.append(
            {
                "id": str(chip.get("id", "")),
                "label": label,
            }
        )

    for default_chip in _DEFAULT_TRENDING_CHIPS:
        label = default_chip["label"]
        if label in seen_labels:
            continue
        seen_labels.add(label)
        results.append(default_chip)

    return results or _DEFAULT_TRENDING_CHIPS


async def _fetch_related_keyword_rows(client: httpx.AsyncClient) -> list[dict]:
    rows = await _fetch_optional_table(
        client,
        "search_related_keywords",
        {
            "is_active": "eq.true",
            "order": "is_exclusive.desc,sort_order.asc",
            "select": (
                "id,group_key,label,keyword,triggers,is_exclusive,sort_order"
            ),
        },
    )
    if not rows:
        return _RELATED_KEYWORD_FALLBACK_ROWS

    merged = {
        str(row.get("id", "")): row
        for row in rows
        if str(row.get("id", "")).strip()
    }
    for fallback in _RELATED_KEYWORD_FALLBACK_ROWS:
        merged[str(fallback["id"])] = fallback
    return list(merged.values())


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


async def _fetch_menus_by_restaurant_name_query(
    client: httpx.AsyncClient,
    query: str,
    limit: int = 30,
) -> list[dict]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/restaurant_menus",
        headers=_headers(),
        params={
            "restaurant_name": f"ilike.*{query}*",
            "order": "is_best.desc,name.asc",
            "limit": str(limit),
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


async def _fetch_restaurants_by_query(
    client: httpx.AsyncClient,
    query: str,
    limit: int = _SUGGESTION_LIMIT,
) -> list[dict]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/restaurants",
        headers=_headers(),
        params={
            "name": f"ilike.*{query}*",
            "order": "name.asc",
            "limit": str(limit),
            "select": (
                "id,name,category_name,category_group_code,category_group_name,"
                "phone,address_name,road_address_name,place_url,lat,lng"
            ),
        },
        timeout=5,
    )
    if response.status_code != 200:
        return []
    return response.json() or []


async def _fetch_cafe_restaurants(
    client: httpx.AsyncClient,
    lat: float | None,
    lng: float | None,
    limit: int = 30,
) -> list[dict]:
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/restaurants",
        headers=_headers(),
        params={
            "category_group_code": "eq.CE7",
            "order": "name.asc",
            "limit": str(limit),
            "select": (
                "id,name,category_name,category_group_code,category_group_name,"
                "phone,address_name,road_address_name,place_url,lat,lng"
            ),
        },
        timeout=5,
    )
    if response.status_code != 200:
        return []

    restaurants = response.json() or []
    if lat is not None and lng is not None:
        restaurants.sort(
            key=lambda restaurant: _distance_meters(
                lat,
                lng,
                _as_float(restaurant.get("lat")),
                _as_float(restaurant.get("lng")),
            )
        )
    return restaurants


async def _fetch_menus_by_restaurant_ids(
    client: httpx.AsyncClient,
    restaurant_ids: list[str],
    limit: int = 30,
) -> list[dict]:
    if not restaurant_ids:
        return []

    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/restaurant_menus",
        headers=_headers(),
        params={
            "restaurant_id": _postgrest_in(restaurant_ids),
            "order": "is_best.desc,name.asc",
            "limit": str(limit),
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
            "select": "restaurant_id,issue_keyword_id,positive_count,total_count",
        },
        timeout=5,
    )
    if response.status_code != 200:
        return []
    return response.json() or []


async def _fetch_search_cache(
    client: httpx.AsyncClient,
    query_key: str,
) -> dict | None:
    rows = await _fetch_optional_table(
        client,
        "search_cache",
        {
            "query": f"eq.{query_key}",
            "expires_at": f"gt.{datetime.now(timezone.utc).isoformat()}",
            "limit": "1",
        },
    )
    return rows[0] if rows else None


async def _upsert_search_cache(
    client: httpx.AsyncClient,
    query_key: str,
    result_count: int,
) -> None:
    expires_at = (datetime.now(timezone.utc) + timedelta(days=_CACHE_TTL_DAYS)).isoformat()
    await client.post(
        f"{SUPABASE_URL}/rest/v1/search_cache",
        headers=_headers("resolution=merge-duplicates"),
        json={
            "query": query_key,
            "result_count": result_count,
            "expires_at": expires_at,
        },
        timeout=5,
    )


async def _fetch_keyword_stats(
    client: httpx.AsyncClient,
    query_key: str,
) -> list[dict]:
    return await _fetch_optional_table(
        client,
        "search_keyword_stats",
        {
            "query": f"eq.{query_key}",
            "order": "match_count.desc",
            "limit": str(_ISSUE_CHIP_LIMIT),
        },
    )


async def _upsert_keyword_stats(
    client: httpx.AsyncClient,
    query_key: str,
    issue_keyword_ids: list[str],
) -> None:
    if not issue_keyword_ids:
        return
    rows = [
        {"query": query_key, "issue_keyword_id": keyword_id, "match_count": 1}
        for keyword_id in issue_keyword_ids
    ]
    await client.post(
        f"{SUPABASE_URL}/rest/v1/search_keyword_stats",
        headers=_headers("resolution=merge-duplicates"),
        json=rows,
        timeout=5,
    )


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


async def _fetch_kakao_places(
    client: httpx.AsyncClient,
    query: str,
    lat: float | None,
    lng: float | None,
) -> list[dict]:
    if not KAKAO_REST_API_KEY:
        return []

    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    has_location = lat is not None and lng is not None

    async def fetch_category(category_code: str) -> list[dict]:
        params: dict[str, Any] = {
            "query": query,
            "category_group_code": category_code,
            "size": KAKAO_PAGE_SIZE,
            "sort": "distance" if has_location else "accuracy",
        }
        if has_location:
            params.update({"x": lng, "y": lat, "radius": 5000})

        try:
            response = await client.get(
                KAKAO_KEYWORD_URL,
                headers=headers,
                params=params,
                timeout=5,
            )
            if response.status_code != 200:
                return []
            return response.json().get("documents", []) or []
        except Exception:
            return []

    results = await asyncio.gather(
        *(fetch_category(code) for code in KAKAO_CATEGORY_CODES)
    )

    seen: set[str] = set()
    merged = []
    for documents in results:
        for document in documents:
            place_id = str(document.get("id", "")).strip()
            if not place_id or place_id in seen:
                continue
            seen.add(place_id)
            merged.append(document)
    return merged


async def _upsert_kakao_places(
    client: httpx.AsyncClient,
    documents: list[dict],
) -> None:
    if not documents:
        return

    now = datetime.now(timezone.utc).isoformat()
    restaurants = []
    mappings = []

    for document in documents:
        place_id = str(document.get("id", "")).strip()
        if not place_id:
            continue

        restaurant_id = f"REST_KAKAO_{place_id}"
        address = document.get("address_name", "") or ""
        road_address = document.get("road_address_name", "") or ""
        place_url = document.get("place_url", "") or ""

        restaurants.append(
            {
                "id": restaurant_id,
                "name": document.get("place_name", "") or "",
                "category_name": document.get("category_name", "") or "",
                "category_group_code": document.get("category_group_code", "") or "",
                "category_group_name": document.get("category_group_name", "") or "",
                "phone": document.get("phone", "") or "",
                "address_name": address,
                "road_address_name": road_address,
                "place_url": place_url,
                "lat": _as_float(document.get("y")),
                "lng": _as_float(document.get("x")),
                "updated_at": now,
            }
        )
        mappings.append(
            {
                "restaurant_id": restaurant_id,
                "source": "kakao",
                "external_place_id": place_id,
                "external_url": place_url,
                "raw_name": document.get("place_name", "") or "",
                "raw_address": road_address or address,
                "updated_at": now,
            }
        )

    if restaurants:
        await client.post(
            f"{SUPABASE_URL}/rest/v1/restaurants",
            headers=_headers("resolution=merge-duplicates"),
            json=restaurants,
            timeout=10,
        )

    if mappings:
        await client.post(
            f"{SUPABASE_URL}/rest/v1/restaurant_place_mappings",
            headers=_headers("resolution=merge-duplicates"),
            json=mappings,
            timeout=10,
        )


def _score_issue_chips_from_keywords(
    issue_keywords: list[dict],
    query_norm: str,
) -> tuple[list[dict], list[str]]:
    query_key = _match_key(query_norm)
    results = []
    matched_ids = []

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

        matched_ids.append(str(keyword.get("id", "")))
        results.append(
            {
                "id": keyword.get("id", ""),
                "label": keyword.get("label", ""),
                "keyword": keyword.get("keyword", ""),
                "score": keyword.get("base_score", _SCORE["issue_tag"]),
            }
        )

    results.sort(key=lambda item: item["score"], reverse=True)
    return results[:_ISSUE_CHIP_LIMIT], matched_ids


def _chips_from_keyword_stats(
    stats: list[dict],
    issue_keywords: list[dict],
) -> list[dict]:
    keyword_by_id = {keyword.get("id"): keyword for keyword in issue_keywords}
    chips = []
    for stat in stats:
        keyword = keyword_by_id.get(stat.get("issue_keyword_id"))
        if not keyword:
            continue
        chips.append(
            {
                "id": keyword.get("id", ""),
                "label": keyword.get("label", ""),
                "keyword": keyword.get("keyword", ""),
                "score": keyword.get("base_score", _SCORE["issue_tag"]),
            }
        )
    return chips[:_ISSUE_CHIP_LIMIT]


def _chips_from_trending(trending: list[dict]) -> list[dict]:
    return [
        {
            "id": str(chip.get("id", "")),
            "label": chip.get("label", ""),
            "keyword": chip.get("label", ""),
            "score": 0,
        }
        for chip in trending[:_ISSUE_CHIP_LIMIT]
        if chip.get("label")
    ]


def _build_related_categories(
    query_norm: str,
    rows: list[dict],
) -> list[dict]:
    query_key = _match_key(query_norm)
    if not query_key or not rows:
        return []

    matched_rows = []
    for row in rows:
        trigger_keys = [_match_key(trigger) for trigger in (row.get("triggers") or [])]
        is_exclusive = bool(row.get("is_exclusive"))
        matched = any(
            trigger_key
            and (
                trigger_key in query_key
                or (
                    is_exclusive
                    and len(query_key) >= 3
                    and query_key in trigger_key
                )
                or (not is_exclusive and query_key in trigger_key)
            )
            for trigger_key in trigger_keys
        )
        if matched:
            matched_rows.append(row)

    exclusive_rows = [row for row in matched_rows if row.get("is_exclusive")]
    source_rows = exclusive_rows or matched_rows

    categories = []
    seen_ids: set[str] = set()
    seen_labels: set[str] = set()
    for row in source_rows:
        category_id = str(row.get("id", "")).strip()
        label = str(row.get("label", "")).strip()
        if (
            not category_id
            or not label
            or category_id in seen_ids
            or label in seen_labels
        ):
            continue

        seen_ids.add(category_id)
        seen_labels.add(label)
        categories.append(
            {
                "id": category_id,
                "label": label,
                "keyword": row.get("keyword") or label,
                "score": 80 - len(categories),
                "groupKey": row.get("group_key") or "",
                "isExclusive": bool(row.get("is_exclusive")),
            }
        )
        if len(categories) >= _RELATED_CATEGORY_LIMIT:
            break

    return categories


def _is_cafe_intent(related_categories: list[dict]) -> bool:
    return any(
        category.get("groupKey") == "cafe"
        and not category.get("isExclusive")
        for category in related_categories
    )


def _dedupe_restaurants(restaurants: list[dict]) -> list[dict]:
    seen: set[str] = set()
    result = []
    for restaurant in restaurants:
        restaurant_id = str(restaurant.get("id", "")).strip()
        if not restaurant_id or restaurant_id in seen:
            continue
        seen.add(restaurant_id)
        result.append(restaurant)
    return result


def _dedupe_menus(menus: list[dict]) -> list[dict]:
    seen: set[str] = set()
    result = []
    for menu in menus:
        menu_id = str(menu.get("id", "")).strip()
        if not menu_id or menu_id in seen:
            continue
        seen.add(menu_id)
        result.append(menu)
    return result


def _attach_restaurant_names(
    menus: list[dict],
    restaurants: list[dict],
) -> list[dict]:
    restaurant_names = {
        str(restaurant.get("id", "")): restaurant.get("name", "")
        for restaurant in restaurants
        if restaurant.get("id") and restaurant.get("name")
    }
    for menu in menus:
        if not menu.get("restaurant_name"):
            restaurant_name = restaurant_names.get(str(menu.get("restaurant_id", "")))
            if restaurant_name:
                menu["restaurant_name"] = restaurant_name
    return menus


def _restaurant_score_map(
    query_norm: str,
    restaurants: list[dict],
) -> dict[str, int]:
    scores: dict[str, int] = {}
    for restaurant in restaurants:
        restaurant_id = str(restaurant.get("id", "")).strip()
        if not restaurant_id:
            continue
        score = _match_score(
            query_norm,
            restaurant.get("name", ""),
            _SCORE["restaurant_exact"],
            _SCORE["restaurant_prefix"],
            _SCORE["restaurant_partial"],
        )
        if score > 0:
            scores[restaurant_id] = score
    return scores


def _build_suggestions(
    query_norm: str,
    menus: list[dict],
    restaurants: list[dict],
) -> dict:
    scored_menus = []
    for menu in menus:
        score = _match_score(
            query_norm,
            menu.get("name", ""),
            _SCORE["menu_exact"],
            _SCORE["menu_prefix"],
            _SCORE["menu_partial"],
        )
        if score > 0:
            scored_menus.append({"menu": menu, "score": score})
    scored_menus.sort(key=lambda item: item["score"], reverse=True)

    scored_restaurants = []
    for restaurant in restaurants:
        score = _match_score(
            query_norm,
            restaurant.get("name", ""),
            _SCORE["restaurant_exact"],
            _SCORE["restaurant_prefix"],
            _SCORE["restaurant_partial"],
        )
        if score > 0:
            scored_restaurants.append({"restaurant": restaurant, "score": score})

    restaurant_suggestions_by_id: dict[str, dict] = {}
    for item in scored_restaurants:
        restaurant = item["restaurant"]
        restaurant_id = str(restaurant.get("id", "")).strip()
        if not restaurant_id:
            continue
        restaurant_suggestions_by_id[restaurant_id] = {
            "id": restaurant_id,
            "name": restaurant.get("name", ""),
            "score": item["score"],
        }

    for item in scored_menus:
        menu = item["menu"]
        restaurant_id = str(menu.get("restaurant_id", "")).strip()
        restaurant_name = str(menu.get("restaurant_name", "")).strip()
        if not restaurant_id or not restaurant_name:
            continue

        score = max(item["score"] - 5, 1)
        current = restaurant_suggestions_by_id.get(restaurant_id)
        if current is None or score > current["score"]:
            restaurant_suggestions_by_id[restaurant_id] = {
                "id": restaurant_id,
                "name": restaurant_name,
                "score": score,
            }

    scored_restaurant_suggestions = sorted(
        restaurant_suggestions_by_id.values(),
        key=lambda item: item["score"],
        reverse=True,
    )

    return {
        "menus": [
            {
                "id": str(item["menu"].get("id", "")),
                "name": item["menu"].get("name", ""),
                "matchedText": query_norm,
                "score": item["score"],
            }
            for item in scored_menus[:_SUGGESTION_LIMIT]
        ],
        "restaurants": scored_restaurant_suggestions[:_SUGGESTION_LIMIT],
    }


def _build_quick_previews(
    query_norm: str,
    menus: list[dict],
    review_stats: dict[str, int],
    restaurant_scores: dict[str, int] | None = None,
    fallback_restaurant_scores: dict[str, int] | None = None,
    allow_best_fallback: bool = False,
) -> list[dict]:
    restaurant_scores = restaurant_scores or {}
    fallback_restaurant_scores = fallback_restaurant_scores or {}
    scored = []
    for menu in menus:
        menu_score = _match_score(
            query_norm,
            menu.get("name", ""),
            _SCORE["menu_exact"],
            _SCORE["menu_prefix"],
            _SCORE["menu_partial"],
        )
        restaurant_name_score = _match_score(
            query_norm,
            menu.get("restaurant_name", ""),
            _SCORE["restaurant_exact"],
            _SCORE["restaurant_prefix"],
            _SCORE["restaurant_partial"],
        )
        restaurant_id = str(menu.get("restaurant_id", ""))
        restaurant_score = restaurant_scores.get(restaurant_id, 0)
        fallback_score = fallback_restaurant_scores.get(restaurant_id, 0)
        is_best = bool(menu.get("is_best"))

        if (
            menu_score == 0
            and restaurant_name_score == 0
            and restaurant_score == 0
            and fallback_score == 0
            and not allow_best_fallback
        ):
            continue

        score = max(
            menu_score,
            restaurant_name_score,
            restaurant_score,
            fallback_score,
        )
        if score == 0 and allow_best_fallback:
            score = 55
        if is_best:
            score += 8
        score += min(review_stats.get(menu.get("restaurant_id", ""), 0), _SCORE["review_keyword"])
        scored.append(
            {
                "menu": menu,
                "score": score,
                "menuScore": menu_score,
                "restaurantNameScore": restaurant_name_score,
                "restaurantScore": restaurant_score,
                "fallbackScore": fallback_score,
                "usedBestFallback": (
                    menu_score == 0
                    and restaurant_name_score == 0
                    and restaurant_score == 0
                ),
            }
        )
    scored.sort(key=lambda item: item["score"], reverse=True)

    has_restaurant_name_match = any(
        item["restaurantNameScore"] > 0 or item["restaurantScore"] > 0
        for item in scored
    )
    if has_restaurant_name_match:
        ranked = scored[:_PREVIEW_LIMIT]
    else:
        best_by_restaurant: dict[str, dict] = {}
        for item in scored:
            restaurant_id = item["menu"].get("restaurant_id", "")
            if (
                restaurant_id not in best_by_restaurant
                or item["score"] > best_by_restaurant[restaurant_id]["score"]
            ):
                best_by_restaurant[restaurant_id] = item

        ranked = sorted(
            best_by_restaurant.values(),
            key=lambda item: item["score"],
            reverse=True,
        )[:_PREVIEW_LIMIT]

    previews = []
    for item in ranked:
        menu = item["menu"]
        score = item["score"]
        price = menu.get("price")
        menu_name = menu.get("name", "")
        base_score = item["menuScore"]
        if base_score == _SCORE["menu_exact"]:
            reason = "메뉴명 완전일치"
        elif base_score == _SCORE["menu_prefix"]:
            reason = "메뉴명 앞부분 일치"
        elif base_score > 0:
            reason = "메뉴명 부분일치"
        elif item["restaurantNameScore"] > 0:
            reason = "가게명 일치 메뉴"
        elif item["restaurantScore"] > 0:
            reason = "식당명 일치 베스트 메뉴"
        elif item["fallbackScore"] > 0:
            reason = "가까운 카페 베스트 메뉴"
        else:
            reason = "가까운 카페 베스트 메뉴"

        previews.append(
            {
                "restaurantId": menu.get("restaurant_id", ""),
                "restaurantName": menu.get("restaurant_name")
                or menu.get("restaurant_id", ""),
                "menuId": str(menu.get("id", "")),
                "menuName": menu_name,
                "price": price,
                "priceLabel": _format_price(price, menu.get("price_label")),
                "imageUrl": menu.get("image_url"),
                "score": score,
                "matchReason": reason,
            }
        )
    return previews


def _restaurant_to_result(
    restaurant: dict,
    lat: float | None,
    lng: float | None,
) -> dict:
    restaurant_lat = _as_float(restaurant.get("lat"))
    restaurant_lng = _as_float(restaurant.get("lng"))
    address = restaurant.get("road_address_name") or restaurant.get("address_name") or ""

    return {
        "id": restaurant.get("id", ""),
        "storeId": restaurant.get("id", ""),
        "name": restaurant.get("name", ""),
        "address": address,
        "category": restaurant.get("category_name") or restaurant.get("category_group_name") or "",
        "categoryName": restaurant.get("category_name"),
        "categoryGroupCode": restaurant.get("category_group_code"),
        "categoryGroupName": restaurant.get("category_group_name"),
        "lat": restaurant_lat or 0,
        "lng": restaurant_lng or 0,
        "phone": restaurant.get("phone"),
        "link": restaurant.get("place_url"),
        "placeUrl": restaurant.get("place_url"),
        "distance": _distance_meters(lat, lng, restaurant_lat, restaurant_lng),
        "reviewSummary": restaurant.get("name", ""),
    }


def _kakao_doc_to_result(
    document: dict,
    lat: float | None,
    lng: float | None,
) -> dict:
    place_id = str(document.get("id", "")).strip()
    restaurant_lat = _as_float(document.get("y"))
    restaurant_lng = _as_float(document.get("x"))
    address = document.get("road_address_name") or document.get("address_name") or ""

    return {
        "id": f"REST_KAKAO_{place_id}",
        "storeId": f"REST_KAKAO_{place_id}",
        "name": document.get("place_name", ""),
        "address": address,
        "category": document.get("category_name", ""),
        "categoryName": document.get("category_name", ""),
        "categoryGroupCode": document.get("category_group_code", ""),
        "categoryGroupName": document.get("category_group_name", ""),
        "lat": restaurant_lat or 0,
        "lng": restaurant_lng or 0,
        "phone": document.get("phone", ""),
        "link": document.get("place_url", ""),
        "placeUrl": document.get("place_url", ""),
        "distance": _distance_meters(lat, lng, restaurant_lat, restaurant_lng),
        "reviewSummary": document.get("place_name", ""),
    }


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


@router.get("/trending")
async def get_trending_chips(
    authorization: str | None = Header(default=None),
):
    _require_supabase()

    async with httpx.AsyncClient() as client:
        chips = await _fetch_trending_chips(client)
    return {"chips": chips}


@router.get("/preview")
async def get_search_preview(
    query: str = Query(..., min_length=1, max_length=100),
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    authorization: str | None = Header(default=None),
):
    _require_supabase()

    query_norm = _normalize(query)
    query_key = _match_key(query)

    if len(query_key) < _MIN_QUERY_LENGTH:
        return {
            "query": query,
            "relatedCategories": [],
            "issueChips": [],
            "suggestions": {"menus": [], "restaurants": []},
            "quickPreviews": [],
        }

    async with httpx.AsyncClient() as client:
        (
            issue_keywords,
            menus,
            restaurants,
            restaurant_name_menus,
            keyword_stats,
            trending,
            related_keyword_rows,
        ) = await asyncio.gather(
            _fetch_active_issue_keywords(client),
            _fetch_menus_by_query(client, query_norm),
            _fetch_restaurants_by_query(client, query_norm),
            _fetch_menus_by_restaurant_name_query(client, query_norm),
            _fetch_keyword_stats(client, query_key),
            _fetch_trending_chips(client),
            _fetch_related_keyword_rows(client),
        )

        related_categories = _build_related_categories(
            query_norm,
            related_keyword_rows,
        )
        cafe_intent = _is_cafe_intent(related_categories)

        if keyword_stats:
            issue_chips = _chips_from_keyword_stats(keyword_stats, issue_keywords)
        else:
            issue_chips, matched_ids = _score_issue_chips_from_keywords(
                issue_keywords,
                query_norm,
            )
            if not issue_chips and not related_categories:
                issue_chips = _chips_from_trending(trending)
            await _upsert_keyword_stats(client, query_key, matched_ids)

        preview_restaurants = restaurants
        fallback_restaurant_scores: dict[str, int] = {}
        if cafe_intent:
            cafe_restaurants = await _fetch_cafe_restaurants(client, lat, lng)
            preview_restaurants = _dedupe_restaurants(restaurants + cafe_restaurants)
            fallback_restaurant_scores = {
                str(restaurant.get("id", "")): max(55, 75 - index)
                for index, restaurant in enumerate(cafe_restaurants)
                if restaurant.get("id")
            }

        restaurant_ids_for_preview = [
            str(restaurant.get("id", ""))
            for restaurant in preview_restaurants
            if restaurant.get("id")
        ]
        restaurant_menus = await _fetch_menus_by_restaurant_ids(
            client,
            restaurant_ids_for_preview,
            limit=max(30, _PREVIEW_LIMIT * 10),
        )
        preview_menus = _attach_restaurant_names(
            _dedupe_menus(menus + restaurant_name_menus + restaurant_menus),
            preview_restaurants,
        )

        restaurant_ids = list(
            {
                str(menu.get("restaurant_id", ""))
                for menu in preview_menus
                if menu.get("restaurant_id")
            }
        )
        issue_ids = [
            str(keyword.get("id", ""))
            for keyword in issue_keywords
            if keyword.get("id")
        ]
        stats_rows = await _fetch_review_keyword_stats(
            client,
            restaurant_ids,
            issue_ids,
        )

    restaurant_scores = _restaurant_score_map(query_norm, restaurants)
    review_stats: dict[str, int] = {}
    for row in stats_rows:
        restaurant_id = str(row.get("restaurant_id", ""))
        review_stats[restaurant_id] = review_stats.get(restaurant_id, 0) + (
            row.get("positive_count") or 0
        )

    return {
        "query": query,
        "relatedCategories": related_categories,
        "issueChips": issue_chips,
        "suggestions": _build_suggestions(query_norm, menus, restaurants),
        "quickPreviews": _build_quick_previews(
            query_norm,
            preview_menus,
            review_stats,
            restaurant_scores=restaurant_scores,
            fallback_restaurant_scores=fallback_restaurant_scores,
            allow_best_fallback=cafe_intent,
        ),
    }


@router.get("/results")
async def get_search_results(
    query: str = Query(..., min_length=1, max_length=100),
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    authorization: str | None = Header(default=None),
):
    _require_supabase()
    await _get_auth_email_required(authorization)

    query_norm = _normalize(query)
    query_key = _match_key(query)

    if len(query_key) < _MIN_QUERY_LENGTH:
        return {"query": query, "results": [], "source": "ignored"}

    async with httpx.AsyncClient() as client:
        internal_restaurants, cache_hit = await asyncio.gather(
            _fetch_restaurants_by_query(client, query_norm, limit=30),
            _fetch_search_cache(client, query_key),
        )

        if cache_hit:
            return {
                "query": query,
                "results": [
                    _restaurant_to_result(restaurant, lat, lng)
                    for restaurant in internal_restaurants
                ],
                "source": "internal",
            }

        kakao_documents = await _fetch_kakao_places(client, query, lat, lng)
        await asyncio.gather(
            _upsert_kakao_places(client, kakao_documents),
            _upsert_search_cache(client, query_key, len(kakao_documents)),
        )

    internal_ids = {str(restaurant.get("id", "")) for restaurant in internal_restaurants}
    results = [
        _restaurant_to_result(restaurant, lat, lng)
        for restaurant in internal_restaurants
    ]
    for document in kakao_documents:
        result = _kakao_doc_to_result(document, lat, lng)
        if result["id"] in internal_ids:
            continue
        results.append(result)

    results.sort(key=lambda item: item.get("distance", 0))
    return {"query": query, "results": results, "source": "kakao"}


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
        raise HTTPException(status_code=400, detail="검색어가 비어 있습니다")
    if body.clickedType not in _VALID_CLICKED_TYPES:
        raise HTTPException(status_code=422, detail="유효하지 않은 clickedType")

    row = {
        key: value
        for key, value in {
            "user_email": email,
            "query": query,
            "clicked_type": body.clickedType,
            "clicked_id": body.clickedId,
            "clicked_label": body.clickedLabel,
            "restaurant_id": body.restaurantId,
            "menu_id": body.menuId,
        }.items()
        if value is not None
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/user_search_histories",
            headers=_headers("return=representation"),
            json=row,
            timeout=5,
        )

    if response.status_code not in (200, 201):
        raise HTTPException(status_code=502, detail="검색 기록 저장 실패")

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
            params={"id": f"eq.{history_id}", "user_email": f"eq.{email}"},
            timeout=5,
        )
    if response.status_code not in (200, 204):
        raise HTTPException(status_code=502, detail="삭제 실패")


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
        raise HTTPException(status_code=502, detail="전체 삭제 실패")
