# Git History - dev Branch

이 문서는 `origin/dev` 브랜치의 커밋 메시지, 작성자, 변경 범위를 기준으로 The Truth Filtering Engine 서비스가 어떻게 발전했는지 정리한 기록입니다.

## 검토 기준

- 기준 브랜치: `origin/dev`
- 기준 커밋: `5adbc9e`
- 확인 일자: 2026-06-30
- 작성자 기준: Git commit author name (`%an`)을 기반으로 하되, 사용자 확인에 따라 최현석 (`CHOI HYUN SEOK`, `Choi Hyunseok`, `testwelltest01`), 정서영 (`7101lemontea-rgb`, `lemon`), 강주영 (`capt2fact-cyber`), 최대산 (`DSanyC`) 등으로 정규화
- 확인 명령:
  - `git fetch --all --prune`
  - `git log --reverse --format='%h %ad %an %s' --date=short origin/dev`
  - `git log --first-parent --reverse --format=... origin/dev`
  - `git show --name-only <commit>`
  - `git show --shortstat <commit>`
- 전체 reachable 커밋 수: 147개
- first-parent 기준 dev mainline 커밋 수: 128개

`origin/dev`에서 도달 가능한 전체 커밋을 모두 확인했습니다. merge commit으로 dev에 들어온 side-branch 내부 커밋도 전체 reachable 기준 표에 포함했습니다. `Author`는 정규화된 작성자 이름이며, 원본 Git author 별칭은 아래 작성자 정규화 기준에 따릅니다. `Scope`는 변경 파일의 상위 경로 요약이고, `Diff`는 해당 커밋의 shortstat입니다.

## 작성자 정규화 기준

| 정규화 작성자 | Git author name |
| --- | --- |
| 최현석 (choihyunseok) | CHOI HYUN SEOK, Choi Hyunseok, testwelltest01 |
| 정서영 (7101lemontea-rgb) | 7101lemontea-rgb, lemon |
| 강주영 (capt2fact-cyber) | capt2fact-cyber |
| 최대산 (DSanyC) | DSanyC |

## 작성자별 요약

| Author | Commits | Main touched areas |
| --- | ---: | --- |
| 최현석 (choihyunseok) | 72 | the_truth_filtering_engine, web, backend, .gitignore, flutter, README.md |
| 정서영 (7101lemontea-rgb) | 28 | the_truth_filtering_engine, backend, crawling_naver_api, web, flutter, 1st.md |
| 강주영 (capt2fact-cyber) | 23 | the_truth_filtering_engine, backend, supabase, lib, juyeong.py, design_system.md |
| 최대산 (DSanyC) | 21 | backend, web, the_truth_filtering_engine, .gitignore, crawling_naver_api, test_ds.md |
| Tester | 3 | the_truth_filtering_engine |

## 전체 발전 요약

이 서비스는 저장소와 Flutter 실험 프로젝트로 출발했고, 지도 기반 맛집 탐색 앱, FastAPI 백엔드, Naver Blog 리뷰 수집, Supabase 저장, BERT/ELECTRA 계열 모델 추론, React 웹 클라이언트, 사용자 계정/북마크/최근기록/리뷰 피드백, SSE 스트리밍 분석까지 단계적으로 확장되었습니다.

| 기간 | 발전 내용 |
| --- | --- |
| 2026-04-22 ~ 2026-04-23 | 저장소 초기화, 협업 테스트, Naver API/크롤링 실험, 와이어프레임 자료가 추가되었습니다. |
| 2026-04-24 ~ 2026-04-26 | Flutter 앱 골격, 지도 화면, 가게 목록/상세 UI, 초기 디자인 시스템, 프로젝트 구조 리팩토링이 진행되었습니다. |
| 2026-04-27 ~ 2026-04-30 | Kakao/Naver 지도 연동, FastAPI 백엔드, LLM/ELECTRA/Supabase 분석 흐름, 리뷰 상세/워드클라우드/북마크 UX가 들어왔습니다. |
| 2026-05-01 ~ 2026-05-08 | React 웹 클라이언트, 원격 백엔드 연결, 로그인/인증, 검색/북마크/상세 분석, Flutter Google 로그인과 설정 탭, 사용자 피드백 기능이 확장되었습니다. |
| 2026-05-09 ~ 2026-05-14 | Naver 검색 쿼리, 앱·웹 디자인 시스템, AI 추천, SSE 스트리밍, 무료 분석/사용량 차감, 웹 리팩토링과 리뷰 신고 기능이 정리되었습니다. |
| 2026-05-16 ~ 2026-06-04 | 웹 첫 화면, SEO/Google 크롤링 설정, 포트폴리오 페이지 연결, 서버 endpoint 이전, README 정리가 반영되었습니다. |

## 최현석 (choihyunseok) 기여 요약

사용자 확인에 따라 `CHOI HYUN SEOK`, `Choi Hyunseok`, `testwelltest01` 커밋을 모두 최현석(choihyunseok) 기여로 묶었습니다. 이 기준에서 총 72개 커밋이 최현석 기여로 집계됩니다.

| 영역 | 주요 기여 | 관련 커밋 예시 |
| --- | --- | --- |
| React 웹 | Vite 기반 웹 초기 구축, 검색/지도/상세/북마크/AI 추천/피드백/로그인 화면, 포트폴리오 링크와 SEO 설정 | `6b7bac2`, `ca735e1`, `e4d8b77`, `387b8d5`, `c6637b9`, `b8b06b8` |
| Flutter 앱 | 지도/상세 흐름 보강, 원격 백엔드 연결, Google 로그인(web/iOS/Android), 설정 탭의 로그아웃·코인·프리미엄 상태, 테스트 실행 스크립트 | `7779f27`, `1b5d2a6`, `b226976`, `6dce7b3`, `f252abe` |
| 백엔드·API 연동 | 장소/리뷰/사용자 상태 API와 웹·앱 모델 동기화, 사용량 차감 반영, Cloudflare/Vercel endpoint 조정 | `a209e9d`, `dd5b30e`, `297f891`, `52024c5` |
| 지도·리뷰 UX | Kakao Map 오류 수정, 검색 결과 선택 후 지도 재진입, 로딩 순서, 북마크/최근 기록/리뷰 신고 흐름 개선 | `af3d0c4`, `6df2c6c`, `615bf4c`, `43410f9`, `ef15073` |
| 협업·정리 | 초기 협업 테스트, merge 정리, README 및 프로젝트 문서 정리 | `2c5dd50`, `fb21336`, `35b730e`, `5adbc9e` |

