# 바깥 눈 기획 점검 꾸러미 (2026-10-07)

작성: "기획 점검" 스레드. 로컬 워커(GPT Pro 웹, Codex 6.1 sol xh, 아스트라)에게 맡기는 점검 요청이다. 답은 워커조사 답 폴더에 두고, 정리본만 이 폴더(docs/design/review/)에 올린다.

저장소: https://github.com/wndi1130-dot/APP (main, 공개). 아래 경로는 모두 main 기준이다.

## 점검의 잣대

사용자가 지금까지 짚은 것들의 성격이 기준이다. 숫자 맞추기보다 "현실 같은가, 되풀이되지 않는가, 세계 안에서 읽히는가"를 본다.

1. **되풀이 금지.** 같은 사건, 같은 문장이 자주 나오면 감점이다. 프로스트펑크 1·2처럼 사건은 다시 나와도 상황(날씨, 장소, 누가 다쳤는지, 법, 지난 선택)에 따라 세부가 달라야 한다.
2. **게임식 표시보다 세계 안의 조짐.** "사망 가능성" 같은 줄 경고 대신 "입가에 피를 묻힌 까마귀들이 날아간다"처럼 보이고 들리는 것으로 알린다. 그래도 거짓말은 안 한다(조짐이 뜨면 그 일은 반드시 일어난다).
3. **선택지는 행동 설명이 아니라 열차장이 외치는 말.** 비용과 정치 변화는 그 밑 줄에.
4. **법을 안 정하면 예고 뒤 대가**(프로스트펑크 2식). 비상 소집.
5. **몸과 겨울의 디테일**(좀보이드): 추위, 젖음, 병, 위생, 냄새, 부상, 누더기 옷과 낡은 열차.
6. **사람의 무게**(This War of Mine): 죽음, 슬픔, 기억, 이름 있는 개인.
7. **결정을 만드는 사실성만 살리고, 기다림이나 노동만 만드는 부분은 추상화한다**(decisions.md의 사실성 원칙). 모바일 가로, 짧은 세션.

지켜야 할 선: 다른 게임 대사 원문은 짧은 인용만. 도난·암거래·소문·질병을 특정 민족·종교 집단과 엮지 않는다. 집단을 겨냥한 폭력과 홀로코스트 이송 열차·수용소는 조사도 묘사도 하지 않는다.

## 볼 문서

- 출발점: docs/handoff/session_start.md, docs/design/decisions.md
- 정치(S1a): docs/prototype/s1_political_prototype.md, docs/prototype/s1_content_guide.md, docs/design/briefs/s1a_politics_numbers.md, docs/design/briefs/politics_detail.md
- 내정(S1c): docs/design/briefs/s1c_domestic.md
- 필드: docs/design/briefs/field_unified.md, body_injury.md, survival_detail.md, places.md, s2_station.md, weapons.md, zombies.md, vehicles.md
- 사람: docs/design/briefs/character_creation.md, knowledge_system.md
- 이야기·세계: docs/design/briefs/first_leg_story.md, world_lore.md, europe_setting.md
- 연출: docs/design/briefs/presentation_motion.md, presentation_ui.md, sound_music.md
- 아트: docs/art/reference_analysis.md, docs/art/model_renders_20261007.md
- 이미 있는 조사(겹치지 않게): research/politics-events-20261007 가지의 docs/research/ 세 파일(프펑 사건 사슬, 비슷한 게임의 인간 사건, 겨울 열차 생활), docs/research/survival_sim_20261007.md, docs/research/dialogue_choice_forms_20261007.md

## 워커별 요청

### A. GPT Pro 웹: 전체 현실감 점검 (가장 먼저)

설계 전체를 프로젝트 좀보이드, 프로스트펑크 2(그리고 1), This War of Mine을 해 본 사람의 눈으로 읽고 답해 줘.

1. 플레이어가 15시간 동안 같은 것을 되풀이해 보게 될 곳은 어디인가? (사건 카드 40~60장, 정차 장면, 수색 경고 글, 의회 회기, 파견 결과, 일지 줄) 세 게임은 각각 어떻게 변주하는가(규칙 수준으로, 대사 원문 말고)?
2. 숫자, 게이지, 아이콘, 경고 줄로 알리고 있는 것 가운데 세계 안의 조짐(소리, 냄새, 사람의 말투, 짐승, 날씨, 물건의 낡음)으로 바꾸면 더 좋은 것 10개와 바꿀 모습.
3. 세 게임에 있는데 우리 설계에 빠진, "현실 같다"는 느낌을 크게 만드는 디테일 15개. 각각 어느 문서 어디에 붙일지, 새 법·새 숨은 수치·새 화면이 늘어나는지(늘어나면 PC판 후보) 함께.
4. 인과가 닫히지 않는 곳: 필드에서 생긴 일이 의회·일지·사람 관계로 돌아오지 않거나, 정치 결정이 필드에 아무 흔적을 안 남기는 곳.
5. 사람의 무게: 이름 있는 인물의 죽음, 아이, 가족, 슬픔이 숫자 하나로 끝나는 곳.
6. 이 설계가 재미없어질 가장 큰 위험 세 가지와 각각 고칠 안 두 개.

### B. Codex 6.1 sol xh: 문서끼리 어긋남과 순환 점검

1. 문서끼리 서로 다른 규칙이나 숫자(전에 나온 예: 숨긴 물림 규칙, 절단 확률 95%와 늘 성공). 파일:줄, 두 문장, 어느 쪽이 최신인지(git log 날짜).
2. decisions.md의 '확정 사항'과 브리프가 다른 곳.
3. 자원 순환(석탄·식량·물·약·온기·위생)이 한 구간 안에서 실제로 닫히는지. 무한히 쌓이거나 회복할 길이 없는 수치.
4. 확률 사건 가운데 "경고는 거짓말하지 않는다"(뜨면 반드시 일어남)와 맞지 않는 곳.
5. 한 구간에 플레이어가 하는 일(내정 10분 이하, 필드 약 20분)을 실제로 세어 볼 때 넘치는 곳.

### C. 아스트라: 그림이 세계 안 조짐을 담을 수 있는지

프로젝트 파일 art/concepts_20261007/의 C1, C3, C9와 art/models_20261007/의 M4 v6, M6 v4, M7b v5, M8 v2를 보고:

1. 정차 직후 "글 없이 주변을 보여 주는" 장면에서 위험 조짐(까마귀, 새 떼, 개 짖음 없음, 핏자국, 끌린 자국, 깨진 창, 연기)을 넣을 자리가 있는가. 장면마다 세 가지씩.
2. 사람과 열차가 충분히 낡고 누더기인가. 아직 말끔한 곳.
3. 조짐이 장소·날씨에 따라 달라지게 하려면 필요한 그림 조각(소품, 짐승, 날씨 층) 목록.
