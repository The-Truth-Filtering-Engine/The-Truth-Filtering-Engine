import asyncio
import json
import time
from map_crawler import get_map_blog_urls
from capture import get_blog_text

async def analyze_from_map(map_url):
    start = time.time()

    # 1. 네이버 지도에서 블로그 URL 수집
    urls = await get_map_blog_urls(map_url)

    if not urls:
        print("블로그 리뷰를 찾을 수 없습니다.")
        return []

    # 2. 병렬 3개씩 텍스트 추출
    semaphore = asyncio.Semaphore(3)

    async def crawl_one(url):
        async with semaphore:
            await asyncio.sleep(1)
            return await get_blog_text(url)

    results = await asyncio.gather(*[crawl_one(url) for url in urls])
    results = [r for r in results if r is not None]

    elapsed = round(time.time() - start, 1)
    print(f"완료: {len(results)}개 수집 / {elapsed}초 소요")

    # 3. JSON 저장
    with open('reviews.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    return results

if __name__ == "__main__":
    map_url = input("네이버 지도 링크를 입력하세요: ")
    asyncio.run(analyze_from_map(map_url))