# 증기기관차 운용 레퍼런스

## 범위와 읽는 법

볼슈틴 증기 차고의 차량과 실제 증기철도 운용을 조사한 참고 문서다. 기관사·화부의 작업, 연료와 물, 겨울 운용, 공기 제동, 제설, 정비를 다룬다. 게임 수치나 연구 효과를 결정하지 않는다. 작업 범위와 기존 결정은 [작업 명세][task], [설계 결정][decisions], [기관 지식 설정][knowledge]을 따른다.

자료의 성격을 다음과 같이 구분한다.

- **확인한 제원·절차:** 운영기관의 정비 문서, 소장 목록, 교육 자료에 실제로 기재된 내용이다. 특정 차량의 현재 상태까지 보증하는 뜻은 아니다.
- **현장 취재 대략값:** 운행 현장을 취재한 원자료의 수치다. 계측 시험과 구분한다.
- **계산 예시:** 출처의 수치에 명시한 가정을 적용한 산술이다. 실측값이나 게임 권장값이 아니다.
- **미확인:** 자료가 없거나, 조건이 빠졌거나, 자료 사이의 차이를 해소하지 못했다. 임의의 평균값으로 메우지 않는다.

숫자는 해당 값에 붙인 링크에서 확인한다. 형식명·차량 번호는 식별자다. 표의 질량은 별도 표시가 없으면 연료·물을 실은 **사용상태 질량**이며, 기관차 단독과 탄수차 포함을 구분한다. 공개 카탈로그의 오래된 운행 설명보다 최근의 운영 공지를 우선한다. 외국 철도의 사례는 작동 원리와 업무를 비교하는 자료이며 폴란드의 현행 운전 규정으로 취급하지 않는다.

## 기관사와 화부의 일과

기관사는 열차의 움직임과 운행 판단을 맡고, 화부는 필요한 때에 증기를 공급할 수 있도록 불·물·연소를 관리한다. 하지만 물 높이, 압력, 선로 감시는 서로 확인해야 한다. 화부가 삽질만 하고 기관사가 조절기만 잡는 분업은 실제 업무를 지나치게 줄인다. 현대의 화부 교육에도 전방 감시, 신호 전달, 이상 보고와 기관사 유고 때 안전하게 정차시키는 능력이 들어 있다. [화부 직무 기준][fire-training] [역사적 폴란드 승무 지침][pkp-manual]

| 시점 | 기관사 중심의 일 | 화부 중심의 일 | 함께 확인하거나 차고 인력이 돕는 일 |
|---|---|---|---|
| 인수·출발 계획 | 전임자의 고장 기록, 편성·노선·구배, 제동 조건을 확인한다. 운행 가능한 상태인지 판단한다. | 남은 석탄·물, 화실과 재받이 상태, 급수 장치와 계기 상태를 확인한다. | 미해결 결함과 당일 필요한 보급을 인계한다. [검사·출발 준비 직무][prepare-training] [화부 직무][fire-training] |
| 점화 전 | 주행부, 연결봉, 체결부, 윤활부와 누설을 살핀다. 압력계·수면계 등 안전 관련 장치의 상태를 확인한다. | 화격자·재·클링커를 살피고, 확인된 수위를 바탕으로 점화 준비를 한다. 석탄의 공급 상태를 점검한다. | 보일러에 불을 넣어도 되는지를 먼저 확인한다. [소유단체의 정비·운용 자료][gwr-technical] [검사 직무][prepare-training] |
| 예열·증기 발생 | 열팽창과 누설, 윤활 및 보조 장치의 준비 상태를 확인한다. | 불층과 통풍을 조절하면서 압력과 수위를 감시한다. 급수 장치가 실제로 물을 넣는지 확인한다. | 압력이 올랐다는 이유만으로 출발 준비가 끝난 것은 아니다. 제동과 기계 상태도 갖춰야 한다. [화부 직무][fire-training] [소유단체 자료][gwr-technical] |
| 연결·출발 | 입환과 연결을 지휘하고, 제동 시험과 출발 신호를 확인한다. 조절기와 밸브기어를 다뤄 견인을 시작한다. | 출발 뒤 필요한 증기를 미리 준비하고 전방·측방 감시를 돕는다. | 실린더의 응축수와 차륜 미끄러짐에 주의한다. 차종별 절차에 따라 예열·배수를 한다. [역사적 승무 지침][pkp-manual] [제동 점검 자료][fra-steam] |
| 주행 | 속도·신호·구배·편성을 읽고 증기 공급과 팽창을 조절한다. 필요한 때 제동한다. | 압력·수위를 보며 급탄과 급수를 조절한다. 불층의 빈 곳이나 뭉친 재 때문에 연소가 나빠지는 것을 살핀다. | 오르막에 들어간 뒤에야 불을 키우면 증기 공급이 늦는다. 기관사의 운행 예고와 화부의 준비가 맞아야 한다. [기관사 교육 원전][engineers-book] [화부 직무][fire-training] |
| 중간 정차 | 열차를 고정하고 주행부 과열·이상 소음·제동 상태를 확인한다. 다음 구간과 보급 가능성을 판단한다. | 필요한 증기와 수위를 유지한다. 대기 시간에 맞춰 불을 관리하고 급수·급탄을 돕는다. | 뜨거운 기관차에는 감시가 계속 필요하다. 정차는 승무원의 작업이 사라지는 시간이 아니다. [폴란드 승무 지침][pkp-manual] [야간 화기 유지 사례][nnry-start] |
| 운행 뒤 | 결함을 기록하고 다음 승무자·정비 담당자에게 넘긴다. | 재·클링커 처리, 화실 상태 정리, 다음 운행에 맞춘 화기 유지 또는 소화 작업을 맡는다. | 볼슈틴의 실제 복귀 작업에는 급수·급탄, 윤활, 재와 연실 찌꺼기 제거가 포함된다. 차고 설비와 지원 인력이 필요한 일이다. [볼슈틴 현장 안내][wolsztyn-pit] [공식 안내 연결][wolsztyn-guide] |
| 장기 정지·정비 인계 | 운행 중 드러난 결함이 해결됐는지, 다시 출발해도 되는지 확인한다. | 차종별 절차에 따라 냉각·배수·보관을 준비한다. | 압력 경계부와 제동 장치의 수리는 작업 뒤 점검·시험까지 포함한다. [소유단체 자료][gwr-technical] [제동·보일러 검사 자료][fra-steam] |

손으로 석탄을 넣는 기관차와 기계식 급탄기가 달린 기관차는 육체노동의 양이 다르다. 볼슈틴의 Pt47 설명에는 기계식 급탄기가 등장한다. 급탄기가 있어도 화부는 연소 상태와 물을 판단해야 하므로 화부의 직무가 없어지지 않는다. [볼슈틴 Pt47 설명][cat-pt47] [화부 직무][fire-training]

## 점화, 소비와 보급

### 불을 넣은 뒤 출발까지

차가운 보일러를 데우는 시간, 전날 예열한 기관차의 아침 준비, 이미 증기가 있는 기관차의 재출발은 서로 다른 상태다. 다음 기록을 하나의 평균으로 합칠 수 없다. 보일러의 열팽창을 고려한 가열과 장치 점검이 필요하다. [화부 직무][fire-training]

