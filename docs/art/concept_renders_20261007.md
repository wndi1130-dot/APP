# 컨셉 렌더링 주문서 (2026-10-07)

작성: 2026-10-07 "화면 컨셉과 UI 연출" 스레드 · 상태: 렌더 끝, 기준 그림 확정(끝의 '평가' 절). 그림은 분위기와 배치를 보는 시안이고, 게임에 그대로 넣지 않는다.

## 왜 뽑나

1. 필드 파밍(사선 탑뷰)과 정치·내정 화면이 같은 게임처럼 보이는지 한 번에 본다.
2. 열린 질문 10(UI를 매끈하게 할지 픽셀로 할지)을 같은 화면 세 벌로 비교해 사용자가 고르게 한다. → 2026-10-07 닫힘: 매끈·두 재질(법랑·놋쇠와 종이), 희생이 정차 수 대비 커질수록 UI가 낡는다(decisions.md 'UI가 낡아 간다'). 남은 건 긴장 아이콘뿐이다.
3. 연출 문서([../design/briefs/presentation_motion.md](../design/briefs/presentation_motion.md))의 잉크 번짐과 의회 배경 생활이 정지 그림으로 어떻게 보이는지 확인한다.

## 받는 사람에게 (로컬 워커)

- 아래 글상자를 그대로 이미지 모델에 넣는다. 첨부할 그림은 각 항목에 적었다. 저장소 그림은 `docs/art/mockups/`에 있다(공개 저장소라 내려받아도 된다).
- 결과는 **공개 저장소에 올리지 않는다.** 사용자 바탕화면 `화면컨셉_20261007\`에 `C1_field_v1.png`처럼 번호를 붙여 저장하고, 같은 그림을 이 스레드("화면 컨셉과 UI 연출")에 올려 평가받는다.
- 한 항목은 두 장까지 뽑아 나은 쪽을 고른다. 고르지 못하면 둘 다 둔다.
- 한글 글자는 그리게 하지 않는다. 짧은 영어 이름표는 자리표시로 괜찮다. 글자가 깨져도 된다.
- 작품 이름은 프롬프트에 넣지 않는다. 넣으면 원작을 닮게 나온다([reference_analysis.md](reference_analysis.md) 4장).
- 우선순위: **C5 → C7 → C1 → C9 → C10 → C6 → C4 → C3 → C2 → C8.** C5와 C7은 사용자 결정(열린 질문 10, 2026-10-07 두 재질로 닫힘)에 쓰였으므로 먼저 뽑았다. C9·C10(정차 장면)은 2026-10-07 사용자 요청으로 더했다.

## 3D 여부와의 관계

엔진은 Godot 4로 정했고, 정차 카메라가 옆면에서 앞쪽으로 도는 연출 때문에 2026-10-07 08:21 사용자가 그림을 전부 3D로 정했다(decisions.md). 사람이 사는 칸(꼬리칸 포함)은 낡은 객차, 닫힌 화차는 짐과 석탄에만 쓴다. 이 시안은 3D 장면이 맞춰야 할 **보이는 목표**이고, "사실적 비례 + 칠한 듯한 질감 마감"으로 통일했다. 필드 카메라는 고정된 사선 시점(약 35~40도 내려다봄)으로 적었다. 실시간 3D로 가면 카메라를 돌릴 수 있지만, 시안은 고정 시점 하나로 본다.

## 공통 화풍 (모든 글상자에 이미 들어 있음)

문구를 고칠 때만 여기를 본다. home_v3 톤(사용자가 좋다고 한 분위기)과 2026-10-07 날씨·색 결정을 합쳤다.

2026-10-07 08:25 고침: 사용자가 옷차림을 더 누더기처럼 하라고 했다(3D 모델링 스레드). 옷차림 줄을 그 방향으로 바꿨다. 작품 이름은 글상자에 넣지 않고 모습만 풀어 쓴다.

2026-10-07 07:50 덧붙임: 아래 두 줄은 앞으로 뽑는 모든 글상자 끝에 붙인다. 이미 나온 C1~C11 글상자에는 없어서 철모와 군용 외투가 섞여 나왔다(끝의 '민감 표식 점검' 절). 3D 모델링 주문서(main 6188d40, 7dd882e)와 같은 선이다.

```text
Clothing: everyone looks ragged after six winters: torn and frayed mismatched layers, scavenged coats too big or too small, blankets and sacking worn as cloaks, holes patched with burlap, rags and rope wrapped over boots and hands, frayed sleeves and stained knees, soot and grime on faces and cuffs, gear and bundles tied on with cord and straps. No armbands, stars, badges, cap badges, insignia, rank marks, real army uniforms or steel helmets; guards are told apart by fur hats with ear flaps, rifles, clubs and hand lanterns. No red cross or red crescent on anything; medicine is a plain bottle or a pill.
Train: people live and ride only in old passenger coaches (boarded-up windows, tarpaulin patches, stove pipes are fine); closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors.
Props: no abandoned suitcases, piles of luggage or piles of shoes on platforms or beside the train; left-behind goods are only cargo sacks or wooden crates.
The dead: ordinary civilians in torn everyday winter clothes (parkas, anoraks, wool coats, hoodies, work jackets, knit hats or bare heads, loose hair). No olive drab, no camouflage or mottled patterns, no military-style backpacks or webbing, no helmets or round helmet-like caps, never walking in step or in rows.
```

2026-10-07 15:25 더함: 마지막 줄(망자 옷)은 구간 배경 시안(B2·B3·B6)에서 망자가 병사 무리처럼 나와서 넣었다. 구간 배경 주문서와 같은 문장이다.

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

## C9 정차: 카메라가 앞쪽으로 돈 첫 장면 (첨부: home_v3, C1 결과)

2026-10-07 사용자 요청. 평소엔 단면으로 달리다가 정차를 누르면 끼익 소리와 함께 카메라가 열차 옆면에서 약간 앞쪽으로 돌아 정차한 곳을 보여 준다. 위험과 흔적은 글이 아니라 장면으로 준다. 장소는 첫 정차 후보인 작은 역(급수탑 결빙, [../design/briefs/first_leg_story.md](../design/briefs/first_leg_story.md))이다. HUD는 거의 숨긴다.

```text
Match the painterly realistic rendering and weather mood of the first attached image and the place style of the second, but this is a cinematic in-game shot, not a menu screen.

Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials; textures soft and economical rather than crisp up close. Central Europe, sixth winter after civilization collapsed and the dead rose. Dark drab weather: low heavy clouds, freezing fog, wet sleet. Cold is pale grey-white frost and blue-grey shadow, warmth is amber. No gore, no logos, no red cross symbols, no readable text.

