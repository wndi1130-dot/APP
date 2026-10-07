# 레퍼런스 분석 1차: GPT 조사(PR 12)와 프로스트펑크 1 아트북

작성: 2026-10-07 · 상태: 분석과 제안이다. 확정은 [decisions.md](../design/decisions.md)에 적힌 것만 확정이다.

## 요약

- 홈 단면도 월드와 같은 비픽셀 화풍으로 간다(2026-10-07 사용자 선택). v3로 뽑은 시안(home_v3)의 분위기를 사용자가 좋아했고, 고칠 점과 v4 수정 프롬프트는 9장에 있다.
- 바깥도 어둡고 칙칙하게, 궂은 날씨 8할로 간다(2026-10-07 사용자 결정). 아래 4장의 '밝게' 제안은 채택되지 않았다.
- GPT 조사(PR 12)는 제작 자원 목록으로는 쓸모가 있지만 아트 방향 자체는 거의 없다. 월드 정정 부분만 지금 머지하고, 3D 자원 목록과 검사 스크립트는 S2 때 다시 보는 쪽을 권한다(2장).
- 아트북에서 가장 크게 얻은 것: 프로스트펑크의 추위는 '어둡게'가 아니라 '밝게, 하얗고 푸르게'에서 나온다. 지금 정해 둔 '마감 단계에서 더 어둡게'와 부딪힌다. 바깥은 밝고 차갑게, 칸 안은 어둡고 따뜻하게 나누는 안을 제안한다(4장).
- 색의 뜻이 겹친다. 프로스트펑크는 빨강·주황을 '따뜻함', 하늘색을 '추움'으로 쓰는데, 우리는 빨강을 '불만', 하늘색을 '지지'로 정했다. 추위는 채도 낮은 회백색으로, 따뜻함은 호박색으로 그리는 안을 제안한다(4장).
- 애니메이션과 지도에 넘길 내용은 6장에 따로 모았다. 두 스레드가 이미 PR 13(애니메이션)과 지도 문서를 맡았으니 중복 확인용이다.

## 1. 본 자료와 못 본 자료

| 자료 | 상태 | 비고 |
|---|---|---|
| PR 12 (`research/3d-resources-and-art-direction-20261007`, 머리 `f7e13f2`) | 읽음 | production_brief, 새 image_prompts, 2~6판 자원 조사, 3D 지시서·감사 |
| GPT 대화 원문과 1판 조사 브리프 | 읽음 | 사용자 PC에 정리된 사본. 거의 다 PR 12에 있고, 1판 브리프 본문과 링크 4개만 빠졌다(출처 절) |
| 프로스트펑크 1 디지털 아트북(29쪽) | 다 봄 | 사용자 PC의 스팀 폴더. 저작물이라 그림과 긴 발췌는 올리지 않고, 우리 말로 쓴 관찰만 남긴다 |
| Game UI Database 프로스트펑크 화면 | 못 봄 | 사이트가 자동 접속을 막는다. 사용자가 직접 보거나 캡처로 보여 줘야 한다 |
| Last Train Home, Fallout Shelter | 화면은 못 봄 | 5장의 '확인할 후보'로만 둔다 |

## 2. GPT 조사(PR 12) 평가

### 쓸 것

- **층을 나눈 것.** 월드, UI, 초상, 폰트를 서로 다른 결정으로 나눴다. 월드가 비픽셀로 바뀌어도 UI까지 자동으로 바뀌지 않는다는 정리가 맞다(열린 질문 10은 그대로 열려 있다).
- **'상태가 보여야 한다'는 원칙.** 난방이 꺼진 칸, 약탈된 역처럼 같은 장소의 상태 차이를 그림으로 보여 주자는 장면 계획(3판 S01~S06)은 우리 홈 설계와 맞는다.
- **제작자가 직접 설명한 자료 6개(3판 R01~R06).** This War of Mine의 '지친 민간인에 안 맞는 동작은 버렸다', 프로스트펑크 2 의회 얼룩이 긴장도에 반응한다는 것, 프로스트펑크 2 UX 사례(이벤트 표식과 창의 모양을 맞춤), 메트로 엑소더스 메뉴가 열차 객실을 여정 상태에 맞춰 바꾼다는 것. 넷 다 우리 화면에 바로 옮길 수 있다.
- **권리 규칙.** '게임에 써도 된다'와 '원본을 공개 저장소에 올려도 된다'를 나눈 것, 아트북·OST·모델은 링크만 둔다는 것.
- **좀보이드식 ≠ 순수 3D.** 1판 브리프가 짚었듯 좀보이드는 2D 등각 타일에 깊이 정보를 주는 방식이다. '좀보이드처럼 보인다'와 '3D로 만든다'는 다른 결정이다.

### 문제

