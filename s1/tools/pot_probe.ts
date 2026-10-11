// 식당칸 솥(불리기)의 제안 숫자를 잰다(food_cooking 9장 11번). 같은 시드로 솥 정책만 바꿔 돌린다.
// 사용: npx tsx tools/pot_probe.ts [판 수=1000] [--set=D키:값 ...] [--dom=engaged|idle]
// 예: npx tsx tools/pot_probe.ts 2000 --set=potRisk0:0.3 --set=potRiskUp:0 --set=potMixSit:8 --set=potThinSit:5
// 실제 게임 코드를 돌린다. 1000판의 95% 오차는 ±3%p쯤이다.

import { D, potOf } from '../src/game';
import { playGame } from './s1c_bot';
import type { DomPolicy, PotPolicy } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const N = Number(args[0] ?? 1000);
if (!Number.isInteger(N) || N <= 0) throw new Error(`판 수는 1 이상의 정수: ${args[0]}`);
const sets: Record<string, number> = {};
for (const f of flags.filter(x => x.startsWith('--set='))) {
  const [k, v] = f.slice(6).split(':');
  if (!Object.hasOwn(D, k) || !Number.isFinite(Number(v))) throw new Error(`D에 없는 값이거나 수가 아니다: ${f}`);
  (D as unknown as Record<string, number>)[k] = Number(v);
  sets[k] = Number(v);
}
const dom = (flags.find(x => x.startsWith('--dom='))?.slice(6) ?? 'engaged') as DomPolicy;
if (dom !== 'engaged' && dom !== 'idle') throw new Error(`--dom은 engaged나 idle: ${dom}`);

const RUNS: { name: string; pot?: PotPolicy }[] = [
  { name: '그대로' },
  { name: '늘 묽게', pot: 'thin' },
  { name: '모자랄 때만 묽게', pot: 'thin_low' },
  { name: '늘 섞어서', pot: 'mixed' },
  { name: '모자랄 때만 섞어서', pot: 'mixed_low' },
  { name: '모자랄 때만 섞다가 한 번 들키면 그만', pot: 'mixed_once' },
];

interface Row { done: number; out: number; thin: number; mixed: number; caught: number; parts: number; restored: number; trust: number; tension: number; food: number; low: number; deaths: number }
const mean = (xs: number[]): number => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);
const f1 = (x: number): string => x.toFixed(1);
const pc = (x: number): string => `${(x * 100).toFixed(1)}%`;

console.log(`판 수 ${N}, 내정 봇 ${dom}, 바꾼 값 ${JSON.stringify(sets)}`);
console.log('| 솥 정책 | 완주 | 쫓겨남·봉기로 끝남 | 묽게 구간 | 섞은 구간 | 들킨 판 | 판마다 들킨 횟수 | 끝 신임 | 끝 긴장 | 끝 식량 | 식량 30 아래 구간 | 죽은 사람 | 만든 부품 | 되살린 기술 |');
console.log('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
for (const run of RUNS) {
  const rows: Row[] = [];
  for (let i = 0; i < N; i += 1) {
    const { g, m } = playGame(`pot-${i}`, { s1c: true, policy: 'caretaker', dom, pot: run.pot });
    const pot = potOf(g);
    rows.push({
      done: m.end === 'complete' ? 1 : 0, out: m.end === 'ousted' || m.end === 'revolt' || m.end === 'coup' ? 1 : 0,
      thin: pot.thinSegs, mixed: pot.mixedSegs, caught: pot.caught, parts: g.dom?.stats.partsMade ?? 0, restored: g.dom?.stats.restored ?? 0, trust: g.trust, tension: m.tensionEnd, food: m.endFood, low: m.foodUnder30, deaths: m.deaths,
    });
  }
  const col = (k: keyof Row): number => mean(rows.map(r => r[k]));
  console.log(`| ${run.name} | ${pc(col('done'))} | ${pc(col('out'))} | ${f1(col('thin'))} | ${f1(col('mixed'))} | ${pc(mean(rows.map(r => (r.caught > 0 ? 1 : 0))))} | ${col('caught').toFixed(2)} | ${f1(col('trust'))} | ${f1(col('tension'))} | ${f1(col('food'))} | ${f1(col('low'))} | ${f1(col('deaths'))} | ${f1(col('parts'))} | ${col('restored').toFixed(2)} |`);
}
