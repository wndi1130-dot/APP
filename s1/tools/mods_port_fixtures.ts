// 단열·살림 이식 표본(결정 426 PR 4·486·489). 개조 줄·가구·처지·관계 정산을 S1 함수의 답과 맞댄다.
// 규칙 코드는 읽기만 하고 고치지 않는다. 답은 모두 S1 함수가 내고, 여기서는 상태를 흔들고 비추기만 한다.
// 사용: npx tsx tools/mods_port_fixtures.ts [출력 경로=../s2/tests/fixtures/train/mods_vectors.json]
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { createRng, randomInt } from '../src/core/rng';
import {
  advance, castVote, chooseCard, COMMS, createGame, currentAgenda, heatCost, primaryAction,
  resolveStop, situation, viewCard,
} from '../src/game';
import type { Comm, Game, LawId } from '../src/game';
import { HANDS, LAWS, P } from '../src/game/data';
import { enactLaw, repealLaw } from '../src/game/politics';
import { CAR_COMM, COMM_CARS, D, FURNISH_CARS, FURNISH_STEPS, FURNISH_WORK, FURNITURE_SIZE, FURNITURE } from '../src/game/domestic/data';
import type { FurnishStep, FurnitureKind } from '../src/game/domestic/data';
import { createS1cGame, furnishOf, furnishScore, nextFurnishWork } from '../src/game/domestic/state';
import { refreshSit } from '../src/game/domestic/sit';
import { insulatedShare, insulateCarNote, insulateNumbers, insulatePickLine, furnishComparison, furnishTick } from '../src/game/domestic/lawtech';
import { cancelJob, cancelOpen, CAR_NAME, jobCheck, jobTitle, runWorkshop, startJob, workPower, furnishCost } from '../src/game/domestic/workshop';
import { DECOR, DECOR_CARS, DECOR_SLOT_TABLE, DECOR_SLOTS, FURNISH_WALL_MAX, FURNISH_FLOOR_MAX,
  canPlace, decorCrowd, decorItems, migrateDecor, move, place, placeFurniture, readStore, receiveDecor, reconcileStore, removeFurniture, rotate, slotsOpen, takeBack } from '../src/game/domestic/decor';
import type { DecorAt, DecorRes, DecorSpot } from '../src/game/domestic/decor';

const FORMAT = 'mods-vectors-v1';
const seeds = ['mods-0', 'mods-1'];
const checkpoints = [0, 8, 24, 64];
const profiles = 8;
const cars = [...Object.keys(CAR_NAME), 'unknown'];
const residents = Object.keys(CAR_COMM);
const clone = <T>(v: T): T => structuredClone(v);
const byComm = <T>(f: (c: Comm) => T) => Object.fromEntries(COMMS.map(c => [c, f(c)]));
let rng = createRng('mods-port-v1');
function n(lo: number, hi: number): number {
  const next = randomInt(rng, lo, hi);
  rng = next.rng;
  return next.value;
}

// 내정을 붙이기 전 실제 S1a 판을 굴린다(turn을 손으로 다시 쓰지 않는다).
function played(seed: string): { step: number; game: Game }[] {
  const g = createGame(seed);
  const out = [{ step: 0, game: clone(g) }];
  for (let step = 1; step <= checkpoints[checkpoints.length - 1]; step++) {
    if (g.phase === 'end') throw new Error(`${seed} ended before checkpoint ${step}`);
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const idx = viewCard(g, card).choices.findIndex(c => !c.disabled);
      if (idx < 0 || !chooseCard(g, card.uid, idx)) throw new Error(`Cannot choose ${card.kind}`);
    } else if (g.phase === 'stop' && g.stop && !g.stop.done) {
      resolveStop(g, true);
    } else if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) {
      if (!castVote(g)) advance(g);
    } else {
      if (!primaryAction(g).ok) throw new Error(`Blocked in ${g.phase}`);
      advance(g);
    }
    if (checkpoints.includes(step)) out.push({ step, game: clone(g) });
  }
  return out;
}

