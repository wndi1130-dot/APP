# 컨셉 렌더링 주문서 (2026-10-07)

작성: 2026-10-07 "화면 컨셉과 UI 연출" 스레드 · 상태: 주문서. 그림은 분위기와 배치를 보는 시안이고, 게임에 그대로 넣지 않는다.

## 왜 뽑나

1. 필드 파밍(사선 탑뷰)과 정치·내정 화면이 같은 게임처럼 보이는지 한 번에 본다.
2. 열린 질문 10(UI를 매끈하게 할지 픽셀로 할지)을 같은 화면 세 벌로 비교해 사용자가 고르게 한다.
3. 연출 문서([../design/briefs/presentation_motion.md](../design/briefs/presentation_motion.md))의 잉크 번짐과 의회 배경 생활이 정지 그림으로 어떻게 보이는지 확인한다.

## 받는 사람에게 (로컬 워커)

- 아래 글상자를 그대로 이미지 모델에 넣는다. 첨부할 그림은 각 항목에 적었다. 저장소 그림은 `docs/art/mockups/`에 있다(공개 저장소라 내려받아도 된다).
- 결과는 **공개 저장소에 올리지 않는다.** 사용자 바탕화면 `화면컨셉_20261007\`에 `C1_field_v1.png`처럼 번호를 붙여 저장하고, 같은 그림을 이 스레드("화면 컨셉과 UI 연출")에 올려 평가받는다.
- 한 항목은 두 장까지 뽑아 나은 쪽을 고른다. 고르지 못하면 둘 다 둔다.
- 한글 글자는 그리게 하지 않는다. 짧은 영어 이름표는 자리표시로 괜찮다. 글자가 깨져도 된다.
- 작품 이름은 프롬프트에 넣지 않는다. 넣으면 원작을 닮게 나온다([reference_analysis.md](reference_analysis.md) 4장).
- 우선순위: **C5 → C7 → C1 → C6 → C4 → C3 → C2 → C8.** C5와 C7은 사용자 결정(열린 질문 10)에 쓰이므로 먼저 뽑는다.

## 3D 여부와의 관계

엔진과 3D 여부는 "엔진 정하기" 스레드가 본다. 이 시안은 어느 쪽으로 가도 맞춰야 할 **보이는 목표**다. 그래서 "사실적 비례 + 칠한 듯한 질감 마감"으로 통일하고, 미리 렌더링한 스프라이트인지 실시간 3D인지는 정하지 않는다. 필드 카메라는 고정된 사선 시점(약 35~40도 내려다봄)으로 적었다. 실시간 3D로 가면 카메라를 돌릴 수 있지만, 시안은 고정 시점 하나로 본다.

## 공통 화풍 (모든 글상자에 이미 들어 있음)

문구를 고칠 때만 여기를 본다. home_v3 톤(사용자가 좋다고 한 분위기)과 2026-10-07 날씨·색 결정을 합쳤다.

```text
Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials, simple enough to read on a phone; textures soft and economical rather than crisp up close. Setting: Central Europe in the sixth winter after civilization collapsed and the dead rose. Weather is dark and drab: low heavy clouds, freezing fog, wet sleet or snow squalls; the only warm light comes from lamps, stoves and fire. Cold is shown as pale grey-white frost and blue-grey shadow, never saturated blue; warmth is amber. Colour meanings: red appears only where something is wrong (discontent, shortage zones of gauges, danger warnings); sky blue appears only for political support. People are exhausted civilians in layered patched coats; some have blood soaked into bandages or clothing, but no wounds or gore are drawn. Avoid: pixel art, toy or cartoon proportions, glossy product renders, Victorian ornament, logos, real weapon brand marks, red cross symbols, readable text other than short English placeholder labels.
```

## C1 필드 파밍: 정차역 수색 (첨부: home_v3)

필드 HUD 배치는 아직 설계가 없다. 아래 배치는 이 시안의 **제안**이고, 엄지가 닿는 아래 양 모서리에 조작을 둔다는 원칙([presentation_ui.md](../design/briefs/presentation_ui.md))을 따랐다.

```text
Match the painterly realistic rendering, the weather mood and the dark gunmetal-and-brass HUD finish of the attached image, but this is a different screen.

Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials, simple enough to read on a phone; textures soft and economical rather than crisp up close. Setting: Central Europe in the sixth winter after civilization collapsed and the dead rose. Weather is dark and drab: low heavy clouds, freezing fog, wet sleet or snow squalls; the only warm light comes from lamps, stoves and fire. Cold is shown as pale grey-white frost and blue-grey shadow, never saturated blue; warmth is amber. Colour meanings: red appears only where something is wrong (discontent, shortage zones of gauges, danger warnings); sky blue appears only for political support. People are exhausted civilians in layered patched coats; some have blood soaked into bandages or clothing, but no wounds or gore are drawn. Avoid: pixel art, toy or cartoon proportions, glossy product renders, Victorian ornament, logos, real weapon brand marks, red cross symbols, readable text other than short English placeholder labels.

