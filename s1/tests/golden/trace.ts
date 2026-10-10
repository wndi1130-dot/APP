import {
  advance, castVote, chooseCard, COMMS, createGame, createS1cGame, currentAgenda, cutComm, enableDark, enableDisasters, enableEventPack,
  FIELDS, hangSymbol, makeDeal, requestApprentice, requestManual, resolveStop, setBury, setDelegate, startJob, startRestore, supportComm, TECH_IDS, toolStatus,
  unhangSymbol, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';

// 숫자 불변 시험의 길잡이(까닭 장부 옮기기, ledger.ts). 같은 시드와 같은 고르기 규칙으로 판을 끝까지 돌리며
// 구간이 바뀔 때마다 규칙이 내는 숫자를 적는다. 적어 둔 것(trace.json)과 한 톨이라도 다르면 규칙이 바뀐 것이다.
// 화면 쪽 기록(ledger, meterLog, resLog, relLog)은 일부러 적지 않는다.

export type Kind = 'a' | 'c' | 'b' | 'cx';
export interface Run { kind: Kind; seed: string; pick: 'first' | 'last'; busy: boolean }

export const RUNS: Run[] = [
  { kind: 'a', seed: 'gold-1', pick: 'first', busy: false },
  { kind: 'a', seed: 'gold-2', pick: 'last', busy: true },
  { kind: 'c', seed: 'gold-3', pick: 'first', busy: true },
  { kind: 'c', seed: 'gold-4', pick: 'last', busy: false },
  { kind: 'b', seed: 'gold-5', pick: 'first', busy: true },
  { kind: 'b', seed: 'gold-6', pick: 'last', busy: false },
  { kind: 'cx', seed: 'gold-7', pick: 'first', busy: false },
  { kind: 'cx', seed: 'gold-8', pick: 'last', busy: true },
];

export function start(r: Run): Game {
  const g = r.kind === 'a' || r.kind === 'b' ? createGame(r.seed) : createS1cGame(r.seed);
  if (r.kind === 'b') enableDark(g);
  if (r.kind === 'cx') { enableDisasters(g); enableEventPack(g); }
  return g;
}

/** 규칙이 내는 숫자 한 줄. 실수는 그대로 적는다(반올림하면 작은 어긋남을 놓친다). */
export function snap(g: Game): (number | string)[] {
  return [
    g.seg, g.phase, g.trust, g.tension, g.coal, g.food, g.med, g.lux,
    ...COMMS.flatMap(c => [g.comms[c].rel, g.comms[c].pop]),
    g.rng.state, g.journal.length,
  ];
}

/** 한 걸음. 판이 끝났으면 false. */
export function stepOnce(g: Game, r: Run, n: number): boolean {
  if (g.phase === 'end') return false;
  for (const card of r.pick === 'first' ? g.cards : [...g.cards].reverse()) {
    const choices = viewCard(g, card).choices;
    const open = choices.map((ch, i) => (ch.disabled ? -1 : i)).filter(i => i >= 0);
    if (open.length === 0) continue;
    chooseCard(g, card.uid, r.pick === 'first' ? open[0] : open[open.length - 1]);
    return true;
  }
  if (g.phase === 'stop' && g.stop && !g.stop.done) { resolveStop(g, true); return true; }
  if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) {
    if (r.busy) for (const c of COMMS) if (toolStatus(g, c, 'open').ok) makeDeal(g, c, 'open', 0);
    castVote(g);
    return true;
  }
  if (r.busy && g.phase === 'prep') {
    const c = COMMS[(g.seg + n) % COMMS.length];
    if (g.seg % 3 === 0) supportComm(g, c); else if (g.seg % 3 === 1) cutComm(g, c);
    if (g.dom) domestic(g, r);
  }
  advance(g);
  return true;
}

/** 내정 행동을 구간마다 조금씩 해 본다(되는 것만 된다). 공방, 개조, 상징물, 기술 물려주기, 맡기기, 안치. */
function domestic(g: Game, r: Run): void {
  const d = g.dom!;
  const seg = g.seg;
  for (const id of r.pick === 'first' ? TECH_IDS : [...TECH_IDS].reverse()) if (startRestore(g, id, seg % 4 === 0 ? 'defect' : 'full')) break;
  const kind = (['insulate', 'armor', 'convert'] as const)[seg % 3];
  for (const car of d.cars) if (startJob(g, kind, car)) break;
  const c = COMMS[seg % COMMS.length];
  if (seg % 5 === 4) unhangSymbol(g, c); else hangSymbol(g, c);
  if (seg % 2 === 0) requestApprentice(g, FIELDS[seg % FIELDS.length]); else requestManual(g, FIELDS[seg % FIELDS.length]);
  if (seg === 4) setBury(g, true);
  if (seg === 6) setDelegate(g, true, r.pick === 'first' ? 'ours' : 'neutral');
  if (seg === 14) setDelegate(g, false);
}

export function trace(r: Run): (number | string)[][] {
  const g = start(r);
  const rows = [snap(g)];
  let seg = g.seg;
  let phase = g.phase;
  for (let n = 0; n < 4000 && stepOnce(g, r, n); n += 1) {
    if (g.seg !== seg || g.phase !== phase) { rows.push(snap(g)); seg = g.seg; phase = g.phase; }
  }
  rows.push(snap(g));
  return rows;
}

export const runKey = (r: Run): string => `${r.kind}:${r.seed}:${r.pick}:${r.busy ? 'busy' : 'calm'}`;
