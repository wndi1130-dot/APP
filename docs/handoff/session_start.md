# 새 세션 시작 안내

작성: 2026-10-06 · 고침: 2026-10-07 · 새 Claude 세션(Opus, Fable 등)이 가장 먼저 읽는 문서다.

## 지금 단계

- 1단계(S1a 정치)의 끝이다. 플레이 빌드가 PR 20에 있고, 사용자가 직접 해 보고 관문 H1(정치 거래가 잡무가 아니라 재미있는가)을 판정한다. S1b와 S1c 코드는 그 판정 뒤에 시작한다.
- 그사이 나란히 하는 일(2026-10-07): S2 첫 일인 Godot 폰 성능 시험(PR 22), 3D 모델 시안, 열차장 만들기와 사람의 능력(열린 질문 2), 내정 S1c 설계(문서만), 필드 장소 상세와 S2 회색 상자 역(술레후프) 설계.
- s1/에 S1 코드가 있다: 콘텐츠 검사기(A1), 핵심 로직(A2), 프로필 200명 생성기(A3), Gemini 문장 생성(A5), S1a 화면(A4, PR 20에서 플레이 빌드로 바뀐다).
- ref/에 레퍼런스 자료가 있다: 이름 풀(B1), 좀보이드 캐릭터 생성(B2), 증기기관차 운용(B3), 철도망(B4), 장소 유형(B5), 좋아하는 것·싫어하는 것(B6), 대사 레퍼런스(B7), 첫 구간 지도(ref/map/).

## 2026-10-07에 정한 것 (자세한 건 decisions.md)

- 엔진: Godot 4.7.2(GDScript). S2 첫 일은 폰 성능 시험이고, 갤럭시 S22에서 버티지 못하면 Unity 6으로 바꾼다. 정치는 S3 전까지 웹(TypeScript)에서 만들고 S3 시작 때 한 번 옮긴다. 그림은 열차, 칸 안, 사람, 좀비, 필드, 정차 장면 모두 실시간 3D다(2026-10-07 사용자). 성능 시험이 실패하면 3D 범위를 다시 고른다.
- 그림: 월드와 홈은 픽셀이 아니라 좀보이드식 그래픽이다. UI는 매끈한 두 재질(계기·단추는 법랑과 놋쇠, 서류는 종이)이고, 지나온 정차 수 대비 희생 비율만큼 낡는다. 아트를 다룰 때 [docs/art/reference_analysis.md](../art/reference_analysis.md)를 먼저 본다.
- 정차 연출: 단면으로 달리다 정차하면 끼익 소리와 로딩, 카메라가 옆면에서 약간 앞쪽으로 돌아 역을 보여 주고, 내리는 모습이 정치 상태에 따라 달라진 뒤 사선 탑뷰 필드로 넘어간다.
- 첫 구간(볼슈틴 → 라이프치히): 무한모드 첫 런과 캠페인이 함께 쓰는 서막이다. 출발은 망자가 와서 앞당겨지고, 필드 정차는 5곳, 라이프치히는 허브 장면이다.
- 음악: 열차 안에서 나는 음악(노래, 축음기, 라디오, 선전 방송)에 현악 중심 메인 악보를 얹는다.
- 수제 총 품질은 걸림이 아니라 조준 원과 닳는 속도에 걸린다.

## 읽는 순서

1. [docs/design/decisions.md](../design/decisions.md): 확정 사항, 검토 중인 제안, 열린 질문. 모든 논의의 출발점이다.
2. [docs/design/briefs/first_slice_scope.md](../design/briefs/first_slice_scope.md): 첫 검증판 S1 → S2 → S3의 범위.
3. [docs/prototype/s1_political_prototype.md](../prototype/s1_political_prototype.md): S1 기획서(S1a 거래, S1b 어두운 길, S1c 내정). 수치는 [briefs/s1a_politics_numbers.md](../design/briefs/s1a_politics_numbers.md).
4. [docs/prototype/s1_content_guide.md](../prototype/s1_content_guide.md): 콘텐츠 가이드(스키마, 문체, 캐릭터 바이블).
5. 주제별 브리프([docs/design/briefs/](../design/briefs/)): 엔진 [engine.md](../design/briefs/engine.md), 필드 [field_unified.md](../design/briefs/field_unified.md)와 [s2_station.md](../design/briefs/s2_station.md), 이야기 [first_leg_story.md](../design/briefs/first_leg_story.md), UI 연출 [presentation_motion.md](../design/briefs/presentation_motion.md), 소리 [sound_music.md](../design/briefs/sound_music.md), 열차장 [character_creation.md](../design/briefs/character_creation.md).
6. [docs/handoff/codex_review.md](codex_review.md): 지금까지 코드와 레퍼런스 작업의 기록. S2 지시서는 [s2_perf_spike.md](s2_perf_spike.md).
7. 아트를 다룰 때: [docs/art/reference_analysis.md](../art/reference_analysis.md), 시안 주문서 [concept_renders_20261007.md](../art/concept_renders_20261007.md)와 [model_renders_20261007.md](../art/model_renders_20261007.md). [image_prompts.md](../art/image_prompts.md)는 2026-10-06 픽셀 시안 기록이다.
8. 필요할 때: [docs/research/gap_fill.md](../research/gap_fill.md)(증기기관차·이름 보충 조사), [docs/research/프로스트펑크2 정치 시스템 분석.md](../research/프로스트펑크2%20정치%20시스템%20분석.md), [ref/](../../ref/).

## 다음 할 일

장기 목표(게임 완성까지의 단계와 관문)는 [coordinator_goal.md](coordinator_goal.md)에 있다.

1. **S1a 플레이와 H1 판정**(사용자): PR 20을 해 보고 통과하면 합친다. S1b와 S1c 코드가 이 답을 기다린다.
2. **폰 성능 시험**(PR 22): 사용자가 APK를 S22에 깔아 본다. Godot 유지 여부가 여기서 갈리고, 실패하면 3D 범위도 다시 본다.
3. 진행 중인 설계: 열차장 만들기(열린 질문 2), S1c 내정, 장소 상세와 S2 술레후프 역(열린 질문 3), 3D 모델 시안.
4. 보류: 열린 질문 7(법안 짧은 이름, 색, 띠의 의석 경계), 8(사치품), 9(초상화 범위), 긴장 아이콘.

## 작업 방식

- 한국어 반말로, 비판적인 협업 파트너로 답한다. 불확실한 것은 불확실하다고 적는다.
- 새로 정한 것은 decisions.md에 반영한다. 확정과 제안을 구분한다.
- 설계 문서는 main에 바로 올려도 된다. 코드는 브랜치와 PR로 올리고, 테스트와 빌드가 통과한 것만 합친다.
- 저장소는 공개다. 대본, 아트북, 남의 게임 화면 같은 저작물은 올리지 않는다. 시안 그림은 저장소가 아니라 프로젝트 파일이나 사용자 바탕화면에 둔다. 비밀 키는 커밋하지 않는다(GEMINI_API_KEY는 환경 변수로만).
- 새 웹 조사는 클라우드 세션이 직접 하지 않고, 사용자 PC의 로컬 워커에게 맡긴다. 맡기기 전에 저장소의 조사 브랜치(research/…)에 이미 있는지 먼저 본다.
- 클라우드 환경은 npm과 pypi만 열려 있어 Godot을 내려받지 못한다. Godot 빌드와 테스트는 GitHub Actions에서 돈다.
- 큰 코드 작업은 웹 모델에 지시서로 맡길 수 있다. 지시서와 검토 기록은 docs/handoff/에 있다.