- **아트 방향이 거의 없다.** 색, 빛, 실루엣, 재질, 무엇을 피할지에 대한 판단이 적고, 대부분 자원 후보와 라이선스 목록이다.
- **지금 단계에 너무 이르다.** 지금은 S1(2D 웹 텍스트 프로토타입) 준비 단계다. 85건의 3D 자원 목록과 JSON 검사 스크립트는 S2(Unity 회색 박스)에서야 쓸 일이 생기고, 그때까지 목록을 맞춰 두는 관리 비용만 든다.
- **3D를 전제한다.** decisions.md에는 3D로 만든다는 결정이 없다. Blender 작업 이야기는 있지만 화풍 결정은 아니다.
- **Blender 4.5 고정은 근거가 약하다.** GPT가 쓰던 로컬 환경 기준이다.
- **새 홈 프롬프트가 빠뜨린 것.** 흐르는 배경 층(망자, 매달리는 피난민, 지나치는 승강장), 열차 크기(화면 높이의 약 40%), 아래 단추 자리가 빠졌고, 프롬프트에 'Project Zomboid'를 이름으로 넣었다. 이름을 넣으면 원작을 닮게 나온다.
- **'멈춘 곳' 목록이 보관본으로 밀려났다.** 아이콘 ④c 저장, 명판 ⑤, ①b·③ 재생성 같은 남은 일이 새 문서에서 안 보인다.

### PR 12 처리 권고

1. 월드 정정(decisions.md, CLAUDE.md, session_start.md의 해당 줄)만 먼저 머지한다.
2. 3D 자원 목록(ref/art/)과 검사 스크립트는 S2를 시작할 때 다시 본다. 그때 엔진과 Blender 버전을 정한다.
3. image_prompts.md는 통째로 바꾸지 말고 기존 문서에 정정을 덧붙이고 '멈춘 곳'을 살린다. 홈 프롬프트는 이 문서 7장의 v3를 쓴다.

PR 12는 GPT가 만든 브랜치라 이 PR에서 고치지 않았다. 어떻게 할지는 사용자가 정한다.

## 3. 아트북에서 읽은 것

쪽수는 디지털 아트북의 펼침면 순서다.

| 읽은 것 | 쪽 | 우리 게임에 옮기면 |
|---|---|---|
| 차가움은 하양·파랑, 밝은 노출, 화면 가장자리의 성에 막에서 나온다 | 16 | 바깥은 흐린 겨울 낮처럼 밝게. 칸 안만 어둡게 해서 대비를 만든다 |
| 화면이 도시, 결정 창, 바깥 세계 세 층으로 나뉜다 | 16 | 우리도 열차 단면, 결정 카드·창, 창밖 세계 세 층이다. 층마다 빛을 다르게 준다 |
| 발전기가 증기 수준에 따라 눈에 띄게 달라지고, 기계마다 열림·닫힘 상태가 있다 | 20 | 기관차 화실, 난로, 난방관이 레버 단계에 따라 달라 보여야 한다 |
| 건물이 같은 '막대' 문법으로 지어지고, 사회 상태가 벽에 스며든다 | 13 | 칸 개조 문법을 정한다. 꼬리칸은 판자·방수포·헝겊, 앞칸은 원래 내장재. 세력의 흔적(포스터·낙서)이 벽에 남는다 |
| '사람들은 자기 문화 코드를 되살리려 한다'는 메모 | 14 | 무너지기 전 삶의 흔적: 가족사진, 성화(聖畫), 축구 머플러, 고향 지명 |
| 겹겹이 입은 옷이 계급을 넘어 모두의 공통분모. 같은 몸에 외투만 바꾼 변형 | 7~8 | 공통 몸체 1~2종에 외투·목도리·모자로 사람을 가른다(원본 설계 로그 8장과 같은 방향) |
| 메모에 적힌 성격 'SAD, VICTORIAN, COLD, TIRED' | 8 | 우리 판: 지침, 추위, 체념, 버팀. 빅토리아풍은 뺀다(4장) |
| 모두가 들고 다니는 빛 하나(반딧불 등), 계급은 장식으로 구분 | 10 | 우리 판: 철도 손전등(신호등). 꼬리칸은 찌그러진 깡통 등, 앞칸은 놋쇠 등 |
| 의무병의 피는 앞치마와 장갑에만. 목발, 의족, 의수 디자인 | 10, 21 | 피는 옷과 붕대 얼룩까지만 그린다는 기존 규칙과 같다. 의수·의족은 필드 브리프의 절단 결정과 이어진다 |
| 눈 속의 언 손 하나로 죽음을 암시한다 | 17 | 시체를 그리지 않고 흔적으로 보여 준다. 연령 등급에도 유리하다 |
| 기억에 남는 둥근 분화구 실루엣 | 5 | 홈 열차도 멀리서 실루엣만으로 알아볼 수 있어야 한다(기관차 굴뚝, 난방관, 지붕 개조) |
| 결정 그림이 '눈과 석탄'처럼 사물에 다가간 근접 화면이다 | 22~24 | 결정 카드 초상 뒤 배경을 사물 근접(언 손, 빈 그릇, 석탄 한 삽)으로 한다 |
| 신질서는 빨강·하양·검정 깃발에 문장만 바꾼다 | 25~26 | 우리 세력 표식은 이 배색을 피한다. 전체주의 시각 코드를 그대로 따라가는 것이 된다 |
| 열 지도: 빨강·주황·노랑이 따뜻함, 청록이 추움 | 27 | 우리 정치색과 겹친다. 4장 참고 |
| UI: 기계식 숫자판, 가운데 온도 다이얼, 성에 낀 남색 판에 은빛 빅토리아 장식, 세리프체 | 28 | 기계식 숫자판과 다이얼은 가져온다. 장식은 20세기 철도 언어로 바꾼다 |
| 손으로 그린 금빛 방사형 도시 지도 | 1 | 지도 스레드에 넘긴다(6장) |

