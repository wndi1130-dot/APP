# 코드 대조 요약 (2026-10-09, main 19ca4f8, 읽기 전용 조사. grep 0건 = 없음 추정)

약어: dec = docs/design/decisions.md, s1 = s1/src/game/, dom = s1/src/game/domestic/

## 재료·제작
- 자재(고철·목재) 재고·상한·장소 부산물: dom/data.ts D.scrap0/wood0/storeCap(40), BYPRODUCT(장소 6종, frag·core 확률); dom/workshop.ts materials/addMaterials; S2 sulehuf_map.gd 해체 지점 8곳, carry.gd scrap/wood, receipt.gd STOCK_KEYS. 고철·목재·부품·설계도 '바닥 예고'(dec '위 자원 줄')는 사용자가 '나중에 구현'.
- 부품·설계도 조각·코어: dom/state.ts parts/frags/cores.
- 탄약: S2 field_game.gd ammo{pistol,shell,craft}, weapons.gd AMMO_NAMES, receipt ammo_pistol/shell/craft. 소총탄 없음. S1 열차 재고에 탄약 키 없음.
- 열차 공방: dom/workshop.ts runWorkshop/startRestore/startJob/rollBreakdown. 공방이 만드는 것은 부품 하나뿐. 6.2 일 목록 8/8 구현(부품, 복원1~3, 결함판→완성, 적응 복원, 단열 개조, 장갑 개조, 칸 기능 바꾸기(목적지는 온실 하나), 수리(workDebt+부품2)).
- 탄약 재장전·무기 수리·무기 제작: 없음. W2 가 '탄약 재장전'은 정차 부상·사망 ×0.85 효과만(dom/hooks.ts).
- 수제 총: S2 weapons.gd pipe_shotgun(crafted), QUALITY 4행, wear. 연구→종류·숙련→품질 연결 없음, 열차 제작 없음.
- 증기 공기총: 0건.
- 필드 간단 제작: S2 field_actions.gd 부목(판자)·붕대(천→붕대2), 맨홀 뚜껑 막기. 지혈대·창·새총·화염병·즉석 소음기·횃불·모닥불·깡통 유인·바리케이드 0건(body_injury.md는 S2에 화염병·바리케이드·지혈대를 넣는다고 적음 → S2 스레드 몫).
- 레시피·책·작업대 단계: 0건. 물건의 질(젖은 석탄): 0건.
- 문서 어긋남: s1c_domestic.md 15장 "탄약 4계열과 무기 제작(S2)" vs s2_station.md 4장(넣지 않는 것) "열차 안 제작(공방), 수제 총 만들기". 무기 제작이 어느 단계에도 없다.

## 연구·기술
- 기술 19개(s1c 7.3): dom/data.ts TECHS, prereqs, skillNeed; workshop.ts restoreCheck/startRestore/completeRestore. 효과 연결 18/19(R3는 NOT_YET 잠김). W3·E5 일부만.
- production_research 표 노드 약 54개(추정) 중 나머지 약 35개 코드 없음: 눈 녹여 급수, 정수, 제설기(쐐기 쟁기), 보조 기관차, 수술 도구, 소독, 절단 수술, 항생제, 의수·의족, 근접 무기, 수제 총 1~3단계, 총기 수리, 정밀 개조, 돌격소총 복제품, 증기 공기총, 중거리 무전, 전령·신호 깃발·소문망, 썰매 계열, 개썰매, 스키·설피, 야영 장비, 장거리 원정 체계, 설원 생존술, 현지 안내자, 공동 수면칸, 모피 의복, 사냥·채집 파견대, 배급 감량, 함정.
- 결함판 부작용 '연기가 늘어 좀비를 끈다'는 코드·s1c에 없음(고장 +3%p만).
- 세력별 원하는 연구: TechDef.like/dislike, 연구 우선권 협상 있음.
- 지식인: SPECIALISTS 8명, knowledge.ts(견습·매뉴얼·카운트다운·파업), elder.ts, 전문가 동행 setEscort. 데려오기(구조·포로·망명) 없음.
- 간부 자동화: 배급장(s1/turn.ts autoLevers), 공방장(dom/delegate.ts). 의무장·기관장·경비대장 없음.
- 지식 독점·독전대·계엄: 없음 → S1b 스레드 몫.

## 파견·원정·운반
- 파견대(dec '열차 사회': 석탄 광산 특임대, 설숲 사냥부대, 버튼으로 확장·축소, 다음 역 합류 세팅 또는 열차가 돌아와야 함, 안 돌아오면 자립도 급등) + dec '검토 중' 떨어져 나간 집단(자립도 S자, 무전 말투 예고, 간부가 있어야 보냄): grep 파견대/자립도/outpost/detachment 0건. 어느 단계에도 안 적힘. S1 기획서·s1c 15장은 'S1 범위 밖'. first_slice_scope의 '넣지 않을 것' 목록에도 없음.
- 원정·파견 가지: dec는 '파견 효율, 속도, 썰매 강화'. 코드 X1(아동 노동 '짐 꾸리기만' 법 변형, dom/lawtech.ts), X2(핸드카 정찰=장소 후보 둘, s1/turn.ts), X3(궤도 모터카=지나쳐도 '짧게'의 절반, dom/hooks.ts)뿐.
- 자동 파견(정차 자동 처리, S1 필드 결정 카드 = 최종 자동 파견 원형): s1/turn.ts setStop/sendScouts/stopRisk/resolveStop, omens.ts, 파견 인원 투표 제외. 전리품 × (0.7 + 0.075 × 인원), 인원 2~8.
- 썰매: dec 차량·운송 '출시판 운반은 맨손(가방)과 썰매'. 규칙은 vehicles.md 1장 한 줄뿐, 코드 0. review/02_field.md가 이미 지적.
- 핸드카·모터카 짐, 자동차, 차량칸, 큰 짐, 연료, 개썰매: 사용자 '출시 뒤 업데이트'.

## 칸·사회
- 무전칸: s1c 4.1은 '넣지 않는다, 열차장실 무전기로 대신'. 교실칸(교육 법→자란 아이가 공동체에 들어감): 0건, S1 범위 밖. 감옥칸·암시장·열차장 가족·투표함: S1b 둘째 묶음.
- 취사칸 조리: 0건. 음식 상함·요리·통조림(survival_detail 3.5, 제안): 0건.
- 무한모드 루프·이어지는 세계·정착 시도·좌초 모드·구간 속도·경사·밀도 폭동·허시먼 선택지(구조 거절·교대 수면·추방): 0건(객차 추가 attachCar, 라이프치히 분리 hub.ts만 있음).
