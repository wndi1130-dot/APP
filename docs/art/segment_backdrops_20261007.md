# 구간 배경 렌더링 주문서 (2026-10-07)

작성: 2026-10-07 "화면 컨셉과 UI 연출" 스레드 · 상태: 주문 전. 그림은 분위기와 배치를 보는 시안이고 게임에 그대로 넣지 않는다.

## 왜 뽑나

달리는 동안 홈 단면 뒤로 그 구간의 실제 동네가 흐르게 하자는 사용자 요청(12:15)의 시안이다. 규칙은 [../design/briefs/presentation_motion.md](../design/briefs/presentation_motion.md) 7b절. 세 가지를 본다.
1. 지역 키트 여섯이 지붕 위 좁은 띠에서도 서로 다른 동네로 읽히나(실루엣만으로).
2. 망자 밀도 세 단계(고요, 흩어짐, 가득)가 폰 크기에서 구별되나.
3. 칸 안 정보가 배경보다 먼저 읽히나(배경은 늘 더 어둡고 채도가 낮아야 한다).

## 받는 사람에게 (로컬 워커, 아스트라 울트라)

- 첨부: 모든 항목에 `C3_home_v5.png`(바탕화면 `화면컨셉_20261007\`, 사본 /mnt/project-files/art/concepts_20261007/)를 붙인다. 카메라, 열차 크기, HUD 자리를 맞추기 위해서다.
- 결과는 **공개 저장소에 올리지 않는다.** 바탕화면 `구간배경_20261007\`에 `B1_poland_lakes_v1.png`처럼 저장하고, 평가용 사본을 /mnt/project-files/art/backdrops_20261007/에 둔다.
- 한 항목은 두 장까지 뽑아 나은 쪽을 고른다.
- 작품 이름은 글상자에 넣지 않는다. 한글 글자는 그리게 하지 않는다.
- 실제 사진 레퍼런스는 바탕화면 `구간배경_20261007\ref\`에만 둔다. 저장소에는 아래 '사진 레퍼런스' 표에 출처 링크만 적는다. 사진을 이미지 모델에 첨부하지 않는다(사진을 그대로 베끼면 권리 문제가 생긴다). 사진은 사람이 비교해 보는 용도다.
- 우선순위: **B6 → B4 → B1 → B7 → B2 → B3 → B5 → B8.** B6과 B4가 가장 '그 동네' 같아야 하는 곳이고, B7은 밀도 규칙을 확인한다.

## 공통 앞머리 (모든 글상자 맨 앞)

```text
Match the painterly realistic rendering, side-on camera, size of the train cross-section and the HUD layout of the attached image exactly. Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials; textures soft and economical. Central Europe, present-day places, sixth winter after civilization collapsed and the dead rose. Dark drab weather: low heavy clouds, freezing fog, wet sleet. Cold is pale grey-white frost and blue-grey shadow, warmth is amber. No gore, no logos, no red cross symbols, no readable text.

The train is now running at speed, not stopped: the platform, lamp post and waiting family of the attached image are gone. The ground below the train streaks past with slight motion blur; the far horizon above the roof barely moves. The lit car interiors stay the brightest, warmest part of the image; everything outside is darker and less saturated so the interiors read first. Only the outside landscape changes from the attached image, with one fix: the iron plaque above the guard car shows a plain shield, not crossed rifles.
```

## 공통 끝 (모든 글상자 맨 끝)

```text
Clothing: everyone looks ragged after six winters: torn and frayed mismatched layers, scavenged coats too big or too small, blankets and sacking worn as cloaks, holes patched with burlap, rags and rope wrapped over boots and hands, frayed sleeves and stained knees, soot and grime on faces and cuffs, gear and bundles tied on with cord and straps. No armbands, stars, badges, cap badges, insignia, rank marks, real army uniforms or steel helmets. No red cross or red crescent on anything.
Train: people live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors.
Landscape: no barbed-wire fences, watchtowers, rows of barracks, loading ramps, or tall chimneys with smoke anywhere in the scene. Factory chimneys and cooling towers, if present, stand cold and smokeless.
```

## B1 대폴란드 호수 평야 (K1, 0–54km)

```text
Outside: flat snowy farmland in western Poland. Above the roof line, a low horizon of birch and pine copses, a frozen lake catching grey light, and a small red-brick village with a slender church spire, windows dark. Below the train, a drainage ditch, a row of pollarded willows and a small brick level-crossing hut with a broken barrier flash past. Danger level: quiet. Only crows on a fence and one abandoned car half buried in snow; no dead in sight.
```

## B2 오데르·보브르 강 골짜기 (K2, 54–118km)

```text
Outside: a wide river floodplain in western Poland. Above the roof line, a long flood embankment, river fog lying in bands, bare riverside woods, and far off the towers of a small river town. Below the train, frozen reeds, ice-crusted puddles and a toppled flood-level marker streak past. Danger level: scattered. Three or four dead walk slowly out of the fog toward the track; one stumbles after the train.
```

## B3 국경 강변 소도시 (K3, 118–130km)

```text
Outside: the edge of a small border town on a river in eastern Germany. Above the roof line, rows of grey East-German prefabricated apartment blocks with dark windows, old brick factory halls with cold smokeless chimneys, and across the river the tower of a church. Below the train, back gardens, a row of lock-up garages and a burnt-out car flash past. Danger level: scattered to dense. Dead stand in a garage row and turn toward the noise; a few climb the embankment.
```

## B4 라우지츠 소나무 모래 평원 (K4, 130–186km)

```text
Outside: the Lusatian lignite country of eastern Germany. Above the roof line, endless straight rows of planted pine forest on sandy ground; beyond them the raw terraced edge of an open-pit mine, spoil heaps and a grey flooded pit lake; a line of stopped wind turbines with frozen blades; far on the northern horizon two huge cooling towers of a silent power station, no steam. Below the train, pale sand showing through thin snow, a firebreak track and a rusted section of a conveyor belt flash past. Danger level: quiet. A single dead figure stands motionless among the pines.
```

## B5 니더라우지츠 등성이 (K5, 186–236km)

```text
Outside: low rolling wooded hills in southern Brandenburg, the only hills on this route. Above the roof line, forested ridges fading into fog, a small town in a hollow, and on the far horizon the long dark steel silhouette of a giant abandoned mining conveyor bridge standing over a lake. Below the train, a cutting slope with snowdrifts flashes past. Danger level: quiet to scattered. Two dead silhouettes on the ridge, small and far.
```

## B6 엘베·물데 범람원과 라이프치히 교외 (K6, 236–312km)

```text
Outside: the outskirts of a large city in Saxony, eastern Germany, at dusk. Above the roof line, a flood dike, then suburban apartment blocks, big flat logistics warehouses, a motorway overpass with a frozen line of abandoned cars, and railway overhead-wire masts with sagging broken wires along the track. Below the train, a long row of small allotment-garden huts and fences, and a noise barrier wall, flash past. Danger level: dense. Dozens of dead pour over the allotment fences and down the embankment toward the train; a few are thrown aside by the snowplow at the front.
```

## B7 밀도 세 단계 (K6 같은 장소, 첨부: C3_home_v5와 B6 결과)

한 장에 세로로 세 줄. 폰 크기로 줄였을 때 세 단계가 구별되는지 본다.

```text
Make one image with three horizontal strips, the same place and moment as the second attached image, only the number of dead changes. Top strip, quiet: no dead, only crows and an abandoned car. Middle strip, scattered: five or six dead walking toward the track, two following the train. Bottom strip, dense: a crowd of dead pouring over the fences and down the embankment. Keep the train cross-section, light and weather identical in all three strips.
```

## B8 랜드마크 지나기: 오데르 다리 (첨부: C3_home_v5)

```text
Outside: the train is crossing a long steel truss railway bridge over a wide icy river in western Poland. The bridge girders pass in front of and above the car windows in a rhythm, cutting the view into frames; below the train, black water with ice floes and fog. On the far bank, bare woods. Two freight wagons with only coal stand abandoned in the middle of the bridge ahead, seen past the locomotive. Danger level: quiet, but a few dead stand frozen on the far bank, watching.
```

## 사진 레퍼런스 (로컬 워커가 모으고 링크만 여기 적는다)

사진은 Wikimedia Commons처럼 출처와 사용 조건이 적힌 곳에서 고른다. 저장소에는 출처 링크와 한 줄 설명만 남긴다.

| 키트 | 찾을 것 | 링크 |
|---|---|---|
| K1 | 볼슈틴 원형 기관고·급수탑, 대폴란드 벽돌 마을과 교회 탑, 호수 평야의 겨울 | (모으는 중) |
| K2 | 오데르 치가치체 철교, 크로스노오드잔스키에 보브르 골짜기, 범람원 제방 | |
| K3 | 구벤·구빈 강변, 동독 조립 아파트 단지, 옛 공장 굴뚝 | |
| K4 | 라우지츠 소나무 숲, 옌슈발데 노천광 가장자리와 냉각탑, 노천광 호수, 풍력 발전 단지 | |
| K5 | 칼라우 남쪽 숲 언덕, 리히터펠트 F60 컨베이어 다리 | |
| K6 | 토르가우 엘베 철교(다리만), 아일렌부르크 물데 다리, 라이프치히 교외 주말농장·아파트·물류 창고 | |
| 공통 | 구간마다 전차선 기둥이 있는지(전철화 여부) | |

찾지 않는 것: 즈봉신·즈봉시네크의 역과 거리, 토르가우 시내와 성채, 코트부스 교도소, 철거된 소르브 마을, 라이프치히 아브트나운도르프. 이 장소들은 배경으로 그리지 않는다(7b절 '지나가되 보여 주지 않는 곳').

## 받은 뒤 볼 것

- 지붕 위 띠만 잘라 보고 여섯 키트가 서로 다른 동네로 읽히나.
- 칸 안 호박색이 화면에서 가장 밝은가. 배경이 칸 안 정보를 덮지 않나.
- 7b절의 금지 목록(철조망, 망루, 막사, 하역 경사로, 연기 나는 굴뚝, 사람이 모인 화차, 그 시대 표식, 적십자 표장)이 하나라도 섞였나.
