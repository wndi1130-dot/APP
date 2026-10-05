# 이름 원어 풀: 출처·선정·검증 기록

확인일: 2026-10-05. 대상 파일: `ref/names/source_pools.json`.

이 파일은 한글 변환 전의 원어·성별·출처를 모은 자료다. 국가별로 실제 등록자료, 1차 연구, 보존본 또는 공개 사전에서 확인한 이름과 성을 선별했다. 자료의 기준일과 모집단이 서로 다르므로 한 시점의 유럽 인구분포나 같은 뜻의 순위로 합치면 안 된다. 한글 표기와 유명인 이름+성 조합 차단은 이 파일의 검증 범위에 포함하지 않는다.

## 수량

| 풀 | 이름 | 남성 이름 | 여성 이름 | 성 뿌리 |
|---|---:|---:|---:|---:|
| 폴란드어(pl) | 150 | 75 | 75 | 200 |
| 독일어(de) | 150 | 75 | 75 | 200 |
| 체코어(cz) | 150 | 75 | 75 | 200 |
| 우크라이나어(uk) | 30 | 15 | 15 | 40 |
| 슬로바키아어(sk) | 30 | 15 | 15 | 40 |
| 헝가리어(hu) | 30 | 15 | 15 | 40 |
| 리투아니아어(lt) | 30 | 15 | 15 | 40 |
| 합계 | 570 | 285 | 285 | 760 |

‘성 뿌리’는 이 풀에서 한 묶음으로 취급하는 성 항목 수다. 같은 성의 남녀형 두 개를 성 두 개로 세지 않는다. 철자 변이와 어원이 다른지까지 분류한 어원 사전은 아니다.

## 필드와 사용 범위

- `original`에는 표시용 원어를 둔다. NFC를 적용하고 해당 언어의 철자를 보존했다. 원자료의 대문자를 일반 이름 표기로 바꾼 경우와 사전용 강세 부호를 제거한 경우는 각국 메타데이터에 설명한다.
- 모든 이름·성 항목에 `source` URL이 있다. 성별형이 다른 성은 `male`/`female`로 표현하며, 성별 객체에 별도 출처가 있으면 그 출처가 해당 철자의 근거다. 폴란드 공통형의 남녀 빈도·출처는 `source_count_by_gender`/`source_by_gender`에 보존했다.
- `source_count`는 출처에 확인된 수치다. 독일 이름의 여러 해 합계처럼 직접 계산한 값은 계산 방법과 원래 값을 함께 적었다. 인구, 출생등록, 전화가입, 사전 합산 빈도를 서로 같은 단위로 읽지 않는다.
- `source_rank`, `derived_rank`, `source_table_position`은 서로 다르다. 전자는 해당 자료의 순위·행 순번이고, 후자는 직접 계산한 순위, 마지막은 연구 표 안의 번호다. 출처의 기준시점과 범위를 함께 읽어야 한다.
- 빈도나 순위의 근거를 확인하지 못한 항목은 ‘미확인’으로 표시했다. 사전에 등재되었다는 사실만으로 흔하다고 단정하지 않았다.
- 같은 언어에서 이름끼리·성 뿌리끼리·이름과 성 사이의 모든 원어 철자 중복을 검사했다. 교차중복도 제외하라는 편집 지침에 따라 폴란드 1개·독일 3개·체코 5개 이름을 같은 원자료의 다음 적격 후보로 교체했다. 성별형과 추가 미혼형도 교차중복 검사에 포함했다. 원자료의 순위·빈도는 재계산하거나 재번호를 부여하지 않았으며, 언어가 다른 풀 사이의 같은 철자는 유지했다.
- 국가 코드가 모든 항목의 어원 언어·국적·민족을 판정하는 것은 아니다. 독일·체코 등에 실제 등록된 다른 언어 기원의 이름도 포함될 수 있다.
- **리투아니아 성은 `male`과 `female`로 구분한다.** `female`은 검증된 전통 기혼형이며 `female.form_scope`와 `female_form_usage`에 `traditional_married`를 명시했다. 추가 미혼형은 `female_unmarried_verified`에 있다. 기혼형을 모든 여성·아동에게 자동 배정하지 않는다. 주 담당의 게임용 `other` 출력 방침은 검증된 미혼형이 있는 39뿌리만 사용하고 그 미혼형을 기본 `female`에 놓는 것이다. 기혼형은 참고 메타데이터로 보존하고 `Stankus`는 출력에서 제외한다. 이 원자료 파일에는 검증한 40쌍을 보존한다.
- 이 자료는 원어와 근거를 담은 중간 풀이다. 각국 게임용 JSON으로 옮길 때 출처·성별형·형태 적용 범위를 함께 보존해야 한다. 공식 기관이 검수·보증한 게임용 이름 목록이라고 표시하지 않는다.

## 폴란드어(pl)

