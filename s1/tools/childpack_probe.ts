// x1 변경 전 HEAD에서도 그대로 실행한다. 새 살림 API를 가져오지 않는다.
// 사용: npx tsx tools/childpack_probe.ts [판 수=300] [JSON]
import { writeFileSync } from 'node:fs';
import { lawActive, lawOpen, techUsable } from '../src/game';
import type { Game } from '../src/game';
import { playGame } from './s1c_bot';

const args = process.argv.slice(2);
const n = Number(args[0] ?? 300);
if (!Number.isInteger(n) || n < 1 || args.length > 2) throw new Error('사용: childpack_probe.ts [양의 정수=300] [JSON]');
const rows = Array.from({ length: n }, (_, i) => {
  let settlements = 0, openSettlements = 0;
  let childPack = false, childLabor = false, x1 = false;
  const observe = (g: Game) => {
    childPack ||= lawActive(g, 'child_pack') || g.repealedAt.child_pack !== undefined;
    childLabor ||= lawActive(g, 'child_labor') || g.repealedAt.child_labor !== undefined;
    x1 ||= techUsable(g, 'x1');
  };
  const { g, m } = playGame(`cp-${i}`, {
    s1c: true, policy: 'caretaker', dom: 'engaged',
    probe: {
      beforePrep: observe, afterPick: observe, afterStop: observe,
      onSettle(g) {
        observe(g);
        settlements += 1;
        if (!lawActive(g, 'child_pack') && lawOpen(g, 'child_pack')) openSettlements += 1;
      },
    },
  });
  observe(g);
  if (m.end === 'none') throw new Error(`끝나지 않은 판: cp-${i}`);
  return { seed: `cp-${i}`, complete: m.end === 'complete', end: m.end, settlements, openSettlements, childPack, childLabor, x1 };
});
const count = (key: 'complete' | 'childPack' | 'childLabor' | 'x1') => rows.filter(r => r[key]).length;
const settlements = rows.reduce((s, r) => s + r.settlements, 0);
const openSettlements = rows.reduce((s, r) => s + r.openSettlements, 0);
const result = {
  n, seeds: 'cp-0…', options: { s1c: true, policy: 'caretaker', dom: 'engaged' },
  summary: {
    complete: count('complete'), completionRate: count('complete') / n,
    settlements, openSettlements, openShare: openSettlements / Math.max(1, settlements),
    childPackGames: count('childPack'), childPackShare: count('childPack') / n,
    childLaborGames: count('childLabor'), childLaborShare: count('childLabor') / n,
    x1Games: count('x1'), x1Share: count('x1') / n,
  }, rows,
};
const s = result.summary;
const pct = (x: number) => `${(100 * x).toFixed(2)}%`;
console.log('| 판 수 | 완주 | child_pack 미성립·열림 / 정산 | child_pack 통과 판 | child_labor 통과 판 | x1 복원 판 |');
console.log('|---:|---:|---:|---:|---:|---:|');
console.log(`| ${n} | ${s.complete} (${pct(s.completionRate)}) | ${s.openSettlements}/${s.settlements} (${pct(s.openShare)}) | ${s.childPackGames} (${pct(s.childPackShare)}) | ${s.childLaborGames} (${pct(s.childLaborShare)}) | ${s.x1Games} (${pct(s.x1Share)}) |`);
if (args[1]) writeFileSync(args[1], `${JSON.stringify(result, null, 2)}\n`);
