# Project Structure

이 문서는 `The-Truth-Filtering-Engine` 저장소의 현재 파일 구조와 각 파일의 역할을 정리한 문서입니다.

## 분석 기준

- 기준 명령: `rg --files --hidden -g '!/.git/**'`
- 제외 범위: `.git` 내부 파일, 로컬 의존성/빌드 산출물(`web/node_modules`, `web/dist` 등 `.vercelignore` 및 일반 ignore 대상)
- 보안 기준: `.env.production`은 변수 이름만 확인하고 값은 문서에 적지 않았습니다.
- 현재 Git 상태 참고: `PROJECT_HISTORY.md`, `PROJECT_REPORT_GUIDE.md`는 삭제 상태로 표시되지만 현재 작업 트리에 없어서 파일 역할 목록에서는 제외했습니다.
- `Portfolio_AIEngineer.md`, `Portfolio_Backend.md`, `Portfolio_Frontend.md`는 현재 untracked 파일이지만 작업 트리에 존재하므로 포함했습니다.

## 프로젝트 개요

이 저장소는 지도 기반 광고성 맛집 리뷰 필터링 서비스입니다.

- `backend/`: FastAPI 서버. Kakao Local API, Naver Blog API, Supabase, ELECTRA 기반 광고성 리뷰 판별 모델을 연결합니다.
- `web/`: React + TypeScript + Vite 웹 클라이언트. 카카오맵, 장소 검색, 리뷰 분석, 북마크, 최근분석, AI 추천, 설정 화면을 제공합니다.
- `flutter/`: Flutter 앱. 모바일/웹 앱용 지도 탐색, 리뷰 상세 분석, 북마크, 최근 기록, AI 추천 화면을 제공합니다.
- `design-tokens/`: 웹과 Flutter가 공유하는 디자인 토큰 원본입니다.
- 루트 문서: README, 디자인 시스템 문서, 포트폴리오 초안/출력물, Vercel 배포 설정이 있습니다.

## 최상위 구조

```text
.
├── backend/
│   ├── routers/
│   └── services/
├── design-tokens/
├── flutter/
│   ├── android/
│   ├── assets/
│   ├── ios/
│   ├── lib/
│   ├── linux/
│   ├── macos/
│   ├── test/
│   ├── web/
│   └── windows/
├── portfolio/
│   ├── Portfolio_AIEngineer.md
│   ├── Portfolio_Backend.md
│   ├── Portfolio_Frontend.md
│   ├── git.md
│   ├── information.md
│   └── project_structure.md
├── web/
│   ├── app/
│   ├── portfolio/
│   ├── public/
│   └── src/
├── .vercelignore
├── README.md
└── vercel.json
```

## 루트 파일

| 파일 | 역할 |
| --- | --- |
| `.vercelignore` | Vercel 배포 시 `backend`, Flutter 앱 원본, 웹 의존성/빌드 산출물을 제외합니다. |
| `README.md` | 프로젝트 문제 정의, 핵심 기능, 시스템 아키텍처, 하위 README 안내, AI/NLP 모델 활용, 한계와 개선 방향을 정리한 대표 문서입니다. |
| `vercel.json` | Vercel에서 `web` 폴더를 npm install/build하고 `web/dist`를 산출물로 배포하도록 지정합니다. |

## 포트폴리오

| 파일 | 역할 |
| --- | --- |
| `portfolio/Portfolio_AIEngineer.md` | 프로젝트의 광고성 리뷰 NLP 모델, 전처리, 실험 결과, 서비스 적용, 한계와 개선점을 정리한 AI Engineer 포트폴리오 문서입니다. |
| `portfolio/Portfolio_Backend.md` | FastAPI 백엔드 API, 외부 API 연동, Supabase 캐싱, 사용자 사용량 관리, 운영 한계를 정리한 Backend 포트폴리오 문서입니다. |
| `portfolio/Portfolio_Frontend.md` | React 웹과 Flutter 앱의 지도 UX, 화면 구조, 상태 관리, API 연동, 디자인 시스템을 정리한 Frontend 포트폴리오 문서입니다. |
| `portfolio/git.md` | `origin/dev` 브랜치의 커밋 메시지, 작성자, 변경 범위를 기준으로 서비스의 개발 히스토리를 정리한 문서입니다. |
| `portfolio/information.md` | 프로젝트 개요, 팀 구성, 개발 기간 등 전반적인 프로젝트 정보와 발표자료 요약 내용을 담고 있는 문서입니다. |
| `portfolio/project_structure.md` | 현재 파일 구조와 각 파일 역할을 정리한 이 문서입니다. |

## 디자인 토큰

| 파일 | 역할 |
| --- | --- |
| `design-tokens/DESIGN_SYSTEM.md` | 웹/Flutter 공통 디자인 시스템의 토큰 우선 원칙, 접근성 기준, 변경 규칙을 설명합니다. |
| `design-tokens/README.md` | 공통 디자인 토큰의 구성, 사용 위치, 변경 원칙, 검증 방법을 설명합니다. |
| `design-tokens/tokens.json` | 색상, 폰트, 간격, radius, shadow, 버튼, 입력, 카드, 뱃지, toast 등 공통 디자인 토큰의 원본 JSON입니다. |

## Backend

### Backend 루트

| 파일 | 역할 |
| --- | --- |
| `backend/.env.example` | Supabase, Kakao, Naver API 관련 환경 변수 키 목록을 제공하는 예시 파일입니다. |
| `backend/.gitignore` | 백엔드 로컬/생성 파일 제외 규칙을 담는 Git ignore 파일입니다. |
| `backend/README.md` | FastAPI 백엔드 역할, API, 환경 변수, 실행 방법, 모델 파일, 한계를 설명합니다. |
| `backend/main.py` | FastAPI 앱 진입점입니다. `.env`를 로드하고 CORS, 라우터, ELECTRA 모델 lifespan 로딩, `/`와 `/config` 엔드포인트를 설정합니다. |
| `backend/requirements.txt` | FastAPI 서버, HTTP 클라이언트, 환경 변수 로딩, ELECTRA/Transformers 추론에 필요한 Python 의존성을 정의합니다. |

### Backend Routers

