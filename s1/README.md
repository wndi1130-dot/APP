# S1 프로젝트와 콘텐츠 검사기

[A1]의 정적 웹 프로젝트 뼈대와 콘텐츠 검사 도구다. 게임 로직과 화면은 아직 없다. `src/main.ts`는 빈 모듈이며 Vite는 정적 파일만 빌드한다. 별도 서버나 실시간 문장 생성은 없다.

기준 문서는 [공통 규칙과 A1](../docs/handoff/codex_tasks.md), [설계 결정](../docs/design/decisions.md), [S1 기획서](../docs/prototype/s1_political_prototype.md), [콘텐츠 가이드 1·2·5장](../docs/prototype/s1_content_guide.md)이다. `docs/`는 수정하지 않았다. 예제 문장은 검사 전용 창작 샘플이다.

## 설치와 확인

Node.js 20.19 이상인 20 계열 또는 22.12 이상을 사용한다. 의존성 버전은 `package-lock.json`으로 고정했다.

```sh
cd s1
npm ci
npm test
npm run build
npm run validate -- fixtures/valid
npm run validate -- fixtures/invalid
```

통과 예제 검사는 종료 코드 0, 실패 예제 검사는 종료 코드 1이어야 한다. `npm test`가 실패 예제 여덟 파일 각각의 실패와 항목별 진단을 확인한다. `npm run build`는 TypeScript 검사와 Vite 정적 빌드다. `npm run dev`, `npm run preview`는 로컬 확인용 Vite 도구다.

## 검사할 데이터

```sh
npm run validate -- ./data
npm run validate -- "./검사할 데이터"
```

폴더와 하위 폴더의 `.json` 파일을 읽는다. 파일 하나에는 단일 콘텐츠 객체 또는 객체 배열을 넣는다. BOM과 대문자 `.JSON` 확장자도 처리한다. 심볼릭 링크는 범위를 벗어날 수 있어 오류로 보고한다. 입력 폴더가 없거나 비어 있을 때, 빈 배열이나 깨진 JSON일 때도 실패한다.

종류는 선택 필드 `content_type`, 파일·폴더 이름, 객체의 특징적인 필드 순으로 판별한다. 예를 들어 `profiles.json`은 프로필 배열, `character.json`은 인물 객체로 읽는다. 여러 종류가 섞인 배열은 `mixed.json` 같은 이름을 쓰고 각 객체에 `content_type`을 넣으면 명확하다. `content_type`은 여덟 종류 중 하나여야 한다. 기존 가이드의 객체에는 이 필드가 없어도 된다.

오류와 경고에는 파일명, JSON Pointer 경로, 검사 코드, 한국어 이유가 나온다. 배열에서는 `/1/age`처럼 항목 인덱스도 붙는다.

```text
오류 …/profile.json:/age [schema.maximum] 값은 85 이하여야 합니다.
오류 …/event.json:/choices/0/label [schema.maxLength] 글자 수가 15자 이하여야 합니다.
경고 …/character.json:/bio [rule.trait_label] 성향을 딱지처럼 붙이지 말고 행동으로 드러내세요. …
```

오류가 하나라도 있으면 종료 코드 1, 경고만 있으면 0이다. 인자가 빠지거나 너무 많으면 사용법과 종료 코드 2를 반환한다. `--help`는 사용법과 종료 코드 0을 반환한다.

## 스키마와 길이

`schema/`의 스키마는 모두 JSON Schema draft 2020-12다. Ajv의 2020-12 구현으로 검사하며 외부 스키마를 다운로드하지 않는다. 공통 값은 `common.schema.json`, 효과는 `effects.schema.json`, 문장 규칙은 `content_rules.json`에 있다. 각 스키마는 필수 필드와 열거값을 검사하고 알려지지 않은 필드를 거부한다.

