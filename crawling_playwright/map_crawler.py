import asyncio
import re
from playwright.async_api import async_playwright

def extract_place_id(url):
    match = re.search(r'/place/(\d+)', url)
    if match:
        return match.group(1)
    return None

async def get_map_blog_urls(map_url):
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                      "AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
        )
        page = await context.new_page()

        try:
            # 1. 페이지 이동
            print("페이지 이동 중...")
            await page.goto(map_url, timeout=60000, wait_until='domcontentloaded')
            await page.wait_for_timeout(5000)
            real_url = page.url
            print(f"실제 URL: {real_url}")

            place_id = extract_place_id(real_url)
            print(f"식당 ID: {place_id}")

            # 2. pcmap.place.naver.com frame 찾기
            target_frame = None
            for frame in page.frames:
                if 'pcmap.place.naver.com' in frame.url:
                    target_frame = frame
                    print(f"타겟 frame 발견: {frame.url}")
                    break

            if target_frame is None:
                print("타겟 frame 없음")
                return []

            # 3. 리뷰 탭 클릭
            print("리뷰 탭 클릭 중...")
            tabs = await target_frame.query_selector_all('._tab-menu')
            for tab in tabs:
                text = await tab.inner_text()
                if '리뷰' in text:
                    await tab.click()
                    await page.wait_for_timeout(2000)
                    print("리뷰 탭 클릭 완료")
                    break

            # 4. 블로그 리뷰 카테고리 클릭
            print("블로그 리뷰 카테고리 클릭 중...")
            buttons = await target_frame.query_selector_all('a, button, span')
            for btn in buttons:
                try:
                    text = await btn.inner_text()
                    if '블로그 리뷰' in text:
                        await btn.click()
                        await page.wait_for_timeout(2000)
                        print(f"블로그 리뷰 클릭 완료: {text.strip()}")
                        break
                except:
                    continue

            # 5. 스크롤하며 리뷰 더 불러오기
            for i in range(10):
                await target_frame.evaluate('window.scrollTo(0, document.body.scrollHeight)')
                await page.wait_for_timeout(1000)
                print(f"스크롤 {i+1}/10")

            # 6. 블로그 URL 수집
            review_links = await target_frame.query_selector_all(
                'a[role="listitem"][href*="blog.naver.com"]'
            )
            if not review_links:
                print("방법 1 실패 → 방법 2 시도")
                review_links = await target_frame.query_selector_all(
                    'a[href*="blog.naver.com"]'
                )

            urls = []
            for link in review_links:
                href = await link.get_attribute('href')
                if href and href not in urls:
                    urls.append(href)

            print(f"수집된 블로그 URL: {len(urls)}개")
            return urls

        except Exception as e:
            print(f"크롤링 실패: {e}")
            return []

        finally:
            await browser.close()