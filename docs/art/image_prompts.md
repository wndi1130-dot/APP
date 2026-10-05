# 이미지 프롬프트 1차 (GPT 이미지 모델용)

작성: 2026-10-06 · 쓰는 곳: GPT-6의 이미지 모델 2.5 · 결과물은 대화에 올리면 설계 세션이 s1/public/art/에 넣고 화면에 붙인다.

## 방향 (2026-10-06 결정)

- 전체 분위기는 프로스트펑크 2와 This War of Mine을 따른다. 기준은 프로스트펑크 2다.
- 결정·대화 화면의 형식은 수저린(Suzerain)을 참고한다. 인물 초상, 짧은 대사, 읽히는 선택지가 서류처럼 정돈된 배치다.
- 화면에서 설명 문장을 걷어낸다. 자원과 계기는 글자 대신 아이콘과 숫자로 보여 준다.

## 쓰는 법

1. 아래 **공통 화풍**을 매번 프롬프트 맨 앞에 붙인다.
2. 순서대로 뽑는다. ①홈 시안으로 화풍을 먼저 잡고, 마음에 드는 결과가 나오면 그 이미지를 참조로 올려 "이 이미지와 같은 화풍으로"를 붙여 나머지를 뽑는다. 그래야 장마다 화풍이 흔들리지 않는다.
3. 아이콘과 문장은 한 장에 여러 개를 격자로 뽑는다. 따로 뽑으면 크기와 빛 방향이 제각각이 된다. 자르는 건 설계 세션이 한다.
4. 투명 배경이 안 되면 순검정 배경으로 받는다. 아이콘이 밝은 크림색이라 깔끔하게 따낼 수 있다.
5. 화면 시안 ①~③은 배치와 분위기를 정하는 용도이고 게임에 그대로 넣지 않는다. 시안의 글자는 깨져도 괜찮다.

### 주의

- **게임 이름을 프롬프트에 넣지 않았다.** 이름을 넣으면 원작 자산과 너무 닮게 나올 수 있어 출시 자산으로는 위험하다. 분위기 탐색용으로만 쓰려면 공통 화풍 끝에 `Mood references: Frostpunk 2, This War of Mine, Suzerain.`을 붙여도 된다.
- **이미지에 한글을 쓰게 하지 않는다.** 이미지 모델은 글자, 특히 한글을 자주 틀린다. 글자는 게임 코드에서 아래 폰트로 얹는다.
- 의약품 아이콘에 **붉은 십자**를 쓰지 않는다. 적십자 표장은 법으로 보호돼 게임에서 문제가 된 사례가 있다.

## 폰트

