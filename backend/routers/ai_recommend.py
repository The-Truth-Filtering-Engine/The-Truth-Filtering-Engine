import os
from typing import Literal

import httpx
from fastapi import APIRouter, Query

from services.supabase_service import get_ai_recommendation_reviews

router = APIRouter(tags=["ai-recommendations"])

KAKAO_REST_API_KEY = os.getenv("KAKAO_REST_API_KEY", "").strip()
KAKAO_KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"
KAKAO_COORD_TO_REGION_URL = "https://dapi.kakao.com/v2/local/geo/coord2regioncode.json"
KAKAO_PLACE_CATEGORY_CODES = ("FD6", "CE7")
AI_RECOMMEND_SCAN_PAGE_LIMIT = 8

RegionScope = Literal["dong", "gu", "si"]


@router.get("/ai-recommendations")
async def ai_recommendations(
    threshold: float = Query(0.1, ge=0, le=1),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, alias="pageSize", ge=1, le=10),
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    region_scope: RegionScope = Query("dong", alias="regionScope"),
):
    region = await _get_region(lat, lng) if lat is not None and lng is not None else None

    if region:
        items, has_next = await _load_region_filtered_items(
            threshold=threshold,
            page=page,
            page_size=page_size,
            region=region,
            region_scope=region_scope,
        )
    else:
        result = await get_ai_recommendation_reviews(
            threshold=threshold,
            page=page,
            page_size=page_size,
        )
        reviews = result.get("items", [])
        places_by_name = await _find_places_by_names([review.get("name") for review in reviews])

        items = [
            _build_response_item(
                review,
                places_by_name.get((review.get("name") or "").strip()),
            )
            for review in reviews
        ]
        has_next = result.get("has_next", False)

    region_label = _format_region_label(region, region_scope) if region else ""


    return {
        "threshold": threshold,
        "page": page,
        "pageSize": page_size,
        "regionScope": region_scope,
        "regionLabel": region_label,
        "currentRegion": _serialize_region(region) if region else None,
        "isRegionFiltered": bool(region),
        "hasNext": has_next,
        "count": len(items),
        "items": items,
    }


async def _load_region_filtered_items(
    threshold: float,
    page: int,
    page_size: int,
    region: dict[str, str],
    region_scope: RegionScope,
) -> tuple[list[dict], bool]:
    target_count = page * page_size + 1
    filtered_items: list[dict] = []
    source_has_next = True
    scan_page = 1

    while (
        source_has_next
        and scan_page <= AI_RECOMMEND_SCAN_PAGE_LIMIT
        and len(filtered_items) < target_count
    ):
        result = await get_ai_recommendation_reviews(
            threshold=threshold,
            page=scan_page,
            page_size=page_size,
        )
        reviews = result.get("items", [])
        places_by_name = await _find_places_by_names(
            [review.get("name") for review in reviews],
        )

        for review in reviews:
            place = places_by_name.get((review.get("name") or "").strip())
            if not _review_matches_region(review, place, region, region_scope):
                continue

            filtered_items.append(_build_response_item(review, place))
            if len(filtered_items) >= target_count:
                break

        source_has_next = result.get("has_next", False)
        scan_page += 1

    start_index = (page - 1) * page_size
    end_index = page * page_size

    return filtered_items[start_index:end_index], len(filtered_items) > end_index


