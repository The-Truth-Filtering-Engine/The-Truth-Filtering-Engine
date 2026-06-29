# Web README

React + TypeScript + Vite web client for The Truth Filtering Engine.

웹 앱은 지도에서 음식점/카페를 탐색하고, 선택한 매장의 블로그 리뷰 광고성 분석 결과를 확인하는 클라이언트입니다. Kakao Maps JS SDK, FastAPI 백엔드, Supabase Auth를 연결합니다.

## 주요 기능

| 기능 | 설명 |
| --- | --- |
| 로그인 | Supabase Google OAuth와 테스트 계정 로그인을 지원합니다. |
| 지도 탐색 | Kakao Map 위에서 현재 위치, 주변 장소, 검색 결과를 표시합니다. |
| 장소 검색 | 백엔드 `/places/search-restaurants` API로 음식점/카페를 검색합니다. |
| 상세 분석 | 캐시 조회 후 필요 시 SSE 스트리밍으로 리뷰 분석 결과를 받습니다. |
| 북마크 | 매장을 저장하고 지도에서 다시 포커스할 수 있습니다. |
| 최근분석 | 무료 기간인 매장과 지난 검색 매장을 분리해 보여줍니다. |
| AI 추천 | 광고 가능성이 낮은 리뷰 기반 추천 매장을 지역 범위별로 보여줍니다. |
| 설정 | 프로필, 코인/프리미엄 상태, 하트한 리뷰, 최근 기록을 관리합니다. |

## 폴더 구조

```text
web/
├── public/
│   └── images/thumbnails/
├── portfolio/
├── src/
│   ├── api/
│   ├── components/
│   ├── design-system/
│   ├── hooks/
│   ├── lib/
│   ├── App.tsx
│   ├── config.ts
│   ├── index.css
│   └── main.tsx
├── package.json
└── vite.config.ts
```

## 환경 변수

Vite 환경 변수는 `VITE_` prefix가 필요합니다. 값은 커밋하지 않습니다.

```text
VITE_BACKEND_BASE_URL=http://localhost:8000
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_KAKAO_JS_KEY=
```

`VITE_BACKEND_BASE_URL`이 없으면 기본값으로 `http://localhost:8000`을 사용합니다. Supabase 값이 없으면 OAuth 로그인과 사용자 동기화 기능이 제한됩니다.

## 로컬 실행

```bash
cd web
npm install
npm run dev
```

Vite 기본 주소는 다음과 같습니다.

```text
http://localhost:5173
```

백엔드도 함께 실행해야 장소 검색, 상세 분석, 북마크, 추천 기능이 정상 동작합니다.

## 빌드와 검사

```bash
cd web
npm run build
npm run lint
```

빌드 산출물은 `web/dist`에 생성됩니다.

## 배포

루트 `vercel.json`은 웹 폴더를 Vercel 배포 대상으로 사용합니다.

```json
{
  "installCommand": "cd web && npm install",
  "buildCommand": "cd web && npm run build",
  "outputDirectory": "web/dist",
  "framework": "vite"
}
```

배포 환경에서는 Vercel Project Settings에 `VITE_BACKEND_BASE_URL`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_KAKAO_JS_KEY`를 등록합니다.

## 주요 구현 메모

- `src/App.tsx`는 로그인, 지도, 패널 전환, 검색, 상세 분석, 북마크, 최근분석, AI 추천 상태를 연결합니다.
- `src/hooks/useDetail.ts`는 캐시 조회, SSE 스트리밍, 요청 취소, 리뷰 병합, 페이지네이션을 담당합니다.
- `src/hooks/useMap.ts`는 Kakao Map 로딩, 마커 표시, 지도 idle 기반 주변 장소 검색을 관리합니다.
- `src/api/reviews.ts`는 상세 리뷰 JSON 요청과 SSE `data:` 이벤트 파싱을 담당합니다.
- `src/design-system`은 웹 공통 버튼, 카드, 필드, 배지, 토스트, 다이얼로그를 제공합니다.

## 알려진 한계

- 지도와 SSE 상세 분석 플로우에 대한 브라우저 자동화 테스트가 부족합니다.
- 일부 전역 상태가 `App.tsx`에 모여 있어 기능이 더 커지면 상태 store 또는 라우팅 분리를 검토할 수 있습니다.
- Supabase와 Kakao 환경 변수가 없으면 로그인/지도 기능이 제한됩니다.
