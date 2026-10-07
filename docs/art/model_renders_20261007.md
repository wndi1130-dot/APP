# 3D 모델 시안 렌더링 주문서 (2026-10-07)

작성: 2026-10-07 "모델링 시안" 스레드 · 상태: 주문서. 그림은 3D로 만들면 어떻게 보일지 보는 시안이고, 게임에 그대로 넣지 않는다.

## 왜 뽑나

1. 사용자 요청(2026-10-07): 정치 시뮬이 벌어지는 의회 칸, 열차, 열차장·승객·좀비가 3D로 모델링되면 어떻게 보이는지 본다.
2. 3D 여부를 사용자가 판단할 재료를 만든다. 결정됨(2026-10-07 08:21 사용자): 전부 실시간 3D, S2 성능 시험이 안 되면 다시 본다([../design/decisions.md](../design/decisions.md) '개발 순서', 8b2273b).
3. 화면 컨셉 C1~C11은 영화 같은 마감이라 폰 게임으로 실제 나올 모습보다 훨씬 곱다. 이번엔 **갤럭시 S22에서 실시간으로 돌릴 만한 수준**으로 그려서 그 차이를 본다.
4. 사용자 기준(2026-10-07): "탑다운이니까 좀보이드처럼 고퀄리티가 아니어도 되고, 상당히 뭉개져도 된다." 그래서 마감 목표는 **좀보이드 수준**이다. 단순한 덩어리 모델, 가까이 보면 뭉개지는 저해상도 텍스처, 화면에선 작게 보이는 사람. 그림은 디테일이 아니라 빛·안개·실루엣으로 읽힌다.
5. 모델만이 아니라 **게임 안에서 어떻게 보이고 움직이는지**까지 연출로 보여 준다(M8 정차 한 번의 흐름).

## 그림으로 알 수 있는 것과 없는 것

- 알 수 있는 것: 모델의 덩어리와 실루엣, 옷·소품을 모듈로 갈아 끼우는 방식, 폰 크기에서 사람·좀비가 구별되는지, 화면 컨셉과 같은 세계로 보이는지.
- 알 수 없는 것: 실제 폴리곤 수, 텍스처 용량, 프레임. 이미지 모델은 "3D처럼 보이는 그림"을 그릴 뿐 모델을 만들지 않는다. 폰에서 돌아가는지는 S2 성능 시험([../handoff/s2_perf_spike.md](../handoff/s2_perf_spike.md))이 판단한다. 그 시험 장면(회색 역, 좀비 100마리, 단면 → 정차 카메라 → 탑뷰)이 곧 진짜 모델로 만든 첫 게임 화면이다. 이 그림들은 그 회색 상자에 어떤 모델과 마감을 입힐지 정하는 목표다.
- 그래서 모델 시트마다 **회색 점토(텍스처 없음)와 텍스처 입힌 판을 나란히** 그리게 했다. 점토 판이 모델링 자체를 보는 판이다([reference_analysis.md](reference_analysis.md) '3D 단면의 제작량'의 점토 렌더 제안).

## 0단계: 참고 자료 모으기 (Codex 6.1 sol)

