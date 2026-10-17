// 죽음의 무게(death_weight.ts, 결정 353~355·367) 재기: 같은 씨앗을 끈 판과 켠 판으로 돌려 견준다.
// 사용: npx tsx tools/death_weight_sim.ts [판 수=500] [결과 JSON 경로]
// 봇: 내정·재난을 켠 돌봄 봇(명세 8절). 끈 판이 기준이다(같은 커밋).

import { writeFileSync } from 'node:fs';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';
import { lawOpen } from '../src/game';
import type { Game, LawId } from '../src/game';

const n = Number(process.argv[2] ?? 500);
const out = process.argv[3];
const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged', disasters: true };
const DEATH_CARDS = ['orphan', 'keepsake', 'loss_rep', 'loss_child', 'loss_hand', 'chain_push', 'chain_fix', 'heat_after'];
const BUCKETS = [['0', 0, 0], ['1~2', 1, 2], ['3~5', 3, 5], ['6+', 6, 1e9]] as const;

interface Row { end: string; deaths: number; deathCards: number; trustCrisis: boolean; emergency: number; rite: boolean; hands: boolean; trustEnd: number; chains?: NonNullable<Game['deathStats']> }

/** force: 그 「배웅」 법이 열리는 첫 정산에 세운 것으로 친다(봇이 그 안건을 안 골라 두 갈래를 견주려는 측정용 개입) */
function run(on: boolean, force?: LawId): Row[] {
  const rows: Row[] = [];
  for (let i = 0; i < n; i += 1) {
    let crisis = false;
    const { g, m } = playGame(`dw-${i}`, { ...BASE, ...(on ? { deathWeight: true } : {}), probe: { onSettle: x => { if (x.trustCrisis !== null) crisis = true; if (force && x.passed[force] === undefined && lawOpen(x, force)) x.passed[force] = x.session; } } });
    rows.push({
      end: g.end ?? 'none', deaths: g.deaths.length, deathCards: DEATH_CARDS.reduce((s, k) => s + (m.cards[k] ?? 0), 0), trustCrisis: crisis,
      emergency: (g.emergencyCalls ?? []).length, rite: g.passed.farewell_rite !== undefined, hands: g.passed.farewell_hands !== undefined, trustEnd: g.trust,
      ...(g.deathStats ? { chains: g.deathStats } : {}),
    });
  }
  return rows;
}

const pct = (k: number, of: number) => (of ? (100 * k) / of : 0);
function summary(rows: Row[]) {
  const done = (r: Row[]) => pct(r.filter(x => x.end === 'complete').length, r.length);
  const revolt = (r: Row[]) => pct(r.filter(x => x.end === 'revolt').length, r.length);
  const buckets = BUCKETS.map(([name, lo, hi]) => { const r = rows.filter(x => x.deaths >= lo && x.deaths <= hi); return { name, games: r.length, complete: done(r), revolt: revolt(r) }; });
  const sum = (f: (r: Row) => number) => rows.reduce((s, r) => s + f(r), 0);
  const mean = (f: (r: Row) => number) => sum(f) / rows.length;
  // 죽음 한 명당 완주율 기울기: 판의 죽음 수와 완주(1/0)의 최소제곱 기울기(%p/명)
  const mx = mean(r => r.deaths);
  const my = mean(r => (r.end === 'complete' ? 1 : 0));
  const cov = sum(r => (r.deaths - mx) * ((r.end === 'complete' ? 1 : 0) - my));
  const vx = sum(r => (r.deaths - mx) ** 2);
  const sub = (f: (r: Row) => boolean) => { const r = rows.filter(f); return { games: r.length, complete: done(r), revolt: revolt(r), deaths: r.length ? r.reduce((s, x) => s + x.deaths, 0) / r.length : 0 }; };
  const ch = rows.filter(r => r.chains).map(r => r.chains!);
  return {
    games: rows.length, complete: done(rows), revolt: revolt(rows), deathsMean: mx, slopePerDeath: vx ? (100 * cov) / vx : 0, buckets,
    gap6vs02: (buckets[3].games && (buckets[0].games + buckets[1].games)) ? done(rows.filter(r => r.deaths <= 2)) - buckets[3].complete : null,
    deathCardsMean: mean(r => r.deathCards), deathCardsMax: Math.max(...rows.map(r => r.deathCards)),
    trustCrisis: pct(rows.filter(r => r.trustCrisis).length, rows.length), emergencyMean: mean(r => r.emergency), trustEndMean: mean(r => r.trustEnd),
    chains: ch.length ? {
      opened: ch.reduce((s, c) => s + c.opened, 0) / ch.length, fixed: ch.reduce((s, c) => s + c.fixed, 0) / ch.length,
      unfixed: ch.reduce((s, c) => s + c.unfixed, 0) / ch.length, broken: ch.reduce((s, c) => s + c.broken, 0) / ch.length,
      maxOpen: Math.max(...ch.map(c => c.maxOpen)), cards: ch.reduce((s, c) => s + c.cards, 0) / ch.length,
    } : null,
    rite: sub(r => r.rite), hands: sub(r => r.hands), neither: sub(r => !r.rite && !r.hands),
  };
}

const t0 = Date.now();
const off = summary(run(false));
const on = summary(run(true));
const rite = summary(run(true, 'farewell_rite'));
const hands = summary(run(true, 'farewell_hands'));
const res = { n, bot: BASE, off, on, rite, hands, secs: (Date.now() - t0) / 1000 };
console.log(JSON.stringify(res, null, 2));
if (out) writeFileSync(out, JSON.stringify(res, null, 2));
