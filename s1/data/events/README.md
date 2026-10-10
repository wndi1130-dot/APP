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
- 조건 `resource`는 창고 수량을 본다: `{"type":"resource","resource":"coal|food|medicine|luxury|symbol","operator":"lte|gte","value":수}`. `symbol`은 지금 가진 상징물 수다. 범위는 두 조건으로 건다(의약품 3~10 = gte 3 + lte 10).
- 선택지의 `requires`(같은 resource 조건 목록)는 모두 참일 때만 그 선택지를 카드에 보인다. 모자라면 회색으로 막는 것이 아니라 숨긴다. 전부 숨어야 하면 숨기지 않는다.
- 효과 `person.state`·`person.away`의 `target`에 `leader_<칸>`(예: `leader_medtech`)을 쓰면 그 칸의 지금 대표다. 대표는 판마다 달라 사람 id를 못 박을 수 없을 때 쓴다.
- id가 `ev_h` + 두 자리 숫자 + `_`로 시작하는 사건(`ev_h01_low_fire` 등)도 `ev_b01_`과 같이 새 이동 사건 묶음이다. 묶음을 켠 판에서만 뽑힌다(src/game/event_pack.ts).
- 위로 카드(`ev_b01_frost_bird` 등)는 `ev_achieved` 표식이 서야 온다(결정 016). 표식은 엔진이 배관 추인이 가결될 때 세우고(법 통과·다친 사람 없는 정차·지킨 약속은 거의 매 판 서서 뺐다)(`achieve()`, state.ts), 사건은 선택지 효과 `flag`로 세운다. 위로 카드는 고른 뒤 효과 끝에 `ev_achieved false`를 더해 한 성취에 한 장만 오게 한다. 후속 사건은 들어올 때 자기 trigger를 다시 본다(예약한 뒤 조건이 깨졌으면 올리지 않는다).