function prepare(base: Game, profile: number): Game {
  const g = clone(base);
  for (const law of Object.keys(g.passed) as LawId[]) repealLaw(g, law);
  if (profile % 4 === 1 || profile % 4 === 3) enactLaw(g, 'heat_quota', []);
  if (profile % 4 >= 2) enactLaw(g, 'snow_duty', []);
  g.dom = clone(createS1cGame(`${base.seed}-dom`).dom!);
  const d = g.dom;
  // 단열 밖의 처지 보정(refreshSit)과 공방 배수는 일부러 0·1로 둔다.
  d.bedding = {}; d.armored = []; d.typhus = []; d.bedOrder = null;
  delete d.pot; delete d.elder; g.riot.scorched = [];
  g.injured = 0;
  delete (g as Game & { wounds?: unknown[] }).wounds;
  d.techs = {}; d.restoring = null; d.workDebt = 0;
  d.order = ['modify']; d.target = 0; d.partWork = 0;
  for (const p of d.people) {
    delete p.pupil; delete p.learn; delete p.writing; delete p.resting;
    p.skill = n(0, 3);
  }
  d.wood = profile === 3 ? 7.75 : profile === 2 ? 8 : n(8, 32) + 0.25;
  d.scrap = n(0, 20) + 0.5;
  const groups = [[], ['tail1'], ['tail1', 'tail2'], ['tail1', 'tail2', 'tail3'], residents,
    ['tail2', 'guard'], ['medtech', 'front'], ['tail1', 'tail3', 'engine']];
  d.insulated = [...groups[profile]];
  if (profile > 0) {
    d.techs.e5 = { stage: profile === 1 ? 'restoring' : profile === 2 ? 'defective' : 'done',
      defect: profile === 2, progress: profile === 1 ? 1 : 3, need: 3,
      ...(profile === 4 ? { off: true } : {}), ...(profile === 5 ? { starved: true } : {}) };
  }
  if (profile >= 5) {
    const car = residents.find(c => !d.insulated.includes(c))!;
    d.job = { kind: 'insulate', car, need: D.insulateWork,
      progress: profile === 5 ? 0 : profile === 6 ? 1.25 : D.insulateWork - 5e-10,
      paid: { wood: 5.5, scrap: 1.25 } };
  }
  for (const c of COMMS) {
    g.comms[c].heat = n(0, 4); g.comms[c].ration = n(0, 4);
    // Exercise clamps as well as interior values; these are inputs, not expected effects.
    g.comms[c].base[0] = [0, 3, 45, 97, 100][n(0, 4)];
    g.comms[c].base[2] = [0, 40, 98, 100][n(0, 3)];
  }
  g.space = { step: n(0, P.spaceMax), giver: COMMS[n(0, COMMS.length - 1)] };
  g.hands = { have: 0, short: { repair: n(0, 4) / 4, stove: n(0, 4) / 4 },
    expose: byComm(() => n(0, 4)) } as Game['hands'];
  g.journal = [];
  refreshSit(g);
  const bare = clone(g);
  bare.dom!.insulated = [];
  refreshSit(bare);
  // 단열 밖의 내정 처지 보정이 끼어들었으면 뽑기를 멈춘다.
  if (Object.values(bare.dom!.sit).some(v => v.some(x => x !== 0))) throw new Error('Non-insulation situation term');
  return g;
}

// S2 계약 꼴로 비춘다. S1 사람 명부는 PR 6의 experts로.
function state(g: Game) {
  const d = g.dom;
  return { seg: g.seg, passed: g.passed, space: g.space ?? null, hands: g.hands ?? null,
    comms: byComm(c => ({ base: g.comms[c].base, heat: g.comms[c].heat, ration: g.comms[c].ration, pop: g.comms[c].pop })),
    journal: g.journal,
    ...(d ? { dom: { wood: d.wood, scrap: d.scrap, parts: d.parts, target: d.target, partWork: d.partWork,
      techs: d.techs, restoring: d.restoring, insulated: d.insulated, job: d.job,
      experts: d.people.filter(p => p.alive && !p.gone).map(({ name, comm, field, skill }) => ({ name, comm, field, skill })) } } : {}) };
}
// 바꾸는 함수는 같은 입력에서 돌리고, 뒤에는 PR 4 몫 칸과 일지 글만 맞댄다.
function owned(g: Game) {
  const d = g.dom!;
  return clone({ wood: d.wood, scrap: d.scrap, insulated: d.insulated, job: d.job, journal: g.journal });
}
function effects(g: Game) {
  refreshSit(g);
  return { heat: heatCost(g), situation: byComm(c => situation(g, c)) };
}
function mutation(g: Game, f: (copy: Game) => unknown) {
  const copy = clone(g);
  const result = f(copy);
  return { result, after: owned(copy), effects: effects(copy) };
}
function run(g: Game) {
  const car = g.dom!.job?.car ?? null;
  const sample = mutation(g, runWorkshop);
  return { ...sample, completed: car !== null && sample.after.job === null ? car : null };
}

