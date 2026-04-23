# Contributing Guide

## 1. Branch Strategy

- 모든 작업은 Jira 이슈를 기준으로 브랜치를 생성한다.
- 브랜치 이름 규칙:

```

"[SCRUM-번호]-feature/간단한설명"
"[SCRUM-번호]-fix/간단한설명"

```

- 예시:
  - "[SCRUM-번호]-feature/login-api"
  - "[SCRUM-번호]-feature/crash-on-start"

---

## 2. Commit Convention

- 커밋 메시지는 아래 형식을 따른다:

```

타입: 메시지

```

- 타입 종류:
  - feat: 기능 추가
  - fix: 버그 수정
  - refactor: 코드 리팩토링
  - docs: 문서 수정

- 예시:
  - feat: 로그인 API 추가

---

## 3. Pull Request Rules

- PR 제목 규칙:

```

[SCRUM-번호] 작업 내용

```

- PR에는 반드시 포함:
- 작업 내용 요약
- 변경된 주요 파일
- 테스트 방법

- 최소 1명 이상의 코드 리뷰 승인 필요

---

## 4. Merge Strategy

- 모든 PR은 **Squash Merge**로 병합한다.
- 이유:
  - 커밋 히스토리 단순화
  - 이슈 단위로 기록 관리

---

## 5. Workflow

1. Jira에서 이슈 생성
2. 브랜치 생성
3. 작업 및 커밋
4. PR 생성
5. 코드 리뷰
6. Squash Merge

---

## 6. Do Not

- main 브랜치에 직접 push 금지
- Jira 이슈 없이 작업 금지
