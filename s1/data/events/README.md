# 콘텐츠 JSON 사건

Gemini로 새로 쓰는 사건은 여기에 JSON으로 둔다(s1_content_guide 6장, 형식은 schema/event.schema.json).
파일 하나에 사건 하나나 배열. 넣기 전에 `npm run validate -- data/events`를 통과해야 한다.
게임은 src/game/content.ts가 읽는다(브라우저는 main.ts, 도구·시험은 tools/content_fs.ts).
