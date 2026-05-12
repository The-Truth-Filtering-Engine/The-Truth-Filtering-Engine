"""
supabase_service.py
- 검색 결과를 Supabase reviews 테이블에 자동 저장
- 광고 판별 결과 업데이트 (electra, finetuned, llm)
- 캐시 조회, AI 추천 조회 등 모든 DB 접근 통합
"""
import os
import httpx
from datetime import datetime, timedelta, timezone
from typing import Optional
from services.review_limits import MAX_REVIEW_RESULTS, clamp_max_results

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_KEY", "")
)
USER_PROFILE_SELECT = "id,email,premium,coin,freecount,premiumcount,store,bookmark"
ANALYSIS_COIN_COST = 100
ANALYSIS_USAGE_REQUIRED_MESSAGE = "추가분석을 위해 코인을 충전해 주세요"
KST = timezone(timedelta(hours=9))
KAKAO_REST_API_KEY = os.getenv("KAKAO_REST_API_KEY", "").strip()
KAKAO_LOCAL_KEYWORD_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"
KAKAO_PLACE_CATEGORY_CODES = ("FD6", "CE7")


class AnalysisUsageError(RuntimeError):
    pass

# ── 공통 헤더 ────────────────────────────────────────────────────────────────

def _h(prefer: str = "") -> dict:
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    return headers


# ══════════════════════════════════════════════════════════════════════════════
# 리뷰 저장 (검색 시 자동 호출)
# ══════════════════════════════════════════════════════════════════════════════

async def save_reviews(
    query: str,
    blogs: list[dict],
    place_metadata: dict | None = None,
) -> None:
    """
    Naver 블로그 수집 결과를 reviews 테이블에 저장.
    장소 메타데이터가 있으면 같은 상호명의 다른 지점이 섞이지 않도록 함께 저장.
    """
    if not SUPABASE_URL or not blogs:
        return

    metadata = _normalize_place_metadata(query, place_metadata)

    rows = [
        {
            "name": metadata["name"],
            "review_title": b.get("title", ""),
            "review_description": b.get("description", ""),
            "review_bloggername": b.get("bloggername", ""),
            "review_url": b.get("link", ""),
            "review_postdate": b.get("postdate"),
            "store_id": metadata["store_id"],
            "category_name": metadata["category_name"],
            "category_group_code": metadata["category_group_code"],
            "category_group_name": metadata["category_group_name"],
            "phone": metadata["phone"],
            "address_name": metadata["address_name"],
            "road_address_name": metadata["road_address_name"],
            "place_url": metadata["place_url"],
            "is_ad_finetuned_pred": None,
        }
        for b in blogs
    ]

    async with httpx.AsyncClient() as client:
        await client.post(
            f"{SUPABASE_URL}/rest/v1/reviews",
            headers=_h("resolution=ignore-duplicates"),  # 중복 무시
            params={"on_conflict": "review_url"},
            json=rows,
            timeout=15,
        )


def _normalize_place_metadata(query: str, place_metadata: dict | None) -> dict:
    metadata = place_metadata or {}
    return {
        "name": _text_or_none(metadata.get("name")) or query,
        "store_id": _text_or_none(metadata.get("store_id")),
        "category_name": _text_or_none(metadata.get("category_name")),
        "category_group_code": _text_or_none(metadata.get("category_group_code")),
        "category_group_name": _text_or_none(metadata.get("category_group_name")),
        "phone": _text_or_none(metadata.get("phone")),
        "address_name": _text_or_none(metadata.get("address_name")),
        "road_address_name": _text_or_none(metadata.get("road_address_name")),
        "place_url": _text_or_none(metadata.get("place_url")),
    }


def _text_or_none(value) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _int_or_zero(value) -> int:
    if value is None:
        return 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _require_supabase_config() -> None:
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise RuntimeError("Supabase 설정이 없습니다")


def _normalize_user_profile(row: dict) -> dict:
    return {
        "id": _int_or_zero(row.get("id")),
        "email": _text_or_none(row.get("email")) or "",
        "premium": _int_or_zero(row.get("premium")),
        "coin": _int_or_zero(row.get("coin")),
        "freecount": _int_or_zero(row.get("freecount")),
        "premiumcount": _int_or_zero(row.get("premiumcount")),
        "store": row.get("store"),
        "bookmark": row.get("bookmark"),
    }


