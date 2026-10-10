// 통합 보고서 17.1(완주율 하나로 판정하지 않는다)의 다섯 물음을 재는 도구. 게임 규칙과 숫자는 건드리지 않는다.
// 사용: npx tsx tools/measure_17_1.ts <시작 번호> <끝 번호(포함 안 함)> <결과 JSON> [--paired] [--stock] [--off]
//   기본: 시드 sim-<번호> 판을 새 사건 묶음을 켜고 첫 칸 봇(S1a+S1c caretaker engaged, s1c_sim의 기준 실행)으로 한 번 돌려
//         새 사건 고름·정차·끝을 기록한다(rows[].base).
//   --paired: 그 판에서 처음 나온 새 사건 카드마다, 같은 시드·같은 앞부분으로 다른 칸을 강제로 골라 다시 돌린다(rows[].forced).
//   --stock: 낮아진 불(H01)·흰 바람(H08)이 처음 나온 순간 석탄·식량을 30씩 얹어(개입) 다시 돌린다(rows[].stock).
//   --off: 새 사건 묶음을 끈 판(필수 조작 수 비교용).
// --reader는 새 사건 카드만 상태를 읽고 고르고 나머지 카드는 기준 봇 규칙을 따른다.
// --stock의 얹기는 측정용 가정이지 게임의 새 규칙이 아니다. 뽑기 난수는 앞부분이 같아도 개입 뒤에는 달라질 수 있다.

import { writeFileSync } from 'node:fs';
import { COMMS, CONTENT_CARD_KIND, situation } from '../src/game';
import type { Game } from '../src/game';
import { playGame, scoreChoice } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const FROM = Number(args[0] ?? 0);
const TO = Number(args[1] ?? 100);
const OUT = args[2];
const paired = flags.includes('--paired');
const stock = flags.includes('--stock');
const off = flags.includes('--off');
// --reader: 새 사건 카드를 상태를 읽고 고른다(s1c_bot의 효과 점수. 석탄·식량이 적을수록 그 효과를 무겁게 본다). 기본은 첫 칸.
const reader = flags.includes('--reader');

const BASE: BotOptions = { s1c: true, policy: 'caretaker', dom: 'engaged', ...(off ? {} : { eventPack: true }) };
const isPack = (id: string) => id.startsWith('ev_b01_') || /^ev_h\d\d_/u.test(id);

interface Snap {
  seg: number; coal: number; food: number; med: number; trust: number; tension: number; fear: number;
  pop: number; away: number; avail: number; rel: number; expo: number; tailExpo: number; warm: number; ration: number;
  restored: number; deaths: number; flags: number; low: number;
}
function snap(g: Game): Snap {
  let pop = 0, away = 0, rel = 0, expo = 0, warm = 0, ration = 0, low = 0;
  for (const c of COMMS) {
    const s = g.comms[c];
    pop += s.pop; away += s.away; rel += s.rel;
    const [w, r, , e] = situation(g, c);
    expo += e; warm += w; ration += r;
    if (w <= 25 || r <= 25) low += 1;
  }
  return {
    seg: g.seg, coal: g.coal, food: g.food, med: g.med, trust: g.trust, tension: g.tension, fear: g.fear,
    pop, away, avail: pop - away, rel, expo, tailExpo: situation(g, 'tail')[3], warm: +(warm / COMMS.length).toFixed(1), ration: +(ration / COMMS.length).toFixed(1),
    restored: g.dom?.stats.restored ?? 0, deaths: g.deaths.length, flags: Object.keys(g.contentFlags ?? {}).length, low,
  };
}

/** 새 사건 카드 하나를 고른 기록. later는 그 뒤 구간 정산 세 번 뒤의 모습. */
interface PickRow { id: string; idx: number; choiceId: string; openIdx: number[]; seg: number; before: Snap; after: Snap; later: Snap[] }
interface StopRow { seg: number; gain: number; passed: boolean; dead: number; stockBefore: number; restored: number; avail: number; tension: number }
interface GameRow {
  seed: string; end: string; segReached: number; tensionEnd: number; coalMin: number; foodMin: number;
  picks: PickRow[]; stops: StopRow[];
  cards: number; domCards: number; s1aCards: number; dom?: Record<string, number>; endSnap: Snap; minRel: number;
}

