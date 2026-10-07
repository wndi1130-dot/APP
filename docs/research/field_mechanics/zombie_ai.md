# 좀비 AI: 어떻게 작동하나

작성: 2026-10-07 · 조사: 코덱스 루나 워커(사용자 요청) · 정리: 조사 스레드

좀보이드 좀비의 감각·기억·무리 이동, 다른 좀비 게임의 무리와 어그로 규칙, 폰에서 많은 좀비를 굴리는 기술을 정리했다. 우리 규칙은 [zombies.md](../../design/briefs/zombies.md)(결정)와 [field_unified.md](../../design/briefs/field_unified.md) 5·6장(기본값)에 있다. 표시는 [README](README.md)를 따른다.

## 한눈에

- 좀보이드는 좀비의 **시야·청각·기억·인지(길 찾기와 문)** 를 따로 조절한다. 설정 예시에는 후각 항목이 없고, 공식 원문에서도 냄새로 추적하는 규칙은 찾지 못했다. [2차]
- 좀보이드의 `FollowSoundDistance`는 **들은 소리 쪽으로 걸어가는 최대 거리**이지 들리는 반경이 아니다. 둘을 섞으면 안 된다. [2차]
- 다른 게임에서 가져올 만한 것은 셋이다. L4D의 **긴장도에 따른 공세·휴식 박자**, Dying Light 2의 **부르는 자가 위치를 전하는 추격**, World War Z의 **멀리선 단순하게, 가까이선 하나하나**. [1차]
- State of Decay 2는 2024년에 "소리가 좀비를 새로 만든다"를 없애고 **이미 있는 좀비를 끌어오게** 바꿨다. 우리 무리 운용의 '앞쪽 무리는 역 주변 좀비를 끌어온다'와 같은 방향이다. [1차]
- 폰에서는 **가까운 좀비만 개별 AI, 중간은 흐름장 공유, 먼 무리는 구역 수와 방향만** 두는 세 단계가 맞다. "폰은 몇 마리까지"를 말해 주는 출처 숫자는 없다. S2에서 잰다. [제안]

## 1. 좀보이드

**버전**