Very wide landscape (about 2.2:1). The camera stands low beside the track a little ahead of the locomotive and looks back along the side of our steam train, which has just stopped at a small, abandoned country station in western Poland at dusk: brakes still steaming, sparks fading under the wheels, steam rolling across the platform. The train's patched cars recede into the fog behind, their windows glowing amber, faces pressed to the glass. Around the station the scene quietly tells the player what to expect without any text: a brick water tower with a thick skirt of ice and a frozen spout; a hand-painted warning sign nailed to a lamp post, too far to read; a burnt-out passenger car on a siding with its doors chained shut; fresh footprints and a dragged trail in the snow leading into the goods shed; two dead figures standing motionless at the far end of the platform, half hidden in fog; crows on the station roof; a faint smoke line rising from a chimney in the village beyond the trees. Only a small, translucent stop marker and a single arrow button remain at the bottom-right corner of the screen.
```

## C10 하차 장면 네 가지 (첨부: C9 결과)

같은 문 앞에서 열차장이 내리는 모습을 정치 상태에 따라 넷으로 나란히 본다. 엔진 스레드 제안대로 기본 하차 동작에 자세(어깨, 고개)와 짧은 동작(한숨, 어깨 툭)을 섞는 방식이라, 그림도 같은 사람·같은 문·같은 구도로 맞춘다.

```text
Using the rendering, place and weather of the attached image, draw a sheet of four panels in a 2-by-2 grid, each the same medium shot from the platform of the same open carriage door of our stopped steam train at dusk, freezing fog, steam drifting. The same train chief steps down in each panel: a weathered man in his forties in a long dark railway greatcoat with a fur collar, a peaked cap and a satchel, with three scavengers behind him in the doorway (a woman with a fire axe, a young man with a lantern, an older man with a bolt-action rifle).
Panel 1, strongly supported: he steps down chin raised, shoulders squared, one hand lifted in greeting; behind him faces crowd the windows and a few hands wave; the scavengers follow eagerly.
Panel 2, on the edge of a no-confidence vote: he steps down slowly with slumped shoulders and his breath clouding in a long sigh, eyes on the snow; the windows behind him are empty or curtains drawn; the scavengers keep their distance.
Panel 3, carrying guilt: he stops on the bottom step and stares blankly at the fog-bound station, frozen in thought, while the woman with the axe reaches past him to tap his shoulder.
Panel 4, distrusted and watched: he steps down while an armed guard in the doorway watches his back; the scavengers glance at each other; a single figure in the window behind turns away.
No text, no gore, no logos. Small panel numbers 1 to 4 in the corners only.

