import httpx, os, re
from html import unescape
from services.review_limits import REVIEW_BATCH_SIZE, normalize_naver_start

NAVER_CLIENT_ID = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")

def _clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)  # <b>, </b> 등 HTML 태그 제거
    text = unescape(text)                 # &quot; &amp; 등 HTML 엔티티 디코딩
    return text.strip()

async def fetch_blog_previews(
    query: str,
    *,
    start: int = 1,
    display: int = REVIEW_BATCH_SIZE,
) -> list[dict]:
    url = "https://openapi.naver.com/v1/search/blog.json"
    headers = {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
    }
    params = {
        "query": query,
        "display": min(max(display, 1), REVIEW_BATCH_SIZE),
        "start": normalize_naver_start(start),
        "sort": "sim",
    }

    async with httpx.AsyncClient() as client:
        res = await client.get(url, headers=headers, params=params)
        res.raise_for_status()
        items = res.json().get("items", [])

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
