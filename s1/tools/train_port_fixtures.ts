// 열차 이식 표본(S1 쪽). S2가 열차 턴 규칙을 GDScript로 옮길 때 맞대 볼 기준 값을 TS 구현으로 만든다.
// 규칙 코드는 읽기만 하고 고치지 않는다. 셈을 여기서 다시 적지 않고, S1이 내보내는 함수를 그대로 불러 그 답을 적는다.
// 사용: npx tsx tools/train_port_fixtures.ts [출력 경로=../s2/tests/fixtures/train/train_vectors.json]
//
// 판은 S1a 판(createGame 그대로: 내정·어두운 길·바깥 기온·재난·사람 들어옴·카드 예산 모두 꺼짐)이다.
// 자동 플레이는 tools/s3_record.ts recordGame과 같은 규칙이다: 서류는 맨 앞 것의 첫 가능한 선택지, 정차는 보냄, 의회는 바로 표결.
// 걸음마다 판을 떠서(points) 그 상태에서 읽기 함수가 낸 답을 적고, 바꾸는 함수(drift·setLever·setStop·다음 구간)는 복제본에 불러 전/후를 적는다.
// 갈래를 넓히려고 같은 상태의 복제본을 정해 둔 난수(train-vary)로 흔들어 한 번 더 잰다. 흔든 값도 S1 함수가 낸 답이라 참값이다.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { createRng, randomInt } from '../src/core/rng';
import type { RngState } from '../src/core/rng';
import {
  advance, autoLevers, autoLeverStatus, calmCoal, calmTension, CALM, castVote, CHORE_COMMS, chooseCard, cloneGame, COMM_NAME, COMMS, createGame,
  CREW, CREW_COMMS, CREW_COST, CREW_COST_REF, CREW_HAUL, CREW_HAUL_OVER, crewAwayOf, crewBand, crewGainOf, crewHaulMult, crewMult, crewNames,
  crewPreview, currentAgenda, DELEGATE_AFTER, DELEGATE_ON, DELEGATE_RE_ON, drift, effThreat, exposeMult, foodCost, forecast, hash, heatCost,
  isSessionSeg, LAWS, lawFloor, ledgerLevel, LOCO, LOCO_DEFAULT, locoCoal, P, PLACES, potRunning, predictStall, primaryAction, PROFILES, PROTEST,
  rationComm, relStage, resolveStop, REST_FLOOR, riskLevel, segKmOf, setLever, setStop, situation, stageOf, stallKm, stallsEnRoute, standings, STAGES,
  STAY, stopRisk, supportShare, tailIdle, THREAT_STEPS, threatStep, totalPop, viewCard,
} from '../src/game';
import type { Comm, CrewCost, CrewCurve, CrewHaul, Game, LawId, LocoId, LootKey, StayId, StopState } from '../src/game';

export const FORMAT = 'train-vectors-v1';
const SEEDS = ['train-0', 'train-1', 'train-2', 'train-3'];
const MAX_STEPS = 2000;

const byComm = <T>(f: (c: Comm) => T): Record<Comm, T> => Object.fromEntries(COMMS.map(c => [c, f(c)])) as Record<Comm, T>;

// ---- 상태 키(이식 범위 2절). 옮긴 함수가 읽고 쓰는 것만 담는다. 일지는 글과 구간만, 사람 풀은 이름·칸·나이만 ----

function pickStop(s: StopState | null | undefined): Record<string, unknown> | null {
  if (!s) return null;
  return {
    place: s.place, target: s.target, stay: s.stay, crewComm: s.crewComm, crewSize: s.crewSize,
    threat: s.threat ?? null, noise: s.noise ?? 0, scout: !!s.scout, again: !!s.again, done: s.done,
    scoutReport: s.scoutReport ? { names: [...s.scoutReport.names] } : null,
  };
}