const cases = [];
const legacy = [];
for (const seed of seeds) for (const point of played(seed)) {
  legacy.push({ seed, step: point.step, state: state(point.game), effects: effects(point.game) });
  for (let profile = 0; profile < profiles; profile++) {
    const g = prepare(point.game, profile);
    const bare = clone(g);
    bare.dom!.insulated = [];
    const perCar = cars.map(car => {
      const started = clone(g);
      const result = startJob(started, 'insulate', car);
      const after = owned(started);
      return { car, check: jobCheck(g, 'insulate', car), title: jobTitle('insulate', car),
        numbers: insulateNumbers(car), note: insulateCarNote(g, car),
        start: { result, after },
        ...(result ? { chain: { cancel: mutation(started, cancelJob), run: run(started) } } : {}) };
    });
    cases.push({ seed, step: point.step, profile, state: clone(state(g)),
      effects: effects(g), without: effects(bare), share: byComm(c => insulatedShare(g, c)),
      cancelOpen: cancelOpen(g), work: workPower(g), perCar, cancel: mutation(g, cancelJob), run: run(g) });
  }
}
// Furnishing uses the same neutralized S1 state as insulation. Only S2's cloth
// payment is absent here; tests compare the shared fields in both directions
// and independently check paid.cloth and its refund in S2.
type FurnishOp = { op: 'check' | 'start' | 'cancel' | 'run' | 'place' | 'remove' | 'tick'; car?: string; step?: number; kind?: string; index?: number };
function furnishBase(): Game {
  const g = prepare(createGame('furnish-oracle'), 0);
  const d = g.dom!;
  receiveDecor(g, Object.keys(FURNITURE).flatMap(kind => Array<string>(20).fill(kind)));
  d.wood = 100; d.scrap = 100; d.parts = 30; d.insulated = [...FURNISH_CARS];
  for (const id of ['w1', 'w5'] as const) d.techs[id] = { stage: 'done', defect: false, progress: 3, need: 3 };
  for (const p of d.people) p.skill = 2;
  for (const c of COMMS) { g.comms[c].rel = 0; g.comms[c].pop = 10; }
  g.journal = []; g.ledger = [];
  return g;
}
function furnishState(g: Game) {
  const s = state(g);
  return { ...s, ledger: clone(g.ledger ?? []),
    comms: byComm(c => ({ ...s.comms[c], rel: g.comms[c].rel })),
    dom: { ...s.dom!, furnish: clone(g.dom!.furnish ?? {}), store: clone(g.dom!.store ?? {}) } };
}
function furnishOwned(g: Game) {
  return clone({ ...owned(g), parts: g.dom!.parts, furnish: g.dom!.furnish ?? {}, store: g.dom!.store ?? {},
    rel: byComm(c => g.comms[c].rel), ledger: g.ledger ?? [] });
}
function furnishApply(g: Game, op: FurnishOp): unknown {
  switch (op.op) {
    case 'check': return jobCheck(g, 'furnish', op.car!, op.step as FurnishStep | undefined);
    case 'start': return startJob(g, 'furnish', op.car!, op.step as FurnishStep | undefined);
    case 'cancel': return cancelJob(g);
    case 'run': return runWorkshop(g);
    case 'place': return placeFurniture(g, op.car!, op.kind as FurnitureKind);
    case 'remove': return removeFurniture(g, op.car!, op.index!);
    case 'tick': furnishTick(g); return null;
  }
}
const furnishCases: unknown[] = [];
function furnishCase(name: string, g: Game, ops: FurnishOp[]) {
  g.journal = []; g.ledger = [];
  const input = clone(furnishState(g));
  const steps = ops.map(op => {
    const result = furnishApply(g, op);
    return clone({ ...op, result, after: furnishOwned(g), effects: effects(g), comparison: furnishComparison(g),
      cars: Object.fromEntries(FURNISH_CARS.map(car => [car, { state: furnishOf(g, car), score: furnishScore(g, car), next: nextFurnishWork(g, car) ?? 0 }])) });
  });
  // Snapshot each step before another operation mutates a shared furniture list.
  furnishCases.push({ name, state: input, steps });
}
const allJobs: FurnishOp[] = FURNISH_STEPS.flatMap(step => [
  { op: 'check', car: 'tail1', step }, { op: 'start', car: 'tail1', step }, { op: 'cancel' },
  { op: 'start', car: 'tail1', step }, { op: 'run' },
] as FurnishOp[]);
for (const car of FURNISH_CARS) {
  furnishCase(`jobs-${car}`, furnishBase(), [...allJobs.map(op => ({ ...op, ...(op.car ? { car } : {}) })),
    { op: 'check', car }, { op: 'run' }, { op: 'tick' }, { op: 'tick' }]);
}
for (const car of [...FURNISH_CARS, 'engine', 'store', 'tail4', 'unknown']) {
  furnishCase(`furniture-${car}`, furnishBase(), [
    ...Object.keys(FURNITURE).map(kind => ({ op: 'place', car, kind } as FurnishOp)),
    { op: 'place', car, kind: 'unknown' },
    ...[-1, 0.5, 99, 0, 0, 0].map(index => ({ op: 'remove', car, index } as FurnishOp)),
    { op: 'check', car }, { op: 'tick' },
  ]);
}
function atTier(car: string, tier: number): Game {
  const g = furnishBase();
  for (const step of FURNISH_STEPS.filter(n => n <= tier)) {
    if (!startJob(g, 'furnish', car, step)) throw new Error(`Cannot prepare tier ${step}`);
    while (g.dom!.job) runWorkshop(g);
  }
  return g;
}
for (const mode of ['before-tier', 'no-insulation', 'no-w5', 'off-w5', 'defective-w5', 'starved-w5', 'no-w1', 'off-w1', 'wood', 'scrap', 'parts', 'busy', 'bad-step']) {
  const g = atTier('front', mode === 'before-tier' ? 0 : mode.includes('w1') || mode === 'parts' ? 2 : 1);
  const d = g.dom!;
  if (mode === 'no-insulation') d.insulated = [];
  if (mode === 'no-w5') delete d.techs.w5;
  if (mode === 'off-w5') d.techs.w5!.off = true;
  if (mode === 'defective-w5') { d.techs.w5!.stage = 'defective'; d.techs.w5!.defect = true; }
  if (mode === 'starved-w5') d.techs.w5!.starved = true;
  if (mode === 'no-w1') delete d.techs.w1;
  if (mode === 'off-w1') d.techs.w1!.off = true; // S1 uses usable, not mult, for w1.
  if (mode === 'wood' || mode === 'scrap' || mode === 'parts') d[mode] = 0;
  if (mode === 'busy') startJob(g, 'furnish', 'guard');
  const step = mode === 'bad-step' ? 4 : mode.includes('w1') || mode === 'parts' ? 3 : 2;
  furnishCase(`gate-${mode}`, g, [{ op: 'check', car: 'front', step }, { op: 'start', car: 'front', step }]);
}
const recovered = furnishBase();
furnishCase('furniture-replaces-first-work-and-recovers-missing-score', recovered, [
  { op: 'place', car: 'tail1', kind: 'piano' }, { op: 'place', car: 'tail1', kind: 'chair' },
  { op: 'remove', car: 'tail1', index: 0 }, { op: 'start', car: 'tail1' }, { op: 'run' },
  { op: 'start', car: 'tail1' }, { op: 'run' }, { op: 'start', car: 'tail1' }, { op: 'run' },
  { op: 'remove', car: 'tail1', index: 0 }, { op: 'place', car: 'tail1', kind: 'iron_stove' }, { op: 'tick' },
]);
for (const tier of [1, 2, 3]) for (const population of ['all', 'front-empty', 'tail-only']) {
  const g = atTier('front', tier);
  placeFurniture(g, 'tail1', 'piano'); placeFurniture(g, 'tail2', 'piano');
  placeFurniture(g, 'guard', 'small_stove'); placeFurniture(g, 'guard', 'iron_stove');
  placeFurniture(g, 'guard', 'bed_frame');
  if (population === 'front-empty') g.comms.front.pop = 0;
  if (population === 'tail-only') for (const c of COMMS) if (c !== 'tail') g.comms[c].pop = 0;
  g.comms.tail.rel = 99.9; g.comms.medtech.rel = -99.9;
  furnishCase(`comparison-${tier}-${population}`, g, [{ op: 'tick' }, { op: 'tick' }]);
}
// The same operation inputs replay in S2; snapshots include ownership and per-car capacity.
type DecorOp = { op: 'receive' | 'canPlace' | 'place' | 'move' | 'rotate' | 'takeBack' | 'spend' | 'read' | 'reconcile' | 'migrate';
  car?: string; kind?: string; spot?: DecorSpot; at?: DecorAt; rot?: number; on?: number; i?: number;
  gained?: string[]; res?: DecorRes; amount?: number };
