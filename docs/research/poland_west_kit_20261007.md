# 폴란드 서부 구간 지역 키트 K1·K2 자료 조사

> 자료 11개. 조사 상태: PARTIAL. 사진 두 장(Golejewko 성당 탑, Stare Bojanowo 역)의 라이선스와 촬영일을 Commons에서 직접 대조했다. GUGiK 안내 페이지는 이 기록을 옮길 때 다시 열지 못했으니 쓰기 전에 허가 문구를 다시 확인한다. 상업 게임 사용은 여전히 미확인이다. 데이터·사진 파일은 저장소에 넣지 않고 링크만 둔다. 이 문서는 조사 기록이며 확정 사항이 아니다.

## 1절 한눈 요약

- 확인일은 2026-10-07이며, 직접 열린 제공·허가 페이지를 근거로 데이터 6종과 건물 사진 참고 5건을 정리했다. 허가 문서와 보류·제외 항목은 자료 수에 넣지 않았다.
- 대폴란드(Wielkopolska) 호수 평야와 오데르(Odra)·보브르(Bóbr) 골짜기의 제작 자료를 찾는 입구로 GUGiK를 제시한다. 전국 제공 입구와 해당 구간의 실제 파일 확보는 구분한다.
- LoD1·LoD2는 CityGML 2.0이며, NMT는 지형 높이, 정사영상은 지표 배치, LAS·LAZ는 지형·건물 점군을 확인하는 자료다. 지역별 실제 파일과 최신 촬영연도는 미확인이다.
- 원본 항공사진은 전체 해상도로 받으려면 유료 신청이 필요하다. 데이터의 무료·자유 이용 안내는 확인했지만, 허가 문서에서 상업 게임 사용을 분명히 확인하지 못한 항목은 미확인으로 남겼다.
- 사진은 링크만 제공한다. 현재 붉은 벽돌 농가를 확정하지 못해 1957년 주택 사진을 형태 보조로, 2014년 농장 출입 건물을 벽돌 색 보조로 제시한다.
- 자료 파일과 사진 파일을 내려받거나 공개 저장소에 올리지 않았다. 제외 대상의 개별 자료를 수집하지 않았으며, 남은 허가·지역·농가 확인 공백 때문에 결과는 PARTIAL이다.

## 2절 공개 3D·지형·영상 자료 표

다음은 실제로 열린 공식 제공 안내를 통해 확인한 자료다. ‘받는 곳’은 그 안내에 적힌 지도 메뉴 경로다. 동적으로 생성되는 군·도엽별 파일 링크 자체를 시험하거나 파일을 확보하지는 않았다. 전국 자료에서 K1·K2의 대상 구역을 선택해야 하며, 구간 배경 문서의 '지나가되 보여 주지 않는 곳'은 선택 범위에서 빼야 한다.

