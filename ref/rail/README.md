# 핵심 지역 실제 철도망

폴란드 서부·독일 동부·체코·슈트랄준트·뤼겐의 철도망을 게임 설계에 참고하기 위한 OSM 파생 데이터다. 실제 열차 운행을 안내하는 자료가 아니다. 설계 문서와 S1 코드는 수정하지 않는다.

커밋된 기준 시각은 **2026-10-05 10:45:21 UTC**다. 주요 역 67곳(원본에서 화물 야드 표식이 확인된 5곳 포함), 그래프 노드 19,758개, 구간 27,873개를 수록했다. 약 199MB의 본선 원본에서 일반 선형 노드를 줄인 결과 `core.geojson`은 약 10.0MB, `graph.json`은 약 15.2MB다. 원본 본선은 91,747개 OSM way, 964,873개 선로 노드를 포함한다. 실제 OSM 선로·역 표식만 사용했다.

## 파일과 다시 만드는 명령

- `fetch.py`: Python 3.10 이상, 표준 라이브러리만 사용하는 수집·단순화·경로 계산·검사 스크립트.
- `core.geojson`: WGS84 경위도 순서 `[경도, 위도]`의 본선과 주요 역. 노선 Feature ID는 그래프 구간 ID와 같다.
- `graph.json`: 역의 선로 연결점·분기점·말단점, 구간 속성 및 계산된 경로. 역 목록은 `stations`, 실제 연결점은 `nodes`다.
- `routes.md`: 경로 후보의 총거리·구간 거리·경유역 및 원본 링크.
- `test_fetch.py`: 입체교차, 분기점, 속성 변경, 순환선, 복선 해석, 역 안의 연결에 대한 회귀 검사.

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
python3 -m unittest discover -s ref/rail -p test_fetch.py -v
```

원본 JSON과 수신 기록은 `ref/rail/.cache/`에 보관하며 `.gitignore`로 커밋에서 제외한다. 수집 범위의 원본은 수백 MB가 될 수 있고 메모리도 수 GB가 필요하다. 첫 수집은 공개 API 부하에 따라 몇 분 이상 걸릴 수 있다. 서버 장애는 최대 세 번 시도한 뒤 오류로 끝나며 불완전 응답을 결과로 사용하지 않는다. `--download-only`는 내려받기만 한다. `--output ref/rail/.cache/rebuilt`로 별도 출력하여 비교할 수 있다. 산출물의 식별자·정렬·거리 계산은 결정적이며 같은 캐시로 만든 두 JSON의 SHA-256이 같아야 한다. 새 수신은 수신 시각·질의·응답 해시가 달라질 수 있다.

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

`--check`는 고유 ID, 노드 참조, 양수 거리, 세부 구간 거리 합계, 좌표 범위, GeoJSON 끝점, 역 연결 반경, 경로의 연속성과 경유역 순서 및 거리 합계를 검사한다. `test_fetch.py`는 잘못된 입체교차 연결과 역 내 순간 이동을 반례로 검증한다. 경사 방향·복선 누락·속성 변경·순환선도 검사한다.

생성되는 `preview.local.html`은 본선과 경로·역을 보여 주는 외부 통신 없는 검토용 그림이며 커밋하지 않는다. 브라우저에서 열어 전체 범위와 뤼겐 연결을 볼 수 있다. 공식 철도 운행 지도와의 전 구간 대조, 신호·분기기의 운행 제약, 표고 기반 경사, 실제 화물/여객 운행 및 완전한 역 번역은 미확인이다.

드레스덴 프리드리히슈타트는 화물 거점 조사 대상으로 넣었으나, 선택 범위에서는 화물 야드 표식의 본선 연결을 확인하지 못해 **인근 여객역 표식만** 수록했다. `unconfirmed_freight_references`에 이를 따로 남겼다. 다른 다섯 화물 거점은 야드 표식이 확인됐지만 야드 내부선과 실제 화물 취급은 이 자료의 범위 밖이다. 지정 주요 역 67곳의 표식 및 근처 본선 연결점은 모두 확보했다.

## ODbL 출처 표기

`core.geojson`과 `graph.json`은 **OpenStreetMap의 파생 데이터베이스**이며 [Open Data Commons Open Database License 1.0 (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/)로 배포한다.

> © OpenStreetMap contributors. 데이터는 ODbL 1.0에 따라 제공됩니다.

[OSM 저작권·라이선스 안내](https://www.openstreetmap.org/copyright)와 [ODbL 전문](https://opendatacommons.org/licenses/odbl/1-0/)을 참고한다. 데이터 재배포와 수정 데이터베이스 배포에는 ODbL의 출처 표시·동일 라이선스 조건을 적용한다. 게임 지도 등으로 표시할 때도 이용자가 볼 수 있는 곳에 위 출처와 ODbL 안내를 남긴다. 파생 데이터베이스의 라이선스를 게임 코드 전체의 라이선스로 설명하지 않는다. OpenRailwayMap의 타일·스타일을 이 산출물에 포함하지 않았다.