## 커밋별 상세

| # | Date | Author | Commit | Message | Scope | Diff | 발전 내용 |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2026-04-22 | 최현석 (choihyunseok) | `f5861e0` | Initial commit | README.md | 1 file changed, 1 insertion(+) | 저장소 첫 README를 만들었다. |
| 2 | 2026-04-22 | 정서영 (7101lemontea-rgb) | `1422d56` | Test commit - Seo Young | 1st.md | 1 file changed, 1 insertion(+) | 팀원 초기 커밋 테스트를 진행했다. |
| 3 | 2026-04-22 | 강주영 (capt2fact-cyber) | `8ce1f6b` | 첫 커밋 (#1) | juyeong.py | 1 file changed, 0 insertions(+), 0 deletions(-) | 기능 구현 또는 프로젝트 구조를 보강했다. |
| 4 | 2026-04-22 | 최현석 (choihyunseok) | `2c5dd50` | [SCRUM-13] Choihyunseok 첫 푸시 (#2) | pull_request_template.md, test_choihyunseok.md | 2 files changed, 18 insertions(+) | 브랜치/PR 기반 협업 흐름을 테스트했다. |
| 5 | 2026-04-22 | 정서영 (7101lemontea-rgb) | `f818711` | [SCRUM-11] Test branch 01 (#4) | 1st.md | 1 file changed, 2 insertions(+), 1 deletion(-) | 기능 구현 또는 프로젝트 구조를 보강했다. |
| 6 | 2026-04-22 | 최대산 (DSanyC) | `a3e61bb` | [SCRUM-12] DS (#3) | test_ds.md | 1 file changed, 1 insertion(+) | 기능 구현 또는 프로젝트 구조를 보강했다. |
| 7 | 2026-04-23 | 정서영 (7101lemontea-rgb) | `9437b9b` | [Scrum-20] feature/naver-api-test (#6) | crawling_playwright, crawling_naver_api, .gitignore, 1st.md, CONTRIBUTING.md, juyeong.py | 16 files changed, 925 insertions(+), 5 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 8 | 2026-04-23 | 최현석 (choihyunseok) | `fb21336` | 기본세팅 | .agents, docs, .claude, .codex, .gitignore, 1st.md | 12 files changed, 693 insertions(+), 6 deletions(-) | 기능 구현 또는 프로젝트 구조를 보강했다. |
| 9 | 2026-04-23 | 최현석 (choihyunseok) | `3a9ade0` | Merge branch 'dev' of https://github.com/The-Truth-Filtering-Engine/The-Truth-Filtering-Engine into dev | .gitignore | 12 files changed, 925 insertions(+) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 10 | 2026-04-23 | 최현석 (choihyunseok) | `13bcf62` | 기본세팅 | CONTRIBUTING.md | 1 file changed, 84 deletions(-) | 기능 구현 또는 프로젝트 구조를 보강했다. |
| 11 | 2026-04-23 | 정서영 (7101lemontea-rgb) | `c892743` | design: 프로젝트 1차 화면 설계(Wireframing) (#7) | assets | 1 file changed, 0 insertions(+), 0 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 12 | 2026-04-23 | 최현석 (choihyunseok) | `c9f4024` | Merge branch 'dev' of https://github.com/The-Truth-Filtering-Engine/The-Truth-Filtering-Engine into dev | - | 1 file changed, 0 insertions(+), 0 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 13 | 2026-04-23 | 최현석 (choihyunseok) | `3c3f8ee` | 기본세팅 | .env, .env.example, .python-version, README.md | 4 files changed, 8 insertions(+) | 기능 구현 또는 프로젝트 구조를 보강했다. |
| 14 | 2026-04-23 | 최현석 (choihyunseok) | `e8c97c3` | flutter 환경설정 | .gitignore, flutter | 2 files changed, 5 insertions(+), 3 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 15 | 2026-04-24 | 정서영 (7101lemontea-rgb) | `9bd2c15` | [SCRUM-28] feat: Flutter 프로젝트 생성 시도 (#8) | the_truth_filtering_engine, .agents, .claude, .codex, .gitignore, README.md | 153 files changed, 4970 insertions(+), 62 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 16 | 2026-04-24 | 정서영 (7101lemontea-rgb) | `beba58d` | [SCRUM-29] feature/main UI 01 (#9) | the_truth_filtering_engine | 10 files changed, 873 insertions(+) | AI 추천 기능을 웹/앱에 반영했다. |
| 17 | 2026-04-24 | 강주영 (capt2fact-cyber) | `68aeca6` | [SCRUM-16] 디자인 시스템 .md (#10) | lib, design_system.md, pubspec.lock, pubspec.yaml | 10 files changed, 1971 insertions(+) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 18 | 2026-04-24 | 강주영 (capt2fact-cyber) | `0fcc62b` | fix: merge를 위한 프로젝트 파일 구조 수정 | the_truth_filtering_engine, lib | 8 files changed, 4 insertions(+), 381 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 19 | 2026-04-24 | 정서영 (7101lemontea-rgb) | `31a379f` | [SCRUM-31] fix: Git 충돌 오류 해결 (#11) | crawling_playwright, crawling_naver_api, the_truth_filtering_engine, pubspec.yaml | 199 files changed, 19192 insertions(+), 571 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 20 | 2026-04-24 | 강주영 (capt2fact-cyber) | `69d4d0a` | refactor: 프로젝트 폴더구조 리팩토링 | the_truth_filtering_engine | 58 files changed, 19 insertions(+), 8 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 21 | 2026-04-24 | 최현석 (choihyunseok) | `bc18647` | Merge remote-tracking branch 'origin/SCRUM-33-Project-File-Structure-Refactoring' into dev | the_truth_filtering_engine | 58 files changed, 36 insertions(+), 288 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 22 | 2026-04-24 | 최현석 (choihyunseok) | `d6a6339` | merge 수정 | the_truth_filtering_engine | 42 files changed, 310 insertions(+), 25 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 23 | 2026-04-24 | 최현석 (choihyunseok) | `efe9b00` | fix: import 경로 수정 | the_truth_filtering_engine | 4 files changed, 7 insertions(+), 7 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 24 | 2026-04-25 | 강주영 (capt2fact-cyber) | `8e693fb` | [SCRUM-37] UI Flow 통합 및 가게 상세 화면 구현 (#13) | the_truth_filtering_engine | 12 files changed, 775 insertions(+), 158 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 25 | 2026-04-25 | 정서영 (7101lemontea-rgb) | `60a9c83` | [SCRUM-38] feature/Fast API 및 Flutter 연동 (#14) | backend, the_truth_filtering_engine | 19 files changed, 429 insertions(+), 154 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 26 | 2026-04-26 | 강주영 (capt2fact-cyber) | `ce36fa2` | [Scrum-40] store list UI 추가 완료 + API 오류 발생 (해결 전) (#15) | the_truth_filtering_engine | 23 files changed, 826 insertions(+), 79 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 27 | 2026-04-26 | 최대산 (DSanyC) | `38d7f76` | chore: add large file paths to .gitignore (#16) | backend, .gitignore, the_truth_filtering_engine | 16 files changed, 118 insertions(+), 4 deletions(-) | 추적 제외/환경 파일 등 운영성 정리를 진행했다. |
| 28 | 2026-04-27 | 최현석 (choihyunseok) | `af3d0c4` | [Scrum-41] kakao map api error (#17) | the_truth_filtering_engine, .gitignore, backend | 6 files changed, 358 insertions(+), 101 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 29 | 2026-04-27 | 최현석 (choihyunseok) | `78ef4bb` | Scrum 41 kakao map api error (#18) | the_truth_filtering_engine | 7 files changed, 683 insertions(+), 124 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 30 | 2026-04-27 | 정서영 (7101lemontea-rgb) | `ac45e92` | [SCRUM-47] feature: 앱 헤더 UI 수정 (#20) | the_truth_filtering_engine | 10 files changed, 133 insertions(+), 139 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 31 | 2026-04-27 | 강주영 (capt2fact-cyber) | `aaf2108` | SCRUM-42 fix: original_blog_post (#19) | the_truth_filtering_engine | 2 files changed, 7 insertions(+), 242 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 32 | 2026-04-27 | 정서영 (7101lemontea-rgb) | `a714f6f` | [Scrum-49] feature/naver maps api integration (#21) | the_truth_filtering_engine, backend | 8 files changed, 208 insertions(+), 167 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 33 | 2026-04-27 | 정서영 (7101lemontea-rgb) | `0e8af35` | [SCRUM-50] feature: 상세 버튼 - LLM / Supabase 연동 (#22) | backend, the_truth_filtering_engine | 9 files changed, 149516 insertions(+), 91 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 34 | 2026-04-27 | 정서영 (7101lemontea-rgb) | `25a1439` | [SCRUM-51] feature: 분석하기 버튼 - Electra / Supabase 연동 (#23) | backend, the_truth_filtering_engine | 6 files changed, 250 insertions(+), 14 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 35 | 2026-04-27 | 강주영 (capt2fact-cyber) | `197f1ff` | fix: restaurant display 수정 (#24) | the_truth_filtering_engine | 2 files changed, 18 insertions(+), 18 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 36 | 2026-04-28 | 정서영 (7101lemontea-rgb) | `ab18ecb` | [Scrum-54] feature: model-llm-settings (#25) | backend, the_truth_filtering_engine | 22 files changed, 303618 insertions(+), 103 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 37 | 2026-04-28 | 정서영 (7101lemontea-rgb) | `154f759` | [SCRUM-55] feature: 리뷰 상세 화면 워드 클라우드 구현 및 리뷰 페이지 통합 (#26) | the_truth_filtering_engine, backend | 9 files changed, 1138 insertions(+), 376 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 38 | 2026-04-28 | 최현석 (choihyunseok) | `6df2c6c` | Scrum 52 kakao map (#27) | the_truth_filtering_engine, backend | 13 files changed, 1497 insertions(+), 398 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 39 | 2026-04-28 | 최대산 (DSanyC) | `93d3693` | SCRUM-56-fix/convert-binary-output-to-score (#28) | backend, the_truth_filtering_engine | 7 files changed, 51 insertions(+), 10 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 40 | 2026-04-28 | 강주영 (capt2fact-cyber) | `7da8a5d` | feat: update dependencies and map configuration | the_truth_filtering_engine, backend | 4 files changed, 50 insertions(+), 27 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 41 | 2026-04-28 | 강주영 (capt2fact-cyber) | `ca82580` | chore: resolve merge conflicts and update map configuration | - | 7 files changed, 52 insertions(+), 7 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 42 | 2026-04-28 | 최현석 (choihyunseok) | `ac6ad53` | [Scrum-58] 전체적 UI 수정 및 북마크의 로컬 저장 기능 추가 (#29) | the_truth_filtering_engine, backend | 12 files changed, 366 insertions(+), 123 deletions(-) | 북마크 저장과 지도 재진입 흐름을 개선했다. |
| 43 | 2026-04-28 | 정서영 (7101lemontea-rgb) | `f56aa13` | [SCRUM-57] feature: 카카오 API의 음식점 분류에 따른 헤더 및 썸네일 이미지 구현 | the_truth_filtering_engine, backend | 40 files changed, 115 insertions(+), 76 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 44 | 2026-04-28 | 최현석 (choihyunseok) | `0006dc7` | Merge remote-tracking branch 'origin/SCRUM-57-feature-header-thumbnails-image' into dev | the_truth_filtering_engine | 38 files changed, 107 insertions(+), 114 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 45 | 2026-04-28 | 최현석 (choihyunseok) | `8c412f8` | fix: 머지 수정 | the_truth_filtering_engine | 2 files changed, 48 insertions(+), 5 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 46 | 2026-04-28 | 최현석 (choihyunseok) | `9791532` | fix: 서버 ip를 localhost로 변경 | the_truth_filtering_engine | 2 files changed, 3 insertions(+), 4 deletions(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 47 | 2026-04-28 | 최현석 (choihyunseok) | `9f6f223` | feat: AI기능 추가 (#31) | the_truth_filtering_engine, backend | 11 files changed, 840 insertions(+), 40 deletions(-) | AI 추천 기능을 웹/앱에 반영했다. |
| 48 | 2026-04-28 | 정서영 (7101lemontea-rgb) | `d50f135` | [SCRUM-61] feature: 리뷰 상세 페이지 상중하 구현(모델/LLM) | the_truth_filtering_engine, backend | 6 files changed, 336 insertions(+), 102 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 49 | 2026-04-28 | 최현석 (choihyunseok) | `08e4bee` | chore: ignore 대상 파일 추적 해제 | backend, crawling_naver_api, crawling_playwright, the_truth_filtering_engine | 17 files changed, 3 deletions(-) | 추적 제외/환경 파일 등 운영성 정리를 진행했다. |
| 50 | 2026-04-28 | 최현석 (choihyunseok) | `a8cbe71` | Merge remote-tracking branch 'origin/SCRUM-61-feature-color-list' into dev | backend | 23 files changed, 336 insertions(+), 105 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 51 | 2026-04-28 | Tester | `7a5758e` | UI-1-feat:restore pointer cursor on map control buttons using pointer_interceptor | the_truth_filtering_engine | 5 files changed, 113 insertions(+), 38 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 52 | 2026-04-29 | 최대산 (DSanyC) | `cb95e8b` | UI-1-feat:restore pointer cursor on map control buttons using pointer_interceptor (#33) | the_truth_filtering_engine | 5 files changed, 113 insertions(+), 38 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 53 | 2026-04-29 | 정서영 (7101lemontea-rgb) | `ffffd64` | [SCRUM-63] feature: 워드 클라우드 및 UI 개선 (#34) | the_truth_filtering_engine | 4 files changed, 223 insertions(+), 181 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 54 | 2026-04-29 | 최현석 (choihyunseok) | `15bb7ee` | fix: 북마크 페이지에서 가게 이름 누르면, 가게 상세페이지가 보이는게 아니라 지도에서 보일 수 있도록 수정 (#35) | the_truth_filtering_engine | 2 files changed, 9 insertions(+), 11 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 55 | 2026-04-29 | 정서영 (7101lemontea-rgb) | `050c6da` | [SCRUM-68] feature: 상세보기 클릭시 분석 진행 / LLM 판별 기준 변경 (#36) | the_truth_filtering_engine, backend | 3 files changed, 70 insertions(+), 36 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 56 | 2026-04-29 | 최현석 (choihyunseok) | `802826f` | fix: 카카오맵 로딩 왼쪽 위만 되는게 아니라 전부 다 될 수 있도록 로딩 순서 바꿈, (#37) | the_truth_filtering_engine | 1 file changed, 10 insertions(+), 4 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 57 | 2026-04-29 | 최현석 (choihyunseok) | `615bf4c` | fix: 검색 결과 리스트에서 가게 클릭시 지도 화면에서 볼 수 있도록 변경 (#38) | the_truth_filtering_engine | 2 files changed, 22 insertions(+), 15 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 58 | 2026-04-29 | Tester | `c107975` | Merge branch 'dev' of https://github.com/The-Truth-Filtering-Engine/The-Truth-Filtering-Engine into dev | - | 39 files changed, 1465 insertions(+), 347 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 59 | 2026-04-29 | 최대산 (DSanyC) | `066b965` | feat: add Colab model training code (#40) | backend | 8 files changed, 28606 insertions(+) | AI 추천 기능을 웹/앱에 반영했다. |
| 60 | 2026-04-29 | 강주영 (capt2fact-cyber) | `59737e7` | Docs/ final documentation  프로젝트 작업 내역 / 보고서 프레임워크 (#41) | PROJECT_HISTORY.md, PROJECT_REPORT_GUIDE.md | 2 files changed, 153 insertions(+) | 프로젝트 문서와 보고 자료를 정리했다. |
| 61 | 2026-04-30 | 최현석 (choihyunseok) | `b4fc8e8` | feat: 가게 상세 페이지에서 하단 Main tab 추가, 상단 앱바의 아이콘 삭제 (#42) | the_truth_filtering_engine, .claude | 3 files changed, 55 insertions(+), 19 deletions(-) | AI 추천 기능을 웹/앱에 반영했다. |
| 62 | 2026-04-30 | 최현석 (choihyunseok) | `85b742c` | feat:  AiRecommendScreen 에 있는 멘트 수정 | the_truth_filtering_engine | 1 file changed, 1 insertion(+), 1 deletion(-) | AI 추천 기능을 웹/앱에 반영했다. |
| 63 | 2026-04-30 | 강주영 (capt2fact-cyber) | `be55c13` | feat: enable Kakao Map SDK on mobile (카카오 지도 모바일 지원) (#43) | the_truth_filtering_engine, backend, main.bat, main.ps1 | 7 files changed, 556 insertions(+), 39 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 64 | 2026-05-04 | Tester | `1b6584b` | test-1 | the_truth_filtering_engine | 1 file changed, 3 insertions(+), 22 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 65 | 2026-05-04 | 강주영 (capt2fact-cyber) | `d587177` | feat: implement ReviewListSection with tabbed sorting and skeleton loaders (#44) | the_truth_filtering_engine | 1 file changed, 3 insertions(+), 1 deletion(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 66 | 2026-05-04 | 정서영 (7101lemontea-rgb) | `7cdcd87` | [SCRUM-79] feat: BERT 모델 재학습 (#46) | backend | 4 files changed, 932 insertions(+) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 67 | 2026-05-05 | 최현석 (choihyunseok) | `6b7bac2` | [SCRUM-75] react로 웹사이트 생성 및 전체 구성. (#48) | web, backend, .gitignore, .vercelignore, vercel.json | 19 files changed, 5801 insertions(+), 16 deletions(-) | React 웹 클라이언트 기능 또는 UI를 확장했다. |
| 68 | 2026-05-06 | 최현석 (choihyunseok) | `229cf6a` | feat: cloudflare임시주소 수정 | 2026-04-27.md, 2026-04-28.md, 2026-04-29.md, 2026-04-30.md, 2026-05-01.md, web | 6 files changed, 146 insertions(+), 1 deletion(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 69 | 2026-05-06 | 강주영 (capt2fact-cyber) | `57c74e0` | [SCRUM-76] design/UI-login (#47) | the_truth_filtering_engine | 9 files changed, 648 insertions(+), 42 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 70 | 2026-05-06 | 강주영 (capt2fact-cyber) | `074a1b3` | SCRUM-82 feat: prepare ios build (#45) | - | - | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 71 | 2026-05-06 | 강주영 (capt2fact-cyber) | `5982fbe` | feat: 리뷰 신고, 피드백 시스템 구현 및 Supabase 스키마 업데이트 | the_truth_filtering_engine, backend, supabase | 5 files changed, 1479 insertions(+) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 72 | 2026-05-06 | 강주영 (capt2fact-cyber) | `30a6856` | Merge branch 'dev' of https://github.com/The-Truth-Filtering-Engine/The-Truth-Filtering-Engine into dev | - | 9 files changed, 648 insertions(+), 42 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 73 | 2026-05-06 | 최현석 (choihyunseok) | `7779f27` | SCRUM-94 chore: point Flutter app to remote backend (#49) | the_truth_filtering_engine | 7 files changed, 69 insertions(+), 37 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 74 | 2026-05-06 | 강주영 (capt2fact-cyber) | `d4c607b` | SCRUM-87 사용자 피드백 시스템 (#50) | the_truth_filtering_engine, backend | 3 files changed, 258 insertions(+), 144 deletions(-) | 리뷰 신고와 사용자 피드백 기능을 추가했다. |
| 75 | 2026-05-06 | 최현석 (choihyunseok) | `d5e5691` | fix: 주영님이 1줄 고장낸거 고침. 그리고 관리자 로그인 버튼 생성 | the_truth_filtering_engine | 2 files changed, 23 insertions(+), 1 deletion(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 76 | 2026-05-06 | 정서영 (7101lemontea-rgb) | `29f34e5` | [SCRUM-89] feature: 리뷰 제목 포함한 모델 학습 및 벤치마크 테스트 (#51) | backend | 5 files changed, 25814 insertions(+) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 77 | 2026-05-07 | 최현석 (choihyunseok) | `ca735e1` | feat: react 웹 검색 기능 추가 (#52) | web, backend | 3 files changed, 707 insertions(+), 61 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 78 | 2026-05-07 | 최현석 (choihyunseok) | `28ff40e` | feat: react WEB UI 개선: 패널 1/3 지도 2/3 , 그리고 세로모드 (#55) | web | 2 files changed, 68 insertions(+), 48 deletions(-) | 지도 SDK/API와 장소 탐색 UX를 개선했다. |
| 79 | 2026-05-07 | 최현석 (choihyunseok) | `f287582` | fix: WEB 에서 AI추천기능에서 현재 위치 못잡는 버그 수정 (#56) | backend | 2 files changed, 10 insertions(+), 8 deletions(-) | AI 추천 기능을 웹/앱에 반영했다. |
| 80 | 2026-05-07 | 최현석 (choihyunseok) | `e4d8b77` | feat: web에서로그인 화면 생성 (#57) | web | 5 files changed, 375 insertions(+), 6 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 81 | 2026-05-07 | 강주영 (capt2fact-cyber) | `8017d09` | fix: flutter(web) 상세보기 페이지 오류 수정, supabase에서 보내는 데이터 형식에 맞춰서 flutter에서 받을 수 있도록 수정 (#58) | the_truth_filtering_engine, backend | 5 files changed, 142 insertions(+), 68 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 82 | 2026-05-07 | 강주영 (capt2fact-cyber) | `ab57d3c` | Scrum 101 store detail pagination (#59) | backend, the_truth_filtering_engine, web | 9 files changed, 959 insertions(+), 97 deletions(-) | AI 추천 기능을 웹/앱에 반영했다. |
| 83 | 2026-05-07 | 최현석 (choihyunseok) | `a209e9d` | feat: extend backend and frontend models to support comprehensive store and place metadata synchronization (#60) | backend, web | 5 files changed, 337 insertions(+), 94 deletions(-) | 백엔드 API와 서비스 연동 계층을 보강했다. |
| 84 | 2026-05-07 | 최현석 (choihyunseok) | `dd5b30e` | fix: 실수로 cloudflare server 터미널 종료로 주소 변경 | the_truth_filtering_engine, web | 2 files changed, 2 insertions(+), 2 deletions(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 85 | 2026-05-07 | 최현석 (choihyunseok) | `2a0712f` | fix: flutter에서도 extend backend and frontend models to support comprehensive store and place metadata synchronization (#60) | the_truth_filtering_engine | 5 files changed, 122 insertions(+), 24 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 86 | 2026-05-07 | 최현석 (choihyunseok) | `1b5d2a6` | feat: flutter에서 google login(web, ios, android) - supabase 연동 | the_truth_filtering_engine | 12 files changed, 331 insertions(+), 403 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 87 | 2026-05-08 | 최현석 (choihyunseok) | `b226976` | test: flutter용 테스트 실행파일 | the_truth_filtering_engine, .gitignore | 5 files changed, 68 insertions(+), 1 deletion(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 88 | 2026-05-08 | 최현석 (choihyunseok) | `6dce7b3` | feat: 설정탭(flutter,ios,android)에서 로그아웃,코인,프리미엄 기능 추가 및 supabase 연동 | backend, web, the_truth_filtering_engine | 6 files changed, 1337 insertions(+), 21 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 89 | 2026-05-08 | 강주영 (capt2fact-cyber) | `69d8695` | chore: flutter native용 gitignore 설정 수정 | the_truth_filtering_engine | 3 files changed, 7 insertions(+) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 90 | 2026-05-08 | 최대산 (DSanyC) | `dff21f3` | 아 뭐여 커밋 메시지를 안섯잖아 | the_truth_filtering_engine, web | 2 files changed, 2 insertions(+), 2 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 91 | 2026-05-08 | 최현석 (choihyunseok) | `43410f9` | fix: 북마크 기능 수정(로컬 -> 아이디 기반) (#61) | the_truth_filtering_engine, backend, web | 7 files changed, 784 insertions(+), 48 deletions(-) | 북마크 저장과 지도 재진입 흐름을 개선했다. |
| 92 | 2026-05-08 | 최현석 (choihyunseok) | `4cf666c` | Scrum 103 1 bookmark (#62) | backend, the_truth_filtering_engine, web | 5 files changed, 449 insertions(+), 156 deletions(-) | 북마크 저장과 지도 재진입 흐름을 개선했다. |
| 93 | 2026-05-08 | 최대산 (DSanyC) | `adcf02d` | 여러가지 작업-1 (#63) | backend | 12 files changed, 12 insertions(+), 228026 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 94 | 2026-05-08 | 최현석 (choihyunseok) | `b32392d` | [Scrum-103] bookmark, 상세보기 버튼에 포인트 차감 표기 (#64) | the_truth_filtering_engine, backend, web | 9 files changed, 609 insertions(+), 172 deletions(-) | 북마크 저장과 지도 재진입 흐름을 개선했다. |
| 95 | 2026-05-08 | 최대산 (DSanyC) | `c819503` | 여러가지 작업-1 (#65) | backend | 3 files changed, 171 insertions(+), 76 deletions(-) | 백엔드 API와 서비스 연동 계층을 보강했다. |
| 96 | 2026-05-08 | 최현석 (choihyunseok) | `e445e97` | SCRUM-87 사용자 피드백 시스템 (#66) | the_truth_filtering_engine | 14 files changed, 885 insertions(+), 76 deletions(-) | 리뷰 신고와 사용자 피드백 기능을 추가했다. |
| 97 | 2026-05-08 | 최대산 (DSanyC) | `9e61adc` | 여러가지 작업-2 (#67) | backend | 2 files changed, 21 insertions(+), 12 deletions(-) | 백엔드 API와 서비스 연동 계층을 보강했다. |
| 98 | 2026-05-08 | 최대산 (DSanyC) | `9711261` | 추론 속도 최적화 (#69) | backend | 4 files changed, 17 insertions(+), 15 deletions(-) | 백엔드 API와 서비스 연동 계층을 보강했다. |
| 99 | 2026-05-08 | 최현석 (choihyunseok) | `e5f7a91` | feat: 최근 가게 탭 추가(web, flutter) (#70) | the_truth_filtering_engine, backend, web | 8 files changed, 1227 insertions(+), 3 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 100 | 2026-05-08 | 최현석 (choihyunseok) | `49d7330` | SCRUM-81 좋아요 싫어요 계정 저장 추가 (#71) | the_truth_filtering_engine, backend, supabase | 10 files changed, 778 insertions(+), 75 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 101 | 2026-05-09 | 최대산 (DSanyC) | `d88129c` | Supabase 백그라운드 저장 적용 (#72) | backend | 1 file changed, 23 insertions(+), 10 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 102 | 2026-05-11 | 최현석 (choihyunseok) | `1428cff` | fix: naver blog api 검색 쿼리 수정 (#74) | backend | 2 files changed, 139 insertions(+), 3 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 103 | 2026-05-11 | 최현석 (choihyunseok) | `be3fccc` | fix: design system 앱, 웹 수정 및 적용 (#76) | the_truth_filtering_engine, web, DESIGN_SYSTEM.md, design-tokens | 36 files changed, 2552 insertions(+), 1279 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 104 | 2026-05-11 | 최현석 (choihyunseok) | `d8cba1d` | fix: naver blog api 검색 쿼리 수정2 | backend | 3 files changed, 328 insertions(+), 30 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 105 | 2026-05-11 | 최현석 (choihyunseok) | `789c967` | feat: web-블로그리뷰-원문보기 클릭안됌. | web | 2 files changed, 54 insertions(+), 43 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 106 | 2026-05-11 | 최현석 (choihyunseok) | `a77ee1e` | fix: naver blog api 검색 쿼리 수정3 | backend | 2 files changed, 42 insertions(+), 4 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 107 | 2026-05-11 | 최현석 (choihyunseok) | `5bd8775` | feat: web에도 flutter처럼 대분류별 사진 추가 | web | 18 files changed, 170 insertions(+), 25 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 108 | 2026-05-11 | 최현석 (choihyunseok) | `074e2b0` | feat: AI 추천기능 수정(웹/플루터) (#77) | backend, the_truth_filtering_engine, web | 8 files changed, 567 insertions(+), 49 deletions(-) | AI 추천 기능을 웹/앱에 반영했다. |
| 109 | 2026-05-12 | 최대산 (DSanyC) | `8c20c7c` | supabase 중복 데이터 업로드 로직 수정. (#78) | backend | 1 file changed, 7 insertions(+), 1 deletion(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 110 | 2026-05-12 | 정서영 (7101lemontea-rgb) | `e2c45dd` | [SCRUM-100] 데이터 라벨링 (#82) | crawling_naver_api | 128 files changed, 22394 insertions(+), 1 deletion(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 111 | 2026-05-12 | 최대산 (DSanyC) | `40f7c86` | Scrum 117/refactoring backend folder (#84) | crawling_playwright, crawling_naver_api, backend, supabase, .gitignore, .vercelignore | 215 files changed, 18 insertions(+), 97933 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 112 | 2026-05-12 | 정서영 (7101lemontea-rgb) | `9a03571` | [SCRUM-98] feature: 모델 백엔드 적용 및 연동 (#85) | backend | 9 files changed, 68089 insertions(+), 157470 deletions(-) | 백엔드 API와 서비스 연동 계층을 보강했다. |
| 113 | 2026-05-12 | 최대산 (DSanyC) | `4d5ac5c` | 샤갈_서버가_켜졋어요 (#86) | crawling_naver_api, backend | 128 files changed, 1 insertion(+), 22395 deletions(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 114 | 2026-05-12 | 최대산 (DSanyC) | `c8bf454` | 스트리밍 코드로 수정 (#88) | backend, web | 4 files changed, 196 insertions(+), 39 deletions(-) | 분석 결과 스트리밍과 사용량 반영 흐름을 보강했다. |
| 115 | 2026-05-12 | 최현석 (choihyunseok) | `80b3613` | SSE에 맞게 코드 수정 (#89) | backend, web | 2 files changed, 63 insertions(+), 32 deletions(-) | 분석 결과 스트리밍과 사용량 반영 흐름을 보강했다. |
| 116 | 2026-05-12 | 정서영 (7101lemontea-rgb) | `bd904b8` | [SCRUM-88] feature: 캐시 로직 수정 (#87) | backend | 1 file changed, 10 insertions(+) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 117 | 2026-05-12 | 정서영 (7101lemontea-rgb) | `74e4d63` | [SCRUM-123] feature: App.tsx 리팩토링, 스트리밍 코드 반영 (#90) | web | 22 files changed, 3852 insertions(+), 3581 deletions(-) | 분석 결과 스트리밍과 사용량 반영 흐름을 보강했다. |
| 118 | 2026-05-12 | 최현석 (choihyunseok) | `fc001e7` | 웹 리팩토링 오류 수정 (#91) | web | 5 files changed, 5 insertions(+), 6 deletions(-) | React 웹 클라이언트 기능 또는 UI를 확장했다. |
| 119 | 2026-05-12 | 강주영 (capt2fact-cyber) | `0cbf3ee` | [Scrum-110, 111, 114] merge (#92) | the_truth_filtering_engine, backend, supabase | 46 files changed, 5373 insertions(+), 1080 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 120 | 2026-05-13 | 정서영 (7101lemontea-rgb) | `e122a85` | [SCRUM-125] feature: SSE 스트리밍 개선 (#93) | backend, web | 5 files changed, 174 insertions(+), 67 deletions(-) | 분석 결과 스트리밍과 사용량 반영 흐름을 보강했다. |
| 121 | 2026-05-13 | 강주영 (capt2fact-cyber) | `fc1306f` | SCRUM-126 플루터(앱) 리팩토링 (#94) | flutter, the_truth_filtering_engine, backend, supabase | 316 files changed, 1194 insertions(+), 5732 deletions(-) | 공통 디자인 시스템과 앱/웹 UI 토큰을 정리했다. |
| 122 | 2026-05-13 | 최대산 (DSanyC) | `5091cba` | Max_review_result 변경 (#95) | backend, web | 3 files changed, 15 insertions(+), 2 deletions(-) | 백엔드 API와 서비스 연동 계층을 보강했다. |
| 123 | 2026-05-13 | 정서영 (7101lemontea-rgb) | `253f782` | [SCRUM-128] fix: 앱(Flutter) 구글 로그인 오류 수정 (#96) | flutter | 2 files changed, 3 insertions(+), 1 deletion(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 124 | 2026-05-14 | 최현석 (choihyunseok) | `ef15073` | [Scrum-129] 앱 웹 기능 맞추기 및 리팩토링 (#98) | flutter, web, backend, .claude | 38 files changed, 2355 insertions(+), 801 deletions(-) | React 웹 클라이언트 기능 또는 UI를 확장했다. |
| 125 | 2026-05-14 | 최대산 (DSanyC) | `7c40d4d` | fix/opt.service-sppeed,show.backend-log (#99) | backend | 2 files changed, 28 insertions(+), 11 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 126 | 2026-05-14 | 정서영 (7101lemontea-rgb) | `a5acc8f` | [SCRUM-127] feature: 앱(Flutter) SSE 스트리밍 구현 (#97) | flutter | 3 files changed, 174 insertions(+), 133 deletions(-) | 분석 결과 스트리밍과 사용량 반영 흐름을 보강했다. |
| 127 | 2026-05-14 | 최현석 (choihyunseok) | `7d89c25` | [SCRUM-129] fix: 테스트 계정을 위한 이전 레거시 코드 남아서 발생한 오류 해결 | flutter | 1 file changed, 10 insertions(+), 15 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 128 | 2026-05-14 | 최대산 (DSanyC) | `8c35c11` | fix: 돈 없을 때, 상세보기 에외처리 화면에서 분석하기 다시눌럿을때  백엔드에서 오류 나던 것 에외처리함. | backend | 1 file changed, 22 insertions(+), 24 deletions(-) | 기존 기능의 오류나 환경 설정 문제를 수정했다. |
| 129 | 2026-05-14 | 최현석 (choihyunseok) | `297f891` | fix: 백엔드 /search/stream 완료 시점에 실제 차감 호출 추가, 차감 결과 usage를 스트리밍 마지막 응답에 포함, React 쪽에서 그 usage.profile을 받아 화면의 코인/count 상태도 바로 갱신 | web, backend | 5 files changed, 22 insertions(+), 4 deletions(-) | 분석 결과 스트리밍과 사용량 반영 흐름을 보강했다. |
| 130 | 2026-05-14 | 최현석 (choihyunseok) | `387b8d5` | feat: 웹에서 리뷰 신고기능 추가 | web | 10 files changed, 666 insertions(+), 110 deletions(-) | 리뷰 신고와 사용자 피드백 기능을 추가했다. |
| 131 | 2026-05-14 | 정서영 (7101lemontea-rgb) | `8f3ebe0` | Scrum 130 fix application debugging (#100) | flutter, web | 6 files changed, 84 insertions(+), 73 deletions(-) | Flutter 앱 기능 또는 실행 환경을 보강했다. |
| 132 | 2026-05-14 | 최대산 (DSanyC) | `7a3cdb0` | Scrum 132 feature/gpu inference batch100 (#101) | backend | 23 files changed, 79 insertions(+), 112098 deletions(-) | Naver Blog 검색 정확도와 리뷰 수집 흐름을 개선했다. |
| 133 | 2026-05-14 | 최현석 (choihyunseok) | `6c76b62` | feat: 웹에서 멋진 초기 화면 | web | 2 files changed, 396 insertions(+), 202 deletions(-) | React 웹 클라이언트 기능 또는 UI를 확장했다. |
| 134 | 2026-05-14 | 최현석 (choihyunseok) | `35b730e` | Merge branch 'dev' of https://github.com/The-Truth-Filtering-Engine/The-Truth-Filtering-Engine into dev | - | 29 files changed, 163 insertions(+), 112171 deletions(-) | 분기 작업을 dev에 통합하고 충돌/구조를 정리했다. |
| 135 | 2026-05-16 | 최대산 (DSanyC) | `cb0c36f` | fix/update-api-base-url (#102) | web | 1 file changed, 1 insertion(+), 1 deletion(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 136 | 2026-05-16 | 최현석 (choihyunseok) | `f252abe` | fix/updaate-api-base-url | flutter | 1 file changed, 1 insertion(+), 1 deletion(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 137 | 2026-05-16 | 최현석 (choihyunseok) | `febdff3` | Codex/first logo screen (#103) | web | 3 files changed, 251 insertions(+), 88 deletions(-) | React 웹 클라이언트 기능 또는 UI를 확장했다. |
| 138 | 2026-05-16 | 최현석 (choihyunseok) | `0b06409` | feat: 구글 검색 가능하도록 설정 | web | 3 files changed, 1 insertion(+) | 검색 노출과 포트폴리오 연결을 위한 웹 배포 자료를 보강했다. |
| 139 | 2026-05-16 | 최현석 (choihyunseok) | `b8b06b8` | feat: Google 크롤링에 바로 쓰일 수 있도록 Vite 배포 기준 정적 SEO 파일을 추가 | web | 3 files changed, 23 insertions(+) | 검색 노출과 포트폴리오 연결을 위한 웹 배포 자료를 보강했다. |
| 140 | 2026-05-17 | 최대산 (DSanyC) | `fd0a8f0` | fix/update_cloudflare_url (#104) | web | 1 file changed, 1 insertion(+), 1 deletion(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 141 | 2026-05-17 | 최현석 (choihyunseok) | `dda7fdd` | fix: google SEO meta tags 수정 | web | 1 file changed, 13 insertions(+), 13 deletions(-) | 검색 노출과 포트폴리오 연결을 위한 웹 배포 자료를 보강했다. |
| 142 | 2026-05-18 | 최현석 (choihyunseok) | `f76897b` | feat: add initial index.html file for web interface | web | 1 file changed, 18 insertions(+), 11 deletions(-) | React 웹 클라이언트 기능 또는 UI를 확장했다. |
| 143 | 2026-05-18 | 최현석 (choihyunseok) | `771d5f1` | feat: initialize web dashboard with LoginPanel component and entry index.html | web | 2 files changed, 57 insertions(+), 2 deletions(-) | 로그인/인증과 사용자 설정 흐름을 개선했다. |
| 144 | 2026-06-03 | 최현석 (choihyunseok) | `c6637b9` | 로그인 화면에 포트폴리오 페이지 연결 | backend, web | 2 files changed, 276 insertions(+), 8 deletions(-) | 검색 노출과 포트폴리오 연결을 위한 웹 배포 자료를 보강했다. |
| 145 | 2026-06-03 | 최현석 (choihyunseok) | `fc75cbc` | 로그인 화면에 포트폴리오 연동 | web, .gitignore, README.md, backend, pubspec.lock | 7 files changed, 184 insertions(+), 611 deletions(-) | 검색 노출과 포트폴리오 연결을 위한 웹 배포 자료를 보강했다. |
| 146 | 2026-06-03 | 최현석 (choihyunseok) | `52024c5` | 서버이전으로 backend endpoint 변경 | flutter, web | 2 files changed, 1 insertion(+), 4 deletions(-) | 백엔드 접속 주소와 배포 연결 설정을 조정했다. |
| 147 | 2026-06-04 | 최현석 (choihyunseok) | `5adbc9e` | Clean up README by removing unnecessary sections | README.md | 1 file changed, 33 deletions(-) | 프로젝트 문서와 보고 자료를 정리했다. |

## 참고와 한계

- 이 문서는 Git commit metadata와 파일 변경 범위를 기준으로 작성했으므로, 페어 프로그래밍, 회의, 설계 토론, 오프라인 작업처럼 Git에 직접 남지 않은 기여는 별도 근거와 함께 보완하는 것이 좋습니다.
- merge commit은 실제 코드 작성자와 commit author가 다를 수 있습니다. 이 문서의 작성자 집계는 Git author 기준이며, 최현석, 정서영, 강주영, 최대산 계정 별칭만 사용자 확인에 따라 정규화했습니다.
- `Scope`는 파일 경로 기반 요약이므로, 한 커밋이 여러 영역을 동시에 바꾼 경우 대표 경로만 압축해 표시했습니다.
