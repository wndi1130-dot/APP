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
