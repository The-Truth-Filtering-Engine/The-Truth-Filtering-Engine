from fastapi import APIRouter, Query, HTTPException
import httpx
import os
from math import radians, cos, sin, asin, sqrt

router = APIRouter(prefix="/places", tags=["places"])

NAVER_CLIENT_ID = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")
NAVER_MAP_CLIENT_ID = os.getenv("NAVER_MAP_CLIENT_ID")
NAVER_MAP_CLIENT_SECRET = os.getenv("NAVER_MAP_CLIENT_SECRET")
KAKAO_REST_API_KEY = os.getenv("KAKAO_REST_API_KEY", "").strip()

KAKAO_LOCAL_CATEGORY_URL = "https://dapi.kakao.com/v2/local/search/category.json"
KAKAO_PLACE_CATEGORY_CODES = ("FD6", "CE7")

def haversine(lat1, lng1, lat2, lng2):
    R = 6371000
    phi1, phi2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlambda = radians(lng2 - lng1)
    a = sin(dphi/2)**2 + cos(phi1)*cos(phi2)*sin(dlambda/2)**2
    return 2 * R * asin(sqrt(a))

async def get_neighborhood(lat: float, lng: float) -> str:
    url = "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc"
    headers = {
        "X-NCP-APIGW-API-KEY-ID": NAVER_MAP_CLIENT_ID,
        "X-NCP-APIGW-API-KEY": NAVER_MAP_CLIENT_SECRET,
    }
    params = {
        "coords": f"{lng},{lat}",
        "output": "json",
        "orders": "admcode",
    }
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, headers=headers, params=params)
        if resp.status_code == 200:
            data = resp.json()
            results = data.get("results", [])
            if results:
                region = results[0].get("region", {})
                area3 = region.get("area3", {}).get("name", "")
                area2 = region.get("area2", {}).get("name", "")
                return area3 if area3 else area2
    except Exception as e:
        print(f"역지오코딩 에러: {e}")
    return "근처"

@router.get("/nearby-restaurants")
async def get_nearby_restaurants(
    lat: float = Query(...),
    lng: float = Query(...),
    radius: int = Query(500),
    display: int = Query(10, ge=1, le=10),
):
    if not KAKAO_REST_API_KEY:
        raise HTTPException(status_code=500, detail="KAKAO_REST_API_KEY 없음")

    radius = max(1, min(radius, 20000))
    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}

    async def fetch_category(client: httpx.AsyncClient, category_code: str):
        params = {
            "category_group_code": category_code,
            "x": lng,
            "y": lat,
            "radius": radius,
            "sort": "accuracy",
            "size": display,
        }
        response = await client.get(
            KAKAO_LOCAL_CATEGORY_URL,
            headers=headers,
            params=params,
        )
        if response.status_code != 200:
            print(
                "카카오 Local API 에러 "
                f"category={category_code} status={response.status_code} "
                f"body={response.text}"
            )
            raise HTTPException(
                status_code=response.status_code,
                detail="카카오 Local API 호출 실패",
            )
        return response.json().get("documents", [])

    async with httpx.AsyncClient(timeout=5.0) as client:
        documents = []
        for category_code in KAKAO_PLACE_CATEGORY_CODES:
            documents.extend(await fetch_category(client, category_code))

    unique_by_id: dict[str, dict] = {}
    for item in documents:
        place_id = str(item.get("id", "")).strip()
        if not place_id or place_id in unique_by_id:
            continue

        place_lat = float(item.get("y") or 0)
        place_lng = float(item.get("x") or 0)
        distance = int(float(item.get("distance") or 0))
        if distance <= 0:
            distance = int(haversine(lat, lng, place_lat, place_lng))

        unique_by_id[place_id] = {
            "id": place_id,
            "name": item.get("place_name", ""),
            "address": item.get("road_address_name") or item.get("address_name", ""),
            "category": parse_kakao_category(item.get("category_name", "")),
            "lat": place_lat,
            "lng": place_lng,
            "link": item.get("place_url", ""),
            "distance": distance,
            "phone": item.get("phone", ""),
        }

    restaurants = sorted(
        unique_by_id.values(),
        key=lambda restaurant: restaurant["distance"],
    )[:display]

    print(f"카카오 주변 FD6/CE7 장소 수: {len(restaurants)}개, 반경: {radius}m")
    return {"count": len(restaurants), "restaurants": restaurants}


def parse_kakao_category(category_name: str) -> str:
    parts = [part.strip() for part in category_name.split(">") if part.strip()]
    if len(parts) >= 2:
        return parts[-1]
    return parts[0] if parts else "음식점"