사용자 지시(2026-10-07): 자료에 있는 레퍼런스와 3D 자료를 먼저 보고, 없으면 6.1 sol이 검색한다. 그림을 뽑기 전에 아래를 모아 `모델컨셉_20261007\ref\`에 둔다. **공개 저장소에는 올리지 않는다**(남의 게임 화면, 남의 모델 미리보기 그림).

이미 있는 자료(먼저 본다):
- 3D 제작 자료 85개 목록: [research/3d-resources-and-art-direction-20261007 브랜치 ref/art/README.md](https://github.com/wndi1130-dot/APP/tree/research/3d-resources-and-art-direction-20261007/ref/art). 사람 기본 몸은 Quaternius Universal Base Characters와 MPFB(MakeHuman), 동작은 Quaternius 동작 모음, 열차·건물 회색 상자는 Kenney Train Kit·Modular Buildings·Furniture Kit, 재질은 Poly Haven·ambientCG.
- 좀보이드식 그래픽이 어떻게 그려지는지: [research/field-mechanics-20261007 브랜치 graphics.md](https://github.com/wndi1130-dot/APP/tree/research/field-mechanics-20261007/docs/research/field_mechanics/graphics.md). 실제 3D 월드 + 고정 카메라 + 방 단위 벽 자르기 + 시야 어둠.
- 우리 화면 컨셉: 바탕화면 `화면컨셉_20261007\`(기준 그림 C1 v2, C3, C5 v1, C9 v3, C10 v1).

모을 것(없으면 검색):
1. 좀보이드 B42의 기본 줌 게임 화면 2~3장(눈 오는 날, 밤 실내 하나 포함). 마감 수준과 사람 크기를 맞추는 기준이다.
2. 위 목록의 Quaternius 기본 몸, Kenney Train Kit, Kenney Modular Buildings 공식 미리보기 그림 각 1장. 점토 판의 덩어리 크기 기준이다.
3. 폰 탑다운 3D 생존 게임의 실제 게임 화면 2~3장(좀비가 여럿 나오는 장면). 폰에서 사람이 몇 픽셀로 보이는지 보는 기준이다.
4. 낮은 폴리곤 증기기관차·객차 모델 미리보기 1~2장(무료 모델 사이트의 것이면 출처 주소를 같이 적는다).
5. 좀보이드식 벽 자르기(방 안이 보이도록 앞벽을 낮추거나 걷어 낸 화면) 1장.

각 자료는 파일 이름과 출처 주소를 `ref\sources.txt`에 한 줄씩 적는다. 첨부는 **마감과 크기를 맞추는 데만** 쓰고, 프롬프트에 그 게임이나 사이트 이름을 넣지 않는다. 아래 글상자에서 '첨부: ref'라고 적은 곳에 1번(없으면 3번) 그림을 하나 붙인다.

## 받는 사람에게 (로컬 워커)

- 아래 글상자를 그대로 이미지 모델에 넣는다. 첨부 그림은 각 항목에 적었다. C 번호 그림은 사용자 바탕화면 `화면컨셉_20261007\`에 있다.
- 결과는 **공개 저장소에 올리지 않는다.** 사용자 바탕화면 `모델컨셉_20261007\`에 `M1_council_ingame_v1.png`처럼 번호를 붙여 저장한다.
- 한 항목은 두 장까지 뽑아 나은 쪽을 고른다. 고르지 못하면 둘 다 둔다.
- 한글 글자는 그리게 하지 않는다. 작품 이름은 프롬프트에 넣지 않는다([reference_analysis.md](reference_analysis.md) 4장).
- 순서: **0단계 자료 → M1 → M3 → M3b → M7b → M8 → M6 → M2 → M3c → M5 → M4 → M7a → M7c.** 사용자가 정치 시뮬을 먼저 짚었으니 의회 칸(M1)을 먼저, 그다음 사람(M3), 탑뷰 게임 화면(M7b), 연출(M8)이다.
- 앞 항목의 결과를 뒤 항목에 첨부하는 곳이 있다(M5는 M3 결과, M4는 M3·M3b 결과). 앞 결과가 없으면 그 첨부만 빼고 뽑는다.
- 세션 나누기: [model_render_jobs_20261007/](model_render_jobs_20261007/)에 이 주문서를 세션 하나에 그림 하나씩 나눈 작업 파일과 실행 순서(`00_실행순서.md`)가 있다. 바탕화면 `모델컨셉_20261007\_jobs\`로 복사해 쓴다. 0단계 조사 5, 1단계 렌더 18, 스레드가 고르는 관문, 2단계 4, 3단계 2다.

## 공통 화풍 (모든 글상자에 이미 들어 있음)

문구를 고칠 때만 여기를 본다. 화면 컨셉 공통 화풍과 색 규칙은 같고, 마감만 "폰에서 도는 좀보이드 수준 실시간 3D"로 낮췄다.

```text
Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion; no strand hair, no cloth simulation, no film-quality skin. The picture reads through light, fog and silhouette rather than surface detail. Believable adult proportions, never chibi or cartoon. Setting: Central Europe in the sixth winter after civilization collapsed and the dead rose. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost; the only warm colour is amber lamp and fire light. Red is reserved for danger warnings and sky blue for political support, so neither appears on any model. People are exhausted civilians in layered patched coats; some have dark dried blood soaked into bandages or cloth, but no wounds or gore are shown. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, Victorian ornament, logos, real weapon brand marks, red cross symbols, readable text.
```

모델 시트(M2~M6)의 판 짜기:

```text
Model sheet on a plain mid-grey studio background with a faint floor grid and soft even light. Top row: untextured matte light-grey clay with visible flat-shaded facets, so the polygon structure and silhouette can be judged. Bottom row: the same models fully textured. Identical poses and camera angles in both rows. No labels except tiny placeholder numbers.
```

## M1 의회 칸: 게임 화면 그대로 (첨부: C5_council_v1, ref)

C5와 같은 화면을 폰에서 실제로 도는 3D로 낮춰 본다. UI는 그대로 두고 배경 세계만 바꾼다. 배경 사람들은 짧은 반복 동작(수군거림, 손가락질, 흔들리는 등불)으로 돌아가는 저폴리 인물이다([../design/briefs/presentation_motion.md](../design/briefs/presentation_motion.md) 의회 배경 생활).

```text
Edit the attached image. Keep the camera, the composition and the entire UI layer exactly: the semicircle of seats, the telegraph needle, the counter, the bill panel, the leader card, the trade buttons, the top HUD and the sooty stain at the screen edges. Change only the world behind the UI so it looks like a real-time 3D scene running on a phone, as in an actual game screenshot. Use the last attached reference image only to match its level of detail, texture softness and how small people appear on screen; copy nothing else from it.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion; no strand hair, no cloth simulation, no film-quality skin. The picture reads through light, fog and silhouette rather than surface detail. Believable adult proportions, never chibi or cartoon. Setting: Central Europe in the sixth winter after civilization collapsed and the dead rose. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost; the only warm colour is amber lamp and fire light. Red is reserved for danger warnings and sky blue for political support, so neither appears on any model. People are exhausted civilians in layered patched coats; some have dark dried blood soaked into bandages or cloth, but no wounds or gore are shown. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, Victorian ornament, logos, real weapon brand marks, red cross symbols, readable text.

The dining car interior is a simple real-time set: a long box with wooden wall panels, repeated tables and benches, a few hanging oil lamps that are the only light sources, a cast-iron stove glowing at the far end, frost on the window panes and a dark blurred forest scrolling past outside. The forty delegates are low-poly game characters built from a few shared bodies with swapped coats, caps and scarves, so some look alike; their faces are simple painted textures, readable only as expressions at this distance. Several are caught mid-loop in simple idle animations: two leaning together whispering, one standing and pointing, a woman rocking a child, a guard leaning on the wall. Lamp light pools are soft and baked, shadows are simple. The background stays slightly out of focus so the UI reads first.
```

## M2 의회 칸 세트: 분해한 모델 (첨부: C5_council_v1, C3_home_v5)

한 칸 모델을 홈 단면, 한눈에 보기, 의회 배경에 같이 쓰려면 지붕과 앞벽을 뗄 수 있어야 한다. 그 조립 구조를 본다.

```text
Use the attached images only for the materials, mood and the kind of train car. Draw a 3D model sheet of one passenger dining car of our train, used both as the council chamber and as one car of the side cross-section view.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion. Setting: Central Europe in the sixth winter after civilization collapsed. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost; the only warm colour is amber lamp light. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, Victorian ornament, logos, red cross symbols, readable text.

