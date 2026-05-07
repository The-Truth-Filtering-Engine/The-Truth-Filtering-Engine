"""
supabase_service.py
- 검색 결과를 Supabase reviews 테이블에 자동 저장
- 광고 판별 결과 업데이트 (electra, finetuned, llm)
- 캐시 조회, AI 추천 조회 등 모든 DB 접근 통합
"""
import os
import httpx
from typing import Optional
from services.review_limits import MAX_REVIEW_RESULTS, clamp_max_results

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY", "")

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
            # 판별 결과는 초기에 null → 이후 update_* 함수로 채움
            "is_ad_electra_pred": None,
            "is_ad_finetuned_pred": None,
            "is_ad_llm_pred": None,
        }
        for b in blogs
    ]

    async with httpx.AsyncClient() as client:
        await client.post(
            f"{SUPABASE_URL}/rest/v1/reviews",
            headers=_h("resolution=ignore-duplicates"),  # 중복 무시
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

async def update_electra_pred(review_id: str, is_ad: int) -> None:
    """Electra 이진 판별 결과 저장."""
    await _patch_review(review_id, {"is_ad_electra_pred": int(is_ad)})


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

async def get_ai_recommendation_reviews(
    threshold: float = 0.1,
    page: int = 1,
    page_size: int = 10,
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
            params={
                "is_ad_finetuned_pred": f"lte.{threshold}",
                "order": "created_at.desc",
            },
            timeout=10,
        )

    if resp.status_code not in (200, 206):
        return {"items": [], "total": 0, "has_next": False}

    total_str = resp.headers.get("Content-Range", "*/0").split("/")[-1]
    total = int(total_str) if total_str.isdigit() else 0
    items = resp.json() or []
    has_next = offset + len(items) < total

    return {"items": items, "total": total, "has_next": has_next}


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
