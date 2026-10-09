# 구간 배경 렌더링 주문서 (2026-10-07)

작성: 2026-10-07 "화면 컨셉과 UI 연출" 스레드 · 상태: 주문 전. 그림은 분위기와 배치를 보는 시안이고 게임에 그대로 넣지 않는다.

## 왜 뽑나

달리는 동안 홈 단면 뒤로 그 구간의 실제 동네가 흐르게 하자는 사용자 요청(12:15)의 시안이다. 규칙은 [../design/briefs/presentation_motion.md](../design/briefs/presentation_motion.md) 7b절. 세 가지를 본다.
1. 지역 키트 여섯이 지붕 위 좁은 띠에서도 서로 다른 동네로 읽히나(실루엣만으로).
2. 망자 밀도 세 단계(고요, 흩어짐, 가득)가 폰 크기에서 구별되나.
3. 칸 안 정보가 배경보다 먼저 읽히나(배경은 늘 더 어둡고 채도가 낮아야 한다).

## 받는 사람에게 (로컬 워커, 아스트라 울트라)

- 첨부: 모든 항목에 `C3_home_v5.png`(바탕화면 `좀비\화면컨셉_20261007\`, 사본 /mnt/project-files/art/concepts_20261007/)를 붙인다. 카메라, 열차 크기, HUD 자리를 맞추기 위해서다.
- 결과는 **공개 저장소에 올리지 않는다.** 바탕화면 `좀비\구간배경_20261007\`에 `B1_poland_lakes_v1.png`처럼 저장하고, 평가용 사본을 /mnt/project-files/art/backdrops_20261007/에 둔다.
- 한 항목은 두 장까지 뽑아 나은 쪽을 고른다.
- 작품 이름은 글상자에 넣지 않는다. 한글 글자는 그리게 하지 않는다.
- 실제 사진 레퍼런스는 바탕화면 `좀비\구간배경_20261007\ref\`에만 둔다. 저장소에는 아래 '사진 레퍼런스' 표에 출처 링크만 적는다. 사진을 이미지 모델에 첨부하지 않는다(사진을 그대로 베끼면 권리 문제가 생긴다). 사진은 사람이 비교해 보는 용도다.
- 우선순위: **B6 → B4 → B1 → B7 → B2 → B3 → B5 → B8.** B6과 B4가 가장 '그 동네' 같아야 하는 곳이고, B7은 밀도 규칙을 확인한다.

## 공통 앞머리 (모든 글상자 맨 앞)

```text
Match the painterly realistic rendering, side-on camera, size of the train cross-section and the HUD layout of the attached image exactly. Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials; textures soft and economical. Central Europe, present-day places, sixth winter after civilization collapsed and the dead rose. Dark drab weather: low heavy clouds, freezing fog, wet sleet. Cold is pale grey-white frost and blue-grey shadow, warmth is amber. No gore, no logos, no red cross symbols, no readable text.

The train is now running at speed, not stopped: the platform, lamp post and waiting family of the attached image are gone. The ground below the train streaks past with slight motion blur; the far horizon above the roof barely moves. The lit car interiors stay the brightest, warmest part of the image; everything outside is darker and less saturated so the interiors read first. Only the outside landscape changes from the attached image, with one fix: the iron plaque above the guard car shows a plain railway hand lantern, not crossed rifles or a shield.
```

## 공통 끝 (모든 글상자 맨 끝)

```text
Clothing: everyone looks ragged after six winters: torn and frayed mismatched layers, scavenged coats too big or too small, blankets and sacking worn as cloaks, holes patched with burlap, rags and rope wrapped over boots and hands, frayed sleeves and stained knees, soot and grime on faces and cuffs, gear and bundles tied on with cord and straps. No armbands, stars, badges, cap badges, insignia, rank marks, real army uniforms or steel helmets. No red cross or red crescent on anything.
Train: people live and ride only in old passenger coaches; closed freight wagons carry only cargo and coal and never have people inside or crowded at their doors. Only the running locomotive smokes: it pours out a long, heavy, billowing plume of grey steam and coal smoke that streams far back and up over the whole train in the wind, and the coach stovepipes give only thin pale wisps. Chimneys of buildings, factories and cooling towers give no smoke or steam at all, a standing locomotive never sends smoke straight up, and closed wagons have no stovepipe and never smoke. Washing and hygiene appear only as cooking pots, steam, laundry lines and empty basins; never anyone treating or washing a person's body, people scratching, lice, disinfection signs or sprays, or a living car being closed off.
Landscape: no barbed-wire fences, watchtowers, rows of barracks, loading ramps, or tall chimneys with smoke anywhere in the scene. Factory chimneys and cooling towers, if present, stand cold and smokeless.
Props: no abandoned suitcases, piles of luggage or piles of shoes beside the track or on platforms; left-behind goods are only cargo sacks or wooden crates.
The dead: ordinary civilians in torn everyday winter clothes (parkas, anoraks, wool coats, hoodies, work jackets, knit hats or bare heads, loose hair). No olive drab, no camouflage or mottled patterns, no military-style backpacks or webbing, no helmets or round helmet-like caps, never walking in step or in rows.
```

16:05 더함: Train 줄 끝의 연기 문장은 사용자 결정(16:00, 연기 카드 '옅게 둠')이다. 기관차와 객차 난로 연기는 남기되 짙은 검은 기둥 없이 옅고 비스듬히 흐르게 한다. 17:40 고침: 사용자가 17:12에 기관차 연기를 굵고 길게 바꿨다. Train 줄 끝의 연기·위생 문장은 3D 스레드 주문 공통 줄(4a002fa·14d3c36)과 글자까지 같게 맞췄다. 달리는 기관차만 굵은 회색 연기를 뒤로 길게 끌고, 멈춘 기관차·건물 굴뚝·냉각탑·닫힌 화차는 연기가 없다. 위생은 솥·김·빨랫줄·빈 대야로만 보인다.

15:20 더함: 마지막 줄(망자 옷)은 B2 v2, B3 v1·v2, B6 v1에서 망자가 둥근 모자나 철모 같은 머리, 국방색 배낭, 얼룩무늬 상의로 나와 병사 무리처럼 읽혀서 넣었다. 이 줄이 생기기 전에 뽑은 그림은 망자를 참고하지 않는다.

## B1 대폴란드 호수 평야 (K1, 0–54km)

```text
Outside: flat snowy farmland in western Poland. Above the roof line, a low horizon of birch and pine copses, a frozen lake catching grey light, and a small red-brick village with a church tower (a slender spire or a pale clock tower with a dark round cap), windows dark. No overhead wires or wire masts along this track. Below the train, a drainage ditch, a row of pollarded willows and a small brick level-crossing hut with a broken barrier flash past. Danger level: quiet. Only crows on a fence and one abandoned car half buried in snow; no dead in sight.
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
| K1 | 볼슈틴 원형 기관고·급수탑, 대폴란드 벽돌 마을과 교회 탑, 호수 평야의 겨울 | [대폴란드 국립공원의 얼어붙은 겨울 호수와 안개 낀 숲](https://commons.wikimedia.org/wiki/File:WPN_Kocio%C5%82ek_Lake%2C_winter.jpg) (CC BY 4.0); [볼슈틴 원형 기관고 건물](https://commons.wikimedia.org/wiki/File:Parowozownia_Wolsztyn.jpg) (CC BY-SA 4.0); [기관고 건물에 붙은 볼슈틴 급수탑](https://commons.wikimedia.org/wiki/File:Wolsztyn%2C_Stacja_kolejowa_Wolsztyn_-_fotopolska.eu_(26178).jpg) (CC BY-SA 3.0); [대폴란드주 차치 마을의 교회 탑](https://commons.wikimedia.org/wiki/File:Czacz_kosciol_wieza.jpg) (CC BY 2.5 pl); 키트 공통 건물 참고(조사 21, 노선 위 장소는 아님): [벽돌 주택 형태, 1957](https://commons.wikimedia.org/wiki/File:Murowany_dom_z_cegie%C5%82_-_Soko%C5%82owo_Budzy%C5%84skie_-_003460n.jpg) (CC BY-SA 3.0 PL); [농장 건물의 벽돌 색과 줄눈, 슈레니아바](https://commons.wikimedia.org/wiki/File:National_Museum_of_Agriculture_in_Szreniawa,_folwark.JPG) (CC BY-SA 3.0); [세로 목판 헛간, 즈보노보 레시네](https://commons.wikimedia.org/wiki/File:Dzwonowo_Lesne_%28barn%29.jpg) (CC BY-SA 3.0); [성당 시계탑, 골레옙코](https://commons.wikimedia.org/wiki/File:Golejewko_277-21.jpg) (CC BY-SA 3.0); [시골 역사, 스타레 보야노보](https://commons.wikimedia.org/wiki/File:Dworzec_w_Starym_Bojanowie.jpg) (CC BY-SA 4.0); 키트 공통 건물 참고, 지금 모습의 붉은 벽돌 집(노선 위 장소는 아님): [기와지붕 단층 벽돌집, 스탄코보 2022](https://commons.wikimedia.org/wiki/File:Stankowo_(wlkp)_(1).jpg) (CC BY-SA 4.0); [마을 안 벽돌집, 브워트코보 2023](https://commons.wikimedia.org/wiki/File:B%C5%82otkowo_(3).jpg) (CC BY 4.0); [벽돌 농가 건물 두 채와 들판, 프타슈코보 2026](https://commons.wikimedia.org/wiki/File:Ptaszkowo_-_dwa_domki.jpg) (CC BY 4.0) |
| K2 | 오데르 치가치체 철교, 크로스노오드잔스키에 보브르 골짜기, 범람원 제방 | [치가치체 인근 포모르스코의 실제 오데르 철교](https://commons.wikimedia.org/wiki/File:Pomorsko%2C_railway_bridge_across_Oder_river.jpg) (CC BY-SA 3.0); [치가치체의 오데르 도로교와 강변 마을](https://commons.wikimedia.org/wiki/File:Cigacice_bridge.jpg) (CC BY-SA 4.0); [크로스노오드잔스키에 인근 보브르강 하구 쪽 풍경](https://commons.wikimedia.org/wiki/File:Bober_near_Krosno.jpg) (CC BY-SA 3.0); [오데르 강가 출브뤼케의 풀 덮인 제방 둑마루, 독일 쪽 강변](https://commons.wikimedia.org/wiki/File:Zollbr%C3%BCcke-Oderdeich_(4).JPG) (CC BY-SA 3.0) |
| K3 | 구벤·구빈 강변, 동독 조립 아파트 단지, 옛 공장 굴뚝 | [구벤-구빈 국경 다리, 나이세강 보와 소수력 시설](https://commons.wikimedia.org/wiki/File:Gubin.gorod.jpg) (CC0); [콧부스 역 근처의 현대화된 동독식 조립주택](https://commons.wikimedia.org/wiki/File:Plattenbau_in_der_Thiemstra%C3%9Fe.JPG) (CC BY-SA 3.0); [구벤 옛 Cockerill 공장 부지의 현재 건물과 길](https://commons.wikimedia.org/wiki/File:Guben%2C_Cottbuser_Stra%C3%9Fe_1%2C_ehem._Cockerill%2C_Areal.jpg) (CC BY-SA 4.0); 굴뚝 대체(구벤 사진 못 찾음, 같은 브란덴부르크주): [앙거뮌데 옛 공장 벽돌 굴뚝, 연기 없음, 겨울 저녁](https://commons.wikimedia.org/wiki/File:Angerm%C3%BCnde,_Prenzlauer_Str._41,_Schornstein_der_Firma_Breyer,_Baudenkmal_09131400.jpg) (CC BY-SA 4.0) |
| K4 | 라우지츠 소나무 숲, 옌슈발데 노천광 가장자리와 냉각탑, 노천광 호수, 풍력 발전 단지 | [니더라우지츠 뤼커스도르프의 소나무 숲](https://commons.wikimedia.org/wiki/File:Kiefernwald.JPG) (CC BY 3.0); [옌슈발데 노천 갈탄광과 발전소 냉각탑](https://commons.wikimedia.org/wiki/File:Tagebau-Kraftwerk-Jaenschwalde.jpg) (CC0); [그리센 전망 지점 부근 옌슈발데 노천광의 대형 채굴 장비](https://commons.wikimedia.org/wiki/File:Tagebau_J%C3%A4nschwalde_im_Nebel.JPG) (CC BY-SA 3.0); [라우지츠 호수 지구 젠프텐베르거 호수의 해변 파노라마](https://commons.wikimedia.org/wiki/File:Senftenberger_See_01.jpg) (CC BY-SA 4.0); [얼어붙은 젠프텐베르거 호수와 갈대, 겨울](https://commons.wikimedia.org/wiki/File:Senftenberger_see_im_winter2.JPG) (CC BY 3.0); [회를리츠 전망대에서 본 라우지츠링과 클레트비츠 풍력단지](https://commons.wikimedia.org/wiki/File:Eurospeedway_lausitz_1.JPG) (CC BY-SA 3.0) |
| K5 | 칼라우 남쪽 숲 언덕, 리히터펠트 F60 컨베이어 다리 | [칼라우 남쪽 칼라우어 슈바이츠 자연보호구역의 숲 풍경](https://commons.wikimedia.org/wiki/File:Naturschutzgebiet_Calauer_Schweiz_04.jpg) (CC BY-SA 4.0); [카벨 인근 칼라우어 슈바이츠의 숲 언덕](https://commons.wikimedia.org/wiki/File:Cabel_Naturschutzgebiet_Calauer_Schweiz_01.jpg) (CC BY-SA 4.0); [리히터펠트 F60 컨베이어 다리 내부에서 본 구조](https://commons.wikimedia.org/wiki/File:Lichterfeld_EE_09-2015_Foerderbruecke_F60_img1.jpg) (CC BY-SA 3.0); [2008년 리히터펠트 F60 컨베이어 다리 전경](https://commons.wikimedia.org/wiki/File:Abraumf%C3%B6rderbr%C3%BCcke_F60%2C_Lichterfeld_2008_(Alter_Fritz)_33.JPG) (CC BY-SA 3.0) |
| K6 | 이름 없는 엘베 철교(강물·강둑과 다리만, 사진 없이 글로만), 아일렌부르크 물데 다리, 라이프치히 서쪽·북서쪽 교외의 주말농장·아파트·물류 창고(북동쪽 동네 아님) | [아일렌부르크 물데 철교와 교량 위 선로](https://commons.wikimedia.org/wiki/File:J40_474_Muldebr%C3%BCcke_Eilenburg%2C_Nordseite.jpg) (CC BY-SA 4.0); [라이프치히 린데나우 주말농장과 주택가 사이 길](https://commons.wikimedia.org/wiki/File:Leipzig_-_Kleingartenverein_Leipzig-Lindenau_%2B_Rietschelstra%C3%9Fe_01_ies.jpg) (CC BY-SA 3.0); [라이프치히 서쪽 그뤼나우의 리모델링한 조립아파트](https://commons.wikimedia.org/wiki/File:Leipzig_Gruenau_Sanierter_Plattenbau.jpg) (CC BY 3.0); [라이프치히-할레 공항 DHL 물류 허브와 항공화물 구역](https://commons.wikimedia.org/wiki/File:DHL_Leipzig-Halle.jpg) (CC BY-SA 3.0) |
| 공통 | 구간마다 전차선 기둥이 있는지(전철화 여부) | K1·K2(폴란드 PLK 357·358)은 전차선 없음으로 판독. K3은 독일 쪽 본선 있음, 국경 연결선 없음. K4·K6 있음. K5는 주 선로 있음, 크리니츠 지선은 미확인. 근거는 PKP PLK 선로도와 DB InfraGO 인프라 레지스터 2026의 전력 방식 값. |

사진은 바탕화면 `좀비\구간배경_20261007\ref\`에 있고, 표에 적은 34장(로컬 워커가 처음 올린 24장에서 지침 목록에 걸린 2장을 빼고 그뤼나우 1장을 더한 23장, 조사 21의 키트 공통 건물 5장, 빈 곳을 채운 6장)은 모두 Commons 라이선스 표기 파일이다(5장은 Commons에서 라이선스를 다시 대조). 못 찾은 것: 볼슈틴 바로 옆 겨울 호수, 구벤 시내의 옛 공장 굴뚝(Commons에서 못 찾음, 같은 주 굴뚝으로 대체), K5 겨울 사진(Commons 브란덴부르크 겨울 분류에 숲 언덕이 없어 찾기를 그만둠, B5는 프롬프트의 겨울 묘사로 감), 동쪽 교외 주말농장과 물류 창고가 함께 보이는 최신 사진. 치가치체 오데르 다리는 도로교라서 가까운 포모르스코 철교를 따로 넣었다. K4 소나무 숲은 처음 고른 사진의 장소가 피할 지명에 걸려 뤼커스도르프 사진으로 바꿨다(라이선스 직접 대조). 라이프치히 북동쪽 외곽의 조립아파트 사진도 뺐다(2026-10-07 14:15 화면 스레드 판단, 지침 목록의 동네와 붙어 있어서. 뺌). K6 조립아파트는 서쪽 교외 그뤼나우의 2010년 사진(CC BY 3.0, 라이선스 직접 대조)으로 바꿨다. 빠진 두 장은 바탕화면 `ref\_빼둠\`으로 옮겨 두었다. 엘베 철교 사진도 뺐다(2026-10-07 15:55). 엘베 건넘의 도시는 사진에서도 빼는 선이 되었다(장소 거르기 15:46, first_leg_story 0.4. 뺌, 까닭은 적지 않는다). 엘베 건넘은 이름 없이 강물, 강둑, 다리만 그리고, 참고 사진은 쓰지 않는다. 빈 곳을 채운 6장(벽돌 집 3, 제방 1, 굴뚝 1, K4 겨울 1)은 Commons에서 라이선스와 촬영일을 직접 대조했고, 냉각탑 김이 크게 피어오르는 옌슈발데 겨울 사진은 연기 나는 굴뚝으로 읽힐 수 있어 뺐다.

찾지 않는 것: 국경 들판 구간의 역과 거리, 엘베 건넘의 시가지(성, 요새, 다리 모두), 코트부스 교도소, 철거된 소르브 마을, 라이프치히 외곽의 동네들(이름은 프로젝트 지침의 목록에만 둔다). 이 장소들은 배경으로 그리지 않는다(7b절 '지나가되 보여 주지 않는 곳').

전철화 판독(위 '공통' 줄)을 글상자에 반영했다(2026-10-07 14:15): B1·B2는 전차선 없음, B3·B4·B6은 끊어져 처진 전차선 기둥. B5는 지선이 미확인이라 그대로 둔다. 이미 뽑은 v1·v2는 이 줄 전이라 B1·B2에 전차선이 있어도 다시 뽑지 않는다(실제 에셋에서 맞춘다).

## 받은 뒤 볼 것

- 지붕 위 띠만 잘라 보고 여섯 키트가 서로 다른 동네로 읽히나.
- 칸 안 호박색이 화면에서 가장 밝은가. 배경이 칸 안 정보를 덮지 않나.
- 7b절의 금지 목록(철조망, 망루, 막사, 하역 경사로, 연기 나는 굴뚝, 사람이 모인 화차, 그 시대 표식, 적십자 표장)이 하나라도 섞였나.
- 망자가 병사 무리로 읽히지 않나(철모 같은 머리, 국방색, 얼룩무늬, 줄 맞춘 걸음). 망자는 크게 잘라서 본다.

## 평가 (2026-10-07 13:20)

- **B6**: 로컬 워커 PICK(v1)이 맞다. 지붕 위 띠만 잘라 봐도 고가도로의 멈춘 차, 조립 아파트, 전차선 기둥으로 '큰 도시 외곽'이 읽힌다. 칸 안 호박색이 가장 밝고 배경은 어둡다. 경비칸 명판이 방패로 고쳐져 나왔다. 아래 띠 '가득'도 분명하다.
  - 볼 점: 앞줄 망자가 크고 빨라 보여서 아래쪽 HUD(진행 막대, 단추)와 겹친다. 실제 게임에서는 근경 망자를 HUD 높이 아래로 내리거나 흐리게 해야 한다(7b절 근경 층). 가운데 아래 한 명의 얼룩무늬 상의는 군복으로 읽힐 수 있어 실제 에셋에서는 민간 옷으로 둔다. 다시 뽑을 정도는 아니다.

## B8 v2 평가 (2026-10-07 15:00)

평가용 사본은 `/mnt/project-files/art/backdrops_20261007/B8_oder_bridge_v2.png`. 같은 폴더의 `B8_oder_bridge_v2_old_props.png`와 견줬다.

- **B8_oder_bridge_v2를 고른다.** 다시 뽑지 않는다.
- 트러스 부재가 창 앞을 지나며 바깥을 칸칸이 자르는 느낌이 산다. 앞쪽 부재는 움직임으로 흐리고, 칸 안 호박색이 화면에서 가장 밝다. 아래 강물의 얼음 조각과 안개도 주문대로다. K2라 전차선이 없어야 하는데 없다.
- old_props와 갈리는 점: old_props는 가까운 부재가 경비칸 왼쪽을 덮어 칸 안 사람이 가려지고, 식당칸 명판까지 방패로 나왔다. v2는 부재가 칸 사이 이음매에 걸려 칸 안을 덮지 않고, 명판도 식당 = 포크·나이프, 경비 = 무늬 없는 방패로 맞다. (2026-10-07 19:00 고침: J06 점검에서 방패가 휘장으로 읽힐 수 있다고 나와 경비 명판은 철도 손등으로 바꿨다. 주문 줄은 고쳤고, 이미 뽑은 B 그림은 배치 기준이라 다시 뽑지 않고 실제 에셋 때 고친다.)
- 석탄 화차 두 칸은 문 없는 무개차에 석탄만 실렸고 사람이 없다. 금지 목록(철조망, 망루, 막사, 하역 경사로, 연기 나는 굴뚝, 사람이 모인 화차, 표식, 적십자)은 섞이지 않았다.
- 볼 점 1: 화차가 '기관차 앞 다리 한가운데'가 아니라 열차 뒤 먼 선로에 서 있는 것처럼 보인다. 옆에서 보는 구도에서는 앞을 보여 주기 어렵다. 실제 장면에서는 다리를 다 건너기 직전 오른쪽 끝에 들어오게 하거나, 화차를 이 구간 사건 그림으로 따로 보여 준다.
- 볼 점 2: 건너편 강가에 첨탑이 선 도시 윤곽이 있다. 주문은 헐벗은 숲이었고, 치가치체 근처 오데르는 큰 도시가 보이는 곳이 아니다. 실제 배경에서는 숲과 낮은 마을 지붕으로 바꾼다.
- 볼 점 3: 건너편 강가의 망자들은 폰 크기에서 점에 가깝다. 위험도 '조용함'이라 지금 크기도 틀리지 않지만, 위험도가 올라간 판에서는 망자 무리를 더 크게, 더 가까이 둔다.

## B1~B5·B7 평가 (2026-10-07 15:20)

평가용 사본은 전부 `/mnt/project-files/art/backdrops_20261007/`에 있다(B1~B8 두 장씩, B6_PICK). B1~B4는 전차선 줄(B3·B4에 전차선 기둥)과 짐 줄, 망자 옷 줄이 생기기 전에 뽑은 그림이다. 그래서 B3·B4에 전차선 기둥이 없는 것은 그림 탓이 아니고, 실제 배경에서 넣는다.

| 항목 | 고른 것 | 까닭 | 볼 점 |
|---|---|---|---|
| B1 호수 평야 | v2 | 얼어붙은 호수가 넓고 울타리 위 까마귀, 반쯤 묻힌 차, 건널목 초소와 차단기까지 주문이 다 들어갔다. 전차선 없음도 맞다. | 기관차 검은 연기가 오른쪽 위 하늘을 덮어 HUD 둘레가 어수선하다. 17:12 결정 뒤에도 연기가 굵고 긴 것은 맞지만, 이 장의 연기는 검은 덩어리라 틀렸다. 회색으로 뒤로 흐르게 하고, 위 띠 뒤로는 지나가도 칸 단면의 창과 얼굴은 덮지 않는다(7b '열차 연기'). 반쯤 묻힌 차가 아래 HUD 단추 높이에 걸린다. |
| B2 오데르·보브르 | v2(배경만) | 긴 범람원 제방과 띠처럼 깔린 안개, 강가 마을 탑이 있어 K2가 B1과 갈린다. | **v2의 망자는 쓰지 않는다.** 둥근 모자, 국방색 배낭과 옷이라 병사 무리로 읽힌다. 망자 참고는 v1(누더기 민간 옷, 후드, 산발)으로 한다. v1은 아래 HUD가 빠졌고 망자가 너무 크고 가깝다. 쓰러진 수위 표지는 둘 다 서 있다. |
| B3 국경 소도시 | v2(배경만) | 조립 아파트 줄, 연기 없는 공장 굴뚝, 강 건너 철교와 교회 탑, 차고 줄과 불탄 차가 다 있고 '동독 소도시'가 지붕 위 띠만으로 읽힌다. | **두 장 다 망자를 쓰지 않는다.** v1은 철모처럼 둥근 머리에 갈색 옷을 입은 셋이 나란히 걸어 병사 행렬로 읽히고, v2는 오른쪽 망자가 얼룩무늬 상의다. |
| B4 라우지츠 | v1 | 계단식 노천광, 노천광 호수, 멈춘 풍차, 김 없는 냉각탑, 소나무 열이 다 보이고, 소나무 사이 망자 하나가 분명하다. | 오른쪽 위의 높은 컨베이어 다리는 B5의 거대 컨베이어 다리(K5 랜드마크)와 겹친다. K4의 컨베이어는 아래 띠의 낮은 벨트로만 둔다. v2는 망자가 객차 지붕선 바로 위에 서 있어 지붕에 올라탄 사람으로 읽힐 수 있어 뺐다. |
| B5 니더라우지츠 | v1 | 숲 등성이, 우묵한 곳의 소도시, 지평선의 컨베이어 다리, 등성이의 망자 둘이 주문대로다. 겨울 사진 없이도 겨울이 산다. | v2는 기관차 연기가 무겁다(17:12 결정으로 굵은 연기는 괜찮아졌지만, v2 연기는 검고 하늘을 덮어서 여전히 v1을 고른다). 컨베이어 다리는 v1 크기로 충분하다. |
| B7 밀도 세 단계 | v1 | 열차 단면과 HUD가 C3 v5와 같아 세 줄 비교가 정직하다. 고요(까마귀만), 흩어짐(여섯 일곱), 가득(울타리 넘는 무리)이 폰 크기에서 갈린다. | v2는 기관차와 탄수차, 객차 비례를 바꿔 그려 비교 기준이 흔들린다. v1의 '가득' 줄에서 망자 몇이 객차 옆면을 기어올라 칸 안 아래쪽을 가린다. 실제 게임에서는 망자가 바퀴선 아래에 머물거나 칸 바깥 테두리에만 겹친다. 망자 머리가 둥근 모자처럼 보이는 것도 있어 새 망자 옷 줄로 다시 확인한다. |

여섯 키트를 지붕 위 띠만으로 견주면 대체로 갈린다. B3(조립 아파트·굴뚝), B4(노천광·냉각탑), B5(등성이·컨베이어 다리), B6(고가도로·전차선)은 실루엣만으로 바로 구별된다. **약한 곳은 B1과 B2다.** 둘 다 평평한 땅, 물, 뾰족탑 마을이라 띠만 보면 헷갈린다. B2는 제방 선과 다리를, B1은 자작나무 숲과 붉은 벽돌, 둥근 모자 시계탑을 앞세운다. 또 B1, B2, B3, B5, B8에 거의 같은 뾰족탑 교회가 되풀이된다. 탑 하나로 키트를 가르지 말고, 키트마다 탑 모양을 다르게 한다(K1 둥근 모자 시계탑, K3 양파 지붕 없는 네모 탑, K5 낮은 마을 교회).

B8 v1도 봤다. 가까운 부재가 객차 여러 칸 안을 크게 가로질러 v2를 고른 판단 그대로다.

칸 안 호박색은 모든 그림에서 가장 밝다. 7b절 금지 목록 가운데 철조망, 망루, 막사, 하역 경사로, 연기 나는 굴뚝(공장 굴뚝과 냉각탑은 모두 연기와 김이 없음), 사람이 모인 화차, 표식, 적십자는 어느 그림에도 없다. 남은 위험은 망자 옷 하나였고, 위 공통 끝 줄로 막았다.
