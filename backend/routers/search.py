from fastapi import APIRouter, Query
from services.supabase_service import (
    get_cached_reviews, save_reviews,
    update_llm_pred, update_electra_pred, update_finetuned_pred,
)
from services.naver_service import fetch_blog_previews, MAX_TOTAL
from services.llm_service import classify_ad, summarize_reviews
from services.electra_service import predict_is_ad, score_is_ad

router = APIRouter()


# ── 캐시 조회 (페이지네이션) ─────────────────────────────────────────────────

@router.get("/search/cached")
async def search_cached(
    query: str,
    page: int = Query(1, ge=1, description="페이지 번호 (1-based)"),
    page_size: int = Query(20, ge=1, le=100, description="페이지당 개수"),
):
    cached = await get_cached_reviews(query)
    if not cached:
        return {"reviews": [], "total": 0, "page": page, "page_size": page_size, "has_next": False}

    total = len(cached)
    start = (page - 1) * page_size
    end   = start + page_size
    page_items = cached[start:end]

    return {
        "reviews":   page_items,
        "total":     total,
        "page":      page,
        "page_size": page_size,
        "has_next":  end < total,
    }


# ── 메인 검색 ────────────────────────────────────────────────────────────────

@router.get("/search")
async def search(
    query: str,
    mode: str = "model",
    total: int = Query(MAX_TOTAL, ge=20, le=300, description="수집할 최대 리뷰 수"),
    page: int = Query(1, ge=1, description="페이지 번호"),
    page_size: int = Query(20, ge=1, le=100, description="페이지당 개수"),
):
    print(f"[DEBUG] 검색 요청 | query={query} | mode={mode} | total={total} | page={page}")

    # Step 1: 캐시 확인
    cached = await get_cached_reviews(query)
    print(f"[DEBUG] cached count: {len(cached) if cached else 0}")

    if cached:
        print("[DEBUG] → Supabase 캐시 hit")
        summary    = await summarize_reviews(cached)
        page_items = _paginate(cached, page, page_size)
        return {
            "source":    "cache",
            "reviews":   page_items["items"],
            "total":     page_items["total"],
            "page":      page,
            "page_size": page_size,
            "has_next":  page_items["has_next"],
            "summary":   summary,
        }

    # Step 2: Naver API — start 파라미터로 여러 번 호출
    print(f"[DEBUG] → 캐시 없음, Naver API 호출 (목표 {total}개)")
    blogs = await fetch_blog_previews(query, total=total)
    print(f"[DEBUG] Naver 수집 완료 | count: {len(blogs)}")

    # Step 3: Supabase 저장
    await save_reviews(query, blogs)
    print("[DEBUG] Supabase 저장 완료")

    # Step 4: 저장된 데이터 재조회 (id 포함)
    saved = await get_cached_reviews(query)
    print(f"[DEBUG] 재조회 완료 | count: {len(saved)}")

    # Step 5: 광고 판별
    for review in saved:
        description = review.get("review_description") or ""

        if mode == "llm":
            print(f"[DEBUG] LLM 판별 | id: {review['id']}")
            is_ad_llm = await classify_ad(review)
            await update_llm_pred(review["id"], is_ad_llm)
            review["is_ad_llm_pred"] = is_ad_llm
        else:
            print(f"[DEBUG] ELECTRA 판별 | id: {review['id']}")
            is_ad_electra = predict_is_ad(description)
            score         = score_is_ad(description)
            await update_electra_pred(review["id"], is_ad_electra)
            await update_finetuned_pred(review["id"], score)
            review["is_ad_electra_pred"]   = is_ad_electra
            review["is_ad_finetuned_pred"]  = score

    # Step 6: 요약
    summary    = await summarize_reviews(saved)
    page_items = _paginate(saved, page, page_size)

    return {
        "source":    "fresh",
        "reviews":   page_items["items"],
        "total":     page_items["total"],
        "page":      page,
        "page_size": page_size,
        "has_next":  page_items["has_next"],
        "summary":   summary,
    }


# ── 헬퍼 ────────────────────────────────────────────────────────────────────

def _paginate(items: list, page: int, page_size: int) -> dict:
    total = len(items)
    start = (page - 1) * page_size
    end   = start + page_size
    return {
        "items":    items[start:end],
        "total":    total,
        "has_next": end < total,
    }