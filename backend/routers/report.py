from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional
import httpx
import os

router = APIRouter()

# ── Supabase 설정 ──────────────────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY", "")

def _headers():
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

# ── Schemas ────────────────────────────────────────────────────────────────

class ReportRequest(BaseModel):
    review_id: str
    reason: str          # "spam" | "fake" | "ad" | "inappropriate" | "other"
    detail: Optional[str] = None   # 선택적 부가 설명
    reporter_id: Optional[str] = None  # 로그인 사용자 id (없으면 익명)

class ReportResponse(BaseModel):
    id: str
    review_id: str
    reason: str
    status: str  # "pending" | "reviewed" | "dismissed"


# ══════════════════════════════════════════════════════════════════════════════
# 1. 리뷰 페이지네이션
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/reviews", summary="리뷰 목록 (페이지네이션)")
async def get_reviews(
    query: str,
    start: int = Query(0, ge=0, description="시작 오프셋"),
    limit: int = Query(10, ge=1, le=50, description="페이지당 개수"),
):
    """
    Naver 검색 결과 기반으로 Supabase에 저장된 리뷰를 페이지 단위로 반환합니다.
    - start: 0-based 오프셋 (10이면 11번째 리뷰부터)
    - limit: 최대 반환 개수 (기본 10, 최대 50)
    """
    if not SUPABASE_URL:
        # Supabase 미연결 시 목업 데이터 반환
        return _mock_reviews(query, start, limit)

    end = start + limit - 1  # Supabase Range는 inclusive
    url = f"{SUPABASE_URL}/rest/v1/reviews"
    params = {
        "query": f"eq.{query}",
        "order": "created_at.desc",
        "offset": start,
        "limit": limit,
    }
    headers = {**_headers(), "Range": f"{start}-{end}", "Range-Unit": "items"}

    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=headers, params={"query": f"eq.{query}"})

    if resp.status_code not in (200, 206):
        raise HTTPException(status_code=resp.status_code, detail="리뷰 조회 실패")

    reviews = resp.json()
    total = int(resp.headers.get("Content-Range", "*/0").split("/")[-1])

    return {
        "start": start,
        "limit": limit,
        "total": total,
        "has_next": start + limit < total,
        "reviews": reviews,
    }


def _mock_reviews(query: str, start: int, limit: int):
    """Supabase 미연결 개발용 목업"""
    total = 35
    reviews = [
        {
            "id": f"mock-{i}",
            "query": query,
            "title": f"[목업] {query} 리뷰 #{i + 1}",
            "review_description": f"이것은 {query}에 대한 테스트 리뷰입니다. (#{i + 1})",
            "is_ad_electra_pred": i % 3 == 0,
            "is_ad_finetuned_pred": round(0.1 + (i % 10) * 0.08, 2),
            "created_at": "2025-01-01T00:00:00",
        }
        for i in range(start, min(start + limit, total))
    ]
    return {
        "start": start,
        "limit": limit,
        "total": total,
        "has_next": start + limit < total,
        "reviews": reviews,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 2. 신고 시스템
# ══════════════════════════════════════════════════════════════════════════════

REPORT_REASONS = {"spam", "fake", "ad", "inappropriate", "other"}

@router.post("/reviews/{review_id}/report", summary="리뷰 신고")
async def report_review(review_id: str, req: ReportRequest):
    if req.reason not in REPORT_REASONS:
        raise HTTPException(
            status_code=422,
            detail=f"유효하지 않은 신고 사유입니다. 허용: {REPORT_REASONS}",
        )

    payload = {
        "review_id": review_id,
        "reason": req.reason,
        "detail": req.detail,
        "reporter_id": req.reporter_id,
        "status": "pending",
    }

    if not SUPABASE_URL:
        # 개발용: 저장 없이 성공 응답
        return {"message": "신고가 접수되었습니다. (개발 모드 - 실제 저장 안 됨)", "data": payload}

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{SUPABASE_URL}/rest/v1/review_reports",
            headers=_headers(),
            json=payload,
        )

    if resp.status_code not in (200, 201):
        raise HTTPException(status_code=500, detail="신고 저장 실패")

    return {"message": "신고가 접수되었습니다.", "data": resp.json()[0] if resp.json() else payload}


# ══════════════════════════════════════════════════════════════════════════════
# 3. 신뢰도 투표 👍👎
# ══════════════════════════════════════════════════════════════════════════════

VALID_VOTES = {"trust", "doubt"}

class VoteRequest(BaseModel):
    review_id: str
    vote: str                        # "trust" | "doubt"
    user_id: Optional[str] = None

