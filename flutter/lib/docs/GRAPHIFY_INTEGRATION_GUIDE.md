# Graphify 도입 가이드

## 목적

이 문서는 [Graphify 공식 사이트](https://graphify.net/kr/)와 [safishamsi/graphify 저장소](https://github.com/safishamsi/graphify)를 기준으로, `The-Truth-Filtering-Engine` 프로젝트에서 Graphify 기능을 어떻게 활용하면 되는지 정리한 문서다.

현재 이 저장소는 코드보다 운영 문서 비중이 높고, 워크트리에도 삭제 예정 파일이 섞여 있다. 따라서 지금 시점의 Graphify 도입 목표는 "프로덕션 기능 추가"가 아니라 아래 3가지에 두는 것이 맞다.

1. 저장소 안의 코드, 문서, 다이어그램을 지식 그래프로 구조화한다.
2. Codex가 프로젝트 구조와 설계 의도를 더 짧은 토큰으로 이해할 수 있게 만든다.
3. 이후 소스가 늘어나더라도 변경 영향도와 핵심 노드를 빠르게 파악할 수 있게 한다.

## Graphify에서 가져올 수 있는 핵심 기능

Graphify는 AI 코딩 어시스턴트를 위한 오픈소스 지식 그래프 빌더다. 공식 소개 기준으로 이 프로젝트에 특히 유용한 기능은 다음이다.

### 1. 멀티모달 추출

- 코드 파일: Tree-sitter 기반 AST, 호출 관계, docstring/comment rationale 추출
- 문서 파일: Markdown, HTML, TXT, RST 등의 개념/관계 추출
- PDF: 논문/문서의 개념 및 인용 관계 추출
- 이미지: 다이어그램, 스크린샷 의미 추출

즉, `README`, 설계 문서, 회의 정리, 시스템 다이어그램, 소스코드를 하나의 그래프로 합칠 수 있다.

### 2. Knowledge Graph 생성

- 추출된 노드/엣지를 `graph.json`으로 저장
- `graph.html`로 시각화
- `GRAPH_REPORT.md`로 사람이 읽는 분석 보고서 생성

이 프로젝트에서는 단순 검색보다 "무엇이 무엇과 연결되는지"를 보는 데 가치가 있다.

### 3. 핵심 노드와 예상 밖 연결 탐지

Graphify는 degree가 높은 "god node"와 의외의 연결(surprises)을 찾아준다.

이 기능은 아래 상황에서 유용하다.

- 어떤 문서/모듈이 프로젝트 전체에서 중심 역할을 하는지 찾기
- 문서와 코드가 서로 어긋나는 지점 찾기
- 하나의 규칙/정책 문서가 여러 구현 파일에 영향을 주는지 추적하기

### 4. Codex/CLI 연동

공식 안내 기준으로 Graphify는 Codex 환경에서 사용할 수 있고, `graphify query`, `graphify path`, `graphify explain` 같은 질의 흐름을 제공한다.

프로젝트가 커지면 "전체 코드베이스를 매번 다시 읽는 방식"보다 Graphify 결과물을 바탕으로 필요한 부분만 재질의하는 방식이 효율적이다.

## 이 프로젝트에서의 추천 사용 방식

이 저장소에서는 Graphify를 아래 3단계로 도입하는 것이 현실적이다.

### 단계 1. 저장소 분석 자산 만들기

우선 이 저장소를 Graphify의 입력 대상으로 삼아 기본 산출물을 만든다.

대상 예시:

- 루트의 `CONTRIBUTING.md`
- `README.md`가 복구되면 해당 문서
- 향후 추가될 백엔드/프론트엔드 소스
- 시스템 구조도, 정책 문서, 실험 노트

예상 산출물:

- `graphify-out/graph.json`
- `graphify-out/graph.html`
- `graphify-out/GRAPH_REPORT.md`

가장 먼저 얻는 효과는 "이 프로젝트의 현재 중심 문서/개념이 무엇인지"를 자동으로 드러내는 것이다.

### 단계 2. 문서 중심 프로젝트에 맞게 입력 구조 정리

Graphify는 문서도 강하게 활용하므로, 이 프로젝트는 초기에 코드보다 문서 구조를 정리하는 것이 더 중요하다.

권장 폴더 구조:

```text
docs/
  product/
  architecture/
  policies/
  research/
diagram/
src/
tests/
```

권장 이유:

- 문서와 코드가 섞여 있어도 Graphify가 관계를 묶기 쉽다.
- 이후 `graphify watch`나 재빌드 시 변경 영향 추적이 쉬워진다.
- Codex가 "정책 -> 설계 -> 구현" 흐름을 파악하기 쉬워진다.

### 단계 3. Codex 작업 흐름에 편입

이 프로젝트에서 Graphify의 가장 큰 가치는 개발자가 직접 HTML 그래프를 보는 것보다, Codex가 그래프 결과를 바탕으로 질문에 답하게 만드는 데 있다.

권장 흐름:

1. 문서/코드 추가
2. Graphify 재실행
3. `graph.json`과 `GRAPH_REPORT.md` 생성
4. Codex에게 그래프 산출물을 기준으로 질문

예시 질문:

- "이 프로젝트의 핵심 정책 문서와 직접 연결된 구현 파일은 무엇인가?"
- "팩트체크 엔진 규칙과 테스트 사이의 연결이 약한 부분은 어디인가?"
- "가장 중심 degree를 가진 노드는 무엇이고 왜 중요한가?"

## 실제 도입 방법

## 1. 로컬 설치

공식 사이트 기준 설치는 아래 흐름이다.

```bash
pip install graphifyy
graphify install
```

Graphify는 Python 3.10+ 기준으로 안내되어 있다.

Windows 환경에서 먼저 확인할 것:

- `python --version`
- `pip --version`

## 2. 프로젝트 대상 첫 분석 실행

이 저장소 루트에서 아래처럼 실행하면 된다.

```bash
graphify .
```

또는 공식 예시처럼 입력 폴더를 명시적으로 줄 수도 있다.

```bash
graphify ./raw
```

이 프로젝트에서는 루트 전체를 바로 돌리기보다, 초반에는 문서와 소스가 모인 폴더를 명시해서 실행하는 편이 낫다.

예시:

```bash
graphify ./docs
graphify ./src
```

문서와 코드를 분리 운영하다가, 구조가 안정되면 루트 단위로 확장하는 방식이 좋다.

## 3. 산출물 버전 관리 방침 정하기

다음 중 하나를 선택하면 된다.

### 옵션 A. `graphify-out/`을 커밋하지 않음

추천 상황:

- 그래프를 로컬 분석 도구로만 쓸 때
- 산출물 크기나 변경량이 클 때

권장:

- `.gitignore`에 `graphify-out/` 추가

### 옵션 B. `GRAPH_REPORT.md`만 선택적으로 커밋

추천 상황:

- PR 리뷰에서 "현재 구조 분석 결과"를 공유하고 싶을 때
- 팀원 간에 핵심 노드와 surprise 연결을 문서로 남기고 싶을 때

### 옵션 C. `graph.json`까지 커밋

추천 상황:

- 이후 별도 UI나 사내 도구에서 그래프 데이터를 직접 활용할 계획이 있을 때

현재 프로젝트 단계에서는 **옵션 B**가 가장 현실적이다.

## 이 프로젝트에 맞는 권장 적용안

### 적용안 A. 아키텍처 문서 인덱서로 사용

문서가 많은 프로젝트에서 가장 먼저 쓸 만한 방식이다.

진행:

1. `docs/architecture`, `docs/policies`, `docs/research` 정리
2. Graphify 실행
3. `GRAPH_REPORT.md`로 핵심 개념과 연결 구조 확인

효과:

- 설계 의도와 구현 후보 사이의 연결을 빠르게 파악 가능
- 신규 기여자가 프로젝트를 온보딩하기 쉬워짐

### 적용안 B. 변경 영향도 분석기로 사용

프로젝트가 커지면 변경 한 건이 어느 문서/모듈/테스트에 연결되는지 빠르게 확인하는 데 쓸 수 있다.

진행:

1. 기능 추가 전 Graphify 실행
2. 변경 후 재실행
3. `god nodes`, `surprises`, 연결 경로 비교

효과:

- 변경이 국소적인지 구조적인지 판단 가능
- 테스트 보강이 필요한 연결 지점 파악 가능

### 적용안 C. "정책-규칙-구현" 추적 도구로 사용

`The-Truth-Filtering-Engine`라는 이름상, 사실 검증 규칙 또는 신뢰성 판단 기준이 핵심 자산이 될 가능성이 높다.

이 경우 Graphify는 아래 연결을 만드는 데 유용하다.

- 정책 문서
- 규칙 정의 문서
- 구현 코드
- 테스트 케이스
- 예시 데이터 또는 리서치 문서

이 구조를 잘 만들면 Codex에게 단순 코드 질문이 아니라 "이 판단 규칙이 어디에서 정의되고 어디에서 검증되는가?" 같은 질문을 던질 수 있다.

## 추천 저장소 작업 항목

이 저장소에 실제로 적용하려면 아래 순서로 진행하는 것이 좋다.

1. `README.md`와 핵심 설계 문서를 복구 또는 신규 작성
2. `docs/`, `src/`, `tests/` 기본 구조 생성
3. Graphify 설치 및 첫 분석 실행
4. `graphify-out/GRAPH_REPORT.md` 결과 검토
5. 필요하면 `.gitignore` 또는 커밋 정책 결정
6. 이후 PR마다 선택적으로 Graphify 재실행

## 바로 적용 가능한 예시 운영 규칙

### PR/개발 프로세스에 넣는 방법

- 구조를 크게 바꾸는 PR에서는 Graphify를 다시 실행한다.
- `GRAPH_REPORT.md`에서 새 중심 노드나 surprise 연결이 생겼는지 확인한다.
- 정책/설계 문서를 바꿨다면 연결된 테스트도 함께 점검한다.

### 문서 작성 규칙

Graphify가 잘 동작하려면 문서 이름과 내용이 추상적이면 안 된다.

예시:

- `docs/policies/source-credibility.md`
- `docs/architecture/pipeline-overview.md`
- `docs/research/claim-verification-flow.md`

이렇게 하면 Graphify가 개념과 파일 관계를 더 명확하게 잡는다.

## 한계와 주의점

1. 현재 저장소는 실제 소스가 거의 없어 초기 그래프 밀도가 낮을 수 있다.
2. 문서 품질이 낮거나 파일명이 모호하면 그래프 품질도 같이 떨어진다.
3. Graphify는 분석 보조 도구이지, 프로젝트 구조를 대신 설계해 주는 도구는 아니다.
4. 산출물을 무조건 커밋하기보다 팀 운영 방식에 맞는 정책이 먼저 필요하다.

## 결론

이 프로젝트에서 Graphify를 쓰는 가장 좋은 방식은 "기능 라이브러리로 코드에 내장"하는 것이 아니라, **저장소 전체의 코드/문서/다이어그램을 지식 그래프로 빌드해서 Codex의 프로젝트 이해도를 높이는 분석 레이어**로 도입하는 것이다.

가장 현실적인 첫 실행안은 아래와 같다.

1. 저장소 구조를 `docs/`, `src/`, `tests/` 중심으로 정리한다.
2. `pip install graphifyy` 후 `graphify .` 또는 폴더 단위 분석을 실행한다.
3. `GRAPH_REPORT.md`와 `graph.json`을 기준으로 프로젝트 중심 노드와 연결 구조를 파악한다.
4. 이후 구조 변경이 큰 작업마다 Graphify를 재실행해 영향도를 관리한다.

## 참고 링크

- Graphify 공식 사이트: https://graphify.net/kr/
- GitHub 저장소: https://github.com/safishamsi/graphify

# graphify

[![CI](https://github.com/safishamsi/graphify/actions/workflows/ci.yml/badge.svg?branch=v3)](https://github.com/safishamsi/graphify/actions/workflows/ci.yml)
[![PyPI](https://img.shields.io/pypi/v/graphifyy)](https://pypi.org/project/graphifyy/)
[![Sponsor](https://img.shields.io/badge/sponsor-safishamsi-ea4aaa?logo=github-sponsors)](https://github.com/sponsors/safishamsi)

**AI 코딩 어시스턴트를 위한 스킬.** Claude Code, Codex, OpenCode, OpenClaw, Factory Droid, 또는 Trae에서 `/graphify`를 입력하면 파일을 읽고 지식 그래프를 구축하여, 미처 몰랐던 구조를 보여줍니다. 코드베이스를 더 빠르게 이해하고, 아키텍처 결정의 "이유"를 찾아보세요.

완전한 멀티모달 지원. 코드, PDF, 마크다운, 스크린샷, 다이어그램, 화이트보드 사진, 심지어 다른 언어로 된 이미지까지 — graphify는 Claude Vision을 사용하여 이 모든 것에서 개념과 관계를 추출하고 하나의 그래프로 연결합니다. tree-sitter AST를 통해 20개 언어를 지원합니다(Python, JS, TS, Go, Rust, Java, C, C++, Ruby, C#, Kotlin, Scala, PHP, Swift, Lua, Zig, PowerShell, Elixir, Objective-C, Julia).

> Andrej Karpathy는 논문, 트윗, 스크린샷, 메모를 모아두는 `/raw` 폴더를 관리합니다. graphify는 바로 그 문제에 대한 답입니다 — 원본 파일을 직접 읽는 것 대비 쿼리당 토큰 소비가 71.5배 적고, 세션 간에 영속적이며, 발견한 것과 추측한 것을 정직하게 구분합니다.

```
/graphify .                        # 어떤 폴더든 동작 - 코드베이스, 노트, 논문, 무엇이든
```

```
graphify-out/
├── graph.html       인터랙티브 그래프 - 노드 클릭, 검색, 커뮤니티별 필터
├── GRAPH_REPORT.md  갓 노드, 의외의 연결, 추천 질문
├── graph.json       영속 그래프 - 몇 주 후에도 재읽기 없이 쿼리 가능
└── cache/           SHA256 캐시 - 재실행 시 변경된 파일만 처리
```

그래프에 포함하지 않을 폴더를 제외하려면 `.graphifyignore` 파일을 추가하세요:

```
# .graphifyignore
vendor/
node_modules/
dist/
*.generated.py
```

`.gitignore`와 동일한 문법입니다. 패턴은 graphify를 실행한 폴더 기준의 상대 경로에 대해 매칭됩니다.

## 동작 원리

graphify는 두 번의 패스로 실행됩니다. 첫 번째는 결정론적 AST 패스로, 코드 파일에서 구조(클래스, 함수, 임포트, 콜 그래프, docstring, 근거 주석)를 LLM 없이 추출합니다. 두 번째는 Claude 서브에이전트가 문서, 논문, 이미지에 대해 병렬로 실행되어 개념, 관계, 설계 근거를 추출합니다. 결과는 NetworkX 그래프로 병합되고, Leiden 커뮤니티 탐지로 클러스터링되며, 인터랙티브 HTML, 쿼리 가능한 JSON, 그리고 일반 언어 감사 보고서로 내보내집니다.

**클러스터링은 그래프 토폴로지 기반 — 임베딩을 사용하지 않습니다.** Leiden은 엣지 밀도를 기반으로 커뮤니티를 찾습니다. Claude가 추출하는 의미적 유사성 엣지(`semantically_similar_to`, INFERRED로 표시)는 이미 그래프에 포함되어 있으므로 커뮤니티 탐지에 직접 영향을 줍니다. 그래프 구조 자체가 유사성 신호이며 — 별도의 임베딩 단계나 벡터 데이터베이스가 필요하지 않습니다.

모든 관계는 `EXTRACTED`(소스에서 직접 발견), `INFERRED`(합리적 추론, 신뢰도 점수 포함), `AMBIGUOUS`(리뷰 필요 표시) 중 하나로 태깅됩니다. 무엇이 발견된 것이고 무엇이 추측된 것인지 항상 알 수 있습니다.

## 설치

**필수 요구사항:** Python 3.10+ 및 다음 중 하나: [Claude Code](https://claude.ai/code), [Codex](https://openai.com/codex), [OpenCode](https://opencode.ai), [OpenClaw](https://openclaw.ai), [Factory Droid](https://factory.ai), 또는 [Trae](https://trae.ai)

```bash
pip install graphifyy && graphify install
```

> PyPI 패키지는 `graphify` 이름을 되찾는 동안 임시로 `graphifyy`로 명명되어 있습니다. CLI와 스킬 명령은 여전히 `graphify`입니다.

> `graphify install` 이 안되면 환경변수로 등록해야 합니다.

### 플랫폼 지원

| 플랫폼                  | 설치 명령                                                                 |
| ----------------------- | ------------------------------------------------------------------------- |
| Claude Code (Linux/Mac) | `graphify install`                                                        |
| Claude Code (Windows)   | `graphify install` (자동 감지) 또는 `graphify install --platform windows` |
| Codex                   | `graphify install --platform codex`                                       |
| OpenCode                | `graphify install --platform opencode`                                    |
| OpenClaw                | `graphify install --platform claw`                                        |
| Factory Droid           | `graphify install --platform droid`                                       |
| Trae                    | `graphify install --platform trae`                                        |
| Trae CN                 | `graphify install --platform trae-cn`                                     |

Codex 사용자는 병렬 추출을 위해 `~/.codex/config.toml`의 `[features]` 아래에 `multi_agent = true`도 필요합니다. Factory Droid는 병렬 서브에이전트 디스패치에 `Task` 도구를 사용합니다. OpenClaw는 순차 추출을 사용합니다(해당 플랫폼의 병렬 에이전트 지원은 아직 초기 단계입니다). Trae는 병렬 서브에이전트 디스패치에 Agent 도구를 사용하며 PreToolUse 훅을 **지원하지 않습니다** — AGENTS.md가 상시 작동 메커니즘입니다.

그런 다음 AI 코딩 어시스턴트를 열고 입력하세요:

```
/graphify .
```

참고: Codex는 스킬 호출에 `/` 대신 `$`를 사용하므로 `$graphify .`라고 입력하세요.

### 어시스턴트가 항상 그래프를 사용하도록 설정 (권장)

그래프를 빌드한 후, 프로젝트에서 한 번만 실행하세요:

| 플랫폼        | 명령                        |
| ------------- | --------------------------- |
| Claude Code   | `graphify claude install`   |
| Codex         | `graphify codex install`    |
| OpenCode      | `graphify opencode install` |
| OpenClaw      | `graphify claw install`     |
| Factory Droid | `graphify droid install`    |
| Trae          | `graphify trae install`     |
| Trae CN       | `graphify trae-cn install`  |

**Claude Code**는 두 가지를 수행합니다: 아키텍처 질문에 답하기 전에 `graphify-out/GRAPH_REPORT.md`를 읽도록 Claude에게 지시하는 `CLAUDE.md` 섹션을 작성하고, 모든 Glob 및 Grep 호출 전에 실행되는 **PreToolUse 훅**(`settings.json`)을 설치합니다. 지식 그래프가 존재하면 Claude는 다음 메시지를 보게 됩니다: _"graphify: Knowledge graph exists. Read GRAPH_REPORT.md for god nodes and community structure before searching raw files."_ — 이를 통해 Claude는 모든 파일을 grep하는 대신 그래프를 통해 탐색합니다.

**Codex**는 `AGENTS.md`에 작성하고 Bash 도구 호출 전에 실행되는 **PreToolUse 훅**을 `.codex/hooks.json`에 설치합니다 — Claude Code와 동일한 상시 작동 메커니즘입니다.

**OpenCode, OpenClaw, Factory Droid, Trae**는 프로젝트 루트의 `AGENTS.md`에 동일한 규칙을 작성합니다. 이 플랫폼들은 PreToolUse 훅을 지원하지 않으므로 AGENTS.md가 상시 작동 메커니즘입니다.

제거는 대응하는 uninstall 명령으로 수행합니다(예: `graphify claude uninstall`).

**상시 작동 vs 명시적 트리거 — 차이점은?**

상시 작동 훅은 `GRAPH_REPORT.md`를 노출합니다 — 갓 노드, 커뮤니티, 의외의 연결을 한 페이지로 요약한 것입니다. 어시스턴트는 파일 검색 전에 이것을 읽으므로 키워드 매칭이 아닌 구조 기반으로 탐색합니다. 이것만으로 대부분의 일상적인 질문을 처리할 수 있습니다.

`/graphify query`, `/graphify path`, `/graphify explain`은 더 깊이 들어갑니다: 원시 `graph.json`을 홉 단위로 순회하고, 노드 간의 정확한 경로를 추적하며, 엣지 수준의 세부 정보(관계 유형, 신뢰도 점수, 소스 위치)를 보여줍니다. 일반적인 오리엔테이션이 아닌 그래프에서 특정 질문에 답하고 싶을 때 사용하세요.

이렇게 생각하면 됩니다: 상시 작동 훅은 어시스턴트에게 지도를 주고, `/graphify` 명령은 그 지도를 정확하게 탐색하게 합니다.

## `graph.json`을 LLM과 함께 사용하기

`graph.json`은 프롬프트에 한 번에 전부 붙여넣기 위한 것이 아닙니다. 유용한 워크플로우는 다음과 같습니다:

1. `graphify-out/GRAPH_REPORT.md`로 높은 수준의 개요를 파악합니다.
2. `graphify query`를 사용하여 답하려는 특정 질문에 대한 더 작은 서브그래프를 가져옵니다.
3. 전체 원시 코퍼스 대신 그 집중된 결과를 어시스턴트에게 제공합니다.

예를 들어, 프로젝트에서 graphify를 실행한 후:

```bash
graphify query "show the auth flow" --graph graphify-out/graph.json
graphify query "what connects DigestAuth to Response?" --graph graphify-out/graph.json
```

출력에는 노드 레이블, 엣지 유형, 신뢰도 태그, 소스 파일, 소스 위치가 포함됩니다. 이는 LLM을 위한 좋은 중간 컨텍스트 블록이 됩니다:

```text
이 그래프 쿼리 결과를 사용하여 질문에 답하세요. 추측보다 그래프 구조를 우선하고,
가능한 경우 소스 파일을 인용하세요.
```

어시스턴트가 도구 호출이나 MCP를 지원하는 경우, 텍스트를 붙여넣는 대신 그래프를 직접 사용하세요. graphify는 `graph.json`을 MCP 서버로 노출할 수 있습니다:

```bash
python -m graphify.serve graphify-out/graph.json
```

이를 통해 어시스턴트가 `query_graph`, `get_node`, `get_neighbors`, `shortest_path` 같은 반복 쿼리에 구조화된 그래프 접근을 할 수 있습니다.

<details>
<summary>수동 설치 (curl)</summary>

```bash
mkdir -p ~/.claude/skills/graphify
curl -fsSL https://raw.githubusercontent.com/safishamsi/graphify/v3/graphify/skill.md \
  > ~/.claude/skills/graphify/SKILL.md
```

`~/.claude/CLAUDE.md`에 추가:

```
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.
```

</details>

## 사용법

```
/graphify                          # 현재 디렉토리에서 실행
/graphify ./raw                    # 특정 폴더에서 실행
/graphify ./raw --mode deep        # 더 적극적인 INFERRED 엣지 추출
/graphify ./raw --update           # 변경된 파일만 재추출하여 기존 그래프에 병합
/graphify ./raw --cluster-only     # 기존 그래프의 클러스터링만 재실행, 재추출 없음
/graphify ./raw --no-viz           # HTML 건너뛰기, 보고서 + JSON만 생성
/graphify ./raw --obsidian                          # Obsidian 볼트도 생성 (옵트인)
/graphify ./raw --obsidian --obsidian-dir ~/vaults/myproject  # 볼트를 특정 디렉토리에 생성

/graphify add https://arxiv.org/abs/1706.03762        # 논문 가져오기, 저장, 그래프 업데이트
/graphify add https://x.com/karpathy/status/...       # 트윗 가져오기
/graphify add https://... --author "Name"             # 원저자 태그
/graphify add https://... --contributor "Name"        # 코퍼스에 추가한 사람 태그

/graphify query "어텐션과 옵티마이저를 연결하는 것은?"
/graphify query "어텐션과 옵티마이저를 연결하는 것은?" --dfs   # 특정 경로 추적
/graphify query "어텐션과 옵티마이저를 연결하는 것은?" --budget 1500  # N 토큰으로 제한
/graphify path "DigestAuth" "Response"
/graphify explain "SwinTransformer"

/graphify ./raw --watch            # 파일 변경 시 그래프 자동 동기화 (코드: 즉시, 문서: 알림)
/graphify ./raw --wiki             # 에이전트가 크롤 가능한 위키 빌드 (index.md + 커뮤니티별 문서)
/graphify ./raw --svg              # graph.svg 내보내기
/graphify ./raw --graphml          # graph.graphml 내보내기 (Gephi, yEd)
/graphify ./raw --neo4j            # Neo4j용 cypher.txt 생성
/graphify ./raw --neo4j-push bolt://localhost:7687    # 실행 중인 Neo4j 인스턴스에 직접 푸시
/graphify ./raw --mcp              # MCP stdio 서버 시작

# git 훅 - 플랫폼 무관, 커밋 및 브랜치 전환 시 그래프 재빌드
graphify hook install
graphify hook uninstall
graphify hook status

# 상시 작동 어시스턴트 지시 - 플랫폼별
graphify claude install            # CLAUDE.md + PreToolUse 훅 (Claude Code)
graphify claude uninstall
graphify codex install             # AGENTS.md (Codex)
graphify opencode install          # AGENTS.md (OpenCode)
graphify claw install              # AGENTS.md (OpenClaw)
graphify droid install             # AGENTS.md (Factory Droid)
graphify trae install              # AGENTS.md (Trae)
graphify trae uninstall
graphify trae-cn install           # AGENTS.md (Trae CN)
graphify trae-cn uninstall

# 터미널에서 직접 그래프 쿼리 (AI 어시스턴트 불필요)
graphify query "어텐션과 옵티마이저를 연결하는 것은?"
graphify query "인증 흐름 보기" --dfs
graphify query "CfgNode이 뭐지?" --budget 500
graphify query "..." --graph path/to/graph.json
```

다양한 파일 유형의 조합과 함께 동작합니다:

| 유형   | 확장자                                                                                                          | 추출 방식                                                                      |
| ------ | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 코드   | `.py .ts .js .jsx .tsx .go .rs .java .c .cpp .rb .cs .kt .scala .php .swift .lua .zig .ps1 .ex .exs .m .mm .jl` | tree-sitter AST + 콜 그래프 + docstring/주석 근거                              |
| 문서   | `.md .txt .rst`                                                                                                 | Claude를 통한 개념 + 관계 + 설계 근거                                          |
| 오피스 | `.docx .xlsx`                                                                                                   | 마크다운으로 변환 후 Claude를 통해 추출 (`pip install graphifyy[office]` 필요) |
| 논문   | `.pdf`                                                                                                          | 인용 마이닝 + 개념 추출                                                        |
| 이미지 | `.png .jpg .webp .gif`                                                                                          | Claude Vision - 스크린샷, 다이어그램, 모든 언어                                |

## 결과물

**갓 노드** - 최고 차수의 개념 (모든 것이 연결되는 허브)

**의외의 연결** - 복합 점수로 순위 지정. 코드-논문 엣지는 코드-코드보다 높게 순위됩니다. 각 결과에는 쉬운 설명이 포함됩니다.

**추천 질문** - 그래프가 고유하게 답할 수 있는 4~5개의 질문

**"이유"** - docstring, 인라인 주석(`# NOTE:`, `# IMPORTANT:`, `# HACK:`, `# WHY:`), 문서의 설계 근거가 `rationale_for` 노드로 추출됩니다. 코드가 무엇을 하는지뿐만 아니라 — 왜 그렇게 작성되었는지.

**신뢰도 점수** - 모든 INFERRED 엣지에는 `confidence_score`(0.0~1.0)가 있습니다. 무엇이 추측되었는지뿐 아니라 모델이 얼마나 확신했는지도 알 수 있습니다. EXTRACTED 엣지는 항상 1.0입니다.

**의미적 유사성 엣지** - 구조적 연결 없는 파일 간 개념 링크. 서로를 호출하지 않으면서 같은 문제를 해결하는 두 함수, 코드의 클래스와 같은 알고리즘을 설명하는 논문의 개념 등.

**하이퍼엣지** - 쌍별 엣지로는 표현할 수 없는 3개 이상 노드의 그룹 관계. 공유 프로토콜을 구현하는 모든 클래스, 인증 흐름의 모든 함수, 논문 섹션에서 하나의 아이디어를 구성하는 모든 개념 등.

**토큰 벤치마크** - 매 실행 후 자동으로 출력됩니다. 혼합 코퍼스(Karpathy 리포지토리 + 논문 + 이미지)에서: 원본 파일 대비 쿼리당 **71.5배** 적은 토큰. 첫 실행은 추출과 그래프 빌드를 수행합니다(토큰이 소비됩니다). 이후 모든 쿼리는 원본 파일 대신 압축된 그래프를 읽습니다 — 여기서 절약이 복리로 누적됩니다. SHA256 캐시로 재실행 시 변경된 파일만 재처리합니다.

**자동 동기화** (`--watch`) - 백그라운드 터미널에서 실행하면 코드베이스가 변경될 때 그래프가 자동으로 업데이트됩니다. 코드 파일 저장 시 즉시 재빌드가 트리거됩니다(AST만, LLM 없음). 문서/이미지 변경 시에는 LLM 재처리를 위해 `--update` 실행을 알려줍니다.

**Git 훅** (`graphify hook install`) - post-commit 및 post-checkout 훅을 설치합니다. 모든 커밋과 브랜치 전환 후 그래프가 자동으로 재빌드됩니다. 재빌드가 실패하면 훅이 0이 아닌 코드로 종료하여 git이 에러를 표시하고 조용히 계속 진행하지 않습니다. 백그라운드 프로세스가 필요 없습니다.

**위키** (`--wiki`) - 커뮤니티 및 갓 노드별 위키피디아 스타일 마크다운 문서와 `index.md` 진입점. 어떤 에이전트든 `index.md`를 가리키면 JSON을 파싱하는 대신 파일을 읽어서 지식 베이스를 탐색할 수 있습니다.

## 실전 예제

| 코퍼스                                      | 파일 수 | 축소율    | 결과                                               |
| ------------------------------------------- | ------- | --------- | -------------------------------------------------- |
| Karpathy 리포지토리 + 논문 5편 + 이미지 4장 | 52      | **71.5x** | [`worked/karpathy-repos/`](worked/karpathy-repos/) |
| graphify 소스 + Transformer 논문            | 4       | **5.4x**  | [`worked/mixed-corpus/`](worked/mixed-corpus/)     |
| httpx (합성 Python 라이브러리)              | 6       | ~1x       | [`worked/httpx/`](worked/httpx/)                   |

토큰 축소는 코퍼스 크기에 비례하여 확장됩니다. 6개 파일은 어차피 컨텍스트 윈도우에 들어가므로, 그래프의 가치는 압축이 아닌 구조적 명확성에 있습니다. 52개 파일(코드 + 논문 + 이미지)에서는 71배 이상을 달성합니다. 각 `worked/` 폴더에는 원본 입력 파일과 실제 출력(`GRAPH_REPORT.md`, `graph.json`)이 있어 직접 실행하여 수치를 검증할 수 있습니다.

## 개인정보 보호

graphify는 문서, 논문, 이미지의 의미적 추출을 위해 파일 내용을 AI 코딩 어시스턴트의 기반 모델 API로 전송합니다 — Anthropic(Claude Code), OpenAI(Codex), 또는 사용 중인 플랫폼의 제공자. 코드 파일은 tree-sitter AST를 통해 로컬에서 처리됩니다 — 코드의 경우 파일 내용이 사용자의 머신을 벗어나지 않습니다. 어떠한 텔레메트리, 사용 추적, 분석도 없습니다. 유일한 네트워크 호출은 추출 중 플랫폼 모델 API에 대한 것이며, 사용자 본인의 API 키를 사용합니다.

## 기술 스택

NetworkX + Leiden (graspologic) + tree-sitter + vis.js. 의미적 추출은 Claude(Claude Code), GPT-4(Codex), 또는 플랫폼이 실행하는 모델을 통해 수행됩니다. Neo4j 불필요, 서버 불필요, 완전히 로컬에서 실행됩니다.

**실전 예제**는 가장 신뢰를 쌓는 기여 방식입니다. 실제 코퍼스에서 `/graphify`를 실행하고, 결과를 `worked/{slug}/`에 저장하고, 그래프가 맞게 파악한 것과 틀린 것을 평가하는 솔직한 `review.md`를 작성하여 PR을 제출하세요.

**추출 버그** - 입력 파일, 캐시 엔트리(`graphify-out/cache/`), 그리고 누락되거나 날조된 내용과 함께 이슈를 열어주세요.

모듈 책임과 언어 추가 방법은 [ARCHITECTURE.md](ARCHITECTURE.md)를 참조하세요.

</details>