Model sheet on a plain mid-grey studio background with a faint floor grid and soft even light. Top row: untextured matte light-grey clay with visible flat-shaded facets, so the polygon structure and silhouette can be judged. Bottom row: the same models fully textured. Identical poses and camera angles in both rows. No labels except tiny placeholder numbers.

Each row shows, left to right: (1) the closed car in three-quarter view: an old wooden-bodied passenger car with a curved roof, riveted steel underframe, two bogies, patched planks and a bolted-on steel plate over two windows; (2) an exploded view of the same car from slightly above: the roof lifted straight up, the near side wall slid out sideways, and the floor with its interior left in place, showing that the car is a few separate parts; (3) the interior kit laid out in a neat row: a long table, a bench, a hanging oil lamp, a cast-iron stove, a wooden ballot box with two bowls of stones, a stack of crates, a coat hook rail; (4) the assembled interior seen from the in-game council camera, from one end of the car looking down its length, with no people.
```

## M3 열차장 모델 시트 (첨부: C10_chief_states_v3)

열차장은 플레이어가 만든다(성별, 체격 셋, 나이대 셋, 직업 16, 부위 조합 얼굴: [../design/briefs/character_creation.md](../design/briefs/character_creation.md) 5장, 초안). 이 시트는 그 가운데 기본값 하나(보통 체격 40대 남자)를 C10과 같은 사람으로 맞춘 것이다. 오른쪽 아래 작은 그림은 탑뷰 필드에서 실제로 보일 크기로, 폰에서 알아볼 수 있는지 본다.

```text
Use the attached image only for this character's face, build and clothing. Draw a 3D character model sheet of him.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion; no strand hair, no cloth simulation, no film-quality skin. The picture reads through light, fog and silhouette rather than surface detail. Believable adult proportions, never chibi or cartoon. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, logos, real weapon brand marks, readable text.

Model sheet on a plain mid-grey studio background with a faint floor grid and soft even light. Top row: untextured matte light-grey clay with visible flat-shaded facets, so the polygon structure and silhouette can be judged. Bottom row: the same models fully textured. Identical poses and camera angles in both rows. No labels except tiny placeholder numbers.

The character: the train chief, a weathered man in his forties with a short dark beard, in a long dark railway greatcoat with a fur collar, a peaked railway cap, a leather satchel on a strap, gloves and worn boots; frost caught on his shoulders. Each row shows him four times in a relaxed A-pose: front, three-quarter, side and back. The beard and fur collar are simple solid shapes with painted texture, not strands; the coat skirt is one solid piece. Hair, beard and cap read as separate simple pieces fitted onto one head, the way a modular character is assembled. On the right side of the sheet: a close-up of the textured head; below it, the same textured character shown tiny, about 40 pixels tall, from a three-quarter top-down camera at about 40 degrees on a patch of snowy ground, holding a lantern, exactly as small as he would appear in the top-down field view on a phone.
```

## M3b 기본 몸 여섯과 변형 (첨부 없음)

열차장 만들기 초안(character_creation.md 5장, 10장)의 3D 몸 안이다. 체격 셋(마른·보통·다부진) × 성별 둘 = 기본 몸 여섯. 쇠약은 같은 몸을 마른 쪽으로 미는 변형(블렌드 셰이프), 나이대는 머리색과 자세로 보인다. 몸 여섯이 탑뷰 크기에서 갈리는지, 쇠약과 나이가 옷 없이도 읽히는지 본다.

```text
Draw a 3D base-body sheet for a mobile survival game: the few shared mannequin bodies that every character in the game is built on before clothing is added. All six share one skeleton and one animation set.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion; no strand hair, no cloth simulation, no film-quality skin. The picture reads through light, fog and silhouette rather than surface detail. Believable adult proportions, never chibi or cartoon. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, logos, readable text.

Model sheet on a plain mid-grey studio background with a faint floor grid and soft even light. The bodies are smooth untextured matte light-grey clay mannequins with visible flat-shaded facets and plain moulded grey thermal underwear, no anatomical detail. No labels except tiny placeholder numbers.

Top row, six bodies standing in a relaxed A-pose in three-quarter view, left to right: thin man, average man, sturdy man, thin woman, average woman, sturdy woman. Thin is narrow and wiry; sturdy is broad-shouldered with thick arms and legs, strong rather than fat; none is heavy or obese. Middle row, left half: the average man and the average woman beside a starved version of the same mesh, pushed toward gaunt: hollow cheeks, sunken chest, sharp collarbones and elbows, thin neck, shown as the same body morphed, not a new model. Middle row, right half: the average man three times, changed only by hair colour and posture to show age: thirties standing upright with dark hair; forties slightly settled with grey at the temples; fifties and over with white hair and a forward-hunched stance. Bottom strip: the six bodies again, now tiny, about 40 pixels tall each, seen from a three-quarter top-down camera at about 40 degrees on a patch of snowy ground, to judge whether the builds still read at phone size.
```

## M3c 얼굴 부품 (첨부: C10_chief_states_v3)

얼굴은 부위 조합(얼굴형, 눈, 코, 머리, 수염, 흉터)으로 만든다(character_creation.md 5.4). 얼굴은 탑뷰 40픽셀에서는 거의 안 보이고 하차 연출, 정차 카메라, 초상에서 보인다. 그래서 아래 띠에 작은 크기에서 무엇이 남는지(머리 모양, 수염, 모자 실루엣)를 같이 그리게 했다.

```text
Use the attached image only as a guide to the level of realism and the weathered look of the people. Draw a 3D modular face-parts kit sheet for a mobile survival game, where every character's head is assembled from a few swappable parts.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion; no strand hair, no cloth simulation, no film-quality skin. The picture reads through light, fog and silhouette rather than surface detail. Believable adult proportions, never chibi or cartoon. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, logos, readable text.

