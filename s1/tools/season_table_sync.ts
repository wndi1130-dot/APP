// 계절표 정본(src/game/season_table.json)을 S2가 읽는 자리(s2/game/season_table.json)로 그대로 복사한다.
// 사용: npx tsx tools/season_table_sync.ts   (정본을 고친 뒤 한 번. tests/game/season_table.test.ts가 둘이 같은지 본다)

import { copyFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const from = fileURLToPath(new URL('../src/game/season_table.json', import.meta.url));
const to = fileURLToPath(new URL('../../s2/game/season_table.json', import.meta.url));
copyFileSync(from, to);
console.log(`${from} -> ${to}`);