# ══════════════════════════════════════════════════════════════════════════════
# 사용자 프로필 (Supabase Auth 토큰 기반)
# ══════════════════════════════════════════════════════════════════════════════

async def get_auth_email(access_token: str) -> str | None:
    """Supabase access token으로 인증된 사용자의 email을 조회."""
    _require_supabase_config()
    token = _text_or_none(access_token)
    if not token:
        return None

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {token}",
            },
            timeout=10,
        )

    if resp.status_code != 200:
        return None

    data = resp.json() or {}
    return _text_or_none(data.get("email"))


async def ensure_user_profile(email: str) -> dict:
    """email 기준으로 users row를 조회하고, 없으면 기본값으로 생성."""
    _require_supabase_config()
    normalized_email = _text_or_none(email)
    if not normalized_email:
        raise RuntimeError("사용자 이메일이 없습니다")

    async with httpx.AsyncClient() as client:
        existing = await _fetch_user_profile_by_email(client, normalized_email)
        if existing:
            return existing

        resp = await client.post(
            f"{SUPABASE_URL}/rest/v1/users",
            headers=_h("resolution=merge-duplicates,return=representation"),
            params={
                "on_conflict": "email",
                "select": USER_PROFILE_SELECT,
            },
            json={"email": normalized_email},
            timeout=10,
        )

        if resp.status_code not in (200, 201):
            raise RuntimeError(
                f"사용자 프로필을 생성하지 못했습니다: "
                f"{resp.status_code} {resp.text[:240]}"
            )

        rows = resp.json() or []
        if rows:
            return _normalize_user_profile(rows[0])

        created = await _fetch_user_profile_by_email(client, normalized_email)
        if created:
            return created

    raise RuntimeError("사용자 프로필을 조회하지 못했습니다")


async def set_user_premium(email: str, enabled: bool) -> dict:
    normalized_email = _text_or_none(email)
    if not normalized_email:
        raise RuntimeError("사용자 이메일이 없습니다")

    await ensure_user_profile(normalized_email)
    return await _patch_user_profile(
        normalized_email,
        {"premium": 1 if enabled else 0},
    )


async def add_user_coins(email: str, amount: int) -> dict:
    normalized_email = _text_or_none(email)
    if not normalized_email:
        raise RuntimeError("사용자 이메일이 없습니다")

    profile = await ensure_user_profile(normalized_email)
    next_coin = _int_or_zero(profile.get("coin")) + int(amount)
    return await _patch_user_profile(normalized_email, {"coin": next_coin})


async def has_analysis_usage(email: str, store_id: str | None = None) -> bool:
    profile = await ensure_user_profile(email)
    normalized_store_id = _text_or_none(store_id)
    if normalized_store_id and not _should_charge_store_detail(
        profile.get("store"),
        normalized_store_id,
    ):
        return True
    return _has_analysis_usage(profile)


