import re
from html import unescape

def preprocess(title: str, description: str, store_name: str) -> str:
    # Step 1 — 컬럼 병합
    text = (title or "") + ". " + (description or "")

    # Step 2-③ 가게명 → "식당" 치환 (3글자 미만 제외)
    name = (store_name or "").strip()
    if len(name) >= 2:
        text = text.replace(name, "식당")

    # Step 2-① HTML 엔티티 디코딩
    text = unescape(text)

    # Step 2-② HTML 태그 제거
    text = re.sub(r"<[^>]+>", "", text)

    # Step 2-④ 해시태그 단어 추출
    text = re.sub(r"#(\S+)", r"\1", text)

    # Step 2-⑤ 말줄임 제거
    text = re.sub(r"\.{2,}|…", " ", text)

    # Step 2-⑥ 특수문자 정리 (한글/영문/숫자/부호만 유지)
    text = re.sub(r"[^\w\s가-힣a-zA-Z0-9.,!?()%\-]", " ", text)

    # Step 2-⑦ 공백 정리
    text = re.sub(r"\s+", " ", text).strip()

    return text