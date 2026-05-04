"""
APIReviewList_Classified 성능 평가 + 레이턴시 추정
- 성능 지표 : Accuracy / Precision / Recall / F1 (LLM, BERT, ELECTRA)
- 레이턴시  : Supabase에서 무작위 20건만 GPT-4o 재호출 → 평균 추정

필요한 환경변수:
  OPENAI_API_KEY
  SUPABASE_URL
  SUPABASE_SERVICE_KEY
"""

import asyncio
import os
import json
import time
import random
import statistics
from openai import AsyncOpenAI, RateLimitError
from supabase import create_client, Client

# ── 클라이언트 초기화 ──────────────────────────────────────────────
openai_client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_KEY"),
)

TARGET_TABLE    = "APIReviewList_Classified"
AD_THRESHOLD    = 0.5   # BERT / ELECTRA 확률값 이진화 기준
LATENCY_SAMPLE  = 20    # 레이턴시 측정용 샘플 수
MAX_RETRIES     = 6
RETRY_BASE      = 2.0


# ── Rate Limit 자동 재시도 래퍼 ────────────────────────────────────
async def call_with_retry(coro_fn, *args, **kwargs):
    for attempt in range(MAX_RETRIES):
        try:
            return await coro_fn(*args, **kwargs)
        except RateLimitError:
            if attempt == MAX_RETRIES - 1:
                raise
            wait = RETRY_BASE ** attempt
            print(f"  ⚠️  RateLimit, {wait:.0f}초 후 재시도 ({attempt+1}/{MAX_RETRIES})...")
            await asyncio.sleep(wait)


# ── 1. 데이터 로드 ─────────────────────────────────────────────────
def fetch_rows() -> list[dict]:
    all_rows = []
    page_size = 1000
    offset = 0
    while True:
        res = (
            supabase.table(TARGET_TABLE)
            .select("id, is_ad, is_ad_llm_pred, is_ad_bert_pred, is_ad_electra_pred, review_title, review_description, review_bloggername")
            .range(offset, offset + page_size - 1)
            .execute()
        )
        rows = res.data
        if not rows:
            break
        all_rows.extend(rows)
        if len(rows) < page_size:
            break
        offset += page_size
    return all_rows


# ── 2. 성능 지표 계산 ──────────────────────────────────────────────
def compute_metrics(y_true: list[int], y_pred: list[int]) -> dict:
    tp = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 1)
    tn = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 0)
    fp = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 1)
    fn = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 0)

    accuracy  = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) > 0 else 0
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall    = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1        = (2 * precision * recall) / (precision + recall) if (precision + recall) > 0 else 0

    return {"tp": tp, "tn": tn, "fp": fp, "fn": fn,
            "accuracy": accuracy, "precision": precision,
            "recall": recall, "f1": f1}


def print_metrics(model_name: str, m: dict):
    print(f"\n{'─' * 48}")
    print(f"  {model_name}")
    print(f"{'─' * 48}")
    print(f"  Accuracy  : {m['accuracy']:.4f}  ({m['accuracy']*100:.2f}%)")
    print(f"  Precision : {m['precision']:.4f}")
    print(f"  Recall    : {m['recall']:.4f}")
    print(f"  F1-Score  : {m['f1']:.4f}")
    print(f"\n  혼동행렬")
    print(f"  {'':10s}  예측:광고  예측:진성")
    print(f"  실제:광고     {m['tp']:>5}     {m['fn']:>5}")
    print(f"  실제:진성     {m['fp']:>5}     {m['tn']:>5}")