| 자료 이름(링크) | 범위 | 형식 | 받는 곳 | 사용 허가와 상업 사용 | 출처 표기 문구 | 근거 URL |
|---|---|---|---|---|---|---|
| [GUGiK 건물 모델 LoD1](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/) | 전국의 BDOT10k 건물 중 상당 부분이며 군(powiat)별 패키지다. 열린 안내의 최신 목록은 LoD1 2024다. 대상 구간의 개별 군 패키지는 미확인이다. | CityGML 2.0이다. 건물 윤곽과 점군 높이를 이용한 평지붕 입체다. | [공식 제공 안내](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/) → Geoportal의 `Pobierz dane → Dane do pobrania → Topografia → Modele 3D budynków → Budynki LoD1 – 2024`에서 군을 식별해 받는다. | 데이터 안내의 무료·자유 이용 문구와 재사용 지침을 확인했다. 약관은 출처를 밝힌 게시를 허용한다. **상업 게임 사용은 미확인**이다. | 표기안 A에 자료명 `Modele 3D budynków LoD1`과 실제 버전·군 이름을 넣는다. | [자료·형식](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/), [약관 제3조](https://www.geoportal.gov.pl/en/about-geoportal/terms-and-conditions/), [재사용 조건](https://www.gov.pl/web/gugik/ponowne-wykorzystanie-informacji-sektora-publicznego) |
| [GUGiK 건물 모델 LoD2](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/) | CAPAP의 10개 주, 236개 군에 대한 자료다. 전국 전부라고 표시하지 않는다. 대폴란드·Odra·Bóbr의 대상 군별 포함 여부는 미확인이다. | CityGML 2.0, LoD2다. 폴란드어 안내는 2017년 상태라고 적는다. 텍스처 포함 여부는 미확인이다. | [공식 제공 안내](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/) → `Pobierz dane → Dane do pobrania → Topografia → Modele 3D budynków → Budynki LoD2`에서 군을 식별해 받는다. | 무료·자유 이용 안내와 재사용 지침을 확인했다. **상업 게임 사용은 미확인**이다. | 표기안 A에 `Modele 3D budynków LoD2`, 실제 자료연도·군 이름을 넣는다. | [자료·범위](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/), [약관 제3조](https://www.geoportal.gov.pl/en/about-geoportal/terms-and-conditions/), [재사용 조건](https://www.gov.pl/web/gugik/ponowne-wykorzystanie-informacji-sektora-publicznego) |
| [GUGiK 정사영상 ORTO](https://www.geoportal.gov.pl/pl/dane/ortofotomapa-orto/) | 폴란드 국가 정사영상의 도엽·연도별 제공 입구다. 대상 평야·골짜기의 개별 도엽과 촬영연도는 미확인이다. | 래스터이며 WCS의 GeoTIFF 출력 경로를 확인했다. WMS·WMTS는 열람 서비스다. 개별 원본 배포 파일의 확장자는 미확인이다. | [공식 제공 안내](https://www.geoportal.gov.pl/pl/dane/ortofotomapa-orto/) → `Pobierz dane → Dane do pobrania → Ortofotomapa`의 도엽 식별·파일 링크 또는 안내된 WCS로 받는다. | 무료·자유 이용 안내와 재사용 지침을 확인했다. **상업 게임의 지면 텍스처 사용은 미확인**이다. | 표기안 A에 `Ortofotomapa`, 실제 도엽·촬영연도를 넣고 잘라내기·색 보정 여부를 적는다. | [제공·GeoTIFF 출력](https://www.geoportal.gov.pl/pl/dane/ortofotomapa-orto/), [약관 제3조](https://www.geoportal.gov.pl/en/about-geoportal/terms-and-conditions/), [재사용 조건](https://www.gov.pl/web/gugik/ponowne-wykorzystanie-informacji-sektora-publicznego) |
| [GUGiK 수치지형모델 NMT](https://www.geoportal.gov.pl/pl/dane/numeryczny-model-terenu-nmt/) | 폴란드 지표면 높이 자료의 도엽별 제공 입구다. 기본 격자는 1m이며 5m 격자도 안내한다. 대상 구역의 가용 도엽·연도는 미확인이다. | GRID·TIN을 설명한다. WCS의 GeoTIFF 출력 경로를 확인했다. 개별 원본 파일이 ASCII GRID인지 여부는 미확인이다. | [공식 제공 안내](https://www.geoportal.gov.pl/pl/dane/numeryczny-model-terenu-nmt/) → `Pobierz dane → Dane do pobrania → Numeryczny Model Terenu → Siatka ≤ 1m / Siatka 5m` 또는 안내된 WCS로 받는다. 높이 기준계도 선택한다. | 무료·자유 이용 안내와 재사용 지침을 확인했다. **상업 게임의 지형 메시 제작에 사용할 권한은 미확인**이다. | 표기안 A에 `Numeryczny Model Terenu`, 도엽·격자·높이 기준계를 넣고 지형 가공 사실을 적는다. | [제공·격자·출력](https://www.geoportal.gov.pl/pl/dane/numeryczny-model-terenu-nmt/), [약관 제3조](https://www.geoportal.gov.pl/en/about-geoportal/terms-and-conditions/), [재사용 조건](https://www.gov.pl/web/gugik/ponowne-wykorzystanie-informacji-sektora-publicznego) |
| [GUGiK 항공 레이저 점군 LIDAR](https://www.geoportal.gov.pl/pl/dane/dane-pomiarowe-lidar/) | 안내는 전국 ALS 점군의 범위를 명시한다. 대상 구역의 최신 섹션·점밀도는 미확인이다. | LAS와 압축형 LAZ다. 지면·식생·건물 등의 분류값을 포함한다. | [공식 제공 안내](https://www.geoportal.gov.pl/pl/dane/dane-pomiarowe-lidar/) → `Pobierz dane → Dane do pobrania → Chmura punktów`에서 기준계와 섹션을 선택해 받는다. | 무료·자유 이용 안내와 재사용 지침을 확인했다. **상업 게임의 메시·충돌 지형 제작 사용은 미확인**이다. | 표기안 A에 `Dane pomiarowe LIDAR`, 섹션·측정연도·기준계를 넣고 점군 가공 사실을 적는다. | [제공·LAS/LAZ](https://www.geoportal.gov.pl/pl/dane/dane-pomiarowe-lidar/), [약관 제3조](https://www.geoportal.gov.pl/en/about-geoportal/terms-and-conditions/), [재사용 조건](https://www.gov.pl/web/gugik/ponowne-wykorzystanie-informacji-sektora-publicznego) |
| [GUGiK 사진측량 항공사진](https://www.geoportal.gov.pl/en/data/photogrammetric-aerial-imagery/) | 수직·경사 항공사진의 촬영 위치·범위·연도별 색인이다. 대상 구간의 현재 촬영편은 미확인이다. 현대 촬영 자료를 우선 선택해야 한다. | 저해상도 미리보기는 JPG다. 전체 해상도 원본의 실제 전달 형식은 미확인이다. | [공식 제공 안내](https://www.geoportal.gov.pl/en/data/photogrammetric-aerial-imagery/)의 `Indexes → Aerial Imagery`에서 식별한다. 전체 해상도는 안내에 연결된 PZGIK 포털의 계정·신청·유료 제공 절차다. 신청하지 않았다. | 무료 공개 원본으로 분류하지 않는다. 약관의 일반 게시 조건은 확인했으나 유료 원본의 개별 허가·상업 게임 사용·요금은 **미확인**이다. | 표기안 A는 일반 출처 표기 제안이다. 실제 제공 시 붙는 개별 허가 문구와 저자 정보가 확인되어야 한다. | [유료 원본·JPG 미리보기 안내](https://www.geoportal.gov.pl/en/data/photogrammetric-aerial-imagery/), [약관 제3조](https://www.geoportal.gov.pl/en/about-geoportal/terms-and-conditions/), [재사용 조건](https://www.gov.pl/web/gugik/ponowne-wykorzystanie-informacji-sektora-publicznego) |

**표기안 A**는 공식적으로 지정된 고정 문장을 인용한 것이 아니라, 열린 재사용 지침의 의무 정보를 담도록 작성한 제안이다. 예시는 `Źródło: Główny Urząd Geodezji i Kartografii (GUGiK); [자료명·버전]; [제작 시점]; [실제 취득일]; [가공 내용]; [확인된 저자명]`이다. 지침은 기관의 정식 명칭, 정보의 제작·취득 시점, 가공 사실, 알려진 창작자의 이름 등을 알리도록 한다. 이번 확인일을 파일 취득일로 적으면 안 된다. 별도 재사용 조건이 있는 자료는 그 조건을 먼저 확인해야 한다. [GUGiK 재사용 지침](https://www.gov.pl/web/gugik/ponowne-wykorzystanie-informacji-sektora-publicznego)을 직접 열어 확인했다.

## 3절 건물 사진 참고 표

개별 파일 설명과 아래에 연결한 실제 라이선스 페이지를 직접 열었다. 표의 상업 이용 판정은 사진 저작권의 허용 범위에 대한 것이다. 새로 제작할 3D 모델에 사진의 동일조건 의무가 적용되는지는 미확인이다. 사진 파일을 텍스처로 복제·변형해 배포할 때는 저자·파일 제목·원문 링크·라이선스 링크·변경 내용을 표시하고 해당 동일조건을 따라야 한다. [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/), [CC BY-SA 3.0 PL](https://creativecommons.org/licenses/by-sa/3.0/pl/), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)은 상업 목적의 공유·가공을 명시적으로 허용한다.

| 대상(농가·헛간·성당 탑·시골역) | 장소(지금 이름) | 링크 | 라이선스 | 무엇을 보여 주나 |
|---|---|---|---|---|
| 농가 참고 — 벽돌 주택의 형태 보조 | Sokołowo Budzyńskie다. 원문에 있는 과거 행정구역 이름은 지명으로 옮기지 않는다. | [벽돌 주택 사진 003460n](https://commons.wikimedia.org/wiki/File:Murowany_dom_z_cegie%C5%82_-_Soko%C5%82owo_Budzy%C5%84skie_-_003460n.jpg) | **CC BY-SA 3.0 PL이며 상업 이용이 가능하다.** 저자는 Józef Burszta다. 표기안은 `Józef Burszta, Murowany dom z cegieł – 003460n, [사진 링크], CC BY-SA 3.0 PL, [변경 내용]`이다. [허가 문서](https://creativecommons.org/licenses/by-sa/3.0/pl/)를 확인했다. | 촬영연도는 **1957년**이다. 맞배 기와지붕, 입구의 작은 지붕, 세로로 긴 창과 농촌 주택의 비례를 보여 준다. 흑백 사진이므로 실제 벽돌 색과 2026년 현황은 미확인이다. 농가의 농업 용도 자체도 미확인이다. |
| 농가 부속 참고 — 농장 출입 건물의 벽돌 색·줄눈 보조 | Szreniawa의 농업박물관 농장 구역이다. 주거 농가로 표시하지 않는다. | [Szreniawa 농장 출입 건물](https://commons.wikimedia.org/wiki/File:National_Museum_of_Agriculture_in_Szreniawa,_folwark.JPG) | **CC BY-SA 3.0이며 상업 이용이 가능하다.** 저자는 Wistula다. 표기안은 `Wistula, National Museum of Agriculture in Szreniawa, folwark.JPG, [사진 링크], CC BY-SA 3.0, [변경 내용]`이다. [허가 문서](https://creativecommons.org/licenses/by-sa/3.0/)를 확인했다. | **2014-04-18** 사진이다. 적갈색 벽돌, 밝은 줄눈, 큰 아치형 목재문, 돌 기단과 작은 세로 창의 대비를 보여 준다. 붉은 벽돌 주택 대신 농장 부속 건물의 재료를 참고하는 보조 자료다. |
| 헛간 | Dzwonowo Leśne의 Puszcza Zielonka 숲속 마을이다. | [Dzwonowo Leśne 헛간](https://commons.wikimedia.org/wiki/File:Dzwonowo_Lesne_%28barn%29.jpg) | **CC BY-SA 3.0이며 상업 이용이 가능하다.** 저자는 MOs810이다. 표기안은 `MOs810, Dzwonowo Lesne (barn).jpg, [사진 링크], CC BY-SA 3.0, [변경 내용]`이다. [허가 문서](https://creativecommons.org/licenses/by-sa/3.0/)를 확인했다. | **2013-06-13** 사진이다. 짙게 풍화된 세로 목판 벽, 넓은 맞배지붕, 큰 작업 출입구와 길쭉한 덩어리를 보여 준다. 붉은 벽돌 헛간으로 오인하지 않는다. |
| 가톨릭 성당 탑 | Golejewko의 Wszystkich Świętych 성당이다. [장소·가톨릭 용도 설명](https://commons.wikimedia.org/wiki/Category:All_Saints_church_in_Golejewko)을 확인했다. | [Golejewko 성당 탑 277-21](https://commons.wikimedia.org/wiki/File:Golejewko_277-21.jpg) | **CC BY-SA 3.0이며 상업 이용이 가능하다.** 저자는 Roweromaniak이다. 표기안은 `Roweromaniak, Golejewko 277-21.jpg, [사진 링크], CC BY-SA 3.0, [변경 내용]`이다. [허가 문서](https://creativecommons.org/licenses/by-sa/3.0/)를 확인했다. | **2005-09-17** 사진이다. 큰 미리보기에서 연노랑 시계탑, 어두운 둥근 지붕, 그 위의 작은 구조와 십자가를 확인했다. 성당 전경에 조형물이 함께 나온 다른 사진은 제외하고 탑 단독 사진을 골랐다. |
| 시골역 | Stare Bojanowo다. [역의 장소 설명](https://commons.wikimedia.org/wiki/Category:Stare_Bojanowo_train_station)을 확인했다. | [Stare Bojanowo 역사](https://commons.wikimedia.org/wiki/File:Dworzec_w_Starym_Bojanowie.jpg) | **CC BY-SA 4.0이며 상업 이용이 가능하다.** 저자는 Tobiasz0708이다. 표기안은 `Tobiasz0708, Dworzec w Starym Bojanowie.jpg, [사진 링크], CC BY-SA 4.0, [변경 내용]`이다. [허가 문서](https://creativecommons.org/licenses/by-sa/4.0/)를 확인했다. | **2020-06-09** 사진이다. 연한 황갈색 외벽, 중앙의 높은 맞배 부분과 낮은 양옆 건물, 흰 창틀의 세로 창, 역명 표기 위치를 보여 준다. 전체 미리보기에서 요청한 제외 표식·시설은 확인되지 않았다. |

## 4절 3D 제작에 옮길 점

- 제작 제안으로, Szreniawa 사진의 적갈색 벽돌·밝은 줄눈·어두운 돌 기단을 서로 다른 재료 영역으로 나누어 작은 화면에서도 입면을 읽을 수 있게 한다.
- 주택은 1957년 사진의 맞배지붕, 작은 입구 지붕과 세로 창 비례만 참고한다. 그 사진을 붉은 벽돌의 색 견본으로 사용하지 않는다.
- 헛간은 Dzwonowo Leśne 사진의 길쭉한 덩어리, 세로 목판과 넓은 맞배지붕을 독립 모듈로 만든다.
- 성당 탑은 시계·둥근 지붕의 윤곽, 역사는 중앙 맞배와 낮은 양옆 건물의 높이 차를 우선 잡는다. 확인하지 않은 치수는 실측값으로 쓰지 않는다.
- 지형은 NMT의 높이, 정사영상의 지표 배치, 건물 모델의 윤곽을 대조하는 제작 방안을 쓴다. 모바일용 메시 단순화는 제작 제안이며 원자료의 상업 사용 허가를 대신하지 않는다.

## 5절 못 연 것, 미확인 목록

- **현재의 붉은 벽돌 주거 농가 사진은 미확인이다.** 1957년 주택은 형태 보조이며 농업 용도·원래 벽돌 색·현황을 확정하지 못했다. 2014년 Szreniawa 사진은 농장 출입 건물이라 주거 농가의 대체 증거로 쓰지 않았다.
- **GUGiK 데이터의 상업 게임 사용 허가는 미확인이다.** 제공 안내의 자유 이용 문구, 약관의 출처 조건, 기관의 재사용 지침을 읽었으나 상업 게임 사용을 분명히 규정한 개별 허가를 확인하지 못했다. 무료 제공을 상업 사용 확정으로 바꾸지 않았다.
- **LoD2의 대상 구간 군별 적용 범위는 미확인이다.** 공식 안내의 10개 주·236개 군이라는 범위는 확인했다. [범위 지도 이미지](https://www.geoportal.gov.pl/wp-media/2025/07/rys1-5-1024x534.png)는 검색 도구에서 열리지 않았으며 근거로 쓰지 않았다.
- **LoD2 기준연도 표기가 서로 다르다.** [폴란드어 안내](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/)는 2017년, [영어 안내](https://www.geoportal.gov.pl/en/data/other-data/3d-models-of-building/)는 2018년으로 설명한다. 표는 폴란드어 페이지의 표기를 따랐으며 개별 패키지 메타데이터로 차이를 해소하지 못했다.
- **파일 자체 검증은 미실행이다.** 개별 지역 패키지의 존재·정상 열림·좌표계·텍스처, 원본 ORTO·NMT의 파일 확장자, 대상 도엽의 최신 촬영연도는 미확인이다. 실제 파일을 내려받지 않았기 때문이다.
- **전체 해상도 항공사진의 전달 형식·요금·개별 라이선스는 미확인이다.** 계정 생성, 유료 신청, 결제는 하지 않았다. 정사영상의 무료 제공과 원본 항공사진의 유료 제공을 구분했다.
- **사진의 2026년 건물 현황은 미확인이다.** 촬영일을 확인일과 구분했다. 사진 5건의 화면 미리보기를 살폈으며 요청한 제외 표식·시설은 확인되지 않았다. 초기 브라우저 시간 초과는 재확인으로 해소했다. 이는 원본 이미지 파일의 픽셀 단위 검사나 현장 조사를 했다는 뜻은 아니다.
- **제외 후보를 채택하지 않았다.** 성당 전경에 받침대 위 조형물이 나온 사진과 울타리가 함께 나온 2013년 역 사진은 제외했다. 1939~1945년 사진, 군대·정당 표식 자료, 추모 시설과 맡긴 글의 제외 목록에 든 장소·시설은 참고 대상으로 추가하지 않았다. 전국 데이터에 대한 제외 건물 자동 필터링은 실행하지 않았다.
