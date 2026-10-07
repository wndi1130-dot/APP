# 지도 레퍼런스

조사일: 2026-10-07 · 상태: 첫 정리

범위: 비슷한 게임의 지도 화면 / 첫 구간(볼슈틴 → 라이프치히)이 지나는 지역의 실제 지도, 옛 지도, 공개 지리 데이터

## 1. 읽는 법

- 이 문서는 링크와 우리 말로 쓴 메모만 담는다. 게임 화면, 지도 스캔, 아트북 그림은 저장소에 올리지 않았다.
- 퍼블릭 도메인이나 CC 지도도 이번에는 파일로 올리지 않았다. 스캔 한 장이 수십 MB라 공개 저장소가 무거워지고, 링크한 기관이 원본을 보관한다. 게임이나 시안에 실제로 쓸 때 권리 표기와 함께 받는다.
- 권리는 세 가지로 적는다. **쓸 수 있음(출처 표기)**: 상업 게임에 넣어도 되는 조건이 제공처에 적혀 있다. **참고만**: 비상업 조건이나 저작권 때문에 보고 배우는 데만 쓴다. **불명확**: 제공처 문구로 판단하지 못했다. 법률 검토를 거친 판정이 아니다.
- 링크를 열어 확인하지 못한 내용은 **미확인**이라 적는다.
- '가져올 것'은 제안이다. 정한 것은 [decisions.md](../docs/design/decisions.md)에만 적는다.

### 이미 있는 자료와 나눈 범위