## 4. 짚어야 할 충돌

### 어둡게 vs 밝게 추운

decisions.md는 '세기말답게 어둡고 칙칙하게', image_prompts.md는 '마감 단계에서 더 어둡게'로 적어 두었다. 그런데 아트북은 추위를 밝은 노출과 하양·파랑으로 만든다. 전부 어둡게 하면 춥다기보다 그냥 밤처럼 보이고, 폰 화면에서 칸 안이 뭉개진다.

제안이었던 것: 바깥은 흐린 겨울 낮처럼 밝게.

**사용자 결정(2026-10-07):** 밝게가 아니라 바깥도 어둡고 칙칙하게 간다. 영국 날씨나 러시아 분위기로, 궂은 날씨(안개, 구름, 폭풍, 비)가 8할, 평범한 날씨가 2할이다. 남는 위험은 폰에서 칸 안이 뭉개지는 것이다. 칸 안 등불과 HUD의 대비로 막는다(9장 v4 프롬프트).

### 색의 뜻

우리는 빨강 = 불만(그리고 계기의 부족 구간), 하늘색 = 지지로 정했다. 프로스트펑크처럼 추위를 하늘색으로 칠하면 '지지가 높은 칸'처럼 읽힌다.

사용자가 회백색 추위에 동의했다(2026-10-07).

- 빨강은 무언가 나쁠 때만(불만, 계기의 부족 구간). 하늘색은 지지에만.
- 추위는 채도 낮은 회백색 성에와 청회색 그림자로, 따뜻함은 호박색 빛으로.
- ①b 프롬프트의 칸 종류별 색(앞칸 버건디, 기관차 녹슨 빨강)도 이 규칙과 부딪힌다. 열린 질문 7(칸 종류별 색과 집단 색)에서 같이 정한다.

### 빅토리아풍 장식

프로스트펑크 1 UI의 은빛 덩굴 장식은 19세기 영국 설정에서 나왔다. 우리는 붕괴 6년째의 20세기 중앙유럽 열차다. 같은 장식을 쓰면 원작을 베낀 것처럼 보이고 시대도 안 맞는다.

제안: 에나멜 철도 표지판, 스텐실 글자, 리벳, 놋쇠 테, 시간표 활자 같은 20세기 철도·공업 언어로 옮긴다.

### 프롬프트의 작품 이름

PR 12의 새 프롬프트는 Project Zomboid를 이름으로 넣었고, 기존 image_prompts.md도 사용자 요청으로 한 번 이름을 넣었다. 이름을 넣으면 원작과 닮게 나오기 쉽다. v3에는 작품 이름을 넣지 않고 성질(사선 탑뷰, 사실적 비례, 낡은 재질)로만 적었다.

### 3D 단면의 제작량

홈이 비픽셀이 되면서 3D로 만들면 열차 모델 하나로 홈, 한눈에 보기, 필드를 다 쓸 수 있다. 대신 칸마다 지붕·앞벽을 뗄 수 있게 조립하고, 개조 상태를 바꿀 수 있게 만들어야 해서 칸 하나의 제작량이 꽤 크다. 3D로 갈지는 아직 정하지 않았다. 시안 단계에서는 실루엣 확인용으로 회색 점토 렌더를 먼저 보는 방법이 싸다.

## 5. 작품별 가져올 것과 피할 것