| 대상·상태 | 확인된 시간 | 해석과 한계 |
|---|---|---|
| Spa Valley Railway의 완전히 식은 증기기관차 | 출발 준비까지 약 [4시간][spa-faq] | 운영기관의 일반 안내다. 형식·외기온·보일러 상태는 미확인이다. |
| [GWR 기관차 5637][gwr-technical]의 운행 전날 예열 | 작은 예열 불로 보일러를 데우며 약 [3시간][gwr-technical]을 목표로 하는 사례 | 본격적인 점화 전날의 작업이다. 냉간 상태에서 출발까지 걸리는 전체 시간으로 읽으면 안 된다. |
| Nevada Northern의 출고 준비 기록 | 점화부터 차고를 나설 때까지 [4–6시간][nnry-start] | 해당 철도의 작업 기록이다. 시작할 때의 보일러 온도는 미확인이다. |
| 볼슈틴 Ol49의 현장 취재 | 출발 전 준비 약 [1.5시간][ol49-report] | 취재 사진은 [2002-05-01][ol49-report]의 운행을 다룬다. 점화 직전 온도와 전날 불 유지 여부가 없어 **냉간 점화 시간은 미확인**이다. |
| 볼슈틴 Ol49·Pt47의 혹한기 냉간 점화 | **미확인** | 외기온·보일러 잔열·급수 온도·연료 품질을 함께 기록한 자료를 확보하지 못했다. |
| 불과 증기를 유지한 뒤 재출발 | **미확인** | 차종별 잔압과 정차 작업 조건이 필요하다. 정차 시간만으로 정할 수 없다. |

### 석탄과 물 소비의 확인 범위

| 형식·운용 조건 | 석탄 | 물 | 신뢰 범위 |
|---|---|---|---|
| Ol49, 볼슈틴–포즈난 왕복 취재 | [180 km][ol49-report] 왕복에 원문 약 [3 tons][ol49-report]; 톤의 종류는 **미확인** | 같은 왕복에 최대 약 [18,000 L][ol49-report]로 소개 | **현장 취재 대략값.** 열차 중량, 시간, 날씨, 급수 횟수와 계측 방법은 미확인이다. |
| 위 Ol49 취재 수치를 거리로 나눈 값 | 원문의 tons를 미터톤으로 해석할 경우 약 [16.7 kg/km][ol49-report] | 약 [100 L/km][ol49-report] | **계산 예시.** 석탄은 단위 해석을 가정한 값이며 확정된 형식별 소비율은 아니다. 보고된 소비량을 왕복 거리로 나눴을 뿐 모든 Ol49 운행의 평균·상한을 뜻하지 않는다. |
| Pt47, 조건을 명시한 실제 운행 | **미확인** | **미확인** | 출력이나 탄수차 크기만으로 Ol49의 소비량을 비례 확대할 근거가 없다. |
| 비교용: Tornado, 무거운 열차의 빠른 본선 운행 | 분당 [36 lb][tornado], 운영기관이 제시한 평균 | 분당 [191 L][tornado] 증발 | 다른 대형 증기기관차의 규모 비교다. 볼슈틴 형식의 값으로 대입하지 않는다. |
| 비교용: Tornado, 최대 출력 | 분당 [23 kg][tornado], 시간당 약 [1.38 t][tornado]로 환산 | 분당 [300 L][tornado] 증발, 시간당 [18 m³][tornado]로 환산 | 증발량은 급수 시설에서 취수한 총량과 구분한다. |
| Ol49·Pt47, 정차 중 불·증기 유지 | **시간당 석탄 소비 미확인** | **시간당 물 소비 미확인** | 따뜻한 대기, 객차 난방, 혹한기 보온, 밤새 약한 불 유지는 부하가 서로 다르다. |
| Ol49·Pt47, 정차/주행 소비 비율 | **미확인** | **미확인** | 같은 차량·날씨·난방·측정 시간 기준으로 비교한 자료가 필요하다. |

운영 기록에는 운행 뒤 불을 약하게 유지하고 야간에도 상태를 살피며 석탄을 보충하는 사례가 있다. 따라서 증기를 유지하는 정차에도 연료가 든다는 근거는 있지만, 이를 고정된 시간당 소비량으로 바꿀 근거는 없다. [야간 화기 유지 기록][nnry-start]

연료가 더 든다는 원인도 구분해야 한다. 견인 부하 증가, 나쁜 불층·통풍, 증기 누설, 불필요한 안전밸브 방출은 같은 현상이 아니다. 난방과 보조 장치에 쓰는 증기도 견인과 별개로 공급해야 한다. [기관사 교육 원전][engineers-book] [승무 지침][pkp-manual] [증기 압축기 복원 자료][pump-restoration]

### 급수·급탄 간격

**탄수차 용량은 보급 간격과 다르다.** 예정 구간의 소모량, 안전하게 남겨 둘 물과 석탄, 중간 급수 시설의 가동 여부를 알아야 한다. 특히 취재 자료의 왕복 소비량만으로 실제 급수 횟수나 무급수 주행거리를 확정할 수 없다. [Ol49 취재 기록][ol49-report] [출발 준비 직무][prepare-training]

| 대상 | 확인된 간격 또는 범위 | 남는 문제 |
|---|---|---|
| Ol49 | 실제 급수·급탄 간격 **미확인** | 위 취재의 왕복 중 중간 보급 여부가 명확하지 않다. |
| Pt47 | 실제 급수·급탄 간격 **미확인** | 현차 탄수차 조합과 운행별 소비 기록이 필요하다. |
| 비교용 Tornado | 물을 가득 실었을 때 운영기관이 밝힌 실용 최대 항속거리 약 [110 mile][tornado] | 다른 형식의 운영 사례다. 적재 용량만으로 계산한 최대치와 구분한다. |

보급 가능 거리를 계산하려면 `사용 가능한 잔량 ÷ 해당 조건의 거리당 소비량`을 석탄과 물에 각각 적용하고 더 먼저 부족해지는 쪽을 봐야 한다. 이는 산술적 관계이며, 현재 확보한 자료만으로 Ol49·Pt47의 실제 겨울 보급 간격을 산정할 수는 없다. 게임에서는 물을 석탄 자원에 합친다는 [기존 결정][decisions]을 유지하면서 이 공급 제약의 성격만 참고할 수 있다.

### 보일러 압력과 안전밸브

보일러 압력은 증기의 상태를 보여 주지만, 안전 여부를 단독으로 판정하지 못한다. 안전밸브는 과압을 제한하기 위해 증기를 내보낸다. 이를 더 큰 힘을 얻기 위한 조절 장치로 다루거나 임의로 설정을 바꾸는 것은 정상 운용이 아니다. 실제 개방 압력과 시험 조건은 해당 보일러의 승인·검사 자료로 확인해야 하며, 이번 조사에서 **Ol49·Pt47 현차 안전밸브의 정확한 개방·재폐쇄 압력은 미확인**이다. [폴란드 승무 지침][pkp-manual] [정비·검사 자료][gwr-technical]

**수위가 낮아 화실 상부가 충분히 냉각되지 않는 위험은 안전밸브로 해결되지 않는다.** 실제 저수위 사고 조사에서는 수위 관리와 대응 실패로 보일러가 과열됐다. 압력이 정격 이하이거나 천천히 달리고 있다는 사실만으로 보일러가 안전한 것은 아니다. 저수위·과열이 의심되는 상황의 대응은 차종별 비상 절차와 훈련의 영역이다. [철도사고조사기관의 저수위 사고 보고][raib-water]

## 볼슈틴의 형식과 제원

### 보존 목록과 현재 운행을 구분하기

공식 카탈로그에는 **Ok1, Ok22, Ol49, Ty1, Ty2, Ty42, Ty3, Ty43, Ty5, Tr5, Ty45, Ty51, Pt47, Pm36, TKt48, TKi3**가 수록돼 있다. 아래 표는 이 목록의 형식을 다룬다. 이는 모든 차량이 지금 운행 가능하다는 뜻이 아니며, 현재 가동 가능한 전체 차량 명단은 **미확인**이다. 정비 문서의 적용 형식 목록도 볼슈틴 소장 목록과 동일하지 않다. [공식 카탈로그][catalogue] [카탈로그 배포 안내][catalogue-page]

