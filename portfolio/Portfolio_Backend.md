# Backend Portfolio - The Truth Filtering Engine

## 1. 프로젝트 개요

The Truth Filtering Engine은 지도에서 음식점과 카페를 탐색할 때 네이버 블로그 리뷰의 광고성 가능성을 분석해 사용자가 신뢰할 수 있는 리뷰를 먼저 확인하도록 돕는 서비스입니다.

백엔드는 FastAPI 기반으로 장소 검색, 리뷰 수집, 광고성 리뷰 분석, Supabase 저장/캐싱, 사용자 사용량 관리를 담당합니다. 지도 기반 클라이언트가 선택한 매장 정보를 받아 Kakao Local API와 Naver Blog API를 연결하고, ELECTRA 기반 분류 모델의 추론 결과를 서비스 응답으로 제공합니다.

| 항목 | 내용 |
| --- | --- |
| 프로젝트명 | The Truth Filtering Engine |
| 서비스 형태 | 지도 기반 광고성 리뷰 필터링 서비스 |
| 담당 영역 | FastAPI 백엔드 API 연동, Supabase 사용자 상태 동기화, 웹·앱 클라이언트 연결, endpoint/환경 설정 조정 |
| 주요 기술 | Python, FastAPI, httpx, Supabase REST/Auth, Kakao Local API, Naver Blog API, HuggingFace Transformers |
| 주요 클라이언트 | React 웹, Flutter 앱 |

> 기여 기준: 최현석(choihyunseok)의 직접 기여는 백엔드 전체 단독 구현이라기보다 웹·앱 기능을 완성하기 위한 API 연동, 사용자 상태 동기화, endpoint 조정, 일부 백엔드 오류 수정에 집중되어 있습니다.

## 2. 문제 정의

사용자가 음식점 리뷰를 확인할 때 가장 큰 문제는 실제 방문 후기와 광고성 블로그 글이 섞여 있다는 점입니다. 프론트엔드가 단순히 리뷰 목록만 보여주면 사용자는 다시 직접 광고 여부를 판단해야 하므로, 백엔드에서 다음 문제를 해결해야 했습니다.

- 지도에서 선택한 매장을 기준으로 정확한 장소 정보를 조회해야 합니다.
- 매장명, 주소, 카테고리를 조합해 관련 블로그 리뷰를 수집해야 합니다.
- 같은 리뷰를 반복 수집하거나 반복 분석하지 않도록 캐싱해야 합니다.
- 리뷰 제목과 본문을 모델 입력으로 전처리하고 광고성 점수를 계산해야 합니다.
- 로그인 사용자별 무료 분석, 프리미엄 횟수, 코인 차감 정책을 일관되게 적용해야 합니다.
- 웹과 앱이 같은 API를 사용하도록 응답 형태를 안정적으로 유지해야 합니다.

## 3. API 설계

주요 API는 장소 탐색, 리뷰 분석, 사용자 상태, AI 추천, 리뷰 피드백으로 나뉩니다.

### 장소 탐색 API

| Method | Endpoint | 역할 |
| --- | --- | --- |
| GET | `/places/nearby-restaurants` | 지도 중심 좌표 기준 주변 음식점/카페를 Kakao Local API로 조회합니다. |
| GET | `/places/search-restaurants` | 검색어와 좌표를 기준으로 음식점/카페를 검색합니다. |

`places.py`는 Kakao Local API 응답을 클라이언트가 바로 사용할 수 있도록 `id`, `name`, `latitude`, `longitude`, `addressName`, `roadAddressName`, `categoryName`, `placeUrl`, `distance` 등으로 정규화합니다.

### 리뷰 분석 API

| Method | Endpoint | 역할 |
| --- | --- | --- |
| GET | `/api/search/cached` | Supabase에 이미 저장된 분석 리뷰만 빠르게 조회합니다. |
| GET | `/api/search` | 캐시 조회, 신규 Naver Blog 수집, 모델 분석, 저장까지 수행합니다. |
| GET | `/api/search/stream` | 리뷰 분석 결과를 SSE 형태로 배치 단위 스트리밍합니다. |

리뷰 상세 화면은 먼저 `/api/search/cached`로 캐시를 확인하고, 부족하면 `/api/search/stream`으로 분석 결과를 받습니다. 이 구조를 통해 이미 분석된 매장은 빠르게 열고, 신규 매장은 분석 진행 상황을 화면에 점진적으로 표시할 수 있습니다.

### 사용자 API

