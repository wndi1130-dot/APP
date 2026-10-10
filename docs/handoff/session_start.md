# 새 세션 시작 안내

작성: 2026-10-06 · 고침: 2026-10-10 · 새 세션이 가장 먼저 읽는 문서다.

지금 무엇이 어디에 있는지는 [개발 현황 핸드북](../handbook/README.md)에 더 자세히 있다. 2026-10-10부터 작업 자리가 claude.ai 프로젝트에서 사용자 PC의 로컬 세션으로 옮겨졌다. 일하는 틀은 [핸드북의 '로컬에서 일하기'](../handbook/working.md#로컬에서-일하기-2026-10-10부터)를 본다. 핸드북의 '다른 계정 프로젝트로 옮길 때' 절은 클라우드 계정 사이를 옮긴 10-09의 기록이고 로컬 이전 절차가 아니다.

## 지금 단계

- 1단계 S1a(정치 거래)는 끝났다. 사용자가 관문 H1(정치 거래가 잡무가 아니라 재미있는가)을 통과시켰다(2026-10-07). 코드는 모두 main에 있다. 사용자가 마지막으로 해 본 플레이 빌드는 claude.ai 비공개 링크의 v10(main b042d12)이고, 그 링크는 로컬에서 고칠 수 없다. 앞으로 S1 판은 PC에서 띄워 폰으로 본다(2026-10-10 사용자 결정, [builds.md](../handbook/builds.md)).
- S1b 어두운 길, S1c 내정, S2 필드 회색 상자를 나란히 만들고 있다.
  - S1b: 핵심 묶음과 계엄 PR A(PR 87) 코드가 main에 있고 판에서는 기본 꺼짐. 켜기 전 고칠 것(K02 필수 셋·높음 둘·중간·낮음 여섯)은 다 고쳤다(PR 46·47·53). 시뮬레이션의 H7 줄은 붙었고(PR 58), 사용자 플레이 판정은 아직이다. 관문 H7.
  - S1c: 기능 플래그로 코드가 들어갔다(메뉴 '내정 켠 새 판'). **H6는 사용자 판정 '손질 필요'다(2026-10-10). 통과가 아니다.** 남은 손질은 콘텐츠 부족과 상징물 쓰임 둘이고, 손질한 판을 해 본 뒤 다시 판정한다.
  - S2: Godot 4.7.2 술레후프 역 회색 상자. 빌드 47로 H3 통과(2026-10-10). 판 의견 가운데 층 찾기(PR 103)와 조작 묶음(PR 108)은 고쳤고, 몸 그림 화면과 상태 아이콘이 남았다.
- 엔진은 갤럭시 S22 성능 시험을 통과해 Godot 4.7.2를 쓴다. 그림은 전부 실시간 3D다.
- 캠페인 정차 표는 확정했다(2026-10-08). 실제 이름 14곳, 나머지는 이름 없는 생성 역, 신호 지점은 지어낸 송신소다(first_leg_story 8.1~8.3). 라이프치히 뒤 1~3막 큰 틀은 [campaign_story.md](../design/briefs/campaign_story.md)에 있다(제안, 1막 큰 희생만 확정).
- 2026-10-08에 모든 스레드가 마무리 요약을 남기고 한 번 멈췄다. 그 뒤 10-09와 10-10에 결정과 병합이 이어졌다(아래 '최근 정한 것', PR 50번대~107).

## 최근 정한 것 (자세한 건 decisions.md)

- 10-10: H3 통과(빌드 47). H6는 '손질 필요'. '내정 켠 새 판'은 이동 사건 20장을 켠 채 시작한다(PR 109). S1 판은 PC에서 띄워 폰으로 본다. 작업 자리를 로컬 세션으로 옮겼다.
- 10-09: 1막 큰 희생은 '후위조'(자리 10, 고르는 절차의 세부는 금지선 점검이 한 번 더 본다). 노선 갈림길마다 어디로 갈지 고를 수 있게 한다(자리와 수는 제안). 경비가 막아도 불씨는 한 칸 오른다. 재난은 예고를 무시했을 때만 드물게 사람을 직접 죽인다. AI 음성은 주요 인물 대사에 쓰지 않고 군중 소리 재료로만 쓰며, 서비스는 베타 때 정한다. 계절 흐름·나라 범위·오브젝트 변형(맨 모델 + 엔진 층) 카드 셋. 트리포 맥스 한 달 구독으로 정적 소품을 만든다(결제는 사용자). 몸 관성은 무거움으로 확정.
- 10-08 아침 목록 30개와 카드 답: 몸 관성 무거움(0.2·0.25·0.4초), 위 띠는 선을 넘을 때와 크게 나빠질 때 모두 흔듦, 의회 외침은 AI 음성(결제는 사용자), 서막 약속을 어기면 신임 −4·꼬리칸 −10만, 열차장 몫을 꼬리칸으로 돌리는 단추, 캠페인은 1막만 무료, 유료판은 한 번 사는 해금만, 열차장은 털모자.
- 꼬리칸 연결기 카드는 위협만 둔다. 실제로 풀지 않고, 거절하면 파업이나 원한이며, 앞칸이 떼자는 안건은 없다.
- 캠페인 정차 거르기: '역에서 보이는 곳' 기준, '모름'은 지도로 다시, 일반 피해자 추모비도 걸림으로 셈. 1막 마지막 역은 Greiffenberg, 신호 지점은 '브란덴부르크 북동부'의 지어낸 옛 송신소.
- PC 옵시디언 위키의 이 게임 트랙은 세션 시작 회상에 등재하지 않는다.

## 읽는 순서

1. [docs/design/decisions.md](../design/decisions.md): 확정 사항, 검토 중인 제안, 열린 질문. 모든 논의의 출발점이다.
2. [docs/handbook/](../handbook/README.md): 지금 상태, 기다리는 것, 다음 할 일, 정할 것, 빌드 받는 법, 일하는 방식.
3. [docs/design/briefs/first_slice_scope.md](../design/briefs/first_slice_scope.md): 첫 검증판 S1 → S2 → S3의 범위와 관문.
4. [docs/prototype/s1_political_prototype.md](../prototype/s1_political_prototype.md): S1 기획서. 수치는 [briefs/s1a_politics_numbers.md](../design/briefs/s1a_politics_numbers.md). 규칙의 기준 구현은 `s1/src/game/`이다.
5. [docs/prototype/s1_content_guide.md](../prototype/s1_content_guide.md): 콘텐츠 가이드. 글 규격은 6장.
6. 주제별 브리프([docs/design/briefs/](../design/briefs/)): 어두운 길 [s1b_dark_path.md](../design/briefs/s1b_dark_path.md)와 계엄 [s1b_martial_impl.md](../design/briefs/s1b_martial_impl.md), 내정 [s1c_domestic.md](../design/briefs/s1c_domestic.md), 사건·재난 [events_disasters.md](../design/briefs/events_disasters.md), 필드 [field_unified.md](../design/briefs/field_unified.md)와 [s2_station.md](../design/briefs/s2_station.md), 이야기 [first_leg_story.md](../design/briefs/first_leg_story.md)와 [campaign_story.md](../design/briefs/campaign_story.md), 계절·지역 [seasons_regions.md](../design/briefs/seasons_regions.md), 정치 디테일 [politics_detail.md](../design/briefs/politics_detail.md), UI 연출 [presentation_motion.md](../design/briefs/presentation_motion.md), 상태 화면 [ui_states.md](../design/briefs/ui_states.md), 셰이더 [shaders.md](../design/briefs/shaders.md), 소리 [sound_music.md](../design/briefs/sound_music.md)·[ai_audio.md](../design/briefs/ai_audio.md)·[crowd_voices.md](../design/briefs/crowd_voices.md), 열차장 [character_creation.md](../design/briefs/character_creation.md), 엔진 [engine.md](../design/briefs/engine.md).
7. 아트를 다룰 때: [docs/art/reference_analysis.md](../art/reference_analysis.md), 시안 기록 [concept_renders_20261007.md](../art/concept_renders_20261007.md)와 [model_renders_20261007.md](../art/model_renders_20261007.md), 트리포 소품 기준 [tripo_pipeline.md](../art/tripo_pipeline.md).
8. 필요할 때: [docs/research/](../research/), [ref/](../../ref/), 바깥 점검 [docs/design/review/](../design/review/), 다른 모델에 맡긴 일의 기록 [docs/handoff/](.).

## 다음 할 일

장기 목표(게임 완성까지의 단계와 관문)는 [coordinator_goal.md](coordinator_goal.md)에 있다. 순서와 세부는 [핸드북 '다음 할 일'](../handbook/README.md#다음-할-일)을 따른다. 아래에서 '공유 폴더 `…`'로 적은 파일은 옛 클라우드 프로젝트의 공유 폴더에 있던 것으로, 지금은 저장소 밖 비공개 인계 묶음에 같은 상대 경로로 있다.

1. **H6 손질과 다시 판정**: 남은 손질 둘(콘텐츠 부족, 상징물 쓰임)을 고치고, 손질한 판을 PC에서 띄워 폰으로 보여 준다. '내정 켠 새 판'은 이동 사건 20장을 켠 채 시작하고 메뉴의 '사건 끈 새 판'으로 끈 판과 비교할 수 있다(PR 109). 끝 화면의 내정 기록은 단추로 복사한다(PR 111). 상징물 쓰임 손질로 가진 상징물을 칸에 걸어 두는 규칙이 들어갔다(PR 116, 수치는 제안). 사용자 의견 가운데 설명(노출·상징물·정보), 수색 문장 순서, 거래로 안 넘어오는 반대 표, 내정 반복 줄이기는 이미 main에 있다(PR 91·96·106). 점검표는 공유 폴더 `s1c_play/h6_checklist.md`. 사건을 켠 판은 끝 긴장이 오르는데 원인을 재는 중이고, 숫자 손질은 결과를 보고 따로 묻는다.
2. **S1 코드**: 이름 풀 정리는 가지에서 하고 있고 PR은 H6 통과 뒤에 연다. S1b 켜기 전 중간·낮음(K02 6~11)은 PR 53, 늙은 장인 아크 N1과 배관 추인 N2는 PR 60·97로 고쳤다. 내정 버그 목록(공유 폴더 `s1c_handoff/s1a_bugs_20261008.md`)의 J10 10(기술 축)·12(열차장 직업)는 S1 코드에 축과 직업이 없어 남겨 두었다(PR 35).
3. **내정 재측정**: 4000판으로 다시 잰다(완주율, 꼬리칸 이 카드 몫, 장인 아크 카운트다운). 2026-10-09 기준값은 돌보는 정책 S1a 43.4%, 내정 켠 판 36.7%, 꼬리칸 이 카드 몫 22%인데, 그 뒤 PR 96·97·106이 들어가 기준값부터 다시 재야 비교가 된다. 온실 값(4.3 식 하나로)과 복원 비용 대조(값 어긋남 없음)는 끝냈다(PR 57).
4. **S1b**: TS 4,000판 시뮬(16.1 8차·9차, 2026-10-09). 계엄 PR A(문 1, 계엄 회기, 쿠데타, 거두기·추인, 경비대 재판, 시험 시작 상태 `?s1b=1&scene=powers|martial`)는 합쳤다(PR 87, [briefs/s1b_martial_impl.md](../design/briefs/s1b_martial_impl.md) 8장). 남은 것: 사용자 H7 판정(점검표는 공유 폴더 `s1b_play/checklist.md`), 그 뒤 PR B(문 2·3·4, 내전), 비상대권이 안 열리는 병목(H7 뒤 사용자 결정), 거둔 계엄의 완주가 높은 까닭 확인. 위기 길이는 아직 못 쟀다.
5. **S2**: 몸 그림 화면과 상태 아이콘을 만들고, H3 의견을 고친 빌드(조작 묶음 PR 108 포함)를 사용자가 확인한다. K03 높음 9개와 리뷰 지적은 고쳤다(PR 62·69·100·105). 남은 K03 중간(도달 못 하는 조사 목표, 기적보다 먼저 뜨는 결과 화면, 소수 자원 반올림, 반복 할당)이 있다. 셰이더는 필드에 이었다(PR 73·81·88·94).
6. **이야기**: 1막 큰 희생은 후위조로 정해졌다(decisions.md 확정 사항 '세계관', campaign_story 3.11). 남은 사용자 카드는 캠페인의 끝 갈래 하나이고 3막 전에 묻는다. 2막 역 순서 지도 대조와 뤼겐 목적지 조사는 워커에게 맡긴다(장소가 얽힌 조사는 금지선을 먼저 대조한다).
   - 막마다 계절 상태와 지역 띠를 정차 자리에 붙인다([briefs/seasons_regions.md](../design/briefs/seasons_regions.md) 2.2·5.2). 계절 카드 가운데 셋(계절 흐름, 나라 범위, 오브젝트 변형)은 확정했고, 밤 정차 '기다린다/들어간다'는 S3 전에 묻는다.
7. **바깥 검수 정리**: 금지선 표 K05와 문서 충돌 K06의 문서 몫은 고쳤다(PR 59·61·64·65·80·85·104). K03~K06을 다른 모델로 교차 확인하는 일은 아직이다.
8. 관문을 넘으면 **S3**: 정치 로직을 GDScript로 옮기고 술레후프 정차 한 번을 왕복한다. 본 이식은 H6 통과 뒤다.

## 작업 방식

- 한국어 반말로, 짧게, 비판적인 협업 파트너로 답한다. 불확실한 것은 불확실하다고 적는다.
- 새로 정한 것은 decisions.md에 반영한다. 확정과 제안을 구분한다. 단계를 마치면 이 문서의 '다음 할 일'과 핸드북을 고친다.
- 설계 문서는 main에 바로 올려도 된다. 코드는 브랜치와 PR로 올리고, 테스트와 빌드가 통과한 것만 합친다. CI가 초록이면 PR을 연 세션이 직접 합친다.
- 저장소는 공개다. 대본, 아트북, 남의 게임 화면 같은 저작물, 시안 그림, 모델 답 원문, 비밀 키, PC 경로, 개인 정보는 올리지 않는다(GEMINI_API_KEY는 환경 변수로만). 커밋 작성자 주소는 noreply 주소만 쓰고 개인 이메일은 쓰지 않는다.
- 민감한 역사 금지선은 프로젝트 지침에 전문이 있다(저장소 밖). 글, 그림 주문, 소리, 움직임, 조사, 게임 데이터, 외부 모델 의뢰에 모두 적용하고, 장소 목록은 저장소에 옮기지 않는다.
- 로컬에서는 코디네이터 세션 하나가 일을 줄기로 나누고, 줄기마다 워크트리 작업 세션이 맡는다. 줄기의 목표와 진행은 저장소 밖 줄기 파일로 주고받는다. 여러 줄기가 함께 건드리는 파일(s1의 politics.ts·data.ts·turn.ts·dark/, s2의 field_hud.gd·field_combat.gd)은 열린 PR을 먼저 보고 PR 하나씩만 연다.
- 새 조사를 맡기기 전에 저장소의 조사 가지(research/…)에 이미 있는지 먼저 본다.
- Godot 테스트(GUT)는 PC에서도 돌릴 수 있다. 폰에 까는 APK는 GitHub Actions가 만든다.