- **Pt47-65:** 공식 공지는 [2026-09-28부터 2026-10-07까지][pt47-status] 계획 정비로 정기 운행을 디젤 차량이 대체한다고 알린다. 작업 기준일인 [2026-10-05][task]는 이 공지 구간 안에 있다. 따라서 조사 시점에 증기로 정기 운행 중이라고 쓰지 않는다.
- **Ok22-31·Pm36-2:** 운영기관은 [2025-05-09][custody]에 위탁 보관 계약을 맺었으며 최소 [2035-05-31][custody]까지 볼슈틴에 남는다고 발표했다. Pm36의 운행 복귀는 정비 자금 확보가 필요한 과제로 설명한다.
- **Ol49와 나머지 형식:** 공식 카탈로그의 보존·소장 근거는 확인했다. 개별 차량의 현재 검사 유효기간과 즉시 출고 가능 여부는 **미확인**이다. 카탈로그의 과거 운행 서술을 오늘의 가동 상태로 옮기지 않는다. [카탈로그][catalogue]

### 정비 문서에 제시된 주요 형식

축 배치는 **앞쪽 비동력축–동력축–뒤쪽 비동력축의 축 수**다. 바퀴 수를 세는 표기와 다르다. 압력은 보일러의 게이지압이다. 출력은 정비 문서가 적은 **명목 출력**이며, 지시출력·차륜출력·견인봉출력 중 무엇인지는 **미확인**이다. 최고속도는 형식 제원으로, 보존차의 현재 허용속도나 훼손된 선로에서의 안전속도가 아니다. [정비 문서][dsu]

아래 표는 단위 환산 혼동을 줄이기 위해 정비 문서의 질량 단위인 kg을 유지한다. 물도 원문의 **질량**이다.

| 기관차 + 탄수차 | 축 배치 | 보일러 압력 | 명목 출력 | 최고속도 | 석탄 적재 | 물 적재 | 기관차 질량 | 탄수차 포함 질량 |
|---|---|---|---|---|---|---|---|---|
| [Ol49 + 25D49][dsu-ol49] | [1-3-1][dsu-ol49] | [1.6 MPa][dsu-ol49] | [949 kW][dsu-ol49] | [100 km/h][dsu-ol49] | [12,000 kg][dsu-ol49] | [25,000 kg][dsu-ol49] | [82,900 kg][dsu-ol49] | [144,900 kg][dsu-ol49] |
| [Pt47 + 33D48][dsu-pt47] | [1-4-1][dsu-pt47] | [1.5 MPa][dsu-pt47] | [1,470 kW][dsu-pt47] | [110 km/h][dsu-pt47] | [17,000 kg][dsu-pt47] | [33,000 kg][dsu-pt47] | [104,200 kg][dsu-pt47] | [182,100 kg][dsu-pt47] |
| [Pt47 + 34D48][dsu-pt47] | [1-4-1][dsu-pt47] | [1.5 MPa][dsu-pt47] | [1,470 kW][dsu-pt47] | [110 km/h][dsu-pt47] | [10,000 kg][dsu-pt47] | [34,000 kg][dsu-pt47] | [104,200 kg][dsu-pt47] | [178,400 kg][dsu-pt47] |
| [Pm36 + 32D36][dsu-pm36] | [2-3-1][dsu-pm36] | [1.8 MPa][dsu-pm36] | [1,323 kW][dsu-pm36] | [130 km/h][dsu-pm36] | [9,000 kg][dsu-pm36] | [32,000 kg][dsu-pm36] | [94,000 kg][dsu-pm36] | [161,500 kg][dsu-pm36] |
| [Tr5 + 17C1][dsu-tr5] | [1-4-0][dsu-tr5] | [1.4 MPa][dsu-tr5] | [596 kW][dsu-tr5] | [70 km/h][dsu-tr5] | [7,000 kg][dsu-tr5] | [16,500 kg][dsu-tr5] | [74,600 kg][dsu-tr5] | [120,100 kg][dsu-tr5] |
| [Ok1 + 22D2][dsu-ok1] | [2-3-0][dsu-ok1] | [1.2 MPa][dsu-ok1] | [662 kW][dsu-ok1] | [100 km/h][dsu-ok1] | [7,000 kg][dsu-ok1] | [21,500 kg][dsu-ok1] | [78,200 kg][dsu-ok1] | [129,700 kg][dsu-ok1] |
| [Ok22 + 22D23][dsu-ok22] | [2-3-0][dsu-ok22] | [1.2 MPa][dsu-ok22] | [721 kW][dsu-ok22] | [100 km/h][dsu-ok22] | [10,000 kg][dsu-ok22] | [21,500 kg][dsu-ok22] | [78,900 kg][dsu-ok22] | [133,000 kg][dsu-ok22] |
| [TKt48, 탄수차 없음][dsu-tkt48] | [1-4-1][dsu-tkt48] | [1.6 MPa][dsu-tkt48] | **미확인: 자료 상충** | [80 km/h][dsu-tkt48] | [6,000 kg][dsu-tkt48] | [10,000 kg][dsu-tkt48] | [98,000 kg][dsu-tkt48] | 해당 없음 |

### 나머지 보존 형식의 비교 제원

카탈로그와 철도 운영기관의 박물관 자료를 사용했다. 이 표의 물은 **부피**다. 출력의 측정 기준은 모두 **미확인**이며, 각 볼슈틴 보존차의 현재 탄수차 조합과 일치하는지도 별도 확인이 필요하다. 압력의 `at`는 원자료의 기술기압 표기를 보존한 것으로, MPa·bar와 수치만 맞춰 바꾸지 않는다. [카탈로그][catalogue] [박물관의 Ty2 제원][museum-ty2]

| 형식·자료의 탄수차 | 축 배치 | 보일러 압력 | 출력 | 최고속도 | 석탄 / 물 | 기관차 / 탄수차 포함 질량 |
|---|---|---|---|---|---|---|
| [Ty1 + 20C1][cat-ty1] | [1-5-0][cat-ty1] | [1.4 MPa][cat-ty1] | [1,413 kW][cat-ty1] | [65 km/h][cat-ty1] | [6 t / 20 m³][cat-ty1] | [95.7 / 141.3 t][cat-ty1] |
| [Ty2·Ty42 + 30D42][cat-ty2] | [1-5-0][cat-ty2] | [16 at][museum-ty2] | **미확인: 자료 상충** | [80 km/h][museum-ty2] | [8 또는 10 t / 30 m³][museum-ty2] | [86.1 / 146.9 t][museum-ty2], Ty2 자료 기준; Ty42 현차 질량은 미확인 |
| [Ty3·Ty43, 묶음 제원][cat-ty3] | [1-5-0][cat-ty3] | [1.6 MPa][cat-ty3] | [1,350 kW][cat-ty3] | [80 km/h][museum-ty43] | [10 t / 30 m³][cat-ty3], 현차 조합 미확인 | [96 t][museum-ty43] / **미확인: 합계 불일치** |
| [Ty5 + 26D5][cat-ty5] | [1-5-0][cat-ty5] | [1.6 MPa][cat-ty5] | **미확인**: 원문 [1,273 PS][cat-ty5] 표기의 추가 검증 필요 | [80 km/h][cat-ty5] | [8 t / 26 m³][cat-ty5] | [86.85 t][cat-ty5] / **미확인: 합계 불일치** |
| [Ty45 + 32D47][cat-ty45] | [1-5-0][cat-ty45] | [1.6 MPa][cat-ty45] | [1,266 kW][cat-ty45] | [75 km/h][museum-ty45] | [12 t / 32 m³][cat-ty45] | [97.5 t][museum-ty45] / [163.1 t][cat-ty45] |
| [Ty51 + 27D51][museum-ty51] | [1-5-0][cat-ty51] | [16 at][museum-ty51] | [2,160 KM][museum-ty51], 원문 마력 단위 | [80 km/h][museum-ty51] | [20.5 t / 27 m³][museum-ty51] | [109.9 t][cat-ty51] / [188.9 t][museum-ty51] |
| [TKi3, 탄수차 없음][cat-tki3] | [1-3-0][cat-tki3] | [1.2 MPa][cat-tki3] | [460 kW][cat-tki3] | [65 km/h][cat-tki3] | [2 t / 7 m³][cat-tki3] | [59 t][cat-tki3] / 해당 없음 |

