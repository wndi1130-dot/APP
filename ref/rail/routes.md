# 실제 철도망 경로 후보

OSM 기준 시각: `2026-10-05T10:45:21Z`. 출처: [OpenStreetMap](https://www.openstreetmap.org/copyright), [OpenRailwayMap](https://www.openrailwaymap.org/).

거리는 단순화 전 OSM 선로 중심선의 구면 거리 합계다. 지정된 역을 순서대로 지나는 무방향 최단 경로이며, 운행표·운행 허가·화물열차 통과 가능성·열차의 방향 전환 가능성은 미확인이다. 역 표식과 실제 선로의 연결점 차이는 최대 350m다. 역 안의 선로 사이에 가상의 연결은 넣지 않았다.

뤼겐 둑길 경유는 슈트랄준트 뤼겐담역에서 베르겐으로 이어지는 실제 선로의 다리 구간으로 확인한다. 도로 전용 뤼겐교는 경로에 넣지 않는다.

## 첫 구간 기본: 즈봉시네크·코트부스 직결선

[첫 구간 결정](../../docs/design/decisions.md)에 따른 기본 경로다. 볼슈틴 → 즈봉시네크 → 코트부스 중앙역 → 라이프치히 중앙역을 순서대로 지난다.

총 **311.9km**(정확한 계산값 **311,875.372m**). 문서용 경로 ID: `first_leg_direct`.

```sh
python3 ref/rail/route_from_graph.py wolsztyn zbaszynek cottbus leipzig
```

| 구간 | 거리 | 누적 거리 |
|---|---:|---:|
| 볼슈틴 → 즈봉시네크 | 28.424km | 28.424km |
| 즈봉시네크 → 코트부스 중앙역 | 134.900km | 163.324km |
| 코트부스 중앙역 → 라이프치히 중앙역 | 148.551km | 311.875km |

### 경유역 원본

- [볼슈틴 (Wolsztyn)](https://www.openstreetmap.org/node/469291096)
- [즈봉시네크 (Zbąszynek)](https://www.openstreetmap.org/node/2843454031)
- [코트부스 중앙역 (Cottbus Hauptbahnhof / Chóśebuz głowne dwórnišćo)](https://www.openstreetmap.org/node/2599505466)
- [라이프치히 중앙역 (Leipzig Hauptbahnhof)](https://www.openstreetmap.org/node/376142577)

결정 문서의 ‘코트부스’는 그래프의 `cottbus`와 같은 역이며, 저장된 한글 이름은 ‘콧부스 중앙역’이다. 볼슈틴–즈봉시네크 직결선에 **현재 여객 열차가 다니는지는 미확인**이다.

## 첫 구간 비교: 포즈난을 들르지 않는 오데르·베를린 경유

볼슈틴 → 즈봉시네크 → 제핀 → 프랑크푸르트 오데르 → 베를린 중앙역 → 라이프치히 중앙역

총 **383.7km**(정확한 계산값 **383,745.771m**). 문서용 경로 ID: `first_leg_via_berlin`. 위 직결선 기본 경로보다 71,870.399m 길다.

```sh
python3 ref/rail/route_from_graph.py wolsztyn zbaszynek rzepin frankfurt berlin leipzig
```

| 구간 | 거리 | 누적 거리 |
|---|---:|---:|
| 볼슈틴 → 즈봉시네크 | 28.266km | 28.266km |
| 즈봉시네크 → 제핀 | 75.291km | 103.556km |
| 제핀 → 프랑크푸르트 오데르 | 21.216km | 124.772km |
| 프랑크푸르트 오데르 → 베를린 중앙역 | 90.862km | 215.634km |
| 베를린 중앙역 → 라이프치히 중앙역 | 168.112km | 383.746km |

### 경유역 원본

- [볼슈틴 (Wolsztyn)](https://www.openstreetmap.org/node/469291096)
- [즈봉시네크 (Zbąszynek)](https://www.openstreetmap.org/node/2843454031)
- [제핀 (Rzepin)](https://www.openstreetmap.org/node/3258261975)
- [프랑크푸르트 오데르 (Frankfurt (Oder))](https://www.openstreetmap.org/node/321555238)
- [베를린 중앙역 (Berlin Hauptbahnhof)](https://www.openstreetmap.org/node/3856100103)
- [라이프치히 중앙역 (Leipzig Hauptbahnhof)](https://www.openstreetmap.org/node/376142577)

두 추가 경로는 `graph.json`의 기존 `stations`와 `edges`에서 새로 계산한 것이며, `graph.json.routes`에는 추가하지 않았다. 문서용 ID는 `--route`의 입력값이 아니므로 위 역 ID 명령으로 재현한다.

구간 거리는 **전체 경로의 경유점 누적거리 차이**다. 볼슈틴 → 즈봉시네크는 후속 경로에 따라 같은 역의 다른 연결점에 도착해 28,424.268m와 28,265.799m로 다르다. 중간 역에서 다른 선로로 순간 이동하지 않는 조건에서 생기는 차이이며, 역 쌍별 최단거리 합계로 바꾸지 않는다. 표의 km 값은 반올림하므로 표시된 구간값 합과 누적값이 조금 다를 수 있다.

## 우회 선택지: 포즈난·오데르·베를린 경유

볼슈틴 → 포즈난 중앙역 → 즈봉시네크 → 제핀 → 프랑크푸르트 오데르 → 베를린 중앙역 → 라이프치히 중앙역

총 **514.7km**. 그래프 경로 ID: `west_via_berlin`.

| 구간 | 거리 | 누적 거리 |
|---|---:|---:|
| 볼슈틴 → 포즈난 중앙역 | 79.3km | 79.3km |
| 포즈난 중앙역 → 즈봉시네크 | 79.9km | 159.3km |
| 즈봉시네크 → 제핀 | 75.3km | 234.6km |
| 제핀 → 프랑크푸르트 오데르 | 21.2km | 255.8km |
| 프랑크푸르트 오데르 → 베를린 중앙역 | 90.9km | 346.6km |
| 베를린 중앙역 → 라이프치히 중앙역 | 168.1km | 514.7km |

### 경유역 원본

- [볼슈틴 (Wolsztyn)](https://www.openstreetmap.org/node/469291096)
- [포즈난 중앙역 (Poznań Główny)](https://www.openstreetmap.org/node/646734838)
- [즈봉시네크 (Zbąszynek)](https://www.openstreetmap.org/node/2843454031)
- [제핀 (Rzepin)](https://www.openstreetmap.org/node/3258261975)
- [프랑크푸르트 오데르 (Frankfurt (Oder))](https://www.openstreetmap.org/node/321555238)
- [베를린 중앙역 (Berlin Hauptbahnhof)](https://www.openstreetmap.org/node/3856100103)
- [라이프치히 중앙역 (Leipzig Hauptbahnhof)](https://www.openstreetmap.org/node/376142577)

## 우회 선택지: 포즈난·브로츠와프·드레스덴 경유

볼슈틴 → 포즈난 중앙역 → 레슈노 → 브로츠와프 중앙역 → 레그니차 → 벵글리니에츠 → 괴를리츠 → 드레스덴 중앙역 → 라이프치히 중앙역

총 **628.0km**. 그래프 경로 ID: `west_via_dresden`.

| 구간 | 거리 | 누적 거리 |
|---|---:|---:|
| 볼슈틴 → 포즈난 중앙역 | 79.3km | 79.3km |
| 포즈난 중앙역 → 레슈노 | 67.9km | 147.3km |
| 레슈노 → 브로츠와프 중앙역 | 95.8km | 243.1km |
| 브로츠와프 중앙역 → 레그니차 | 64.1km | 307.1km |
| 레그니차 → 벵글리니에츠 | 70.9km | 378.0km |
| 벵글리니에츠 → 괴를리츠 | 28.4km | 406.4km |
| 괴를리츠 → 드레스덴 중앙역 | 105.6km | 512.0km |
| 드레스덴 중앙역 → 라이프치히 중앙역 | 116.0km | 628.0km |

### 경유역 원본

- [볼슈틴 (Wolsztyn)](https://www.openstreetmap.org/node/469291096)
- [포즈난 중앙역 (Poznań Główny)](https://www.openstreetmap.org/node/646734838)
- [레슈노 (Leszno)](https://www.openstreetmap.org/node/618850607)
- [브로츠와프 중앙역 (Wrocław Główny)](https://www.openstreetmap.org/node/155479759)
- [레그니차 (Legnica)](https://www.openstreetmap.org/node/2627870779)
- [벵글리니에츠 (Węgliniec)](https://www.openstreetmap.org/node/410697138)
- [괴를리츠 (Görlitz)](https://www.openstreetmap.org/node/1438696887)
- [드레스덴 중앙역 (Dresden Hbf)](https://www.openstreetmap.org/node/25397500)
- [라이프치히 중앙역 (Leipzig Hauptbahnhof)](https://www.openstreetmap.org/node/376142577)

## 라이프치히에서 자스니츠: 베를린·뤼겐 둑길 경유

라이프치히 중앙역 → 베를린 중앙역 → 슈트랄준트 중앙역 → 슈트랄준트 뤼겐담역 → 베르겐 아우프 뤼겐 → 리초 → 자스니츠

총 **449.5km**. 그래프 경로 ID: `north_to_sassnitz`.

| 구간 | 거리 | 누적 거리 |
|---|---:|---:|
| 라이프치히 중앙역 → 베를린 중앙역 | 167.5km | 167.5km |
| 베를린 중앙역 → 슈트랄준트 중앙역 | 230.9km | 398.5km |
| 슈트랄준트 중앙역 → 슈트랄준트 뤼겐담역 | 3.7km | 402.1km |
| 슈트랄준트 뤼겐담역 → 베르겐 아우프 뤼겐 | 25.7km | 427.8km |
| 베르겐 아우프 뤼겐 → 리초 | 9.4km | 437.2km |
| 리초 → 자스니츠 | 12.4km | 449.5km |

### 경유역 원본

- [라이프치히 중앙역 (Leipzig Hauptbahnhof)](https://www.openstreetmap.org/node/376142577)
- [베를린 중앙역 (Berlin Hauptbahnhof)](https://www.openstreetmap.org/node/3856100103)
- [슈트랄준트 중앙역 (Stralsund Hbf)](https://www.openstreetmap.org/node/277350630)
- [슈트랄준트 뤼겐담역 (Stralsund Rügendamm)](https://www.openstreetmap.org/node/4267863816)
- [베르겐 아우프 뤼겐 (Bergen auf Rügen)](https://www.openstreetmap.org/node/4268035708)
- [리초 (Lietzow (Rügen))](https://www.openstreetmap.org/node/343805839)
- [자스니츠 (Sassnitz)](https://www.openstreetmap.org/node/4244819966)

### 뤼겐 둑길 통과 근거

계산된 경로에 아래 철도 교량의 실제 OSM way가 포함된다. 둑길 전체 길이가 아니라 이름이 기록된 교량 부분의 선로 길이만 나열한다.

- [Ziegelgrabenbrücke · OSM way 26398898](https://www.openstreetmap.org/way/26398898): 58.6m
- [Ziegelgrabenbrücke · OSM way 1109547240](https://www.openstreetmap.org/way/1109547240): 28.2m
- [Ziegelgrabenbrücke · OSM way 1109547239](https://www.openstreetmap.org/way/1109547239): 54.5m
- [Rügendammbrücke · OSM way 25877054](https://www.openstreetmap.org/way/25877054): 558.0m

## 체코 간선: 데친·프라하·브르노·오스트라바

데친 중앙역 → 프라하 중앙역 → 파르두비체 중앙역 → 체스카트르제보바 → 브르노 중앙역 → 프르제로프 → 오스트라바 중앙역

총 **550.6km**. 그래프 경로 ID: `czech_corridor`.

| 구간 | 거리 | 누적 거리 |
|---|---:|---:|
| 데친 중앙역 → 프라하 중앙역 | 133.5km | 133.5km |
| 프라하 중앙역 → 파르두비체 중앙역 | 103.1km | 236.7km |
| 파르두비체 중앙역 → 체스카트르제보바 | 59.7km | 296.4km |
| 체스카트르제보바 → 브르노 중앙역 | 89.5km | 385.9km |
| 브르노 중앙역 → 프르제로프 | 81.2km | 467.1km |
| 프르제로프 → 오스트라바 중앙역 | 83.6km | 550.6km |

### 경유역 원본

- [데친 중앙역 (Děčín hlavní nádraží)](https://www.openstreetmap.org/node/5062517821)
- [프라하 중앙역 (Praha hlavní nádraží)](https://www.openstreetmap.org/node/3134751791)
- [파르두비체 중앙역 (Pardubice hlavní nádraží)](https://www.openstreetmap.org/node/3129312254)
- [체스카트르제보바 (Česká Třebová)](https://www.openstreetmap.org/node/3129289404)
- [브르노 중앙역 (Brno hlavní nádraží)](https://www.openstreetmap.org/node/3325029085)
- [프르제로프 (Přerov)](https://www.openstreetmap.org/node/3266780396)
- [오스트라바 중앙역 (Ostrava hlavní nádraží)](https://www.openstreetmap.org/node/3036772660)

## 기존 네 경로 재계산 확인

다음 명령은 저장된 거리·선로 목록을 답으로 읽지 않고, `graph.json`의 선로와 각 경로의 역 목록으로 다시 탐색한다. 원본 캐시·GeoJSON·네트워크는 필요 없다. 네 경로 모두 총거리뿐 아니라 시작·도착 노드, 구간 ID와 진행 방향, 경유역 노드와 누적거리까지 저장값과 일치했다.

```sh
python3 ref/rail/route_from_graph.py --check
```

| 그래프 경로 ID | 저장 거리 | 재계산 거리 | 차이 |
|---|---:|---:|---:|
| `west_via_berlin` | 514,743.385m | 514,743.385m | 0m |
| `west_via_dresden` | 628,002.522m | 628,002.522m | 0m |
| `north_to_sassnitz` | 449,545.406m | 449,545.406m | 0m |
| `czech_corridor` | 550,623.158m | 550,623.158m | 0m |

## 해석 범위와 남은 문제

- 이 데이터는 현재 OSM 기록을 바탕으로 한 게임 참고 자료다. 재난 이후의 운행 가능성을 뜻하지 않는다.
- 보존 철도·폐선·공사 중 선로·경전철 태그는 제외했다. 궤간 수치로 거른 것은 아니므로 750mm 단독 구간 6개와 복수 궤간 구간은 남아 있다. 6000mm 이상값과 해당 원본 목록은 [README의 남은 문제](README.md#남은-문제)에 적었다. 체코 전체와 서부 폴란드·동부 독일을 둘러싸는 사각 범위여서 경계 주변의 다른 지역도 일부 포함된다.
- 복선 여부와 경사 등 누락 태그는 미확인이다. 경사에 표고 모델은 사용하지 않았다.
- 세부 경유역을 바꾸면 같은 데이터에서도 다른 후보가 나올 수 있다. 소규모 여객 정차장은 의도적으로 생략했다.
- 데이터 배포 시 © OpenStreetMap contributors와 [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)을 표시한다.

- 드레스덴 프리드리히슈타트: 화물 야드 표식은 미확인이고 인근 여객역 표식만 수록.
