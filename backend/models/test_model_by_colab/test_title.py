## 테스트 csv 데이터, safetensors 모델 및 openvino 모델이 모두 있어야 작동하는 코드입니다.

import os, time
import torch
import numpy as np
import pandas as pd
from collections import Counter
from transformers import AutoTokenizer, BertForSequenceClassification
from optimum.intel.openvino import OVModelForSequenceClassification
from sklearn.metrics import accuracy_score, f1_score, recall_score, precision_score, classification_report

# ── 경로 설정 ──────────────────────────────────────
HF_PATH  = "../transfomer"
OV_PATH  = "../ber2naver_title"
CSV_PATH = "data.csv"

# ── 1. 데이터 준비 ──────────────────────────────────
df = pd.read_csv(CSV_PATH)
df = df[df["is_ad"].notna()].copy()
df["text"] = df["review_title"].fillna("") + " [SEP] " + df["review_description"].fillna("")

# P99 신뢰도를 위해 광고/정상 각 500개씩 (총 1000개)
ad_count  = min(500, (df["is_ad"] == 1).sum())
neg_count = min(500, (df["is_ad"] == 0).sum())

df_ad   = df[df["is_ad"] == 1].sample(ad_count,  random_state=42)
df_neg  = df[df["is_ad"] == 0].sample(neg_count, random_state=42)
df_eval = pd.concat([df_ad, df_neg]).sample(frac=1, random_state=42).reset_index(drop=True)

texts  = df_eval["text"].tolist()
labels = df_eval["is_ad"].astype(int).tolist()

print("레이블 분포:", Counter(labels))
print(f"총 샘플 수: {len(texts)}개")
if len(texts) < 1000:
    print(f"⚠️  샘플이 {len(texts)}개로 1000개 미만입니다. P99는 참고용으로만 사용하세요.")

# ── 2. 모델 로드 ────────────────────────────────────
tokenizer = AutoTokenizer.from_pretrained(HF_PATH, local_files_only=True)

hf_model = BertForSequenceClassification.from_pretrained(HF_PATH, local_files_only=True)
hf_model.eval()

ov_model = OVModelForSequenceClassification.from_pretrained(
    OV_PATH, device="CPU", local_files_only=True
)
print("모델 로드 완료!\n")

# ── 3. 평가 함수 ────────────────────────────────────
def evaluate(model, tokenizer, texts, labels, model_name):
    preds, latencies = [], []

    # 워밍업 (결과에 미포함)
    for text in texts[:10]:
        inp = tokenizer(text, return_tensors="pt",
                        truncation=True, max_length=128, padding="max_length")
        with torch.no_grad():
            model(**inp)

    # 본 측정
    for text in texts:
        inp = tokenizer(text, return_tensors="pt",
                        truncation=True, max_length=128, padding="max_length")
        t0 = time.perf_counter()
        with torch.no_grad():
            out = model(**inp)
        latencies.append((time.perf_counter() - t0) * 1000)

        logits = out.logits if hasattr(out, "logits") else out["logits"]
        preds.append(int(torch.argmax(logits, dim=1)))

    # 성능 지표
    acc       = accuracy_score(labels, preds)
    f1        = f1_score(labels, preds, average="binary", pos_label=1)
    recall    = recall_score(labels, preds, average="binary", pos_label=1)
    precision = precision_score(labels, preds, average="binary", pos_label=1)

    # Latency 지표
    lat_mean = float(np.mean(latencies))
    lat_p50  = float(np.percentile(latencies, 50))
    lat_p95  = float(np.percentile(latencies, 95))
    lat_p99  = float(np.percentile(latencies, 99))
    lat_min  = float(np.min(latencies))
    lat_max  = float(np.max(latencies))
    rps      = 1000 / lat_mean
    lat_std = float(np.std(latencies))

    print(f"=== {model_name} ===")
    print("예측 분포:", Counter(preds))
    print(classification_report(labels, preds,
          target_names=["정상(0)", "광고(1)"], digits=4))

    return {
        "acc": acc, "f1": f1, "recall": recall, "precision": precision,
        "lat_mean": lat_mean, "lat_std": lat_std, "lat_p50": lat_p50,
        "lat_p95": lat_p95, "lat_p99": lat_p99,
        "lat_min": lat_min, "lat_max": lat_max,
        "rps": rps
    }

# ── 4. 평가 실행 ────────────────────────────────────
hf = evaluate(hf_model, tokenizer, texts, labels, "HF Safetensors")
ov = evaluate(ov_model, tokenizer, texts, labels, "OpenVINO INT8")

# ── 5. 실제 파일 크기 ───────────────────────────────
hf_mb = os.path.getsize(f"{HF_PATH}/model.safetensors") / 1024**2
ov_mb = os.path.getsize(f"{OV_PATH}/openvino_model.bin") / 1024**2

# ── 6. 최종 비교표 ──────────────────────────────────
print("="*58)
print(f"{'Metric':<25} {'HF':>14} {'OpenVINO':>14}")
print("="*58)

# 성능 지표
print(f"{'[성능]':<25}")
print(f"{'Accuracy':<25} {hf['acc']:>14.4f} {ov['acc']:>14.4f}")
print(f"{'F1-Score':<25} {hf['f1']:>14.4f} {ov['f1']:>14.4f}")
print(f"{'Recall':<25} {hf['recall']:>14.4f} {ov['recall']:>14.4f}")
print(f"{'Precision':<25} {hf['precision']:>14.4f} {ov['precision']:>14.4f}")

# Latency 지표
print(f"\n{'[Latency]':<25}")
print(f"{'Mean':<25} {hf['lat_mean']:>13.2f}ms {ov['lat_mean']:>13.2f}ms")
print(f"{'Std':<25} {hf['lat_std']:>13.2f}ms {ov['lat_std']:>13.2f}ms")
print(f"{'P50':<25} {hf['lat_p50']:>13.2f}ms {ov['lat_p50']:>13.2f}ms")
print(f"{'P95':<25} {hf['lat_p95']:>13.2f}ms {ov['lat_p95']:>13.2f}ms")
print(f"{'P99':<25} {hf['lat_p99']:>13.2f}ms {ov['lat_p99']:>13.2f}ms")
print(f"{'Min':<25} {hf['lat_min']:>13.2f}ms {ov['lat_min']:>13.2f}ms")
print(f"{'Max':<25} {hf['lat_max']:>13.2f}ms {ov['lat_max']:>13.2f}ms")

# 처리량 및 모델 크기
print(f"\n{'[처리량 / 크기]':<25}")
print(f"{'RPS':<25} {hf['rps']:>13.2f}  {ov['rps']:>13.2f}")
print(f"{'Model Size (MB)':<25} {hf_mb:>13.2f}MB {ov_mb:>13.2f}MB")

print("="*58)
print(f"\n[요약]")
print(f"속도 향상 (Mean):  {hf['lat_mean']/ov['lat_mean']:.2f}배")
print(f"속도 향상 (P99):   {hf['lat_p99']/ov['lat_p99']:.2f}배")
print(f"정확도 변화:        {ov['acc']  - hf['acc']:+.4f}")
print(f"F1 변화:           {ov['f1']   - hf['f1']:+.4f}")
print(f"Recall 변화:       {ov['recall']- hf['recall']:+.4f}")
print(f"용량 절감:          {(1 - ov_mb/hf_mb)*100:.1f}%")

# P99 신뢰도 경고
if len(texts) < 1000:
    print(f"\n⚠️  P99 신뢰도 주의: 샘플 {len(texts)}개 (권장 1,000개 이상)")
    print(f"   P95까지만 신뢰도 있는 지표로 사용하세요.")