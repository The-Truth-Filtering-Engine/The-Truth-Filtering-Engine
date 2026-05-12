import re
from html import unescape

# 훈련 코드와 동일한 업종 키워드
CATEGORY_WORDS = {
    "베이커리", "스테이크", "카페", "식당", "레스토랑",
    "치킨", "피자", "분식", "횟집", "고깃집", "술집",
}

def extract_brand(name: str) -> str:
    """가게명에서 브랜드명만 추출 (업종어·지점명 제거)"""
    if not isinstance(name, str):
        return ""
    tokens = name.split()
    brand_tokens = [
        t for t in tokens
        if t not in CATEGORY_WORDS
        and not re.search(r"(점|본점|지점|센터|타워)$", t)
    ]
    return " ".join(brand_tokens).strip()

def mask_store_name(text: str, store_name: str) -> str:
    """가게명 → '식당' 치환 (훈련 코드와 동일한 방식)"""
    if not store_name or len(store_name.strip()) < 2:
        return text

    brand = extract_brand(store_name)
    if len(brand.replace(" ", "")) < 2:
        return text

    # 공백 유연 매칭
    flexible = r"\s*".join(re.escape(part) for part in brand.split())

    # 브랜드명 + 지점명 패턴 우선
    text = re.compile(flexible + r"\s*[\uAC00-\uD7A3]+점").sub("식당", text)
    # 브랜드명 단독
    text = re.compile(flexible).sub("식당", text)
    # 단독 지점명 후처리
    text = re.sub(r"[\uAC00-\uD7A3]{2,6}(점|본점|지점)\b", "식당", text)

    return text

def preprocess(title: str, description: str, store_name: str) -> str:
    title_clean = (title or "").strip()
    desc_clean  = (description or "").strip()

    # ① HTML 엔티티 디코딩
    title_clean = unescape(title_clean)
    desc_clean  = unescape(desc_clean)

    # ② HTML 태그 제거
    title_clean = re.sub(r"<[^>]+>", "", title_clean)
    desc_clean  = re.sub(r"<[^>]+>", "", desc_clean)

    # ③ 가게명 → "식당" 치환 (특수문자 정리 전에 실행)
    title_clean = mask_store_name(title_clean, store_name)
    desc_clean  = mask_store_name(desc_clean, store_name)

    # ④ 해시태그 # 제거 (단어 보존)
    title_clean = re.sub(r"#(\S+)", r"\1 ", title_clean)
    desc_clean  = re.sub(r"#(\S+)", r"\1 ", desc_clean)

    # ⑤ 말줄임 제거
    title_clean = re.sub(r"\.{2,}|…", " ", title_clean)
    desc_clean  = re.sub(r"\.{2,}|…", " ", desc_clean)

    # ⑥ 공백 정리
    title_clean = re.sub(r"\s+", " ", title_clean).strip()
    desc_clean  = re.sub(r"\s+", " ", desc_clean).strip()

    # ⑦ 훈련과 동일하게 [SEP]로 결합
    return f"{title_clean} [SEP] {desc_clean}"