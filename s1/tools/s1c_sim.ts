// S1a 판과 S1a+S1c 판을 같은 시드로 돌려 비교한다(s1c_domestic 14.1의 2번).
// 사용: npx tsx tools/s1c_sim.ts [판 수=1000] [결과 JSON 경로]
// 실제 게임 코드를 돌린다. 판 수 차이를 볼 땐 4000판으로 잰다(1000판의 95% 오차는 ±3%p).

import { writeFileSync } from 'node:fs';
import { D, TRAVEL_EVENTS } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions, GameMetrics } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const N = Number(args[0] ?? 1000);
const OUT = args[1];
// --set=key:value 로 domestic/data.ts의 D 값을 바꿔 민감도를 본다(예: --set=hotWater0:0 --set=liceDirty:0.05).
const sets: Record<string, number> = {};
for (const f of flags.filter(x => x.startsWith('--set='))) {
  const [k, v] = f.slice(6).split(':');
  if (!(k in D)) throw new Error(`D에 없는 값: ${k}`);
  (D as unknown as Record<string, number>)[k] = Number(v);
  sets[k] = Number(v);
}
const only = flags.find(x => x.startsWith('--only='))?.slice(7);

const RUNS: { name: string; opts: BotOptions }[] = [
  { name: 'S1a caretaker', opts: { s1c: false, policy: 'caretaker', dom: 'idle' } },
  { name: 'S1a+S1c caretaker engaged', opts: { s1c: true, policy: 'caretaker', dom: 'engaged' } },
  { name: 'S1a+S1c caretaker idle', opts: { s1c: true, policy: 'caretaker', dom: 'idle' } },
  { name: 'S1a first', opts: { s1c: false, policy: 'first', dom: 'idle' } },
  { name: 'S1a+S1c first engaged', opts: { s1c: true, policy: 'first', dom: 'engaged' } },
];

const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);
const pct = (xs: number[], q: number) => { const s = [...xs].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(q * s.length))] ?? 0; };

function summarizeRepeat(ms: GameMetrics[]) {
  const sum = (f: (m: GameMetrics) => number) => ms.reduce((s, m) => s + f(m), 0);
  const per = (f: (m: GameMetrics) => number, d = 2) => +mean(ms.map(f)).toFixed(d);
  const ids = new Set([...TRAVEL_EVENTS.map(e => e.id), ...ms.flatMap(m => Object.keys(m.travelById ?? {}))]);
  const travelById = Object.fromEntries([...ids].sort().map(id => [id, per(m => m.travelById?.[id] ?? 0)]));
  const cids = new Set(ms.flatMap(m => Object.keys(m.contentById ?? {})));
  const contentById = Object.fromEntries([...cids].sort().map(id => [id, per(m => m.contentById?.[id] ?? 0)]));
  const segs = sum(m => m.segsTotal);
  const dist = [0, 1, 2, 3, 4].map(i => +(sum(m => m.cardsPerSeg?.[i] ?? 0) / Math.max(1, segs)).toFixed(3));
  return {
    travelCards: per(m => Object.values(m.travelById ?? {}).reduce((a, b) => a + b, 0)),
    travelRepeats: per(m => m.travelRepeats ?? 0),
    contentCards: per(m => Object.values(m.contentById ?? {}).reduce((a, b) => a + b, 0)),
    contentRepeats: per(m => m.contentRepeats ?? 0),
    titleRepeats: per(m => m.titleRepeats ?? 0),
    titleTotal: per(m => m.titleTotal ?? 0),
    titleRepeatRate: +(sum(m => m.titleRepeats ?? 0) / Math.max(1, sum(m => m.titleTotal ?? 0))).toFixed(3),
    segs: per(m => m.segsTotal ?? 0),
    segsWithTravel: per(m => m.segsWithTravel ?? 0),
    segsNoTravel: per(m => (m.segsNoTravel?.rest ?? 0) + (m.segsNoTravel?.empty ?? 0) + (m.segsNoTravel?.other ?? 0)),
    segsNoTravelRest: per(m => m.segsNoTravel?.rest ?? 0),
    segsNoTravelEmpty: per(m => m.segsNoTravel?.empty ?? 0),
    segsNoTravelOther: per(m => m.segsNoTravel?.other ?? 0),
    cardsPerSegDist: dist, // 0,1,2,3,4+ 장인 구간의 비율(전 판 합산)
    cardsPerSegMaxMean: per(m => m.cardsPerSegMax ?? 0),
    cardsPerSegMax: Math.max(0, ...ms.map(m => m.cardsPerSegMax ?? 0)),
    travelById,
    contentById,
  };
}

