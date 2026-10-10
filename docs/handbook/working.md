# 일하는 방식과 문서 지도

기준: 2026-10-10 · [핸드북 입구](README.md)

## 로컬에서 일하기 (2026-10-10부터)

2026-10-10에 작업 자리를 claude.ai 프로젝트에서 사용자 PC의 로컬 세션으로 옮겼다. 깃허브 저장소는 그대로 쓴다. 아래 '누가 무엇을 하나'와 '스레드와 맡은 것'의 스레드·공유 폴더·코디네이터에게 보내기는 클라우드 때의 틀이고, 지금은 이렇게 한다.

- **코디네이터 세션 하나와 작업 세션 여럿.** 코디네이터가 할 일을 줄기(예: S1 코드 마무리, S2 필드, S1c 손질, 문서 정정)로 나누고, 줄기마다 작업 세션 하나가 저장소의 git 워크트리에서 일한다. 동시에 여는 세션 수는 묶지 않는다. 같은 줄기를 둘이 열지 않는다.
- **인계는 줄기 파일로.** 줄기마다 목표, 읽을 것, 남은 일, 하지 말 것, 끝 조건, 한 일, 막힌 것, 사용자에게 물을 것, 다음 한 걸음을 적은 파일이 있고, 작업 세션은 한 걸음을 마칠 때마다 그 파일을 고친다. 줄기 파일과 코디네이터의 상태 글은 저장소 밖(사용자 PC의 조정 폴더)에 있고 공개 저장소에 올리지 않는다.
- **사용자에게 묻기.** 코디네이터가 하나씩 묻고, 답은 결정 하나에 파일 하나로 적은 뒤 decisions.md에 확정과 제안을 구분해 옮긴다. 답을 기다리는 동안 되돌릴 수 있는 일은 추천안대로 계속한다.
- **옛 공유 폴더.** 클라우드 프로젝트의 공유 폴더에 있던 결정 카드, 점검표, 정리 글, 판정 글은 저장소 밖 비공개 인계 묶음에 같은 상대 경로로 있다. 저장소 문서에 '공유 폴더 `s1c_play/h6_checklist.md`'처럼 적힌 것은 그 묶음의 같은 경로다. 금지선 전문과 이름 제외 목록도 그 묶음에만 두고, 내용을 저장소·커밋 글·PR 글·워커에게 주는 글에 옮기지 않는다.
- **S1 웹 판 보기.** PC에서 판을 띄우고 같은 와이파이의 폰으로 접속해 해 본다(2026-10-10 사용자 결정, [builds.md](builds.md)). claude.ai 아티팩트에 새로 올리지 않는다. 예전 비공개 링크(v10, main b042d12)는 로컬에서 고칠 수 없다.
- **S2 폰 빌드.** APK는 GitHub Actions가 만든다. PC에서는 Godot로 GUT 테스트만 돌린다.
- **PR.** 코드는 가지와 PR로 올리고, CI가 초록이면 PR을 연 세션이 직접 main에 합친다. 여러 줄기가 함께 건드리는 파일(s1의 politics.ts·data.ts·turn.ts·dark/와 끝 종류 EndKind, s2의 field_hud.gd·field_combat.gd)은 열린 PR을 먼저 보고 PR 하나씩만 연다. 문서만 바꾸는 PR은 CI가 걸리지 않으니 링크와 줄 대조를 직접 하고 그 결과를 PR에 적는다.
- **워커.** 찾기·요약·기계 수정·시험 초안 같은 잔일은 워커 모델에 떼어 준다. 어떤 모델을 어떻게 부르는지는 사용자 PC 쪽 규칙(저장소 밖)을 따른다. 워커의 답은 자료이고, 부른 세션이 읽고 확인한 뒤 자기 커밋으로 올린다.
- **하지 않는 것.** 주기적으로 들여다보기와 깨우기용 핑, 테스트를 끄거나 건너뛰어 초록 만들기, 외부 게시와 결제, 사용자 확인 없는 설계 확정.

