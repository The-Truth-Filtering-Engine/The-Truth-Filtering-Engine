from fastapi import APIRouter, Query

from services.electra_service import predict_is_ad, score_is_ad
from services.llm_service import classify_ad, summarize_reviews
from services.naver_service import fetch_blog_previews
from services.review_limits import (
    MAX_REVIEW_RESULTS,
    REVIEW_BATCH_SIZE,
    clamp_max_results,
    clamp_review_limit,
    normalize_naver_start,
)
from services.supabase_service import (
    get_cached_reviews,
    save_reviews,
    update_electra_pred,
    update_finetuned_pred,
    update_llm_pred,
)

router = APIRouter()


@router.get("/search/cached")
async def search_cached(
    query: str,
    limit: int = Query(MAX_REVIEW_RESULTS, ge=1, le=MAX_REVIEW_RESULTS),
    store_id: str | None = Query(None, alias="storeId"),
):
    review_limit = clamp_max_results(limit)
    cached = await get_cached_reviews(query, limit=review_limit, store_id=store_id)
    return {
        "source": "cache",
        "reviews": cached or [],
        "reviewBatchSize": REVIEW_BATCH_SIZE,
        "maxReviewResults": MAX_REVIEW_RESULTS,
        "hasMore": bool(cached) and len(cached) >= REVIEW_BATCH_SIZE,
    }


@router.get("/search")
async def search(
    query: str,
    mode: str = "model",
    naver_start: int = Query(1, alias="naverStart", ge=1, le=MAX_REVIEW_RESULTS),
    limit: int = Query(REVIEW_BATCH_SIZE, ge=1, le=REVIEW_BATCH_SIZE),
    max_results: int = Query(
        MAX_REVIEW_RESULTS,
        alias="maxResults",
        ge=1,
        le=MAX_REVIEW_RESULTS,
    ),
    refresh: bool = False,
    store_id: str | None = Query(None, alias="storeId"),
    category_name: str | None = Query(None, alias="categoryName"),
    category_group_code: str | None = Query(None, alias="categoryGroupCode"),
    category_group_name: str | None = Query(None, alias="categoryGroupName"),
    phone: str | None = None,
    address_name: str | None = Query(None, alias="addressName"),
    road_address_name: str | None = Query(None, alias="roadAddressName"),
    place_url: str | None = Query(None, alias="placeUrl"),
):
    review_limit = clamp_review_limit(limit)
    max_review_results = clamp_max_results(max_results)
    normalized_start = normalize_naver_start(naver_start)
    place_metadata = _build_place_metadata(
        query=query,
        store_id=store_id,
        category_name=category_name,
        category_group_code=category_group_code,
        category_group_name=category_group_name,
        phone=phone,
        address_name=address_name,
        road_address_name=road_address_name,
        place_url=place_url,
    )

    print(
        "[DEBUG] 검색 요청 | "
        f"query: {query} | mode: {mode} | naverStart: {normalized_start} | "
        f"limit: {review_limit} | refresh: {refresh} | storeId: {store_id or '-'}"
    )

    cached = await get_cached_reviews(
        query,
        limit=max_review_results,
        store_id=store_id,
    )
    cached_count = len(cached)
    requested_batch_end = normalized_start + review_limit - 1
    should_fetch = refresh or cached_count < requested_batch_end
    fetched_count = 0

    if should_fetch:
        print("[DEBUG] → Naver API 호출")
        blogs = await fetch_blog_previews(
            query,
            start=normalized_start,
            display=review_limit,
        )
        fetched_count = len(blogs)
        print(f"[DEBUG] Naver 블로그 수집 완료 | count: {fetched_count}")

        await save_reviews(query, blogs, place_metadata=place_metadata)
        print("[DEBUG] Supabase 저장 완료")

        saved = await get_cached_reviews(
            query,
            limit=max_review_results,
            store_id=store_id,
        )
        if not saved and blogs:
            saved = _blogs_to_reviews(
                query,
                blogs,
                normalized_start,
                place_metadata=place_metadata,
            )
    else:
        print(f"[DEBUG] → Supabase 캐시 hit | count: {cached_count}")
        saved = cached

    await _analyze_missing_reviews(saved, mode)

    print("[DEBUG] 리뷰 요약 시작")
    summary = await summarize_reviews(saved)
    print("[DEBUG] 리뷰 요약 완료")

    loaded_count = len(saved)
    has_more = (
        loaded_count < max_review_results
        and (
            fetched_count == review_limit
            or (not should_fetch and loaded_count >= requested_batch_end)
        )
    )

    return {
        "source": "fresh" if should_fetch else "cache",
        "reviews": saved,
        "summary": summary,
        "reviewBatchSize": REVIEW_BATCH_SIZE,
        "maxReviewResults": max_review_results,
        "naverStart": normalized_start,
        "fetchedCount": fetched_count,
        "hasMore": has_more,
    }


