from fastapi import APIRouter, Header, HTTPException, Query, status
from fastapi.responses import StreamingResponse
import json

import asyncio
import time
from services.preprocess import preprocess
from services.electra_service import predict_and_score_batch
from services.naver_service import (
    build_naver_blog_query,
    fetch_blog_previews,
    fetch_first_store_blog_page,
    fetch_store_blog_previews,
    filter_blogs_by_store_name,
    iter_store_blog_pages,
)
from services.review_limits import (
    MAX_REVIEW_RESULTS,
    REVIEW_BATCH_SIZE,
    STREAM_BATCH_SIZE,
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
    save_reviews_with_scores,
    update_finetuned_pred,
)

router = APIRouter()

TEST_ACCOUNT_EMAIL = "test@example.com"
TEST_ACCOUNT_HEADER = "X-Test-Account-Email"

@router.get("/search/cached")
async def search_cached(
    query: str,
    limit: int = Query(MAX_REVIEW_RESULTS, ge=1, le=MAX_REVIEW_RESULTS),
    store_id: str | None = Query(None, alias="storeId"),
    authorization: str | None = Header(default=None),
    test_account_email: str | None = Header(default=None, alias=TEST_ACCOUNT_HEADER),
):
    review_limit = clamp_max_results(limit)
    cached = await get_cached_reviews(query, limit=review_limit, store_id=store_id, scored_only=True)
    place_detail_request = _is_place_detail_request(store_id)
    if place_detail_request:
        cached = filter_blogs_by_store_name(cached, query)
    usage = None
    auth_email = await _get_optional_auth_email(authorization, test_account_email)

    if cached and auth_email and store_id:
        usage = await _consume_analysis_usage(auth_email, store_id)

    response = {
        "source": "cache",
        "reviews": cached or [],
        "reviewBatchSize": REVIEW_BATCH_SIZE,
        "maxReviewResults": MAX_REVIEW_RESULTS,
        "hasMore": False
        if place_detail_request
        else bool(cached) and len(cached) >= REVIEW_BATCH_SIZE,
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
    test_account_email: str | None = Header(default=None, alias=TEST_ACCOUNT_HEADER),
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
    place_detail_request = _is_place_detail_request(store_id)
    if place_detail_request:
        cached = _filter_reviews_for_place(cached, place_metadata)
    cached_count = len(cached)
    requested_batch_end = normalized_start + review_limit - 1
    
    should_fetch = refresh or (
        not place_detail_request and cached_count < requested_batch_end
    ) or (
        place_detail_request and cached_count == 0
    )
    
    fetched_count = 0
    raw_fetched_count = 0
    naver_query = build_naver_blog_query(query, place_metadata)
    usage = None
    auth_email = await _get_optional_auth_email(authorization, test_account_email)

    if should_fetch:
        if auth_email:
            await _ensure_analysis_usage_available(auth_email, store_id)

        print(f"[DEBUG] → Naver API 호출 | naverQuery: {naver_query}")
        if place_detail_request:
            fetch_result = await fetch_store_blog_previews(
                naver_query,
                query,
                start=normalized_start,
                display=REVIEW_BATCH_SIZE,
                max_results=max_review_results,
            )
            blogs = fetch_result.items
            raw_fetched_count = fetch_result.raw_count
        else:
            blogs = await fetch_blog_previews(
                naver_query,
                start=normalized_start,
                display=review_limit,
            )
            raw_fetched_count = len(blogs)
        fetched_count = len(blogs)
        print(
            "[DEBUG] Naver 블로그 수집 완료 | "
            f"raw: {raw_fetched_count} | matched: {fetched_count}"
        )

        await save_reviews(query, blogs, place_metadata=place_metadata)
        print("[DEBUG] Supabase 저장 완료")

        saved = await get_cached_reviews(
            query,
            limit=max_review_results,
            store_id=store_id,
        )
        if place_detail_request:
            saved = _filter_reviews_for_place(saved, place_metadata)
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

    loaded_count = len(saved)
    has_more = (
        False
        if place_detail_request
        else (
            loaded_count < max_review_results
            and (
                fetched_count == review_limit
                or (not should_fetch and loaded_count >= requested_batch_end)
            )
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
        "reviewBatchSize": REVIEW_BATCH_SIZE,
        "maxReviewResults": max_review_results,
        "naverStart": normalized_start,
        "naverQuery": naver_query,
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


def _extract_optional_test_account_email(
    test_account_email: str | None,
) -> str | None:
    email = (test_account_email or "").strip().lower()
    if not email:
        return None
    if email != TEST_ACCOUNT_EMAIL:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="테스트 계정 이메일이 올바르지 않습니다",
        )
    return TEST_ACCOUNT_EMAIL


async def _get_optional_auth_email(
    authorization: str | None,
    test_account_email: str | None = None,
) -> str | None:
    account_email = _extract_optional_test_account_email(test_account_email)
    if account_email:
        return account_email

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

async def _save_to_supabase(targets: list[dict], scores: list[float]) -> None:
    for idx, (review, score) in enumerate(zip(targets, scores), 1):
        review_id = review.get("id")
        if review_id is not None:
            await update_finetuned_pred(review_id, score)
        print(f"[DEBUG] 저장 완료 | {idx}/{len(targets)} | id: {review_id} | score: {score:.3f}")

async def _analyze_missing_reviews(reviews: list[dict], mode: str) -> None:

    targets = [r for r in reviews if r.get("is_ad_finetuned_pred") is None]
    if not targets:
        return

    all_scores: list[float] = []

    print(f"[DEBUG] 모델 배치 판별 시작 | count: {len(targets)}")
    batch_start = time.time()
    for i in range(0, len(targets), STREAM_BATCH_SIZE):
        chunk = targets[i:i + STREAM_BATCH_SIZE]
        descriptions = [
            preprocess(
                title=r.get("review_title") or "",
                description=r.get("review_description") or "",
                store_name=r.get("name") or "",
            )
            for r in chunk
        ]
        try:
            _, scores = predict_and_score_batch(descriptions)
        except Exception as e:
            print(f"[WARNING] 배치 추론 실패, score=0.0 대체 | {e}")
            scores = [0.0] * len(chunk)
        all_scores.extend(scores)
        print(f"[DEBUG] 모델 판별 진행 | {len(all_scores)}/{len(targets)}")
    batch_elapsed = time.time() - batch_start
    print(f"[DEBUG] 모델 배치 판별 완료 | 소요 시간: {batch_elapsed:.2f}s")

    for review, score in zip(targets, all_scores):
        review["is_ad_finetuned_pred"] = score

    asyncio.create_task(_save_to_supabase(targets, all_scores))

def _is_place_detail_request(store_id: str | None) -> bool:
    return bool(str(store_id or "").strip())


def _filter_reviews_for_place(
    reviews: list[dict],
    place_metadata: dict,
) -> list[dict]:
    return filter_blogs_by_store_name(reviews, place_metadata.get("name"))


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

@router.get("/search/stream")
async def search_stream(
    query: str,
    mode: str = "model",
    naver_start: int = Query(1, alias="naverStart", ge=1, le=MAX_REVIEW_RESULTS),
    limit: int = Query(REVIEW_BATCH_SIZE, ge=1, le=REVIEW_BATCH_SIZE),
    max_results: int = Query(MAX_REVIEW_RESULTS, alias="maxResults", ge=1, le=MAX_REVIEW_RESULTS),
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
    test_account_email: str | None = Header(default=None, alias=TEST_ACCOUNT_HEADER),
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
    naver_query = build_naver_blog_query(query, place_metadata)
    auth_email = await _get_optional_auth_email(authorization, test_account_email)

    cached = await get_cached_reviews(query, limit=max_review_results, store_id=store_id)
    place_detail_request = _is_place_detail_request(store_id)
    if place_detail_request:
        cached = _filter_reviews_for_place(cached, place_metadata)
    cached_count = len(cached)
    requested_batch_end = normalized_start + review_limit - 1

    should_fetch = refresh or (
        not place_detail_request and cached_count < requested_batch_end
    ) or (
        place_detail_request and cached_count == 0
    )

    print(f"[DEBUG] 스트림 검색 요청 | query: {query} | mode: {mode} | cached: {cached_count} | should_fetch: {should_fetch}", flush=True)

    if should_fetch and auth_email:
        await _ensure_analysis_usage_available(auth_email, store_id)

    async def event_generator():
        naver_task = asyncio.create_task(
            fetch_first_store_blog_page(naver_query, query, start=normalized_start)
        ) if should_fetch else None

        already_scored = [r for r in cached if r.get("is_ad_finetuned_pred") is not None]

        if already_scored:
            yield f"data: {json.dumps({'reviews': already_scored, 'done': False})}\n\n"

        loop = asyncio.get_running_loop()

        if should_fetch:    

            # Supabase 필드명("review_url")으로 중복 URL 집합 구성
            seen_urls = {r.get("review_url") for r in already_scored}

            print(f"[DEBUG] → Naver API 호출 | naverQuery: {naver_query}", flush=True)

            page_blogs = await naver_task
            new_blogs = [b for b in page_blogs if b.get("link") not in seen_urls]
            if new_blogs:
                seen_urls.update(b.get("link") for b in new_blogs)

                reviews = _blogs_to_reviews(query, new_blogs, normalized_start, place_metadata)
                page_scores: list[float] = []

                print(f"[DEBUG] 모델 배치 판별 시작 | count: {len(reviews)}", flush=True)
                batch_start = time.time()

                for i in range(0, len(reviews), STREAM_BATCH_SIZE):
                    chunk = reviews[i:i + STREAM_BATCH_SIZE]
                    chunk_blogs = new_blogs[i:i + STREAM_BATCH_SIZE]
                    descriptions = [
                        preprocess(
                            title=r.get("review_title") or "",
                            description=r.get("review_description") or "",
                            store_name=r.get("name") or "",
                        )
                        for r in chunk
                    ]
                    try:
                        _, scores = await loop.run_in_executor(None, predict_and_score_batch, descriptions)
                    except Exception as e:
                        print(f"[WARNING] 스트림 배치 추론 실패, score=0.0 대체 | {e}")
                        scores = [0.0] * len(chunk)
                    for review, score in zip(chunk, scores):
                        review["is_ad_finetuned_pred"] = score
                    page_scores.extend(scores)

                    print(f"[DEBUG] 모델 판별 진행 | {len(page_scores)}/{len(reviews)}", flush=True)
                    yield f"data: {json.dumps({'reviews': chunk, 'done': False})}\n\n"
                    await asyncio.sleep(0)

                print(f"[DEBUG] 모델 배치 판별 완료 | 소요 시간: {time.time() - batch_start:.2f}s", flush=True)
                asyncio.create_task(
                    save_reviews_with_scores(query, new_blogs, page_scores, place_metadata)
                )
        else:
            if naver_task is not None:
                naver_task.cancel()
            targets = [r for r in cached if r.get("is_ad_finetuned_pred") is None]
            print(f"[DEBUG] → Supabase 캐시 hit | cached: {cached_count} | unscored: {len(targets)}", flush=True)
            for i in range(0, len(targets), STREAM_BATCH_SIZE):
                chunk = targets[i:i + STREAM_BATCH_SIZE]
                descriptions = [
                    preprocess(
                        title=r.get("review_title") or "",
                        description=r.get("review_description") or "",
                        store_name=r.get("name") or "",
                    )
                    for r in chunk
                ]
                try:
                    _, scores = await loop.run_in_executor(None, predict_and_score_batch, descriptions)
                except Exception as e:
                    print(f"[WARNING] 스트림 배치 추론 실패, score=0.0 대체 | {e}")
                    scores = [0.0] * len(chunk)
                for review, score in zip(chunk, scores):
                    review["is_ad_finetuned_pred"] = score
                asyncio.create_task(_save_to_supabase(chunk, scores))
                yield f"data: {json.dumps({'reviews': chunk, 'done': False})}\n\n"

        yield f"data: {json.dumps({'reviews': [], 'done': True, 'naverQuery': naver_query})}\n\n"
        print(f"[DEBUG] 스트림 완료 | query: {query}", flush=True)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