## 누가 무엇을 하나

- **사용자:** 핵심 규칙, 범위, 단계 순서, 아트 방향, 수익, 출시 시점, 열린 질문, 돈이 드는 일을 정한다. 단계가 끝나면 직접 플레이해 관문을 판정한다.
- **Claude:** 구현, 테스트, 문서 정리, 작업 나누기. 확인 없이 설계를 확정하거나 범위를 넓히지 않고, 외부 게시·결제를 하지 않으며, 테스트를 끄지 않는다.
- **프로젝트 대화와 스레드(클라우드 때, 10-09까지):** 프로젝트 대화의 코디네이터가 요청을 받아 주제별 스레드에 나눈다. 스레드마다 맡은 문서나 코드가 있다(예: s1/은 'S1a 화면 옮기기와 플레이 빌드', s2/는 'S2 파밍 회색 상자 제작', CI와 병합은 '코드 통합과 CI').
- **사용자에게 묻는 카드:** 스레드가 초안(질문, 맥락, 안 2~4개, 추천)을 쓰면 코디네이터가 프로젝트 대화에서 모아 묻는다. 답을 기다리는 동안 되돌릴 수 있는 일은 추천안대로 진행하고 문서에 제안으로 적는다.
- **다른 모델 워커:** 코드 리뷰, 테스트 초안, 문서 사이 모순 찾기, 조사, 시뮬레이션 검증은 워커 모델에도 맡기고, 판단이 갈리는 일은 둘 이상에 맡겨 대조한다. 모델의 답은 자료이고, 맡긴 쪽이 읽고 확인한 뒤 자기 커밋이나 PR로 올린다. 부르는 법은 사용자 PC의 워커 핸드북(WORKER-ROUTING.md)을 따른다. 클라우드 때는 스레드가 작업 묶음을 코디네이터에게 보내 PC의 로컬 워커 세션이 돌렸고, 지금은 작업 세션이 직접 부른다.
- **PC 옵시디언 위키:** 사용자 PC의 옵시디언 LLM 위키에 이 게임 트랙 `apocalypse-train-game`이 있다(2026-10-08 첫 기록, 10-08 결정 요지). 'LLM 위키 기록' 스레드가 폴더 도구로 날짜·주제·원천·확정/제안 목록을 넣는다. 세션 시작 회상에는 등재하지 않는다(2026-10-08 사용자 카드 '안 함'). 볼트 규칙은 위키 안의 `_SYSTEM.md`를 따르고, 위키 내용은 공개 저장소에 올리지 않는다.

## 스레드와 맡은 것

클라우드 때의 스레드 표다. 로컬에는 스레드가 없고 줄기가 그 자리를 잇는다(위 '로컬에서 일하기'). 어느 문서와 코드가 한 묶음인지 보는 데 쓴다. 2026-10-08에 진행 중인 일을 한 번 정리했다. '정리'는 그 스레드가 마무리 요약을 남겼는지다. 요약 글은 공유 폴더 `wrapup/<스레드>.md`에 있다. 스레드는 프로젝트마다 따로라서 다른 계정 프로젝트로 옮기면 같은 이름으로 새로 연다.