| Method | Endpoint | 역할 |
| --- | --- | --- |
| GET | `/api/user/me` | 사용자 프로필, 무료 분석 횟수, 프리미엄/코인 상태를 조회합니다. |
| PATCH | `/api/user/me/premium` | 테스트/관리 목적의 프리미엄 상태를 변경합니다. |
| POST | `/api/user/me/coins` | 사용자 코인을 충전합니다. |
| GET/POST/DELETE | `/api/user/me/bookmarks` | 사용자 북마크 목록 조회, 추가, 삭제를 처리합니다. |
| GET/POST/DELETE | `/api/user/me/recent-visits` | 최근 열어본 리뷰 기록을 관리합니다. |
| GET | `/api/user/me/recent-analyses` | 최근 분석한 매장을 무료 기간/지난 검색으로 나누어 반환합니다. |
| GET/PUT | `/api/user/me/review-reactions` | 사용자가 하트한 리뷰 상태를 조회/갱신합니다. |

인증은 Supabase Bearer token을 기본으로 사용하고, 개발/테스트 편의를 위해 `X-Test-Account-Email` 헤더를 함께 지원합니다.

### 추천 및 피드백 API

| Method | Endpoint | 역할 |
| --- | --- | --- |
| GET | `/api/ai-recommendations` | 광고 가능성이 낮은 리뷰를 기준으로 추천 매장을 반환합니다. |
| GET | `/reviews` | 리뷰 목록을 페이지네이션으로 조회합니다. |
| POST | `/reviews/{review_id}/report` | 리뷰 신고를 저장합니다. |
| POST | `/reviews/{review_id}/vote` | 리뷰 신뢰도 투표를 저장합니다. |
| POST | `/reviews/{review_id}/ai-feedback` | AI 판별 결과에 대한 사용자 피드백을 저장합니다. |
| POST/GET | `/reviews/{review_id}/tag`, `/reviews/{review_id}/tags` | 리뷰 태그 추가와 집계를 제공합니다. |

## 4. 데이터 구조

Supabase는 리뷰와 사용자 상태를 저장하는 중심 저장소입니다. 레포에 마이그레이션 파일이 완비되어 있지는 않지만, 백엔드 코드 기준으로 다음 구조를 사용합니다.

### reviews 주요 필드

| 필드 | 역할 |
| --- | --- |
| `id` | 리뷰 식별자입니다. |
| `name` | 매장명입니다. |
| `store_id` | Kakao place id 기반 매장 식별자입니다. |
| `review_title` | Naver Blog 리뷰 제목입니다. |
| `review_description` | Naver Blog 리뷰 요약 본문입니다. |
| `review_bloggername` | 블로거 이름입니다. |
| `review_url` | 원문 블로그 URL입니다. 중복 저장 방지 기준으로 사용합니다. |
| `review_postdate` | 리뷰 작성일입니다. |
| `is_ad_finetuned_pred` | ELECTRA 기반 모델의 광고 가능성 점수입니다. |
| `address_name`, `road_address_name` | 위치 기반 추천과 장소 표시를 위한 주소입니다. |
| `category_name`, `category_group_code` | 음식점/카페 카테고리 정보입니다. |

### user_profiles 주요 상태

| 필드 | 역할 |
| --- | --- |
| `email` | Supabase Auth 또는 테스트 계정 이메일입니다. |
| `is_premium` | 프리미엄 여부입니다. |
| `coins` | 유료 분석에 사용할 코인 수입니다. |
| `free_search_count` | 무료 분석 가능 횟수입니다. |
| `premium_search_count` | 프리미엄 분석 가능 횟수입니다. |
| `bookmark` | 사용자별 북마크 매장 map입니다. |
| `recent_visits` | 최근 열어본 리뷰 map입니다. |
| `recent_store_dates` | 매장별 최근 분석 날짜 map입니다. |
| `review_likes` | 리뷰 하트 반응 map입니다. |

## 5. 서버 아키텍처

백엔드는 HTTP 라우터와 외부 연동/도메인 로직을 분리한 구조입니다.

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

### 요청 흐름

```text
React Web / Flutter App
  -> FastAPI Router
  -> Service Layer
  -> Kakao Local API / Naver Blog API / Supabase / ELECTRA Model
  -> 정규화된 JSON 또는 SSE 응답
```

`main.py`는 FastAPI 앱 생성, CORS 설정, 라우터 등록, 서버 시작 시 ELECTRA 모델 로딩을 담당합니다. `routers`는 HTTP 요청/응답 경계를 담당하고, `services`는 외부 API 호출, 전처리, 모델 추론, Supabase 접근을 담당합니다.

## 6. 핵심 구현

### 1) 캐시 우선 리뷰 분석 흐름