Mobile game screen mockup, very wide landscape (about 2.2:1). A fixed three-quarter top-down camera looking down at about 35 to 40 degrees, like a classic isometric survival game, over the freight yard of a small railway junction town in western Poland at dusk, in freezing fog and wet sleet. Our steam train stands at the platform along the top edge of the screen, its locomotive leaking steam and its windows glowing amber. In the yard: a coal stockpile with abandoned hopper wagons, a brick goods shed with a broken door, a water tower with icicles, a signal box, rusted rails and frozen puddles, a few abandoned cars on the access road.

People: the player's scavenger, a woman in a long patched coat with a backpack and a fire axe, crouching beside an opened locker in the goods shed; three companions nearby, one holding a hand lantern, one with a bolt-action rifle on guard, one carrying a crate. Near the coal stockpile, a small work crew of four shovels coal into sacks and pushes a hand cart toward the train while two guards stand watch. At the foggy edge of the screen, the dead approach: slow, stumbling silhouettes in rotting winter clothing, one of them frozen stiff; a thin red-tinged smear of frost creeps in from that screen edge as a warning of where the horde comes from.

HUD as a proposal, small and quiet: top-left, four round clock-like gauges in a row with tiny icons (train coal, threat, cold and daylight, body fatigue), each needle partly turned; top-right, a four-step noise meter shaped like a sound fan and a small horde forecast dial; bottom-left, three small companion portraits in brass frames, each with a tiny order icon below (follow, hold, search, cover, retreat as a short row on the selected one); bottom-center, two hand slots (fire axe, revolver) and a bag weight bar with a weight icon; bottom-right, a large round shove button and a pause button shaped like a stopwatch. A thin circle around the scavenger shows her footstep noise radius. Interactable objects have a faint pale outline.
```

## C2 필드 교전: 전술 일시정지 (첨부: C1 결과)

```text
Edit the attached image. Keep the camera, the place, the characters, the rendering and the HUD. Show the moment the player has paused during a fight:
1) The whole scene is frozen and slightly desaturated toward grey-brown, as if time stopped; snowflakes and steam hang still in the air. The HUD and the selected characters stay at full colour.
2) Three of the dead have reached the coal crew; one crew member is held by a dead man and is pushing him away. A living raider with a rifle stands on top of a hopper wagon; above him floats a small red aiming marker meaning he is aiming at us.
3) The player's rifle companion is selected: a narrowing aiming circle sits on the raider, with a thin line from the companion to it. A thin pale line from the axe woman points to the held crew member, meaning 'go help'.
4) Bottom-left, the companion order row is expanded on the selected portrait. The pause button at the bottom-right is lit to show the game is paused.
No gore; impact is shown by posture and motion blur only.
```

## C3 홈 v4

새 글상자 없음. [reference_analysis.md](reference_analysis.md) 9장의 **v4 수정 프롬프트**를 home_v3에 첨부해 그대로 쓴다. 날씨를 어둡게, 꼬리칸을 춥게, 빨간 십자 명판·빨간 커튼·파란 신임 막대를 고치는 판이다.

## C4 한눈에 보기 (첨부: home_v3, overview_v1)

overview_v1은 픽셀이라 배치만 본다. [image_prompts.md](image_prompts.md)의 ①b 평가(열차 2~3배, 칸 묶음, 레버와 반원 계기, 고른 칸과 창을 잇는 선, '수치만 보기' 단추)를 반영했다.

```text
Use the second attached image for layout only and do not copy its pixel-art style. Match the painterly realistic rendering, weather mood and gunmetal-and-brass HUD of the first attached image.

Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials, simple enough to read on a phone; textures soft and economical rather than crisp up close. Setting: Central Europe in the sixth winter after civilization collapsed and the dead rose. Weather is dark and drab: low heavy clouds, freezing fog, wet sleet or snow squalls; the only warm light comes from lamps, stoves and fire. Cold is shown as pale grey-white frost and blue-grey shadow, never saturated blue; warmth is amber. Colour meanings: red appears only where something is wrong (discontent, shortage zones of gauges, danger warnings); sky blue appears only for political support. Avoid: pixel art, toy or cartoon proportions, glossy product renders, Victorian ornament, logos, red cross symbols, readable text other than short English placeholder labels.

