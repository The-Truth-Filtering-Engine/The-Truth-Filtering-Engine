"""
APIReviewList → APIReviewList_Classified
- 원본 컬럼 전체 복사
- GPT-4o로 광고 확률(is_ad_llm_prob) 계산
- is_ad_llm_pred (0/1 이진값) 추가
- 장소(name)별 진성 리뷰 요약(review_summary) 추가
- RateLimitError 자동 재시도 (지수 백오프)

필요한 환경변수:
  OPENAI_API_KEY
  SUPABASE_URL
  SUPABASE_SERVICE_KEY  ← Settings > API > service_role key
"""

import asyncio
import os
import json
from openai import AsyncOpenAI, RateLimitError
from supabase import create_client, Client

# ── 클라이언트 초기화 ──────────────────────────────────────────────
openai_client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_KEY"),
)

# ── 설정 ───────────────────────────────────────────────────────────
SOURCE_TABLE = "APIReviewList"
TARGET_TABLE = "APIReviewList_Classified"
AD_THRESHOLD = 0.5  # 이 값 이상이면 광고(1), 미만이면 진성(0)
CONCURRENCY  = 3    # TPM 30,000 기준 안전값 (여유 있으면 5까지 올려도 됨)
BATCH_SIZE   = 100  # Supabase upsert 배치 크기
MAX_RETRIES  = 6    # RateLimitError 최대 재시도 횟수
RETRY_BASE   = 2.0  # 지수 백오프 기본값(초): 1→2→4→8→16→32초


# ── Rate Limit 자동 재시도 래퍼 ────────────────────────────────────
async def call_with_retry(coro_fn, *args, **kwargs):
    """RateLimitError 발생 시 지수 백오프로 자동 재시도"""
    for attempt in range(MAX_RETRIES):
        try:
            return await coro_fn(*args, **kwargs)
        except RateLimitError:
            if attempt == MAX_RETRIES - 1:
                raise
            wait = RETRY_BASE ** attempt
            print(f"  ⚠️  RateLimit 도달, {wait:.0f}초 후 재시도 ({attempt + 1}/{MAX_RETRIES})...")
            await asyncio.sleep(wait)


# ── 1. 광고 확률 판별 ──────────────────────────────────────────────
async def classify_ad(review: dict) -> float:
    text = (
        f"제목: {review.get('review_title') or ''}\n"
        f"내용: {review.get('review_description') or ''}\n"
        f"블로거: {review.get('review_bloggername') or ''}"
    )

    response = await call_with_retry(
        openai_client.chat.completions.create,
        model="gpt-4o",
        max_tokens=100,
        temperature=0,
        messages=[
            {
                "role": "system",
                "content": """당신은 네이버 블로그 광고 판별 전문가입니다.
절대로 URL에 접속하지 말고, 입력된 텍스트만으로 판단하세요.

[1] 기본 점수: 0.3 (중립)

[2] 아래 신호가 있으면 점수를 조정하세요
(광고 신호 - 점수 증가)
- 협찬/제공/무료체험/PPL 명시: +0.7
- 일방적 칭찬만 있고 단점 없음: +0.2
- 가격·링크·예약 유도 CTA: +0.15
- 정보 나열형 (주소·영업시간·메뉴 나열): +0.1
- 해시태그 10개 이상: +0.1

(진성 리뷰 신호 - 점수 감소)
- 단점·불만 명시적 언급: -0.4
- 부정적 감정 포함 (아쉬웠다/불편/별로): -0.2
- 구체적 개인 경험 묘사: -0.1
- 자연스러운 구어체 문체: -0.1

[3] 최종 점수 = 기본점수 + 합산, 범위 0.0~1.0으로 제한

[4] JSON만 출력 (설명 금지):
{"is_ad_prob": 숫자}""",
            },
            {"role": "user", "content": text},
        ],
    )

    try:
        result = json.loads(response.choices[0].message.content)
        return float(result["is_ad_prob"])
    except (json.JSONDecodeError, KeyError, ValueError):
        return 0.5  # 판별 실패 시 중립값


# ── 2. 진성 리뷰 요약 (장소 단위) ─────────────────────────────────
async def summarize_reviews(reviews: list[dict]) -> str:
    real_reviews = [
        f"제목: {r.get('review_title') or ''}\n내용: {r.get('review_description') or ''}"
        for r in reviews
        if r.get("is_ad_llm_pred") == 0
    ]

    if not real_reviews:
        return "진짜 리뷰가 없습니다."

    combined = "\n\n".join(real_reviews[:20])  # 최대 20개만 사용
    response = await call_with_retry(
        openai_client.chat.completions.create,
        model="gpt-4o-mini",
        max_tokens=300,
        messages=[
            {"role": "system", "content": "광고가 아닌 진짜 리뷰들을 3줄로 요약해주세요."},
            {"role": "user", "content": combined},
        ],
    )
    return response.choices[0].message.content


