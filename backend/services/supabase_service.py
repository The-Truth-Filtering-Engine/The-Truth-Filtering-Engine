from supabase import create_client
import os

supabase = create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_KEY"))

async def get_cached_reviews(name: str) -> list:
    res = supabase.table("reviews") \
        .select("*") \
        .eq("name", name) \
        .execute()
    return res.data if res.data else []

async def save_reviews(name: str, blogs: list[dict]):
    rows = [
        {
            "name": name,
            "review_url": blog.get("link"),
            "review_title": blog.get("title"),
            "review_description": blog.get("description"),
            "review_bloggername": blog.get("bloggername"),
            "review_postdate": blog.get("postdate"),
        }
        for blog in blogs
    ]
    supabase.table("reviews").insert(rows).execute()

async def update_llm_pred(review_id: int, is_ad_llm_pred: float):  
    supabase.table("reviews") \
        .update({"is_ad_llm_pred": float(is_ad_llm_pred)}) \
        .eq("id", review_id) \
        .execute()

async def update_electra_pred(review_id: int, is_ad_electra_pred: int):
    supabase.table("reviews") \
        .update({"is_ad_electra_pred": is_ad_electra_pred}) \
        .eq("id", review_id) \
        .execute()

async def update_finetuned_pred(review_id: int, is_ad_finetuned_pred: float):
    res = supabase.table("reviews") \
        .update({"is_ad_finetuned_pred": float(is_ad_finetuned_pred)}) \
        .eq("id", review_id) \
        .execute()

async def get_ai_recommendation_reviews(
    threshold: float = 0.1,
    page: int = 1,
    page_size: int = 10,
) -> dict:
    page = max(1, page)
    page_size = max(1, min(page_size, 10))
    end_index = page * page_size
    fetch_limit = min(max((end_index + page_size) * 20, 100), 1000)

    res = supabase.table("reviews") \
        .select("*") \
        .lt("is_ad_finetuned_pred", threshold) \
        .order("is_ad_finetuned_pred", desc=False) \
        .limit(fetch_limit) \
        .execute()
    rows = res.data if res.data else []

    grouped: dict[str, dict] = {}
    for row in rows:
        name = (row.get("name") or "").strip()
        if not name or name in grouped:
            continue

        grouped[name] = row
        if len(grouped) >= end_index + 1:
            break

    grouped_rows = list(grouped.values())
    start_index = (page - 1) * page_size

    return {
        "items": grouped_rows[start_index:end_index],
        "has_next": len(grouped_rows) > end_index,
    }
