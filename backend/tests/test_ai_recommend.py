import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from routers import ai_recommend  # noqa: E402
from services.supabase_service import (  # noqa: E402
    AI_RECOMMEND_REVIEW_ORDER,
    _build_ai_recommendation_query_params,
)


REGION = {
    "si": "경기도",
    "gu": "수원시 영통구",
    "dong": "광교1동",
    "legal_dong": "이의동",
}


class AiRecommendRegionFilterTest(unittest.TestCase):
    def test_si_scope_matches_abbreviated_address_name(self):
        review = {"address_name": "경기 수원시 영통구 이의동 1347-1"}

        self.assertTrue(
            ai_recommend._review_matches_region(review, None, REGION, "si")
        )
        self.assertIn("경기도", ai_recommend._address_search_terms(REGION, "si"))
        self.assertIn("경기", ai_recommend._address_search_terms(REGION, "si"))

    def test_gu_scope_requires_matching_city_and_district(self):
        matching = {"address_name": "경기 수원시 영통구 이의동 1347-1"}
        other_gu = {"address_name": "경기 수원시 팔달구 이의동 1347-1"}

        self.assertTrue(
            ai_recommend._review_matches_region(matching, None, REGION, "gu")
        )
        self.assertFalse(
            ai_recommend._review_matches_region(other_gu, None, REGION, "gu")
        )
        self.assertIn("영통구", ai_recommend._address_search_terms(REGION, "gu"))

    def test_dong_scope_accepts_legal_dong_and_rejects_other_gu(self):
        legal_dong = {"address_name": "경기 수원시 영통구 이의동 1347-1"}
        other_gu = {"address_name": "경기 용인시 수지구 이의동 1347-1"}

        self.assertTrue(
            ai_recommend._review_matches_region(legal_dong, None, REGION, "dong")
        )
        self.assertFalse(
            ai_recommend._review_matches_region(other_gu, None, REGION, "dong")
        )
        dong_terms = ai_recommend._address_search_terms(REGION, "dong")
        self.assertIn("광교1동", dong_terms)
        self.assertIn("이의동", dong_terms)
        self.assertEqual(ai_recommend._serialize_region(REGION)["dong"], "이의동")

    def test_ai_recommendation_query_params_filter_score_address_and_sort(self):
        params = _build_ai_recommendation_query_params(
            threshold=0.1,
            address_terms=["경기도", "경기"],
        )

        self.assertIn(("is_ad_finetuned_pred", "not.is.null"), params)
        self.assertIn(("is_ad_finetuned_pred", "lte.0.1"), params)
        self.assertIn(("order", AI_RECOMMEND_REVIEW_ORDER), params)

        params_by_key = {key: value for key, value in params}
        self.assertEqual(params_by_key["address_name"], "not.is.null")
        self.assertIn("address_name.ilike.*경기도*", params_by_key["or"])
        self.assertIn("address_name.ilike.*경기*", params_by_key["or"])
        self.assertEqual(
            params_by_key["order"],
            "is_ad_finetuned_pred.asc,review_postdate.desc,id.desc",
        )


if __name__ == "__main__":
    unittest.main()
