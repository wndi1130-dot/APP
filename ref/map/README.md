# 첫 구간 지리 데이터

[조사 결과 요약](summary.md). 기준일 2026-10-07. 지도 이미지·지도 타일은 포함하지 않는다. CSV/GeoJSON은 기획 참고용이며 실제 철도 운행·토목 설계 자료가 아니다.

## 파일

| 파일 | 내용 |
|---|---|
| `elevation_1km.csv` | `km,lat,lon,elev_m`, UTF-8, 헤더 뒤 313행 |
| `grades_1km.csv` | 앞뒤 km·고도·평균 경사 %·완전한 1km 여부 |
| `route.geojson`, `route_metadata.json` | 사용한 경로, 각 꼭짓점의 누적 거리, 방향별 edge ID, 경유역, 입력 SHA-256 |
| `railways_osm_5km.geojson` | 요청한 세 railway 태그의 OSM 선, 5km 띠로 절단 |
| `railways_ohm_5km.geojson` | OHM 역사 철도·궤도 기록, 5km 띠로 절단; 현재 소멸 여부 미확인 |
| `bridge_waterways.csv`, `bridge_waterways.geojson` | 교량 4곳의 물길 이름과 교량·물길 기하 |
| `evidence/` | 표고 API 응답, 교량 태그·평면 교차 근거 |
| `queries/` | 실행한 Overpass QL 원문 |
| `collection_manifest.json` | 결과 수량·극값, API 요청·응답 SHA-256·조회시각·DB 기준시각·실패 기록 |
| `collect.py`, `test_collect.py`, `requirements.txt` | 수집·로컬 재현·네트워크 없는 검증 |

GeoJSON 좌표는 WGS84 `[lon,lat]`, CSV는 요청대로 `lat,lon`이다. 이름·날짜가 없으면 JSON `null` 또는 CSV 빈칸이며 “없다”는 판정이 아니다. `length_km`는 **5km 띠 내부의 해당 way 길이**, `original_way_length_km`는 조회된 way 전체 길이다. 동일 way가 띠를 여러 번 드나들면 하나의 MultiLineString이 된다. 이는 여러 way를 합친 노선 길이가 아니다.

## 계산 방법

입력은 이 저장소의 `ref/rail/graph.json`과 `core.geojson`이다. 최초 조사 시 저장소 HEAD는 `868df7742bddbced18aff2f1c95f17118f159918`이며 입력 파일별 SHA-256은 `route_metadata.json`에 있다. 입력 검증용 `sha256`은 운영체제별 Git 체크아웃의 줄바꿈 차이를 없애기 위해 UTF-8 텍스트를 LF로 정규화한 값이다. 실제 수집 당시 파일 바이트의 해시는 `collected_worktree_raw_sha256`에 별도로 남긴다. API 응답 해시는 정규화하지 않은 원본 바이트 기준이다. 다음 호출의 결과만으로 경로를 정한다.

```python
route_from_graph.calculate_route(graph, ['wolsztyn', 'zbaszynek', 'cottbus', 'leipzig'])
```

`path`의 edge를 `forward` 방향대로 연결하고 공통 끝점과 노드 연속성을 검사한다. 그래프 거리 311,875.372m를 보존하기 위해 각 edge의 단순화된 선형에 원래 `length_m`를 길이 비례로 배분한다. 그 누적 거리의 1,000m 배수와 실제 종점에서 구면 측지선 보간한다. 구면 반지름은 원래 철도 수집 코드와 같은 6,371,008.8m다. 따라서 **1km는 그래프 거리 기준**이며 단순화된 선형을 별도로 잰 거리와 완전히 같지는 않다. 끝부분을 312km로 늘리지 않았다.

