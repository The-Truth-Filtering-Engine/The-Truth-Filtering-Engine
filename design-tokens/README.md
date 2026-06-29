# Design Tokens README

Shared design token source for The Truth Filtering Engine.

`design-tokens/tokens.json`은 웹과 Flutter 앱의 색상, typography, spacing, radius, shadow, 버튼, 입력, 카드, 배지, toast 스타일을 맞추기 위한 공통 원본입니다.

## 파일

```text
design-tokens/
└── tokens.json
```

## 토큰 구성

| 영역 | 설명 |
| --- | --- |
| `meta` | 토큰 이름, 버전, 브랜드, tagline 정보를 담습니다. |
| `primitive.color` | white, black, slate, brand, success, warning, danger, info 등 기본 색상입니다. |
| `primitive.font` | 기본 font family와 weight 값입니다. |
| `color` | 배경, surface, text, border, 상태 색상처럼 제품 의미가 붙은 semantic color입니다. |
| `space` | UI 간격 토큰입니다. |
| `radius` | 카드, 버튼, 입력 등에 쓰는 border radius입니다. |
| `shadow` | elevation과 overlay에 쓰는 shadow 값입니다. |
| `component` | button, input, card, badge, toast 등 컴포넌트 단위 토큰입니다. |

## 사용 위치

| 대상 | 위치 |
| --- | --- |
| 웹 CSS 토큰 | `web/src/design-system/tokens.css` |
| 웹 컴포넌트 스타일 | `web/src/design-system/components.css` |
| Flutter 디자인 시스템 | `flutter/lib/core/design_system/app_tokens.dart`, `app_theme.dart` |
| 문서 | `DESIGN_SYSTEM.md`, `web/DESIGN_SYSTEM.md`, `flutter/design_system.md` |

현재는 토큰 JSON에서 각 플랫폼 파일로 자동 변환하는 빌드 스크립트가 없습니다. 토큰을 바꾸면 웹 CSS와 Flutter Dart 토큰 반영 여부를 함께 확인해야 합니다.

## 변경 원칙

- 새 색상이 필요하면 먼저 기존 semantic token으로 표현 가능한지 확인합니다.
- 컴포넌트 내부에서 임의 색상/간격을 늘리기보다 토큰을 우선 사용합니다.
- 웹과 Flutter 중 한쪽만 바뀌지 않도록 관련 파일을 함께 점검합니다.
- 브랜드/상태 색상 변경 시 접근성 대비를 확인합니다.

## 검증

토큰을 수정한 뒤 최소한 다음을 확인합니다.

```bash
cd web
npm run build
```

```bash
cd flutter
flutter test
```

시각 변경이 있는 경우 웹과 Flutter 화면을 직접 확인하는 것이 좋습니다.
