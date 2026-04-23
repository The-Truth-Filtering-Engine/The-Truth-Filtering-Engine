import asyncio
from playwright.async_api import async_playwright

async def get_blog_text(url):
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                      "AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
        )

        page = await context.new_page()

        try:
            await page.goto(url, timeout=30000)
            await page.wait_for_load_state('networkidle')

            # iframe 진입
            frame = page.frame('mainFrame')
            if frame is None:
                frame = page

            # 제목 텍스트 추출
            title_element = await frame.query_selector('.se-title-text')
            title_text = await title_element.inner_text() \
                if title_element else ""

            # 본문 전체 텍스트 추출
            body_element = await frame.query_selector('.se-main-container')
            body_text = await body_element.inner_text() \
                if body_element else ""

            return {
                "url": url,
                "title": title_text.strip(),
                "body": body_text.strip()
            }

        except Exception as e:
            print(f"텍스트 추출 실패 ({url}): {e}")
            return None

        finally:
            await browser.close()