function pickState(g: Game): Record<string, unknown> {
  return {
    seed: g.seed, seg: g.seg, phase: g.phase, session: g.session,
    coal: g.coal, food: g.food, med: g.med, lux: g.lux, trust: g.trust, tension: g.tension, fear: g.fear,
    inStrike: g.inStrike, forcedRun: g.forcedRun, guardEscort: g.guardEscort,
    stranded: g.stranded ? { since: g.stranded.since } : null,
    route: g.route ?? null, passed: { ...g.passed }, calm: g.calm ? { ...g.calm } : null, loco: g.loco ?? null,
    space: g.space ? { ...g.space } : null, thrown: g.thrown, pyre: g.pyre ?? 0, pyreKin: { ...(g.pyreKin ?? {}) }, stored: g.stored,
    deaths: [...g.deaths], left: [...(g.left ?? [])], decreeLeft: g.decreeLeft, autoLevers: g.autoLevers, autoDropped: !!g.autoDropped,
    hunger: g.hunger, stop: pickStop(g.stop),
    comms: byComm(c => {
      const s = g.comms[c];
      return {
        base: [...s.base], heat: s.heat, ration: s.ration, rel: s.rel, coh: s.coh, fervor: s.fervor, badStreak: s.badStreak, backStreak: s.backStreak,
        grudge: s.grudge, pop: s.pop, away: s.away, sick: s.sick ? { rep: { name: s.sick.rep.name } } : null,
      };
    }),
  };
}

const journalSince = (g: Game, n: number) => g.journal.slice(n).map(j => ({ seg: j.seg, text: j.text, tone: j.tone ?? null }));
const cardsSince = (g: Game, n: number) => g.cards.slice(n).map(k => ({ kind: k.kind, comm: k.comm ?? null, who: k.who ?? null, text: k.text ?? null }));

// ---- 흔들기(train-vary) ----

class Vary {
  rng: RngState = createRng('train-vary');
  int(lo: number, hi: number): number {
    const next = randomInt(this.rng, lo, hi);
    this.rng = next.rng;
    return next.value;
  }
  pick<T>(xs: readonly T[]): T { return xs[this.int(0, xs.length - 1)]; }
  chance(pct: number): boolean { return this.int(0, 99) < pct; }
}

const LAW_IDS = Object.keys(LAWS) as LawId[];
const LOCO_IDS = Object.keys(LOCO) as LocoId[];
const STAY_IDS = Object.keys(STAY) as StayId[];
const LOOT_IDS: LootKey[] = ['coal', 'food', 'medicine', 'luxury', 'symbol', 'secret'];

/** 같은 판의 복제본을 넓은 갈래로 흔든다. S1a 판에 없는 칸(내정·어두운 길 등)은 건드리지 않는다. */
function shake(g0: Game, v: Vary): Game {
  const g = cloneGame(g0);
  for (const c of COMMS) {
    const s = g.comms[c];
    s.heat = v.int(0, 4);
    s.ration = v.int(0, 4);
    if (v.chance(50)) s.rel = v.int(-100, 100);
    if (v.chance(30)) s.fervor = v.int(0, 3);
    if (v.chance(30)) s.badStreak = v.int(0, 3);
    if (v.chance(30)) s.backStreak = v.int(0, 4);
    if (v.chance(25)) s.grudge = v.int(0, 3);
    if (v.chance(40)) s.base = [v.int(0, 100), v.int(0, 100), v.int(0, 100), v.int(0, 100)];
    if (v.chance(20)) s.pop = v.int(0, 120);
  }
  g.coal = v.chance(15) ? 0 : v.int(-5, 200) + v.int(0, 99) / 100;
  g.food = v.chance(15) ? 0 : v.int(-5, 200) + v.int(0, 99) / 100;
  g.lux = v.chance(25) ? 0 : v.int(0, 20);
  g.med = v.int(0, 30);
  g.trust = v.int(0, 100);
  g.tension = v.int(0, 100);
  g.fear = v.int(0, 100);
  g.inStrike = v.chance(15);
  g.forcedRun = v.chance(15);
  g.guardEscort = v.chance(20);
  g.thrown = v.chance(30) ? v.int(0, 12) : 0;
  g.pyre = v.chance(20) ? v.int(0, 4) : 0;
  g.loco = v.chance(60) ? v.pick(LOCO_IDS) : undefined;
  g.passed = {};
  const nLaws = v.chance(40) ? 0 : v.int(1, 4);
  for (let i = 0; i < nLaws; i += 1) g.passed[v.pick(LAW_IDS)] = v.int(0, 6);
  if (g.passed.evening_pot !== undefined && v.chance(60)) g.calm = { ...(g.calm ?? {}), potOn: v.chance(50) };
  g.space = v.chance(30) ? { step: v.int(0, P.spaceMax), giver: v.pick(['medtech', 'guard', 'front', 'engine'] as Comm[]) } : g.space;
  if (v.chance(10)) g.stranded = { since: g.seg, turns: 0, segKm: 30, atKm: 10, toNextKm: 20, seen: [], trip: null, captainAway: false, deputy: null, lostTrips: 0, snow: null, lamp: false };
  if (v.chance(25)) g.route = [{ seg: g.seg, km: v.int(5, 80) }];
  g.autoLevers = v.chance(30);
  g.autoDropped = v.chance(30);
  if (g.stop) {
    g.stop.stay = v.pick(STAY_IDS);
    g.stop.crewComm = v.pick(CREW_COMMS);
    g.stop.crewSize = v.int(2, 8);
    g.stop.threat = v.pick(THREAT_STEPS);
    g.stop.noise = v.chance(30) ? v.int(-1, 2) : 0;
    g.stop.scout = v.chance(40);
    if (v.chance(30)) g.stop.place = v.pick(PLACES).id;
  }
  return g;
}

