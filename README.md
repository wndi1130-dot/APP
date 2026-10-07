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

조사 항목 **62개**: 2판 37개 + 3판 17개 + 4판 8개. 공급자 수나 확보한 파일 수가 아니며, 도구·서비스·기법·개별 자산을 포함한다. 프로젝트 적용은 미검증이다.

| 순서 | 자료 | 내용 |
|---|---|---|
| 1 | [현재 아트 기준](docs/art/production_brief.md) · [조사 지시서](docs/handoff/3d_research_tasks.md) | 비픽셀 월드·UI 분리와 작업 범위 |
| 2 | [전체 자원 목록](ref/art/README.md) | 분야·용도·출처·미확인 상태로 검색 |
| 3 | [제작 자원 2판](ref/art/production_resources.md) · [JSON](ref/art/resource_index.json) | 기반 도구·리그·소품·재질·셰이더 37개, 별도 제외 3개 |
| 4 | [작품별 보충 3판](ref/art/game_reference_resources_v3.md) · [JSON](ref/art/game_reference_resources_v3.json) | This War of Mine·Frostpunk 1·2·Metro 제작자 자료 6개, 후보 17개, 장면 검증안 6개 |
| 5 | [빠진 자원 보충 4판](ref/art/production_gap_resources_v4.md) · [JSON](ref/art/production_gap_resources_v4.json) | 작업·구조 모션, 철도 음향, 의복/소품/경로 제작 8개, 재확인 1건, 자료 경로 2건 |

### 이번에 추가한 4판 항목

| 자원 | 필요한 부분 |
|---|---|
| [MoCap Central — Fix & Build](ref/art/production_gap_resources_v4.md#mcc_fix_build) | 삽질·렌치·탁상 정비·설계도 확인 동작의 조달 후보. |
| [Reallusion — Injury & Rescue](ref/art/production_gap_resources_v4.md#reallusion_injury_rescue) | 부상자 부축·업거나 들기·들것 운반·구호물자 전달 비교. |
| [Freesound 125211 — keithpeter의 증기열차 출발 녹음](ref/art/production_gap_resources_v4.md#audio_train_departure_125211) | 출발 순간의 증기·급탄·기적·차륜 소리 층을 비교할 재료. |
| [Freesound 686058 — relwin의 기관차 기적](ref/art/production_gap_resources_v4.md#audio_loco_whistle_686058) | 열차 출발 신호의 실제 기관차 기적 후보. |
| [Evocative Sound and Visuals — American Steam Trains](ref/art/production_gap_resources_v4.md#evocative_american_steam) | 화실 급탄·증기 방출·근접/원경 주행·정비 소리의 수급 후보. |
| [MPFB — MakeClothes 의복 제작 절차](ref/art/production_gap_resources_v4.md#mpfb_makeclothes_workflow) | 긴 방한 외투를 찾지 못했을 때 자체 의복을 같은 몸체에 맞추는 대안. |
| [Blender 4.5 — Child Of 제약과 소품 인계](ref/art/production_gap_resources_v4.md#blender_child_of_handoffs) | 삽을 집고 내려놓기, 물자 건네기, 들것 손잡이와 인물의 관계를 제작할 때 참고. |
| [Unity Splines — 경로와 Spline Animate](ref/art/production_gap_resources_v4.md#unity_spline_train_path) | 곡선 위 열차 전경·카메라 이동·선로 주변 반복 배치의 후순위 비교. |

[WATCH] 저장된 것은 작성한 조사 문서·출처 주소·메타데이터·검사 도구다. 원작 게임 자산, 외부 유료 팩, 모션·음원 원본, 도면 PDF를 이 저장소에 추가하지 않았다. 구매·다운로드·설치·Blender/Unity 실행·음원 청취·모바일 성능 검증은 이번 범위 밖이다.

검사: `python ref/art/build_research_index.py --check` · `python ref/art/validate_catalog.py` · `python -m unittest discover -s ref/art -p 'test_*.py' -v`
<!-- APP_3D_RESEARCH_INDEX_END -->
