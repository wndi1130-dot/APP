# 이미지 프롬프트 2차 (GPT 이미지 모델용)

작성: 2026-10-06 · 쓰는 곳: GPT-6의 이미지 모델 2.5 · 결과물은 대화에 올리면 설계 세션이 s1/public/art/에 넣고 화면에 붙인다.

## 방향 (2026-10-06 결정)

- ~~그림은 옆 스크롤 픽셀 아트로 한다.~~ **2026-10-07 정정:** 월드와 홈은 픽셀이 아니라 좀보이드식 그래픽이다. 이 문서의 픽셀 문구와 프롬프트는 2026-10-06 시안 기록이다. 새 홈 시안과 프롬프트는 [reference_analysis.md](reference_analysis.md)에 있다.
- 분위기는 그대로 프로스트펑크 2와 This War of Mine이다. 결정·대화 화면의 형식은 수저린을 참고한다.
- 화면에 설명 문장을 두지 않는다. 자원과 계기는 아이콘과 숫자로, 칸의 수치는 칸을 눌렀을 때만 보여 준다.
- **더 어둡게 (2026-10-06, 마감 단계에서 한다):** 지금 시안들은 밝다. 다만 지금은 설계도(배치, 기능, 아이콘의 뜻)만 정하는 단계라, 분위기 보정은 프롬프트에 넣지 않고 마감 단계로 미룬다. 세기말의 어둡고 칙칙한 분위기로 간다. 참고: 프로스트펑크 1·2, This War of Mine, The Long Dark, 메트로 시리즈. 사람들은 모두 지쳐 있고 몇몇은 옷이나 붕대에 피가 배어 있다. UI·UX·레이아웃의 마감도 분위기에 맞게 자연스럽고 낡게 한다(메트로 적극 참고).
  - 피는 옷과 붕대의 얼룩까지만 그린다. 상처를 직접 그리지 않는다(콘텐츠 가이드 '쓰지 않는 것'). 피 표현은 앱의 연령 등급에도 영향을 준다.
  - 화면이 어두워져도 숫자, 아이콘, 단추는 또렷해야 한다. 폰은 밝은 곳에서도 본다.
  - 사용자 요청으로 프롬프트에 참고 작품 이름을 넣었다. 이름을 넣으면 원작과 닮게 나올 수 있으니 게임에 넣을 그림은 정리 단계에서 다시 본다.
- **작업 도구:** 에셋과 Blender 작업은 주로 Claude Opus로 한다. Fable 5.5가 나오면 그것을 주로 쓴다(사용자 계획).
- 홈 화면 구성은 [decisions.md](../design/decisions.md) '화면과 연출'에 적었다.

## 참고 자료