// ---- 지점마다 잴 것 ----

function reads(g: Game): Record<string, unknown> {
  const fc = forecast(g);
  const ps = predictStall(g);
  const st = standings(g);
  const als = autoLeverStatus(g);
  const out: Record<string, unknown> = {
    situation: byComm(c => situation(g, c)),
    relStage: byComm(c => relStage(g, c)),
    stage: byComm(c => stageOf(g.comms[c].rel)),
    exposeMult: byComm(c => exposeMult(g, c)),
    heatCost: heatCost(g), foodCost: foodCost(g), forecast: { coal: fc.coal, food: fc.food },
    tailIdle: tailIdle(g), heatFloor: lawFloor(g, 'heatFloor'), rationFloor: lawFloor(g, 'rationFloor'),
    stallsEnRoute: stallsEnRoute(g), predictStall: ps, segKm: segKmOf(g),
    isSessionSeg: isSessionSeg(g.seg), totalPop: totalPop(g), supportShare: supportShare(g),
    standings: { unrest: st.unrest, neutral: st.neutral, support: st.support, byComm: st.byComm.map(b => ({ c: b.c, seats: b.seats, side: b.side })) },
    autoLeverStatus: als.ok, rationComm: rationComm(g),
    potRunning: potRunning(g), calmCoal: calmCoal(g), calmTension: calmTension(g), ledgerLevel: ledgerLevel(g), locoCoal: locoCoal(g),
  };
  if (g.stop) {
    const r = stopRisk(g);
    out.stopRisk = {
      lam: r.lam, pDeath: r.pDeath, maxHurt: r.maxHurt, maxDead: r.maxDead, dead: r.fate.dead, hurt: r.fate.hurt,
      guardRefused: r.guardRefused, horde: r.horde, fresh: r.fresh, known: r.known, pyre: r.pyre, noisy: r.noisy,
      need: r.need, ratio: r.ratio, band: r.band, level: riskLevel(r),
    };
    out.crewNames = crewNames(g, g.stop.crewComm, g.stop.crewSize);
    out.effThreat = effThreat(g.stop);
    out.crewPreview = Object.fromEntries(CREW_COMMS.map(c => [c, crewPreview(g, c)]));
  }
  return out;
}

