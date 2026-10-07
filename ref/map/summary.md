# 첫 구간 지도 조사 — 2026-10-07

볼슈틴 → 즈봉시네크 → 코트부스 → 라이프치히. 지정한 `calculate_route`로 다시 계산한 거리는 **311.875372km**다. 원본 문서: [지도 참고 §4](../map_references.md). 계산·조회 근거는 [수집 기록](collection_manifest.json), [재현 방법](README.md)에 있다.

## [PASS] 받은 자료

AMS M641 1:100,000 지도 6장은 [텍사스대 색인](https://maps.lib.utexas.edu/maps/ams/central_europe/)에서 요청한 이름·도엽 번호를 확인한 뒤 지정된 바탕화면 폴더에만 저장했다. JPEG 검사와 SHA-256 기록을 마쳤다. 이미지·색인 그림·다운로드 캐시는 이 저장소에 넣지 않았다. 파일명과 바이트 크기는 PR 본문에 기록한다.

[고도 CSV](elevation_1km.csv)는 0~311km의 정수 지점과 실제 종점 311.875372km를 합친 **313행**이다. 열은 `km,lat,lon,elev_m`, 고도 누락은 없다. [경사 CSV](grades_1km.csv)는 311개의 완전한 1km 구간과 마지막 0.875372km 구간을 구분한다.

## [WATCH] 기존 §4.2와 다른 점

| 항목 | 기존 6km 간격 문서 | 이번 1km 간격 표본 |
|---|---|---|
| 최고 표고 | 198km, 134m | **197km, 139m** (51.6937387, 13.8615077) |
| 최저 표고 | 96km, 38m | **94·96km, 모두 39m** |
| 가장 가파른 상승 | 186→192km, +46m/6km, 약 0.8% | **129→130km, 49→67m, +1.8%** |
| 가장 가파른 하강 | 별도 표기 없음 | **174→175km, 86→71m, −1.5%** |

이번 값을 다시 6km 간격으로 고르면 최고 134m/198km와 186→192km의 **+46m, 0.766667%**가 재현된다. 따라서 기존 0.8%가 계산 오류인 것은 아니다. 최저 38m와 39m의 1m 차이는 남는다. 기존 조회의 정확한 좌표·보간 설정·응답 원본이 없어 원인을 확정하지 않았다.

위 최고·최저는 **표본 지점 중 극값**, 경사는 **DEM 표면 높이 차의 구간 평균**이다. 선로의 실제 종단 경사나 열차 견인 한계로 사용하면 안 된다. SRTM 표면 영향과 선형 단순화 오차 때문에 “첫 구간 실제 철도에 1.8% 구배가 있다”는 결론은 미확인이다.

## [PASS] 양옆 5km 철도

| 데이터 | 선 객체 수 | 잘라낸 선 길이 합계 | 구성 |
|---|---:|---:|---|
| [OSM](railways_osm_5km.geojson) | **2,633 ways** | **608.247140km** | abandoned 1,632 / disused 1,001 / preserved 0 |
| [OpenHistoricalMap](railways_ohm_5km.geojson) | **467 ways** | **522.003871km** | rail 269 / tram 183 / disused 7 / abandoned 4 / narrow_gauge 3 / razed 1 |

현재 태그가 요청한 값인 OSM 선과 OHM의 역사 철도 기록을 **서로 다른 파일**로 보존했다. 수치는 노선 수가 아니라 분할된 way 수다. 복선·시대별 중복을 합치지 않았으므로 두 길이 합계를 더해 폐선 총연장으로 부를 수 없다. OHM 선을 모두 “현재 사라진 선”으로 판정하지 않았다. `preserved=0`도 보존철도 부재를 입증하지 않는다.

## [PASS] ‘유력’ 교량 4곳의 물길 이름

| 문서 km | 교량 way | 교차하는 waterway way | 확인된 name |
|---:|---|---|---|
| 21.5 | [318584357](https://www.openstreetmap.org/way/318584357) | [24769175](https://www.openstreetmap.org/way/24769175) | **Obra** |
| 96 | [801395051](https://www.openstreetmap.org/way/801395051) | [801855025](https://www.openstreetmap.org/way/801855025) | **Bóbr** |
| 162 | [116512069](https://www.openstreetmap.org/way/116512069) | [117860615](https://www.openstreetmap.org/way/117860615) | **Spree** |
| 236 | [33775391](https://www.openstreetmap.org/way/33775391) | [22990464](https://www.openstreetmap.org/way/22990464) | **Schwarze Elster** — Kleine Elster가 아님 |

네 교량 모두 `railway=rail`, `bridge=yes`, `layer=1`이며, 이름 있는 `waterway=river` 선과 실제 평면 교차한다. 단순히 가까운 강을 고른 결과가 아니다. 물길의 `layer` 자체는 네 곳 모두 미기록이다. [교차 근거](evidence/bridge_matches.json), [CSV](bridge_waterways.csv), [GeoJSON](bridge_waterways.geojson).

## [WATCH] 확인하지 못한 것과 권리

이름 태그가 없는 **OSM 2,389개, OHM 428개 way**는 `name=null`로 남겼다. 관계 객체의 노선명을 임의로 옮기거나 이름을 만들지 않았다. 실제 폐선 연도·현장 상태·실제 철도 구배·지도 미등록 노선의 완전성은 이 조회로 확인할 수 없다. 요청한 API 조회와 파일 생성에서 실패한 작업은 없다.

**© OpenStreetMap contributors, ODbL. OpenHistoricalMap 원천 데이터는 CC0. SRTM 원천 표고는 퍼블릭 도메인으로 사용 제한 없음.** OHM 개별 way와 구성 노드의 `license` 예외를 검사했으며 이번 추출에서 제외할 예외는 없었다. OSM에서 얻은 경로·절단 경계를 사용하는 이 폴더의 파생 데이터 묶음은 ODbL로 배포한다. OHM·SRTM 원천 데이터의 권리까지 ODbL로 바뀐다는 뜻은 아니다. [권리와 출처](README.md#권리와-출처).
