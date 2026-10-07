# 아포칼립스 열차 생존 게임 (가칭)

달리는 열차를 이동식 사회로 운영하는 모바일 탑뷰 아포칼립스 생존·내정 게임의 설계 저장소다. 지금은 설계 논의와 첫 검증판 S1(정치 텍스트 프로토타입) 준비 단계이고, s1/에 S1 코드 뼈대가 있다.

## 문서

- [docs/handoff/session_start.md](docs/handoff/session_start.md): 새 세션 시작 안내. 가장 먼저 읽는다
- [docs/design/decisions.md](docs/design/decisions.md): 확정 사항, 검토 중인 제안, 열린 질문
- [docs/design/briefs/](docs/design/briefs/): 결정을 앞둔 주제의 브리프
- [docs/prototype/s1_political_prototype.md](docs/prototype/s1_political_prototype.md): 첫 검증판 S1(정치 텍스트 프로토타입) 기획서 2판. S1a 거래, S1b 어두운 길, S1c 내정
- [docs/prototype/s1_content_guide.md](docs/prototype/s1_content_guide.md): S1 콘텐츠 가이드(Gemini용 스키마, 문체 가이드, 캐릭터 바이블의 틀)
- [docs/handoff/codex_tasks.md](docs/handoff/codex_tasks.md): 코덱스 등 다른 에이전트에게 넘길 작업 목록. 코드는 s1/, 레퍼런스는 ref/에 만든다
- [docs/handoff/codex_prompts.md](docs/handoff/codex_prompts.md): 위 작업을 하나씩 바로 붙여 넣는 프롬프트
- [docs/handoff/codex_review.md](docs/handoff/codex_review.md): 1차 결과 검토와 합치는 순서
- [docs/handoff/round2_prompts.md](docs/handoff/round2_prompts.md): 1차 결과를 반영한 2차 프롬프트(남은 작업, 후속 수정, 순서)
- [ops/dispatch.md](ops/dispatch.md): 밤사이 자동 진행용 신호판. Claude가 쓰고 DOTS가 읽는다. DOTS는 [ops/dispatch_ack.md](ops/dispatch_ack.md)에만 쓴다
- [docs/design/apocalypse_train_game_design_log.md](docs/design/apocalypse_train_game_design_log.md): 원본 설계 로그와 레퍼런스 조사
- [docs/research/프로스트펑크2 정치 시스템 분석.md](docs/research/프로스트펑크2%20정치%20시스템%20분석.md): 프로스트펑크 2 정치 시스템 조사 보고서
- [docs/research/notes/](docs/research/notes/): 프로스트펑크 2 보고서의 원자료 노트
- [docs/research/reports/좀보이드 모드 설계 참고.md](docs/research/reports/좀보이드%20모드%20설계%20참고.md): 좀보이드 유명 모드 조사 보고서(무리 습격, 사람 적, 무기, 의료·절단, 지식, 열차)
- [docs/research/research_notes/](docs/research/research_notes/): 좀보이드 모드 보고서의 원자료 노트
- [docs/art/production_brief.md](docs/art/production_brief.md): 현재 월드·UI 구분과 3D 제작/조사 기준. 월드는 픽셀 아트가 아니라 좀보이드식 그래픽이다
- [docs/art/image_prompts.md](docs/art/image_prompts.md): 현재 시안 지침. 과거 픽셀 원문은 별도 보관본으로 분리
- [ref/art/production_resources.md](ref/art/production_resources.md): 3D 제작 자료 조사 2판(후보·출처·권리·버전·잔여 검증)
- [docs/handoff/3d_research_tasks.md](docs/handoff/3d_research_tasks.md): Claude Code·Codex·웹 채팅 공통 조사 지시서
- [docs/research/3d_instruction_audit.md](docs/research/3d_instruction_audit.md): 이번 지시사항 교정 내역과 검증 범위
- [docs/research/gap_fill.md](docs/research/gap_fill.md): ref/ 자료의 '미확인' 보충 조사(증기기관차 소비·점화·제설, 피난민 이름 표기)

<!-- APP_3D_RESEARCH_INDEX_BEGIN -->
## 3D 제작 자료 목록

**[전체 자원 색인: ref/art/README.md](ref/art/README.md)** — 버전별 후보를 한곳에서 찾는다.

조사 항목 **85개**: 2판 37개 + 3판 17개 + 4판 8개 + 5판 9개 + 6판 14개. 공급자 수나 확보한 파일 수가 아니며, 도구·서비스·기법·개별 자산을 포함한다. 프로젝트 적용은 미검증이다.

