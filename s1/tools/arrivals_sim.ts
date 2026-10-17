// 사람이 들어오는 사건(arrivals.ts, 결정 352·369) 재기: 같은 씨앗을 빈도·봇·선택 규칙별로 돌려 견준다(명세 7장).
// 사용: npx tsx tools/arrivals_sim.ts [판 수=500] [결과 JSON 경로] [--rate=off|low|mid|high] [--bot=care|event|nolever] [--pick=bot|uniform] [--ar=AR키:값]
// event: 돌봄 봇 + 사람을 받은 칸의 레버를 사건에 맞춰 고르는 규칙(s1c_bot.ts arrivalLevers, 결정 369 2차)
// 봇: 내정·재난을 켠 돌봄 봇(지금 500판 기준과 같게). 레버 조작 수는 출발 전 운영에서 봇이 바꾼 난방·배급 레버 칸 수와 공간 레버 바뀜 수다.

import { writeFileSync } from 'node:fs';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';
import { AR, COMMS } from '../src/game';
import type { Game } from '../src/game';

const args = process.argv.slice(2);
const pos = args.filter(a => !a.startsWith('--'));
const flag = (k: string, d: string) => args.find(a => a.startsWith(`--${k}=`))?.slice(k.length + 3) ?? d;
const n = Number(pos[0] ?? 500);
const out = pos[1];
const rate = flag('rate', 'mid');
const bot = flag('bot', 'care');
const pick = flag('pick', 'bot');
const RATES: Record<string, [number, number]> = { low: [0.06, 0.03], mid: [0.12, 0.06], high: [0.24, 0.12] };
if (rate !== 'off') [AR.stopP, AR.travelP] = RATES[rate];
const arSets: Record<string, number> = {};
for (const f of args.filter(x => x.startsWith('--ar='))) {
  const [k, v] = f.slice(5).split(':');
  if (!(k in AR)) throw new Error(`AR에 없는 값: ${k}`);
  (AR as unknown as Record<string, number>)[k] = Number(v);
  arSets[k] = Number(v);
}
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged', disasters: true, ...(bot === 'nolever' ? { noLevers: true } : {}), ...(bot === 'event' ? { arrivalLevers: true } : {}), ...(rate !== 'off' ? { arrivals: true } : {}) };

interface Row { end: string; deaths: number; taken: number; turned: number; riot: boolean; fever: number; ops: number; opsAfter: number; segsAfter: number; opsQuiet: number; segsQuiet: number; cards: number; picks: Record<string, number> }

type Snap = string[];
const snap = (g: Game): Snap => [...COMMS.flatMap(c => [`${g.comms[c].heat}`, `${g.comms[c].ration}`]), `${g.space?.giver ?? ''}:${g.space?.step ?? 0}`];
const diff = (a: Snap, b: Snap): number => a.reduce((s, x, i) => s + (x === b[i] ? 0 : 1), 0);

function rand(seed: string): () => number {
  let x = 2166136261;
  for (let i = 0; i < seed.length; i += 1) x = Math.imul(x ^ seed.charCodeAt(i), 16777619);
  return () => { x = Math.imul(x ^ (x >>> 15), 2246822507) ^ Math.imul(x ^ (x >>> 13), 3266489909); return ((x >>>= 0) % 1e6) / 1e6; };
}

function run(): Row[] {
  const rows: Row[] = [];
  for (let i = 0; i < n; i += 1) {
    const r = rand(`ar-pick-${i}`);
    let before: Snap = [];
    const opsBySeg = new Map<number, number>();
    const entered = new Set<number>();
    let lastTaken = 0;
    const picks: Record<string, number> = {};
    const { g, m } = playGame(`ar-${i}`, {
      ...BASE,
      ...(pick === 'uniform' ? { forcePick: (_g, card, _v, open) => (card.kind === 'arrival' || card.kind === 'family' ? open[Math.floor(r() * open.length)] : undefined) } : {}),
      probe: {
        beforePrep: x => { before = snap(x); },
        afterPrep: x => { opsBySeg.set(x.seg, diff(before, snap(x))); },
        beforePick: (_x, card, view, idx) => { if (card.kind === 'arrival' || card.kind === 'family') { const id = view.choices[idx]?.id ?? '?'; picks[id] = (picks[id] ?? 0) + 1; } },
        afterPick: x => { const t = x.arrivals?.taken ?? 0; if (t > lastTaken) entered.add(x.seg); lastTaken = t; },
        afterStop: x => { const t = x.arrivals?.taken ?? 0; if (t > lastTaken) entered.add(x.seg); lastTaken = t; },
      },
    });
    let opsAfter = 0; let segsAfter = 0; let opsQuiet = 0; let segsQuiet = 0;
    for (const [seg, ops] of opsBySeg) {
      const after = [...entered].some(s => seg > s && seg <= s + 3);
      if (after) { opsAfter += ops; segsAfter += 1; } else { opsQuiet += ops; segsQuiet += 1; }
    }
    rows.push({
      end: g.end ?? 'none', deaths: g.deaths.length, taken: g.arrivals?.taken ?? 0, turned: g.arrivals?.turned ?? 0, riot: g.riot.riots > 0,
      fever: (g.dom?.stats as { typhus?: number } | undefined)?.typhus ?? 0, ops: [...opsBySeg.values()].reduce((a, b) => a + b, 0),
      opsAfter, segsAfter, opsQuiet, segsQuiet, cards: (m.cards.arrival ?? 0) + (m.cards.family ?? 0), picks,
    });
  }
  return rows;
}

const pct = (k: number, of: number) => (of ? (100 * k) / of : 0);
const t0 = Date.now();
const rows = run();
const mean = (f: (r: Row) => number) => rows.reduce((s, r) => s + f(r), 0) / rows.length;
const tot = (f: (r: Row) => number) => rows.reduce((s, r) => s + f(r), 0);
const picks: Record<string, number> = {};
for (const r of rows) for (const [k, v] of Object.entries(r.picks)) picks[k] = (picks[k] ?? 0) + v;
const rateAfter = tot(r => r.opsAfter) / Math.max(1, tot(r => r.segsAfter));
const rateQuiet = tot(r => r.opsQuiet) / Math.max(1, tot(r => r.segsQuiet));
const res = {
  n, rate, bot, pick, ar: { stopP: AR.stopP, travelP: AR.travelP, ...arSets },
  complete: pct(rows.filter(r => r.end === 'complete').length, n), revolt: pct(rows.filter(r => r.end === 'revolt').length, n), coup: pct(rows.filter(r => r.end === 'coup').length, n),
  riotGames: pct(rows.filter(r => r.riot).length, n), deathsMean: mean(r => r.deaths), takenMean: mean(r => r.taken), turnedMean: mean(r => r.turned),
  feverMean: mean(r => r.fever), opsMean: mean(r => r.ops), opsRateAfter: rateAfter, opsRateQuiet: rateQuiet, afterOverQuiet: rateQuiet ? rateAfter / rateQuiet : null,
  cardsMean: mean(r => r.cards), cardsMax: Math.max(...rows.map(r => r.cards)), picks, secs: (Date.now() - t0) / 1000,
};
console.log(JSON.stringify(res, null, 2));
if (out) writeFileSync(out, JSON.stringify(res, null, 2));
