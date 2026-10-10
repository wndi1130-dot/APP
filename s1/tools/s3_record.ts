// S3 맞대기 기록(S1 쪽). S3에서 정치 규칙을 GDScript로 옮길 때, 두 구현이 같은 시드에서 같은 판을 내는지
// 맞대 볼 기준 기록을 TS 구현으로 만든다. 규칙 코드는 읽기만 하고 고치지 않는다.
//
// 세 가지를 낸다.
// - 판 기록(recordGame): 정해진 자동 플레이로 한 판을 돌리며 행동마다 난수 상태와 주요 수치를 적는다.
//   난수 상태가 한 걸음이라도 어긋나면 그 걸음에서 두 구현이 갈린 것이다.
// - 계산 표본(calcVectors): 난수·의석·찬반 몫처럼 판 상태 없이 맞대 볼 수 있는 순수 계산의 입력과 답.
// - 수치 표(dataTables): data.ts에서 함수가 아닌 값만 그대로 뽑은 것. GDScript가 숫자를 손으로 옮기지 않고 이걸 읽는다.

import { createRng, nextRandom, randomInt } from '../src/core/rng';
import type { RngState } from '../src/core/rng';
import * as DATA from '../src/game/data';
import {
  advance, blocs, castVote, chooseCard, COMMS, createGame, currentAgenda, isLawAgenda, makeDeal, primaryAction, resolveStop, seats,
  split, stageOf, toolStatus, undecidedChance, viewCard,
} from '../src/game';
import type { Agenda, Bloc, Comm, Game, VoteResult } from '../src/game';

export const RECORD_FORMAT = 's3-record-v1';
export const VECTORS_FORMAT = 's3-vectors-v1';
export const TABLES_FORMAT = 's3-tables-v1';

/** 칸 순서는 COMMS 그대로다. 칸별 값은 이 순서의 배열로 적는다. */
const byComm = <T>(f: (c: Comm) => T): T[] => COMMS.map(f);

export interface RecordStep {
  i: number;
  /** 이 걸음에 한 행동. new | card:<종류>:<고른 번호> | stop | vote | advance */
  act: string;
  seg: number;
  phase: string;
  /** 행동 뒤의 난수 상태(uint32) */
  rng: number;
  coal: number; food: number; med: number; lux: number;
  trust: number; tension: number; fear: number;
  pop: number[]; rel: number[];
  cards: number; journal: number; deaths: number;
}

/** 개표 한 번의 입력과 답. blocs는 거래까지 반영한 쐐기(개표 직전), rngBefore에서 시작해 flips 순서대로 뽑았다. */
export interface RecordVote {
  step: number;
  seg: number;
  agenda: string;
  need: number;
  rngBefore: number;
  rngAfter: number;
  deals: { comm: Comm; tool: string }[];
  blocs: Bloc[];
  yes: number; no: number; absent: number; passed: boolean;
  byComm: [number, number, number][];
  flips: [number, boolean][];
}

export interface GameRecord {
  format: typeof RECORD_FORMAT;
  seed: string;
  /** deal: 의회에서 되는 칸마다 공개 약속을 건다. 그 밖엔 늘 첫 번째로 고를 수 있는 선택지를 고른다. */
  policy: { deal: boolean };
  comms: readonly Comm[];
  steps: RecordStep[];
  votes: RecordVote[];
  end: { kind: string | null; seg: number; steps: number; passed: string[]; deaths: number };
}

function agendaKey(a: Agenda): string {
  if (isLawAgenda(a)) return `law:${a.law}${a.repeal ? ':repeal' : ''}${a.ratify ? ':ratify' : ''}`;
  return `motion:${a.motion}${a.subject ? `:${a.subject}` : ''}`;
}

function snapshot(g: Game, i: number, act: string): RecordStep {
  return {
    i, act, seg: g.seg, phase: g.phase, rng: g.rng.state,
    coal: g.coal, food: g.food, med: g.med, lux: g.lux, trust: g.trust, tension: g.tension, fear: g.fear,
    pop: byComm(c => g.comms[c].pop), rel: byComm(c => g.comms[c].rel),
    cards: g.cards.length, journal: g.journal.length, deaths: g.deaths.length,
  };
}