function decorBase(): Game {
  const g = furnishBase();
  g.dom!.store = {}; g.food = 40; g.med = 20; g.lux = 40; g.sup = 20;
  return g;
}
function decorState(g: Game) { return { ...furnishState(g), food: g.food, med: g.med, lux: g.lux, sup: g.sup }; }
function decorOwned(g: Game) {
  return clone({ furnish: g.dom!.furnish ?? {}, store: g.dom!.store ?? {}, food: g.food, med: g.med, lux: g.lux, sup: g.sup,
    rel: byComm(c => g.comms[c].rel), ledger: g.ledger ?? [],
    slots: Object.fromEntries(DECOR_CARS.map(car => [car, slotsOpen(g, car)])),
    crowd: Object.fromEntries(DECOR_CARS.map(car => [car, decorCrowd(decorItems(g, car))])) });
}
function decorApply(g: Game, op: DecorOp): unknown {
  switch (op.op) {
    case 'receive': receiveDecor(g, op.gained!); return null;
    case 'canPlace': return canPlace(g, op.car!, op.kind!, op.spot!, op.at, op.rot, op.on);
    case 'place': return place(g, op.car!, op.kind!, op.spot!, op.at, op.rot, op.on);
    case 'move': return move(g, op.car!, op.i!, op.at!, op.rot);
    case 'rotate': return rotate(g, op.car!, op.i!, op.rot!);
    case 'takeBack': return takeBack(g, op.car!, op.i!);
    case 'spend': g[op.res!] = (g[op.res!] ?? 0) - op.amount!; return null;
    case 'read': return readStore(g);
    case 'reconcile': reconcileStore(g); return null;
    case 'migrate': migrateDecor(g); return null;
  }
}
const decorCases: { name: string; state: ReturnType<typeof decorState>; steps: unknown[] }[] = [];
function decorCase(name: string, g: Game, ops: DecorOp[]) {
  const state = clone(decorState(g));
  if (!Object.hasOwn(g.dom!, 'store')) Reflect.deleteProperty(state.dom, 'store');
  const steps = ops.map(op => { const result = decorApply(g, op); return clone({ ...op, result, after: decorOwned(g) }); });
  decorCases.push({ name, state, steps });
}
const decorSlots: unknown[] = [];
for (const car of DECOR_CARS) for (const tier of [0, 1, 2, 3]) {
  const g = atTier(DECOR_SLOT_TABLE[car] === 'tier' ? car : 'tail2', tier);
  g.dom!.store = {};
  for (const surface of [false, true]) {
    if (surface) { receiveDecor(g, ['side_table']); place(g, car, 'side_table', 'floor'); }
    decorSlots.push(clone({ car, tier, surface, state: decorState(g), open: slotsOpen(g, car) }));
  }
}
decorCase('ownership-and-parent-indices', decorBase(), [
  { op: 'place', car: 'front', kind: 'chair', spot: 'floor' },
  { op: 'receive', gained: ['chair', 'side_table', 'table', 'record', 'record', 'record', 'can_beans', 'unknown'] },
  { op: 'place', car: 'engine', kind: 'chair', spot: 'floor' },
  { op: 'place', car: 'front', kind: 'chair', spot: 'floor', at: [0, 0], rot: 0 },
  { op: 'place', car: 'front', kind: 'side_table', spot: 'floor', at: [0, 0] },
  { op: 'place', car: 'front', kind: 'record', spot: 'surface', on: 1, at: [0, 0] },
  { op: 'place', car: 'front', kind: 'record', spot: 'surface', on: 1, at: [1, 0] },
  { op: 'place', car: 'front', kind: 'record', spot: 'surface', on: 1 },
  { op: 'place', car: 'front', kind: 'table', spot: 'floor' },
  { op: 'place', car: 'front', kind: 'can_beans', spot: 'surface', on: 4, at: [0, 0], rot: 1 },
  { op: 'move', car: 'front', i: 0, at: [999, -7], rot: 2 },
  { op: 'rotate', car: 'front', i: 0, rot: 3 },
  { op: 'rotate', car: 'front', i: 0, rot: 4 },
  { op: 'takeBack', car: 'front', i: 0 },
  { op: 'takeBack', car: 'front', i: 0 },
  { op: 'takeBack', car: 'front', i: 0 },
  { op: 'takeBack', car: 'front', i: -1 },
]);
const tagsGame = atTier('front', 1); tagsGame.dom!.store = {}; tagsGame.lux = 4; tagsGame.sup = 0;
decorCase('newest-tags-melt-across-kinds', tagsGame, [
  { op: 'receive', gained: ['painting', 'record', 'rare_violin'] },
  { op: 'place', car: 'front', kind: 'rare_violin', spot: 'wall', at: [31, 1] },
  { op: 'spend', res: 'lux', amount: 0.5 }, { op: 'read' },
  { op: 'spend', res: 'lux', amount: 1.5 }, { op: 'reconcile' },
  { op: 'takeBack', car: 'front', i: 0 }, { op: 'read' },
]);
for (const car of ['captain', 'dining']) decorCase(`common-${car}`, decorBase(), [
  { op: 'receive', gained: ['piano', 'side_table', 'can_meat', 'jar_cabbage', 'jar_jam', 'bottle_spirit', 'rare_wine_case'] },
  { op: 'place', car, kind: 'piano', spot: 'floor' }, { op: 'place', car, kind: 'side_table', spot: 'floor' },
  { op: 'place', car, kind: 'can_meat', spot: 'surface', on: 1 },
  { op: 'place', car, kind: 'jar_cabbage', spot: 'surface', on: 1 },
  { op: 'place', car, kind: 'jar_jam', spot: 'surface', on: 1 }, { op: 'takeBack', car, i: 1 },
  { op: 'takeBack', car, i: 0 },
]);
const oldDecor = decorBase(); delete oldDecor.dom!.store;
oldDecor.dom!.furnish = { front: { work: 0, jobs: [], furnPts: 1, tier: 0, best: 0, items: [{ kind: 'frame', size: 'small' }] } };
decorCase('legacy-unpositioned', oldDecor, [{ op: 'migrate' }, { op: 'read' }, { op: 'takeBack', car: 'front', i: 0 }]);