interface RunOpts {
  /** 이 카드(id)가 처음 나오면 이 칸(view.choices 번호)을 고른다 */
  force?: { id: string; idx: number };
  /** 이 카드들이 처음 나오면 석탄·식량을 얹는다 */
  bump?: { ids: string[]; coal: number; food: number };
}
function run(seed: string, ro: RunOpts = {}): GameRow {
  const picks: PickRow[] = [];
  const stops: StopRow[] = [];
  const pending: PickRow[] = [];
  const seenForce = new Set<string>();
  const seenBump = new Set<string>();
  let cur: Omit<PickRow, 'after' | 'later'> | null = null;
  const { g, m } = playGame(seed, {
    ...BASE,
    forcePick: (gg, card, _view, open) => {
      if (card.kind !== CONTENT_CARD_KIND || !card.text) return undefined;
      if (ro.bump && ro.bump.ids.includes(card.text) && !seenBump.has(card.text)) {
        seenBump.add(card.text);
        gg.coal += ro.bump.coal; gg.food += ro.bump.food;
      }
      if (ro.force && card.text === ro.force.id && !seenForce.has(card.text)) {
        seenForce.add(card.text);
        return open.includes(ro.force.idx) ? ro.force.idx : undefined;
      }
      if (reader && isPack(card.text)) {
        let best = -1e9, bi: number | undefined;
        for (const i of open) { const s = scoreChoice(gg, _view.choices[i]); if (s > best) { best = s; bi = i; } }
        return bi;
      }
      return undefined;
    },
    probe: {
      beforePick: (gg, card, view, idx) => {
        if (card.kind !== CONTENT_CARD_KIND || !card.text || !isPack(card.text)) { cur = null; return; }
        const sp = view.choices[idx]?.special ?? '';
        cur = { id: card.text, idx, choiceId: sp.replace(/^content:/u, ''), openIdx: view.choices.map((c, i) => (c.disabled ? -1 : i)).filter(i => i >= 0), seg: gg.seg, before: snap(gg) };
      },
      afterPick: (gg) => {
        if (!cur) return;
        const row: PickRow = { ...cur, after: snap(gg), later: [] };
        picks.push(row); pending.push(row);
        cur = null;
      },
      onSettle: (gg) => {
        const s = snap(gg);
        for (let i = pending.length - 1; i >= 0; i -= 1) {
          pending[i].later.push(s);
          if (pending[i].later.length >= 3) pending.splice(i, 1);
        }
      },
      afterStop: (gg) => {
        const r = gg.stop?.result;
        if (!r) return;
        const gain = Object.values(r.gains).reduce((a, b) => a + (b ?? 0), 0);
        const s = snap(gg);
        stops.push({ seg: gg.seg, gain, passed: r.passed, dead: r.dead.length, stockBefore: s.coal + s.food - (r.gains.coal ?? 0) - (r.gains.food ?? 0), restored: s.restored, avail: s.avail, tension: s.tension });
      },
    },
  });
  const d = g.dom;
  return {
    seed, end: m.end, segReached: m.segReached, tensionEnd: m.tensionEnd, coalMin: m.coalMin, foodMin: m.foodMin,
    endSnap: snap(g), minRel: Math.min(...COMMS.map(c => g.comms[c].rel)),
    picks, stops, cards: Object.values(m.cards).reduce((a, b) => a + b, 0), domCards: m.domCards, s1aCards: m.s1aCards,
    ...(d ? { dom: { restored: d.stats.restored, repairs: d.stats.repairs, breakdowns: d.stats.breakdowns, demands: d.stats.demands, partsMade: d.stats.partsMade, apprentices: d.stats.apprentices, manuals: d.stats.manuals } } : {}),
  };
}

const t0 = Date.now();
const rows: { seed: string; base: GameRow; forced?: Record<string, Record<number, GameRow>>; stock?: GameRow }[] = [];
for (let i = FROM; i < TO; i += 1) {
  const seed = `sim-${i}`;
  const base = run(seed);
  const row: (typeof rows)[number] = { seed, base };
  if (paired) {
    row.forced = {};
    const seen = new Set<string>();
    for (const p of base.picks) {
      if (seen.has(p.id)) continue;
      seen.add(p.id);
      const byIdx: Record<number, GameRow> = {};
      // 기준 판이 고른 칸은 base 기록을 그대로 쓰고, 나머지 열린 칸만 다시 돌린다.
      for (const k of p.openIdx) {
        if (k === p.idx) continue;
        byIdx[k] = run(seed, { force: { id: p.id, idx: k } });
      }
      row.forced[p.id] = byIdx;
    }
  }
  if (stock) {
    const ids = ['ev_h01_low_fire', 'ev_h08_white_wind'].filter(id => base.picks.some(p => p.id === id));
    if (ids.length > 0) row.stock = run(seed, { bump: { ids, coal: 30, food: 30 } });
  }
  rows.push(row);
}
if (OUT) writeFileSync(OUT, JSON.stringify({ from: FROM, to: TO, paired, stock, off, reader, rows }));
console.log(`done ${FROM}..${TO} ${rows.length}판 ${((Date.now() - t0) / 1000).toFixed(1)}초`);