Kit sheet on a plain mid-grey studio background with soft even light. No labels except tiny placeholder numbers. Top left: one neutral base head in untextured matte light-grey clay with visible flat-shaded facets, front and three-quarter view. To its right, a grid of clay heads, one row per part, each part shown in a slightly warmer clay tone on the same neutral head: face shape (narrow, broad, square-jawed); eyes and brows (deep-set, heavy-lidded, narrow); nose (straight, broken, broad); hair as solid sculpted shapes (cropped, receding, long hair tied back, shaved with stubble); beard (none, stubble, short full beard); scar (none, a cheek scar, a frost-bitten ear). Bottom strip: four finished textured heads assembled from different combinations, two men and two women of different ages from thirties to sixties, each with weathered, wind-burned skin; next to each, the same character shown tiny, about 40 pixels tall, from a three-quarter top-down camera in a winter hat and coat, to show what of the face survives at phone size.
```

## M4 승객 다섯 공동체 (첨부: M3 결과, M3b 결과, C3_home_v5)

공동체 다섯은 [../design/decisions.md](../design/decisions.md) '세계관'의 탄 순서를 따른다. 같은 몸 몇 개에 옷과 소품을 바꿔 끼우는 방식이라야 사람 200명을 만들 수 있다. 그 방식이 그림에서 자연스러운지 본다. 다섯은 M3b의 몸 여섯 가운데 다섯을 하나씩 쓰고(보통 남자는 M3 열차장), 꼬리칸 피난민은 쇠약 변형이다.

```text
Match the modeling style and finish of the first attached image. Draw a 3D model sheet of five train passengers, one from each community on our train, built from a small set of shared base bodies (three builds, thin, average and sturdy, each in a male and a female version) with swapped clothing and props. The first attached image fixes the modeling finish; the second shows the bare base bodies.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion; no strand hair, no cloth simulation, no film-quality skin. The picture reads through light, fog and silhouette rather than surface detail. Believable adult proportions, never chibi or cartoon. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost. People are exhausted; some have dark dried blood soaked into bandages, but no wounds or gore. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, logos, real weapon brand marks, red cross symbols, readable text.

Model sheet on a plain mid-grey studio background with a faint floor grid and soft even light. Top row: untextured matte light-grey clay with visible flat-shaded facets, so the polygon structure and silhouette can be judged. Bottom row: the same models fully textured. Identical poses and camera angles in both rows. No labels except tiny placeholder numbers.

Five figures in three-quarter view, standing in neutral poses, left to right: (1) an old locomotive engine driver from the depot, sturdy man, white hair and a slight stoop: coal-blackened padded jacket over oily overalls, a fur-lined cap with ear flaps, goggles pushed up, a heavy wrench; (2) a well-off front-car passenger, average-build woman: a good but frayed wool overcoat with a fur collar, a felt cloche hat, leather gloves, a small locked case; (3) a guard, sturdy woman: a patched quilted winter coat over a long railway-company coat, a fur-lined cap with ear flaps, a bolt-action rifle on a sling, a short wooden club and a hand lantern; (4) a technician and medic, thin man: a long leather apron over layered sweaters, a tool roll and a canvas bag, wire spectacles; (5) a tail-car refugee, thin woman visibly starved, hollow-cheeked and gaunt: wrapped in a grey blanket over layered rags, cloth-wrapped feet, a bandaged hand with a dark dried stain, a bundle on her back. Behind each figure, a faint ghosted outline of the bare base body it uses shows that the five are built from the same few bodies with different outfits.
```

## M5 좀비 상태 넷 (첨부: M3 결과)

[../design/briefs/zombies.md](../design/briefs/zombies.md)의 상태 넷이다. "실루엣·색·소리로 알아볼 수 있어야 한다"는 원칙이 있어서, 아랫줄은 검은 실루엣만으로 구별되는지 본다(이 항목만 판 짜기가 다르다).

```text
Match the modeling style and finish of the attached image. Draw a 3D model sheet of the four kinds of the dead in our game, all built on the same shared human base body as the living, so they read as ordinary people who died.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion; no strand hair, no cloth simulation. Believable adult proportions, never cartoon. The dead have greyish waxy skin, clouded eyes, torn and soiled winter clothing and dark dried stains, but no open wounds, no exposed bone and no gore. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, logos, red cross symbols, readable text, monster features, glowing eyes.

Model sheet on a plain mid-grey studio background with a faint floor grid and soft even light. Top row: the four figures fully textured in three-quarter view. Middle row: the same four in untextured matte light-grey clay with visible flat-shaded facets. Bottom row: the same four as solid black silhouettes only, to test whether each can be told apart by shape alone. Tiny placeholder numbers only.

