from pathlib import Path
from optimum.intel import OVModelForSequenceClassification
from transformers import PreTrainedTokenizerFast

# electra2naver 모델 선정
MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "electra2naver"

_tokenizer = None
_model = None

def load_model() -> None:
    global _tokenizer, _model
    _tokenizer = PreTrainedTokenizerFast.from_pretrained(MODEL_DIR)
    _model = OVModelForSequenceClassification.from_pretrained(MODEL_DIR)

def predict_is_ad(review_description: str) -> int:
    if _model is None or _tokenizer is None:
        raise RuntimeError("모델이 로드되지 않았습니다.")
    text = (review_description or "").strip()
    if not text:
        return 0
    encoded = _tokenizer(text, truncation=True, padding=True, max_length=512, return_tensors="pt")
    logits = _model(**encoded).logits
    pred = logits.argmax(dim=-1).item()
    return int(pred)