async def _analyze_missing_reviews(reviews: list[dict], mode: str) -> None:
    for review in reviews:
        review_id = review.get("id")
        description = review.get("review_description") or ""

        if mode == "llm":
            if review.get("is_ad_llm_pred") is not None:
                continue
            print(f"[DEBUG] LLM 판별 중 | id: {review_id}")
            is_ad_llm = await classify_ad(review)
            if review_id is not None:
                await update_llm_pred(review_id, is_ad_llm)
            review["is_ad_llm_pred"] = is_ad_llm
            print(f"[DEBUG] LLM 판별 완료 | id: {review_id} | is_ad_llm_pred: {is_ad_llm}")
            continue

        if (
            review.get("is_ad_electra_pred") is not None
            and review.get("is_ad_finetuned_pred") is not None
        ):
            continue

        print(f"[DEBUG] ELECTRA 판별 중 | id: {review_id}")
        is_ad_electra = predict_is_ad(description)
        score = score_is_ad(description)
        if review_id is not None:
            await update_electra_pred(review_id, is_ad_electra)
            await update_finetuned_pred(review_id, score)
        review["is_ad_electra_pred"] = is_ad_electra
        review["is_ad_finetuned_pred"] = score
        print(
            f"[DEBUG] ELECTRA 판별 완료 | id: {review_id} | "
            f"is_ad_electra_pred: {is_ad_electra} | is_ad_finetuned_pred: {score}"
        )


def _build_place_metadata(
    query: str,
    store_id: str | None,
    category_name: str | None,
    category_group_code: str | None,
    category_group_name: str | None,
    phone: str | None,
    address_name: str | None,
    road_address_name: str | None,
    place_url: str | None,
) -> dict:
    return {
        "name": query,
        "store_id": store_id,
        "category_name": category_name,
        "category_group_code": category_group_code,
        "category_group_name": category_group_name,
        "phone": phone,
        "address_name": address_name,
        "road_address_name": road_address_name,
        "place_url": place_url,
    }


def _blogs_to_reviews(
    query: str,
    blogs: list[dict],
    naver_start: int,
    place_metadata: dict | None = None,
) -> list[dict]:
    metadata = place_metadata or {}
    return [
        {
            "id": naver_start + index,
            "name": metadata.get("name") or query,
            "review_title": blog.get("title", ""),
            "review_description": blog.get("description", ""),
            "review_bloggername": blog.get("bloggername", ""),
            "review_url": blog.get("link", ""),
            "review_postdate": blog.get("postdate"),
            "store_id": metadata.get("store_id"),
            "category_name": metadata.get("category_name"),
            "category_group_code": metadata.get("category_group_code"),
            "category_group_name": metadata.get("category_group_name"),
            "phone": metadata.get("phone"),
            "address_name": metadata.get("address_name"),
            "road_address_name": metadata.get("road_address_name"),
            "place_url": metadata.get("place_url"),
            "is_ad_electra_pred": None,
            "is_ad_finetuned_pred": None,
            "is_ad_llm_pred": None,
        }
        for index, blog in enumerate(blogs)
    ]