| 순서 | 자료 | 내용 |
|---|---|---|
| 1 | [현재 아트 기준](docs/art/production_brief.md) · [조사 지시서](docs/handoff/3d_research_tasks.md) | 비픽셀 월드·UI 분리와 작업 범위 |
| 2 | [전체 자원 목록](ref/art/README.md) | 분야·용도·출처·미확인 상태로 검색 |
| 3 | [제작 자원 2판](ref/art/production_resources.md) · [JSON](ref/art/resource_index.json) | 기반 도구·리그·소품·재질·셰이더 37개, 별도 제외 3개 |
| 4 | [작품별 보충 3판](ref/art/game_reference_resources_v3.md) · [JSON](ref/art/game_reference_resources_v3.json) | This War of Mine·Frostpunk 1·2·Metro 제작자 자료 6개, 후보 17개, 장면 검증안 6개 |
| 5 | [빠진 자원 보충 4판](ref/art/production_gap_resources_v4.md) · [JSON](ref/art/production_gap_resources_v4.json) | 작업·구조 모션, 철도 음향, 의복/소품/경로 제작 8개, 재확인 1건, 자료 경로 2건 |
| 6 | [방한복·소품·전달 보충 5판](ref/art/production_resources_v5.md) · [JSON](ref/art/production_resources_v5.json) | 구체 의복·생활 소품·의존 파일·렌더 관리·UV/텍스처·메모리 9개, 버전 제외 1개 |
| 7 | [애니메이션 보충 6판](ref/art/animation_resources_v6.md) · [JSON](ref/art/animation_resources_v6.json) | 사다리·계단·사격·부상·절단 이후 14개, 대표 클립명 34개, 동작 묶음 10개 |

### 이번에 추가한 6판 항목

| 자원 | 필요한 부분 |
|---|---|
| [MoCap Online — LADDER](ref/art/animation_resources_v6.md#mco_ladder) | 역 설비·객차 접근 사다리의 진입, 오르내리기, 정지, 방향 전환, 이탈. |
| [Motionbeats — Action Adventure Stairs and Slope](ref/art/animation_resources_v6.md#motionbeats_stairs_slopes) | 역 계단·승강장 단차·경사로에서 올라감/내려감과 시작/정지/회전. |
| [KayKit — Character Animations](ref/art/animation_resources_v6.md#kaykit_character_animations) | 이동·기어가기·웅크리기·피격·사망과 한손/양손 원거리·활·도구 동작의 저비용 기반. |
| [Kubold — Rifle Animset Pro](ref/art/animation_resources_v6.md#kubold_rifle_animset) | 조준·발사·재장전·이동과 방향별 피격·사망의 연결. |
| [Kubold — Pistol Animset Pro](ref/art/animation_resources_v6.md#kubold_pistol_animset) | 권총 조준·이동·발사·재장전·피격을 비교. |
| [Kubold — Cover Rifle Animset Pro](ref/art/animation_resources_v6.md#kubold_cover_rifle) | 역 기둥·상자·객차 옆에서 엄폐 진입, 노출 사격, 복귀, 재장전. |
| [KaidoomDev — Pump-Action shotgun Character Animation Pack](ref/art/animation_resources_v6.md#kaidoom_pump_shotgun) | 산탄총 캐릭터 동작과 무기 작동·부분 재장전의 시각적 연결. |
| [Ailive — Injury Animation Pack](ref/art/animation_resources_v6.md#ailive_injury) | 다친 다리, 다친 팔, 목발 보행 상태를 분리해 비교. |
| [Raise Creation — Combat Injured Animation Pack](ref/art/animation_resources_v6.md#raise_combat_injured) | 다리 끌기, 무릎/바닥 자세 전환, 부축 진입·걷기·이탈을 연결. |
| [Studio Ochi — Low Poly Disabled People Animated & Rigged](ref/art/animation_resources_v6.md#ochi_mobility_animations) | 지팡이·목발·보행기·휠체어와 몸의 접촉을 살펴볼 후보. |
| [IKFootPlacement — plonkabartosz](ref/art/animation_resources_v6.md#ik_footplacement) | 계단/경사에서 발의 위치와 방향을 맞추는 구현 참고. |
| [LimbHacker — JoeCooper](ref/art/animation_resources_v6.md#limbhacker) | 스킨드 메시·여러 렌더러·분리 뒤 래그돌 연결의 문제를 조사. |
| [Unity — Animation Layers / Avatar Mask](ref/art/animation_resources_v6.md#unity_animation_layers_masks) | 다친 하체 이동과 상체 조준·재장전의 적용 범위를 나누는 후보. |
| [Unity — Animator.MatchTarget](ref/art/animation_resources_v6.md#unity_target_matching) | 사다리 첫 발판·문턱·소품에 몸의 기준점이 닿도록 진입 동작을 정렬. |

[WATCH] 저장된 것은 작성한 조사 문서·출처 주소·메타데이터·검사 도구다. 원작 게임 자산, 외부 유료 팩, 모션·음원 원본, 도면 PDF를 이 저장소에 추가하지 않았다. 구매·다운로드·설치·Blender/Unity 실행·음원 청취·모바일 성능 검증은 이번 범위 밖이다.

검사: `python ref/art/build_research_index.py --check` · `python ref/art/validate_catalog.py` · `python -m unittest discover -s ref/art -p 'test_*.py' -v`
<!-- APP_3D_RESEARCH_INDEX_END -->