| 종류 | 주요 제한 |
|---|---|
| `profile` | 나이 0~85 정수, 공동체·출신·탄 경위·상태 열거, 한 줄 40자 |
| `character` | 프로필 필드 포함, 역할·성향·말투 열거, 비밀 0~2개, 관계 1~3개, 가중치 정확히 2개, 소개 3문장 |
| `secret` | 가이드의 비밀 종류와 출처 열거, 심각도 1~3 정수, 소문·증거 열거, 본문 2문장 |
| `event` | 단계·진행 시점·발언자 열거, 본문 120자·3문장, 선택지 2~4개, 선택지 문구 15자 |
| `law` | 일반·통치 법 열거, 세 축의 입장, 효과와 기록 참조 |
| `deal` | 거래 수단 다섯 가지, 구간 기한은 음수가 아닌 정수, 요구·대가·위반 효과 |
| `place` | 장소 여섯 가지, 위험도 1~3 정수, 자원 가중치는 음수 불가 |
| `chronicle` | 기록 주체·사건·장소·구간·이유·목격자·틀, 구간은 음수가 아닌 정수, 증언 2문장 |

글자 수는 JSON Schema의 Unicode 코드 포인트 기준이다. 소개, 사건 본문, 비밀 본문, 증언의 문장 수는 한국어 `Intl.Segmenter`로 세고 줄바꿈도 경계로 취급한다. 문장 끝에 종결 부호가 없어도 마지막 문장을 센다. 약어와 복잡한 인용문의 문장 경계에는 사람 검수가 필요하다. 한 줄과 선택지 문구는 줄바꿈을 허용하지 않는다. A3의 문장 작성 전 프로필을 위해 `line`은 빈 문자열을 허용한다.

200명, 이름 있는 인물 11~13명은 전체 런의 생성 분량이다. 개별 콘텐츠 스키마와 임의 폴더 검사에는 그 전체 분량을 강제하지 않는다. A3에서 생성 분포를 확인한다.

## 가이드가 세부 형식을 정하지 않은 필드

아래는 A1에서 정한 최소 데이터 계약이다. A2 이후 확장이 필요하면 데이터와 스키마를 함께 바꾼다. 효과 실행이나 조건 평가는 여기서 구현하지 않는다.

- 모든 항목에 `id`를 둔다. `p_001` 예시에 맞춰 소문자로 시작하고 소문자·숫자·밑줄을 허용한다.
- `relations`: `{ target, kind }`. `kind`는 `family`, `friend`, `enemy`다.
- `debts`: `{ person, direction, reason }`. `direction`은 갚을 빚 `owed_to`, 받을 빚 `owed_from`이다.
- `weights`: `[집단 이익, 개인 이익]` 순서의 음수가 아닌 수 두 개다. 합을 1로 강제하지 않는다.
- `voice`: 공동체 키 다섯 가지와 세력 키 `engine_faith`, `restoration`, `adaptation`이다.
- `secret.kind`, `secret.sources`는 가이드에 명시된 한국어 열거값을 그대로 쓴다. 출처는 중복 없이 1~4개다.
- `trigger`, `opens_when`: 조건 객체 배열이다. 빈 배열은 추가 조건이 없다는 뜻이다. `segment`는 `{ type, min, max }`, `community`는 `{ type, community, metric, operator, value }`, `flag`는 `{ type, id, value }`, `person`은 `{ type, id, state }`다. 구간 범위가 뒤집히면 검사기에서 거부한다.
- `stances`: `ration`은 `equal/contribution/neutral`, `authority`는 `discipline/practical/neutral`, `technology`는 `restoration/adaptation/neutral`이다.
- 법안의 `chronicle`은 `{ passed, rejected }` 참조다. 사건의 `chronicle`은 중요한 사건에만 넣는 선택 참조다.
- `loot`: `coal`, `food`, `medicine`, `luxury` 가중치 네 개다. 없는 자원은 0으로 쓴다. 상징물은 `symbols` 참조 목록에 따로 둔다.
- `witnesses`: 목격자 id 또는 `{ person, text }` 증언 객체 목록이다. 사건 선택지와 일대기 모두 같은 형식을 쓴다.

## 효과 어휘

| `type` | 필요한 인자 |
|---|---|
| `coal`, `food`, `medicine`, `luxury` | `amount`: 변화량 |
| `symbol`, `secret` | `id`, `amount`: 정수 변화량 |
| `community.warmth`, `community.ration`, `community.crowding`, `community.exposure` | `target`: 공동체, `amount` |
| `trust`, `tension`, `fear` | `amount` |
| `relation`, `cohesion`, `votes` | `target`: 집단 참조, `amount` |
| `person.state` | `target`: 사람 참조, `state` |
| `person.away` | `target`, `segments`: 음수가 아닌 구간 수 |
| `flag` | `id`, `value`: 불리언·수·문자열 |
| `followup` | `id`: 사건 참조, `delay`: 음수가 아닌 구간 수 |
| `deal`, `chronicle` | `id`: 해당 콘텐츠 참조 |

