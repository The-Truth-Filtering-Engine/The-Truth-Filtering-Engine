from fastapi import APIRouter
from services.supabase_service import get_cached_reviews, save_reviews, update_llm_pred
from services.naver_service import fetch_blog_previews
from services.llm_service import classify_ad, summarize_reviews

router = APIRouter()

@router.get("/search")
async def search(query: str):
    # Step 1: 캐시 확인
    cached = await get_cached_reviews(query)
    if cached:
        summary = await summarize_reviews(cached)
        return {"source": "cache", "reviews": cached, "summary": summary}

    # Step 2: Naver API로 블로그 수집
    blogs = await fetch_blog_previews(query)

    # Step 3: Supabase에 raw 데이터 저장
    await save_reviews(query, blogs)

    # Step 4: 저장된 데이터 다시 조회 (id 포함)
    saved = await get_cached_reviews(query)

    # Step 5: LLM으로 광고 판별 후 업데이트
    for review in saved:
        is_ad = await classify_ad(review)
        await update_llm_pred(review["id"], is_ad)
        review["is_ad_llm_pred"] = is_ad

    # Step 6: 진짜 리뷰 요약
    summary = await summarize_reviews(saved)

    return {"source": "fresh", "reviews": saved, "summary": summary}