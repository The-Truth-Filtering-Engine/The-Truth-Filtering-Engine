"""
supabase_service.py
- 검색 결과를 Supabase reviews 테이블에 자동 저장
- 광고 판별 결과 업데이트 (electra, finetuned, llm)
- 캐시 조회, AI 추천 조회 등 모든 DB 접근 통합
"""
import os
import httpx
from typing import Optional

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

async def save_reviews(query: str, blogs: list[dict]) -> None:
    """
    Naver 블로그 수집 결과를 reviews 테이블에 저장.
    이미 같은 query + link 가 있으면 upsert로 중복 방지.
    """
    if not SUPABASE_URL or not blogs:
        return

    rows = [
        {
            "query": query,
            "review_title": b.get("title", ""),
            "review_description": b.get("description", ""),
            "review_bloggername": b.get("bloggername", ""),
            "review_bloggerlink": b.get("bloggerlink", ""),
            "review_link": b.get("link", ""),
            "review_postdate": b.get("postdate"),
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


# ══════════════════════════════════════════════════════════════════════════════
# 캐시 조회
# ══════════════════════════════════════════════════════════════════════════════

async def get_cached_reviews(query: str) -> list[dict]:
    """같은 query 로 저장된 리뷰가 있으면 반환, 없으면 빈 리스트."""
    if not SUPABASE_URL:
        return []

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/rest/v1/reviews",
            headers=_h(),
            params={
                "query": f"eq.{query}",
                "order": "created_at.desc",
            },
            timeout=10,
        )

    if resp.status_code != 200:
        return []
    return resp.json() or []


# ══════════════════════════════════════════════════════════════════════════════
# 판별 결과 업데이트 (search.py 에서 호출)
# ══════════════════════════════════════════════════════════════════════════════

async def update_electra_pred(review_id: str, is_ad: int) -> None:
    """Electra 이진 판별 결과 저장."""
    await _patch_review(review_id, {"is_ad_electra_pred": bool(is_ad)})


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
        return {"items": [], "total": 0}

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
        return {"items": [], "total": 0}

    total_str = resp.headers.get("Content-Range", "*/0").split("/")[-1]
    total = int(total_str) if total_str.isdigit() else 0

    return {"items": resp.json() or [], "total": total}


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