| 작품 | 가져올 것 | 피할 것 |
|---|---|---|
| 프로스트펑크 1 | 밝은 추위, 기계 상태가 보이는 발전기, 모두가 드는 빛, 사회가 벽에 스며드는 건물 문법, 기계식 숫자판 | 빅토리아 장식, 열 지도 색, 신질서 배색 |
| 프로스트펑크 2 | 의회 얼룩처럼 긴장도에 반응하는 UI, 아이콘을 결과 중심으로 고친 UX 원칙, 이벤트 표식과 창 모양 맞추기 | 원작 얼룩 효과를 그대로 복제하기, 긴장이 높을수록 숫자가 안 읽히는 연출 |
| This War of Mine | 지친 민간인의 자세, 단면도에서 생활이 보이는 칸, 맞지 않는 동작은 버리는 기준 | 흑백에 가까운 무채색 전체(우리 정치색이 죽는다) |
| 메트로 엑소더스 | 열차 객실이 여정 상태(계절, 소품, 빈자리)에 따라 바뀌는 연출, 손에 든 사물이 상태를 알려 주는 방식 | HUD를 없애는 것(폰에서는 숫자·경고가 필요하다) |
| 좀보이드 | 사선 탑뷰, 읽히는 실루엣, 공통 몸체에 옷으로 구분 | 픽셀화 강제, 그 게임의 그림을 닮게 하기 |
| Last Train Home(확인할 후보) | 열차와 겨울, 칸 업그레이드, 승무원의 비전투 역할(치료, 제작, 식당칸 사기)이 우리와 가장 가깝다 | 화면에서 열차를 어떻게 보여 주는지는 못 봤다. 직접 보고 판단한다 |
| Fallout Shelter(확인할 후보) | 단면에서 칸마다 사람과 상태가 보이는 화면 구성의 대표 사례 | 만화 비례와 밝은 색. 구성만 본다 |

## 6. 애니메이션·지도 스레드용 표시

