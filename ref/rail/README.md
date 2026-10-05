# 핵심 지역 실제 철도망

폴란드 서부·독일 동부·체코·슈트랄준트·뤼겐의 철도망을 게임 설계에 참고하기 위한 OSM 파생 데이터다. 실제 열차 운행을 안내하는 자료가 아니다. 설계 문서와 S1 코드는 수정하지 않는다.

커밋된 기준 시각은 **2026-10-05 10:45:21 UTC**다. 주요 역 67곳(원본에서 화물 야드 표식이 확인된 5곳 포함), 그래프 노드 19,758개, 구간 27,873개를 수록했다. 약 199MB의 본선 원본에서 일반 선형 노드를 줄인 결과 `core.geojson`은 약 10.0MB, `graph.json`은 약 15.2MB다. 원본 본선은 91,747개 OSM way, 964,873개 선로 노드를 포함한다. 실제 OSM 선로·역 표식만 사용했다.

## 파일과 다시 만드는 명령

- `fetch.py`: Python 3.10 이상, 표준 라이브러리만 사용하는 수집·단순화·경로 계산·검사 스크립트.
- `route_from_graph.py`: 커밋된 그래프만 읽는 독립 경로 계산기. `fetch.py`도 이 모듈의 같은 계산 함수를 사용한다.
- `core.geojson`: WGS84 경위도 순서 `[경도, 위도]`의 본선과 주요 역. 노선 Feature ID는 그래프 구간 ID와 같다.
- `graph.json`: 역의 선로 연결점·분기점·말단점, 구간 속성 및 계산된 경로. 역 목록은 `stations`, 실제 연결점은 `nodes`다.
- `routes.md`: 경로 후보의 총거리·구간 거리·경유역 및 원본 링크.
- `test_fetch.py`: 입체교차, 분기점, 속성 변경, 순환선, 복선 해석, 역 안의 연결에 대한 회귀 검사.
- `test_route_from_graph.py`: 역 간 연결성·경유 순서·전체 최단거리, 기존 네 경로와 새 첫 구간 두 경로, 원본 없는 독립 실행에 대한 회귀 검사.

저장소 루트에서 실행한다. 아래의 `python3`은 설치된 Python 3.10 이상 실행 파일로 바꿀 수 있다. Windows PowerShell에서는 실행 파일의 절대경로 앞에 `&`를 붙여 실행한다.

```sh
# 현재 데이터 내려받기 및 산출물 생성. 기존 캐시가 있으면 재사용한다.
python3 ref/rail/fetch.py

# 현재 데이터로 갱신. 네트워크 요청을 다시 한다.
python3 ref/rail/fetch.py --refresh

# 같은 원본 캐시로 산출물 다시 생성. 네트워크 요청 없음.
python3 ref/rail/fetch.py --offline

# 커밋된 기준 시각으로 다시 내려받기. 서버의 과거 데이터 지원이 필요하다.
python3 ref/rail/fetch.py --date 2026-10-05T10:45:21Z

# 커밋된 결과만 검사. 원본 캐시와 네트워크가 필요 없다.
python3 ref/rail/fetch.py --check
python3 -m unittest discover -s ref/rail -p 'test_*.py' -v
```

원본 JSON과 수신 기록은 `ref/rail/.cache/`에 보관하며 `.gitignore`로 커밋에서 제외한다. 수집 범위의 원본은 수백 MB가 될 수 있고 메모리도 수 GB가 필요하다. 첫 수집은 공개 API 부하에 따라 몇 분 이상 걸릴 수 있다. 서버 장애는 최대 세 번 시도한 뒤 오류로 끝나며 불완전 응답을 결과로 사용하지 않는다. `--download-only`는 내려받기만 한다. `--output ref/rail/.cache/rebuilt`로 별도 출력하여 비교할 수 있다. 산출물의 식별자·정렬·거리 계산은 결정적이며 같은 캐시로 만든 두 JSON의 SHA-256이 같아야 한다. 새 수신은 수신 시각·질의·응답 해시가 달라질 수 있다.

`core.geojson`과 `graph.json`에는 `text eol=lf`, `-diff`, `linguist-generated=true`를 적용했다. 기준 시각을 바꾸는 별도 갱신 때만 데이터를 다시 만든다. 아래 경로 계산과 검사는 두 데이터 파일을 수정하지 않는다.