async def consume_analysis_usage(email: str, store_id: str | None = None) -> dict:
    normalized_email = _text_or_none(email)
    normalized_store_id = _text_or_none(store_id)
    if not normalized_email:
        raise RuntimeError("사용자 이메일이 없습니다")

    await ensure_user_profile(normalized_email)

    for _ in range(3):
        profile = await ensure_user_profile(normalized_email)
        freecount = _int_or_zero(profile.get("freecount"))
        premiumcount = _int_or_zero(profile.get("premiumcount"))
        coin = _int_or_zero(profile.get("coin"))
        store_date_map = _normalize_store_date_map(profile.get("store"))

        if normalized_store_id and not _should_charge_store_detail(
            store_date_map,
            normalized_store_id,
        ):
            return _build_analysis_usage_not_charged(profile)

        store_update = (
            _with_today_store_date(store_date_map, normalized_store_id)
            if normalized_store_id
            else None
        )

        if freecount > 0:
            data = {"freecount": freecount - 1}
            if store_update is not None:
                data["store"] = store_update
            updated = await _patch_user_profile_if_current(
                normalized_email,
                data=data,
                match={"freecount": freecount},
            )
            if updated:
                return _build_analysis_usage("freecount", updated)
            continue

        if premiumcount > 0:
            data = {"premiumcount": premiumcount - 1}
            if store_update is not None:
                data["store"] = store_update
            updated = await _patch_user_profile_if_current(
                normalized_email,
                data=data,
                match={"premiumcount": premiumcount},
            )
            if updated:
                return _build_analysis_usage("premiumcount", updated)
            continue

        if coin >= ANALYSIS_COIN_COST:
            data = {"coin": coin - ANALYSIS_COIN_COST}
            if store_update is not None:
                data["store"] = store_update
            updated = await _patch_user_profile_if_current(
                normalized_email,
                data=data,
                match={"coin": coin},
            )
            if updated:
                return _build_analysis_usage("coin", updated)
            continue

        raise AnalysisUsageError(ANALYSIS_USAGE_REQUIRED_MESSAGE)

    profile = await ensure_user_profile(normalized_email)
    if not _has_analysis_usage(profile):
        raise AnalysisUsageError(ANALYSIS_USAGE_REQUIRED_MESSAGE)

    raise RuntimeError("분석 사용량을 차감하지 못했습니다")


async def get_user_bookmarks(email: str) -> dict:
    profile = await ensure_user_profile(email)
    return _normalize_user_bookmarks(profile)


async def get_user_recent_analyses(email: str) -> dict:
    profile = await ensure_user_profile(email)
    store_date_map = _normalize_store_date_map(profile.get("store"))
    today = datetime.now(KST).date()
    today_text = today.strftime("%Y%m%d")

    if not store_date_map:
        return {"today": today_text, "freeItems": [], "expiredItems": []}

    recent_entries = []
    for store_id, date_text in store_date_map.items():
        try:
            analyzed_date = datetime.strptime(date_text, "%Y%m%d").date()
        except ValueError:
            analyzed_date = None

        days_elapsed = (
            max(0, (today - analyzed_date).days) if analyzed_date else None
        )
        recent_entries.append(
            {
                "storeId": store_id,
                "analyzedDate": date_text,
                "daysElapsed": days_elapsed,
                "remainingFreeDays": 1
                if days_elapsed is not None and days_elapsed < 2
                else 0,
                "restaurant": None,
            }
        )

    async with httpx.AsyncClient(timeout=6.0) as client:
        for item in recent_entries:
            store_id = item["storeId"]
            review = await _fetch_latest_review_for_store(client, store_id)
            place = await _find_kakao_place_for_recent_analysis(
                client,
                store_id=store_id,
                review=review,
            )
            item["restaurant"] = _recent_analysis_restaurant(
                store_id=store_id,
                review=review,
                place=place,
            )

    recent_entries.sort(
        key=lambda item: (
            item.get("analyzedDate") or "",
            item.get("restaurant", {}).get("name") or "",
        ),
        reverse=True,
    )

    free_items = [
        item
        for item in recent_entries
        if isinstance(item.get("daysElapsed"), int) and item["daysElapsed"] < 2
    ]
    expired_items = [
        item
        for item in recent_entries
        if not isinstance(item.get("daysElapsed"), int)
        or item.get("daysElapsed", 0) >= 2
    ]

    return {
        "today": today_text,
        "freeItems": free_items,
        "expiredItems": expired_items,
    }


async def _fetch_latest_review_for_store(
    client: httpx.AsyncClient,
    store_id: str,
) -> dict | None:
    resp = await client.get(
        f"{SUPABASE_URL}/rest/v1/reviews",
        headers=_h(),
        params={
            "store_id": f"eq.{store_id}",
            "select": (
                "name,store_id,category_name,category_group_code,"
                "category_group_name,phone,address_name,road_address_name,"
                "place_url,created_at"
            ),
            "order": "created_at.desc",
            "limit": "1",
        },
        timeout=10,
    )

    if resp.status_code != 200:
        return None

    rows = resp.json() if resp.text else []
    return rows[0] if rows else None


