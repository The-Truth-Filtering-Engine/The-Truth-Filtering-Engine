import os
from pathlib import Path
from typing import Any
from dotenv import load_dotenv

import torch
from supabase import Client, create_client
from transformers import AutoModelForSequenceClassification, AutoTokenizer

load_dotenv(Path(__file__).resolve().parents[2] / "the_truth_filtering_engine" / ".env")

MODEL_DIR = Path(__file__).resolve().parents[2] / "classifier" / "electra2naver"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

_tokenizer = None
_model = None
_supabase = None


def _get_supabase() -> Client:
    global _supabase
    if _supabase is None:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_KEY")
        if not url or not key:
            raise ValueError("SUPABASE_URL/SUPABASE_KEY environment variables are required.")
        _supabase = create_client(url, key)
    return _supabase


def _load_model() -> None:
    global _tokenizer, _model
    if _tokenizer is None:
        _tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
    if _model is None:
        _model = AutoModelForSequenceClassification.from_pretrained(MODEL_DIR)
        _model.to(DEVICE)
        _model.eval()


def predict_is_ad(review_description: str) -> int:
    _load_model()
    text = (review_description or "").strip()
    if not text:
        return 0

    encoded = _tokenizer(
        text,
        truncation=True,
        padding=True,
        max_length=512,
        return_tensors="pt",
    )
    encoded = {k: v.to(DEVICE) for k, v in encoded.items()}

    with torch.no_grad():
        logits = _model(**encoded).logits
        pred = torch.argmax(logits, dim=-1).item()
    return int(pred)


def _fetch_target_reviews(batch_size: int) -> list[dict[str, Any]]:
    supabase = _get_supabase()
    response = (
        supabase.table("reviews")
        .select("id, review_description")
        .is_("is_ad_electra_pred", "null")
        .limit(batch_size)
        .execute()
    )
    return response.data or []


def _update_electra_pred(review_id: int, is_ad: int) -> None:
    supabase = _get_supabase()
    (
        supabase.table("reviews")
        .update({"is_ad_electra_pred": is_ad})
        .eq("id", review_id)
        .execute()
    )


async def classify_reviews_with_electra(batch_size: int = 200) -> dict[str, int]:
    targets = _fetch_target_reviews(batch_size=batch_size)
    updated = 0

    for row in targets:
        review_id = row["id"]
        review_description = row.get("review_description") or ""
        pred = predict_is_ad(review_description)
        _update_electra_pred(review_id, pred)
        updated += 1

    return {"selected": len(targets), "updated": updated}


if __name__ == "__main__":
    import asyncio

    result = asyncio.run(classify_reviews_with_electra())
    print(result)
