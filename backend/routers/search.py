from fastapi import APIRouter
from services.supabase_service import get_cached_reviews, save_reviews, update_llm_pred, update_electra_pred
from services.naver_service import fetch_blog_previews
from services.llm_service import classify_ad, summarize_reviews
from services.electra_service import predict_is_ad

router = APIRouter()

@router.get("/search")
async def search(query: str):
    # Step 1: 캐시 확인
    cached = await get_cached_reviews(query)
    print(f"[DEBUG] cached count: {len(cached) if cached else 0}")
    if cached:
        print("[DEBUG] → Supabase 캐시 hit")
        summary = await summarize_reviews(cached)
        return {"source": "cache", "reviews": cached, "summary": summary}

    print("[DEBUG] → 캐시 없음, Naver API 호출")
    # Step 2: Naver API로 블로그 수집
    blogs = await fetch_blog_previews(query)

    # Step 3: Supabase에 raw 데이터 저장
    await save_reviews(query, blogs)

    # Step 4: 저장된 데이터 다시 조회 (id 포함)
    saved = await get_cached_reviews(query)

    # Step 5: 광고 판별 후 업데이트
    for review in saved:
        description = review.get("review_description") or ""

        # ── LLM 판별 (테스트 시 아래 두 줄 주석 해제) ──────────────────
        # is_ad_llm = await classify_ad(review)
        # await update_llm_pred(review["id"], is_ad_llm)
        # review["is_ad_llm_pred"] = is_ad_llm

        # ── ELECTRA 판별 (테스트 시 아래 세 줄 주석 해제) ───────────────
        is_ad_electra = predict_is_ad(description)
        await update_electra_pred(review["id"], is_ad_electra)
        review["is_ad_electra_pred"] = is_ad_electra

    # Step 6: 진짜 리뷰 요약
    summary = await summarize_reviews(saved)

    return {"source": "fresh", "reviews": saved, "summary": summary}