| 파일 | 역할 |
| --- | --- |
| `backend/routers/ai_recommend.py` | 광고 가능성이 낮은 리뷰를 추천 목록으로 반환합니다. 위치 좌표가 있으면 Kakao 행정구역 API와 주소 필터를 이용해 시/구/동 범위 추천을 제공합니다. |
| `backend/routers/places.py` | Kakao Local API로 주변 음식점/카페 검색과 키워드 검색을 수행하고, 거리/주소/카테고리 정보를 프론트엔드 모델 형태로 정규화합니다. |
| `backend/routers/report.py` | 리뷰 목록 조회, 신고, 신뢰도 투표, AI 판별 피드백, 태그 집계 등 리뷰 피드백 관련 REST 엔드포인트를 제공합니다. |
| `backend/routers/search.py` | 리뷰 검색/분석 핵심 라우터입니다. Supabase 캐시 조회, Naver Blog 수집, 전처리, 모델 추론, 사용량 차감, SSE 스트리밍 응답을 처리합니다. |
| `backend/routers/users.py` | Supabase Auth 또는 테스트 계정 헤더를 기반으로 사용자 프로필, 프리미엄, 코인, 북마크, 최근 분석, 최근 방문, 리뷰 반응 API를 제공합니다. |

### Backend Services

| 파일 | 역할 |
| --- | --- |
| `backend/services/electra_service.py` | GPU용 ELECTRA/Transformers 모델을 로드하고 단건/배치 광고 확률 점수를 계산합니다. 모델 파일이 없으면 0점 fallback을 반환합니다. |
| `backend/services/naver_service.py` | Naver Blog API 호출, HTML 정리, 장소명/주소/카테고리 기반 검색어 생성, 매장명 매칭 필터링, 페이지 단위 수집을 담당합니다. |
| `backend/services/preprocess.py` | 리뷰 제목/본문의 HTML 제거, 엔티티 디코딩, 가게명 마스킹, 해시태그/말줄임 정리, `[SEP]` 결합 등 모델 입력 전처리를 수행합니다. |
| `backend/services/review_limits.py` | 리뷰 배치 크기, 최대 결과 수, Naver start 정규화 등 검색/스트리밍 한계를 정의합니다. |
| `backend/services/supabase_service.py` | Supabase DB/Auth 접근을 통합합니다. 리뷰 저장/업서트, 캐시 조회, 분석 점수 업데이트, AI 추천 조회, 사용자 프로필/코인/북마크/최근기록/리뷰반응/사용량 차감을 처리합니다. |

## Web

### Web 설정/루트

| 파일 | 역할 |
| --- | --- |
| `web/.env.production` | 웹 배포용 환경 변수 파일입니다. 확인된 변수는 `VITE_BACKEND_BASE_URL`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`이며 값은 문서에 기록하지 않았습니다. |
| `web/.gitignore` | 웹 프로젝트의 로컬/빌드/의존성 파일 제외 규칙입니다. |
| `web/DESIGN_SYSTEM.md` | 웹 폴더 안에 복사된 디자인 시스템 문서입니다. |
| `web/README.md` | React + Vite 웹 클라이언트의 기능, 환경 변수, 실행/빌드, 배포, 주요 구현 메모를 설명합니다. |
| `web/eslint.config.js` | TypeScript, React Hooks, React Refresh, 브라우저 globals 기반 ESLint 설정입니다. |
| `web/index.html` | React 웹 앱 HTML 진입점입니다. SEO meta, OpenGraph, 구조화 데이터, favicon, `/src/main.tsx` 로딩을 설정합니다. |
| `web/logo.png` | 웹 앱 favicon/브랜드 로고 이미지입니다. |
| `web/package-lock.json` | npm 의존성 잠금 파일입니다. |
| `web/package.json` | React 19, Vite, TypeScript, Supabase, lucide-react 의존성과 `dev/build/lint/preview` 스크립트를 정의합니다. |
| `web/tsconfig.app.json` | 웹 앱 소스용 TypeScript 컴파일 설정입니다. |
| `web/tsconfig.json` | Vite 프로젝트의 TypeScript project references 진입 설정입니다. |
| `web/tsconfig.node.json` | Node 환경 설정 파일용 TypeScript 컴파일 설정입니다. |
| `web/vite.config.ts` | Vite React 플러그인 설정과 `index.html`, `portfolio/index.html` 다중 entry 빌드를 설정합니다. |

### Web App/Portfolio/Public

| 파일 | 역할 |
| --- | --- |
| `web/app/sitemap.ts` | Next.js 스타일 MetadataRoute sitemap 함수입니다. 현재 Vite 앱과 함께 남아 있는 sitemap 코드입니다. |
| `web/portfolio/index.html` | Tailwind CDN을 이용한 포트폴리오 단일 HTML 출력물입니다. 프로젝트 문제, 해결 흐름, 시스템 플로우, AI/NLP 기술 스택, 역할을 시각적으로 정리합니다. |
| `web/public/google5962f5cea71c7113.html` | Google Search Console 소유권 확인용 HTML 파일입니다. |
| `web/public/image.png` | 공개 정적 이미지 자산입니다. |
| `web/public/robots.txt` | 검색 엔진 크롤링 허용 및 sitemap URL을 선언합니다. |
| `web/public/sitemap.xml` | 배포 사이트의 sitemap XML입니다. |
| `web/public/구글 검색 가능하도록 하기.PNG` | Google 검색 노출/등록 관련 참고 이미지입니다. |

### Web Public Thumbnails

| 파일 | 역할 |
| --- | --- |
| `web/public/images/thumbnails/asian.png` | 아시안/퓨전 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/bar.png` | 술집/주점 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/buffet.png` | 뷔페 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/bunsik.png` | 분식 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/cafe.png` | 카페 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/chicken.png` | 치킨 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/chinese.png` | 중식 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/default.png` | 매칭되는 카테고리가 없을 때 쓰는 기본 썸네일입니다. |
| `web/public/images/thumbnails/fastfood.png` | 패스트푸드 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/japanese.png` | 일식 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/korean.png` | 한식 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/meat.png` | 고기/구이 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/noodle.png` | 면/국수 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/pizza.png` | 피자 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/seafood.png` | 해산물/횟집 카테고리 기본 썸네일입니다. |
| `web/public/images/thumbnails/western.png` | 양식 카테고리 기본 썸네일입니다. |

### Web Src 루트/API/Lib