| 스레드 | 맡은 것 | 정리 |
|---|---|---|
| S1a 화면 옮기기와 플레이 빌드 | s1/ 코드 전체(S1b·S1c 코드 포함), 플레이 빌드 | 됨 |
| S1b 어두운 길 설계 | s1b_dark_path.md, S1b 코드 리뷰와 시뮬레이션 | 됨 |
| 내정(S1c) 설계 | s1c_domestic.md, 내정 시뮬레이션 | 됨 |
| 현실감 디테일 찾기 | politics_detail.md(사람의 무게, 열차 정치) | 됨 |
| S2 파밍 회색 상자 제작 | s2/ 코드, 폰 빌드 | 됨 |
| 파밍·수집·전투 설계 통일 | field_unified, body_injury, places, zombies | 됨 |
| 열차장 만들기와 사람 능력 | character_creation.md | 됨 |
| 첫 구간 이야기 뼈대 | first_leg_story.md, 글 규격, 캠페인 정차 거르기 | 됨 |
| 화면 컨셉과 UI 연출 | presentation_motion.md, 구간 배경 | 됨 |
| 3D 모델링 시안 | docs/art/의 모델·열차 시안과 주문서 | 됨 |
| 사운드·음악 방향 | sound_music.md, rights_ledger.md | 됨 |
| 기획 점검 | docs/design/review/ 01~07 | 됨 |
| 재미·상품성 점검 | review/08·09, 판매 결정 | 됨 |
| 출시 기준 확정·미정 정리 | 「출시 기준 설계 현황」 문서, 플레이 계정 | 됨 |
| 코드 통합과 CI | PR 병합, CI, 영수증·프로필 계약 | 됨 |
| 로컬 워커 조사 | 사용자 PC에서 다른 모델 부르기, 조사·렌더 | 됨 |
| 개발 현황 핸드북 | docs/handbook/, 늦게 온 정리 덧붙이기 | 됨 |
| LLM 위키 기록 | PC 옵시디언 위키에 결정 기록 넣기 | 됨 |
| 다른 계정으로 옮기기 | 이 핸드북의 옮기기 절, 옮길 묶음 | 됨 (2026-10-09) |

## 병합하지 않은 연구 가지

다른 모델의 검수·조사 결과는 main에 합치지 않은 가지에 있다. 읽어 보고 필요한 것만 main으로 옮긴다.

| 가지 | 든 것 |
|---|---|
| research/astra-20261008 | 바깥 검수 K01(정치·내정), K02(어두운 길), K03(S2 정적 검수, 높음 9)과 고칠 안 패치, K04(저장소 위생), K05(금지선 대조 표), K06(문서 충돌). K03~K06은 main 1a68302 기준이고 다른 모델 교차 확인 전이다. 최신 main과 대조해 고친 것: K01(PR 45·49), K02(PR 46·47·53), K03 높음(PR 62·69), K05(PR 59·64·65·66·80·85·104), K06 문서 몫 27건(PR 61) |
| research/stop-screening-20261008 | 캠페인 정차 후보 거르기. 판정과 걸린 종류만 있다. 지도 대조 v3(fcb0075)와 보충 판정 v4(c777546)로 정차 표를 확정했고, 확정 표는 main의 first_leg_story 8.1·8.3에 옮겼다. 판정 근거 메모는 사용자 PC에만 있다 |
| research/codex-20261008 | Codex 대조 답(J 묶음) |
| research/codex-events-20261009 | 이동 사건 첫 묶음 초안 20장. 고른 것은 main의 이동 사건 20장(PR 102, 기본 꺼짐)으로 옮겼다 |
| research/codex-rumor-20261009 | 소문 시제품과 켬·끔 4,000판 측정. 측정 요지는 main의 politics_detail 7.4에 옮겼다(PR 95) |
| research/ui-motion-sound-20261007 | UI 움직임·소리 조사(이벤트 24개 규격) |

이 표에 없는 `research/…` 가지는 10-07의 조사 가지들이다(레퍼런스, 구간 사진, 필드·어두운 길 조사 등). 목록은 `git branch -r --list 'origin/research/*'`로 본다. 열린 PR 12·21·24는 이런 조사 가지에서 연 것이고(합치지 않은 채 열려 있다), 닫을지 정리할지는 사용자가 정한다.

워커 쪽 남은 일: 아직 시작 안 한 작업 몇 묶음(K07~K11, 성능 시험용 열차 키트, J03, J25), K03~K06 교차 확인, 직업 시트(F5a·F5b) 다시 그리기. 캠페인 정차 거르기, 소문 규칙 측정, 이름 풀 원 통계 사본 찾기는 끝났다. 커밋 작성자 주소는 앞으로 GitHub noreply로 맞췄고 옛 이력은 그대로 둔다.

