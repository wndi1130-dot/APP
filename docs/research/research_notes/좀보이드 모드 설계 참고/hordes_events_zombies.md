# 좀보이드 모드 조사: 호드·웨이브·이벤트·좀비 종류 (2026-10-05 기준)

> **읽는 법.** **[스니펫]** = 원문을 못 열고 검색 요약으로만 확인. **[미검증]** = 플레이어 한 명의 보고이거나 교차 확인을 못 함. **[제안]** = 조사자의 설계 추론(확정 아님).
> **인기 수치.** 구독자 수는 모두 Steam Web API `ISteamRemoteStorage/GetPublishedFileDetails`(https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/)로 **2026-10-05에 직접 받은 값**이다. "현재"는 지금 구독 중인 수(subscriptions), "누적"은 누적 고유 구독 수(lifetime_subscriptions)다. Build 41/42 태그는 작가가 고르는 값이라 실제 호환과 다를 수 있어서, 설명문과 댓글로 따로 확인했다.
> **게임 버전.** 42.20이 안정판(Stable) 브랜치로 나왔다([공식 블로그](https://projectzomboid.com/blog/news/2026/07/project-zomboid-build-42-20-released/)). 날짜는 2026-07-29다([PCGamesN](https://www.pcgamesn.com/project-zomboid/build-42-20-stable-plans) 등 검색 요약 [스니펫]. 같은 날부터 "42.20 업데이트 해 달라"는 워크숍 댓글이 쏟아진 것과도 맞는다). 2026-10-05 공식 사이트 헤더 기준 안정판은 42.21이다. B41은 `legacy41` 베타 브랜치로 남았다([공식 블로그](https://projectzomboid.com/blog/news/2026/07/project-zomboid-build-42-20-released/)).

## 1. 어떤 호드·웨이브·이벤트 모드가 유명하고, 타이밍·규모 증가·표적·경고·설정은 어떻게 작동하나

### Takeaway
현재 구독자 기준 1위는 **Expanded Helicopter Events(EHE, 125.6만)**다. EHE는 헬기 이벤트를 '날짜에 따라 바뀌는 세계 사건 연대기'로 바꿨다. 플레이어 위치를 주기적으로 치는 호드의 원조는 **Horde Night(44.0만)**다. 사람 습격까지 치면 **Bandits NPC(104.4만)**가 '시간이 갈수록 커지고 무장하는 습격'의 최대 사례다. 호드 모드는 거의 모두 두 틀 중 하나다. ① **달력형**: 정한 날짜·시각에 온다(Horde Night, Blood Moon Hordes, Siege Night, Dynamic Horde Events). ② **누적 계기형**: 소음·활동이 쌓여 문턱을 넘으면 온다(Here They Come!의 동요도, Siege Night의 열기, EHE의 활동 히트맵, Warlord의 소음 점수). B42 안정판이 나온 뒤 B41 고전 호드 모드는 대부분 깨졌거나 방치됐다. 그 자리에 **Dynamic Horde Events B42(5.2만, 2026-04 출시)**가 B42 호드 모드 1위로 올라섰다.

### Cited Findings

#### Expanded Helicopter Events (EHE): 헬기를 '세계 사건' 연대기로 바꾼 모드
- 정의: 바닐라 헬기 이벤트를 "a more dynamic suite of events which are both challenging and fair"로 대체한다. 다른 모드가 확장할 수 있는 프레임워크이기도 하다 — [EHE 워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2458631365)
- 일정 곡선: 초반 이벤트는 점점 드물어지다 약 한 달에 끝난다('아포칼립스 후 경과 개월' 샌드박스 값을 반영). 후반 이벤트는 **45일째 다시 늘었다가 90일째 완전히 끝난다** — [FEATURES.md](https://github.com/TEHE-Studios/ExpandedHelicopterEvents/blob/main/docs/FEATURES.md)
- 사건 목록(초반): 군 헬기(처음엔 방송만 하다가 점점 좀비를, 나중엔 플레이어까지 쏜다), FEMA 보급 투하(문명 붕괴 전), 경찰 헬기(처음부터 좀비 사격), 뉴스 헬기(대상을 따라다니며 바닐라와 가장 비슷하다. 실내나 엄폐물로 피할 수 있다), 지나가는 제트기(초반에 호드를 움직인다), 폭격과 공습 사이렌(적대로 돌아섰다는 신호). (후반): 약탈자 'The Wolverines'(쓰레기를 던지는 수준부터 사격까지), 생존자 헬기(스쳐 지나감), 'The Samaritans'(보급 상자 투하) — [FEATURES.md](https://github.com/TEHE-Studios/ExpandedHelicopterEvents/blob/main/docs/FEATURES.md)
- 핵심 사건은 9종이고 대부분 "progress through a timeline based on in-game days"다. 좀비만 치는 사건, 플레이어만 치는 사건, 가리지 않는 사건, 물자를 떨구는 사건이 섞여 있다 — [공식 모드 스포트라이트(2022-01)](https://projectzomboid.com/blog/news/2022/01/mod-spotlight-expanded-helicopter-events/)
- 표적 선정: **활동 히트맵**이 이동, 사격, 좀비 처치, 조명탄 발사를 기록한다. 일부 사건은 더 '뜨거운' 대상으로 표적을 바꾼다. 숲보다 도시의 대상을 선호하고, 인기 NPC 모드의 NPC도 표적이 된다. 조명탄은 사건을 소환하지 않는 대신 매우 뜨거운 표적이 된다. 악천후에는 날지 않고, 날씨가 나쁠수록 추락 확률이 오른다. 추락한 헬기는 뒤질 수 있는 차량 오브젝트로 남는다 — [FEATURES.md](https://github.com/TEHE-Studios/ExpandedHelicopterEvents/blob/main/docs/FEATURES.md)
- 피할 수 있음: "Players can actually hide from / avoid the helicopter. (The vanilla helicopter 'knows' where you are if you step outside while it's active regardless of distance.)" 사격은 즉사가 아니라 "gravely wound targets and shred clothing"이고, 움직이거나 엄폐하면 명중률이 내려간다 — [FEATURES.md](https://github.com/TEHE-Studios/ExpandedHelicopterEvents/blob/main/docs/FEATURES.md)
- 경고: 다가오는 헬기·추락지·보급 투하의 방향과 거리를 가리키는 **인디케이터**가 있다(시력 관련 특성이 인디케이터가 켜지는 거리에 영향을 준다). 헬기 그림자가 위치를 보여 주고, 확성기 방송은 전부 음성이다. 바닐라처럼 라디오 비상방송(AEBS)에도 등록된다 — [FEATURES.md](https://github.com/TEHE-Studios/ExpandedHelicopterEvents/blob/main/docs/FEATURES.md)
- 설정: Start Day, Scheduler's Duration, 사건별 Frequency(1 Never·2 Rare·3 Uncommon·4 Common·5 Frequent·6 Insane), Continue Scheduler / Late-Game Only(마지막 단계를 무한히 이어갈지). 바닐라 헬기는 강제로 꺼진다(`/chopper`로는 부를 수 있다) — [FAQ.md](https://github.com/TEHE-Studios/ExpandedHelicopterEvents/blob/main/docs/FAQ.md)
- 설계 의도: 작가 Chuck은 바닐라 헬기를 "overly-brutal"이라 했다. 그 이벤트가 "creates a meta where most people constantly 'run for the hills'"이고, 조심과 계획을 보상하는 게임을 "turns things upside down through no fault of your own"한다는 이유다. 공동 작가 Shark는 "the same way that Rimworld approaches story tellers", "never overshadow PZ itself"를 원칙으로 들었고, 목표를 "less of a player-centric challenge ... a series of world events with the player acting as a witness"라고 했다. 가장 어려웠던 점으로는 "the human element ... people need to understand what is happening"을 꼽았다. 인디케이터 덕분에 소리를 끄고 하거나 청각장애가 있는 플레이어도 불이익을 받지 않게 됐다고 했다 — [공식 모드 스포트라이트](https://projectzomboid.com/blog/news/2022/01/mod-spotlight-expanded-helicopter-events/)
- 상태: 2025-01-19 변경 기록이 "FINAL UPDATE for B41"이고, 마지막 갱신은 2025-10-12(마커 위치 조정)다 — [EHE 변경 기록](https://steamcommunity.com/sharedfiles/filedetails/changelog/2458631365). 2025-02-07 공지에서 작가는 "Work has begun on the B42 version"이라 했고, 워크숍 댓글은 닫았다 — [Steam 토론 PSA](https://steamcommunity.com/app/108600/discussions/0/592888463635869664/)
- 2026-10-05 현재 공식 B42판은 찾지 못했다 **[미검증: 워크숍 검색으로만 확인]**. 무단 재업로드로 보이는 'helicoptero_B42'(현재 205명, "42.13 호환"을 주장)는 API상 살아 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3628707117). EHE 페이지에는 "not authorized for posting on Steam, except under the Steam account named shark"라고 적혀 있다 — [EHE 워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2458631365). (검색 요약은 이 재업로드가 '삭제됐다'고 했지만 API 결과와 어긋난다.)
- B42 대안: **HEF – Helicopter Event Framework**(현재 29,877명)는 바닐라 헬기에 2차 사건을 붙인다. 독가스(방독면이 피해를 줄이고 좀비를 끌어들임), 지원(좀비만 사격, 좀비를 끌지 않음), 적대(플레이어만 사격), 원거리 폭격, 먼 곳 폭발음(좀비를 플레이어에게서 떼어 냄), 헬기 추락(강한 방향성 소리로 좀비를 끌어감), 정찰(끌지 않음, 심리적 압박), 네이팜 소탕, 연막(연막 안에서는 좀비가 플레이어를 못 알아봄), 전자기 교란(무전 방해, 배터리 소모)이 있다 — [HEF 워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3672792485). Ultimate Helicopter Event [B42](현재 606명)는 바닐라 헬기가 오히려 너무 쉽다고 본다: "All you really have to do is go inside and sit around reading until you no longer hear the helicopter" — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3429167063)

#### 바닐라 헬기 이벤트(기준선, B42.19)
- 첫 이벤트는 '생존한 밤' 6~9 중 하나로 굴린다. 시작 시각은 9~18시, 발동 창은 시작 후 1~4시간이다. 기본 Apocalypse 프리셋은 Once다. Sometimes면 다음 이벤트가 +10~15밤, Often이면 +6~9밤 뒤다. 해당 밤에는 AEBS에 "Air Activity detected"가 나온다 — [pzfans 가이드(제3자)](https://pzfans.com/hovering_doom_surviving_project_zomboid_build_42s_helicopter_event/)
- 실내에 있거나 숲(Forest/Deep Forest) 바깥 칸에 있으면 헬기가 플레이어를 못 본다. 커튼, 웅크리기, 소음은 판정에 들어가지 않는다. 맴돌기는 약 ±50칸, 수색은 약 ±100칸 범위다. 한 번 발동하면 맴돌기와 수색에 약 60초(게임 속도 비례)를 쓰고 떠난다. 활동 중에는 헬기 위치에서 약 500칸짜리 큰 소리를 주기적으로 내서 좀비를 끈다 — [pzfans 가이드](https://pzfans.com/hovering_doom_surviving_project_zomboid_build_42s_helicopter_event/)

#### Horde Night (WindFly): 7 Days to Die식 정기 호드의 원조
- 작동: "If you have played games like 7 days to die, you will know what's coming." 정한 날짜·시각에 경고가 뜨고, 곧이어 "every players will get a big swarm approaching from all sides." 썸네일은 They Are Billions 예고편에서 따왔다 — [Horde Night 워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2714850307)
- 샌드박스 9개: Starting Hour, First Day(0=시작일), Frequency(일 단위, 1이면 매일), Starting Zombie Counts, Zombie Increments(한 번 버틸 때마다 더해지는 수), Zombie Limits(상한), Random HordeNight Chance(0.0~1.0, 첫 호드 뒤부터, 정기 호드가 없는 날에만, MP에선 플레이어마다 따로 굴림), Spawn Distance(최대), Indicator(호드 당일 우상단 아이콘, 무작위 호드는 표시 안 함) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2714850307)
- 스폰 규칙: "inside" 칸과 플레이어의 시야 범위에는 절대 스폰하지 않는다. MP에선 **플레이어마다 따로** 호드가 온다(100마리 설정 × 4명 = 400마리). 원래 있던 좀비도 깨어나 합류하므로 설정보다 많아진다. 2022-02-01 패치로 경고음을 "Greatly turned down"했고, MP 안전가옥 구역에는 스폰하지 않게 했다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2714850307)
- 상태: 2024-12 B42 불안정판 지원을 넣은 게 마지막 갱신(2024-12-22)이다. 2026-08~09 댓글들은 42.20 안정판에서 튕긴다(CTD)고 하고 방치됐다고 본다 — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2714850307)

#### Hark's Horde Night Revamped [B42 Stable]: Horde Night의 B42 후계
- 원작자 WindFly의 Horde Night를 B42용으로 포크했다(현재 6,219명) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3713005182)
- 예보: AEBS가 정확한 카운트다운 없이 알린다. "Migration Pattern Detected"는 내일, "Migration Activity Detected"는 오늘이다. 발동 3시간 전과 1시간 전에 따로 경고한다. 정확한 인디케이터는 옵션이고 기본값은 꺼짐이다("Keep an eye on the AEBS, or don't. Everybody loves surprise mechanics.") — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3713005182)
- 모드: **Tracking**(호드가 대상 생존자를 따라감, 이동형 플레이어용)과 **Anchored**(발동 지점에 고정, 큰 요새용)가 있다. 스폰한 좀비의 일정 비율을 일시적으로 질주자로 바꾸는 옵션이 있고 기본값은 0%다(끝나면 원래 속도로 되돌릴 수 있다). 기존 세이브에 넣으면 첫 카운트다운은 설치한 날부터 센다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3713005182)

#### Here They Come! (SpoutNick): 누적 동요도 계기형
- 작동: "Over time, zombies get restless and excited by your scent. After a certain threshold is reached, a horde of zombies will come hunting you down." 발동 중에는 보이지 않는 소리 펄스가 기존 좀비와 호드 좀비를 플레이어 쪽으로 끈다(조정·끄기 가능) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2779839289)
- 샌드박스 23개: Cooldown(호드 사이, 게임 분), 최소·최대 시작 시각, 시간당 동요도 최소·최대, 발동 문턱, 첫 날, 호드당 웨이브 수, 웨이브당 최소·최대 좀비, 호드마다 늘어나는 최대 좀비 수, 웨이브 간격(분), 최소·최대 스폰 거리, Horde Angle Spread(진입 방향 집중도), 배치당 좀비 수, 배치 간 틱, 동요도 아이콘, 경고 문구, Heads-up time(경고 후 첫 웨이브까지 분), 소리 펄스 켜기·범위·주기 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2779839289)
- 스폰: 실외에만, 배치로 나눠, 여러 웨이브로 온다. 같은 구역의 플레이어가 많을수록 수가 늘고, 방향은 무작위지만 모든 플레이어에게 같다. 바이옴에 맞춘 옷을 입힌다. v0.2.1부터 호드가 시작되면 자는 플레이어를 깨운다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2779839289); 코드 [GitHub](https://github.com/spoutnickgp/zomboid-mod-here-they-come)
- 상태: 마지막 갱신 2022-05-28, B41 태그. 제3자의 B42.20 이식판이 있다(현재 300명) — [이식판](https://steamcommunity.com/sharedfiles/filedetails/?id=3787895035)

#### Dynamic Horde Events B42: B42 호드 모드 1위(현재 51,821명)
- 세 종류가 있다. ① **Normal**: 플레이어 주변 밖에서 스폰해 '이벤트 소리'로 끌려온다. 직접 추적 옵션을 켜면 이 이벤트로 만든 좀비만 약 1게임시간 동안 플레이어 현재 위치를 계속 받는다(기본 꺼짐). ② **Wandering**: 플레이어를 치지 않고 "Spawn point → Player area → Exit point"로 지나간다. 조용히 있으면 비켜 가고, 총성·차량·경보에는 경로를 벗어난다. ③ **Cataclysm**: 드물고 훨씬 크며, 정한 게임시간 동안 지정 플레이어를 추적한다. 플레이어가 멀리 달아나면 근처에 제한된 '따라잡기' 무리를 스폰한다. 폭풍·비·바람·안개·채도 저하 같은 날씨 연출이 붙는다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3716405632)
- 일정: 종류마다 따로 정한다. 무작위 간격(최소~최대 사이에서 굴림)이나 고정 날짜·시각("every seven days at 18:00", '7 Days To Die Mode')을 고른다. Normal 호드 규모는 생존 일·월에 따라 커지게 할 수 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3716405632)
- 경고: 움직일 수 있는 방향 인디케이터가 **사건 종류, 방향, 거리, 대략적인 좀비 수**를 보여 준다. 경고음, 생존자 대사, Cataclysm 화면 효과는 끌 수 있다. 물 타일과 활성 안전가옥은 스폰 지점에서 자동으로 피한다. MP에선 세계 일정을 공유하고, 사건마다 활성 플레이어 한 명을 표적으로 고른다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3716405632)
- 상태: 42.20을 명시하고, 마지막 갱신은 2026-08-17이다. 작가는 무기한 휴식에 들어가며 "Feel free to modify, fix, edit"라고 남겼다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3716405632)

