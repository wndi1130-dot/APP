# J07 영수증 계약: S2 검사기와 S1 스키마가 다르게 판단하는 입력 (2026-10-08)

근거: PR23 가지 claude/project-thread-zoz1rs 4d42a3d(main에 아직 없음)
묻은 곳: 코덱스(높은 추론, 저장소 사본을 직접 읽음)와 웹 GPT(파일 아홉 개를 줄 번호와 함께 붙여 보냄)에 같은 물음을 따로. 둘 다 읽기만 했고, Godot·Ajv·테스트는 돌리지 않았다(정적 대조).
물음: s2/game/sim/receipt.gd의 builder·검사기와 s1/schema/receipt.schema.json(+ common·place·chronicle)이 다르게 판단하는 입력, builder가 만들 수 있는데 스키마가 거부하는 값, .github/workflows/s1-web.yml의 paths가 계약 파일을 다 덮는지.
제 한 줄 판정: 두 모델 답이 사실상 같다. GD 검사기가 스키마보다 느슨해서 'GD 통과, 스키마 거부'가 생기고, 그 반대는 없다. CI 경로는 빠진 파일이 없다. 저는 witnesses 원소 검사 누락(receipt.gd 240줄)과 스키마의 추가 키 금지(receipt.schema.json 26·47·110·194·231줄)를 직접 열어 확인했다.

메모: 물음에서 'validate'라고 부른 함수의 실제 이름은 `Receipt.check()`다. 또 이 사본의 테스트는 표본 셋만 넣어 보지 않고, 양쪽에 잘못된 입력 테스트도 있다(s1/tests/receipt.test.ts 53, s2/tests/game/test_receipt.gd 96·238). 빠진 것은 '같은 변형 입력을 양쪽에 넣어 판단이 같은지 비교하는 테스트'다(코덱스).

---

## 1. GD 통과, 스키마 거부 (둘 다 높음)

| 어디 | 스키마 | GD `check()` | 근거 | 최소 예 |
|---|---|---|---|---|
| witnessed[].witnesses 원소 | 원소마다 ID 문자열 또는 {person, text(빈 글 아님)} | 배열인지만 본다. builder `witness()`도 원소를 검사 없이 복사 | receipt.gd 240; common.schema.json 264; chronicle.schema.json 29 | `"witnesses":[0]` |
| witnessed[]의 선택 필드 id·weight·template | 있으면 ID 패턴, weight ≥ 0 | 검사하지 않음 | receipt.schema.json 267·295; receipt.gd 227 | `"weight":-1` |
| place·time·items·witnessed·promises·decisions 안의 모르는 키 | `additionalProperties:false`라 거부 | 아는 키만 보고 나머지는 무시 | receipt.schema.json 26·47·110·194·231·310; receipt.gd 169·179·201·227·260·274 | `place`에 `"extra":1` |

- 최상위의 모르는 키는 양쪽 다 거부한다. placeState는 스키마도 추가 키를 허용해서(172줄) 양쪽이 같다.
- 실제로 생길 수 있는 길(코덱스): builder로 `witness(..., [0])`을 만들면 'builder 생성 → GD 통과 → S1 스키마 거부'가 된다.

## 2. builder가 만들 수 있는데 양쪽 검사기가 거부하는 값 (둘 다 중간)

- 새 builder의 시각이 빈 문자열(`arrive=""`, `depart=""`)로 시작한다. `set_time()`도 형식을 검사하지 않는다(receipt.gd 18~20·43).
- 음수 `stayGameMinutes`, 잘못된 ID(대문자·하이픈·빈 글)를 `gain_item()`·`person()`·`promise()`·`decision()`·`witness()`가 검사 없이 받는다.
- `to_dict()`·`to_json()`이 내보내기 전에 `check()`를 부르지 않는다.
- 문제없는 것(둘 다 같음): 빈 목록 전체, 음수 stock, 범위 안 소수 looted, items의 같은 ID 반복, 서로 다른 people 목록 사이의 같은 인물. builder는 looted를 0~1로, risk를 0 이상으로 보정한다.
- 의미가 다른 곳(웹 GPT): decisions에 같은 id가 두 번 있으면 raw JSON은 양쪽 다 통과하지만, builder는 뒤의 선택으로 바꿔 넣는다. 스키마 위반은 아니고 '검사 계약과 builder의 정리 방식이 다르다'는 점만 기록한다.

## 3. 스키마 통과, GD 거부

- 둘 다 0건. id 패턴, 시각(D1 00:00 꼴), stock 11개 키·정수, people 7개 목록·목록 안 중복, source, endReason 모두 같은 규칙이다.

## 4. CI 경로 (둘 다 빠진 파일 없음)

- `s1/**`가 스키마 넷, s1/tests/receipt.test.ts, S1 표본 둘을 덮는다.
- s2/game/sim/receipt.gd, s2/tests/game/test_receipt.gd는 이름으로, s2/tests/game/fixtures/**가 receipt_gd_sample.json을 덮는다. push와 pull_request 양쪽에 같은 필터가 있다.
- 다만 이 워크플로는 `npm test`만 돌리고 Godot 테스트나 GD 표본 재생성은 하지 않는다. GD 파일이 바뀌면 워크플로는 뜨지만 GD 쪽 검사는 돌지 않는다(코덱스).

## 합친 판단

- 같은 것: 위 1~4 전부. 갈린 곳이 없다.
- 고칠 순서(제 판단): ① `check()`에 witnesses 원소 검사와 중첩 객체의 모르는 키 거부를 넣는다. ② builder가 `to_dict()` 전에 `check()`를 부르거나, 각 setter가 ID·시각을 검사한다. ③ 계약 테스트에 '같은 변형 입력을 양쪽에 넣어 판단이 같은지' 표를 하나 둔다(위 표의 최소 예가 그대로 첫 줄이 된다).
- 이 가지는 아직 main에 없으므로, 고치는 일은 S2 스레드 몫이다.
