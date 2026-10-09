# 새 세션 시작 안내

작성: 2026-10-06 · 고침: 2026-10-09 · 새 Claude 세션(Opus, Fable 등)이 가장 먼저 읽는 문서다.

지금 무엇이 어디에 있는지는 [개발 현황 핸드북](../handbook/README.md)에 더 자세히 있다. 다른 계정의 프로젝트에서 이어 가는 첫 세션이면 [핸드북의 옮기기 절](../handbook/working.md#다른-계정-프로젝트로-옮길-때)부터 본다.

## 지금 단계

- 1단계 S1a(정치 거래)는 끝났다. 사용자가 관문 H1(정치 거래가 잡무가 아니라 재미있는가)을 통과시켰다(2026-10-07). 플레이 빌드는 웹 v22이고 코드는 모두 main에 있다(PR 20·45·46 등).
- S1b 어두운 길, S1c 내정, S2 필드 회색 상자를 나란히 만들고 있다.
  - S1b: 핵심 묶음 코드가 main에 있고 판에서는 기본 꺼짐. 켜기 전 필수 셋(PR 46)과 높음 둘(K02 3·4, 정차 암살 목격자·영수증 줄, 증거 단계별 벌 반응)을 고쳤다. 중간·낮음이 남았다. 관문 H7.
  - S1c: 기능 플래그로 코드가 들어갔다(메뉴 '내정 켠 새 판'). 사용자가 H6를 판정할 차례다.
  - S2: Godot 4.7.2 술레후프 역 회색 상자. 빌드 47(관성 무거움 기본, K03 고침과 부위별 상처 모델 포함)로 사용자가 H3를 판정할 차례다.
- 엔진은 갤럭시 S22 성능 시험을 통과해 Godot 4.7.2를 쓴다. 그림은 전부 실시간 3D다.
- 캠페인 정차 표는 확정했다(2026-10-08). 실제 이름 14곳, 나머지는 이름 없는 생성 역, 신호 지점은 지어낸 송신소다(first_leg_story 8.1~8.3).
- 2026-10-08에 모든 스레드가 마무리 요약을 남기고 한 번 멈췄다. 그 뒤 새로 정한 것은 없다.

## 최근 정한 것 (자세한 건 decisions.md)

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
6. 주제별 브리프([docs/design/briefs/](../design/briefs/)): 어두운 길 [s1b_dark_path.md](../design/briefs/s1b_dark_path.md), 내정 [s1c_domestic.md](../design/briefs/s1c_domestic.md), 필드 [field_unified.md](../design/briefs/field_unified.md)와 [s2_station.md](../design/briefs/s2_station.md), 이야기 [first_leg_story.md](../design/briefs/first_leg_story.md), 정치 디테일 [politics_detail.md](../design/briefs/politics_detail.md), UI 연출 [presentation_motion.md](../design/briefs/presentation_motion.md), 소리 [sound_music.md](../design/briefs/sound_music.md), 열차장 [character_creation.md](../design/briefs/character_creation.md), 엔진 [engine.md](../design/briefs/engine.md).
7. 아트를 다룰 때: [docs/art/reference_analysis.md](../art/reference_analysis.md), 시안 기록 [concept_renders_20261007.md](../art/concept_renders_20261007.md)와 [model_renders_20261007.md](../art/model_renders_20261007.md).
8. 필요할 때: [docs/research/](../research/), [ref/](../../ref/), 바깥 점검 [docs/design/review/](../design/review/), 다른 모델에 맡긴 일의 기록 [docs/handoff/](.).

## 다음 할 일

장기 목표(게임 완성까지의 단계와 관문)는 [coordinator_goal.md](coordinator_goal.md)에 있다. 순서와 세부는 [핸드북 '다음 할 일'](../handbook/README.md#다음-할-일)을 따른다.

1. **사용자 판정 받기**: H3(S2 빌드 47, 점검표 공유 폴더 `s2_play/checklist.md`), H6(S1 플레이 빌드의 '내정 켠 새 판', 점검표는 공유 폴더 `s1c_play/h6_checklist.md`). 피드백으로 S2와 S1c를 고친다. S2의 K03 높음 9개는 10-09에 고쳤다(PR 62, 69). 남은 K03 중간(도달 못 하는 조사 목표, 기적보다 먼저 뜨는 결과 화면, 소수 자원 반올림, 반복 할당)은 S2 스레드 몫이다.
2. **S1a 코드**: 이름 풀 정리(원 통계 사본은 PC에서 찾음), S1b 켜기 전 남은 중간·낮음(K02 6~11), 내정 버그 목록의 남은 것(J10 10·12, 늙은 장인 아크 N1, 배관 추인 N2. 목록은 공유 폴더 `s1c_handoff/s1a_bugs_20261008.md`). K01 중간 넷은 고쳤다.
3. **내정 재측정**: 내정 버그 목록이 고쳐지면 4000판으로 다시 잰다(완주율, 꼬리칸 이 카드 몫, 장인 아크 카운트다운). 2026-10-09 기준값은 돌보는 정책 S1a 43.4%, 내정 켠 판 36.7%, 꼬리칸 이 카드 몫 22%. 온실 값(4.3 식 하나로)과 복원 비용 대조(값 어긋남 없음)는 끝냈다.
4. **S1b**: TS 4,000판 시뮬은 돌렸다(16.1 8차, 2026-10-09). 사용자 H7 플레이 점검표는 공유 폴더 `s1b_play/checklist.md`. 경비가 막아도 불씨가 오르게 할지 사용자 카드 대기. 계엄 묶음은 [briefs/s1b_martial_impl.md](../design/briefs/s1b_martial_impl.md)대로 PR A(계엄·경비대 재판)부터 짠다. 'S1 코드 마무리'의 PR이 합쳐진 뒤 main에서 맞춘다.
5. **이야기**: 라이프치히 뒤 1~3막 큰 틀은 [briefs/campaign_story.md](../design/briefs/campaign_story.md)(2026-10-09, 제안). 사용자 카드 둘(1막 큰 희생 안 셋, 끝 갈래)이 대기다. 그다음은 사용자 답으로 3.11을 채우고, 2막 역 순서 지도 대조와 뤼겐 목적지 조사를 로컬 워커에게 맡긴다.
   - 막마다 계절 상태와 지역 띠를 정차 자리에 붙인다([briefs/seasons_regions.md](../design/briefs/seasons_regions.md) 2.2·5.2). 사용자 카드 넷(공유 폴더 `decision_cards/seasons.md`) 가운데 오브젝트 변형 방식이 급하다(트리포 주문에 눈을 굽지 않기).
6. **바깥 검수 정리**: K03~K06 교차 확인, Codex 점검 넷 결과를 주인 스레드로.
7. 관문을 넘으면 **S3**: 정치 로직을 GDScript로 옮기고 술레후프 정차 한 번을 왕복한다.

## 작업 방식

- 한국어 반말로, 짧게, 비판적인 협업 파트너로 답한다. 불확실한 것은 불확실하다고 적는다.
- 새로 정한 것은 decisions.md에 반영한다. 확정과 제안을 구분한다. 단계를 마치면 이 문서의 '다음 할 일'과 핸드북을 고친다.
- 설계 문서는 main에 바로 올려도 된다. 코드는 브랜치와 PR로 올리고, 테스트와 빌드가 통과한 것만 합친다.
- 저장소는 공개다. 대본, 아트북, 남의 게임 화면 같은 저작물, 시안 그림, 모델 답 원문, 비밀 키는 올리지 않는다(GEMINI_API_KEY는 환경 변수로만). 커밋 작성자 주소는 noreply 주소만 쓰고 개인 이메일은 쓰지 않는다.
- 민감한 역사 금지선은 프로젝트 지침에 전문이 있다. 글, 그림 주문, 소리, 움직임, 조사, 게임 데이터, 외부 모델 의뢰에 모두 적용하고, 장소 목록은 저장소에 옮기지 않는다.
- 새 웹 조사는 클라우드 세션이 직접 하지 않고 사용자 PC의 로컬 워커에게 맡긴다. 맡기기 전에 저장소의 조사 가지(research/…)에 이미 있는지 먼저 본다.
- 클라우드 환경은 npm과 pypi만 열려 있어 Godot을 내려받지 못한다. Godot 빌드와 테스트는 GitHub Actions에서 돈다.
