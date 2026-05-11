import httpx, os, re, unicodedata
from typing import NamedTuple
from html import unescape
from services.review_limits import (
    MAX_REVIEW_RESULTS,
    REVIEW_BATCH_SIZE,
    normalize_naver_start,
)

NAVER_CLIENT_ID = os.getenv("NAVER_CLIENT_ID")
NAVER_CLIENT_SECRET = os.getenv("NAVER_CLIENT_SECRET")
NAVER_BLOG_API_URL = "https://openapi.naver.com/v1/search/blog.json"
NAVER_BLOG_MAX_DISPLAY = 100
_MATCH_WORD_CHAR_PATTERN = r"0-9a-z가-힣"
_MATCH_SEPARATOR_PATTERN = rf"[^{_MATCH_WORD_CHAR_PATTERN}]*"

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


class BlogFetchResult(NamedTuple):
    items: list[dict]
    raw_count: int
    exhausted: bool


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


def normalize_store_name_for_match(value: object) -> str:
    text = unicodedata.normalize("NFKC", _clean(str(value or ""))).casefold()
    return re.sub(r"[^0-9a-z가-힣]", "", text)


def _normalize_text_for_match(value: object) -> str:
    return unicodedata.normalize("NFKC", _clean(str(value or ""))).casefold()


def _store_name_match_pattern(store_name: object) -> re.Pattern | None:
    required = normalize_store_name_for_match(store_name)
    if not required:
        return None

    required_chars = _MATCH_SEPARATOR_PATTERN.join(
        re.escape(char)
        for char in required
    )
    return re.compile(
        rf"(?<![{_MATCH_WORD_CHAR_PATTERN}])"
        rf"{required_chars}"
        rf"(?![{_MATCH_WORD_CHAR_PATTERN}])"
    )


def blog_mentions_store_name(blog: dict, store_name: object) -> bool:
    pattern = _store_name_match_pattern(store_name)
    if pattern is None:
        return True

    candidates = (
        blog.get("title"),
        blog.get("description"),
        blog.get("review_title"),
        blog.get("review_description"),
    )
    return any(
        pattern.search(_normalize_text_for_match(candidate))
        for candidate in candidates
    )


def filter_blogs_by_store_name(blogs: list[dict], store_name: object) -> list[dict]:
    return [
        blog
        for blog in blogs
        if blog_mentions_store_name(blog, store_name)
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

async def fetch_blog_previews(
    query: str,
    *,
    start: int = 1,
    display: int = REVIEW_BATCH_SIZE,
) -> list[dict]:
    async with httpx.AsyncClient() as client:
        return await _fetch_blog_previews_page(
            client,
            query,
            start=start,
            display=display,
        )


async def fetch_store_blog_previews(
    query: str,
    store_name: str,
    *,
    start: int = 1,
    display: int = REVIEW_BATCH_SIZE,
    max_results: int = MAX_REVIEW_RESULTS,
    client: httpx.AsyncClient | None = None,
) -> BlogFetchResult:
    if client is not None:
        return await _fetch_store_blog_previews(
            client,
            query,
            store_name,
            start=start,
            display=display,
            max_results=max_results,
        )

    async with httpx.AsyncClient() as owned_client:
        return await _fetch_store_blog_previews(
            owned_client,
            query,
            store_name,
            start=start,
            display=display,
            max_results=max_results,
        )


async def _fetch_store_blog_previews(
    client: httpx.AsyncClient,
    query: str,
    store_name: str,
    *,
    start: int,
    display: int,
    max_results: int,
) -> BlogFetchResult:
    page_display = NAVER_BLOG_MAX_DISPLAY
    first_start = normalize_naver_start(start)
    max_start = min(max(max_results, 1), MAX_REVIEW_RESULTS)
    page_starts = range(first_start, max_start + 1, page_display)
    filtered = []
    raw_count = 0
    exhausted = False

    for page_start in page_starts:
        page = await _fetch_blog_previews_page(
            client,
            query,
            start=page_start,
            display=page_display,
        )
        raw_count += len(page)
        filtered.extend(filter_blogs_by_store_name(page, store_name))
        if len(page) < page_display or page_start + page_display - 1 >= max_start:
            exhausted = True
            break

    return BlogFetchResult(
        items=filtered[:max_results],
        raw_count=raw_count,
        exhausted=exhausted,
    )


async def _fetch_blog_previews_page(
    client: httpx.AsyncClient,
    query: str,
    *,
    start: int,
    display: int,
) -> list[dict]:
    headers = {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
    }
    params = {
        "query": query,
        "display": min(max(display, 1), NAVER_BLOG_MAX_DISPLAY),
        "start": normalize_naver_start(start),
        "sort": "sim",
    }

    res = await client.get(NAVER_BLOG_API_URL, headers=headers, params=params)
    res.raise_for_status()
    items = res.json().get("items", [])

    return [_normalize_blog_item(item) for item in items]


def _normalize_blog_item(item: dict) -> dict:
    return {
        "title": _clean(item.get("title", "")),
        "description": _clean(item.get("description", "")),
        "link": item.get("link", ""),
        "bloggername": item.get("bloggername", ""),
        "postdate": item.get("postdate"),
    }
