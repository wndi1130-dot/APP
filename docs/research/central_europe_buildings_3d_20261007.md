# 중부유럽 건물·도면과 3D 제작 자원

> 링크 76개를 모았다(일부 미확보, 7절). 링크 2곳(Ludwigsfelde PDF, Delitzsch 도면)을 직접 열어 대조했다. GPL 도구는 도구로만 쓰고 코드는 넣지 않는다. 조사 상태: PARTIAL. 이 문서는 조사 기록이며 확정 사항이 아니다. 사진·모델 파일은 저장소에 넣지 않고 링크만 둔다.
「레퍼런스 76개」

# 중부 유럽 건물 모델링과 3D 자원

조사 기준일은 2026-10-07이다. B·D·R·C 번호가 붙은 서로 다른 자료 76개를 세었으며, 보조 라이선스 링크와 실패한 열기 시도는 개수에서 제외하였다. 모든 연결 링크는 웹에서 실제로 페이지를 열어 확인한 것이다. 사진·모델·텍스처·도면 파일은 내려받지 않았다. 도면의 존재를 확인한 목록과 도면의 공개 기록을 구분하였으며, 원본 도면 이미지의 세부 치수를 전부 판독한 것은 아니다.

기존 배경 결정과 실제 장소 지도 모드의 겹치는 내용은 `europe_setting.md`, `pz_vehicles_maps_winter.md`를 참조한다. 엔진 목표는 요청한 Godot 4.7.2이다. 아래 `stable` 문서가 같은 패치 버전인지와 에셋·애드온의 해당 버전 호환성은 확인 못 함이다. 최종 문서의 텍스트 구조와 링크 목록은 검사하였으며, 렌더링 미리보기는 확인 못 함이다.

## 1. 한눈 요약

- 작은 역은 Putbus·Kühlungsborn 사진과 Delitzsch의 평면·단면 도면을 함께 보는 구성이 유용하다.
- 농가는 Bechelsdorf 도면과 Diesdorf의 Vierseithof 배치를, 조립식 아파트는 WBS 70의 실제 치수 자료를 우선한다.
- 네 주의 LoD1·LoD2와 정사영상은 마을 배치·지붕 형태의 근거로 쓰며, 창호와 실내는 별도 자료로 보완한다.
- 무료 제작 출발점은 CC0 모듈 건물·철도 키트와 PBR 재질이며, 유료 팩은 지역 적합성과 라이선스를 확인하여 선택한다.
- 모바일에서는 베이크 조명·LOD·공유 재질·아틀라스와 겹 레이어 배경을 먼저 검토하는 것이 적절하다.
- 건물 유형별 창 치수·지붕 각도와 일부 공개 평면도, 전용 그을음 튜토리얼을 확보하지 못하여 PARTIAL로 표시한다.

## 2. 건물 유형별 레퍼런스

사진의 픽셀 크기나 도면 종이의 센티미터 크기는 건물의 치수가 아니다. 아래에서 치수를 확인하지 못한 자료는 모델링 비율을 보는 참고로만 사용한다. 사진 모음의 라이선스는 각 파일 설명 페이지에서 확인해야 한다. CC-BY와 CC-BY-SA 사진은 상업 사용이 가능하지만 출처 표시 등 해당 조건을 따라야 한다.

