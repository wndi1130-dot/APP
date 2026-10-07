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
Props: no abandoned suitcases, piles of luggage or piles of shoes beside the track or on platforms; left-behind goods are only cargo sacks or wooden crates.
```

## B1 대폴란드 호수 평야 (K1, 0–54km)

```text
Outside: flat snowy farmland in western Poland. Above the roof line, a low horizon of birch and pine copses, a frozen lake catching grey light, and a small red-brick village with a slender church spire, windows dark. No overhead wires or wire masts along this track. Below the train, a drainage ditch, a row of pollarded willows and a small brick level-crossing hut with a broken barrier flash past. Danger level: quiet. Only crows on a fence and one abandoned car half buried in snow; no dead in sight.
```

## B2 오데르·보브르 강 골짜기 (K2, 54–118km)

```text
Outside: a wide river floodplain in western Poland. Above the roof line, a long flood embankment, river fog lying in bands, bare riverside woods, and far off the towers of a small river town. No overhead wires or wire masts along this track. Below the train, frozen reeds, ice-crusted puddles and a toppled flood-level marker streak past. Danger level: scattered. Three or four dead walk slowly out of the fog toward the track; one stumbles after the train.
```

## B3 국경 강변 소도시 (K3, 118–130km)

```text
Outside: the edge of a small border town on a river in eastern Germany. Above the roof line, rows of grey East-German prefabricated apartment blocks with dark windows, old brick factory halls with cold smokeless chimneys, and across the river the tower of a church. Below the train, back gardens, a row of lock-up garages and a burnt-out car flash past; railway overhead-wire masts with sagging broken wires line the track. Danger level: scattered to dense. Dead stand in a garage row and turn toward the noise; a few climb the embankment.
```

## B4 라우지츠 소나무 모래 평원 (K4, 130–186km)

```text
Outside: the Lusatian lignite country of eastern Germany. Above the roof line, endless straight rows of planted pine forest on sandy ground; beyond them the raw terraced edge of an open-pit mine, spoil heaps and a grey flooded pit lake; a line of stopped wind turbines with frozen blades; far on the northern horizon two huge cooling towers of a silent power station, no steam. Below the train, pale sand showing through thin snow, a firebreak track and a rusted section of a conveyor belt flash past; railway overhead-wire masts with sagging broken wires line the track. Danger level: quiet. A single dead figure stands motionless among the pines.
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
| K1 | 볼슈틴 원형 기관고·급수탑, 대폴란드 벽돌 마을과 교회 탑, 호수 평야의 겨울 | [대폴란드 국립공원의 얼어붙은 겨울 호수와 안개 낀 숲](https://commons.wikimedia.org/wiki/File:WPN_Kocio%C5%82ek_Lake%2C_winter.jpg) (CC BY 4.0); [볼슈틴 원형 기관고 건물](https://commons.wikimedia.org/wiki/File:Parowozownia_Wolsztyn.jpg) (CC BY-SA 4.0); [기관고 건물에 붙은 볼슈틴 급수탑](https://commons.wikimedia.org/wiki/File:Wolsztyn%2C_Stacja_kolejowa_Wolsztyn_-_fotopolska.eu_(26178).jpg) (CC BY-SA 3.0); [대폴란드주 차치 마을의 교회 탑](https://commons.wikimedia.org/wiki/File:Czacz_kosciol_wieza.jpg) (CC BY 2.5 pl) |
| K2 | 오데르 치가치체 철교, 크로스노오드잔스키에 보브르 골짜기, 범람원 제방 | [치가치체 인근 포모르스코의 실제 오데르 철교](https://commons.wikimedia.org/wiki/File:Pomorsko%2C_railway_bridge_across_Oder_river.jpg) (CC BY-SA 3.0); [치가치체의 오데르 도로교와 강변 마을](https://commons.wikimedia.org/wiki/File:Cigacice_bridge.jpg) (CC BY-SA 4.0); [크로스노오드잔스키에 인근 보브르강 하구 쪽 풍경](https://commons.wikimedia.org/wiki/File:Bober_near_Krosno.jpg) (CC BY-SA 3.0) |
| K3 | 구벤·구빈 강변, 동독 조립 아파트 단지, 옛 공장 굴뚝 | [구벤-구빈 국경 다리, 나이세강 보와 소수력 시설](https://commons.wikimedia.org/wiki/File:Gubin.gorod.jpg) (CC0); [콧부스 역 근처의 현대화된 동독식 조립주택](https://commons.wikimedia.org/wiki/File:Plattenbau_in_der_Thiemstra%C3%9Fe.JPG) (CC BY-SA 3.0); [구벤 옛 Cockerill 공장 부지의 현재 건물과 길](https://commons.wikimedia.org/wiki/File:Guben%2C_Cottbuser_Stra%C3%9Fe_1%2C_ehem._Cockerill%2C_Areal.jpg) (CC BY-SA 4.0) |
| K4 | 라우지츠 소나무 숲, 옌슈발데 노천광 가장자리와 냉각탑, 노천광 호수, 풍력 발전 단지 | [니더라우지츠 뤼커스도르프의 소나무 숲](https://commons.wikimedia.org/wiki/File:Kiefernwald.JPG) (CC BY 3.0); [옌슈발데 노천 갈탄광과 발전소 냉각탑](https://commons.wikimedia.org/wiki/File:Tagebau-Kraftwerk-Jaenschwalde.jpg) (CC0); [그리센 전망 지점 부근 옌슈발데 노천광의 대형 채굴 장비](https://commons.wikimedia.org/wiki/File:Tagebau_J%C3%A4nschwalde_im_Nebel.JPG) (CC BY-SA 3.0); [라우지츠 호수 지구 젠프텐베르거 호수의 해변 파노라마](https://commons.wikimedia.org/wiki/File:Senftenberger_See_01.jpg) (CC BY-SA 4.0); [회를리츠 전망대에서 본 라우지츠링과 클레트비츠 풍력단지](https://commons.wikimedia.org/wiki/File:Eurospeedway_lausitz_1.JPG) (CC BY-SA 3.0) |
| K5 | 칼라우 남쪽 숲 언덕, 리히터펠트 F60 컨베이어 다리 | [칼라우 남쪽 칼라우어 슈바이츠 자연보호구역의 숲 풍경](https://commons.wikimedia.org/wiki/File:Naturschutzgebiet_Calauer_Schweiz_04.jpg) (CC BY-SA 4.0); [카벨 인근 칼라우어 슈바이츠의 숲 언덕](https://commons.wikimedia.org/wiki/File:Cabel_Naturschutzgebiet_Calauer_Schweiz_01.jpg) (CC BY-SA 4.0); [리히터펠트 F60 컨베이어 다리 내부에서 본 구조](https://commons.wikimedia.org/wiki/File:Lichterfeld_EE_09-2015_Foerderbruecke_F60_img1.jpg) (CC BY-SA 3.0); [2008년 리히터펠트 F60 컨베이어 다리 전경](https://commons.wikimedia.org/wiki/File:Abraumf%C3%B6rderbr%C3%BCcke_F60%2C_Lichterfeld_2008_(Alter_Fritz)_33.JPG) (CC BY-SA 3.0) |
| K6 | 토르가우 엘베 철교(다리만), 아일렌부르크 물데 다리, 라이프치히 교외 주말농장·아파트·물류 창고 | [토르가우 엘베 철교의 교량 구조만 보이는 측면 사진](https://commons.wikimedia.org/wiki/File:Torgau_Eisenbahnbruecke-05.jpg) (CC BY-SA 4.0); [아일렌부르크 물데 철교와 교량 위 선로](https://commons.wikimedia.org/wiki/File:J40_474_Muldebr%C3%BCcke_Eilenburg%2C_Nordseite.jpg) (CC BY-SA 4.0); [라이프치히 린데나우 주말농장과 주택가 사이 길](https://commons.wikimedia.org/wiki/File:Leipzig_-_Kleingartenverein_Leipzig-Lindenau_%2B_Rietschelstra%C3%9Fe_01_ies.jpg) (CC BY-SA 3.0); [라이프치히-할레 공항 DHL 물류 허브와 항공화물 구역](https://commons.wikimedia.org/wiki/File:DHL_Leipzig-Halle.jpg) (CC BY-SA 3.0) |
| 공통 | 구간마다 전차선 기둥이 있는지(전철화 여부) | K1·K2(폴란드 PLK 357·358)은 전차선 없음으로 판독. K3은 독일 쪽 본선 있음, 국경 연결선 없음. K4·K6 있음. K5는 주 선로 있음, 크리니츠 지선은 미확인. 근거는 PKP PLK 선로도와 DB InfraGO 인프라 레지스터 2026의 전력 방식 값. |

사진은 바탕화면 `구간배경_20261007\ref\`에 있고, 표에 적은 23장(로컬 워커가 올린 24장에서 하이터블리크 1장을 뺌)은 모두 Commons 라이선스 표기 파일이다(4장은 Commons에서 라이선스를 다시 대조). 못 찾은 것: 볼슈틴 바로 옆 겨울 호수, 범람원 제방만 보이는 사진, 구벤 옛 공장 굴뚝, K4·K5 겨울 사진, 동쪽 교외 주말농장과 물류 창고가 함께 보이는 최신 사진. 치가치체 오데르 다리는 도로교라서 가까운 포모르스코 철교를 따로 넣었다. K4 소나무 숲은 처음 고른 사진의 장소가 피할 지명에 걸려 뤼커스도르프 사진으로 바꿨다(라이선스 직접 대조). 라이프치히 동쪽 하이터블리크 일대 조립아파트 사진도 뺐다(2026-10-07 14:15 화면 스레드 판단). 거리 이름과 동네가 아브트나운도르프 쪽과 붙어 있어서다. K6 조립아파트는 서쪽이나 남쪽 교외(그뤼나우 등)에서 다시 고른다.

찾지 않는 것: 즈봉신·즈봉시네크의 역과 거리, 토르가우 시내와 성채, 코트부스 교도소, 철거된 소르브 마을, 라이프치히 아브트나운도르프. 이 장소들은 배경으로 그리지 않는다(7b절 '지나가되 보여 주지 않는 곳').

전철화 판독(위 '공통' 줄)을 글상자에 반영했다(2026-10-07 14:15): B1·B2는 전차선 없음, B3·B4·B6은 끊어져 처진 전차선 기둥. B5는 지선이 미확인이라 그대로 둔다. 이미 뽑은 v1·v2는 이 줄 전이라 B1·B2에 전차선이 있어도 다시 뽑지 않는다(실제 에셋에서 맞춘다).

## 받은 뒤 볼 것

- 지붕 위 띠만 잘라 보고 여섯 키트가 서로 다른 동네로 읽히나.
- 칸 안 호박색이 화면에서 가장 밝은가. 배경이 칸 안 정보를 덮지 않나.
- 7b절의 금지 목록(철조망, 망루, 막사, 하역 경사로, 연기 나는 굴뚝, 사람이 모인 화차, 그 시대 표식, 적십자 표장)이 하나라도 섞였나.

## 평가 (2026-10-07 13:20)

- **B6**: 로컬 워커 PICK(v1)이 맞다. 지붕 위 띠만 잘라 봐도 고가도로의 멈춘 차, 조립 아파트, 전차선 기둥으로 '큰 도시 외곽'이 읽힌다. 칸 안 호박색이 가장 밝고 배경은 어둡다. 경비칸 명판이 방패로 고쳐져 나왔다. 아래 띠 '가득'도 분명하다.
  - 볼 점: 앞줄 망자가 크고 빨라 보여서 아래쪽 HUD(진행 막대, 단추)와 겹친다. 실제 게임에서는 근경 망자를 HUD 높이 아래로 내리거나 흐리게 해야 한다(7b절 근경 층). 가운데 아래 한 명의 얼룩무늬 상의는 군복으로 읽힐 수 있어 실제 에셋에서는 민간 옷으로 둔다. 다시 뽑을 정도는 아니다.
