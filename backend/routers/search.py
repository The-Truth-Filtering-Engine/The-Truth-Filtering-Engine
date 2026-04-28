from fastapi import APIRouter
from services.supabase_service import get_cached_reviews, save_reviews, update_llm_pred, update_electra_pred
from services.naver_service import fetch_blog_previews
from services.llm_service import classify_ad, summarize_reviews
from services.electra_service import predict_is_ad

router = APIRouter()

@router.get("/search/cached")
async def search_cached(query: str):
    cached = await get_cached_reviews(query)  # 기존 함수 재사용
    return {"reviews": cached or []}

@router.get("/search")
async def search(query: str, mode: str = "model"):
    print(f"[DEBUG] 검색 요청 | query: {query} | mode: {mode}")

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
    print(f"[DEBUG] Naver 블로그 수집 완료 | count: {len(blogs)}")

    # Step 3: Supabase에 raw 데이터 저장
    await save_reviews(query, blogs)
    print("[DEBUG] Supabase 저장 완료")

    # Step 4: 저장된 데이터 다시 조회 (id 포함)
    saved = await get_cached_reviews(query)
    print(f"[DEBUG] 저장 후 재조회 완료 | count: {len(saved)}")

    # Step 5: 광고 판별 후 업데이트
    for review in saved:
        description = review.get("review_description") or ""

        if mode == "llm":
            print(f"[DEBUG] LLM 판별 중 | id: {review['id']}")
            is_ad_llm = await classify_ad(review)
            await update_llm_pred(review["id"], is_ad_llm)
            review["is_ad_llm_pred"] = is_ad_llm
            print(f"[DEBUG] LLM 판별 완료 | id: {review['id']} | is_ad_llm_pred: {is_ad_llm}")
        else:
            print(f"[DEBUG] ELECTRA 판별 중 | id: {review['id']}")
            is_ad_electra = predict_is_ad(description)
            await update_electra_pred(review["id"], is_ad_electra)
            review["is_ad_electra_pred"] = is_ad_electra
            print(f"[DEBUG] ELECTRA 판별 완료 | id: {review['id']} | is_ad_electra_pred: {is_ad_electra}")

    # Step 6: 진짜 리뷰 요약
    print("[DEBUG] 리뷰 요약 시작")
    summary = await summarize_reviews(saved)
    print("[DEBUG] 리뷰 요약 완료")

    return {"source": "fresh", "reviews": saved, "summary": summary}