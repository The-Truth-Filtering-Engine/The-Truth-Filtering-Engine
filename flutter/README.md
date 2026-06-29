# Flutter README

Flutter client for The Truth Filtering Engine.

Flutter 앱은 지도 기반 맛집 탐색, 리뷰 상세 분석, 북마크, 최근 분석, AI 추천, 설정 화면을 제공하는 크로스 플랫폼 클라이언트입니다.

## 주요 기능

| 기능 | 설명 |
| --- | --- |
| 시작/로그인 | Supabase Auth와 테스트 계정 로그인을 제공합니다. |
| 지도 탐색 | Kakao Map 기반 매장 탐색 화면과 현재 위치 흐름을 제공합니다. |
| 매장 상세 | 리뷰 광고성 분석 결과, AI 분석 카드, 워드클라우드, 리뷰 목록을 표시합니다. |
| 리뷰 액션 | 리뷰 하트, 신고, 원문 열기, 최근 열어본 리뷰 기록을 지원합니다. |
| 북마크 | 관심 매장을 저장하고 다시 확인할 수 있습니다. |
| 최근 분석 | 최근 분석한 매장을 다시 열 수 있습니다. |
| AI 추천 | 광고 가능성이 낮은 리뷰 기반 추천 매장을 보여줍니다. |
| 설정 | 계정, 하트한 리뷰, 최근 기록 관련 메뉴를 제공합니다. |

## 폴더 구조

```text
flutter/
├── assets/
├── lib/
│   ├── core/
│   ├── data/
│   ├── features/
│   ├── models/
│   ├── screens/
│   ├── services/
│   └── main.dart
├── test/
├── android/
├── ios/
├── web/
├── macos/
├── linux/
└── windows/
```

## 아키텍처

| 영역 | 설명 |
| --- | --- |
| `core/config` | 백엔드 URL, Supabase URL/anon key, 테스트 계정 인증 헤더를 정의합니다. |
| `core/design_system` | Flutter 색상, typography, spacing, 버튼, 카드, 배지 등 공통 UI를 제공합니다. |
| `core/providers` | 현재 사용자, 프로필, 북마크, 최근 기록, 하트한 리뷰 상태를 관리합니다. |
| `data` | 리뷰 하트/신고 모델, repository, remote source를 제공합니다. |
| `features/map` | 지도 화면, 매장 모델, Kakao map view, 매장 상세 화면을 담당합니다. |
| `features/bookmarks` | 북마크 저장/조회 화면과 provider를 담당합니다. |
| `features/recent_analysis` | 최근 분석 목록을 관리합니다. |
| `features/ai_recommend` | AI 추천 목록과 카드 UI를 제공합니다. |
| `features/settings` | 계정/리뷰 활동/최근 기록 설정 화면을 제공합니다. |

## 환경 설정

앱은 `--dart-define`으로 주요 설정을 받습니다.

```text
BACKEND_BASE_URL=http://localhost:8000
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

`BACKEND_BASE_URL`을 지정하지 않으면 코드에 정의된 기본 URL을 사용합니다. 로컬 백엔드와 연결하려면 명시적으로 지정하는 편이 안전합니다.

`pubspec.yaml`에는 웹 테스트 실행을 돕기 위한 `flutter_auth` 설정이 있습니다. README에는 실제 값을 적지 않습니다.

## 로컬 실행

```bash
cd flutter
flutter pub get
flutter run \
  --dart-define=BACKEND_BASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_URL=<supabase-url> \
  --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key>
```

Windows PowerShell에서는 줄바꿈 없이 실행하는 것이 편합니다.

```powershell
cd flutter
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000 --dart-define=SUPABASE_URL=<supabase-url> --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key>
```

## 웹 테스트 실행 스크립트

다음 스크립트는 `pubspec.yaml`의 `flutter_auth` 설정을 읽어 Chrome 웹 실행에 필요한 Supabase 값을 전달합니다.

```bash
cd flutter
./run_web_test.sh
```

Windows에서는 다음을 사용합니다.

```powershell
cd flutter
.\run_web_test.bat
```

기본 웹 포트는 `8080`입니다.

## 테스트

```bash
cd flutter
flutter test
```

현재 테스트는 AI 추천 화면, 블로그 리뷰 모델, 리뷰 URL, 리뷰 리스트 섹션 등을 중심으로 구성되어 있습니다.

## 백엔드 연동

Flutter 앱은 `lib/services/api_service.dart`와 feature별 provider/repository를 통해 FastAPI 백엔드와 Supabase에 접근합니다.

```text
Flutter UI
  -> Riverpod Provider
  -> ApiService / Repository
  -> FastAPI Backend 또는 Supabase
  -> 화면 상태 갱신
```

## 알려진 한계

- 플랫폼별 지도 SDK 설정은 실행 대상에 따라 추가 확인이 필요합니다.
- `pubspec.yaml`의 publishable auth 설정은 운영 보안 정책에 맞게 별도 환경 관리로 옮기는 것이 좋습니다.
- Flutter와 React 웹의 디자인 토큰 동기화는 아직 완전 자동화되어 있지 않습니다.
