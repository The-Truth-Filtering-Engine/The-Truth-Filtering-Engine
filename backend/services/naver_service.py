import httpx, os, re, asyncio
from html import unescape

NAVER_CLIENT_ID     = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")

DISPLAY_PER_CALL = 100  # Naver API 1회 최대
CONCURRENT_CALLS = 3    # 동시 호출 수
MAX_TOTAL = 300         # 기본 수집 목표량

def _clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)  # <b>, </b> 등 HTML 태그 제거
    text = unescape(text)                 # &quot; &amp; 등 HTML 엔티티 디코딩
    return text.strip()

async def _fetch_once(
    client: httpx.AsyncClient,
    query: str,
    start: int,
    display: int,
) -> list[dict]:
    url = "https://openapi.naver.com/v1/search/blog.json"
    headers = {
        "X-Naver-Client-Id":     NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
    }
    params = {"query": query, "display": display, "start": start, "sort": "sim"}

    try:
        res = await client.get(url, headers=headers, params=params, timeout=10)
        items = res.json().get("items", [])
    except Exception as e:
        print(f"[naver] 오류 start={start}: {e}")
        return []

    return [
        {
            "title":       _clean(item["title"]),
            "description": _clean(item["description"]),
            "link":        item["link"],
            "bloggername": item["bloggername"],
            "postdate":    item["postdate"],
        }
        for item in items
    ]

async def fetch_blog_previews(query: str, total: int = MAX_TOTAL) -> list[dict]:
    """
    네이버 블로그 검색 API를 사용하여 리뷰를 수집합니다.
    한 번에 최대 100개까지 가져올 수 있으므로, total이 100을 넘으면 start 파라미터를 조절하여 여러 번 호출합니다.
    """
    results: list[dict] = []
    # 호출할 start 포인트 계산 (1, 101, 201...)
    starts = list(range(1, total + 1, DISPLAY_PER_CALL))

    async with httpx.AsyncClient() as client:
        for i in range(0, len(starts), CONCURRENT_CALLS):
            batch = starts[i: i + CONCURRENT_CALLS]
            display_last = min(DISPLAY_PER_CALL, total - (batch[-1] - 1))
            tasks = [
                _fetch_once(client, query, s, DISPLAY_PER_CALL if s != batch[-1] else display_last)
                for s in batch
            ]
            batch_results = await asyncio.gather(*tasks)

            for items in batch_results:
                results.extend(items)

            # 결과 없으면 조기 종료
            if any(len(items) == 0 for items in batch_results):
                break

    # 중복 link 제거
    seen: set[str] = set()
    unique: list[dict] = []
    for item in results:
        if item["link"] not in seen:
            seen.add(item["link"])
            unique.append(item)

    print(f"[naver] '{query}' 수집 완료: {len(unique)}개 (목표 {total}개)")
    return unique[:total]