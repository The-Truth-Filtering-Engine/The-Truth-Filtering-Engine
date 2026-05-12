import itertools
import pandas as pd
import numpy as np
import torch
from torch.utils.data import Dataset, DataLoader
from torch.optim import AdamW
from transformers import BertForSequenceClassification, AutoTokenizer
from transformers import get_linear_schedule_with_warmup, get_cosine_schedule_with_warmup
from sklearn.model_selection import train_test_split
from sklearn.metrics import (roc_auc_score, accuracy_score,
                             precision_score, recall_score,
                             f1_score, classification_report)

# 1. 토크나이저
tokenizer = AutoTokenizer.from_pretrained("beomi/kcbert-base")

# 2. 데이터 로드
df = pd.read_csv("data.csv")
df = df[df["is_ad"].notna()].copy()
df["text"]  = df["review_title"].fillna("") + " [SEP] " + df["review_description"].fillna("")
df["label"] = df["is_ad"].astype(int)

train_df, val_df = train_test_split(
    df, test_size=0.2, random_state=42, stratify=df["label"]
)
print(f"학습: {len(train_df)}개, 검증: {len(val_df)}개")

# 3. Dataset
class AdDataset(Dataset):
    def __init__(self, df, tokenizer, max_len=128):
        self.texts     = df["text"].tolist()
        self.labels    = df["label"].tolist()
        self.tokenizer = tokenizer
        self.max_len   = max_len

    def __len__(self):
        return len(self.texts)

    def __getitem__(self, idx):
        encoded = self.tokenizer(
            self.texts[idx],
            max_length=self.max_len,
            padding="max_length",
            truncation=True,
            return_tensors="pt"
        )
        return {
            "input_ids":      encoded["input_ids"].squeeze(),
            "attention_mask": encoded["attention_mask"].squeeze(),
            "token_type_ids": encoded["token_type_ids"].squeeze(),
            "label":          torch.tensor(self.labels[idx], dtype=torch.long),
        }

train_dataset = AdDataset(train_df, tokenizer)
val_dataset   = AdDataset(val_df,   tokenizer)

# 4. 하이퍼파라미터 조합
param_grid = {
    "batch_size": [16, 32],
    "lr":         [1e-5, 3e-5, 5e-5],
    "scheduler":  ["cosine", "cosine_warmup", "linear"],
    "dropout":    [0.1, 0.2, 0.3],
}

keys, values = zip(*param_grid.items())
all_configs  = [dict(zip(keys, v)) for v in itertools.product(*values)]
print(f"총 실험 수: {len(all_configs)}가지")

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"사용 디바이스: {device}")

results = []

