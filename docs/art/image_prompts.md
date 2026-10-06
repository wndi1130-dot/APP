# 현재 이미지 시안 지침과 프롬프트

갱신: 2026-10-07 · **월드는 픽셀 아트가 아니라 좀보이드식 그래픽이다.**

현재 작업은 조사·지시사항 정리다. 아래 프롬프트는 시안 제작을 별도로 지시받았을 때 사용한다. 문서를 열었다는 이유로 이미지·모델을 생성하거나 설치를 시작하지 않는다. 사용 가능 모델의 정확한 이름·버전은 실행 시 확인하며 과거에 적힌 모델명을 필수 의존성으로 사용하지 않는다.

## 1. 먼저 읽을 것

[공통 제작 기준](production_brief.md)과 [설계 결정](../design/decisions.md)을 읽는다. 2026-10-06의 원문·시안 평가·아이콘 뜻·보류 메모는 [과거 보관본](image_prompts_20261006_archived.md)에 있다. 보관본의 픽셀 격자/스프라이트 분할/폰트/옛 카드 배치는 현재 월드 지침이 아니다. `mockups/`의 파일은 삭제하지 않는다.

기존 시안의 활용 범위는 배치·아이콘의 의미·카메라 흐름이다. 과거 시안의 화풍을 전체 월드에 복제하지 않는다. UI·초상·폰트는 미확정 부분이 있어, 새로운 시안에서 고른 표현을 자동 확정하지 않는다.

## 2. 공통 시각 브리프

아래는 월드 장면 시안용 문구다. 실제 에셋의 메시·리그·내보내기 규격을 대신하지 않는다. 장면에 필요한 비율과 시점을 개별로 덧붙인다.

```text
Create a concept mockup for a mobile, landscape-oriented survival and political management game set around a steam train in a frozen Central Europe, during the sixth winter after a collapse.
The world should evoke Project Zomboid's readable oblique top-down presentation and grounded, modestly detailed forms. It is not a pixel-art world. Do not impose a uniform pixel grid, blocky pixel enlargement, a PSX filter, or toy-like proportions. Do not assume that referencing a game's appearance means copying its renderer or proprietary assets.
Use worn steel, wood, brick, glass and layered winter clothing, with cold, subdued surroundings and restrained warm light near heat sources. Modern-era ruins, radios, hospitals and industrial equipment are allowed when consistent with the setting; this is not a blanket medieval or Victorian world.
Show useful spatial relationships and readable silhouettes. Avoid glossy product-render styling, gratuitous detail, recognizable commercial logos, red-cross emblems and explicit bodily mutilation. Do not darken the scene so much that people, doors and routes become unreadable.
Keep world art, UI, portraits and typography as separate design decisions. Do not invent new resources or gameplay meters.
```

특정 기존 이미지를 편집할 때는 그 이미지가 실제 첨부/접근 가능한 경로에 있는지 먼저 확인한다. 없으면 새 이미지를 수정 대상이라고 꾸미지 않는다. 이미지 모델의 결과를 게임에서 사용 가능하다고 확정하지 않는다.

## 3. 홈 화면 — 가로 열차 단면

기존 홈 시안을 첨부했다면 **배치만** 참고한다고 명시한다. 필드의 사선 탑뷰와 홈의 가로 단면은 화면의 목적 차이지 전체 세계관/화풍의 전환이 아니다.

```text
Show a side cutaway of the train as the management home screen, with the rear cars to the left and the locomotive to the right. The train extends beyond the screen so cars can be explored horizontally. Show interiors and a small functional emblem above each car door.
Use the non-pixel world direction described above. If an old pixel mockup is attached, follow its layout and information hierarchy only, not its pixel treatment.
Do not permanently display warmth or crowding over every car. A selected car may open a compact contextual panel. Heating, rations, medicine and space use smooth levers with discrete detents and a semicircular gauge, not plus/minus buttons.
Place trust and tension at the top left, a red-discontent / grey-neutral / sky-blue-support strip at the top center, and existing resource icons at the top right. Keep the established bottom navigation positions. Add a small dossier stack on the left for pending decisions.
Use only a few short placeholder labels when essential; final Korean text is overlaid by the application. Treat the panel finish as a proposal, not a settled UI style.
```

