// 긴장이 오르는 길을 나눠 잰다(사건 20장 켬/끔 비교). 규칙과 숫자는 건드리지 않고 판을 읽기만 한다.
// 사용: npx tsx tools/tension_probe.ts [판 수=1000] [off|on] [실행번호=1] [결과 JSON 경로] [--score] [--uniform]
// 실행번호는 s1c_sim.ts의 RUNS 순서(0 S1a caretaker, 1 S1a+S1c caretaker engaged, 2 idle, 3 S1a first, 4 first engaged). 시드는 sim-0 ~ sim-(N-1)로 s1c_sim.ts와 같다.
// 재는 것: (가) 구간 정산 때 긴장 올림 몫(turn.ts meters의 inc)을 낱낱으로 쪼갠 값, (나) 카드 id별 직접 긴장·처지 변화, (다) 구간별 긴장 평균, (라) 긴장 변화 합계가 맞는지(남는 몫).

import { writeFileSync } from 'node:fs';
import { COMMS, CONTENT_CARD_KIND, DRAW, situation } from '../src/game';
import type { Game } from '../src/game';
import { playGame } from './s1c_bot';
import type { BotOptions } from './s1c_bot';

const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const flags = process.argv.slice(2).filter(a => a.startsWith('--'));
const N = Number(args[0] ?? 1000);
const MODE = args[1] ?? 'off';
const RUN = Number(args[2] ?? 1);
const OUT = args[3];
if (MODE !== 'off' && MODE !== 'on') throw new Error('두 번째 인자는 off나 on');
const scoreCards = flags.includes('--score');
// --uniform: 켠 판의 가중 뽑기를 균등으로 되돌린다(새 사건 20장이 들어간 효과와 가중 뽑기 효과를 가르려는 측정용. 저장소 값은 그대로).
const uniform = flags.includes('--uniform');
if (uniform) Object.assign(DRAW, { pressMax: 1, tenderBase: 1, seen1: 1, seen2: 1, speakerPenalty: 1 });

const RUNS: BotOptions[] = [
  { s1c: false, policy: 'caretaker', dom: 'idle' },
  { s1c: true, policy: 'caretaker', dom: 'engaged' },
  { s1c: true, policy: 'caretaker', dom: 'idle' },
  { s1c: false, policy: 'first', dom: 'idle' },
  { s1c: true, policy: 'first', dom: 'engaged' },
];

/** turn.ts meters의 inc를 같은 식으로 쪼갠다(내정 방송 tensionCut·법 tensionAdd는 빼고 센다). */
function parts(g: Game) {
  const p = { relTail: 0, relOther: 0, relMild: 0, warmLow: 0, rationLow: 0, bothLow: 0, noFood: 0 };
  for (const c of COMMS) {
    const rel = g.comms[c].rel;
    if (rel <= -40) { if (c === 'tail') p.relTail += 3; else p.relOther += 2; } else if (rel <= -15) p.relMild += 1;
    const [w, r] = situation(g, c);
    if (w <= 25 && r <= 25) p.bothLow += 2; else if (w <= 25) p.warmLow += 2; else if (r <= 25) p.rationLow += 2;
  }
  if (g.food <= 0) p.noFood = 8;
  return p;
}
type Parts = ReturnType<typeof parts>;
const sumParts = (p: Parts) => p.relTail + p.relOther + p.relMild + p.warmLow + p.rationLow + p.bothLow + p.noFood;
/** 지금 상태에서 구간마다 붙는 긴장 몫(inc)과 그 속 칸별 낮은 처지 수 */
const incNow = (g: Game) => sumParts(parts(g));
const lowCount = (g: Game) => COMMS.reduce((s, c) => { const [w, r] = situation(g, c); return s + (w <= 25 || r <= 25 ? 1 : 0); }, 0);
const relSum = (g: Game) => COMMS.reduce((s, c) => s + g.comms[c].rel, 0);

interface Acc { dTail: number; n: number; direct: number; dInc: number; dLow: number; dRel: number; dCoal: number; dFood: number; dTrust: number }
const newAcc = (): Acc => ({ dTail: 0, n: 0, direct: 0, dInc: 0, dLow: 0, dRel: 0, dCoal: 0, dFood: 0, dTrust: 0 });