| 파일 | 역할 |
| --- | --- |
| `web/src/App.tsx` | 웹 앱의 중심 컴포넌트입니다. 로그인 상태, 지도 상태, 패널 전환, 검색, 상세 분석, 북마크, 최근분석, AI 추천, 설정 액션을 연결합니다. |
| `web/src/config.ts` | 백엔드 URL, Supabase URL/anon key, Kakao JS key, Google OAuth redirect, 테스트 계정 헤더 상수를 제공합니다. |
| `web/src/index.css` | 웹 앱 전역 스타일입니다. 인트로 스플래시, 지도 레이아웃, 사이드 패널, 검색/상세/북마크/최근/AI/설정 UI, 마커, 반응형 스타일을 정의합니다. |
| `web/src/main.tsx` | React root를 생성해 `App`을 `StrictMode`로 렌더링합니다. |
| `web/src/api/places.ts` | 백엔드 장소 API(`/places/nearby-restaurants`, `/places/search-restaurants`)를 호출하고 음식점 payload를 `Restaurant` 모델로 파싱합니다. |
| `web/src/api/reviews.ts` | 리뷰 상세 타입, 광고 등급, 키워드 생성, SSE 스트림 파서, 상세 JSON 요청, 리뷰 검색 path builder를 제공합니다. |
| `web/src/api/user.ts` | 사용자 프로필, 프리미엄/코인, 북마크, 최근분석 API 호출과 응답 파싱을 담당합니다. |
| `web/src/lib/detailUsage.ts` | 사용자 프로필의 무료 분석 기간, 무료/프리미엄 횟수, 코인 보유량을 기준으로 상세 분석 가능 여부와 버튼 라벨을 계산합니다. |
| `web/src/lib/format.ts` | HTML/엔티티 제거, 외부 URL/이미지 URL 검증, 거리/리뷰 날짜/광고 점수 표시 형식을 제공합니다. |
| `web/src/lib/kakao.ts` | Kakao Maps JS SDK 로더, 지도 타입 선언, 현재 위치 조회, 마커 DOM 생성, 거리/viewport radius 계산 유틸입니다. |
| `web/src/lib/restaurant.ts` | 음식점, AI 추천, 최근분석 타입과 카테고리 썸네일 매핑, API payload 정규화, 북마크 저장 형태 변환을 담당합니다. |
| `web/src/lib/supabase.ts` | Supabase URL/anon key가 있을 때 Supabase 클라이언트를 생성하고 없으면 `null`을 반환합니다. |

### Web Hooks

| 파일 | 역할 |
| --- | --- |
| `web/src/hooks/useAuth.ts` | Supabase Google OAuth와 테스트 계정 로그인을 통합 관리하고 API 인증 헤더를 생성합니다. |
| `web/src/hooks/useBookmarks.ts` | 북마크 목록을 원격 API와 동기화하고 optimistic toggle 상태를 관리합니다. |
| `web/src/hooks/useDetail.ts` | 상세 분석 상태를 관리합니다. 캐시 조회, SSE 분석 스트리밍, 리뷰 정렬/페이지네이션, 숨김 처리, 사용량 프로필 반영을 담당합니다. |
| `web/src/hooks/useMap.ts` | Kakao 지도 초기화, 현재 위치, 지도 idle 기반 주변 장소 검색, 마커 표시, 검색/북마크 포커스 모드를 관리합니다. |
| `web/src/hooks/useReviewActivity.ts` | Supabase 기반 리뷰 하트, 신고, 내 하트 목록, 최근 연 리뷰 기록을 관리합니다. |

### Web Components

| 파일 | 역할 |
| --- | --- |
| `web/src/components/RestaurantThumb.tsx` | 음식점 카테고리/이미지 URL에 맞는 썸네일을 렌더링하고 실패 시 default 썸네일로 fallback합니다. |
| `web/src/components/panels/AiPanel.tsx` | AI 추천 패널입니다. 지역 범위 탭, 추천 카드, 위치 보기, 리뷰 열기, 페이지네이션 상태를 표시합니다. |
| `web/src/components/panels/BookmarkPanel.tsx` | 북마크 목록 패널입니다. 저장된 음식점 선택과 북마크 해제를 제공합니다. |
| `web/src/components/panels/DetailPanel.tsx` | 음식점 상세 패널입니다. 리뷰 키워드, 리뷰 목록, 정렬/페이지네이션, 하트, 신고 다이얼로그, 원문 열기 액션을 렌더링합니다. |
| `web/src/components/panels/LoginPanel.tsx` | 로그인 패널입니다. 로고, SEO 소개 문구, Google 로그인, 테스트 계정 로그인, 포트폴리오 링크를 제공합니다. |
| `web/src/components/panels/RecentPanel.tsx` | 최근분석 패널입니다. 무료 분석 가능 항목과 지난 검색 항목을 표시하고 지도 포커스를 유도합니다. |
| `web/src/components/panels/RestaurantPanel.tsx` | 선택된 음식점 기본 정보 패널입니다. 전화, 저장, 길찾기, 공유, 상세 보기 액션을 제공합니다. |
| `web/src/components/panels/SearchPanel.tsx` | 장소 검색 패널입니다. 검색 입력, 로딩/오류/빈 상태, 결과 목록을 렌더링합니다. |
| `web/src/components/panels/SettingsPanel.tsx` | 계정 설정 패널입니다. 프로필/코인/프리미엄, 하트한 리뷰, 최근 기록, 로그아웃과 관련 목록 관리를 제공합니다. |

### Web Design System

| 파일 | 역할 |
| --- | --- |
| `web/src/design-system/components.css` | 웹 디자인 시스템 컴포넌트의 버튼, 아이콘 버튼, 텍스트 필드, 카드, 뱃지, toast, dialog 스타일을 정의합니다. |
| `web/src/design-system/index.tsx` | `DsButton`, `DsIconButton`, `DsTextField`, `DsCard`, `DsBadge`, `DsToast`, `DsDialog` React 컴포넌트를 제공합니다. |
| `web/src/design-system/tokens.css` | `design-tokens/tokens.json`을 CSS custom properties 형태로 반영한 웹 토큰 파일입니다. |

## Flutter

### Flutter 루트

