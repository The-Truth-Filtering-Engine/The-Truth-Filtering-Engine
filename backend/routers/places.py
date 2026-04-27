from fastapi import APIRouter, Query, HTTPException
import httpx
import os
import hashlib
import asyncio
from math import radians, cos, sin, asin, sqrt

router = APIRouter(prefix="/places", tags=["places"])

NAVER_CLIENT_ID = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")
NAVER_MAP_CLIENT_ID = os.getenv("NAVER_MAP_CLIENT_ID")
NAVER_MAP_CLIENT_SECRET = os.getenv("NAVER_MAP_CLIENT_SECRET")

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
    display: int = Query(20, le=20),
):
    if not NAVER_CLIENT_ID or not NAVER_CLIENT_SECRET:
        raise HTTPException(status_code=500, detail="네이버 검색 API 키 없음")

    neighborhood = await get_neighborhood(lat, lng)
    print(f"동네명: {neighborhood}, 반경: {radius}m")

    queries = [
        f"{neighborhood} 식당",
        f"{neighborhood} 맛집",
        f"{neighborhood} 음식점",
        f"{neighborhood} 한식",
        f"{neighborhood} 중식",
        f"{neighborhood} 일식",
        f"{neighborhood} 양식",
        f"{neighborhood} 카페",
        f"{neighborhood} 분식",
        f"{neighborhood} 치킨",
    ]

    url = "https://openapi.naver.com/v1/search/local.json"
    headers = {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
    }

    async def fetch_query(client: httpx.AsyncClient, query: str):
        params = {
            "query": query,
            "display": display,
            "sort": "random",
            "coordinate": f"{lng},{lat}",
        }
        try:
            resp = await client.get(url, headers=headers, params=params)
            if resp.status_code == 200:
                return resp.json().get("items", [])
        except Exception:
            pass
        return []

    async with httpx.AsyncClient() as client:
        results = await asyncio.gather(*[
            fetch_query(client, query) for query in queries
        ])

    all_items: dict[str, dict] = {}
    for items in results:
        for item in items:
            mapx = int(item.get("mapx", 0))
            mapy = int(item.get("mapy", 0))
            wgs_lng = mapx / 1e7
            wgs_lat = mapy / 1e7

            dist = haversine(lat, lng, wgs_lat, wgs_lng)

            if dist > radius * 2:
                continue

            name = item.get("title", "").replace("<b>", "").replace("</b>", "")
            unique_str = f"{name}_{wgs_lat}_{wgs_lng}"
            place_id = hashlib.md5(unique_str.encode()).hexdigest()[:12]

            if place_id not in all_items:
                all_items[place_id] = {
                    "id": place_id,
                    "name": name,
                    "address": item.get("roadAddress") or item.get("address", ""),
                    "category": item.get("category", ""),
                    "lat": wgs_lat,
                    "lng": wgs_lng,
                    "link": item.get("link", ""),
                    "distance": int(dist),
                }

    restaurants = sorted(all_items.values(), key=lambda x: x["distance"])
    print(f"최종 식당 수: {len(restaurants)}개")

    return {"count": len(restaurants), "restaurants": restaurants}