#### Siege Night (B42): 웨이브·소강·휴식의 리듬과 방향 고정
- 며칠에 한 번 밤마다, 나침반 8방위 중 **한 방향**에서 웨이브가 몰려온다. 웨이브는 **WAVE**(밀집 공격), **TRICKLE**(낙오자), **BREAK**(보수·보강 시간)가 돈다. 하룻밤 3~7웨이브이고 자정에 가까워질수록 강해진다. 버틴 공성 수와 접속자 수에 비례해 커진다. 초반은 3웨이브 약 75~150마리, 후반은 6~7웨이브 최대 1,500마리다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584)
- 특수 좀비는 **자정 이후 절정 때부터** 나온다. Sprinter는 "Blend in with the horde until they're already on you", Breaker는 공사 장비 차림으로 바리케이드·벽을 부순다, Tank는 군복 차림에 체력 5배이고 기본 공성당 2마리다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584)
- **열기(heat)**: 공성 사이에는 활동이 열기를 만든다. 발전기 +15, 총성 +10, 운전 +8, 큰 공사 +5이고, 조용히 있으면 천천히 식는다. 문턱을 넘으면 캐릭터가 "Something's attracting them from the south..."라고 말하고, 그 열원 방향에서 미니 호드가 온다. 충분히 잡으면 유인 장치가 꺼지고 나머지는 흩어진다. 쿨다운과 일일 상한이 있어 연달아 맞지 않는다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584)
- 권장 MP 기준값: FirstSiegeDay 5, FrequencyDays 5, BaseZombieCount 50, MaxActiveZombies(그룹당) 200, MaxZombies(공성당) 800, 미니 호드 NoiseThreshold 100·Cooldown 60분·하루 최대 2회·8~35마리. 1~2명이면 Base 25~40·Active 120~160, 6명 이상이면 60~80·250~350. 새벽까지 버티면 캐릭터가 처치 수를 말하고, 캐릭터 정보(H)에 웨이브·단계·처치·최근 20밤 기록 탭이 생긴다. 안전가옥 고정 모드를 켜면 플레이어가 떠나도 기지를 친다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584)

#### Blood Moon Hordes [Build 42]: '무한 스폰이 아닌 통제된 압박'
- 생존 7일째 밤마다(7·14·21·28일…) 온다. 경고는 09:00, 21:00, 21:50에 오고, 22:00에 시작해 04:00에 강제 추적이 끝난다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674)
- 회차별 상승: 1회차는 8마리 웨이브 1개. 2~26회차는 6웨이브·60분 간격, 27~52회차는 8웨이브·50분 간격, 53~78회차는 9웨이브·40분 간격, 79회차부터는 12웨이브·30분 간격. 하룻밤 **전체 예산**은 320마리까지, **동시 활성 상한**은 60마리까지 서서히 올라 약 104회차에 천장에 닿는다("finite nightly limits, not the size of every wave") — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674)
- 스폰·추적: 대상 그룹에서 약 50~70칸 떨어진 곳, 플레이어가 못 보는 실외 지점을 고른다. 진입 무리마다 따로 **나침반 방향과 실시간 거리**를 HUD에 띄우고, 다음 웨이브 HUD와 마지막 카운트다운도 있다. 표적은 실제 3초마다 갱신하고 경로는 15초마다 다시 짠다. 새벽이 되면 강제 표적을 지우되 살아남은 좀비를 지우지 않고 보통 AI로 돌려보낸다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674)
- MP·재시작: 100칸 안의 플레이어를 한 그룹으로 묶고, 그룹들이 **전역 예산 하나를 나눠 쓴다**(인원수만큼 호드가 복제되지 않음). 오프라인 동안 놓친 웨이브는 로드 후 몰아서 내보내지 않고 버린다. 42.20 이상이 필요하다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674)

#### The Calm Before The Storm: 기존 좀비를 빼냈다가 돌려보내는 3단계
- 'You Have One Day' 도전에서 따왔다. ① Cooldown(평상시) → ② Calm(좀비가 플레이어에게서 멀리 대이동해 마을이 텅 빔. 약탈·방비 시간) → ③ Storm(거대한 호드로 돌아와 집요하게 사냥함. 기본값으로 좀비가 플레이어 위치를 **항상 안다**). Storm 시작은 바람 소리와 먼 좀비 소리로 알린다. **새로 스폰하지 않고** 이미 있는 좀비를 옮긴다. 단계 길이, 반경, 거리를 조정할 수 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2953621037)