| 파일 | 역할 |
| --- | --- |
| `flutter/.gitignore` | Flutter 프로젝트 로컬/빌드 산출물 제외 규칙입니다. |
| `flutter/.metadata` | Flutter tool이 관리하는 프로젝트 생성/마이그레이션 메타데이터입니다. |
| `flutter/README.md` | Flutter 앱 기능, 구조, dart-define 설정, 로컬 실행, 테스트 방법을 설명합니다. |
| `flutter/analysis_options.yaml` | `flutter_lints` 기반 Dart analyzer/lint 설정입니다. |
| `flutter/design_system.md` | Flutter 앱 디자인 시스템 관련 문서입니다. |
| `flutter/pubspec.lock` | Flutter/Dart 패키지 의존성 잠금 파일입니다. |
| `flutter/pubspec.yaml` | Flutter 앱 메타데이터, SDK 범위, 의존성, dev 의존성, asset 등록, 실행 보조용 publishable auth 설정을 정의합니다. 민감 값은 별도 관리가 권장됩니다. |
| `flutter/run_web_test.bat` | Windows에서 `pubspec.yaml`의 Flutter auth 설정을 읽어 Chrome 웹 실행에 `--dart-define`으로 전달하는 스크립트입니다. |
| `flutter/run_web_test.sh` | Unix shell에서 동일하게 Supabase 설정을 읽고 `flutter run -d chrome --web-port 8080`을 실행하는 스크립트입니다. |

### Flutter Assets

| 파일 | 역할 |
| --- | --- |
| `flutter/assets/logo.png` | Flutter 앱 로고 asset입니다. |
| `flutter/assets/images/categories/asian.png` | 아시안/퓨전 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/bar.png` | 술집 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/buffet.png` | 뷔페 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/bunsik.png` | 분식 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/cafe.png` | 카페 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/chicken.png` | 치킨 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/chinese.png` | 중식 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/default.png` | 카테고리 매칭 실패 시 사용하는 대표 이미지입니다. |
| `flutter/assets/images/categories/fastfood.png` | 패스트푸드 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/japanese.png` | 일식 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/korean.png` | 한식 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/meat.png` | 고기/구이 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/pizza.png` | 피자 카테고리 대표 이미지입니다. |
| `flutter/assets/images/categories/western.png` | 양식 카테고리 대표 이미지입니다. |
| `flutter/assets/images/thumbnails/asian.png` | 아시안/퓨전 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/bar.png` | 술집 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/buffet.png` | 뷔페 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/bunsik.png` | 분식 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/cafe.png` | 카페 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/chicken.png` | 치킨 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/chinese.png` | 중식 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/default.png` | 카테고리 매칭 실패 시 사용하는 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/fastfood.png` | 패스트푸드 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/japanese.png` | 일식 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/korean.png` | 한식 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/meat.png` | 고기/구이 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/pizza.png` | 피자 카테고리 목록 썸네일입니다. |
| `flutter/assets/images/thumbnails/western.png` | 양식 카테고리 목록 썸네일입니다. |

### Flutter Lib 루트/서비스/모델

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/main.dart` | Flutter 앱 진입점입니다. Supabase 초기화, ProviderScope, `TruthMouthApp`, 로그인 후 `MainShell` 탭 구조를 정의합니다. |
| `flutter/lib/services/api_service.dart` | Dio 기반 백엔드 API 클라이언트입니다. 주변 음식점, 캐시 리뷰, AI 추천 응답을 모델로 변환합니다. |
| `flutter/lib/screens/restaurant_list_screen.dart` | Kakao Local API 직접 호출 기반 음식점 검색 결과 화면입니다. 위치 권한, 검색, 정렬, 오류 메시지, 결과 카드 UI를 포함합니다. |
| `flutter/lib/models/review_item.dart` | legacy 리뷰 아이템 모델입니다. 검색 응답 JSON을 단순 리뷰 객체로 변환합니다. |
| `flutter/lib/models/search_result.dart` | legacy 검색 결과 모델입니다. 리뷰 목록과 광고/진성 개수 계산 getter를 제공합니다. |

### Flutter Core Config/Providers/Theme

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/core/config/backend_config.dart` | `BACKEND_BASE_URL` dart-define 기반 백엔드 URL과 API URI 생성 유틸을 제공합니다. |
| `flutter/lib/core/config/supabase_config.dart` | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, 모바일 OAuth redirect URL과 설정 가능 여부를 정의합니다. |
| `flutter/lib/core/config/test_account_auth_config.dart` | 테스트 계정 헤더 또는 Supabase Bearer 토큰 기반 API 인증 헤더를 생성합니다. |
| `flutter/lib/core/providers/analysis_mode_provider.dart` | 광고 분석 모드(`model`, `llm`) Riverpod 상태를 제공합니다. |
| `flutter/lib/core/providers/current_user_provider.dart` | Google OAuth/테스트 계정 로그인 상태, 현재 사용자 이메일, 앱 인증 상태를 관리합니다. |
| `flutter/lib/core/providers/liked_reviews_provider.dart` | 현재 사용자의 하트한 리뷰 목록을 Supabase reviews.likes와 백엔드 review-reactions 기준으로 동기화합니다. |
| `flutter/lib/core/providers/recent_visit_provider.dart` | 최근 열어본 리뷰를 SharedPreferences와 백엔드 `recent-visits` API에 동기화합니다. |
| `flutter/lib/core/providers/user_profile_provider.dart` | 사용자 프로필, 프리미엄, 코인, 분석 횟수, 최근 분석 유효기간 계산을 관리합니다. |
| `flutter/lib/core/theme/app_colors.dart` | legacy import 호환을 위해 디자인 시스템 색상 토큰을 re-export합니다. |
| `flutter/lib/core/theme/app_text_styles.dart` | 지도 마커, 식당명, 메타, 리뷰 인용, 버튼 등 앱 전용 텍스트 스타일을 정의합니다. |
| `flutter/lib/core/theme/app_theme.dart` | legacy import 호환을 위해 디자인 시스템 theme/token을 re-export합니다. |

### Flutter Core Design System

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/core/design_system/app_theme.dart` | Flutter `ThemeData` light 테마를 디자인 토큰 기반으로 구성합니다. |
| `flutter/lib/core/design_system/app_tokens.dart` | Flutter 색상, spacing, radius, shadow, typography, tone mapping 등 디자인 토큰 구현입니다. |
| `flutter/lib/core/design_system/widgets/ds_app_logo.dart` | 앱 로고와 텍스트를 조합한 공통 로고 위젯입니다. |
| `flutter/lib/core/design_system/widgets/ds_badge.dart` | tone별 배경/텍스트 색을 적용한 공통 뱃지 위젯입니다. |
| `flutter/lib/core/design_system/widgets/ds_bottom_sheet.dart` | 핸들과 상단 radius/shadow를 가진 공통 bottom sheet 컨테이너입니다. |
| `flutter/lib/core/design_system/widgets/ds_button.dart` | primary/secondary/ghost/danger, size, loading, icon 옵션을 가진 공통 버튼 위젯입니다. |
| `flutter/lib/core/design_system/widgets/ds_card.dart` | padding/margin/tap 옵션을 가진 공통 카드 위젯입니다. |
| `flutter/lib/core/design_system/widgets/ds_feedback.dart` | `DsToast`와 `DsDialog` 등 피드백 UI 유틸을 제공합니다. |
| `flutter/lib/core/design_system/widgets/ds_text_field.dart` | label, helper/error/success, icon, disabled/readOnly를 지원하는 공통 텍스트 필드입니다. |
| `flutter/lib/core/design_system/widgets/widgets.dart` | 디자인 시스템 위젯 barrel export입니다. |