async def _find_kakao_place_for_recent_analysis(
    client: httpx.AsyncClient,
    *,
    store_id: str,
    review: dict | None,
) -> dict | None:
    if not KAKAO_REST_API_KEY:
        return None

    name = _text_or_none(review.get("name")) if review else None
    address = _text_or_none(
        (review or {}).get("road_address_name") or (review or {}).get("address_name")
    )
    queries = [name, f"{name} {address}" if name and address else None, store_id]
    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    fallback = None

    for query in [item for item in queries if item]:
        for category_code in KAKAO_PLACE_CATEGORY_CODES:
            response = await client.get(
                KAKAO_LOCAL_KEYWORD_URL,
                headers=headers,
                params={
                    "query": query,
                    "category_group_code": category_code,
                    "size": 5,
                },
                timeout=5,
            )
            if response.status_code != 200:
                continue

            documents = response.json().get("documents", [])
            if not documents:
                continue

            exact = next(
                (
                    document
                    for document in documents
                    if _text_or_none(document.get("id")) == store_id
                ),
                None,
            )
            if exact:
                return exact
            fallback = fallback or documents[0]

    return fallback


def _recent_analysis_restaurant(
    *,
    store_id: str,
    review: dict | None,
    place: dict | None,
) -> dict:
    review = review or {}
    place = place or {}
    place_url = (
        _text_or_none(review.get("place_url"))
        or _text_or_none(place.get("place_url"))
        or ""
    )
    address_name = (
        _text_or_none(review.get("address_name"))
        or _text_or_none(place.get("address_name"))
        or ""
    )
    road_address_name = (
        _text_or_none(review.get("road_address_name"))
        or _text_or_none(place.get("road_address_name"))
        or ""
    )
    lat = _float_or_none(place.get("y"))
    lng = _float_or_none(place.get("x"))

    return {
        "id": store_id,
        "storeId": store_id,
        "name": _text_or_none(review.get("name"))
        or _text_or_none(place.get("place_name"))
        or store_id,
        "address": road_address_name or address_name,
        "category": _text_or_none(review.get("category_name"))
        or _text_or_none(place.get("category_name"))
        or "음식점",
        "categoryName": _text_or_none(review.get("category_name"))
        or _text_or_none(place.get("category_name"))
        or "",
        "categoryGroupCode": _text_or_none(review.get("category_group_code"))
        or _text_or_none(place.get("category_group_code"))
        or "",
        "categoryGroupName": _text_or_none(review.get("category_group_name"))
        or _text_or_none(place.get("category_group_name"))
        or "",
        "distance": 0,
        "phone": _text_or_none(review.get("phone"))
        or _text_or_none(place.get("phone"))
        or "",
        "link": place_url,
        "placeUrl": place_url,
        "addressName": address_name,
        "roadAddressName": road_address_name,
        "lat": lat,
        "lng": lng,
        "latitude": lat,
        "longitude": lng,
    }


async def add_user_bookmark(email: str, store_id: str, store: dict | None) -> dict:
    normalized_email = _text_or_none(email)
    normalized_store_id = _text_or_none(store_id)
    if not normalized_email:
        raise RuntimeError("사용자 이메일이 없습니다")
    if not normalized_store_id:
        raise RuntimeError("storeId가 없습니다")

    profile = await ensure_user_profile(normalized_email)
    bookmark_map = _normalize_bookmark_map(profile.get("bookmark"))
    bookmark_map[normalized_store_id] = _normalize_bookmark_store(
        normalized_store_id,
        store,
        touch=True,
    )

    updated = await _patch_user_profile(
        normalized_email,
        {"bookmark": bookmark_map},
    )
    return _normalize_user_bookmarks(updated)


async def remove_user_bookmark(email: str, store_id: str) -> dict:
    normalized_email = _text_or_none(email)
    normalized_store_id = _text_or_none(store_id)
    if not normalized_email:
        raise RuntimeError("사용자 이메일이 없습니다")
    if not normalized_store_id:
        raise RuntimeError("storeId가 없습니다")

    profile = await ensure_user_profile(normalized_email)
    bookmark_map = _normalize_bookmark_map(profile.get("bookmark"))
    bookmark_map.pop(normalized_store_id, None)

    updated = await _patch_user_profile(
        normalized_email,
        {"bookmark": bookmark_map},
    )
    return _normalize_user_bookmarks(updated)