## C11 낡아 가는 UI 세 단계 (첨부: C7a 결과)

2026-10-07 사용자 결정: UI는 매끈하게 시작해 희생이 커질수록 녹·피·때에 찌든다([../design/briefs/presentation_motion.md](../design/briefs/presentation_motion.md) 8장). 같은 화면의 0·2·4단계를 나란히 본다.

```text
Using the attached image, draw three versions side by side in one wide sheet, separated by thin dark gaps, each a crop of the right-hand leader card, the trade buttons and the vote lever. Keep layout, labels, numbers and icons identical and perfectly legible in all three.
Left, stage 0: clean enamel, bright worn brass rims, clean off-white paper.
Middle, stage 2: rust blooms around the rivets and along the brass rims, enamel chipped at the corners, paper edges yellowed with a coffee ring and grimy thumbprints.
Right, stage 4: heavy rust and soot on every rim, a hairline crack across the gauge glass, the paper creased, water-stained and torn at one corner, dried dark brown blood smears on the paper edge and on one button rim; no wounds or gore, and nothing covers any text, number or icon.
Small labels 0, 2, 4 under each version only.
```

## 받은 뒤 볼 것

1. C1과 C5를 나란히 놓았을 때 같은 게임으로 보이는가(화풍, 빛, HUD 마감).
2. 폰 크기로 줄여도 C1에서 사람, 좀비, 줍는 물건, 무리 경고가 구별되는가.
3. C5에서 배경 생활이 표결 정보(숫자, 쐐기 색)를 가리지 않는가. 긴장 얼룩이 숫자와 얼굴에 닿지 않는가.
4. C7 세 장에서 어느 UI가 월드와 어울리는가. 특히 C7c에서 픽셀 UI가 비픽셀 월드 위에 떠 보이는지.
5. 빨강·하늘색이 정치 뜻과 경고 말고 다른 데 쓰이지 않았는가. 빨간 십자가 없는가.
6. C9에서 글 없이도 '물이 얼었다, 누가 먼저 왔다, 망자가 있다'가 읽히는가.
7. C10 네 장이 폰 크기에서 자세만으로 구별되는가. 같은 사람·같은 문으로 유지됐는가(동작 섞기로 만들 수 있는 범위인지).

## 평가 (2026-10-07, 1차 결과 12장)