Ty42 자료는 Ty2와 같은 기술 제원을 사용한다고 설명한다. Ty43 자료도 Ty3 계열과의 관계를 설명한다. 묶음 행은 그 계열의 비교용이며 개별 차량의 개조 상태까지 동일하다는 뜻은 아니다. [Ty42 설명][museum-ty42] [Ty43 설명][museum-ty43]

### 수치가 충돌하거나 현차와 달라질 수 있는 곳

| 항목 | 확인한 차이 | 문서에서의 처리 |
|---|---|---|
| Ol49 사용상태 질량 | 정비 문서 [82,900 kg][dsu-ol49], 카탈로그 [83.25 t][cat-ol49] | 주표는 정비 문서를 따른다. 박물관도 [82.9 t][museum-ol49]를 제시한다. 차이의 원인과 현차 실측값은 **미확인**이다. |
| Pt47 출력과 질량 | 정비 문서 [1,470 kW·104,200 kg][dsu-pt47], 카탈로그 [1,200 kW·103 t][cat-pt47] | 주표는 정비 문서의 명목값이다. 출력 정의·차량 상태에 따른 차이인지 오류인지 **미확인**이다. |
| Pt47 탄수차 | 정비 문서의 [33D48·34D48][dsu-pt47], 카탈로그의 [27D48][cat-pt47], 실제 정비 공고의 [Pt47-65 + 34D74-42][pt47-tender]가 다르다. | 현차의 석탄·물 용량과 총중량은 **미확인**이다. 위 형식 표의 용량을 현재 차량의 적재량으로 확정하지 않는다. |
| Ok1 출력 | 정비 문서 [662 kW][dsu-ok1], 카탈로그 [1,180 kW][cat-ok1] | 주표는 정비 문서를 따른다. 차이의 원인은 **미확인**이다. |
| TKt48 출력 | 정비 문서 [78 kW][dsu-tkt48], 카탈로그 [785 kW][cat-tkt48], 박물관 [1,060 KM][museum-tkt48] | 오기 가능성은 있으나 원인은 **미확인**이다. 정비 문서의 값을 임의로 고치지 않는다. |
| Ty2·Ty42 출력·질량 | 출력은 정비 문서 [787 kW][dsu-ty2], 카탈로그 [1,200 kW][cat-ty2]다. Ty42 정비 문서의 기관차 [85,000 kg][dsu-ty42]·탄수차 포함 [145,800 kg][dsu-ty42]는 박물관의 Ty2 제원과 다르다. | 공통된 출력값과 현재 차량의 정확한 질량은 **미확인**으로 둔다. |
| 카탈로그의 질량 합계 | Ty3·Ty43은 기관차 [96 t][cat-ty3]와 탄수차 [60.8 t][cat-ty3]에 대해 전체 [158 t][cat-ty3]를 제시한다. Ty5도 기관차 [86.85 t][cat-ty5]와 탄수차 [59.5 t][cat-ty5]에 대해 전체 [140.35 t][cat-ty5]를 제시한다. | 같은 사용상태 항목의 합이 맞지 않는다. 전체 질량을 추정해 보정하지 않고 **미확인**으로 둔다. |
| 그 밖의 카탈로그 비교 | [Pm36의 기관차·탄수차·합계][cat-pm36]도 일치하지 않으며, Ty51의 탄수차 질량은 카탈로그 [79.5 t][cat-ty51]와 박물관 [79.0 t][museum-ty51]가 다르다. | 해당 표에 선택한 출처를 유지한다. 개별 차량의 실제 질량과 차이의 원인은 **미확인**이다. |

## 겨울 운용

추위의 문제는 보일러가 증기를 만드는지에만 있지 않다. 물이 남은 가는 배관, 급수 설비, 압축공기 안의 응축수, 윤활과 선로 설비가 함께 영향을 받는다. 역사적 폴란드 승무 지침도 급수 장치와 배관의 보온, 윤활, 응축수 처리를 따로 다룬다. [폴란드 승무 지침][pkp-manual]

| 문제 | 기계·운용에 생기는 일 | 실제 대응의 방향과 한계 |
|---|---|---|
| 인젝터·급수관 결빙 | 보일러에 증기가 있어도 인젝터까지 물이 오지 않거나 물길이 막힐 수 있다. | 사용하지 않는 인젝터의 공급관도 관리 대상이다. 형식에 맞는 보온·예열·순환과 배수가 필요하다. 외국 매뉴얼의 밸브 조작 순서를 폴란드 차량에 그대로 옮길 수는 없다. [화부 핸드북][nsrm-fireman] [폴란드 승무 지침][pkp-manual] |
| 인젝터 작동 불량 | 인젝터는 증기 분사와 응축을 이용해 물을 보일러로 밀어 넣는다. 공급수 과열, 공기 유입, 막힘도 작동을 방해한다. | 물이 안 들어가는 원인을 모두 결빙으로 판단해서 계속 가열하면 안 된다. 동결 여부와 공급수·누설·막힘을 구분해야 한다. [인젝터 설명·고장 항목][nsrm-fireman] |
| 급수탑·급수전 결빙 | 물이 있어도 급수 배관이 얼면 공급이 막힌다. | 급수관을 목제 동결 방지함으로 둘러싼 실제 조사 사례가 있다. 증기차고 박물관은 관의 단열과 급수탑을 감싼 난방 구조물도 설명한다. 볼슈틴 설비의 혹한기 가동 한계·해빙 시간은 **미확인**이다. [급수탱크 현장 조사][water-tank-survey] [박물관의 급수 설비 설명][water-tank-heating] |
| 공기 제동 계통의 수분 | 응축수가 고이거나 얼면 공기 흐름과 장치 작동을 방해할 수 있다. | 저장통·배관의 수분 배출과 누설 점검이 정비 업무에 포함된다. 동결 부위 확인 없이 압력을 올리는 것은 수리가 아니다. [폴란드 승무 지침][pkp-manual] [제동 점검 자료][fra-steam] |
| 실린더·증기관의 응축수 | 차가운 기계에 증기가 들어가면서 물이 생긴다. 물은 증기처럼 압축되지 않아 기계에 부담을 준다. | 출발 전 예열과 차종별 배수 절차가 필요하다. 실제 필요한 시간은 **미확인**이다. [폴란드 승무 지침][pkp-manual] |
| 차가운 윤활유·결빙한 주변부 | 윤활 공급과 움직임이 나빠질 수 있다. | 적절한 윤활제와 예열 상태를 점검한다. 따뜻할 때의 점검만으로 추운 출발 조건을 확인했다고 볼 수 없다. [소유단체 정비 자료][gwr-technical] [폴란드 승무 지침][pkp-manual] |
| 눈과 얼음의 선로 막힘 | 레일 주변뿐 아니라 분기기와 틈에 눈·얼음이 들어가 움직임을 막는다. | 분기기의 제빙·가열·제설은 기관차 앞의 제설기와 별도 작업이다. 눈사태 잔해에는 돌·얼음·다른 장애물도 섞일 수 있다. [선로 운영기관 안내][network-snow] [겨울 장비 안내][network-fleet] |
| 밤샘·긴 정차 | 불 유지에는 연료와 감시 인력이 들고, 완전히 식히면 재가열과 동결 관리가 필요하다. | 운행을 이어갈 때의 화기 유지와 장기 보관을 위한 소화·배수는 다른 작업이다. [야간 화기 유지 사례][nnry-start] [냉간 보관 자료][gwr-technical] |
| 짧은 해빙기 뒤 재동결 | 녹은 물이 고이는 배관·설비는 다음 한파의 점검 대상이 된다. | **자료에서 도출한 운용상 추론:** 해빙을 단순한 운행 보너스로 보기보다 배수·누설·급수 시설을 확인할 기회로 볼 수 있다. 효과의 수치는 **미확인**이다. [동결 방지 설비][water-tank-survey] [냉간 보관 자료][gwr-technical] |