#### 떠도는 호드·이주 시스템
- **Wandering Zombies**(현재 104,224명, B42·B42 MP 지원): "Wandering Zombies does not spawn zombies, and it never will." 배회 주기(Num/Rand Ticks), 최대 이동 거리, Homing Chance(플레이어 쪽으로 향할 확률), Random Chance 등을 조정한다. 일부 기능엔 Reflection Enabler가 필요하다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2983905789). WIP판의 '호드 이벤트'는 SP 전용이다. 작가는 MP에서 남의 기지로 호드를 유인하는 그리핑을 이유로 들었다(2026-09-16) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2983905789)
- **Living Hordes [B42] Beta**(현재 2,635명, 솔로 전용): 작가는 바닐라가 좀비를 "only migrate into the empty parts of their own cell, a 256 tile square they never leave"한다고 진단한다 **[작가 주장]**. 그래서 개체군 계층을 통째로 갈아 끼웠다. 수만 마리가 지도를 가로지르지만 엔진에는 거의 존재하지 않고, 플레이어가 볼 수 있을 때만 게임 오브젝트가 된다(게임의 가시성 판정 사용). 지도를 읽어 피란지(경찰서, 군 시설, 병원, 대피소가 된 교회·학교)에 가중치를 주고, 호드가 거점 사이를 강을 돌아 이동한다. 새 호드는 지도 가장자리(특히 도로)로 계속 들어온다. 아무도 안 가는 지역은 휴면한다. 지나가는 호드는 벽과 문에 쌓여 실제 피해를 남긴다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3691686404)
- **Big Chiefs Dynamic Hordes**(B42.20, 현재 5,169명): 1~8개의 영속 호드가 실제 마을 이름 네트워크를 따라 이동하고, 마을마다 1~3일 머문다. 멀리 있을 땐 추상 수치로만 있다가 로드 구역에 들어오면 화면 밖에서 실체화한다. 죽이면 영속 개체수가 실제로 줄고, 일정 비율 아래로 떨어지면 붕괴해 낙오자가 된다. **Onslaught 모드**를 켜면 모든 호드가 순간이동 없이 플레이어 쪽으로 이주한다. 화면에 보이는 칸, 방 안, B42 울타리로 막힌 단지 안에는 스폰하지 않는다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3780696417)
- **Wandering Hordes**(B42, 2026-07 출시, 현재 11,506명)는 "No HUD warnings, no scripted alerts and no zombies that magically know where you are"를 내세운다. 기존 호드 모드를 셋으로 나눈다: "A fixed spawn of homing zombies every couple of days (7 Days to Die style)", 설정이 어렵고 렉과 예측 불가 결과를 낳는 지도 배회 시스템, 검증 안 된 신작. 작동은 이렇다. 무리 방향은 '선택된 플레이어 방향 + 산포(기본 110°)'로 정하고, 크기는 1마리부터 50마리까지 무작위다. 울타리 안, 집 안, 물 위에는 스폰하지 않는다. 도시 청크일수록 스폰 확률이 높다. 설명문에는 "Zombies that have seen player or went to final point are deleted"라고 적혀 있다(배회 시스템 관리에서 빠진다는 뜻일 수도 있다 **[미검증]**) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3759920384)
- **DEZ – Dynamic Evolution Z**(현재 5,157명): 대규모 소탕 같은 플레이어 활동 뒤에 무리가 주변 청크로 옮겨 간다("Safe areas do not remain safe forever"). 진화 내용은 2절에 정리했다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3676814360)

#### 감독(Director)·전령·소음 증폭형
- **The Director**(B42.18, 현재 1,034명): L4D의 AI 디렉터를 본떴다. 매 주기 행동을 고른다: spawn_horde(walker / fast_shambler / **fake_shambler** / sprinter / crawler / mixed), 기존 좀비 유인·우회, siege_phase(강도 1~5), 가짜 총성·환청·잡음, 메타 이벤트 앞당기기, 날씨 밀기, 도발 대사, **wait**("enforced relax windows (the same trick L4D uses)"), 먼 좀비 정리. 가짜 셔블러("look slow, then run when you commit")는 정찰하는 플레이어에게만 쓰고, 질주자는 "saved for the climax"다. 성격은 Patient, Sadistic, Tactical, Narrator 중에서 고른다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3720305815)
- **Warlord**(B42.17, 현재 108명): 소음 점수(총성, 헬기의 날, 경보, 지속 공사)가 문턱을 넘으면 체력 높은 질주 좀비 '워로드'가 온다. 주기적으로 외쳐 호드를 지휘한다. 공격은 2단계다. 경고 포효 뒤 약 2게임분 안에 안전가옥 둘레에 8~12마리가 스폰한다. **그 사이에 워로드를 죽이면 습격이 취소된다.** 소음기를 쓰면 점수가 덜 쌓인다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3719581107)
- **Thumping Attracts Zombies**(B41/B42, 현재 29,166명): 바리케이드를 두드리는 소리가 주변 좀비를 더 끈다. 같은 물체를 치는 좀비가 많을수록 소리 범위가 지수적으로 커져서 공성이 저절로 커진다. 기본 범위, 마리당 증가, 지수, 최대 범위를 조정한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3646787580)
- **Reactive Sound Events**(B42, 현재 150,279명): 메타 이벤트 소리가 나면 실제로 그 자리에 총격전 잔해, 차량 충돌, 야영지 같은 조사 가능한 장면이 생긴다. 소리가 난 방향을 화면 마커로 보여 준다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3656190498). **Random Sound Events**(B41, 현재 85,499명)는 핵폭발, 지진, 공습 사이렌을 넣는다. 종류별 시작·종료일과 쿨다운이 있고, 이 소리들이 좀비를 끈다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2834231099)

#### 사람 습격·시나리오·웨이브 디펜스형
- **Bandits NPC [B42]**(현재 1,043,646명, 42.20 이상 전용): 24시간 뒤부터 약 55칸 떨어진 곳에 근접 무기를 든 소규모 무리가 나온다. 시간이 갈수록 더 크고 총기를 든 무리가 더 자주 온다. 무리는 플레이어를 추적하고, 기지를 털거나 발전기·차량·작물을 사보타주하고, 문과 가구를 부순다. 스폰은 "purely distance based"라서 기지 안에 나올 수 있다고 작가가 인정한다. 오래된 세이브에 넣으면 후반 무리가 곧바로 나온다. 워크숍 댓글은 "because of hostility" 닫았다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- **Week One NPC [B42]**(현재 330,249명): 발병 7일 전에 시작해 녹스 사태까지 점점 고조된다("Things escalate quickly"). 성능 부담이 크다고 작가가 경고한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
- **Last Stand Together**(Chuckleberry Finn, B41+B42 태그, 현재 5,250명): "A multiplayer adaption of Project Zomboid's Last Stand mode." 건물을 골라 웨이브를 버틴다. 웨이브 규모와 간격은 패널이나 샌드박스에서 정한다. 전원이 죽으면 지도 전체에서 무작위 건물을 다시 고르는 자동 모드가 있고, 상점이 붙는다. 세계의 좀비를 모두 지운다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3534542229)
- **Extraction Mode**(B42, 2026-08-17 출시, 현재 34,554명): 타르코프식 레이드다. "Loot, survive escalating hordes, and reach marked extraction zones. Call the helicopter and board the extraction rope before it is too late." "Late-raid and extraction hordes that scale with player count." "Progressive sprinter chances." — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3785397275)
- **Horde Day**(B41, 현재 1,194명): 일·주·사용자 지정 주기로 호드가 오고, 다음 호드까지 카운트다운을 보여 준다. 선택형 퍼마데스 모드가 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3495000708)
- **Horde Event**(BitBraven, B41, 현재 87,139명): 관리자가 지역을 찍으면, 플레이어가 그 안에 들어왔을 때 지연 후 정한 규모·옷·종류의 호드가 스폰한다. 반복 횟수와 쿨다운을 정할 수 있다(맵 제작·RP용 트리거) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2992366401)