/**
 * 정해진 자동 플레이로 S1a 한 판을 돌려 기록한다(서막·내정·어두운 길 없음).
 * 플레이 규칙은 tests/game/play.test.ts의 자동 플레이와 같다: 서류는 맨 앞 것의 첫 가능한 선택지,
 * 정차는 수색대를 보내고, 의회는 (deal이면 공개 약속을 건 뒤) 바로 표결, 그 밖엔 다음 단계로.
 * GDScript 쪽은 이 규칙만 그대로 옮기면 같은 기록을 내야 한다.
 */
export function recordGame(seed: string, deal = false, maxSteps = 2000): GameRecord {
  const g = createGame(seed);
  const steps: RecordStep[] = [snapshot(g, 0, 'new')];
  const votes: RecordVote[] = [];
  const push = (act: string): void => { steps.push(snapshot(g, steps.length, act)); };
  for (let guard = 0; guard < maxSteps && g.phase !== 'end'; guard += 1) {
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const idx = viewCard(g, card).choices.findIndex(c => !c.disabled);
      if (idx < 0 || !chooseCard(g, card.uid, idx)) throw new Error(`서류를 못 골랐다: ${card.kind}`);
      push(`card:${card.kind}:${idx}`);
      continue;
    }
    if (g.phase === 'stop' && g.stop && !g.stop.done) {
      resolveStop(g, true);
      push('stop');
      continue;
    }
    const agenda = g.phase === 'council' && g.council && !g.council.result ? currentAgenda(g) : null;
    if (agenda && g.council) {
      if (deal) for (const c of COMMS) if (toolStatus(g, c, 'open').ok) makeDeal(g, c, 'open', 0);
      const map = blocs(g, agenda, g.council.deals);
      const rngBefore = g.rng.state;
      const r = castVote(g);
      if (r) votes.push(voteRecord(g, steps.length, agenda, map, rngBefore, r));
      else advance(g);
      push(r ? 'vote' : 'advance');
      continue;
    }
    const primary = primaryAction(g);
    if (!primary.ok) throw new Error(`막혔다: ${g.phase} ${primary.label} ${primary.why ?? ''}`);
    advance(g);
    push('advance');
  }
  return {
    format: RECORD_FORMAT, seed, policy: { deal }, comms: COMMS, steps, votes,
    end: { kind: g.end, seg: g.seg, steps: steps.length, passed: Object.keys(g.passed), deaths: g.deaths.length },
  };
}

function voteRecord(g: Game, step: number, agenda: Agenda, map: Record<Comm, Bloc>, rngBefore: number, r: VoteResult): RecordVote {
  return {
    step, seg: g.seg, agenda: agendaKey(agenda), need: r.need, rngBefore, rngAfter: g.rng.state,
    deals: (g.council?.deals ?? []).map(d => ({ comm: d.comm, tool: d.tool })),
    blocs: byComm(c => ({ ...map[c] })),
    yes: r.yes, no: r.no, absent: r.absent, passed: r.passed,
    byComm: byComm(c => [r.byComm[c].yes, r.byComm[c].no, r.byComm[c].absent]),
    flips: r.flips.map(f => [COMMS.indexOf(f.comm), f.yes]),
  };
}

// ---- 계산 표본 ----

const RNG_SEEDS: (string | number)[] = ['s1a', 'seed-0', '', 'a', '술레후프 급수탑', 'Sulechów', 0, 1, 42, 4294967295, 4294967296, -1];
/** 뒤 두 줄은 너비가 2^32를 나누지 못해 버리고 다시 뽑는 경우가 나온다. */
const INT_RANGES: [number, number][] = [[0, 0], [0, 1], [1, 6], [-5, 5], [0, 99], [0, 2999999999], [-2147483648, 2147483647]];
const SEAT_POPS: number[][] = [
  [90, 30, 25, 30, 25], [40, 40, 40, 40, 40], [1, 1, 1, 0, 0], [0, 0, 0, 0, 0], [1, 0, 0, 0, 0], [3, 3, 3, 3, 1],
  [33, 33, 34, 0, 0], [7, 7, 7, 7, 7], [199, 1, 0, 0, 0], [61, 29, 27, 31, 22],
];

