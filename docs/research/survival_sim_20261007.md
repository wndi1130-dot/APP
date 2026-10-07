# 생존 시뮬레이션 세부 조사

조사 기준일: 2026-10-07. 이 문서는 공개 출처에서 새로 확인한 빈 항목을 보충한다.

## 1. 한눈 요약

- [1차] **PZ 좀비의 냄새 추적 1차 근거는 이번 조사에서 확인되지 않았다.** 구현 부재까지 입증한 것은 아니다. [개발사 42.21 공지](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/) · [접근 시도한 PZwiki 좀비 항목](https://pzwiki.net/wiki/Zombie)
- [1차] 개발사는 2026-09-28에 Build 42.21 Stable을 발표했다. [PZ 42.21 공지](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/) · [공식 뉴스 날짜 목록](https://projectzomboid.com/blog/news/)
- [1차] The Long Dark의 공식 과거 패치 기록은 옷 겹, 젖음·결빙·건조, 동상 체계를 소개하며, 세부 온도 규칙은 아래에서 페이지 버전 한계를 붙여 설명한다. [Resolute Outfitter](https://www.thelongdark.com/time-capsule/resolute-outfitter/)
- [2차] 7 Days to Die 2.5는 날고기 냄새 시스템을 다시 넣었고, State of Decay 2는 ScentBlock과 Zombait를 아이템으로 사용한다. [7 Days Raw Meat](https://7daystodie.wiki.gg/wiki/Raw_Meat) · [State of Decay 2 Consumables](https://state-of-decay-2.fandom.com/wiki/Consumables)
- [2차] DayZ의 공개 감염자 설명은 시야·소리 탐지와 수색을 다루지만 냄새 규칙은 확인되지 않았다. [DayZ Infected](https://dayz.wiki.gg/wiki/Infected)
- [제안] 모바일에서는 냄새를 한 가지 탐지 거리 보정으로 두고, 냄새 원인·씻기 선택·상태 표시를 짧은 순환으로 묶는 편이 초안의 짧은 필드 임무에 맞는다. [설계 초안](../design/briefs/body_injury.md)

## 2. 항목별 조사

### 2.1 Project Zomboid

[1차] **기존 조사 참고:** [pz_hordes_events_zombies.md](research_notes/%EC%A2%80%EB%B3%B4%EC%9D%B4%EB%93%9C%20%EB%AA%A8%EB%93%9C%20%EC%84%A4%EA%B3%84%20%EC%B0%B8%EA%B3%A0/hordes_events_zombies.md), [pz_medical_knowledge_crafting.md](research_notes/%EC%A2%80%EB%B3%B4%EC%9D%B4%EB%93%9C%20%EB%AA%A8%EB%93%9C%20%EC%84%A4%EA%B3%84%20%EC%B0%B8%EA%B3%A0/medical_knowledge_crafting.md), [pz_npcs_combat_weapons.md](research_notes/%EC%A2%80%EB%B3%B4%EC%9D%B4%EB%93%9C%20%EB%AA%A8%EB%93%9C%20%EC%84%A4%EA%B3%84%20%EC%B0%B8%EA%B3%A0/npcs_combat_weapons.md), [pz_vehicles_maps_winter.md](research_notes/%EC%A2%80%EB%B3%B4%EC%9D%B4%EB%93%9C%20%EB%AA%A8%EB%93%9C%20%EC%84%A4%EA%B3%84%20%EC%B0%B8%EA%B3%A0/vehicles_maps_winter.md), [field_zombie_ai.md](https://github.com/wndi1130-dot/APP/blob/research/field-mechanics-20261007/docs/research/field_mechanics/zombie_ai.md), [field_enemy_ai.md](https://github.com/wndi1130-dot/APP/blob/research/field-mechanics-20261007/docs/research/field_mechanics/enemy_ai.md), [gap_fill.md](gap_fill.md).

**작동 방식·버전**

[1차] The Indie Stone은 2026-09-28 공지에서 Build 42.21을 Stable로 발표했고, 페이지 머리말에도 Stable과 Unstable이 42.21로 표시된다. [42.21 Stable Released](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/) · [공식 뉴스 날짜 목록](https://projectzomboid.com/blog/news/)

[1차] 42.21 공지는 좀비 중복·청크 재진입 문제와 XXL 나무 표시 조정 등을 대표 변경으로 들며 전체 변경점은 포럼 공지로 넘기므로, 이 글만으로 생존 수치가 B41과 같거나 달라졌다고 결론내릴 수 없다. [42.21 Stable Released](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/)

[제안] 기존 조사에서 다룬 온도·의복·질병·영양·수면·무들 규칙은 그 파일 안의 B41/B42 표기를 그대로 유지하고 여기서 재서술하지 않는다. [기존 조사 파일 묶음](research_notes/%EC%A2%80%EB%B3%B4%EC%9D%B4%EB%93%9C%20%EB%AA%A8%EB%93%9C%20%EC%84%A4%EA%B3%84%20%EC%B0%B8%EA%B3%A0/)

**냄새 감지 근거**

[1차] 개발사 블로그에서 좀비가 플레이어의 몸 냄새·피·음식 냄새를 따라간다는 규칙을 찾지 못했다. 공식 위키 페이지는 이번 공개 검색 도구에서 robots 제한으로 열리지 않았고 게임 파일도 직접 확인하지 못했으므로, 엄밀한 결론은 “냄새 추적의 1차 근거 미확인”이며 “게임에 절대 없다”는 증명이 아니다. [개발사 공지 검색 기준점](https://projectzomboid.com/blog/news/) · [접근이 제한된 PZwiki 좀비 항목](https://pzwiki.net/wiki/Zombie)

[2차] 2018년 커뮤니티 샌드박스 변수 안내에 `ZombieLore.Smell` 항목이 나오지만 설명이 Hearing과 중복되어 있어 그 문서만으로 작동 규칙이나 실제 구현을 확인할 수 없다. [Steam 커뮤니티 안내](https://steamcommunity.com/sharedfiles/filedetails/?id=1281473597)

**우리 게임에 쓸 점**

[제안] 초안의 냄새 단계·바람 보정·씻기 규칙은 Project Zomboid 재현이 아니라 우리 게임의 별도 규칙으로 표시한다. [설계 초안](../design/briefs/body_injury.md)

[제안] 기존 근접 피·때 처리는 외형 상태로 유지하고, 적 탐지에는 냄새값 하나만 쓰며 시야·소리·추적 기억과 합산하지 않는다. [설계 초안](../design/briefs/survival_detail.md) · [비교 사례](#23-냄새위생을-탐지에-쓰는-게임)

### 2.2 The Long Dark

**작동 방식**

[1차] Hinterland의 `Resolute Outfitter` 공식 기록은 2016-12-19의 v.393 업데이트에 옷 슬롯·겹쳐 입기 UI, 젖음·결빙·건조, 동상 상태가 들어왔다고 기록한다. [공식 Time Capsule 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/)

[1차] 같은 기록에서 옷의 보온 수치가 착용한 옷끼리 합산되고, 젖은 옷은 보온이 낮아지고 무거워지며 완전히 젖은 옷은 얼기 시작하고, 옷감에 따라 젖었을 때의 보온 유지와 건조 속도가 달라진다고 설명한다. [공식 Time Capsule 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/)

[2차] 현재 위키 문서의 계산 설명은 체감온도를 공기온도·풍냉·옷의 보온·방풍 보정의 합으로 제시하고, 방풍 보정은 겉에 드러난 외층만 반영한다고 설명한다. [Feels Like](https://thelongdark.fandom.com/wiki/Feels_Like) · [Clothing](https://thelongdark.fandom.com/wiki/Clothing)

[2차] 저체온증 상태는 추위로 인한 상태 저하를 두 배로 만들며, 동상은 발생 부위별 최대 상태치를 낮추고 되돌릴 치료가 없는 상태로 설명된다. [Afflictions](https://thelongdark.fandom.com/wiki/Afflictions) · [Condition](https://thelongdark.fandom.com/wiki/Condition)

[2차] 오두막 증후군은 최근 6일의 실내 체류가 113시간을 넘으면 위험이 생기며, 발병하면 24시간 동안 실내 수면·시간 보내기·연구를 막는 것으로 기재되어 있다. [Cabin Fever](https://thelongdark.fandom.com/wiki/Cabin_Fever) · [Afflictions](https://thelongdark.fandom.com/wiki/Afflictions)

**숫자·버전**

[1차] 공식 옷·젖음 시스템 도입 기록의 버전은 v.393이며 발표일은 2016-12-19다. [Resolute Outfitter](https://www.thelongdark.com/time-capsule/resolute-outfitter/)

[2차] 위키가 제시한 저체온증의 추위 상태 손실은 시간당 상태치 20%에서 40%로 증가하며, 회복에는 난이도별로 따뜻한 상태를 6·12·18·24시간 유지해야 한다고 적혀 있다. [Afflictions](https://thelongdark.fandom.com/wiki/Afflictions)

[2차] 위키가 제시한 동상 수치는 발생 1회마다 최대 상태치 10% 감소이며, 오두막 증후군 기준은 최근 6일 중 실내 113시간 초과와 발병 후 24시간이다. [Condition](https://thelongdark.fandom.com/wiki/Condition) · [Cabin Fever](https://thelongdark.fandom.com/wiki/Cabin_Fever)

[2차] 위 수치 페이지는 열람 시점 2026-10-07의 위키 설명이며 현재 게임 빌드 번호를 제시하지 않아, 빌드별 수치로 확정할 수 없다. [Afflictions](https://thelongdark.fandom.com/wiki/Afflictions) · [Cabin Fever](https://thelongdark.fandom.com/wiki/Cabin_Fever)

**우리 게임에 쓸 점**

[제안] 체온 계산은 필드 UI에 체감온도 하나로 감추되 기온·바람·옷·젖음은 내부적으로 분리하고, 추위가 강해질수록 회복 정지→상태 손실처럼 두 단계만 보여준다. [공식 옷 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/) · [설계 초안](../design/briefs/survival_detail.md)

[제안] 옷은 속옷·겉옷·장갑·모자 네 슬롯으로 제한하되 보온과 방풍을 분리하고, 젖음은 보온 하락·무게 증가·건조 시간으로 연결한다. [공식 옷 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/) · [설계 초안](../design/briefs/body_injury.md)

[제안] 오두막 증후군의 누적 실내 시간은 공동체의 열차 생활 규칙에 참고하되, 필드 임무에는 옮기지 않는다. [Cabin Fever](https://thelongdark.fandom.com/wiki/Cabin_Fever) · [설계 초안](../design/briefs/survival_detail.md)

### 2.3 냄새·위생을 탐지에 쓰는 게임

**작동 방식**

[2차] 7 Days to Die 2.5에서는 소지한 날고기가 일정량 이상일 때 냄새가 생기고, 게임 위키는 냄새 반경이 고기 수량에 따라 커져 최대치에 이르며 포장하거나 버리면 차츰 사라진다고 설명한다. [Official 7 Days to Die Wiki: Raw Meat](https://7daystodie.wiki.gg/wiki/Raw_Meat)

[2차] 같은 위키는 날고기 5개 이상 소지 시 10초 유예 뒤 냄새가 시작되고, 반경은 10m에서 시작해 날고기 1개 추가마다 2m씩 커져 최대 100m에 이른다고 적는다. [Official 7 Days to Die Wiki: Raw Meat](https://7daystodie.wiki.gg/wiki/Raw_Meat)

[2차] 날고기를 먹을 때도 50m 냄새 거리가 추가되는 것으로 기재되어 있다. [Official 7 Days to Die Wiki: Raw Meat](https://7daystodie.wiki.gg/wiki/Raw_Meat)

[2차] 해당 위키 기록상 날고기 냄새는 Alpha 16에서 빠졌고 Alpha 17에서 냄새 시스템이 제거되었다가 Version 2.5에서 다시 들어왔다. [Official 7 Days to Die Wiki: Emitting Smell](https://7daystodie.wiki.gg/wiki/Emitting_Smell) · [Raw Meat](https://7daystodie.wiki.gg/wiki/Raw_Meat)

[2차] State of Decay 2 위키의 검색 색인에는 생존자의 존재를 숨기는 ScentBlock과 좀비를 끌어들이는 Zombait가 소모품으로 기록되어 있다. [Consumables](https://state-of-decay-2.fandom.com/wiki/Consumables) · [Mysterious Strangers](https://state-of-decay-2.fandom.com/wiki/Mysterious_Strangers)

[2차] DayZ 공개 감염자 설명은 시야를 잃은 뒤 소리를 들은 위치를 조사하는 수색 상태를 설명하지만 냄새 탐지를 규칙으로 들지 않는다. [DayZ Wiki: Infected](https://dayz.wiki.gg/wiki/Infected)

**숫자·버전과 평가**

[2차] 7 Days to Die 냄새의 수량·시간·거리 수치는 Version 2.5로 표시된 날고기 항목의 값이며, 과거 버전에서 냄새가 제거·복귀한 기록과 함께 읽어야 한다. [Raw Meat](https://7daystodie.wiki.gg/wiki/Raw_Meat) · [Emitting Smell](https://7daystodie.wiki.gg/wiki/Emitting_Smell)

[2차] Fun Pimps 공식 커뮤니티의 2.5 논의에는 음식별 냄새 세분화를 바라는 의견, 10초 유예가 사냥 중 유용하다는 의견, 물에 들어가면 냄새가 너무 쉽게 사라진다는 의견이 함께 나타난다. [공식 커뮤니티 토론](https://community.thefunpimps.com/threads/arrow-sponges-even-with-a-headshot-are-annoying-and-other-musings-2-5.46550/)

[2차] State of Decay 2 플레이어 토론 일부는 ScentBlock이 난도를 과도하게 낮춘다고 평가하고, 적과 접촉하면 효과가 깨지는 방식이 강하다고 말한다. 이는 대표성 있는 설문이 아니라 개별 커뮤니티 반응이다. [ScentBlock 커뮤니티 토론](https://www.reddit.com/r/StateofDecay2/comments/1qt6lj5/lethal_zone_is_easy_with_double_positive/)

[미확인] 조사한 DayZ 페이지와 State of Decay 2 아이템 위키는 이 규칙의 현재 게임 빌드와 정확한 지속시간을 표시하지 않아 해당 숫자를 기재하지 않는다. [DayZ Infected](https://dayz.wiki.gg/wiki/Infected) · [State of Decay 2 Consumables](https://state-of-decay-2.fandom.com/wiki/Consumables)

[미확인] State of Decay 2 위키 본문은 검색 도구의 402 응답으로 열리지 않아 검색 색인 발췌만 확인했으며, 아이템 작동 설명은 잠정적인 2차 근거로 취급한다. [Consumables](https://state-of-decay-2.fandom.com/wiki/Consumables) · [Mysterious Strangers](https://state-of-decay-2.fandom.com/wiki/Mysterious_Strangers)

**우리 게임에 쓸 점**

[제안] 세 게임의 공통 설계점은 냄새가 환경·아이템·임무 선택을 바꾸는 단일 탐지 신호라는 점이며, 복잡한 생물학 모델보다 명확한 반경과 사라지는 조건을 플레이어에게 알리는 방식이 모바일에 맞는다. [7 Days to Die Raw Meat](https://7daystodie.wiki.gg/wiki/Raw_Meat) · [State of Decay 2 Consumables](https://state-of-decay-2.fandom.com/wiki/Consumables)

[제안] 초안의 깨끗함·땀내·악취 3단계와 씻기 선택은 유지하되, 냄새가 바꾸는 것은 감지 거리 하나로 제한하고 수치 대신 작은 아이콘·바람 방향·옷 얼룩으로 알린다. [설계 초안](../design/briefs/body_injury.md) · [비교 규칙](https://7daystodie.wiki.gg/wiki/Raw_Meat)

[제안] 세척은 전원 공통으로 한 번 선택하게 하고 비용·기회비용을 붙여 반복 잡무를 줄인다. [설계 초안](../design/briefs/survival_detail.md) · [공식 커뮤니티 반응](https://community.thefunpimps.com/threads/arrow-sponges-even-with-a-headshot-are-annoying-and-other-musings-2-5.46550/)

### 2.4 1900년대 초중반 열차·피난민 위생 자료

**작동 방식과 생활 근거**

[1차] 암스테르담 시립 기록보관소는 1914년 피난민 임시 숙소로 개조한 창고에 세면 장소, 진료 공간, 빽빽한 침대와 짐, 세탁물을 말리는 줄이 있었다고 기록한다. 이는 피난민 수용 공간의 한 사례이지 열차 내부의 시설 기록은 아니다. [Stadsarchief Amsterdam: Leven in een loods](https://www.amsterdam.nl/stadsarchief/stukken/eerste-wereldoorlog/leven-loods/)

[1차] ECDC는 몸니가 옷과 침구를 통해 전파될 수 있고, 옷에 사는 몸니는 겨울·과밀·세탁 부족과 관련되며 위생과 세탁이 어려운 환경에서 문제가 커진다고 정리한다. [ECDC Lice Factsheet](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera)

[1차] ECDC에 따르면 발진티푸스는 몸니가 옮기는 세균성 감염이며, 몸니 배설물이 긁힌 상처나 점막으로 들어가는 방식으로 전파될 수 있다. [ECDC Lice Factsheet](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera)

[1차] ECDC의 현행 위생 안내는 목욕·샤워와 의류·침구의 정기 세탁·교체를 강조하며, 옷과 침구는 60°C 열건조 또는 55°C에서 30분 세탁으로 이를 제거할 수 있다고 설명한다. 이는 현재 보건 지침이지 1900년대 열차에서 실제 쓰인 방법이라는 사료는 아니다. [ECDC Lice Factsheet](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera)

**숫자·시대와 우리 게임에 쓸 점**

[1차] 기록보관소 사례의 연도는 1914년이며 ECDC의 세척 온도·시간은 현재 기술 안내다. 과거 열차의 소독 절차에 이 수치를 그대로 적용할 근거는 없다. [Stadsarchief Amsterdam](https://www.amsterdam.nl/stadsarchief/stukken/eerste-wereldoorlog/leven-loods/) · [ECDC Lice Factsheet](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera)

[미확인] 공개 자료에서 겨울 피난민 열차 내부의 목욕·옷 소독 장비와 운영 간격을 직접 입증하는 자료는 이번 조사에서 찾지 못했으므로 그 장면이나 수치를 사실처럼 쓰지 않는다. [열차가 아닌 임시 숙소의 기록](https://www.amsterdam.nl/stadsarchief/stukken/eerste-wereldoorlog/leven-loods/) · [ECDC 위생 자료](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera)

[제안] 열차 내 위생 설계는 공동 침구·옷 공유, 세탁물 말릴 공간, 온수·연료 배급 같은 생활 조건을 사건 원인으로 삼고 특정 사람 집단을 병원체와 연결하지 않는다. [암스테르담 시립 기록보관소](https://www.amsterdam.nl/stadsarchief/stukken/eerste-wereldoorlog/leven-loods/) · [ECDC Lice Factsheet](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera)

[제안] 모바일에서는 공동체 위생을 한 단계 값으로 요약하고, 목욕·의복 교체·침구 건조 중 한두 가지 행동만 선택지로 노출한다. [설계 초안](../design/briefs/survival_detail.md) · [설계 초안](../design/briefs/body_injury.md)

## 3. 초안 항목과 근거 연결표

| 초안 위치 | 붙일 근거 | 적용 범위 |
|---|---|---|
| [survival_detail.md §1](../design/briefs/survival_detail.md): 체온·땀·젖음·옷 층 | [기존 PZ 조사](#21-project-zomboid) · [1차: TLD 공식 옷·젖음 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/) · [2차: 체감온도 설명](https://thelongdark.fandom.com/wiki/Feels_Like) | [제안] PZ 사실은 기존 조사에서 버전별 확인하고, TLD는 비교 모델로 사용한다. |
| [survival_detail.md §1](../design/briefs/survival_detail.md): 의복 손상·피때·더러운 붕대 | [기존 PZ 조사](#21-project-zomboid) · [1차: TLD 공식 옷 손상 UI 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/) · [1차: 몸니 관리 원리](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera) | [제안] 게임 치료 규칙과 위생 자료를 섞지 말고 별도 근거로 붙인다. |
| [survival_detail.md §1](../design/briefs/survival_detail.md): 갈증·눈·배고픔·공황·발자국·발소리·날씨·근육통·수면 | [기존 PZ 조사 참고](#21-project-zomboid) | [제안] 기존 조사 내용을 재검색하거나 다시 서술하지 않는다. |
| [body_injury.md §4](../design/briefs/body_injury.md): 저체온·탈진·공황 상태 | [기존 PZ 조사](#21-project-zomboid) · [2차: TLD 저체온·동상 위키](https://thelongdark.fandom.com/wiki/Afflictions) | [제안] 기존 수치를 베끼지 않고 표시·단계 구조만 비교한다. |
| [body_injury.md §6](../design/briefs/body_injury.md): 겉옷·장갑·가방·수선 | [기존 PZ 조사](#21-project-zomboid) · [1차: TLD 공식 겹·손상 표시 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/) | [제안] 모바일 슬롯 수를 제한하는 데 참고한다. |
| [body_injury.md §8.1](../design/briefs/body_injury.md): 냄새·바람·씻기 | [PZ 냄새 근거 확인](#21-project-zomboid) · [2차: 7 Days to Die](https://7daystodie.wiki.gg/wiki/Raw_Meat) · [2차: State of Decay 2](https://state-of-decay-2.fandom.com/wiki/Consumables) · [2차: DayZ](https://dayz.wiki.gg/wiki/Infected) | [제안] PZ 재현이 아닌 독립 설계임을 표기한다. |
| [survival_detail.md §2–3](../design/briefs/survival_detail.md): 씻기 비용·공동체 위생·질병 | [2차: State of Decay 2 비교](https://state-of-decay-2.fandom.com/wiki/Consumables) · [1차: 1914 임시 수용공간 기록](https://www.amsterdam.nl/stadsarchief/stukken/eerste-wereldoorlog/leven-loods/) · [1차: 몸니·세탁 보건 자료](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera) | [제안] 실제 열차 운영 사실로 일반화하지 않고 설계 참고로만 쓴다. |

## 4. 확인하지 못한 것

[미확인] PZ 공식 위키는 검색 도구에서 robots 제한으로 열리지 않았고 게임 실행 파일도 분석하지 않았으므로, 냄새 추적이 코드에 아예 없는지까지는 결론 내리지 못했다. [PZwiki 좀비 항목 접근 시도](https://pzwiki.net/wiki/Zombie) · [PZ 공식 뉴스](https://projectzomboid.com/blog/news/)

[미확인] PZ B41과 B42의 생존 규칙 차이는 기존 조사 파일의 수치·버전 표기를 그대로 이어야 하며, 이 보충 조사에서 다시 검증하지 않았다. [기존 조사 참고](#21-project-zomboid) · [공식 B42.21 공지](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/)

[미확인] The Long Dark의 최신 게임 빌드 번호는 이번에 열람한 공식 v.393 도입 기록과 현재 위키 페이지만으로 확정하지 못했으며, 위키 수치가 어느 빌드에 대응하는지 확인되지 않았다. [공식 v.393 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/) · [TLD Cabin Fever 위키](https://thelongdark.fandom.com/wiki/Cabin_Fever)

[미확인] State of Decay 2와 DayZ의 인용 위키는 현재 게임 빌드와 정확한 효과 지속시간을 밝히지 않으므로 두 게임의 냄새 지속 시간을 비교하지 않았다. [State of Decay 2 Consumables](https://state-of-decay-2.fandom.com/wiki/Consumables) · [DayZ Infected](https://dayz.wiki.gg/wiki/Infected)

[미확인] 역사 자료로 확인한 것은 1914년 임시 수용공간의 세면·세탁·건조 환경이며, 피난민 열차 안의 실제 목욕차·소독 방식·정기 운영표는 확인되지 않았다. [Stadsarchief Amsterdam](https://www.amsterdam.nl/stadsarchief/stukken/eerste-wereldoorlog/leven-loods/)

## 5. 출처 표

| 구분 | 제목 | URL | 확인한 내용 |
|---|---|---|---|
| 1차 | 42.21 Stable Released — The Indie Stone | [공식 공지](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/) | 42.21 Stable 전환과 공지에서 다룬 변경 범위다. |
| 1차 | News — The Indie Stone | [공식 뉴스](https://projectzomboid.com/blog/news/) | 42.21 Stable 공지의 2026-09-28 게시 날짜다. |
| 1차 | Resolute Outfitter — The Long Dark Time Capsule | [공식 v.393 기록](https://www.thelongdark.com/time-capsule/resolute-outfitter/) | 겹쳐 입기, 젖음·결빙·건조, 의복 상태 표시와 보온 수치 소개다. |
| 2차 | Feels Like — The Long Dark Wiki | [페이지](https://thelongdark.fandom.com/wiki/Feels_Like) | 체감온도의 보온·방풍 계산 설명이며 게임 빌드는 표시하지 않는다. |
| 2차 | Clothing — The Long Dark Wiki | [페이지](https://thelongdark.fandom.com/wiki/Clothing) | 외층 방풍과 옷의 젖음 관련 설명이며 게임 빌드는 표시하지 않는다. |
| 2차 | Afflictions — The Long Dark Wiki | [페이지](https://thelongdark.fandom.com/wiki/Afflictions) | 저체온증·회복 시간·실내 체류 관련 상태 효과다. |
| 2차 | Condition — The Long Dark Wiki | [페이지](https://thelongdark.fandom.com/wiki/Condition) | 동상에 따른 최대 상태치 변화다. |
| 2차 | Cabin Fever — The Long Dark Wiki | [페이지](https://thelongdark.fandom.com/wiki/Cabin_Fever) | 실내 체류 시간 기준과 24시간 제약이다. |
| 2차 | Raw Meat — Official 7 Days to Die Wiki | [페이지](https://7daystodie.wiki.gg/wiki/Raw_Meat) | Version 2.5 날고기 냄새의 수량·시간·반경·상한이다. |
| 2차 | Emitting Smell — Official 7 Days to Die Wiki | [페이지](https://7daystodie.wiki.gg/wiki/Emitting_Smell) | 냄새 기능의 Alpha 16·17 제거와 Version 2.5 복귀 이력이다. |
| 2차 | 2.5 forum discussion — The Fun Pimps | [공식 커뮤니티 글](https://community.thefunpimps.com/threads/arrow-sponges-even-with-a-headshot-are-annoying-and-other-musings-2-5.46550/) | 7 Days 냄새 유예·세분화·물 세척에 대한 이용자 의견이다. |
| 2차 | Consumables — State of Decay 2 Wiki | [페이지](https://state-of-decay-2.fandom.com/wiki/Consumables) | ScentBlock 효과와 Zombait 아이템의 존재다. |
| 2차 | Mysterious Strangers — State of Decay 2 Wiki | [페이지](https://state-of-decay-2.fandom.com/wiki/Mysterious_Strangers) | ScentBlock·Zombait의 게임 내 설정과 획득 장면이다. |
| 2차 | Lethal zone is easy with double positive curveballs and scent block — Reddit | [토론](https://www.reddit.com/r/StateofDecay2/comments/1qt6lj5/lethal_zone_is_easy_with_double_positive/) | 플레이어 일부의 ScentBlock이 지나치게 강하다는 평가다. |
| 2차 | Infected — DayZ Wiki | [페이지](https://dayz.wiki.gg/wiki/Infected) | 감염자의 시야·소리 수색 설명이며 냄새 규칙은 기재하지 않는다. |
| 1차 | Leven in een loods — Stadsarchief Amsterdam | [시립 기록보관소](https://www.amsterdam.nl/stadsarchief/stukken/eerste-wereldoorlog/leven-loods/) | 1914 임시 수용공간의 세면 장소·침상·건조 줄·진료 공간이다. |
| 1차 | Lice factsheet — European Centre for Disease Prevention and Control | [ECDC 자료](https://www.ecdc.europa.eu/en/all-topics-z/disease-vectors/facts/factsheet-lice-phthiraptera) | 몸니 전파 경로, 발진티푸스 원인·전달 방식, 세탁·열처리 보건 안내다. |
| 확인 제한 | Zombie — PZwiki | [접근 시도한 공식 위키 항목](https://pzwiki.net/wiki/Zombie) | 검색 도구의 robots 제한으로 본문을 확인하지 못했다. |