Left to right: (1) the common dead: hunched, head hanging forward, arms loose, one foot dragging, in a torn civilian coat; (2) the freshly risen: standing straighter and leaning forward as if about to hurry, cleaner clothes, skin only slightly grey; (3) the frozen: rigid and half-crouched, the whole body crusted with pale grey-white frost and ice, a lump of snow on the shoulders and head; (4) the bundled: a bulky silhouette in a thick padded work coat and a heavy scarf, wider than the others, arms held away from the body by the padding.
```

## M6 열차 겉모습 (첨부: C3_home_v5, C9_stop_v5)

필드와 정차 장면에 쓰일 열차 바깥이다. 앞머리의 쐐기형 금속(decisions.md '좀비')과 덧댄 철판을 모듈 부품으로 본다.

```text
Use the attached images only for the train's mood, materials and weather wear. Draw a 3D model sheet of our steam train.

Real-time 3D for a mobile survival game seen mostly from a top-down three-quarter camera, shown as it would actually look running on a mid-range phone, not a cinematic render: low polygon count with simple blocky forms and clear silhouettes; deliberately low-resolution painted textures that look soft and smudged when seen up close; baked ambient occlusion. Setting: Central Europe in the sixth winter after civilization collapsed. Muted palette of soot black, umber, rust, olive, slate and pale grey-white frost; the only warm colour is amber light from windows and the firebox. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; guards and crew wear mismatched civilian and railway winter clothing. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes. Textures look hand-painted and blurred, never blocky pixel mosaics or camouflage-like squares. Avoid: pixel art, glossy product renders, Victorian ornament, logos, red cross symbols, readable text.

Model sheet on a plain mid-grey studio background with a faint floor grid and soft even light. Top row: untextured matte light-grey clay with visible flat-shaded facets, so the polygon structure and silhouette can be judged. Bottom row: the same models fully textured. Identical poses and camera angles in both rows. No labels except tiny placeholder numbers.