Mobile game screen mockup, very wide landscape (about 2.2:1). The camera has risen above the moving train: a top-down view of the train with its roofs lifted off, standing vertically along the left 40% of the screen, wide and large, so each car's floor plan is readable: bunks and people under blankets in the tail cars, beds and a cloth partition in the medical car, long tables in the dining car, lockers in the guard car, upholstered seats in the front car, the boiler and glowing firebox at the top. Snowy ground and sleeper ties around it, seen through thin fog. Cars of the same type are grouped with a thin brass bracket and a small iron plaque emblem beside each group; the group colours are muted and avoid red and sky blue (dark umber, olive, slate, ochre, grey-green). The second tail car is selected with a thin brass outline, and a thin brass line runs from it to a dark gunmetal panel on the right 55% of the screen. In the panel: the tail car's plaque and a small portrait of its representative at the top; two stat rows (warmth shown by a thermometer, crowding shown by a crowd icon) with short bars; three lever controls (heating, rations, medicine), each a handle in a notched track with a small semicircular gauge above it, the heating needle leaning into the red; two policy rows with small toggle switches. Above the train, two small buttons: one with a top-down train icon (overview, lit) and one with a bar-chart icon (numbers only). Keep the top HUD: trust and tension meters at top-left, the red-grey-sky-blue bar with fist and open palm in the center, resources at top-right.
```

## C5 의회: 식당칸 회기 (첨부: home_v3, council_v1)

council_v1은 픽셀이라 배치만 본다. 2026-10-07 사용자 요청인 배경 생활(오가는 사람, 수군거림, 흔들리는 등불)과 긴장에 반응하는 화면 가장자리 얼룩을 넣었다. 이 그림이 C7의 바탕이 된다.

```text
Use the second attached image for the screen layout only and do not copy its pixel-art style. Match the painterly realistic rendering and the gunmetal-and-brass HUD finish of the first attached image.

Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials, simple enough to read on a phone; textures soft and economical rather than crisp up close. Setting: Central Europe in the sixth winter after civilization collapsed and the dead rose. The only warm light comes from lamps and stoves. Cold is shown as pale grey-white frost and blue-grey shadow, never saturated blue; warmth is amber. Colour meanings: red appears only where something is wrong (discontent, opposing votes, shortage zones); sky blue appears only for support and supporting votes. People are exhausted civilians in layered patched coats; some have blood soaked into bandages, but no wounds or gore. Avoid: pixel art, toy or cartoon proportions, glossy product renders, Victorian ornament, logos, red cross symbols, readable text other than short English placeholder labels.

Mobile game screen mockup, very wide landscape (about 2.2:1). Inside the dining car of a moving steam train at night, turned into a council chamber. The background is alive but softly out of focus so the UI stays readable: about forty delegates crowd the long tables and the aisle; some lean together whispering, one stands and points, a woman holds a child, two men argue near the far door, a guard leans by the window; oil lamps sway on hooks; frosted windows show dark forest rushing past; breath and pipe smoke hang in the lamp light. A wooden ballot box and two bowls of white and black stones sit on a table in the lower middle.

Foreground UI: a large semicircle of 100 small seat figures split into five community wedges, each wedge tipped with a small iron plaque emblem; seats are coloured sky blue (yes), red (no) or grey (undecided). In the center, a brass engine-order-telegraph needle with tick marks at 51 and 67, and below it a large '46 / 51' counter. Left panel: the bill, with a short title plate, a small open-eye icon for a public vote, and three changed values as icons with plus or minus numbers. Right panel, linked by a thin brass line to the selected wedge: the community leader's portrait, seat count, a cohesion bar, five trade buttons each with an icon and a one-word label (Negotiate, Favor, Supply, Bribe, Leverage), and a large vote button shaped like a lever handle.

Tension is high: from the screen edges a dark sooty stain, like ink or coal smoke spreading through water, creeps inward with soft branching tendrils, darkest in the corners and fading before it reaches any panel, number or face. The top HUD stays as in the first attached image.
```

## C6 결정 카드: 서류 뭉치에서 꺼낸 카드 (첨부: home_v3, card_v1)

2026-10-06에 정한 배치다. 카드는 홈 왼쪽 서류 뭉치에서 꺼내 화면 왼쪽 절반만 덮고, 오른쪽엔 열차가 그대로 보인다(card_v1은 아래에서 올라오는 옛 배치라 초상과 선택지 모양만 참고).

```text
Use the first attached image as the background screen and match its rendering and HUD. Use the second attached image only for the idea of a portrait with numbered choices; do not copy its pixel-art style or its layout.

Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials, simple enough to read on a phone. Dark, drab weather outside. Colour meanings: red appears only where something is wrong; sky blue appears only for political support. Avoid: pixel art, cartoon proportions, glossy renders, Victorian ornament, logos, red cross symbols, readable text other than short English placeholder labels.

