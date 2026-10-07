# 탈것 렌더 참고 (도로 차량·좀보이드 차량)

> 링크 43개를 모았다. 금지어·모델 이름 검사를 거쳤다. 조사 상태: COMPLETE. 이 문서는 조사 기록이며 확정 사항이 아니다. 사진·모델 파일은 저장소에 넣지 않고 링크만 둔다.
레퍼런스 43개

## 1. 한눈 요약

- 2026-10-07 기준으로 실제 열어 본 공개 페이지 43개를 골랐으며, 기존 조사 파일에 이미 나온 모드는 다시 풀어 쓰지 않고 이름만 연결했다.
- PZ 모드 페이지는 제작자와 설명을 볼 수 있지만, 게임용 모델의 폴리곤 수·텍스처 크기·모드별 상업 재사용 허가는 대체로 공개 페이지에서 확인하지 못했다.
- 동독·중부 유럽 레퍼런스는 Trabant, Wartburg, Barkas, IFA, Ikarus, Leipzig Tatra, Fortschritt 등 승용차부터 대형 탈것까지의 사진·치수 자료를 포함한다.
- 재사용 후보는 CC0 차량 팩과 CC0 PBR 재질로 우선 분리했다. Sketchfab 모델과 PZ 모드 파일은 별도 허가가 확인되지 않아 시각 참고용으로만 둔다.
- Godot 자료는 공간 셰이더, 눈·녹 데칼, LOD·HLOD 및 오버드로우 지침을 제공하며, Android 실제 프레임 성능은 별도 기기 확인이 필요하다.
- Commons 이미지는 파일마다 조건이 다르고, 검색 결과/페이지에서 확인한 라이선스만 기록했다. 이미지 파일은 내려받지 않았다.

## 2. 레퍼런스 표