# ── 3. 레이턴시 측정 (샘플 N건만 GPT 재호출) ──────────────────────
async def measure_latency(samples: list[dict]) -> list[float]:
    print(f"\n[3] GPT-4o 레이턴시 측정 중 ({len(samples)}건 샘플 호출)...")
    latencies = []

    for i, review in enumerate(samples, 1):
        text = (
            f"제목: {review.get('review_title') or ''}\n"
            f"내용: {review.get('review_description') or ''}\n"
            f"블로거: {review.get('review_bloggername') or ''}"
        )
        start = time.perf_counter()
        await call_with_retry(
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
        ms = (time.perf_counter() - start) * 1000
        latencies.append(ms)
        print(f"  샘플 {i:>2}/{len(samples)} → {ms:.0f}ms")

    return latencies


# ── 4. 메인 ───────────────────────────────────────────────────────
async def main():
    # 4-1. 데이터 로드
    print(f"[1] {TARGET_TABLE} 데이터 로드 중...")
    rows = fetch_rows()
    print(f"    총 {len(rows)}건 로드 완료")

    # is_ad NULL 행 제외
    valid = [r for r in rows if r.get("is_ad") is not None]
    skipped = len(rows) - len(valid)
    if skipped:
        print(f"    ⚠️  is_ad 값 없는 행 {skipped}건 제외 → 유효 {len(valid)}건")

    y_true = [int(r["is_ad"]) for r in valid]

    # 4-2. 성능 지표
    print(f"\n[2] 성능 지표 계산 중...")
    print(f"    레이블 분포: 광고={y_true.count(1)}건 / 진성={y_true.count(0)}건")

    models = {
        "GPT-4o  (is_ad_llm_pred)":    [int(r["is_ad_llm_pred"] or 0)                                       for r in valid],
        "BERT    (is_ad_bert_pred)":    [1 if (r.get("is_ad_bert_pred")    or 0) >= AD_THRESHOLD else 0      for r in valid],
        "ELECTRA (is_ad_electra_pred)": [1 if (r.get("is_ad_electra_pred") or 0) >= AD_THRESHOLD else 0     for r in valid],
    }

    results = {}
    for name, y_pred in models.items():
        metrics = compute_metrics(y_true, y_pred)
        results[name] = metrics
        print_metrics(name, metrics)

    # 모델 비교 요약표
    print(f"\n\n{'═' * 65}")
    print(f"  📊 모델 성능 비교 요약")
    print(f"{'═' * 65}")
    print(f"  {'모델':<38} {'Acc':>7} {'Prec':>7} {'Rec':>7} {'F1':>7}")
    print(f"  {'─'*38} {'─'*7} {'─'*7} {'─'*7} {'─'*7}")
    for name, m in results.items():
        print(f"  {name:<38} {m['accuracy']:>7.4f} {m['precision']:>7.4f} {m['recall']:>7.4f} {m['f1']:>7.4f}")
    print(f"{'═' * 65}")
    best = max(results, key=lambda k: results[k]["f1"])
    print(f"\n  🏆 F1 기준 최고 모델: {best.split('(')[0].strip()}")

    # 4-3. 레이턴시 측정 (랜덤 20건 샘플)
    sample_size = min(LATENCY_SAMPLE, len(valid))
    samples = random.sample(valid, sample_size)
    latencies = await measure_latency(samples)

    print(f"\n{'═' * 45}")
    print(f"  ⏱️  GPT-4o 레이턴시 추정 (샘플 {sample_size}건 기준)")
    print(f"{'═' * 45}")
    print(f"  평균    : {statistics.mean(latencies):>8.1f} ms")
    print(f"  중앙값  : {statistics.median(latencies):>8.1f} ms")
    print(f"  최솟값  : {min(latencies):>8.1f} ms")
    print(f"  최댓값  : {max(latencies):>8.1f} ms")
    print(f"  표준편차: {statistics.stdev(latencies):>8.1f} ms")
    print(f"\n  * 1000건 전체 예상 소요시간: {statistics.mean(latencies) * 1000 / 1000 / 60:.1f}분")
    print(f"    (단일 호출 기준, 병렬 처리 시 단축됨)")
    print(f"{'═' * 45}")


if __name__ == "__main__":
    asyncio.run(main())