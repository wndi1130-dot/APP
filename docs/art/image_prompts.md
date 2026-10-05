# 이미지 프롬프트 2차 (GPT 이미지 모델용)

작성: 2026-10-06 · 쓰는 곳: GPT-6의 이미지 모델 2.5 · 결과물은 대화에 올리면 설계 세션이 s1/public/art/에 넣고 화면에 붙인다.

## 방향 (2026-10-06 결정)

- 그림은 옆 스크롤 픽셀 아트로 한다. 사용자가 Kingdom Two Crowns를 참고로 뽑은 홈 시안이 기준 그림이다.
- 분위기는 그대로 프로스트펑크 2와 This War of Mine이다. 결정·대화 화면의 형식은 수저린을 참고한다.
- 화면에 설명 문장을 두지 않는다. 자원과 계기는 아이콘과 숫자로, 칸의 수치는 칸을 눌렀을 때만 보여 준다.
- 홈 화면 구성은 [decisions.md](../design/decisions.md) '화면과 연출'에 적었다.

## 홈 시안 평가 (2026-10-06, 사용자)

기준 그림(home_v2)을 보고 남긴 아쉬운 점이다. ①b와 ④ 프롬프트에 반영했다.

1. 칸 조절의 −/+ 단추가 마음에 들지 않는다. 프로스트펑크 2나 Claude Code의 추론 수준 고르기(낮음부터 최대까지 딱딱 끊기는 단계)처럼 단계 고르개로 바꾼다. 난방, 배급, 의약품도 같은 방식이다.
2. 열차는 지금도 좋지만, 폰에서 볼 것을 생각하면 조금 더 키운다.
3. 왼쪽 위 신임·긴장의 숫자(72, 28)만으로는 뜻이 읽히지 않는다. 숫자 옆에 짧은 눈금 막대를 붙이는 안을 ①b에서 시험한다.
4. 불만은 빨강, 지지는 파랑이나 하늘색으로 한다.
5. 자원 아이콘은 프로스트펑크 2의 자원 UI처럼 무엇인지 바로 읽혀야 한다. 지금 석탄은 석탄으로 안 보이고, 의약품 병은 총알처럼 보인다. 자원 아이콘만은 단색 대신 재료의 색을 살린다.
6. 사치품이 왜 있는지 모르겠다. 참고: S1 기획서에서 사치품은 뇌물 수단이고 앞칸이 바라는 물자다([s1_political_prototype.md](../prototype/s1_political_prototype.md) 거래 수단). 남길지는 따로 정한다([decisions.md](../design/decisions.md) 열린 질문).

## ①b 한눈에 보기 시안 평가 (2026-10-06, 사용자)

시안은 [mockups/overview_v1.webp](mockups/overview_v1.webp)다. 사용자가 표시한 판은 [mockups/overview_v1_notes.webp](mockups/overview_v1_notes.webp)다. 파란 선은 원하는 열차 폭, 빨간 선은 고른 칸과 오른쪽 창을 잇는 선, 갈색은 긴장 아이콘을 가리킨다. 다음에 ①b를 다시 뽑을 때 아래를 고친다.

좋은 점

- 단추를 누르면 카메라가 위로 올라가 열차를 왼쪽으로 옮기고 오른쪽에 창을 펼치는 흐름이 좋다(배틀필드 1의 재배치 화면처럼).
- 새 자원 아이콘(석탄 수레, 빵, 알약과 병, 반지)은 매우 좋다. 그대로 간다.
- 기관사 초상이 잘 나왔다.

고칠 점