| 번호 | 이름(링크) | 종류 | 무엇을 보여 주나 | 어디에 쓸까 | 라이선스와 주의점 |
|---:|---|---|---|---|---|
| 1 | [‘63 Volkswagen 1300 Beetle — KI5](https://steamcommunity.com/sharedfiles/filedetails/?id=3005903549) | 모드 | 기존 조사와 겹치는 유럽 승용차 모드의 이름·제작자 페이지다. | 모델링 참고 | 제작자는 KI5로 표시된다. 별도 모델 라이선스 표시는 확인하지 못했다. 기존 모드 설명은 반복하지 않는다. |
| 2 | [Filibuster Rhymes’ Used Cars](https://steamcommunity.com/sharedfiles/filedetails/?id=1510950729) | 모드 | 기존 조사 모드의 Workshop 원문이다. | 모델링 참고 | Workshop 구독 가능과 다른 상업 게임에서의 자산 재사용 허가는 별개다. |
| 3 | [Project Zomboid 모드 스포트라이트: Filibuster Rhymes’ Used Cars](https://projectzomboid.com/blog/news/2021/08/mod-spotlight-filibuster-rhymes-used-cars/) | 모드 | 제작자 인터뷰와 개발 소개를 제공한다. | 모델링·장면 | 게임 개발사의 소개 페이지다. 모델·텍스처 재배포 허가를 주는 자료는 아니다. |
| 4 | [More Immersive Vehicles](https://steamcommunity.com/sharedfiles/filedetails/?id=3162566044&l=koreana) | 모드 | 기존 조사 모드 이름과 제작자 DaNiG의 페이지다. | 장면 | 페이지에 별도 3D 원본 자산 라이선스는 없다. |
| 5 | [Vehicle Recycling - Rebuild](https://steamcommunity.com/workshop/filedetails/?id=2930682200) | 모드 | 부서지거나 불탄 차량을 해체 대상으로 다루는 게임 규칙을 설명한다. | 장면·수색 | 로직 참고다. 외형 모델·텍스처 팩으로 제시된 것은 아니다. |
| 6 | [Zomboid Modding Guide](https://github.com/FWolfe/Zomboid-Modding-Guide/blob/master/README.md?plain=1) | GitHub·튜토리얼 | 구형 모드 모델 파이프라인과 Blender 사용을 소개한다. | 모델링 | 문서가 오래되어 B42 파이프라인을 보증하지 않는다. 현재 버전 형식은 제작 전 다시 확인해야 한다. |
| 7 | [ProjectZomboid-Vanilla-Lua VehicleDistributions.lua](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/blob/main/server/Vehicles/VehicleDistributions.lua) | GitHub | 차량별 글로브박스·트렁크 분배 데이터를 구분한다. | 장면·수색 | Lua 데이터 참고다. 차량 메시·재질·모델 권리는 다루지 않는다. |
| 8 | [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/?curator_clanid=45088573) | 라이선스 | 구독 콘텐츠 이용 범위와 복제·상업 사용 제한을 확인할 수 있다. | 라이선스 검토 | 모드 게시 페이지에 별도 라이선스가 없으면 상업 게임에 가져올 권리가 있다고 간주하지 않는다. |
| 9 | [Steam Workshop Supplemental Terms](https://steamcommunity.com/workshop/workshoplegalagreement/?appid=0) | 라이선스 | 유료 Workshop 기여물의 수익 배분 조건을 다룬다. | 라이선스 검토 | 수익 분배 약관이 개별 모드 모델을 다른 게임에 쓸 수 있게 해 주는 것은 아니다. |
| 10 | [Trabant 601 — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Trabant_601) | 사진·치수 | 여러 차체·트림 사진과 길이·폭·높이·축거를 한데 모은다. | 모델링·장면 | 사진별 권리가 다르다. 실제 사용 전 개별 파일 페이지를 확인한다. |
| 11 | [Abandoned Trabant 601 — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Abandoned_Trabant_601) | 사진 | 동독 승용차가 방치·해체·부식된 여러 상태를 보여 준다. | 재질·장면 | 일부는 1990년 전후 독일 기록이다. 개별 파일의 권리 조건을 확인해야 한다. |
| 12 | [Leipzig에서 해체된 Trabant — Bundesarchiv 사진](https://commons.wikimedia.org/wiki/File%3ABundesarchiv_B_145_Bild-F086568-0046%2C_Leipzig%2C_ausgeschlachteter_PKW_Trabant_%28Trabbi%29.jpg) | 사진 | 라이프치히의 1990년 해체 차량에서 빠진 부품과 그래피티 상태를 보여 준다. | 장면·마모 | 기록 사진이다. Commons 파일 페이지의 Bundesarchiv 표기와 사용 조건을 따른다. |
| 13 | [IFA W50 — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:IFA_W50) | 사진·치수 | 동독 트럭 사진과 기본 외형·치수, 차체별 자료를 모은다. | 모델링·장면 | 민간 화물차 사진을 우선 고른다. 범주 내 일부 파일은 별도 성격이므로 파일별 검토가 필요하다. |
| 14 | [IFA W 50 기술 개요](https://en.wikipedia.org/wiki/IFA_W_50) | 도면·치수 | 캡오버 트럭 형태, 축거 선택지와 기본 길이를 확인한다. | 모델링 | Wikipedia 2차 자료다. 실제 기준 치수는 제조사·박물관 자료와 교차 확인한다. |
| 15 | [Barkas B 1000 — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Barkas_B_1000) | 사진·치수 | 밴·박스형·평판형 사진과 길이 4.52m, 폭 1.86m, 높이 1.85m를 제공한다. | 모델링·장면 | 이미지 사용 허가는 파일별로 다르다. 민간 밴·화물형 사진을 우선 본다. |
| 16 | [Barkas B 1000 기술 자료](https://de.wikipedia.org/wiki/Barkas_B_1000) | 도면·치수 | 밴, 소형버스, 적재함 등 차체 유형과 치수를 비교한다. | 모델링 | 독일어 Wikipedia 2차 자료다. 세부 변형 치수는 별도 검증한다. |
| 17 | [Wartburg 353](https://en.wikipedia.org/wiki/Wartburg_353) | 사진·치수 | 세단·왜건·픽업 차체와 4.22m급 비례를 제공한다. | 모델링 | 표의 수치는 차체 세대별 차이를 반영해 최종 모델 기준을 고른다. |
| 18 | [Volkswagen Golf II — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Volkswagen_Golf_II) | 사진·치수 | 1980년대 해치백의 정·측·후면과 구조 비례를 확인한다. | 모델링·장면 | 각 사진은 별도 라이선스다. |
| 19 | [Škoda Octavia — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:%C5%A0koda_Octavia) | 사진 | 여러 세대와 Combi 왜건 사진을 비교한다. | 모델링·장면 | 이 범주는 여러 연식이 섞인다. 게임 연도·지역 설정에 맞는 세대만 택한다. 파일별 라이선스를 확인한다. |
| 20 | [Mercedes-Benz Sprinter — Wikimedia Commons](https://commons.wikimedia.org/wiki/Mercedes-Benz_Sprinter) | 사진 | 현대 유럽 소형 화물밴·미니버스와 길이·높이별 외형을 보여 준다. | 모델링·장면 | 세대·축거에 따라 비례가 크게 달라진다. 사진 권리는 파일마다 확인한다. |
| 21 | [Ikarus 280](https://en.wikipedia.org/wiki/Ikarus_280) | 사진·치수 | 굴절버스의 두 차체 연결부, 문 배치, 16.5m급 길이를 제공한다. | 모델링·장면 | 중부·동유럽 버스 참고다. Wikipedia 치수는 별도 원자료와 확인한다. |
| 22 | [Leipzig Tatra T4D/B4D — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Tatra_T4D_/_B4D_in_Leipzig) | 사진 | 라이프치히 운행 전차의 문·창·팬터그래프·연결 편성 사진을 모은다. | 모델링·장면 | 페이지는 라이프치히 현지 차량에 초점을 둔다. 개별 사진 이용권을 확인한다. |
| 23 | [Fortschritt ZT 300](https://de.wikipedia.org/wiki/Fortschritt_ZT_300) | 사진·치수 | 동독 농업용 트랙터의 차체, 앞·뒤 축, 바퀴와 장비 결합부를 다룬다. | 모델링 | 기본 민간 농업용 사양을 우선한다. 궤도·특수 변형은 요구 시 별도 조사한다. |
| 24 | [Simson S51 — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Simson_S51) | 사진 | 동독 1980년대 소형 이륜차의 기본형·Enduro·우편용 변형을 보여 준다. | 모델링·장면 | 길이·공장 도면은 이 범주에서 확인되지 않았다. 사진별 권리가 다르다. |
| 25 | [MZ ETS 250 기술 자료](https://de.wikipedia.org/wiki/MZ_ETS_250) | 사진·치수 | 전후면, 앞 포크·스포크 휠과 2.2m급 이륜차 비례를 제공한다. | 모델링 | 독일어 2차 자료다. 제품별 연식 차이를 재검증한다. |
| 26 | [MIFA Mitteldeutsche Fahrradwerke](https://de.wikipedia.org/wiki/MIFA_Mitteldeutsche_Fahrradwerke) | 사진·기술 배경 | 동독 자전거 생산과 26·28인치 투어링 자전거 계열을 찾는 출발점이다. | 모델링·장면 | 특정 자전거의 공장 도면·정확한 치수 자료는 확인하지 못했다. |
| 27 | [Abandoned automobiles — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Abandoned_automobiles) | 사진 | 깨진 창, 빠진 휠, 열린 도어, 노출된 실내·부품 등 손상 상태가 다양하다. | 재질·장면 | 사진은 국가·기후가 섞인다. 독일 풍경이라고 일반화하지 않는다. 파일별 권리를 확인한다. |
| 28 | [Automobiles in snow — Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Automobiles_in_snow) | 사진 | 차체 위 눈 깊이와 유리·지붕·바퀴 주변 적설을 비교한다. | 재질·장면 | 눈 사진은 나라와 적설 조건이 다르다. 독일 하위범주를 우선 골라 파일 권리를 확인한다. |
| 29 | [Quaternius Cars Pack](https://quaternius.com/packs/cars.html) | 에셋 | FBX·OBJ·Blend 형식의 승용차 8종을 제공한다. | 모델링·LOD | 페이지 표기는 CC0 및 상업 프로젝트 사용 가능이다. 지역 고유 실루엣은 별도 제작해야 한다. |
| 30 | [Kenney Car Kit](https://kenney-assets.itch.io/car-kit) | 에셋 | 40종 이상 자동차·트럭·밴과 OBJ·FBX·glTF 형식을 제공한다. | 모델링·LOD | CC0 1.0으로 상업 사용과 출처표기 생략이 허용된다고 페이지에 적혀 있다. 원본 페이지를 최종 출고 전에 다시 확인한다. |
| 31 | [Low Poly Vehicle Pack v2](https://assetstore-fallback.unity.com/packages/3d/vehicles/land/low-poly-vehicle-pack-v2-223413) | 에셋 | 저폴리 차량 묶음으로 승용차·트럭·버스 등 실루엣과 분리 메시 설명을 제공한다. | 모델링·LOD | 열어 본 판매 페이지는 미화 29달러, Single Entity, Unity Asset Store 표준 EULA로 표시했다. Godot 상용 게임에 쓰기 전 EULA 적용 범위를 확인한다. |
| 32 | [Trabant 601 3D 모델 — Sketchfab](https://sketchfab.com/3d-models/trabant-601-fefe2869599145448a51c72eed9c6cd5) | 에셋·3D 모델 | 제작자는 부품을 이름별로 분리했다고 설명하며 페이지에 248.6k 삼각형이 표시된다. | 모델링 참고·LOD | 구매형 페이지지만 가격·정확한 라이선스 조건은 열어 본 본문에서 확인하지 못했다. 모바일용으로는 그대로 쓰기 어려운 밀도다. |
| 33 | [Snow 02 — Poly Haven](https://polyhaven.com/a/snow_02) | 에셋·재질 | 확산·노멀·거칠기·범프 등 눈 PBR 맵과 1K~8K 선택지를 제공한다. | 재질·장면 | CC0다. 페이지의 8K는 모바일용 기본 크기로 과하다. 1K~2K 축소가 현실적이다. |
| 34 | [Rusty Metal 02 — Poly Haven](https://polyhaven.com/a/rusty_metal_02) | 에셋·재질 | 페인트 벗겨짐·부식 얼룩이 있는 금속 PBR 세트를 제공한다. | 재질·장면 | CC0다. 자동차 도장면 전체보다 하부·모서리·이음부용 마스크로 쓰는 편이 적합하다. |
| 35 | [Godot 셰이딩 언어 문서](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html) | 튜토리얼 | Godot 공간 셰이더와 파라미터 기초를 안내한다. | 재질 | Godot stable 문서다. 모바일에서 복잡한 분기·투명 효과는 실제 기기에서 측정해야 한다. |
| 36 | [Godot 공간 눈 셰이더 예제](https://godotshaders.com/shader/synty-polygon-drop-in-replacement-for-polygonshader/) | 튜토리얼·셰이더 | 삼면 투영, 표면 오버레이, 눈 효과가 포함된 3D shader 예제다. | 재질 | 게시자는 코드에 MIT를 표시한다. 이는 셰이더 코드 조건이며 관련 에셋 팩 권리와 무관하다. 버전 호환성을 먼저 확인한다. |
| 37 | [Godot 3D 성능 최적화](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) | 튜토리얼·LOD | 메시 LOD, 가시 범위 HLOD, impostor, 투명 재질·인스턴싱 조건을 설명한다. | LOD·재질 | Godot 자동 인스턴싱은 Forward+ 한정이며 Mobile 렌더러에서는 같은 동작을 전제하면 안 된다. |
| 38 | [Godot Decal 사용법](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html) | 튜토리얼 | 녹·먼지·그을음 데칼에 쓸 수 있는 투영 방식과 성능 지침을 제공한다. | 재질·장면 | Decal은 Forward+와 Mobile에서 지원되고 Compatibility에서는 지원되지 않는다. Compatibility에서는 평면 Sprite3D를 검토한다. |
| 39 | [Multilayer Snowfall Shader](https://godotshaders.com/shader/multilayer-snowfall-shader/) | 튜토리얼·셰이더 | 바람·속도·크기를 조절하는 화면 눈발 효과다. | 장면 | 코드 조각은 CC0다. 2D 화면 눈 효과이며 차체 표면에 쌓이는 눈 셰이더는 아니다. |
| 40 | [Blender 절차적 녹 재질](https://blender.fi/2023/06/24/easy-rust-material-in-blender-quick-adjustable-shader-setup/) | 튜토리얼 | Noise·ColorRamp·범프·roughness를 조절해 손상·녹을 섞는 흐름이다. | 재질 | 영상 소개를 재게시한 페이지다. Blender 렌더용 구성을 모바일 실시간 셰이더로 그대로 옮기지 않는다. |
| 41 | [Blender 절차적 눈 재질](https://jsabbott.artstation.com/blog/oArpN/how-do-you-create-a-snow-material-in-blender-5-1) | 튜토리얼 | 표면 노이즈, 색 변화, 거칠기와 변위로 눈 재질을 만든다. | 재질·장면 | Blender 5.1·Cycles 변위 중심이다. 게임에서는 모양을 참고해 텍스처나 단순 마스크로 굽는 편이 낫다. |
| 42 | [Blender 충돌 찌그러짐·손상](https://foro3d.com/en/2026/february/simulating-dents-and-impact-damage-in-blender.html) | 튜토리얼 | Shrinkwrap와 조각 도구로 충돌 자국을 만들고 셰이더로 표면 손상을 보탠다. | 모델링·장면 | 자동 번역된 영상효과 튜토리얼이다. 저폴리 실시간 게임 성능을 보증하지 않는다. |
| 43 | [Survivalist: Invisible Strain — 차량 업데이트](https://store.steampowered.com/news/posts/?appids=1054510&enddate=1702396687&feed=steam_community_announcements) | 게임 | 자동차 수리 부품·연료·마을 전리품 운반·지도 이탈 흐름을 개발사 공지로 볼 수 있다. | 장면·수색 | 차량 시스템 참고다. 본 게임의 사선 탑뷰 화면과 시각 품질을 직접 검수한 결과는 아니다. |

### PZ 모드 모델·재질 판단

기존 조사에 적힌 KI5, Filibuster Rhymes, Autotsar, RV Interior 등의 모드는 여기서 기능 설명을 되풀이하지 않는다. 열린 Workshop 페이지로 제작자 이름과 모드 화면을 찾을 수는 있지만, 대부분 폴리곤 수·텍스처 크기·정확한 부품 메시 구조를 공개하지 않았다. 모드 모델의 시각 품질을 수치로 비교하거나 원본 파일에서 UV·머티리얼을 검사하지는 않았다.

열어 본 Sketchfab Trabant 모델은 저자 설명상 명명된 부품이 나뉘어 있고 페이지상 248.6k 삼각형이다. 이 사례는 문·바퀴·창 메시를 분리하는 제작 참고지만, 모델 권리를 확인하지 못했고 폰용 실시간 에셋으로는 그대로 적합하지 않다. PZ 모드를 포함한 외부 모델은 상업 프로젝트 재사용 허가가 별도 확인되기 전까지 링크 참조에 한정한다.

## 3. 첫 업데이트 차종 제안

| 우선 | 차종 | 이유 |
|---:|---|---|
| 1 | Trabant 601 세단·Universal | 동독 실루엣과 기본 승용차 역할을 동시에 갖는다. |
| 2 | Wartburg 353 Tourist 왜건 | 긴 루프·큰 적재부로 세단과 쉽게 구분된다. |
| 3 | Volkswagen Golf II 해치백 | 보통 승용차 밀집 장면에 넣기 쉽고 크기 기준점이 된다. |
| 4 | Škoda Octavia Combi | 동유럽 브랜드의 현대 왜건 계열로 시대 대비를 만든다. |
| 5 | Barkas B1000 밴·평판형 | 소형 상용차와 우편·정비·상점 흔적을 만들 수 있다. |
| 6 | IFA W50 민간 평판·박스 트럭 | 큰 화물차 장애물과 여러 차체 변형을 제공한다. |
| 7 | Mercedes-Benz Sprinter형 밴 | 독일 도로에서 알아보기 쉬운 현대 배송차 실루엣이다. |
| 8 | Ikarus 280 굴절버스 | 긴 차체가 길목·역 주변을 막는 랜드마크가 된다. |
| 9 | Leipzig Tatra T4D 전차 | 현지성을 주고 선로·정차장 장면을 확장한다. |
| 10 | Fortschritt ZT 300 트랙터 | 외곽 마을·농지에서 농기계 실루엣을 채운다. |
| 11 | Simson S51·MZ ETS 250 이륜차군 | 좁은 주차 공간과 도로 가장자리에 배치하기 좋다. |
| 12 | MIFA·Diamant형 자전거 | 보행 이동 대안이자 작은 실루엣 소품군이 된다. |

차종 빈도 통계가 아니라 지역·시대·크기 실루엣을 균형 있게 보여 주기 위한 초기 제안이다. 실제 연식·모델 분포는 게임 세계의 붕괴 연도를 확정한 뒤 조정한다.

## 4. 추가로 할 것

### 먼저

1. 위 사진의 파일별 권리를 다시 확인하고, 유료 상용 게임에 들어갈 차량 메시·사진은 명시 라이선스가 확인된 것만 별도 자산 목록에 넣는다.
2. 차량 크기를 실측 치수로 맞춘 공통 기준 장면을 만들고, 승용차 1종·밴 1종으로 회전·사선 탑뷰 실루엣을 확인한다.
3. 먼저 게임플레이 프록시를 만들고 CC0 팩은 임시 대체물로 사용한다. 지역 차량은 새 메시를 만들거나 제작자에게 서면 이용 허가를 받은 뒤 제작한다.
4. 차체·유리·문·보닛·트렁크·바퀴를 따로 조합 가능한 구조로 정한다. 손상 단계는 정상, 외판 찌그러짐, 유리 파손·부품 탈거로 나누고 서로 공유할 재질을 줄인다.
5. 녹은 하단 패널·휠 아치·문 이음부에 집중하고, 눈은 지붕·보닛·평평한 짐칸 위에 쌓이는 마스크를 별도로 둔다. 눈가루·성에는 얇은 셰이더보다 정적 텍스처 변형을 우선 검토한다.
6. Godot에서 근거리 원형, 중거리 간략 메시, 원거리 impostor/HLOD 3단계를 만든 뒤 Galaxy S22급 실기기로 GPU·메모리·프레임을 측정한다. 본 조사는 실제 프로파일링을 하지 않았다.

### 나중

- 동독 박물관·제조사 기록에서 도면과 정확한 제원표를 더 확보한다.
- 트램·굴절버스·농기계처럼 실루엣이 큰 차종은 각 1개 변형부터 시각 검수 후 추가한다.
- 손수레·자전거·썰매는 탈것 주행 시스템과 분리해 정적 소품·수색 가능한 운반물로 우선 설계한다.
- PZ 원본 모델을 상용 사용하려면 개별 제작자, 적용 파일, 매체, 상업 사용, 수정·배포 범위를 적어 허가를 확인한다.

## 5. 찾았지만 못 연 것, 못 찾은 것

- Sketchfab의 IFA W50 모델 페이지는 검색 결과에 CC Attribution 표시가 있었으나 직접 열 때 403으로 막혔다. 원문 라이선스와 모델 구성을 확인하지 못해 링크를 표에 넣지 않았다.
- Barkas 전문 박물관 사이트의 기술 자료 페이지를 찾았으나 열리지 않았다. 본문은 열 수 있었던 Commons·Wikipedia 자료로 대체했다.
- Leipzig NGT8 전차 단일 사진 파일 페이지는 캐시 미스로 열리지 않아, 열 수 있었던 Tatra T4D/B4D Leipzig 범주를 사용했다.
- Trabant·Wartburg·Simson·MIFA의 공장 정투영 도면과 일부 연식별 정확한 제원표를 찾지 못했다. 치수는 열린 요약 자료에 한정한다.
- PZ Workshop 모드의 모델 파일·텍스처 해상도·부품별 메시 구조·공식 상업 재사용 라이선스를 확인하지 못했다. 모드 이미지를 시각 품질 평가 자료로 내려받거나 재사용하지 않았다.
- 수색 가능한 차량의 전용 UI 동선, 다른 게임의 실제 도로 봉쇄 화면, 차량별 LOD 전환 거리는 이번에 열린 공개 출처만으로 확인하지 못했다. 위 게임 링크는 시스템 아이디어 참고이며 Galaxy S22급 기기 성능 근거는 아니다.