## 저장소에 올리는 법

- 설계 문서는 main에 바로 올린다.
- 코드는 맡은 세션이 브랜치에서 고치고 PR을 연다. CI가 초록이면 PR을 연 세션이 직접 합친다(클라우드 때는 '코드 통합과 CI' 스레드가 합쳤다). S1과 S2를 잇는 영수증 스키마·계약을 바꾸면 양쪽 검사를 함께 맞춘다.
- 조사 결과와 모델 답 요약은 병합하지 않는 `research/…` 가지에 둔다. 새 조사를 맡기기 전에 이미 있는지 먼저 본다.
- 새로 정한 것은 decisions.md에 반영하고, 확정과 제안을 구분한다. 단계를 마치면 session_start.md의 '다음 할 일'을 고친다.

## 공개 저장소 규칙

저장소는 공개다. 다음은 올리지 않는다.

- 비밀 키, 토큰, 영수증, 개인 정보, 로컬 계정 이름이 든 경로.
- 레퍼런스 그림, 아트북, 다른 게임의 화면·대사·코드, 대본 같은 남의 저작물. 좀보이드는 논리만 참고하고 GPL 코드는 참고만 한다.
- 시안 그림 파일(사용자 PC에 둔다).
- 모델 답 원문.
- 커밋 글과 PR 글에는 모델 이름을 쓰지 않는다(2026-10-10부터).

2026-10-08 바깥 검수(K04)로 저장소를 훑었을 때 비밀과 GPL 코드 복사는 0건이었다. 다른 작품 원문 인용 14곳은 이미 설명으로 바꿨다. 낮음으로 남은 것은 연구 가지와 옛 PR 하나에 든 로컬 PC 경로, 1MB 넘는 파일 셋이다.

민감한 역사 금지선(장소, 탓과 위생, 이송 열차와 수용소를 떠올리게 하는 것, 옷·말·노래·음식)은 프로젝트 지침에 전문이 있고 글, 그림 주문, 소리, 움직임, 조사, 게임 데이터, 외부 모델 의뢰에 모두 적용한다. 이 저장소에는 장소 목록을 옮기지 않는다.

## 다른 계정 프로젝트로 옮길 때

이 절은 클라우드 계정 사이를 옮긴 2026-10-09의 기록이다. 10-10에 작업 자리를 다시 로컬 세션으로 옮겼고 그 틀은 맨 위 '로컬에서 일하기'에 있다. 아래 순서는 로컬 이전에 쓰는 절차가 아니다.

2026-10-09 사용자가 다른 Claude 계정의 프로젝트에서 이어 가기로 했다. 깃허브 저장소(코드, 설계 문서, 이 핸드북, 연구 가지)는 그대로 쓴다. 아래는 저장소 밖에만 있어서 손으로 옮겨야 하는 것이다.

옮길 묶음은 `carry_20261009.zip`이다. 옛 프로젝트 공유 폴더의 `handoff/`에 있고, 내려받기로만 넘긴다. 공개 저장소에는 올리지 않는다. 안에는 공유 폴더 전체(렌더 `art/`만 뺌), 프로젝트 지침과 목표 글 전문, 프로젝트 메모리, 비공개 아티팩트 두 개의 사본이 있고, 맨 위 `README_carry.md`에 목록과 순서가 있다.