const byCard: Record<string, Acc> = {};
/** 칸별 관계(rel) 변화의 출처: 카드 고름 / 구간 정산 / 그 밖(의회·정차 등). 판당 합 */
const relSrc: Record<string, { pick: number; settle: number; total: number; end: number }> = Object.fromEntries(COMMS.map(c => [c, { pick: 0, settle: 0, total: 0, end: 0 }]));
const relBySeg: Record<string, Record<number, { n: number; sum: number; low: number }>> = Object.fromEntries(COMMS.map(c => [c, {}]));
let relAtStart: Record<string, number> = {};
const byKind: Record<string, Acc> = {};
const settleParts: Record<string, number> = { relTail: 0, relOther: 0, relMild: 0, warmLow: 0, rationLow: 0, bothLow: 0, noFood: 0, settles: 0, settleDelta: 0, pickDelta: 0, otherDelta: 0, incRaw: 0 };
const tensionBySeg: Record<number, { n: number; sum: number }> = {};
const settleDeltaBySeg: Record<number, { n: number; sum: number; inc: number }> = {};
const totals = { games: 0, tensionStart: 0, tensionEnd: 0 };
const ends: Record<string, number> = {};

const opts: BotOptions = { ...RUNS[RUN], ...(MODE === 'on' ? { eventPack: true } : {}), ...(scoreCards ? { scoreCards: true } : {}) };

for (let i = 0; i < N; i += 1) {
  let snapRel: Record<string, number> = {};
  const gamePickRel: Record<string, number> = Object.fromEntries(COMMS.map(c => [c, 0]));
  const gameSettleRel: Record<string, number> = Object.fromEntries(COMMS.map(c => [c, 0]));
  let snap = { tension: 0, inc: 0, low: 0, rel: 0, coal: 0, food: 0, trust: 0 };
  let prevT = 20; // P.tension0. 첫 고름 전에 틀어진 값은 없다.
  let gameSettleDelta = 0;
  let gamePickDelta = 0;
  let startT: number | null = null;
  const { g, m } = playGame(`sim-${i}`, {
    ...opts,
    probe: {
      beforePick: (gg) => {
        if (startT === null) { startT = gg.tension; relAtStart = Object.fromEntries(COMMS.map(c => [c, gg.comms[c].rel])); }
        snapRel = Object.fromEntries(COMMS.map(c => [c, gg.comms[c].rel]));
        snap = { tension: gg.tension, inc: incNow(gg), low: lowCount(gg), rel: relSum(gg), coal: gg.coal, food: gg.food, trust: gg.trust };
      },
      afterPick: (gg, card) => {
        const key = card.kind === 'travel' ? `travel:${card.text}` : card.kind === CONTENT_CARD_KIND ? `content:${card.text}` : card.kind;
        const kind = card.kind === 'travel' ? 'travel(옛 이동 사건)' : card.kind === CONTENT_CARD_KIND ? 'content(새 묶음 포함 JSON 사건)' : card.kind;
        const d = gg.tension - snap.tension;
        gamePickDelta += d;
        for (const c of COMMS) gamePickRel[c] += gg.comms[c].rel - snapRel[c];
        for (const [map, k] of [[byCard, key], [byKind, kind]] as const) {
          const a = (map[k] ??= newAcc());
          a.n += 1; a.direct += d; a.dInc += incNow(gg) - snap.inc; a.dLow += lowCount(gg) - snap.low; a.dRel += relSum(gg) - snap.rel; a.dTail += gg.comms.tail.rel - snapRel.tail;
          a.dCoal += gg.coal - snap.coal; a.dFood += gg.food - snap.food; a.dTrust += gg.trust - snap.trust;
        }
      },
      onSettle: (gg) => {
        const st = gg.lastSettle!;
        const p = parts(gg);
        for (const k of Object.keys(p) as (keyof Parts)[]) settleParts[k] += p[k];
        settleParts.settles += 1;
        settleParts.settleDelta += st.tension;
        settleParts.incRaw += sumParts(p);
        gameSettleDelta += st.tension;
        for (const c of COMMS) {
          gameSettleRel[c] += st.rel[c];
          const rb = (relBySeg[c][gg.seg] ??= { n: 0, sum: 0, low: 0 });
          rb.n += 1; rb.sum += gg.comms[c].rel; if (gg.comms[c].rel <= -15) rb.low += 1;
        }
        const sg = (settleDeltaBySeg[gg.seg] ??= { n: 0, sum: 0, inc: 0 });
        sg.n += 1; sg.sum += st.tension; sg.inc += sumParts(p);
        const tb = (tensionBySeg[gg.seg] ??= { n: 0, sum: 0 });
        tb.n += 1; tb.sum += gg.tension;
        prevT = gg.tension;
      },
    },
  });
  void prevT;
  totals.games += 1;
  totals.tensionStart += startT ?? 20;
  totals.tensionEnd += g.tension;
  for (const c of COMMS) {
    relSrc[c].pick += gamePickRel[c]; relSrc[c].settle += gameSettleRel[c]; relSrc[c].end += g.comms[c].rel;
    relSrc[c].total += g.comms[c].rel - (relAtStart[c] ?? 0);
  }
  settleParts.pickDelta += gamePickDelta;
  settleParts.otherDelta += (g.tension - (startT ?? 20)) - gamePickDelta - gameSettleDelta;
  ends[m.end] = (ends[m.end] ?? 0) + 1;
}

