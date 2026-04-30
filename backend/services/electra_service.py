import logging
from pathlib import Path

logger = logging.getLogger(__name__)

# electra2naver 모델 선정
MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "electra2naver"

_tokenizer = None
_model = None
_model_available = False

def load_model() -> None:
    global _tokenizer, _model, _model_available
    model_bin = MODEL_DIR / "openvino_model.bin"
    if not model_bin.exists():
        logger.warning(
            f"[electra_service] 모델 파일 없음: {model_bin}\n"
            "Electra 분석 기능은 비활성화됩니다. 나머지 기능은 정상 동작합니다."
        )
        _model_available = False
        return
    try:
        from optimum.intel import OVModelForSequenceClassification
        from transformers import PreTrainedTokenizerFast
        _tokenizer = PreTrainedTokenizerFast.from_pretrained(MODEL_DIR)
        _model = OVModelForSequenceClassification.from_pretrained(MODEL_DIR)
        _model_available = True
        logger.info("[electra_service] 모델 로드 완료.")
    except Exception as e:
        logger.warning(f"[electra_service] 모델 로드 실패 (기능 비활성화): {e}")
        _model_available = False

def predict_is_ad(review_description: str) -> int:
    if not _model_available or _model is None or _tokenizer is None:
        return 0  # 모델 없을 때 기본값 반환
    text = (review_description or "").strip()
    if not text:
        return 0
    encoded = _tokenizer(text, truncation=True, padding=True, max_length=512, return_tensors="pt")
    logits = _model(**encoded).logits
    pred = logits.argmax(dim=-1).item()
    return int(pred)

def score_is_ad(review_description: str) -> float:
    if not _model_available or _model is None or _tokenizer is None:
        return 0.0  # 모델 없을 때 기본값 반환
    text = (review_description or "").strip()
    if not text:
        return 0.0
    encoded = _tokenizer(text, truncation=True, padding=True, max_length=512, return_tensors="pt")
    logits = _model(**encoded).logits
    probs = logits.softmax(dim=-1)
    ad_score = probs[0, 1].item()
    return float(ad_score)