| 무엇 | 지금 어디 | 옮기는 법 |
|---|---|---|
| 프로젝트 지침(PC 연결, 워커, 결정 카드, 코드 병합, 민감한 역사 금지선 전문) | 옛 프로젝트 설정 | 묶음의 `project/instructions.txt`를 새 프로젝트 지침에 그대로 붙인다. 금지선 전문은 지침에만 두고 저장소로 옮기지 않는다(장소 목록 포함) |
| 프로젝트 목표 글(완성의 정의, 단계와 관문, 사용자가 정하는 것) | 옛 프로젝트 설정 | 묶음의 `project/topic.txt`를 새 프로젝트 설명에 붙인다 |
| 프로젝트 메모리 | 옛 프로젝트 메모리 | 새로 시작한다. 묶음의 `memory/MEMORY.md`에서 사람·PC 정보, 사용자 결정 요지, 일하는 규칙 줄만 옮긴다. 스레드 id(cmsg_…)와 세션 id는 새 프로젝트에서 통하지 않으니 빼고 스레드 이름으로 바꾼다 |
| 공유 폴더(결정 카드, 정리 글, 점검표·스크린샷, S1b 판정, S1c 버그 목록, 아스트라 원답, 이름 제외 목록) | 옛 프로젝트 `/mnt/project-files` | 묶음의 `files/`를 새 프로젝트 첫 스레드에서 공유 폴더에 같은 경로로 푼다. `s1/tests`의 세 파일이 `s1b_wip/`의 판정 글 경로를 주석으로 인용하니 경로를 바꾸지 않는다. S1c 버그 목록(`s1c_handoff/s1a_bugs_20261008.md`)은 이 묶음에만 있다. 이름 제외 목록(`guard/`)은 공개 저장소와 커밋 글에 적지 않는다 |
| 렌더 그림(공유 폴더 `art/`, 약 134MB) | 원본은 사용자 PC 바탕화면 `좀비\*_20261007\` | 묶음에서 뺐다. 필요할 때 PC에서 새 프로젝트 공유 폴더 `art/`로 올린다. docs/art/ 문서의 `/mnt/project-files/art/` 경로는 그 자리를 가리킨다 |
| S1a 플레이 빌드 v22 | claude.ai 비공개 아티팩트 | 옛 링크는 새 계정에서 열리지 않는다. 묶음의 `claude_ai/s1a_play_v22.html`을 새 계정에서 아티팩트로 다시 게시하거나 s1/에서 다시 빌드한다([builds.md](builds.md)) |
| 「출시 기준 설계 현황」 문서 | claude.ai 문서(rev 307, 10-07 기준) | 묶음의 `claude_ai/release_status_doc_rev307.md`. 새 계정에서 새 문서로 만든다. 10-07 뒤 바뀐 것은 이 핸드북이 더 새롭다 |
| GitHub 연결 | 옛 계정 | 새 계정에서 같은 GitHub 계정을 잇고(claude.ai/connect-github), Claude GitHub 앱이 이 저장소에 깔려 있는지 확인한 뒤 새 프로젝트 설정에 저장소를 더한다 |
| PC 연결 | 옛 계정의 Claude 데스크톱 앱 | 새 계정으로 데스크톱 앱에 들어가 바탕화면 폴더 허락을 다시 준다. 로컬 워커 세션(바탕화면 `작업폴더`의 Remote Control)도 새 프로젝트에서 다시 연다. 옵시디언 위키 폴더는 기록할 때만 따로 허락한다 |
| 다른 커넥터 | 옛 계정 | 쓰는 것만 새 계정에서 다시 잇는다 |
| 스레드 대화 원문 | 옛 프로젝트 | 옮기지 않는다. 결과는 저장소와 묶음의 정리 글(`wrapup/`), 결정 카드에 있다 |

사용자 PC에 있는 것(워커 핸드북, 로컬 워커 답 폴더, 렌더 원본, 옵시디언 위키, S2 빌드 폴더)은 계정과 상관없이 그대로다.

새 계정에서 할 순서:

1. 새 계정에서 GitHub를 잇고 새 프로젝트를 만든 뒤 이 저장소를 더한다.
2. 프로젝트 지침과 설명에 묶음의 `project/` 두 파일을 붙인다.
3. 첫 메시지에 묶음 zip을 붙이고 "공유 폴더에 풀고 핸드북부터 읽어"라고 한다. 그 스레드가 `files/`를 공유 폴더에 풀고, `memory/`에서 핵심 줄만 새 메모리로 옮긴다.
4. 데스크톱 앱을 새 계정으로 열고 바탕화면 폴더를 허락한다. 로컬 워커 세션을 다시 연다.
5. S1a 플레이 빌드를 다시 게시하고 새 링크를 메모리와 [builds.md](builds.md)에 적는다.

## 문서 지도

| 알고 싶은 것 | 먼저 볼 문서 |
|---|---|
| 지금 단계와 새 세션 시작 | [handoff/session_start.md](../handoff/session_start.md) |
| 무엇이 확정이고 무엇이 제안인가 | [design/decisions.md](../design/decisions.md) |
| 단계와 관문의 원래 계획 | [briefs/first_slice_scope.md](../design/briefs/first_slice_scope.md), [handoff/coordinator_goal.md](../handoff/coordinator_goal.md) |
| 원래 아이디어와 레퍼런스 조사 | [design/apocalypse_train_game_design_log.md](../design/apocalypse_train_game_design_log.md) |
| 정치 | [briefs/s1a_politics_numbers.md](../design/briefs/s1a_politics_numbers.md), [prototype/s1_political_prototype.md](../prototype/s1_political_prototype.md), [research/프로스트펑크2 정치 시스템 분석.md](../research/프로스트펑크2%20정치%20시스템%20분석.md) |
| 어두운 길 | [briefs/s1b_dark_path.md](../design/briefs/s1b_dark_path.md), 계엄 [briefs/s1b_martial_impl.md](../design/briefs/s1b_martial_impl.md) |
| 내정 | [briefs/s1c_domestic.md](../design/briefs/s1c_domestic.md), [briefs/s1c_build_notes.md](../design/briefs/s1c_build_notes.md) |
| 사건·재난 | [briefs/events_disasters.md](../design/briefs/events_disasters.md) |
| 필드 | [briefs/field_unified.md](../design/briefs/field_unified.md), [briefs/s2_station.md](../design/briefs/s2_station.md), [briefs/places.md](../design/briefs/places.md), [briefs/body_injury.md](../design/briefs/body_injury.md) |
| 이야기 | [briefs/first_leg_story.md](../design/briefs/first_leg_story.md), [briefs/campaign_story.md](../design/briefs/campaign_story.md), [briefs/world_lore.md](../design/briefs/world_lore.md) |
| 계절·시각·지역 | [briefs/seasons_regions.md](../design/briefs/seasons_regions.md) |
| 글 규격(대사·카드 쓰는 법) | [prototype/s1_content_guide.md](../prototype/s1_content_guide.md) 6장 |
| 화면 | [briefs/presentation_ui.md](../design/briefs/presentation_ui.md), [briefs/presentation_motion.md](../design/briefs/presentation_motion.md), 상태 화면 [briefs/ui_states.md](../design/briefs/ui_states.md), 셰이더 [briefs/shaders.md](../design/briefs/shaders.md) |
| 그림 | [docs/art/](../art/), 트리포 소품 기준 [tripo_pipeline.md](../art/tripo_pipeline.md) |
| 소리와 권리 | [briefs/sound_music.md](../design/briefs/sound_music.md), [briefs/ai_audio.md](../design/briefs/ai_audio.md), [briefs/crowd_voices.md](../design/briefs/crowd_voices.md), [design/rights_ledger.md](../design/rights_ledger.md) |
| 바깥 점검 | [docs/design/review/](../design/review/) |
| 시뮬레이터 | [docs/design/sim/](../design/sim/) |
| 레퍼런스 자료(이름 풀, 철도망, 장소, 지도) | [ref/](../../ref/) |
| 다른 모델에 맡긴 작업의 기록 | [docs/handoff/](../handoff/) |
