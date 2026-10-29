// 결정 471 G1: 법 되돌리기가 얼마나 잦은지, 되돌린 회기에 신임·긴장·칸 관계가 어떻게 움직이는지,
// 판을 따라 칸 관계가 한쪽으로 벌어지는지(정차 10번 뒤 퍼짐)를 실제 봇으로 잰다. 게임과 봇은 바꾸지 않고 probe로 읽기만 한다.
// 사용: npx tsx tools/repeal_sim.ts [판 수=100] [JSON 경로] [--arms=care,kind,tyrant]
import { writeFileSync } from 'node:fs';
import { COMMS, seats } from '../src/game';
import type { Comm, Game } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const ARMS = ['care', 'kind', 'tyrant'] as const;
type Arm = typeof ARMS[number];
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged' };
const OPTS: Record<Arm, BotOptions> = { care: BASE, kind: { ...BASE, s1b: 'kind' }, tyrant: { ...BASE, s1b: 'tyrant' } };
/** 합격(카드 G1): 되돌리기 몫 상한, 퍼짐을 보는 정차 번호 */
const G1 = { repealShareMax: 0.3, spreadStop: 10 } as const;

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const n = Number(args[0] ?? 100);
const out = args[1];
if (!Number.isSafeInteger(n) || n < 1) throw new Error('판 수는 1 이상의 정수여야 한다');
if (args.length > 2 || flags.some(f => !f.startsWith('--arms=')) || flags.length > 1) {
  throw new Error('사용: repeal_sim.ts [판 수=100] [JSON] [--arms=care,kind,tyrant]');
}
const selected = flags[0]?.slice('--arms='.length).split(',') ?? [...ARMS];
if (!selected.length || selected.some(a => !ARMS.includes(a as Arm)) || new Set(selected).size !== selected.length) {
  throw new Error('--arms는 care,kind,tyrant 중 겹치지 않게 고른다');
}
const arms = selected as Arm[];

const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);
const sum = (xs: number[]) => xs.reduce((s, x) => s + x, 0);
const sd = (xs: number[]) => Math.sqrt(mean(xs.map(x => (x - mean(xs)) ** 2)));
const f2 = (x: number) => x.toFixed(2);
const pct = (x: number) => `${(100 * x).toFixed(1)}%`;

/** 칸 다섯의 관계 퍼짐과 의석 몫 퍼짐 */
const relSd = (g: Game) => sd(COMMS.map(c => g.comms[c].rel));
const seatSd = (g: Game) => { const s = seats(g); return sd(COMMS.map(c => s[c])); };

interface Snap { session: number; repeals: number; trust: number; tension: number; rel: Record<Comm, number> }
const snap = (g: Game): Snap => ({
  session: g.session, repeals: g.stats.repeals, trust: g.trust, tension: g.tension,
  rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>,
});
/** 회기가 낀 정산 사이의 바뀜. 되돌린 회기와 아닌 회기를 갈라 견준다 */
interface Step { repealed: boolean; dTrust: number; dTension: number; dRelMin: number; dRelSum: number }

interface Row {
  seed: string; end: string; complete: boolean; councils: number; lawsPassed: number; lawsFailed: number; repeals: number;
  betrayals: number; relSd0: number; relSdAt: number | null; relSdEnd: number; seatSd0: number; seatSdAt: number | null; seatSdEnd: number;
  steps: Step[];
}

function playOne(arm: Arm, seed: string): Row {
  let prev: Snap | null = null;
  let stops = 0;
  let relSd0 = Number.NaN;
  let seatSd0 = Number.NaN;
  let relSdAt: number | null = null;
  let seatSdAt: number | null = null;
  const steps: Step[] = [];
  const { g, m } = playGame(seed, { ...OPTS[arm], probe: {
    onSettle: (gg) => {
      const now = snap(gg);
      if (prev === null) { relSd0 = relSd(gg); seatSd0 = seatSd(gg); }
      else if (now.session > prev.session) {
        const p = prev;
        steps.push({
          repealed: now.repeals > p.repeals, dTrust: now.trust - p.trust, dTension: now.tension - p.tension,
          dRelMin: Math.min(...COMMS.map(c => now.rel[c] - p.rel[c])), dRelSum: sum(COMMS.map(c => now.rel[c] - p.rel[c])),
        });
      }
      prev = now;
    },
    afterStop: (gg) => {
      stops += 1;
      if (stops === G1.spreadStop) { relSdAt = relSd(gg); seatSdAt = seatSd(gg); }
    },
  } });
  return {
    seed, end: m.end, complete: m.end === 'complete', councils: m.councils, lawsPassed: g.stats.lawsPassed, lawsFailed: g.stats.lawsFailed,
    repeals: g.stats.repeals, betrayals: g.journal.filter(j => j.text.includes('배신으로 기억')).length,
    relSd0, relSdAt, relSdEnd: relSd(g), seatSd0, seatSdAt, seatSdEnd: seatSd(g), steps,
  };
}

