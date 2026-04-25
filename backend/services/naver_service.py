import httpx, os

NAVER_CLIENT_ID = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")

async def fetch_blog_previews(query: str) -> list[dict]:
    url = "https://openapi.naver.com/v1/search/blog.json"
    headers = {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
    }
    params = {"query": query, "display": 20, "sort": "sim"}

    async with httpx.AsyncClient() as client:
        res = await client.get(url, headers=headers, params=params)
        items = res.json().get("items", [])

    return [
        {
            "title": item["title"],
            "description": item["description"],
            "link": item["link"],
            "bloggername": item["bloggername"],
            "postdate": item["postdate"],
        }
        for item in items
    ]