- 2026-09-28에 Build 42.21이 정식이 됐다. 큰 무리 설정에서 청크를 떠났다 돌아오면 좀비가 사라지던 문제와 멀티 중복 문제를 고쳤다. [1차, 원문 대조] [42.21 Stable Released](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/)
- 42.20은 좀비 분포를 도시 쪽으로 모으는 새 출현 지도와 Voronoi 기반 무작위 분포를 넣었다. [1차] [Build 42.20 기능](https://projectzomboid.com/blog/features-overview-build-42-20/)
- 41.72는 플레이어를 쫓는 좀비의 길 찾기를 우선하도록 조정했다. [1차] [41.72 Unstable](https://projectzomboid.com/blog/news/2022/07/41-72-unstable/)

**감각과 기억**

- 샌드박스 설정은 시야(Eagle/Normal/Poor), 청각(Pinpoint/Normal/Poor), 기억(Long/Normal/Short), 인지(문 사용·길 찾기 단계)를 범주로 고른다. 실제 거리 숫자는 설정에 없다. 이 파일은 커뮤니티 미러라 42.21 기본값으로 보지 않는다. [2차] [SandboxVars 예시](https://github.com/F56/zomboid/blob/main/servertest_SandboxVars.lua)
- 기억은 "시야나 소리로 알아챈 뒤 얼마나 오래 기억하나"다. `ThumpNoChasing`은 플레이어를 못 본 좀비도 돌아다니며 문을 두드릴지 정한다. [2차] 같은 파일
- 개발사 모딩 문서에는 좀비 소리 종류와 `radius` 필드가 있지만 숫자는 없다. [1차] [IsoZombie.ZombieSound](https://www.projectzomboid.com/modding/zombie/characters/IsoZombie.ZombieSound.html)
- 문·창문을 두드리는 소리가 주변 좀비를 더 끈다. [2차][미확인] [팬 위키 Zombie](https://projectzomboid.fandom.com/wiki/Zombie)

**화면 밖과 재출현**

- 2015년 Build 32 개발 글: 세계를 300×300 타일 셀로 나누고, 플레이어 근처만 "실제 좀비"로 굴리며, 셀마다 현재 수·목표 수·재출현 시간을 따로 셌다. 로드된 곳과 막 로드된 곳, 막힌 곳에는 다시 만들지 않았다. **옛 구조라 지금 B42 규칙은 아니다.** [1차·레거시] [Bring Out Your Zed](https://projectzomboid.com/blog/news/2015/05/bring-out-your-zed/)
- 화면 밖 총성·비명·헬기 같은 메타 사건이 좀비를 움직인다. [2차][미확인] [팬 위키 Metagame](https://projectzomboid.fandom.com/wiki/Other_%28Game%29)
- 재출현 값은 자료끼리 맞지 않는다. 버전 없는 설정 예시는 `RespawnHours=72`, B42.19 가이드는 Apocalypse 프리셋에서 시간 재출현 0이다. 하나로 합치지 않았다. [2차] [B42.19 서버 설정](https://pzfans.com/project-zomboid-server-settings/)
- 개발사는 멀티에서 플레이어들이 흩어지면 서버가 여러 지역의 좀비 AI와 길 찾기를 같이 돌려야 해 부하가 컸다고 썼다. 넓은 세계 전부에 개별 AI를 돌리는 값이 비싸다는 뜻이다. [1차] [Techno Babbloid](https://projectzomboid.com/blog/news/2021/04/techno-babbloid/)

**시간 척도 메모**: field_unified 5장은 "좀보이드는 기본 설정에서 실시간 1시간이 게임 하루"라고 기억에 기대 적었다. 무기 메모를 정리할 때 브라우저로 연 PZwiki Tired 문서는 기본 하루를 실시간 90분으로 적고 있었다. 버전마다 기본값이 다를 수 있어 5장 문장은 "1~1.5시간, 버전에 따라 다름" 정도로 고치는 게 안전하다. [1차·공식 위키] [PZwiki Tired](https://pzwiki.net/wiki/Tired)

**우리에게**: 좀비 머릿속 상태를 **지금 보이는 대상 / 소리 난 곳 / 마지막으로 본 곳** 셋으로 나눈다. 시야를 끊어도 무리가 바로 멈추지 않고, 마지막 소리 지점으로 모였다가 흩어진다. 6장의 소리 4단계는 반경 하나만 키우지 말고 **몇 마리가 반응하나, 얼마나 오래 쫓나, 얼마나 멀리 길을 트나**를 따로 올린다. 후각은 근거가 없으니, 6장의 "피 냄새 = 1분마다 보통 소리 하나"처럼 소리 규칙에 얹는 지금 방식이 좋다. [제안]

## 2. 다른 게임의 무리와 어그로

**Left 4 Dead**: Director가 생존자마다 긴장도를 재고 가장 높은 값을 따른다. 공세는 `Build Up → Sustain Peak → Peak Fade → Relax`로 돈다. 정점 뒤 3~5초는 공세를 유지하고, Relax는 최소 위협을 30~45초 두거나 다음 안전실 쪽으로 충분히 가면 끝난다. 난이도가 아니라 **공세 빈도**를 조절한다. [1차, 원문 대조] [AI Systems of L4D](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf)

**State of Decay 2**: Update 38(2024)은 차 뒤지기 실패나 문 닫는 소리가 좀비를 새로 만들던 것을 없애고, 이미 있는 좀비를 그 자리로 끌어오게 바꿨다. Update 33은 자극한 역병 심장이 무리를 보내 감염 거점을 만들고 기지를 포위하게 했다. [1차] [SoD2 공식 공지](https://steamcommunity.com/app/495420/announcements/)

**Days Gone**: 무리마다 생활권이 있다. 낮엔 동굴에서 쉬고 물과 먹이를 찾아 움직인다. 잠든 무리는 소리를 들으면 한꺼번에 깬다. [1차] [PlayStation Blog](https://blog.playstation.com/?p=210452) GDC 2018 발표는 소개문만 읽었다. [1차] [GDC 소개](https://gdconf.com/article/study-the-ai-and-freak-o-system-of-sony-s-days-gone-at-gdc-2018/)

**Dying Light 2**: 하울러에게 들키면 주변 감염자에게 경보가 가고, 추격이 길수록 더 센 적이 붙는다. [1차] [개발자 기고](https://blog.playstation.com/2022/02/01/five-ways-dying-light-2-stay-human-innovates-on-techlands-fps-formula/) 사운드팀은 추격을 4단계로 나누고, 플레이어가 멀리 달아나 실제 좀비 소리가 안 들릴 땐 먼 비명·발소리를 따로 만들어 "아직 쫓긴다"를 알린다고 했다. [2차] [A Sound Effect 인터뷰](https://www.asoundeffect.com/dying-light-2-gameaudio/)

**7 Days to Die**: 은신 감지에 소리·빛·거리가 들어가고, 돌을 던져 주의를 돌린다. 소리마다 **즉시 유인**과 **오래 쌓이는 열(Screamer를 부르는 값)** 을 따로 둔다. [1차·공식 위키][미확인] [Stealth System](https://7daystodie.wiki.gg/wiki/Stealth_System), [2차][미확인] [sounds.xml](https://7d2dmodding.wiki.gg/wiki/Sounds.xml)

**World War Z**: 한 화면에 최대 500마리, 멀리 있을 땐 단순한 AI, 다가오면 개별 행동으로 갈라진다. [1차] [PlayStation Blog](https://blog.playstation.com/2019/12/16/world-war-zs-horde-mode-z-launches-tomorrow/) 군중 렌더링은 GDC 발표가 다룬다. [1차] [GDC Vault](https://www.gdcvault.com/play/1025817/Advanced-Graphics-Techniques-Tutorial-High)

**They Are Billions**: 개발사는 감염자 최대 20,000을 각자 AI로 처리한다고 홍보한다. 알고리즘은 공개하지 않았고, RTS라 우리 시점과 같은 숫자로 옮기면 안 된다. [1차] [공식 소개](https://www.theyarebillions.com/TheyAreBillions/)

**우리에게**

- **정차 압박은 L4D식 박자로.** 무리 간격 공식(4.5분, 0.85배)은 그대로 두고, 그 위에 '무리 직후 짧은 휴식 창'을 얹으면 무리가 오는 리듬이 생긴다. 휴식 길이는 총성·보일러 열·부상으로 줄어든다. 숫자는 S2. [제안]
- **소리는 새 좀비를 만들지 않고 있는 좀비를 끈다.** zombies.md의 '예산 하나를 나눈다', '공정한 스폰'과 맞물린다. SoD2가 바꾼 이유가 그것이다. [제안]
- **부르는 자의 비명은 순간이동이 아니라 위치 전달.** 들리는 범위 안의 무리에게 플레이어 위치를 알리고, 다음 무리를 당긴다. 들키기 전에 잡으면 다음 무리가 늦어지는 결정과 그대로 붙는다. [제안]
- **소음 UI는 둘로.** 7DTD처럼 '지금 끌리는 정도'와 '쌓이는 압박'을 나누면 발전기·보일러 같은 반복 소음과 소음기 마모가 읽힌다. 6장의 소음 점수가 이미 '쌓이는 압박'이다. [제안]
- **무리에 생활권을.** 역 주변 무리가 쉬는 곳·열원·선로를 가지면 무작위 스폰이 아니라 세상 안에서 움직이는 위험으로 보인다. 앞쪽 무리 규칙의 연출로 쓴다. [제안]
- **추격 끝을 오해하지 않게.** 탑뷰에서 화면 밖으로 벗어난 무리도 소리 방향 표시나 먼 신음으로 남겨 둔다. [제안]

## 3. 폰에서 많은 좀비 굴리기

- **흐름장**: 유닛마다 A*를 돌리지 않고, 격자 칸마다 목표 방향을 저장해 같은 목표를 가는 유닛이 나눠 쓴다. 목표나 통행이 바뀔 때만 다시 계산한다. Fieldrunners 2가 폰에서 이렇게 수천 유닛을 굴렸다. [1차] [Game AI Pro 24장](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter24_Efficient_Crowd_Simulation_for_Mobile_Games.pdf) Supreme Commander 2는 비용장·통합장·방향장을 나눈 흐름장 타일을 썼다. [1차] [Game AI Pro 23장](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf)
- **Boids**: 가까운 이웃만 보고 분리·정렬·응집 세 규칙으로 무리 움직임을 만든다. [1차] [Reynolds 1987](https://www.cs.toronto.edu/~dt/siggraph97-course/cwr87/)
- **사건 기반 감지**: 모든 적이 매 프레임 시야선과 소리 반경을 검사하면 비싸다. 시간 분할은 일을 줄이는 게 아니라 나눌 뿐이다. [1차] [Game AI Pro Online 2021 2장](https://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter02_Efficient_Event_Based_Simulations.pdf)
- **거리별 LOD**: Unity CullingGroup 문서는 가까운 인물엔 정밀 AI·애니메이션, 먼 인물엔 싼 행동을 쓰는 예를 든다. [1차] [CullingGroup](https://docs.unity.com/en-us/engine/6000.3/manual/cameras/occlusion-culling/culling-group-api/api) 엔진을 Godot로 정했으니 같은 생각을 `VisibleOnScreenNotifier3D`와 거리 구간으로 옮긴다. [제안]
- **소리 전파**: 거리 감쇠만으론 벽과 방을 못 나눈다. Hitman은 포털과 가림을 썼다. [1차] [GDC Vault](https://gdcvault.com/play/1022824/Sound-Propagation-in)
- **프레임 예산**: Unity 폰 최적화 글은 30fps(33.3ms) 중 발열 여유를 두고 약 22ms를 쓰라고 권한다. 게임 전체 예산이지 AI 몫이 아니다. [1차] [Unity 폰 최적화](https://unity.com/blog/games/optimize-your-mobile-game-performance-tips-on-profiling-memory-and-code-architecture-from)

**우리에게**: 세 단계로 나눈다. ① 맞붙음·팔 길이·화면 안의 가까운 좀비만 개별 길 찾기·충돌·시야. ② 화면 가장자리 무리는 정차 지점이나 큰 소리 지점을 목표로 한 흐름장 하나를 나눠 쓰고, Boids로 간격만 맞춘다. 문틀과 열차 출입구에서는 응집을 약하게 해 한 점에 끼지 않게 한다. ③ 화면 밖 무리는 구역별 수와 이동 방향만 들고 있다가 진입로에 닿으면 실제 개체가 된다. 총성·비명·보일러 배기는 위치·단계·수명·종류를 가진 사건으로 한 번 내보내고, 근처 구역의 좀비만 받는다. S2 회색 상자(좀비 50/100/150 토글)에서 ①의 상한을 잰다. [제안]

## 확인 못 한 것

- PZwiki는 자동 접속을 막아 이번 조사에서 본문을 읽지 못했다. 좀보이드는 개발사 블로그, 모딩 문서, 버전 미확정 설정 예시, 팬 위키를 구분해 썼다.
- B42.21의 시야·청각 실제 거리, 총성·헬기별 반경, 화면 밖 좀비가 실제 개체로 바뀌는 거리와 절차는 공개 자료에 없다.
- Days Gone GDC 2018은 소개문만 봤다.

## 다른 조사와의 관계

사용자의 3D 자원·아트 방향 조사 브랜치와 겹치는 링크는 없다. 좀보이드 42.20·42.21 공지와 PlayStation Blog는 main의 다른 문서에도 이미 인용돼 있다.