### Flutter Data Layer

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/data/models/ai_recommend_item.dart` | AI 추천 아이템 모델의 feature 구현을 re-export합니다. |
| `flutter/lib/data/models/blog_review_model.dart` | 상세 리뷰 모델을 data layer 타입 alias로 재사용합니다. |
| `flutter/lib/data/models/review_like_model.dart` | 리뷰 하트 상태, 좋아요 사용자 ID 파싱, JSON list 정규화 유틸을 제공합니다. |
| `flutter/lib/data/models/review_report_model.dart` | 리뷰 신고 카테고리, confirm 상태, Supabase `report` jsonb 모델을 정의합니다. |
| `flutter/lib/data/repositories/review_like_repository.dart` | 리뷰 row의 `likes`와 사용자 계정 `review_likes`를 조율하며 하트 상태 조회/토글을 처리합니다. |
| `flutter/lib/data/repositories/review_report_repository.dart` | 신고 제출, 중복 신고 판정, 내 신고 여부 확인 흐름을 repository로 감쌉니다. |
| `flutter/lib/data/sources/review_like_remote_source.dart` | Supabase reviews.likes 및 백엔드 `/user/me/review-reactions` API 접근을 담당합니다. |
| `flutter/lib/data/sources/review_report_remote_source.dart` | Supabase reviews 테이블의 `report`, `confirm` 컬럼을 업데이트/조회합니다. |

### Flutter Features: Map

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/features/map/map_provider.dart` | 주변 음식점 FutureProvider, 선택 음식점, 지도 포커스 대상, 현재 위치, 레이어 메뉴 상태를 정의합니다. |
| `flutter/lib/features/map/models/map_point.dart` | 지도 좌표, bounds, camera 상태와 두 좌표 간 거리 계산을 제공합니다. |
| `flutter/lib/features/map/models/restaurant_model.dart` | 음식점/장소/리뷰 메타를 하나로 담는 핵심 모델입니다. JSON 변환, 카테고리 이미지 경로, 마커 타입 계산을 포함합니다. |
| `flutter/lib/features/map/screens/map_screen.dart` | 메인 지도 화면입니다. 검색바, KakaoMapView, 주변 장소 자동 조회, 현재 위치, 지도 컨트롤, 북마크, 상세 화면 진입을 관리합니다. |
| `flutter/lib/features/map/widgets/kakao_map_view.dart` | 플랫폼에 따라 web/mobile/stub KakaoMapView 구현을 조건부 export합니다. |
| `flutter/lib/features/map/widgets/kakao_map_view_mobile.dart` | 모바일 WebView 기반 Kakao Maps JS SDK 렌더링 구현입니다. Flutter와 JavaScript 채널로 마커/카메라 이벤트를 주고받습니다. |
| `flutter/lib/features/map/widgets/kakao_map_view_stub.dart` | 지원하지 않는 플랫폼에서 표시되는 KakaoMapView placeholder 구현입니다. |
| `flutter/lib/features/map/widgets/kakao_map_view_web.dart` | Flutter web에서 HTML element와 JS interop으로 Kakao Maps SDK를 렌더링합니다. |
| `flutter/lib/features/map/widgets/map_control_buttons.dart` | 내 위치, 지도 타입 전환, 확대/축소 버튼 묶음입니다. |
| `flutter/lib/features/map/widgets/map_search_bar.dart` | 지도 상단 검색 입력을 디자인 시스템 텍스트 필드로 감싼 위젯입니다. |
| `flutter/lib/features/map/widgets/restaurant_bottom_sheet.dart` | 지도에서 선택한 음식점의 썸네일, 메타, 전화/저장/길찾기/공유/상세보기 액션을 표시합니다. |

