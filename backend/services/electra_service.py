import logging
from pathlib import Path
from optimum.intel import OVModelForSequenceClassification
from transformers import PreTrainedTokenizerFast

logger = logging.getLogger(__name__)

# electra2naver 모델 선정
MODEL_DIR = Path(__file__).resolve().parents[1] / "models"

_tokenizer = None
_model = None
_model_available = False

def load_model() -> None:
    global _tokenizer, _model, _model_available
    model_bin = MODEL_DIR / "openvino_model.bin"
    try:
        _tokenizer = PreTrainedTokenizerFast.from_pretrained(MODEL_DIR)
        _model = OVModelForSequenceClassification.from_pretrained(MODEL_DIR)
        _model_available = True
        logger.info("[electra_service] 모델 로드 완료.")
    except Exception as e:
        logger.warning(f"[electra_service] 모델 로드 실패 (기능 비활성화): {e}")
        _model_available = False

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
    preds = logits.argmax(dim=-1).tolist()
    probs = logits.softmax(dim=-1)
    scores = [float(probs[i, 1].item()) for i in range(len(cleaned))]
    return [int(p) for p in preds], scores