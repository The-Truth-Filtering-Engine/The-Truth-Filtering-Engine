import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

_DEFAULT_MODEL_DIR = Path(__file__).resolve().parents[1] / "models"
MODEL_DIR = Path(os.getenv("NER_MODEL_DIR", "") or _DEFAULT_MODEL_DIR)

_tokenizer = None
_model = None
_model_available = False

LABEL_MAP = {
    0: "O",
    1: "B-PERSON",
    2: "I-PERSON",
    3: "B-STORE",
    4: "I-STORE",
    5: "B-LOCATION",
    6: "I-LOCATION",
    7: "B-MENU",
    8: "I-MENU",
    9: "B-BRAND",
    10: "I-BRAND",
}

_EMPTY_ENTITIES = {
    "persons": [],
    "stores": [],
    "locations": [],
    "menus": [],
    "brands": [],
    "raw": [],
}


def load_ner_model() -> None:
    global _tokenizer, _model, _model_available

    model_bin = MODEL_DIR / "openvino_model.bin"

    if not model_bin.exists():
        logger.warning(f"[ner_service] model file not found: {MODEL_DIR}")
        _model_available = False
        return

    try:
        from optimum.intel import OVModelForTokenClassification
        from transformers import AutoTokenizer

        _tokenizer = AutoTokenizer.from_pretrained(str(MODEL_DIR))
        _model = OVModelForTokenClassification.from_pretrained(
            str(MODEL_DIR),
            ov_config={
                "PERFORMANCE_HINT": "LATENCY",
                "NUM_STREAMS": "1",
            },
        )
        _model_available = True
        logger.info("[ner_service] NER model loaded")
    except Exception as exc:
        logger.warning(f"[ner_service] NER model load failed; disabled: {exc}")
        _model_available = False


def _empty_entities() -> dict:
    return {key: list(value) for key, value in _EMPTY_ENTITIES.items()}


def empty_entities() -> dict:
    return _empty_entities()


def load_model() -> None:
    load_ner_model()


def _merge_entities(tokens, labels):
    results = []
    current_text = ""
    current_type = None

    for token, label in zip(tokens, labels):
        if token in {"[CLS]", "[SEP]", "[PAD]"}:
            continue

        if label == "O":
            if current_text:
                results.append(
                    {
                        "text": current_text.strip(),
                        "type": current_type,
                    }
                )
                current_text = ""
                current_type = None
            continue

        if "-" not in label:
            continue

        prefix, entity_type = label.split("-", 1)
        token = token.replace("##", "")

        if prefix == "B":
            if current_text:
                results.append(
                    {
                        "text": current_text.strip(),
                        "type": current_type,
                    }
                )
            current_text = token
            current_type = entity_type
        elif prefix == "I" and current_type == entity_type:
            current_text += token

    if current_text:
        results.append(
            {
                "text": current_text.strip(),
                "type": current_type,
            }
        )

    return results


def _dedupe(values: list[str]) -> list[str]:
    seen = set()
    deduped = []
    for value in values:
        text = str(value or "").strip()
        if not text or text in seen:
            continue
        seen.add(text)
        deduped.append(text)
    return deduped


def extract_entities(text: str) -> dict:
    if not _model_available or _model is None or _tokenizer is None:
        return _empty_entities()

    text = (text or "").strip()
    if not text:
        return _empty_entities()

    try:
        encoded = _tokenizer(
            text,
            truncation=True,
            padding=True,
            max_length=256,
            return_tensors="pt",
        )
        outputs = _model(**encoded)
        predictions = outputs.logits.argmax(dim=-1)[0]
        input_ids = encoded["input_ids"][0]
        tokens = _tokenizer.convert_ids_to_tokens(input_ids)
        labels = [LABEL_MAP.get(int(pred.item()), "O") for pred in predictions]
        merged = _merge_entities(tokens, labels)
    except Exception as exc:
        logger.warning(f"[ner_service] entity extraction failed: {exc}")
        return _empty_entities()

    result = _empty_entities()
    result["raw"] = merged

    for item in merged:
        entity_type = item.get("type")
        entity_text = str(item.get("text") or "").strip()
        if not entity_text:
            continue

        if entity_type == "PERSON":
            result["persons"].append(entity_text)
        elif entity_type == "STORE":
            result["stores"].append(entity_text)
        elif entity_type == "LOCATION":
            result["locations"].append(entity_text)
        elif entity_type == "MENU":
            result["menus"].append(entity_text)
        elif entity_type == "BRAND":
            result["brands"].append(entity_text)

    for key in ("persons", "stores", "locations", "menus", "brands"):
        result[key] = _dedupe(result[key])

    return result
