# 애니메이션 레퍼런스

확인일: 2026-10-07. 이 게임에서 무엇이 어떻게 움직여야 하는지 보여 주는 자료를 모았다. **레퍼런스는 검토용이며, 게임 규칙이나 화풍의 결정 사항이 아니다.** 표의 '제안'은 이 문서가 덧붙인 해석이다.

## 1. 범위와 읽는 법

### 1.1 PR 12와 나눈 범위

동작을 만드는 데 쓰는 모션 파일과 도구는 [PR 12의 3D 자원 조사](https://github.com/wndi1130-dot/APP/pull/12)([전체 색인](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/ref/art/README.md))에 이미 있다. Quaternius 동작 라이브러리, Mixamo, CMU 모션 캡처, MoCap Online 군중, MoCap Central 작업 동작, Reallusion 부축·운반, Rigify, 리타기팅, Unity Timeline·Splines, 연기 flipbook, 프로스트펑크 2 의회 효과가 그렇다. 이 문서는 그것들을 다시 적지 않고, **움직임과 연출의 본보기**와 PR 12에 없는 기법만 모은다. 겹치는 곳은 PR 12 항목을 가리키기만 한다.

### 1.2 전제

- 월드는 픽셀 아트가 아니라 좀보이드식 그래픽과 사선 탑뷰다(2026-10-07 사용자 정정, PR 12).
- 홈의 열차 단면도 월드와 같은 화풍으로 통일한다(2026-10-07 사용자 선택).
- 그래서 2D 스프라이트가 아니라 3D 인물과 열차를 움직이는 쪽을 기준으로 골랐다.

### 1.3 표시

| 표시 | 뜻 |
|---|---|
| `PD` | 퍼블릭 도메인(미국 기준. 다른 나라 기준은 따로 확인하지 않았다). 보고 따라 그려도 되고, 영상 위에서 동작을 그대로 따도(로토스코프) 된다. |
| `CC` | 출처와 라이선스를 밝히면 쓸 수 있다. 다만 CC BY-SA·GFDL은 고친 결과물에도 같은 조건이 붙으니 게임 에셋에 섞지 말고 보기 자료로 쓴다. |
| `보기만` | 저작물이다. 타이밍과 순서를 보고 배우되, 프레임을 따라 그리거나 화면 구성을 그대로 옮기지 않는다. |
| `원리` | 장치나 기법의 원리를 설명하는 글이다. |

모든 링크는 확인일에 열어 내용과 권리 표시를 읽었다. 원문을 못 열고 다른 사이트의 사본으로만 확인한 것은 메모에 적었다. 저장소가 공개라서 영상과 그림은 올리지 않고 링크와 메모만 둔다.

### 1.4 먼저 볼 것

1. [This War of Mine 제작 인터뷰](https://80.lv/articles/this-war-of-mine-a-game-about-civilians-in-war): 옆에서 보는 게임인데 모든 것이 3D다. 홈 단면(옆)과 필드(사선 위)를 인물·동작 한 벌로 만들 수 있다는 근거다. → 2.7
2. [역회전 레버](https://en.wikipedia.org/wiki/Reversing_gear)와 [기관 전령기](https://en.wikipedia.org/wiki/Engine_order_telegraph): 단계마다 걸리는 레버와 반원 계기의 실물 원형이다. → 5.1
3. Muybridge 동작 사진(1887): 쓰러지기, 일어나기, 기기, 삽질. `PD`라 그대로 따라 그려도 된다. → 3.1
4. [좀보이드 좀비 행동 목록](https://pzwiki.net/wiki/Zombie): 기는 자, 죽은 척, 덮치기, 담 넘다 떨어짐, 밟기. 필드 좀비 동작 목록의 출발점이다. → 4
5. [Night of the Living Dead](https://archive.org/details/night_of_the_living_dead)(1968): `PD`인 망자 걸음의 기준이다. → 4
6. [OpenVAT](https://extensions.blender.org/add-ons/openvat/)와 [Unity Animation Instancing](https://blog.unity.com/engine-platform/animation-instancing-for-skinnedmeshrenderer): 폰에서 무리를 돌리는 방법과 그 한계다. → 6

## 2. 열차

### 2.1 바퀴, 연결봉, 밸브 기어

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Steam locomotive work](https://commons.wikimedia.org/wiki/File:Steam_locomotive_work.gif) (Panther, Wikimedia Commons) | `CC` | 피스톤, 연결봉, 동륜, 밸브 기어가 한 바퀴 동안 엇갈려 움직이는 그림. 옆 단면 열차의 바퀴 리그를 이 순서대로 잇는다. CC BY-SA 3.0과 GFDL. Commons 원문은 이 세션에서 열리지 않아 [사본](https://www.wiki.pathfindersonline.org/w/File:Steam_locomotive_work.gif)에서 확인했다. |
| [Walschaerts motion](https://commons.wikimedia.org/wiki/File:Walschaerts_motion.gif) (R. A. Booty) | `CC` | 밸브 기어만 확대한 그림. [위키백과](https://en.wikipedia.org/wiki/Walschaerts_valve_gear)에 따르면 20세기 유럽에서는 거의 모든 기관차가 이 방식이었고, 폴란드와 체코에서는 Heusinger 밸브 기어라고 부른다. GFDL 1.2 이상([2007년 사본](https://dlab.epfl.ch/wikispeedia/wpcd/images/170/17013.gif.htm) 기준이고, 지금 Commons 표기는 확인하지 못했다). |

### 2.2 볼슈틴의 실제 기관차

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Springtime steam action at Wolsztyn](https://railwayworld.net/2025/05/13/springtime-steam-action-at-wolsztyn/) (Railway World, 2025-05-13) | `보기만` | 2025년 8월 16일까지 Pt47-65가 볼슈틴–즈봉시네크 평일 왕복과 토요일 포즈난 왕복을 끌었다. 우리 첫 구간과 같은 선로라서 이 운행을 찍은 영상이 출발, 기적, 승강장의 가장 가까운 실물이다. 기사 시점에 Ol49-59는 정비 중이었고, 해마다 5월 초에 기관차 퍼레이드가 열린다(2025년은 5월 3일). 그 뒤 운행은 확인하지 않았다. |
| [증기기관차 운용 레퍼런스](steam_operations.md) | `원리` | 출발할 때 실린더 응축수 배수와 차륜 미끄러짐을 조심한다는 승무 순서가 있다. 출발 장면에 실린더 옆으로 흰 증기를 뿜는 순간과 바퀴가 헛도는 순간을 넣을 근거다. 볼슈틴의 Pt47 설명에는 기계식 급탄기가 나오니, 급탄 동작은 기관차 형식마다 달라진다. |

### 2.3 달리기, 도착, 출발

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [New Black Diamond Express](https://www.loc.gov/item/00694259) (Edison, 1900, 미국 의회도서관) | `PD` | 산을 배경으로 다가오는 급행. 굴뚝 연기의 양과 뒤로 눕는 각도로 속도를 보여 주는 법. 선로의 일꾼들에게 기적을 울린다. |
| [Overland Express arriving at Helena, Mont.](https://www.loc.gov/item/00694263) (Edison, 1897) | `PD` | 사람이 붐비는 긴 승강장으로 열차가 들어온다. 정차 연출(속도가 줄고, 증기가 퍼지고, 사람들이 다가오는 순서)과, 출발 때 창밖 승강장에 남겨진 사람을 보여 주는 구도의 참고. |
| [L'Arrivée d'un train en gare de La Ciotat](https://en.wikipedia.org/wiki/L%27Arriv%C3%A9e_d%27un_train_en_gare_de_La_Ciotat) (뤼미에르, 1896) | `PD` | 비스듬히 들어오는 열차와 타고 내리는 사람들. 승강장 쪽 사선 카메라에서 열차가 얼마나 크게 다가오는지. |

의회도서관은 이 영화들에 미국 내 저작권 제한을 알지 못한다고 적는다.

### 2.4 급탄과 기관실 일

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Muybridge, Plate 521](https://www.nga.gov/artworks/136535-plate-number-521-walking-b-ascending-step-c-throwing-disk-d-using-shovel-e-f-using-pick) (1887, 미국 국립미술관) | `PD` | D칸이 삽질이다. 허리와 다리로 무게를 옮기는 순서가 화부 급탄 동작의 뼈대가 된다. 땅을 파는 삽질이라 화실 문으로 던져 넣는 마지막 손목은 바꿔야 한다. 같은 판에 걷기, 계단 오르기, 곡괭이질도 있다. |
| [Derail Valley 매뉴얼: 증기 개요](https://manual.derailvalley.com/wiki/Steam_Overview) | `보기만` | 기관실에서 손이 가는 순서. 삽으로 급탄하고, 인젝터로 급수하고, 조절기와 컷오프로 증기를 보낸다. 기관실 칸을 눌렀을 때 보이는 작업 장면의 순서로 쓴다. |
| [Last Train Home](https://en.wikipedia.org/wiki/Last_Train_Home_(video_game)) (Ashborne Games, 2023) | `보기만` | 겨울 시베리아를 가로지르는 열차 경영 게임. 기관차가 움직이려면 기관사와 화부가 있어야 하고, 사람을 칸마다 배치한다. 기관실 파업을 화면에서 보여 줄 때(빈 자리, 식어 가는 화실) 참고한다. |

삽질·렌치 동작 파일은 PR 12의 MoCap Central Fix & Build와 CMU subject 62에 있다. PR 12는 CMU 목록에서 삽질 동작의 이름을 확인하지 못했다고 적었다.

### 2.5 제설과 쐐기

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Bucking the Blizzard](https://catalog.afi.com/Film/30239-BUCKING-THE-BLIZZARD) (American Mutoscope, 1899) | `PD` | 1899년 눈보라 때 뉴욕주 워터타운 부근에서 기관차 두 대가 로터리 제설차를 밀며 눈을 뿜는 장면. 미국 영화연구소 목록 기준으로 의회도서관에 사본이 있고, 온라인 재생 링크는 찾지 못했다. 열차가 눈 더미나 좀비 무리를 밀고 나갈 때 속도가 얼마나 떨어지고 무엇이 얼마나 흩날리는지의 기준. |
| [Colorado snow plow on the Colorado Midland R.R.](https://www.loc.gov/item/2017658705) (W. H. Jackson, 1899, 사진) | `PD` | 의회도서관 표기는 '출판에 알려진 제한 없음'. 제설차의 앞모습과 옆의 급수탑. |
| [Rotary snowplow](https://en.wikipedia.org/wiki/Rotary_snowplow), [증기기관차 운용 레퍼런스의 제설 항목](steam_operations.md) | `원리` | 우리 설계는 쐐기형이다. 로터리는 눈을 날리는 그림이 강하지만 원리가 다르다는 것을 알고 본다. |

### 2.6 칸 연결과 분리

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Buffers and chain coupler](https://en.wikipedia.org/wiki/Buffers_and_chain_coupler) | `원리` | 한쪽 차량의 사슬 끝 고리를 다른 차량의 갈고리에 걸고 나사를 조여 양쪽 완충기를 맞붙인다. 뗄 때는 나사를 풀어 느슨하게 한 뒤 고리를 벗긴다. 꼬리칸을 떼는 장면에서 누군가 칸 사이로 들어가 나사를 푸는 몇 초가 긴장을 만든다. 제동관과 난방관도 같이 떼야 하는지는 이 글에 없어서 확인이 필요하다. |

### 2.7 단면 속 생활 (홈 화면)

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [This War of Mine 제작 인터뷰](https://80.lv/articles/this-war-of-mine-a-game-about-civilians-in-war) (80.lv) | `보기만` | 개발진은 "모든 것이 3D이고, 옆 스크롤 2D 게임인 척할 뿐"이라고 말한다. 직접 3D 스캔한 사람 모델로 걷기, 달리기, 먹기, 자기, 싸우기 동작을 만들었다. 홈 단면과 필드를 한 벌의 인물과 동작으로 만드는 근거다. PR 12에 있는 SIGGRAPH 기사와는 다른 자료다. |
| [This War of Mine 인물 제작 영상](https://youtu.be/_RHXqG7HlEM) | `보기만` | 개발자와 가족, 친구를 모델로 삼았다. 마르고, 통통하고, 크고, 작은 보통 사람의 체형. 수백 명이 모두 지쳐 보이되 같은 몸으로 보이지 않게 하는 출발점. |
| [The Final Station](https://en.wikipedia.org/wiki/The_Final_Station) (Do My Best Games, 2016) | `보기만` | 좀비 세상을 달리는 열차 안에서 구한 사람들을 먹이고 치료하며, 작은 조작으로 열차를 굴린다. 칸 안 사람의 상태를 몸짓으로 먼저 보여 주는 방식을 본다. 2D 픽셀 게임이라 화풍은 가져오지 않는다. |
| [Fallout Shelter](https://en.wikipedia.org/wiki/Fallout_Shelter) (Bethesda, 2015) | `보기만` | 옆 단면의 방마다 사람이 일하고 오간다. 칸을 좌우로 스크롤할 때 몇 명을 얼마나 바쁘게 움직여야 살아 있어 보이는지 본다. |
| [프로스트펑크 2의 Zoom Stories](https://gamingbolt.com/frostpunk-2-gameplay-improvements-new-ui-features-and-zoom-stories-detailed) | `보기만` | 도시의 한 곳을 확대하면 주민의 일상이 보인다. 결정의 결과를 1~2초 장면으로 보여 주자는 [연출 브리프](../docs/design/briefs/presentation_ui.md) 제안 2(난방을 끊은 칸에 성에가 번지고 사람들이 웅크린다)와 같은 방향이다. |

### 2.8 창밖과 곡선

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [New Brooklyn to New York via Brooklyn Bridge, no. 1](https://www.loc.gov/item/2017604953) (Edison, 1899) | `PD` | 달리는 열차 맨 앞에서 찍은 장면. 가까운 것은 빠르게, 먼 것은 느리게 지나가는 실제 시차를 보고 홈 배경 여러 겹의 속도 비율을 정한다. 의회도서관은 1899년 저작권 등록을 적었지만, 미국에서 1931년 이전 공개작은 지금 퍼블릭 도메인이다. |
| [104th Street curve, New York, elevated railway](https://www.loc.gov/item/00694262) (Edison, 1899) | `PD` | 뒤로 달리는 열차에서 S자 곡선을 찍었다. 곡선 위에서 열차와 풍경이 어떻게 돌아 보이는지. 열차 전체 구경 화면의 곡선 구도 참고. |

## 3. 사람

### 3.1 Muybridge 동작 사진

모두 Eadweard Muybridge의 《Animal Locomotion》(1887)이고 미국 국립미술관이 퍼블릭 도메인으로 공개했다(`PD`). 19세기 연구 사진이라 대부분 벗은 몸이다. 동작만 본다.

| 판 | 가져올 것 |
|---|---|
| [Plate 257. 땅에 눕기](https://www.nga.gov/artworks/166737-plate-number-257-lying-ground) | 서 있다가 웅크려 눕기까지. 쓰러지는 사람, 시신, 죽은 척하는 좀비. |
| [Plate 258. 땅에서 일어나 걸어가기](https://www.nga.gov/collection/art-object-page.166738.html) | 누운 자세에서 일어나 다시 걷기까지 끊김 없이 이어진 동작. |
| [Plate 268. 땅에서 일어나기](https://www.nga.gov/collection/art-object-page.166746.html) | 죽은 사람이 일어나는 동작의 뼈대. 4장의 경련 단계를 위에 얹는다. |
| [Plate 182. 손과 무릎으로 기기](https://www.nga.gov/collection/art-object-page.166677.html) | 다리가 부서진 좀비, 다친 사람의 기기. |
| [Plate 521. 걷기, 계단, 삽, 곡괭이](https://www.nga.gov/artworks/136535-plate-number-521-walking-b-ascending-step-c-throwing-disk-d-using-shovel-e-f-using-pick) | 2.4 참고. |

### 3.2 PR 12에 이미 있는 것

- 부축, 업기, 들것 운반: Reallusion Injury & Rescue(4판)
- 삽질, 렌치, 정비: MoCap Central Fix & Build(4판), CMU subject 62(3판 항목의 재확인)
- 의회 청중의 반응: MoCap Online Crowd(3판)
- 기본 이동과 생활 동작: Quaternius Universal Animation Library 1·2, Mixamo(2판)
- 물건을 집고 건네기: Blender Child Of 제약(4판)

지친 사람과 추운 사람의 몸짓은 확인할 만한 공개 자료를 찾지 못해 7장의 녹화 목록으로 넘겼다.

## 4. 좀비

[decisions.md](../docs/design/decisions.md) '좀비'의 상태와 공통 규칙 순서로 정리했다.

| 상태·동작 | 자료 | 표시 | 가져올 것 |
|---|---|---|---|
| 망자 걸음 | [Night of the Living Dead](https://archive.org/details/night_of_the_living_dead) (조지 A. 로메로, 1968) | `PD` | 느리고 뻣뻣한 걸음, 창과 문을 두드리고 붙잡는 손. 기본 망자의 속도와 무게. 배급사가 제목을 바꾸며 저작권 표시를 빠뜨려 미국에서 퍼블릭 도메인이 됐다([위키백과](https://en.wikipedia.org/wiki/Night_of_the_Living_Dead)). |
| 갓 일어난 자(빠름) | [부산행](https://en.wikipedia.org/wiki/Train_to_Busan) (2016) | `보기만` | 열차 통로와 문에 몰려 쌓이는 빠른 좀비. 제작진은 게임 7 Days to Die, 《이노센스》의 인형 움직임, 사일런트 힐의 간호사를 참고했다. 이 빠르고 꺾인 동작이 망자와 확실히 달라 보여야 '갓 일어난 자'가 읽힌다. |
| 죽은 뒤 일어나는 순간 | [한국 좀비 안무 기사](https://www.koreajoongangdaily.com/lifestyle/the-ups-and-downs-and-lefts-and-rights-of-zombie-choreography/11723022) (코리아중앙데일리) | `원리` | 《#살아있다》의 안무가 예효승은 숨이 무거워지고, 몸이 점점 세게 떨리고, 마지막에 비정상적으로 뒤틀린다고 설명한다. 시체에 표시가 뜬 뒤 일어나기까지를 이 세 단계로 나누면 그대로 예고가 된다(제안). 일어나는 동작 자체는 Plate 268. |
| 기는 자 | [PZwiki: Zombie](https://pzwiki.net/wiki/Zombie) | `보기만` | 서 있는 좀비의 약 5분의 1 속도로 기고, 돌아서려면 몸 전체를 180도 밀어 돌리며, 주로 덮쳐서 공격한다. 죽은 척 누워 있다가 소리에 깨기도 한다. '다리가 부서지면 긴다' 규칙의 출발점. |
| 넘어짐, 일어남, 밟기 | 같은 문서 | `보기만` | 담을 넘다 바닥에 떨어진다. 쓰러지면 일어나기 전에 잠깐 틈이 생긴다. 쓰러진 좀비 위에 서 있으면 일어나지 못한다. 벽에 기대 앉은 좀비는 먼저 일어서야 움직인다. '잡히면 밀쳐낼 틈' 규칙과 짝을 이룰 동작 목록. |
| 잡기, 끌어내리기 | 같은 문서 | `보기만` | 다가와 붙잡고 문다. 무리가 크면 붙잡아 끌어내린다. |
| 무리 안의 개별 행동 | [좀보이드 Build 41 공지](https://projectzomboid.com/blog/news/2021/12/project-zomboid-build-41-released/) | `보기만` | 동작 개편과 함께 들어온 좀비 행동: 갓 죽은 시체를 먹고, 벽에 기대 늘어지고, 담을 넘다 떨어진다. 무리 안에서도 몇 마리는 다른 일을 해야 무리가 살아 보인다. |
| 무리의 생활과 이동 | [Days Gone 무리 설계](https://blog.playstation.com/?p=210452) (PlayStation 블로그), [GDC 2018 강연 소개](https://gdconf.com/news/study-ai-freak-o-system-sonys-days-gone-gdc-2018) | `보기만` | 무리마다 사는 곳이 있고, 쉬고, 마시고, 먹고, 이동하는 패턴이 있다. 정차역의 무리(출처 둘: 역 주변, 진입로)가 어디서 와서 어디로 가는지 보이게 할 때 참고. |
| 얼어붙은 자 | 찾지 못함 | | 맞는 레퍼런스를 찾지 못했다. 제안: 관절 각도를 줄인 뻣뻣한 걸음에, 깨어날 때 얼음 조각이 떨어지는 효과와 둔기에 부서지는 효과를 더해 새 동작보다 효과로 푼다. |
| 껴입은 자 | 따로 두지 않음 | | 제안: 새 동작 없이 옷 부피만큼 팔 흔들림을 줄이고, 실루엣으로 구별한다. |

## 5. UI와 화면 연출

### 5.1 단계 레버와 반원 계기

사용자는 난방, 배급, 의약품, 공간 같은 조절과 인구 조절을 프로스트펑크나 Claude Code의 추론 수준 고르기처럼 단계로 끊기면서 부드럽게 움직이는 조작으로 원한다. 그 '걸림'의 실물이 아래 둘이다.

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Reversing gear](https://en.wikipedia.org/wiki/Reversing_gear) (역회전 레버, Johnson bar) | `원리` | 증기기관차의 진짜 단계 레버다. 손잡이의 스프링 방아쇠를 쥐면 걸쇠가 풀리고, 레버가 톱니판 두 장 사이를 지나 원하는 홈에 걸린다. 홈 사이에는 멈출 수 없다. 화물용은 홈이 적고 여객용은 많다. 압력이 높을 때 걸쇠를 풀면 레버가 확 튕겨 나가 사람이 다친다. 제안: 누르면 걸쇠가 풀리는 작은 딸깍, 끄는 동안 홈마다 걸리는 느낌, 놓으면 가장 가까운 홈에 '탁'. 위기 때 레버가 저절로 튕기는 연출도 쓸 수 있다. |
| [Engine order telegraph](https://en.wikipedia.org/wiki/Engine_order_telegraph) (기관 전령기) | `원리` | 함교에서 손잡이를 옮기면 기관실에 종이 울리고, 기관실이 같은 칸으로 손잡이를 옮겨 응답하면 함교의 바늘이 따라오고 종이 멈춘다. 제안: 반원 계기의 바늘을 이 '응답'으로 쓴다. 레버(명령)를 옮기면 바늘(실제 공급)이 조금 늦게 따라와 멈추고, 최대로 당겨도 모자라면 바늘이 끝까지 못 따라와 빨간 쪽에 남는다. |
| [Android 햅틱 원칙](https://developer.android.com/develop/ui/views/haptics/haptics-principles), [iOS UISelectionFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiselectionfeedbackgenerator) | `원리` | 홈에 걸릴 때마다 손에 짧은 진동을 준다. 안드로이드 문서는 실제 기계의 딸깍을 흉내 내고, 자주 일어나는 동작에는 아주 약하게 주고, 키 클릭은 10~20ms로 하라고 한다. iOS에는 선택이 바뀔 때 쓰는 햅틱이 따로 있다. |

### 5.2 손맛과 흔들림

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Juice it or lose it](https://www.youtube.com/watch?v=Fy0aCDmgnxg) (Martin Jonasson·Petri Purho, 15분) | `보기만` | 같은 게임에 작은 반응을 하나씩 더하며 느낌이 바뀌는 과정. 레버, 서류, 투표함의 작은 튐과 소리의 기준. 우리는 어둡고 조용한 게임이라 양을 크게 줄여서 쓴다. |
| [The Art of Screenshake](https://www.youtube.com/watch?v=AJdEqssNZ-U) (Jan Willem Nijman, 40분) | `보기만` | 화면 흔들림, 멈춤, 반동의 효과. 우리 원칙은 "덜컹거림은 전환할 때만, 정보를 읽을 땐 카메라가 멈춘다"라서 오히려 어디서 흔들지 않을지 정하는 데 쓴다. |

### 5.3 서류 뭉치와 결정 카드

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Papers, Please](https://en.wikipedia.org/wiki/Papers,_Please) (Lucas Pope, 2013) | `보기만` | 책상 위 서류를 끌어 펼치고 도장을 찍는 손맛. 홈 왼쪽 서류 뭉치에서 카드를 꺼내는 동작의 직접 원형이다(decisions.md '결정 카드'). |
| [Reigns](https://en.wikipedia.org/wiki/Reigns_(video_game)) (Nerial, 2016) | `보기만` | 카드를 좌우로 밀어 고른다. 우리 선택지는 2~3개라 그대로 쓰지 못하고, 카드가 들어오고 치워지는 움직임만 본다. |
| [Balatro](https://en.wikipedia.org/wiki/Balatro_(video_game)) (LocalThunk, 2024) | `보기만` | 카드를 집고 놓을 때 기울고, 흔들리고, 튀는 반응. 카드가 손가락에 붙어 있는 느낌. |

### 5.4 투표함과 마지막 돌

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Blackballing](https://en.wikipedia.org/wiki/Blackballing) | `원리` | 투표자는 상자나 천으로 손을 가린 채 공 하나를 소리 나게 넣는다. 누가 넣는지는 보이고 무엇을 넣는지는 안 보인다. 비밀 투표 연출의 실물 원형: 돌 소리는 들리고 손은 가려진다. |
| [Peggle](https://en.wikipedia.org/wiki/Peggle) (PopCap, 2007) | `보기만` | 마지막 주황 못에 다가가는 공을 확대해 따라간다. "박빙이면 마지막 돌이 느리게 떨어진다"(S1b)의 기준. |

### 5.5 카메라가 가는 곳이 곧 메뉴

| 자료 | 표시 | 가져올 것 |
|---|---|---|
| [Supreme Commander](https://en.wikipedia.org/wiki/Supreme_Commander_(video_game))의 전략 줌 | `보기만` | 유닛 하나에서 전체 지도까지 끊김 없이 줌 아웃하고, 끝까지 빼면 아이콘으로 된 지도가 된다. 칸 → 열차 전체 → 철도망 지도로 이어지는 줌 아웃의 기준. |
| 배틀필드 1 재배치 화면 | `보기만` | 사용자가 이미 고른 '한눈에 보기' 전환의 기준(①b 시안 평가). |

## 6. 만들 때 쓸 기법 (PR 12에 없는 것)

| 자료 | 가져올 것 |
|---|---|
| [OpenVAT](https://extensions.blender.org/add-ons/openvat/) (Blender 확장, GPL-3.0 이상, 1.1.2) | 동작을 텍스처에 구워 엔진에서 GPU로 재생한다. Unity, Unreal 5, Godot으로 내보내고 Blender 4.2 LTS 이상에서 돈다. 무리 좀비 수십~수백 마리를 폰에서 돌릴 후보. GPL은 애드온 코드에 붙는 조건이라 구운 결과물에는 붙지 않는 것으로 보이지만, 쓰기 전에 확인한다. |
| [Unity Animation Instancing](https://blog.unity.com/engine-platform/animation-instancing-for-skinnedmeshrenderer) (Unity 블로그, 2018-04) | 동작을 텍스처로 만들어 스키닝을 GPU로 옮긴다. 30fps에서 5~6배 많은 캐릭터를 그렸다고 한다. 대신 동작 전환과 레이어를 못 쓰고, LOD가 없고, OpenGL ES 3.0 이상이 필요하다. 2018년 자료라 지금 Unity와 맞는지는 확인하지 않았다. |
| [Unity 매뉴얼: Mecanim 성능과 최적화](https://docs.unity3d.com/Manual/MecanimPeformanceandOptimization.html) | 화면 밖이면 Cull Completely로 두고 Update When Offscreen을 끈다. 스케일 커브를 피하고, 안 쓰는 레이어는 무게를 0으로 두고, 아바타 마스크로 손가락과 IK를 뺀다. 칸 20~30개에 사람 수백 명을 둘 홈 화면의 기본 규칙. |
| [An Indie Approach to Procedural Animation](http://www.gdcvault.com/play/1020583/Animation-Bootcamp-An-Indie-Approach) (David Rosen, GDC 2014) | 적은 키 포즈와 코드로 걷기와 달리기를 만든다. 지침, 다침, 추위 같은 상태마다 동작을 따로 만들지 않고 코드로 기울이고 늦추는 쪽의 참고. |
| [MDN: Web Animations API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Animations_API) | S1(웹) 화면에서 레버 걸림, 바늘 따라오기, 서류 꺼내기를 라이브러리 없이 만든다. |
| [LitMotion](https://github.com/annulusgames/LitMotion) (MIT) | (2026-10-07 엔진이 Godot 4로 정해져 참고로만 남긴다. Godot에서는 내장 Tween을 쓴다: docs/design/briefs/presentation_motion.md 8b장) S2부터 Unity에서 레버, 바늘, 카드 같은 UI 움직임을 메모리 할당 없이 만드는 트윈 라이브러리. 튕김(Punch)과 흔들림(Shake)도 있다. |

## 7. 직접 녹화해 두면 좋은 장면

게임 화면은 공개 저장소에 올리지 못한다. 가지고 있는 게임에서 10~20초씩 녹화해 PC에만 두고, 파일 이름에 무엇을 보려고 찍었는지 적는다. 따라 그리지 않고 타이밍과 순서만 본다.

- 프로스트펑크 1(이 PC에 설치돼 있다): 눈길을 걷는 작은 사람들의 자세와 속도, 발전기 과부하를 켤 때 화면과 소리의 반응, 법에 서명하는 연출, 폭풍이 올 때 화면이 바뀌는 순서.
- This War of Mine: 다치거나 아프거나 지친 인물의 걸음, 단면 안에서 여러 사람이 동시에 다른 일을 하는 장면.
- Project Zomboid: 기는 자, 담 넘다 떨어지는 좀비, 쓰러졌다 일어나는 좀비, 밀쳐내기.
- 프로스트펑크 2: 의회 표결 연출, Zoom Stories.
- Last Train Home: 기관사와 화부를 배치하는 화면.

## 8. 찾지 못한 것, 일부러 뺀 것

- 얼어붙은 자가 깨어나는 동작은 맞는 레퍼런스를 찾지 못했다(4장).
- 볼슈틴 기관차의 사용 허락된 영상: Wikimedia Commons가 이 세션에서 열리지 않아 확인하지 못했다. Commons에 CC 영상이 있을 수 있다(미확인).
- 실제 피난 열차의 사진과 영상은 모으지 않았다. 강제 이송 열차의 이미지와 섞일 위험이 있어서다([decisions.md](../docs/design/decisions.md) '세계와 런').
- 절단 장면은 소리와 얼굴로 끌고 간다고 정해져 있어 동작 레퍼런스를 모으지 않았다.

## 9. 짚어 둘 점

1. **동작 수가 가장 큰 비용이다.** 사람의 상태(지침, 추위, 다침, 짐)와 행동(걷기, 일하기, 앉기)을 곱하고, 좀비 상태 넷과 진화 둘을 더하면 클립이 금방 수백 개가 된다. 상태는 속도, 자세, 상체 레이어로 얹고 클립을 곱하지 않는 쪽을 S2 회색 박스에서 먼저 시험한다. Rosen의 강연과 Unity 최적화 문서가 이 방향이다.
2. **한 벌의 동작이 두 카메라에서 다 읽히는지 먼저 봐야 한다.** This War of Mine는 옆 카메라 하나에서 3D 인물을 썼다. 우리는 옆(홈)과 사선 위(필드)를 다 쓴다. 위에서 보면 팔다리가 짧아 보여 동작을 크게 해야 하고, 그 동작이 옆에서는 과해 보일 수 있다(추론). 같은 걷기를 두 카메라에서 나란히 보는 시험이 필요하다.
3. **무리 기법은 상호작용과 부딪힌다.** VAT와 인스턴싱은 동작 전환이 안 된다. 붙잡고 밀쳐내는 좀비는 가까운 몇 마리만 정식 애니메이션으로 바꿔야 하고, 바뀌는 순간이 튀지 않게 하는 것이 숙제다.
4. **따라 그려도 되는 것은 `PD`뿐이다.** 게임과 영화 화면은 타이밍만 본다. `CC` 자료는 출처를 밝혀도 결과물에 같은 조건이 붙는다.