## 원본 없는 경로 계산

`route_from_graph.py`와 `graph.json` 두 파일만 있어도 실행된다. Python 3.10 이상 표준 라이브러리만 쓰며 `fetch.py`, `core.geojson`, 원본 캐시, 네트워크가 필요 없다. 입력은 역 ID를 출발역부터 도착역까지 순서대로 나열한다.

```sh
# 역 ID와 저장된 한글·원어 이름 확인
python3 ref/rail/route_from_graph.py --list-stations

# 두 역 사이 최단 경로
python3 ref/rail/route_from_graph.py wolsztyn leipzig

# 첫 구간 기본: 즈봉시네크·코트부스 직결선
python3 ref/rail/route_from_graph.py wolsztyn zbaszynek cottbus leipzig

# 포즈난을 들르지 않는 오데르·베를린 경유 경로
python3 ref/rail/route_from_graph.py wolsztyn zbaszynek rzepin frankfurt berlin leipzig

# 기존 포즈난 우회 경로를 저장된 역 목록으로 새로 계산
python3 ref/rail/route_from_graph.py --route west_via_berlin

# 기존 네 경로의 거리·시종점·선로 ID/방향·경유점이 저장값과 같은지 대조
python3 ref/rail/route_from_graph.py --check

# 다른 위치의 그래프로 계산하고 상세 결과를 JSON으로 출력
python3 ref/rail/route_from_graph.py --graph ref/rail/graph.json wolsztyn zbaszynek cottbus leipzig --json
```

거리는 `edges.length_m`의 합계이며 JSON의 `length_m`와 경유점 누적거리는 m 단위 소수 셋째 자리다. `path`에는 구간 ID와 정·역방향, `waypoints`에는 실제 선로 노드와 누적거리를 반환한다. JSON 출력에는 기준 시각·출처 표시·라이선스도 포함한다. 경로가 확인되거나 저장값 대조가 모두 맞으면 종료 코드 0, 연결 미확인 또는 대조 불일치는 1, 잘못된 입력·파일 오류는 2다. 계산 함수의 `connected`는 그래프의 선로 연결 상태이며 실제 열차 운행 가능 판정이 아니다.

전체 경로를 `(선로 노드, 통과한 경유역 수)` 상태로 한 번에 탐색한다. 중간 역에 도착해도 현재 선로 노드는 그대로 유지한다. 역 쌍마다 따로 구한 최단거리를 더하지 않으며, 구간 거리는 전체 경로의 누적거리 차이로 읽는다. 같은 두 역 사이도 이후 경유역에 따라 다른 연결점을 선택할 수 있다. [첫 구간 결정](../../docs/design/decisions.md)에 따른 추가 두 경로와 기존 네 경로의 재계산값은 [routes.md](routes.md)에 있다. 추가 경로는 문서에만 수록하고 `graph.json.routes`의 기존 네 경로는 보존했다.

## 출처와 범위