#### 큐레이션 목록에서의 노출
- PCGamesN(2026-02-23 갱신)은 호드·이벤트 계열로 Last Stand Together, EHE(B41), Bandits Creator(B42), SecretZ Pandemic, They Knew를 싣는다 — [PCGamesN](https://www.pcgamesn.com/project-zomboid/mods)
- finalboss.io의 'B42 테스트 15선'(2026-06-28 갱신)은 Bandits Creator, SecretZ Pandemic, They Knew, Ultimate Helicopter Event [B42], Last Stand Together를 싣는다 — [finalboss.io](https://finalboss.io/15-project-zomboid-mods-that-totally-change-how)
- 여러 목록 요약에 More Zombies, Random Zombies, Horde Night, Last Stand Together가 반복해서 나온다 **[스니펫, 사이트별 귀속 불명확]** — [Sparked Host](https://blog.sparkedhost.com/project-zomboid/best-mods-for-project-zomboid), [GameRant](https://gamerant.com/project-zomboid-best-mods/)
- 'B42 떠도는 호드 모드' 토론(2026-06-08, 연도 표기가 없어 올해로 추정)에서는 Dynamic Horde Events B42, DEZ, Wandering Zombies(새로 스폰하지 않고 기존 개체군을 쓴다는 점을 칭찬), Starving Zombies("I've had a horde move to my base drawn by the smell of corpses"), Calm Before The Storm, Horde Night, Dynamic Horde Spawner가 언급됐다 — [Steam 토론](https://steamcommunity.com/app/108600/discussions/0/564785084310231589/)

### Inferences
- 열차 정차 설계("플레이어가 있는 곳을 치는 횟수가 늘어난다")와 가장 가까운 틀은 셋이다. Blood Moon의 **회차가 오를수록 간격은 줄고 웨이브 수는 느는 표**, Siege Night의 **WAVE/TRICKLE/BREAK 리듬과 열기 시스템**, Here They Come!의 **누적 동요도 → 문턱 → 다중 웨이브** 구조다. 셋 다 '시간'과 '플레이어 활동'을 동시에 압력의 입력으로 쓴다.
- '정기 + 무작위'와 '정확한 예보 vs 흐린 예보'의 조합이 모드마다 다르다(Horde Night의 무작위 호드는 표시 안 함, Hark's의 AEBS 예보와 기본 꺼진 정밀 인디케이터). 정보의 정밀도 자체가 설계 변수로 쓰인다는 뜻이다.
- B42 생태계는 아직 굳지 않았다. B41 고전(44만, 11만)의 후계는 수천 명 규모(Hark's 6천, HTC 이식판 300)이고, B42 신작 1위 DHE도 5.2만이다. '인기' 판단은 누적 수치(B41)와 최근 성장(B42)을 나눠 봐야 한다.

### Gaps
- Here They Come!과 Horde Night의 **기본값 숫자**(첫 날, 마리 수, 증가량 등)는 설명문에 없다(스크린샷·GitHub 코드에만 있는 것으로 보이며 확인 못 함).
- EHE의 공식 B42 출시 여부는 작가 채널(GitHub, Discord)로 확인하지 못했다. 이 세션에선 GitHub API 접근이 막혔다.
- Extraction Mode의 레이드 타이머와 '후반 호드' 발동 조건 수치는 시작 가이드 토론 글이 Steam 429(요청 과다)로 막혀 못 읽었다.
- Reddit(r/projectzomboid) 원문 스레드는 검색에 잡히지 않았다. RPS, PC Gamer, TheGamer 목록 원문도 확인하지 못했다.

## 2. 좀비 종류·행동을 바꾸는 모드는 무엇이고, 플레이어에게 종류를 어떻게 알려 주나

### Takeaway
좀비 다양화 모드는 세 부류다. ① **능력치 분포형**: 속도·체력·인지 비율만 바꾸고 외형은 그대로다(Random Zombies 61.9만, Customizable Zombies 36.0만, Night Sprinters 13.1만). ② **특수 감염체형**: 모델·옷·소리·능력이 다르다(CDDA Zombies 13.5만, The Mutants 7.1만은 한 달 만, TLOU Infected). ③ **행동·환경형**: 밤·안개·온도·빛·배고픔에 따라 행동이 바뀐다(Under Cover of Darkness 21.9만, Definitive Zombies, PhunSprinters 2, Realism Zombies). 종류는 **고유 모델·옷 → 고유 소리 → 예비동작(자세) → 이름표·무들(상태 아이콘)** 순으로 많이 알린다. 반대로 DEZ, Lingering Reflexes, Siege Night 질주자처럼 일부러 숨기는 설계도 있다. 숨김형은 "알아볼 수 없어서 죽었다"는 불만을 부른다.

### Cited Findings

#### 능력치 분포형(외형 변화 없음)
- **Random Zombies**(현재 618,949명): Crawler·Shambler·Fast Shambler·Sprinter 비율(합 100), Smart(문을 여는 좀비) 비율, Fragile·Normal·Tough 비율(합 100)을 정한다. 기본값은 기어다니는 좀비 2%, 셔블러 15%, 빠른 셔블러 78%, 질주자 5%, 체력 100% 보통, 똑똑한 좀비 0%다. 좀비 재활용 때문에 7,500ms마다 설정을 다시 검사한다. 힘, 시야, 기억은 "no way" 바꿀 수 없다고 한다. **42.20.0부터 은퇴했다** — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2818577583)
- **Customizable Zombies**(현재 360,067명, 유지보수 끝): 기본값은 죽은 척하는 상태 2%, 기어다니는 좀비 5%, 셔블러 47%, 빠른 셔블러 47%, 질주자 1%이고, 종류별 체력 배수가 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=1992785456)
- **Random Zombies – Day and Night**(현재 111,307명): 낮·밤 분포를 따로 두고, 비·눈·안개(강도별)용 특별 분포를 더한다. 게임시간 1시간마다 어떤 분포를 쓸지 다시 판단한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2888099799)
- **Night Sprinters [41.60+]**(현재 130,998명): 밤에는 질주한다. 낮·밤 각각 속도, 체력, 시야, 청각, 기억을 정하고, 계절별로 밤 시간을 정의한다. '비 오면 질주'도 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2683677702)
- **[42.20] Night Sprinters – Dusk and Dawn**(현재 3,236명): 하늘이 1/4 어두워지면 바뀌기 시작한다. 질주자 비율이 해 진 직후 1%에서 +10분 2%, +30분 4%, +1시간 8%, +90분 16%, +2시간 32%, +2시간 30분 64%, **+3시간 100%로 두 배씩** 오르고, 해 뜰 무렵 되돌아간다. 활성 시간은 6월 6시간 43분, 3월 8시간 37분, 12월 10시간 31분이다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3777915284)
- **Sprinters Over Time**(B42, 현재 25,107명): 질주자 비율을 기본 30일마다 1%씩 올린다(6개월 된 세계면 7%). 상한, 첫 등장 지연, 역방향(1일째 100%에서 줄어듦)을 고를 수 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3608589196)
- **PhunSprinters 2**(B42, 현재 39,946명): 질주 위험을 층층이 곱한다. 전역 기본 위험 → 구역 덮어쓰기 → **생존 시간 할인**(예: 구역 위험 50%, 할인 100시간, 생존 50시간 → 실효 25%) → **달 위상**(보름 200%면 20%→40%) → 어둠 규칙 → **빛 억제**(밝은 빛이 질주자를 걷게 만든다). 모드는 상시, 해질녘~새벽, 바깥이 어두울 때, 좀비 주변이 어두울 때(손전등이 핵심 도구가 됨) 넷이다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252110)
- **Slower Sprinters**(현재 190,531명): 질주자 애니메이션 속도를 20~43% 늦춘다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2716710487)
- **Lingering Reflexes**(현재 95,952명): 기본 100마리에 1마리꼴로 문을 여는 똑똑한 좀비를 섞는다. 다른 좀비와 구별되지 않게 해서 "catch you off guard"를 노린다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2898005857)
- **Not Random Sprinters**(B42, 현재 2,238명): **특정 옷을 입은 좀비는 늘 질주자**다. 기본 목록은 153+19개다(학교·경찰·소방·군·의료 같은 거점 옷과 좋은 전리품 옷, 웨딩·스피포 같은 희귀 옷 등) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3665657529)

#### 행동·환경형
- **Under Cover of Darkness**(현재 218,560명): 해 진 2시간 뒤부터 해 뜨기 2시간 전까지, 그리고 안개가 끼면 좀비 시야를 '나쁨'으로 바꾼다. 인공조명은 고려하지 않는다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2954422590)
- **Definitive Zombies B41**(현재 117,858명): '현실적' 프리셋. 낮에는 시야와 기억이 오르고, 밤에는 시야와 기억이 내려가는 대신 청각이 오른다. **0°C 이하면 느려진다.** 안개, 비, 눈, 구름, 바람이 감각을 깎는다. 보름달은 밤의 불리함을 없앤다. 'Entropy'는 세계 나이에 따라 좀비를 열화시킨다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2981571303)
- **Hive Mind**(현재 24,353명): 반경 안의 좀비가 시야를 공유한다(기본 100칸=셀 하나, 낮 전용·밤 전용 선택 가능) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2990755215)
- **More Zombie Behavior**(현재 6,109명): 보이드(boids) 군집 이동으로 '콩가 줄'을 없앤다. 플레이어 속도를 읽어 **진로를 가로막는 추격**, 추격 중 가속, 공격하며 이동한다. 행동마다 적용 비율을 정한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3174295288)
- **Tripping Zombies**(현재 111,628명): 추격 중 서로 부딪히면 넘어진다. B42 후계작 'Reborn w/ Ragdolls'(현재 40,425명)가 있다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2856413047), [Reborn](https://steamcommunity.com/sharedfiles/filedetails/?id=3746603021)
- **Vaulting Zombies**(현재 18,623명): 울타리와 창문을 넘고, 창 너머·울타리 가까이의 플레이어를 태클한다(넘어오는 순간 밀치면 막을 수 있다) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2872586942)
- **Realism Zombies [B42.21]**(현재 4,475명): 개체별 배고픔, 냄새, 섭식, 부패, 날씨, 혈흔. 굶주린 좀비는 점점 약해진다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3802966881)

#### 특수 감염체형(모델·소리·능력이 다름)
- **The Mutants**(B42.20/42.21, 2026-09-06 출시, 현재 71,329명): 기본 스폰율은 **종류마다 0.4%**이고, 종류마다 고유한 외형, 애니메이션, 모델, 옷, 소리가 있다. **Puker**: 30초마다 표적 쪽으로 토하는데 피할 수 있다. 맞으면 'Puked' 상태가 되어 최대 3게임시간 동안 좀비가 따라오고, 몸을 씻으면 풀린다. 바닥의 토사물도 좀비를 끈다. **Husk**: 플레이어를 보면 팔로 머리를 가린다. 헤드샷 외의 총기 피해가 줄어 기본 프리셋에서 15%만 받는다. 근접 공격은 그대로다. **Skitter**: 늘 기어다니고, 발견하면 초고속으로 돌진한다. **Leaper**: 늘 질주자이고, 10초마다 도약한다. 맞으면 넘어지지만 피할 수 있고, 울타리와 창문을 빨리 넘는다. **Wrecker**: 10초마다 직선 돌진해 경로의 대상을 넘어뜨린다. 통과할 수 없는 물체에 부딪히면 자기가 넘어지고, 부술 수 있는 물체면 부순다. **Weeper**: 늘 질주자이고 시야·청각이 극히 나쁘다. 앉은 휴면 상태로 스폰해 울고, 가까울수록 플레이어의 공황이 오른다. 휴면 중엔 피해를 받지 않는다. 치명타와 넘어뜨리기에 면역이다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3796669056)
- **Special Zombies 시리즈**(B42.20.2, 한국어 병기 작가): 공용 프레임워크는 등록된 특수 좀비만 갱신해 성능을 아낀다 — [프레임워크](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282009). **Screamer**: 흰 드레스의 창백한 여성 좀비이고 체력이 낮고 느리다. 약 10칸 안의 플레이어를 눈으로 보면(일반 좀비보다 시야각이 좁음) **멈춰서 비명을 준비**하고, 짧은 준비 뒤 약 30칸 안의 좀비를 끈다. 준비 중에 공격, 밀치기, 경직을 주면 취소된다. 비명을 들은 플레이어는 'Horrific Echo' 무들과 악몽을 얻는다 — [Screamer](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282817). Spitter, Tank, Bloater 편도 있다 — [Tank](https://steamcommunity.com/sharedfiles/filedetails/?id=3783283328), [Bloater](https://steamcommunity.com/sharedfiles/filedetails/?id=3789467089)
- **The Last of Us Infected**(2958052085판, 현재 11,059명): Runner는 보통 질주자다. Stalker는 시야와 청각이 나쁘고 기억이 없어 건물 안에 숨으며, Runner보다 강하다. Clicker는 느리지만 강하고 체력이 높으며 한 방에 죽인다. **밀치거나 밟을 수 없어 무기가 필수**다. Bloater는 산탄총 약 6발을 버티고, 잡으면 한 방에 죽인다. **경직 면역이라 근접이 무의미하고 불에 약하다.** 등장 시기 옵션(기본 꺼짐)도 있다: Stalker 7~28일, Clicker 330~550일, Bloater 1825~3650일 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2958052085). 종류별 고유 울음 사운드 애드온도 있다("runners will make runner sounds, stalkers stalker sounds…") — [사운드 애드온](https://steamcommunity.com/sharedfiles/filedetails/?id=3046492205)
- **TLOU Infected(SirDoggyJvla판)**: 좀비 머리 위에 **이름표**를 띄운다. Mod Options나 샌드박스로 끄거나 위치를 바꿀 수 있다(B41판, 현재 28,326명) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3248766883). B42판은 버려진 뒤 오픈소스로 풀렸고(현재 11,752명) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3409434765), 커뮤니티의 안정판 패치는 ZomboidForge와 StarlitLibrary가 필요하다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3776164832)
- **CDDA Zombies**(현재 134,882명, 2026-03-27 갱신): 종류별로 속도와 체력이 다르다. Feral(빠름), Tough, Fat(느리고 단단함), Skeleton(약함), Decayed, Crawler, **Necromancer**(주변 시체를 되살림), Brute·Wrestler(공격 시 밀침), Screamer·Screecher(추적 중 비명), Grabber(붙잡음), **Master**(주변 좀비를 진화시킴), Child(죽이면 불행해짐), Firefighter(불 면역), Survivor(문을 엶), 그리고 경찰·방호복·군인 좀비 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2749928925). 파생작 CDDA Zomboids는 35종이다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2914016243)
- **ScreecherZ**(현재 127,986명): 질주자가 플레이어를 **발견하는 순간 큰 비명**을 지른다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3041996269)
- **보스형**: ZomBoss(현재 38,721명)는 체력, 질주, 부하 웨이브 소환, 옷, 드롭을 설정할 수 있지만 디버그나 관리자로만 부를 수 있고 한 번에 한 마리뿐이다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3010956746). The Boss Zombie(B42, 현재 3,814명)는 고유 모델과 목소리를 가졌다. 질주하고, 넘어뜨리고, 문과 울타리를 부수고, 원거리에서 폭발하는 바위를 던진다. 차로 치기 어렵다. 자연 스폰하거나 처치 수로 소환된다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3802964456)
- **DEZ**: 진화를 좀비마다 따로 저장하고, 드물게 '리더'가 나온다. 리더 원형은 HIVE(결속), HUNTER(추적 지속), FRENZY(소음에 과민), SHADOW(경로 고집), SPLIT(분산), STALKER(한 먹잇감만 쫓음), **HOWLER**(주변을 불러모아 웨이브로 밀어붙임)다. 체력이나 공격력 보너스는 없고 집단 행동만 바꾼다. "No UI. No mutation gimmicks. No arcade bosses." "You may never know which type you are facing — until the horde behaves differently." — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3676814360)
- **외형 다양화(능력 변화 없음)**: Authentic Z(현재 2,444,006명)는 좀비 관련 모드 중 구독이 가장 많고 옷 다양화 모드다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2335368829). Realistic Army Zombies(현재 107,497명)는 군 좀비에게 방호 장비와 고유 얼굴 텍스처를 준다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=1902435140)
- **분위기형**: Lingering Whispers(현재 317,777명)는 0.1% 확률로 좀비가 1~4단어를 '텍스트로만' 말하게 한다. 문을 부술 때처럼 좀비 상태에 따라 대사가 다르다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2874678809)