# ── 3. Supabase 전체 데이터 로드 ───────────────────────────────────
def fetch_all_reviews() -> list[dict]:
    all_rows = []
    page_size = 1000
    offset = 0

    while True:
        res = (
            supabase.table(SOURCE_TABLE)
            .select("*")
            .gte("id", 1)       # id >= 1
            .lte("id", 1000)    # id <= 1000
            .range(offset, offset + page_size - 1)
            .execute()
        )
        rows = res.data
        if not rows:
            break
        all_rows.extend(rows)
        print(f"  로드 중... {len(all_rows)}건")
        if len(rows) < page_size:
            break
        offset += page_size

    return all_rows


# ── 4. Supabase upsert ─────────────────────────────────────────────
def upsert_rows(rows: list[dict]):
    for i in range(0, len(rows), BATCH_SIZE):
        chunk = rows[i : i + BATCH_SIZE]
        supabase.table(TARGET_TABLE).upsert(chunk).execute()
        print(f"  저장 완료: {i + len(chunk)}/{len(rows)}")


# ── 5. 메인 파이프라인 ─────────────────────────────────────────────
async def main():
    # 5-1. 원본 데이터 로드
    print(f"[1] {SOURCE_TABLE} 데이터 로드 중...")
    reviews = fetch_all_reviews()
    print(f"    총 {len(reviews)}건 로드 완료\n")

    # 5-2. 광고 확률 병렬 계산
    print(f"[2] 광고 판별 중 (동시 처리: {CONCURRENCY}개)...")
    semaphore = asyncio.Semaphore(CONCURRENCY)
    done_count = 0

    async def classify_with_semaphore(review: dict) -> dict:
        nonlocal done_count
        async with semaphore:
            prob = await classify_ad(review)
            done_count += 1
            if done_count % 10 == 0 or done_count == len(reviews):
                print(f"  진행: {done_count}/{len(reviews)}건 완료")
            return {
                # ── 원본 컬럼 전체 복사 ──
                "id":                  review.get("id"),
                "name":                review.get("name"),
                "review_url":          review.get("review_url"),
                "review_title":        review.get("review_title"),
                "review_description":  review.get("review_description"),
                "review_bloggername":  review.get("review_bloggername"),
                "review_postdate":     review.get("review_postdate"),
                "created_at":          review.get("created_at"),
                "is_ad":               review.get("is_ad"),
                "is_ad_bert_pred":     review.get("is_ad_bert_pred"),
                "is_ad_electra_pred":  review.get("is_ad_electra_pred"),
                # ── 기존 GPT 결과 보존 (컬럼명 정리) ──
                "is_ad_llm_prob_prev": review.get("is_ad_llm_pred(GPT5.4)"),
                # ── 새 GPT-4o 판별 결과 ──
                "is_ad_llm_prob":      prob,
                "is_ad_llm_pred":      1 if prob >= AD_THRESHOLD else 0,
            }

    classified = await asyncio.gather(
        *[classify_with_semaphore(r) for r in reviews]
    )
    print(f"    판별 완료\n")

    # 5-3. 장소(name)별 진성 리뷰 요약
    print("[3] 장소별 진성 리뷰 요약 중...")
    groups: dict[str, list[dict]] = {}
    for r in classified:
        key = r.get("name") or "unknown"
        groups.setdefault(key, []).append(r)

    summaries: dict[str, str] = {}
    for place_name, group_reviews in groups.items():
        summaries[place_name] = await summarize_reviews(group_reviews)
        real_cnt = sum(1 for r in group_reviews if r["is_ad_llm_pred"] == 0)
        print(f"  [{place_name}] 전체 {len(group_reviews)}건 / 진성 {real_cnt}건 요약 완료")

    for r in classified:
        r["review_summary"] = summaries.get(r.get("name") or "unknown", "")

    print()

    # 5-4. 결과 저장
    print(f"[4] {TARGET_TABLE}에 저장 중...")
    upsert_rows(list(classified))

    # 5-5. 통계 출력
    ad_count   = sum(1 for r in classified if r["is_ad_llm_pred"] == 1)
    real_count = len(classified) - ad_count
    print(f"\n✅ 완료!")
    print(f"\n📊 결과 통계")
    print(f"   전체: {len(classified)}건")
    print(f"   광고: {ad_count}건 ({ad_count / len(classified) * 100:.1f}%)")
    print(f"   진성: {real_count}건 ({real_count / len(classified) * 100:.1f}%)")


if __name__ == "__main__":
    asyncio.run(main())