/** 바꾸는 함수를 복제본에 불러 전/후를 적는다. */
function changes(g0: Game, v: Vary): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  {
    const g = cloneGame(g0);
    const j = g.journal.length;
    drift(g);
    out.drift = { comms: byComm(c => ({ rel: g.comms[c].rel, fervor: g.comms[c].fervor, badStreak: g.comms[c].badStreak, backStreak: g.comms[c].backStreak })), journal: journalSince(g, j) };
  }
  {
    const g = cloneGame(g0);
    const levers: { c: Comm; which: 'heat' | 'ration'; value: number; after: number }[] = [];
    for (let i = 0; i < 3; i += 1) {
      const c = v.pick(COMMS);
      const which = v.chance(50) ? 'heat' : 'ration';
      const value = v.int(-20, 60) / 10;
      setLever(g, c, which, value);
      levers.push({ c, which, value, after: g.comms[c][which] });
    }
    out.setLever = levers;
  }
  {
    const g = cloneGame(g0);
    const j = g.journal.length;
    const changed = autoLevers(g);
    out.autoLevers = { changes: changed, heat: byComm(c => g.comms[c].heat), ration: byComm(c => g.comms[c].ration), journal: journalSince(g, j) };
  }
  if (g0.stop && !g0.stop.done) {
    const g = cloneGame(g0);
    const patch: Partial<{ target: LootKey; stay: StayId; crewComm: Comm; crewSize: number }> = {};
    if (v.chance(60)) patch.target = v.pick(LOOT_IDS);
    if (v.chance(60)) patch.stay = v.pick(STAY_IDS);
    if (v.chance(60)) patch.crewComm = v.pick(COMMS);
    if (v.chance(60)) patch.crewSize = v.int(0, 11);
    setStop(g, patch);
    out.setStop = { patch, stop: pickStop(g.stop) };
  }
  return out;
}

/** settle 단계에서 다음 구간으로 넘길 수 있고, 다른 줄기의 틱이 끼지 않는 판인가(이식 범위 3절). */
function nextSegOk(g: Game): boolean {
  return g.phase === 'settle' && g.cards.length === 0 && primaryAction(g).ok && !g.stranded && !g.budget && !g.dark && !g.dom
    && g.seg + 1 < P.segments - 1 && g.decreeLeft !== 1;
}

function nextSegCase(g0: Game): Record<string, unknown> {
  const g = cloneGame(g0);
  const j = g.journal.length;
  const k = g.cards.length;
  advance(g);
  return { after: { ...pickState(g), lastStop: pickStop(g.lastStop) }, journal: journalSince(g, j), cards: cardsSince(g, k) };
}

// ---- 판 하나 ----

interface Point { seed: string; step: number; act: string; vary: boolean; state: Record<string, unknown>; reads: Record<string, unknown>; changes: Record<string, unknown>; journalN: number }

function playSeed(seed: string, v: Vary, points: Point[], nextSegs: unknown[]): void {
  const g = createGame(seed);
  let step = 0;
  // 서류를 고르는 걸음은 거의 같은 판을 되풀이하니, 구간·단계마다 첫 걸음만 지점으로 담는다(표본 크기). 다음 구간 표본은 다 담는다.
  const seen = new Set<string>();
  const take = (act: string): void => {
    const key = `${g.seg}|${g.phase}`;
    if (nextSegOk(g) && seen.has(key)) nextSegs.push({ seed, step, vary: false, before: pickState(g), ...nextSegCase(g) });
    if (seen.has(key)) { step += 1; return; }
    seen.add(key);
    points.push({ seed, step, act, vary: false, state: pickState(g), reads: reads(g), changes: changes(g, v), journalN: g.journal.length });
    const s = shake(g, v);
    points.push({ seed, step, act, vary: true, state: pickState(s), reads: reads(s), changes: changes(s, v), journalN: s.journal.length });
    if (nextSegOk(g)) nextSegs.push({ seed, step, vary: false, before: pickState(g), ...nextSegCase(g) });
    if (nextSegOk(s)) nextSegs.push({ seed, step, vary: true, before: pickState(s), ...nextSegCase(s) });
    step += 1;
  };
  take('new');
  for (let guard = 0; guard < MAX_STEPS && g.phase !== 'end'; guard += 1) {
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const idx = viewCard(g, card).choices.findIndex(c => !c.disabled);
      if (idx < 0 || !chooseCard(g, card.uid, idx)) throw new Error(`서류를 못 골랐다: ${card.kind}`);
      take(`card:${card.kind}:${idx}`);
      continue;
    }
    if (g.phase === 'stop' && g.stop && !g.stop.done) {
      resolveStop(g, true);
      take('stop');
      continue;
    }
    const agenda = g.phase === 'council' && g.council && !g.council.result ? currentAgenda(g) : null;
    if (agenda && g.council) {
      const r = castVote(g);
      if (!r) advance(g);
      take(r ? 'vote' : 'advance');
      continue;
    }
    const primary = primaryAction(g);
    if (!primary.ok) throw new Error(`막혔다: ${g.phase} ${primary.label} ${primary.why ?? ''}`);
    advance(g);
    take('advance');
  }
}