1. 칸막이 단계 고르개 대신 레버로 한다. 손잡이를 밀면 단계마다 딱 걸리고, 움직임은 Claude Code의 추론 수준 고르기처럼 부드럽다. 레버 위에는 배의 기관 전령기 같은 반원 계기를 둔다. 낮은 단계로도 모자라지 않으면 바늘이 가운데(중립)에 머물고, 최대로 당겨도 모자라면 바늘이 빨간 왼쪽으로 쏠린다. 난방, 배급, 의약품 모두 같다.
2. 의약품 아래 두 아이콘(사람들, 방패)이 무엇인지 읽히지 않는다. 글자를 너무 걷어냈다. 프로스트펑크처럼 조절과 정책에는 짧은 이름표를 단다. 문장은 여전히 쓰지 않는다.
3. 고른 칸(예: 기관실)과 오른쪽 창을 선으로 잇는다.
4. 열차가 너무 작다. 지금보다 2~3배(표시한 파란 폭쯤) 크게 그리고, 위아래로 스크롤한다.
5. 신임(72)과 긴장(28)의 그림을 바꾼다. 특히 긴장은 반란자인지 불만인지 뜻이 읽히지 않는다.
6. 위에서 보는 목적은 칸이 20~30개로 늘어도 내정을 한눈에 보고 배치하는 것이다. 지금은 예쁘지만 쓰기에 부족하다.
   - 같은 종류의 칸을 묶는다(예: 꼬리칸 세 개를 한 묶음으로).
   - 한눈에 보기 단추 옆에 '수치만 보기' 단추를 둔다. 프로스트펑크에서 발전기를 누르면 온기만 보이는 화면처럼, 또는 발표 자료의 입체 그래프처럼 칸 묶음마다 수치를 크게 보여 주고 거기서 배치를 정한다.

설계 세션 메모 (제안, 결정 아님)

- 반원 계기의 바늘이 무엇을 재는지 정해야 한다. 제안: 그 칸 묶음의 필요량 대비 공급량. 가운데는 충분, 왼쪽 빨강은 부족, 오른쪽 호박색은 남음(낭비)이다. 필요량은 바깥 기온, 인원, 아픈 사람 수에 따라 바뀐다.
- 칸을 묶으면 설정도 묶음 단위가 된다. 묶음을 공동체 단위로 하면 배급과 난방이 곧 공동체 정치가 되어 의회와 이어진다. 기관실과 열차장실처럼 하나뿐인 칸만 따로 다룬다.
- 열차를 2~3배 키우면 한 화면에 들어오는 칸이 줄어 '한눈에'와 부딪힌다. 평소 위 시점은 크게 보여 주고, '수치만 보기'가 전체를 작게 보여 주는 두 단계로 나누면 둘 다 살릴 수 있다.
- 긴장 아이콘 후보: 불붙은 도화선, 끊어지려는 밧줄, 맞부딪친 두 주먹. 이름표(신임, 긴장)를 같이 달면 그림의 부담이 줄어든다.

## 쓰는 법

1. **기준 그림**은 사용자가 고른 홈 시안(픽셀 아트, 옆에서 본 열차)이다. ① 수정까지 마친 판을 [mockups/home_v2.webp](mockups/home_v2.webp)에 두었다(2026-10-06 확정).
2. ① 수정은 기준 그림을 첨부하고 글상자를 붙여 넣는다. 새로 그리는 게 아니라 고치라는 프롬프트다. 결과가 마음에 들면 그게 새 기준 그림이 된다.
3. ①b부터는 새 기준 그림을 첨부하고 글상자를 붙여 넣는다. 글상자 첫 문장이 "첨부한 그림과 같은 화풍으로"라는 뜻이다.
4. 아이콘과 명판은 한 장에 여러 개를 격자로 뽑는다. 자르는 건 설계 세션이 한다.
5. 투명 배경이 안 되면 순검정 배경으로 받는다.
6. 이 대화에는 완성된 그림만 올리고 번호(예: ④)를 같이 적는다.
7. 시안(①, ①b, ②, ③)은 배치와 분위기를 정하는 용도라 게임에 그대로 넣지 않는다. 글자는 깨져도 괜찮다.

### 주의

- **AI가 그린 픽셀 아트는 격자가 맞지 않는다.** 1차 시안에서도 연기 픽셀이 나무 픽셀보다 컸다. 게임에 넣는 그림은 설계 세션이 픽셀 격자를 맞추고 색 수를 줄여서 넣는다. 그래서 큰 그림 한 장보다 칸 하나, 아이콘 하나처럼 작게 나눠 뽑는 편이 낫다.
- **게임 이름은 프롬프트에 넣지 않았다.** 화풍은 첨부한 기준 그림에서 이어받는다. 이름을 넣으면 원작 자산과 너무 닮게 나올 수 있다.
- 이미지에 한글을 쓰게 하지 않는다. 글자는 게임 코드에서 아래 폰트로 얹는다.
- 의약품 아이콘에 붉은 십자를 쓰지 않는다. 적십자 표장은 법으로 보호된다.