원천은 [OpenStreetMap](https://www.openstreetmap.org/)이며 [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API)의 `https://overpass-api.de/api/interpreter`에서 조회한다. [OpenRailwayMap](https://wiki.openstreetmap.org/wiki/OpenRailwayMap)은 OSM 철도 태그를 표시하는 지도이므로 별도의 독립된 철도 데이터베이스로 합치지 않았다. 타일·이미지·지도 스타일은 수집하지 않았다.

사각 범위는 **북위 48.45~54.8°, 동경 10.7~19.0°**다. 체코 전역과 서부 폴란드·동부 독일 및 뤼겐을 포함하도록 잡았다. 행정 경계로 자르지 않아 주변 오스트리아·독일 중부·폴란드 중부의 일부도 포함한다. 범위 안의 점을 갖는 OSM way는 전체 노드를 받으므로 경계 밖으로 조금 이어질 수 있다. 범위 밖 연결은 미완성이다.

`graph.json.source`에는 API 주소, 실제 질의, 요청/질의/응답 SHA-256, 요청/응답 바이트 수, 수신 시각과 OSM 기준 시각을 남긴다. `server_osm_base`는 서버 최신 데이터 시각, `requested_snapshot`은 요청한 과거 시각, `osm_base`는 산출물에 실제 적용한 기준 시각이다. 추가 화물 야드 질의는 본선과 같은 기준 시각에 거점 이름으로 조회하고 `supplemental_sources`에 별도 수신 기록을 남긴다. 수신 날짜와 OSM 데이터 기준 시각을 구분한다.

## 단순화 기준

1. 현재 OSM에서 `railway=rail`인 선로를 사용한다. `service=yard|siding|spur`인 야드 내부선·측선·인입선은 제외하고 실제 본선 사이 연결에 필요한 `crossover`는 유지한다. `railway=preserved|disused|abandoned|construction`과 지하철·노면전차·경전철은 제외한다. 박물관 증기기관차의 본선 운행 여부는 이 필터와 별개의 문제다.
2. 여객·화물 주요 역은 `STATION_SPECS`의 지역 거점과 지정 경로의 역만 남긴다. 선별 목록은 스크립트에 공개한다. 일반 정차장·승강장·소규모 역 전체를 나열하지 않는다. 정확한 OSM 역 이름으로 선택하며 역의 원어명·좌표·객체 ID·출처 링크는 원본에서 가져온다. 선택 실패는 `unconfirmed_stations`에 한국어 이유를 남긴다.
3. 역 표식마다 350m 이내의 각 본선 way에서 가장 가까운 **실제 OSM 선로 노드**를 연결점으로 선택한다. 표식 좌표는 이동시키지 않는다. 한 역의 연결점은 여러 개일 수 있다. 역 이름이 같다는 이유로 연결점을 합치거나 가상 선로를 만들지 않는다. 350m는 대형 역의 여러 승강장을 포함하기 위한 근사 기준이며, 운행 가능 승강장은 미확인이다.
4. 공유 OSM 노드에서 선로 차수가 3 이상인 곳과 명시된 `railway=junction`은 분기점으로 남긴다. 단순 차수 2 노드는 제거하되 속성 변경과 원본 way ID는 구간의 `segments`에 남긴다. 차수 1의 말단점과 분기점 없는 순환선의 기준점도 연결성 보존을 위해 남긴다. 교량·터널의 평면상 교차를 접속으로 바꾸지 않는다.
5. 선형은 Douglas–Peucker의 투영 좌표상 25m 허용치로 줄인다. 위도 51.6° 기준의 고정 구면 투영을 쓰므로 지역 가장자리에서는 실제 미터 오차가 약간 다르다. 노드·구간 끝점은 보존한다. 거리는 **단순화 전 좌표**에 지구 평균 반지름 6,371,008.8m를 적용한 haversine 합계다. 지형에 따른 3차원 거리와 공식 영업거리는 미확인이다.

## 그래프와 속성 해석

`edges`는 무방향 연결이다. `from/to`는 저장 순서이며 통행 방향이나 열차의 방향 전환 가능성을 뜻하지 않는다. `segments`는 `from → to` 순서다. 노선의 서로 다른 궤간을 변환 없이 통과할 수 있다는 뜻도 아니다.

| 필드 | 뜻과 누락 처리 |
|---|---|
| `length_m` | 단순화 전 선로 길이(m), 소수 셋째 자리. 원본 way별 구간 합계도 보관한다. |
| `electrified` | [`electrified`](https://wiki.openstreetmap.org/wiki/Key:electrified) 원본 값: `contact_line`, `rail`, `yes`, `no` 등. 전압·주파수는 세부 구간에 보관한다. |
| `gauge_mm` | [`gauge`](https://wiki.openstreetmap.org/wiki/Key:gauge) 숫자 태그를 mm 배열로 읽는다. 복수 궤간은 세미콜론을 분리한다. |
| `double_track` | [`tracks`](https://wiki.openstreetmap.org/wiki/Key:tracks)가 2 이상이면 `true`. 별도 way로 표현된 복선이 많으므로 `tracks=1`이나 누락을 `false`로 판정하지 않고 `null`(미확인)로 둔다. 평행 선로 기하로 복선을 추정하지 않는다. |
| `incline_percent` | [`incline`](https://wiki.openstreetmap.org/wiki/Key:incline)가 `%` 또는 `°` 숫자일 때만 백분율로 읽는다. `from → to` 방향의 부호이며 반대 방향에서는 부호가 바뀐다. `up/down`과 누락은 `null`. 표고 모델은 사용하지 않았다. |
| `segments` | `osm_way_id`, 길이, `attribute_id`. 속성은 `attribute_profiles[attribute_id]`에서 읽는다. OSM 링크는 `https://www.openstreetmap.org/way/{osm_way_id}`로 다시 열 수 있다. `bridge/tunnel/layer/service/ref/name_original/bridge_name_original`도 보관한다. 반복 속성을 공유해 파일 크기를 줄인다. |

세부 구간의 값이 서로 다르면 상위 구간 속성은 `null`이다. 세부 값과 길이를 읽어야 전철화 비중이나 구간별 경사를 알 수 있다. `null`과 속성 프로필의 생략된 필드는 음성 판정이 아니라 **미확인 또는 혼합**이며 OSM 기록이 없는 값을 지리 상식으로 채우지 않는다. `kind=freight_station`은 OSM의 `railway=yard` 또는 `station=freight|yard`를 근거로 한다. `freight_reference`는 선별 목록에서 화물 거점으로 조사한 대상이라는 뜻이다. 원본 표식 태그는 `marker_tags`에 보관한다. 여객역에 화물 기능이 없는지와 실제 취급 규모는 확인하지 않았다.

경로 계산은 모든 지정 경유역을 순서대로 지나는 그래프 위의 최단 거리 탐색이다. 역의 여러 연결점 중에서 연속된 실제 선로로 도달 가능한 것을 고르며, 중간 역에서 다른 선로로 순간 이동하지 않는다. 구간 ID와 정방향/역방향, 경유역의 실제 노드와 누적 거리를 `graph.json.routes`에 남겨 추적할 수 있다. 상세 경로는 [routes.md](routes.md)에 있다.

## 검사와 시각 검토

`fetch.py --check`는 고유 ID, 노드 참조, 양수 거리, 세부 구간 거리 합계, 좌표 범위, GeoJSON 끝점, 역 연결 반경, 경로의 연속성과 경유역 순서 및 거리 합계를 검사한다. 궤간은 모든 세부 구간의 속성 프로필을 검사하며, 집계 궤간이 `null`인 혼합 구간도 빠뜨리지 않는다. 검토 기준은 **600·750·760·900·1000·1435·1520mm**다. 이 지역 데이터와 요청된 궤간을 위한 기준이며 세계의 모든 유효 궤간 목록은 아니다. 기준 밖 값은 `[WATCH]`와 구간 ID·OSM way·출처 URL로 보고하고, 구조 검사가 통과하면 경고가 있어도 종료 코드 0으로 끝난다. 알려진 복수 궤간과 누락값은 이상값으로 세지 않는다.

`route_from_graph.py --check`는 저장된 거리나 선로 목록을 계산 입력으로 쓰지 않고, 역 목록에서 네 경로를 다시 탐색해 대조한다. `test_fetch.py`는 입체교차·역 내 순간 이동·궤간 경고의 반례를 검사한다. `test_route_from_graph.py`는 전체 최단거리와 경유 순서를 검사하며, 두 파일만 복사한 임시 디렉터리에서 경로 계산기를 실행해 원본·GeoJSON·수집 코드 비의존성을 확인한다.

생성되는 `preview.local.html`은 본선과 경로·역을 보여 주는 외부 통신 없는 검토용 그림이며 커밋하지 않는다. 브라우저에서 열어 전체 범위와 뤼겐 연결을 볼 수 있다. 공식 철도 운행 지도와의 전 구간 대조, 신호·분기기의 운행 제약, 표고 기반 경사, 실제 화물/여객 운행 및 완전한 역 번역은 미확인이다.

드레스덴 프리드리히슈타트는 화물 거점 조사 대상으로 넣었으나, 선택 범위에서는 화물 야드 표식의 본선 연결을 확인하지 못해 **인근 여객역 표식만** 수록했다. `unconfirmed_freight_references`에 이를 따로 남겼다. 다른 다섯 화물 거점은 야드 표식이 확인됐지만 야드 내부선과 실제 화물 취급은 이 자료의 범위 밖이다. 지정 주요 역 67곳의 표식 및 근처 본선 연결점은 모두 확보했다.

## 남은 문제

### 궤간 이상값 1건

2026-10-05 10:45:21 UTC 데이터에서 위 검토 기준 밖 값은 다음 한 건이다. [OSM gauge 태그](https://wiki.openstreetmap.org/wiki/Key:gauge)를 그대로 읽은 값이며, 실제 궤간과 태그 오류 여부는 **미확인**이다. 원본 이름만으로 일반 열차용 선로인지 확정하지 않는다. 값을 수정하거나 구간을 삭제하지 않았다.

| 구간 ID | 궤간 | 수록 길이 | 속성 프로필 | 원본 이름 | 출처 |
|---|---:|---:|---|---|---|
| `e025293` | 6000mm | 128.892m | `a04774` | Leipziger Auwaldkran | [OSM way 543311049](https://www.openstreetmap.org/way/543311049) |

### 협궤 수록 범위

750mm는 알려진 궤간이므로 수치 이상 경고와 구분한다. 현재 수집 조건은 `railway=rail`과 `service` 태그에 따른 것으로, 궤간 수치 자체를 제외 조건으로 삼지 않는다. 따라서 **750mm 단독 구간 6개, 서로 다른 원본 way 5개, 총 418.383m**가 남아 있다. 각 수치는 커밋된 그래프에서 읽은 선로 길이다.

| 구간 ID | 수록 길이 | 출처 |
|---|---:|---|
| `e006988` | 46.851m | [OSM way 84974327](https://www.openstreetmap.org/way/84974327) |
| `e006989` | 220.589m | [OSM way 84974327](https://www.openstreetmap.org/way/84974327) |
| `e019796` | 13.538m | [OSM way 283921897](https://www.openstreetmap.org/way/283921897) |
| `e026013` | 59.924m | [OSM way 828214914](https://www.openstreetmap.org/way/828214914) |
| `e027824` | 41.615m | [OSM way 1537562528](https://www.openstreetmap.org/way/1537562528) |
| `e027825` | 35.866m | [OSM way 1537738704](https://www.openstreetmap.org/way/1537738704) |

이 밖에 750·1435mm 복수 궤간으로 기록된 세부 구간 8개(합계 5,928.483m)도 있다. `e002507`에 [178068082](https://www.openstreetmap.org/way/178068082), [30748715](https://www.openstreetmap.org/way/30748715), [1354765963](https://www.openstreetmap.org/way/1354765963), [30748718](https://www.openstreetmap.org/way/30748718), [1354765962](https://www.openstreetmap.org/way/1354765962), [29363118](https://www.openstreetmap.org/way/29363118)의 여섯 세부 구간, `e013474`에 [1115019732](https://www.openstreetmap.org/way/1115019732), [394092402](https://www.openstreetmap.org/way/394092402)의 두 세부 구간이 포함된다. 두 상위 구간의 집계 궤간은 모두 `null`이다. 일반 철도망의 수록 대상으로 적절한지와 실제 통과 가능성은 미확인이다.

- 볼슈틴–즈봉시네크 직결선의 **현재 여객 열차 운행 여부는 미확인**이다. 경로 계산은 저장된 OSM 선로의 기하 연결을 확인한 것이다.
- 경로 계산기는 궤간 호환성, 진행 방향, 신호·분기기 제약이나 방향 전환 가능성을 판정하지 않는다. 궤간 검사 경고를 통과 허가로 해석하지 않는다.

## ODbL 출처 표기

`core.geojson`과 `graph.json`은 **OpenStreetMap의 파생 데이터베이스**이며 [Open Data Commons Open Database License 1.0 (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/)로 배포한다.

> © OpenStreetMap contributors. 데이터는 ODbL 1.0에 따라 제공됩니다.

[OSM 저작권·라이선스 안내](https://www.openstreetmap.org/copyright)와 [ODbL 전문](https://opendatacommons.org/licenses/odbl/1-0/)을 참고한다. 데이터 재배포와 수정 데이터베이스 배포에는 ODbL의 출처 표시·동일 라이선스 조건을 적용한다. 게임 지도 등으로 표시할 때도 이용자가 볼 수 있는 곳에 위 출처와 ODbL 안내를 남긴다. 파생 데이터베이스의 라이선스를 게임 코드 전체의 라이선스로 설명하지 않는다. OpenRailwayMap의 타일·스타일을 이 산출물에 포함하지 않았다.