async def get_user_review_reactions(email: str) -> dict:
    normalized_email = _text_or_none(email)
    if not normalized_email:
        raise RuntimeError("?ъ슜???대찓?쇱씠 ?놁뒿?덈떎")

    await ensure_user_profile(normalized_email)
    async with httpx.AsyncClient() as client:
        reactions = await _fetch_user_review_reactions_by_email(
            client,
            normalized_email,
        )
    return _normalize_user_review_reactions(reactions)


async def update_user_review_reaction(
    email: str,
    review_id: str,
    reaction: str | None,
) -> dict:
    normalized_email = _text_or_none(email)
    normalized_review_id = _text_or_none(review_id)
    if not normalized_email:
        raise RuntimeError("?ъ슜???대찓?쇱씠 ?놁뒿?덈떎")
    if not normalized_review_id:
        raise RuntimeError("reviewId媛 ?놁뒿?덈떎")
    if reaction not in ("like", "dislike", None):
        raise RuntimeError("reaction??like, dislike, null留?媛?ν빀?덈떎")

    await ensure_user_profile(normalized_email)
    async with httpx.AsyncClient() as client:
        current = await _fetch_user_review_reactions_by_email(
            client,
            normalized_email,
        ) or {}

        review_likes = _normalize_review_reaction_map(
            current.get("review_likes")
        )
        review_dislikes = _normalize_review_reaction_map(
            current.get("review_dislikes")
        )

        if reaction == "like":
            review_likes[normalized_review_id] = _normalize_review_reaction(
                normalized_review_id,
                touch=True,
            )
            review_dislikes.pop(normalized_review_id, None)
        elif reaction == "dislike":
            review_dislikes[normalized_review_id] = _normalize_review_reaction(
                normalized_review_id,
                touch=True,
            )
            review_likes.pop(normalized_review_id, None)
        else:
            review_likes.pop(normalized_review_id, None)
            review_dislikes.pop(normalized_review_id, None)

        updated = await _patch_user_review_reactions(
            client,
            normalized_email,
            review_likes,
            review_dislikes,
        )

    return _normalize_user_review_reactions(updated)


def _normalize_user_bookmarks(profile: dict) -> dict:
    bookmark_map = _normalize_bookmark_map(profile.get("bookmark"))
    return {
        "bookmark": bookmark_map,
        "store": profile.get("store") if isinstance(profile.get("store"), dict) else {},
    }


def _normalize_user_review_reactions(profile: dict | None) -> dict:
    profile = profile or {}
    return {
        "review_likes": _normalize_review_reaction_map(
            profile.get("review_likes")
        ),
        "review_dislikes": _normalize_review_reaction_map(
            profile.get("review_dislikes")
        ),
    }


def _normalize_review_reaction_map(value) -> dict:
    if not isinstance(value, dict):
        return {}

    reaction_map = {}
    for key, item in value.items():
        review_id = _text_or_none(key)
        if not review_id:
            continue
        reaction_map[review_id] = _normalize_review_reaction(review_id, item)

    return reaction_map


def _normalize_review_reaction(
    review_id: str,
    reaction: dict | None = None,
    *,
    touch: bool = False,
) -> dict:
    normalized = dict(reaction) if isinstance(reaction, dict) else {}
    normalized["reviewId"] = review_id

    if touch or not _text_or_none(normalized.get("updatedAt")):
        normalized["updatedAt"] = datetime.now(KST).isoformat()

    return normalized


def _normalize_bookmark_map(value) -> dict:
    if not isinstance(value, dict):
        return {}

    bookmark_map = {}
    for key, item in value.items():
        store_id = _text_or_none(key)
        if not store_id or not isinstance(item, dict):
            continue
        bookmark_map[store_id] = _normalize_bookmark_store(store_id, item)

    return bookmark_map