Each row, from right to left in three-quarter view: (1) an old museum-restored steam locomotive with its tender, a large welded wedge-shaped steel plough over the front buffers for pushing through the dead on the track, extra steel plates bolted around the cab; (2) the front car: an old sleeper car with curtained windows; (3) the dining car with a stovepipe through its roof; (4) the tail car: a worn-out old wooden third-class passenger carriage with a row of passenger windows, some boarded or patched with planks, a crooked stovepipe and tarpaulin over a broken roof section; it must read clearly as a passenger carriage, never as a closed freight wagon. At the right end of the sheet, a small kit of separate add-on parts laid out on the floor: two bolt-on armour plates, a window grille, a roof lookout platform with a railing, a snow-covered tarpaulin, a coupler with chains.
```

## M7 게임 화면 안에서 (폰 실시간 3D 마감)

화면 컨셉 기준 그림을 같은 구도로 두고 마감만 폰 실시간 3D로 낮춘다. 영화 같은 C 그림과 나란히 놓고 "실제로는 이 정도"를 본다. 각 한 장, 많아도 두 장.

### M7a 홈 단면 (첨부: C3_home_v5, ref)

```text
Edit the first attached image. Keep the camera, the composition, the HUD and every UI element exactly. Use the last attached reference image only to match its level of detail, texture softness and how small people appear on screen; copy nothing else from it. Re-render only the world so it looks like a real-time 3D game screenshot running on a phone, not a cinematic painting: the train cars are simple low-poly boxes with the near wall removed, interiors built from a small kit of repeated bunks, tables, lamps and crates; the passengers are small low-poly figures from a few shared bodies, some in simple idle poses; lamp light is soft and baked with simple shadows; sleet is simple particle streaks; distance fog hides the far hills and village, which are flat low-detail shapes. Keep the dark drab weather, the amber warmth inside and the pale grey-white frost. No red and no sky blue on the world, no red cross symbols, no readable text. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; replace any such items from the attached images with mismatched civilian and railway winter clothing and fur-lined caps. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes.
```

### M7b 필드 탑뷰 (첨부: C1_field_v3, ref. 1단계는 v2로 뽑음)

```text
Edit the first attached image. Keep the camera angle, the place, the characters' positions and the HUD exactly. Use the last attached reference image only to match its level of detail, texture softness and how small people appear on screen; copy nothing else from it. Re-render only the world so it looks like a real-time 3D game screenshot running on a phone, not a cinematic painting: buildings, wagons, the water tower and the coal pile are simple blocky low-poly models with low-resolution, slightly smudged painted textures and baked shadows; the near walls of the goods shed are cut down to knee height so its inside is visible, as top-down survival games do; the ground is a tiled snow texture with a few decals for tracks, puddles and footprints; the characters and the dead are small low-poly figures about 40 to 50 pixels tall with readable silhouettes and simple painted faces; sleet is simple particle streaks; fog is a flat distance fog that hides the screen edges. Keep the red-tinged frost warning at the horde's screen edge as a flat UI overlay. No sky blue anywhere except political UI, no red cross symbols, keep any sign text unreadable. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; replace any such items from the attached images with mismatched civilian and railway winter clothing and fur-lined caps. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes.
```

### M7c 정차 장면 (첨부: C9_stop_v5, ref)

```text
Edit the first attached image. Use the last attached reference image only to match its level of detail, texture softness and how small people appear on screen; copy nothing else from it. Keep the camera, the composition and every element of the scene exactly: the empty platform, the faces in the windows, the frozen water tower, the burnt-out car, the footprints into the goods shed, the two dead at the far end. Re-render it so it looks like a real-time 3D game scene running on a phone, not a cinematic painting: the train and station are low-poly models with soft painted textures; steam and sleet are simple particle sprites; light comes from the amber train windows and one or two lamps with simple soft shadows; distance fog hides the village and trees as flat shapes; the faces in the windows are small simple painted figures. No readable text, no gore. Keep only the small translucent stop marker and one arrow button at the bottom-right corner. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; replace any such items from the attached images with mismatched civilian and railway winter clothing and fur-lined caps. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes.
```

## M8 연출: 정차 한 번의 흐름 (첨부: M7a 결과, M7c 결과, M7b 결과)

사용자 요청(2026-10-07): 모델이 게임 안에서 어떻게 보일지 연출까지 본다. [../design/decisions.md](../design/decisions.md) '정차 연출'의 다섯 박자(단면 주행 → 정차 → 옆 앞쪽 카메라 → 하차 → 탑뷰 파밍)에 돌아와서 의회로 이어지는 박자를 더해 여섯 칸 콘티로 그린다. 모두 같은 열차, 같은 사람, 같은 역, 같은 좀보이드 수준 마감이다. 실제 움직임은 S2 성능 시험의 카메라 전환에서 본다.

```text
Using the three attached images for the train, the station, the people and the rendering fidelity, draw a storyboard sheet of six wide panels in two rows of three, each panel a phone game screenshot in very wide landscape, separated by thin dark gaps, showing one stop from start to end. Everything is real-time 3D as it would look running on a phone: simple blocky low-poly models, low-resolution slightly smudged painted textures, small figures, simple particle steam and sleet, flat distance fog, amber window light. Same train, same chief, same station and same dusk weather in every panel. No gore, no logos, no red cross symbols, no readable text. Tiny panel numbers 1 to 6 only.
Panel 1, running: the side cross-section of the moving train with the near walls removed, small passengers inside the cars, the snowy plain sliding past, the full home HUD at the edges.
Panel 2, braking: the same side view, the train slowing at a small station, bright sparks under the wheels and a burst of steam from the brakes, the HUD fading out.
Panel 3, the camera swings: the camera has moved low beside the track ahead of the locomotive and looks back along the stopped train; empty platform, faces in the amber windows, the frozen water tower, two dead figures far down the platform in the fog. Only a small stop marker remains.
Panel 4, stepping down: a medium shot at an open carriage door; the train chief in his long dark greatcoat steps down onto the platform with three scavengers behind him (a woman with a fire axe, a young man with a lantern, an older man with a rifle); faces watch from the windows.
Panel 5, the field: the camera has risen to a fixed top-down three-quarter view at about 40 degrees over the station yard; the four small figures move toward the goods shed whose near walls are cut low to show its inside; a soft noise circle around the chief; the dead slowly turning toward them at the foggy screen edge; the small field HUD with gauges at the top and thumb controls in the bottom corners.
Panel 6, back aboard: the side cross-section again, the train pulling away; in the dining car several small figures crowd around a table where the chief stands, the start of a council session; a small paper document icon glows at the left edge. Nobody wears armbands, stars, badges, cap badges, rank marks, insignia, the uniform of any real army or steel combat helmets, and there is no red cross, red crescent or cross-shaped medical emblem anywhere; replace any such items from the attached images with mismatched civilian and railway winter clothing and fur-lined caps. People live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Cars with people inside never show chains, bars, padlocks or nailed-shut doors; their doors open normally or stand ajar, and planks or scrap plates patch walls and roofs but never seal all of a car's windows, so warm light and faces still show through. Everyone and everything is ragged after six winters: clothes are worn in many mismatched layers, torn at the cuffs and hems, patched again and again with different cloth, tied with rope and strips of blanket, stained with soot, grease and grime and faded to dull colours; bundles are lashed with cord. Train cars and walls are battered and improvised: rusted and scorched metal, plywood and plank patches, scrap plates bolted over holes, tarpaulins, ropes and stovepipes.
```

## 민감한 표식 규칙 (07:45 추가)

2단계 M4 경비가 누런 완장과 2차대전식 철모를 쓰고 나왔고, M4 의무진은 흰 완장, M5 껴입은 자 v1은 털모자에 작은 휘장이 있었다. M7b 필드 사람들도 철모와 군용 외투 차림이라 화물칸 옆에서 무장한 제복 무리로 읽힌다. 이 시대와 지역에서는 그런 그림이 민감한 역사를 떠올리게 하고, 우리 원칙은 관련 묘사를 아예 넣지 않는 것이다. 그래서 모든 글상자에 '완장, 별, 배지, 휘장, 실제 군대 제복, 철모 없음. 경비와 대원은 섞인 민간·철도 방한복' 문장을 넣고, M4 경비와 의무진, M5 껴입은 자의 옷을 고쳤다. 경비는 소총, 짧은 몽둥이, 손등불, 귀덮개 털모자로 알아보게 한다. 같은 문장에 '텍스처는 칠해서 뭉갠 것, 픽셀 모자이크 아님'도 넣었다(1단계 평가의 주의).

07:55 더함: 빨간 십자·적십자 표장(빨간 초승달, 십자 모양 의료 표식 포함)은 어디에도 넣지 않는다. 제네바 협약과 각국 법이 보호하는 표장이라 게임에서도 피하는 게 관례다. 꼬리칸은 개조한 유개화차가 아니라 낡은 3등 객차로 바꿨다([../design/briefs/europe_setting.md](../design/briefs/europe_setting.md) '조심할 것': 사람을 화물칸에 싣는 장면을 흉내 내지 않는다). 사람이 사는 칸은 객차 모양, 닫힌 화차는 짐과 석탄에만 쓴다. 이 방향은 사용자 확인을 기다리는 안이다.

## 더 누더기로 (08:25 추가)

사용자(2026-10-07 08:21): "좀 더 누더기 같아야 됨. 프로스트펑크나 워킹데드, 레프트 4 데드가 좋은 예시." 모든 글상자에 '여섯 겨울을 버틴 누더기' 문장을 넣었다: 짝 안 맞는 여러 겹, 해진 소매와 단, 몇 번이고 덧댄 천, 끈과 담요 조각으로 묶음, 그을음·기름·때, 바랜 색. 열차와 벽은 녹슬고 그을린 쇠, 합판·판자 덧댐, 구멍 위에 볼트로 박은 고철판, 방수포, 밧줄, 연통. 작품 이름과 캐릭터는 프롬프트에 넣지 않는다(특정 캐릭터를 닮으면 상업 게임에 위험하다). 참고 그림은 6단계 R6으로 모으고, 첨부는 마감을 맞추는 데만 쓴다. 기준 컨셉 그림은 C1 v3, C3 v5, C9 v5, C10 v3로 바뀌었다.

08:35 더함(내정 스레드와 코디네이터 의견): 사람이 탄 칸에는 사슬, 빗장, 자물쇠, 못 박아 막은 문을 그리지 않는다. 문은 평소처럼 열리거나 반쯤 열려 있고, 판자와 고철판은 벽과 지붕을 덧대도 한 칸의 창을 다 막지는 않아서 불빛과 얼굴이 보인다. 누더기 줄의 덧댐이 '막아 둔 칸'으로 읽히는 걸 막으려는 문장이다. 내정 16.5 발진티푸스의 '그 칸 문을 닫는다' 갈래도 잠긴 문 장면으로 그리지 않는다.

## 받은 뒤 볼 것

1. 점토 판만 봐도 무엇인지 알아보는가(열차장, 공동체 다섯, 좀비 넷, 칸 종류). 실루엣이 약하면 텍스처로 메워야 하고, 폰에선 그게 잘 안 보인다.
2. M3의 40픽셀 열차장과 M7b의 사람들이 폰 크기에서 사람·좀비·동료로 구별되는가. 뭉갠 텍스처로도 이게 되면 좀보이드 수준 마감으로 충분하다는 뜻이다.
3. M8 여섯 칸이 한 게임의 흐름으로 이어져 보이는가. 특히 3(옆 앞쪽 카메라)에서 5(탑뷰)로 넘어갈 때 같은 역·같은 사람으로 읽히는가. 이게 안 되면 정차 연출을 실시간 3D로 해야 할 이유가 약해진다.
4. M5 아랫줄 실루엣만으로 좀비 넷이 갈리는가. 망자와 갓 일어난 자가 자세만으로 구별되는가(대응이 달라서 꼭 갈려야 한다).
5. M4 다섯이 같은 몸이라는 게 거슬리지 않으면서도 공동체가 옷만으로 읽히는가. M3b 몸 여섯이 40픽셀에서 갈리는가. 안 갈리면 체격 셋은 수치 차이만 남기고 몸은 둘(성별)로 줄이는 안도 낸다.
6. M1·M7을 C 그림과 나란히 놓았을 때 "같은 게임, 낮은 마감"으로 받아들일 만한가, 아니면 실망스러운가. 실망스러우면 3D 범위를 줄이는 쪽(아래 안 B·C)을 다시 본다.
7. M2 분해도처럼 칸을 지붕·앞벽·바닥으로 나누는 구조가 홈 단면, 한눈에 보기, 의회 배경에 다 쓰일 만한가.
8. 빨강·하늘색이 모델에 쓰이지 않았는가. 빨간 십자가 없는가.
9. M3c 얼굴 부품이 작게 보면 머리 모양·수염·모자 말고는 거의 사라지는가. 그렇다면 얼굴 부위는 초상과 가까운 카메라용으로만 만들어도 된다.

## 3D 여부: 사용자에게 낸 안 (결정됨: A, 2026-10-07 08:21)

사용자가 A(전부 실시간 3D)를 골랐다. 아래는 그때 낸 안의 기록이다.


- **A. 전부 실시간 3D(엔진 스레드 추천과 같음).** 열차, 칸 내부, 사람, 좀비, 필드, 정차 장면 모두. 모델 하나로 홈·한눈에 보기·필드·정차를 다 쓴다. 대신 폰 성능 위험이 가장 크고, 칸 내부 소품과 사람 옷 모듈의 제작량이 크다.
- **B. 사람과 열차는 3D, 필드 배경은 미리 렌더링한 타일.** 좀보이드가 간 길이다. 폰에서 가볍지만 날씨·시간대마다 배경을 따로 구워야 하고, 정차 장면의 역 배경은 결국 3D로 하나 더 만든다.
- **C. 정치 화면(홈·의회)은 2D 그림 + 반복 애니메이션, 필드와 정차만 3D.** 의회 배경 생활을 그린 그림 위에 움직이는 층을 얹는 방식. 정치 화면 품질은 가장 높게 나오지만 홈 단면과 필드의 열차가 서로 다른 모델이 되어 한 세계로 맞추는 품이 든다.

## 1단계 평가 (2026-10-07 07:30, "모델링 시안" 스레드)

18장을 다 봤다. 결과 원본은 바탕화면 `모델컨셉_20261007\`, 고른 것의 작은 사본은 `/mnt/project-files/art/models_20261007/`. 고른 판은 `*_PICK.png`로 복사했다.

| 항목 | 고른 판 | 이유 |
|---|---|---|
| M1 의회 칸 | v1 | 두 장이 거의 같다. v1이 뒤 사람들이 조금 더 덩어리져 보인다 |
| M2 칸 분해 | v1 | 지붕·앞벽·바닥이 깔끔하게 떨어진다 |
| M3 열차장 | v2 | 코트 텍스처가 v1보다 덜 모자이크처럼 보인다 |
| M3b 기본 몸 | v1 | 긴 내복을 입어 M4 옷 갈아입히기 기준으로 낫다. 나이 줄의 굽은 자세가 분명하다 |
| M3c 얼굴 부품 | v1 | 부위별 줄이 깔끔하고 작은 그림이 같이 있다 |
| M6 열차 | v2 | 덩어리가 더 단순하고 쐐기형 제설기와 덧붙임 부품이 잘 읽힌다 |
| M7a 홈 | v2 | 둘 다 C3을 거의 그대로 옮겼다. v2가 사람만 조금 더 뭉개졌다 |
| M7b 필드 | v1 | 창고 지붕을 걷은 벽 자르기가 있다. 텍스처는 v2가 더 폰 같다 |
| M7c 정차 | v2 | 기관차가 눈에 띄게 낮은 폴리곤이라 실시간 3D에 가깝다 |

'받은 뒤 볼 것'에 비춘 결과:

- **된 것.** M2·M6은 쓸 만하다. 칸을 지붕·앞벽·바닥으로 나누는 구조가 홈 단면과 의회 배경에 그대로 맞고(7번), 열차는 점토만으로도 칸 종류가 갈린다(1번). M3b는 체격 셋이 점토 단계에서 갈리고 쇠약 변형과 나이(머리색·굽은 자세)가 옷 없이 읽힌다.
- **얼굴(9번).** 작은 그림에서는 모자, 수염, 머리색만 남는다. 얼굴 부위는 초상과 가까운 카메라용으로만 만들어도 된다는 쪽이 맞아 보인다.
- **못 본 것(2번, 6번).** M1·M7a는 첨부한 C5·C3을 거의 그대로 다시 그렸다. 이미지 모델은 강한 첨부가 있으면 '폰 마감'이라는 글을 무시한다. 그래서 실제 폰 화면과의 차이는 이 그림으로 판단할 수 없고, S2 성능 시험 장면이 처음 보는 진짜 화면이다. '40픽셀' 작은 그림도 실제로는 100픽셀 안팎이라 폰 크기 판별(2번)은 보류다.
- **주의할 것.** 사람 텍스처가 픽셀 모자이크(위장무늬 같은 네모)로 나왔다. 비픽셀 화풍과 어긋나니 실제 에셋 주문에서는 '붓으로 칠한 듯 뭉갠' 텍스처라고 따로 적는다. M1·M7a는 C5·C3의 빨강·하늘색 막대와 파랑·빨강 사람 아이콘을 그대로 가져와 색 규칙(8번)을 어긴다. 모델 쪽에는 빨강·하늘색이 없다.
- **3D 여부 안 A·B·C**는 M8 콘티를 본 뒤 사용자에게 냈고, 08:21 A(전부 실시간 3D)로 결정됐다.

## 2·3단계 평가 (2026-10-07 07:50)

| 항목 | 고른 판 | 이유 |
|---|---|---|
| M4 공동체 다섯 | v3 (4단계, 07:58) | 다섯이 옷만으로 갈리고 몸 공유도 자연스럽다(5번 통과). 다만 경비가 누런 완장과 2차대전식 철모, 의무진이 흰 완장을 찼다. 위 '민감한 표식 규칙'으로 고쳐 다시 뽑는다 |
| M5 좀비 넷 | v2 | 실루엣 줄만으로 넷이 갈리고 망자(늘어짐)와 갓 일어난 자(앞으로 덤빔)가 자세로 구별된다(4번 통과). v1은 껴입은 자 털모자에 작은 휘장이 있고 외투 무늬가 별처럼 보여 뺐다 |
| M8 정차 콘티 | v2 | 4번 하차 칸 뒤에 급수탑이 보여 3번(옆 앞쪽)과 5번(탑뷰)이 같은 역으로 이어진다(3번 통과). 2번에서 UI가 흐려지며 브레이크 불꽃이 튀는 것도 연출 브리프와 맞는다 |

M7b 필드도 사람들이 철모와 군용 외투 차림이라 화물칸 옆의 무장한 제복 무리로 읽힌다. 4단계에서 같이 다시 뽑는다. M1·M7a는 2차대전식 표식이 눈에 띄지 않았다.

4단계(07:58): M4는 v3을 골랐다. 경비는 귀덮개 털모자, 소총, 몽둥이, 손등불로 읽히고 완장·철모·모표가 없다. v4는 털모자 앞에 작은 모표가 남아 뺐다. M7b v3·v4는 첨부 C1_field_v2에서 철모와 군용 외투를 다시 옮겨 와서, 화면 컨셉 스레드의 C1_field_v3가 나오면 그걸 첨부로 5단계에서 다시 뽑는다.

5단계(08:05): M7b는 C1_field_v3를 첨부로 다시 뽑은 v5를 골라 PICK으로 바꿨다. 철모 없이 털모자·니트 모자·목도리 차림이고, 화차는 지붕 없는 석탄차, 열차는 객차다. 크레인 옆 두 명의 허리띠 맨 올리브 외투만 살짝 제복 느낌이 남았다. v6은 둥근 모자가 철모처럼 읽혀 뺐다. M8 콘티(M7b v1 기준)는 다시 뽑지 않았다. 5번 칸 사람이 작아 철모가 거의 안 읽히지만, 콘티를 다시 쓸 일이 생기면 새 PICK으로 다시 뽑는다.