@router.post("/reviews/{review_id}/vote", summary="신뢰도 투표 (믿을만해요 / 의심돼요)")
async def vote_review(review_id: str, req: VoteRequest):
    if req.vote not in VALID_VOTES:
        raise HTTPException(status_code=422, detail=f"허용 값: {VALID_VOTES}")

    payload = {"review_id": review_id, "vote": req.vote, "user_id": req.user_id}

    if not SUPABASE_URL:
        return {"message": "투표 완료 (개발 모드)", "data": payload}

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{SUPABASE_URL}/rest/v1/review_votes",
            headers=_headers(),
            json=payload,
        )

    if resp.status_code not in (200, 201):
        raise HTTPException(status_code=500, detail="투표 저장 실패")

    return {"message": "투표가 반영되었습니다.", "data": resp.json()[0] if resp.json() else payload}


@router.get("/reviews/{review_id}/votes", summary="리뷰 투표 집계")
async def get_votes(review_id: str):
    if not SUPABASE_URL:
        # 개발용 목업
        return {"trust": 12, "doubt": 3, "trust_ratio": 0.8}

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/rest/v1/review_votes",
            headers=_headers(),
            params={"review_id": f"eq.{review_id}"},
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail="투표 조회 실패")

    votes = resp.json()
    trust = sum(1 for v in votes if v["vote"] == "trust")
    doubt = sum(1 for v in votes if v["vote"] == "doubt")
    total = trust + doubt
    return {
        "trust": trust,
        "doubt": doubt,
        "trust_ratio": round(trust / total, 2) if total > 0 else None,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 4. AI 판별 피드백 ("이 결과 틀렸어요")
# ══════════════════════════════════════════════════════════════════════════════

class AiFeedbackRequest(BaseModel):
    review_id: str
    ai_was_correct: bool             # True: AI 맞음 / False: AI 틀림
    user_label: Optional[str] = None # "ad" | "not_ad"  (틀렸을 때 실제 정답)
    user_id: Optional[str] = None

@router.post("/reviews/{review_id}/ai-feedback", summary="AI 판별 피드백")
async def ai_feedback(review_id: str, req: AiFeedbackRequest):
    payload = {
        "review_id": review_id,
        "ai_was_correct": req.ai_was_correct,
        "user_label": req.user_label,
        "user_id": req.user_id,
    }

    if not SUPABASE_URL:
        return {"message": "피드백 저장 완료 (개발 모드)", "data": payload}

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{SUPABASE_URL}/rest/v1/ai_feedbacks",
            headers=_headers(),
            json=payload,
        )

    if resp.status_code not in (200, 201):
        raise HTTPException(status_code=500, detail="피드백 저장 실패")

    return {"message": "피드백이 반영되었습니다. 모델 개선에 활용됩니다.", "data": resp.json()[0] if resp.json() else payload}


# ══════════════════════════════════════════════════════════════════════════════
# 5. 리뷰 태그 시스템
# ══════════════════════════════════════════════════════════════════════════════

VALID_TAGS = {"광고같음", "내돈내산", "과장됨", "사진없음", "재방문의향", "친절함"}

class TagRequest(BaseModel):
    review_id: str
    tag: str
    user_id: Optional[str] = None

@router.post("/reviews/{review_id}/tag", summary="리뷰 태그 추가")
async def add_tag(review_id: str, req: TagRequest):
    if req.tag not in VALID_TAGS:
        raise HTTPException(status_code=422, detail=f"허용 태그: {VALID_TAGS}")

    payload = {"review_id": review_id, "tag": req.tag, "user_id": req.user_id}

    if not SUPABASE_URL:
        return {"message": "태그 추가 완료 (개발 모드)", "data": payload}

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{SUPABASE_URL}/rest/v1/review_tags",
            headers=_headers(),
            json=payload,
        )

    if resp.status_code not in (200, 201):
        raise HTTPException(status_code=500, detail="태그 저장 실패")

    return {"message": "태그가 추가되었습니다.", "data": resp.json()[0] if resp.json() else payload}


@router.get("/reviews/{review_id}/tags", summary="리뷰 태그 집계")
async def get_tags(review_id: str):
    if not SUPABASE_URL:
        return {"tags": {"광고같음": 5, "내돈내산": 8, "과장됨": 2}}

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/rest/v1/review_tags",
            headers=_headers(),
            params={"review_id": f"eq.{review_id}"},
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail="태그 조회 실패")

    tags = resp.json()
    counts: dict = {}
    for t in tags:
        counts[t["tag"]] = counts.get(t["tag"], 0) + 1
    return {"tags": counts}


@router.get("/reviews/{review_id}/reports", summary="특정 리뷰 신고 목록 (관리자용)")
async def get_reports(review_id: str):
    if not SUPABASE_URL:
        return {"reports": [], "total": 0}

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{SUPABASE_URL}/rest/v1/review_reports",
            headers=_headers(),
            params={"review_id": f"eq.{review_id}", "order": "created_at.desc"},
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail="신고 조회 실패")

    reports = resp.json()
    return {"reports": reports, "total": len(reports)}