def _normalize_bookmark_store(
    store_id: str,
    store: dict | None,
    *,
    touch: bool = False,
) -> dict:
    normalized = dict(store) if isinstance(store, dict) else {}
    normalized["id"] = _text_or_none(normalized.get("id")) or store_id
    normalized["storeId"] = store_id

    latitude = _float_or_none(normalized.get("latitude"))
    if latitude is None:
        latitude = _float_or_none(normalized.get("lat"))
    longitude = _float_or_none(normalized.get("longitude"))
    if longitude is None:
        longitude = _float_or_none(normalized.get("lng"))

    if latitude is not None:
        normalized["latitude"] = latitude
        normalized["lat"] = latitude
    if longitude is not None:
        normalized["longitude"] = longitude
        normalized["lng"] = longitude

    if touch or not _text_or_none(normalized.get("updatedAt")):
        normalized["updatedAt"] = datetime.now(KST).isoformat()

    return normalized


def _float_or_none(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _normalize_store_date_map(value) -> dict:
    if not isinstance(value, dict):
        return {}

    date_map = {}
    for key, item in value.items():
        store_id = _text_or_none(key)
        date_text = _text_or_none(item)
        if not store_id or not date_text:
            continue
        date_map[store_id] = date_text

    return date_map


def _today_store_date() -> str:
    return datetime.now(KST).strftime("%Y%m%d")


def _with_today_store_date(store_date_map: dict, store_id: str) -> dict:
    next_store_date_map = dict(store_date_map)
    next_store_date_map[store_id] = _today_store_date()
    return next_store_date_map


def _should_charge_store_detail(store_value, store_id: str) -> bool:
    store_date_map = (
        store_value
        if isinstance(store_value, dict)
        else _normalize_store_date_map(store_value)
    )
    last_date_text = _text_or_none(store_date_map.get(store_id))
    if not last_date_text:
        return True

    try:
        last_date = datetime.strptime(last_date_text, "%Y%m%d").date()
    except ValueError:
        return True

    today = datetime.now(KST).date()
    return (today - last_date).days >= 2


def _has_analysis_usage(profile: dict) -> bool:
    return (
        _int_or_zero(profile.get("freecount")) > 0
        or _int_or_zero(profile.get("premiumcount")) > 0
        or _int_or_zero(profile.get("coin")) >= ANALYSIS_COIN_COST
    )


def _build_analysis_usage(charged_by: str, profile: dict) -> dict:
    return {
        "charged": True,
        "chargedBy": charged_by,
        "profile": profile,
    }


def _build_analysis_usage_not_charged(profile: dict | None = None) -> dict:
    return {
        "charged": False,
        "chargedBy": None,
        "profile": profile,
    }


async def _fetch_user_profile_by_email(
    client: httpx.AsyncClient,
    email: str,
) -> dict | None:
    resp = await client.get(
        f"{SUPABASE_URL}/rest/v1/users",
        headers=_h(),
        params={
            "email": f"eq.{email}",
            "select": USER_PROFILE_SELECT,
            "limit": "1",
        },
        timeout=10,
    )

    if resp.status_code != 200:
        raise RuntimeError(
            f"사용자 프로필을 조회하지 못했습니다: "
            f"{resp.status_code} {resp.text[:240]}"
        )

    rows = resp.json() if resp.text else []
    return _normalize_user_profile(rows[0]) if rows else None


async def _fetch_user_review_reactions_by_email(
    client: httpx.AsyncClient,
    email: str,
) -> dict | None:
    resp = await client.get(
        f"{SUPABASE_URL}/rest/v1/users",
        headers=_h(),
        params={
            "email": f"eq.{email}",
            "select": "review_likes,review_dislikes",
            "limit": "1",
        },
        timeout=10,
    )

    if resp.status_code != 200:
        raise RuntimeError(
            "review_likes/review_dislikes 而щ읆???꾩슂?⑸땲?? "
            "supabase/migrations/20260508_add_user_review_reactions.sql瑜? "
            f"?ㅽ뻾??二쇱꽭?? {resp.status_code} {resp.text[:240]}"
        )

    rows = resp.json() if resp.text else []
    return rows[0] if rows else None


async def _patch_user_review_reactions(
    client: httpx.AsyncClient,
    email: str,
    review_likes: dict,
    review_dislikes: dict,
) -> dict:
    resp = await client.patch(
        f"{SUPABASE_URL}/rest/v1/users",
        headers=_h("return=representation"),
        params={
            "email": f"eq.{email}",
            "select": "review_likes,review_dislikes",
        },
        json={
            "review_likes": review_likes,
            "review_dislikes": review_dislikes,
        },
        timeout=10,
    )

    if resp.status_code not in (200, 204):
        raise RuntimeError(
            f"由щ럭 諛섏쓳???ъ슜???꾨줈?꾩뿉 ??ν븯吏 紐삵뻽?듬땲?? "
            f"{resp.status_code} {resp.text[:240]}"
        )

    rows = resp.json() if resp.text else []
    return rows[0] if rows else {
        "review_likes": review_likes,
        "review_dislikes": review_dislikes,
    }


async def _patch_user_profile(email: str, data: dict) -> dict:
    _require_supabase_config()
    async with httpx.AsyncClient() as client:
        resp = await client.patch(
            f"{SUPABASE_URL}/rest/v1/users",
            headers=_h("return=representation"),
            params={
                "email": f"eq.{email}",
                "select": USER_PROFILE_SELECT,
            },
            json=data,
            timeout=10,
        )

    if resp.status_code not in (200, 204):
        raise RuntimeError(
            f"사용자 프로필을 업데이트하지 못했습니다: "
            f"{resp.status_code} {resp.text[:240]}"
        )

    rows = resp.json() if resp.text else []
    if not rows:
        return await ensure_user_profile(email)
    return _normalize_user_profile(rows[0])


async def _patch_user_profile_if_current(
    email: str,
    data: dict,
    match: dict,
) -> dict | None:
    _require_supabase_config()
    params = {
        "email": f"eq.{email}",
        "select": USER_PROFILE_SELECT,
    }
    for key, value in match.items():
        params[key] = f"eq.{value}"

    async with httpx.AsyncClient() as client:
        resp = await client.patch(
            f"{SUPABASE_URL}/rest/v1/users",
            headers=_h("return=representation"),
            params=params,
            json=data,
            timeout=10,
        )

    if resp.status_code not in (200, 204):
        raise RuntimeError(
            f"사용자 프로필을 업데이트하지 못했습니다: "
            f"{resp.status_code} {resp.text[:240]}"
        )

    rows = resp.json() if resp.text else []
    if not rows:
        return None
    return _normalize_user_profile(rows[0])


# ══════════════════════════════════════════════════════════════════════════════
# 캐시 조회
# ══════════════════════════════════════════════════════════════════════════════

async def get_cached_reviews(
    query: str,
    limit: int = MAX_REVIEW_RESULTS,
    store_id: str | None = None,
) -> list[dict]:
    """store_id가 있으면 장소 ID 기준으로, 없으면 기존 query 기준으로 캐시 조회."""
    if not SUPABASE_URL:
        return []

    review_limit = clamp_max_results(limit)
    end = review_limit - 1
    store_id = _text_or_none(store_id)
    lookup_params = (
        {"store_id": f"eq.{store_id}"}
        if store_id
        else {"name": f"eq.{query}"}
    )

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/rest/v1/reviews",
            headers={**_h(), "Range": f"0-{end}", "Range-Unit": "items"},
            params={
                **lookup_params,
                "order": "created_at.desc",
                "limit": str(review_limit),
            },
            timeout=10,
        )

    if resp.status_code not in (200, 206):
        return []
    return resp.json() or []


