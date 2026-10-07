# 새 세션 시작 안내

작성: 2026-10-06 · 새 Claude 세션(Opus, Fable 등)이 가장 먼저 읽는 문서다.

## 지금 단계

- 설계 논의와 첫 검증판 S1(정치 텍스트 프로토타입) 준비 단계다.
- s1/에 S1 코드가 있다: 콘텐츠 검사기(A1), 핵심 로직(A2), 프로필 200명 생성기(A3), Gemini 문장 생성(A5), S1a 화면 뼈대(A4).
- ref/에 레퍼런스 자료가 있다: 이름 풀(B1), 좀보이드 캐릭터 생성(B2), 증기기관차 운용(B3), 철도망(B4), 장소 유형(B5), 좋아하는 것·싫어하는 것(B6), 대사 레퍼런스(B7).
- 아트는 설계도(화면 배치, 기능, 아이콘의 뜻) 단계에서 멈췄다. 분위기 작업은 마감 단계에서 한다.
- 월드와 홈은 픽셀 아트가 아니라 좀보이드식 그래픽이다(2026-10-07). 아트를 다룰 때 [docs/art/reference_analysis.md](../art/reference_analysis.md)를 먼저 본다.

## 읽는 순서

1. [docs/design/decisions.md](../design/decisions.md): 확정 사항, 검토 중인 제안, 열린 질문. 모든 논의의 출발점이다.
2. [docs/prototype/s1_political_prototype.md](../prototype/s1_political_prototype.md): S1 기획서(S1a 거래, S1b 어두운 길, S1c 내정).
3. [docs/prototype/s1_content_guide.md](../prototype/s1_content_guide.md): 콘텐츠 가이드(스키마, 문체, 캐릭터 바이블).
4. [docs/handoff/codex_review.md](codex_review.md): 지금까지 코드와 레퍼런스 작업의 기록.
5. 아트를 다룰 때: [docs/art/image_prompts.md](../art/image_prompts.md)(방향, 시안 평가, '멈춘 곳'). 시안 그림은 docs/art/mockups/에 있다.
6. 필요할 때: [docs/research/gap_fill.md](../research/gap_fill.md)(증기기관차·이름 보충 조사), [docs/research/프로스트펑크2 정치 시스템 분석.md](../research/프로스트펑크2%20정치%20시스템%20분석.md), [docs/design/briefs/](../design/briefs/), [ref/](../../ref/).

## 다음 할 일

1. **S1a 정치 콘텐츠와 수치**(다음 설계 주제, 2026-10-06 결정): 법 15~20개, 사건 카드 40~60장, 인물 11~13명과 비밀, 시작 수치, AI 지도자의 판단, 거래, 기관실 파업 규칙. decisions.md 열린 질문 1.
2. 그다음: 열차장 캐릭터 생성과 사람의 능력(열린 질문 2), 필드(파밍) 상세(열린 질문 3).
3. 보류: 아트 작업(image_prompts.md '멈춘 곳'), 열린 질문 8(사치품), 9(초상화 범위), 10(UI 그림 방식과 긴장 아이콘).

## 작업 방식

- 한국어 반말로, 비판적인 협업 파트너로 답한다. 불확실한 것은 불확실하다고 적는다.
- 새로 정한 것은 decisions.md에 반영한다. 확정과 제안을 구분한다.
- 저장소는 공개다. 대본, 아트북 같은 저작물은 올리지 않는다. 비밀 키는 커밋하지 않는다(GEMINI_API_KEY는 환경 변수로만).
- 큰 코드 작업은 웹 모델에 지시서로 맡길 수 있다. 지시서와 검토 기록은 docs/handoff/에 있다.
