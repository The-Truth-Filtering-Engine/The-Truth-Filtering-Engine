import os
from typing import Literal

import httpx
from fastapi import APIRouter, Query

from services.supabase_service import get_ai_recommendation_reviews

router = APIRouter(tags=["ai-recommendations"])

KAKAO_REST_API_KEY = os.getenv("KAKAO_REST_API_KEY", "").strip()
KAKAO_KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"
KAKAO_ADDRESS_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/address.json"
KAKAO_COORD_TO_REGION_URL = "https://dapi.kakao.com/v2/local/geo/coord2regioncode.json"
KAKAO_PLACE_CATEGORY_CODES = ("FD6", "CE7")
AI_RECOMMEND_SCAN_PAGE_LIMIT = 8
AI_RECOMMEND_REGION_QUERY_PAGE_SIZE = 50

RegionScope = Literal["dong", "gu", "si"]
FoodFeature = Literal[
    "user_taste",
    "korean",
    "western",
    "world",
    "new_menu",
    "popular_menu",
    "cafe_dessert",
]
PriceRange = Literal[
    "any",
    "value",
    "under_10000",
    "10000_20000",
    "20000_40000",
    "special_day",
]
PartySize = Literal["any", "solo", "two", "small_group", "group", "parents", "family"]
TransportMode = Literal["any", "walk", "transit", "parking", "public_parking"]

FOOD_FEATURE_TERMS = {
    "korean": ["한식", "백반", "국밥", "찌개", "전골", "냉면", "가정식"],
    "western": ["양식", "파스타", "스테이크", "피자", "햄버거", "브런치"],
    "world": ["세계", "쌀국수", "커리", "멕시칸", "인도", "태국", "베트남", "터키"],
    "new_menu": ["신상", "신메뉴", "새로운", "시즌", "한정", "이색"],
    "popular_menu": ["인기", "대표", "시그니처", "추천", "베스트", "유명"],
    "cafe_dessert": ["카페", "커피", "라떼", "베이커리", "디저트", "케이크", "후식"],
}

PRICE_RANGE_TERMS = {
    "value": ["가성비", "저렴", "착한 가격", "합리적"],
    "under_10000": ["만원", "1만원", "저렴", "가성비", "분식", "백반"],
    "10000_20000": ["1만원", "2만원", "한 끼", "든든"],
    "20000_40000": ["2만원", "3만원", "4만원", "고기", "회식"],
    "special_day": ["특별한 날", "기념일", "고급", "파인다이닝", "오마카세", "코스"],
}

PARTY_SIZE_TERMS = {
    "solo": ["혼밥", "혼자", "1인", "바 자리"],
    "two": ["데이트", "둘이", "2인", "커플"],
    "small_group": ["친구", "모임", "3명", "4명"],
    "group": ["단체", "회식", "예약", "룸", "넓"],
    "parents": ["부모님", "어버이", "부모", "가족 식사", "조용", "룸", "한정식"],
    "family": ["가족", "아이", "부모님", "유아", "넓"],
}

TRANSPORT_MODE_TERMS = {
    "walk": ["도보", "가까", "역 근처", "근처", "골목"],
    "transit": ["역", "버스", "지하철", "대중교통", "정류장"],
    "parking": ["주차", "주차장", "발렛", "무료주차"],
    "public_parking": ["공영주차장", "공영 주차장", "공영주차", "공영 주차", "공영"],
}