- 원자료 제공자: 폴란드 디지털부(Ministerstwo Cyfryzacji). PESEL 등록자료에서 **살아 있는 사람**의 첫 번째 이름과 현재 성을 각각 집계한 공식 XLSX를 직접 내려받았다. 국적이나 민족을 판정하는 자료가 아니다. 사망자와 한 번만 등장하는 표기는 공개 목록에서 제외한다. 원자료 설명: <https://api.dane.gov.pl/1.4/datasets/1667>, <https://api.dane.gov.pl/1.4/datasets/1681>.
- 기준일: 네 파일 모두 **2026-01-20**. 취득일: **2026-10-05**. 파일 업로드일은 이름 2026-01-30, 성 2026-01-28로 기준일과 다르다.
- 첫 이름(남성): [resource 1159669](https://api.dane.gov.pl/1.4/resources/1159669). 첫 이름(여성): [resource 1159670](https://api.dane.gov.pl/1.4/resources/1159670). 현재 성(남성): [resource 1148808](https://api.dane.gov.pl/1.4/resources/1148808). 현재 성(여성): [resource 1148811](https://api.dane.gov.pl/1.4/resources/1148811). 각 항목의 `source`와 `sources[].url`에는 실제로 내려받은 XLSX의 전체 URL을 보존했다.
- 선정: 이름은 원자료의 빈도순으로 남성 75개·여성 75개를 선택했다. 한글 변환 언어의 혼용을 줄이기 위한 **편집상 선택**으로, 선택 범위에서 남성 표기 OLEKSANDR, ANDRII, SERHII, VOLODYMYR, DMYTRO와 여성 표기 TETIANA, NATALIIA, OLENA, IRYNA, OLHA, OKSANA를 제외했다. 이는 해당 표기를 가진 사람의 국적 판정이 아니며, 공식적인 ‘폴란드어 이름’ 분류도 아니다. 추가 편집 지침에 따라 성 풀과 철자가 겹치는 이름 **Marek**을 제외하고 같은 원자료에서 다음 적격 남성 후보 **Władysław**(원자료 81번째 행, 64,365명)를 보충했다. Marek이 실제 이름이자 성이라는 사실을 부정하는 제외가 아니다. 따라서 결과를 ‘전체 상위 75위 명단’이라고 부르면 안 된다. 남성 마지막 선택은 원자료 81번째 Władysław, 여성은 81번째 Angelika다. 원래 행 순번·빈도는 재번호를 부여하지 않고 보존했으며 언어 범위에 따른 배제와 이름·성 교차중복에 따른 배제를 JSON 메타데이터에 각각 기록했다.
- 성은 남성 명부의 첫 200개 표기를 200개 뿌리로 사용했다. 여성 명부 전체에서 대응형 또는 공통형의 실재와 빈도를 확인했다. 성별형이 다른 99개는 `male`/`female`, 같은 표기를 사용하는 101개는 `original`과 `source_by_gender`에 넣었다. -ski/-cki 계열의 여성형과 Konieczny/Konieczna는 모두 실제 여성 명부에 있는 표기다. 원자료가 개별 가족관계나 두 형태의 어원적 동일성을 증명하는 것은 아니며, 뿌리 묶음은 편집상 형태 대응이다.
- 원어 보존: 대문자 원자료를 표시용 대소문자로 바꾸고 Unicode NFC 정규화만 수행했다. 폴란드어 악센트·철자는 유지하며 `source_original`에 대문자 원문을 보존했다. 첫 이름의 원자료 `PŁEĆ`와 남녀 성 파일 구분을 성별 근거로 사용했다.
- 수치 의미: `source_count`는 해당 원어 표기를 가진 생존자의 공개 집계다. `source_rank`는 빈도순 XLSX의 **헤더를 제외한 행 순번**이다. 동률 처리 공식 순위나 남녀 합산 순위로 해석하지 않는다. 여성형의 수치·순번은 여성 명부의 것이며, 공통형에는 남녀 값을 별도로 저장했다. 게임의 추첨 가중치로 사용할지는 별도 설계 사항이다.
- 라이선스: 두 dataset API 응답의 `license_name`에서 **CC0 1.0**을 직접 확인했다. 라이선스 근거는 위 dataset API URL이며, 각 원본의 SHA-256·크기·취득일은 JSON의 `sources`에 기록했다.
- 미확인: 이름의 연령대별 적합성, 지역별 대표성, 국적·민족, 선정한 이름과 성을 결합한 특정 조합의 유명인 중복 여부는 이 원자료 수집으로 확인하지 않았다. 유명인 조합 회피는 별도 blocklist/생성기 검수의 범위다.


## 독일어(de)

### 이름: 쾰른시 출생등록 공식 공개 데이터

자료명: `Vornamen 2019-2022`, 파일 `Gesamt_Vornamen_2019-2022_0.csv`.

- 데이터 제공자: Stadt Köln / Standesamt Stadt Köln.
- 설명: https://www.offenedaten-koeln.de/dataset/vornamen-2019-2022
- 실제 다운로드: https://www.offenedaten-koeln.de/sites/default/files/distribution/Gesamt_Vornamen_2019-2022_0.csv
- 라이선스: 데이터 설명 페이지의 **Datenlizenz Deutschland – Zero – Version 2.0**. 연결된 라이선스 식별자: http://dcat-ap.de/def/licenses/dl-zero-de/2.0
- 자료 시기: 2019~2022년. 다운로드한 CSV는 27,170행이며 실제 열은 `jahr;vorname;anzahl;geschlecht;position`이다.
- 원본 크기: 512,734바이트.
- SHA-256: `353293ced97bb3d11cdd3ed22fef815c75cddba6f57068e30dc6d821235fe2ca`.

선정 방법은 다음과 같다. `position=1` 행만 가져와 같은 원어 표기와 성별의 `anzahl`을 2019~2022년 합산한다. 최종 독일 성 목록과 원어 표기가 같은 이름은 편집상 제외한 뒤, 합계 내림차순으로 남녀 각각 75개를 선택한다. 합계가 같으면 원문 NFC 문자열 오름차순으로 자른다. 끝자리 동률의 모든 이름을 포함한 명단은 아니며 남녀 수량을 정확히 맞춘 선택이다. `Clara`와 `Klara`처럼 서로 다른 실제 철자는 합치지 않는다. `gender`는 자료의 `m`·`w`를 `male`·`female`로 옮긴 값이다.

`source_count`는 직접 합산한 4년간 첫이름 등록 건수다. `source_counts_by_year`가 연도별 검증 값을 제공한다. `derived_rank`는 교차중복 제외 전의 원래 모집단에서 같은 성별의 더 큰 합계를 가진 표기 수에 1을 더한 공동순위로 계산했다. 제외 후 순위를 다시 매기지 않는다. 이 순위는 CSV에 원래 들어 있던 순위도, 독일 전국 순위도 아니다.

### 이름·성 교차중복에 따른 편집상 교체

동일 언어의 이름과 성 사이에서도 같은 원어가 나오지 않게 하라는 최신 지시에 따라 `Adam`, `Fritz`, `Paul`을 이름 풀에서 제외했다. 세 이름이 실제로 쓰이지 않거나 잘못된 이름이라는 뜻은 아니다. 성 200개를 유지하면서 이름만 같은 쾰른 원자료의 다음 남성 후보 `Hannes`, `Kian`, `Kilian`으로 보충했다. 여성 이름은 바뀌지 않았다. 제외·보충 항목과 이유는 쾰른 출처 메타데이터의 `editorial_exclusions`, `editorial_replacements`에도 기록했다.

아래 건수는 모두 쾰른 `position=1`, `geschlecht=m`의 실제 원자료 값이다. 순위는 제외 전 원래 남성 모집단에서 계산한 공동순위다. 출처: https://www.offenedaten-koeln.de/sites/default/files/distribution/Gesamt_Vornamen_2019-2022_0.csv

| 편집 | 이름 | 2019 | 2020 | 2021 | 2022 | 4년 합계 | 원래 공동순위 |
|---|---|---:|---:|---:|---:|---:|---:|
| 제외 | Adam | 35 | 34 | 38 | 47 | 154 | 31 |
| 제외 | Fritz | 18 | 21 | 23 | 19 | 81 | 70 |
| 제외 | Paul | 96 | 79 | 87 | 91 | 353 | 2 |
| 보충 | Hannes | 23 | 17 | 19 | 12 | 71 | 76 |
| 보충 | Kian | 20 | 15 | 20 | 16 | 71 | 76 |
| 보충 | Kilian | 16 | 18 | 15 | 21 | 70 | 78 |

지역 대표성은 쾰른시에 한정된다. 자료가 이름의 어원 언어나 등록인의 국적을 제공하지 않으므로 `de`는 **독일에서 등록된 이름 풀**이라는 뜻이다. 독일어 어원의 이름만 골랐다는 뜻이 아니다. 독일 전국·성인·고령층에서 흔한지와 현재 이름 분포는 미확인이다. 메타데이터 설명에는 이름 위치 열의 존재에 관해 상충하는 문장이 있지만, 다운로드 CSV에 `position` 1~6이 실제로 있으므로 그 열에 근거하여 첫이름만 사용했다.

### 성: Marynissen·Nübling의 1차 언어학 연구

Ann Marynissen·Damaris Nübling(2010), *Familiennamen in Flandern, den Niederlanden und Deutschland – ein diachroner und synchroner Vergleich*.

- 쾰른대 저장소 서지정보: https://kups.ub.uni-koeln.de/10755/
- 실제 다운로드: https://kups.ub.uni-koeln.de/10755/2/FamNamKontrastivMarynissenNuebling2010.pdf
- 사용 위치: **표 4, PDF 12~13쪽, 인쇄 쪽수 322~323**.
- 자료 기준: **2005년 전화가입(Telefonanschlüsse)**. 주민등록 인구나 사람 수의 집계가 아니다.
- 원본 크기: 1,202,511바이트.
- SHA-256: `7276e4ac138286c6d86b01476ea96aaf165cc0c558e06cbb7da33c54fad53edd`.

표 4의 200개 원어 성과 표 번호를 PDF에서 직접 추출했다. `Müller`부터 `Göbel`까지의 표 안 번호 1~200이 정확히 한 번씩 존재하는지 검사하고, 두 쪽을 화면으로 확인했다. 실제 철자 변형은 원문대로 별개 표기로 보존했다. 여기서 200개는 서로 다른 성 표기의 수이며 어원이 서로 다른 200개라는 뜻은 아니다.

**원표는 `Nowak`을 제외했다고 명시한다.** 따라서 각 항목의 `source_table_position`은 그 제외가 반영된 표의 번호다. 이를 독일 전체의 정확한 순위라고 부르지 않았다. 원문은 개별 성의 전화가입 건수를 표 4에 싣지 않아 성 항목에 `source_count`를 만들지 않았다. 2005년 자료에서 상위 성이라는 근거는 확인했지만 2026년 인구 빈도는 미확인이다.

KUPS 서지 메타데이터는 출판연도 2010과 Open Access를 표시한다. 다만 구체적인 재배포 라이선스명은 해당 페이지에서 확인되지 않았다. 이 작업은 이름 표기와 표 안 번호라는 사실만 전사했고, 논문의 문장·뜻풀이·도표 디자인·지도를 복제하지 않았다. 원본 PDF는 검증용 캐시에만 두며 저장소에 체크인하지 않는다. Open Access라는 표기를 논문 전체에 대한 임의의 오픈 라이선스로 해석하지 않는다.

KUPS 서지 페이지에 기재된 쪽수 `11–35`는 실제 PDF 인쇄 쪽수와 맞지 않는다. 인용 위치는 실제 파일의 표 4, 인쇄 322~323쪽/PDF 12~13쪽을 사용했다.

### 검토했지만 풀을 만드는 데 사용하지 않은 자료

- 마인츠 디지털 성씨사전 DFD: https://www.namenforschung.net/dfd/woerterbuch/liste/ . 이 작업에서 기본 목록 페이지와 프로젝트·imprint 페이지는 HTTP 403을 반환했다. 개별 표제어 `Kellner`의 실제 페이지 https://www.namenforschung.net/id/name/444/1 는 웹 조회로 읽었지만 이 성은 이번 표 4의 200개에 들어가지 않으므로 출처만 붙여 추가하지 않았다. 200개 전체를 DFD에서 개별 검증했다고 주장하지 않는다.
- GfdS의 과거 이름 목록: https://gfds.de/vornamen/beliebteste-vornamen/ . 1977년부터의 목록과 소프트웨어·상업 사용에 관한 별도 문의 문구를 확인했다. 고령층 보강용 목록을 여기서 복제하지 않았으며, 이번 데이터에 대한 GfdS 이용허락을 받았다고 주장하지 않는다.


## 체코어(cz)

### 자료와 용도

| 자료 | 기준시점 | 사용한 범위 | 출처 |
|---|---|---|---|
| 체코 내무부 이름·출생연도 XLS의 보존본 | 2017년에 공개된 보존본. 전체 원자료의 정확한 집계일은 미확인. 표의 출생연도 상한은 2017 | 이름 철자와 `3000` 합계 열. 이름 빈도 내림차순 선정을 위한 수치 | https://raw.githubusercontent.com/michalbcz/cetnost-jmen-a-prijmeni/main/cetnost-jmena-dnar.zip |
| ČSÚ 비소치나 남녀 이름·전국 지역별 분포 XLSX | 2016-12-31 | `ORP` 시트의 남녀 60개씩으로 체코에서의 성별 사용을 확인. `Kraje` 시트의 60개 이름은 지역 합계와 보존본의 전국 합계를 대조 | https://csu.gov.cz/docs/107783/161a10be-6553-14b2-8696-ff57bc2a6817/%C4%8Detnost_jmen_vys_kraje2016.xlsx?version=1.0 |
| 체코 내무부 남성·여성·중립 이름 CSV | 목록 페이지 표시는 2026-09-30. 다운로드 URL 문자열은 2026-06-30 | ČSÚ 60+60 바깥 이름의 성별 분류. 허용 이름 목록이므로 흔함을 증명하는 자료로 쓰지 않음 | https://mv.gov.cz/documents/opendata-seznamjmenk2026-06-30?disposition=attachment |
| V4 성씨사전 체코 상위 200 목록 | 방법 설명에서 체코 자료를 2016년 MV/Kdejsme 기반으로 명시 | 성씨 뿌리 200개 선정, 사전이 제시한 남녀형 합산 빈도와 순위 | https://v4surnames.elte.hu/index.php/en/site/toplist?modelsToplistSearch%5Bpagesize%5D=200&modelsToplistSearch%5Bcountry%5D=cs |
| 체코 내무부 `zcpr.csv` 보존본 | 보존본 README상 2017-09 갱신 | 각 남녀 성씨형이 원자료 행에 실제 존재하는지 검증 | https://raw.githubusercontent.com/michalbcz/cetnost-jmen-a-prijmeni/main/zcpr.zip |
| 체코 과학원 체코어연구소 문법 안내 | 확인일 2026-10-05 | 등록된 남녀 성씨형 간 문법적 대응 확인 | https://prirucka.ujc.cas.cz/?id=701 · https://prirucka.ujc.cas.cz/?id=702 · https://m.prirucka.ujc.cas.cz/en/?id=703 |

추가 설명 페이지:

- 원자료 보존 경위와 파일 설명: https://github.com/michalbcz/cetnost-jmen-a-prijmeni
- 현재 내무부 성별 명단 안내: https://mv.gov.cz/seznam-jmen/
- ČSÚ 공식 글과 첨부자료 안내: https://csu.gov.cz/vys/jmena-a-prijmeni-v-kraji-vysocina-vede-jiri-marie-a-dvorakovi
- V4의 자료시점·표제어·남녀형 합산 방법: https://v4surnames.elte.hu/index.php/en/site/aboutthedictionary
- 내무부의 빈도자료 공개 중단에 관한 공식 안내: https://mv.gov.cz/clanek/poskytnuti-informace-ukonceni-zverejnovani-seznamu-cetnosti-jmen-prijmeni-a-titulu-na-webovych-strankach-mv.aspx

### 선정과 검증

1. 내려받은 이름 XLS의 두 시트에서 원어와 `3000` 전국 합계 열을 추출했다. 합계 행 `SOUČET`는 후보에서 제외했다. 공백이 있는 복합 이름은 쓰지 않았다.
2. 성별은 먼저 ČSÚ `ORP` 시트의 남녀 사용을 확인했다. 이 표 바깥에서는 현재 내무부 CSV의 `MUZ` 또는 `ZENA` 분류를 사용했다. 최종 성씨 200개의 모든 남녀형과 원어 철자가 겹치는 이름을 제외한 뒤, 성별마다 원자료 빈도가 높은 이름 75개를 골랐다.
3. Jan, Daniel, Hana, Martina, Vlasta, Andrea, Nikola, Iva는 현재 내무부의 중립명 목록에도 있지만, ČSÚ 자료에서 체코 내 해당 성별 사용이 확인되므로 포함했다. 해당 항목의 `gender_note`와 `neutral_name_source`에 이 점을 남겼다. David는 중립명 분류 때문에 제외한 것이 아니라 성씨와 원어가 겹쳐 제외했다. 성별은 다른 국가·언어에서의 모든 용례를 배제하는 판정이 아니다.
4. 교차중복 제거 후 이름의 원자료상 최소 빈도는 남성 Mikuláš 6,008, 여성 Renáta 16,027이다. 이 숫자는 현재 인구 수가 아니라 내려받은 보존본의 합계 열 수치다.
5. V4 목록의 체코 표제어 200개를 가져온 뒤, 각 여성형을 `zcpr.csv`의 실제 철자와 대조했다. 예를 들어 Vaněk–Vaňková, Staněk–Staňková, Daněk–Daňková, Němec–Němcová, Moravec–Moravcová, Adamec–Adamcová, Brabec–Brabcová의 자음 변화도 확인했다. 모든 최종 남녀형은 `zcpr.csv`에 있다.
6. 성씨 항목의 `source_rank`와 `source_count`는 V4 목록의 실제 열 값이다. 남녀 성씨형을 묶은 사전의 합계이며, 게임 풀에서 선택한 두 철자의 `zcpr.csv` 수치를 더한 값이 아니다. 남녀 객체 안의 `source`는 철자 검증용 보존본이고, 항목 최상위의 `source`는 순위·빈도 근거인 V4 목록이다.
7. 여성형은 등록된 대표형 하나를 골랐다. 가족별로 다른 등록형을 사용할 수 있으며, 특히 Krejčí–Krejčová와 Kočí–Kočová에서는 접미사를 붙인 여성형을 선택했다. 이 두 쌍은 ÚJČ의 `id=702`에 실제 대응 예시로 제시되어 있다. 선정한 상위 200개에는 Janků·Petrů 같은 `-ů`형이나 Dolejší·Hořejší 같은 비교급 `-ší`형이 없다. 모든 `-í` 성씨에 동일한 변형을 강제하는 생성 규칙으로 읽으면 안 된다.

### 이름·성씨 교차중복 제거

후속 편집 기준에 따라 이름과 성씨 사이의 같은 원어도 제외했다. 아래 이름들은 실재성과 흔함에 문제가 있어서 빠진 것이 아니다. 최종 성씨 목록의 원어와 겹친다는 편집상 이유로 이름 풀에서 제외했다. 같은 성별 자료의 빈도순 다음 후보로 보충했으며, 원자료의 빈도와 성씨 순위는 수정하거나 다시 매기지 않았다. 이름 자료에는 공식 순위 열이 없으므로 새 공식 순위를 만들지 않았다.

| 처리 | 원어 | 원자료 빈도 |
|---|---|---:|
| 제외 | Petr | 272,135 |
| 제외 | David | 101,311 |
| 제외 | Marek | 63,088 |
| 제외 | Filip | 50,464 |
| 제외 | Štěpán | 24,148 |
| 추가 | Vilém | 6,701 |
| 추가 | Tobiáš | 6,617 |
| 추가 | Alexandr | 6,609 |
| 추가 | Otakar | 6,253 |
| 추가 | Mikuláš | 6,008 |

모든 수치는 위 MV 이름·출생연도 보존본의 합계 열에서 확인했다. 새 이름 5개의 남성 사용은 내려받은 공식 MV CSV의 `MUZ` 행에서 각각 확인했다. 제외 목록·이유와 보충 항목의 원자료 URL·빈도·성별 근거는 통합 JSON의 `cz.selection_metadata`에 보존했다. 변경 전후 비교에서 기존 이름 145개와 성씨 200개 쌍의 전체 항목이 그대로 유지되었다. 당시 변경 적용 검증 결과는 `cz_overlap_patch_validation.json`에 있다.

### 확인된 차이와 미확인

[WATCH] 보존본 이름 합계와 ČSÚ의 2016-12-31 지역 합계를 비교한 원자료 60개 중 58개가 정확히 일치했다. 나머지는 Petr 272,135 대 272,134, Lucie 111,937 대 111,936으로 각각 1명 차이다. Petr는 이후 이름·성씨 교차중복 제거에 따라 최종 이름 풀에서 제외되었지만 원자료 비교 결과는 남겼다. 지역코드 없는 사람의 처리 등으로 인한 것일 가능성은 있으나 원인은 미확인이다. 서로 합치거나 임의로 보정하지 않았다. 정확히 일치하는 이름에는 날짜와 `count_crosscheck_source`를 기록하고, 나머지 보존본 항목은 정확한 집계일을 미확인으로 남겼다.

[WATCH] `zcpr.csv`의 인원은 V4 수치와 다르다. 예를 들어 `NOVÁK` 49,341과 `NOVÁKOVÁ` 50,052를 합치면 99,393이지만, V4의 2016년 Novák 항목 합계는 68,693이다. `zcpr.csv`의 정확한 집계 대상·차이 원인은 미확인이다. 최종 JSON에 이 CSV의 빈도를 사용하지 않고 철자 존재 확인에만 사용했다.

[WATCH] `zcpr.csv`에는 동일 철자 중복 행이 9개 있다: ŠACHA, PECHAL, STACHA, ČECHA, CHMELA, CHOURA, LERCHL, CHÁBR, PECHAČ. 인원이 다른 중복도 있으므로 임의 합산하지 않고 해당 철자는 검증 후보에서 제외했다. 이번 최종 200개 쌍에는 영향이 없다. CSV는 CP1250으로 읽었고 따옴표 해석을 끈 세미콜론 구분으로 처리했다.

[WATCH] 현재 내무부 성별 명단 페이지의 2026-09-30 표시와 링크 이름의 2026-06-30 표시는 일치하지 않는다. 명단 내용을 실제 다운로드해 확인했지만 링크 이름을 근거로 파일 내용의 기준일을 다시 단정하지 않았다.

[WATCH] 체코 국가 내 사용을 기준으로 한 풀이며 모든 항목의 어원이나 민족적 기원이 체코어라는 뜻은 아니다. Müller, Horváth, Kováč 등 실제 체코 사용 성씨도 들어 있다. 항목 단위 이름·성씨는 실재성이 확인되었지만, 생성되는 이름+성의 조합이 유명 실존 인물과 겹치는지 확인하는 일은 별도 blocklist의 역할이다.

### 라이선스와 재사용 표시

- ČSÚ 공식 이용조건은 CC BY 4.0을 명시한다. 출처와 라이선스 조건을 표시하고, 가공·파생된 자료임을 밝혀야 한다. 이 풀은 ČSÚ 원표를 바탕으로 다른 출처를 결합하고 수량을 제한한 게임용 파생 자료다. ČSÚ 공식 이름 풀 또는 수정 없는 공식 통계라고 표시하면 안 된다. 이용조건: https://csu.gov.cz/podminky_pro_vyuzivani_a_dalsi_zverejnovani_statistickych_udaju_csu · 라이선스: https://creativecommons.org/licenses/by/4.0/
- 내무부의 보존본 GitHub 저장소, 현재 이름 목록 CSV와 V4 웹사전의 명시적 재사용 라이선스는 확인하지 못했다. 공개 접근 가능성을 개방형 라이선스나 자유로운 원본 재배포 허가로 해석하지 않았다. 이름의 철자·빈도 같은 사실만 선별했고 원자료 전체와 사전의 어원·뜻풀이 문장은 커밋 대상에서 제외한다.
- ÚJČ 안내는 저작권 보유 및 복제 관련 안내가 있다. 설명문·사전 내용을 복제하지 않고 문법적 사실을 확인하는 참고 출처로 썼다.


## 우크라이나어(uk)

### 사용 출처

| 출처 | 기준시점·범위 | 사용 방식 | 근거 강도·한계 |
|---|---|---|---|
| https://centraljust.gov.ua/news/direction/yak-ukraintsi-nazivali-svoih-ditey-v-2021-rotsi | 2021-11-09 발표. 키이우시·키이우주·체르카시주의 신생아 이름 | 인기 이름이라고 설명한 문단에서 남 9·여 10개를 추출 | 법무부 중앙지역청 공식 발표. 이름별 인원수·수치 순위 미공개. 2021년 연말 확정 집계가 아님 |
| https://centraljust.gov.ua/news/direction/yaki-imena-otrimali-malenki-ukraintsi-u-2019 | 2019년, 위 세 지역. 게시일 2020-01-17 | 앞 출처와 중복되지 않는 인기 이름 남 6·여 5개를 추가 | 같은 공식 행정기관 발표. 지역별 신생아 인기 목록이며 전체 연령·현재 전국 순위는 미확인 |
| https://ridni.org/karta/ | 2011–2013년 우크라이나 성 분포 | 상위 100개 표에서 Іванова·Іванов·Попова를 제외한 앞 40개. 원문 인원수와 행 순위를 각각 `source_count`·`source_rank`에 보존 | 원자료 공개 주체의 집계표를 직접 취득. 정부 통계가 아니며 모집단·수집 경로의 독립 검증은 하지 못함. 전쟁 이후의 이동·변화 미반영 |

이름은 공식 발표에서 인기 이름으로 확인했으나 정량 근거가 공개되어 있지 않아 요청에 따라 각 항목의 `commonness_status`를 `미확인`으로 기록했다. 자료에 없는 수치·순위는 만들지 않았다. 성 통계는 남녀형이 다르면 서로 다른 표기로 집계된다는 Ridni 설명에 따라 임의 합산하지 않았다. 위 세 표제어는 별도 성별형 짝 검증이 필요한 항목이어서 이번 작은 풀에서 제외했다.

### 라이선스와 재현

법무부 중앙지역청의 두 페이지는 하단에 전체 자료의 Creative Commons Attribution 4.0 International 적용을 명시한다. 라이선스 URL은 https://creativecommons.org/licenses/by/4.0/deed.uk 이다. 원출처와 기관을 표기하고 인기 이름을 선별·JSON으로 구조화했음을 밝힌다. Ridni의 데이터 재이용 라이선스는 미확인이다. 공개된 이름·수치 사실만 추출했으며 설명 문장이나 사전의 어원 본문은 복제하지 않았다. 공개 웹 접근을 곧 개방형 라이선스라고 해석하지 않는다.


## 슬로바키아어(sk)

### 출처와 추출

| 출처 | 기준시점·사용 범위 | 방법·제약 |
|---|---|---|
| https://www.minv.sk/?tlacove-spravy&sprava=najpopularnejsimi-menami-pre-deti-narodene-v-roku-2024-su-opat-sofia-a-jakub | 2024-11-30까지의 신생아 이름, 발표일 2024-12-03 | 내무부가 본문에 제공한 남녀별 20개 목록에서 각각 앞 15개. 원문 순위와 인원수를 보존. 전체 연령·2024년 연말 확정 빈도가 아님 |
| https://v4surnames.elte.hu/index.php/en/site/toplist?modelsToplistSearch%5Bpagesize%5D=200&modelsToplistSearch%5Bcountry%5D=sk | 1995년 주민등록 자료를 바탕으로 한 슬로바키아 성 상위 200개 | 성 표제어와 빈도·순위를 실제 다운로드하여 추출. 여성형 증빙을 확보한 40개를 선택했으므로 현재 전국 상위 40개를 뜻하지 않음 |
| https://v4surnames.elte.hu/index.php/en/site/aboutthedictionary | 사전의 방법 설명 | 대학·국가 언어기관의 공동 연구. 슬로바키아는 1995년 공식 인구등록 자료와 Ďurčo 등의 1998년 데이터베이스를 사용한다고 명시. 남성형을 표제어로 두고 남녀형 인원을 합산한다고 설명 |
| https://www.juls.savba.sk/latroporterogreta.html | 국가 언어기관의 역순사전 표제어 색인, 정확한 데이터 기준연도 미확인 | 직접 내려받은 앞 3,000,000바이트의 부분 HTML에서 실제로 등장하는 여성형 36개를 확인. 빈도 자료로 사용하지 않음. 표제어는 단어·고유명사 색인이므로 성의 대표성은 별도 V4 자료가 담당 |
| https://www.juls.savba.sk/ediela/psp2000/psp.pdf | 국가 언어기관의 2000년 표기 규정. PDF 73쪽부터 여성 성 형성 규칙 | 남녀형 짝을 규칙에 대조. Švec–Švecová 및 Hudec–Hudecová는 PDF 73쪽에 직접 실린 형태. Hudec에는 Hudcová도 허용되어 있으므로 이번 선택이 유일한 가족형은 아님 |
| https://www.juls.savba.sk/ediela/sociolinguistica_slovaca/1997/3/sls3.pdf | 1997년 원 연구논문집, PDF 314쪽 | Molnár–Molnárová, Kovács–Kovácsová를 직접 열거한 자료. 이 표의 철자변형 합산 빈도는 JSON 빈도에 사용하지 않았으며, 빈도는 V4표 값만 사용 |

JSON의 각 성은 `male`·`female`을 갖는다. 항목 `source`는 V4 목록이며 실제 여성형을 확인한 출처는 `female.source`와 성 항목 최상위 `form_source`에 둔다. 규칙 대조 출처는 `form_rule_source`다. 사전에 두 형태가 존재하고 규칙상 대응한다는 것을 확인했으며, 모든 실제 가족의 등록형이 동일하다고 주장하지 않는다. 여성형 단독의 빈도는 확인하지 못해 `female.commonness_status`를 `미확인`으로 두었다. 상위 후보 Kmeť·Kmeťo는 여성형이 겹쳐 Kmeť만 남겼다.

### 라이선스

내무부 페이지에는 내무부 저작권 고지가 있고, V4 사전은 공개 열람 자료이지만 별도의 개방형 재이용 라이선스는 확인하지 못했다. 국가 언어기관의 규정 PDF에는 저작권 적용 고지가 있다. 이 자료들에서 사용한 것은 원어 이름·성, 집계 숫자, 언어 형태에 관한 사실이며 본문·어원 해설을 복제하지 않았다. 공개 열람과 개방형 라이선스는 구분했다.

### 실제 취득·검증·정리 대상

내무부 본문은 PowerShell `Invoke-WebRequest`로 직접 받았다. Python의 인증서 체인 오류에 대해 검증을 끄지 않았으며 Windows의 정상 인증서 검증을 사용했다. 그 원문에서 Sofia 558명, Jakub 793명을 포함한 이름별 수치와 11월 30일 기준 문구를 다시 대조했다.

각 다운로드 파일의 `.meta.json`에 URL·UTC 취득시각·바이트 수·SHA-256을 보관했다. `sk_juls_reverse.html`만 전체가 아닌 부분 원문이며 해당 메타데이터에 `download_complete: false`를 명시했다. 여성형을 실제로 발견한 완전한 표제어 링크만 활용했고, 찾지 못한 항목을 실재하지 않는 이름으로 판단하지 않았다. 두 PDF는 완전한 파일이며 `pypdf`로 해당 페이지의 남녀형을 실제 추출해 대조했다.

검증은 이름·성 수량, 남녀 수, 원어 중복, Unicode NFC, 원문 순위·빈도와 특정 기준값, 여성형의 사전/PDF 존재를 확인한다. 조사 중의 브라우저 검사 페이지 `sk_juls_test.html`, 대체 경로 탐색용 `sk_v4_toplist.html`·`sk_v4_allnames.html`·`sk_v4_top50.html`·`sk_v4_entry_206.html`, 이전 연구 에세이 `sk_juls_forms_rule.html`은 최종 항목의 근거로 사용하지 않았다.

`.cache/sk_*` 다운로드·보조물은 모두 체크인 대상에서 제외하며 재취득·재현 가능하다. 통합·검수 후 정리 대상이고 삭제는 하지 않았다.


## 헝가리어(hu)

- 발행기관: 헝가리 정부·내무부 주민등록 통계. 자료 안내: https://kormany.hu/nyilvantartasok/statisztika/lakossagi-szamadatok
- 기준일: 두 원본 모두 2025-01-01. 이름 XLSX의 첫 행에 `2025.01.01-jén` 표시. 성 XLSX의 날짜 셀 값 45658도 해당 날짜다.
- 이름 원본: https://cdn.kormany.hu/uploads/document/e/e1/e1d/e1dba22ffb16f7ca4df0baa2499e56f96b8ffe65.xlsx
- 성 원본: https://cdn.kormany.hu/uploads/document/1/17/173/1739c283e6e8048d662c07e9761ee9098f6314b5.xlsx
- 선정: 남녀 각각 원본 1~15위, 성 원본 1~40위. 실제 다운로드한 XLSX의 XML에서 추출했으며 악센트를 보존하고 대문자만 일반 이름 표기로 정리했다.
- 이름의 `source_count`는 첫 번째 이름(`Első utónévként`) 보유 인원이다. 두 번째 이름의 빈도와 더하지 않았다. 성은 출생 시 성(`Születési családi név`) 출현 수이며 기혼자의 전체 이름 관습을 재현하는 자료가 아니다.
- 품질: 각 항목의 순위와 수치를 원본에 대응시킬 수 있다. 현재 2026년 순위가 아니라 고정한 2025년 기준값이다. 이름을 무작위로 동일 확률 선택하면 실제 인구분포를 재현하지 않는다.
- 라이선스: 국가 공공데이터 포털의 같은 통계 계열 페이지는 `License not specified`로 표시하고, 이용약관 II.1은 별도 라이선스가 없는 공공데이터의 제한 없는 재이용을 설명한다. https://www.kozadatportal.hu/dataset/cd460417-14a0-4051-ad2d-8b352f228c67 ; https://www.kozadatportal.hu/dataset/e781fb13-905d-4b83-8a4e-f894695c29cc
- [WATCH] 위 카탈로그는 과거 연도 목록이므로 2025년 CDN 원본에 별도 라이선스가 부여됐는지는 미확인이다. 원본 문장·서식은 복제하지 않았으며 필요한 이름과 통계 사실, 출처만 추출했다. CC0 또는 CC BY로 임의 표시하지 않는다.


## 리투아니아어(lt)

이름은 국영 등록기관 Registrų centras의 공개 CSV 두 건에서 추출했다. 형성일은 CSV `data_formav`의 **2026-01-03**이며, `nr`와 `viso_vardas`를 실제 읽은 값대로 보존했다. 자료 범위는 **1900년 이후 등록 이름 TOP 50**이다. 현재 생존 인구나 2026년 신생아 이름 순위로 바꾸어 설명하면 안 된다. 생존·사망 포함 범위의 상세 정의는 미확인이다.

- 남성 CSV: https://www.registrucentras.lt/aduomenys/?byla=08_gr_open_top50_vardai_v_1900_r8.csv
- 여성 CSV: https://www.registrucentras.lt/aduomenys/?byla=07_gr_open_top50_vardai_m_1900_r7.csv
- 남성 메타데이터·CC BY 4.0: https://data.gov.lt/datasets/1754/?resource_version=542
- 여성 메타데이터·CC BY 4.0: https://data.gov.lt/datasets/1753/?resource_version=975

남성은 원본 순위 1~18위 중 `IVAN`, `ALEKSANDR`, `VLADIMIR`를 제외한 15개, 여성은 원본 1~15위를 선정했다. 이 제외는 작은 리투아니아어 표기 풀의 범위를 위한 편집 선택이며 해당 사람들의 민족이나 국적을 추정한 것이 아니다. 원본 대문자를 일반 이름 표기로 바꾸고 원어 철자의 부호는 보존했다. 직접 urllib 다운로드는 HTTP 403이었으나 웹 도구가 공개 CSV 전체 본문을 반환했고, 행을 자동 추출해 `.cache/lt_given_web_extract.json`에 보관했다. 다운로드 성공으로 바꾸어 기록하지 않는다.

성의 주 원자료는 Wiktionary 리투아니아어 사전의 공개 구조 추출본이다.

- 자료 안내: https://kaikki.org/dictionary/Lithuanian/categories-other/D-/Lithuanian%20surnames/index.html
- 실제 다운로드: https://kaikki.org/dictionary/Lithuanian/categories-other/D-/Lithuanian%20surnames/kaikki.org-dictionary-Lithuanian-category-Lith-09a8RctF
- 원사전: https://en.wiktionary.org/wiki/Category:Lithuanian_male_surnames ; 각 항목 `wiktionary_url`에도 대응 표제어를 적었다.
- 출처·재이용: **Wiktionary 기여자**, 추출·가공 **Tatu Ylonen / Kaikki.org / Wiktextract**. 원사전의 본문 라이선스는 **CC BY-SA 4.0**이며 실제 Kazlauskas 페이지의 라이선스 링크를 확인했다: https://en.wiktionary.org/wiki/Kazlauskas ; https://creativecommons.org/licenses/by-sa/4.0/
- 버전: Kaikki 안내상 2026-09-02 Wiktionary 덤프를 2026-10-03 추출. 받은 날짜 2026-10-05. 실제 JSONL 3,464,889바이트, 764개 레코드를 파싱했다.
- 선정·변경: 보조 빈도 목록에서 발견한 후보 가운데 원사전 추출본의 `Lithuanian surnames` 분류와 `lt-proper noun`의 남성값이 실제 있는 40개를 선정했다. 일부는 남성 성 하위 분류가 없어 상위 성 분류와 표제어의 남성값을 함께 확인했다. 이름·성별·명시된 여성형만 발췌했으며 어원·설명 문장·굴절표는 옮기지 않았다. 재배포할 때 이 출처와 변경 사항, CC BY-SA 표기를 함께 유지한다.
- [WATCH] 국립기관에서 40개 성의 현재 빈도를 검증하지 못했다. 성은 모두 `commonness_status: 미확인`으로 표시하고 빈도·순위 숫자를 넣지 않았다. 이름 자료와 달리 성 자료는 공동 편집 사전의 2차 자료다. 보조 후보 확인에 읽은 https://forebears.io/lithuania/surnames 의 수치는 원본 연도·방법을 확인하지 못해 채택하지 않았다.

성별 형태의 적용 범위:

- `female`: 사전이 명시한 `feminine` 표기. 전통적 기혼 여성형 참고값이며 `form_scope: traditional_married`. 모든 여성이나 아동에게 자동 적용하면 안 된다.
- `female_unmarried_verified`: 사전이 명시한 `unmarried feminine` 표기 또는 아래 지자체 자료의 실제 여아 표기. `form_scope: traditional_unmarried`. 혼인 여부를 숨기는 중립 여성형은 이 풀에서 생성하지 않았다.
- `male.original`은 남성형, `female.original`은 전통 기혼형이다. 최종 통합에서는 남성형을 공통형으로 오인하지 않도록 male/female 구조로 정리했다. female_form_usage와 form_scope를 읽어야 한다. 게임용 other 출력은 미혼형이 검증된 39뿌리의 female_unmarried_verified를 기본 female로 사용하고 기혼형은 별도 참고 메타데이터로 남긴다. Stankus는 원자료에 보존하되 게임용 other 출력에서 제외한다. 이는 이번 생성기의 편집상 기본값이며 모든 여성에게 미혼형을 일률 적용하는 언어 규칙이라는 뜻은 아니다.
- 사전용 강세 표시(결합 악센트 acute/grave/tilde)만 제거했다. `source_spelling`에 원본을 남겼고, 리투아니아어 철자의 `č š ž ė ą ę į ų ū` 등은 보존했다.
- `Šimkus → Simkienė`는 어두 철자 불일치가 있어 후보에서 제외했다. `Butkus → Butkáitė`, `Rimkus → Rimkáitė`는 보조 사전 값 대신 우테나 시 설명에 실제 등장하는 **Butkutė, Rimkutė**를 채택했다. 이 자료는 2011년 여아 성 목록을 인용한다: https://utena.lt/rasykime-ir-kalbekime-taisyklingai/
- `Stankus`의 미혼형 `Stankáitė`는 별도 검증하지 못해 저장하지 않았으며 미확인으로 남겼다. 따라서 미혼 여성형은 39개다. 임의로 어미를 바꾸어 보충하지 않았다.

[WATCH] LKI의 https://pavardes.lki.lt/ 는 무허가 데이터베이스 생성·복제를 제한하고 NC 라이선스를 표시한다. 그 데이터베이스 결과는 이 이름 풀의 원자료로 쓰지 않았다. 새 E. KALBA 사전 https://ekalba.lt/pavardziu-duomenu-baze 도 API 요청이 HTTP 405로 끝났다.


## 재검증

프로젝트 루트에서 다음 검사를 실행할 수 있다. 다운로드 원본이 없어도 수량·성별 균형·원어 중복과 이름·성 교차중복·NFC·항목별 출처·리투아니아 성형 제한을 검사한다.

```powershell
@'
import collections
import json
import unicodedata
from pathlib import Path
from urllib.parse import urlsplit

EXPECTED = {"pl": (150, 200), "de": (150, 200), "cz": (150, 200),
            "uk": (30, 40), "sk": (30, 40), "hu": (30, 40), "lt": (30, 40)}

def url_ok(value):
    return isinstance(value, str) and urlsplit(value).scheme in {"http", "https"} and bool(urlsplit(value).netloc)

def original_ok(value):
    return isinstance(value, str) and bool(value) and value == value.strip() and unicodedata.normalize("NFC", value) == value

def verify(data):
    summary = {}
    for language, (minimum_names, minimum_surnames) in EXPECTED.items():
        pool = data[language]
        given = pool["given_names"]
        surnames = pool["surnames"]
        assert len(given) >= minimum_names, (language, "given count")
        assert len(surnames) >= minimum_surnames, (language, "surname count")
        gender_counts = collections.Counter(item["gender"] for item in given)
        assert gender_counts == {"male": minimum_names // 2, "female": minimum_names // 2}, (language, gender_counts)
        assert len({item["original"].casefold() for item in given}) == len(given), (language, "duplicate given")
        roots = []
        spellings = []
        for item in given:
            assert original_ok(item["original"]), (language, item)
            assert url_ok(item.get("source")), (language, "missing given source", item)
        for item in surnames:
            assert url_ok(item.get("source")), (language, "missing surname source", item)
            if "original" in item:
                root = item["original"]
                values = [root]
                assert language != "lt", ("lt", "gendered surname stored as common original")
            else:
                root = item["male"]["original"]
                values = [root, item["female"]["original"]]
                assert values[0] != values[1], (language, "common form stored twice", root)
                if language == "lt":
                    assert item["male"].get("gender") == "male", ("lt", "male scope")
                    assert item["female"].get("form_scope") == "traditional_married", ("lt", "female form scope")
                    assert item.get("female_form_usage") == "traditional_married", ("lt", "female usage scope")
            for key in ("female_verified", "female_unmarried_verified"):
                if key in item:
                    variant = item[key]
                    assert original_ok(variant["original"]), (language, key)
                    assert variant.get("form_scope") in {"traditional_married", "traditional_unmarried"}, (language, key, "scope")
                    assert url_ok(variant.get("source", item["source"])), (language, key, "source")
                    values.append(variant["original"])
            assert all(original_ok(value) for value in values), (language, values)
            roots.append(root.casefold())
            spellings += [value.casefold() for value in values]
        assert len(roots) == len(set(roots)), (language, "duplicate surname root")
        assert len(spellings) == len(set(spellings)), (language, "duplicate surname spelling")
        cross_role_duplicates = {item["original"].casefold() for item in given} & set(spellings)
        assert not cross_role_duplicates, (language, "given-surname duplicate", sorted(cross_role_duplicates))
        assert pool.get("sources"), (language, "missing source registry")
        summary[language] = {
            "given_names": len(given), "male": gender_counts["male"], "female": gender_counts["female"],
            "surname_roots": len(surnames), "surname_spellings": len(spellings),
            "gender_pairs": sum("male" in item for item in surnames),
            "shared_or_restricted_original": sum("original" in item for item in surnames),
            "source_missing": 0, "duplicate_given": 0, "duplicate_surnames": 0,
            "duplicate_given_surname": 0
        }
    assert sum(row["given_names"] for row in summary.values()) == 570
    assert sum(row["surname_roots"] for row in summary.values()) == 760
    lt_surnames = data["lt"]["surnames"]
    lt_verified_unmarried = [item for item in lt_surnames if "female_unmarried_verified" in item]
    assert len(lt_verified_unmarried) == 39, ("lt", "unmarried count")
    assert all(item["female_unmarried_verified"]["form_scope"] == "traditional_unmarried" for item in lt_verified_unmarried)
    assert [item["male"]["original"] for item in lt_surnames if "female_unmarried_verified" not in item] == ["Stankus"]
    return summary

if __name__ == "__main__":
    path = Path("ref/names/source_pools.json")
    result = verify(json.loads(path.read_text(encoding="utf-8")))
    for language, values in result.items():
        print("[PASS]", language, json.dumps(values, ensure_ascii=False))
    print("[PASS] total_given=570 total_surname_roots=760")
'@ | py -3.13 -X utf8 -
```

검수 시에는 이 구조 검사 외에 실제 원자료와 항목·수치를 대조했다. 폴란드 네 원본의 남녀 레코드, 독일 CSV 집계와 논문 표 4, 체코 보존본·공식 성별 목록·V4 표, 헝가리 XLSX, 우크라이나 공식 발표·Ridni 표, 슬로바키아의 남녀형 근거, 리투아니아 공식 CSV·사전 형식·보정 근거를 각각 확인했다. 정확히 일치하지 않는 자료는 각국 항목에 남겼으며 임의 합산·보정하지 않았다.

## 원본·보조물과 체크인 범위

최종 산출물은 `source_pools.json`과 이 `SOURCES.md` 두 파일이다. 다운로드 원본·메타데이터·추출 코드·검증 중간물은 사용자가 지정한 `ref/names/.cache/` 안에만 두었다. 이 캐시는 체크인 대상이 아니다. 위 URL과 각국 `sources`의 원본 링크로 다시 확인할 수 있다. 원본 SHA-256·크기는 제공된 항목과 별도 `.cache` 메타데이터에 기록했으며 모든 `sources` 항목에 이 필드가 있는 것은 아니다. 라이선스 미확인은 명시된 그대로 남겼으며 원문 전체의 재배포 허가로 해석하지 않았다.

이번 수집의 국가별 캐시(`pl_*`, `de_*`, `cz_*`, `uk_*`, `sk_*`, `hu_*`, `lt_*`) 크기는 완료 시점 합계 **65,650,927바이트**다. 소스 원본과 작은 검증 중간물이 포함된 값이다. 캐시를 삭제하지 않았으며, 통합 검수 후 정리할 수 있는 대상으로 남겼다. 다른 작업자가 만든 파일은 이 수량에서 제외했다.