def _build_response_item(review: dict, place: dict | None) -> dict:
    review_address = review.get("road_address_name") or review.get("address_name") or ""
    review_place_url = review.get("place_url") or ""
    item = {
        "id": review.get("id"),
        "name": review.get("name") or "",
        "reviewTitle": review.get("review_title") or "",
        "reviewDescription": review.get("review_description") or "",
        "reviewUrl": review.get("review_url") or "",
        "bloggerName": review.get("review_bloggername") or "",
        "postDate": review.get("review_postdate") or "",
        "adScore": review.get("is_ad_finetuned_pred"),
        "placeId": review.get("store_id") or "",
        "placeName": review.get("name") or "",
        "address": review_address,
        "category": review.get("category_name") or "",
        "categoryGroupCode": review.get("category_group_code") or "",
        "categoryGroupName": review.get("category_group_name") or "",
        "addressName": review.get("address_name") or "",
        "roadAddressName": review.get("road_address_name") or "",
        "lat": None,
        "lng": None,
        "placeUrl": review_place_url,
        "phone": review.get("phone") or "",
    }

    if not place:
        if not item["category"]:
            item["category"] = "음식점"
        return item

    item.update(
        {
            "placeId": item["placeId"] or place.get("id") or "",
            "placeName": item["placeName"] or place.get("place_name") or "",
            "address": item["address"]
            or place.get("road_address_name")
            or place.get("address_name")
            or "",
            "category": item["category"] or place.get("category_name") or "음식점",
            "categoryGroupCode": item["categoryGroupCode"]
            or place.get("category_group_code")
            or "",
            "categoryGroupName": item["categoryGroupName"]
            or place.get("category_group_name")
            or "",
            "addressName": item["addressName"] or place.get("address_name") or "",
            "roadAddressName": item["roadAddressName"]
            or place.get("road_address_name")
            or "",
            "lat": _safe_float(place.get("y")),
            "lng": _safe_float(place.get("x")),
            "placeUrl": item["placeUrl"] or place.get("place_url") or "",
            "phone": item["phone"] or place.get("phone") or "",
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

    async with httpx.AsyncClient(timeout=10.0) as client:
        for name in cleaned_names:
            place = await _find_place_by_name(client, headers, name)
            if place:
                places[name] = place

    return places


async def _get_region(lat: float, lng: float) -> dict[str, str] | None:
    if not KAKAO_REST_API_KEY:
        return None

    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    params = {"x": lng, "y": lat}

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(
                KAKAO_COORD_TO_REGION_URL,
                headers=headers,
                params=params,
            )
    except Exception as exc:
        print(f"카카오 행정구역 조회 에러: {exc}")
        return None

    if response.status_code != 200:
        print(
            "카카오 행정구역 API 에러 "
            f"status={response.status_code} body={response.text}"
        )
        return None

    documents = response.json().get("documents", [])
    if not documents:
        return None

    administrative = next(
        (document for document in documents if document.get("region_type") == "H"),
        documents[0],
    )
    legal = next(
        (document for document in documents if document.get("region_type") == "B"),
        administrative,
    )

    return {
        "si": administrative.get("region_1depth_name") or legal.get("region_1depth_name") or "",
        "gu": administrative.get("region_2depth_name") or legal.get("region_2depth_name") or "",
        "dong": administrative.get("region_3depth_name") or "",
        "legal_dong": legal.get("region_3depth_name") or "",
    }


def _review_matches_region(
    review: dict,
    place: dict | None,
    region: dict[str, str],
    region_scope: RegionScope,
) -> bool:
    address_text = _normalize_region_text(
        " ".join(
            [
                review.get("road_address_name") or "",
                review.get("address_name") or "",
                place.get("road_address_name") if place else "",
                place.get("address_name") if place else "",
            ]
        )
    )
    if not address_text:
        return False

    si_variants = _region_variants(region.get("si", ""))
    gu_variants = _region_variants(region.get("gu", ""))
    dong_variants = _region_variants(region.get("dong", "")) | _region_variants(
        region.get("legal_dong", "")
    )

    if region_scope == "si":
        return _matches_any(address_text, si_variants)

    if region_scope == "gu":
        return _matches_any(address_text, gu_variants) and (
            not si_variants or _matches_any(address_text, si_variants)
        )

    return _matches_any(address_text, gu_variants) and _matches_any(
        address_text,
        dong_variants,
    )


def _format_region_label(region: dict[str, str], region_scope: RegionScope) -> str:
    parts = [region.get("si", "")]
    if region_scope in {"gu", "dong"}:
        parts.append(region.get("gu", ""))
    if region_scope == "dong":
        parts.append(region.get("dong") or region.get("legal_dong", ""))

    return " ".join(part for part in parts if part)


def _serialize_region(region: dict[str, str]) -> dict[str, str]:
    dong = region.get("dong") or region.get("legal_dong", "")
    return {
        "si": region.get("si", ""),
        "gu": region.get("gu", ""),
        "dong": dong,
        "label": " ".join(
            part for part in [region.get("si", ""), region.get("gu", ""), dong] if part
        ),
    }


def _region_variants(value: str) -> set[str]:
    normalized = _normalize_region_text(value)
    if not normalized:
        return set()

    shortened = normalized
    for suffix in ("특별자치시", "특별자치도", "특별시", "광역시", "자치구", "도"):
        shortened = shortened.replace(suffix, "")

    return {variant for variant in {normalized, shortened} if variant}


def _matches_any(text: str, variants: set[str]) -> bool:
    return bool(variants) and any(variant in text for variant in variants)


def _normalize_region_text(value: str) -> str:
    return value.replace(" ", "").strip()


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
