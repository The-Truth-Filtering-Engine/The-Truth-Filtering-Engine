import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.naver_service import (
    build_naver_blog_query,
    filter_blog_previews_by_store_name,
    filter_reviews_by_store_name,
)


class BuildNaverBlogQueryTest(unittest.TestCase):
    def test_adds_city_district_category_and_restaurant_hint(self):
        query = build_naver_blog_query(
            "양자강",
            {
                "address_name": "경기도 수원시 영통구 원천동 123",
                "category_name": "음식점 > 중식당",
            },
        )

        self.assertEqual(query, "양자강 수원 영통구 중식 맛집")

    def test_falls_back_to_restaurant_hint_without_metadata(self):
        self.assertEqual(build_naver_blog_query("양자강"), "양자강 맛집")

    def test_cafe_category_uses_cafe_without_restaurant_hint(self):
        query = build_naver_blog_query(
            "커피빈",
            {
                "road_address_name": "서울특별시 강남구 테헤란로 123",
                "category_name": "카페",
            },
        )

        self.assertEqual(query, "커피빈 서울 강남구 카페")

    def test_removes_duplicate_and_blank_tokens(self):
        query = build_naver_blog_query(
            " 양자강 ",
            {
                "address_name": "경기 수원시 수원시 영통구",
                "category_name": "중식당",
            },
        )

        self.assertEqual(query, "양자강 수원 영통구 중식 맛집")


class StoreNameFilterTest(unittest.TestCase):
    def test_filters_blog_previews_without_store_name(self):
        blogs = filter_blog_previews_by_store_name(
            [
                {
                    "title": "수원 양자강 탕수육 후기",
                    "description": "영통구 중식 맛집",
                },
                {
                    "title": "수원 영통구 중식 맛집 모음",
                    "description": "짜장면이 맛있는 곳들",
                },
            ],
            "양자강",
        )

        self.assertEqual(len(blogs), 1)
        self.assertEqual(blogs[0]["title"], "수원 양자강 탕수육 후기")

    def test_filters_cached_reviews_without_store_name(self):
        reviews = filter_reviews_by_store_name(
            [
                {
                    "review_title": "양자강 광교점 방문",
                    "review_description": "짬뽕 후기",
                },
                {
                    "review_title": "광교 호수공원 산책",
                    "review_description": "주변 맛집도 많아요",
                },
            ],
            "양자강 광교점",
        )

        self.assertEqual(len(reviews), 1)
        self.assertIn("양자강", reviews[0]["review_title"])


if __name__ == "__main__":
    unittest.main()
