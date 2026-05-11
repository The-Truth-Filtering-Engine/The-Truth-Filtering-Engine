import httpx, os, re
from html import unescape
from services.review_limits import REVIEW_BATCH_SIZE, normalize_naver_start

NAVER_CLIENT_ID = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")

_PROVINCE_ALIASES = {
    "경기",
    "강원",
    "충북",
    "충남",
    "전북",
    "전남",
    "경북",
    "경남",
    "제주",
}
_MAJOR_CITY_ALIASES = {
    "서울": "서울",
    "서울특별시": "서울",
    "부산": "부산",
    "부산광역시": "부산",
    "대구": "대구",
    "대구광역시": "대구",
    "인천": "인천",
    "인천광역시": "인천",
    "광주": "광주",
    "광주광역시": "광주",
    "대전": "대전",
    "대전광역시": "대전",
    "울산": "울산",
    "울산광역시": "울산",
    "세종": "세종",
    "세종시": "세종",
    "세종특별자치시": "세종",
}
_CATEGORY_HINTS = (
    ("카페", "카페"),
    ("커피", "카페"),
    ("중식", "중식"),
    ("중국", "중식"),
    ("짜장", "중식"),
    ("한식", "한식"),
    ("일식", "일식"),
    ("일본", "일식"),
    ("양식", "양식"),
    ("분식", "분식"),
    ("치킨", "치킨"),
    ("피자", "피자"),
    ("고기", "고기"),
    ("구이", "고기"),
    ("횟집", "횟집"),
    ("회", "횟집"),
    ("해산물", "해산물"),
    ("돈까스", "돈까스"),
    ("국수", "국수"),
    ("면", "면"),
    ("술집", "술집"),
    ("주점", "술집"),
    ("베이커리", "베이커리"),
    ("디저트", "디저트"),
)

def _clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)  # <b>, </b> 등 HTML 태그 제거
    text = unescape(text)                 # &quot; &amp; 등 HTML 엔티티 디코딩
    return text.strip()


def build_naver_blog_query(query: str, place_metadata: dict | None = None) -> str:
    metadata = place_metadata or {}
    parts = [_clean_query_token(query)]
    parts.extend(
        _address_tokens(
            metadata.get("address_name"),
            metadata.get("road_address_name"),
        )
    )

    category_hint = _category_hint(
        metadata.get("category_name"),
        metadata.get("category_group_name"),
    )
    if category_hint:
        parts.append(category_hint)
    if category_hint != "카페":
        parts.append("맛집")

    return " ".join(_dedupe_tokens(parts)) or query.strip()


def filter_blog_previews_by_store_name(
    blogs: list[dict],
    store_name: str,
) -> list[dict]:
    return [
        blog
        for blog in blogs
        if _contains_store_name(
            store_name,
            blog.get("title", ""),
            blog.get("description", ""),
        )
    ]


def filter_reviews_by_store_name(
    reviews: list[dict],
    store_name: str,
) -> list[dict]:
    return [
        review
        for review in reviews
        if _contains_store_name(
            store_name,
            review.get("review_title", ""),
            review.get("review_description", ""),
        )
    ]


def _clean_query_token(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _dedupe_tokens(tokens: list[str]) -> list[str]:
    seen = set()
    deduped = []
    for token in tokens:
        cleaned = _clean_query_token(token)
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        deduped.append(cleaned)
    return deduped


def _address_tokens(*addresses: object) -> list[str]:
    tokens = []
    for address in addresses:
        for raw_token in re.split(r"[\s,]+", _clean_query_token(address)):
            token = _location_token(raw_token)
            if not token or token in tokens:
                continue
            tokens.append(token)
            if len(tokens) >= 2:
                return tokens
    return tokens


def _location_token(value: str) -> str | None:
    token = re.sub(r"\([^)]*\)", "", value)
    token = re.sub(r"[^0-9A-Za-z가-힣]", "", token)
    if not token or any(char.isdigit() for char in token):
        return None
    if token in _MAJOR_CITY_ALIASES:
        return _MAJOR_CITY_ALIASES[token]
    if token in _PROVINCE_ALIASES or token.endswith(("도", "특별자치도")):
        return None
    if token.endswith("시") and len(token) > 2:
        return token[:-1]
    if token.endswith(("구", "군")) and len(token) > 1:
        return token
    return None


def _category_hint(*categories: object) -> str | None:
    category_text = " ".join(_clean_query_token(category) for category in categories)
    if not category_text:
        return None
    for needle, hint in _CATEGORY_HINTS:
        if needle in category_text:
            return hint
    return None


def _contains_store_name(store_name: str, *texts: object) -> bool:
    required = _primary_store_name_token(store_name)
    if not required:
        return True

    haystack = _normalize_for_match(" ".join(_clean_query_token(text) for text in texts))
    return required in haystack


def _primary_store_name_token(store_name: str) -> str:
    for raw_token in re.split(r"[\s,/|]+", _clean_query_token(store_name)):
        token = _normalize_for_match(raw_token)
        if token.endswith("점") and len(token) > 2:
            token = token[:-1]
        if len(token) >= 2:
            return token
    return _normalize_for_match(store_name)


def _normalize_for_match(value: object) -> str:
    return re.sub(r"[^0-9A-Za-z가-힣]", "", str(value or "")).lower()


async def fetch_blog_previews(
    query: str,
    *,
    start: int = 1,
    display: int = REVIEW_BATCH_SIZE,
    required_store_name: str | None = None,
) -> list[dict]:
    url = "https://openapi.naver.com/v1/search/blog.json"
    headers = {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
    }
    params = {
        "query": query,
        "display": min(max(display, 1), REVIEW_BATCH_SIZE),
        "start": normalize_naver_start(start),
        "sort": "sim",
    }

    async with httpx.AsyncClient() as client:
        res = await client.get(url, headers=headers, params=params)
        res.raise_for_status()
        items = res.json().get("items", [])

    blogs = [
        {
            "title":       _clean(item["title"]),
            "description": _clean(item["description"]),
            "link":        item["link"],
            "bloggername": item["bloggername"],
            "postdate":    item["postdate"],
        }
        for item in items
    ]

    if required_store_name:
        return filter_blog_previews_by_store_name(blogs, required_store_name)
    return blogs