불을 유지한다고 탄수차의 모든 관, 쓰지 않는 급수전, 객차 끝의 배관까지 저절로 안전해지는 것은 아니다. 보일러 보온과 외부 설비의 동결 방지는 연결되지만 별도의 관리 업무다. [화부 핸드북][nsrm-fireman] [급수 설비의 동결 방지][water-tank-heating]

## 공기 제동과 증기로 구동하는 압축기

### 무엇이 무엇을 움직이는가

증기 구동 공기 압축기는 보일러의 증기로 피스톤을 움직이고, 그 운동으로 외부 공기를 압축한다. 증기는 동력원이고 공기 저장통에 모으는 매체는 압축공기다. 조압기는 저장통 압력에 따라 압축기로 들어가는 증기를 조절한다. 보일러 압력과 공기 저장통 압력은 별개다. [철도박물관의 압축기 복원 기록][pump-restoration]

자동 공기 제동에서는 기관사가 제동관 압력을 낮추면 차량의 제어밸브가 이를 감지하고 보조 공기통의 공기를 제동 실린더로 보낸다. 제동관을 다시 충전하면 제동을 푼다. 따라서 “관의 압력을 높일수록 더 세게 제동한다”는 식으로 이해하면 틀린다. 압축기 공급이 끊겨도 저장된 공기로 작동할 수 있지만, 반복 제동 뒤에는 재충전이 필요하므로 공급 능력과 잔압이 중요하다. [폴란드 공기 제동 용어·원리 자료][polish-brakes]

| 항목 | 공개 자료의 값 | 해석 |
|---|---|---|
| Ol49의 압축기 | [H11a3, 120 m³/h, 정격 0.8 MPa][dsu-ol49] | 유량의 기준 상태가 자유공기량인지 압축된 상태의 부피인지 **미확인**이다. |
| Pt47의 압축기 | [H11a3/H11a4, 120 m³/h, 정격 0.8 MPa][dsu-pt47] | 복수 형식과 유량이 함께 적혀 있다. 현재 장착품의 실측 유량은 **미확인**이다. |
| 비교용 Pm36의 압축기 | [H11a4, 180 m³/h, 정격 0.8 MPa][dsu-pm36] | Pt47의 장착품에 이 유량을 자동 적용하지 않는다. |
| 정비 시험표의 압축기 항목 | 정격압 [0.8 ± 0.01 MPa][dsu-compressor], 유량 [120 / 180 m³/h][dsu-compressor] | 검사용 요구값이다. 노후·혹한 상태의 실제 성능이 아니다. |
| 주 공기통 / 제동관 / 제동 실린더 | 계기 최대압 표시 확인값 [0.80 / 0.50 / 0.40 MPa][dsu-brakes] | 항상 동시에 유지되는 작동압을 뜻하지 않는다. 폴란드 교육 자료의 제동 해제 상태 제동관 압력은 [0.5 MPa][polish-brakes]다. |
| Ol49·Pt47 주 공기통 | 각각 [400 dm³짜리 2개][dsu-reservoir] | 합계 [800 L][dsu-reservoir]는 계산값이다. 제동용 저장 용량이며 무기용 탱크 제원이 아니다. |

공기통의 물·기름 배출, 누설, 윤활과 조압기 상태를 보아야 한다. 오래 세워 둔 압축기에서도 부식으로 피스톤 로드와 밀봉부가 손상된 복원 사례가 있다. [볼슈틴 공압계통 정비 항목][dsu-pneumatic] [보존철도의 공기펌프 정비 기록][bluebell-pump]

## 배장기, 쐐기형 제설기와 고장

### 앞에 달린 장치는 같은 역할을 하지 않는다

| 장치 | 역할 | 한계와 기관차의 부담 |
|---|---|---|
| 배장기·파일럿, 게임의 불바를 비교할 때의 출발점 | 레일 앞의 물체가 차륜 아래로 들어가는 것을 줄이도록 옆으로 밀어내는 앞쪽 구조물이다. | 단순한 막대나 배장기를 깊은 눈용 제설기와 동일시할 근거는 없다. 실제 고정 방식과 구조 상태가 중요하다. [철도 보존단체의 배장기 복원 자료][pilot] |
| 쐐기형 제설기 | 쐐기로 눈을 갈라 선로 옆으로 밀어낸다. 전용 제설차는 기관차가 밀고, 날개로 더 넓게 치우기도 한다. | 견인력을 제설 저항에 써야 하며, 옆에 밀어낼 공간과 숨은 장애물이 문제가 된다. 앞에 부착한 소형 날과 전용 제설차는 같은 규모의 장비가 아니다. [철도박물관의 쐐기 제설차][wedge] [겨울 장비 안내][network-fleet] |
| 회전식 제설기 | 회전 날로 눈을 잘라 멀리 배출한다. 증기식 회전 날의 동력과 차량을 전진시키는 견인은 구분된다. | 별도의 기계·연료·운용·정비 부담이 생긴다. 비교용 장비이며 게임의 연구 항목을 추가한다는 뜻은 아니다. [철도박물관의 제설 장비 설명][rotary] |

Network Rail은 제설 장치가 없는 열차에 대해 선로 위 눈이 [30 cm][network-snow]를 넘으면 안전한 운행이 어려워질 수 있다고 안내한다. 이는 해당 운영기관의 안내로, **Ol49·Pt47 또는 임의의 쐐기형 제설기의 한계 깊이는 미확인**이다. 눈의 밀도·수분·얼어붙은 층·옆으로 밀어낼 공간·선로 형태가 다르면 같은 깊이에서도 부담이 달라진다. 실제 산악 철도는 상황에 따라 여러 제설 장비를 조합한다. [운영기관의 눈 대응][network-snow] [산악 철도의 제설 기록][up-snow]

### 흔한 문제와 수리 범위

여기서 현장 작업은 상태를 판단할 수 있는 숙련자와 적합한 공구·부품이 있다는 전제다. 기계와 압력 장치를 안전하게 격리한 뒤 하는 청소·교환도 포함한다. **현장과 차고의 구분은 정비 항목과 필요한 설비를 바탕으로 한 해석**이며, 특정 차량의 공식 현장 수리 허용 목록은 아니다. 차고 작업에는 분해·가공뿐 아니라 수리 후 시험과 재검사가 포함된다. 결함을 잠시 덜 드러나게 만드는 것과 운행 가능한 상태로 수리하는 것은 구분해야 한다. [정비·검사 자료][gwr-technical] [보일러·제동 검사 자료][fra-steam]

