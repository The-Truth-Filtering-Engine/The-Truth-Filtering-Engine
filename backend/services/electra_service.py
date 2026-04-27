from pathlib import Path

import torch
from transformers import AutoModelForSequenceClassification, AutoTokenizer

# backend/models/electra2naver 기준 경로
MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "electra2naver"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

_tokenizer = None
_model = None


def load_model() -> None:
    """서버 시작 시 main.py lifespan에서 1회 호출"""
    global _tokenizer, _model
    print(f"[ELECTRA] 모델 로드 중: {MODEL_DIR}")
    _tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
    _model = AutoModelForSequenceClassification.from_pretrained(MODEL_DIR)
    _model.to(DEVICE)
    _model.eval()
    print(f"[ELECTRA] 모델 로드 완료 (device: {DEVICE})")


def predict_is_ad(review_description: str) -> int:
    """
    리뷰 본문을 받아 광고 여부를 반환합니다.
    Returns:
        0: 비광고
        1: 광고
    """
    if _model is None or _tokenizer is None:
        raise RuntimeError("모델이 로드되지 않았습니다. load_model()을 먼저 호출하세요.")

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