@router.get("/ai-recommendations")
async def ai_recommendations(
    threshold: float = Query(0.1, ge=0, le=1),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, alias="pageSize", ge=1, le=10),
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    location_query: str | None = Query(None, alias="locationQuery"),
    region_scope: RegionScope = Query("dong", alias="regionScope"),
    food_feature: FoodFeature = Query("user_taste", alias="foodFeature"),
    price_range: PriceRange = Query("any", alias="priceRange"),
    party_size: PartySize = Query("any", alias="partySize"),
    transport_mode: TransportMode = Query("any", alias="transportMode"),
):
    region = await _resolve_requested_region(lat, lng, location_query)
    has_recommendation_filters = _has_recommendation_filters(
        food_feature=food_feature,
        price_range=price_range,
        party_size=party_size,
        transport_mode=transport_mode,
    )

    if region or has_recommendation_filters:
        items, has_next = await _load_filtered_items(
            threshold=threshold,
            page=page,
            page_size=page_size,
            region=region,
            region_scope=region_scope,
            food_feature=food_feature,
            price_range=price_range,
            party_size=party_size,
            transport_mode=transport_mode,
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
        "foodFeature": food_feature,
        "priceRange": price_range,
        "partySize": party_size,
        "transportMode": transport_mode,
        "locationQuery": location_query or "",
        "regionLabel": region_label,
        "currentRegion": _serialize_region(region) if region else None,
        "isRegionFiltered": bool(region),
        "hasNext": has_next,
        "count": len(items),
        "items": items,
    }


async def _load_filtered_items(
    threshold: float,
    page: int,
    page_size: int,
    region: dict[str, str] | None,
    region_scope: RegionScope,
    food_feature: FoodFeature,
    price_range: PriceRange,
    party_size: PartySize,
    transport_mode: TransportMode,
) -> tuple[list[dict], bool]:
    target_count = page * page_size + 1
    filtered_items: list[dict] = []
    source_has_next = True
    scan_page = 1
    address_terms = _address_search_terms(region, region_scope) if region else None

    while (
        source_has_next
        and scan_page <= AI_RECOMMEND_SCAN_PAGE_LIMIT
        and len(filtered_items) < target_count
    ):
        result = await get_ai_recommendation_reviews(
            threshold=threshold,
            page=scan_page,
            page_size=max(page_size, AI_RECOMMEND_REGION_QUERY_PAGE_SIZE),
            address_terms=address_terms,
        )
        reviews = result.get("items", [])
        places_by_name = await _find_places_by_names(
            [review.get("name") for review in reviews],
        )

        for review in reviews:
            place = places_by_name.get((review.get("name") or "").strip())
            if region and not _review_matches_region(review, place, region, region_scope):
                continue
            if not _review_matches_recommendation_filters(
                review=review,
                place=place,
                food_feature=food_feature,
                price_range=price_range,
                party_size=party_size,
                transport_mode=transport_mode,
            ):
                continue

            filtered_items.append(_build_response_item(review, place))
            if len(filtered_items) >= target_count:
                break

        source_has_next = result.get("has_next", False)
        scan_page += 1

    start_index = (page - 1) * page_size
    end_index = page * page_size

    return filtered_items[start_index:end_index], len(filtered_items) > end_index


def _has_recommendation_filters(
    food_feature: FoodFeature,
    price_range: PriceRange,
    party_size: PartySize,
    transport_mode: TransportMode,
) -> bool:
    return (
        food_feature != "user_taste"
        or price_range != "any"
        or party_size != "any"
        or transport_mode != "any"
    )


def _review_matches_recommendation_filters(
    review: dict,
    place: dict | None,
    food_feature: FoodFeature,
    price_range: PriceRange,
    party_size: PartySize,
    transport_mode: TransportMode,
) -> bool:
    text = _recommendation_filter_text(review, place)
    return all(
        [
            _matches_filter_terms(text, FOOD_FEATURE_TERMS.get(food_feature, [])),
            _matches_filter_terms(text, PRICE_RANGE_TERMS.get(price_range, [])),
            _matches_filter_terms(text, PARTY_SIZE_TERMS.get(party_size, [])),
            _matches_filter_terms(text, TRANSPORT_MODE_TERMS.get(transport_mode, [])),
        ]
    )


def _recommendation_filter_text(review: dict, place: dict | None) -> str:
    parts = [
        review.get("name") or "",
        review.get("review_title") or "",
        review.get("review_description") or "",
        review.get("category_name") or "",
        review.get("category_group_name") or "",
        review.get("address_name") or "",
        review.get("road_address_name") or "",
    ]
    if place:
        parts.extend(
            [
                place.get("place_name") or "",
                place.get("category_name") or "",
                place.get("address_name") or "",
                place.get("road_address_name") or "",
            ]
        )
    return _normalize_filter_text(" ".join(parts))