function summarize(rows: Row[]) {
  const steps = rows.flatMap(r => r.steps);
  const withRepeal = steps.filter(s => s.repealed);
  const without = steps.filter(s => !s.repealed);
  const reached = rows.filter(r => r.relSdAt !== null);
  const passed = sum(rows.map(r => r.lawsPassed));
  const repeals = sum(rows.map(r => r.repeals));
  const repealShare = passed > 0 ? repeals / passed : 0;
  const relSd0 = mean(reached.map(r => r.relSd0));
  const relSdAt = mean(reached.map(r => r.relSdAt as number));
  const side = (xs: Step[]) => ({
    n: xs.length, dTrust: mean(xs.map(s => s.dTrust)), dTension: mean(xs.map(s => s.dTension)),
    dRelMin: mean(xs.map(s => s.dRelMin)), dRelSum: mean(xs.map(s => s.dRelSum)),
  });
  return {
    games: rows.length, complete: rows.filter(r => r.complete).length / rows.length,
    councilsPerGame: mean(rows.map(r => r.councils)), lawsPerGame: passed / rows.length,
    failedPerGame: mean(rows.map(r => r.lawsFailed)), repealsPerGame: repeals / rows.length,
    gamesWithRepeal: rows.filter(r => r.repeals > 0).length / rows.length, repealShare,
    betrayalsPerGame: mean(rows.map(r => r.betrayals)),
    councilStep: { repeal: side(withRepeal), other: side(without) },
    spread: {
      reachedStop: reached.length, relSd0, relSdAt, relSdEnd: mean(rows.map(r => r.relSdEnd)),
      seatSd0: mean(reached.map(r => r.seatSd0)), seatSdAt: mean(reached.map(r => r.seatSdAt as number)), seatSdEnd: mean(rows.map(r => r.seatSdEnd)),
    },
    pass: { repealShare: repealShare <= G1.repealShareMax, spreadGrows: reached.length > 0 && relSdAt > relSd0 },
  };
}

const results: Partial<Record<Arm, { summary: ReturnType<typeof summarize>; rows: Row[] }>> = {};
for (const arm of arms) {
  const rows = Array.from({ length: n }, (_, i) => playOne(arm, `rp-${i}`));
  const s = summarize(rows);
  results[arm] = { summary: s, rows };
  console.log(`[${arm}] ${n}판 완주 ${pct(s.complete)} · 회기 ${f2(s.councilsPerGame)} · 세운 법 ${f2(s.lawsPerGame)} · 부결 ${f2(s.failedPerGame)} · 되돌리기 ${f2(s.repealsPerGame)}(몫 ${pct(s.repealShare)}, 있는 판 ${pct(s.gamesWithRepeal)}) · 배신 ${f2(s.betrayalsPerGame)}`);
  const r = s.councilStep.repeal;
  const o = s.councilStep.other;
  console.log(`  회기 낀 정산 사이 — 되돌림 ${r.n}번: 신임 ${f2(r.dTrust)} 긴장 ${f2(r.dTension)} 관계 가장 깎인 칸 ${f2(r.dRelMin)} 관계 합 ${f2(r.dRelSum)} / 아님 ${o.n}번: ${f2(o.dTrust)} ${f2(o.dTension)} ${f2(o.dRelMin)} ${f2(o.dRelSum)}`);
  const p = s.spread;
  console.log(`  칸 관계 퍼짐(표준편차) 처음 ${f2(p.relSd0)} → 정차 ${G1.spreadStop} ${f2(p.relSdAt)} → 끝 ${f2(p.relSdEnd)} (닿은 판 ${p.reachedStop}) · 의석 퍼짐 ${f2(p.seatSd0)} → ${f2(p.seatSdAt)} → ${f2(p.seatSdEnd)}`);
  console.log(`  합격: 되돌리기 몫 ≤ ${pct(G1.repealShareMax)} ${s.pass.repealShare} · 정차 ${G1.spreadStop} 뒤 관계 퍼짐 > 처음 ${s.pass.spreadGrows}`);
}
if (out) writeFileSync(out, JSON.stringify({ n, arms, g1: G1, results }, null, 1));
