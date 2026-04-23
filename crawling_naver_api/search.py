import requests

NAVER_CLIENT_ID = "MUUADsIYWROs07ZDyToI"
NAVER_CLIENT_SECRET = "anh11zkJgj"

def get_blog_reviews(restaurant_name, display=50):
    url = "https://openapi.naver.com/v1/search/blog"
    headers = {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET
    }
    params = {
        "query": restaurant_name,
        "display": display,
        "sort": "sim"
    }

    response = requests.get(url, headers=headers, params=params)
    items = response.json()["items"]

    reviews = []
    for item in items:
        if "blog.naver.com" in item["link"]:
            reviews.append({
                "url": item["link"],
                "title": item["title"],
                "description": item["description"],  # 미리보기 텍스트
                "bloggername": item["bloggername"],
                "postdate": item["postdate"]
            })

    print(f"수집된 리뷰: {len(reviews)}개")
    return reviews