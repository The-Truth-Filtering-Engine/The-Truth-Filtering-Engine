import os

import httpx
from fastapi import APIRouter, Query

from services.supabase_service import get_ai_recommendation_reviews

router = APIRouter(tags=["ai-recommendations"])

KAKAO_REST_API_KEY = os.getenv("KAKAO_REST_API_KEY", "").strip()
KAKAO_KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"
KAKAO_PLACE_CATEGORY_CODES = ("FD6", "CE7")


@router.get("/ai-recommendations")
async def ai_recommendations(
    threshold: float = Query(0.1, ge=0, le=1),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, alias="pageSize", ge=1, le=10),
):
    result = await get_ai_recommendation_reviews(
        threshold=threshold,
        page=page,
        page_size=page_size,
    )
    reviews = result["items"]
    places_by_name = await _find_places_by_names([review.get("name") for review in reviews])

    items = [
        _build_response_item(review, places_by_name.get((review.get("name") or "").strip()))
        for review in reviews
    ]

    return {
        "threshold": threshold,
        "page": page,
        "pageSize": page_size,
        "hasNext": result["has_next"],
        "count": len(items),
        "items": items,
    }


def _build_response_item(review: dict, place: dict | None) -> dict:
    item = {
        "id": review.get("id"),
        "name": review.get("name") or "",
        "reviewTitle": review.get("review_title") or "",
        "reviewDescription": review.get("review_description") or "",
        "reviewUrl": review.get("review_url") or "",
        "bloggerName": review.get("review_bloggername") or "",
        "postDate": review.get("review_postdate") or "",
        "adScore": review.get("is_ad_finetuned_pred"),
        "placeId": "",
        "placeName": "",
        "address": "",
        "category": "",
        "lat": None,
        "lng": None,
        "placeUrl": "",
        "phone": "",
    }

    if not place:
        return item

    item.update(
        {
            "placeId": place.get("id") or "",
            "placeName": place.get("place_name") or "",
            "address": place.get("road_address_name") or place.get("address_name") or "",
            "category": place.get("category_name") or "음식점",
            "lat": _safe_float(place.get("y")),
            "lng": _safe_float(place.get("x")),
            "placeUrl": place.get("place_url") or "",
            "phone": place.get("phone") or "",
        }
    )
    return item


async def _find_places_by_names(names: list) -> dict[str, dict]:
    if not KAKAO_REST_API_KEY:
        return {}

    cleaned_names = []
    seen = set()
    for name in names:
        cleaned = (name or "").strip()
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        cleaned_names.append(cleaned)

    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    places: dict[str, dict] = {}

    async with httpx.AsyncClient(timeout=5.0) as client:
        for name in cleaned_names:
            place = await _find_place_by_name(client, headers, name)
            if place:
                places[name] = place

    return places


async def _find_place_by_name(
    client: httpx.AsyncClient,
    headers: dict[str, str],
    name: str,
) -> dict | None:
    for category_code in KAKAO_PLACE_CATEGORY_CODES:
        params = {
            "query": name,
            "category_group_code": category_code,
            "size": 1,
        }
        response = await client.get(
            KAKAO_KEYWORD_SEARCH_URL,
            headers=headers,
            params=params,
        )
        if response.status_code != 200:
            print(
                "카카오 장소 검색 API 에러 "
                f"name={name} status={response.status_code} body={response.text}"
            )
            return None

        documents = response.json().get("documents", [])
        if documents:
            return documents[0]

    return None


def _safe_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