가이드 1.9의 흐름 효과 네 가지를 마지막 네 키로 표현했다. 모르는 효과와 잘못된 인자는 실패한다. 실제 효과 적용은 A2의 범위다.

## 문장 규칙과 검수 범위

규칙 파일의 `text_fields`에 지정한 이름·소개·본문·선택지·요약·증언만 검사한다. 참조 id, 숨겨진 성향, 공동체 같은 코드값은 문장 검사 대상이 아니다.

- 오류: 등록된 실제 총기 제조사·모델명, 대사의 ‘좀비’, 수용소·강제 이송 어휘와 일부 직접 모방 표현, 문장에 드러난 도덕·선악 수치.
- 경고: 성향 딱지와 가이드의 상투어. ‘가족’은 금지하거나 경고하지 않는다.
- 사건 본문·선택지와 증언은 대사로 검사한다. 나머지 문장에서는 따옴표 안의 발화를 대사로 검사한다. 일반 서술 속 ‘좀비’는 이 대사 규칙으로 막지 않는다.
- 금지어 검사는 Unicode 정규화와 대소문자 처리를 한다. 총기 이름 목록은 검사용 설정에만 있고 창작 예문에 넣지 않았다.

`manual_review`에는 어휘 검사만으로 판정할 수 없는 사항을 남겼다. 목록에 없는 실존 명칭, 유명 인물·정당·단체 이름, 원인 단정과 인물의 해석 구분, 민족의 성격화, 직접적인 폭력·선별 장면, 말투·물건·장소의 적합성은 사람 검수가 필요하다. id가 가리키는 대상의 존재 여부도 아직 검사하지 않는다. 따라서 검사 통과는 가이드 5장의 사람 검수 완료를 뜻하지 않는다.

