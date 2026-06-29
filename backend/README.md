# Backend README

FastAPI backend for The Truth Filtering Engine.

이 백엔드는 지도에서 선택한 음식점/카페 정보를 바탕으로 블로그 리뷰를 수집하고, ELECTRA 기반 NLP 모델로 광고성 가능성을 계산한 뒤, Supabase에 저장/캐싱해 웹과 Flutter 앱에 제공합니다.

## 역할

| 영역 | 설명 |
| --- | --- |
| 장소 검색 | Kakao Local API로 주변 음식점/카페와 키워드 검색 결과를 조회합니다. |
| 리뷰 수집 | Naver Blog API로 매장 관련 블로그 리뷰 후보를 가져옵니다. |
| 리뷰 분석 | 리뷰 제목과 본문을 전처리한 뒤 ELECTRA 기반 모델로 광고 가능성 점수를 계산합니다. |
| 캐싱 | Supabase `reviews` 테이블에 리뷰와 분석 점수를 저장해 반복 분석을 줄입니다. |
| 사용자 상태 | Supabase Auth 또는 테스트 계정 헤더를 기준으로 북마크, 최근 기록, 사용량, 코인을 관리합니다. |
| 추천 | 광고 가능성이 낮은 리뷰를 기준으로 위치 기반 추천 목록을 제공합니다. |

## 폴더 구조

```text
backend/
├── main.py
├── routers/
│   ├── ai_recommend.py
│   ├── places.py
│   ├── report.py
│   ├── search.py
│   └── users.py
└── services/
    ├── electra_service.py
    ├── naver_service.py
    ├── preprocess.py
    ├── review_limits.py
    └── supabase_service.py
```

## 주요 API

| Method | Endpoint | 설명 |
| --- | --- | --- |
| GET | `/` | 서버 상태 확인용 루트 응답입니다. |
| GET | `/config` | 프론트엔드가 필요한 공개 설정 여부를 확인합니다. |
| GET | `/places/nearby-restaurants` | 지도 중심 좌표 기준 주변 음식점/카페를 조회합니다. |
| GET | `/places/search-restaurants` | 검색어 기준 음식점/카페를 조회합니다. |
| GET | `/api/search/cached` | Supabase에 저장된 분석 리뷰를 먼저 조회합니다. |
| GET | `/api/search` | 리뷰 수집, 분석, 저장을 한 번에 수행합니다. |
| GET | `/api/search/stream` | 리뷰 분석 결과를 SSE 배치로 스트리밍합니다. |
| GET | `/api/ai-recommendations` | 광고 가능성이 낮은 리뷰 기반 추천 목록을 반환합니다. |
| GET | `/api/user/me` | 사용자 프로필과 사용량 상태를 조회합니다. |
| GET/POST/DELETE | `/api/user/me/bookmarks` | 사용자 북마크를 관리합니다. |
| GET/POST/DELETE | `/api/user/me/recent-visits` | 최근 열어본 리뷰 기록을 관리합니다. |
| GET/PUT | `/api/user/me/review-reactions` | 리뷰 하트 상태를 조회/갱신합니다. |

## 환경 변수

`backend/.env.example`을 기준으로 `backend/.env`를 만듭니다. 값은 README나 커밋에 포함하지 않습니다.

```text
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_KEY=
KAKAO_REST_API_KEY=
KAKAO_JS_KEY=
NAVER_CLIENT_ID=
NAVER_CLIENT_SECRET=
NAVER_MAP_CLIENT_ID=
NAVER_MAP_CLIENT_SECRET=
```

## 로컬 실행

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

macOS/Linux에서는 가상환경 활성화 명령만 다릅니다.

```bash
source .venv/bin/activate
```

## 모델 파일

`services/electra_service.py`는 다음 위치의 모델 파일을 로드합니다.

```text
backend/models/GPU/model.safetensors
```

모델 파일이 없거나 로드에 실패하면 서버 전체를 중단하지 않고 모델 사용 불가 상태로 둡니다. 이 경우 추론 점수는 fallback 값으로 처리되므로, 실제 분석 품질 검증에는 모델 아티팩트 준비가 필요합니다.

`requirements.txt`의 `torch`는 기본 PyPI 설치 기준입니다. CUDA가 필요한 운영/실험 환경에서는 PyTorch 공식 안내에 맞는 CUDA wheel 설치 명령으로 교체하거나 선설치한 뒤 나머지 의존성을 설치합니다.

## 데이터 흐름

```text
Client
  -> FastAPI Router
  -> Kakao Local API로 장소 확인
  -> Naver Blog API로 리뷰 수집
  -> preprocess.py로 리뷰 텍스트 정리
  -> electra_service.py로 광고 가능성 점수 계산
  -> supabase_service.py로 저장/캐싱
  -> JSON 또는 SSE 응답
```

## 인증 방식

사용자 API는 다음 두 방식을 지원합니다.

- Supabase Auth access token: `Authorization: Bearer <token>`
- 테스트 계정 헤더: `X-Test-Account-Email`

테스트 계정 헤더는 개발 편의 기능이므로 운영 환경에서는 사용 범위와 접근 제어를 별도로 점검해야 합니다.

## 검증

서버 실행 후 다음을 확인합니다.

```bash
curl http://localhost:8000/
curl http://localhost:8000/config
```

Swagger UI는 로컬 실행 시 아래에서 확인할 수 있습니다.

```text
http://localhost:8000/docs
```

## 알려진 한계

- 백엔드 의존성은 `requirements.txt`에 정리되어 있지만, 완전한 lock 파일은 없습니다.
- Supabase 스키마와 마이그레이션이 레포에 완전히 정리되어 있지 않습니다.
- 모델 학습 데이터와 모델 아티팩트는 레포만으로 재현하기 어렵습니다.
- Cloudflare Quick Tunnel 환경에서는 SSE 스트리밍이 버퍼링될 수 있습니다.
