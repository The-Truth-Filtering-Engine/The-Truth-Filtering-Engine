import asyncio
import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.naver_service import (  # noqa: E402
    fetch_store_blog_previews,
    filter_blogs_by_store_name,
    normalize_store_name_for_match,
)


class FakeResponse:
    def __init__(self, items):
        self._items = items

    def raise_for_status(self):
        return None

    def json(self):
        return {"items": self._items}


class FakeClient:
    def __init__(self, pages):
        self.pages = pages
        self.calls = []

    async def get(self, url, headers, params):
        self.calls.append(dict(params))
        return FakeResponse(self.pages.get(params["start"], []))


def _blog(title, description="", link="https://blog.example/post"):
    return {
        "title": title,
        "description": description,
        "link": link,
        "bloggername": "tester",
        "postdate": "20260511",
    }


def _many_missing(prefix, count):
    return [
        _blog(f"{prefix} 근처 카페 {index}", "다른 매장 후기", f"https://x/{prefix}/{index}")
        for index in range(count)
    ]


class NaverServiceStoreNameFilterTest(unittest.TestCase):
    def test_normalizes_store_name_for_exact_match(self):
        self.assertEqual(
            normalize_store_name_for_match(" <b>스타벅스</b> 강남-역점! "),
            "스타벅스강남역점",
        )

    def test_filters_out_results_without_exact_store_name(self):
        blogs = [
            _blog("스타벅스 강남역점 라떼 후기"),
            _blog("강남역 카페", "다녀온 곳은 스타벅스 강남역점 입니다"),
            _blog("스타벅스 강남역", "좋았던 역점 근처 카페"),
            _blog("스타벅스", "강남역점"),
        ]

        filtered = filter_blogs_by_store_name(blogs, "스타벅스 강남역점")

        self.assertEqual([item["title"] for item in filtered], [
            "스타벅스 강남역점 라떼 후기",
            "강남역 카페",
        ])

    def test_rejects_store_name_when_letters_are_attached(self):
        blogs = [
            _blog("슈슈커리 신상 메뉴"),
            _blog("맛슈슈 방문기"),
            _blog("슈슈123 후기"),
            _blog("슈슈 커리"),
            _blog("[슈슈] 주말 후기"),
        ]

        filtered = filter_blogs_by_store_name(blogs, "슈슈")

        self.assertEqual([item["title"] for item in filtered], [
            "슈슈 커리",
            "[슈슈] 주말 후기",
        ])

    def test_filters_cached_review_fields(self):
        reviews = [
            {
                "review_title": "브런치 기록",
                "review_description": "스타벅스 강남역점 에서 커피",
            },
            {
                "review_title": "강남역 카페",
                "review_description": "다른 스타벅스 방문",
            },
        ]

        filtered = filter_blogs_by_store_name(reviews, "스타벅스 강남역점")

        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0]["review_title"], "브런치 기록")

    def test_fetches_three_raw_pages_and_keeps_only_matching_results(self):
        pages = {
            1: _many_missing("first", 99)
            + [_blog("<b>스타벅스</b> 강남역점 첫 후기", link="https://x/match-1")],
            101: [_blog("스타벅스 강남역점 두번째 후기", link="https://x/match-2")]
            + _many_missing("second", 99),
            201: _many_missing("third", 99)
            + [_blog("강남역 카페", "스타벅스 강남역점 재방문", "https://x/match-3")],
        }
        client = FakeClient(pages)

        result = asyncio.run(
            fetch_store_blog_previews(
                "스타벅스 강남역점 강남 카페",
                "스타벅스 강남역점",
                display=100,
                max_results=300,
                client=client,
            )
        )

        self.assertEqual([call["start"] for call in client.calls], [1, 101, 201])
        self.assertTrue(all(call["display"] == 100 for call in client.calls))
        self.assertEqual(result.raw_count, 300)
        self.assertTrue(result.exhausted)
        self.assertEqual([item["link"] for item in result.items], [
            "https://x/match-1",
            "https://x/match-2",
            "https://x/match-3",
        ])


if __name__ == "__main__":
    unittest.main()