def _matches_filter_terms(text: str, terms: list[str]) -> bool:
    if not terms:
        return True
    return any(_normalize_filter_text(term) in text for term in terms if term)


def _normalize_filter_text(value: str) -> str:
    return value.replace(" ", "").casefold().strip()


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


async def _resolve_requested_region(
    lat: float | None,
    lng: float | None,
    location_query: str | None,
) -> dict[str, str] | None:
    if lat is not None and lng is not None:
        return await _get_region(lat, lng)

    query = (location_query or "").strip()
    if query:
        return await _get_region_by_location_query(query)

    return None


async def _get_region_by_location_query(query: str) -> dict[str, str] | None:
    if not KAKAO_REST_API_KEY:
        return None

    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(
                KAKAO_ADDRESS_SEARCH_URL,
                headers=headers,
                params={"query": query, "size": 1},
            )
            documents = response.json().get("documents", []) if response.status_code == 200 else []

            if not documents:
                response = await client.get(
                    KAKAO_KEYWORD_SEARCH_URL,
                    headers=headers,
                    params={"query": query, "size": 1},
                )
                documents = (
                    response.json().get("documents", [])
                    if response.status_code == 200
                    else []
                )
    except Exception as exc:
        print(f"카카오 위치 검색 에러: {exc}")
        return None

    if not documents:
        return None

    document = documents[0]
    lat = _safe_float(document.get("y"))
    lng = _safe_float(document.get("x"))
    if lat is None or lng is None:
        return None

    return await _get_region(lat, lng)


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

    return (
        _matches_any(address_text, dong_variants)
        and (not gu_variants or _matches_any(address_text, gu_variants))
        and (not si_variants or _matches_any(address_text, si_variants))
    )


def _format_region_label(region: dict[str, str], region_scope: RegionScope) -> str:
    parts = [region.get("si", "")]
    if region_scope in {"gu", "dong"}:
        parts.append(region.get("gu", ""))
    if region_scope == "dong":
        parts.append(_display_dong(region))

    return " ".join(part for part in parts if part)


def _serialize_region(region: dict[str, str]) -> dict[str, str]:
    dong = _display_dong(region)
    return {
        "si": region.get("si", ""),
        "gu": region.get("gu", ""),
        "dong": dong,
        "label": " ".join(
            part for part in [region.get("si", ""), region.get("gu", ""), dong] if part
        ),
    }


def _display_dong(region: dict[str, str]) -> str:
    return region.get("legal_dong") or region.get("dong", "")


def _address_search_terms(region: dict[str, str], region_scope: RegionScope) -> list[str]:
    if region_scope == "si":
        return _region_search_variants(region.get("si", ""))

    if region_scope == "gu":
        gu_terms = _region_search_variants(region.get("gu", ""))
        gu_parts = (region.get("gu") or "").split()
        if gu_parts:
            gu_terms.extend(_region_search_variants(gu_parts[-1]))
        return _dedupe_terms(gu_terms)

    terms = _region_search_variants(region.get("dong", ""))
    terms.extend(_region_search_variants(region.get("legal_dong", "")))
    return _dedupe_terms(terms)


def _region_search_variants(value: str) -> list[str]:
    original = value.strip()
    normalized = _normalize_region_text(value)
    if not original and not normalized:
        return []

    variants = [original, normalized]
    shortened_original = original
    shortened_normalized = normalized
    for suffix in ("특별자치시", "특별자치도", "특별시", "광역시", "자치구", "도"):
        shortened_original = shortened_original.replace(suffix, "")
        shortened_normalized = shortened_normalized.replace(suffix, "")

    variants.extend([shortened_original, shortened_normalized])
    return _dedupe_terms(variants)


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


def _dedupe_terms(values: list[str]) -> list[str]:
    seen = set()
    result = []
    for value in values:
        text = (value or "").strip()
        if not text or text in seen:
            continue
        seen.add(text)
        result.append(text)
    return result


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