표고는 [OpenTopoData SRTM GL1 v3](https://www.opentopodata.org/datasets/srtm/) 공개 API `srtm30m`에 좌표를 80개씩 POST하여 읽었다. `interpolation=bilinear`, `nodata_value=null`. API 결과의 좌표·개수·데이터셋과 유한값을 검사한다. [API 문서](https://www.opentopodata.org/api/)에 따라 정수형 DEM의 보간 결과도 정수 미터로 반올림될 수 있다. 이 폴더는 전체 DEM 타일이 아니라 조회한 표고를 담는다.

경사 %는 `(뒤 표고−앞 표고) / (거리차 km × 1000) × 100`이다. 방향은 볼슈틴→라이프치히다. 가장 가파른 1km는 **절댓값 최대**로 고르고, 마지막 0.875372km는 제외한다. 최고·최저는 표본의 극값이지 점 사이까지 탐색한 연속 극값이 아니다. 6km 비교는 동일 좌표·표고 표본의 0,6,…,306km를 골라 다시 계산했다.

5km 띠는 EPSG:32633(UTM 33N)에서 선형을 5,000m 버퍼링한다. 원호 사분면당 64분할, 양 종점은 둥근 캡이다. 이 버퍼의 외접 사각형을 0.01도 넓혀 Overpass로 조회한 다음 Shapely로 **띠 안에 있는 선만 절단**한다. 길이는 WGS84 타원체 측지선으로 계산한다. 5km는 이 투영좌표계에서 정의한 값이며 정밀 측지선 오프셋과 같다고 보장하지 않는다. 25m 허용오차로 단순화된 입력 선형의 오차도 경계에 남는다.

OSM은 `railway=disused|abandoned|preserved`를 정확히 조회한다. `disused:railway=*` 같은 별도 생애주기 접두어만 있고 요청된 `railway` 값이 없는 선은 이번 범위 밖이다. OHM은 `railway` way를 조회하고 역·승강장 등 비선로 객체를 제외한다. 노면전차는 `railway=tram`으로 구별한다. 시간 필터를 걸지 않았고, `start_date`·`end_date`는 원래 문자열 그대로 둔다. OHM의 `status`는 현재 소멸을 확정하지 않는 역사 기록이라는 뜻이며 원래 상태는 `railway`·`tags`에 보존한다.

교량은 §4.1의 way ID에서 300m 내 물길 후보를 조회한 뒤, 실제로 교량 선을 가로지르는 물길의 `name`만 확인했다. 네 교량 모두 양의 교량 layer와 river 교차가 확인됐지만 물길의 layer는 미기록이다. 물리적 높이 측정이나 현장 조사는 하지 않았다.

OSM 추출 DB 기준시각은 **2026-10-07 03:49:11 UTC**, OHM은 **03:40:38 UTC**다. 경로 원본 그래프는 **2026-10-05 10:45:21 UTC** 데이터다. 조회일은 역사 철도의 운영 시점이나 SRTM 관측 시점과 다르다. 공개 지도에 미등록된 선, 잘못된 태그, 관계 객체에만 붙은 이름은 이 결과만으로 복원할 수 없다. OSM/OHM 간 중복 제거나 복선의 노선 단위 통합은 하지 않았다.

## 재현과 검증

Python 3.11 이상. 저장소 루트에서 실행한다.

```sh
python -m pip install -r ref/map/requirements.txt
python ref/map/collect.py
python -m unittest discover -s ref/map -p 'test_*.py' -v
python -m unittest discover -s ref/rail -p 'test_*.py' -v
```

`collect.py`는 결과 파일을 갱신한다. API는 순차 요청하고 요청 사이에 1.2초를 쉰다. 429는 우회하지 않는다. Overpass의 부분 응답·실행오류 `remark`, 표고 누락은 실패로 기록한다. 원시 응답은 `.cache/`에 저장하지만 커밋하지 않는다. 같은 캐시가 있는 작업 환경에서 `python ref/map/collect.py --offline`으로 네트워크 없이 재생성할 수 있다. **새 clone에는 캐시가 없으므로 완전한 오프라인 재수집은 불가능**하다. 다만 `test_collect.py`는 커밋된 자료만으로 경로 입력·좌표·표고·경사·절단 범위·길이·이름·라이선스·교량 교차를 검사한다. 새 온라인 수집은 OSM/OHM 수정으로 개수와 내용이 달라질 수 있다.

### 검증 기록

**[PASS]** 새 조사 데이터 검증은 **12/12 통과**했다. 캐시를 이용한 오프라인 재생성도 완료했다. 검증 환경은 Windows/Python 3.13, requests 2.34.2, Shapely 2.1.2, pyproj 3.8.0이다. OHM 응답의 구성 노드 22,333개를 대조했으며 누락된 way 노드 참조는 0개였다.

**[WATCH]** 수정하지 않은 기존 `ref/rail` 테스트는 이 Windows 환경에서 **36개 중 34개 통과, 실패 1개·오류 1개**였다. 두 항목은 `RouteCliTests.test_only_graph_and_script_support_all_real_data_modes`, `RouteCliTests.test_invalid_requests_return_nonzero_status`이며, 격리된 Python 하위 프로세스의 CP949 출력과 UTF-8 디코딩 문제다. 기존 CLI를 `-I -S -B`로 직접 실행하면 `cp949`가 저작권 문자 `©`를 인코딩하지 못해 종료 코드 2가 재현된다. 같은 명령에 **`-X utf8`**을 추가하면 종료 코드 0, 경로 길이 311,875.372m가 확인됐다. 이번 수집은 CLI 문자열이 아니라 Python 함수를 직접 호출하므로 영향을 받지 않는다. 자료 수집 범위를 지키기 위해 기존 철도 코드·테스트는 수정하지 않았다.

## 권리와 출처

**© OpenStreetMap contributors, ODbL.** OSM 기반 경로, 좌표, 교량·물길, 철도 추출과 이들을 이용한 파생 데이터 묶음은 [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)로 제공한다. [OSM 저작권 안내](https://www.openstreetmap.org/copyright). 이 조건은 게임 코드 전체의 라이선스를 지정하는 것이 아니다.

**OpenHistoricalMap 원천 데이터: CC0.** [OHM 저작권 안내](https://www.openhistoricalmap.org/copyright)의 기본 CC0와 개별 `license=*` 예외를 구분했다. 추출된 way와 그 구성 노드의 예외 태그를 검사하고, CC0/퍼블릭 도메인 이외의 명시적 라이선스는 제외하도록 했다. 이번에는 제외 0건이다. 공개 지도 기여자의 원출처 권리까지 독립적으로 감사한 것은 아니다. OHM 선을 **OSM 경로의 5km 경계로 골라 자른 이 파생 묶음은 보수적으로 ODbL로 배포**하며, `source_license=CC0`와 산출물 `license=ODbL`을 분리한다. OHM의 원래 데이터를 ODbL이라고 설명하지 않는다.

**SRTM 원천 표고: 퍼블릭 도메인, 사용 제한 없음.** [USGS SRTM 안내](https://www.usgs.gov/centers/eros/science/usgs-eros-archive-digital-elevation-shuttle-radar-topography-mission-srtm-1), [NASA SRTMGL1 v003](https://doi.org/10.5067/MEaSUREs/SRTM/SRTMGL1.003). OSM 선로에서 고른 좌표와 결합한 이 CSV 묶음은 위 ODbL 표기를 유지한다. SRTM을 현재의 정확한 지면·레일 표고로 해석하지 않는다.

AMS JPG는 [University of Texas Libraries 색인](https://maps.lib.utexas.edu/maps/ams/central_europe/)을 통해 로컬 폴더에만 받았다. UT 색인의 시리즈 표기는 **M641, U.S. Army Map Service, 1943**이다. 개별 도엽의 모든 측량·수정 연도가 1943년이라는 뜻은 아니다. 이미지 자체는 이 저장소에 포함하지 않았다.