### Flutter Features: Restaurant Detail

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/features/map/restaurant_detail/blog_review_url.dart` | Naver 블로그 URL을 모바일 URL로 보정하고 비-Naver URL은 그대로 유지합니다. |
| `flutter/lib/features/map/restaurant_detail/providers/blog_review.dart` | 블로그 리뷰 모델, 광고 등급, 상세 화면 요약 `ShopInfo`, 더미 리뷰 데이터를 정의합니다. |
| `flutter/lib/features/map/restaurant_detail/providers/review_like_provider.dart` | 리뷰별 하트 상태 family provider입니다. optimistic toggle, 원격 동기화, 로그인 사용자 ID를 연결합니다. |
| `flutter/lib/features/map/restaurant_detail/providers/review_report_provider.dart` | 리뷰 신고 bottom sheet와 repository를 연결하는 신고 상태 provider입니다. |
| `flutter/lib/features/map/restaurant_detail/restaurant_detail_screen.dart` | 음식점 상세 분석 화면입니다. 캐시 확인, SSE 스트리밍 분석, 리뷰 병합, 워드클라우드, 분석 카드, 최근분석 갱신, 리뷰 원문 기록을 처리합니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/ai_analysis_card.dart` | 진성 리뷰 비율/광고 의심 비율을 원형 점수와 progress bar로 보여주는 분석 카드입니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/no_data_card.dart` | 리뷰 데이터가 없거나 분석 중일 때 표시되는 분석 요청/로딩 카드입니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/report_button.dart` | 리뷰 신고 버튼입니다. 현재 사용자의 신고 여부를 Supabase에서 확인하고 신고 dialog를 엽니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/restaurant_header_widget.dart` | 상세 화면 상단 음식점 이미지, 이름, 주소/카테고리, 전화/저장/길찾기/공유 액션을 표시합니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/review_action_buttons.dart` | 리뷰 카드 우측 하트/신고 액션 묶음입니다. 로그인/프로필 준비 상태를 처리합니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/review_item.dart` | 리뷰 카드 UI입니다. 광고 등급 뱃지, 제목, 미리보기, 작성자/날짜, 액션 버튼을 렌더링합니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/review_list_section.dart` | 추천순/신뢰순/최신순 탭, 10개 단위 페이지네이션, skeleton, 신고 후 숨김, 리뷰 원문 open guard를 처리합니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/review_report_dialog.dart` | 신고 사유 선택과 기타 memo 입력을 제공하는 bottom sheet dialog입니다. |
| `flutter/lib/features/map/restaurant_detail/widgets/word_cloud_card.dart` | 리뷰 제목에서 키워드 빈도를 계산하고 말풍선 형태의 custom painter 워드클라우드로 렌더링합니다. |

### Flutter Features: Bookmarks / Recent / AI / Settings / Auth

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/features/bookmarks/bookmark_provider.dart` | 북마크 음식점 목록 StateNotifierProvider입니다. 로그인 상태에 맞는 BookmarkService를 생성합니다. |
| `flutter/lib/features/bookmarks/bookmark_screen.dart` | 북마크 목록 화면입니다. 저장된 장소를 지도 포커스로 보내거나 제거합니다. |
| `flutter/lib/features/bookmarks/bookmark_service.dart` | 백엔드 북마크 API와 로컬 메모리 상태를 동기화하며 추가/삭제를 처리합니다. |
| `flutter/lib/features/ai_recommend/ai_recommend_item.dart` | AI 추천 응답 모델입니다. 광고 점수 percent 계산과 지도 포커스용 `RestaurantModel` 변환을 제공합니다. |
| `flutter/lib/features/ai_recommend/ai_recommend_provider.dart` | AI 추천 목록 상태, 지역 범위(`si/gu/dong`), 페이지네이션, 현재 위치 기반 API 조회를 관리합니다. |
| `flutter/lib/features/ai_recommend/ai_recommend_screen.dart` | AI 추천 화면입니다. 지역 chip, 현재 위치 안내, 추천 카드 목록, 이전/다음 페이지 컨트롤을 표시합니다. |
| `flutter/lib/features/ai_recommend/recommend_card.dart` | AI 추천 단일 카드입니다. 광고 가능성 뱃지, 리뷰 요약, 위치 보기, 리뷰 열기 액션을 제공합니다. |
| `flutter/lib/features/recent_analysis/recent_analysis_provider.dart` | 백엔드 최근분석 API 응답을 파싱하고 무료 분석 가능/만료 항목을 관리합니다. |
| `flutter/lib/features/recent_analysis/recent_analysis_screen.dart` | 최근분석 목록 화면입니다. 날짜 뱃지, 장소 정보, 위치 정보 유무, 지도 포커스 액션을 표시합니다. |
| `flutter/lib/features/settings/account_section.dart` | 설정 화면의 계정 part입니다. 프로필 표시, 프리미엄 토글, 코인 충전, 로그아웃을 구현합니다. |
| `flutter/lib/features/settings/liked_reviews/liked_reviews_screen.dart` | 설정 하위 내 하트 화면입니다. 하트한 리뷰 목록, 원문 열기, 하트 해제를 제공합니다. |
| `flutter/lib/features/settings/recent_reviews/recent_reviews_screen.dart` | 설정 하위 최근 기록 화면입니다. 최근 연 리뷰 목록, 원문 열기, 개별 삭제를 제공합니다. |
| `flutter/lib/features/settings/review_menu_section.dart` | 설정 화면에서 내 하트/최근 기록 하위 화면으로 이동하는 메뉴 section입니다. |
| `flutter/lib/features/settings/settings_flow_bottom_nav.dart` | 설정 하위 화면에서 메인 탭으로 복귀하는 bottom navigation part입니다. |
| `flutter/lib/features/settings/settings_screen.dart` | 설정 화면 본체입니다. 계정/리뷰 section part를 묶고 리뷰 원문 열기/최근 기록 저장 helper를 제공합니다. |
| `flutter/lib/features/start_auth/start_auth_screen.dart` | 앱 시작 로그인 화면입니다. Google OAuth, 테스트 계정 로그인, Supabase auth state listener, MainShell 이동을 처리합니다. |

### Flutter Docs

| 파일 | 역할 |
| --- | --- |
| `flutter/lib/docs/CONTRIBUTING.md` | Flutter 프로젝트 기여/작업 가이드 문서입니다. |
| `flutter/lib/docs/GRAPHIFY_INTEGRATION_GUIDE.md` | Graphify 연동 관련 가이드 문서입니다. |
| `flutter/lib/docs/[SCRUM-52-1].md` | SCRUM-52 관련 작업 기록/문서 1입니다. |
| `flutter/lib/docs/[SCRUM-52-2].md` | SCRUM-52 관련 작업 기록/문서 2입니다. |

### Flutter Tests

| 파일 | 역할 |
| --- | --- |
| `flutter/test/features/ai_recommend/ai_recommend_screen_test.dart` | AI 추천 화면의 지역 범위 chip 표시/선택과 현재 위치 미확인 상태 UI를 검증합니다. |
| `flutter/test/features/map/restaurant_detail/blog_review_model_test.dart` | Supabase UUID 리뷰 ID가 리뷰 액션용 ID로 보존되는지 검증합니다. |
| `flutter/test/features/map/restaurant_detail/blog_review_url_test.dart` | Naver desktop/PostView URL이 모바일 블로그 URL로 변환되고 외부 URL은 유지되는지 검증합니다. |
| `flutter/test/features/map/restaurant_detail/review_list_section_test.dart` | 리뷰 추천순 정렬, 페이지네이션, 탭 변경, skeleton, 리뷰 tap guard 동작을 검증합니다. |

