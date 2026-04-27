# 광고 판별 모델 전환 가이드

LLM(GPT) ↔ ELECTRA 전환 시 수정할 파일과 위치를 정리한 문서입니다.

---

## 전환 시 수정 파일 목록

| 파일 | 위치 |
|------|------|
| `search.py` | `backend/routers/search.py` |
| `blog_review.dart` | `frontend/lib/.../blog_review.dart` |

---

## 1. `backend/routers/search.py`

### ELECTRA 단독 (현재 상태)
LLM 블록이 주석 처리되어 있고 ELECTRA 블록이 활성화된 상태입니다.

```python
# Step 5: 광고 판별 후 업데이트
for review in saved:
    description = review.get("review_description") or ""

    # ── LLM 판별 (테스트 시 아래 두 줄 주석 해제) ──────────────────
    # is_ad_llm = await classify_ad(review)
    # await update_llm_pred(review["id"], is_ad_llm)
    # review["is_ad_llm_pred"] = is_ad_llm

    # ── ELECTRA 판별 (테스트 시 아래 세 줄 주석 해제) ───────────────
    is_ad_electra = predict_is_ad(description)
    await update_electra_pred(review["id"], is_ad_electra)
    review["is_ad_electra_pred"] = is_ad_electra
```

### LLM 단독으로 전환할 때
LLM 블록 주석 해제, ELECTRA 블록 주석 처리

```python
    # ── LLM 판별 ────────────────────────────────────────────────────
    is_ad_llm = await classify_ad(review)
    await update_llm_pred(review["id"], is_ad_llm)
    review["is_ad_llm_pred"] = is_ad_llm

    # ── ELECTRA 판별 ─────────────────────────────────────────────────
    # is_ad_electra = predict_is_ad(description)
    # await update_electra_pred(review["id"], is_ad_electra)
    # review["is_ad_electra_pred"] = is_ad_electra
```

### 둘 다 병행할 때
두 블록 모두 주석 해제

```python
    is_ad_llm = await classify_ad(review)
    await update_llm_pred(review["id"], is_ad_llm)
    review["is_ad_llm_pred"] = is_ad_llm

    is_ad_electra = predict_is_ad(description)
    await update_electra_pred(review["id"], is_ad_electra)
    review["is_ad_electra_pred"] = is_ad_electra
```

---

## 2. `frontend/lib/.../blog_review.dart`

`fromApi()` 안에 두 블록이 있습니다.

### ELECTRA 단독 (현재 상태)
LLM 앙상블 블록이 주석 처리되어 있고 ELECTRA 단독 블록이 활성화된 상태입니다.

```dart
final electraPred = json['is_ad_electra_pred'] as int? ?? -1;

// ── LLM 앙상블 사용 시 위 줄 아래에 주석 해제 ───────────────────────
// final llmPred = json['is_ad_llm_pred'] as int? ?? -1;
// if (llmPred != -1 && electraPred != -1) { ... }
// ...

// ── ELECTRA 단독 판별 ────────────────────────────────────────────────
final int adProb = switch (electraPred) { ... };
final ReviewStatus status = switch (electraPred) { ... };
```

### LLM 단독으로 전환할 때
`fromApi()` 상단의 읽는 필드명만 변경

```dart
// 변경 전
final electraPred = json['is_ad_electra_pred'] as int? ?? -1;

// 변경 후
final llmPred = json['is_ad_llm_pred'] as int? ?? -1;
```

이후 `switch` 두 곳과 `isSponsored` 한 곳의 변수명을 `electraPred` → `llmPred` 로 교체

### LLM 앙상블 병행할 때
`fromApi()` 안의 LLM 앙상블 주석 블록 전체 해제 후,
ELECTRA 단독 `switch` 블록 두 개를 주석 처리

---

## 전환 체크리스트

### ELECTRA → LLM 단독
- [ ] `search.py` : LLM 블록 주석 해제, ELECTRA 블록 주석 처리
- [ ] `blog_review.dart` : `electraPred` → `llmPred`, 필드명 `is_ad_llm_pred` 로 변경

### LLM → ELECTRA 단독 (현재 상태로 복귀)
- [ ] `search.py` : ELECTRA 블록 주석 해제, LLM 블록 주석 처리
- [ ] `blog_review.dart` : `llmPred` → `electraPred`, 필드명 `is_ad_electra_pred` 로 변경

### 병행 테스트
- [ ] `search.py` : 두 블록 모두 주석 해제
- [ ] `blog_review.dart` : LLM 앙상블 주석 블록 해제, ELECTRA 단독 블록 주석 처리
- [ ] Supabase에서 `is_ad_llm_pred` / `is_ad_electra_pred` 두 컬럼 모두 확인

---

## 참고: Supabase 컬럼 정리

| 컬럼 | 설명 |
|------|------|
| `is_ad` | 실제 정답 라벨 (수동 입력) |
| `is_ad_llm_pred` | LLM(GPT) 판별 결과 |
| `is_ad_electra_pred` | ELECTRA 판별 결과 |
| `is_ad_bert_pred` | BERT 판별 결과 (미사용) |