# 좀보이드 모드 조사: 의료·절단, 사후 지식 보존, 형질/스킬, 제작, 생존 욕구·UI (2026-10-05 기준)

조사 범위는 Project Zomboid 모드와, B42 바닐라가 모드를 대체한 부분이다. 수치와 상태는 2026-10-05에 확인했다. Steam 구독 수는 Workshop 검색 페이지에 내장된 JSON과 Steam Web API(`ISteamRemoteStorage/GetPublishedFileDetails`)에서 직접 읽었다. "현재 구독"은 지금 구독 중인 계정 수, "누적 구독"은 한 번이라도 구독한 계정 수다. 출처 링크는 각 Workshop 페이지로 단다. 메커니즘 수치는 가능한 한 모드 소스 코드(GitHub)에서 직접 확인했다.

**신뢰도 경고:** WebFetch 요약기와 검색엔진 요약이 Skill Recovery Journal, The Only Cure 구판 등을 "Steam 가이드라인 위반으로 삭제됨"이라고 반복 보고했다. 오보다. Steam 아이템 HTML에는 모든 아이템에 `style="display: none"`인 숨김 템플릿 문구("This item has been removed from the community…")가 들어 있고, 요약기가 이걸 실제 상태로 착각했다. Steam API도 SRJ에 `banned=0`, `visibility=0`(공개)을 반환했다. 보고서에 "삭제됨"이라고 쓰면 안 된다.

---

## 1. 절단과 의수: 어떤 모드가 있고 정확히 어떻게 작동하나

### Takeaway
절단 모드의 표준은 The Only Cure(TOC)다. 현재 구독은 B41판 약 50만, B42판 약 25만이다. 코드를 보면 감염 치료는 확률 굴림이 아니다. 감염 수치가 20 미만(0~100 척도)이고 팔 이외 부위(머리, 목, 몸통, 다리 등)에 물린 상처나 감염이 없을 때만 확정적으로 낫는다. 사망 위험은 출혈과 피해에서 나온다. 의수는 연구 없이 용접 스킬(갈고리 2, 의수 4)로 만들거나 의료 클리닉에서 줍는다. 최근 B42 모드들은 범위를 넓혔다. 다리 절단과 휠체어(LT Amputation), 미니게임식 수술과 즉석 목제 의수(Casualties Undead)가 나왔다.

### Cited Findings