기술 기준: [JSON Schema 문자열 길이](https://json-schema.org/understanding-json-schema/reference/string), [Ajv JSON Schema 2020-12](https://ajv.js.org/json-schema.html), [Vite 안내](https://vite.dev/guide/).

## S1a 플레이 빌드

S1a(정치 텍스트 프로토타입)를 폰 가로 화면에서 한 판 끝까지 할 수 있는 빌드다. 규칙과 수치는 [S1a 정치 수치 브리프](../docs/design/briefs/s1a_politics_numbers.md)와 시뮬레이터(`docs/design/sim/s1a_balance.py`)를 TypeScript로 옮겼고, 화면 배치는 [decisions.md](../docs/design/decisions.md)의 홈·의회·한눈에 보기·결정 카드 설계를 따른다. 그림은 회색 상자 수준의 자리표시다. 맨 위 소개의 "게임 로직과 화면은 아직 없다"는 A1 시절 설명이다.

```sh
cd s1
npm ci
npm run dev            # 개발 서버. 같은 와이파이의 폰에서 열려면 npm run dev -- --host
npm test               # 규칙 자동 플레이(40판), 결정성, 저장, 화면 글 금지어 검사 포함
npm run build          # dist/에 정적 파일. 아무 정적 호스팅에 올려도 된다(경로는 상대 경로)
```

주소에 `?seed=글자`를 붙이면 그 시드로 시작한다. 저장은 localStorage 한 칸(`s1a.game.v2`)이고 행동마다 저절로 한다. 메뉴에 같은 시드로 처음부터, 새 판, 숨은 수치 보기(테스트용)가 있다.

### 스크린샷과 배치 검사

```sh
npm run build
NODE_PATH="$(npm root -g)" node tools/screenshots.cjs
```

- `dist/`를 작은 정적 서버로 띄우고 844×390에서 한 판을 눌러 가며(홈, 칸 창, 한눈에 보기, 불만 쪽 창, 서류 카드, 정차, 3구간 의회와 공개 협상, 표결 결과, 정산, 일지, 끝) 17장을 `screenshots/`에 저장한다. 마지막 장은 세로 화면의 "가로로 돌려 주세요"다.
- 찍을 때마다 가로 스크롤, 화면 밖으로 나간 요소(열차 가로 스크롤 안은 뺀다), 잘린 내용, 위아래 막대를 침범한 본문, 세로 스크롤, 12px보다 작은 글자를 검사하고 하나라도 있으면 실패한다.
- 다른 크기: `SCREENSHOT_VIEWPORT=667x375 SCREENSHOT_DIR=/tmp/shots`. 667×375, 740×360, 844×390, 932×430에서 통과했다.

### 구성

| 경로 | 내용 |
|---|---|
| `src/game/` | DOM 없는 규칙: 수치와 법 18개(`data`), 판 상태(`state`), 의회·거래 도구(`politics`), 서류 카드(`cards`), 구간 진행·정차·정산·AI 대표(`turn`), 죽음과 시신 법(`death`) |
| `src/ui/` | 화면: 위·아래 막대(`hud`), 홈 단면도(`home`), 한눈에 보기(`overview`), 의회(`council`), 서류·정차 카드(`card`), 겹쳐 뜨는 창(`panels`), 레버와 계기(`widgets`), 반원 좌석(`seats`), 입력과 저장(`app`) |
| `tests/game/` | 자동 플레이 40판이 끝 조건으로 끝나는지, 같은 시드면 같은 판인지, 저장·복원, 화면 글 금지어 |
| `tools/screenshots.cjs` | 스크린샷과 배치 검사 |

### 화면과 조작

- 홈: 옆에서 본 열차 단면. 왼쪽이 꼬리(꼬리칸 셋), 오른쪽이 기관차이고 좌우로 민다. 칸을 누르면 작은 창에 온기·배급·과밀·노출과 난방·배급 레버가 뜬다. 레버는 다섯 칸이고, 반원 계기는 모자라면 빨간 쪽, 남으면 호박색 쪽으로 기운다.
- 서류 뭉치: 왼쪽 아래. 사건·요구·부탁·파업 경고 카드와 정차 결정이 쌓인다. 누르면 화면 왼쪽 절반에 펼쳐지고 오른쪽엔 관련 칸이 보이게 열차가 움직인다. 서류가 남아 있으면 주 단추가 "서류 N장"으로 바뀐다.
- 위 막대: 신임·긴장, 불만·중립·지지 띠(양 끝 주먹·편 손을 누르면 집단 창. 집단마다 구간당 지지·칼질·고유 행동 하나), 석탄·식량(구간당 예상 소모)·의약품·사치품.
- 아래 막대: 메뉴·일지, 구간과 다섯 단계(출발 전 운영, 이동, 정차, 의회, 정산), 한눈에 보기, 주 단추.
- 한눈에 보기: 세로로 세운 열차에서 칸 묶음을 고르면 오른쪽 창과 선으로 잇는다. "수치만 보기"는 묶음마다 온기·배급·과밀만 크게 보인다. "배급장에게 맡기기"는 출발 전마다 레버를 저절로 맞춘다.
- 의회(3·6·9…구간): 반원 100석을 집단 쐐기로 나눈다. 가운데 바늘과 51·67 눈금, 예상 찬성(폭 최소~최대). 왼쪽은 안건(거래 전에는 ‹ ›로 바꿈), 오른쪽은 고른 집단의 대표와 거래 도구 다섯(공개 협상, 사적 부탁, 현장 조달, 뇌물, 협박). 막힌 도구는 이유를 쓴다. 회기당 거래 3번. 표결은 미정 표가 하나씩 갈리는 개표로 보여 준다.
- 비밀 투표 법이 서면 의석은 약속한 자리만 보이고 나머지는 가려진다.

### 아직 자리표시인 것

- 그림 전부(칸, 사람, 초상은 실루엣과 이름 첫 글자), 아이콘, 소리.
- 카드 문장은 짧은 임시 글이다. Gemini 문장 생성은 붙이지 않았다.
- 정차 장소 이름은 일반 명사(병원, 관청 등)다. 실제 노선과 역 이름은 넣지 않았다.
- 자재(고철·목재)는 S1a에 없어서 표시하지 않는다.