### Flutter Web Shell

| 파일 | 역할 |
| --- | --- |
| `flutter/web/favicon.png` | Flutter web favicon입니다. |
| `flutter/web/index.html` | Flutter web HTML shell입니다. `flutter_bootstrap.js`를 로드하고 manifest/favicon/meta를 설정합니다. |
| `flutter/web/manifest.json` | Flutter web PWA manifest입니다. 앱 이름, 색상, 아이콘, display 모드를 정의합니다. |
| `flutter/web/icons/Icon-192.png` | Flutter web 192px 앱 아이콘입니다. |
| `flutter/web/icons/Icon-512.png` | Flutter web 512px 앱 아이콘입니다. |
| `flutter/web/icons/Icon-maskable-192.png` | Flutter web maskable 192px 앱 아이콘입니다. |
| `flutter/web/icons/Icon-maskable-512.png` | Flutter web maskable 512px 앱 아이콘입니다. |

## Flutter Android

| 파일 | 역할 |
| --- | --- |
| `flutter/android/.gitignore` | Android 하위 프로젝트 생성물 제외 규칙입니다. |
| `flutter/android/build.gradle.kts` | Android project-level Gradle 설정입니다. |
| `flutter/android/gradle.properties` | Android/Gradle 빌드 속성 설정입니다. |
| `flutter/android/gradle/wrapper/gradle-wrapper.properties` | Gradle wrapper 배포판 버전/URL 설정입니다. |
| `flutter/android/settings.gradle.kts` | Android Gradle plugin, Flutter plugin, 앱 모듈 include 설정입니다. |
| `flutter/android/app/build.gradle.kts` | Android 앱 모듈 설정입니다. namespace, SDK, Java/Kotlin 17, applicationId, signing 설정을 포함합니다. |
| `flutter/android/app/src/debug/AndroidManifest.xml` | debug 빌드용 Android manifest 오버레이입니다. |
| `flutter/android/app/src/main/AndroidManifest.xml` | Android 앱 권한, launcher activity, OAuth deep link, Flutter embedding, Naver Map client id, 외부 앱 query scheme을 정의합니다. |
| `flutter/android/app/src/main/kotlin/com/example/the_truth_filtering_engine/MainActivity.kt` | Flutter Android MainActivity Kotlin 진입점입니다. |
| `flutter/android/app/src/main/res/drawable/launch_background.xml` | Android launch background drawable입니다. |
| `flutter/android/app/src/main/res/drawable-v21/launch_background.xml` | Android API 21+ launch background drawable입니다. |
| `flutter/android/app/src/main/res/mipmap-hdpi/ic_launcher.png` | Android hdpi launcher icon입니다. |
| `flutter/android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | Android mdpi launcher icon입니다. |
| `flutter/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` | Android xhdpi launcher icon입니다. |
| `flutter/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` | Android xxhdpi launcher icon입니다. |
| `flutter/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | Android xxxhdpi launcher icon입니다. |
| `flutter/android/app/src/main/res/values/styles.xml` | Android 일반 테마/style 정의입니다. |
| `flutter/android/app/src/main/res/values-night/styles.xml` | Android 다크 모드 테마/style 정의입니다. |
| `flutter/android/app/src/profile/AndroidManifest.xml` | profile 빌드용 Android manifest 오버레이입니다. |

## Flutter iOS

| 파일 | 역할 |
| --- | --- |
| `flutter/ios/.gitignore` | iOS 하위 프로젝트 생성물 제외 규칙입니다. |
| `flutter/ios/Flutter/AppFrameworkInfo.plist` | Flutter iOS app framework 정보 plist입니다. |
| `flutter/ios/Flutter/Debug.xcconfig` | iOS Debug 빌드 xcconfig입니다. |
| `flutter/ios/Flutter/Release.xcconfig` | iOS Release 빌드 xcconfig입니다. |
| `flutter/ios/Podfile` | iOS CocoaPods 의존성 설정입니다. |
| `flutter/ios/Runner/AppDelegate.swift` | iOS 앱 delegate 진입 코드입니다. |
| `flutter/ios/Runner/Info.plist` | iOS 앱 표시명, URL scheme, 위치 권한 문구, ATS, 외부 앱 query scheme, Naver Map client id를 정의합니다. |
| `flutter/ios/Runner/Runner-Bridging-Header.h` | Swift/Objective-C bridging header입니다. |
| `flutter/ios/Runner/Base.lproj/LaunchScreen.storyboard` | iOS launch screen storyboard입니다. |
| `flutter/ios/Runner/Base.lproj/Main.storyboard` | iOS main storyboard입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | iOS app icon set 메타데이터입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` | iOS app icon 20pt 1x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` | iOS app icon 20pt 2x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` | iOS app icon 20pt 3x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` | iOS app icon 29pt 1x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` | iOS app icon 29pt 2x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` | iOS app icon 29pt 3x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` | iOS app icon 40pt 1x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` | iOS app icon 40pt 2x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` | iOS app icon 40pt 3x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` | iOS app icon 60pt 2x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` | iOS app icon 60pt 3x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` | iOS app icon 76pt 1x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` | iOS app icon 76pt 2x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` | iPad Pro app icon 83.5pt 2x 이미지입니다. |
| `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` | App Store 1024px marketing icon입니다. |
| `flutter/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` | iOS launch image set 메타데이터입니다. |
| `flutter/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png` | iOS launch image 1x입니다. |
| `flutter/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png` | iOS launch image 2x입니다. |
| `flutter/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png` | iOS launch image 3x입니다. |
| `flutter/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | LaunchImage asset 안내 문서입니다. |
| `flutter/ios/Runner.xcodeproj/project.pbxproj` | Xcode project 빌드 설정 파일입니다. |
| `flutter/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Xcode project workspace 연결 파일입니다. |
| `flutter/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | Xcode workspace check 설정입니다. |
| `flutter/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Xcode workspace 설정입니다. |
| `flutter/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | Xcode Runner shared scheme입니다. |
| `flutter/ios/Runner.xcworkspace/contents.xcworkspacedata` | CocoaPods 포함 iOS workspace 연결 파일입니다. |
| `flutter/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | iOS workspace check 설정입니다. |
| `flutter/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | iOS workspace 설정입니다. |
| `flutter/ios/RunnerTests/RunnerTests.swift` | iOS Runner 기본 테스트 파일입니다. |

## Flutter macOS

| 파일 | 역할 |
| --- | --- |
| `flutter/macos/.gitignore` | macOS 하위 프로젝트 생성물 제외 규칙입니다. |
| `flutter/macos/Flutter/Flutter-Debug.xcconfig` | macOS Debug Flutter xcconfig입니다. |
| `flutter/macos/Flutter/Flutter-Release.xcconfig` | macOS Release Flutter xcconfig입니다. |
| `flutter/macos/Runner/AppDelegate.swift` | macOS 앱 delegate 진입 코드입니다. |
| `flutter/macos/Runner/DebugProfile.entitlements` | macOS Debug/Profile entitlements 설정입니다. |
| `flutter/macos/Runner/Info.plist` | macOS 앱 bundle 정보 plist입니다. |
| `flutter/macos/Runner/MainFlutterWindow.swift` | macOS Flutter window 생성 코드입니다. |
| `flutter/macos/Runner/Release.entitlements` | macOS Release entitlements 설정입니다. |
| `flutter/macos/Runner/Base.lproj/MainMenu.xib` | macOS 앱 기본 메뉴 UI 리소스입니다. |
| `flutter/macos/Runner/Configs/AppInfo.xcconfig` | macOS 앱 이름/식별자 등 정보 설정입니다. |
| `flutter/macos/Runner/Configs/Debug.xcconfig` | macOS Debug 빌드 설정입니다. |
| `flutter/macos/Runner/Configs/Release.xcconfig` | macOS Release 빌드 설정입니다. |
| `flutter/macos/Runner/Configs/Warnings.xcconfig` | macOS warning 관련 빌드 설정입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | macOS app icon set 메타데이터입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png` | macOS 16px app icon입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png` | macOS 32px app icon입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png` | macOS 64px app icon입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png` | macOS 128px app icon입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png` | macOS 256px app icon입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png` | macOS 512px app icon입니다. |
| `flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png` | macOS 1024px app icon입니다. |
| `flutter/macos/Runner.xcodeproj/project.pbxproj` | macOS Xcode project 빌드 설정 파일입니다. |
| `flutter/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | macOS project workspace check 설정입니다. |
| `flutter/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | macOS Runner shared scheme입니다. |
| `flutter/macos/Runner.xcworkspace/contents.xcworkspacedata` | macOS workspace 연결 파일입니다. |
| `flutter/macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | macOS workspace check 설정입니다. |
| `flutter/macos/RunnerTests/RunnerTests.swift` | macOS Runner 기본 테스트 파일입니다. |