function summarize(ms: GameMetrics[]) {
  const ends: Record<string, number> = {};
  for (const m of ms) ends[m.end] = (ends[m.end] ?? 0) + 1;
  const kinds = new Set(ms.flatMap(m => Object.keys(m.cards)));
  const cardsPerGame = Object.fromEntries([...kinds].sort().map(k => [k, +mean(ms.map(m => m.cards[k] ?? 0)).toFixed(2)]));
  const dom = ms[0]?.dom ? Object.fromEntries((Object.keys(ms[0].dom!) as (keyof NonNullable<GameMetrics['dom']>)[])
    .filter(k => k !== 'techs').map(k => [k, +mean(ms.map(m => m.dom![k] as number)).toFixed(2)])) : undefined;
  const techFreq: Record<string, number> = {};
  for (const m of ms) for (const t of m.dom?.techs ?? []) techFreq[t] = (techFreq[t] ?? 0) + 1;
  return {
    games: ms.length,
    ends: Object.fromEntries(Object.entries(ends).map(([k, v]) => [k, +(v / ms.length).toFixed(3)])),
    coalMin: +mean(ms.map(m => m.coalMin)).toFixed(1),
    foodMin: +mean(ms.map(m => m.foodMin)).toFixed(1),
    coalUnder30: +mean(ms.map(m => m.coalUnder30)).toFixed(2),
    foodUnder30: +mean(ms.map(m => m.foodUnder30)).toFixed(2),
    forcedPerGame: +mean(ms.map(m => m.forced)).toFixed(2),
    councils: +mean(ms.map(m => m.councils)).toFixed(2),
    lawsPassed: +mean(ms.map(m => m.lawsPassed)).toFixed(2),
    harshPassed: +mean(ms.map(m => m.harshPassed)).toFixed(2),
    deaths: +mean(ms.map(m => m.deaths)).toFixed(2),
    emergencyCoal: +mean(ms.map(m => (m.emergencyCoal ? 1 : 0))).toFixed(3),
    endCoal: +mean(ms.map(m => m.endCoal)).toFixed(1),
    endFood: +mean(ms.map(m => m.endFood)).toFixed(1),
    s1aCards: +mean(ms.map(m => m.s1aCards)).toFixed(2),
    domCards: +mean(ms.map(m => m.domCards)).toFixed(2),
    domCardsP10: pct(ms.map(m => m.domCards), 0.1),
    domCardsP90: pct(ms.map(m => m.domCards), 0.9),
    cardsPerGame,
    tailExpoMax: +mean(ms.map(m => m.tailExpoMax ?? 0)).toFixed(1),
    tailExpoEnd: +mean(ms.map(m => m.tailExpoEnd ?? 0)).toFixed(1),
    tailExpoHit90: +mean(ms.map(m => ((m.tailExpoMax ?? 0) >= 90 ? 1 : 0))).toFixed(3),
    crews: Object.fromEntries(['tail', 'medtech', 'guard', 'front'].map(c => [c, +mean(ms.map(m => m.crews?.[c] ?? 0)).toFixed(2)])),
    spaceSegs: +mean(ms.map(m => m.spaceSegs ?? 0)).toFixed(2),
    dom,
    // 사건 반복·카드 밀도(2026-10-09). 판당 평균. travelById는 TRAVEL_EVENTS 전체 id를 넣어 0회 사건도 보인다.
    repeat: summarizeRepeat(ms),
    techFreq: Object.fromEntries(Object.entries(techFreq).sort().map(([k, v]) => [k, +(v / ms.length).toFixed(3)])),
  };
}

const out: Record<string, ReturnType<typeof summarize>> = {};
const t0 = Date.now();
for (const run of RUNS.filter(r => !only || r.name.includes(only) || !r.opts.s1c)) {
  const ms: GameMetrics[] = [];
  for (let i = 0; i < N; i += 1) ms.push(playGame(`sim-${i}`, run.opts).m);
  out[run.name] = summarize(ms);
  const s = out[run.name];
  console.log(`${run.name.padEnd(28)} 완주 ${(100 * (s.ends.complete ?? 0)).toFixed(0)}% 좌초 ${(100 * (s.ends.stranded ?? 0)).toFixed(0)}% `
    + `위기안건 ${s.forcedPerGame} 가혹법 ${s.harshPassed} 법 ${s.lawsPassed} 석탄최저 ${s.coalMin} 식량최저 ${s.foodMin} `
    + `석탄<30 ${s.coalUnder30} 식량<30 ${s.foodUnder30} 죽음 ${s.deaths} S1a카드 ${s.s1aCards} 내정카드 ${s.domCards}(${s.domCardsP10}~${s.domCardsP90})`);
  const r = s.repeat;
  console.log(`${''.padEnd(28)} 이동사건 ${r.travelCards}(반복 ${r.travelRepeats}) 콘텐츠사건 ${r.contentCards}(반복 ${r.contentRepeats}) 제목반복 ${r.titleRepeats}/${r.titleTotal}(${(100 * r.titleRepeatRate).toFixed(1)}%) `
    + `이동사건없는구간 ${r.segsNoTravel}/${r.segs}(쉼 ${r.segsNoTravelRest} 빔 ${r.segsNoTravelEmpty} 그외 ${r.segsNoTravelOther}) 구간별카드[0,1,2,3,4+] ${r.cardsPerSegDist.join('/')} 최대 ${r.cardsPerSegMax}`);
}
console.log(`(${N}판씩, ${((Date.now() - t0) / 1000).toFixed(1)}초${Object.keys(sets).length ? `, 바꾼 값 ${JSON.stringify(sets)}` : ''})`);
if (OUT) writeFileSync(OUT, JSON.stringify({ n: N, sets, runs: out }, null, 2));