# ══════════════════════════════════════════════════════════════════════════════
# 판별 결과 업데이트 (search.py 에서 호출)
# ══════════════════════════════════════════════════════════════════════════════

# async def update_electra_pred(review_id: str, is_ad: int) -> None:
#     """Electra 이진 판별 결과 저장."""
#     await _patch_review(review_id, {"is_ad_electra_pred": int(is_ad)})


async def update_finetuned_pred(review_id: str, score: float) -> None:
    """파인튜닝 모델 광고 확률(0~1) 저장."""
    await _patch_review(review_id, {"is_ad_finetuned_pred": round(float(score), 4)})


async def update_llm_pred(review_id: str, score: float) -> None:
    """LLM(GPT) 광고 확률(0~1) 저장."""
    await _patch_review(review_id, {"is_ad_llm_pred": round(float(score), 4)})


async def _patch_review(review_id: str, data: dict) -> None:
    if not SUPABASE_URL:
        return
    async with httpx.AsyncClient() as client:
        await client.patch(
            f"{SUPABASE_URL}/rest/v1/reviews",
            headers=_h("return=minimal"),
            params={"id": f"eq.{review_id}"},
            json=data,
            timeout=10,
        )


# ══════════════════════════════════════════════════════════════════════════════
# AI 추천 (ai_recommend.py 에서 호출)
# ══════════════════════════════════════════════════════════════════════════════

