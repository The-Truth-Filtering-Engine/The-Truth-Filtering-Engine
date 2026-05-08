from fastapi import APIRouter, Header, HTTPException, Query, status

import time
from services.preprocess import preprocess
from services.electra_service import predict_is_ad, score_is_ad, predict_and_score_batch
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
    ANALYSIS_USAGE_REQUIRED_MESSAGE,
    AnalysisUsageError,
    consume_analysis_usage,
    get_auth_email,
    get_cached_reviews,
    has_analysis_usage,
    save_reviews,
    # update_electra_pred,
    update_finetuned_pred,
    update_llm_pred,
)

router = APIRouter()


@router.get("/search/cached")
async def search_cached(
    query: str,
    limit: int = Query(MAX_REVIEW_RESULTS, ge=1, le=MAX_REVIEW_RESULTS),
    store_id: str | None = Query(None, alias="storeId"),
    authorization: str | None = Header(default=None),
):
    review_limit = clamp_max_results(limit)
    cached = await get_cached_reviews(query, limit=review_limit, store_id=store_id)
    usage = None
    auth_email = await _get_optional_auth_email(authorization)

    if cached and auth_email and store_id:
        usage = await _consume_analysis_usage(auth_email, store_id)

    response = {
        "source": "cache",
        "reviews": cached or [],
        "reviewBatchSize": REVIEW_BATCH_SIZE,
        "maxReviewResults": MAX_REVIEW_RESULTS,
        "hasMore": bool(cached) and len(cached) >= REVIEW_BATCH_SIZE,
    }
    if usage is not None:
        response["usage"] = usage
    return response


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
    authorization: str | None = Header(default=None),
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
    usage = None
    auth_email = await _get_optional_auth_email(authorization)

    if should_fetch:
        if auth_email:
            await _ensure_analysis_usage_available(auth_email, store_id)

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

    if auth_email and (should_fetch or (store_id and saved)):
        usage = await _consume_analysis_usage(auth_email, store_id if store_id else None)
    elif auth_email:
        usage = {
            "charged": False,
            "chargedBy": None,
            "profile": None,
        }

    response = {
        "source": "fresh" if should_fetch else "cache",
        "reviews": saved,
        "summary": summary,
        "reviewBatchSize": REVIEW_BATCH_SIZE,
        "maxReviewResults": max_review_results,
        "naverStart": normalized_start,
        "fetchedCount": fetched_count,
        "hasMore": has_more,
    }
    if usage is not None:
        response["usage"] = usage
    return response


def _extract_optional_bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer 인증 토큰이 필요합니다",
        )

    return token.strip()


async def _get_optional_auth_email(authorization: str | None) -> str | None:
    token = _extract_optional_bearer_token(authorization)
    if not token:
        return None

    try:
        email = await get_auth_email(token)
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 인증 토큰입니다",
        )

    return email


async def _ensure_analysis_usage_available(
    email: str,
    store_id: str | None = None,
) -> None:
    try:
        if await has_analysis_usage(email, store_id=store_id):
            return
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error

    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail=ANALYSIS_USAGE_REQUIRED_MESSAGE,
    )


# async def _analyze_missing_reviews(reviews: list[dict], mode: str) -> None:
#     for review in reviews:
#         review_id = review.get("id")
#         description = review.get("review_description") or ""

#         if mode == "llm":
#             if review.get("is_ad_llm_pred") is not None:
#                 continue
#             print(f"[DEBUG] LLM 판별 중 | id: {review_id}")
#             is_ad_llm = await classify_ad(review)
#             if review_id is not None:
#                 await update_llm_pred(review_id, is_ad_llm)
#             review["is_ad_llm_pred"] = is_ad_llm
#             print(f"[DEBUG] LLM 판별 완료 | id: {review_id} | is_ad_llm_pred: {is_ad_llm}")
#             continue

#         if (
#             review.get("is_ad_electra_pred") is not None
#             and review.get("is_ad_finetuned_pred") is not None
#         ):
#             continue

#         print(f"[DEBUG] BERT 판별 중 | id: {review_id}")
#         is_ad_electra = predict_is_ad(description)
#         score = score_is_ad(description)
#         if review_id is not None:
#             await update_electra_pred(review_id, is_ad_electra)
#             await update_finetuned_pred(review_id, score)
#         review["is_ad_electra_pred"] = is_ad_electra
#         review["is_ad_finetuned_pred"] = score
#         print(
#             f"[DEBUG] BERT 판별 완료 | id: {review_id} | "
#             f"is_ad_electra_pred: {is_ad_electra} | is_ad_finetuned_pred: {score}"
#         )

# 수정 후
async def _consume_analysis_usage(
    email: str,
    store_id: str | None = None,
) -> dict:
    try:
        return await consume_analysis_usage(email, store_id=store_id)
    except AnalysisUsageError as error:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=str(error),
        ) from error
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(error),
        ) from error


async def _analyze_missing_reviews(reviews: list[dict], mode: str) -> None:
    if mode == "llm":
        for review in reviews:
            review_id = review.get("id")
            if review.get("is_ad_llm_pred") is not None:
                continue
            print(f"[DEBUG] LLM 판별 중 | id: {review_id}")
            is_ad_llm = await classify_ad(review)
            if review_id is not None:
                await update_llm_pred(review_id, is_ad_llm)
            review["is_ad_llm_pred"] = is_ad_llm
            print(f"[DEBUG] LLM 판별 완료 | id: {review_id} | is_ad_llm_pred: {is_ad_llm}")
        return

    # 분석이 필요한 리뷰만 필터링
    targets = [
        r for r in reviews
        if r.get("is_ad_finetuned_pred") is None
    ]
    if not targets:
        return
    
    INFER_BATCH = 32
    all_preds, all_scores = [], []

    print(f"[DEBUG] BERT 배치 판별 시작 | count: {len(targets)}")
    batch_start = time.time()
    for i in range(0, len(targets), INFER_BATCH):
        chunk = targets[i:i + INFER_BATCH]
        descriptions = [
            preprocess(
                title=r.get("review_title") or "",
                description=r.get("review_description") or "",
                store_name=r.get("name") or "",
            )
            for r in chunk
        ]
        preds, scores = predict_and_score_batch(descriptions)
        all_preds.extend(preds)
        all_scores.extend(scores)
        print(f"[DEBUG] BERT 판별 진행 | {len(all_preds)}/{len(targets)}")
    batch_elapsed = time.time() - batch_start
    print(f"[DEBUG] BERT 배치 판별 완료 | 소요 시간: {batch_elapsed:.2f}s")

    print(f"[DEBUG] BERT 배치 판별 시작 | count: {len(targets)}")
    preds, scores = predict_and_score_batch(descriptions)
    print(f"[DEBUG] BERT 배치 판별 완료")

    for idx, (review, pred, score) in enumerate(zip(targets, all_preds, all_scores), 1):
      review_id = review.get("id")
      if review_id is not None:
          await update_finetuned_pred(review_id, score)
      review["is_ad_finetuned_pred"] = score
      print(f"[DEBUG] 저장 완료 | {idx}/{len(targets)} | id: {review_id} | score: {score:.3f}")


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
            # "is_ad_electra_pred": None,
            "is_ad_finetuned_pred": None,
            "is_ad_llm_pred": None,
        }
        for index, blog in enumerate(blogs)
    ]