## 4. 한눈에 보기 — 위에서 본 열차

```text
Show the train from above on the left side, arranged vertically with the locomotive at the top. Reveal the interior only where needed. Group cars of the same function, retain vertical scrolling, and provide a separate data-only view control for managing a train of twenty to thirty cars.
A selected car or group connects by a thin line to the information panel on the right. Keep the chosen car large enough to read on a phone. Use stepped levers and semicircular gauges for heating, rations and medicine, with short labels instead of unexplained icons.
Do not switch back to the old block-selector controls or force a pixel grid. Do not imply that this layout mockup proves the 3D camera transition or roof occlusion works in the engine.
```

## 5. 의회 — 정보 계약 유지

```text
Set the council in the dining car. Use a semicircular diagram of one hundred seats, grouped by community, with the current yes / required count and threshold marks at 51 and 67. Put the bill and its confirmed effects on the left, and the selected community's leader, seat count, cohesion and the five established trading actions on the right. Connect the selected wedge and its panel. Use a lever-shaped vote control and a visible exit.
Keep a physical ballot box and white/black voting stones as scene elements. Follow the public-versus-secret voting information rules; secret voting must not identify individual voters. Keep backgrounds subordinate to the readable controls. Do not assume that all one hundred seats require separately simulated 3D characters.
```

## 6. 결정 카드 — 왼쪽 절반

```text
Open a decision dossier from the small paper stack at the left of the home screen. The dossier occupies the left half, not the lower two thirds. The right half still shows the train and the car relevant to the decision.
Use a speaker portrait placeholder, brief dialogue and numbered choices. Show only confirmed current costs and political changes that are certain immediately on selection. Do not reveal later consequences, rumors or hidden outcomes. Do not add a hope meter or other resources that do not exist.
Use a witness symbol distinct from the public-vote eye symbol. The final portrait style remains a separate decision; an attached old portrait supplies identity/layout context, not mandatory pixel styling.
```

## 7. 아이콘·명판·초상

현재 유지할 것은 뜻이다. 석탄 수레·빵·알약과 약병·반지, 공개 투표의 눈, 목격자의 인물 실루엣, 비밀 투표함, 현장 조달의 손수레와 상자, 협박의 잠긴 서류철을 혼동하지 않게 한다. 장면 속 투표는 흰 돌/검은 돌이며, 아이콘의 단순화와 별개다. 구체 원형과 이미 고른 도안은 보관본 평가를 대조한다.

UI를 따로 요청받기 전까지 전세계와 같은 픽셀 크기·32×32·갈무리·특정 매끈한 폰트를 강제하지 않는다. 글자는 기본적으로 코드에서 얹는다. 다수 인물의 초상 범위는 열린 질문이며 200~300명 얼굴을 일괄 생성하는 지시로 확장하지 않는다.

투명 배경이 필요하면 alpha 포함을 요구한다. 투명이 불가능하면 별도 마스크/후처리 계획을 적고 배경이 남아 있다고 보고한다. **순검정 배경을 투명이라고 부르거나 석탄·외투의 검은 부분까지 일괄 제거하지 않는다.**

## 8. 시안 검수와 현재 보류

배치·아이콘 의미·어두운 환경 가독성·기존 자원 일치·정보 누출 여부를 먼저 본다. 모델링 가능성·애니메이션·엔진 동작·모바일 성능·원본 이용 권리는 별도 검사다. 미리보기는 실제 첨부/파일 경로로 전달한다.

남은 결정: UI 그림 방식과 긴장 아이콘, 초상화 범위, 법안 짧은 이름, 객차/공동체 색 등의 열린 질문. 이 문서는 그 결정을 몰래 채우지 않는다. 기성 자산을 찾는 일은 [자료 조사 2판](../../ref/art/production_resources.md)에서 계속하며, 실제 이미지 제작 재개는 현재 사용자 요청 범위로 정한다.