두 스레드는 이미 결과를 냈다(애니메이션은 [PR 13](https://github.com/wndi1130-dot/APP/pull/13)의 `ref/animation_references.md`, 지도는 `ref/map_references.md` 작업 중). 아래는 PR 12와 아트북에서 그쪽에 속하는 것을 모은 중복 확인용 목록이다.

### 애니메이션

- PR 12 2판: rigify, mpfb, quaternius_bodies, quaternius_anim1, quaternius_anim2, rokoko_retarget, mixamo, unity_rigging, texture_sheet, smoke_particles
- PR 12 3판: cmu_focused_mocap, mco_crowd(AI 조항 때문에 보류), unity_timeline, unity_ugui_shaders, 제작자 자료 R01(TWoM 동작 기준), R03(FP2 의회 얼룩)
- PR 12 4판: mcc_fix_build, reallusion_injury_rescue, blender_child_of_handoffs
- PR 12 6판(`ref/art/animation_resources_v6.md`): 사다리·계단(MoCap Online LADDER, Motionbeats Stairs), KayKit, Kubold 소총·권총·엄폐, 펌프 산탄총, 부상(Ailive, Raise Creation), 장애인 캐릭터(Studio Ochi), IKFootPlacement, LimbHacker, Unity Avatar Mask·MatchTarget. EzySlice를 캐릭터 절단에 쓰는 안은 막힘으로 분류
- 아트북: 같은 몸에 옷만 바꾼 변형(7~8쪽), 기계의 열림·닫힘 상태(20쪽), 2.5D 모션 디자이너 크레딧(27쪽), 간판의 작은 반복 동작(14쪽)

### 지도

- PR 12 2판: blender_gis, ant_landscape, sapling, kenney_train, kenney_buildings, kenney_industrial, kenney_factory, wall_cutout, snow_tracks, urp_decals
- PR 12 4판: unity_spline_train_path, 기관차 도면 단서(Ol49-69 볼슈틴 입찰 문서, Pt31 박물관 문서)
- PR 12 3판: S06 약탈된 역 장면 계획
- 아트북: 손으로 그린 금빛 방사형 지도(1쪽), 바깥 세계 장소 썸네일(17~18쪽), 기억에 남는 지형 실루엣(5쪽)
- 기존 main: ref/rail/(B4), ref/places_central_europe.md(B5)

## 7. ① 홈 시안 v3 프롬프트 (초안)

home_v2를 첨부하되 배치만 가져오고 픽셀 화풍은 버린다. 영어로 쓰는 이유는 이미지 모델이 영어 지시를 더 정확히 따르기 때문이다.

```text
Use the attached image for layout only: the camera, the train's position and size, and the HUD placement. Do not copy its pixel-art style.

Mobile game screen mockup, very wide landscape (about 2.2:1). A steam train crosses a frozen Central European plain in the sixth winter after modern civilization collapsed. Not pixel art: a grounded, realistic 3D-rendered look with a painterly texture finish, believable proportions and worn real materials, simple enough to read on a phone.

Camera: a straight side view with the near walls cut away so the interiors show, as in a cross-section. From left to right: a rear car cut off at the edge, a second rear car, the medical car, the dining car, the guard car, the front passengers' car, and the locomotive cut off at the edge with its firebox glowing. The car bodies fill about 40% of the screen height.

Light: overcast winter daylight. Outside is bright, white and pale blue, cold just to look at. Inside the cars it is dim, lit only by oil lamps, railway hand lanterns and small stoves.

The cars are old steel-and-wood railway carriages, each patched by the people who live in it: rear cars with planks, tarpaulin and rags stuffed into gaps; the medical car with clean sheet metal and white cloth partitions; the dining car with long tables under a hanging lamp; the guard car with steel shutters; the front car with curtains, a carpet and its original upholstery. Show each car's condition without numbers: the rear car is crowded and cold, with people sitting on the floor under blankets, bunks stacked three high, visible breath and frost on the windows; the front car is spacious and warm. Add small remnants of pre-collapse life such as family photos, a saint's icon and a football scarf. A lagged heating pipe runs from the locomotive along the roofs but stops before the rear cars. Above each car door hangs a small iron plaque with a simple emblem and no text.

Outside, in layers that keep moving: refugees in layered coats run beside the rear cars and reach for the train; a family waits on a platform the train will not stop at; far behind, dark stumbling figures follow; an abandoned train lies on a siding; pine forest and a distant church spire under a grey sky. No gore.

The second rear car is selected with a thin brass outline. A compact panel above it holds two lever controls (heating, space), each with discrete notches and a small semicircular gauge; on this cold, crowded car both needles lean into the red on the left. No plus or minus buttons.

HUD: top left, trust (two clasped gloved hands) and tension (a taut, fraying rope), each with a number, a short segmented bar and a tiny label; top center, a bar running from red (discontent) through grey (neutral) to sky blue (support), with a raised fist button at the left end and an open palm at the right; top right, coal (a small mine cart of coal), food (a loaf), medicine (a pill beside a brown bottle) and luxury goods (a ring), each with mechanical counter digits. On the left, slightly away from the edge, a small bundle of worn papers tied with string and a dark red wax seal, for pending decisions. Bottom left, a round menu button and a book button; bottom center, a five-step route line and a small overview button showing a top-down train; bottom right, a large arrow button with a blank label plate.

UI finish, as a proposal: smooth, not pixel; dark gunmetal panels like enamel railway signs, thin brass rims, slightly worn edges, condensed numerals. Frost creeps in only at the screen corners and never covers numbers.

Red appears only where something is wrong (the discontent end of the bar, gauge shortage zones); sky blue appears only for support. Show cold as pale grey-white frost and blue-grey shadow rather than saturated blue, and warmth as amber light. Avoid pixel art, toy or cartoon proportions, glossy product renders, Victorian ornament, readable text other than the tiny labels, logos, red cross symbols, wounds and gore.
```

### home_v2에서 바뀐 것

- 픽셀 대신 사실적 비례의 비픽셀 화풍(사용자 선택 '월드와 통일').
- 밤·노을 대신 흐린 겨울 낮. 바깥은 밝고 칸 안은 어둡다.
- −/+ 단추 대신 레버와 반원 계기(decisions.md 2026-10-06).
- 칸의 처지를 숫자 없이 보여 주는 장치: 바닥에 앉은 사람, 3층 침상, 입김, 창의 성에, 꼬리칸 앞에서 끊긴 난방관.
- 신임·긴장에 짧은 눈금 막대와 이름표, 자원에 기계식 숫자판, 왼쪽 서류 뭉치.
- 지나치는 승강장의 가족, 버려진 열차 같은 배경 층.

### 볼 것

1. 폰 크기로 줄여도 칸 다섯이 구별되는가.
2. 숫자 없이 꼬리칸이 춥고 붐빈다는 것이 읽히는가.
3. 빨강·하늘색이 정치 뜻 말고 다른 데 쓰이지 않았는가.
4. 칸 안이 너무 어두워 뭉개지지 않는가.
5. HUD가 decisions.md의 배치와 맞는가.

긴장 아이콘의 끊어지려는 밧줄은 시험 후보다. 아직 정하지 않았다(열린 질문 10).

## 8. 다음 할 일

1. ~~v3로 ① 홈을 뽑아 평가한다.~~ 끝남(9장). v4 수정 프롬프트로 다시 뽑는다.
2. 결과가 괜찮으면 같은 기준으로 ①b 한눈에 보기, ③ 결정 카드 프롬프트를 고친다.
3. 사용자가 정할 것: PR 12 처리(2장 권고), '밝게 추운' 안(4장), 추위 색 규칙과 열린 질문 7, UI 그림 방식(열린 질문 10).
4. Game UI Database의 프로스트펑크 2 화면과 Last Train Home 화면은 사용자가 캡처로 보여 주면 평가에 더한다. 캡처는 저장소에 올리지 않는다.

## 9. home_v3 시안 평가와 v4 수정 프롬프트

v3로 뽑은 결과가 [mockups/home_v3.webp](mockups/home_v3.webp)다. 사용자는 분위기가 마음에 든다고 했다(2026-10-07).

### 잘 된 것

- 칸 여섯(잘린 꼬리칸, 둘째 꼬리칸, 의무칸, 식당칸, 경비칸, 앞칸)과 기관차가 폰 크기에서도 구별된다. 칸 문 위 명판도 읽힌다.
- HUD가 정해 둔 배치대로 나왔다. 이름표 달린 신임·긴장, 빨강→회색→파랑 띠와 양 끝 주먹·편 손 단추, 기계식 숫자판 자원, 왼쪽 아래 밀랍 봉인 서류 뭉치, 다섯 칸 노선, 한눈에 보기 단추, 오른쪽 화살표.
- 긴장 아이콘인 끊어지려는 밧줄이 이름표와 함께 잘 읽힌다. 열린 질문 10에서 정할 후보로 가장 유력하다.
- 앞칸의 커튼·카펫·성화와 꼬리칸의 3층 침상·헝겊이 숫자 없이 처지 차이를 보여 준다.

### 고칠 것

1. **날씨.** 바깥이 밝은 흐린 낮이다. 사용자 결정대로 어둡고 칙칙한 궂은 날씨로 바꾼다.
2. **의무칸 명판의 빨간 십자.** 금지 목록에 있는데 나왔다. 적십자 표장은 법으로 보호되는 표지라 게임에 쓰면 문제가 된다. 정해 둔 톱니와 약병 명판으로 바꾼다.
3. **꼬리칸이 따뜻해 보인다.** 모든 칸이 같은 호박색 실내라 꼬리칸이 춥다는 것이 안 읽힌다. 꼬리칸은 등불 하나, 입김, 창의 성에로 차갑게 하고, 앞쪽 칸으로 갈수록 따뜻하게 한다. 난방관이 꼬리칸 앞에서 끊기는 것도 안 보인다.
4. **레버가 가로 슬라이더처럼 보인다.** 손잡이가 단계마다 걸리는 눈금 칸이 없다. 반원 계기는 잘 나왔다.
5. **앞칸의 빨간 커튼과 의자.** 빨강은 나쁠 때만 쓴다는 규칙과 겹친다. 짙은 녹색이나 갈색 벨벳으로 바꾼다.
6. **신임 막대가 파랑이다.** 하늘색은 지지에만 쓰기로 했으니 신임 막대는 놋쇠색이나 회백색으로 바꾼다.
7. **아래 단추가 배경과 겹친다.** 앞쪽 울타리와 피난민 여인이 메뉴·책·서류 뭉치 단추 뒤에 겹쳐 읽기 어렵다. 맨 앞 전경을 낮추거나 비운다.
8. **빠진 것.** 열차가 서지 않고 지나치는 승강장의 가족이 없다.

### 날씨에서 짚을 점

세계는 긴 겨울과 짧은 해빙기다(decisions.md 세계관). 영하의 긴 겨울에는 비가 그대로 내리기 어렵다. 겨울의 궂은 날씨는 얼음 안개, 진눈깨비, 어는 비, 눈보라로 하고, 진짜 비와 진창은 해빙기에 두는 편이 맞다(제안). 이렇게 하면 해빙기의 비가 계절이 바뀌었다는 신호도 된다.

### v4 수정 프롬프트

home_v3를 첨부하고 쓴다. 날씨는 궂은 날씨 8할 가운데 하나로 해 질 녘 얼음 안개와 진눈깨비를 골랐다.

```text
Edit the attached image. Keep the composition, the camera, the train, the car interiors, the HUD layout and the painterly realistic style. Make these changes:
1) Weather and light: late afternoon under low, heavy clouds, with freezing fog and wet sleet blowing diagonally. The sky and the land are dark, grey and drab; the distant forest and church fade into the fog. No bright daylight. The only warm light comes from the car windows, lamps and the locomotive firebox, so the cutaway interiors stay clearly readable against the dark outside.
2) Make the rear cars visibly cold: the second rear car has a single weak lantern, visible breath, frost on the inner walls and people huddled under blankets; warmth increases car by car toward the locomotive. Show the lagged heating pipe along the roofs ending before the rear cars.
3) Replace the red cross plaque on the medical car with a plaque showing a gear beside a small medicine bottle. No cross symbols anywhere.
4) Recolor the front car's red curtains and armchairs to dark green and brown velvet. Red appears only on the discontent end of the top bar, the tension meter and the gauge shortage zones.
5) Recolor the trust meter's small bar from blue to brass. Sky blue appears only on the support end of the top bar.
6) Turn the two controls in the selected car's panel into lever handles that move along a track with clear notched steps, like a ship's engine-order lever, keeping the semicircular gauges with needles leaning into the red.
7) Lower or clear the foreground fence and figures in the bottom-left so the dossier bundle, menu and book buttons sit on a calm, dark area.
8) Outside, near the middle cars, add a small platform the train passes without stopping, with a family waiting on it.
Keep all labels and numbers sharp and readable; frost stays only in the screen corners.
```

## 10. 웹에서 찾은 참고 자료 (2026-10-07)

모두 저작물이라 링크와 우리 말 메모만 둔다. 그림을 저장하거나 저장소에 올리지 않는다. 재사용할 수 있는 사진 후보는 Wikimedia Commons뿐이고, 파일마다 라이선스를 따로 확인해야 한다.

### 짚을 점

- **프로스트펑크 2가 확대하면 뭉개지는 것이 메모리 절약 때문이라는 근거는 못 찾았다.** 기술 인터뷰와 벤치마크에 줌 단계별 텍스처·LOD 이야기는 없었다. 그 설명은 추정으로 다룬다. 우리가 텍스처를 아끼는 방향 자체는 맞고, 그 근거로는 좀보이드 개발 블로그가 더 낫다(아래).
- **Last Train Home은 옆 단면이 아니라 위에서 내려다보는 3D 디오라마로 보인다**(체험기 기준, 영상으로 확인 전 추정). 우리 옆 단면 열차의 직접 선례는 This War of Mine, Fallout Shelter, Sheltered다.

### 프로스트펑크 2

- [GamingBolt: Zoom Stories와 UI 단순화](https://gamingbolt.com/frostpunk-2-gameplay-improvements-new-ui-features-and-zoom-stories-detailed): 평소엔 추상적인 지도, 지정한 곳을 확대할 때만 시민의 생활을 보여 준다. 우리 홈에서 칸을 눌렀을 때만 자세히 보여 주는 구조와 같다.
- [PCGamesN: 베타 뒤 UI 재설계](https://www.pcgamesn.com/frostpunk-2/ui-improvements): 정보를 한 화면에 몰아넣었다가 비판받았다. 피할 점이다.
- [Julie Baechtold: 이벤트 삽화 스케치](https://www.artstation.com/artwork/K35AJx): 역동성보다 다큐 같은 구도와 가독성을 우선했다. 결정 카드 삽화 기준으로 쓸 만하다.
- [Robert Rejmak: 이벤트 일러스트](https://www.artstation.com/artwork/zxmbr4), [ZooWe Chen: 환경 컨셉](https://www.artstation.com/artwork/3EeBgo): 결정 결과 삽화의 톤, 서리 덮인 건물 실루엣.
- [ComputerBase 벤치마크](https://www.computerbase.de/2024-09/frostpunk-2-benchmark-test/): 날씨에 따라 조명이 바뀐다. 발상은 가져오고, 모바일에서 동적 전역 조명은 피한다.
- 못 연 것: Game UI Database(자동 접속 차단), [Xbox Wire 게임패드 UI 적용기](https://news.xbox.com/en-us/2025/09/18/adapting-frostpunk-2s-depth-to-a-gamepad/)(터치 UI에 참고할 가치가 커 보인다).

### Last Train Home

- [Ashborne 개발일지: 세계 만들기](https://ashbornegames.com/news/the-worldbuilding-of-last-train-home): 작전, 열차, 지도 세 화면으로 나뉜다. 역사 사진과 화가 세르게이 바소프를 참고했고, 게임을 위해 비율을 일부러 바꿨다. 동쪽으로 갈수록 풍경이 거칠어진다.
- [THQ Nordic: 실제 군단 열차 복제](https://thqnordic.com/news/the-train-is-real-a-look-behind-the-scenes-of-last-train-home-s-reveal-trailer): 작업칸, 주방, 의무칸, 포차 구성. 칸 종류를 정할 때 참고한다.
- [Game*Spark 체험기](https://www.gamespark.jp/article/2023/10/01/134648.html): 열차를 위에서 내려다보다가 줌아웃하면 필드로 넘어간다.
- [Peter Minďaš: 지도 화면](https://www.artstation.com/artwork/9Eb4AR), [같은 작가: O급 증기기관차](https://www.artstation.com/artwork/Za2RxR): 계절별 지도 변형, 기관차 형태.

### 궂은 날씨와 분위기

- [The Long Dark 화풍 튜토리얼](https://www.creativebloq.com/how-to/how-to-create-stylised-game-artwork): 날카로운 실루엣, 넓은 면에 은은한 질감, 차분한 색. 텍스처를 적게 쓰면서 분위기를 내는 방법이라 모바일에 잘 맞는다.
- [Pavel Panfilov: Pathologic 2 환경](https://www.artstation.com/artwork/L2O400): 불길한 러시아 소도시 분위기와 조명.
- [Markus Lovadina: Metro Exodus 컨셉](https://malo.artstation.com/projects/BmbG3A): 회색 블록 위에 분위기를 덧칠하는 작업 순서. 우리 시안 작업에도 쓸 수 있다.
- [GDC 2022: Horizon Forbidden West 폭풍](https://www.gdcvault.com/play/1027688/The-Real-Time-Volumetric-Superstorms): 위협을 연출하는 원리만 본다. 기법은 모바일에 무겁다.
- Wikimedia Commons 분류 [안개 속 열차](https://commons.wikimedia.org/wiki/Category:Trains_in_fog), [안개](https://commons.wikimedia.org/wiki/Category:Fog): 못 열었다. 사진을 쓸 일이 생기면 파일별 라이선스를 확인한다.

### 좀보이드 방식 (메모리 절약 근거)

- [Play Your Cardz Right (2023-02)](https://projectzomboid.com/blog/news/2023/02/play-your-cardz-right/): 2D 타일에서 깊이 정보를 만들고 한 번 그려 캐시한다. 3D 캐릭터가 그 깊이에 맞춰 가려진다.
- [42 Techdoid (2022-02)](https://projectzomboid.com/blog/news/2022/02/42-techdoid/): 청크 캐시는 속도를 얻는 대신 그래픽 메모리를 더 쓴다. 모바일에서는 이 대가가 크다.
- [차량 녹 텍스처 글](https://projectzomboid.com/blog/?p=7876): 차마다 텍스처를 따로 두지 않고 공용 녹 맵을 겹쳐 메모리를 아꼈다. 우리 칸의 서리·그을음·녹에 그대로 옮길 수 있는 방법이다.

### 옆 단면의 선례

- [Kotaku: This War of Mine 제작기](https://kotaku.com/the-making-of-a-very-different-kind-of-war-video-game-1560735762), [TechRaptor 아트 인터뷰](https://techraptor.net/content/art-war-mine-interview-11-bit-studios): 집을 잘라 여러 방을 동시에 보여 주고, 무채색 위에 색을 골라 넣는다.
- [Fallout Shelter 개요](https://fallout.wiki/wiki/Fallout_Shelter_Overview): 같은 방을 붙이면 합쳐지고, 사람은 늘 벽 앞에 그린다. 칸 확장 규칙과 가독성 규칙으로 참고한다.
- [Sheltered 프리뷰](https://stevivor.com/previews/preview-sheltered/): 낮은 해상도 옆 단면에서 물건끼리 구별이 안 된다는 비판. 텍스처를 아낄 때도 사람과 상호작용 물건의 실루엣은 지켜야 한다.

## 출처

- [PR 12: 월드 그래픽 정정과 3D 자원 조사](https://github.com/wndi1130-dot/APP/pull/12)
- [ACM SIGGRAPH: This War of Mine 개발팀 인터뷰](https://www.siggraph.org/news/indie-game-exposes-the-intimate-horror-of-war/)
- [11 bit studios: 프로스트펑크 RizomUV 작업 설명](https://11bitstudios.com/frostpunk_rizomuv/)
- [Adam Dyląg: Frostpunk 2 의회 얼룩](https://gunzes.artstation.com/projects/kNVK9d)
- [Milena Młynarska: Frostpunk 2 UX 사례 연구](https://www.milenamlynarska.com/uxui)
- [Andrii Krasavin: Metro Exodus 메인 메뉴](https://akrasavin.github.io/portfolio/projects/metro-exodus.html)
- [Project Zomboid 개발 블로그(2023-02, 렌더링 설명)](https://projectzomboid.com/blog/news/2023/02/play-your-cardz-right/)
- [Gematsu: Last Train Home 발표](https://www.gematsu.com/2023/06/world-war-i-real-time-strategy-game-last-train-home-announced-for-pc)
- [AUTOMATON: Last Train Home 출시 안내(일본어)](https://automaton-media.com/articles/newsjp/20231011-267716/)
- 프로스트펑크 1 디지털 아트북(11 bit studios, 스팀 판매물). 저작물이라 저장소에 올리지 않는다.
- PR 12에 없는 GPT 1판 브리프의 링크: [Blender glTF 설명서](https://docs.blender.org/manual/ja/4.5/addons/import_export/scene_gltf2.html), [Kenney 후원 안내](https://kenney.nl/support), [Unity URP 성능](https://docs.unity3d.com/kr/6000.0/Manual/urp/understand-performance.html), [Unity URP 데칼 셰이더 그래프](https://docs.unity3d.com/kr/6000.0/Manual/urp/prebuilt-shader-graphs-urp-decal.html)