## Flutter Linux

| 파일 | 역할 |
| --- | --- |
| `flutter/linux/.gitignore` | Linux 하위 프로젝트 생성물 제외 규칙입니다. |
| `flutter/linux/CMakeLists.txt` | Linux Flutter 앱 최상위 CMake 설정입니다. |
| `flutter/linux/flutter/CMakeLists.txt` | Linux Flutter engine/plugin CMake 설정입니다. |
| `flutter/linux/runner/CMakeLists.txt` | Linux runner 실행 파일 CMake 설정입니다. |
| `flutter/linux/runner/main.cc` | Linux 앱 main 함수 진입점입니다. |
| `flutter/linux/runner/my_application.cc` | Linux GTK 애플리케이션 구현 파일입니다. |
| `flutter/linux/runner/my_application.h` | Linux GTK 애플리케이션 헤더 파일입니다. |

## Flutter Windows

| 파일 | 역할 |
| --- | --- |
| `flutter/windows/.gitignore` | Windows 하위 프로젝트 생성물 제외 규칙입니다. |
| `flutter/windows/CMakeLists.txt` | Windows Flutter 앱 최상위 CMake 설정입니다. |
| `flutter/windows/flutter/CMakeLists.txt` | Windows Flutter engine/plugin CMake 설정입니다. |
| `flutter/windows/runner/CMakeLists.txt` | Windows runner 실행 파일 CMake 설정입니다. |
| `flutter/windows/runner/Runner.rc` | Windows 앱 리소스 스크립트입니다. |
| `flutter/windows/runner/flutter_window.cpp` | Windows Flutter window 구현 파일입니다. |
| `flutter/windows/runner/flutter_window.h` | Windows Flutter window 헤더 파일입니다. |
| `flutter/windows/runner/main.cpp` | Windows 앱 main 함수 진입점입니다. |
| `flutter/windows/runner/resource.h` | Windows 리소스 ID 헤더입니다. |
| `flutter/windows/runner/runner.exe.manifest` | Windows 실행 파일 manifest입니다. |
| `flutter/windows/runner/utils.cpp` | Windows runner 유틸 구현 파일입니다. |
| `flutter/windows/runner/utils.h` | Windows runner 유틸 헤더 파일입니다. |
| `flutter/windows/runner/win32_window.cpp` | Win32 window 래퍼 구현 파일입니다. |
| `flutter/windows/runner/win32_window.h` | Win32 window 래퍼 헤더 파일입니다. |
| `flutter/windows/runner/resources/app_icon.ico` | Windows 앱 아이콘 리소스입니다. |

## 관찰 사항

- 실제 서비스 흐름은 `web/src/App.tsx`, `flutter/lib/main.dart`, `backend/routers/search.py`, `backend/services/supabase_service.py`가 가장 큰 축입니다.
- 리뷰 상세 분석은 웹과 Flutter 모두 캐시 조회 후 필요 시 SSE 스트리밍 분석을 수행하는 구조입니다.
- Flutter와 웹 모두 테스트 계정 헤더 `X-Test-Account-Email`을 지원합니다.
- `report.py`에는 별도 신고/투표/태그 API가 있지만, 현재 웹/Flutter 주요 화면은 Supabase 직접 업데이트와 사용자 API를 더 많이 사용합니다.
- `flutter/lib/data/models/blog_review_model.dart`, `flutter/lib/data/models/ai_recommend_item.dart`처럼 feature 모델을 data layer에서 re-export하는 파일이 있어 legacy import 호환 목적이 보입니다.
- 플랫폼별 Flutter 생성 파일은 대부분 표준 runner/manifest/config/asset 역할이며, 앱 로직은 `flutter/lib`에 집중되어 있습니다.