function rngVectors(): unknown[] {
  return RNG_SEEDS.map(seed => {
    let rng: RngState = createRng(seed);
    const start = rng.state;
    const draws: { state: number; u32: number; value: number }[] = [];
    for (let i = 0; i < 8; i += 1) {
      const next = nextRandom(rng);
      rng = next.rng;
      draws.push({ state: rng.state, u32: next.value * 0x1_0000_0000, value: next.value });
    }
    const ints = INT_RANGES.map(([min, max]) => {
      const next = randomInt(rng, min, max);
      const from = rng.state;
      rng = next.rng;
      return { from, min, max, value: next.value, state: rng.state };
    });
    return { seed, start, draws, ints };
  });
}

function seatVectors(): { pop: number[]; seats: number[] }[] {
  const g = createGame('seats');
  const cases = [...SEAT_POPS];
  let rng = createRng('seat-cases');
  for (let i = 0; i < 30; i += 1) {
    const pop: number[] = [];
    for (let k = 0; k < COMMS.length; k += 1) {
      const next = randomInt(rng, 0, i < 15 ? 12 : 120);
      rng = next.rng;
      pop.push(next.value);
    }
    cases.push(pop);
  }
  return cases.map(pop => {
    COMMS.forEach((c, k) => { g.comms[c].pop = pop[k]; });
    const out = seats(g);
    return { pop, seats: byComm(c => out[c]) };
  });
}

/**
 * 판 상태 없이 맞대 볼 수 있는 계산의 입력과 답. votes는 실제 판 기록에서 모은 개표(쐐기와 난수 상태 → 표)다.
 * stages는 표본을 만들 때의 관계 단계 표다. GDScript 시험은 이 표를 그대로 넣어 맞대므로 data.ts가 바뀌어도 표본은 스스로 맞는다.
 */
export function calcVectors(): Record<string, unknown> {
  const scores = [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6];
  const rels = [-100, -70, -69, -40, -39, -15, -14, 0, 14, 15, 39, 40, 69, 70, 100];
  const votes = ['seed-0', 'seed-1', 'seed-2'].flatMap((seed, k) => recordGame(seed, k % 2 === 0).votes)
    .map(({ step: _step, seg: _seg, ...rest }) => rest);
  return {
    format: VECTORS_FORMAT,
    comms: COMMS,
    rng: rngVectors(),
    seats: seatVectors(),
    split: scores.map(score => ({ score, split: split(score) })),
    undecided: scores.map(score => ({ score, chance: undecidedChance(score) })),
    stages: DATA.STAGES,
    stageOf: rels.map(rel => ({ rel, ...stageOf(rel) })),
    votes,
  };
}

// ---- 수치 표 ----

function plain(value: unknown): boolean {
  if (value === null) return true;
  if (typeof value === 'function' || typeof value === 'undefined' || typeof value === 'symbol' || typeof value === 'bigint') return false;
  if (typeof value === 'number') return Number.isFinite(value);
  if (typeof value !== 'object') return true;
  return Object.values(value as object).every(plain);
}

/** data.ts가 내보내는 값 가운데 함수가 섞이지 않은 것만 이름 그대로 담는다. 빠진 이름은 skipped에 적는다. */
export function dataTables(): { format: string; tables: Record<string, unknown>; skipped: string[] } {
  const tables: Record<string, unknown> = {};
  const skipped: string[] = [];
  for (const [name, value] of Object.entries(DATA).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))) {
    if (plain(value)) tables[name] = value; else skipped.push(name);
  }
  return { format: TABLES_FORMAT, tables, skipped };
}