const per = (x: number, d = 3) => +(x / N).toFixed(d);
const cardTable = (map: Record<string, Acc>) => Object.fromEntries(Object.entries(map).sort(([a], [b]) => a.localeCompare(b)).map(([k, a]) => [k, {
  n: per(a.n), direct: per(a.direct), dInc: per(a.dInc), dLow: per(a.dLow), dRel: per(a.dRel, 2), dCoal: per(a.dCoal, 2), dFood: per(a.dFood, 2), dTrust: per(a.dTrust, 2),
  dTail: per(a.dTail, 2), directPerPick: +(a.direct / Math.max(1, a.n)).toFixed(3), dIncPerPick: +(a.dInc / Math.max(1, a.n)).toFixed(3),
}]));
const result = {
  N, mode: MODE, run: RUN, scoreCards, uniform,
  ends: Object.fromEntries(Object.entries(ends).map(([k, v]) => [k, +(v / N).toFixed(3)])),
  tensionEnd: per(totals.tensionEnd, 2),
  perGame: { settles: per(settleParts.settles, 2), settleDeltaSum: per(settleParts.settleDelta, 2), pickDeltaSum: per(settleParts.pickDelta, 2), otherDeltaSum: per(settleParts.otherDelta, 2) },
  incPerSettle: Object.fromEntries(['relTail', 'relOther', 'relMild', 'warmLow', 'rationLow', 'bothLow', 'noFood', 'incRaw'].map(k => [k, +(settleParts[k] / Math.max(1, settleParts.settles)).toFixed(3)])),
  settleDeltaPerSettle: +(settleParts.settleDelta / Math.max(1, settleParts.settles)).toFixed(3),
  bySeg: Object.fromEntries(Object.keys(tensionBySeg).map(Number).sort((a, b) => a - b).map(s => [s, {
    games: tensionBySeg[s].n, tension: +(tensionBySeg[s].sum / tensionBySeg[s].n).toFixed(2),
    settleDelta: +(settleDeltaBySeg[s].sum / settleDeltaBySeg[s].n).toFixed(2), inc: +(settleDeltaBySeg[s].inc / settleDeltaBySeg[s].n).toFixed(2),
  }])),
  relSrc: Object.fromEntries(COMMS.map(c => [c, { pick: per(relSrc[c].pick, 1), settle: per(relSrc[c].settle, 1), other: per(relSrc[c].total - relSrc[c].pick - relSrc[c].settle, 1), end: per(relSrc[c].end, 1) }])),
  relBySeg: Object.fromEntries(COMMS.map(c => [c, Object.fromEntries(Object.keys(relBySeg[c]).map(Number).sort((a, b) => a - b).map(s => [s, { rel: +(relBySeg[c][s].sum / relBySeg[c][s].n).toFixed(1), lowShare: +(relBySeg[c][s].low / relBySeg[c][s].n).toFixed(2) }]))])),
  byKind: cardTable(byKind),
  byCard: cardTable(byCard),
};
console.log(`[${MODE}] run ${RUN} ${N}판${scoreCards ? ' (효과 점수로 고름)' : ''}${uniform ? ' (균등 뽑기)' : ''} 끝 긴장 ${result.tensionEnd} 끝 ${JSON.stringify(result.ends)}`);
console.log(`  판당: 정산 ${result.perGame.settles}번, 정산에서 오른 긴장 합 ${result.perGame.settleDeltaSum}, 카드 고를 때 직접 ${result.perGame.pickDeltaSum}, 그 밖 ${result.perGame.otherDeltaSum}`);
console.log(`  정산 한 번당 inc 몫: ${JSON.stringify(result.incPerSettle)} · 정산 한 번 긴장 변화 ${result.settleDeltaPerSettle}`);
if (OUT) writeFileSync(OUT, JSON.stringify(result, null, 2));