// Append new cases after all existing inputs so prepare's shared RNG keeps their seeds stable.
furnishCase('furniture-rewards-once-after-each-tier-drops', furnishBase(), [
  { op: 'place', car: 'front', kind: 'piano' },
  ...FURNISH_STEPS.flatMap(step => [
    ...(step > 1 ? [{ op: 'start', car: 'front', step }, { op: 'run' }] as FurnishOp[] : []),
    { op: 'remove', car: 'front', index: 0 }, { op: 'place', car: 'front', kind: 'piano' },
  ] as FurnishOp[]),
]);

const blockedWall = decorBase();
blockedWall.lux = DECOR.painting.v! + DECOR.rare_violin.v!;
decorCase('tier-drop-wall-keeps-unreconciled-stock', blockedWall, [
  { op: 'receive', gained: ['piano', 'painting', 'rare_violin'] },
  { op: 'place', car: 'front', kind: 'piano', spot: 'floor' },
  { op: 'place', car: 'front', kind: 'painting', spot: 'wall' },
  { op: 'spend', res: 'lux', amount: DECOR.rare_violin.v! },
  { op: 'takeBack', car: 'front', i: 0 }, { op: 'takeBack', car: 'front', i: 1 },
  { op: 'takeBack', car: 'front', i: 0 }, { op: 'place', car: 'front', kind: 'piano', spot: 'floor' },
]);
for (const overflow of [false, true]) decorCase(`tier-drop-cascade-${overflow ? 'blocked-per-parent' : 'fits'}`, decorBase(), [
  { op: 'receive', gained: ['cupboard', 'side_table', ...(overflow ? ['side_table'] : []),
    ...Array<string>(4).fill('can_beans'), ...Array<string>(overflow ? 3 : 2).fill('record')] },
  { op: 'place', car: 'front', kind: 'cupboard', spot: 'floor' },
  { op: 'place', car: 'front', kind: 'side_table', spot: 'floor' },
  ...(overflow ? [{ op: 'place', car: 'front', kind: 'side_table', spot: 'floor' }] as DecorOp[] : []),
  ...Array.from({ length: 4 }, (): DecorOp => ({ op: 'place', car: 'front', kind: 'can_beans', spot: 'surface', on: 0 })),
  ...Array.from({ length: overflow ? 3 : 2 }, (): DecorOp => ({ op: 'place', car: 'front', kind: 'record', spot: 'surface', on: 1 })),
  { op: 'takeBack', car: 'front', i: 0 },
]);
for (const car of ['captain', 'dining']) for (const spot of ['floor', 'wall', 'surface']) {
  const kinds = spot === 'floor' ? Array<string>(9).fill('chair') : spot === 'wall' ? ['painting'] : ['side_table', 'record', 'record', 'record'];
  decorCase(`common-tier-drop-${car}-${spot}`, decorBase(), [
    { op: 'receive', gained: ['piano', ...kinds] },
    { op: 'place', car: 'front', kind: 'piano', spot: 'floor' },
    ...kinds.map((kind): DecorOp => ({ op: 'place', car, kind, spot: DECOR[kind as keyof typeof DECOR].spot,
      ...(kind === 'record' ? { on: 0 } : {}) })),
    { op: 'takeBack', car: 'front', i: 0 },
  ]);
}
for (const best of [undefined, 0, 1]) {
  const old = decorBase();
  old.dom!.furnish!.front = { work: 0, jobs: [], furnPts: 0, tier: 1, best: 1, items: [] };
  if (best === undefined) Reflect.deleteProperty(old.dom!.furnish!.front, 'best');
  else old.dom!.furnish!.front.best = best as 0 | 1;
  decorCase(`legacy-reward-best-${best ?? 'missing'}`, old, [{ op: 'migrate' }, { op: 'migrate' },
    { op: 'receive', gained: ['chair', 'piano'] }, { op: 'place', car: 'front', kind: 'chair', spot: 'floor' },
    { op: 'takeBack', car: 'front', i: 0 }, { op: 'place', car: 'front', kind: 'piano', spot: 'floor' }]);
}

