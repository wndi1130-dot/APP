# 일하는 방식과 문서 지도

기준: 2026-10-08 오전 · [핸드북 입구](README.md)

## 누가 무엇을 하나

- **사용자:** 핵심 규칙, 범위, 단계 순서, 아트 방향, 수익, 출시 시점, 열린 질문, 돈이 드는 일을 정한다. 단계가 끝나면 직접 플레이해 관문을 판정한다.
- **Claude:** 구현, 테스트, 문서 정리, 작업 나누기. 확인 없이 설계를 확정하거나 범위를 넓히지 않고, 외부 게시·결제를 하지 않으며, 테스트를 끄지 않는다.
- **프로젝트 대화와 스레드:** 프로젝트 대화의 코디네이터가 요청을 받아 주제별 스레드에 나눈다. 스레드마다 맡은 문서나 코드가 있다(예: s1/은 'S1a 화면 옮기기와 플레이 빌드', s2/는 'S2 파밍 회색 상자 제작', CI와 병합은 '코드 통합과 CI').
- **사용자에게 묻는 카드:** 스레드가 초안(질문, 맥락, 안 2~4개, 추천)을 쓰면 코디네이터가 프로젝트 대화에서 모아 묻는다. 답을 기다리는 동안 되돌릴 수 있는 일은 추천안대로 진행하고 문서에 제안으로 적는다.
- **다른 모델 워커:** 코드 리뷰, 테스트 초안, 문서 사이 모순 찾기, 조사, 시뮬레이션 검증은 사용자 PC의 다른 모델(Codex 등)에도 맡기고, 판단이 갈리는 일은 둘 이상에 맡겨 대조한다. 모델의 답은 자료이고, 주인 스레드가 읽고 확인한 뒤 자기 커밋이나 PR로 올린다.

## 스레드와 맡은 것

2026-10-08 오전에 진행 중인 일을 한 번 정리했다. '정리'는 그 스레드가 마무리 요약을 남겼는지다.

| 스레드 | 맡은 것 | 정리 |
|---|---|---|
| S1a 화면 옮기기와 플레이 빌드 | s1/ 코드 전체(S1b·S1c 코드 포함), 플레이 빌드 | 정리 기다림(PR 45 합침) |
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

## 병합하지 않은 연구 가지

다른 모델의 검수·조사 결과는 main에 합치지 않은 가지에 있다. 읽어 보고 필요한 것만 main으로 옮긴다.

| 가지 | 든 것 |
|---|---|
| research/astra-20261008 | 바깥 검수 K01(정치·내정), K02(어두운 길), K03(S2 정적 검수, 높음 9)과 고칠 안 패치, K04(저장소 위생), K05(금지선 대조 표), K06(문서 충돌 32건). K03~K06은 main 1a68302 기준이고 다른 모델 교차 확인 전이다. K03 패치는 지금 코드에 그대로 붙지 않아 손으로 맞춘 뒤 GUT를 돌려야 한다 |
| research/stop-screening-20261008 | 캠페인 정차 후보 거르기. 1막 14곳 다시 거르기는 뺌 2, 뺌(불확실) 2, 모름 10. 사용자에게 보일 표와 추천은 이야기 스레드가 만든다 |
| research/codex-20261008 | Codex 대조 답(J 묶음) |
| research/ui-motion-sound-20261007 | UI 움직임·소리 조사(이벤트 24개 규격) |

로컬 워커(사용자 PC) 쪽 남은 일: 2막 13곳 다시 거르기와 1막 '모름' 10곳·갈린 2곳 처리, 아직 시작 안 한 작업 몇 묶음(K07~K11, 성능 시험용 열차 키트, J03, J25), K03~K06 교차 확인, 다음 Codex 커밋의 작성자 주소 확인, 직업 시트 다시 그리기. 커밋 작성자 주소는 앞으로 GitHub noreply로 맞췄고 옛 이력은 그대로 둔다.

## 저장소에 올리는 법