## 폰트

픽셀 아트로 바뀌어서 1차에 찾은 프로스트펑크 2의 폰트(Barlow Condensed, Crimson Pro, Cormorant Garamond, [Game Font Library](https://www.gamefontlibrary.com/games/frostpunk-2) 기준, 미확인)는 화면과 어울리지 않는다. 매끈한 글자가 픽셀 그림 위에 뜨면 따로 노는 것처럼 보인다.

| 쓰임 | 추천 | 비고 |
|---|---|---|
| 숫자, 단추, 짧은 이름표 | 갈무리(Galmuri) | 한글 픽셀 폰트. [저장소](https://github.com/quiple/galmuri), OFL로 알고 있다(쓰기 전에 저장소의 라이선스를 다시 확인) |
| 일지, 대사, 카드 본문 | 갈무리11을 먼저 시험 | 폰에서 긴 글이 읽기 힘들면 본문만 Pretendard(OFL) 같은 깔끔한 고딕으로 바꾼다. 기기에서 직접 보고 정한다 |

## 공통 화풍

아래 글상자마다 이미 들어 있다. 문구를 고칠 때만 여기를 본다.

```text
Visual style: high-quality 2D pixel art for a side-scrolling mobile game about a steam train crossing a frozen Central Europe in the sixth winter after a collapse. The whole image uses one uniform pixel size: snow, smoke, trees, people and UI all sit on the same pixel grid, with crisp hard edges, no blur, no smooth gradients and no mixed resolutions. Limited palette with careful dithering: deep blue and violet snow, black pine forests, a faint orange-pink band on the horizon, and warm amber window light and firebox glow as the only saturated accents; reflections on dark water and ice. Several parallax layers of landscape. Quiet, grim and humane rather than heroic. UI: dark navy panels with thin brass borders and angled corners, cream-white pixel icons, condensed pixel numerals, almost no text. Avoid: readable words unless asked, logos, watermarks, modern objects, gore, neon, 3D render look, painterly brush strokes, anime style, red cross symbols.
```

## ① 홈 화면 수정 (기준 그림 첨부)

끝났다. 결과가 [mockups/home_v2.webp](mockups/home_v2.webp)다.

```text
Edit the attached image. Keep its pixel art style, palette, lighting, parallax landscape and HUD frames as they are, and keep every element on the same small pixel size (the smoke must use the same pixels as the trees). Make these changes:
1) Scale the train up to about 1.6 times its current size so the car bodies fill roughly 40% of the screen height. The train is now longer than the screen: show five middle cars fully, with the tail car cut off at the left edge and the locomotive cut off at the right edge, like a horizontally scrolling view. Keep the cut-away interiors and the cold-blue-to-warm-amber lighting from tail to front.
2) Hang a small iron plaque with a simple pixel emblem above each car's door to show its function; no text.
3) One car is selected: it has a thin brass outline, and a small dark pop-up panel floats above it with two rows, a flame icon with a short bar and a crowd icon with a short bar, each with small round minus and plus buttons.
4) Outside, beside the rear cars, a few refugees in layered coats run through the snow reaching toward the train; far behind, dark stumbling silhouettes follow the train. No blood or gore.
5) HUD: top-left shows two meters instead of the pressure gauge and thermometer: two gloved hands clasped (trust) and a cracked glass pane (tension), each with a number. On the top-center bar, replace the two head icons with round buttons, a raised clenched fist at the left end (discontent) and a raised open palm at the right end (support), and put a few grey segments between the two colors for neutral. Bottom-left: keep the round menu button and add a small closed-book button next to it (the log). Bottom-center: keep the five-step route line and add a small square button above it with a top-down train icon (overview). Bottom-right: keep the arrow button and add a blank label plate on it for one short word.
```

## ①b 한눈에 보기 화면 (새 기준 그림 첨부)

열차가 10~20칸으로 늘어도 한 화면에서 보고 관리하는 화면이다.

```text
Match the art style, palette, line work and HUD design of the attached reference image.

Visual style: high-quality 2D pixel art for a side-scrolling mobile game about a steam train crossing a frozen Central Europe in the sixth winter after a collapse. The whole image uses one uniform pixel size, with crisp hard edges, no blur, no smooth gradients and no mixed resolutions. Limited palette with careful dithering; warm amber light as the only saturated accent. Quiet, grim and humane. UI: dark navy panels with thin brass borders and angled corners, cream-white pixel icons, condensed pixel numerals, almost no text. Avoid: readable words, logos, watermarks, modern objects, gore, neon, 3D render look, painterly brush strokes, red cross symbols.

Mobile game screen mockup, very wide landscape (about 2.2:1). The camera has risen above the train: a top-down view of a longer train of twelve cars with the roofs removed, so each car shows its floor plan (bunks, stoves, long tables, lockers, a desk with maps, upholstered seats, the locomotive's boiler and glowing firebox). The train stands vertically along the left third of the screen, locomotive at the top and tail at the bottom, on a track over snowy ground with a few pines. Each car has a muted color tint and outline by type so types read at a glance: tail cars cold grey-blue, tech and medical teal, dining car amber, guard car olive, captain's car gold, front cars burgundy, locomotive rust red. The locomotive car is selected and a dark panel has slid out over the right two-thirds: at its top the engine crew's pixel emblem and a small pixel portrait of their representative; below that two stat rows with icons and short gauges (warmth, crowding); below that three control rows for heating, rations and medicine, each a horizontal stepped selector with five discrete notches from lowest to highest, the current notch lit in amber, like a level picker, with no plus or minus buttons; and at the bottom two policy rows, each with a small icon and a pixel toggle switch.
HUD changes from the reference: on the top-center bar the discontent part is red and the support part is sky blue, with a few grey neutral segments between them; in the top-left panel each meter shows a short segmented gauge next to its number (trust in blue, tension in red-orange); the top-right resource icons are clearer and use muted natural colors: coal as a small iron mine cart heaped with black coal and a faint ember, food as a brown loaf of bread, medicine as a two-tone pill capsule beside a squat brown bottle, luxury goods as a small gold ring. At the bottom center the overview button now shows a side-view train icon for returning.
```

## ② 의회 화면 시안 (새 기준 그림 첨부)

```text
Match the art style, palette, line work and HUD design of the attached reference image.

Visual style: high-quality 2D pixel art, one uniform pixel size, crisp hard edges, limited palette with careful dithering, cold blue night with warm amber lamp light as the only saturated accent. Quiet, grim and humane. UI: dark navy panels with thin brass borders, cream-white pixel icons, almost no text. Avoid: readable words, logos, gore, 3D render look, painterly brush strokes.

Mobile game screen mockup, very wide landscape (about 2.2:1). The camera has moved into the dining car, seen from the side as a cut-away that fills the screen width: tables pushed to the walls, about thirty representatives in the work clothes of five communities (patched refugee coats, oil-stained engine overalls, guard greatcoats, medical aprons, tailored front-car coats) standing and sitting in rows, the captain at a small lectern at the right end, a wooden ballot box on a table with bowls of white and black stones, oil lamps, frosted windows with snow streaking past. UI overlay: in the upper area a semicircle chart of one hundred small pixel dots (filled = yes, hollow = no, small = abstain, dashed outline = absent) in five muted colors for the five communities, a small numeric tally beside it, and one large action button at the bottom right with a blank label plate.
```

## ③ 결정 카드 시안: 수저린 형식 (새 기준 그림 첨부)

```text
Match the art style, palette, line work and HUD design of the attached reference image.

Visual style: high-quality 2D pixel art, one uniform pixel size, crisp hard edges, limited palette with careful dithering, cold blues with warm amber accents. Quiet, grim and humane. UI: dark navy panels with thin brass borders, cream-white pixel icons. Avoid: logos, gore, 3D render look, painterly brush strokes.

Mobile game screen mockup, very wide landscape (about 2.2:1). A decision dialogue panel slides up over the dimmed train scene. Left third: a large, detailed pixel-art portrait of the speaker, a 67-year-old Polish engine driver with soot in the lines of his face, white stubble, a wool flat cap and a heavy railway jacket with brass buttons, looking at the viewer. Right two-thirds, laid out like a paper dossier with thin brass rules: one short line of dialogue (illegible pixel text is fine), then three stacked numbered choice plates; each plate shows small cost icons (for example a coal icon with a minus sign) instead of explanatory text.
```

## ④ 아이콘 판 10개 (새 기준 그림 첨부)

설계 세션이 잘라 `s1/public/art/icons/`에 넣는다: res_coal, res_food, res_medicine, res_luxury, meter_trust, meter_tension, bar_discontent, bar_support, btn_log, btn_overview.

```text
Match the pixel style of the attached reference image.

A sprite sheet of ten pixel-art UI icons in a 5 by 2 grid on a transparent background (if transparency is not possible, a pure black #000000 background). Each icon is drawn on its own 32 by 32 pixel grid, centered in its cell with generous padding, same scale, light from the top left, a dark outline, crisp pixels with no smoothing, no text, no frames. Icons 1 to 4 are resources and use muted natural colors so each material reads at a glance; icons 5 to 10 are cream-white (#EDE6D6) with a small accent where noted. Left to right, top to bottom: 1) coal: a small iron mine cart heaped with black coal lumps and a faint ember; 2) food: a brown loaf of bread; 3) medicine: a two-tone pill capsule beside a squat brown glass bottle, no cross; 4) luxury goods: a small gold ring with a gem; 5) trust: two gloved hands clasped (blue accent); 6) tension: a cracked glass pane (red-orange accent); 7) discontent: a raised clenched fist (red accent); 8) support: a raised open palm (sky-blue accent); 9) log: a closed book with a ribbon bookmark; 10) overview: a train seen from directly above, a long rectangle split into car segments.
```

## ⑤ 칸 명판 8개 (새 기준 그림 첨부)

①에서 칸 문 위에 거는 명판이자 공동체 문장이다. 설계 세션이 잘라 `s1/public/art/emblems/`에 넣는다.

```text
Match the pixel style of the attached reference image.

A sheet of eight small pixel-art plaques in a 4 by 2 grid on a transparent background (if not possible, pure black #000000). Each plaque is a small dark iron sign with riveted corners hanging from two short chains, carrying one cream-white pixel emblem; all the same size, readable at 32 pixels, no text. Left to right, top to bottom: 1) tail-car workers: a coal shovel crossed with a dented tin cup; 2) engine crew: a locomotive driving wheel with a spanner across it; 3) guard: a peaked guard cap above a storm lantern; 4) technicians and medics: an open tool roll with a stethoscope, no cross; 5) front-car passengers: an ornate key with a tassel; 6) captain: a compass; 7) dining car and council: a ballot box with a white stone; 8) workshop, for later: an anvil with a hammer.
```

## ⑥ 초상 두 장

`s1/public/art/portraits/`에 넣는다. 첫째 초상에는 ③의 결과(초상이 마음에 들면)나 새 기준 그림을, 둘째 초상에는 첫째 초상을 첨부한다.

```text
Match the pixel style of the attached reference image. A detailed pixel-art portrait for a dialogue panel, vertical 3:4, half-length, facing the viewer, plain dark navy background with a faint warm rim light from the left, one uniform pixel size, limited palette, crisp pixels. Henryk Mazurek, 67, a retired Polish volunteer engine driver from a steam depot: weathered face, soot in the wrinkles, white stubble, wool flat cap, heavy dark railway jacket with brass buttons, calm and stubborn eyes.
```

```text
Match the pixel style and framing of the attached reference portrait. A detailed pixel-art portrait for a dialogue panel, vertical 3:4, half-length, facing the viewer, plain dark navy background with a faint cold rim light from the right, one uniform pixel size, limited palette, crisp pixels. Pavla Krejčí, 41, a Czech refugee from Brno who now speaks for the tail car: thin face, wind-chapped cheeks, dark hair tied under a knitted scarf, several patched coats layered, tired but sharp eyes, chin slightly raised.
```

## 다음 차례

- 게임에 넣을 그림은 나눠서 뽑는다: 칸 일곱 개(옆 단면, 한 칸씩), 배경 층(먼 숲, 가까운 숲, 눈밭), 연기, 사람과 망자 걸음 그림.
- 화면 뼈대 고치기: 위 결정대로 홈을 옆 스크롤로 바꾸고, 칸 수치는 누르면 뜨게 하고, 일지는 책 단추로 옮기고, 설명 문장을 걷어낸다. 아이콘이 들어오면 같이 한다.
