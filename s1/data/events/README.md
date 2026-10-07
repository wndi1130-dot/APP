# 콘텐츠 JSON 사건

Gemini로 새로 쓰는 사건은 여기에 JSON으로 둔다(s1_content_guide 6장, 형식은 schema/event.schema.json).
파일 하나에 사건 하나나 배열. 넣기 전에 `npm run validate -- data/events`를 통과해야 한다.
게임은 src/game/content.ts가 읽는다(브라우저는 main.ts, 도구·시험은 tools/content_fs.ts).

## 판에 붙이는 규칙(6.9)

- 자리표시자 값은 고정 규칙이 기본이고 사건마다 `bind`로 바꾼다. `car`·`item`·`n`·`n2`는 `bind`가 있어야 한다.
- 값을 댈 사람·법이 판에 없으면 그 사건은 뽑지 않는다. S1a에서 아직 값을 못 대는 것: `place`의 이동 중 기본값과 `next_stop`(S1a엔 노선이 없다), `item`의 `last_symbol`(상징물에 이름이 없다), `person`의 `scapegoat`(표시를 켜는 곳이 S1b에 있다), `faction_leader` 사건.
- `speaker`가 `rep`·`aide`면 `community`(공동체 id나 `any`), `faction_leader`면 `faction`이 있어야 한다.
- 효과 `secret`은 data/secrets/*.json에, `deal`은 data/deals/*.json에 그 id가 있어야 뽑힌다.
  - 비밀 글의 `{person}`은 그 비밀을 쥔 사람이다(사건의 person, 없으면 말하는 칸의 대표).
  - 거래의 `ask`는 기한에 열차장이 치를 효과(내는 것은 음수로 쓴다), `gives`는 받자마자 오는 효과, `breach`는 기한에 못 치렀을 때 오는 효과다. 기한 0이면 받을 때 같이 치른다.
