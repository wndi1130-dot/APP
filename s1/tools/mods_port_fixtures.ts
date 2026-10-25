// 단열 개조 이식 표본(결정 426 PR 4). S2가 단열 개조 줄·난방 석탄·처지 몫을 GDScript로 옮길 때 맞대 볼 기준 값을 만든다.
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
import { CAR_COMM, COMM_CARS, D } from '../src/game/domestic/data';
import { createS1cGame } from '../src/game/domestic/state';
import { refreshSit } from '../src/game/domestic/sit';
import { insulatedShare, insulateCarNote, insulateNumbers, insulatePickLine } from '../src/game/domestic/lawtech';
import { cancelJob, cancelOpen, CAR_NAME, jobCheck, jobTitle, runWorkshop, startJob, workPower } from '../src/game/domestic/workshop';

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
const dKeys = ['insulateWork', 'insulateWood', 'insulateWarm', 'insulateHeat', 'insulateCrowd', 'insulateQuotaHalf'] as const;
const output = { format: FORMAT, seeds, checkpoints, profiles,
  scope: 'Played S1a + neutralized S1c dom; modify-only order, no work debt, no other law-tech relief; no climate/hygiene/UI',
  tables: { COMMS, P, HANDS, CAR_COMM, COMM_CARS, CAR_NAME, HEAT_QUOTA_MATS: LAWS.heat_quota.mats,
    D: Object.fromEntries(dKeys.map(k => [k, D[k]])) }, pickLine: insulatePickLine(), legacy, cases };
const out = resolve(process.argv.find(a => a.endsWith('.json')) ?? '../s2/tests/fixtures/train/mods_vectors.json');
const text = JSON.stringify(output) + '\n';
if (Buffer.byteLength(text) >= 5_000_000) throw new Error('Fixture exceeds 5 MB');
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, text);
console.log(JSON.stringify({ format: FORMAT, cases: cases.length, bytes: Buffer.byteLength(text), out }));