리뷰 상세 분석은 먼저 Supabase 캐시를 조회합니다. 이미 분석된 리뷰가 있으면 즉시 반환하고, 부족한 경우에만 Naver Blog API를 호출해 신규 리뷰를 수집합니다. 신규 리뷰는 모델 분석 후 Supabase에 저장해 다음 요청에서 재사용합니다.

이 구조로 같은 매장을 반복 분석할 때 외부 API 호출과 모델 추론 비용을 줄였습니다.

### 2) SSE 기반 점진적 분석 응답

`/api/search/stream`은 리뷰를 한 번에 모두 분석한 뒤 반환하지 않고, 배치 단위로 분석한 결과를 SSE `data:` 이벤트로 보냅니다. 프론트엔드는 중간 결과를 받을 때마다 리뷰 목록을 갱신할 수 있어 분석 대기 시간을 체감상 줄일 수 있습니다.

### 3) 장소 기반 리뷰 필터링

Naver Blog 검색은 매장명이 같은 다른 지점이나 무관한 키워드가 섞일 수 있습니다. `naver_service.py`와 `search.py`에서는 매장명 정규화, 주소/카테고리 기반 검색어 생성, 매장명 포함 여부 필터링을 통해 선택한 장소와 관련성이 높은 리뷰만 남기도록 처리했습니다.

### 4) 사용자 사용량 차감 정책

`supabase_service.py`는 무료 분석 횟수, 프리미엄 분석 횟수, 코인 차감을 한 곳에서 처리합니다. 같은 매장을 당일 다시 여는 경우 중복 차감하지 않는 예외도 함께 관리해 클라이언트가 과금 정책을 직접 판단하지 않도록 했습니다.

### 5) 위치 기반 AI 추천

`ai_recommend.py`는 광고 점수가 낮은 리뷰를 Supabase에서 조회하고, 좌표가 들어오면 Kakao 좌표-행정구역 변환 결과로 시/구/동 범위를 구성합니다. 주소 표기가 다양한 문제를 줄이기 위해 지역명 변형을 생성해 필터링합니다.

## 7. 예외 처리

| 상황 | 처리 방식 |
| --- | --- |
| 필수 인증 누락 | `401 Unauthorized`와 명확한 detail 메시지를 반환합니다. |
| 사용자 입력 누락 | `query`, `storeId`, `reviewId` 등 필수값을 검사하고 `400` 계열 오류를 반환합니다. |
| 외부 API 실패 | Kakao/Naver/Supabase 호출 실패 시 `HTTPException` 또는 fallback 응답으로 처리합니다. |
| 모델 파일 없음 | 서버는 중단하지 않고 모델 사용 불가 상태로 두며 점수 `0.0` fallback을 사용합니다. |
| 스트리밍 중 추론 실패 | 해당 배치 점수를 `0.0`으로 대체하고 스트림 자체는 이어갑니다. |
| Supabase 설정 누락 | 필요한 환경변수가 없으면 명시적인 런타임 오류를 발생시킵니다. |

서비스 관점에서 중요한 결정은 모델이나 외부 API 일부가 실패해도 전체 탐색 기능이 완전히 멈추지 않도록 fallback 경로를 둔 점입니다.

## 8. 성능 및 안정성

- Supabase 캐시를 먼저 조회해 반복 분석 비용을 줄였습니다.
- 신규 분석은 `STREAM_BATCH_SIZE` 단위로 나누어 SSE로 반환했습니다.
- 모델 추론은 배치 입력으로 처리해 리뷰별 단건 호출보다 효율적으로 구성했습니다.
- 서버 시작 시 모델을 한 번 로드해 요청마다 모델을 다시 로드하지 않도록 했습니다.
- 리뷰 수집 개수와 시작 위치는 `review_limits.py`에서 제한해 과도한 요청을 막았습니다.
- 사용자 북마크와 최근 기록은 map 형태로 저장하고 최대 개수를 제한해 프로필 payload가 비대해지는 문제를 줄였습니다.

## 9. 보안 및 설정 관리

- Supabase, Kakao, Naver API 키는 환경변수로 관리합니다.
- `.env.example`에는 필요한 키 이름만 제공하고 실제 값은 포함하지 않습니다.
- 웹 배포용 `.env.production`도 문서에는 변수명만 언급하고 값은 기록하지 않았습니다.
- 사용자 API는 Supabase Bearer token을 확인하고, 테스트 계정 헤더는 별도 경로로 분리해 처리합니다.
- CORS는 로컬 개발 주소와 배포 주소를 허용하도록 설정했습니다.

추가로 운영 환경에서는 Supabase RLS 정책, 테스트 계정 사용 범위, 관리자성 API 접근 제어를 더 엄격히 점검해야 합니다.