| 문제·징후 | 현장에서 가능한 범위 | 차고·전문 설비가 필요한 경계 |
|---|---|---|
| 불층 불균일, 재·클링커로 통풍 저하 | 원인을 확인하고 화실·재받이를 관리한다. 화부가 급탄과 통풍을 조절한다. [기관사 교육 원전][engineers-book] | 화격자·화실 구조의 손상이나 반복되는 이상은 정비가 필요하다. [소유단체 자료][gwr-technical] |
| 인젝터가 물을 넣지 못함 | 공급수, 결빙, 공기 유입, 외부 막힘 등 접근 가능한 원인을 확인한다. 가능한 청소·해빙·건전한 장치로의 전환은 차종별 절차를 따른다. [화부 핸드북][nsrm-fireman] | 노즐·밸브의 손상, 원인을 못 찾은 급수 실패, 수면계 이상은 운행을 계속할 근거가 되지 않는다. 분해·시험이 필요할 수 있다. [화부 핸드북][nsrm-fireman] [저수위 사고 조사][raib-water] |
| 제동 호스·연결부 누설 | 결함 위치를 찾고 적합한 교환품으로 수리할 수 있는 연결부를 다룬 뒤 제동 시험을 한다. [제동 점검 자료][fra-steam] | 공기통 균열·부식, 제어밸브 내부 결함, 압력 시험이 필요한 손상은 전문 정비 대상이다. [제동 검사 자료][fra-steam] |
| 압축기 출력 저하·불규칙 운전 | 윤활·공급·누설·응축수 상태를 점검한다. [압축기 구조 자료][pump-restoration] [볼슈틴 정비 항목][dsu-pneumatic] | 마모된 실린더·밸브, 부식한 로드·밀봉면은 분해·가공·부품 제작이 필요할 수 있다. [공기펌프 복원 사례][bluebell-pump] |
| 축상·베어링 과열, 주행부 소음 | 정차해 원인을 살피고 윤활 상태와 손상 여부를 확인한다. 윤활 보충만으로 해결됐다고 단정하지 않는다. [실제 과열·차축 수리 기록][nnry-axle] | 균열 차축, 손상된 베어링과 주행부는 차축 분리·가공·교체가 필요할 수 있다. [같은 수리 기록][nnry-axle] |
| 보일러 누설·화실 손상·저수위 과열 | 이상을 확인하면 운행을 멈추고 해당 비상·정비 절차로 넘긴다. 압력이 걸린 마개를 조여 해결하는 식의 작업은 피한다. [소유단체 자료][gwr-technical] | 압력 경계부 수리, 화실·관 교체, 균열 검사와 압력 시험은 전문 정비 대상이다. [보일러 검사 자료][fra-steam] [저수위 사고 조사][raib-water] |
| 제설기·앞쪽 구조물 변형 | 눈과 이물질, 보이는 체결부 및 선로 간섭을 확인한다. | 휘어진 장착부와 구조 균열, 프레임 손상은 단순 재체결로 복구됐다고 볼 수 없다. **자료에서 도출한 정비상 추론**이다. [배장기 복원 사례][pilot] |

위 문제들은 정비 자료에 반복해서 등장하는 고장 유형이다. **형식별 고장 발생 빈도, 야외 수리 성공률과 평균 수리 시간은 미확인**이다. 장인이 있어도 선반·인양 설비·시험 장비·적합한 재료의 역할이 없어지지는 않는다. 실제 보존기관차의 운행 복귀에는 보일러, 주행부, 제동 장치의 폭넓은 정비가 필요했다. [박물관의 Pt47 복원 설명][museum-pt47] [차축 수리 기록][nnry-axle]

## 남은 미확인과 후속 확인에 필요한 자료

| 미확인 항목 | 확인하려면 필요한 자료 |
|---|---|
| Ol49·Pt47의 냉간 점화, 예열, 재출발 시간 | 시작 수온·잔압·외기온과 작업 범위를 적은 실제 운전 일지 |
| Pt47의 운행 소비와 두 형식의 정차 소비·정차/주행 비율 | 같은 차량의 석탄·물 보급 계측, 거리·시간·편성·구배·난방·날씨 기록 |
| Ol49 취재 자료의 석탄 질량 단위 | 원문 tons가 미터톤인지 밝히는 취재 원기록 |
| 실제 급수·급탄 간격과 겨울 예비량 | 노선별 급수 시설, 운전 일지, 잔량 기준 |
| 현차 탄수차 적재량·중량, 보존차의 현재 출고 가능 여부 | 차량별 정비대장·검사 상태·실측 제원 |
| 출력·질량 자료 상충 | 제조·시험 기록과 개조 이력, 출력 측정 기준 |
| 현차 안전밸브 개방·재폐쇄 압력 | 해당 보일러의 검사·조정 기록 |
| 혹한기 온도 한계, 급수 설비 해빙 시간 | 설비별 동결 방지 구조와 기온별 운용 기록 |
| 제설기별 통과 가능한 눈 깊이, 추가 연료와 구조 하중 | 특정 제설기·부착 구조·눈 상태에 대한 운용 또는 시험 기록 |
| 압축기 유량의 기준 상태, 실제 남는 공급량, 추가 증기·석탄 소비 | 장착 압축기의 성능곡선, 자유공기량 기준, 제동·누설·보조 부하 측정 |
| 공기총 탱크의 충전 시간·소음·기관 부담 | 게임에서 아직 정하지 않은 탱크 조건과 실제 압축기 여유량. 무기의 성능 수치로 대신 채우지 않는다. |
| 고장 빈도·수리 시간·숙련도별 성공률 | 정비 이력과 교육·작업 관찰 기록 |

검색 중 나온 다른 게임의 기관차 수치는 실제 운용 근거에서 제외했다. 물리 계산도 입력 조건이 확인되지 않으면 실제 성능으로 취급하지 않는다.

### 출처 위치 안내

핵심 제원은 볼슈틴이 공개한 [정비 문서][dsu]와 [공식 카탈로그][catalogue]에서 확인했다. 카탈로그 링크의 페이지는 PDF 파일의 페이지 위치이며 인쇄된 쪽수와 다를 수 있다. 작업·정비·겨울 설명은 본문의 운영기관·박물관·교육기관·사고조사기관 링크에서 확인할 수 있다. 모든 설명은 사실을 한국어로 다시 정리했으며 원문 문장이나 사진을 옮기지 않았다.