for i, cfg in enumerate(all_configs):
    print(f"\n{'='*75}")
    print(f"[{i+1}/54] 실험 시작")
    print(f"  Batch={cfg['batch_size']} | LR={cfg['lr']} | Scheduler={cfg['scheduler']} | Dropout={cfg['dropout']}")
    print(f"{'='*75}")

    # 모델 초기화
    model = BertForSequenceClassification.from_pretrained(
        "beomi/kcbert-base",
        num_labels=2,
        hidden_dropout_prob=cfg["dropout"],
        attention_probs_dropout_prob=cfg["dropout"],
    ).to(device)

    train_loader = DataLoader(train_dataset, batch_size=cfg["batch_size"], shuffle=True)
    val_loader   = DataLoader(val_dataset,   batch_size=cfg["batch_size"], shuffle=False)
    optimizer    = AdamW(model.parameters(), lr=cfg["lr"], weight_decay=0.01)
    total_steps  = len(train_loader) * 5

    if cfg["scheduler"] == "linear":
        scheduler = get_linear_schedule_with_warmup(
            optimizer, num_warmup_steps=total_steps//10, num_training_steps=total_steps)
    elif cfg["scheduler"] == "cosine":
        scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
            optimizer, T_max=total_steps)
    elif cfg["scheduler"] == "cosine_warmup":
        scheduler = get_cosine_schedule_with_warmup(
            optimizer, num_warmup_steps=total_steps//10, num_training_steps=total_steps)

    class_weights = torch.tensor([1.0, 768/513]).to(device)
    criterion     = torch.nn.CrossEntropyLoss(weight=class_weights)

    # ✅ for 루프 안에 있어야 함
    best_auc       = 0
    best_acc       = 0
    best_precision = 0
    best_recall    = 0
    best_f1        = 0
    best_saved     = False

    print(f"{'Epoch':>6} | {'Loss':>7} | {'AUC':>7} | {'ACC':>7} | {'Prec':>7} | {'Recall':>7} | {'F1':>7} | {'비고':>12}")
    print(f"{'-'*85}")

    for epoch in range(5):
        # Train
        model.train()
        total_loss = 0
        for batch in train_loader:
            optimizer.zero_grad()
            outputs = model(
                input_ids=batch["input_ids"].to(device),
                attention_mask=batch["attention_mask"].to(device),
                token_type_ids=batch["token_type_ids"].to(device),
            )
            loss = criterion(outputs.logits, batch["label"].to(device))
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            scheduler.step()
            total_loss += loss.item()

        avg_loss = total_loss / len(train_loader)

        # Validation
        model.eval()
        all_probs, all_preds, all_labels = [], [], []
        with torch.no_grad():
            for batch in val_loader:
                outputs = model(
                    input_ids=batch["input_ids"].to(device),
                    attention_mask=batch["attention_mask"].to(device),
                    token_type_ids=batch["token_type_ids"].to(device),
                )
                probs = torch.softmax(outputs.logits, dim=1)[:, 1]
                preds = outputs.logits.argmax(dim=1)
                all_probs.extend(probs.cpu().numpy())
                all_preds.extend(preds.cpu().numpy())
                all_labels.extend(batch["label"].numpy())

        auc       = roc_auc_score(all_labels, all_probs)
        acc       = accuracy_score(all_labels, all_preds)
        precision = precision_score(all_labels, all_preds, zero_division=0)
        recall    = recall_score(all_labels, all_preds, zero_division=0)
        f1        = f1_score(all_labels, all_preds, zero_division=0)

        if auc > best_auc:
            best_auc = auc

        # 저장 조건: F1 >= 0.8 이면서 Recall이 가장 높을 때
        is_best = ""
        if f1 >= 0.8 and recall > best_recall:
            best_recall    = recall
            best_acc       = acc
            best_precision = precision
            best_f1        = f1
            best_saved     = True
            is_best        = "★ 저장 (F1≥0.8)"
            torch.save(model.state_dict(), f"best_model_{i+1}.pt")
        elif f1 >= 0.8:
            is_best = "(F1≥0.8)"

        print(f"{epoch+1:>6} | {avg_loss:>7.4f} | {auc:>7.4f} | {acc:>7.4f} | {precision:>7.4f} | {recall:>7.4f} | {f1:>7.4f} | {is_best:>12}")

        if epoch == 4:
            if not best_saved:
                print(f"  ※ 조건 미충족 (F1 >= 0.8 달성 없음) - 모델 저장 안됨")
            print(f"\n  [상세 분류 리포트 - 실험 {i+1}]")
            print(classification_report(all_labels, all_preds,
                                        target_names=["비광고", "광고"],
                                        digits=4))

    print(f"{'-'*85}")
    if best_saved:
        print(f"{'최종':>6} | {'':>7} | {best_auc:>7.4f} | {best_acc:>7.4f} | {best_precision:>7.4f} | {best_recall:>7.4f} | {best_f1:>7.4f} | {'저장완료':>12}")
    else:
        print(f"{'최종':>6} | {'':>7} | {best_auc:>7.4f} | {'조건미충족 - 저장없음':>50}")

    results.append({
        "실험번호":    i+1,
        "batch_size": cfg["batch_size"],
        "lr":         cfg["lr"],
        "scheduler":  cfg["scheduler"],
        "dropout":    cfg["dropout"],
        "best_auc":   round(best_auc, 4),
        "best_acc":   round(best_acc, 4),
        "precision":  round(best_precision, 4),
        "recall":     round(best_recall, 4),
        "f1":         round(best_f1, 4),
        "saved":      best_saved,
    })

    del model
    torch.cuda.empty_cache()

# 전체 결과 저장 및 출력
results_df = pd.DataFrame(results).sort_values("best_auc", ascending=False)
results_df.to_csv("hyperparameter_results.csv", index=False)

print(f"\n{'='*75}")
print("=== 전체 실험 결과 (AUC 상위 10개) ===")
print(f"{'='*75}")
print(results_df.head(10).to_string(index=False))

print(f"\n{'='*75}")
print("=== 최적 조합 ===")
print(f"{'='*75}")
best = results_df.iloc[0]
print(f"  실험번호:   {int(best['실험번호'])}")
print(f"  Batch Size: {int(best['batch_size'])}")
print(f"  LR:         {best['lr']}")
print(f"  Scheduler:  {best['scheduler']}")
print(f"  Dropout:    {best['dropout']}")
print(f"  Best AUC:   {best['best_auc']:.4f}")
print(f"  Best ACC:   {best['best_acc']:.4f}")
print(f"  Precision:  {best['precision']:.4f}")
print(f"  Recall:     {best['recall']:.4f}")
print(f"  F1:         {best['f1']:.4f}")