## 10. 배포 및 운영

프론트엔드는 Vercel 배포 설정이 있으며, `vercel.json`은 `web` 폴더를 빌드 대상으로 사용합니다. 백엔드는 FastAPI 앱으로 구성되어 로컬 또는 별도 서버에서 실행하는 구조입니다.

```bash
cd backend
uvicorn main:app --reload
```

웹 빌드는 다음 명령으로 수행합니다.

```bash
cd web
npm install
npm run build
```

초기 외부 테스트는 로컬 FastAPI 서버를 Cloudflare Quick Tunnel로 노출하고, 웹은 Vercel에서 제공하는 방식으로 구성했습니다. 다만 Quick Tunnel 환경에서 SSE 응답이 버퍼링되어 실시간 스트리밍 안정성에는 한계가 있었습니다.

## 11. 트러블슈팅

### 문제 1. 신규 매장 리뷰 분석 응답 지연

신규 매장은 Naver Blog 수집과 모델 분석을 모두 거쳐야 해서 사용자가 결과를 기다리는 시간이 길었습니다.

원인은 분석 결과를 모두 만든 뒤 한 번에 반환하는 구조였습니다. 이를 `/api/search/stream` SSE 방식으로 바꾸고, 배치 분석 결과를 중간중간 보내도록 구성했습니다. 그 결과 프론트엔드는 첫 배치가 도착하는 즉시 리뷰 목록을 표시할 수 있게 되었습니다.

### 문제 2. 매장명 때문에 모델 일반화가 흔들림

리뷰 텍스트에 특정 매장명이 반복되면 모델이 실제 광고 표현보다 상호명에 과하게 반응할 수 있었습니다.

`preprocess.py`에서 매장명과 브랜드명을 일반 표현으로 마스킹하고, 제목과 본문을 `[SEP]`로 결합해 모델 입력을 정리했습니다. 이를 통해 새로운 매장에 대한 일반화 가능성을 높이는 방향으로 전처리했습니다.

### 문제 3. 같은 매장 반복 분석 시 사용량 중복 차감

상세 화면을 다시 열 때마다 무료 횟수나 코인이 차감되면 사용자 경험이 나빠집니다.

`recent_store_dates`를 기준으로 매장별 당일 분석 여부를 기록하고, 같은 매장을 다시 여는 경우 차감하지 않는 정책을 `supabase_service.py`에 통합했습니다.

### 문제 4. 지역 기반 추천에서 주소 표기 차이로 누락 발생

Kakao 좌표 변환 결과와 저장된 리뷰 주소의 행정구역 표기가 완전히 일치하지 않는 경우가 있었습니다.

시/구/동 값에서 다양한 검색 변형을 만들고, 도로명주소와 지번주소를 함께 비교해 지역 추천 누락을 줄였습니다.

## 12. 한계와 개선점

| 한계 | 개선 방향 |
| --- | --- |
| 학습 데이터와 모델 파일 전체가 레포에 포함되어 있지 않음 | 학습/평가 파이프라인, 모델 아티팩트 준비 절차, 실험 로그를 별도 문서화합니다. |
| Supabase 스키마 재현성이 부족함 | 마이그레이션 파일과 ERD를 추가해 로컬 재현성을 높입니다. |
| Cloudflare Quick Tunnel에서 SSE 버퍼링 이슈가 있음 | 정식 백엔드 배포 환경 또는 스트리밍 친화적인 인프라로 이전합니다. |
| 외부 API 실패 재시도/서킷브레이커가 제한적임 | timeout, retry, rate limit, 관측 로그를 체계화합니다. |
| 테스트 커버리지가 부족함 | 사용량 차감, SSE 응답, 캐시 hit/miss, 지역 필터링 단위 테스트를 추가합니다. |
| 관리자성 신고/피드백 API 보호가 약함 | 관리자 권한 검사와 Supabase RLS 정책을 강화합니다. |

## 13. 백엔드 역량 어필 포인트

- 지도 서비스 흐름 안에서 Kakao, Naver, Supabase, NLP 모델을 하나의 API 경험으로 통합했습니다.
- 캐시 우선 조회와 SSE 스트리밍으로 외부 API/모델 추론 지연을 줄였습니다.
- 사용자 사용량 정책을 백엔드에서 일관되게 관리해 클라이언트 복잡도를 낮췄습니다.
- 모델 추론 실패, 외부 API 실패, 인증 누락 등 서비스 중단으로 이어질 수 있는 상황에 fallback과 명확한 오류 응답을 두었습니다.
- 웹과 Flutter 앱이 같은 백엔드를 바라보도록 응답 모델과 데이터 정규화 계층을 유지했습니다.