[task]: https://github.com/wndi1130-dot/APP/blob/c0127c50152b24fd910e46e11db1be1ce5ab5a65/docs/handoff/codex_tasks.md
[decisions]: https://github.com/wndi1130-dot/APP/blob/c0127c50152b24fd910e46e11db1be1ce5ab5a65/docs/design/decisions.md
[knowledge]: https://github.com/wndi1130-dot/APP/blob/c0127c50152b24fd910e46e11db1be1ce5ab5a65/docs/design/briefs/knowledge_system.md
[production]: https://github.com/wndi1130-dot/APP/blob/c0127c50152b24fd910e46e11db1be1ce5ab5a65/docs/design/briefs/production_research.md
[catalogue-page]: https://parowozowniawolsztyn.pl/?page_id=2224
[catalogue]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf
[cat-ok1]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=4
[cat-ol49]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=6
[cat-ty1]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=7
[cat-ty2]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=8
[cat-ty3]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=9
[cat-ty5]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=10
[cat-ty45]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=12
[cat-ty51]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=13
[cat-pt47]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=14
[cat-pm36]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=15
[cat-tkt48]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=16
[cat-tki3]: https://parowozowniawolsztyn.pl/wp-content/uploads/2024/10/ebook.pdf#page=17
[dsu]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf
[dsu-ol49]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=7
[dsu-pt47]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=8
[dsu-pm36]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=9
[dsu-tr5]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=10
[dsu-ok1]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=11
[dsu-ok22]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=12
[dsu-ty2]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=17
[dsu-ty42]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=18
[dsu-tkt48]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=19
[dsu-pneumatic]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=53
[dsu-brakes]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=75
[dsu-compressor]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=161
[dsu-reservoir]: https://bip.parowozowniawolsztyn.pl/dokumenty/zamowienia_publiczne/przetarg_publiczny_PES.2.26.3.2020/Zalacznik-nr-8-do-SIWZ-Dokumentacja-Systemu-Utrzymania-lokomotyw-parowych-PW_PES.2.26.3.2020.pdf#page=182
[pt47-status]: https://parowozowniawolsztyn.pl/?p=3606
[pt47-tender]: https://bip.parowozowniawolsztyn.pl/przetarg_publiczny_PPZ.265.6.2025.htm
[custody]: https://parowozowniawolsztyn.pl/?p=2630
[museum-ol49]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/ol49/
[museum-pt47]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/pt47/
[museum-tkt48]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/tkt48/
[museum-ty2]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/ty2/
[museum-ty42]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/ty42/
[museum-ty43]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/ty43/
[museum-ty45]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/ty45/
[museum-ty51]: https://www.parowozy.pl/ekspozycja/lokomotywy-parowe/ty51/
[ol49-report]: https://www.worldpressphoto.org/collection/photo-contest/2003/witold-krassowski/4
[tornado]: https://www.a1steam.com/tornado/about-tornado/tornado-facts-figures
[spa-faq]: https://spavalleyrailway.co.uk/faqs/
[gwr-technical]: https://5637.co.uk/technical/
[nnry-start]: https://nnry.com/museum-update-2/
[nnry-axle]: https://nnry.com/no-93-one-lucky-steam-locomotive/
[fire-training]: https://training.gov.au/training/details/TLIC3073
[prepare-training]: https://tps.dtwd.wa.gov.au/unit-of-competency/48f9aadd-44e7-4d5f-a9b8-97c1f8c03419
[pkp-manual]: https://parowozy.com.pl/pdf/podrecznik_1926.pdf
[engineers-book]: https://www.gutenberg.org/cache/epub/17783/pg17783-images.html
[raib-water]: https://www.gov.uk/raib-reports/boiler-incident-on-the-kirklees-light-railway
[wolsztyn-pit]: https://www.poznajhistorie.pl/monument/wolsztyn-kanal
[wolsztyn-guide]: https://parowozowniawolsztyn.pl/?page_id=2188
[nsrm-fireman]: https://nsrm-friends.org/manuals/ST-05-Fireman%20Handbook.pdf
[water-tank-survey]: https://npgallery.nps.gov/GetAsset/8e6a6a46-44fe-4559-b783-32dc99568775#page=5
[water-tank-heating]: https://ageofsteamroundhouse.org/collections/other-than-a-steam-loco-nothing-says-old-time-railroading-more-than-a-wooden-water-tank-part-2/
[fra-steam]: https://www.govinfo.gov/content/pkg/CFR-2024-title49-vol4/pdf/CFR-2024-title49-vol4-part230-subpartC.pdf
[network-snow]: https://www.networkrail.co.uk/rail-travel/delays-explained/snow-and-ice/
[network-fleet]: https://www.networkrail.co.uk/stories/five-things-you-didnt-know-about-our-winter-fleet/
[polish-brakes]: https://zpe.gov.pl/a/slownik-pojec-dla-e-materialu/DckjzjCMy
[pump-restoration]: https://blog.railwaymuseum.org.uk/sir-nigel-gresley-overhaul-update-17/
[bluebell-pump]: https://bluebell-railway.co.uk/bluebell/locos/vt/473/air_pump.html
[pilot]: https://www.friendsofno9.org/post/restoration-update-reconstructing-no-9-s-pilot-cowcatcher
[wedge]: https://www.irm.org/player/cgwx38/
[rotary]: https://coloradorailroadmuseum.org/snowplows/
[up-snow]: https://www.up.com/news/people/sierra-snow-fighters-it-230203
[air-manual]: https://www.atlascopco.com/content/dam/atlas-copco/local-countries/australia/documents/Compressed-Air-Manual-9th-edition_compressed.pdf

## 게임과 닿는 곳

이 절은 실제 운용에서 이어지는 관찰과 조건부 계산이다. 볼슈틴에서 출발한 열차, 붕괴 후 [여섯 번째 겨울][decisions], 짧은 해빙기, 물을 석탄에 합친 자원 체계는 주어진 설정으로 둔다. [기존 결정][decisions]

### 석탄 경제: 달릴 때와 정차할 때

증기를 유지하는 정차에는 연료와 감시가 필요하다. 달릴 때는 여기에 견인에 필요한 증기가 더해진다. 따라서 단순히 이동 거리만 셀 경우 긴 정차·난방·재가열 비용이 빠진다. 그러나 **정차 소비가 주행 소비의 얼마라는 비율은 미확인**이다. 뜨거운 대기와 혹한기 난방, 약한 불의 야간 유지는 같은 정차 상태가 아니다. [야간 유지 기록][nnry-start] [운행 증기 관리][engineers-book]

**자료에서 도출한 관계:** 같은 편성과 노선에서 더 큰 견인 출력을 요구하면 증기 공급 부담이 커진다. 반면 천천히 가면 이동 시간이 길어져 시간에 따라 드는 보온·보조 장치 비용이 누적된다. 속도만으로 소비가 선형 증가한다고 하거나 가장 느린 속도가 언제나 가장 경제적이라고 정할 근거는 없다. 재가속, 구배, 미끄러짐, 급탄과 급수의 조화도 중요하다. 실제로 쓸 속도별 소비 곡선은 **미확인**이다. [기관사 교육 원전][engineers-book] [실제 대형 기관차 소비 자료][tornado]

물 부족은 실제로 출발과 안전을 제한한다. 게임에서 물을 별도 자원으로 분리하지 않아도 급수 설비 고장, 정차 보급, 증기 낭비가 석탄 경제와 이어진다는 사실은 참고할 수 있다. 추상화 비율은 이 문서에서 정하지 않는다. [저수위 사고 조사][raib-water] [기존 자원 결정][decisions]

### 제설: 깊이 외에 무엇이 부담을 바꾸는가

기존 설정의 쐐기형 제설기 [연구 2단계][production]는 눈을 옆으로 밀어내는 장치의 원리와 연결된다. 하지만 통과 가능한 깊이는 제설기 모양만으로 결정되지 않는다. 젖은 눈·얼어붙은 덩어리·밀려 쌓인 눈·옆으로 버릴 공간·분기기 상태를 함께 봐야 한다. 쐐기형 장치의 깊이별 성공률이나 연료 배수는 **미확인**이다. [쐐기 제설차][wedge] [산악 철도의 제설][up-snow] [선로 동결][network-snow]

**자료에서 도출한 관계:** 눈을 밀어내는 저항은 기관차의 견인 여유를 줄이고, 미끄러짐과 정체를 늘릴 수 있다. 충격은 장착부와 주행부에도 전달된다. 무리를 밀어내는 상황은 게임의 가정이며, 눈의 운용 자료로 무리의 규모별 통과 성능을 계산할 근거는 없다. 부착 구조의 허용 하중도 **미확인**이다. [장비 구조 사례][wedge] [앞쪽 구조물 복원][pilot]

### 공기총 충전: 확보한 값으로 어디까지 계산할 수 있는가

