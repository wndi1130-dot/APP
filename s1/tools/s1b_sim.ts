// S1a 판과 S1a+S1b 판을 같은 시드로 돌려 비교한다(s1b_dark_path 16.1, 1.1의 숫자 선).
// 사용: npx tsx tools/s1b_sim.ts [판 수=1000] [결과 JSON 경로]
// 실제 게임 코드를 돌린다. 봇은 S1a를 돌보는 정책으로 하고, S1b 카드만 세 가지로 고른다(tools/s1c_bot.ts DarkPolicy).
// 판 수 차이를 볼 땐 4000판으로 잰다(1000판의 95% 오차는 ±3%p).

import { writeFileSync } from 'node:fs';
import { B } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions, GameMetrics } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
// 판 수는 양의 정수만 받는다(0·음수·소수·글자는 빈 결과나 NaN 평균으로 새어 나간다, K02 11).
if (args[0] !== undefined && !/^[1-9]\d*$/.test(args[0])) throw new Error(`판 수는 양의 정수여야 한다: ${args[0]}`);
const N = Number(args[0] ?? 1000);
const OUT = args[1];
// --set=key:value 로 dark/data.ts의 B 값을 바꿔 민감도를 본다(예: --set=escBase:0.25).
const sets: Record<string, number> = {};
for (const f of flags.filter(x => x.startsWith('--set='))) {
  const [k, v] = f.slice(6).split(':');
  // `in`은 toString 같은 상속 속성도 통과시킨다. B 자신의 속성만 받는다(K02 11).
  if (!Object.hasOwn(B, k)) throw new Error(`B에 없는 값: ${k}`);
  if (v === undefined || v.trim() === '' || !Number.isFinite(Number(v))) throw new Error(`숫자가 아닌 값: ${k}:${v}`);
  (B as unknown as Record<string, number>)[k] = Number(v);
  sets[k] = Number(v);
}

const RUNS: { name: string; opts: BotOptions }[] = [
  { name: 'S1a caretaker', opts: { s1c: false, policy: 'caretaker', dom: 'idle' } },
  { name: 'S1b kind (경비·재판)', opts: { s1c: false, policy: 'caretaker', dom: 'idle', s1b: 'kind' } },
  { name: 'S1b blind (징후 무시)', opts: { s1c: false, policy: 'caretaker', dom: 'idle', s1b: 'blind' } },
  { name: 'S1b cruel (선을 넘음)', opts: { s1c: false, policy: 'caretaker', dom: 'idle', s1b: 'cruel' } },
];

const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);

function summarize(ms: GameMetrics[]) {
  const ends: Record<string, number> = {};
  for (const m of ms) ends[m.end] = (ends[m.end] ?? 0) + 1;
  const keys = [...new Set(ms.flatMap(m => Object.keys(m.dark ?? {})))].sort();
  const darkCards = [...new Set(ms.flatMap(m => Object.keys(m.cards).filter(k => k.startsWith('dark:'))))].sort();
  return {
    games: ms.length,
    ends: Object.fromEntries(Object.entries(ends).map(([k, v]) => [k, +(v / ms.length).toFixed(3)])),
    deaths: +mean(ms.map(m => m.deaths)).toFixed(2),
    s1aCards: +mean(ms.map(m => m.s1aCards)).toFixed(2),
    dark: Object.fromEntries(keys.map(k => [k, +mean(ms.map(m => m.dark?.[k] ?? 0)).toFixed(2)])),
    darkCards: Object.fromEntries(darkCards.map(k => [k, +mean(ms.map(m => m.cards[k] ?? 0)).toFixed(2)])),
  };
}

const out: Record<string, unknown> = { n: N, sets };
for (const run of RUNS) {
  const ms: GameMetrics[] = [];
  for (let i = 0; i < N; i += 1) ms.push(playGame(`s1b-${i}`, run.opts).m);
  const s = summarize(ms);
  out[run.name] = s;
  console.log(`\n== ${run.name} (${N}판)`);
  console.log(JSON.stringify(s));
}
if (OUT) writeFileSync(OUT, JSON.stringify(out, null, 2));