- [Game UI Database](https://www.gameuidatabase.com/gameData.php?id=1965): 게임 UI 화면을 모아 둔 사이트다. 프로스트펑크 같은 게임의 UI 화면을 볼 수 있다(2026-10-06 사용자가 찾음). 화면을 설계할 때 먼저 찾아본다.
- 프로스트펑크 1 아트북: 사용자 PC 바탕화면에 있다(2026-10-06 내려받음). 분위기, 색, 건물과 UI 소품을 정할 때 참고한다. 저작물이고 저장소가 공개라서 **저장소에는 올리지 않는다.** 클라우드 세션은 사용자 PC를 볼 수 없으니, 필요한 쪽만 대화에 캡처로 올려 보고 그 그림도 저장소에 넣지 않는다. 사용자 PC에서 돌리는 로컬 세션이면 파일을 바로 읽을 수 있다.

## 멈춘 곳 (2026-10-06)

이미지 생성 한도와 크레딧이 다 되어 여기서 멈췄다. 다시 시작할 때 할 일이다.

1. ④c 고친 아이콘 그림을 다시 받아 mockups/icons_c_v1.webp로 저장한다(평가는 통과).
2. ⑤ 칸 명판을 뽑는다(프롬프트 준비됨).
3. ①b 한눈에 보기를 평가대로 다시 뽑는다: 레버와 반원 계기, 짧은 이름표, 고른 칸과 창을 잇는 선, 2~3배 큰 열차, 칸 묶음, '수치만 보기'.
4. ③ 결정 카드를 새 배치로 다시 뽑는다: 홈 왼쪽 서류 뭉치에서 꺼내 왼쪽 절반만 덮고, 선택지에 즉시 바뀌는 불만·지지를 보여 준다.
5. decisions.md 열린 질문 8(사치품), 9(초상화 범위), 10(UI 그림 방식과 긴장 아이콘)을 정한다.
6. 설계가 굳으면 S1 화면 뼈대 코드에 옮긴다. 웹 모델에 맡길 작업 지시서를 먼저 쓴다.
7. 분위기 보정(더 어둡게, 낡게)은 마감 단계에서 한다.

## 홈 시안 평가 (2026-10-06, 사용자)

기준 그림(home_v2)을 보고 남긴 아쉬운 점이다. ①b와 ④ 프롬프트에 반영했다.

1. 칸 조절의 −/+ 단추가 마음에 들지 않는다. 프로스트펑크 2나 Claude Code의 추론 수준 고르기(낮음부터 최대까지 딱딱 끊기는 단계)처럼 단계 고르개로 바꾼다. 난방, 배급, 의약품도 같은 방식이다.
2. 열차는 지금도 좋지만, 폰에서 볼 것을 생각하면 조금 더 키운다.
3. 왼쪽 위 신임·긴장의 숫자(72, 28)만으로는 뜻이 읽히지 않는다. 숫자 옆에 짧은 눈금 막대를 붙이는 안을 ①b에서 시험한다.
4. 불만은 빨강, 지지는 파랑이나 하늘색으로 한다.
5. 자원 아이콘은 프로스트펑크 2의 자원 UI처럼 무엇인지 바로 읽혀야 한다. 지금 석탄은 석탄으로 안 보이고, 의약품 병은 총알처럼 보인다. 자원 아이콘만은 단색 대신 재료의 색을 살린다.
6. 사치품이 왜 있는지 모르겠다. 참고: S1 기획서에서 사치품은 뇌물 수단이고 앞칸이 바라는 물자다([s1_political_prototype.md](../prototype/s1_political_prototype.md) 거래 수단). 남길지는 따로 정한다([decisions.md](../design/decisions.md) 열린 질문).

## (마감 단계) 기준 그림 어둡게 (home_v2 첨부)

설계도 단계에서는 쓰지 않는다(2026-10-06 사용자). 마감 단계에서 기준 그림을 어둡게 고친 뒤, 그 결과를 새 기준 그림으로 삼아 다시 뽑는다.

```text
Edit the attached image. Keep the composition, the train, the HUD layout and the pixel art style. Make the whole scene darker and drearier, an end-of-the-world tone in the spirit of Frostpunk 1 and 2, This War of Mine, The Long Dark and the Metro series: night instead of dusk, lower light, deeper shadows, dirtier and more muted colors, soot and frost on the train, heavier snowfall. Only the windows and the firebox keep their warm amber glow. The refugees running beside the train look exhausted and underfed, and one has a bloodstained bandage, with no wounds or gore. Make the HUD panels look worn, with scratched brass, chipped paint and grime in the corners, while every icon and number stays clearly readable.
```

## ①b 한눈에 보기 시안 평가 (2026-10-06, 사용자)

시안은 [mockups/overview_v1.webp](mockups/overview_v1.webp)다. 사용자가 표시한 판은 [mockups/overview_v1_notes.webp](mockups/overview_v1_notes.webp)다. 파란 선은 원하는 열차 폭, 빨간 선은 고른 칸과 오른쪽 창을 잇는 선, 갈색은 긴장 아이콘을 가리킨다. 다음에 ①b를 다시 뽑을 때 아래를 고친다.

좋은 점

- 단추를 누르면 카메라가 위로 올라가 열차를 왼쪽으로 옮기고 오른쪽에 창을 펼치는 흐름이 좋다(배틀필드 1의 재배치 화면처럼).
- 새 자원 아이콘(석탄 수레, 빵, 알약과 병, 반지)은 매우 좋다. 그대로 간다.
- 기관사 초상이 잘 나왔다.

고칠 점

1. 칸막이 단계 고르개 대신 레버로 한다. 손잡이를 밀면 단계마다 딱 걸리고, 움직임은 Claude Code의 추론 수준 고르기처럼 부드럽다. 레버 위에는 배의 기관 전령기 같은 반원 계기를 둔다. 낮은 단계로도 모자라지 않으면 바늘이 가운데(중립)에 머물고, 최대로 당겨도 모자라면 바늘이 빨간 왼쪽으로 쏠린다. 난방, 배급, 의약품 모두 같다.
2. 의약품 아래 두 아이콘(사람들, 방패)이 무엇인지 읽히지 않는다. 글자를 너무 걷어냈다. 프로스트펑크처럼 조절과 정책에는 짧은 이름표를 단다. 문장은 여전히 쓰지 않는다.
3. 고른 칸(예: 기관실)과 오른쪽 창을 선으로 잇는다.
4. 열차가 너무 작다. 지금보다 2~3배(표시한 파란 폭쯤) 크게 그리고, 위아래로 스크롤한다.
5. 신임(72)과 긴장(28)의 그림을 바꾼다. 특히 긴장은 반란자인지 불만인지 뜻이 읽히지 않는다.
6. 위에서 보는 목적은 칸이 20~30개로 늘어도 내정을 한눈에 보고 배치하는 것이다. 지금은 예쁘지만 쓰기에 부족하다.
   - 같은 종류의 칸을 묶는다(예: 꼬리칸 세 개를 한 묶음으로).
   - 한눈에 보기 단추 옆에 '수치만 보기' 단추를 둔다. 프로스트펑크에서 발전기를 누르면 온기만 보이는 화면처럼, 또는 발표 자료의 입체 그래프처럼 칸 묶음마다 수치를 크게 보여 주고 거기서 배치를 정한다.

설계 세션 메모 (제안, 결정 아님)

- 반원 계기의 바늘이 무엇을 재는지 정해야 한다. 제안: 그 칸 묶음의 필요량 대비 공급량. 가운데는 충분, 왼쪽 빨강은 부족, 오른쪽 호박색은 남음(낭비)이다. 필요량은 바깥 기온, 인원, 아픈 사람 수에 따라 바뀐다.
- 칸을 묶으면 설정도 묶음 단위가 된다. 묶음을 공동체 단위로 하면 배급과 난방이 곧 공동체 정치가 되어 의회와 이어진다. 기관실과 열차장실처럼 하나뿐인 칸만 따로 다룬다.
- 열차를 2~3배 키우면 한 화면에 들어오는 칸이 줄어 '한눈에'와 부딪힌다. 평소 위 시점은 크게 보여 주고, '수치만 보기'가 전체를 작게 보여 주는 두 단계로 나누면 둘 다 살릴 수 있다.
- 긴장 아이콘 후보: 불붙은 도화선, 끊어지려는 밧줄, 맞부딪친 두 주먹. 이름표(신임, 긴장)를 같이 달면 그림의 부담이 줄어든다.

## ② 의회 시안 평가 (2026-10-06)

시안은 [mockups/council_v1.webp](mockups/council_v1.webp)다. 사용자는 아쉬운 점이 없다고 했고, 아래는 설계 세션의 판단이다.

잘 된 것

- 반원 의석과 공동체 쐐기, 쐐기 끝 명판, 전령기 바늘과 51·67 눈금, 큰 숫자 '46 / 51'이 한눈에 읽힌다.
- 고른 공동체에서 오른쪽 창으로 이어진 선, 지도자 초상(①b와 같은 얼굴), 의석·결속도, 거래 단추 다섯, 레버 모양의 표결 단추가 다 들어갔다.
- 이름표를 단 신임·긴장(Trust, Tension)이 그림만 있을 때보다 훨씬 잘 읽힌다. 이름표 방식을 유지한다.
- 투표함과 흰 돌·검은 돌이 장면 안에 있다.

맞출 것 (시안끼리 어긋난 것)

- 위 막대가 home_v2의 옛 모양으로 돌아갔다. 불만 띠가 빨강이 아니고, 석탄·의약품 아이콘도 옛것이다. 다음 시안부터는 HUD를 글로 못 박거나 새 HUD가 있는 그림을 첨부한다.
- 쐐기 명판이 즉석에서 그려졌다(밀 이삭 등). ⑤ 명판을 뽑은 뒤 통일한다.
- 법안 효과에 목재(통나무)가 나왔다. S1 자원이 아니다. 효과 줄에는 석탄, 식량, 의약품, 사치품, 온기처럼 실제 있는 값만 쓴다.
- 연단의 열차장이 기관실 대표와 같은 얼굴이다. 열차장은 다른 얼굴이어야 한다.

넣을 것 (코드에서)

- 나가기 단추. 의회에서 열차로 돌아가는 길이 보이지 않는다. 왼쪽 아래(홈의 메뉴 자리)에 둔다.
- 거래 단추마다 지금 드는 비용과 조건을 작게 표시한다(뇌물은 반지 수, 협박은 비밀 카드 수). 쓸 수 없으면 단추를 흐리게 한다. 공개 협상은 미이행 약속이 있으면 막힌다(기획서 8장).
- 오른쪽 창에 그 공동체의 미이행 약속과 빚을 기한과 함께 한 줄로 보여 준다.
- 예상 찬성은 점 하나가 아니라 폭으로 보여 준다. 결속도 때문에 약속한 표가 다 오지 않을 수 있어서다. 바늘 둘레의 옅은 부채꼴로 시험한다.
- 일반 법이면 67 눈금을, 통치 법이면 51 눈금을 흐리게 한다.
- 안건이 여럿이면 법안 창에 넘기는 화살표를 둔다.
- 법안 창의 제목 판을 채우려면 법안에 짧은 이름(title)이 있어야 한다. A1 스키마에 title을 더하는 일을 화면 작업 때 같이 한다(제안).

뺄 것

- 반원 양 끝의 0과 100 표시. 51·67 눈금만 있으면 된다.
- 배경(앞줄 사람들, 등잔, 컵)은 지우지 않고, 창이 열려 있을 때 더 어둡게 해서 대비를 높인다. 분위기를 만드는 장치다.

## ③ 결정 카드 시안 평가 (2026-10-06)

시안은 [mockups/card_v1.webp](mockups/card_v1.webp)다.

사용자 평가

- 수저린식 결정 카드로 잘 나왔다.
- 선택지에 '불만이 약간 증가', '지지가 약간 증가'처럼 정치 변화를 보여 준다. 희망 수치는 없으니 쓰지 않는다.
- 카드는 홈에서 뜬다. 아래에서 올라오는 대신 홈 왼쪽 빈 곳에 작은 서류 뭉치(멸망한 세상의 낡은 서류철)를 두고, 누르거나 끌어오면 펼쳐진다. 페이퍼스, 플리즈에서 서류를 끌어오는 방식이다.
- 지금은 화면의 3분의 2를 덮는다. 왼쪽 절반만 채운다.
- 초상화를 어떻게 할지 정해야 한다. 등장인물이 200~300명이라 AI로 많이 뽑아도 얼굴이 반복되고, AI 그림에 대한 거부감도 걱정된다. 중요 인물만 얼굴을 주고 나머지는 얼굴이 안 보이는 그림으로 대신하는 안도 있다.
- 선택은 하나하나 일지에 남긴다.

설계 세션 판단

- 위 막대가 이번에는 정해 둔 모양대로 나왔다(이름표 달린 신임·긴장, 빨강·하늘색 띠, 새 자원 아이콘). HUD를 글로 못 박는 방식이 통했다.
- 목격자 표시가 의회의 공개 투표 표시와 같은 눈 아이콘이다. 목격자는 다른 그림(사람 실루엣과 눈)으로 바꾼다.
- 왼쪽 절반에 넣으려면 초상을 작게 위로 올리고 선택지가 창의 너비를 다 쓰게 한다. 선택지는 가이드대로 15자 이내다.
- 서류 뭉치를 끌어오는 동작은 홈의 좌우 스크롤, 아이폰 사파리의 왼쪽 가장자리 뒤로 가기와 겹칠 수 있다. 누르기를 기본으로 하고, 끌기는 서류 뭉치 위에서 시작할 때만 받고, 서류 뭉치는 가장자리에서 조금 떨어뜨린다.
- 카드가 왼쪽 절반만 덮으면 오른쪽에 열차가 보인다. 카드와 관련된 칸으로 열차를 자동으로 스크롤하면 맥락이 같이 보인다.

## ④a 아이콘 판 평가 (2026-10-06)

판은 [mockups/icons_a_v1.webp](mockups/icons_a_v1.webp)다. 설계도 단계라 뜻이 읽히는지만 본다. 자르고 배경을 따는 일은 에셋 단계에서 한다(이번 판은 흰 배경).

- 그대로 쓸 것: 석탄 수레, 빵, 알약과 병, 반지, 맞잡은 손(신임), 주먹(빨간 소매)과 편 손(파란 소매), 일지 책, 서류 뭉치, 수치 막대, 돌아가기, 불꽃.
- 긴장은 나중에 정한다(2026-10-06 사용자). 프로스트펑크 2처럼 일렁이는 애니메이션을 붙일지와 같이 본다. 그때까지 후보 셋을 남겨 둔다. 설계 세션 추천은 끊어지려는 밧줄(8번)이다. '팽팽하다가 끊어지기 직전'이 긴장의 뜻에 가장 가깝다. 도화선은 폭탄으로, 금 간 유리는 '이미 깨짐'으로 읽힌다.
- 한눈에 보기(13번)가 세로 막대처럼 보여 뜻이 읽히지 않는다. 다음에 다시 뽑는다(예: 위에서 본 열차를 가로로 눕히고 지붕 칸을 또렷하게, 또는 열차 윤곽이 그려진 도면 한 장).

## ④b 아이콘 판 평가 (2026-10-06)

판은 [mockups/icons_b_v1.webp](mockups/icons_b_v1.webp)다. 뜻이 읽히는지만 본다.

- 그대로 쓸 것: 열린 눈(공개 투표), 그림자 인물(목격자), 세 사람(과밀), 악수와 서류(공개 협상), 봉투(사적 부탁), 주머니와 반지(뇌물), 난로(난방), 그릇과 빵(배급), 매듭(결속도).
- 헷갈리는 짝 둘
  - 투표함(2번)과 보급 상자(7번)가 둘 다 나무 상자다. 투표함을 쇠 상자로 바꾸고 흰 돌이 들어가는 모습을 넣는다.
  - 봉투(6번 사적 부탁)와 봉인 서류(9번 협박)가 둘 다 검은 봉인이 찍힌 종이다. 협박은 자물쇠로 잠근 서류철로 바꾼다.
- 보급 상자의 지도 핀은 요즘 지도 앱 기호라 세계와 맞지 않는다. 손수레에 실은 상자로 바꾼다.
- 목격자는 '첩자'로도 읽힐 수 있다. 목격자 규칙과 뜻이 가까워서 그대로 둔다.

## ④c 고칠 아이콘 4개 (icons_a_v1, icons_b_v1 첨부)

④a의 한눈에 보기와 ④b에서 헷갈린 셋을 다시 뽑는다.

```text
Match the pixel style and icon designs of the attached images.

A sprite sheet of four pixel-art UI icons in a 2 by 2 grid on a transparent background (if transparency is not possible, a pure black #000000 background). Each icon is drawn on its own 32 by 32 pixel grid and shown enlarged with hard square pixels, centered in its cell with generous padding, same scale, light from the top left, a dark outline, no smoothing, no text, no frames, cream-white (#EDE6D6) with a small accent where noted.
1) overview: a whole train seen from directly above, lying horizontally, with clearly separated car roofs and a small locomotive at the right end, drawn on a sheet of plan paper with a folded corner;
2) secret vote: a dark iron ballot box with a slot and a white stone dropping into it, clearly different from a wooden crate;
3) leverage: a closed document folder held shut by a small padlock (red accent), clearly different from an envelope;
4) supply: a wooden crate on a small two-wheeled handcart (amber accent), with no map pin.
```

## ④c 고친 아이콘 평가 (2026-10-06)

넷 다 통과다. 그림 파일은 아직 저장하지 못했다(대화 중에 올라온 그림이 세션에 파일로 남지 않았다). 다시 올리면 mockups/icons_c_v1.webp로 넣는다.

- 한눈에 보기: 도면 위에 가로로 누운 열차라 뜻이 읽힌다.
- 비밀 투표: 쇠 투표함이라 보급 상자와 헷갈리지 않는다. 돌 대신 종이가 들어가는데, 아이콘에서는 종이가 더 잘 읽혀서 그대로 둔다. 장면 속 투표는 흰 돌·검은 돌 그대로다.
- 협박: 자물쇠 서류철이라 봉투와 갈린다.
- 현장 조달: 손수레 위 상자라 지도 핀이 없어졌다.

이로써 아이콘은 긴장만 남았다(UI 그림 방식과 같이 정한다, decisions.md 열린 질문).

## 쓰는 법

1. **기준 그림**은 사용자가 고른 홈 시안(픽셀 아트, 옆에서 본 열차)이다. ① 수정까지 마친 판을 [mockups/home_v2.webp](mockups/home_v2.webp)에 두었다(2026-10-06 확정).
2. ① 수정은 기준 그림을 첨부하고 글상자를 붙여 넣는다. 새로 그리는 게 아니라 고치라는 프롬프트다. 결과가 마음에 들면 그게 새 기준 그림이 된다.
3. ①b부터는 새 기준 그림을 첨부하고 글상자를 붙여 넣는다. 글상자 첫 문장이 "첨부한 그림과 같은 화풍으로"라는 뜻이다.
4. 아이콘과 명판은 한 장에 여러 개를 격자로 뽑는다. 자르는 건 설계 세션이 한다.
5. 투명 배경이 안 되면 순검정 배경으로 받는다.
6. 이 대화에는 완성된 그림만 올리고 번호(예: ④)를 같이 적는다.
7. 시안(①, ①b, ②, ③)은 배치와 분위기를 정하는 용도라 게임에 그대로 넣지 않는다. 글자는 깨져도 괜찮다.

### 주의

- **AI가 그린 픽셀 아트는 격자가 맞지 않는다.** 1차 시안에서도 연기 픽셀이 나무 픽셀보다 컸다. 게임에 넣는 그림은 설계 세션이 픽셀 격자를 맞추고 색 수를 줄여서 넣는다. 그래서 큰 그림 한 장보다 칸 하나, 아이콘 하나처럼 작게 나눠 뽑는 편이 낫다.
- **게임 이름은 프롬프트에 넣지 않았다.** 화풍은 첨부한 기준 그림에서 이어받는다. 이름을 넣으면 원작 자산과 너무 닮게 나올 수 있다.
- 이미지에 한글을 쓰게 하지 않는다. 글자는 게임 코드에서 아래 폰트로 얹는다.
- 의약품 아이콘에 붉은 십자를 쓰지 않는다. 적십자 표장은 법으로 보호된다.

## 폰트

**2026-10-07 정정:** UI가 매끈한 두 재질로 정해져(decisions.md 열린 질문 10) 아래의 갈무리 추천은 쓰지 않는다. 매끈한 폰트 쪽(Barlow Condensed, IBM Plex Sans KR 같은 계열)으로 가고, 어느 폰트를 쓸지는 아직 정하지 않았다. 아래는 2026-10-06 픽셀 시안 때의 기록이다.

픽셀 아트로 바뀌어서 1차에 찾은 프로스트펑크 2의 폰트(Barlow Condensed, Crimson Pro, Cormorant Garamond, [Game Font Library](https://www.gamefontlibrary.com/games/frostpunk-2) 기준, 미확인)는 화면과 어울리지 않는다. 매끈한 글자가 픽셀 그림 위에 뜨면 따로 노는 것처럼 보인다.

| 쓰임 | 추천 | 비고 |
|---|---|---|
| 숫자, 단추, 짧은 이름표 | 갈무리(Galmuri) | 한글 픽셀 폰트. [저장소](https://github.com/quiple/galmuri), OFL로 알고 있다(쓰기 전에 저장소의 라이선스를 다시 확인) |
| 일지, 대사, 카드 본문 | 갈무리11을 먼저 시험 | 폰에서 긴 글이 읽기 힘들면 본문만 Pretendard(OFL) 같은 깔끔한 고딕으로 바꾼다. 기기에서 직접 보고 정한다 |

## 공통 화풍

아래 글상자마다 이미 들어 있다. 문구를 고칠 때만 여기를 본다.

```text
Visual style: high-quality 2D pixel art for a side-scrolling mobile game about a steam train crossing a frozen Central Europe in the sixth winter after a collapse. The whole image uses one uniform pixel size: snow, smoke, trees, people and UI all sit on the same pixel grid, with crisp hard edges, no blur, no smooth gradients and no mixed resolutions. Limited palette with careful dithering: deep blue and violet snow, black pine forests, a faint orange-pink band on the horizon, and warm amber window light and firebox glow as the only saturated accents; reflections on dark water and ice. Several parallax layers of landscape. Quiet, grim and humane rather than heroic. UI: dark navy panels with thin brass borders and angled corners, cream-white pixel icons, condensed pixel numerals, almost no text. Avoid: readable words unless asked, logos, watermarks, modern objects, gore, neon, 3D render look, painterly brush strokes, anime style, red cross symbols.
```

## ① 홈 화면 수정 (기준 그림 첨부)

끝났다. 결과가 [mockups/home_v2.webp](mockups/home_v2.webp)다.

```text
Edit the attached image. Keep its pixel art style, palette, lighting, parallax landscape and HUD frames as they are, and keep every element on the same small pixel size (the smoke must use the same pixels as the trees). Make these changes:
1) Scale the train up to about 1.6 times its current size so the car bodies fill roughly 40% of the screen height. The train is now longer than the screen: show five middle cars fully, with the tail car cut off at the left edge and the locomotive cut off at the right edge, like a horizontally scrolling view. Keep the cut-away interiors and the cold-blue-to-warm-amber lighting from tail to front.
2) Hang a small iron plaque with a simple pixel emblem above each car's door to show its function; no text.
3) One car is selected: it has a thin brass outline, and a small dark pop-up panel floats above it with two rows, a flame icon with a short bar and a crowd icon with a short bar, each with small round minus and plus buttons.
4) Outside, beside the rear cars, a few refugees in layered coats run through the snow reaching toward the train; far behind, dark stumbling silhouettes follow the train. No blood or gore.
5) HUD: top-left shows two meters instead of the pressure gauge and thermometer: two gloved hands clasped (trust) and a cracked glass pane (tension), each with a number. On the top-center bar, replace the two head icons with round buttons, a raised clenched fist at the left end (discontent) and a raised open palm at the right end (support), and put a few grey segments between the two colors for neutral. Bottom-left: keep the round menu button and add a small closed-book button next to it (the log). Bottom-center: keep the five-step route line and add a small square button above it with a top-down train icon (overview). Bottom-right: keep the arrow button and add a blank label plate on it for one short word.
```

## ①b 한눈에 보기 화면 (새 기준 그림 첨부)

열차가 10~20칸으로 늘어도 한 화면에서 보고 관리하는 화면이다.

```text
Match the art style, palette, line work and HUD design of the attached reference image.

Visual style: high-quality 2D pixel art for a side-scrolling mobile game about a steam train crossing a frozen Central Europe in the sixth winter after a collapse. The whole image uses one uniform pixel size, with crisp hard edges, no blur, no smooth gradients and no mixed resolutions. Limited palette with careful dithering; warm amber light as the only saturated accent. Quiet, grim and humane. UI: dark navy panels with thin brass borders and angled corners, cream-white pixel icons, condensed pixel numerals, almost no text. Avoid: readable words, logos, watermarks, modern objects, gore, neon, 3D render look, painterly brush strokes, red cross symbols.

Mobile game screen mockup, very wide landscape (about 2.2:1). The camera has risen above the train: a top-down view of a longer train of twelve cars with the roofs removed, so each car shows its floor plan (bunks, stoves, long tables, lockers, a desk with maps, upholstered seats, the locomotive's boiler and glowing firebox). The train stands vertically along the left third of the screen, locomotive at the top and tail at the bottom, on a track over snowy ground with a few pines. Each car has a muted color tint and outline by type so types read at a glance: tail cars cold grey-blue, tech and medical teal, dining car amber, guard car olive, captain's car gold, front cars burgundy, locomotive rust red. The locomotive car is selected and a dark panel has slid out over the right two-thirds: at its top the engine crew's pixel emblem and a small pixel portrait of their representative; below that two stat rows with icons and short gauges (warmth, crowding); below that three control rows for heating, rations and medicine, each a horizontal stepped selector with five discrete notches from lowest to highest, the current notch lit in amber, like a level picker, with no plus or minus buttons; and at the bottom two policy rows, each with a small icon and a pixel toggle switch.
HUD changes from the reference: on the top-center bar the discontent part is red and the support part is sky blue, with a few grey neutral segments between them; in the top-left panel each meter shows a short segmented gauge next to its number (trust in blue, tension in red-orange); the top-right resource icons are clearer and use muted natural colors: coal as a small iron mine cart heaped with black coal and a faint ember, food as a brown loaf of bread, medicine as a two-tone pill capsule beside a squat brown bottle, luxury goods as a small gold ring. At the bottom center the overview button now shows a side-view train icon for returning.
```

## ② 의회 화면 시안 (그림 두 장 첨부: home_v2, overview_v1)

①b 평가를 반영했다: 쓰임이 먼저(예상 찬성 수와 필요 수를 숫자로), 고른 묶음과 창을 잇는 선, 조절과 단추의 짧은 이름표(영어 자리표시, 게임에서는 한글로 바꾼다), 전령기 바늘. 거래 단추 다섯은 [S1 기획서](../prototype/s1_political_prototype.md) 8장의 거래 수단이다.

```text
Match the pixel art style and HUD of the first attached image, and the side-panel design and portrait style of the second attached image.

Visual style: high-quality 2D pixel art for a mobile political survival game set on a steam train in a frozen Central Europe, sixth winter after a collapse. One uniform pixel size, crisp hard edges, no blur, no smooth gradients, no mixed resolutions; limited palette with careful dithering; cold blues with warm amber lamp light. Quiet, grim and humane. UI: dark navy panels with thin brass borders and angled corners, cream-white pixel icons, condensed pixel numerals. Short one-word labels in plain English are allowed on buttons and panels as placeholders; no sentences. Avoid: logos, watermarks, modern objects, gore, neon, 3D render look, painterly brush strokes, red cross symbols.

Mobile game screen mockup, very wide landscape (about 2.2:1): the council session in the dining car. The background is the dining car interior seen from the side and dimmed: long tables pushed to the walls, representatives of five communities in their work clothes, oil lamps, frosted windows with snow streaking past, and a wooden ballot box with bowls of white and black stones near the captain's lectern.
Center: a large semicircle seat chart of one hundred pixel seats, split into five wedges, one per community, each wedge marked at its outer edge with that community's small iron plaque emblem. Seat states: sky-blue filled = yes, red filled = no, small grey = undecided, dashed outline = absent on a field mission. A brass needle pivots at the center of the semicircle like a ship's engine telegraph and points to the projected yes count; brass tick marks on the outer arc at 51 and 67; under the semicircle, large pixel numerals show the projected yes count against the needed count (for example 46 / 51).
Left: a narrow bill panel with a short title plate, a small icon showing whether the vote is public (an open eye) or secret (a closed ballot box), and two or three effect rows that show what the law changes as icons with plus or minus signs (for example coal minus, warmth plus).
Right: the engine-crew wedge is selected; a thin brass line runs from that wedge to a dark panel that has slid out on the right, styled like the second attached image: the community's emblem and the leader's pixel portrait at the top, a seat count and a short cohesion gauge, then five trade buttons in a column, each with an icon and a one-word label: Negotiate (a handshake over a paper), Favor (a sealed envelope), Supply (a crate with a map pin), Bribe (a small gold ring), Leverage (a wax-sealed file).
Bottom right: one large vote button with a lever icon and the label Vote. Keep the top HUD of the first attached image, and add a tiny one-word label under each top-left meter (Trust, Tension).
```

## ③ 결정 카드 시안: 수저린 형식 (그림 두 장 첨부: council_v1, overview_v1)

②까지의 평가를 반영했다. HUD를 글로 못 박고, 비용은 지금 확실한 것만 보여 준다(가이드 2장). 초상은 둘째 인물(파블라 크레이치)로 뽑아 ⑥을 미리 시험한다.

```text
Match the pixel art style, the labelled HUD meters and the panel design of the first attached image, and use the resource icons and the red-and-sky-blue discontent-support bar of the second attached image.

Visual style: high-quality 2D pixel art for a mobile political survival game set on a steam train in a frozen Central Europe, sixth winter after a collapse. One uniform pixel size, crisp hard edges, no blur, no smooth gradients, no mixed resolutions; limited palette with careful dithering; cold blues with warm amber lamp light. Quiet, grim and humane. UI: dark navy panels with thin brass borders and angled corners, cream-white pixel icons, condensed pixel numerals. Short labels in plain English are allowed as placeholders; no long text. Avoid: logos, watermarks, modern objects, gore, neon, 3D render look, painterly brush strokes, red cross symbols.

Mobile game screen mockup, very wide landscape (about 2.2:1). The side view of the train from the home screen is dimmed in the background, and a decision panel has slid up from the bottom, covering about two-thirds of the screen height, with a small chevron tab on its top edge for folding it away. Left third of the panel: a large, detailed pixel-art portrait of the speaker, Pavla Krejčí, a 41-year-old Czech refugee who speaks for the tail car: thin face, wind-chapped cheeks, dark hair tied under a knitted scarf, several patched coats layered, tired but sharp eyes, chin slightly raised; under the portrait a small name plate and the tail car's iron emblem (a coal shovel crossed with a tin cup). Right two-thirds, laid out like a paper dossier with thin brass rules: one short line of dialogue in placeholder English, then three stacked numbered choice plates. Each plate has a two- or three-word label and, on its right, only the costs that are certain now, shown as resource icons with minus numbers (for example coal -10, food -5); no arrows or faces predicting how people will react. One plate also carries a small eye icon meaning someone will witness this choice. Keep the top HUD: Trust and Tension meters with their labels on the left, the red-and-sky-blue bar with fist and open-palm buttons in the center, and coal cart, bread, pill and bottle, and ring icons with numbers on the right.
```

## ④ 아이콘 판 두 장 (그림 두 장 첨부: card_v1, council_v1)

②·③까지 나온 아이콘을 모두 모았다. 한 장에 너무 많으면 작아지고 흔들려서 두 장으로 나눴다. 긴장은 사용자 요청대로 다른 그림 둘을 같이 뽑아 고른다. 설계 세션이 잘라 `s1/public/art/icons/`에 넣는다.

- ④a(16개): res_coal, res_food, res_medicine, res_luxury, meter_trust, meter_tension_glass, meter_tension_fuse, meter_tension_rope, bar_discontent, bar_support, btn_log, btn_dossier, btn_overview, btn_dataview, btn_return, stat_warmth
- ④b(12개): vote_public, vote_secret, mark_witness, stat_crowding, trade_negotiate, trade_favor, trade_supply, trade_bribe, trade_leverage, ctrl_heating, ctrl_rations, stat_cohesion

```text
Match the pixel style and the icon designs of the attached images.

Keep the four resource icons exactly as they appear in the first image.

A sprite sheet of sixteen pixel-art UI icons in a 4 by 4 grid on a transparent background (if transparency is not possible, a pure black #000000 background). Each icon is drawn on its own 32 by 32 pixel grid and shown enlarged with hard square pixels, centered in its cell with generous padding, same scale, light from the top left, a dark outline, no smoothing, no text, no frames. Icons 1 to 4 use muted natural colors; the others are cream-white (#EDE6D6) with a small accent color where noted.
Row 1: 1) coal: a small iron mine cart heaped with black coal and a faint ember; 2) food: a brown loaf of bread; 3) medicine: a two-tone pill capsule beside a squat brown bottle, no cross; 4) luxury goods: a small gold ring with a gem.
Row 2: 5) trust: two gloved hands clasped (blue accent); 6) tension: a cracked glass pane (red-orange accent); 7) tension, alternative: a short burning fuse with sparks (red-orange accent); 8) tension, alternative: a taut rope starting to fray in the middle (red-orange accent).
Row 3: 9) discontent: a raised clenched fist (red accent); 10) support: a raised open palm (sky-blue accent); 11) log: a closed book with a ribbon bookmark; 12) pending decisions: a worn bundle of papers tied with string, with a small red wax seal.
Row 4: 13) overview: a train seen from directly above, a long rectangle split into car segments; 14) data view: three vertical bars of different heights on a small brass plate; 15) return: a left-pointing arrow above a small side-view train; 16) warmth: a small flame (amber accent).
```

```text
Match the pixel style and the icon designs of the attached images, especially the trade button icons in the second image.

A sprite sheet of twelve pixel-art UI icons in a 4 by 3 grid on a transparent background (if transparency is not possible, a pure black #000000 background). Each icon is drawn on its own 32 by 32 pixel grid and shown enlarged with hard square pixels, centered in its cell with generous padding, same scale, light from the top left, a dark outline, no smoothing, no text, no frames. All icons are cream-white (#EDE6D6) with a small amber accent where noted.
Row 1: 1) public vote: an open eye; 2) secret vote: a closed wooden ballot box with a slot; 3) witness: the head and shoulders of a shadowy figure with one bright eye, clearly different from the open eye; 4) crowding: three standing figures pressed together.
Row 2: 5) negotiate: a handshake over a sheet of paper; 6) favor: a sealed envelope; 7) supply: a wooden crate with a map pin (amber accent); 8) bribe: a small drawstring pouch with a gold ring on top (amber accent).
Row 3: 9) leverage: a folded document with a black wax seal; 10) heating: a small cast-iron stove with a glowing door (amber accent); 11) rations: a bowl beside a slice of bread; 12) cohesion: a tight rope knot.
```

## ⑤ 칸 명판 8개 (그림 두 장 첨부: home_v2, council_v1)

①에서 칸 문 위에 거는 명판이자 공동체 문장이다. 시안들에서 잘 읽힌 문장(방패, 안락의자, 기어와 약병, 나침반)을 살려 통일했다. 식당칸은 투표함 대신 식탁으로 한다. 투표함은 비밀 투표 아이콘과 겹친다. 설계 세션이 잘라 `s1/public/art/emblems/`에 넣는다.

```text
Match the pixel style of the attached images, especially the small iron plaques hanging above the car doors in the first image.

A sheet of eight small pixel-art plaques in a 4 by 2 grid on a transparent background (if transparency is not possible, a pure black #000000 background). Each plaque is a small dark iron sign with riveted corners hanging from two short chains, carrying one cream-white pixel emblem; all the same size, readable at 32 pixels, no text. Left to right, top to bottom: 1) tail-car workers: a coal shovel crossed with a dented tin cup; 2) engine crew: a locomotive driving wheel with a spanner across it; 3) guard: a plain shield; 4) technicians and medics: a gear beside a small medicine bottle, no cross; 5) front-car passengers: an upholstered armchair; 6) captain: a compass; 7) dining car: a long table under a hanging lamp; 8) workshop, for later: an anvil with a hammer.
```

## ⑥ 초상 두 장

`s1/public/art/portraits/`에 넣는다. 첫째 초상에는 ③의 결과(초상이 마음에 들면)나 새 기준 그림을, 둘째 초상에는 첫째 초상을 첨부한다.

```text
Match the pixel style of the attached reference image.

A detailed pixel-art portrait for a dialogue panel, vertical 3:4, half-length, facing the viewer, plain dark navy background with a faint warm rim light from the left, one uniform pixel size, limited palette, crisp pixels. Henryk Mazurek, 67, a retired Polish volunteer engine driver from a steam depot: weathered face, soot in the wrinkles, white stubble, wool flat cap, heavy dark railway jacket with brass buttons, calm and stubborn eyes.
```

```text
Match the pixel style and framing of the attached reference portrait.

A detailed pixel-art portrait for a dialogue panel, vertical 3:4, half-length, facing the viewer, plain dark navy background with a faint cold rim light from the right, one uniform pixel size, limited palette, crisp pixels. Pavla Krejčí, 41, a Czech refugee from Brno who now speaks for the tail car: thin face, wind-chapped cheeks, dark hair tied under a knitted scarf, several patched coats layered, tired but sharp eyes, chin slightly raised.
```

## 다음 차례

- 게임에 넣을 그림은 나눠서 뽑는다: 칸 일곱 개(옆 단면, 한 칸씩), 배경 층(먼 숲, 가까운 숲, 눈밭), 연기, 사람과 망자 걸음 그림.
- 화면 뼈대 고치기: 위 결정대로 홈을 옆 스크롤로 바꾸고, 칸 수치는 누르면 뜨게 하고, 일지는 책 단추로 옮기고, 설명 문장을 걷어낸다. 아이콘이 들어오면 같이 한다.