증기 공기총 [연구 3단계][decisions]의 충전원은 실제 증기 구동 공기 압축기와 연결된다. 다만 **무기용 탱크의 용량·시작 압력·목표 압력과 압축기의 실제 여유 유량이 미확인**이므로, 해당 공기총의 충전 시간을 확정할 수 없다. 조용하다는 것은 게임의 설정이며, 실제 소음 수치와 무음 운용 가능성도 **미확인**이다.

탱크 안 공기 온도가 유량의 기준온도와 같게 유지되고, 순공급 유량이 일정하다고 가정하면 다음 관계를 쓸 수 있다. `Q여유`는 같은 기준 압력·온도로 환산한 자유공기 유량이며, 제동 재충전·다른 공기 장치·누설에 필요한 양을 제외한 값이다. [압축공기 기술 매뉴얼][air-manual]

`충전 시간 ≈ 탱크 부피 × (목표 압력 − 시작 압력) ÷ (기준 절대압 × Q여유)`

규모를 가늠하는 계산은 **실제 기관차의 제동용 주 공기통**을 대상으로만 해 볼 수 있다.

| 계산 입력 | 출처 또는 명시한 가정 |
|---|---|
| 공기통 전체 부피 [800 L][dsu-reservoir] | 정비 문서의 [400 dm³ × 2개][dsu-reservoir]를 합산했다. |
| 충전 압력 차 [0.8 MPa][dsu-ol49] | 대기압 상태에서 정격 공기압까지 채운다는 계산 가정이다. |
| 계산용 기준 흡입 절대압 [1 bar][air-manual] | 기술 매뉴얼의 기준 상태를 빌린 가정이다. 해당 장소의 실제 흡입 압력은 **미확인**이다. |
| 공급 유량 [120 m³/h][dsu-ol49], 환산하면 [2,000 L/min][dsu-ol49] | **이 값이 위 기준의 자유공기량이고 전량 충전에 쓰인다는 가정.** 원문에서 유량 기준은 **미확인**이다. |
| 계산 결과 약 [3.2분][air-manual] | 위 입력으로 계산한 이상적인 예시다. **실측 충전 시간은 미확인**이며 실제 충전 시간이 반드시 이 이상이라는 보장도 하지 않는다. |

같은 가정에서 최종 정격압력으로 연속 토출할 때 필요한 이상적인 등온 압축 동력은 `기준 절대압 × 자유공기 유량 × ln(토출 절대압 / 흡입 절대압)`이다. 정격 공기압을 게이지압으로 해석하면, 계산용 흡입 절대압 [1 bar][air-manual]에 압력 차 [0.8 MPa][dsu-ol49]를 더한 최종 토출 절대압은 [9 bar][air-manual]로 계산되며, 위 유량에서 약 [7.3 kW][air-manual]가 나온다. **최종 압력 조건의 계산값이며, 충전 전 과정의 평균 동력은 아니다.** 또한 실제 증기기관의 축출력·열소비·석탄 소비가 아니다. 기계 손실, 증기 조건, 압축 방식과 효율 자료가 없으므로 실제 추가 석탄 소모는 **미확인**이다. [압축기 원 제원][dsu-ol49] [등온 압축식][air-manual]

운용에서 중요한 연결은 **공기 공급과 증기 공급을 다른 일과 공유한다는 것**이다. 압축기가 동작하는 동안 증기가 들고, 공기를 많이 쓰면 제동 계통의 재충전 여유가 줄 수 있다. 이 때문에 충전 시간은 기관차가 정차했는지뿐 아니라 제동 후인지, 다른 공기 소비가 있는지에 따라서도 달라진다. 압력 조정이나 연결 방식, 무기 성능과 게임의 제한 규칙은 이 문서에서 정하지 않는다. [공기 제동 원리][polish-brakes] [증기 압축기 구조][pump-restoration]

### 기관 지식: 견습·숙련·장인과 매뉴얼

아래 대응은 실제 자격 등급이 아니라, 현실의 업무를 게임의 [견습·숙련·장인 체계][knowledge]로 읽어 본 해석이다. 역할별 소요 시간이나 성공률을 정하는 표가 아니다.

| 게임의 지식 단계 | 연결할 수 있는 실제 업무 | 혼자 맡기기 어려운 경계 |
|---|---|---|
| 견습 | 선임의 지시를 받아 석탄·물과 윤활품을 준비하고, 관측값을 읽어 전달하고, 청소·기록·전방 감시를 돕는다. | 계기의 고장 여부 판단, 노선 전체의 제동 계획, 저수위·급수 실패 대응을 독립적으로 책임지는 단계로 보기는 어렵다. [화부 교육의 요구 업무][fire-training] |
| 숙련 | 평상시 급탄·급수와 증기 공급을 맞추고, 맡은 기관차의 출발 점검·제동·운전·일상 정비를 수행한다. 이상을 알아차리고 정차·도움 요청을 판단한다. | 기관사와 화부의 숙련은 업무별로 다를 수 있다. 익숙하지 않은 형식·노선·중결함까지 즉시 해결한다는 뜻은 아니다. [출발 준비 직무][prepare-training] [화부 직무][fire-training] [기관사 교육 원전][engineers-book] |
| 장인 | 소리·진동·연소·수위 변화와 정비 이력을 연결해 원인을 좁히고, 다른 사람을 가르치며 수리 범위와 운행 재개 가능성을 판단한다. | 경험이 있어도 차축 가공, 보일러 수리, 압력 시험에 필요한 설비와 재료를 대신할 수 없다. [정비 인계·교육 자료][pkp-manual] [차축 수리 사례][nnry-axle] [제동·보일러 검사][fra-steam] |

매뉴얼로 배울 수 있는 것은 부품 이름과 계기 의미, 점검 순서, 윤활 위치, 정상 상태의 기준, 기록 방법, 고장 시 확인할 항목이다. 반면 불층을 읽는 눈, 급탄 뒤 증기 발생의 지연을 예상하는 감각, 소리로 누설·미끄러짐을 구분하는 능력, 구배와 편성에 맞춘 운전은 읽는 것만으로 숙달됐다고 확인하기 어렵다. 화부 직무 기준은 이러한 현장 작업을 수행하는 능력을 요구한다. [화부 직무 기준][fire-training] [기관사 교육 원전][engineers-book]

기관사를 잃고 매뉴얼을 보며 운용하는 상황에서는 점검 항목을 찾고 서로 대조하는 일, 밸브·계기의 의미를 해석하는 일, 증기 공급과 움직임을 맞추는 일, 다음 구간을 판단하는 일이 모두 느려질 수 있다. 모르는 이상이 생길 때마다 멈춰서 확인해야 하고, 잘못 읽은 수면계·급수 실패·제동 재충전 부족은 저속에서도 위험하다. **이는 실제 업무에서 도출한 해석**이며, 얼마나 느려지는지와 사고 확률은 **미확인**이다. [출발 준비 직무][prepare-training] [화부 직무][fire-training] [저수위 사고 조사][raib-water]

기존 설정에서는 기관사를 모두 잃으면 누군가 매뉴얼로 운전을 익힐 때까지 좌초 상태를 버텨야 한다. 이후 매우 느리게 굴러갈 수 있고, 매뉴얼로는 숙련까지 배우며 장인은 살아 있는 장인의 전수가 필요하다는 구조를 그대로 둔다. 이 레퍼런스가 보태는 것은 매뉴얼을 펼치는 시간, 감독을 대신할 상호 확인, 반복 점검, 예측을 못 해 낭비되는 증기, 차고 없이는 끝내지 못하는 수리라는 구체적인 작업의 근거다. [기존 기관 지식 결정][knowledge]