#### 종류를 알리는 방식(근거별 정리)
- 고유 모델·옷: The Mutants([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3796669056)), Screamer의 흰 드레스([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282817)), Siege Night의 Breaker(공사복)와 Tank(군복)([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584)), Not Random Sprinters의 '옷 = 질주자' 규칙([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3665657529))
- 고유 소리: ScreecherZ의 발견 비명([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3041996269)), TLOU 종류별 울음([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3046492205)), Weeper의 울음과 근접 공황([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3796669056))
- 예비동작(자세): Husk가 머리를 가림, Screamer가 멈춰서 비명을 준비함 — [The Mutants](https://steamcommunity.com/sharedfiles/filedetails/?id=3796669056), [Screamer](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282817). 플레이어도 "why is he crouching like that… bug? Nope. He suddenly launched himself at me"(Leaper)라고 썼다 — [댓글 2026-10-03](https://steamcommunity.com/sharedfiles/filedetails/comments/3796669056)
- 이름표·무들: TLOU 이름표([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3248766883)), Puked 상태(Moodle Framework 필요)([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3796669056)), Horrific Echo 무들([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282817))
- 일부러 숨김: DEZ 리더([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3676814360)), Lingering Reflexes의 문 여는 좀비([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2898005857)), Siege Night의 섞여 드는 질주자([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584)), Random Zombies 계열(속도는 움직임으로만 드러남)([워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2818577583))

### Inferences
- 호평받는 특수 좀비는 거의 모두 **규칙 하나 + 예비동작 + 정답 대응 하나**로 정의된다. 예: Clicker는 밀치기 무효라 무기가 정답이고, Bloater는 경직 면역에 불이 약점이고, Husk는 총에 강하고 근접에 약하고, Screamer는 준비 중에 끊으면 되고, Wrecker는 벽에 유도하면 된다. 각 종류가 플레이어의 지배적 전략(밀치기, 사격, 농성, 은신)을 하나씩 깨도록 짜여 있다.
- 스폰율을 아주 낮게 두고(The Mutants 종당 0.4%, Siege Night Tank 공성당 2마리) 등장 시점을 미루는(TLOU 단계별 일수, Siege Night 자정 이후, Sprinters Over Time) 방식이 표준이다. 종류 수보다 '언제 처음 보게 하느냐'를 설계한다.
- 한 달 만에 7.1만을 모은 The Mutants와 그 댓글란의 L4D 반응("Pills here! TANK TANK TANK!!!", "left for dead" — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3796669056))을 보면, 플레이어에게 가장 잘 통하는 참조 틀은 여전히 **L4D 특수 감염체**다. 반면 '정보 없음'을 내세운 DEZ(5천)와 Wandering Hordes(1.2만)는 작은 틈새다. 다만 출시 시기가 달라 단순 비교는 위험하다.

### Gaps
- Special Zombies 시리즈의 Spitter·Tank·Bloater 세부 수치, ScreamerZ(2957605921)의 작동 방식은 받지 못했다.
- CDDA Zombies가 종류를 시각적으로 어떻게 구분하는지(옷 외에 전용 모델이 있는지)는 설명문에 없다.
- TLOU 이름표가 실제로 얼마나 켜진 채 쓰이는지 같은 사용 실태 데이터는 없다.

## 3. 플레이어는 무엇을 칭찬하고 무엇을 불평하나(공정성·가독성·난이도 급등·성능)

### Takeaway
불평은 다섯 갈래로 모인다. ① **기지 안·눈앞·지붕 위 스폰**(공정성 붕괴의 1순위), ② **전지적 추적·끝나지 않는 스폰**("항상 내 위치를 안다", "수천 마리를 죽였는데 계속 온다"), ③ **설정이 안 먹는 수치 폭주**(줄였는데 100마리, 2웨이브에 1,000마리), ④ **예비동작 없는 특수 공격**(토사물 즉발, 접촉 전 넉다운), ⑤ **잘 때·자리 비웠을 때 오는 사건**. 칭찬은 "기지 지루함을 고쳐 준다", "게임이 다시 위험해졌다", "설정을 마음대로 바꿀 수 있다"에 몰린다. 원작자가 떠난 B41 모드에는 'o7(경례)'과 "업데이트해 달라"가 몰린다.

### Cited Findings

#### 공정성: 스폰 위치
- Siege Night: "zombies spawn in the house and break all of your windows", "zombies just spawn wherever you can visually see them spawn in"(2026-09-02). 미니 호드 하나가 "zombies from the entire map converge on your location"(2026-06-11) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3669589584)
- Dynamic Horde Events: "Hordes spawn in my base and on top of roofs. Not a fan."(2026-09-03). 강가 기지에서 "hordes spawn in my basement … because it cannot spawn in water"(2026-08-23). 울타리로 막은 단지 안에 스폰한다는 MP 보고가 있고(2026-09-10), "Can we add a safe zone feature so that zombie hordes won't spawn inside the base?"(2026-08-23)라는 요청이 나왔다 — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3716405632)
- Bandits는 작가 스스로 "purely distance based"라서 기지 안에 나올 수 있다고 적었다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- 반대 사례: Horde Night는 실내와 시야 범위 스폰을 막았다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2714850307). Big Chiefs는 화면에 보이는 칸과 B42 울타리 단지를 거부한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3780696417). Blood Moon은 '보이지 않는 실외 지점'만 고른다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674)

#### 전지적 추적·끝없는 스폰
- Calm Before the Storm: "what is the reason for them to always know where you are I can't go anywhere without a horde gathering around me"(2026-06-15). "This took me 489 shotgun shells to clear a deafult settings rosewood horde"(2026-07-15) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2953621037)
- Here They Come!: "Zombies wont stop spawning. I killed thousands by now. They keep coming. I have default settings."(2024-11-08). "so when does the 'pulse' end?"(2025-05-08) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2779839289)
- Dynamic Horde Events: "do the zombies appear out of thin air … I wouldn't want an infinite zombie spawner."(2026-08-25) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3716405632)
- Wandering Zombies: 반대로 "getting tired of mobs breaking agro and wandering off all the time"(2026-09-11)라는 불만도 있다 — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2983905789)
- Wandering Hordes 작가는 경쟁작들을 "zombies that magically know where you are"와 대비해 자기 모드를 홍보한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3759920384)

#### 난이도 급등·설정 신뢰성
- Siege Night: "The reduced numbers have no effect, siege spawned 100 zombies no matter how few i put"(2026-04-04). 첫 습격 2웨이브에 "like 1000 zombies came … even lagged my game"(2026-03-30). 시작일 설정이 하루 어긋남(2026-09-14), 06시 시작·08시 종료 같은 오작동(2026-09-22). "most likely vibe coded"라는 혹평(2026-09-02)도 있다 — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3669589584)
- Horde Night: 42.18에서 호드가 5일째가 아니라 10일째 왔다(2026-05-22) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2714850307). Hark's 후계작은 v0.45 'Clarity'에서 설정을 바꿔도 예전 일정이 남던 문제를 고쳤다("No same day surprises") — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3713005182)
- Here They Come!에는 동요도 아이콘이 빨간색에 멈춘 채 호드가 안 온다는 보고(2024-11-17)와, 반대로 빨간색에 멈춘 채 좀비가 계속 온다는 보고(2024-11-18)가 있다. 경고 없이 엄청난 수를 넣고 수를 조절할 수 없게 했다는 러시아어 항의(2024-10-26)도 있다 — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2779839289)
- Calm Before the Storm: MP에서 10일 넘게 호드가 한 번도 안 왔다는 보고(2026-07-22, 2026-09-12), "sandbox options need more information"(2026-06-15) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2953621037)
- Dynamic Horde Events: "1/2 the time nothing happens … the other 1/2 the horde comes when im asleep and i can't do a single thing about it"(2026-08-26) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3716405632). 대조적으로 Here They Come!은 v0.2.1에서 호드가 시작되면 자는 플레이어를 깨우게 했다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2779839289)
- Night Sprinters: "at 22:00 ALL ZEDS BECOME SPRINTERS cant set porcenages … it ignores all the configurations"(2026-07-07) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2683677702)

#### 가독성·예비동작(특수 좀비)
- The Mutants:
  - Weeper는 "knocking you down before you can even make physical contact with it is kinda cheap … frame-perfect attack"(2026-10-04).
  - Puker는 "can snipe you from like 10 tiles away, also i've seen it insta puking me without any animation"(2026-09-30).
  - Leaper는 군중 속에서 구별되는 소리를 넣어 달라는 요청이 나왔다: "Most of my recent deaths were due to spotting it at last time in a crowd"(2026-09-29).
  - "First one I came across was a leaper and had no idea until I was jumpscared"(2026-10-03).
  - 다른 모드의 탱크 투척물이 "you can't actually see anything so it's hard to know what's going on"이라는 보고도 있다(2026-09-29).
  - 출처: [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3796669056)