| 쓰임 | 프로스트펑크 2 | 출처·라이선스 | 한글 짝(추천) |
|---|---|---|---|
| 라벨·숫자 | Barlow Condensed | [Google Fonts](https://fonts.google.com/specimen/Barlow+Condensed), OFL | IBM Plex Sans KR (OFL) |
| 서술·대사 | Crimson Pro | [Google Fonts](https://fonts.google.com/specimen/Crimson+Pro), OFL | Noto Serif KR (OFL) |
| 제목·인용 | Cormorant Garamond | [Google Fonts](https://fonts.google.com/specimen/Cormorant+Garamond), OFL | Noto Serif KR 굵게 |

- 근거: [Game Font Library의 Frostpunk 2 항목](https://www.gamefontlibrary.com/games/frostpunk-2)이 위 셋을 주·보조·셋째 폰트로 적는다. 게임 파일에서 직접 확인한 것은 아니다. 이 사이트가 실제 폰트를 적는지, 닮은 무료 폰트를 적는지도 밝히지 않는다(미확인). 참고로 같은 사이트는 프로스트펑크 1을 Playfair Display, Roboto Slab, Josefin Sans로 적는다.
- 프로스트펑크 2 한국어판의 한글 폰트는 확인하지 못했다. 한글 짝은 같은 인상을 내는 OFL 폰트로 고른 추천이다.
- 셋 다 OFL이라 상업 게임에 넣어 쓸 수 있다.

## 공통 화풍

```text
Visual style for a mobile political survival game set aboard a steam train crossing a frozen Central Europe, in the sixth winter after a collapse. Painterly hand-finished digital illustration with visible brush texture and fine charcoal line work. Desaturated palette of blue-grey snow, soot black and iron grey; the only saturated accent is warm amber light from fireboxes, lamps and heated windows, so every image has a strong cold-versus-warm contrast. Quiet, grim and humane rather than heroic. Worn materials: riveted steel, frosted glass, patched wool and canvas, brass gauges. UI language: dark charcoal-navy translucent panels, thin brass hairline borders, angled corner cuts, flat cream-white icons, large condensed numerals, generous spacing and almost no text. Avoid: readable words unless asked, logos, watermarks, modern objects, monsters, gore, neon, glossy 3D render look, anime style, red cross symbols.
```

## ① 홈 화면 시안: 열차 단면도

```text
[공통 화풍] Mobile game screen mockup, very wide landscape (about 2.2:1, a phone held sideways, safe margins at the edges). Dusk over a snowfield. The center is a side-view cut-away of a seven-car steam train, like a dollhouse cross-section, read left to right: tail car (crowded refugees around one small stove, coldest blue light), tech and medical car (cots, a workbench), dining car (long tables that double as the council room), guard car (lockers, greatcoats on hooks), captain's car (a desk with maps and a logbook), front car (curtains, upholstered seats, warmest light), and the locomotive at the far right with a glowing firebox and two engine crew; smoke trails back over the cars. Interior light shifts from cold blue at the tail to warm amber at the front. Thin UI overlay only: top-left two small gauge icons with numbers; top-center one horizontal segmented bar split into discontent and support; top-right four resource icons with numbers (coal, food, medicine, luxury goods); bottom-left a round menu button; bottom-center a minimal five-step route progress line; bottom-right one large primary action button. Numbers in a condensed sans-serif. No sentences anywhere on screen.
```

## ② 의회 화면 시안: 식당칸 의회

```text
[공통 화풍] Mobile game screen mockup, very wide landscape (about 2.2:1). Inside the dining car turned into a council chamber, seen from the captain's lectern: about one hundred representatives packed in a tight semicircle, dressed by community (patched refugee coats, oil-stained engine overalls, guard greatcoats, medical aprons, tailored front-car coats). A wooden ballot box on a table with two bowls of white and black stones. Hanging oil lamps, frost on the windows, snow blowing past outside. UI overlay: in the upper half a semicircle seat chart of one hundred small dots (filled = yes, hollow = no, small dot = abstain, dashed outline = absent), five thin wedge colors for the five communities, a small numeric tally beside it, and one large action button at the bottom right. Minimal text.
```

## ③ 결정 카드 시안: 수저린 형식

```text
[공통 화풍] Mobile game screen mockup, very wide landscape (about 2.2:1). A decision dialogue panel slides up over the dimmed train scene. Left third: a painted half-length portrait of the speaker, a 67-year-old Polish engine driver with soot in the lines of his face, white stubble, a wool flat cap and a heavy railway jacket with brass buttons, looking straight at the viewer. Right two-thirds, arranged like a political dossier with a faint paper texture and thin brass rules: one short line of dialogue in a classic serif, then three stacked numbered choice plates; each plate shows a small pair of cost icons (for example a coal icon and a minus sign) instead of explanatory text.
```

## ④ 아이콘 판: 자원과 계기 6개

설계 세션이 잘라 `s1/public/art/icons/`에 넣는다: res_coal, res_food, res_medicine, res_luxury, meter_tension, meter_trust.

```text
[공통 화풍] A sprite sheet of six game UI icons in a 3 by 2 grid on a transparent background (if transparency is not possible, a pure black #000000 background). Every icon is centered in its cell with generous padding, drawn at the same scale with light from the top left. Flat cream-white glyphs (#EDE6D6) with a subtle worn, etched texture and a thin dark outline, readable at 24 pixels; no color except a small amber accent where noted; no text, no frames, no shadows outside the glyph. Left to right, top to bottom: 1) coal: a lump of coal with a faint ember glow (amber accent); 2) food: a loaf of dark bread next to a tin can; 3) medicine: a small glass medicine bottle with a stopper and a blank label, no cross symbol; 4) luxury goods: a small hinged jewelry box with a pocket watch; 5) tension: a round steam pressure gauge with the needle near the top of the dial (amber accent on the needle); 6) trust: two gloved hands clasped in a handshake.
```

## ⑤ 문장 판: 공동체 다섯과 열차장

설계 세션이 잘라 `s1/public/art/emblems/`에 넣는다. 색은 코드에서 입힌다.

```text
[공통 화풍] A sheet of six faction emblems in a 3 by 2 grid on a transparent background (if not possible, pure black #000000). Each emblem is a simple stenciled badge in a single cream-white color (#EDE6D6) with worn paint texture, same size and line weight, readable at 32 pixels, no text, no color. Left to right, top to bottom: 1) tail-car workers: a coal shovel crossed with a dented tin cup; 2) engine crew: a locomotive driving wheel with a spanner across it; 3) guard: a peaked guard cap above a storm lantern; 4) technicians and medics: an open tool roll with a stethoscope, no cross symbol; 5) front-car passengers: an ornate brass key with a tassel; 6) the captain: a brass compass.
```

## ⑥ 초상 두 장: 콘텐츠 가이드 3.2의 인물

`s1/public/art/portraits/`에 넣는다. 세로 3:4, 같은 구도로 뽑는다.

```text
[공통 화풍] Portrait for a dialogue panel, vertical 3:4, half-length, facing the viewer, plain dark charcoal background with a faint warm rim light from the left. Henryk Mazurek, 67, a retired Polish volunteer engine driver from a steam depot: weathered face, soot in the wrinkles, white stubble, wool flat cap, heavy dark railway jacket with brass buttons, calm and stubborn eyes.
```

```text
[공통 화풍] Portrait for a dialogue panel, vertical 3:4, half-length, facing the viewer, plain dark charcoal background with a faint cold rim light from the right, same framing as the previous portrait. Pavla Krejčí, 41, a Czech refugee from Brno who now speaks for the tail car: thin face, wind-chapped cheeks, dark hair tied under a knitted scarf, several patched coats layered, tired but sharp eyes, chin slightly raised.
```

## 다음 차례 (시안을 보고 정한다)

- 열차 칸 일곱 개의 단면 그림(홈 띠용). 시안 ①의 화풍이 정해지면 칸마다 뽑는다.
- 화면 뼈대에서 걷어낼 문장: 단계 설명 문장, 세 번 겹치는 '다음 회기까지 N구간', 칸마다 붙은 '추움·과밀' 같은 낱말(막대와 아이콘으로 대신한다), 'S1a 자리' 자리표시 상자(디버그에서만 보이게), 일지 줄마다 되풀이되는 구간 표시, 식당칸·열차장실의 보조 설명. 아이콘을 붙일 때 같이 고친다.