// ---- 판 상태 없는 셈 ----

function scalars(): Record<string, unknown> {
  const rs = [0, 0.1, 0.25, 0.5, 0.6, 0.8, 1, 1.2, 1.5, 1.9, 2, 2.5, 4, 10];
  const curves: CrewCurve[] = ['off', 'A', 'B'];
  const costs: CrewCost[] = ['off', 'X'];
  const hauls: CrewHaul[] = ['flat', 'half', 'none'];
  const saved = { ...CREW };
  const crewMultCases = curves.flatMap(curve => rs.map(r => ({ curve, r, m: crewMult(r, curve) })));
  const crewBandCases = rs.map(r => ({ r, band: crewBand(r) }));
  const gainCases = costs.flatMap(cost => {
    CREW.cost = cost;
    return [0, 1, 2, 3, 4, 5, 6, 7, 8].map(size => ({ cost, size, ...crewGainOf(size), away: crewAwayOf(size) }));
  });
  CREW.cost = saved.cost;
  const haulCases = hauls.flatMap(haul => {
    CREW.haul = haul;
    return [2, 4, 6, 8].flatMap(size => [1.6, 2.4, 4, 9].map(need => ({ haul, size, need, mult: crewHaulMult(size, need) })));
  });
  CREW.haul = saved.haul;
  const stall = [[30, 0, 6], [30, 3.5, 7], [30, 100, 8], [30, 5, 0], [10, 50, 3], [80, 12.4, 9.1], [2, 1, 4], [1, 0, 1]]
    .map(([segKm, coalBefore, need]) => ({ segKm, coalBefore, need, km: stallKm(segKm, coalBefore, need) }));
  const hashes = ['', 'a', 'train-0|1|freight|x|d', '알기르다스|h', 'sim-12|7|church|소피아 몰나로바|sd|again', 'Łódź Żółć'].map(s => ({ s, h: hash(s) }));
  const threats = [0.5, 0.8, 0.9, 1, 1.2, 1.4, 2].map(t => ({ t, step: threatStep(t), eff: [-2, -1, 0, 1, 2].map(n => effThreat({ threat: t, noise: n } as StopState)) }));
  return { crewMult: crewMultCases, crewBand: crewBandCases, crewGain: gainCases, crewHaul: haulCases, stallKm: stall, hash: hashes, threat: threats };
}

// ---- 표 ----

function tables(): Record<string, unknown> {
  return {
    COMMS, P, STAGES, STAY, LOCO_DEFAULT, CREW: { ...CREW }, CREW_COST, CREW_COST_REF, CREW_HAUL, CREW_HAUL_OVER, CHORE_COMMS, CREW_COMMS, REST_FLOOR,
    COMM_NAME, PROTEST, THREAT_STEPS, CALM,
    DELEGATE: { after: DELEGATE_AFTER, on: DELEGATE_ON, reOn: DELEGATE_RE_ON },
    LAWS_RES: Object.fromEntries(LAW_IDS.map(id => [id, LAWS[id].res])),
    LOCO_COAL: Object.fromEntries(LOCO_IDS.map(id => [id, LOCO[id].coal])),
    PLACES: PLACES.map(p => ({ id: p.id, risk: p.risk })),
    PROFILES: PROFILES.map(p => ({ id: p.id, name: p.name, community: p.community, age: p.age })),
  };
}

export function trainVectors(): Record<string, unknown> {
  const v = new Vary();
  const points: Point[] = [];
  const nextSegs: unknown[] = [];
  for (const seed of SEEDS) playSeed(seed, v, points, nextSegs);
  return { format: FORMAT, seeds: SEEDS, tables: tables(), scalars: scalars(), points, nextSegment: nextSegs };
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) {
  const out = resolve(process.argv[2] ?? resolve(import.meta.dirname, '../../s2/tests/fixtures/train/train_vectors.json'));
  const data = trainVectors();
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, `${JSON.stringify(data)}\n`);
  const pts = data.points as Point[];
  console.log(`${out}: 판 ${SEEDS.length}, 지점 ${pts.length}, 다음 구간 ${(data.nextSegment as unknown[]).length}`);
}