- MP 경고 동기화: DHE에서 호드 경고가 호스트에게만 보이거나 플레이어마다 다른 시각에 뜬다는 보고가 있다(2026-08-28, 2026-09-08) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3716405632)

#### 성능
- Siege Night에서 1,000마리 웨이브가 렉을 일으켰다(위 출처). Hark's는 "Huge hordes … can place significant load on the server"라고 적었다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3713005182). DHE도 거대 호드는 서버 부담이 크니 크기와 빈도를 줄이라고 권한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3716405632). Week One은 "consumes a lot of performance"라고 경고한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
- 대응 설계: Random Zombies는 "less CPU-intensive"를 내세우고 검사 주기를 조정할 수 있게 했다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2818577583). Special Zombies 프레임워크는 일반 좀비 전체 검사를 없애 FPS를 개선했다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282009). Living Hordes와 Big Chiefs는 먼 호드를 추상 수치로 시뮬레이션한다 — [Living Hordes](https://steamcommunity.com/sharedfiles/filedetails/?id=3691686404), [Big Chiefs](https://steamcommunity.com/sharedfiles/filedetails/?id=3780696417)
- EHE는 'sound bug'가 반복된 문제였다. 2025-01 변경 기록 제목이 "Infamous Sound-Bug Fix v3? v4?"다 — [변경 기록](https://steamcommunity.com/sharedfiles/filedetails/changelog/2458631365)

#### 칭찬
- Siege Night: "its so good i cant even describe how much this fixes base boredom", "highly customizable"(2026-05-17). 30일째에 지루해서 넣었다는 사용 동기도 보인다(2026-05-24) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3669589584)
- The Mutants: "This actually makes the game feel dangerous again"(2026-10-04) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3796669056)
- Horde Night: "the best horde night mod … Other horde mods have no customisation settings. This one was perfect"(2026-08-07) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2714850307)
- Wandering Zombies: "Should be base game."(2026-09-29). 호드 이벤트가 장거리 이동에서 "Empty Cell gets populated after a while and in combination with Meta sounds it's just feels so natural"(2026-09-15) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2983905789)
- Night Sprinters: "actually horrifying … boss in the day..... babay at night"(2025-09-13) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2683677702)
- 장르 피로: Blood Moon 첫 댓글은 "7 days to die mod? again?"(2026-08-30)이었다 — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/3792781674)

### Inferences
- 가장 큰 불공정감은 난이도 자체가 아니라 **'내가 막을 수 없는 곳에서 생긴 위협'**에서 온다: 안전하다고 지은 기지 안, 시야 안, 잠든 사이. 웨이브 강도보다 **스폰 위치와 발동 시점의 규칙**이 신뢰를 좌우한다.
- '끝없는 스폰'은 의도된 압박이어도 **끝나는 조건이 안 보이면** 버그로 읽힌다(HTC 펄스, CBTS의 항상 아는 위치). 열차 게임에선 '떠나면 끝난다'는 출구가 있으니, 그 출구를 얼마나 분명히 보여 주느냐가 같은 불만을 막는 열쇠다 **[제안]**.
- 특수 좀비의 불만은 거의 모두 **예비동작의 부족**(즉발 토사물, 접촉 전 넉다운)과 **군중 속 식별 불가**다. 작은 모바일 화면에선 더 심해질 문제다 **[제안]**.

### Gaps
- 칭찬과 불평의 비율 같은 정량 데이터는 없다(최근 댓글 최대 40개씩만 표본으로 읽었다).
- Reddit, YouTube 반응은 확인하지 못했다. EHE는 워크숍 댓글이 닫혀 있어 최근 사용자 불만을 직접 확인하지 못했다.

## 4. 인기(구독자 수, 2026-10-05 조회)와 B41/B42 지원 현황

### Takeaway
누적 기준 상위는 여전히 B41 시절 모드다: EHE 252만, Bandits 165만, Random Zombies 123만, Horde Night 95만. B42 안정판 이후 이 중 상당수가 깨졌거나 은퇴했다(Horde Night CTD, Random Zombies 은퇴, EHE는 B41 최종판). B42 신작 중 빠르게 크는 것은 Dynamic Horde Events B42(5.2만, 5개월), The Mutants(7.1만, 1개월), Extraction Mode(3.5만, 7주), Reactive Sound Events(15.0만, 8개월)다.

### Cited Findings
아래 표의 구독자 수, 날짜, 태그는 Steam Web API로 2026-10-05에 받았다. 링크는 각 워크숍 페이지다. '실제 상태'는 설명문과 댓글 근거다.

