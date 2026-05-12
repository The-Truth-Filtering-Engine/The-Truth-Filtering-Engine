import logging
from pathlib import Path

logger = logging.getLogger(__name__)

MODEL_DIR = Path(__file__).resolve().parents[1] / "models"

_tokenizer = None
_model = None
_model_available = False

def load_model() -> None:
    global _tokenizer, _model, _model_available
    model_bin = MODEL_DIR / "openvino_model.bin"
    if not model_bin.exists():
        logger.warning(
            f"[MODEL_service] 모델 파일 없음: {model_bin}\n"
            "MODEL 분석 기능은 비활성화됩니다. 나머지 기능은 정상 동작합니다."
        )
        _model_available = False
        return
    try:
        from optimum.intel import OVModelForSequenceClassification
        from transformers import AutoTokenizer
        _tokenizer = AutoTokenizer.from_pretrained(str(MODEL_DIR))
        _model = OVModelForSequenceClassification.from_pretrained(str(MODEL_DIR))
        _model_available = True
        logger.info("[MODEL_service] 모델 로드 완료.")
    except Exception as e:
        logger.warning(f"[MODEL_service] 모델 로드 실패 (기능 비활성화): {e}")
        _model_available = False

AD_THRESHOLD_HIGH = 0.739  # 하(광고)
AD_THRESHOLD_LOW  = 0.343  # 상(진성), 중(의심): 0.343 ~ 0.739

def score_is_ad(review_description: str) -> float:
    if not _model_available or _model is None or _tokenizer is None:
        return 0.0
    text = (review_description or "").strip()
    if not text:
        return 0.0
    encoded = _tokenizer(text, truncation=True, padding=True, max_length=512, return_tensors="pt")
    logits = _model(**encoded).logits
    probs = logits.softmax(dim=-1)
    return float(probs[0, 1].item())

def predict_is_ad(review_description: str) -> int:
    """0=진성, 1=의심, 2=광고"""
    score = score_is_ad(review_description)
    if score >= AD_THRESHOLD_HIGH:
        return 2
    if score >= AD_THRESHOLD_LOW:
        return 1
    return 0

def predict_and_score_batch(texts: list[str]) -> tuple[list[int], list[float]]:
    if not _model_available or _model is None or _tokenizer is None:
        return [0] * len(texts), [0.0] * len(texts)

    cleaned = [(t or "").strip() for t in texts]
    encoded = _tokenizer(
        cleaned,
        truncation=True,
        padding=True,
        max_length=256,
        return_tensors="pt",
    )
    logits = _model(**encoded).logits
    probs  = logits.softmax(dim=-1)
    scores = [float(probs[i, 1].item()) for i in range(len(cleaned))]
    preds  = [
        2 if s >= AD_THRESHOLD_HIGH else
        1 if s >= AD_THRESHOLD_LOW  else
        0
        for s in scores
    ]
    return preds, scores