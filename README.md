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
- [docs/art/image_prompts.md](docs/art/image_prompts.md): 아트 방향과 이미지 프롬프트 1차(화면 시안, 아이콘, 문장, 초상), 폰트 후보
- [docs/research/gap_fill.md](docs/research/gap_fill.md): ref/ 자료의 '미확인' 보충 조사(증기기관차 소비·점화·제설, 피난민 이름 표기)

<!-- APP_UI_MOTION_RESEARCH_BEGIN -->
## UI 애니메이션·연출·사운드 레퍼런스

**[자료 입구: ref/ui_motion/README.md](ref/ui_motion/README.md)** — Frostpunk 1·2와 This War of Mine의 잉크·목탄·기름 표현, 정치/연구/버튼 전환과 음향을 정리했다.

| 읽을 자료 | 내용 |
|---|---|
| [원작별 근거](ref/ui_motion/original_games.md) | 법률서·Council·Idea Tree·일반 창의 사용 상황과 확인된 제작 방식 |
| [상황별 매핑](ref/ui_motion/event_matrix.md) | 우리 게임 이벤트 24개, 소리 의도 20개, 연타·취소·동작 감소 제안 |
| [구현 후보](ref/ui_motion/implementation.md) | 국소 마스크/노이즈와 큰 화면 합성, S1 웹·Unity 경로 구분 |
| [사운드 설계](ref/ui_motion/sound_design.md) | 제작팀 설명·독립 분석·자체 제안을 분리하고 재생 상황을 기록 |
| [출처 장부](ref/ui_motion/sources.md) · [JSON](ref/ui_motion/sources.json) | 37개 자료 항목의 저자·URL·권리·열람 수준·미확인 사항 |
| [영상·청취 확인표](ref/ui_motion/capture_checklist.md) | 저자가 제시한 구간 5개, 아직 직접 관찰하지 못한 원작 상황 6개 |
| [후속 작업자 인계](ref/ui_motion/handoff.md) | 기존 배치·게임 판정·최신 색 의미를 보존하는 적용 규격 |

**[WATCH] 자료 37개는 영상 시청 수·원본 에셋 확보 수가 아니다.** 문서·전사·챕터를 읽었으며 직접 영상 재생/음원 청취, 원작 프레임 시간 측정, 설치·게임 구현은 하지 않았다. 이벤트별 ms와 음색 조합은 원작 수치가 아닌 프로젝트 제안이다. 원작 영상·음원·이미지·아트북은 복제하지 않고 출처와 작성한 요약을 남겼다.

최신 main `20a2728`에서 분리한 UI 연구다. 기존 3D 자원 연구 [PR #12](https://github.com/wndi1130-dot/APP/pull/12)와 별도 관리하며 해당 PR을 병합한 것이 아니다. 비픽셀 월드/홈, 하늘색은 지지에만 사용, 고철·목재 분리 재고를 묶어 표시하는 최신 결정을 유지한다.

검사: `python ref/ui_motion/validate_research.py` · `python -m unittest discover -s ref/ui_motion -p 'test_*.py' -v`. 실행 기록: [validation.json](ref/ui_motion/validation.json).
<!-- APP_UI_MOTION_RESEARCH_END -->
