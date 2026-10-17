// S3 첫 시험 네 사례 표(구현명세 S3 연결 v1 6-1, 확인 줄 12·13·17·18).
// 같은 씨앗으로 상징물 있음/없음 × 서막 약속 지킴/어김 넷을 돌려, 특별 회기 후보와 안건별 예상 찬성을 찍는다.
// 쓰는 법: npx tsx tools/field_slice_table.ts [씨앗]
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { agendaTitle, blocs, createGame, expected, isLawAgenda, sameAgenda } from '../src/game';
import type { Agenda, Game } from '../src/game';
import { applyFieldReturn, chooseSymbolUse, FIELD } from '../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../src/game/field_receipt';
import { openSpecialCouncil } from '../src/game/field_council';

const dir = fileURLToPath(new URL('../../s2/tests/game/fixtures/field_v4/', import.meta.url));
const read = <T>(name: string): T => JSON.parse(readFileSync(join(dir, name), 'utf8')) as T;
const seed = process.argv[2] ?? 'slice-seed-a';
const CASES = [
  ['1', 'case1_symbol_kept', true],
  ['2', 'case2_symbol_broken', true],
  ['3', 'case3_nosymbol_kept', false],
  ['4', 'case4_nosymbol_broken', false],
] as const;

const rows: { name: string; g: Game; options: Agenda[] }[] = [];
for (const [name, file, symbol] of CASES) {
  const g = createGame(seed);
  const rec = applyFieldReturn(g, read<FieldDeparture>('departure_prologue.json'), read<FieldReceipt>(`${file}.json`)).record;
  if (symbol) chooseSymbolUse(g, rec.receiptId, 'hang_before_session');
  openSpecialCouncil(g);
  rows.push({ name, g, options: [...(g.council?.options ?? [])] });
}

const fmt = (a: Agenda, g: Game) => {
  const e = expected(blocs(g, a));
  return `${e.mean.toFixed(1)} (${e.min}~${e.max})`;
};
console.log(`씨앗 ${seed} · 값 ${JSON.stringify(FIELD)}`);
for (const { name, g, options } of rows) {
  const rec = g.fieldReturns!.records[0];
  const b = rec.before;
  console.log(`\n사례 ${name}: 약속 ${rec.verdicts[0].verdict}, 상징물 ${rec.symbol ? rec.symbol.use : '없음'}`);
  console.log(`  신임 ${b.trust} → ${g.trust}, 꼬리칸 관계 ${b.rel.tail} → ${g.comms.tail.rel}`);
  for (const a of options) console.log(`  후보 ${agendaTitle(a)}: 예상 찬성 ${fmt(a, g)}`);
}
// 같은 안건을 골라 놓고 견준다: 네 사례 모두에 있는 법 안건 가운데 첫째.
const common = rows[0].options.find(a => isLawAgenda(a) && rows.every(r => r.options.some(o => sameAgenda(o, a))));
if (common) {
  console.log(`\n같은 안건 「${agendaTitle(common)}」의 예상 찬성`);
  for (const { name, g } of rows) console.log(`  사례 ${name}: ${fmt(common, g)}`);
}