Mobile game screen mockup, very wide landscape (about 2.2:1). The home screen's side view of the train stays visible on the right half, slightly dimmed. The small bundle of papers tied with string at the left edge has just been opened: one sheet has been pulled out and unfolded to cover the left half of the screen. The sheet is a worn, slightly creased document of thick off-white paper with a typewritten-looking layout, coffee and soot smudges at its corners and a torn dark-red wax seal at the top; its edges look as if dark ink has just soaked outward into the paper. On the sheet: at the upper left, a charcoal-drawn portrait in a paper frame of a thin, tired 41-year-old woman with wind-chapped cheeks, dark hair under a knitted scarf and layered patched coats; beside it a small name plate and an iron plaque emblem of a coal shovel crossed with a tin cup. Below, one short line of quoted dialogue as placeholder English, then three numbered choices written like typed lines, each with, on its right, only the costs that are certain now (resource icons with minus numbers) and the immediate political shift as a tiny red or sky-blue tick on a mini bar; one choice carries a small eye icon meaning someone will witness it. Behind the opened sheet, the bundle shows two more sealed papers waiting. Keep the top HUD.
```

## C7 UI 방식 비교 세 벌 (첨부: C5 결과)

C5 결과 한 장을 세 번 고친다. **월드(식당칸 배경)는 그대로 두고 UI 층만** 바꾼다. 세 장을 나란히 놓고 사용자가 고른다. 안의 뜻은 [presentation_motion.md](../design/briefs/presentation_motion.md) 6장에 있다.

### C7a 매끈·두 재질 (추천안)

```text
Edit the attached image. Keep the background scene, the composition and every UI element's position exactly. Restyle only the UI layer: gauges, meters, bars and buttons are dark gunmetal enamel like old railway signs with thin worn brass rims, rivets and condensed sans-serif numerals; the bill panel on the left and the leader card on the right look like thick off-white paper documents pinned to the enamel, with typed-looking lines, charcoal-drawn icons and a soot-dark ink stain that has soaked into the paper edges. Icons are smooth, hand-drawn charcoal and engraved line drawings, not pixel art. The selected trade button has a soft dark ink bloom spreading behind its icon. Keep the high-tension sooty stain at the screen edges.
```

### C7b 매끈·한 재질

```text
Edit the attached image. Keep the background scene, the composition and every UI element's position exactly. Restyle only the UI layer so that every panel, gauge and button is one consistent material: matte dark charcoal panels with a subtle oily sheen, thin light-grey keylines, clean condensed sans-serif numerals and flat, smooth, single-colour pictogram icons. No paper, no brass, no rivets. The selected trade button has a soft dark oily bloom spreading behind its icon. Keep the high-tension sooty stain at the screen edges.
```

### C7c 픽셀 UI

```text
Edit the attached image. Keep the background scene exactly as it is, painterly and not pixelated. Restyle only the UI layer as crisp pixel art on one uniform pixel grid: dark navy panels with thin brass pixel borders and angled corners, cream-white pixel icons, chunky pixel numerals, hard edges and no smooth gradients. The selected trade button's highlight is a dithered pixel pattern. The high-tension stain at the screen edges becomes a dithered pixel pattern too.
```

## C8 잉크 번짐 연출 콘티 (첨부: C7a 결과)

정지 그림으로 움직임의 단계를 본다. 실제 움직임은 이 스레드의 비교 데모에서 본다.

```text
Using the UI style of the attached image, draw a storyboard sheet of six panels in two rows on a plain dark background, each panel a close-up of the same rectangular trade button with a handshake icon and the placeholder label 'Negotiate'. Panel 1: idle. Panel 2: a finger presses; the brass rim dips slightly. Panel 3: a small blot of dark sooty ink appears behind the icon where the finger touched. Panel 4: the blot spreads outward with soft branching tendrils, like ink dropped in water, while the icon and label stay perfectly sharp on top. Panel 5: the stain fills the button face and its tendrils reach just past the rim. Panel 6: the stain settles into a calm dark selected state with a thin bright rim; a faint lighter ring shows where the spread stopped. Small frame numbers 1 to 6 under each panel. No other text.
```

## 받은 뒤 볼 것

1. C1과 C5를 나란히 놓았을 때 같은 게임으로 보이는가(화풍, 빛, HUD 마감).
2. 폰 크기로 줄여도 C1에서 사람, 좀비, 줍는 물건, 무리 경고가 구별되는가.
3. C5에서 배경 생활이 표결 정보(숫자, 쐐기 색)를 가리지 않는가. 긴장 얼룩이 숫자와 얼굴에 닿지 않는가.
4. C7 세 장에서 어느 UI가 월드와 어울리는가. 특히 C7c에서 픽셀 UI가 비픽셀 월드 위에 떠 보이는지.
5. 빨강·하늘색이 정치 뜻과 경고 말고 다른 데 쓰이지 않았는가. 빨간 십자가 없는가.