그림은 공개 저장소에 올리지 않았다. 원본은 사용자 바탕화면 `화면컨셉_20261007\`, 사본은 프로젝트 파일 `art/concepts_20261007/`.

- **전체**: 필드(C1)와 정치 화면(C5, C6)이 같은 게임으로 보인다. 법랑과 놋쇠 HUD, 어두운 날씨, 호박색 불빛이 통일됐다. 필드는 눈 때문에 정치 화면보다 밝은데 자연스럽다.
- **C5 의회(v1을 기준으로 씀)**: 배경 생활(손가락질하는 사람, 아이 안은 여자, 수군거림)이 표결 정보를 가리지 않는다. 가장자리 긴장 얼룩은 성에처럼 약하게 나왔다. 고칠 것: 법안 창의 온기 +2가 하늘색이라 '하늘색은 지지에만' 규칙과 어긋난다. 기관실 명판 위에 십자처럼 보이는 모양이 있다.
- **C7 UI 세 벌**: a(두 재질)는 법안·지도자 카드가 진짜 서류처럼 읽히고, 고른 단추 뒤 그을음도 보인다. 종이 판이 밝아서 가운데 반원보다 눈을 먼저 끄는 건 마감 때 종이 명도를 낮춰 맞춘다. b는 깔끔하지만 요즘 앱처럼 보인다. c는 그림 배경 위에서 UI만 떠 보이고 초상만 픽셀로 깨진다. 추천은 a.
- **C1 필드(v2 추천)**: v2가 이름표가 있고 덜 복잡하다. 무리가 오는 왼쪽 가장자리의 붉은 성에, 발소리 원, 운송조와 호위조가 읽힌다. 고칠 것: 'JUNCTION' 같은 영어 표지판은 게임에선 그 나라 말로. v1은 망자가 마당 안까지 너무 가깝다.
- **C2 전술 일시정지**: 멈춤이 거의 안 보인다. 색 빠짐이 약하고 눈송이·증기가 멈춘 느낌이 없다. 조준 원과 적 조준 표시는 나왔다. 다시 뽑을 때 '화면 전체를 회갈색으로 확 바래게'를 더 세게 적는다.
- **C3 홈 v4**: v4 수정 여덟 가지 가운데 날씨(진눈깨비), 차가운 꼬리칸, 톱니·약병 명판, 녹색 벨벳, 놋쇠 신임 막대, 지나치는 승강장 가족이 됐다. 레버는 여전히 눈금 칸 없는 슬라이더이고, 난방관이 꼬리칸 앞에서 끊기는 게 안 보인다.
- **C4 한눈에 보기**: 세로 열차, 칸 묶음 괄호, 고른 칸과 창을 잇는 선, 레버와 반원 계기가 다 들어갔다. 고칠 것: 앞칸 의자가 빨강(빨강 규칙), 레버 단계가 셋(LOW/MED/HIGH)인데 단계 수는 아직 안 정했다.
- **C6 결정 카드**: 가장 잘 나왔다. 서류 뭉치에서 꺼낸 종이, 목탄 초상, 선택지 옆 비용과 즉시 정치 변화 막대, 목격자 눈. 고칠 것: 화면엔 성을 빼고 이름만 쓰기로 했으니 명판은 'Pavla'만.
- **C8 잉크 콘티**: 단계는 잘 나뉘었는데 검은 그을음이 어두운 법랑 위에서 잘 안 보인다(비교 데모에서도 같았다). 번짐 가장자리에 아주 옅은 따뜻한 테두리를 주거나 단추 바탕을 한 단계 밝혀야 한다.
- **안 나온 것**: C9 정차 장면, C10 하차 네 가지, C11 낡아 가는 UI.

## 평가 (2026-10-07, 2차 결과 9장)

C9 v1·v2, C10 v1·v2, C11 v1·v2·v3, C2 v2·v3. 보관 위치는 1차와 같다.

- **C9 정차 첫 장면**: 카메라 위치(기관차 약간 앞, 낮게, 열차 옆을 따라 뒤로 보는 구도)와 브레이크 증기·불꽃, 창에 붙은 얼굴, 얼어붙은 급수탑, 마을 굴뚝 연기는 둘 다 잘 나왔다. 정차 연출로 쓸 만하다. 문제는 **승강장에 이미 우리 사람이 내려와 있다는 것**이다(v1은 열차장과 수색조, v2는 상자 나르는 조). 다섯 박자 순서로는 이 장면이 하차 전 '읽기' 박자라 승강장이 비어 있어야 한다. 사람이 있으니 먼 끝의 망자 둘이 그냥 우리 사람처럼 보이고, '누가 먼저 왔다'는 발자국도 우리 발자국으로 읽힌다(점검 6번 절반만 통과). v2는 하차가 아니라 **떠나기 전 싣는 장면**으로 쓰기 좋다. → C9 v3을 다시 뽑는다(아래).
- **C10 하차 네 가지**: 같은 얼굴·같은 문·같은 구도가 넷 내내 유지돼서, 기본 하차 동작에 자세와 짧은 동작을 섞는 방식이 그림으로는 성립한다. 1(환영)은 둘 다 한눈에 읽힌다. 3(어깨 짚임)은 v2가 손이 어깨에 닿아 더 분명하다. **2(불신임 직전)와 4(감시당함)는 폰 크기에서 거의 같아 보인다.** 둘 다 '어두운 얼굴로 내리는 남자'다. 차이는 열차장 자세보다 주변(빈 창과 커튼, 문간의 무장 경비, 돌아서는 사람)에서 난다. 그래서 하차 장면 연출은 열차장 동작만이 아니라 **창과 문간의 반응을 같이 바꿔야** 구별된다(연출 문서에 반영). 열차장 얼굴은 캐릭터 생성(열린 질문 2) 전 임시다. 다시 뽑지 않는다.
- **C11 낡아 가는 UI(v3 추천)**: 녹은 테와 리벳에, 그을음은 가장자리에만 생겨서 공용 덧칠 마스크 방식과 맞는다. 세 단계 모두 글자와 숫자는 읽힌다. 고칠 것 셋.
  - **0단계가 이미 더럽다.** 종이 모서리에 검은 얼룩, 판 전체에 때가 있다. 0이 깨끗하지 않으면 낡아 가는 폭이 줄고, 처음 본 화면이 기준이 되므로 0은 정말 깨끗해야 한다.
  - **피가 너무 붉다.** v1·v2는 선홍색이라 경고 빨강과 헷갈린다. v3이 가장 어둡지만 아직 붉다. 마른 피는 짙은 갈색으로.
  - **얼룩이 아이콘에 닿는다.** 2단계 커피 자국이 기관차 아이콘에 걸치고(v1, v3), v2의 4단계는 결속 계기 유리에 금이 가서 칸이 가려진다. '글자·숫자·아이콘 위엔 아무것도 없다' 규칙과 어긋난다.
  → C11 v4를 다시 뽑는다(아래).
- **C2 전술 일시정지(v3 추천)**: 화면 전체가 회갈색으로 바래고 HUD, 조준 원, 명령 선만 색이 남아 이제 '멈췄다'가 바로 읽힌다. v2는 1차와 같이 약하다. 고칠 것: 왼쪽 위 '추위' 계기가 하늘색이다(C5와 같은 문제, 추위는 회백색 성에). 'JUNCTION' 영어 표지판은 C1과 같이 그 나라 말로. 다시 뽑지 않고 마감 때 고친다.

### C9 v3 (다시, 첨부: C9_stop_v1)

```text
Recreate the attached image with the same camera, train, station, weather and light, but this is the moment just after the train stops and before anyone has stepped off. The platform is completely empty of living people: no crew, no scavengers, no lanterns carried. Faces stay pressed to the glowing train windows, looking out. Keep the frozen water tower, the warning sign too far to read, the burnt-out car on the siding with its doors chained shut, crows on the roof and the thin chimney smoke in the village. Add a single line of old footprints and a dragged trail in the snow leading from the far end of the platform into the dark goods shed, half filled with fresh snow so they are clearly days old. At the far end of the platform two dead figures stand motionless in the fog, slightly hunched, arms hanging, clearly not living people. No text, no gore. Only the small translucent stop marker and one arrow button at the bottom-right corner.
```

### C11 v4 (다시, 첨부: C11_weathering_v3)

```text
Recreate the attached sheet with the same layout, labels, numbers and icons, with these changes. Stage 0 must be truly clean and new: no stains, no soot, no dark spots, crisp off-white paper, bright enamel, polished brass. Stage 2 stays as it is, but move the coffee ring so it touches no icon, only blank paper. Stage 4: keep the rust, soot, torn corner and creases, keep the gauge glass uncracked over the bars, and paint any blood as a few small dried smears in dark brown, almost black, never bright red, only on paper margins and one button rim, never on the portrait, text, numbers or icons.
```

## 평가 (2026-10-07, 3차: 다시 뽑은 C9·C11)

- **C9 정차(v3 확정)**: 승강장에 산 사람이 없고 창마다 얼굴, 먼 끝에 망자 둘, 화물창고로 들어가는 발자국과 끌린 자국이 읽힌다. 창고 입구 어둠 속 웅크린 사람은 지우지 않고 둔다. '창고 안에 뭔가 있다'는 단서라 읽기 박자에 오히려 맞다. v4는 그 사람을 지웠지만 발자국이 눈에 묻혀 '누가 먼저 왔다'가 안 읽힌다. 남은 아쉬움: 먼 망자 둘이 아직 산 사람처럼 곧게 서 있다(실제 장면에선 걸음걸이 동작으로 구별된다).
- **C11 낡아 가는 UI(v5 확정)**: 0단계가 정말 새것이고, 2단계 얼룩이 아이콘을 비켜 가고, 4단계 계기 유리가 멀쩡하다. 글자·숫자·아이콘 위엔 아무것도 없다. 다만 4단계 피가 이번엔 너무 옅어 거의 안 보인다(v3은 너무 붉었고 v5는 너무 숨었다). 그림은 이걸로 충분하고, 피 마스크의 진하기는 제작 때 조절값으로 맞춘다. v4는 커피 자국이 기관차 아이콘을 감싸서 탈락.
- 이로써 C1~C11 모두 기준 그림이 정해졌다. 더 뽑을 건 없다.

## 민감 표식 점검 (2026-10-07 07:50)

3D 모델링 스레드가 모델 렌더에서 철모·완장·휘장을 걸러 낸 뒤(main 6188d40, 7dd882e), 같은 눈으로 이 주문서의 기준 그림을 다시 봤다. 기준: europe_setting.md '조심할 것'(사람을 화물칸에 싣는 장면을 흉내 내지 않는다), 철모·완장·별·휘장·실제 군복 없음, 빨간 십자·초승달 없음.

- **C1 필드 v2: 걸림.** 호위조와 소총수 여럿이 2차대전식 철모에 군용 외투와 탄띠 차림이라, 화차 옆 무장 제복 무리로 읽힌다. M7b가 이 그림을 바탕으로 해서 같은 문제가 옮아갔다. 열차는 열린 석탄차와 객차라 괜찮다. → C1 v3 다시.
- **C3 홈 v4: 걸림.** 꼬리칸 둘이 창 없는 리벳 화차 안에 담요 쓴 사람들이 웅크린 모양이다. 장식이 없어도 이송 열차로 읽힐 수 있다. 그 칸 사람들 일부도 철모 같은 둥근 모자를 썼다. → 3D 스레드 카드의 추천안(꼬리칸은 낡은 3등 객차)대로 C3 v5 다시. 사용자가 '화차 개조 유지'를 고르면 이 판은 버린다.
- **C9 정차 v3: 작게 걸림.** 사람은 없고 열차는 객차라 괜찮다. 다만 옆 선로의 '문을 사슬로 감은 칸'은 안에 사람이 갇힌 봉인 차량을 떠올리게 한다. 내가 쓴 지시문 탓이다. → 사슬을 빼고 '불탄 객차'만 남긴 C9 v5.
- **C10 하차 v1·v2: 작게 걸림.** 철모·완장은 없다. 그런데 열차장 모자에 둥근 모표가 있고, 4번 칸 경비가 챙 모자에 가죽 띠, 소총이라 제복 경찰처럼 보인다. → 모표 없는 철도 모자, 경비는 귀덮개 털모자로 바꾼 C10 v3.
- **C4 한눈에 보기:** 위에서 본 칸이라 화차 모양 문제는 없다. 약 아이콘 하나에 십자 같은 흐린 무늬가 있어 마감 때 민무늬 병으로.
- **C5:** 기관실 명판의 십자 같은 모양은 1차 평가에 이미 적었다.
- **C2, C6, C7, C8, C11:** 걸리는 것 없음. C11 열차장 초상의 모표는 C10과 같이 마감 때 뺀다.

### C1 v3 (다시, 첨부: C1_field_v2)

```text
Recreate the attached image with the same camera, yard, weather, light and HUD, changing only the people and nothing else in the layout. Every person is a ragged civilian survivor in patched layered coats, scarves, knitted caps or fur hats with ear flaps; no steel helmets, no military greatcoats, no ammunition webbing, no uniforms, armbands, badges or insignia. The two escorts are told apart by a hunting rifle, a club and a hand lantern. The wagons stay open coal wagons; no closed freight wagons with people near their doors. No red cross or red crescent anywhere.
```

### C3 v5 (다시, 첨부: C3_home_v4_v1)

```text
Recreate the attached image with the same cross-section layout, weather, HUD and car order, with these changes. The two rear cars are old third-class wooden passenger coaches, not freight wagons: a row of small windows along the side, some boarded up with planks, a tarpaulin patch on the roof, a stove pipe. Inside, the same cold, crowded bunks and blankets. Nobody wears a helmet; people wear knitted caps, scarves and fur hats. The background siding shows only open coal wagons or empty passenger coaches, no row of closed freight wagons. No armbands, badges, insignia or red cross.
```

### C9 v5 (다시, 첨부: C9_stop_v3)

```text
Recreate the attached image exactly, changing only the old car on the left siding: it is a burnt-out passenger coach with broken and blackened windows and a collapsed roof corner; remove every chain and lock from its doors, and leave its doors hanging open on an empty interior.
```

### C10 v3 (다시, 첨부: C10_chief_states_v1)

```text
Recreate the attached four-panel sheet with the same people, poses, door and framing, changing only clothing details. The train chief's peaked railway cap has no badge, emblem or cockade. The armed guard in panel 4 wears a fur hat with ear flaps and a patched civilian coat with a rope belt instead of a peaked cap and leather belt, and holds a hunting rifle. Nobody wears a helmet, armband, badge, star or insignia.
```

### 다시 뽑은 결과 (2026-10-07 08:05)

네 장 모두 고칠 점이 풀렸다. 기준 그림을 바꾼다.

- **C1 v3**: 털모자, 니트 모자, 목도리 차림이고 철모·군용 외투·탄띠가 없다. 화차는 열린 석탄차, 뒤는 불 켜진 객차다. 배치와 HUD는 v2와 같다. → 필드 기준 그림은 C1 v3. M7b처럼 C1을 바탕으로 한 그림은 v3을 첨부한다.
- **C3 v5**: 꼬리칸 둘이 판자 막은 창, 방수포, 연통을 단 낡은 객차가 됐고 안의 춥고 비좁은 모습은 그대로다. 뒷배경 선로도 창 있는 객차 줄이다. 맨 왼쪽 끝에 창이 안 보이는 작은 차량 두세 대가 남았지만 사람은 없고 폰 크기에선 거의 안 보인다. 실제 배경을 만들 때 열린 석탄차나 객차로 둔다. → 홈 기준 그림은 C3 v5(꼬리칸은 객차, 08:21 사용자 확정).
- **C9 v5**: 옆 선로가 사슬 없이 문 열린 불탄 빈 객차다. 나머지는 v3과 같다. → 정차 기준 그림은 C9 v5.
- **C10 v3**: 열차장 모자에 모표가 없고, 4번 칸 경비는 귀덮개 털모자, 밧줄 띠, 사냥총이다. 덕분에 4번이 2번과 더 잘 갈린다. 뒤 승강장의 긴 외투 인물들에 표식은 안 보인다. → 하차 기준 그림은 C10 v3(3번 칸 어깨 짚임은 v2가 더 분명).

### 옷차림 (2026-10-07 08:25)

사용자가 사람들을 더 누더기처럼 하라고 했다. 기준 그림 C1 v3, C3 v5, C5, C10 v3의 옷은 기워 입었지만 아직 깔끔한 편이다. 이 그림들은 다시 뽑지 않는다. 사람 모습의 기준은 3D 모델링 스레드의 인물 모델이 정하고, 이 주문서의 그림은 화면 배치·빛·분위기 기준으로만 쓴다. 앞으로 뽑는 글상자에는 위 공통 화풍의 바뀐 옷차림 줄이 들어간다.

## 바깥 눈 점검 C 반영 (2026-10-07 12:40)

로컬 워커의 그림 조짐 점검(가지 research/design-review-20261007, docs/design/review/art_omens_check_20261007.md)에서 이 주문서 몫 둘이다.

- **C3 v5 경비칸 명판의 교차 장총**: 원래 명판 주문(image_prompts.md ⑤ 칸 명판 8개)은 경비 = 무늬 없는 방패였는데, 그림에서 교차한 장총으로 나왔다. 군 병과 표식처럼 읽힌다. 채택하지 않는다. 명판은 무늬 없는 방패로 둔다. C3 v5는 배치 기준이라 다시 뽑지 않고, C4 약 아이콘·C11 모표처럼 실제 에셋 때 고친다. C3 v5를 첨부하는 새 주문(구간 배경 B1~B8)에는 고침 줄을 넣었다.
- **조짐 자리**: 점검이 정차·필드 그림 네 장에 조짐 자리를 셋씩 잡았고, 소품을 정상·조짐·사건 뒤 세 상태로 묶자고 했다. 연출 문서 '조짐을 장면으로'에 규칙으로 넣었다. 폰 크기에서 세 상태가 읽히는지 C12로 한 번 본다.

## C12 조짐 세 상태 (첨부: C9_stop_v5)

```text
Using the attached image's camera, station, train, weather and light, make one image with three horizontal strips showing the same stopped-train view at three moments. Change only two props between the strips; everything else stays identical.