- [ref/rail/](rail/README.md)는 OSM에서 뽑은 선로 그래프와 경로 계산이다(ODbL). 선로 모양, 거리, 전철화, 궤간은 거기서 본다. 이 문서는 그림 지도, 옛 지도, 지형, 다른 게임의 화면을 다룬다.
- ref/rail은 폐선, 보존 철도, 공사 중 선로를 뺐다. 사라진 지선이나 전쟁 뒤 뜯긴 선로는 옛 지도로만 보인다.
- [설계 로그](../docs/design/apocalypse_train_game_design_log.md) 11장의 OpenRailwayMap, OpenStreetMap, BlenderGIS와 [PR 12](https://github.com/wndi1130-dot/APP/pull/12)(3D 자료 조사)의 BlenderGIS, A.N.T. Landscape는 여기서 다시 세지 않는다. PR 12의 71개 항목 가운데 지도·지형과 닿는 항목은 이 둘뿐이다.
- 아트 레퍼런스(PR 12, ref/art/)와 애니메이션 레퍼런스는 다른 문서가 맡는다.

## 2. 우리 지도가 할 일

[decisions.md](../docs/design/decisions.md)와 [presentation_ui.md](../docs/design/briefs/presentation_ui.md)에서 뽑았다. 다른 게임을 볼 때 이 목록에 비춰 본다.

| 할 일 | 근거 | 상태 |
|---|---|---|
| 열차에서 끊김 없이 줌 아웃해 철도망 지도로 간다. 카메라가 가는 곳이 곧 메뉴다 | 화면과 연출 | 확정 |
| 다음 구간과 정차를 고른다. 구간 하나에 정차 하나. 직결선(약 312km)이 기본이고, 포즈난 우회는 물자가 많지만 위험과 석탄 소모가 크다 | 세계와 런 | 확정 |
| 정차할 곳의 장소 유형, 위험, 전리품 6종(석탄, 식량, 의약품, 사치품, 상징물, 정보)을 보여 준다 | 필드 | 전리품 키는 확정, 보여 주는 양은 미정 |
| 핸드카 정찰이 다음 역 지도의 일부를 연다. 찾은 지도와 문서는 정보 전리품이다 | 시간 구조, [field_system.md](../docs/design/briefs/field_system.md) | 검토 중 |
| 털린 역, 무너진 다리, 옛 열차 잔해가 남는 지속 세계를 지도에 표시한다 | 세계와 런 | 확정 |
| 선로를 따라오는 무리(밖으로 던진 시신이 섞인다)를 보여 준다 | 좀비 | 확정 |
| 파견대, 분리 열차, 경쟁 열차의 위치. 경쟁 열차는 접촉이 있어야 보인다 | 열차 사회, 검토 중인 제안 | 일부 검토 중 |
| 궤간이 세계의 경계다 | 세계와 런 | 확정 |
| OSM 파생 데이터를 그리면 게임 화면에 출처(© OpenStreetMap contributors, ODbL)를 보여야 한다 | [ref/rail/README.md](rail/README.md) | 의무 |

## 3. 비슷한 게임의 지도 화면

22개 게임을 봤다. 화면 그림은 링크로만 남긴다. [Game UI Database](https://www.gameuidatabase.com/)는 이번 조사 도구로 열리지 않아(robots.txt 차단) 게임별 페이지를 확인하지 못했다. 브라우저로 직접 찾아보면 된다. **[판단]**은 사실이 아니라 우리 평가다. 모바일 출시 여부는 각 항목 첫 줄에 적었다.

### 3.1 열차와 차량의 여정

**Last Train Home (2023)** · PC만
- 화면이 미션, 열차(줌 인), 지도(줌 아웃) 3단이다. 지도는 위성사진을 바탕으로 손으로 만들었고, 처음엔 언덕과 나무가 장난감처럼 작아 보여서 크기를 키웠다. 평균 여정은 약 40시간이다. 단계 사이가 연속 줌인지는 **미확인**.
- 선로변 관심 지점에 서서 분대를 보낸다. 정찰은 전투 없이 글과 선택지로 끝나기도 하고 전투로 이어지기도 한다. 연료는 기관차와 객차 난로가 함께 쓰고, 속도 모드가 연비와 묶인다. 쓰러진 나무를 치울지 들이받을지 같은 선로 장애물 사건이 있다.
- 가져올 것: 가장 가까운 선례다. 실제 지형을 축척 조정해 보여 주기, 속도와 석탄 연비 연동, 글로 끝나는 정찰(자동 수색대 카드의 선례), 구간 중간의 선로 사건.
- 피할 것: 지도 진행과 칸별 인력 배치를 동시에 돌리는 PC 밀도 **[판단]**.
- [개발 일지](https://ashbornegames.com/news/the-worldbuilding-of-last-train-home) · [연료 가이드](https://gamesfuze.com/guides/last-train-home-fuel-guide-location-prevent-running-out-of-fuel/)

**Frostpunk 2 (2024)** · PC, 콘솔
- 도시에서 줌 아웃하면 끊김 없이 Frostland 지도로 넘어가고, 따로 단추도 있다. 지역을 고르면 필요한 팀 수, 위협, 얻을 자원, 원정 시간이 뜬다. 끝난 원정은 지도 표식으로 남고, 채집지는 길로 도시와 잇는다(험한 땅일수록 비싸다). 반대로 도시를 확대하면 시민 이야기(Zoom Stories)가 나온다.
- 베타 뒤 개발사가 Frostland의 명확성과 가독성 개선을 공식 과제로 삼았다.
- 가져올 것: '카메라가 곧 메뉴'의 직계 선례다. 줌 제스처와 늘 보이는 단추를 같이 둔다. 지역 카드 네 칸(팀, 위협, 자원, 시간)을 정차 카드(석탄·물, 위험, 전리품 유형, 시간)로 옮긴다.
- 피할 것: 마우스 환경에서도 가독성이 문제가 됐다. 폰에서는 카드 항목과 아이콘을 더 줄인다.
- [리뷰](https://www.neowin.net/reviews/frostpunk-2-review-a-grim-masterpiece-set-at-the-end-of-the-world/) · [Frostland 가이드](https://selphie1999gaming.com/game-guides/frostpunk-2/how-frostpunk-2-frostland-exploration-works/) · [연기 발표](https://www.thesixthaxis.com/2024/06/27/frostpunk-2-delayed-to-september-after-beta-feedback/)

**Frostpunk (2018)** · PC. 모바일 각색작 Frostpunk: Beyond the Ice(2024, iOS·Android)에도 원정대가 있다
- 정찰대를 만들어 세계 지도의 장소를 고르면 예상 이동 시간이 뜨고, 도착하면 보고서와 선택지(생존자를 데려올지)가 나온다. 아는 장소로 갈 때는 더 빠르다. 전초기지를 두면 정기적으로 자원이 들어온다.
- 가져올 것: '예상 시간 → 보고서와 선택지' 형식은 자동 수색대 카드에 그대로 맞는다. 아는 길의 속도 보너스는 지속 세계와 맞는다.
- [원정 가이드](https://www.gamepressure.com/frostpunk/expeditions/zfa19d) · [모바일판 출시](https://godisageek.com/2024/10/frostpunk-beyond-the-ice-released-on-mobile-devices/)

**Metro Exodus (2019)** · PC, 콘솔
- 화면 미니맵이 없다. 가방에서 종이 지도를 꺼내 보고, 방향은 손목 나침반으로 본다. 지도 아이콘을 일부러 적게 두고 망원경과 높은 곳으로 찾게 한다. 오로라 열차가 계절이 바뀌는 지역들 사이의 허브다.
- 가져올 것: 정차역 지도를 '꺼내 드는 물건'으로 만들고 빈 지도에서 시작해 정찰로 표시가 늘게 한다. 낡은 마감의 기준.
- 피할 것: 1인칭 전제다. 탑뷰 폰에서 매번 꺼내는 연출을 강제하면 느려진다 **[판단]**.
- [Wikipedia](https://en.wikipedia.org/wiki/Metro_Exodus) · [GMTK 분석 영상 자막본](https://amara.org/v/C3BEM)

**Pacific Drive (2024)** · PC, 콘솔
- 차고 작업대 옆 기계(루트 플래너)에서 구역 지도를 보고 교차점을 고른다. 거리, 안정도, 위험(산성, 폭발 등), 조건이 뜨고 조건에는 범례 화면이 따로 있다. 다녀온 곳의 정보가 쌓인다. 폭풍이 지형을 바꿔 온 길로 못 돌아가고, 오래 머물면 폭풍이 덮친다.
- 가져올 것: 기지 안 물건에서 지도를 연다(열차장실 지도 탁자나 무전실에서 줌 아웃이 시작되는 연출). '머물수록 위험'은 우리 무리 수렴과 같은 문법이다.
- 피할 것: 범례가 필요할 만큼 많은 위험 종류. 폰에서는 위험 아이콘 수에 상한을 둔다 **[판단]**.
- [Steam](https://store.steampowered.com/app/1458140/Pacific_Drive/) · [플래너 가이드](https://twinfinite.net/?p=1050075)

**80 Days (2014)** · iOS, Android, PC
- 150개 도시가 있는 지구본에서 증기선, 열차, 비행선을 갈아탄다. 도시를 돌아보거나 사람과 이야기해야 새 노선이 지도에 생긴다. 여정을 고를 때 출발, 소요 시간, 비용이 보인다.
- 가져올 것: '정보 전리품 = 노선 발견'의 모바일 선례다. 역에서 주운 시간표, 전신 기록, 철도 지도가 지선, 우회로, 다리 상태를 노선도에 더한다.
- 피할 것: 75만 단어 규모의 글. 우리는 글을 줄이는 쪽이다.
- [공식](https://www.inklestudios.com/80days/) · [리뷰](https://www.thesixthaxis.com/2015/05/20/80-days-and-the-power-of-exploring-by-word-of-mouth/)

**Overland (2019)** · PC, 콘솔, iOS(Apple Arcade)
- 미국을 동에서 서로 가로지르는 노드형 진행이다. 정차 사이에 다음 행선지를 고르고, 업그레이드가 있는 긴 우회로에 연료를 쓸지 정한다.
- 가져올 것: '보상 있는 우회 vs 연료 비축'은 포즈난 우회와 같은 구조이고 모바일에서도 성립했다.
- 피할 것: PC Gamer 리뷰는 짧은 정차만 이어져 어딘가로 가는 느낌이 없다고 했다. 구간 이동 자체에도 사건과 결정이 필요하다.
- [Wikipedia](https://en.wikipedia.org/wiki/Overland_(video_game)) · [리뷰](https://www.pcgamer.com/au/overland-review)

**The Banner Saga (2014)** · PC, iOS, Android, 콘솔
- 행렬이 옆으로 걷는 이동 화면이 있고, 이동하는 날마다 보급을 쓴다. 쉬면 사기가 오르고 보급이 준다. 세계 지도는 손그림이고 장소를 누르면 이야기를 읽는 열람용이다. 경로 선택에도 쓰이는지는 **미확인**.
- 가져올 것: '달리는 행렬의 옆모습이 곧 홈'이라는 우리 구도의 선례. 노선도의 역을 누르면 그곳의 역사와 폐허 메모를 읽는 층.
- [App Store](https://apps.apple.com/app/id911006986) · [리뷰](https://www.macworld.com/article/667202/the-banner-saga-for-mac-review.html)

**Death Road to Canada (2016)** · PC, iOS, Android, 콘솔
- 실제 지명을 따라 플로리다에서 캐나다로 간다. 길 위에서 병원, 주유소 같은 장소를 고른다. 상세 지도가 없다. 개발 중 글 사건 비중을 줄이고 액션을 70% 안팎으로 늘렸다.
- 가져올 것: 글(자동)과 직접 플레이의 비율을 플레이 테스트로 맞춘 선례. 자동 수색대 카드와 필드 플레이의 비율을 정할 때 기준점.
- 피할 것: 지도가 없어 경로 계획의 재미가 없다. 우리 핵심과 반대다.
- [인터뷰](https://www.nintendolife.com/news/2018/03/feature_road_tripping_with_death_road_to_canadas_rocketcat_games)

**Sunless Skies (2019)** · PC, 콘솔
- 하늘을 나는 기관차를 직접 몬다. 지역은 다니는 만큼 드러나고, 연료와 보급이 줄며, 미지로 갈수록 공포가 쌓인다. 전작에서 되돌아가는 항해가 지루했다는 교훈으로 허브를 여럿 뒀지만, 리뷰는 여전히 느린 이동을 지적했다.
- 가져올 것: 지속 세계라도 되돌아가는 이동은 줄이거나 자동으로 처리한다. '처음 가는 구간은 사기 비용'이라는 생각.
- [개발 일지](https://www.failbettergames.com/sunless-skies-pre-production-talkin-bout-proc-generation) · [리뷰](https://primagames.com/featured/sunless-skies-review-pc)

**HighFleet (2021)** · PC만
- 연료가 이동 제약인 전략 지도다. 레이더 접촉은 바로 식별되지 않고, 두 지점을 표시해 속도로 위협을 가늠하며 무전을 감청한다. 계기판 모양의 지도 화면이다.
- 가져올 것: 정보가 '불완전한 접촉'으로 들어오는 방식(무전 감청으로 무리나 약탈자의 단서). 계기판 마감은 메트로 톤과 맞는다.
- 피할 것: 손으로 계산하고 판독하는 부담은 폰에 과하다 **[판단]**.
- [Steam](https://store.steampowered.com/app/1434950/HighFleet/)

**Euro Truck Simulator 2 (2012)** · PC
- 실제 유럽을 압축했다. 개발사 블로그는 American Truck Simulator의 축척을 1:35에서 1:20으로 바꾸며 이것이 ETS2와 같은 축척이라고 밝혔다. 커뮤니티 위키는 도시를 1:3 정도로 따로 크게 잡는다고 적는다(위키 기록). 이유로는 시간 흐름, 도로 길이(박자), 풍경과 도시를 넣을 공간을 들었다.
- 가져올 것: 실제 노선 압축의 업계 기준점. 312km를 1:20으로 줄이면 약 16km다. 역(도시)은 크게, 구간은 압축하는 이중 축척.
- 피할 것: 운전 시간 자체가 콘텐츠인 구조.
- [개발사 블로그](https://blog.scssoft.com/2016/06/the-rescale.html) · [커뮤니티 위키](https://truck-simulator.fandom.com/wiki/Time_Compression)

### 3.2 분기 지도와 추격

**FTL: Faster Than Light (2012)** · PC, iPad(아이폰판 없음)
- 섹터마다 비컨 그래프가 있다. 반란군 함대가 점프마다 빨간 영역으로 전진하고, 다음 전진 범위를 미리 보여 준다. 점령된 비컨은 사건이 사라지고 매우 위험해진다. 개발진은 작은 화면 때문에 아이폰판을 만들지 못했다고 했다.
- 가져올 것: 추격을 지도 레이어로 보여 주고 '다음 행동 뒤 여기까지 온다'를 예고한다. 우리 무리는 선로를 따라오므로 선로 위의 번짐으로 그리고, 우회를 고르면 늘어나는 전진량을 미리 보여 준다.
- 피할 것: 정보가 빽빽한 노드 지도는 폰까지 오지 못했다. 폰 가로 화면에 올릴 노드와 이름표 수의 상한을 먼저 정한다.
- [위키](https://ftl.fandom.com/wiki/Rebel_Fleet) · [iOS 개발 인터뷰](https://www.pocketgamer.biz/we-dont-really-like-developing-on-ios-admits-ftl-dev-team)

**Slay the Spire (2019)** · PC, 콘솔, iOS, Android
- 막마다 분기 그래프 전체를 한 번에 보여 준다. 층마다 노드 최대 6개, 아이콘 7종(일반, 엘리트, 휴식, 미지, 보물, 상인, 보스). 9층 보물과 보스 앞 휴식은 고정이다.
- 가져올 것: '유형은 아이콘으로 공개, 세부는 숨김'의 표준이다. 고정 리듬은 급수탑과 석탄 보급역 배치에 쓸 수 있다.
- 피할 것: 추상 그래프라 지리감이 없다. 구조만 빌린다.
- [지도 생성 위키](https://slaythespire.wiki.gg/wiki/Map_Generation) · [장소 위키](https://slaythespire.wiki.gg/wiki/Map_Locations)

**Darkest Dungeon II (2023)** · PC, 콘솔
- 역마차가 분기 도로를 달린다. 도로마다 종류(전투, 장갑 피해, 바퀴 피해, 불안 증가, 안전)가 있고 정찰 전에는 숨겨진다. 정찰은 확률이고, 감시탑 노드에 가면 그 지역의 남은 장소가 모두 드러난다.
- 가져올 것: 역뿐 아니라 구간에도 위험 종류를 둔다(끊긴 다리, 눈더미, 매복을 정찰 전엔 '?'로). 급수탑이나 첨탑처럼 높은 곳을 잡으면 다음 구간이 드러나는 감시탑 개념.
- [도로 위키](https://darkestdungeon.wiki.gg/wiki/Roads)

### 3.3 정차지 고르기와 자동 파견

**This War of Mine (2014)** · PC, iOS, Android, 콘솔
- 밤마다 도시의 장소 하나를 골라 사람을 보낸다. 장소 설명에 얻을 것, 사는 사람, 필요한 도구(삽, 쇠지렛대)가 있다. 시간이 지나면 장소가 바뀐다(병원이 폭격당하는 식).
- 가져올 것: 정차 카드의 '필요한 도구' 칸. 출발 전 준비가 결정이 된다. 같은 역의 상태 변화 표시는 지속 세계와 맞는다.
- 피할 것: 같은 집에서 같은 장소를 반복해 가는 구조라 전진형인 우리와 다르다.
- [App Store](https://apps.apple.com/us/app/this-war-of-mine/id982175678) · [리뷰](https://pcgamer.com/this-war-of-mine-review)

**Fallout Shelter (2015)** · iOS, Android, PC
- 황무지 탐험은 자동으로 진행되고 기록으로 본다. 돌아오는 시간은 나가 있던 시간의 절반이다. 퀘스트는 팀을 꾸려 지도 위 장소로 보내고 방 단위로 직접 진행한다.
- 가져올 것: 자동 파견과 직접 진행을 나누는 모바일 선례. '귀환은 절반'처럼 단순하고 예측되는 시간 규칙.
- 피할 것: 유료 가속 아이템으로 시간 압박을 푸는 구조는 생존 긴장과 부딪친다 **[판단]**.
- [퀘스트 발표](https://bethesda.net/en-AU/news/fallout-shelter-quests-and-pc-version-now-available)

**The Alters (2025)** · PC, 콘솔
- 바퀴 달린 기지로 이동한다. 막마다 기한 안에 다음 지점까지 가야 하고, 늦으면 일출에 탄다. 스캐너가 매장지를 색으로 보여 준다.
- 가져올 것: '정차는 기한 있는 막, 이동은 막 사이 전환'. 우리 정차 20분과 무리 수렴의 리듬과 같다.
- [Wikipedia](https://en.wikipedia.org/wiki/The_Alters)

### 3.4 필드 지도와 정보 얻기

**Project Zomboid** · PC
- 마을 지도가 주유소, 차 글러브박스, 좀비 시체에서 나온다. 읽으면 그 지역이 지도에 열린다. 좀비가 지닌 주석 지도에는 생존자 거점이 표시돼 있다. 펜으로 기호를 그리고 지운다. 월드맵과 미니맵은 탐험한 곳만 보인다.
- 가져올 것: 정보 전리품의 정석. 지도 아이템은 다음 역 구획을 열고, 주석 지도는 특정 건물의 보급을 표시한다. 플레이어 기호를 노선도와 필드 지도 양쪽에 허용한다.
- 피할 것: 자유 필기는 마우스 전제다. 폰에서는 도장 기호 몇 개로 줄인다 **[판단]**.
- [PZwiki](https://pzwiki.net/wiki/Map)(오래된 문서 표시) · [B42 기능 글](https://projectzomboid.com/blog/upcoming-features-b42/) · 우리 쪽 조사: [좀보이드 모드 노트 3장](../docs/research/research_notes/좀보이드%20모드%20설계%20참고/vehicles_maps_winter.md)

**The Long Dark (2017)** · PC, 콘솔
- 숯으로 측량하면 내 주변 정해진 반경이 손그림 지도에 그려진다. 맑은 낮에만 되고, 절벽이 범위를 막으며, 측량에 시간이 든다. 내 위치는 찍히지 않는다.
- 가져올 것: 정찰 규칙을 '소모품 + 조건(날씨, 시간) + 정해진 반경'으로 예측할 수 있게 만든다. 눈보라 중 정찰 불가. 정찰에 드는 시간이 곧 무리가 다가오는 비용.
- [위키](https://thelongdark.fandom.com/wiki/Map)

**State of Decay 2 (2018)** · Xbox, PC
- 관측 지점에 올라 살피면 지도의 물음표가 건물로 바뀌고, 건물마다 상자 수와 있을 법한 자원 아이콘이 뜬다.
- 가져올 것: 핸드카 정찰이 열어 줄 정보의 해상도 기준. 건물별 '있을 법한 자원'과 상자 수까지만 보여 주고 내용물은 정하지 않는다.
- [가이드](https://www.shacknews.com/article/105001/where-to-find-food-in-state-of-decay-2)

### 3.5 망을 읽기 쉽게

**Mini Metro (2015)** · PC, iOS, Android, 콘솔
- 실제 도시를 바탕으로 한 해리 벡식 지하철 노선도다. 강은 수가 정해진 터널과 다리로만 건넌다. 색맹 모드가 있다. GDC 2017 강연 주제가 '빼서 만드는 디자인'이었다.
- 가져올 것: 가장 멀리 줌 아웃했을 때 지리 대신 노선도(직선과 45도, 역은 기호)로 바꾸는 방식은 폰에서 검증됐다. 다리를 노선도 문법으로 다루면 다리 파괴와 바로 이어진다.
- 피할 것: 밝은 미니멀 톤. 구조만 빌린다.
- [GDC Vault](https://gdcvault.com/play/1024250/-Mini-Metro-When-Less)

조사하고 뺀 것: Honkai: Star Rail(열차 허브에서 목적지 지도로 가는 흐름을 확인할 출처가 없다), The Oregon Trail 2021(지도 화면을 다룬 출처가 없다), IXION(The Alters와 겹친다). Railway Empire 2와 Ticket to Ride: Europe은 위험, 정보, 압박 문제와 거리가 멀어 보지 않았다.

### 3.6 반복되는 패턴

1. **줌 단계가 곧 화면 계층이다.** Last Train Home은 미션, 열차, 지도 3단이고, Frostpunk 2는 도시와 Frostland 사이를 줌으로 오간다. 둘 다 단추로도 들어간다. 핀치만으로는 찾기 어렵다.
2. **목적지 카드는 서너 값으로 모인다.** Frostpunk 2는 팀, 위협, 자원, 시간. Pacific Drive는 시간, 안정도, 위험, 조건. 80 Days는 출발, 소요, 비용. This War of Mine은 전리품, 사는 사람, 도구. 우리 정차 카드도 석탄·물, 위험, 전리품 유형, 시간(+필요한 도구)을 넘기면 과하다.
3. **압박은 지도 위 레이어로 보이고 다음 행동의 결과를 예고한다.** FTL, Pacific Drive, The Alters.
4. **유형은 보여 주고 세부는 얻게 한다.** Slay the Spire, Darkest Dungeon II의 감시탑, State of Decay 2, The Long Dark, Project Zomboid와 80 Days의 지도·대화로 열리는 노선.
5. **자동과 직접 플레이를 나눈다.** Last Train Home의 글 정찰, Fallout Shelter, Death Road to Canada의 비율 조정.

## 4. 첫 구간이 지나는 곳

ref/rail의 기본 경로(`wolsztyn zbaszynek cottbus leipzig`, 311.9km)를 따라 다리와 고도를 뽑았다. 거리는 볼슈틴에서 잰 km다. 지명의 한글 표기는 ref/rail에 저장된 것을 먼저 따르고, 없는 것은 원어 발음대로 적었다.

### 4.1 노선 띠

다리는 ref/rail 그래프에서 40m가 넘는 철도 교량을 뽑았다. 건너는 강은 다리 위치와 지형으로 판단했고, OSM 원본을 열어 강 이름 태그까지 대조하지는 못했다(**미확인**). 괄호의 '확실'·'유력'은 그 판단의 정도다.

| km | 곳 | 지도에서 볼 것 |
|---:|---|---|
| 0 | 볼슈틴(Wolsztyn) | 출발지인 증기 차고. 1907년 급수탑, 1908년 8칸 원형 기관고가 있다([대폴란드주 자료](https://www.umww.pl/generuj-pdf---47885)). 두 호수 사이의 작은 도시. 선로 359는 비전철 단선 지선이다 |
| 21.5 | 즈봉신 오브라강 다리(63m, 유력) | [OSM way 318584357](https://www.openstreetmap.org/way/318584357) |
| 22 | 즈봉신(Zbąszyń) | 1920~1939년 폴란드 쪽 국경역. 1938년 추방 사건의 장소다(4.3) |
| 28 | 즈봉시네크(Zbąszynek) | 1925년 독일 쪽 국경역으로 연 분기역이고, 1923~1930년 철도원 정원도시로 지었다(Neubentschen, Neu Bentschen). 선로 3(바르샤바–베를린)과 만난다 |
| 54 | 술레후프(Sulechów) | 옛 지명 Züllichau |
| 64 | 치가치체 오데르강 다리(455m, 확실) | 첫 구간에서 가장 긴 다리. [OSM way 230950458](https://www.openstreetmap.org/way/230950458) |
| 69 | 체르비엔스크(Czerwieńsk) | 지엘로나구라 쪽 선로가 갈라진다 |
| 96 | 크로스노오드잔스키에 보브르강 다리(271m, 유력) | 첫 구간 최저점(38m) 근처. [OSM way 801395051](https://www.openstreetmap.org/way/801395051) |
| 123 | 구빈·구벤 나이세강 다리(126m, 확실) | 지금의 국경이자 1945년 도시를 둘로 가른 오데르–나이세선. [OSM way 165716103](https://www.openstreetmap.org/way/165716103) |
| 125 | 구벤(Guben) | 독일 선로 6345(할레–구벤)가 시작된다 |
| 135~150 | 파이츠(Peitz) 부근 | 북쪽에 옌슈발데 갈탄 노천광과 발전소. 채굴은 2023년에 끝났고 호수 셋이 계획돼 있다(5.4) |
| 162 | 코트부스 슈프레강 다리(75m, 유력) | [OSM way 116512069](https://www.openstreetmap.org/way/116512069) |
| 163 | 코트부스 중앙역 | 저지 소르브어를 함께 쓰는 지역. OSM 역 이름에 'Chóśebuz głowne dwórnišćo'가 함께 적혀 있다. ref/rail의 저장 표기는 '콧부스 중앙역'이다 |
| 186 | 칼라우(Calau) | 남쪽으로 첫 구간에서 유일한 언덕 지대가 시작된다 |
| 200~215 | 핀스터발데(Finsterwalde) 부근 | 남쪽 리히터펠트의 옛 노천광 호수에 F60 컨베이어 다리(길이 502m, 높이 80m)가 남아 있다([F60](https://www.f60.de/)) |
| 221 | 도베를루크키르히하인 | |
| 236 | 슈바르체 엘스터강 다리(62m, 유력. 클라이네 엘스터일 수도 있다) | [OSM way 33775391](https://www.openstreetmap.org/way/33775391) |
| 241 | 팔켄베르크(엘스터) | 2층 교차역(Turmbahnhof). 우리 선로는 위층이고 아래층으로 다른 두 선로가 지난다. 1939년 분기기 324조의 큰 조차장이 있었다. 242km의 45m 교량은 강이 아니라 이 아래층 선로를 넘는 다리다 |
| 259 | 토르가우 엘베강 다리(356m, 확실) | [OSM way 7801306](https://www.openstreetmap.org/way/7801306) |
| 260 | 토르가우(Torgau) | 1945년 4월 미군과 소련군이 엘베에서 만난 곳(4.3) |
| 287 | 아일렌부르크 물데강 다리(284m, 확실) | [OSM way 89272457](https://www.openstreetmap.org/way/89272457). 여기서 선로 6360(아일렌부르크 철도)으로 갈아탄다 |
| 302 | 타우하(Taucha) | |
| 312 | 라이프치히 중앙역 | 1909~1915년에 지은 막다른 종착역. 개업 때 승강장 26면, 작센 쪽과 프로이센 쪽으로 나뉜 구조였고, 1944년 7월 공습 피해를 1965년까지 복구했다([Wikipedia](https://en.wikipedia.org/wiki/Leipzig_Hauptbahnhof)) |

역의 출처: 즈봉시네크는 [Wikipedia](https://en.wikipedia.org/wiki/Zb%C4%85szynek_railway_station)와 [Urbaniak 2017](https://www.deutscherkunstverlag.de/article/10.1515/ATC-2017-0007)(유료 논문), 팔켄베르크는 [Wikipedia](https://en.wikipedia.org/wiki/Falkenberg_(Elster)_station). 6345선 복선 한쪽은 1945년 뒤 소련 배상으로 뜯겼다가 1970년까지 복구됐다는 Wikipedia 서술이 있다(원문 재확인 **미확인**).

### 4.2 고도

SRTM 30m 표고를 선로를 따라 6km마다 읽었다([OpenTopoData](https://www.opentopodata.org/) 공개 API, 2026-10-07 조회). SRTM은 퍼블릭 도메인이다. 나무와 건물 높이가 일부 섞인 표면 값이고, 단순화한 선로 좌표(오차 25m 안팎)에서 읽었으므로 몇 m에서 십여 m의 오차가 있다. 성토, 절토, 국지 경사는 잡히지 않는다.

| 구간 | km | 높이 |
|---|---:|---:|
| 볼슈틴 → 즈봉시네크 | 0–30 | 58–75m |
| 즈봉시네크 → 오데르 다리 | 30–66 | 48–91m |
| 오데르 → 구벤 | 66–126 | 38–65m (96km 보브르 계곡이 첫 구간 최저) |
| 구벤 → 코트부스 | 126–162 | 45–93m |
| 코트부스 → 칼라우 | 162–186 | 66–86m |
| 칼라우 → 도베를루크키르히하인 | 186–222 | 75–134m (198km가 첫 구간 최고) |
| 도베를루크키르히하인 → 토르가우 | 222–264 | 81–107m |
| 토르가우 → 라이프치히 | 264–312 | 86–132m |

6km 사이 가장 크게 오르는 곳은 186→192km(칼라우 남쪽)로 46m, 평균 0.8% 정도다. 6km 평균으로는 1%를 넘는 곳이 없다. 칼라우 남쪽은 브란덴부르크에서 드문 언덕 지대인 니더라우지츠 등성이(Niederlausitzer Landrücken) 자연공원 언저리다. 근처 칼라우어 슈바이츠의 케셀베르크가 161m다([Reiseland Brandenburg](https://www.reiseland-brandenburg.de/erlebnisberichte/spreewald/durch-die-calauer-schweiz/)).

### 4.3 지도에서 읽은 것

1. **장애물은 산이 아니라 강이다.** 312km에 큰 강 다리가 7곳이다(오브라, 오데르, 보브르, 나이세, 슈프레, 슈바르체 엘스터, 엘베, 물데 가운데 확인 정도는 4.1). 확정된 '무너진 다리'가 첫 구간에서 가장 자연스럽게 생기는 자리이고, 오데르와 나이세 다리는 국경이기도 하다. 다리를 노선도 문법으로 다루는 Mini Metro(3.5)와 바로 이어진다.
2. **거의 평지다.** 6km 평균 경사가 1%를 넘지 않는다(4.2). 검토 중인 '경사(열차를 나눠 오르기)'는 실제 지리를 지키면 첫 구간에서 거의 일어나지 않는다. 첫 구간에서 가르치려면 언덕을 지어내야 하고, 사실을 지키려면 산지 구간까지 미뤄야 한다.
3. **갈탄 지대를 두 번 지난다.** 코트부스 주변 라우지츠 탄전과 라이프치히 남쪽 중부 독일 탄전이다. '석탄은 캐서 바로 땐다'와 맞지만, 갈탄은 질이 낮다. 작센주 농업청 표는 생갈탄 8.92MJ/kg, 갈탄 연탄 19.39MJ/kg, 석탄(Steinkohle) 30~33MJ/kg이다([LfULG 2006](https://www.landwirtschaft.sachsen.de/download/Heizwerte.pdf)). 같은 무게로 생갈탄은 석탄의 3분의 1이 안 된다. 석탄을 한 자원으로 합친 지금 규칙에서 '첫 구간의 석탄은 질이 나쁘다'를 어떻게 보일지는 열린 문제다.
4. **옛 지도의 지명은 독일어다.** 1945년 이전 독일 지도에는 폴란드 쪽 도시가 Wollstein(볼슈틴), Bentschen(즈봉신), Neu Bentschen(즈봉시네크), Züllichau(술레후프), Crossen(크로스노)으로 적혀 있다. 지금의 폴란드 땅을 독일어 지명 지도로 보여 주면 폴란드 플레이어에게 수정주의로 읽힐 수 있다. 옛 지도는 질감, 배선, 마을 배치의 참고로 쓰고 게임 안 지명은 지금 이름으로 쓰는 편이 안전하다. 코트부스 일대의 독일어·소르브어 두 언어 표기는 존중해서 살린다.
5. **즈봉신(22km)은 1938년 추방 사건의 장소다.** 1938년 10월 독일이 폴란드 국적 유대인 약 17,000명을 국경으로 내쫓았고, 그 가운데 약 8,000명이 즈봉신의 옛 군 마구간, 학교, 방앗간 등에 묶였다([유대역사연구소 JHI](https://www.jhi.pl/en/exhibitions/polenaktion-october1938-the-story-of-the-expellees-from-germany,80)). '강제 이송 열차를 흉내 내지 않는다'는 결정에 비추어, 이 역을 추방, 분리, 희생양 사건의 무대로 쓰지 않는다.
6. **다른 무거운 장소.** 토르가우는 엘베의 날(1945년 4월 25일)의 장소이면서 같은 곳에 국방군 형벌 체계의 거점(포르트 치나), 1945~1948년 소련 특별수용소, 동독 형벌 시설이 겹친다([작센 기념재단](https://www.stsg.de/cms/node/896)). 코트부스 교도소는 나치와 동독 시기 모두 정치범을 가뒀다([코트부스 인권센터](https://menschenrechtszentrum-cottbus.de)). 라이프치히 북동쪽 아브트나운도르프에서는 1945년 4월 18일 부헨발트 하위 수용소 수감자 학살이 있었다([부헨발트 기념관](https://liberation.buchenwald.de/en/otd1945/the-abtnaundorf-massacre)). 라우지츠의 소르브 마을들(호르노 등)은 노천광 때문에 철거됐고 지금도 지역 갈등이다. 장소로 쓸 때는 승리나 폐허 구경거리로만 다루지 않는다.

## 5. 실제 지도와 옛 지도

이 절의 '권리'는 각 기관 안내문을 2026-10-07에 읽고 적었다. 장마다 권리가 다른 소장처가 있어서, 실제로 그림을 쓰기 전에 그 장의 상세 페이지를 다시 확인한다.

### 5.1 옛 지형도

| 자료 | 링크 | 권리 | 가져올 것 |
|---|---|---|---|
| 미 육군 지도국 AMS M641 중부 유럽 1:100,000 (1943) | [텍사스대 PCL 색인](https://maps.lib.utexas.edu/maps/ams/central_europe/) | 쓸 수 있음. PCL 안내는 대부분 퍼블릭 도메인이라 내려받아 마음대로 써도 된다고 하고, "University of Texas Libraries" 표기를 요청한다([FAQ](https://maps.lib.utexas.edu/faq.html)) | 노선 전체를 같은 축척, 같은 기호로 덮는 가장 좋은 바탕이다. 마을, 숲, 늪, 둑, 역 배선이 1940년대 그대로라 '사람이 떠난 세계'의 마을 배치 참고로 쓴다. 지명은 독일어라 §4.3의 4번을 따른다 |
| 같은 시리즈의 노선 관련 장 | 파일 이름 앞부분 `txu-pclmaps-oclc-6624264-` 뒤에 `leipzig-q7`(라이프치히~토르가우~팔켄베르크), `finsterwalde-q8`, `lubben-p8`(코트부스 쪽), `guben-p9`, `grunberg-p10`(체르비엔스크~볼슈틴), `meseritz-n10`(즈봉신) | 위와 같음 | 조사 워커가 UT GeoData 목록에서 찾은 이름이다. 색인 페이지가 이 컨테이너에서 열리지 않아 파일을 직접 열어 보지는 못했다(미확인) |
| AMS M508 / GSGS 4346 중부 유럽 1:250,000 | [텍사스대 PCL](https://maps.lib.utexas.edu/maps/ams/central_europe_250k/) | 쓸 수 있음. UT Collections에 퍼블릭 도메인 마크가 붙어 있다 | N-52 드레스덴, O-52 괴를리츠, O-53 프랑크푸르트(오데르) 석 장이 노선을 덮는다. UT GeoData에 좌표가 붙은 판(GeoJPEG)이 있어 겹쳐 보기 쉽다. 중간 확대 단계의 '지역 지도' 밀도를 정할 때 본다 |
| 브란덴부르크 측량청(LGB) 옛 지도 | [geobasis-bb.de 역사 지도](https://geobasis-bb.de/lgb/de/geodaten/historische-karten/) | 쓸 수 있음. dl-de/by-2-0, 표기 "© GeoBasis-DE/LGB, dl-de/by-2-0". 1:25,000 측량도(Messtischblatt)는 웹 지도 서비스로 열리고, 제국 1:100,000 원본 파일은 장당 4~5유로로 판다 | 코트부스, 구벤, 팔켄베르크 구간의 1:25,000 측량도. 역 하나를 정거장 장면으로 만들 때 건물 배치와 선로 배선을 읽는다 |
| 작센 측량청(GeoSN) 옛 지도 WMS | `geodienste.sachsen.de/wms_geosn_hist/guest` | dl-de/by-2-0로 보이지만 서비스 안내문은 확인하지 못했다(미확인) | 토르가우~라이프치히 구간의 옛 측량도. 엘베 다리와 라이프치히 북동쪽 마을 배치 |
| 작센 주립도서관(SLUB) / 도이체 포토테크 지도 | [SLUB 지도 모음](https://www.slub-dresden.de/en/explore/maps) | 장마다 다르다. 퍼블릭 도메인 마크도 있고 CC BY-SA도 있다 | 작센 쪽 옛 지도와 도시 계획도. 쓰기 전에 장마다 권리 칸을 본다 |

참고만 하거나 확인하지 못한 곳: 독일국립도서관(DNB) '오픈 액세스' 지도는 재사용 조건이 불명확하다. BYU 독일 지도 모음, 폴란드 mapywig, AMZP, Polona는 이 컨테이너에서 열리지 않아 미확인이다. 헝가리 Hungaricana는 보기는 무료지만 재사용은 허락이 필요하다. 프린스턴 소장 지도는 비영리 조건이다.

### 5.2 옛 철도 지도와 역 배선도

| 자료 | 링크 | 권리 | 가져올 것 |
|---|---|---|---|
| OpenHistoricalMap | [저작권 안내](https://www.openhistoricalmap.org/copyright) | 쓸 수 있음. CC0 | 지금은 없어진 선로를 시기별로 그린 지도다. '사라진 노선'을 숨은 지름길이나 폐선 탐색 장소로 쓰는 근거가 된다. 우리 노선 주변에 얼마나 그려져 있는지는 미확인이다 |
| 「폴란드 국유 철도」 지도 (Koleje żelazne państwa polskiego) | [루블린 디지털 도서관](https://bibliotekacyfrowa.pl/en/dlibra/publication/34873/edition/41651) | 쓸 수 있음. 퍼블릭 도메인 마크 | 전간기 폴란드 철도망. 볼슈틴~즈봉신 쪽 지선망이 지금보다 촘촘했다는 점을 확인하는 데 쓴다 |
| 1938년 PKP 철도 지도 | [Residencia 아카이브](https://atom.residencia.csic.es/) | 불명확 | 위 지도와 비교용. 권리를 확인하기 전에는 쓰지 않는다 |
| 라이프치히 철도 지도 1935, 1940 | [museum-digital 61990](https://sachsen.museum-digital.de/object/61990), [62476](https://sachsen.museum-digital.de/object/62476) | 참고만. CC BY-NC-SA라 상업 게임에 못 쓴다 | 라이프치히 철도 결절점(도착지)의 선로 묶음 구조. 도착 장면 설계 때 읽기만 한다 |
| 라이프치히 중앙역 배치도(1913) | [작센안할트 주립문서고](https://recherche.lha.sachsen-anhalt.de/Query/detail.aspx?ID=1469936) | 불명확. 디지털 사본이 온라인에 없다 | 중앙역 승강장과 기관고 배치. 실물 열람이 필요해 당장은 쓸 수 없다 |
| 프린스턴 소장 1935년 장거리 시각표(Fernkursbuch) | 프린스턴 대학 도서관 | 참고만. 저작권 있음 | 당시 열차 운행 간격. 읽기만 한다 |
| 볼슈틴 증기 기관고 자료 | [대폴란드주 PDF](https://www.umww.pl/generuj-pdf---47885) | 사실만 인용 | 출발지가 지금도 증기 기관차가 정기 운행하는 기관고라는 점. 출발 장면의 기관고, 급수탑, 전차대 배치 근거다 |

### 5.3 지금의 공개 지리 데이터

| 자료 | 링크 | 권리 | 가져올 것 |
|---|---|---|---|
| Copernicus DEM GLO-30 | [Copernicus Data Space](https://dataspace.copernicus.eu/) | 쓸 수 있음. 상업 이용 포함 무료. 고정 문구 "© DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved"를 붙이고, 원본 파일을 그대로 다시 배포하지 않는다 | §4.2보다 촘촘한 고도 단면, 강 골짜기 모양. 지형 높낮이를 지도 음영으로 만들 때의 원본 |
| SRTM GL1 v003 | [NASA LP DAAC](https://lpdaac.usgs.gov/products/srtmgl1v003/) | 쓸 수 있음. 재사용, 판매, 재배포에 제한이 없다 | §4.2의 출처. Copernicus보다 거칠지만 권리가 가장 단순하다 |
| Natural Earth | [이용 조건](https://www.naturalearthdata.com/about/terms-of-use/) | 쓸 수 있음. 퍼블릭 도메인 | 가장 바깥 확대 단계의 유럽 윤곽, 큰 강, 국경. 휴대폰 화면 최상위 지도에 알맞은 거친 선이다 |
| CORINE 토지 피복 2018 | [Copernicus Land](https://land.copernicus.eu/en/products/corine-land-cover/clc2018) | 쓸 수 있음. 출처 표기 | 숲, 늪, 경작지, 노천광, 도시의 넓이. 구간마다 '어떤 땅을 지나는가'를 정하고 파밍 장소 종류를 배분하는 근거 |
| ESA WorldCover | [데이터 받기](https://esa-worldcover.org/en/data-access) | 쓸 수 있음. CC BY 4.0 | CORINE보다 촘촘한 10m 피복. 정거장 주변 작은 지도를 만들 때 |
| BKG TopPlusOpen, DGM200 | [BKG](https://gdz.bkg.bund.de/index.php/default/wms-topplusopen-wms-topplus-open.html) | 쓸 수 있음. dl-de/by-2-0 | 독일 구간의 깔끔한 현대 지형도. 우리 지도 기호를 정할 때 비교용 |
| 브란덴부르크 측량청 오픈 데이터 | [data.geobasis-bb.de](https://data.geobasis-bb.de/) | 쓸 수 있음. dl-de/by-2-0 | 1m 고도(DGM1), 20cm 항공사진(DOP20), 2009~2024 항공사진 연속판. 연속판으로 얜슈발데 노천광과 F60 일대가 어떻게 바뀌었는지 볼 수 있다 |
| 작센 측량청 오픈 데이터 | [geodaten.sachsen.de](https://www.geodaten.sachsen.de/) | 쓸 수 있음. dl-de/by-2-0, 표기 "Quelle: GeoSN, dl-de/by-2-0" | 토르가우~라이프치히의 고도, 항공사진. 엘베 다리 장면 |
| 폴란드 측지청(GUGiK) geoportal | [geoportal.gov.pl](https://www.geoportal.gov.pl/) | 쓸 수 있음. 정사영상, 고도, BDOT10k는 무료이며 어떤 목적에도 쓸 수 있다고 안내한다. 표기 문구는 미확인. 옛 지형도는 유료다 | 폴란드 구간(볼슈틴~오데르)의 항공사진과 지형 |
| OpenTopoMap | [GitHub](https://github.com/der-stefan/OpenTopoMap) | 참고만. 지도 그림은 CC BY-SA라 게임 자산에 섞으면 같은 조건 공개 의무가 생길 수 있다. Garmin판은 비영리 | 등고선과 음영을 어떻게 섞으면 읽기 좋은지 보는 견본 |

### 5.4 탄광 지대 지도

| 자료 | 링크 | 권리 | 가져올 것 |
|---|---|---|---|
| 브란덴부르크 광업청(LBGR) INSPIRE 지도 서비스 | [옛 광산 WMS](https://inspire.brandenburg.de/services/am_bgalt_wms?), [지질 WMS](https://inspire.brandenburg.de/services/am_ugk300_wms) | 쓸 수 있음. dl-de/by-2-0 | 옛 갱도와 노천광 경계. 갈탄을 캐는 정거장을 어디에 둘지 고르는 근거 |
| 얜슈발데 광산 폐쇄 계획 | [LBGR PDF](https://lbgr.brandenburg.de/sixcms/media.php/9/ABP_Jw.pdf) | 불명확. 사실만 인용 | 2023년 채굴 종료, 남는 호수(타우벤도르프, 얜슈발데, 하이너스브뤼크). 노선 바로 옆이라 '물이 차오르는 노천광' 장면 근거 |
| LMBV 라우지츠 호수 지대 개관도 | [PDF](https://www.lmbv.de/wp-content/uploads/2021/04/Uebersichtskarte_Lausitzer_Seenland_2019.pdf) | 허락 필요. 보기만 한다 | 옛 노천광이 호수로 바뀐 전체 그림 |
| LEAG 광산 지도 | LEAG 누리집 | 쓸 수 없음 | 없음. 사실 확인만 |
| KuLaDig 문화경관 | [호르노](https://www.kuladig.de/Objektansicht/BKM-32003078), [사라진 마을 기록관](https://www.kuladig.de/Objektansicht/BKM-32000956), [베르크하이더 호수](https://www.kuladig.de/Objektansicht/BKM-32002424) | 쓸 수 있음. dl-de/by-2-0 | 노천광으로 철거된 마을의 위치와 사연. §4.3의 6번처럼 조심해서 다룬다 |
| F60 컨베이어 다리 | [f60.de](https://www.f60.de/) | 사실만 인용 | 길이 502m, 폭 204m, 높이 80m, 무게 11,000t. 노선에서 조금 떨어진 거대 구조물이라 지도의 '멀리 보이는 표지물' 후보 |
| 나투라 2000 보호구역 | [EEA](https://www.eea.europa.eu/en/datahub) | 쓸 수 있음. CC BY 4.0 | 늪과 숲 보호구역. 사람 손이 덜 탄 구역, 짐승이 많은 구역을 정하는 근거 |

## 6. 권리 한눈에 보기

| 묶음 | 예 | 게임에서 할 일 |
|---|---|---|
| 퍼블릭 도메인, CC0 | AMS 미군 지도, Natural Earth, OpenHistoricalMap, 폴란드 국유 철도 지도 | 그대로 써도 된다. 출처는 크레딧에 적는다 |
| 출처만 붙이면 되는 공개 데이터 | dl-de/by-2-0(LGB, GeoSN, BKG, LBGR, KuLaDig), CC BY 4.0(WorldCover, 나투라 2000), CORINE, GUGiK | 크레딧에 기관명과 라이선스를 적는다. dl-de/by-2-0은 고쳤으면 "Daten geändert"를 함께 적는다 |
| 고정 문구가 있는 데이터 | Copernicus DEM | 정해진 문구를 그대로 붙이고 원본 파일은 배포하지 않는다 |
| ODbL | ref/rail의 OSM 선로 | 게임 화면이나 크레딧에 "© OpenStreetMap contributors"를 보이게 둔다. 가공한 데이터베이스를 공개해야 하는지는 출시 전에 따로 확인한다 |
| 같은 조건 공개(SA) | OpenTopoMap 그림, 위키백과 글, SLUB 일부 | 게임 자산에 섞지 않는다. 섞으면 그 자산을 같은 조건으로 풀어야 할 수 있다 |
| 비영리(NC) | David Rumsey, museum-digital, 프린스턴, OpenTopoMap Garmin판 | 읽기만 한다. 상업 게임에 못 쓴다 |
| 보기만 무료 | Hungaricana, LMBV, LEAG, DNB 일부 | 읽기만 한다. 쓰려면 허락을 받는다 |
| 유료 | LGB 제국 1:100,000 원본, GUGiK 옛 지형도 | 꼭 필요한 장만 사서 쓴다 |

함정 몇 가지를 따로 적는다. 첫째, 같은 소장처 안에서도 장마다 권리가 다르다(SLUB). 둘째, 미국에서 퍼블릭 도메인이라도 1931년 이후 외국 저작물은 미국 법(URAA)으로 다시 보호되는 경우가 있어서, 독일 지도를 미국 기관이 올렸다고 안심하면 안 된다. 미군이 만든 AMS 지도는 미국 정부 저작물이라 이 문제가 없다. 셋째, EU에서는 퍼블릭 도메인 그림을 그대로 찍은 사본에 새 권리가 생기지 않는다(DSM 지침 14조, 독일 저작권법 68조). 다만 기관이 붙인 이용 약관은 따로 있을 수 있다.

## 7. 약점과 열린 질문

1. **실제 지리를 따르면 휴대폰에서 읽기 어렵다.** 312km 노선을 한 화면에 넣으면 강, 역, 다리가 겹친다. Last Train Home처럼 지형을 줄여 그린 중간 확대와, Mini Metro처럼 선과 점만 남긴 최상위 확대를 함께 두는 안이 있다. 확대할 때 모양이 바뀌면 플레이어가 익힌 공간 감각이 깨질 수 있어서 시제품으로 확인해야 한다.
2. **도착 전에 얼마나 보여 줄지 정하지 않았다.** 정거장의 종류만 미리 보여 주고 자세한 내용은 정찰로 알게 하는 안을 기본으로 둔다. 실제 지명을 쓰면 플레이어가 지도를 검색해 미리 짐작할 수 있다는 점은 감수하거나 가공 지명과 섞어야 한다.
3. **되돌아가기를 허용할지 정해야 한다.** 무리가 뒤에서 쫓아오면 되돌아갈 이유가 거의 없다. 되돌아가기를 막으면 지도는 한 방향 길이 되고, 허용하면 지나온 정거장의 상태를 계속 저장해야 한다.
4. **정거장만 있고 이동이 비면 여정 느낌이 사라진다.** Overland가 받은 비판이다. 구간 중간 사건(다리 점검, 선로 위 장애물, 눈보라)을 넣어 이동 자체에 선택을 둔다.
5. **압박이 두 겹이다.** 필드의 좀비 무리와 지도 위 추격자를 둘 다 두면 플레이어가 무엇을 피해야 하는지 흐려질 수 있다. 하나는 시간, 하나는 공간처럼 역할을 나눌지 정해야 한다.
6. **첫 구간은 평지라 경사 규칙을 보여 줄 수 없다.** §4.2대로 가장 가파른 곳이 약 0.8%다. 경사가 연료와 속도에 영향을 주는 규칙은 더 남쪽이나 산지 구간에서 처음 소개한다.
7. **첫 구간은 거의 한 줄이다.** 갈림길이 적어서 지도에서 고를 것이 적다. 지선, 폐선(OpenHistoricalMap), 정거장 선택으로 고를 거리를 만들지, 첫 구간을 튜토리얼처럼 짧게 둘지 정해야 한다.
8. **지도 화풍을 정하지 않았다.** 종이 지도처럼 게임 세계 안의 물건으로 보일지, 월드 화면에서 끊김 없이 줌 아웃되는 지도로 할지 열려 있다. PR 12의 월드 방향(좀보이드 계열 그래픽)과 맞춰 아트 스레드와 함께 정한다.
9. **이 문서의 한계.** 게임 지도 화면은 공식 페이지와 리뷰 글로 확인했고 직접 플레이한 것은 아니다. §5의 지도 파일은 이 컨테이너에서 내려받을 수 없어서 직접 열어 본 것이 적다. 미확인 표시가 있는 항목은 쓰기 전에 다시 본다.

## 8. 다음에 맡길 수 있는 일

1. **정밀 고도 단면.** Copernicus DEM이나 SRTM으로 노선을 1km 간격으로 다시 잰다. 지금 컨테이너는 그 서버에 닿지 않아서 네트워크가 열린 곳(로컬 워커)이 해야 한다.
2. **사라진 노선 추출.** OSM의 폐선(disused, abandoned, preserved)과 OpenHistoricalMap을 노선 주변에서 뽑아 ref/rail에 '사라진 노선' 층으로 더한다.
3. **강 이름 검증.** 다리 아래 강 이름을 overpass-turbo 질의로 다시 확인한다. §4.1의 '유력' 표시 항목이 대상이다.
4. **정거장 후보 카드.** 볼슈틴 기관고, 코트부스, 팔켄베르크 2층 교차역, 토르가우 엘베 다리 같은 후보마다 옛 지형도와 현재 항공사진을 나란히 놓은 한 장짜리 자료를 만든다. 권리가 확인된 지도만 쓴다.
5. **6345 노선 철거 확인.** 할레~구벤 노선이 전후 배상으로 한쪽 선로를 뜯겼는지 확인한다. 맞다면 '복선 흔적만 남은 노선' 풍경 근거가 된다.
