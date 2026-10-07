# S1c 내정 1. 문서와 코드의 어긋남 (2026-10-08)

근거: 코드 4ba1025(가지 claude/s1a-screens-playable-08op8y), 문서 main 6ee9794
묻은 곳: 코덱스(높은 추론), 읽기 전용
물음: s1c_domestic.md 4.1·6.4~6.6·7.1·7.3·8.1·16장과 s1/src/game/domestic/*.ts의 숫자·규칙 차이, 코드에만 있는 규칙
제 한 줄 판정: 위생 세 가지(liceFromSeg 4, 따로 눕히기, 씻을 물 표시)는 들어갔다. 가장 큰 어긋남은 옷 삶기가 카드 경로에서 석탄을 두 번 깎아 실제 4가 되는 것이다. R2·R3·X2 기술은 설명만 있고 효과가 없다.

---

지정한 사본을 읽기만 해 대조했다. 파일 생성·수정, 변경 이력 조회, 외부 역사 조사는 하지 않았다. 아래는 **정적 코드 검토 결과**이며, 게임을 실행해 확인한 결과는 아니다.

문서의 `s1c_domestic.md`는 snap_m3의 최신 설계 문서를 뜻한다. 코드 표기의 `domestic/`는 **snap_s1a의 `s1/src/game/domestic/`**, `game/`와 `ui/`는 각각 같은 사본의 `s1/src/game/`, `s1/src/ui/`다. “최신” 판단은 제공된 사본 기준과 문서 안의 수정 문구에 한정했다.

**불일치·코드에만 있는 규칙·주요 반영 상태**

| 문서 절·줄 | 코드 파일:줄 | 문서 값 | 코드 값 | 어느 쪽이 최신으로 보이나 |
|---|---|---|---|---|
| 4.1 · `s1c_domestic.md:130` | `domestic/data.ts:51`; `domestic/medbay.ts:10`; `domestic/beds.ts:12` | 침상 6을 부상자·발진티푸스·폐렴 환자가 사용 | 침상 6은 같음. 부상자와 발진티푸스만 계산하며, 폐렴은 아직 없다고 주석에 명시 | **문서가 더 넓은 목표**. 폐렴 미구현을 코드가 명시함 |
| 4.1 · `s1c_domestic.md:142` | `game/turn.ts:205` | S1c에서는 목재 4가 있으면 화장에 목재부터 사용 | `burnPyre`는 시신 수에 따라 석탄만 차감. 목재 사용 없음 | **문서 최신 설계 미반영** |
| 4.1 · `s1c_domestic.md:133`; `s1c_domestic.md:140` | `game/turn.ts:638`; `game/turn.ts:646`; `domestic/cars.ts:164` | 안치 상한 6, 초과하면 사고 확률 ×2. 화장 대기 시신은 1구당 3%/구간 | 확률에 **30% 상한**을 먼저 적용. 안치 시신은 그 뒤 초과 배율 ×2이므로 최대 60% | **코드만 상한을 구체화**. 지정 문서 절에는 30% 상한이 없음 |
| 6.4 · `s1c_domestic.md:294`; `s1c_domestic.md:334`; `s1c_domestic.md:335` | `domestic/data.ts:87`; `domestic/delegate.ts:27` | 본문에는 인구 220~300, 시험판 시작 인구+5가 남아 있지만, 뒤의 수정 문구는 **S1 인구 조건 없음** | `delegatePop: 5`는 남아 있으나 위임 조건 검사에서는 사용하지 않음 | **문서:335의 수정 문구와 실행 코드가 일치**. +5를 현재 적용값으로 보면 안 됨 |
| 6.4 · `s1c_domestic.md:287`; `s1c_domestic.md:288`; `s1c_domestic.md:335` | `domestic/delegate.ts:12`; `domestic/state.ts:176` | 표에서는 공방장만 S1c, 나머지는 이후. 그러나 :335는 S1c에서 “나머지 넷도” 연다고 서술 | 새 내정 위임은 **공방장 하나** | **문서 내부 충돌**. 코드는 간부 표의 범위와 일치 |
| 6.4 · `s1c_domestic.md:295` | `domestic/delegate.ts:32`; `domestic/state.ts:11` | 간부가 사는 공동체 관계 ≥15, **간부 본인의 적의 0** | 관계는 간부 공동체 기준이나, 적의는 **그 공동체의 `grudge`**를 검사. `DomPerson`에 개인 적의 필드 없음 | **문서의 개인 적의 규칙 미반영** |
| 6.4 · `s1c_domestic.md:295`; `s1c_domestic.md:335` | `game/turn.ts:107`; `domestic/delegate.ts:33` | 배급장도 “배급장의 공동체”를 기준으로 해야 함. 지지로 꺼진 뒤 재개선은 +20 | 공방장은 최초 +15·재개 +20 반영. 배급장은 **앞칸 고정, +15만 검사** | **공방장 반영 / 배급장 수정 미반영** |
| 6.4 · `s1c_domestic.md:315` | `domestic/delegate.ts:72`; `domestic/delegate.ts:75` | 중립은 처지가 가장 나쁜 공동체부터 챙김. 구체적인 계산식 없음 | **온기+배급 합이 최소인 공동체**를 고름. 복원 점수는 선호 공동체 수×2 − 반대 공동체 수 − 기술 단계×0.1 | **코드만 계산식을 구체화**. 과밀·노출은 이 선정식에 없음 |
| 6.4 · `s1c_domestic.md:314` | `domestic/delegate.ts:113` | 우선 방침: 우호 공동체 +1/구간은 호의 한계 안에서, 나머지 −1. 3구간마다 공정성 시비 확률 | 우호 쪽은 관계 **35 미만일 때 +1**. 3구간마다 **30%**, 발생하면 비우호 공동체에 **추가 −3** | +1/−1과 주기는 반영. **35·30%·추가 −3은 코드의 상세값** |
| 6.4 · `s1c_domestic.md:324` | `domestic/delegate.ts:86`; `domestic/delegate.ts:88` | 탐욕: 구간마다 10%로 부품 1개 빼돌림 | 횡령 10%·부품 1은 같음. 횡령을 알아채 일지에 남기는 확률은 **위임 중 10%, 직접 운영 중 20%** | 핵심 값 반영. **발각 확률은 코드에만 있음** |
| 6.4 · `s1c_domestic.md:325` | `domestic/delegate.ts:72`; `domestic/delegate.ts:100` | 이상주의 공방장은 우선 방침이어도 꼬리칸 단열 하나를 끼워 넣음 | 성향 분기는 가족·야심·겁·탐욕에만 있음. 이상주의의 단열 작업 추가 없음 | **문서 규칙 미반영** |
| 6.4 · `s1c_domestic.md:364`; `s1c_domestic.md:365`; `s1c_domestic.md:366` | `domestic/delegate.ts:122`; `domestic/cards.ts:338`; `domestic/state.ts:178` | 침상 중 야심 간부가 범위를 한 단계 넓힘. **일어난 뒤** 카드. 승인하면 범위 유지·야심 +1, 거절하면 개인 적의 +1·신임 +2 | 침상 중 바로 카드 생성. 실제 위임 단계 상승·유지와 승인 시 야심 +1 처리는 없음. 거절은 공동체 적의 +1, 신임 +2. `captainInBed`는 시작 false이며 켜는 경로 없음 | **S3용 훅만 일부 구현**. 문서도 S1c에서는 침상 사건을 만들지 않는다고 명시(`s1c_domestic.md:360`) |
| 6.5 · `s1c_domestic.md:375`; `s1c_domestic.md:376`; `s1c_domestic.md:377` | `domestic/data.ts:43`; `domestic/workshop.ts:470`; `domestic/workshop.ts:479`; `domestic/workshop.ts:495` | 고장 10% + 결함판당 3%p. 부품 ≥2이면 부품 2로 자동 수리. 부족하면 종류별 벌 | 해당 확률·자동 수리 조건·비용 반영. 벌도 석탄 +1, 산출 ×0.8, 꼬리칸 난방 레버 −1로 처리 | **주요 숫자·규칙 일치** |
| 6.6 · `s1c_domestic.md:385`; `s1c_domestic.md:388`; `s1c_domestic.md:391`; `s1c_domestic.md:395` | `domestic/hooks.ts:47`; `game/turn.ts:155` | 망자 0/1~10/11~30/31 이상 → 부품 0/1/2/3. 쐐기는 0/1/1/2. 부족분마다 다음 구간 석탄 +1·도착 +1시간, 최대 3 | 출발 처리에 망자 수별 쟁기 비용·부족분·도착 지연 처리 없음 | **문서의 S3 예정 규칙**. :395가 S1에는 밀고 나가는 일이 없다고 명시하므로 현재 S1 누락 결함으로 단정할 수 없음 |
| 7.1 · `s1c_domestic.md:405`; `s1c_domestic.md:410`; `s1c_domestic.md:411` | `domestic/data.ts:22`; `domestic/data.ts:184`; `domestic/workshop.ts:57`; `domestic/state.ts:253` | 1/2/3단계 조각 1/2/3, 부품 2/4/8, 3단계 코어 1. 같은 가지 선행 기술. 분야 숙련+공작 장인도 3단계 가능 | 비용·선행 조건·둘째 경로 반영 | **일치** |
| 7.1 · `s1c_domestic.md:408`; 7.3 · `s1c_domestic.md:440`; `s1c_domestic.md:445` | `domestic/data.ts:146`; `domestic/data.ts:158`; `domestic/workshop.ts:59` | 적응은 부품 0~2와 목재·처지로 비용 지불. E5·M5의 구체적인 해금 비용은 지정 절에 없음 | **E5 해금: 부품 1·목재 4 / M5 해금: 부품 0·목재 2**. E5 해금 뒤 객차 단열 목재 8은 별도 | **코드만 구체화한 해금 비용** |
| 7.3 · `s1c_domestic.md:422` | `domestic/workshop.ts:101`; `domestic/workshop.ts:115`; `domestic/workshop.ts:172`; `domestic/workshop.ts:200` | 복원을 **마칠 때** 선호 +5·반대 −5 | 관계는 **시작할 때** 움직이며 취소해도 유지. 반대 공동체가 없는 기술은 관계 변화 없음 | **시점은 불일치**. “반대가 없으면 변화 없음”은 문서 7.5에도 있으므로 코드만의 규칙이 아님(`s1c_domestic.md:471`) |
| 7.3 · `s1c_domestic.md:458` | `domestic/workshop.ts:106`; `domestic/workshop.ts:112`; `domestic/workshop.ts:151` | 변형은 한 번 고르면 그 판에서는 변경 불가 | 복원 취소 시 기술 상태와 변형 기록을 삭제. 다시 복원하면 다른 변형을 선택할 수 있음 | **문서의 판 전체 고정 규칙 미반영** |
| 7.3 · `s1c_domestic.md:440` | `domestic/lawtech.ts:58`; `domestic/data.ts:146` | E5: 단열 객차의 난방 배당 벌 제거, 한파 사건 벌 절반 | 난방 배당 벌 제거는 구현. 한파 사건 절반 처리는 없음 | **일부 반영**. 문서가 한파 몫은 S3부터라고 명시 |
| 7.3 · `s1c_domestic.md:448` | `domestic/workshop.ts:218`; `domestic/workshop.ts:267`; `domestic/sit.ts:19` | W3: 장갑 개조, 습격·사보타주 피해 −50%, 경비대칸 노출 −10 | 장갑 개조와 경비대칸 노출 −10은 구현. 장갑 상태를 습격·사보타주 피해에 적용하는 경로 없음 | **문서 효과 일부 미반영** |
| 7.3 · `s1c_domestic.md:450` | `domestic/data.ts:172`; `domestic/data.ts:173`; `game/politics.ts:262`; `game/turn.ts:812` | R2 가: 회기마다 비밀 확률 +25%. 나: 긴장 증가 −1·공포 +1/구간 | 기술 설명·유지비·변형은 있으나, 회기 비밀 판정과 긴장·공포 정산에 R2 효과 적용 없음 | **설명 데이터만 반영, 실제 효과 미반영** |
| 7.3 · `s1c_domestic.md:451` | `domestic/data.ts:176`; `domestic/state.ts:176`; `game/turn.ts:232` | R3: 다음 정차 장소·위험 미리 보기, 판당 장소 변경 3회 | 설명과 `reroutes: 3` 초기값만 있음. 미리 보기·장소 변경·횟수 차감 경로 없음 | **설명·상태만 반영, 실제 효과 미반영** |
| 7.3 · `s1c_domestic.md:453` | `domestic/data.ts:178`; `domestic/state.ts:176`; `game/turn.ts:233` | X2: 정차마다 장소 후보 2개 중 선택 | 설명과 `altPlace: null`만 있음. 정차는 무작위 장소 하나를 생성하며 두 번째 후보·선택 경로 없음 | **설명·상태만 반영, 실제 효과 미반영** |
| 7.3 · `s1c_domestic.md:454` | `domestic/hooks.ts:113`; `game/data.ts:237` | X3: 지나쳐도 ‘짧게’ 산출의 절반, 석탄 1 | **목표가 석탄·식량일 때만** 절반 산출. 의약품·사치품·상징물·정보 목표는 산출 0인데 석탄 1은 차감 | **코드의 제한이 문서보다 좁음**. 문서에 자원 종류 제한 없음 |
| 7.3 · `s1c_domestic.md:459` | `domestic/data.ts:164`; `domestic/workshop.ts:172` | W2 나도 기술 축을 적응 쪽으로 움직임 | W2 나의 전투 효과는 있지만, 복원 완료 시 기술 축을 움직이는 처리 없음 | **문서 규칙 미반영** |
| 8.1 · `s1c_domestic.md:484`; `s1c_domestic.md:486`; `s1c_domestic.md:497` | `domestic/data.ts:199`; `domestic/data.ts:201`; `domestic/state.ts:159` | 견습 화부는 S1a #10, 약사는 #11 겸직. 새 인물은 공방장·용접공·무전병 셋 | 대표 겸직 셋만 기존 대표에서 가져옴. 견습 화부·약사는 **별도 프로필 추첨** | **문서의 측근 겸직 연결 미반영** |
| 8.1 · `s1c_domestic.md:488`; `s1c_domestic.md:494` | `domestic/state.ts:162`; `domestic/knowledge.ts:37`; `domestic/knowledge.ts:47` | 기존 용접공이 공방장의 견습이며, 그를 장인으로 키울 수 있음 | 시작 용접공은 숙련도 1만 있고 학습 연결 없음. 견습 붙이기는 **새 숙련도 0 인물**을 생성하며 기존 용접공을 붙이는 경로 없음 | **기존 용접공의 육성 경로 미반영** |
| 8.1 · `s1c_domestic.md:496` | `domestic/state.ts:159`; `domestic/state.ts:233`; `domestic/knowledge.ts:48`; `domestic/knowledge.ts:129` | 열차장 직업의 지식 숙련을 추가. 교사는 모든 견습 기간 −1구간 | 전문가 8명과 이후 생성 인물만 지식 계산. 열차장 직업 지식·교사 기간 보정 없음 | **문서 규칙 미반영** |
| 16.5 · `s1c_domestic.md:880`; 16.9 · `s1c_domestic.md:917`; 16.8 · `s1c_domestic.md:944` | `domestic/data.ts:79`; `domestic/cards.ts:223`; `game/cards.ts:683`; `game/cards.ts:794`; `domestic/cards.ts:345`; `domestic/hygiene.ts:135` | 조정 후 옷 삶기 **석탄 2**. 16.8에는 옛 값 3이 남음 | 상수는 2지만 공통 카드 효과에서 −2, 위생 함수에서 다시 −2. **카드 선택 경로의 실제 차감은 4** | **최신 설계값은 2**. 16.8의 3은 잔존 문구이며, 실제 코드 경로에는 중복 차감이 있음 |
| 16.5 · `s1c_domestic.md:883` | `domestic/hygiene.ts:20`; `domestic/hygiene.ts:203` | 과밀 ≥70인 이웃 칸에 열병 전파 | 공동체 이웃을 **꼬리↔의무진↔경비대↔앞칸↔기관실**로 고정. 실제 객차 순서 변경은 참조하지 않음 | **코드만 인접 관계를 고정**. 문서의 ‘이웃 칸’과 객차 재배치의 관계는 명시되지 않음 |
| 16.5 · `s1c_domestic.md:883`; `s1c_domestic.md:885` | `game/turn.ts:503`; `game/turn.ts:614`; `domestic/hooks.ts:179`; `domestic/hygiene.ts:186` | 환자 1명당 의약품 0.5. 부상자와 환자 사이의 의약품 차감 순서는 지정하지 않음 | **부상자 의약품을 먼저 차감한 뒤** 발진티푸스 의약품을 차감. 의무칸을 비워 부상 회복을 멈춘 경우에도 부상자 약은 먼저 소비 | **코드에만 있는 자원 배분 순서**. 문서로 승인된 우선순위인지는 판단 불가 |
| 16.3·16.5 · `s1c_domestic.md:853`; `s1c_domestic.md:883` | `domestic/hygiene.ts:117`; `domestic/hygiene.ts:118`; `domestic/hygiene.ts:182`; `domestic/hygiene.ts:204` | 위생별 이 확률, 환자의 구간별 회복·사망·전파 | 열병 중인 공동체에는 새 이 발생 제외, 이미 열병인 이웃에는 중복 전파 제외. **환자 발생 구간에는 약 소비·회복·사망·전파 정산 생략** | **코드에만 있는 발생 제외·첫 구간 유예 규칙** |
| 16.3·16.5 · `s1c_domestic.md:857`; `s1c_domestic.md:879` | `domestic/data.ts:85`; `domestic/hygiene.ts:116`; `domestic/state.ts:173` | 시작 시 이 없음, 이 카드는 4구간부터 | `lice: {}`로 시작하며 `g.seg < 4`면 발생 검사 생략 | **들어갔다. `liceFromSeg: 4` 반영** |
| 16.5 · `s1c_domestic.md:885`; `s1c_domestic.md:886` | `domestic/data.ts:83`; `domestic/cards.ts:235`; `domestic/cards.ts:236`; `domestic/hygiene.ts:159`; `domestic/hygiene.ts:189`; `domestic/hygiene.ts:201`; `domestic/medbay.ts:37` | 의무칸: 전파 없음·회복 40%·부상 회복 중단. 따로 눕히기: 전파 10%·회복 25%·부상 회복 유지 | 선택지·상태·회복 확률·전파 확률·부상 회복 중단 모두 구현 | **들어갔다. 다만 침상 계산은 아래 미반영 표 참고** |
| 16.1·16.3 · `s1c_domestic.md:834`; `s1c_domestic.md:860` | `domestic/data.ts:233`; `domestic/hygiene.ts:79`; `ui/domestic.ts:216`; `ui/domestic.ts:218` | 화면에는 ‘씻을 물 넉넉·빠듯·없음’, 조건 설명, 이가 돌면 솥·빨랫줄 표시 | `WASH_NAME` 매핑과 실제 화면 출력, 조건 설명, 솥·빨랫줄 표시 있음 | **들어갔다. 이름 상수만 있는 상태가 아니라 UI에서 사용함** |

**위생 미반영 표 — 없는 것과 부분 반영된 부분만 분리**

| 문서 절·줄 | 코드 파일:줄 | 문서 값 | 코드 값 | 어느 쪽이 최신으로 보이나 |
|---|---|---|---|---|
| 16.3 · `s1c_domestic.md:858` | `domestic/hygiene.ts:91`; `domestic/hooks.ts:59`; `game/turn.ts:246` | 위생에 따라 작업조·수색대 시작 냄새가 깨끗·땀내·악취로 결정. ‘씻고 나간다’는 석탄 0.1/명으로 깨끗하게 출발 | 위생 판정은 있으나 파견 냄새 상태·씻기 선택·인원당 석탄 비용으로 연결되지 않음 | **미반영**. 현재 S1 코드에는 필드 연결이 없음 |
| 16.5 · `s1c_domestic.md:883` | `domestic/hygiene.ts:151`; `domestic/cards.ts:233`; `ui/domestic.ts:213`; `ui/domestic.ts:219` | 환자를 프로필에서 뽑고 **이름이 보임** | 이름은 `patients`에 저장하지만 카드와 칸 UI는 **환자 수만 표시** | **이름 생성은 반영 / 환자 이름 표시는 미반영** |
| 16.5 · `s1c_domestic.md:886` | `domestic/hygiene.ts:164`; `domestic/beds.ts:8`; `domestic/beds.ts:13`; `domestic/medbay.ts:19`; `ui/domestic.ts:214` | ‘따로 눕힌다’를 고르면 환자는 **제 칸에 남음** | `apart`의 회복·전파 효과는 반영됐지만, 침상 계산은 `apart`를 보지 않음. `bedOrder === 'workers'`인 예외 외에는 제 칸 환자도 의무칸 침상 수에 포함 | **부분 미반영**. 선택지 자체는 구현됐으나 위치에 따른 침상 제외가 연결되지 않음 |

요청한 예시인 **`liceFromSeg: 4`, 따로 눕히기의 10% 전파·25% 회복, ‘씻을 물 넉넉·빠듯·없음’ 표시는 모두 코드에 들어갔다.** 위생에서 가장 분명한 값 불일치는 옷 삶기의 **설계 비용 2 대 실제 카드 경로 비용 4**이고, 별도 미반영 항목은 필드 냄새·씻기 연결, 환자 이름 표시, 따로 눕힌 환자의 침상 계산이다.