Prop A, beside the goods shed door on the left: top strip (normal) a few old footprints in the snow; middle strip (omen) a wide dark-brown drag mark leading over the snow to the shed threshold, one boot print beside it, and the hem of a coat moving behind a crate just inside the dark doorway; bottom strip (after) one of the dead has stepped out of the doorway onto the platform: grey-blue frozen skin, head hanging, stiff arms, dragging one foot, clearly not a living survivor (no gore).
Prop B, on the platform walkway in the middle: top strip a flat iron drain cover under a thin skin of ice; middle strip a heavy wooden crate lying on the cover with one corner sunk in, thick cracks spreading from under it and a black gap opening; bottom strip the cover has collapsed, the crate has dropped in and a dark hole blocks the walkway.

No warning text, no icons, no colored outlines; the props must read on their own at phone size. Blood and drag marks are small and dark brown, no gore. Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish.
```

공통 끝 두 줄(옷차림, 열차)을 붙인다. 저장은 바탕화면 `화면컨셉_20261007\C12_omen_states_v1.png`.

### C12 v1 평가 (2026-10-07 13:20)

- 읽힘: 세 상태가 폰 크기에서도 갈린다. 끌린 자국(가운데 줄)은 어두운 띠로 분명하고, 배수구 덮개의 금과 구멍도 잘 보인다. 문간의 외투 자락은 흐려서 끌린 자국 없이는 못 읽는다. 둘을 짝으로 두는 게 맞았다.
- **걸린 것 1, 내 주문 잘못**: 가운데 줄의 여행가방. 승강장, 열차 옆에 버려진 여행가방은 이송을 기리는 추모 상징과 겹친다(코디네이터 지적). 주문에서 내가 가방을 적었다. 나무 상자로 바꾸고, 공통 끝에 '승강장·열차 옆에 버려진 여행가방·짐 더미·신발 무더기 없음, 남긴 물건은 화물 자루와 나무 상자만' 줄을 더했다(구간 배경 주문서에도). 연출 문서의 조짐 조각 목록도 고쳤다.
- **걸린 것 2**: 아래 줄의 '사건 뒤' 인물이 산 노인처럼 보인다. 망자인지 생존자인지 모르면 조짐이 거짓말이 된다. 얼어붙은 회청색 피부, 늘어진 머리, 끄는 발로 고쳤다(고어 없음).
- 표식·군복은 안 보인다(로컬 워커 점검과 같음). → **v2를 다시 뽑는다**(위 글상자는 고친 판).

### C12 v2 평가 (2026-10-07 15:00)

평가용 사본은 `/mnt/project-files/art/concepts_20261007/C12_omen_states_v2.png`.

- **채택한다.** C12는 세 상태가 폰 크기에서 갈리는지 보려는 그림이었고, 그 목적은 채웠다. 다시 뽑지 않는다.
- v1에서 걸린 두 가지는 고쳐졌다. 가운데 줄의 짐은 나무 상자로 바뀌었고 여행가방은 없다. 아래 줄 인물은 회색 피부와 늘어진 머리, 굳은 팔로 그려져 산 노인보다 망자에 가깝게 읽힌다. 다만 외투를 입은 구부정한 사람과 아직 헷갈릴 여지가 있으니, 실제 에셋에서는 걸음새(끄는 발, 흔들리는 몸)를 움직임으로 더해 확실하게 한다.
- 배수구 줄(덮개, 상자가 내려앉고 금 감, 구멍)이 가장 잘 읽힌다. 끌린 자국은 갈색 띠로 보이고 고어는 없다.
- **걸린 것**: 위 줄(정상)의 창고 문간 안쪽에 사람 그림자가 이미 서 있다. 정상 상태에 조짐이 새어 들어간 것이다. 다시 뽑을 일은 아니지만 실제 에셋에서는 정상 문간을 비운다. 연출 문서의 세 상태 규칙에 '정상 상태에는 조짐 단서가 없다'를 덧붙였다.
- 세 줄 모두 승강장 먼 쪽에 걸어가는 사람 둘이 있다. 줄마다 같으니 상태 비교는 흐리지 않는다. 실제 장면에서 이런 배경 인물은 생존자로 읽히는 옷과 움직임으로 둔다.
- 금지 목록(표식, 군복, 철조망, 연기 나는 굴뚝, 버려진 가방·신발 더미, 사람 칸의 빗장·쇠창살)은 보이지 않는다. 객차 창의 얼굴들은 불 켜진 창 안쪽이고 창살은 없다.