const dKeys = ['insulateWork', 'insulateWood', 'insulateWarm', 'insulateHeat', 'insulateCrowd', 'insulateQuotaHalf',
  'furnishClothWood', 'furnishFurnitureCap', 'furnishThreshold', 'furnishWarm', 'furnishCrowd', 'furnishRel',
  'furnishGapMin', 'furnishGapMax', 'furnishGapRel', 'furnishGapCap', 'furnishPianoRel'] as const;
const output = { format: FORMAT, seeds, checkpoints, profiles,
  scope: 'Played S1a + neutralized S1c dom; modify-only order, no work debt, no other law-tech relief; no climate/hygiene/UI',
  tables: { COMMS, P, HANDS, CAR_COMM, COMM_CARS, CAR_NAME, HEAT_QUOTA_MATS: LAWS.heat_quota.mats,
    D: Object.fromEntries(dKeys.map(k => [k, D[k]])), FURNISH_CARS, FURNISH_STEPS, FURNISH_WORK, FURNITURE_SIZE, FURNITURE: DECOR },
  furnish: { costs: FURNISH_STEPS.map(step => ({ step, cost: furnishCost(step) })), cases: furnishCases },
  decor: { tables: { DECOR, DECOR_CARS, DECOR_SLOT_TABLE, DECOR_SLOTS, FURNISH_WALL_MAX, FURNISH_FLOOR_MAX }, slots: decorSlots, cases: decorCases },
  pickLine: insulatePickLine(), legacy, cases };
const out = resolve(process.argv.find(a => a.endsWith('.json')) ?? '../s2/tests/fixtures/train/mods_vectors.json');
const text = JSON.stringify(output) + '\n';
if (Buffer.byteLength(text) >= 5_000_000) throw new Error('Fixture exceeds 5 MB');
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, text);
console.log(JSON.stringify({ format: FORMAT, cases: cases.length, furnishCases: furnishCases.length,
  furnishSteps: furnishCases.reduce<number>((sum, row) => sum + (row as { steps: unknown[] }).steps.length, 0),
  decorSlots: decorSlots.length, decorCases: decorCases.length, decorSteps: decorCases.reduce((sum, row) => sum + row.steps.length, 0), bytes: Buffer.byteLength(text), out }));