| 모드 | 분류 | 현재 구독 | 누적 | 최종 갱신 | 빌드 태그 | 실제 상태(근거) |
|---|---|---:|---:|---|---|---|
| [Authentic Z](https://steamcommunity.com/sharedfiles/filedetails/?id=2335368829) | 좀비 옷(외형) | 2,444,006 | 3,916,756 | 2026-09-13 | B41, B42 | 외형 전용 |
| [[B41] Expanded Helicopter Events](https://steamcommunity.com/sharedfiles/filedetails/?id=2458631365) | 헬기·세계 사건 | 1,256,403 | 2,524,545 | 2025-10-12 | B41 | B41 최종판, 공식 B42판 미확인 ([PSA](https://steamcommunity.com/app/108600/discussions/0/592888463635869664/)) |
| [[B42] Bandits NPC](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204) | 사람 습격 | 1,043,646 | 1,650,932 | 2026-10-04 | B42 | 42.20 이상 전용(설명문) |
| [Random Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=2818577583) | 분포 | 618,949 | 1,226,095 | 2025-02-24 | B41, B42 | 42.20.0부터 은퇴(설명문) |
| [Horde Night](https://steamcommunity.com/sharedfiles/filedetails/?id=2714850307) | 정기 호드 | 440,396 | 947,155 | 2024-12-22 | B41 | 42.20에서 CTD, 방치([댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2714850307)) |
| [Customizable Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=1992785456) | 분포 | 360,067 | 783,211 | 2022-01-10 | B40, B41 | 유지보수 끝, B41 MP(41.66+) 미지원 |
| [[B42] Week One NPC](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543) | 시나리오 고조 | 330,249 | 651,565 | 2026-08-07 | B42 | 42.19/42.20 안정판 |
| [Lingering Whispers](https://steamcommunity.com/sharedfiles/filedetails/?id=2874678809) | 분위기 | 317,777 | 725,618 | 2025-01-10 | B41, B42 | 42.20 상태 미확인 |
| [Under Cover of Darkness](https://steamcommunity.com/sharedfiles/filedetails/?id=2954422590) | 밤·안개 시야 | 218,560 | 533,170 | 2023-04-04 | B41 | B42 미확인 |
| [Slower Sprinters](https://steamcommunity.com/sharedfiles/filedetails/?id=2716710487) | 질주자 속도 | 190,531 | 484,050 | 2025-01-03 | B41, B42 | "works on B42"(42.20 미확인) |
| [Reactive Sound Events](https://steamcommunity.com/sharedfiles/filedetails/?id=3656190498) | 메타 이벤트 | 150,279 | 274,997 | 2026-03-16 | B42 | B42 |
| [CDDA Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=2749928925) | 특수 종류 | 134,882 | 293,646 | 2026-03-27 | B41, B42 | 42.20+용 독립 패치가 따로 있음([SinPatch](https://steamcommunity.com/sharedfiles/filedetails/?id=3791346420), 606명) |
| [Night Sprinters [41.60+]](https://steamcommunity.com/sharedfiles/filedetails/?id=2683677702) | 낮밤 속도 | 130,998 | 333,610 | 2023-01-16 | B41 | B42 이식판·후계작 있음([Dusk and Dawn](https://steamcommunity.com/sharedfiles/filedetails/?id=3777915284) 3,236명) |
| [ScreecherZ](https://steamcommunity.com/sharedfiles/filedetails/?id=3041996269) | 소리 신호 | 127,986 | 337,040 | 2024-02-22 | B41 | B41 |
| [Definitive Zombies B41](https://steamcommunity.com/sharedfiles/filedetails/?id=2981571303) | 환경 반응 | 117,858 | 347,908 | 2025-01-26 | B41 | 지원 종료, B42 초기판은 별도 |
| [Here They Come!](https://steamcommunity.com/sharedfiles/filedetails/?id=2779839289) | 누적형 호드 | 113,086 | 292,264 | 2022-05-28 | B41 | B42.20 제3자 이식판([300명](https://steamcommunity.com/sharedfiles/filedetails/?id=3787895035)) |
| [Tripping Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=2856413047) | 행동 | 111,628 | 306,914 | 2023-04-17 | B41 | B42 후계([Reborn](https://steamcommunity.com/sharedfiles/filedetails/?id=3746603021) 40,425명) |
| [Random Zombies – Day and Night](https://steamcommunity.com/sharedfiles/filedetails/?id=2888099799) | 낮밤 분포 | 111,307 | 274,977 | 2024-07-24 | B41 | B41 |
| [Wandering Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=2983905789) | 배회 | 104,224 | 245,124 | 2026-08-03 | B41, B42 | B42·B42 MP 지원 명시(MP 일부 문제 댓글) |
| [EHE: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) | EHE 애드온 | 102,243 | 262,740 | 2024-07-17 | B41 | B41 |
| [Horde Event](https://steamcommunity.com/sharedfiles/filedetails/?id=2992366401) | 트리거 호드 | 87,139 | 224,976 | 2023-11-28 | B41 | B41 |
| [The Mutants](https://steamcommunity.com/sharedfiles/filedetails/?id=3796669056) | 특수 종류 | 71,329 | 82,051 | 2026-09-29 | B42 | 42.20/42.21 SP·MP(설명문) |
| [The Calm Before The Storm](https://steamcommunity.com/sharedfiles/filedetails/?id=2953621037) | 이주·귀환 | 57,252 | 152,426 | 2025-06-19 | B41, B42 | 42.20 "(partially) works", 작가 지원 중단([댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2953621037)) |
| [Dynamic Horde Events B42](https://steamcommunity.com/sharedfiles/filedetails/?id=3716405632) | 호드 3종 | 51,821 | 74,796 | 2026-08-17 | B42 | 42.20 명시, 작가 휴식 중 |
| [PhunSprinters 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252110) | 위험 계산 질주 | 39,946 | 64,712 | 2026-08-30 | B42 | B42(B41 지원 중단) |
| [ZomBoss](https://steamcommunity.com/sharedfiles/filedetails/?id=3010956746) | 보스 | 38,721 | 118,186 | 2023-07-29 | B41 | B41 |
| [Extraction Mode](https://steamcommunity.com/sharedfiles/filedetails/?id=3785397275) | 레이드·탈출 | 34,554 | 43,497 | 2026-10-04 | B42 | B42 베타 |
| [HEF – Helicopter Event Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3672792485) | 헬기 2차 사건 | 29,877 | 69,289 | 2026-09-23 | B42 | B42 |
| [Thumping Attracts Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=3646787580) | 공성 증폭 | 29,166 | 79,591 | 2026-01-20 | B41, B42 | 42.13 동작 명시 |
| [[B41] The Last of Us Infected](https://steamcommunity.com/sharedfiles/filedetails/?id=3248766883) | 특수 종류 | 28,326 | 87,651 | 2024-10-30 | B41 | B42판은 [버려짐](https://steamcommunity.com/sharedfiles/filedetails/?id=3409434765), [커뮤니티 패치](https://steamcommunity.com/sharedfiles/filedetails/?id=3776164832) 3,662명 |
| [Sprinters Over Time](https://steamcommunity.com/sharedfiles/filedetails/?id=3608589196) | 장기 상승 | 25,107 | 64,326 | 2026-03-09 | B42 | B42 |
| [Hive Mind](https://steamcommunity.com/sharedfiles/filedetails/?id=2990755215) | 시야 공유 | 24,353 | 82,250 | 2023-11-28 | B41 | B41 |
| [Siege Night](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584) | 공성 웨이브 | 17,177 | 46,745 | 2026-03-15 | B42 | B42 SP 동작 보고와 오작동 보고 혼재 |
| [Wandering Hordes](https://steamcommunity.com/sharedfiles/filedetails/?id=3759920384) | 지나가는 무리 | 11,506 | 15,054 | 2026-09-29 | B42 | B42, MP 지원 명시 |
| [Hark's Horde Night Revamped](https://steamcommunity.com/sharedfiles/filedetails/?id=3713005182) | 정기 호드 | 6,219 | 8,569 | 2026-08-12 | B42 | B42 안정판 |
| [Special Zombies Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282009) | 특수 종류 | 6,219 | 9,203 | 2026-08-25 | B42 | 42.20.2 |
| [Last Stand Together](https://steamcommunity.com/sharedfiles/filedetails/?id=3534542229) | 웨이브 디펜스 | 5,250 | 11,332 | 2026-08-30 | B41, B42 | 42.20 명시 없음 |
| [Big Chiefs Dynamic Hordes](https://steamcommunity.com/sharedfiles/filedetails/?id=3780696417) | 영속 호드 | 5,169 | 7,051 | 2026-09-26 | B42 | 42.20용 |
| [DEZ – Dynamic Evolution Z](https://steamcommunity.com/sharedfiles/filedetails/?id=3676814360) | 진화 | 5,157 | 11,108 | 2026-09-27 | B42 | B42 |
| [Living Hordes Beta 0.8](https://steamcommunity.com/sharedfiles/filedetails/?id=3691686404) | 개체군 교체 | 2,635 | 5,602 | 2026-09-28 | B42 | 솔로 전용 |
| [Horde Day](https://steamcommunity.com/sharedfiles/filedetails/?id=3495000708) | 정기 호드 | 1,194 | 3,473 | 2025-06-22 | B41 | B41 |
| [The Director](https://steamcommunity.com/sharedfiles/filedetails/?id=3720305815) | 감독 AI | 1,034 | 2,288 | 2026-05-19 | B42 | B42.18 |
| [Blood Moon Hordes](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674) | 7일 주기 | 645 | 869 | 2026-08-30 | B42 | 42.20 이상 필요 |
| [Warlord](https://steamcommunity.com/sharedfiles/filedetails/?id=3719581107) | 전령 습격 | 108 | 299 | 2026-05-05 | B42 | 42.17 |

- 참고(그 밖의 수치): Night Sprinters 이식판 [B42_12](https://steamcommunity.com/sharedfiles/filedetails/?id=3625565608) 2,025명, [Not Random Sprinters](https://steamcommunity.com/sharedfiles/filedetails/?id=3665657529) 2,238명, [Ultimate Helicopter Event [B42]](https://steamcommunity.com/sharedfiles/filedetails/?id=3429167063) 606명, [EHE Super Weird Edition](https://steamcommunity.com/sharedfiles/filedetails/?id=2580001162) 25,789명, [Rewarding Night Combat](https://steamcommunity.com/sharedfiles/filedetails/?id=2781963981) 181,102명, [Lingering Reflexes](https://steamcommunity.com/sharedfiles/filedetails/?id=2898005857) 95,952명, [Random Sound Events](https://steamcommunity.com/sharedfiles/filedetails/?id=2834231099) 85,499명, [Realistic Army Zombies](https://steamcommunity.com/sharedfiles/filedetails/?id=1902435140) 107,497명.
- B41 모드를 B42에서 돌리는 우회법으로 "change to folder structure to the build 42 one (folders "42" and "common")"이라는 댓글이 있다. 자바나 라이브러리에 의존하지 않는 B41 모드는 그대로 돈다는 주장이다(2025-10-02) **[미검증]** — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2779839289)

### Inferences
- "가장 인기 있는 호드 모드"라는 질문은 B41 누적(Horde Night)과 B42 현재(DHE)로 답이 갈린다. 원작 고전들은 B42 안정판에서 대부분 비공식 포크로 넘어갔고, 그 포크들은 원작 구독자의 1~2%만 얻었다.
- EHE와 Bandits처럼 "무단 재업로드 금지"를 명시한 모드는 공식판이 없으면 후계가 끊긴다. 반대로 Calm Before the Storm과 Dynamic Horde Events처럼 포크를 허락한 모드는 커뮤니티판이 생긴다(Rin Horde Rush 등) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2953621037)

### Gaps
- 구독자 수는 '활성 사용자 수'가 아니다(구독만 해 두고 안 쓰는 경우가 섞여 있다). 실제 플레이 비율은 알 수 없다.
- 표에 없는 모드(More Zombies, More Difficult Zombies, Random Zeds, Starving Zombies, Dynamic Horde Spawner, Thump with Friends)는 ID와 수치를 확인하지 못했다.

## 5. 이 모드들의 기능 중 B42 바닐라에 들어간 것이 있나

### Takeaway
**부분적으로만 그렇다.** 가장 분명한 것은 **질주자 비율 설정**이다. B42 샌드박스에 'Random Sprinter Amount'가 생겼고, 그 결과 Random Zombies 작가가 42.20.0에서 모드를 은퇴시켰다("vanilla is basically caught up"). 다만 종류별 비율(기어다니는 좀비·빠른 셔블러·강인함·똑똑함 비율) 같은 세밀한 분포는 아직 바닐라에 없다. B42.18의 **좀비별 속도 API**는 모더를 위한 기반이다. 정기 호드·웨이브, EHE식 헬기 다양화, 특수 감염체, NPC 습격이 바닐라에 들어갔다는 증거는 찾지 못했다.

### Cited Findings
- B42 샌드박스: Zombie Lore → Speed에 Sprinters, Fast Shamblers, Shamblers, Random이 있다. Random을 고르면 'Random Sprinter Amount'(Sprinter Percentage)로 질주자 비율을 정하고, 프리셋은 100/90/50/33/6/0%다. 종류별 비율 조절은 노출되어 있지 않다. 기어다니는 좀비는 속도 단계가 아니라 '자세'다 — [pzfans(B42.19)](https://pzfans.com/shamblers-fast-shamblers-sprinters-and-customize-zombie-speed/)
- 42.20에서 질주자 수를 'Custom'으로 고르면, 하단 'Advanced'를 체크해야 숫자 입력칸이 나온다는 사용자 안내가 있다 **[미검증: 댓글]** — [Random Zombies 댓글 2026-08-07](https://steamcommunity.com/sharedfiles/filedetails/comments/2818577583)
- Random Zombies 작가(2026-08-05): "this mod is not coming back for B42 now that vanilla is basically caught up." 지역별로 설정할 수 있는 More Difficult Zombies를 대안으로 권했다. 설명문에도 "With 42.20.0, this mod is retired … the value added in B42 is small"이라 적었다 — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2818577583), [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2818577583)
- 반론(같은 스레드): "without B42 native or modded support for precise zombie attribute percentages, … the 'Custom Sandbox' is missing its most important tools"(2026-08-05). "I liked having mostly shamblers, but able to set a small percentage of zombies to be others. The default options in the game don't allow that."(2026-08-04) — [댓글](https://steamcommunity.com/sharedfiles/filedetails/comments/2818577583)
- B42.18의 좀비별 속도 API로 The Director가 fast_shambler와 fake_shambler 단계를 만들었다("landed in v1.2.0 via B42.18's per-zombie speed API") — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3720305815)
- 42.20 공식 기능 목록에서 좀비와 관련된 것:
  - 새 스폰 맵이 "makes hordes more urban-focused and natural feeling"하다. 분포는 'Voronoi Noise' 기반이고 월드 시드로 정한다.
  - 좀비가 차량, 총탄, 폭발에 맞으면 래그돌로 쓰러진다.
  - 밤이 "darker … and also a lot more dangerous"해졌다.
  - 세계 전체가 질주자인 도전 모드 "28 Seconds Later"가 생겼다.
  - 샌드박스에 "more nuanced options for … zombie behavior"가 생겼다.
  - 게임 사건에 따라 음악 강도가 바뀌는 적응형 사운드트랙이 들어갔다.
  - 출처: [공식 기능 목록](https://projectzomboid.com/blog/features-overview-build-42-20/)
- B42.19 기준 바닐라 헬기는 여전히 Never/Once/Sometimes/Often 일정과 AEBS 예고로 도는 단일 사건이다(위 1절). 이 가이드는 EHE 등을 "separate mods … not covered here as vanilla behavior"로 구분한다. 즉 EHE식 사건 다양화는 바닐라에 들어가지 않았다 — [pzfans](https://pzfans.com/hovering_doom_surviving_project_zomboid_build_42s_helicopter_event/)
- 바닐라에 웨이브 생존용 'Last Stand' 모드가 있거나 있었다는 것은 Last Stand Together 설명("A multiplayer adaption of Project Zomboid's Last Stand mode")으로 확인된다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3534542229). 42.20 기능 목록이 언급한 도전 모드는 A Really CD DA, Winter is Coming, Top of the World, 28 Seconds Later뿐이라 B42에서 Last Stand의 현황은 확인하지 못했다 — [공식 기능 목록](https://projectzomboid.com/blog/features-overview-build-42-20/)
- 앞으로의 공식 계획: 42.20 뒤 패치는 "primarily aimed at the late game"이고, 2026년 남은 기간엔 "Build 42 Support Update that focuses on optimization, additional modding support, and some player-requested features"를 낸다 — [공식 블로그](https://projectzomboid.com/blog/news/2026/07/project-zomboid-build-42-20-released/)

### Inferences
- 바닐라가 흡수한 것은 '파라미터'(질주자 비율)이지 '사건'(호드의 밤, 헬기 연대기, 특수 감염체)이 아니다. 호드·이벤트 영역은 2026-10 기준으로도 모드의 몫이다.
- 개발사가 후반부 패치를 예고했으므로, 후반 지루함을 겨냥한 정기 호드 류가 공식화될 여지는 있다. 근거 없는 추정이니 확정 정보로 쓰면 안 된다.

### Gaps
- 공식 위키(pzwiki.net)는 Cloudflare 확인 페이지에 막혀 B42 샌드박스 전체 목록(예: 'Active Only' 낮/밤 설정의 정확한 효과, 이주 관련 Rally 설정)을 원문으로 확인하지 못했다.
- 42.21 패치 노트의 좀비 관련 변경은 확인하지 못했다.

## 6. 열차 정차 웨이브와 모바일 좀비 로스터에 주는 설계 교훈

### Takeaway
모드들이 공통으로 증명한 공식은 이렇다. **"시간 시계 + 활동 계기"로 압력을 쌓고, 웨이브는 '정해진 리듬(공격·소강·휴식)'으로 보내되 간격을 줄여 가고, 스폰은 '안 보이는 바깥'에서만, 경고는 '방향·거리·대략 규모'로, 끝은 분명하게.** 특수 좀비는 "규칙 하나 + 예비동작 + 정답 대응 하나 + 낮은 스폰율 + 늦은 첫 등장"이 호평의 조건이다. 열차 게임의 '안전 20분 / 손실 30분'은 이 재료들로 수치화할 수 있다.

### Cited Findings
- 간격을 줄이는 리듬: Blood Moon은 공격 시간대(22~04시)를 그대로 두고 웨이브 수를 6→8→9→12로 늘리며 간격을 60→50→40→30분으로 줄인다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674). Siege Night는 WAVE/TRICKLE/BREAK를 돌리며 자정으로 갈수록 강해진다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584). The Director는 L4D처럼 'wait'(강제 휴식 구간)을 둔다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3720305815)
- 지수 상승 곡선: Night Sprinters – Dusk and Dawn은 질주자 비율을 1%에서 3시간 만에 100%로 두 배씩 올린다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3777915284)
- 활동 계기: Siege Night 열기 값(발전기 +15, 총성 +10, 운전 +8, 공사 +5, 조용하면 냉각) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584). EHE 히트맵(이동, 사격, 처치, 조명탄) — [FEATURES.md](https://github.com/TEHE-Studios/ExpandedHelicopterEvents/blob/main/docs/FEATURES.md). Here They Come! 시간당 동요도 최소·최대와 문턱 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2779839289). Warlord 소음 점수(소음기면 감소) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3719581107)
- 끊을 수 있는 웨이브: Warlord를 경고 포효와 습격 사이에 죽이면 습격이 취소된다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3719581107). Siege Night 미니 호드는 충분히 잡으면 유인이 꺼진다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584). Screamer는 준비 중에 때리면 비명이 취소된다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3783282817)
- 예산과 상한: Blood Moon은 하룻밤 예산 320마리, 동시 활성 60마리 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674). Siege Night는 그룹당 활성 200, 공성당 800(권장) — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584). 먼 무리를 추상 수치로 두는 방식 — [Living Hordes](https://steamcommunity.com/sharedfiles/filedetails/?id=3691686404), [Big Chiefs](https://steamcommunity.com/sharedfiles/filedetails/?id=3780696417)
- 재접속 몰아치기 금지: Blood Moon은 놓친 웨이브를 버린다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674)
- 기존 개체군 활용과 새 유입: Calm Before the Storm, Wandering Zombies는 기존 좀비를 쓴다 — [CBTS](https://steamcommunity.com/sharedfiles/filedetails/?id=2953621037), [WZ](https://steamcommunity.com/sharedfiles/filedetails/?id=2983905789). Living Hordes는 지도 가장자리와 도로로 새 호드를 계속 들인다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3691686404). Big Chiefs는 처치가 영속 개체수를 실제로 줄이고, 일정 비율 아래면 무리가 붕괴한다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3780696417)
- 경고 정보의 층위: Hark's는 내일·오늘을 AEBS로 흐리게 알리고 3시간·1시간 전에 경고하며, 정밀 인디케이터는 기본 꺼짐이다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3713005182). DHE는 종류, 방향, 거리, 대략 수를 보여 준다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3716405632). Blood Moon은 무리별 방향·거리와 다음 웨이브 HUD를 띄운다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3792781674)
- 위험과 보상: Rewarding Night Combat은 23~06시 전투 경험치를 1.5~1.75배로 준다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2781963981). PhunSprinters 2는 "Night travel becomes a risk vs reward decision"이라 쓴다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252110)
- 추위와 빛: Definitive Zombies는 0°C 이하에서 좀비를 늦춘다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=2981571303). PhunSprinters 2는 밝은 빛이 질주자를 걷게 만든다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3676252110). Siege Night 열기는 발전기를 가장 큰 열원(+15)으로 친다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3669589584)
- 탈출형 구조: Extraction Mode는 "survive escalating hordes … Call the helicopter and board the extraction rope before it is too late"라고 쓰고, 후반·탈출 호드와 점진적 질주자 확률을 둔다 — [워크숍](https://steamcommunity.com/sharedfiles/filedetails/?id=3785397275)

### Inferences
- **[제안] 20분·30분을 '리듬'으로 정의하기.** '안전 체류 20분'은 *BREAK(휴식) 구간이 마지막으로 보강 1회를 할 만큼 길었던 시점*으로, '손실 한계 30분'은 *웨이브 도착률이 호위조 처리량을 넘어 TRICKLE이 끊기지 않는 시점*으로 정의한다(Siege Night 리듬 + L4D식 휴식). 그러면 두 숫자가 감이 아니라 테스트로 맞출 수 있는 값이 된다.
- **[제안] 기하급수로 줄어드는 간격의 점근선.** 웨이브 간격을 매번 r배로 줄이면(I_n = I_0·r^n) 웨이브가 무한히 몰리는 시각은 T∞ = I_0/(1−r)이다. 예: I_0 = 4.5분, r = 0.85 → T∞ = 30분이다. 웨이브는 4.5, 8.3, 11.6, 14.3, 16.7, 18.7, 20.4, 21.8, 23.1분…에 오고, 20분 무렵 간격이 약 1.5분 밑으로 떨어진다. 최소 간격 바닥값(예: 30초)과 웨이브 크기 증가를 함께 둬야 한다. 모드에서 가져온 수식이 아니라 조사자가 Blood Moon의 '간격 축소' 원리를 일반화한 것이다.
- **[제안] 소음이 시계를 앞당긴다.** 정차 위협 시계를 '실시간 + 활동 열기'로 만든다. 사격, 발전, 공사, 화물 하역, 기관 예열이 열기를 더한다(Siege Night 값을 출발점으로). 조용히 털면 안전 시간이 20분보다 길어지고, 시끄러우면 짧아진다. decisions.md의 "진화한 좀비는 열과 연기를 쫓는다"와 바로 이어진다. 출발 준비(보일러 가열)가 곧 열기라는 딜레마도 생긴다.
- **[제안] 웨이브를 끊는 표적.** Warlord, DEZ의 HOWLER, CDDA의 Master Z처럼 '부르는 개체'를 두고, 그 개체를 잡으면 다음 웨이브가 늦어지거나 줄어들게 한다. 시계에 맞서는 능동적 대응 수단이 된다.
- **[제안] 스폰 규칙은 신뢰의 문제다.** 열차 주변의 '안전 고리'와 플레이어 화면 안에는 절대 스폰하지 않는다. 진입로(역 출입구, 선로 끝, 도로)에서만 들어오게 한다. 초반엔 한 방향(Siege Night), 후반엔 방향 산포를 넓힌다(Here They Come!의 Angle Spread).
- **[제안] 먼저 역 주민, 나중에 외부 유입.** 웨이브의 앞부분은 역 주변의 기존 좀비를 끌어오고(일찍 정리하면 중반 웨이브가 줄어듦), 뒷부분은 지도 가장자리 유입으로 무한하게 한다. 정리 행동에 보상을 주면서도 무한 체류는 막는다. decisions.md의 '좀비 수렴'과 맞물린다.
- **[제안] 경고 정밀도를 열차 업그레이드로.** 기본은 '방향 + 대략 시각'만 준다. 망루, 무전, 정찰 핸드카를 갖추면 정확한 도착 시각과 규모를 준다(Hark's의 흐린 예보 / 정밀 인디케이터 분리에서 착안).
- **[제안] 끝과 출구를 분명히.** 웨이브마다 끝 신호와 결산(처치 수)을 준다(Siege Night의 새벽 결산, Blood Moon의 새벽 해제). '이제 떠나야 할 단계'를 기적 소리처럼 단계별 신호로 알린다. 그래야 'HTC 펄스는 언제 끝나냐'는 혼란을 피한다.
- **[제안] 앱 백그라운드 복귀 처리.** 앱이 백그라운드에 있던 동안의 웨이브를 복귀 순간 몰아서 내보내지 않는다(Blood Moon 원칙). 모바일은 중단이 잦아 더 중요하다.
- **[제안] 모바일 로스터 원칙.**
  - 종류마다 *실루엣 하나, 색 강조 하나, 고유 소리 하나, 충분한 예비동작 하나, 정답 대응 하나*를 준다.
  - The Mutants의 실패 사례(즉발 토사물, 접촉 전 넉다운, 군중 속 Leaper)를 체크리스트로 쓴다.
  - 첫 등장은 '정차 시간'과 '역 차수'로 늦춘다(Siege Night 자정 이후, TLOU 단계별 일수).
  - 일부러 숨기는 종류(DEZ 리더, 문 여는 1% 좀비)는 작은 화면에서 불공정하게 느껴지기 쉽다. '드문 양념'으로만 쓴다.
- **[제안] 열차 게임용 후보 로스터(모드 근거와 짝지음).**
  - 비명꾼: 은신 실패를 벌함. 준비 중에 끊을 수 있음(Screamer).
  - 파쇄꾼: 바리케이드와 작업 구역 방벽을 깸(Siege Night Breaker, Wrecker).
  - 갑각: 총에 강하고 근접에 약함. "탄약이 떨어지면 근접" 규칙과 맞물림(Husk).
  - 도약꾼: 호위 대열을 무너뜨림. 피할 수 있는 주기 도약(Leaper).
  - 팽창체: 근접 무효, 불이 약점(Bloater).
  - 표식꾼: 맞으면 무리가 따라옴. 물로 씻어 해제해 물 자원과 연결(Puker).
  - 잠복자: 실내 파밍 매복(Stalker, Weeper).
  - 부르는 자: 웨이브 호출, 처치하면 지연(Warlord, HOWLER).
  - 환경 수식어: 한파에 둔화(Definitive Zombies), 빛을 꺼림(PhunSprinters).
  - 주의: decisions.md의 '열과 연기를 쫓는 진화 좀비'와 '빛을 꺼리는 질주자'를 함께 넣으면 서로 반대 신호를 준다. 하나로 정해야 한다.

### Gaps
- 모바일·탑뷰 게임에서 한 화면에 동시에 보일 좀비 수의 적정 상한(성능, 가독성)은 이번 조사 범위의 모드에서 근거를 얻지 못했다. 모드의 상한(60, 200)은 PC 기준이다.
- 위 [제안]의 수치(4.5분, 0.85배, 열기 값)는 플레이테스트로 검증해야 한다. 모드 커뮤니티 데이터로는 '몇 분이 적당한가'를 알 수 없다.
- Extraction Mode의 레이드 시간과 후반 호드 시점(열차 정차와 가장 비슷한 구조)은 확인하지 못했다(Steam 429).