#### TOC 계보와 현황
- 원조 The Only Cure(ID 2703664356, 작성자 Pao·MrBounty, 2022-01-01 게시, 2023-03-11 최종 업데이트)의 제목은 이제 "[DEPRECATED, CHECK THE DESCRIPTION] The Only Cure"이다. 설명은 "SUPERSEDED BY The Only Cure - Rebuilt. THIS VERSION IS NO LONGER SUPPORTED" 한 줄뿐이다. 그래도 현재 구독 397,035명, 즐겨찾기 19,090개가 남아 있다. 필수 모드는 Simple UI library(2760035814)였다. — [Workshop 2703664356](https://steamcommunity.com/sharedfiles/filedetails/?id=2703664356)
- 중간 포크 이름 "The Only Cure but better by Pao"는 Brutal Handwork 설명에서만 확인된다("FULLY compatible with The Only Cure but better by Pao. Keep the ability to attack without your Right Arm!"). — [Workshop 2934621024](https://steamcommunity.com/sharedfiles/filedetails/?id=2934621024)
- [B41] The Only Cure(3236152598, Pao): 2024-04-30 게시, 2025-10-05 최종 업데이트, 현재 구독 500,246, 누적 953,815. 설명은 B42판과 거의 같다. — [Workshop 3236152598](https://steamcommunity.com/sharedfiles/filedetails/?id=3236152598)
- [B42.20] The Only Cure(3580276809, Pao): 2025-10-04 게시, 2026-09-13 최종 업데이트, 현재 구독 248,581, 누적 361,257, 즐겨찾기 8,823. "rebuilt from scratch to support future additions and to feel as close as possible as a vanilla mechanic"이다. 구판에서 넘어오려면 새 캐릭터나 새 세이브가 필요하다. 싱글과 멀티를 지원하지만 "Host Mode is currently UNSUPPORTED!"다. — [Workshop 3580276809](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809)
- 소스는 GitHub(ZioPao/The-Only-Cure, GPL-3.0)에 있다. main 브랜치 최신 커밋 0d165f6(2026-09-13)은 Workshop 업데이트 날짜와 같다. — [GitHub](https://github.com/ZioPao/The-Only-Cure)

#### TOC 사용법 (Workshop 설명 기준)
- "Get a Saw or a Garden Saw, right click on it, and choose which limb to amputate." 톱을 해당 부위로 드래그해도 된다. 인벤토리에 붕대나 봉합 키트가 있으면 자동으로 쓰여 "multiplying the chances of your survival". 지혈대를 같은 쪽에 착용하면 절단 후 피해가 줄어든다. — [Workshop 3580276809](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809)
- 위팔(upper arm)을 자르면 의수를 장착할 수 없다. 절단 후에는 해당 쪽 스킬(Left/Right Side) 포인트가 쌓여 timed action이 점점 빨라진다. — [Workshop 3580276809](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809)
- 반흔화(Cicatrization) 상태는 체력 패널에서 본다. 붕대로 상처를 주기적으로 닦아야 하고, 덜 아문 상태로 의수를 끼우면 랜덤 출혈이 날 수 있다. — [Workshop 3580276809](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809)
- 손이 없으면 양손 무기 장착 등 "a lot of things"를 못 한다. 의수는 Hook Prosthesis와 Arm Prosthesis 두 종류이고 "crafted\found in medical areas"다. 갈고리는 행동이 더 느리다. 의수를 끼우면 Prosthesis Familiarity 퍽이 올라 점점 빨라진다. — [Workshop 3580276809](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809)
- 관리자 도구로 "Reset Amputations"와 "Force Amputation"이 있다. — [Workshop 3580276809](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809)
- 권장 동반 모드는 Fancy Handwork와 Brutal Handwork다(오프핸드 조작과 공격). 하지만 "At the moment, the mods listed here aren't compatible with B42.. Compatibility patches are on the workshop but haven't been tested."라고 적혀 있다. Brutal Handwork는 오프핸드 근접 공격, 쌍수, 맨손 공격을 더한다. — [Workshop 3580276809](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809); [Workshop 2934621024](https://steamcommunity.com/sharedfiles/filedetails/?id=2934621024)

#### TOC B42 코드에서 확인한 정확한 수치 (main @ 0d165f6)
- **사용 가능한 도구:** 설명에는 톱만 나오지만, 코드의 `SAWS_TYPES`에는 Saw, GardenSaw, Plank_Saw, SmallSaw, Machete, MacheteForged, Hatchet, HandAxe_Old, HandAxe가 들어 있다. 설명이 코드보다 뒤처졌다. 2차 출처 pzfans도 B42판은 "Saw, Axe, or Machete"라고 쓴다. — [StaticData.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/shared/TOC/StaticData.lua); [pzfans](https://pzfans.com/bitten_in_pz_hack_it_off_with_the_only_cure_mod/)
- **절단 시간:** `1000 − 50 × 응급처치(Doctor) 레벨` tick이다. 응급처치 10이면 500이다. 애니메이션은 "SawLog"다. — [CutLimbAction.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/client/TOC/TimedActions/CutLimbAction.lua)
- **감염 치료 조건(핵심):** `healInfection()`은 `infectionLevel < 20 and not isPartInfected`일 때만 작동한다. 좀비 감염 수치를 0으로 만들고 감염 플래그와 사망 타이머를 해제한다. 코드 주석은 "If the part was actually infected, heal the player, if they were in time (infectionLevel < 20)"이고, 함수 위에 "--- TO BE TESTED"가 붙어 있다. — [AmputationHandler.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/shared/TOC/Handlers/AmputationHandler.lua)
- **절단으로 살릴 수 없는 부위:** 발, 사타구니, 머리, 종아리, 목, 하복부, 상체, 허벅지가 `IGNORED_BODYLOCS_BPT`로 묶여 있다. 이 중 한 곳이라도 물리거나 감염되면 `isIgnoredPartInfected=true`가 되고, 그 뒤에는 절단해도 낫지 않는다. 코드 주석은 "if there's a bite there then the player is fucked"다. 결국 TOC B42에서 절단할 수 있는 건 좌우 팔의 손, 아래팔, 위팔뿐이다. — [StaticData.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/shared/TOC/StaticData.lua); [LocalPlayerController.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/client/TOC/Controllers/LocalPlayerController.lua)
- **확률 굴림 여부:** AmputationHandler에서 난수(ZombRand)는 절단 부위 출혈 시간에만 쓰인다. 지혈대가 없으면 10~20, 있으면 1~5다. 이 파일에는 치료 성공 확률을 굴리는 코드가 없다. 붕대와 봉합이 "생존 확률을 높이는" 방식은 절단 직후 바닐라 ISStitch와 ISApplyBandage 행동을 자동으로 큐에 넣는 것이다. — [AmputationHandler.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/shared/TOC/Handlers/AmputationHandler.lua)
- **절단 후 피해:** 인접 부위에 피해, 통증, 출혈, 깊은 상처를 준다. 크기는 기본값(손 60, 아래팔 80, 위팔 100)에서 surgeonFactor를 뺀 값이다. surgeonFactor는 수술자의 응급처치 레벨 × SurgeonAbilityImportance(샌드박스 기본 2, 범위 1~3)다. 지혈대가 있으면 기본값이 절반이 된다. 스트레스도 같은 값으로 설정된다. — [AmputationHandler.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/shared/TOC/Handlers/AmputationHandler.lua); [sandbox-options.txt](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/sandbox-options.txt)
- **반흔화 시간:** 손 120, 아래팔 144, 위팔 192에서 surgeonFactor를 뺀 값이다. 단위는 확인하지 못했다(Gaps 참조). — [StaticData.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/shared/TOC/StaticData.lua)
- **행동 시간 배수:** 손 2배, 아래팔 3배, 위팔 4배다. — [StaticData.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/shared/TOC/StaticData.lua). 애드온 작성자에 따르면 원본은 양팔의 모든 절단 구간 배수를 곱한다. 그래서 양팔을 어깨에서 자르고 의수를 낀 상태면 스킬 0에서 576배이고, "A one second action turns into nearly ten minutes." — [Workshop 3794771273](https://steamcommunity.com/sharedfiles/filedetails/?id=3794771273)
- **의수 제작 레시피:** `NeedToBeLearn = false`라서 레시피를 배울 필요가 없다. Arm 의수는 용접(MetalWelding) 4, 금속 파이프 4, 판자 2, 토치, 용접봉 4, 시간 150, 용접 XP 50이다. Hook은 용접 2, 금속 파이프 2, 판자 1, 토치, 용접봉 2, 시간 100, XP 30이다. 둘 다 `Tags = InHandCraft`라 작업대가 필요 없다. — [TOC_recipes.txt](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/scripts/TOC_recipes.txt)
- **의수 획득:** 루트 테이블 "MedicalClinicTools"에 갈고리(가중치 3), 의수(2), 지혈대(20)가 들어간다. — [Distributions.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/server/TOC/Distributions.lua)
- **시작 형질:** 손 절단(cost −8), 아래팔 절단(−10), 위팔 절단(−20)이 있다. 음수 비용은 포인트를 돌려준다는 뜻이다. 셋 다 XPBoosts로 왼쪽(Side_L) +4, Fitness −1, Strength −1을 받는다. — [TOC_traits.txt](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/scripts/TOC_traits.txt)
- **샌드박스 옵션:** — [sandbox-options.txt](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/sandbox-options.txt)
  - CicatrizationSpeed: 1~10, 기본 1
  - WoundDirtynessMultiplier: 0~5, 기본 1
  - SurgeonAbilityImportance: 1~3, 기본 2
  - 좌측·우측·의수 숙련 XP 배수: 기본 1.0
  - EnableZombieAmputations(좀비도 팔다리가 잘림): 기본 off
  - ZombieAmputationDamageThreshold: 기본 1
  - ZombieAmputationDamageChance: 기본 25%
- **행동 제한:** 양손이 모두 잘리면 무기 장착이 원천 불가다(코드 주석 "Both hands are cut off, so it's impossible to equip in any way"). 옷 착용과 옷 부가 행동도 같은 검사로 감싸져 있다. — [LimitActionsController.lua](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/lua/client/TOC/Controllers/LimitActionsController.lua)
- **치료 실패 체감:** GitHub 이슈에 "amputations don't always cure Knox infection"이라는 보고가 있다. 손과 아래팔 두 곳을 물린 뒤 팔을 잘랐는데도 죽었다는 보고도 있다. 둘 다 검색 요약으로만 확인했고 원문은 열람하지 못했다. 위키 요약(namu 미러)은 "물린 곳 위를 최대한 빨리 잘라야 하며 늦을수록 의미가 없어진다"고 쓴다(namu는 403으로 직접 열람 불가, 검색 스니펫). — [GitHub Issues](https://github.com/ZioPao/The-Only-Cure/issues); [namu 미러](https://en.namu.wiki/w/The%20Only%20Cure)

#### TOC 확장과 다른 절단 모드
- **[B42] The Only Cure Additions**(3794771273, Leesun, 2026-09-02 게시, 구독 1,323): 위팔 절단자용 "Upper Arm Socket"을 추가한다. 제작은 용접 5에 금속 파이프 3, 가죽끈 2, 벨트, 토치와 용접봉이고, 의료 클리닉에서도 드물게 나온다. 효과와 시간 규칙은 다음과 같다. — [Workshop 3794771273](https://steamcommunity.com/sharedfiles/filedetails/?id=3794771273)
  - 휘두르기 속도: 맨 위팔 절단면 0.70, 소켓 0.91, 갈고리 0.95, 의수는 정상.
  - 행동 시간: 팔마다 가장 높은 절단 부위만 계산하고, 스킬로 페널티를 갚는다. 양 위팔(소켓+갈고리)은 레벨 0에서 16배, 5에서 6.25배, 10에서 정상이다. 한쪽 위팔은 4배, 2.5배, 정상이다. 의수가 없으면 손 2배, 아래팔 3배, 위팔 4배다.
  - 먹기, 마시기, 읽기, 알약 복용에는 영향이 없다.
- **LT Amputation [42.20.4]**(3782593221, L1GHT, 구독 385, RP 서버용, TOC 기반): 팔(손, 아래팔, 위팔)에 더해 다리(발, 종아리, 허벅지) 절단을 추가한다. 다리 의수는 발과 종아리 절단에만 쓸 수 있다. 허벅지까지 잃으면 휠체어가 이동 속도를 크게 보정한다. 보행용 Mobility Cane과 무기용 지팡이가 따로 있다(휠체어와 같은 슬롯이라 중첩 불가). 출혈, 청결, 붕대, 봉합, 지혈대, 반흔화를 추적하고 서버에서 검증한다. — [Workshop 3782593221](https://steamcommunity.com/sharedfiles/filedetails/?id=3782593221)
- **Casualties Undead (Build 42)**(3805748433, Zaeer23·Centox, 2026-09-21 게시, 현재 구독 16,047, 즐겨찾기 3,951, B42.20 이상): "Casualties: Unknown"에서 영감을 받은 응급처치 오버홀이다. — [Workshop 3805748433](https://steamcommunity.com/sharedfiles/filedetails/?id=3805748433)
  - 처치 방식: 붕대, 봉합, 주사, 유리 제거, 부목, 소작, 톱 절단을 진행 막대 대신 마우스 미니게임으로 한다. 실패하면 아프거나 상처가 다시 벌어진다.
  - 절단: 팔다리를 물리면 톱으로 자르고 불에 달군 칼날로 소작한다. 가슴, 목, 머리는 소용없다.
  - 절단 후 상태: 팔이 없으면 아무것도 들 수 없고 모든 행동이 느려진다. 다리가 없으면 목발을 쓰거나 기어간다.
  - 의수·의족: 병원에서 나오거나 Metalworking 6과 First Aid 2로 직접 용접한다. "The Prosthetics skill gets you back up to 95% of your old speed."
  - 손이 아예 없을 때: 이로 가벼운 물건을 든다(큰 고통). 벽에서 나무를 물어뜯어 덕트테이프로 5조각을 붙이면 조잡한 목제 의수가 된다(약하고 잘 부서짐).
  - 신체 시뮬레이션: 심장 리듬, 혈압, 산소, 혈액, 장기 6개. 저절로 생기는 질환이 21종(기흉, 패혈증, 파상풍, 두개내 출혈, 저혈당 등)이다.
  - 사망: 심정지로 처리하고 제세동기 미니게임으로 되살릴 수 있다.
  - 기타: 저기분 시스템에 자해·자살 묘사가 있어 검열 옵션이 있다. 샌드박스 옵션은 약 40개이고, "Not compatible with The Only Cure"다.
- **Amputations RP**(2986581203, 구독 52,404, B41, 2023): 절단, 의수, 휠체어, 보청기, 지팡이 소품이다. "purely cosmetic and do not have any gameplay effects"이고, 작성자는 모델이 TOC에 들어갈 예정이라고 했다. — [Workshop 2986581203](https://steamcommunity.com/sharedfiles/filedetails/?id=2986581203)
- **Prosthetic Leg**(3738580033, 구독 2,503): 커미션으로 만든 왼쪽 의족이고 디버그 메뉴로만 스폰된다. — [Workshop 3738580033](https://steamcommunity.com/sharedfiles/filedetails/?id=3738580033)

#### 절단 말고 감염에 대응하는 모드 (비교용)
- **Antibodies**(2392676812, lonegamedev, 현재 구독 324,762, 누적 668,337, B41+B42, 2026-09-10 업데이트): 감염이 진행되면 항체가 생성되고 생성률은 감염 50%에서 정점이다. 컨디션, 상처, 감염, 위생이 생성률을 바꾼다. 기본 Base Antibodies Growth는 180이고 이때 감염 40% 지점에서 이긴다. 140이면 66%, 138이면 70%이고 135면 죽는다. 감염은 2~3일 안에 어느 쪽이든 결론이 난다. 의료 배경(+2 First Aid)이 있으면 진단 버튼이 생긴다. 작성자는 바닐라 Knox 감염이 응급처치, 재봉, 위생 같은 핵심 메커니즘을 무의미하게 만든다고 본다. — [Workshop 2392676812](https://steamcommunity.com/sharedfiles/filedetails/?id=2392676812)
- **Not Dead Yet**(3631727340, 구독 17,374, B42.20 MP): 감염이 95%(MP) 또는 99%(SP)에 이르면 생존 판정을 한 번 굴린다. 기본 25%이고 0~100% 조절할 수 있다. 형질 보정이 있고, 물린 곳이 많으면 생존률이 줄어든다(6곳이면 절반). 감염 수치는 0~100이고, "at 26% infection, which is just after you get the Sick moodle"이라고 쓴다. 설계 의도는 감염되자마자 'New Character'를 고르는 대신 끝까지 버티게 하는 것이다. — [Workshop 3631727340](https://steamcommunity.com/sharedfiles/filedetails/?id=3631727340)
- **They Knew**(B41판 2725378876: 현재 구독 1,238,603, 2022-02 이후 업데이트 없음 / B42판 3387110070: 209,609, 2024-12-19 이후 업데이트 없음): 희귀 좀비가 치료제를 들고 다닌다. 스폰 점수는 500으로, 골퍼 좀비 2000, 공원 관리인 10000과 비교된다. Zomboxivir 1회분은 모든 감염을 없애지만 이후 감염은 막지 못한다. Zomboxycycline은 24시간 감염을 예방하고 기본으로 꺼져 있다. — [Workshop 2725378876](https://steamcommunity.com/sharedfiles/filedetails/?id=2725378876); [Workshop 3387110070](https://steamcommunity.com/sharedfiles/filedetails/?id=3387110070)
- **Zombie Virus Vaccine [B42.14~B42.20]**(3615135168, 구독 156,252): 실험실 워크스테이션을 짓고, 유리를 녹여 실험기구를 만들고, 부검으로 혈액과 뇌 샘플을 얻고, 백혈구와 항체를 추출해 백신이나 치료제를 개발한다. 바이러스학 교재는 군사 시설, 병원, 대학 연구소에만 있다. "doesn't remove the fear of death… it gives you a long-term goal"이 설계 의도다. — [Workshop 3615135168](https://steamcommunity.com/sharedfiles/filedetails/?id=3615135168)

#### 바닐라 기준선
- 바닐라 PZ에는 팔다리 절단도 기본 치료제도 없다(2차 출처). — [pzfans](https://pzfans.com/bitten_in_pz_hack_it_off_with_the_only_cure_mod/)
- 기본 감염 확률은 긁힘 7%, 열상 25%, 물림 100%다. 1차 출처 pzwiki는 403으로 막혀서 2차 출처 여러 곳이 일치하는 것까지만 확인했다. — [ProGameGuides](https://progameguides.com/project-zomboid/how-to-deal-with-infections-in-project-zomboid/); [Supercraft](https://supercraft.host/wiki/project-zomboid/bitten/); [Steam 토론](https://steamcommunity.com/app/108600/discussions/0/3198118671854199481/)

### Inferences
- TOC의 치료 창(감염 20 미만)은 Sick 무들이 뜨는 약 26%(Not Dead Yet 기준)보다 앞선다. 즉 증상이 보이기 전에 잘라야 한다.
  - 물림은 감염이 100%라서 결정이 명확하다.
  - 긁힘(7%)과 열상(25%)에서는 "감염 여부를 모른 채 팔을 걸 것인가"라는 불확실성 하의 결정이 된다. 열차 게임의 "물린 팔 절단"도 이 긴장을 쓸 수 있다.
  - 다만 TOC처럼 창을 숨기면 "잘랐는데 죽었다"는 혼란과 버그 보고가 생긴다. 모바일에서는 창을 타이머로 보여줄지 숨길지 의도적으로 정해야 한다.
- 감염 수치가 Infection Mortality 기간(Antibodies FAQ 기준 2~3일)에 걸쳐 선형으로 오른다고 가정하면, 20% 창은 대략 처음 10~14 게임 시간이다. **미검증 추정이다.**
- TOC에서 생사를 가르는 건 확률이 아니라 세 가지다. 타이밍(창), 부위(팔만 가능), 그리고 출혈과 피해 관리(지혈대, 붕대, 수술자 응급처치 레벨)다. 확률 대신 준비물과 숙련으로 결과가 갈리는 구조는 의료칸과 의무병의 가치를 키운다. 열차 게임에 옮기기 좋다.
- 곱셈 페널티는 폭주한다(576배). 열차 게임의 절단 페널티는 상한을 두거나, 가장 심한 부위만 세거나, 숙련으로 되돌리는 방식(Additions의 16배 → 6.25배 → 정상)이 안전하다.
- 기능 회복 곡선이 있다(좌·우측 스킬, Prosthesis Familiarity, Casualties Undead의 95% 회복). 그래서 절단자가 영구적으로 쓸모없어지지 않는다. 이게 "절단자를 어떻게 대우할 것인가"라는 정치 문제의 경제적 토대가 된다. 희소한 용접 자원으로 만든 의수를 누구에게 먼저 줄지, 회복 기간 동안 배급을 줄지 같은 선택이 생긴다.
- TOC는 의수를 연구로 잠그지 않는다(학습 불필요, 용접 2/4). 연구로 해금하는 의수는 열차 게임만의 차별점이다. Casualties Undead의 2단 구조(현장 즉석 목제 의수 → 숙련 용접 의수)는 "현장 간이 제작 vs 열차 정밀 제작"과 바로 맞물린다.
- 다리 절단은 TOC가 다루지 않고 소형 모드(LT)만 다룬다. 열차라는 공간에서는 휠체어나 목발 사용자에게 "열차 안에서는 일하지만 원정은 못 나가는" 역할을 줄 수 있어 정치 시스템과 엮을 여지가 크다.
- 즐겨찾기/현재 구독 비율은 Casualties Undead가 공개 2주 만에 약 25%(3,951/16,047)이고 TOC B42는 약 3.5%다. 하드코어 의료를 원하는 소수의 열광은 강하지만 대중성은 아직 검증되지 않았다. 자해 묘사와 검열 옵션은 모바일 등급 심사에서 주의할 점이다.

### Gaps
- 원조 TOC(MrBounty, 2022)의 상세 메커니즘(예: 의수 종류)은 확인하지 못했다. Workshop 설명이 "SUPERSEDED" 한 줄로 바뀌었고 namu 미러는 403이다.
- TOC 반흔화 시간(120/144/192)의 단위(게임 시간인지, 갱신 주기 횟수인지)는 감소 로직을 끝까지 추적하지 못해 미확인이다.
- 바닐라 감염 수치가 선형으로 오르는지, Infection Mortality 기본값이 얼마인지는 1차 출처(pzwiki, 게임 코드)로 확인하지 못했다.
- GitHub 이슈의 "절단해도 안 낫는다" 보고는 원문과 재현 조건을 직접 보지 못했다.
- 다른 생존자가 절단자를 어떻게 대우하는지(사회·정치적 처우)를 모델링한 PZ 모드는 찾지 못했다. 바닐라에 NPC 사회가 없어서 생긴 공백으로 보인다.

---

## 2. 사후 지식 보존과 기술 전수: 스킬이 어떻게 보존되고 한계와 밸런스 설정은 무엇인가

### Takeaway
Skill Recovery Journal(SRJ)은 PZ 모드 전체에서 누적 구독 15위다(현재 281만, 누적 400만). 기본값은 관대하다. 획득 XP를 100% 복구하고, 무제한으로 다시 읽을 수 있고, 레시피도 복구한다. 기본으로 빠지는 건 직업·형질 시작 보너스, TV XP, Fitness·Strength다. 멀티에서는 기본적으로 쓴 사람의 계정(사용자명 + SteamID)만 읽을 수 있다. 그래서 SRJ는 "사람 간 지식 전달"이 아니라 "본인 계승"이다. 반대 방향의 설계(부분 복구, 직업 잠금, 페이지당 시간 비용, 살아 있는 교사의 전수)는 소형 변형과 B42.20 이후 신규 모드에 흩어져 있다.

### Cited Findings

#### Skill Recovery Journal (2503622437)
- 작성자는 MassCraxx와 Chuckleberry Finn이다. 2021-05-31 게시, 2026-09-04 최종 업데이트. 현재 구독 2,814,606, 누적 3,999,777, 즐겨찾기 95,795, 태그 B41/B42. 필수 모드는 errorMagnifier(2896041179)와 Mod Update and Alert System(3077900375)이다. 설명 텍스트는 "Lore-friendly(ish) solution to the loss of a character. Craftable journals which allow the recovery of skills and recipes."뿐이고 나머지는 이미지다. — [Workshop 2503622437](https://steamcommunity.com/sharedfiles/filedetails/?id=2503622437); [GitHub repo](https://github.com/Chuckleberry-Finn/Skill-Recovery-Journal)
- Steam "가장 많이 구독됨(전체 기간)" 정렬에서 15위다. — [Steam Workshop 순위](https://steamcommunity.com/workshop/browse/?appid=108600&browsesort=totaluniquesubscribers&section=readytouseitems)
- 제작 레시피(B42.20.1)는 다음 재료로 시간 150, `InHandCraft`다. — [recipe_SRJ.txt](https://github.com/Chuckleberry-Finn/Skill-Recovery-Journal/blob/main/Contents/mods/Skill%20Recovery%20Journal/42.20.1/media/scripts/recipes/recipe_SRJ.txt)
  - 노트, 저널, 일기장, 메모장 중 1개(소모)
  - 접착제 또는 목공풀
  - 가죽끈 3개(소모)
  - 실, 노끈, 낚싯줄, 치실, 힘줄실, 아라미드실 중 1개
- 저널은 펜이나 연필로 직접 갱신해야 하고, 같은 저널을 계속 업데이트하는 것이 기본 사용법이다(2차 요약). — [goodmods.info](https://goodmods.info/mods/project-zomboid/skill-recovery-journal.html)
- B42.20.1 샌드박스 기본값(코드에서 직접 확인): — [sandbox-options.txt](https://github.com/Chuckleberry-Finn/Skill-Recovery-Journal/blob/main/Contents/mods/Skill%20Recovery%20Journal/42.20.1/media/sandbox-options.txt)
  - RecoveryPercentage **100**(1~100). 다른 항목에서 −1을 고르면 이 값을 쓴다.
  - TranscribeSpeed **1.0**, ReadTimeSpeed **1.0**(0.001~1000).
  - IlliterateSpeedMultiplier **0**: "Set to 0 to prevent illiterate people from reading."
  - RecoverProfessionAndTraitsBonuses **false**: 직업·형질로 받은 시작 레벨은 복구하지 않는다.
  - TranscribeTVXP **false**. 툴팁: 켜면 "players can carry over watched XP between characters cumulatively".
  - RecoverPassiveSkills(Fitness+Strength) **0%**.
  - 범주별 복구율(Physical, Melee Combat, Firearm, Crafting, Survivalist, Farming): 기본 −1, 즉 일반 값을 쓴다.
  - KillsTrack(좀비·생존자 처치 수): **0%**.
  - RecoverRecipes **true**.
  - RecoveryJournalUsed **false**: 기본은 몇 번이든 다시 읽을 수 있다. 켜면 "each individual XP point can only be recovered once"다.
  - SecurityFeatures 기본값 **"Prevent Username/SteamID Mismatch"**. 다른 선택지는 "Only Prevent SteamID Mismatch"와 "Don't Prevent Mismatches"이고, 툴팁은 "Disabling this entirely would mean people can share journals"라고 경고한다. — [Sandbox.json(EN)](https://github.com/Chuckleberry-Finn/Skill-Recovery-Journal/blob/main/Contents/mods/Skill%20Recovery%20Journal/common/media/lua/shared/Translate/EN/Sandbox.json)
  - CraftRecipeNeedLearn **false**. true로 하면 "Currently there is no way to learn it, making the recipe uncraftable."
  - CraftRecipe: 서버가 저널 재료를 직접 다시 정의할 수 있다.
- 체인지로그에 따르면 보안 옵션은 Steam이나 플레이어 계정을 공유해서 치트하는 걸 막으려고 추가됐다(검색 요약, 원문 미열람). — [SRJ Change Notes](https://steamcommunity.com/sharedfiles/filedetails/changelog/2503622437)
- 멀티에서 저널 초기화 보고가 반복된다. 예를 들어 죽은 뒤 저널을 주워 "읽기"를 누르면 내용이 지워진다. 개발자는 표시 문제를 MP desync 탓으로 설명했다(WebFetch와 검색 요약, 미검증). — [SRJ 버그 토론](https://steamcommunity.com/workshop/filedetails/discussion/2503622437/3198119216812488644)
- 커뮤니티 평가는 갈린다. "치트"라는 시각과, 스킬 쌓기는 좋아하지만 전부 잃는 건 싫은 사람에게 좋은 타협이라는 시각이 공존한다(검색 요약). — [Steam 토론](https://steamcommunity.com/app/108600/discussions/0/3823036673955595931)

#### SRJ 변형과 보조 모드
- **SRJ - Profession Locked**(3055098573, B41, 2023, 구독 2,005): 직업이 다른 새 캐릭터는 이전 직업의 저널을 읽을 수 없다. — [Workshop 3055098573](https://steamcommunity.com/sharedfiles/filedetails/?id=3055098573)
- **SRJ (GAMMA)**(2734189587, B41, 2022, 구독 9,694): 감마 분포로 복구량을 반랜덤하게 하고, 레벨이 높을수록 더 많이 잃는다. 의도는 "balance the desire for a challenging game of consequence against the inconvenience of having to start all over"다. — [Workshop 2734189587](https://steamcommunity.com/sharedfiles/filedetails/?id=2734189587)

  | 기록 레벨 | 99% 확률로 최소 회복 | 50% 확률로 최소 회복 |
  |---|---|---|
  | 10 | 53% | 76% |
  | 5 | 71% | 88% |
  | 1 | 88% | 98% |

- **[42.20] SRJ Reminder**(3156717975, 구독 45,720): 스킬 레벨이 오를 때마다 알림을 띄우고 기록할 항목 수를 센다("...because you keep forgetting to write in it"). — [Workshop 3156717975](https://steamcommunity.com/sharedfiles/filedetails/?id=3156717975)
- B42.19~42.20 전환기에 비공식 패치가 나왔다. "PATCH EDITION (42.19)"(3728736631, 5,985)는 저널 레시피를 하드코딩으로 바꾼다(WebFetch 요약). "Skill Recovery Journal Hotfix"(3748247279, 5,918)도 있다. — [Workshop 3728736631](https://steamcommunity.com/sharedfiles/filedetails/?id=3728736631); [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Skill+Recovery+Journal&browsesort=textsearch&section=readytouseitems)

#### B42.20 이후 등장한 대안 저널
- **Skill Journal**(3776641628, 2026-08-02 게시, 구독 76,571): — [Workshop 3776641628](https://steamcommunity.com/sharedfiles/filedetails/?id=3776641628)
  - 기록 대상: XP, 배운 레시피, 독서 진행도, 처치 수. 펜이나 연필이 필요하다.
  - 원칙: "Never lowers a skill and never pushes one past what was written. It only fills the gap."
  - 형질과 직업은 저장하지 않는다.
  - 독서 진행도는 항상 복원되고 끌 수 없다. VHS XP를 두 번 받는 걸 막기 위해서다.
  - 멀티에서는 쓴 캐릭터만 읽는다.
  - 샌드박스: 복구율 100, 엔트리별 캐릭터당 1회 복구(기본 on), "Pay out XP at the reader's own learning rate"(기본 on), 체중 복구(기본 off) 등.
- **LG Skill Journal**(3779162647, 구독 11,110): — [Workshop 3779162647](https://steamcommunity.com/sharedfiles/filedetails/?id=3779162647)
  - 저널 3종: Skill Notebook(스킬 XP, 스킬북 진행도, 테이프)과 Skill Notepad(잡지, 사진 도면, 씨앗 봉투 같은 레시피)는 읽으면 소모된다. 둘을 합쳐 만드는 Skill Journal만 후계자에게 남는다.
  - 중복 방지: "Totals, not gains." 기록값과 현재값의 차이만 주므로 두 번째 저널은 아무것도 주지 않는다.
  - 시간 비용: 페이지로 매긴다. 스킬 하나 전체가 220쪽, 패시브 스킬이 550쪽이다. 레벨 5는 약 19쪽, 레벨 10은 220쪽이다. 바닐라 스킬북은 권당 220~380쪽이다.
  - 중단과 지급: 중간에 멈춰도 이어서 할 수 있고, 마지막 페이지 전에는 아무것도 주지 않는다.
  - 잠금: SP에서는 캐릭터 이름, MP에서는 이름 + 계정이다. 후계자가 죽은 사람 이름을 써야 하는 문제 때문에 이름 잠금은 옵션으로 끌 수 있다.

#### 살아 있는 사람이 가르치기
- **[B42 MP] Teach Knowledge**(3634599609, 구독 4,624, WIP): 숙련자가 근처 플레이어에게 수업을 한다. 레시피 수업(핫와이어링, 발전기)도 있다. — [Workshop 3634599609](https://steamcommunity.com/sharedfiles/filedetails/?id=3634599609)
  - 학생은 수락(Yes/No)해야 수업이 시작된다.
  - 교사는 자기 레벨보다 1 낮은 레벨까지만 가르칠 수 있다. 최소 교사 레벨은 5다(샌드박스).
  - 과목마다 도구가 필요하다. 목공은 망치나 톱, 재봉은 바늘과 실이다.
  - 응급처치는 근처에 해부 모델로 쓸 시체가 있어야 하고, 붕대와 소독약 또는 메스와 봉합 바늘이 필요하다.
  - 정비는 차량 6타일 이내에서만 한다. 달리기 수업은 교사가 5초 넘게 멈추면 끝난다.
- Workshop에서 "teach"로 검색하면 이것 말고는 구독 수백 명 이하의 소형 모드뿐이다(예: Teaching mod v0.5는 6명). — [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=teach&browsesort=textsearch&section=readytouseitems)

#### 독서 보조
- **Has Been Read**(2544353492, 현재 구독 2,904,450, 누적 4,095,859, B41+B42, 전체 13위): 책과 미디어에 미독(?), 미완(!), 완독(v) 표시를 단다. "Current Target"(o)으로 현재 레벨에 맞는 스킬북과, XP나 레시피를 주는 CD/VHS를 강조한다. — [Workshop 2544353492](https://steamcommunity.com/sharedfiles/filedetails/?id=2544353492); [Steam 순위](https://steamcommunity.com/workshop/browse/?appid=108600&browsesort=totaluniquesubscribers&section=readytouseitems)

#### B42 바닐라의 지식 체계 (모드가 하던 일을 일부 흡수)
- 레시피를 배우는 경로는 네 가지다. ① 직업과 형질, ② 레시피 잡지와 도면(schematic), ③ 아이템 연구(Research Craft, 아이템을 소모하지 않음), ④ 스킬 레벨 자동 학습(autolearn). 멀티에서 레시피 지식은 캐릭터별이라 동료도 각자 연구해야 한다(2차 가이드). — [gamers.wiki (2026-08-28)](https://gamers.wiki/en/games/project-zomboid/guides/project-zomboid-build-42-20-2-research-craft)
- 공식 패치노트로 확인한 내용:
  - 42.4.0(2025-03-04): "Halved the time required for the recipe research action. Having a Magnifying Glass or Loupe in either hand will further slightly reduce item research time." 같은 패치에서 "Removed XP from researching items"를 했다. 타이어 갑옷은 "crafting those and researching them will teach additional tire armor recipes"로 연쇄 연구 구조가 됐다. — [42.4.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1792751526173735)
  - 42.8.1(2025-05-20): 재봉 잡지 "Homespun"이 추가됐다. "Sewing Pattern" 아이템은 "works similarly to recipe clipping and schematics in that it teaches a single random Tailoring recipe"이다. — [42.8.1 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799817379626544)
  - 42.12.0(2025-09-25): 발전기 레시피를 Electrical 3에서 자동 학습한다. Mechanics 8/9/10에서는 기본, 중급, 고급 정비 레시피를 자동 학습한다. 레시피 잡지를 무한히 다시 읽어 스트레스와 지루함을 줄이던 버그도 고쳤다. — [42.12.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1811772772244324)
  - 42.13.0(2025-12-11): Inventive 형질이 자동 학습 판정에서 유효 레벨 +1을 받는다. — [42.13.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592122972)
  - 42.14.0(2026-02-16): "Trifurcated Literature loot setting into 'skill books,' 'recipe resources' and 'Other Literature' options." — [42.14.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1824644522845673)
  - 42.16.0(2026-03-31): VHS 시청도 독서와 똑같이 조명과 Illiterate 형질 규칙을 적용받는다. — [42.16.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1828441623111900)
- 2차 출처 요약: B42에서 스킬북은 XP 배수를 올리고, 레시피 잡지는 레시피를 해금한다. 스킬북은 개별 레시피를 가르치지 않는다. 첫 대장장이 잡지 "Iron Age Blacksmithing"은 Charcoal Pit, Primitive Forge, Primitive Furnace를 가르친다. — [pzfans B42 crafting](https://pzfans.com/b42_crafting_overhaul_surviving_the_apocalypse_one_skill_at_a_time/); [pzfans metalworking](https://pzfans.com/forging_the_apocalypse_build_42s_metalworking_overhaul_in_project_zomboid/)

### Inferences
- SRJ의 인기(전체 15위)는 영구 사망으로 XP를 전부 잃는 데 대한 거부감이 크다는 강한 신호다. 그런데 SRJ 기본값(100%, 무제한 재독)은 획득 XP에 대한 사망 페널티를 사실상 없앤다. "지식은 사람과 함께 죽는다"는 열차 게임의 주제와 반대다. 열차 게임은 GAMMA식 부분·체감 복구, 범주별 비율, 1회성 소모를 기본값으로 삼는 편이 주제와 맞는다.
- 지식을 받는 주체가 다르다. SRJ, Skill Journal, LG는 모두 같은 플레이어의 다음 캐릭터만 읽도록 잠근다(치트 방지).
  - 열차 게임은 싱글 기반이라 계정 공유 치트가 없다. 그래서 남이 쓴 매뉴얼을 다른 사람이 읽는 것 자체를 핵심 기능으로 삼을 수 있다.
  - 대신 "한 권으로 전원 만렙"을 막을 비용이 필요하다. 후보는 읽는 시간(LG의 페이지 비용), 사본 소모(LG의 Notebook/Notepad), 상한(Teach Knowledge의 "교사 레벨 −1", Skill Journal의 "기록값 이상으로는 못 올림")이다.
- "총량만 보장, 증분은 아님"과 "기록된 레벨까지 바닥만 올려 줌"이라는 중복 방지 원칙의 교훈은, 매뉴얼을 XP 덩어리가 아니라 "그 레벨까지의 바닥"으로 설계하라는 것이다. 이렇게 하면 여러 권을 읽어도 착취가 안 된다.
- 문맹 기본 차단(SRJ), 직업 잠금(Profession Locked), 이름 잠금(LG)은 모두 "누가 읽을 수 있나"를 정한다. 열차에서는 이걸 정치 자원으로 바꿀 수 있다. 예를 들면 누구에게 글을 가르칠지, 매뉴얼을 금고에 둘지 공용 도서칸에 둘지다.
- Reminder 모드(4.5만)가 따로 있다는 건 기록 갱신을 잊는 게 실제 마찰이라는 뜻이다. 모바일에서는 자동 기록이나 의식화된 기록 시점(예: 정차 시 도서칸에서 일지 쓰기)이 필요하다.
- 살아 있는 교사 모델(Teach Knowledge)은 소규모지만 "숙련자가 죽으면 상위 레벨 지식이 사라진다"를 기계적으로 구현한다. 매뉴얼로는 중간 레벨까지만, 그 이상은 살아 있는 장인에게서만 배우는 2층 구조로 만들면 "knowledge dies with people"이 시스템 수준에서 성립한다.
- B42 바닐라의 4경로(직업, 잡지·도면, 아이템 연구, 레벨 자동 학습)는 열차 게임의 "연구로 의수 해금"과 어휘가 같다. 특히 아이템 연구가 잘 맞는다. 실물을 관찰해 레시피를 얻고, 아이템은 소모되지 않고, 확대경이 있으면 빨라진다. 이걸 "의수 실물을 회수해 연구하면 제작법 해금"으로 옮기기 좋다.

### Gaps
- SRJ의 싱글플레이 잠금 동작(새 캐릭터를 같은 사용자명으로 취급하는지)은 코드에서 확인하지 못했다.
- SRJ 체인지로그와 토론 원문(보안 옵션 도입 경위, MP 초기화 버그)은 Steam이 429로 막아 직접 열지 못했고 검색 요약에 의존했다.
- Reddit(r/projectzomboid)에서 SRJ에 대한 정서는 직접 수집하지 못했다.
- B42 스킬북 XP 배수(권별, 레벨대별)의 정확한 값은 확인하지 못했다(pzwiki 403).

---

## 3. 형질과 스킬: 인기 모드는 무엇을 바꾸고 플레이어는 무엇을 좋아하나

### Takeaway
형질 모드의 큰 흐름은 플레이 방식에 따라 형질이 생기고 사라지는 "동적 형질"이다. Dynamic Traits(DTEM), Evolving Traits World(ETW), SOTO, More Traits의 동적 서브모드가 여기에 속한다. 플레이어가 좋아하는 이유는 오래 키운 캐릭터가 달라지는 보상감과 빌드 선택지 확대다. 대가도 크다. 모드끼리 충돌하고, 세이브가 깨지고, B42 멀티에서 망가지고, 관리자가 이탈해 포크가 난립한다. 형질과 무들의 실제 수치를 설명해 주는 UI 모드도 크게 인기다(More Description for Traits 181만, Clear description for Moodles 123만). B42 바닐라는 직업과 형질을 대대적으로 재조정했다.

### Cited Findings
- **Dynamic Traits and Expanded Moodles (DTEM)**(2459400130, PepperCat·Afyrmo, 2021-04-17 게시, 2026-09-30 업데이트, 현재 구독 398,252, 누적 932,412): B41.78과 B42.20~42.21+를 지원한다(SP, MP 호스트, 데디). Moodle Framework가 필수다. — [Workshop 2459400130](https://steamcommunity.com/sharedfiles/filedetails/?id=2459400130)
  - 동적 형질: 스킬, 몸 상태, 기분, 활동, 습관, 부상, 장기 행동에 따라 형질을 얻거나 잃는다.
  - 재조정: 직업 비용과 스킬 등을 다시 맞춘다.
  - 중독과 장기 상태: Smoker, Alcoholic, Addicted to Caffeine, Bloodlust, Anorexia, Melancholic, Nervous Wreck 등.
  - 생존 메커니즘: 확장 무들, 과다복용, 알레르기, 상처나 추위로 인한 질병, 과적 골절, 극도 피로로 기절.
  - 지식: 일부 레시피와 지식을 스킬, 연구, 직업 경로로 배운다.
  - 주의: "Removing DTEM from an existing B42 save is currently not recommended." 형질 데이터 때문에 세이브가 열리지 않을 수 있다.
- 공식 블로그 Mod Spotlight(2022-08)은 Dynamic Traits를 "for the player who wants a return on the long hours they put into a single game"이라고 소개했다. 예를 들어 Cowardly를 없애려면 좀비 수천 마리를 죽여야 한다. 부정적 획득도 있다. 스트레스를 받으면 악몽, 슬프면 과식, 항우울제를 남용하면 Nervous Wreck이다. — [공식 블로그](https://projectzomboid.com/blog/news/2022/08/mod-spotlight-dynamic-traits/)
- **More Traits [Legacy]**(1299328280, HypnoToadTrance·MusicManiac·Fajdek, 2018-02-12 게시, 현재 구독 1,940,396, 누적 3,128,393, 전체 34위): — [Workshop 1299328280](https://steamcommunity.com/sharedfiles/filedetails/?id=1299328280); [Steam 순위](https://steamcommunity.com/workshop/browse/?appid=108600&browsesort=totaluniquesubscribers&section=readytouseitems)
  - 상태: 지원, 버그 수정, 호환 패치가 모두 끝났고 공식 후속은 ETW다. 작성자는 "try finding AI-vibecoded 'fixed' version on the workshop. Godspeed o7"이라고 썼다.
  - 내용: 시작 장비 형질, 무기 숙련, 플레이 스타일별 XP 보너스, "zombie infection immunity with cure period" 같은 독특한 형질이 있다.
  - 포인트 설계: 남은 1포인트를 쓸 데 없는 문제를 줄이려고 −1/−2/−3/−5 형질을 다양하게 넣었다.
  - 동적 서브모드: 샌드박스 옵션 120개, 퍽 90여 개 중 50개 이상을 동적으로 만들 수 있다.
  - TOC가 있으면 자체 절단 방식 대신 TOC의 절단을 쓴다.
- **Evolving Traits World (ETW) + More Traits continuation**(2914075159, MusicManiac, 2026-10-04 업데이트, 현재 구독 242,372, 누적 540,093, B42; B41판은 3773982162로 분리): KillCount, Moodle Framework, UCWF가 필수다. — [Workshop 2914075159](https://steamcommunity.com/sharedfiles/filedetails/?id=2914075159)
  - 새 형질 85개. 동적 획득·상실은 선택이고, 모두 고정 형질로 둘 수도 있다.
  - 진행 상황을 보여주는 인게임 UI가 있다("No more needing 3 screens to play PZ").
  - Affinity 시스템은 시작 형질을 유지하기 쉽게 한다. Delayed traits는 무작위 지연 후 형질을 얻거나 잃게 한다.
  - 형질별 샌드박스 커스터마이즈가 가능하다.
- **More Traits Definitive Edition**(3799050151, GersonRess, 2026-09-10 게시, 구독 37,064): B42.20용 커뮤니티 연속판이다. "This is not a rebalance." 동적 서브모드는 빠졌고, 동적 진행은 "Traits As Skills" 애드온이 대신한다. — [Workshop 3799050151](https://steamcommunity.com/sharedfiles/filedetails/?id=3799050151)
- **SOTO (Simple Overhaul: Traits and Occupations)**(2840805724, hea, 2022-07-26 게시, 2026-03-09 업데이트, 현재 구독 749,182, 누적 1,355,175): — [Workshop 2840805724](https://steamcommunity.com/sharedfiles/filedetails/?id=2840805724); [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Simple+Overhaul+Traits&browsesort=textsearch&section=readytouseitems)
  - 목표: "Making vanilla occupations and traits viable".
  - 새 형질 40개 이상, 새 직업 26개(Tailor, Soldier, Botanist, Priest, Detective, School Teacher, Butcher, Miner, Criminal, Animal Control Officer 등).
  - 플레이 중 형질 획득·상실(예: Baseball Player나 Brave가 되거나 담배를 끊음).
  - "MAY NOT BE COMPATIBLE WITH ANY TRAITS MOD".
  - B42에서는 싱글만 정상이다("PLEASE AVOID TO USE IT IN B42 MULTIPLAYER!"). 커뮤니티 MP 수정판(3763874285, 7,262)이 따로 있다.
- 형질 모드 간 상호작용: More Traits, SOTO, ETW를 같이 쓸 때 생기는 운반 무게 문제를 고친 업데이트가 있었다(검색 요약). ETW는 Dynamic Traits, More Traits, SOTO와의 호환표를 별도 토론으로 관리한다. — [ETW 체인지로그(검색 결과)](https://steamcommunity.com/sharedfiles/filedetails/changelog/2914075159?p=8); [Workshop 2914075159](https://steamcommunity.com/sharedfiles/filedetails/?id=2914075159)
- **More Description for Traits [b41] [Not b42!]**(2685168362, 현재 구독 1,809,591, 전체 31위)와 **Clear description for Moodles**(2763647806, 1,228,617, B40/B41)는 형질과 무들의 실제 효과 수치를 보여준다. 후자는 무들 툴팁을 "tested and taken from the game's code" 수치로 바꾼다. — [Workshop 2685168362](https://steamcommunity.com/sharedfiles/filedetails/?id=2685168362); [Workshop 2763647806](https://steamcommunity.com/sharedfiles/filedetails/?id=2763647806)
- B42 바닐라: "Occupations and traits have been heavily rebalanced for fairer, more fun gameplay, providing more skill levels starting out." 새 직업 Rancher와 새 형질 Artisan, Target Shooter, Tinkerer가 추가됐다. — [공식 B42.20 기능 개요](https://projectzomboid.com/blog/features-overview-build-42-20/)
- TOC는 시작 절단 형질(손 −8, 아래팔 −10, 위팔 −20)을 넣어 장애를 캐릭터 생성 단계의 포인트 거래로 다룬다. — [TOC_traits.txt](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/scripts/TOC_traits.txt)

### Inferences
- 플레이어가 원하는 건 형질 개수보다 "캐릭터가 겪은 일이 몸과 성격에 남는 것"이다(DTEM과 ETW의 동적 획득·상실, 공식 블로그의 "return on long hours"). 열차 게임에서 승무원의 경험(절단, 감염 생존, 기근)을 동적 형질로 남기면 서사와 정치(낙인, 존경)가 연결된다.
- 동적 형질은 진행 상황이 안 보이면 좌절감을 준다. ETW는 "3개 화면" 문제를 UI로 풀었고, 수치 설명 모드 두 개는 각각 100만 이상 구독됐다. 수치 투명성 수요가 크다는 뜻이다. 모바일에서는 형질 진행도와 효과 수치를 탭 한 번에 보여줘야 한다.
- 모드 생태계의 고질병은 충돌, 세이브 파손, MP 붕괴, 관리자 이탈과 포크 난립이다(More Traits → ETW, Definitive Edition, "AI-vibecoded fixed version"). 처음부터 큐레이션된 소수 형질을 본편 시스템으로 설계해야 할 근거다.
- TOC의 "절단 형질을 시작 포인트와 교환"은 "장애 = 손해"라는 단순 등식을 만든다. 열차 게임에서 절단자 처우를 정치 주제로 다루려면, 장애를 순수 페널티가 아니라 역할 변화(예: 열차 내부 전문직 숙련 보너스)로도 표현할 여지를 남기는 게 좋다.

### Gaps
- 동적 형질에 대한 플레이어의 구체적 불만(너무 느림, 너무 쉬움 등)을 Reddit이나 리뷰에서 체계적으로 모으지 못했다.
- B42 바닐라 형질 재조정의 세부 수치(형질별 비용 변화)는 확인하지 못했다.
- More Traits에 원래 있었다는 "자체 절단 방식"의 실체는 확인하지 못했다.

---

## 4. 제작 확장과 B42 바닐라 제작 개편: 어떤 복잡도 문제가 있었고 B42는 무엇을 바꿨나

### Takeaway
Hydrocraft는 2015년부터 "kitchen sink" 방식으로 아이템을 약 2,000개까지 늘렸고, 플레이어는 어디서 시작할지 모르는 압도감을 느꼈다. 후속 관리자가 레시피를 병합하고 바닐라와 겹치는 아이템을 지웠지만 B41 판들은 2023년에 멈췄고 B42판은 없다. B42는 제작을 다시 만들었다. 워크스테이션, 원자재 가공, 잡지·도면·연구로 배우는 레시피, 입력·출력 검색 UI가 들어갔다. 그래도 별도 제작 UI 모드(Neat Crafting 78만)와 스킬 연습 모드가 인기다. 레시피 발견성과 숙련 노가다가 여전히 문제라는 뜻이다.

### Cited Findings

#### Hydrocraft의 역사와 복잡성
- 2015-10 공식 Mod Spotlight에서 Hydromancerx는 이렇게 설명했다. "a mod based around crafting and filling in the world of Zomboid with extra stuff… inspired by survival crafting games like Haven and Hearth… a compilation of many other smaller mods, abandoned mods and my own designs." — [공식 블로그](https://projectzomboid.com/blog/news/2015/10/mod-spotlight-hydrocraft/)
  - 규모: v3.7 당시 텍스처 1,873개, 추정 아이템 약 2,000개. "I lost track around v2.0!"
  - 내용: 치즈와 소시지 제조, 양봉, 누에, 약초학, 가축, 사냥, 개 품종, 일상 잡동사니.
  - 레시피 학습: "a TON of textbooks, as you need to learn all these new recipes from somewhere".
  - 본인이 이걸 "'kitchen sink' mods"라고 불렀다.
- 플레이어 반응은 "hydrocraft itself seems like a cluster frick of items....I dont know where to start"였다(2019-06-30). 답글은 위키가 낡았다고 지적했다. — [Steam 토론](https://steamcommunity.com/app/108600/discussions/0/1642041106366594353/)
- 후속판 체인지로그에는 "many recipes merged to reduce recipe count"와, 바닐라에 같은 게 생긴 아이템 삭제가 있다. 다른 반응으로는 "meaningless garbage"라는 평과, 모든 아이템 제작이라는 엔드게임 목표 덕에 플레이가 길어진다는 평이 있다(검색 요약, 원문 미열람). — [HydroCraft b41 Continued 체인지로그](https://steamcommunity.com/sharedfiles/filedetails/changelog/2778991696); [Steam 토론(검색 결과)](https://steamcommunity.com/app/108600/discussions/0/1697168437870004781/)
- 판본별 현황: — [Workshop 498441420](https://steamcommunity.com/sharedfiles/filedetails/?id=498441420); [Workshop 2081538550](https://steamcommunity.com/sharedfiles/filedetails/?id=2081538550); [Workshop 2778991696](https://steamcommunity.com/sharedfiles/filedetails/?id=2778991696); [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Hydrocraft&browsesort=textsearch&section=readytouseitems)
  - Hydrocraft (Build 40)(498441420, Hydromancerx·DemolitionDerby): 현재 구독 245,606. 2019-08-16에 멈췄고 v11.1은 Build 40.43에서 테스트됐다.
  - Hydrocraft XS(2081538550, David Hasihoff): 115,093, 2023-12-10에 멈췄다. 설명 전문은 "As many things in B42 will not be needed any more Hc must get rid of a lot."이다.
  - HydroCraft b41 Continued(2778991696): 100,838, 2023-05-19 핫픽스가 마지막이다.
  - B42에서 살아남은 건 "Wheelbarrow from Hydrocraft" 이식판(2926995676, 56,368)뿐이다.

#### B41 시절 제작 UI 모드
- **Craft Helper Continued**(2787291513, Lanceris, 현재 구독 1,591,657, 누적 2,638,837, B41 전용, 2024-03-31 이후 업데이트 없음): 아이템을 우클릭하면 그 아이템이 들어가는 레시피와 그 아이템을 만드는 법을 보여준다. 전체 검색, 즐겨찾기, 카테고리 필터가 있다. 원판 Craft Helper (41.x)(2186592938)도 651,696이다. — [Workshop 2787291513](https://steamcommunity.com/sharedfiles/filedetails/?id=2787291513)

#### B42 바닐라 제작 개편 (공식)
- B42 공식 개요의 제작 관련 내용: — [공식 B42.20 기능 개요](https://projectzomboid.com/blog/features-overview-build-42-20/)
  - "Build 42 of Project Zomboid overhauls crafting…"
  - 입력 재료를 고를 수 있고, 레시피를 입력 아이템이나 출력 아이템으로 검색할 수 있다.
  - 여러 개를 한 번에 만들거나, 조건이 맞으면 우클릭 단축으로 만든다.
  - 새 제작 방식은 석공(masonry), 조각(carving), 뗀석기(knapping), 대장장이(blacksmithing)이고 관련 직업과 스킬이 붙는다.
  - "A Workstation system interfaces with crafting to create items, with a variety of different surfaces and devices that can be constructed and/or found throughout the world."
  - 사냥은 일부 고급 제작 레시피의 전제다.
  - 근접 무기는 손잡이 내구도, 머리 내구도, 날의 예리함을 따로 추적한다.
  - 제작 가능한 satchel을 포함한 가방, 카톤 포장, 액체 혼합이 들어갔다.
  - 공식 모드 매니저(로드 순서, 의존성, 비호환 표시, 프리셋 공유)가 생겼다.
- 패치노트 세부:
  - 42.4.0: 일부 조각 레시피의 autoLearn 조건을 조였다("too generous; they are still generous"). 연구 시간을 절반으로 줄이고 연구 XP를 없앴다. — [42.4.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1792751526173735)
  - 42.11.0: 레시피 잡지를 우클릭하면 제작 UI의 해당 레시피로 바로 이동한다. 워크스테이션이 필요한 레시피를 워크스테이션 없이 하던 버그를 고쳤다. — [42.11.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1806698490822145)
  - 42.12.0: 플레이어에게 보이는 "Metalworking" 표기를 전부 "Blacksmithing"으로 바꿨다. — [42.12.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1811772772244324)
- 2차 가이드 요약(개별 출처 미특정, 낮은 신뢰도): 기본 작업대(판자, 못, 망치)에서 시작해 대장간(forge), 가마(kiln), 도축대로 이어지는 스테이션 사슬이 있다. 제작 조건은 스킬 레벨, 잡지나 레시피 아이템, 도구라는 세 관문이다. — [pzfans](https://pzfans.com/b42_crafting_overhaul_surviving_the_apocalypse_one_skill_at_a_time/); [gamemetahub](https://www.gamemetahub.com/games/project-zomboid/build-42-survival-guide)

#### B42 제작 관련 인기 모드
- **Neat Crafting [B42]**(3502080466, Afyrmo·Rocco, 2025-06-17 게시, 현재 구독 781,274, 누적 1,036,087, B42.9~42.21.x): 바닐라 B42 제작 UI를 대체한다. "Designed for both vanilla crafting and heavily modded games." NeatUI Framework가 필수다. XP 표시 애드온(3540503606)도 266,201이다. — [Workshop 3502080466](https://steamcommunity.com/sharedfiles/filedetails/?id=3502080466); [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Neat+Crafting&browsesort=textsearch&section=readytouseitems)
  - 리스트 뷰와 그리드 뷰
  - 이름, 필요 아이템, 결과 아이템으로 검색
  - 카테고리 필터와 제작 가능 여부 필터
  - 대체 재료 선택(Item Picker)과 입출력 툴팁
  - 워크스테이션 제작 지원, 뒤로·앞으로 탐색
  - 크기와 투명도 조절, 컨트롤러 지원
- **More Builds**(515555911, ProjectSky, 2015 게시, 2026-10-01 업데이트, 현재 구독 1,268,149): B42 네이티브 건설 시스템으로 전면 재작성했다. 바닐라풍 가구, 수납, 가전, 조명, 문, 벽 등을 추가하고 검색, 카테고리, 즐겨찾기를 지원한다. B41 백포트는 불확실하다. — [Workshop 515555911](https://steamcommunity.com/sharedfiles/filedetails/?id=515555911)
- **Practice Crafting Skills**(3765795716, 2026-07-16 게시, 68,212): 재료와 도구로 연습 레시피를 반복해 스킬을 올린다. 대상은 Knapping, Carving, Pottery, Blacksmithing, Carpentry, Electronics, Glassmaking, Masonry, Mechanics, Tailoring, Welding, First Aid다. "makes early-level grind more tolerable". 단계는 레벨 0/2/4(어려움 버전 0/3/6)이고 기본 XP는 30/60/100이다. — [Workshop 3765795716](https://steamcommunity.com/sharedfiles/filedetails/?id=3765795716)
- **Common Sense**(2875848298, Braven, 현재 구독 3,560,628, 누적 5,019,797, 전체 6위, 2025-03-07 이후 업데이트 없음): "상식" 상호작용을 더한다. 쇠지렛대로 문, 창, 차량 따기, 즉석 재료로 시트 만들기, "Using Alcohol to sanitize Dirty Bandages", 무기와 도구 수리 등이다. B42.20용으로는 커뮤니티판 "Common Sense [B42.20+]"(3750253491, 1Vita, 318,772)와 "B42.20 - Community Compatibility Fix"(3717968421, 75,495)가 따로 있다. — [Workshop 2875848298](https://steamcommunity.com/sharedfiles/filedetails/?id=2875848298); [Workshop 3750253491](https://steamcommunity.com/sharedfiles/filedetails/?id=3750253491); [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Common+Sense&browsesort=textsearch&section=readytouseitems)
- 모드 레시피도 "현장 제작" 태그를 쓴다. TOC 의수와 SRJ 저널 레시피는 모두 `Tags = InHandCraft`다. — [TOC_recipes.txt](https://github.com/ZioPao/The-Only-Cure/blob/main/42/media/scripts/TOC_recipes.txt); [recipe_SRJ.txt](https://github.com/Chuckleberry-Finn/Skill-Recovery-Journal/blob/main/Contents/mods/Skill%20Recovery%20Journal/42.20.1/media/scripts/recipes/recipe_SRJ.txt)

### Inferences
- Hydrocraft의 교훈은 아이템 수가 곧 재미가 아니라는 것이다. 연결고리가 안 보이면 아이템 2,000개는 쓰레기 더미로 읽힌다. 후속 관리자의 레시피 병합은 사후 수습이었다.
  - 열차 게임의 "현장에서는 간단한 제작만(가방, 새총, 덫), 복잡한 제작은 열차에서"는 이 문제를 구조로 막는 설계라 타당하다.
  - 다만 열차 쪽 제작에도 체인을 보여주는 UI(무엇으로 무엇을 만들 수 있나)가 없으면 같은 문제가 열차 안에서 반복된다.
- 레시피 발견 UI 수요는 빌드가 바뀌어도 사라지지 않았다(B41 Craft Helper 159만, B42 Neat Crafting 78만). B42 바닐라가 입출력 검색을 넣었는데도 대체 UI가 78만을 모았다. 모바일에서는 "이 재료로 만들 수 있는 것"과 "이걸 만들려면 부족한 것"을 첫 화면 수준으로 보여줘야 한다.
- B42의 `InHandCraft`와 워크스테이션 이분법은 열차 게임의 현장과 열차 구분에 1:1로 대응한다. 열차 칸을 워크스테이션(대장간 칸, 의무칸, 연구칸)으로 설계하면 B42 바닐라 구조를 검증된 틀로 빌려 쓸 수 있다.
- Hydrocraft(2015)가 이미 교재로 레시피를 배우게 했고, B42 바닐라는 이를 대규모로 채택했다. "매뉴얼 = 레시피 해금"은 장르에서 검증된 문법이다. 열차 게임의 차별점은 매뉴얼이 사람의 죽음, 즉 지식 소실과 연결되는 부분이다.
- 연습 레시피 모드(6.8만)는 B42 숙련 곡선이 노가다로 느껴진다는 신호다. 모바일은 세션이 짧으니 숙련 획득을 실제 생산 활동에 묶어 노가다 행위를 없애는 편이 낫다.

### Gaps
- B42 제작 개편에 대한 플레이어 불만(복잡도, 노가다)은 Reddit이나 리뷰에서 직접 모으지 못했다. 연습 모드와 UI 모드의 인기로 간접 추정했다.
- Hydrocraft 후속판 체인지로그 원문은 Steam 429 때문에 열지 못했다(검색 요약에 의존).
- B42 워크스테이션 목록과 레시피 수 같은 정량 정보는 공식 자료로 확인하지 못했다(pzwiki 403).

---

## 5. 생존 욕구(배고픔·피로·추위)와 체력·인벤토리 UI 모드

### Takeaway
이 분야의 대중적 모드는 욕구를 가혹하게 만드는 쪽이 아니라, 상태를 한눈에 보여주고 조작을 줄이는 쪽이다. Minimal Display Bars 166만, Mini Health Panel 157만, Moodle Framework(B41) 150만, Clear description for Moodles 123만, Better Sorting 331만, Proximity Inventory 218만이 그 예다. 체온, 상처, 패혈증을 정밀 시뮬레이션하는 B42 모드는 구독 수만 이하의 니치다. 널리 쓰이는 배고픔 오버홀은 찾지 못했다. B42 바닐라도 "붕대 더블클릭 → 가장 심한 부위에 자동 적용" 같은 단순화를 넣었다.

### Cited Findings

#### 상태 표시
- **Minimal Display Bars (MDB)**(2004998206, ATPHHe, 현재 구독 1,664,281, 누적 2,934,953, 전체 43위, 2021-09-13 이후 중단, MIT): — [Workshop 2004998206](https://steamcommunity.com/sharedfiles/filedetails/?id=2004998206); [Workshop 3388844542](https://steamcommunity.com/sharedfiles/filedetails/?id=3388844542); [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Minimal+Display+Bars&browsesort=textsearch&section=readytouseitems)
  - 막대: Health, Hunger, Thirst, Endurance, Fatigue, Boredom, Unhappiness, Temperature, Calories.
  - 체력 막대는 다치면 노랑과 빨강으로 바뀌고, 미처치 상태(깊은 상처, 물림, 출혈, 골절, 기아, 열 등)에서 깜빡인다.
  - 막대마다 숨기기와 가로·세로 전환이 된다.
  - B42 포트 "MDB + Nutritions + Discomfort"(3388844542, Vorshim, 73,822)는 스트레스, 지방, 단백질, 탄수화물, 불편함, 질병, 젖음 막대와 프리셋 공유를 더했다. 단독 42.21판(3775659041, 16,326)도 있다.
- **Mini Health Panel**(2866258937, Speedy Von Gofast, 현재 구독 1,573,225, 누적 2,406,175, 전체 67위, B41+B42.20, 2026-10-04 업데이트): 체력 패널을 열지 않아도 실루엣이 상주하고, 치료할 게 없으면 사라진다. B42에서는 부위별 근육 긴장 표시가 추가됐다. — [Workshop 2866258937](https://steamcommunity.com/sharedfiles/filedetails/?id=2866258937)
  - 빨강 깜빡임: 미처치 상처
  - 흰색: 붕대나 부목으로 처치됨
  - 주황: 붕대가 더러움
  - 붕대를 감았는데도 깜빡임: 처치가 불완전함(유리가 박혀 있음, 봉합 필요 등)
  - 우클릭하면 상처 목록이, 좌클릭하면 바닐라 패널이 열린다.
- **Moodle Framework**: B41판(2859296947, 1,501,040)과 B42판(3396446795, Tchernobill, 475,885)이 따로 있다. 모더용 무들 추가 프레임워크로, 무들당 30×30 텍스처, 좋음·나쁨 각 4단계, 0~1 값을 쓴다. B42판은 API 변경("IsoPlayer ModData.Moodles was removed") 때문에 하위호환 모드가 따로 필요하다. — [Workshop 3396446795](https://steamcommunity.com/sharedfiles/filedetails/?id=3396446795)
- **Clear description for Moodles**(2763647806, 1,228,617): 무들에 마우스를 올리면 긍정·부정 효과를 코드 기준 수치로 설명한다. — [Workshop 2763647806](https://steamcommunity.com/sharedfiles/filedetails/?id=2763647806)

#### 원터치 처치
- **Medical Meister**(3173649443, 현재 구독 125,887, B41/B42 Stable과 MP에서 작동 확인): 무들 아이콘을 클릭하면 대응 행동을 바로 실행한다. 행동은 Mod Options에서 바꿀 수 있다. — [Workshop 3173649443](https://steamcommunity.com/sharedfiles/filedetails/?id=3173649443)
  - 출혈 → 붕대. 한 번에 1부위이고 피해가 가장 큰 부위가 우선이다.
  - 배고픔 → 먹기. 날것, 미개봉, 상한 것, 독, 술, 즐겨찾기 음식은 제외한다.
  - 갈증 → 마시기, 통증 → 진통제, 공황 → 베타차단제, 젖음 → 수건, 지루함 → 독서.
- B42 바닐라 42.13.0: "Double Clicking on Bandages now applies them to an injury. If there are multiple body parts that can benefit from being bandaged, then the body part that is inflicting the most current damage will be the one that is bandaged." 읽을거리를 더블클릭하면 읽기를 시작한다. — [42.13.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592122972)
- B42 바닐라 42.6.0: 체력 패널 컨텍스트 메뉴(붕대, 소독 등)에 아이템 아이콘이 표시된다. — [42.6.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1794830911001792)
- 바닐라에는 자동 마시기(Autodrink)가 있다. 42.3.0에서 갈증과 오염 계산을 일반 마시기와 같게 맞췄다. — [42.3.0 패치노트](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1790848102789684)

#### 정밀 의료·상처 (니치)
- **Wounds Overhaul [B42]**(3775026731, 21,717, 2026-07-31 게시): — [Workshop 3775026731](https://steamcommunity.com/sharedfiles/filedetails/?id=3775026731)
  - 검사: 체력 탭 실루엣은 "무엇"이 아니라 "얼마나 나쁜지"만 색으로 보여준다. 부위를 클릭해 검사해야 상처 종류를 알 수 있다. 검사 시간은 First Aid에 따라 3~12초이고, 숙련이 높으면 수치, 패혈증 게이지, Knox 감염 단계까지 보인다.
  - 패혈증: 약 12시간 뒤 피로감이 오고, 이어서 열, 거동 불가, 약 3일째 사망으로 진행된다.
  - 항생제: 한 알이 16시간 유지되고 세 알 연속 복용해야 끝난다. 중간에 끊기면 되돌아간다.
  - 봉합: 드래그 미니게임이다.
  - 수혈(샌드박스 옵션, 기본 off): 혈액형이 실제 인구 비율로 배정된다. 보관은 실온 8시간, 전원이 들어온 냉장고 35일이고 냉동하면 폐기된다. "Carries what the donor carried - Knox included."
- **Proper Infected Wounds**(3410729454, 27,688): 더러운 붕대가 심한 상처 감염과 질병을 일으킨다. First Aid가 낮으면 가벼운 상처 감염이 보이지 않는다. — [Workshop 3410729454](https://steamcommunity.com/sharedfiles/filedetails/?id=3410729454)

#### 배고픔, 피로, 추위
- Workshop에서 "hunger"로 검색한 상위 결과는 모두 소규모다(Real Zombie Decay: Aging & Hunger 1,298, HungerToStamina 424, No Hunger and Thirst 569). 널리 구독된 배고픔 오버홀은 찾지 못했다. — [Steam 검색 "hunger"](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=hunger&browsesort=textsearch&section=readytouseitems)
- **Sleep On It**(2673713236, 670,822, B41): 자는 동안 지루함과 슬픔이 서서히 줄어든다. — [Workshop 2673713236](https://steamcommunity.com/sharedfiles/filedetails/?id=2673713236)
- **Sleep with Friends v2.1**(2686624983, 599,358, B41+B42): 멀티에서 수면 시간을 압축한다. 바닐라 수면 시스템은 그대로 두고, 잠들 때 스탯을 기록한 뒤 공식대로 줄여서 적용한다. — [Workshop 2686624983](https://steamcommunity.com/sharedfiles/filedetails/?id=2686624983)
  - 기본값: RTorIG=1(실시간 분 단위), SleepLength 2.0(완전 피로 시 실시간 2분), 지구력 회복 배수 2.
  - 침대 품질 배수: 바닥 0.6, 바닥+베개 0.75, 나쁜 침대 0.9, 보통 1.0, 보통+베개 1.05, 좋은 침대 1.1, 좋은 침대+베개 1.15.
- **Comfy Sleeping [B41 & B42.19+]**(2998737588, 70,836): 조건에 따라 수면 질이 달라지는 편안함 시스템이다(GameRant 요약). — [Steam 검색 "sleep"](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=sleep&browsesort=textsearch&section=readytouseitems); [GameRant](https://gamerant.com/project-zomboid-best-mods-build-42-b42/)
- **Realistic Temperature Mod [B42.18+ MP]**(3600401184, RedChili, 60,136): 실내 온도를 시뮬레이션한다. 갱신 주기는 게임 시간 1분이다. — [Workshop 3600401184](https://steamcommunity.com/sharedfiles/filedetails/?id=3600401184)
  - 공기 흐름: 열린 문, 창, 벽 틈으로 공기가 드나든다.
  - 건물 내부: 같은 건물의 방끼리 온도가 평준화되고, 플레이어가 없는 동안도 계산한다. 전력이 있으면 HVAC가 돈다.
  - 신체: 옷의 보온 효율이 바뀌고 저체온증이 더 치명적이다.
  - 히터 4종이 추가된다.
- DTEM은 극도 피로 시 기절, 과적 골절, 상처나 추위로 인한 질병을 샌드박스 옵션으로 더한다. — [Workshop 2459400130](https://steamcommunity.com/sharedfiles/filedetails/?id=2459400130)

#### 인벤토리
- **Inventory Tetris**: B41 Legacy(2982070344, 301,036), B42판(3397561666, 119,914, [DISCONTINUED], MIT), 새 유지판(3775513231, 59,919, B42.20, Equipment UI 포함)이 있다. — [Workshop 3397561666](https://steamcommunity.com/sharedfiles/filedetails/?id=3397561666); [Workshop 3775513231](https://steamcommunity.com/sharedfiles/filedetails/?id=3775513231)
  - 그리드 인벤토리라 모든 아이템이 크기를 갖고 회전할 수 있다.
  - 가방은 무게 감소뿐 아니라 공간을 준다. 착용한 아이템은 공간을 차지하지 않는다. "No more shoving 3 boxes of cereal and a carton of milk in your pants."
  - Dextrous와 All Thumbs 형질이 검색 속도와 연동된다. 컨트롤러를 지원한다.
- **Equipment UI**(2950902979, 현재 구독 1,828,406, 전체 46위, [DISCONTINUED], MIT): STALKER와 Tarkov에서 영감을 받은 페이퍼돌 장비 패널이다. 드래그 앤 드롭, 충돌 슬롯 강조, 장착 아이템을 인벤토리에서 숨기기를 지원한다. B42 포크는 "Equipment UI – STABLE +"(3682936016, 127,798)와 "SP/MP [B42.20+]"(3780682550, 57,601)다. — [Workshop 2950902979](https://steamcommunity.com/sharedfiles/filedetails/?id=2950902979); [Steam 검색](https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Equipment+UI&browsesort=textsearch&section=readytouseitems)
- **Better Sorting**(2313387159, 3,306,835, 전체 5위, B41+B42)는 아이템을 재분류하고, **Proximity Inventory**(2847184718, 2,183,226, B42.20+)는 주변 컨테이너를 한 화면에서 루팅하게 한다. — [Workshop 2313387159](https://steamcommunity.com/sharedfiles/filedetails/?id=2313387159); [Workshop 2847184718](https://steamcommunity.com/sharedfiles/filedetails/?id=2847184718); [Supercraft 목록(검색 요약)](https://supercraft.host/wiki/project-zomboid/pz_best_mods_2026/)

### Inferences
- 대중이 원하는 건 "덜 귀찮은 생존"이다. 상위 모드는 정보 노출과 조작 절감이고, 가혹한 시뮬레이션은 수만 명 규모의 니치다. 모바일 열차 게임은 욕구 수치를 단순화하더라도 상태 가시성(막대와 실루엣)과 원터치 처치를 기본으로 주는 편이 대중성에 맞다.
- Mini Health Panel의 색 체계(빨강 깜빡임 = 미처치, 흰색 = 처치, 주황 = 붕대 교체, 처치 후에도 깜빡임 = 불완전)는 터치 UI에 거의 그대로 옮길 수 있다. 평소에는 숨기고 문제가 생길 때만 뜨는 자동 숨김도 작은 화면에 맞다.
- Medical Meister와 바닐라 42.13의 공통 원칙은 "탭 한 번에 가장 심한 곳부터 자동으로"다. 모바일에서는 '처치' 버튼 하나에 우선순위 자동 대상 지정을 주고, 세부 처치는 길게 눌러 여는 2단 구조가 맞다.
- Wounds Overhaul과 Proper Infected Wounds는 숙련도가 정보를 열어 준다(검사 시간, 보이는 수치, 감염 단계). 의무병 같은 열차 승무원 역할의 가치를 UI 정보량으로 표현하는 장치로 쓸 수 있다. 의무병이 죽으면 정보가 흐려지게 하면 "지식은 사람과 함께 죽는다"가 UI에도 반영된다.
- 그리드 인벤토리(Tetris)는 인기가 높지만 개발 부담이 크다. B42판이 중단됐고 포크가 갈라졌다. 페이퍼돌(Equipment UI)은 B41에서 183만이었다. 터치에서는 슬롯과 페이퍼돌에 무게나 칸 수 제한을 더하는 쪽이 그리드 회전보다 조작이 단순하다(추정).
- 수면의 핵심 레버는 시간 압축과 침대 품질 배수였다. 열차의 침대칸 등급(바닥 0.6 ~ 좋은 침대+베개 1.15)은 바로 정치적 배분 자원이 된다. 누가 좋은 침대를 쓰는가의 문제다.
- Realistic Temperature의 방 단위 열 평준화와 문·창 개폐 모델은 "칸 단위 난방"으로 단순화하면 열차 칸별 온도 관리로 옮길 수 있다.

### Gaps
- 배고픔이나 영양 시스템을 바꾼 대형 모드는 찾지 못했다. "nutrition", "calorie" 같은 검색어로 더 찾아볼 여지가 있다.
- Comfy Sleeping의 세부 메커니즘은 페이지를 직접 열지 못했다(GameRant 요약만 확인).
- B42 바닐라 체력·의료 시스템의 변경 전반은 체계적으로 조사하지 않았다. 이 노트는 패치노트 키워드 검색 수준이다.

---

## 6. 인기도와 B41/B42 지원 현황 (2026-10-05 기준)

### Takeaway
B42는 2026-07-29에 42.20으로 안정판이 됐고, 2026-09-28에 42.21 안정판이 나왔다. B41은 `legacy41` 베타 브랜치로 남아 있고 2026-08에 핫픽스(41.78.21)까지 받았다. 대형 모드 다수는 B41판과 B42판이 별개 Workshop 항목으로 갈라졌다. 원판이 중단되고 커뮤니티 포크가 이어받은 경우도 많아 인기 수치가 흩어져 있다. 현재 구독이 가장 많은 항목이 지금 작동한다는 보장은 없다.

### Cited Findings

#### 빌드 일정 (공식)
- "Project Zomboid version 42.20 will be coming direct to the stable public branch Wednesday, the 29th of July." B41 세이브는 B42와 호환되지 않고, B41을 계속하려면 "legacy41" 베타를 고른다. — [공식 블로그 BUILD 42 STABLE PLANS](https://projectzomboid.com/blog/news/2026/07/build-42-stable-plans/)
- 42.20 출시 공지가 예고한 일정은 이렇다. 핫픽스 다음에 후반부 조정 패치를 하고, 맵 도구와 AnimZed를 공개하고, "an extensive modding guide"를 낸다. 2026년 남은 기간에는 최적화와 모딩 지원 중심의 "Build 42 Support Update"를 진행한다. — [공식 블로그 42.20 RELEASED](https://projectzomboid.com/blog/news/2026/07/project-zomboid-build-42-20-released/)
- Steam 공지 날짜는 다음과 같다. projectzomboid.com 헤더 표기는 "Stable Build: 42.21"이다. — [42.20.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1839676055882259); [레거시 핫픽스](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1842212951296601); [42.21](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1844751498231307); [projectzomboid.com](https://projectzomboid.com/blog/features-overview-build-42-20/)
  - 2026-07-29: "Build 42.20.0 Stable Released"
  - 2026-08-26: "42.20.4 STABLE & 42.19.2 UNSTABLE & 41.78.21 LEGACY Hotfixes Released"
  - 2026-09-28: "Build 42.21 Stable Released"

#### 구독 스냅샷 (2026-10-05 수집)
모드 이름의 링크가 출처(Workshop 페이지)다. "빌드 상태"는 작성자 태그와 설명 기준이고 실제 실행으로 검증하지 않았다.

| 모드 (Workshop ID) | 분야 | 현재 구독 | 누적 구독 | 최종 업데이트 | 빌드 상태 (2026-10) |
|---|---|---|---|---|---|
| [Skill Recovery Journal (2503622437)](https://steamcommunity.com/sharedfiles/filedetails/?id=2503622437) | 지식 | 2,814,606 | 3,999,777 | 2026-09-04 | B41+B42 (repo에 42.19, 42.20.1 폴더) |
| [Has Been Read (2544353492)](https://steamcommunity.com/sharedfiles/filedetails/?id=2544353492) | 지식/UI | 2,904,450 | 4,095,859 | 2026-09-28 | B41+B42 Stable |
| [Skill Journal (3776641628)](https://steamcommunity.com/sharedfiles/filedetails/?id=3776641628) | 지식 | 76,571 | 93,033 | 2026-09-01 | B42.20 |
| [SRJ Reminder (3156717975)](https://steamcommunity.com/sharedfiles/filedetails/?id=3156717975) | 지식 | 45,720 | 97,724 | 2026-05-26 | B41+B42.20 |
| [LG Skill Journal (3779162647)](https://steamcommunity.com/sharedfiles/filedetails/?id=3779162647) | 지식 | 11,110 | 13,722 | 2026-09-30 | B42 |
| [Teach Knowledge (3634599609)](https://steamcommunity.com/sharedfiles/filedetails/?id=3634599609) | 지식 | 4,624 | 10,780 | 2026-01-10 | B42 MP (WIP) |
| [[B41] The Only Cure (3236152598)](https://steamcommunity.com/sharedfiles/filedetails/?id=3236152598) | 절단 | 500,246 | 953,815 | 2025-10-05 | B41 전용 |
| [[B42.20] The Only Cure (3580276809)](https://steamcommunity.com/sharedfiles/filedetails/?id=3580276809) | 절단 | 248,581 | 361,257 | 2026-09-13 | B42.20 (Host 모드 미지원) |
| [The Only Cure 구판 (2703664356)](https://steamcommunity.com/sharedfiles/filedetails/?id=2703664356) | 절단 | 397,035 | — | 2023-03-11 | 지원 종료(DEPRECATED) |
| [Amputations RP (2986581203)](https://steamcommunity.com/sharedfiles/filedetails/?id=2986581203) | 절단(외형) | 52,404 | 136,943 | 2023-08-15 | B41 |
| [Casualties Undead (3805748433)](https://steamcommunity.com/sharedfiles/filedetails/?id=3805748433) | 의료 | 16,047 | 18,834 | 2026-10-02 | B42.20+ |
| [Antibodies (2392676812)](https://steamcommunity.com/sharedfiles/filedetails/?id=2392676812) | 감염 | 324,762 | 668,337 | 2026-09-10 | B41+B42 |
| [They Knew [B41] (2725378876)](https://steamcommunity.com/sharedfiles/filedetails/?id=2725378876) | 감염 | 1,238,603 | 2,047,315 | 2022-02-14 | B41 |
| [They Knew [B42] (3387110070)](https://steamcommunity.com/sharedfiles/filedetails/?id=3387110070) | 감염 | 209,609 | 439,724 | 2024-12-19 | B42 (42.20 호환 미확인) |
| [Zombie Virus Vaccine (3615135168)](https://steamcommunity.com/sharedfiles/filedetails/?id=3615135168) | 감염 | 156,252 | 232,283 | 2026-09-23 | B42.14~42.20 |
| [Not Dead Yet (3631727340)](https://steamcommunity.com/sharedfiles/filedetails/?id=3631727340) | 감염 | 17,374 | 36,958 | 2026-07-30 | B42.20 MP |
| [Medical Meister (3173649443)](https://steamcommunity.com/sharedfiles/filedetails/?id=3173649443) | 의료 UI | 125,887 | 279,155 | 2026-09-04 | B41/B42 Stable+MP |
| [Mini Health Panel (2866258937)](https://steamcommunity.com/sharedfiles/filedetails/?id=2866258937) | 의료 UI | 1,573,225 | 2,406,175 | 2026-10-04 | B41+B42.20 |
| [Proper Infected Wounds (3410729454)](https://steamcommunity.com/sharedfiles/filedetails/?id=3410729454) | 의료 | 27,688 | 77,563 | 2026-08-06 | B42.20+MP |
| [Wounds Overhaul (3775026731)](https://steamcommunity.com/sharedfiles/filedetails/?id=3775026731) | 의료 | 21,717 | 29,758 | 2026-10-04 | B42 |
| [More Traits [Legacy] (1299328280)](https://steamcommunity.com/sharedfiles/filedetails/?id=1299328280) | 형질 | 1,940,396 | 3,128,393 | 2026-08-29 | 지원 종료(태그는 B41/B42) |
| [More Description for Traits (2685168362)](https://steamcommunity.com/sharedfiles/filedetails/?id=2685168362) | 형질 UI | 1,809,591 | 3,164,608 | 2025-05-26 | B41 전용("Not b42!") |
| [SOTO (2840805724)](https://steamcommunity.com/sharedfiles/filedetails/?id=2840805724) | 형질 | 749,182 | 1,355,175 | 2026-03-09 | B41 + B42 싱글 (B42 MP 불가) |
| [Dynamic Traits and Expanded Moodles (2459400130)](https://steamcommunity.com/sharedfiles/filedetails/?id=2459400130) | 형질 | 398,252 | 932,412 | 2026-09-30 | B41.78 + B42.20~42.21+ |
| [Evolving Traits World (2914075159)](https://steamcommunity.com/sharedfiles/filedetails/?id=2914075159) | 형질 | 242,372 | 540,093 | 2026-10-04 | B42 (B41판 별도) |
| [More Traits Definitive Edition (3799050151)](https://steamcommunity.com/sharedfiles/filedetails/?id=3799050151) | 형질 | 37,064 | 43,749 | 2026-10-05 | B42.20 |
| [Hydrocraft (Build 40) (498441420)](https://steamcommunity.com/sharedfiles/filedetails/?id=498441420) | 제작 | 245,606 | 575,806 | 2019-08-16 | B40, 중단 |
| [Hydrocraft XS (2081538550)](https://steamcommunity.com/sharedfiles/filedetails/?id=2081538550) | 제작 | 115,093 | 339,994 | 2023-12-10 | B41, B42판 없음 |
| [HydroCraft b41 Continued (2778991696)](https://steamcommunity.com/sharedfiles/filedetails/?id=2778991696) | 제작 | 100,838 | 257,050 | 2023-05-19 | B41 |
| [Craft Helper Continued (2787291513)](https://steamcommunity.com/sharedfiles/filedetails/?id=2787291513) | 제작 UI | 1,591,657 | 2,638,837 | 2024-03-31 | B41 전용 |
| [Neat Crafting [B42] (3502080466)](https://steamcommunity.com/sharedfiles/filedetails/?id=3502080466) | 제작 UI | 781,274 | 1,036,087 | 2026-09-29 | B42.9~42.21.x |
| [More Builds (515555911)](https://steamcommunity.com/sharedfiles/filedetails/?id=515555911) | 건설 | 1,268,149 | 2,321,732 | 2026-10-01 | B42 (전면 재작성) |
| [Practice Crafting Skills (3765795716)](https://steamcommunity.com/sharedfiles/filedetails/?id=3765795716) | 제작 | 68,212 | 83,040 | 2026-09-27 | B42.20 |
| [Common Sense (2875848298)](https://steamcommunity.com/sharedfiles/filedetails/?id=2875848298) | QoL/제작 | 3,560,628 | 5,019,797 | 2025-03-07 | 태그 B41/B42, 42.20용 커뮤니티 포크 있음 |
| [Common Sense [B42.20+] (3750253491)](https://steamcommunity.com/sharedfiles/filedetails/?id=3750253491) | QoL/제작 | 318,772 | 387,621 | 2026-08-13 | B42.20+ |
| [Minimal Display Bars (2004998206)](https://steamcommunity.com/sharedfiles/filedetails/?id=2004998206) | 욕구 UI | 1,664,281 | 2,934,953 | 2021-09-13 | B40/B41, 중단 |
| [MDB + Nutritions + Discomfort (3388844542)](https://steamcommunity.com/sharedfiles/filedetails/?id=3388844542) | 욕구 UI | 73,822 | 144,077 | 2026-09-06 | B41+B42.20 |
| [Moodle Framework B41 (2859296947)](https://steamcommunity.com/sharedfiles/filedetails/?id=2859296947) | 무들 | 1,501,040 | 2,629,545 | 2025-12-11 | B41 |
| [Moodle Framework (3396446795)](https://steamcommunity.com/sharedfiles/filedetails/?id=3396446795) | 무들 | 475,885 | 772,034 | 2026-09-07 | B42 |
| [Clear description for Moodles (2763647806)](https://steamcommunity.com/sharedfiles/filedetails/?id=2763647806) | 무들 UI | 1,228,617 | 2,129,068 | 2023-02-11 | B40/B41 |
| [Realistic Temperature Mod (3600401184)](https://steamcommunity.com/sharedfiles/filedetails/?id=3600401184) | 추위 | 60,136 | 127,782 | 2026-06-10 | B42.18+ MP |
| [Sleep On It (2673713236)](https://steamcommunity.com/sharedfiles/filedetails/?id=2673713236) | 피로 | 670,822 | 1,354,019 | 2021-12-05 | B41 |
| [Sleep with Friends v2.1 (2686624983)](https://steamcommunity.com/sharedfiles/filedetails/?id=2686624983) | 피로 | 599,358 | 1,136,281 | 2026-01-02 | B41+B42 |
| [Comfy Sleeping (2998737588)](https://steamcommunity.com/sharedfiles/filedetails/?id=2998737588) | 피로 | 70,836 | 198,246 | 2026-08-09 | B41+B42.19+ |
| [Equipment UI (2950902979)](https://steamcommunity.com/sharedfiles/filedetails/?id=2950902979) | 인벤토리 | 1,828,406 | 2,860,702 | 2025-12-24 | 중단(MIT), B42 포크 존재 |
| [Inventory Tetris B42 (3397561666)](https://steamcommunity.com/sharedfiles/filedetails/?id=3397561666) | 인벤토리 | 119,914 | 293,974 | 2026-08-15 | 중단(MIT); B41 Legacy판(2982070344) 301,036 |
| [Inventory Tetris – Items and Equipment Overhaul (3775513231)](https://steamcommunity.com/sharedfiles/filedetails/?id=3775513231) | 인벤토리 | 59,919 | 84,898 | 2026-08-20 | B42.20 |
| [Better Sorting (2313387159)](https://steamcommunity.com/sharedfiles/filedetails/?id=2313387159) | 인벤토리 | 3,306,835 | 5,073,139 | 2026-09-12 | B41+B42 |
| [Proximity Inventory (2847184718)](https://steamcommunity.com/sharedfiles/filedetails/?id=2847184718) | 인벤토리 | 2,183,226 | 2,952,767 | 2026-08-30 | B41+B42.20+ |
| [Fancy Handwork (2904920097)](https://steamcommunity.com/sharedfiles/filedetails/?id=2904920097) | 한손 조작 | 975,929 | 1,847,866 | 2025-12-06 | B41 (별도 "B42.20" 항목 3771638611: 101,036) |
| [Brutal Handwork (2934621024)](https://steamcommunity.com/sharedfiles/filedetails/?id=2934621024) | 한손 전투 | 582,223 | 1,217,824 | 2023-02-18 | B41 (B42 패치 3778038193: 27,469) |

#### 전체 기간 구독 순위 속 위치
- Steam "가장 많이 구독됨(전체 기간)" 정렬(2026-10-05)에서 1위는 Mod Options (Build 41)(누적 7,213,461)다. 이 분야 모드의 순위는 다음과 같다. — [Steam Workshop 순위](https://steamcommunity.com/workshop/browse/?appid=108600&browsesort=totaluniquesubscribers&section=readytouseitems)

  | 순위 | 모드 |
  |---|---|
  | 5 | Better Sorting |
  | 6 | Common Sense |
  | 13 | Has Been Read |
  | 15 | Skill Recovery Journal |
  | 27 | Bushcraft Gear - Tools |
  | 31 | More Description for Traits |
  | 34 | More Traits |
  | 40 | Proximity Inventory |
  | 43 | Minimal Display Bars |
  | 46 | Equipment UI |
  | 56 | Craft Helper Continued |
  | 57 | Moodle Framework B41 |
  | 67 | Mini Health Panel |
  | 78 | More Builds |
  | 91 | Clear description for Moodles |
  | 101 | They Knew [B41] |

#### 언론과 큐레이션 목록
- PCGamesN "The best Project Zomboid mods"(Danielle Rose, 2026-02-23 갱신)는 의료 쪽으로 They Knew("medicine types that can heal zombie virus infection")와 Common Sense를 넣었다. SRJ와 TOC는 없다. — [PCGamesN](https://www.pcgamesn.com/project-zomboid/mods)
- GameRant "Best Mods For Project Zomboid Build 42"(2024-12-22, B42 unstable 시기)는 Equipment UI, Comfy Sleeping, More Traits, Common Sense를 꼽았다. — [GameRant](https://gamerant.com/project-zomboid-best-mods-build-42-b42/)
- Supercraft 2026 목록은 SRJ를 "death-tax remover"라 부르며 추천한다. 함께 추천한 건 Inventory Tetris, Common Sense, Better Sorting, Proximity Inventory, More Traits다(검색 요약). — [Supercraft](https://supercraft.host/wiki/project-zomboid/pz_best_mods_2026/)

#### 데이터 신뢰도 메모
- Steam 아이템 HTML에는 모든 아이템에 `<div class="bannedNotification" id="bannedNotification" style="display: none">This item has been removed from the community because it violates Steam Community & Content Guidelines…`가 숨겨져 있다. 요약 도구들이 이걸 실제 상태로 착각했다. SRJ(2503622437)는 Steam API에서 `banned=0`, `visibility=0`이다. — [Workshop 2503622437](https://steamcommunity.com/sharedfiles/filedetails/?id=2503622437); [Steam Web API GetPublishedFileDetails](https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/)
- 다음 출처는 접근이 막혀 확인하지 못했다. pzwiki.net은 curl과 WebFetch 모두 403, Steam 커뮤니티 페이지는 연속 요청 시 429, rockpapershotgun.com은 검색 도구에서 차단됐다.

### Inferences
- "현재 구독"에는 B41 시절 구독이 그대로 남아 있어 활성 사용을 과대평가한다. B42 시대의 실제 수요는 B42 전용 항목 수치(예: TOC B42 25만, Neat Crafting 78만, Moodle Framework B42 48만)로 보는 편이 맞다.
- B41에서 B42로 넘어오며 중단, 포크, 패치 모드가 쏟아졌다. 핵심 UX 기능이 외부 모드에 의존하면 빌드가 바뀔 때 단절 비용이 크다는 뜻이다. 열차 게임에서 체력 패널, 제작 검색, 지식 보존 같은 기능을 처음부터 본편에 넣어야 할 근거다.
- 즐겨찾기 비율이 높은 신작(Casualties Undead 약 25%, Wounds Overhaul 약 10%)은 하드코어 의료 니치의 강한 열광을 보여준다. 하지만 대중 지표인 현재 구독은 아직 작다.
- 언론 목록에는 SRJ와 TOC가 잘 안 나오지만 Workshop 지표에서는 상위다. 설계 참고용 인기도 판단은 언론 목록보다 Workshop 지표에 무게를 두는 게 맞다.

### Gaps
- Reddit(r/projectzomboid) 스레드는 직접 수집하지 못했다.
- 일부 모드의 B42.21 호환성은 작성자 표기(태그와 설명)에만 의존했고 실제로 실행해 검증하지 않았다. 특히 They Knew B42(2024-12 이후 업데이트 없음)와 Common Sense 원판(2025-03 이후 업데이트 없음)이 42.20/42.21에서 동작하는지는 미확인이고, 커뮤니티 포크가 있다는 사실로 추정했을 뿐이다.
- Fancy Handwork B42.20(3771638611) 항목의 작성자가 원작자인지는 확인하지 못했다.
- 구독 수치는 수집 시점에 따라 수십 단위로 오르내린다. 표의 값은 2026-10-05 한 시점의 스냅샷이다.