- 설계 문서는 main에 바로 올린다.
- 코드는 맡은 스레드가 브랜치에서 고치고 PR을 연다. CI가 초록이면 '코드 통합과 CI' 스레드가 합친다. S1과 S2를 잇는 영수증 스키마·계약 검사도 그 스레드 몫이다.
- 조사 결과와 모델 답 요약은 병합하지 않는 `research/…` 가지에 둔다. 새 조사를 맡기기 전에 이미 있는지 먼저 본다.
- 새로 정한 것은 decisions.md에 반영하고, 확정과 제안을 구분한다. 단계를 마치면 session_start.md의 '다음 할 일'을 고친다.

## 공개 저장소 규칙

저장소는 공개다. 다음은 올리지 않는다.

- 비밀 키, 토큰, 영수증, 개인 정보, 로컬 계정 이름이 든 경로.
- 레퍼런스 그림, 아트북, 다른 게임의 화면·대사·코드, 대본 같은 남의 저작물. 좀보이드는 논리만 참고하고 GPL 코드는 참고만 한다.
- 시안 그림 파일(프로젝트 공유 폴더와 사용자 PC에 둔다).
- 모델 답 원문.

2026-10-08 바깥 검수(K04)로 저장소를 훑었을 때 비밀과 GPL 코드 복사는 0건이었다. 다른 작품 원문 인용 14곳은 이미 설명으로 바꿨다. 낮음으로 남은 것은 연구 가지와 옛 PR 하나에 든 로컬 PC 경로, 1MB 넘는 파일 셋이다.

민감한 역사 금지선(장소, 탓과 위생, 이송 열차와 수용소를 떠올리게 하는 것, 옷·말·노래·음식)은 프로젝트 지침에 전문이 있고 글, 그림 주문, 소리, 움직임, 조사, 게임 데이터, 외부 모델 의뢰에 모두 적용한다. 이 저장소에는 장소 목록을 옮기지 않는다.

## 문서 지도

| 알고 싶은 것 | 먼저 볼 문서 |
|---|---|
| 지금 단계와 새 세션 시작 | [handoff/session_start.md](../handoff/session_start.md) |
| 무엇이 확정이고 무엇이 제안인가 | [design/decisions.md](../design/decisions.md) |
| 단계와 관문의 원래 계획 | [briefs/first_slice_scope.md](../design/briefs/first_slice_scope.md), [handoff/coordinator_goal.md](../handoff/coordinator_goal.md) |
| 원래 아이디어와 레퍼런스 조사 | [design/apocalypse_train_game_design_log.md](../design/apocalypse_train_game_design_log.md) |
| 정치 | [briefs/s1a_politics_numbers.md](../design/briefs/s1a_politics_numbers.md), [prototype/s1_political_prototype.md](../prototype/s1_political_prototype.md), [research/프로스트펑크2 정치 시스템 분석.md](../research/프로스트펑크2%20정치%20시스템%20분석.md) |
| 어두운 길 | [briefs/s1b_dark_path.md](../design/briefs/s1b_dark_path.md) |
| 내정 | [briefs/s1c_domestic.md](../design/briefs/s1c_domestic.md), [briefs/s1c_build_notes.md](../design/briefs/s1c_build_notes.md) |
| 필드 | [briefs/field_unified.md](../design/briefs/field_unified.md), [briefs/s2_station.md](../design/briefs/s2_station.md), [briefs/places.md](../design/briefs/places.md), [briefs/body_injury.md](../design/briefs/body_injury.md) |
| 이야기 | [briefs/first_leg_story.md](../design/briefs/first_leg_story.md), [briefs/world_lore.md](../design/briefs/world_lore.md) |
| 글 규격(대사·카드 쓰는 법) | [prototype/s1_content_guide.md](../prototype/s1_content_guide.md) 6장 |
| 화면 | [briefs/presentation_ui.md](../design/briefs/presentation_ui.md), [briefs/presentation_motion.md](../design/briefs/presentation_motion.md) |
| 그림 | [docs/art/](../art/) |
| 소리와 권리 | [briefs/sound_music.md](../design/briefs/sound_music.md), [design/rights_ledger.md](../design/rights_ledger.md) |
| 바깥 점검 | [docs/design/review/](../design/review/) |
| 시뮬레이터 | [docs/design/sim/](../design/sim/) |
| 레퍼런스 자료(이름 풀, 철도망, 장소, 지도) | [ref/](../../ref/) |
| 다른 모델에 맡긴 작업의 기록 | [docs/handoff/](../handoff/) |