| 유형 | 이름(링크) | 종류(사진·도면·치수·데이터) | 무엇을 보여 주나 | 라이선스와 주의점 |
|---|---|---|---|---|
| 작은 역 | B01 [Putbus 역사 사진](https://commons.wikimedia.org/wiki/File:Putbus,_Bahnhof.jpg) | 사진 | 뤼겐의 역사 외관, 창 배열, 지붕과 정면의 비율을 보여 준다. 실측 층고·창 크기·지붕 각도는 확인 못 함이다. | Rauenstein의 사진이며 CC-BY-SA 3.0을 선택할 수 있다. 사진의 이용 조건과 표기를 보존한다. |
| 작은 역 | B02 [Kühlungsborn-Ost 사진 모음](https://commons.wikimedia.org/wiki/Category:Bahnhof_K%C3%BChlungsborn-Ost) | 사진 | 작은 역사 정면과 선로 쪽 외관을 비교할 수 있다. 치수는 확인 못 함이다. | 파일별 라이선스이다. 협궤 관광철도의 외관 자료이므로 표준궤 역의 설비 규격으로 일반화하지 않는다. |
| 역사 도면 | B03 [Delitzsch 역사 도면, ZFB 22,036](https://www.deutsche-digitale-bibliothek.de/item/HZQQRSGOU5F62BLSJCZWCVBAPKQATQOK) | 도면 | 지상층 평면, 역 앞 입면, AB 단면이 명시된 1872년 도면 기록이다. 공간 구획과 지붕 단면을 함께 검토할 수 있다. 창 치수의 판독은 확인 못 함이다. | CC0이며 원작과 디지털 사본이 공유재산이라고 명시한다. 소장처·자료 번호를 기록하는 것이 유용하다. 현재 건물과 일치하는지는 확인 못 함이다. |
| 역 구내 | B04 [Delitzsch·Falkenberg 역 시설 도면, ZFB 22,033](https://www.deutsche-digitale-bibliothek.de/item/ORZ2ZHHX5LV7SSDOG4WEE6KHGXQFXZX3) | 도면 | 평면과 종단면을 가진 역사 철도 시설 자료이다. 역 구내 구성의 비교에 쓴다. 상세 대상별 치수 판독은 확인 못 함이다. | CC0·공유재산 표기이다. 같은 역의 다른 도면인 B03과 구분되는 자료이다. |
| 급수탑 | B05 [Wittenberge 기관차 박물관 급수탑 사진](https://commons.wikimedia.org/wiki/File:Wittenberge_Museum_Historischer_Lokschuppen_Wasserturm_1.jpg) | 사진 | 철도 급수탑의 몸통과 탱크 부분, 벽돌 외관을 보여 준다. 높이와 지름은 확인 못 함이다. | Oberlausitzerin64의 사진이며 CC-BY-SA 4.0이다. |
| 급수탑 | B06 [Hamm 급수탑 단면 기록](https://www.deutsche-digitale-bibliothek.de/item/MLE2JGM5ZYEAOJ6HCCV4H4O3EM5LFJ22) | 도면 목록·축척 | 1:50 단면 도면의 소장 기록이다. 탑 내부와 탱크의 관계를 조사할 다음 경로를 제공한다. 도면 이미지와 실제 치수는 확인 못 함이다. | 공개 목록을 열었다. 이미지의 상업적 재사용 허락은 확인 못 함이다. 대상 노선 밖의 보조 사례이다. |
| 신호소 | B07 [Wittenberge Wm 신호소 사진](https://commons.wikimedia.org/wiki/File:Stellwerk_Wittenberge_Wm_1.jpg) | 사진 | 높은 조작실, 긴 창열, 아래층과 상부의 비율을 보여 준다. 창 크기와 층고는 확인 못 함이다. | MPW57의 사진이며 CC-BY 3.0을 선택할 수 있다. 저작자와 라이선스를 표시한다. |
| 신호소 | B08 [Magdeburg-Rothensee Rmf 신호소 기록](https://www.deutsche-digitale-bibliothek.de/item/KWVZT6ZV2AMAVQKM2LSUSDURUG2SSOMI) | 도면 목록 | 배치도·평면·단면이 포함된 신호소 하부 구조 기록이다. 도면의 공개 이미지와 치수는 확인 못 함이다. | 목록의 공개와 도면 이용 허락을 구분한다. 정확한 재사용 라이선스는 확인 못 함이다. |
| 화물 창고 | B09 [Wurzen 화물 창고 도면 목록](https://recherche.landesarchiv.sachsen-anhalt.de/Query/archivplansuche.aspx?ID=1597306) | 도면 목록 | III/625·626·627에 화물 창고의 평면·단면·입면 기록이 있다. 자료 연대는 1912–1921년 범위이다. 도면 이미지와 창호 치수는 확인 못 함이다. | 주립 기록보관소의 목록이다. 복제·상업 사용 조건은 확인 못 함이다. 같은 페이지에서 해당 세 기록만 대상으로 삼는다. |
| 차량기지·기관고 | B10 [Historischer Lokschuppen Wittenberge](https://www.lokschuppen-wittenberge.de/content_startseite) | 사진·시설 정보 | 보존 기관고와 철도 시설을 보는 운영기관 자료이다. 기관고를 역 수색 구역의 큰 실내 공간으로 구성할 때 참고한다. 공개 실측 도면은 확인 못 함이다. | 무료 열람이지만 사진의 재사용 라이선스는 확인 못 함이다. 페이지의 사진을 게임 재질로 복제하지 않는다. |
| 역사 평면의 보조 사례 | B11 [Goslar 역사 평면도](https://commons.wikimedia.org/wiki/File:Bahnhof_Goslar_Grundriss.jpg) | 도면 | 대기 공간·출입구·서비스 공간의 평면 관계를 비교할 수 있다. 구체적인 실측 치수 판독은 확인 못 함이다. | 공유재산 표시이다. 니더작센의 사례이므로 대상 노선의 지역 고유 형태를 대신하지 않는다. |
| Fachwerk 주택 | B12 [Quedlinburg 목조 골조 주택 사진](https://commons.wikimedia.org/wiki/File:Fachwerkh%C3%A4user_in_Quedlinburg.jpg) | 사진 | 골조와 채움벽, 층별 입면, 창과 골조의 반복을 보여 준다. 부재 크기·층고·지붕 각도는 확인 못 함이다. | FrankBothe의 사진이며 CC-BY-SA 4.0이다. 도시 주택의 사례이므로 농촌 주택의 평면으로 일반화하지 않는다. |
| 농가·목조 주택 | B13 [Bechelsdorf 농가 도면](https://www.deutsche-digitale-bibliothek.de/item/CBEAJJW7FM2IWDHRYEMQP7LX6KTYDI6F) | 도면 | 1906년 간행물의 평면·박공측 입면·긴 측면·횡단면·상세 도면 기록이다. 북부 농가의 큰 실루엣과 내부 구획을 검토할 수 있다. 숫자 치수 판독은 확인 못 함이다. | CC0이며 원작·디지털 사본이 공유재산이다. 재현 도면과 현재 실물을 구분한다. |
| Vierseithof | B14 [Diesdorf의 Mitteldeutscher Vierseithof](https://www.freilichtmuseum-diesdorf.de/Mitteldeutscher-Vierseithof.html) | 사진·배치 설명 | 주거동·마구간·저장동·문간동이 둘러싼 농가 마당과 중앙의 별도 구조물을 설명한다. 박물관에 옮겨 구성한 사례이다. 건물 치수는 확인 못 함이다. | 사진의 상업 재사용 허락은 확인 못 함이다. 주거동은 박물관 재건 과정에서 평면을 변경했다고 명시하므로 원형 평면의 증거로 쓰지 않는다. |
| Vierseithof 부속동 | B15 [농가의 헛간·축사 기록 사진](https://www.deutsche-digitale-bibliothek.de/item/ZSD2W2WJHD7J5CGPR4T53BAHZYBUCYIW) | 사진 아카이브 | 농가 마당 쪽 헛간과 축사를 기록한 사진 자료이다. 큰 출입구·부속동의 반복을 비교한다. 치수는 확인 못 함이다. | 저작권 보호 표시이다. 상업적 복제 허락은 확인 못 함이다. 링크와 관찰용 자료로만 사용한다. |
| 벽돌 주택 | B16 [독일 벽돌 주택 사진 모음](https://commons.wikimedia.org/wiki/Category:Brick_houses_in_Germany) | 사진 | 벽돌 입면·박공·창 주변의 여러 유형을 비교하는 출발점이다. 동부 지역의 실측 사례만 선별한 모음은 아니다. | 파일별 라이선스이다. 각 파일의 촬영 장소를 확인한 뒤 대상 지역 자료를 고른다. 창 크기·지붕 각도는 확인 못 함이다. |
| Plattenbau·WBS 70 | B17 [Neubrandenburg 지역박물관의 Nur Beton](https://www.museum-neubrandenburg.de/Sammeln-Forschen/Nur-Beton/) | 기록·사진·도시 배치 자료 | WBS 70과 Neubrandenburg Oststadt의 건설·배치를 다룬 지역박물관 자료이다. 단지의 동 배치와 반복 외관을 조사하는 출발점이다. | 무료 열람이다. 사진·도면의 재사용 허락과 개별 건물 치수는 확인 못 함이다. |
| WBS 70 실내 | B18 [WBS 70 주거 실내 전시](https://www.ddr-museum.de/de/blog/2022/die-wbs-70-plattenbauwohnung) | 사진·실내 설명 | 재구성한 3실 주거의 방·복도·주방·욕실을 보여 준다. 소형 실내 모듈과 생활 흔적을 검토한다. | 박물관 전시의 재구성이다. 미변형 원형 실내나 실측 평면의 증거로 쓰지 않는다. 사진의 상업 재사용 허락은 확인 못 함이다. |
| WBS 70 치수 | B19 [Ludwigsfelde 주거동 개수 사례 발표](https://www.energiesprong.de/fileadmin/Dokumente/Extern/ES_on_tour_Ludwigsfelde/06_Best_Practices___Lessons_Learned_Seeria_Renova.pdf) | 도면·치수·사진 | PDF 6쪽에 벽 요소 6.00 × 2.80 m와 층고 2.80 m가 명시된다. 반복 벽 패널의 실제 수치 기준으로 쓴다. 2.80 m를 실내 유효 높이로 바꾸어 적지 않는다. | 무료 열람이다. 발표 자료의 그림 재사용 라이선스는 확인 못 함이다. 모든 WBS 70 변형과 창 크기의 규격을 입증하는 자료는 아니다. |
| 벽돌 교회 | B20 [브란덴부르크식 벽돌 마을 교회 설계](https://www.deutsche-digitale-bibliothek.de/item/7BOEWGHPW4AT65BDC3ASHFU2MX4K25R4) | 도면·축척 막대 | 평면·남측 입면·탑 입면·종단면·축척 막대가 있는 1877년 설계 기록이다. 벽체·지붕·탑의 관계를 검토한다. 지붕 각도의 숫자 판독은 확인 못 함이다. | CC0·공유재산 표기이다. 설계 공모안이므로 실재 준공 건물로 단정하지 않는다. |
| 작은 교회 | B21 [Hiddensee Kloster 교회 사진](https://commons.wikimedia.org/wiki/File:Hiddensee_kloster_kirche.jpg) | 사진 | 작은 북부 교회의 외관과 지붕·벽체의 비율을 보여 준다. 평면·치수는 확인 못 함이다. | Andreas Helgert의 별도 귀속 조건이다. 저작자 표시를 하면 상업 사용·변형을 허용한다고 명시한다. CC-BY로 임의 재명명하지 않는다. |
| 공장·창고 | B22 [Leipzig Baumwollspinnerei 사진 모음](https://commons.wikimedia.org/wiki/Baumwollspinnerei_%28Leipzig%29) | 사진 | 큰 벽돌 공장, 반복 창열, 산업 단지의 외관을 비교할 수 있다. 창·벽 모듈과 공장 실루엣에 쓴다. 실측 평면과 층고는 확인 못 함이다. | 파일별 라이선스이다. 보존·개수 뒤 사진과 과거 기록을 구분한다. |
| 주유소 | B23 [Leipzig 주유소 사진 모음](https://commons.wikimedia.org/wiki/Category:Petrol_stations_in_Leipzig) | 사진 | 캐노피·주유기·도로에서 진입하는 전면 공간을 비교할 수 있다. 치수와 공개 평면은 확인 못 함이다. | 파일별 라이선스이다. 시대에 맞는 사례를 고르며 상표 그림의 사용 권한은 별도로 확인한다. |
| 주차장 | B24 [Dresden 주차장 사진 모음](https://commons.wikimedia.org/wiki/Category:Car_parks_in_Dresden) | 사진 | 주차 면·통로·건물 주변 빈 공간을 비교한다. 농촌 역에 적용할 크기와 치수는 확인 못 함이다. | 파일별 라이선스이다. 도시 주차장의 밀도를 작은 마을에 그대로 옮기지 않는다. |
| 작은 상점 | B25 [Konsum 상점 실내 전시 사진](https://commons.wikimedia.org/wiki/File:Welt_der_DDR_Konsum_.jpg) | 사진 | 작은 상점의 진열대·카운터·상품 밀도를 보여 주는 Dresden 전시 사진이다. 실내 탐색 공간의 참고이다. 실제 상점 평면은 확인 못 함이다. | Phi의 사진이며 CC0이다. 박물관 재구성이고, 사진에 보이는 상품 포장·상표 자체의 권리를 일괄 허용하는 것은 아니다. |

치수 확보 상태는 WBS 70의 층고·벽 패널이 가장 분명하다. 나머지 유형의 정확한 층고·창 너비와 높이·지붕 각도는 확인 못 함이다. 공개 도면 기록에는 평면·단면·축척이 있는 자료가 있으나, 다음 제작 단계에서 원도면의 축척과 숫자를 판독하여 건물별 치수표를 작성해야 한다.

## 3. 오픈 데이터와 불러오기 도구

LoD1은 대체로 평면 윤곽을 압출한 블록 모델이며, LoD2는 일반화된 지붕을 더한 모델이다. 두 등급을 실내 평면이나 창호의 실측 자료로 해석하지 않는다. 정사영상은 도로·마당·지붕의 위치를 확인하는 자료이며, 벽면 사진을 대신하지 않는다.

| 대상 | 이름(링크) | 데이터·기능 | 모델링에 쓸 부분 | 라이선스·현재 확인 범위 |
|---|---|---|---|---|
| 문화재 기록 | D01 [작센 문화재 목록·DIVIS 안내](https://www.lfd.sachsen.de/denkmalliste.html) | 문화재 설명·지도·일부 사진 | 역·농가·산업 건물의 주소, 시대, 보호 대상 부분을 조사한다. | 국가기관의 공개 안내이다. 사진의 상업 재사용 권리는 확인 못 함이다. 목록에 없다는 이유로 문화재가 아니라고 판단하지 않는다. |
| 건물 윤곽 | D02 [OSM building 태그](https://wiki.openstreetmap.org/wiki/Key:building) | 건물 윤곽과 유형 태그의 공식 공동체 문서 | 역 주변 건물의 평면 윤곽과 대략적인 용도를 찾는 기준이다. 높이·층수·지붕 태그가 없는 건물의 수치를 자동 보충한 것으로 취급하지 않는다. | 원 데이터는 [OSM 이용 조건](https://www.openstreetmap.org/copyright)의 ODbL이다. 상업 사용이 가능하며 귀속·데이터 배포 조건을 확인한다. 태그 문서와 원 데이터의 라이선스를 구분한다. |
| 작센 LoD·지형 | D03 [높이·3D 도시 모델](https://www.geodaten.sachsen.de/digitale-hoehenmodelle-3994.html) | LoD1·LoD2·높이 자료 | 라이프치히 주변의 건물 덩어리·지붕 형태·지형을 잡는다. | 무료 오픈 데이터이다. [공식 FAQ](https://www.geodaten.sachsen.de/haufig-gestellte-fragen-4464.html)는 데이터 라이선스 독일 명명 2.0에 따른 상업 사용을 안내한다. 개별 제품의 제공자·갱신일을 함께 기록한다. |
| 작센 정사영상 | D04 [Luftbildprodukte](https://www.geodaten.sachsen.de/luftbild-produkte-3995.html) | 항공사진·DOP | 지붕·도로·마당·건물 간격을 대조한다. | 공개 DOP의 해당 제품 조건을 확인한다. 작센 FAQ의 데이터 라이선스 독일 명명 2.0 안내를 참조한다. 촬영 시기와 계절이 현재 게임의 겨울 풍경을 입증하지는 않는다. |
| 작센안할트 LoD | D05 [3D 건물 모델](https://geodatenportal.sachsen-anhalt.de/gfds/de/gdp-3d-gebaeudemodell.html) | LoD1·LoD2, CityGML·3D Shape | Altmark와 중간 정차역 주변의 건물 높이·배치를 조사한다. | [공식 Open Data 안내](https://lvermgeo.sachsen-anhalt.de/de/gdp-open-data.html)는 해당 공개 자료에 데이터 라이선스 독일 명명 2.0을 안내한다. 표준 다운로드는 무료이고 개별 주문은 유료일 수 있다. LoD1 제공은 2026년 11월 말까지라는 안내가 있어 후속 작업 때 재확인이 필요하다. |
| 작센안할트 정사영상 | D06 [Digitale Orthophotos](https://www.lvermgeo.sachsen-anhalt.de/de/gdp-digitale-orthophotos.html) | DOP 제품 안내 | 배치·마당·도로·역 구내의 실제 위치를 대조한다. | 무료 공개 자료는 D05의 Open Data 조건을 확인한다. 별도 주문·역사 영상의 조건을 일괄 동일하게 취급하지 않는다. |
| 브란덴부르크 LoD | D07 [3D 건물 모델 제공 목록](https://data.geobasis-bb.de/geobasis/daten/3d_gebaeude/) | LoD1·LoD2 GML 타일 | 통과 마을의 실루엣과 정차 구역의 초기 배치를 잡는다. | 제공 목록에 데이터 라이선스 독일 명명 2.0, 제공자 GeoBasis-DE / LGB가 명시된다. 무료이다. 실제 파일을 내려받아 검사한 것은 아니다. |
| 브란덴부르크 정사영상 | D08 [DOP 제공 목록](https://data.geobasis-bb.de/geobasis/daten/dop/) | 정사영상 타일 | 지붕·마당·농지와 길의 연결을 대조한다. | 데이터 라이선스 독일 명명 2.0, 제공자 GeoBasis-DE / LGB가 명시된다. 무료이다. |
| 메클렌부르크포어포메른 LoD | D09 [건물 모델 제품 안내](https://www.laiv-mv.de/Geoinformation/Geobasisdaten/gebaeude%E2%80%93modelle/) | LoD2·CityGML과 서비스 안내 | 북부 마을의 지붕과 건물 덩어리를 조사한다. 제품표에는 LoD1 정보도 있으나 현재 무료 타일 제공 범위는 별도 확인한다. | [공식 Open Data 안내](https://www.laiv-mv.de/Geoinformation/Open_Data_Angebot/)는 CC-BY 4.0을 명시한다. 상업 사용이 가능하며 제공자·변경 내용을 표시한다. 무료 다운로드와 유료 주문을 구분한다. |
| 메클렌부르크포어포메른 정사영상 | D10 [Luftbilder](https://www.laiv-mv.de/Geoinformation/Luftbilder/) | DOP·WMS·ATOM·역사 영상 안내 | 북부 해안과 뤼겐 주변의 건물·도로·농지 배치를 조사한다. | 공개 Open Data 자료에는 D09의 CC-BY 4.0 안내를 적용하되 개별 서비스 메타데이터를 대조한다. 역사 영상 전체의 조건은 확인 못 함이다. |
| 지형·OSM 도구 | D11 [BlenderGIS](https://github.com/domlysz/BlenderGIS) | Blender 애드온 | OSM XML, Shapefile, GeoTIFF 지형·영상 등을 다루는 경로이다. | [GPL-3.0](https://raw.githubusercontent.com/domlysz/BlenderGIS/master/LICENSE)·무료이다. 도구로만 쓰고 코드는 포함·재배포하지 않는다(참고만). 사용 중인 Blender 버전에서의 실행은 확인 못 함이다. 외부 지도·높이 서비스의 키와 이용 조건은 별개이다. |
| OSM 불러오기 절차 | D12 [BlenderGIS OSM import](https://github.com/domlysz/BlenderGIS/wiki/OSM-import) | 공식 애드온 문서 | OSM XML 직접 입력과 Overpass 조회 경로, 필터·지리 좌표 설정을 설명한다. | 무료 공개 문서이다. 데이터는 ODbL이다. 서버 장애·조회 제한 가능성이 명시되어 있으며 이번 조사에서 조회를 실행하지 않았다. |
| OSM 도시 불러오기 | D13 [Blosm](https://github.com/vvoovv/blosm) | Blender 애드온 | OSM 건물·지형 불러오기 경로를 검토한다. | GPL 소스이며(도구로만 쓰고 코드는 포함·재배포하지 않는다, 참고만) 기본 경로와 유료 경로의 구성이 다르다. 현재 판매 가격은 확인 못 함이다. 다른 제공자의 3D 도시 서비스 이용 권한을 이 애드온의 라이선스로 대신하지 않는다. |
| CityGML 불러오기 | D14 [CityGML importer/exporter](https://github.com/virtualcitySYSTEMS/blender-citygml-importer-exporter) | Blender 애드온 | CityGML 2.0·3.0의 건물 모델을 직접 불러오는 후보이다. OSM 도구와 구분하여 쓴다. | MIT·무료이다. 저장소는 Blender 4.2 이상 경로를 안내한다. 실제 주별 파일의 불러오기·재질·원점 처리는 확인 못 함이다. |

후속 제작 경로는 OSM 윤곽 → D11·D12 또는 D13 → Blender 정리 → glTF/GLB → Godot로 구성할 수 있다. 주별 CityGML은 D14로 불러오는 경로를 먼저 검토한다. 원본의 좌표계·미터 단위·지역 원점과 모델 높이를 대조한 뒤 지붕을 단순화하고, 가까이 수색할 건물에 창·문·실내를 별도로 붙이는 제작 제안이다. 이번 조사에서는 데이터 다운로드·애드온 설치·불러오기 실행을 하지 않았다.

## 4. 3D 렌더링 자원

가격은 조사일에 공개 페이지에 표시된 값이며 세금·지역 통화·팀 라이선스의 최종 결제액은 확인 못 함이다. 무료 공개 튜토리얼은 절차 참고용이며, 본문 그림과 예제 에셋의 재배포 허락을 일괄 의미하지 않는다. [Godot 공식 문서 저장소](https://github.com/godotengine/godot-docs)는 일반 문서를 CC-BY 3.0, 클래스 문서를 MIT로 구분한다. Godot 문서 링크는 기능 안내이고, 해당 프로젝트나 S22에서 실행한 성능 증거는 아니다.

| 이름(링크) | 종류(에셋·재질·HDRI·셰이더·튜토리얼·도구) | 어디에 쓸까 | 라이선스·가격 |
|---|---|---|---|
| R01 [Quaternius Ultimate Buildings Pack](https://quaternius.com/packs/ultimatetexturedbuildings.html) | 모듈 건물 에셋 | 아틀라스로 색을 바꾸는 건물 모듈의 제작 출발점이다. 독일 동부 고증은 B절로 보완한다. | CC0·무료이다. FBX·OBJ·Blend 제공이 명시된다. |
| R02 [Kenney City Kit Suburban](https://kenney.nl/assets/city-kit-suburban) | 저폴리 에셋 | 집·주변 공간의 빠른 블록아웃과 반복 단위를 검토한다. 지역 특유의 창·지붕을 그대로 제공한다고 보지는 않는다. | CC0·무료이다. |
| R03 [Kenney City Kit Commercial](https://kenney.nl/assets/city-kit-commercial) | 저폴리 에셋 | 작은 상업 구역과 다양한 건물 덩어리의 블록아웃에 쓴다. 동부 독일 상점으로 수정할 근거는 B절에서 찾는다. | CC0·무료이다. |
| R04 [Kenney City Kit Roads](https://kenney.nl/assets/city-kit-roads) | 도로 에셋 | 역 앞 교차로·도로 연결과 주차 공간의 초기 배치를 잡는다. | CC0·무료이다. |
| R05 [Kenney Train Kit](https://kenney.nl/assets/train-kit) | 철도 에셋 | 철도 배치와 소품의 초기 블록아웃에 쓴다. 독일 증기철도의 실제 규격·급수 설비는 B절로 보완한다. | CC0·무료이다. 실제 제공 모델 전체의 세부 목록·폴리곤 수는 확인 못 함이다. |
| R06 [Quaternius Ultimate Stylized Nature](https://quaternius.com/packs/ultimatestylizednature.html) | 자연 에셋 | 마을 뒤 숲과 반복 원경의 초기 배치에 쓴다. 겨울의 나뭇잎·눈 표현은 별도 수정이 필요하다. | CC0·무료이다. FBX·OBJ·glTF·Blend 제공이 명시된다. |
| R07 [Synty POLYGON Town](https://syntystore.com/products/polygon-town-pack) | 유료 저폴리 건물·소품 | 주택과 생활 구역의 조합을 살펴본다. 외관은 범용 교외 양식이므로 동부 독일 고증 자료로 취급하지 않는다. | 표시 가격 US$49.99이다. Synty EULA에 따른 게임 사용이며 원본 에셋의 공개 배포 조건과 팀 범위를 확인한다. |
| R08 [Synty POLYGON Apocalypse](https://syntystore.com/products/polygon-apocalypse-pack) | 유료 저폴리 에셋 | 폐허·차량·방어물·생활 잔해를 넓게 비교하는 후보이다. 지역 건물은 자체 모듈과 혼합하는 제작 제안이다. | 표시 가격 US$349.99이다. Synty EULA를 적용한다. 소품별 폴리곤 수와 Godot 4.7.2에서의 제공 상태는 확인 못 함이다. |
| R09 [KitBash3D Victorian](https://kitbash3d.com/products/victorian) | 유료 건물 키트 | 유럽계 역사 건물의 실루엣·장식·지붕 조합을 비교한다. 영국식 성격과 고밀도 모델을 동부 독일 모바일 키트로 그대로 사용하지 않는다. | 페이지 표시 가격은 $145이며 통화 설정은 확인 못 함이다. [공식 라이선스](https://kitbash3d.com/pages/licenses)는 상업 사용을 허용하며 개인·기업 규모에 따라 조건이 다르다. 실제 팀에 적용되는 가격은 확인 못 함이다. |
| R10 [ambientCG Bricks 001](https://ambientcg.com/view?id=Bricks001) | PBR 재질 | 어두운 붉은 벽돌의 기본 표면이다. 공장·역·벽돌 주택의 색과 반복 크기를 B절 사진에 맞춘다. | [ambientCG 라이선스](https://docs.ambientcg.com/license/)의 CC0·무료·상업 사용 가능이다. |
| R11 [Poly Haven Plaster Grey 04](https://polyhaven.com/a/plaster_grey_04) | PBR 재질 | 회반죽 외벽과 작은 역의 벽면에 쓴다. 지역 색·얼룩은 별도 제작한다. | [Poly Haven 라이선스](https://polyhaven.com/license)의 CC0·무료·상업 사용 가능이다. |
| R12 [Poly Haven Rusty Metal 05](https://polyhaven.com/a/rusty_metal_05) | PBR 재질 | 녹슨 판금·급수탑 부품·산업 소품에 쓴다. 페이지는 부식과 피팅이 있는 표면을 설명한다. | CC0·무료이다. 원본 고해상도 재질의 모바일 적용 크기는 별도 결정한다. |
| R13 [ambientCG Snow 001](https://ambientcg.com/view?id=Snow001) | PBR 재질 | 바닥·평지의 눈 표면에 쓴다. 지붕 위 눈의 두께와 실루엣은 별도 형상으로 만든다. | CC0·무료이다. |
| R14 [ambientCG Ice 001](https://ambientcg.com/view?id=Ice001) | PBR 재질 | 얼어붙은 물·얼음 표면의 비교 자료이다. 창문의 성에와 같은 표면으로 일반화하지 않는다. | CC0·무료이다. 페이지의 태그는 얼어붙은 호수·물 표면이다. |
| R15 [ambientCG Asphalt 010](https://ambientcg.com/view?id=Asphalt010) | PBR 재질 | 주차장·역 앞 길의 아스팔트 기본 표면이다. 젖은 표현은 거칠기·마스크를 수정하는 제작 제안이다. | CC0·무료이다. 젖은 아스팔트 전용 재질이라는 표기는 확인 못 함이다. |
| R16 [cgbookcase 재질 목록](https://www.cgbookcase.com/) | PBR 재질 라이브러리 | 벽·바닥 재질의 추가 후보와 PBR 적용 안내를 조사한다. | 홈페이지는 무료·용도 제한 없음을 안내한다. 정식 CC0 문구와 개별 재질의 조건은 확인 못 함이다. |
| R17 [Poly Haven Snowy Park 01](https://polyhaven.com/a/snowy_park_01) | HDRI | 흐린 겨울 낮, 부드럽고 차가운 빛, 낮은 대비와 앙상한 나무의 조명 기준으로 적합하다. | CC0·무료이다. 원본 해상도를 폰의 실행 해상도로 취급하지 않는다. |
| R18 [Poly Haven Snowy Field](https://polyhaven.com/a/snowy_field) | HDRI | 맑은 겨울의 역광·긴 그림자를 비교하는 보조 자료이다. 흐린 하늘의 기본안은 R17이다. | CC0·무료이다. 페이지는 밝고 대비가 큰 부분적으로 맑은 하늘을 설명한다. |
| R19 [Godot용 PolygonShader 대체 셰이더](https://godotshaders.com/shader/synty-polygon-drop-in-replacement-for-polygonshader/) | 눈 셰이더·코드 참고 | 표면 방향과 눈 효과를 가진 코드를 읽는 출발점이다. 삼평면 샘플링 전체의 모바일 비용을 검토하고 필요한 기능만 적용하는 제작 제안이다. | 코드·스니펫은 MIT·무료이다. 예시 이미지와 Synty 에셋은 같은 허락에 포함되지 않는다. 실제 엔진 호환과 성능은 확인 못 함이다. |
| R20 [Frostbite](https://godotshaders.com/shader/frostbite/) | 성에 화면 셰이더 | 화면 가장자리의 얼어붙은 표현과 진행량 제어를 참고한다. 창문 재질의 실제 성에 전용 셰이더는 아니다. | 코드·스니펫은 CC0·무료이다. 작성자는 4.6.3 제작·4.7 테스트를 안내한다. 4.7.2 실검증은 확인 못 함이다. 화면 샘플링·흐림의 폰 비용을 확인한다. |
| R21 [Godot 데칼 사용법](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html) | 튜토리얼 | 벽의 그을음·누수·파손을 마스크로 추가하는 방법의 기반이다. 전용 그을음 제작 튜토리얼을 찾은 것은 아니다. | 무료 공개 문서이다. Decal은 Forward+·Mobile에서 지원하며 Compatibility에는 별도 Sprite3D 등의 평면 대안을 안내한다. |
| R22 [Blender 모듈 환경 제작 강좌](https://www.3dmotive.com/p/learn-modular-environment-building-for-games-with-blender) | 튜토리얼 | 재사용 가능한 저폴리 산업 환경 모듈의 규격·조합 방식을 배우는 후보이다. | 페이지 표시 수강 가격은 $9이며 통화 설정은 확인 못 함이다. 강의 콘텐츠는 공개 에셋 라이선스가 아니다. 오래된 Blender 화면과 현재 버전의 차이를 확인한다. |
| R23 [Godot LightmapGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html) | 베이크 조명 튜토리얼 | 고정된 정차역 건물의 간접·직접 조명과 라이트맵 UV를 검토한다. 동적 인물과 이동 열차의 조명을 별도 설계한다. | 무료 공개 문서이다. 베이크 결과·메모리·동적 물체의 그림자는 실기기에서 확인해야 한다. |
| R24 [Godot Mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) | LOD 튜토리얼 | 멀어지는 건물·소품의 기하를 줄인다. 가져온 3D 장면의 자동 LOD와 개별 OBJ 메시의 처리를 구분한다. | 무료 공개 문서이다. 자동 생성 후 창·지붕 실루엣을 눈으로 확인한다. |
| R25 [Godot Visibility ranges·HLOD](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) | LOD 튜토리얼 | 가까운 개별 건물과 먼 거리의 합친 마을 덩어리를 거리로 교체하는 기반이다. | 무료 공개 문서이다. 전환·페이드가 실제 화면에서 보이는지와 추가 비용은 확인 못 함이다. |
| R26 [Godot 3D 성능 최적화](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) | 모바일 튜토리얼 | 정적 조명·재질·그리기 호출·장면 구성을 줄이는 우선순위를 검토한다. 모바일 베이크 조명을 권하는 공식 자료이다. | 무료 공개 문서이다. 특정 에셋 수나 S22 프레임 속도를 보장하는 자료는 아니다. |
| R27 [Material Combiner](https://github.com/Grim-es/material-combiner-addon) | 아틀라스 도구 | 여러 재질의 색·텍스처를 묶는 후보이다. 건물·소품의 공유 재질 수를 줄이는 제작 경로를 검토한다. | GPL-3.0·무료이다. 도구로만 쓰고 코드는 포함·재배포하지 않는다(참고만). 새 버전의 일부 다중 맵 기능 제한이 명시되어 있다. 현재 Blender에서의 PBR 맵·UV·여백 처리는 확인 못 함이다. |
| R28 [Blender에서 PBR 재질 사용하기](https://www.cgbookcase.com/learn/how-to-use-pbr-textures-in-blender) | 튜토리얼 | 색·거칠기·법선 등 PBR 맵의 연결을 이해하고 무료 재질을 시험하는 기반이다. | 무료 공개 글이다. 본문 그림의 재배포 라이선스는 확인 못 함이다. |
| R29 [Godot 3D 장면 가져오기](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html) | 파이프라인 문서 | Blender에서 만든 모듈을 엔진으로 옮길 때 가져오기 설정과 하위 문서로 이어지는 출발점이다. | 무료 공개 문서이다. 실제 파일을 만들어 내보내거나 불러오지는 않았다. |
| R30 [Godot StandardMaterial3D·ORM](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html) | 재질·렌더링 문서 | PBR 맵, ORM 채널, 투명도·빌보드·비조명 재질의 설정을 조사한다. 젖은 표면과 먼 배경 카드의 기반이다. | 무료 공개 문서이다. 기능마다 렌더러 지원과 비용이 다르므로 필요한 항목만 검토한다. |
| R31 [Godot 렌더러 비교](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) | 도구·성능 문서 | Mobile·Compatibility·Forward+의 기능 차이를 비교하고 눈·성에·데칼의 구현 범위를 정한다. | 무료 공개 문서이다. 폰 종류만으로 렌더러를 확정하지 않고 같은 장면으로 실측한다. |

Synty의 게임 이용 조건은 [라이선스 개요](https://syntystore.com/pages/licences-overview)와 [일회 구매 EULA](https://syntystore.com/pages/one-time-purchase-licence)에서 확인하였다. 게임에 포함하는 사용과 에셋 자체를 다른 사람이 재사용하도록 배포하는 사용을 구분한다. 공개 저장소에는 이번처럼 링크 목록만 둔다. Godot 엔진의 MIT 고지와 포함된 제3자 라이선스는 [공식 라이선스 준수 안내](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)를 참조한다.

## 5. 바탕화면 연출 자원

아래의 작품 행은 구조를 관찰할 출처이다. 장면 배치에 관한 적용 문장은 제작 제안이며, 해당 작품의 기술 구현이나 성능을 분석하여 입증한 결과가 아니다. 작품의 사진·영상·모델을 게임에 복제할 허락을 확보한 것은 아니다.

| 이름(링크) | 확인한 자료 | 어디에 쓸까 | 라이선스·주의점 |
|---|---|---|---|
| C01 [Godot 2D Parallax](https://docs.godotengine.org/en/stable/tutorials/2d/2d_parallax.html) | 이동 비율·반복·스크롤 오프셋 문서이다. | 직접 만든 3D 마을을 미리 렌더한 이미지의 원경·중경·근경 레이어에 서로 다른 속도를 주는 기반이다. | 무료 공개 문서이다. Parallax2D는 2D 기능이므로 3D 카메라용 자동 기능으로 설명하지 않는다. |
| C02 [Godot MultiMesh 최적화](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) | 반복 인스턴스의 그리기 호출을 줄이는 공식 자료이다. | 반복 울타리·전신주·가로등·나무를 구간 단위로 묶는 제작 제안이다. | 무료 공개 문서이다. 개별 인스턴스 가시성 처리의 제한을 고려하여 지나치게 넓은 한 묶음으로 만들지 않는다. |
| C03 [Godot Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html) | SubViewport·ViewportTexture와 갱신 제어 문서이다. | 고정된 배경을 한 번 렌더하거나 필요할 때만 갱신하는 경로를 검토한다. | 무료 공개 문서이다. 작은 해상도로 렌더해도 매 프레임 별도 3D 장면을 다시 그리면 비용이 생긴다. |
| C04 [The Long Dark 공식 판매 페이지](https://store.steampowered.com/app/305620/The_Long_Dark/) | 겨울 생존 게임의 공식 소개와 화면 자료이다. | 눈·빈 공간·큰 실루엣을 통해 사람이 없는 장소를 읽게 하는 장면 구성을 관찰하는 제안이다. | 장면 구조 참고용이다. 그림·모델·음악의 이용 허락은 확인 못 함이다. 독일 동부의 건축 자료는 아니다. |
| C05 [INFRA 공식 판매 페이지](https://store.steampowered.com/app/251110/INFRA/) | 산업 시설을 탐색하는 게임의 공식 소개와 화면 자료이다. | 사람 없는 산업 공간에서 길·구조물·파손 흔적으로 시선을 유도하는 구성을 관찰하는 제안이다. | 장면 구조 참고용이다. 화면·모델 추출 권한은 확인 못 함이다. 지역 건축 고증은 B절을 따른다. |
| C06 [Days Gone 공식 페이지](https://www.playstation.com/en-us/games/days-gone/) | 다수의 적과 야외 생존 장면을 다룬 공식 소개·화면 자료이다. | 군중 덩어리·도로·지형·은폐 공간을 겹쳐 위험의 규모를 읽게 하는 구성을 관찰하는 제안이다. | 장면 구조 참고용이다. 미국 배경의 외관을 중부 유럽으로 옮기는 자료가 아니다. 적 개체 수나 구현 비용은 이번 작업에서 검증하지 않았다. |

가장 먼저 시험할 제작안은 네 겹이다. 근경에는 선로 옆 울타리·기둥을, 중경에는 실제 마을 배치를 압축한 집·창고를, 원경에는 숲·마을 지붕선·교회 탑을, 가장 뒤에는 흐린 하늘을 둔다. 레이어마다 반복 주기와 이동량을 다르게 하며, 역의 대표 건물 하나는 반복하지 않는 구간 표식으로 둔다. 실제 장소의 이름·지도 모드에 대한 기존 내용은 `pz_vehicles_maps_winter.md`를 참조한다.

3D를 유지하는 안은 비조명 재질의 먼 배경 카드와 가까운 저폴리 메시를 함께 쓰고, 먼 건물은 R25의 거리 전환으로 합친 덩어리로 교체하는 구성이다. 미리 만든 이미지를 쓰는 안은 C01의 스크롤 레이어 또는 C03의 갱신 제어를 검토한다. 카드가 여러 겹 겹치면 투명 픽셀을 반복해서 그리는 비용이 커질 수 있으므로 큰 불투명 실루엣을 우선하는 제작 제안이다. 좀비는 정차 수색 구역의 실제 개체와 달리는 원경의 실루엣 표현을 각각 설계하고, 원경의 군중을 실제 인공지능 개체 수로 채우는 것을 전제로 삼지 않는다.

## 6. 추가로 할 것

### 먼저 할 것

1. B01·B03을 작은 역, B13·B14를 농가, B19를 WBS 70의 첫 제작 근거로 고르고 도면·사진의 연대를 대조한다. 한 건물마다 바닥 윤곽·층고·창 너비와 높이·처마 높이·지붕 경사를 따로 기록한다.
2. 도면 이미지를 열 수 있는 다음 제작 단계에서 축척 막대와 치수선을 판독한다. 사진에 창 개수가 보인다는 이유로 미터 치수를 추정해 기록하지 않는다. WBS 70의 2.80 m 층고와 벽 패널 치수는 B19에 표시된 용어·단위를 유지한다.
3. 첫 역 주변의 작은 구역 하나에서 OSM 윤곽·주별 LoD2·정사영상을 대조한다. 촬영 시기, 누락 건물, 일반화된 지붕을 기록하고 수색 동선에 맞게 배치를 압축한다.
4. 벽·코너·문·창·박공·지붕·기초를 반복 단위로 나누고, 실제 치수 근거를 얻은 뒤 스냅 규격과 피벗을 정한다. 가까운 건물의 실내를 만들고 먼 건물은 외피로 제작한다.
5. 한 역 장면과 한 이동 배경 장면으로 Mobile·Compatibility를 비교한다. 프레임 시간·메모리·그리기 호출·투명 레이어 비용을 측정하고 베이크 조명·LOD·아틀라스의 효과를 확인한다. S22급이라는 조건만으로 폴리곤 수와 텍스처 해상도 상한을 단정하지 않는다.
6. 눈은 형상·표면 마스크·화면 효과를 구분하여 시험한다. 그을음·누수는 R21의 데칼 또는 평면 대안부터, 성에는 R20의 화면 효과와 별도 창 재질을 비교한다.

### 나중에 할 것

1. 작은 상점·주유소·공장·벽돌 농가의 공개 실측 평면과 창호 치수 자료를 보충한다. 현존 형태와 역사 형태를 한 키트에 섞을 경우 제작 기준 연도를 정한다.
2. 가로등·울타리·철도 배수로·빈 상자·파손 차량을 모아 같은 아틀라스와 색 범위로 맞춘다. 유료 팩은 필요한 소품 수와 팀 라이선스를 확인한 뒤 선택한다.
3. 정차역마다 고유 역사·교회·급수탑 중 하나를 만들고, 나머지 마을은 같은 모듈의 조합으로 변화를 준다. 뤼겐 쪽의 북부 외관은 별도 사진으로 검토한다.
4. 허용 조건을 충족하는 제작 단계에서 애드온과 주별 타일을 시험하고, Blender → Godot 4.7.2의 축·단위·법선·재질·UV2·충돌·LOD를 확인한다.
5. 제작에 실제 사용한 자료는 제공자·저작자·라이선스 버전·수정 내용을 기록한다. 공개 저장소의 링크 목록과 게임 배포용 크레딧을 관리한다.

## 7. 찾았지만 못 연 것, 못 찾은 것

이 절에는 열지 못한 주소를 링크로 적지 않는다. 아래는 자료의 부재가 아니라 이번 조사에서 확인할 수 없었던 범위이다.

| 항목 | 이번 조사 상태 | 남은 확인 |
|---|---|---|
| TU Berlin의 개별 기관고 직접 페이지 | 기관고 검색 결과는 찾았으나 직접 페이지는 오류로 열지 못했다. | Magdeburg·Potsdam 등 대상 지역 기관고의 실제 공개 평면·단면을 다시 찾는다. B10은 시설 사진을 보는 대체 경로이다. |
| Deutsche Fotothek의 Dresden 중앙역 개별 사진 | 검색 결과를 찾았으나 해당 직접 기록 페이지를 열지 못했다. | 현재 열리는 개별 사진과 재사용 조건을 찾는다. B22 등 이번에 열린 사진 모음과 구분한다. |
| Delitzsch·Falkenberg의 별도 Empfangsgebäude 기록 | 별도 기록은 열지 못했다. | B03·B04의 공개 도면 기록은 열었으므로 이를 먼저 사용한다. |
| DBU WBS 70 개수 보고서 | 검색 결과에서 보고서를 찾았으나 PDF를 열지 못했다. | 세부 평면과 창호 규격은 확인 못 함이다. 이번에 열린 수치 근거는 B19이다. |
| Blender 공식 glTF·Cycles 베이크 매뉴얼 | 해당 공식 페이지와 대체 버전 페이지에서 열기 오류가 발생하였다. 도구가 한 페이지에 반환한 402 상태를 실제 유료화의 증거로 해석하지 않는다. | Blender 공식 절차를 다시 확인한다. 현재 열린 대안은 R28·R29와 Godot R23이다. |
| 일부 거리 소품·기관고 사진 모음의 후보 주소 | 관련 후보를 검색·열기 시도했지만 유효한 자료 페이지를 확인하지 못하였다. | 가로등·울타리·거리 잔해의 정확한 무료 팩과 모델 목록을 추가한다. 후보 이름이나 주소를 유효한 자원으로 기재하지 않았다. |
| 작은 상점·주유소·주차장·공장 실측 평면 | 유형 사진은 열었지만 대상 지역의 충분한 공개 실측 평면·단면은 확보하지 못하였다. | 건축 기록·시설 개수 자료의 공개 도면을 보충한다. |
| 유형별 창 치수·지붕 각도 | WBS 70의 층고·패널 외에는 충분히 확인 못 함이다. | 축척 도면을 판독한 뒤 건물별 수치표를 만든다. B19의 수치를 다른 유형에 적용하지 않는다. |
| 창문 성에·그을음 전용 Godot 4 튜토리얼 | 화면 성에 코드와 일반 데칼 문서는 열었으나 창문 성에·그을음 제작을 모두 다루는 전용 자료는 확보하지 못하였다. | R20·R21은 구현 경로의 기반으로만 적었다. |
| 젖은 아스팔트 전용 검증 재질 | 열린 R15는 일반 아스팔트이고, 젖은 전용 재질로 확인하지 못하였다. | 별도 젖음 마스크·거칠기 변경을 제작 시험하거나 정확한 전용 재질을 추가한다. |
| Godot 4.7.2·S22 실제 동작 | 자료 페이지를 읽었으며 엔진·애드온·에셋을 설치하거나 실행하지 않았다. | 문서 버전과 실제 가져오기·셰이더·메모리·성능을 확인한다. |
| 실제 제출·공개 저장소 반영 | 지정한 로컬 문서를 작성한 상태이다. | 이번 작업에서는 공개 저장소 게시·push·구매를 실행하지 않았다. |