AI_RECOMMEND_REVIEW_ORDER = "is_ad_finetuned_pred.asc,review_postdate.desc,id.desc"


async def get_ai_recommendation_reviews(
    threshold: float = 0.1,
    page: int = 1,
    page_size: int = 10,
    address_terms: list[str] | None = None,
) -> dict:
    """
    광고 확률이 threshold 이하인 리뷰 = 진짜 리뷰로 간주하여 반환.
    페이지네이션 포함.
    """
    if not SUPABASE_URL:
        return {"items": [], "total": 0, "has_next": False}

    offset = (page - 1) * page_size
    end = offset + page_size - 1

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/rest/v1/reviews",
            headers={
                **_h(),
                "Range": f"{offset}-{end}",
                "Range-Unit": "items",
                "Prefer": "count=exact",
            },
            params=_build_ai_recommendation_query_params(
                threshold=threshold,
                address_terms=address_terms,
            ),
            timeout=10,
        )

    if resp.status_code not in (200, 206):
        return {"items": [], "total": 0, "has_next": False}

    total_str = resp.headers.get("Content-Range", "*/0").split("/")[-1]
    total = int(total_str) if total_str.isdigit() else 0
    items = resp.json() or []
    has_next = offset + len(items) < total

    return {"items": items, "total": total, "has_next": has_next}


def _build_ai_recommendation_query_params(
    threshold: float,
    address_terms: list[str] | None = None,
) -> list[tuple[str, str]]:
    params = [
        ("is_ad_finetuned_pred", "not.is.null"),
        ("is_ad_finetuned_pred", f"lte.{threshold}"),
        ("order", AI_RECOMMEND_REVIEW_ORDER),
    ]

    filters = [
        filter_text
        for term in _dedupe_texts(address_terms or [])
        if (filter_text := _postgrest_contains_filter("address_name", term))
    ]
    if filters:
        params.append(("address_name", "not.is.null"))
        params.append(("or", f"({','.join(filters)})"))

    return params


def _dedupe_texts(values: list[str]) -> list[str]:
    seen = set()
    deduped = []
    for value in values:
        text = _text_or_none(value)
        if not text or text in seen:
            continue
        seen.add(text)
        deduped.append(text)
    return deduped


def _postgrest_contains_filter(column: str, value: str) -> str:
    text = _text_or_none(value)
    if not text:
        return ""

    safe_text = (
        text.replace("*", "")
        .replace(",", "")
        .replace("(", "")
        .replace(")", "")
    )
    if not safe_text:
        return ""
    return f"{column}.ilike.*{safe_text}*"


# ══════════════════════════════════════════════════════════════════════════════
# 단건 조회 (report.py 등에서 review_id 검증 시 사용)
# ══════════════════════════════════════════════════════════════════════════════

async def get_review_by_id(review_id: str) -> Optional[dict]:
    if not SUPABASE_URL:
        return None

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/rest/v1/reviews",
            headers=_h(),
            params={"id": f"eq.{review_id}", "limit": "1"},
            timeout=10,
        )

    if resp.status_code != 200:
        return None
    items = resp.json()
    return items[0] if items else None
