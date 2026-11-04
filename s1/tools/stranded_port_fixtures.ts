// S1 is the oracle. Inputs are copies of the slice's board, with explicit test setup.
// No Godot, network, source rewriting or answer-derived game code is used here.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Card, Game } from '../src/game';
import { END_LINK } from '../src/game/state';
import { readSave } from '../src/ui/repro';
import { buildContentBundle } from './content_port';

const ROOT = resolve(import.meta.dirname, '../..');
const SOURCE = 's2/game/train/slice_start.json';
const OUTPUTS = ['s2/tests/fixtures/train/stranded_vectors.json', 's2/tests/fixtures/train/stranded_content_vectors.json'];
const sourceBytes = readFileSync(resolve(ROOT, SOURCE));
const source = JSON.parse(sourceBytes.toString('utf8')) as { state: Game; seed: string };
const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
type Action = { kind: string; [key: string]: unknown };
type Step = { action: Action; before: Game; after: Game; result?: unknown };
type Case = { id: string; scene: number; seed: string; setup: string; steps: Step[]; profileAges?: Record<string, number> };
type Run = { row: Case; g: Game; step: (action: Action, run: () => unknown) => unknown };
const cases: Case[] = [];

function fresh(seed: string): Game {
  const g = plain(source.state);
  g.seed = seed;
  g.rng = plain(S1.createGame(seed).rng);
  g.cards = [];
  return g;
}
function rels(g: Game, value = 30): void { for (const c of S1.COMMS) g.comms[c].rel = value; }
function stopped(g: Game, distance = 15): void {
  g.coal = 5;
  S1.enterStranded(g, 5, 10);
  g.stranded!.atKm = 15;
  g.stranded!.segKm = 15 + distance;
  g.stranded!.toNextKm = distance;
  rels(g);
}
function make(id: string, scene: number, seed = 'st-bot-1', setup = '', init?: (g: Game) => void): Run {
  const g = fresh(seed);
  init?.(g);
  const row: Case = { id, scene, seed, setup, steps: [] };
  cases.push(row);
  return { row, g, step(action, run) {
    const before = plain(g);
    const result = run();
    row.steps.push(plain({ action, before, after: g, ...(result === undefined ? {} : { result }) }));
    return result;
  } };
}
// Setup transitions isolate a subrule (e.g. a pending last return tick). They are
// explicitly labelled, replayed by the test harness only, never claimed as game actions.
function setup(r: Run, values: Partial<Game>): void {
  r.step({ kind: 'setup', values: plain(values) }, () => { Object.assign(r.g, plain(values)); });
}
function advance(r: Run): void {
  assert.equal(S1.primaryAction(r.g).ok, true, `${r.row.id}: advance is available at ${r.g.seg}/${r.g.phase}, cards=${r.g.cards.map(c => c.kind)}`);
  r.step({ kind: 'advance' }, () => S1.advance(r.g));
}
function tuple(e: S1.Eff): unknown[] {
  switch (e.t) {
    case 'rel': case 'fervor': case 'pop': return [e.t, e.c, e.v];
    case 'base': return [e.t, e.c, e.i, e.v];
    case 'lever': return [e.t, e.c, e.which, e.v];
    case 'debt': case 'grudge': return [e.t, e.c];
    default: return [e.t, e.v];
  }
}
function projectedView(g: Game, card: Card) {
  const v = S1.viewCard(g, card);
  return plain({ title: v.title, body: v.body ?? '', required: !!v.required, focus: v.focus ?? null, speaker: v.speaker ?? null, key: v.key ?? null,
    choices: v.choices.map(c => ({ label: c.label, log: c.log ?? '', say: c.say ?? '', why: c.why ?? '', later: c.later ?? '', disabled: c.disabled ?? '',
      special: c.special ?? '', witness: !!c.witness, extra: c.extra ?? [], effs: c.effs.map(tuple) })),
    costs: v.choices.map(S1.costLines), pols: v.choices.map(S1.politicsLines) });
}
function view(r: Run, card: Card): void { r.step({ kind: 'view', card: plain(card) }, () => projectedView(r.g, card)); }
function add(r: Run, card: Omit<Card, 'uid'>): Card {
  r.step({ kind: 'add_card', card }, () => S1.addCard(r.g, card));
  return r.g.cards.find(c => c.kind === card.kind && c.text === card.text)!;
}
function choose(r: Run, card: Card, index: number): void {
  view(r, card);
  r.step({ kind: 'choose_card', uid: card.uid, index }, () => { assert(S1.chooseCard(r.g, card.uid, index), `${r.row.id}: choose ${card.kind}/${index}`); });
}
function start(r: Run, mode: 'crew' | 'captain'): void {
  r.step({ kind: 'start_trip', mode }, () => S1.startTrip(r.g, mode));
  assert(r.g.stranded?.trip);
}
function tick(r: Run): void { r.step({ kind: 'trip_tick' }, () => S1.tripTick(r.g)); }
function plans(r: Run): void {
  r.step({ kind: 'plans' }, () => ({ crew: S1.tripPlan(r.g, 'crew'), captain: S1.tripPlan(r.g, 'captain'),
    allowed: S1.crewAllowed(r.g), deputy: S1.deputyOf(r.g), supportLine: S1.supportLineText(r.g) }));
}
function drain(r: Run): void {
  for (let n = 0; n < 60 && r.g.cards.length; n++) {
    const card = r.g.cards[0];
    choose(r, card, S1.viewCard(r.g, card).choices.findIndex(c => !c.disabled));
  }
  assert.equal(r.g.cards.length, 0, `${r.row.id}: drained actual card choices`);
}
function ready(seed: string, mode: 'crew' | 'captain', shortage = 0, radio = false): Game {
  const g = fresh(seed); stopped(g);
  if (shortage) g.food = S1.tripPlan(g, mode)!.food - shortage;
  if (radio) g.dom = { techs: { r3: { stage: 'done' } } } as never; // isolated trip rule, not domestic settlement
  assert(S1.startTrip(g, mode));
  return g;
}
const seedCache = new Map<string, string>();
function seedFor(outcome: 'coal' | 'lost', extensions = 0, mode: 'crew' | 'captain' = 'crew', shortage = 0): string {
  const key = `${outcome}-${extensions}-${mode}-${shortage}`;
  if (seedCache.has(key)) return seedCache.get(key)!;
  for (let i = 0; i < 4000; i++) {
    const seed = `stranded-${key}-${i}`;
    const g = ready(seed, mode, shortage);
    const trip = g.stranded!.trip!;
    for (let n = 0; n < 24 && trip.outcome === null; n++) S1.tripTick(g);
    if (trip.outcome === outcome && trip.extends === extensions) { seedCache.set(key, seed); return seed; }
  }
  throw new Error(`seed not found: ${key}`);
}
function tripRun(id: string, scene: number, outcome: 'coal' | 'lost', extensions = 0, mode: 'crew' | 'captain' = 'crew', shortage = 0, radio = false, forced = false): Run {
  const seed = seedFor(outcome, extensions, mode, shortage);
  const r = make(id, scene, seed, `15km; ${mode}; shortage=${shortage}; radio=${radio}; forced=${forced}; outcome=${outcome}; extensions=${extensions}`, g => {
    stopped(g);
    if (forced) rels(g, -20);
    if (shortage) g.food = S1.tripPlan(g, mode)!.food - shortage;
    if (radio) g.dom = { techs: { r3: { stage: 'done' } } } as never;
  });
  start(r, mode);
  return r;
}
function toReturn(r: Run): Card {
  for (let i = 0; i < 24 && r.g.stranded?.trip && r.g.phase !== 'end'; i++) {
    tick(r);
    const card = r.g.cards.find(c => c.kind === 'trip_return');
    if (card) return card;
  }
  throw new Error(`no return: ${r.row.id}`);
}

function buildCases(): void {
  const distance = make('segment-distance-and-floor-ceil', 1, 'st-bot-1', 'fixture route length=45; coal=4; need=7.6', g => { g.coal = 4; g.route = [{ seg: g.seg, km: 45 }] as never; });
  distance.step({ kind: 'enter', coal: 4, need: 7.6 }, () => S1.enterStranded(distance.g, 4, 7.6));
  distance.step({ kind: 'stall_math' }, () => [S1.stallKm(30, 4, 10), S1.stallKm(30, 0, 10), S1.stallKm(30, 10, 10), S1.stallKm(30, 4, 0), S1.stallKm(1, -2, 10)]);
  plans(distance);
  for (const [id, route] of [['null', null], ['missing-km', [{ seg: 1 }]], ['null-km', [{ seg: 1, km: null }]], ['other-segment', [{ seg: 2, km: 45 }]]] as const) {
    const r = make(`route-fallback-${id}`, 1, 'st-bot-1', `route=${id}; missing distance falls back to P.segKmDefault`, g => { g.coal = 4; g.route = plain(route) as never; });
    r.step({ kind: 'enter', coal: 4, need: 10 }, () => S1.enterStranded(r.g, 4, 10));
    assert.equal(r.g.stranded!.segKm, S1.P.segKmDefault);
  }
  const hot = make('heat-four-coal-11.35', 2, 'st-bot-1', 'decision 521 regression: population=200; all heat=4; coal=11.35; climate off', g => {
    g.coal = 11.35; g.climate = false; g.phase = 'travel'; for (const c of S1.COMMS) g.comms[c].heat = 4;
  });
  advance(hot); assert(hot.g.stranded); assert.equal(hot.g.stranded.burned, 11.35);
  for (const [id, scene, phase] of [['first-settle', 1, 'council'], ['en-route', 2, 'travel']] as const) {
    const r = make(id, scene, 'st-bot-1', 'coal=3; no council/cards; phase=' + phase, g => { g.coal = 3; g.phase = phase; g.council = null; });
    advance(r);
    assert.equal(r.g.stranded!.burned, 3);
    assert.equal(r.g.lastSettle!.coal, -3);
    assert.equal(r.g.stop, null);
    assert.equal(r.g.stranded!.turns, 0);
  }
  for (const coal of [0, 1, 2]) {
    const r = make(`stranded-settle-coal-${coal}`, 3, 'st-bot-1', `already stranded; coal=${coal}; seg=2; council settlement`, g => {
      stopped(g); g.seg = 2; g.phase = 'council'; g.coal = coal;
      g.comms.tail.base[0] = 7; g.comms.front.base[0] = 12;
    });
    advance(r);
    assert.equal(r.g.stranded!.turns, 1);
  }
  const warm = make('warm-floor-and-zero-ration', 8, 'st-bot-1', 'warm=7/12; ration=0; ration_down_asked', g => {
    stopped(g); g.comms.tail.base[0] = 7; g.comms.front.base[0] = 12; g.comms.tail.ration = 0; g.contentFlags!.ration_down_asked = true;
  });
  warm.step({ kind: 'stranded_settle' }, () => S1.strandedSettle(warm.g));
  assert.equal(warm.g.comms.tail.base[0], 7); assert.equal(warm.g.comms.front.base[0], 10); assert.equal(warm.g.comms.tail.ration, 0);

  for (const [id, rel, special] of [['crew', 30, 'trip_go_crew'], ['captain', 30, 'trip_go_captain'], ['forced', -20, 'trip_go_captain'], ['wait', 30, 'trip_stay']] as const) {
    const r = make(`depart-${id}`, 4, 'st-bot-1', `all relations=${rel}; choice=${special}`, g => { stopped(g); rels(g, rel); });
    const card = add(r, { kind: 'trip_depart', comm: 'tail' });
    const index = S1.viewCard(r.g, card).choices.findIndex(c => c.special === special);
    assert(index >= 0); choose(r, card, index);
    if (id === 'forced') assert.equal(r.g.stranded!.trip!.forced, true);
    if (id === 'wait') assert.equal(r.g.stranded!.trip, null);
  }
  const threshold = make('support-exactly-half-and-relation-15', 4, 'st-bot-1', 'support=100/200; relations=15/14; stable COMMS tie', g => {
    stopped(g);
    S1.COMMS.forEach((c, i) => { g.comms[c].pop = [50, 50, 40, 30, 30][i]; g.comms[c].rel = i < 2 ? 15 : 14; });
  });
  plans(threshold); assert.equal(S1.supportShare(threshold.g), 0.5); assert.equal(S1.tripPlan(threshold.g, 'crew')!.comm, S1.COMMS[0]);
  const tied = make('all-relations-tied', 4, 'st-bot-1', 'all relations=15', g => { stopped(g); rels(g, 15); }); plans(tied);
  const pool = S1.PROFILES.filter(p => p.community === 'tail' && p.name !== source.state.comms.tail.leader.name && p.age >= 16 && p.age <= 65).slice(0, 4);
  assert.equal(pool.length, 4);
  const ages = Object.fromEntries(pool.map((p, i) => [p.name, [15, 16, 65, 66][i]]));
  const savedAges = new Map(S1.PROFILES.map(p => [p.name, p.age]));
  try {
    for (const p of S1.PROFILES) if (p.name in ages) p.age = ages[p.name];
    const boundary = make('age-15-16-65-66-and-short-pool', 4, 'st-bot-1', 'fixture-only profile ages; only two eligible tail volunteers; no other eligible cars', g => {
      stopped(g); rels(g, 14); g.comms.tail.rel = 15;
      g.deaths = S1.PROFILES.filter(p => !pool.some(x => x.name === p.name) && !S1.COMMS.some(c => g.comms[c].leader.name === p.name)).map(p => p.name);
    });
    boundary.row.profileAges = ages;
    plans(boundary);
    assert.equal(S1.tripPlan(boundary.g, 'crew'), null);
    assert.deepEqual(new Set(S1.tripPlan(boundary.g, 'captain')!.names), new Set([pool[1].name, pool[2].name]));
  } finally { for (const p of S1.PROFILES) p.age = savedAges.get(p.name)!; }
  const sick = make('exclude-current-and-sick-representatives', 4, 'st-bot-1', 'tail sick representative is excluded as well as current representative', g => {
    stopped(g); g.comms.tail.rel = 60;
    g.comms.tail.sick = { rep: { ...g.comms.tail.leader, name: pool[0].name } } as never;
  }); plans(sick); assert(!S1.tripPlan(sick.g, 'crew')!.names.includes(pool[0].name));
  const oldCards = make('trip-card-empty-and-null-fields', 4, 'st-bot-1', 'old cards with absent/null names and no active trip', g => { stopped(g); });
  for (const card of [{ uid: 800, kind: 'trip_return' }, { uid: 801, kind: 'trip_lost', comm: null, who: null }, { uid: 802, kind: 'trip_extend', comm: null, n: null }] as unknown as Card[]) view(oldCards, card);

  for (const radio of [false, true]) for (const extensions of [0, 1, 2]) {
    const r = tripRun(`coal-extend-${extensions}-radio-${radio}`, extensions ? 6 : 5, 'coal', extensions, 'crew', 0, radio);
    const card = toReturn(r); view(r, card);
    if (!radio && extensions === 0) view(r, { ...card, n: null } as never);
    assert.equal(r.g.stranded!.trip!.extends, extensions);
    if (radio && extensions) {
      const extended = r.g.cards.find(c => c.kind === 'trip_extend'); assert(extended); view(r, extended);
    }
  }
  for (const radio of [false, true]) {
    const r = tripRun(`crew-lost-radio-${radio}`, 5, 'lost', 0, 'crew', 0, radio);
    for (let i = 0; i < 24 && r.g.stranded!.trip; i++) tick(r);
    assert.equal(r.g.stranded!.lostTrips, 1);
    view(r, r.g.cards.find(c => c.kind === 'trip_lost')!);
  }
  for (const shortage of [3, 4]) {
    const r = tripRun(`food-short-${shortage}`, 6, 'lost', 0, 'crew', shortage);
    assert.equal(r.g.stranded!.trip!.foodShort, shortage);
    for (let i = 0; i < 24 && r.g.stranded!.trip; i++) tick(r);
  }
  let paritySeed = '';
  for (let i = 0; i < 4000; i++) {
    const candidate = `stranded-short-parity-${i}`;
    const draw = S1.rnd(ready(candidate, 'crew', 3));
    if (draw >= S1.P.tripLostFirst + S1.P.tripShortLost && draw < S1.P.tripLostFirst + 2 * S1.P.tripShortLost) { paritySeed = candidate; break; }
  }
  assert(paritySeed);
  for (const shortage of [3, 4]) {
    const r = make(`shortage-parity-${shortage}`, 6, paritySeed, `same first RNG draw; foodShort=${shortage}; floor(short/2) boundary`, g => { stopped(g); g.food = S1.tripPlan(g, 'crew')!.food - shortage; });
    start(r, 'crew'); tick(r);
    assert.equal(r.g.stranded!.trip!.outcome === 'lost', shortage === 4);
  }
  for (const promise of ['yes', 'no'] as const) {
    const r = tripRun(`promise-flag-${promise}`, 6, 'coal');
    setup(r, { contentFlags: { ...r.g.contentFlags, stranded_promise: promise } });
    tick(r);
    assert.equal(r.g.stranded!.trip!.promise, promise); assert.equal(r.g.contentFlags!.stranded_promise, false);
  }
  for (const [id, mode, promise, lux, forced] of [
    ['promise-rich', 'crew', 'yes', 3, false], ['promise-poor', 'crew', 'yes', 0, false], ['no-promise', 'crew', 'no', 3, false],
    ['captain', 'captain', null, 3, false], ['forced-captain', 'captain', null, 3, true],
  ] as const) {
    const r = tripRun(`return-${id}`, 6, 'coal', 0, mode, 0, false, forced);
    const card = toReturn(r);
    const st = plain(r.g.stranded!); st.snow = 'none'; st.trip!.promise = promise;
    setup(r, { stranded: st, lux });
    choose(r, card, 0);
    assert.equal(r.g.stranded, null); assert.equal(r.g.coal, S1.P.tripCoal - 2);
    const resumed = plain(r.g);
    r.step({ kind: 'save' }, () => { const read = readSave(plain(r.g)); assert(read.ok); return read.ok ? read.g.stranded : null; });
    assert.deepEqual(r.g, resumed);
  }
  const lamp = tripRun('lamp-after-entering-back', 6, 'coal');
  while (lamp.g.stranded!.trip!.phase !== 'back') tick(lamp);
  const back = lamp.g.stranded!.trip!.backTurns;
  setup(lamp, { contentFlags: { ...lamp.g.contentFlags, stranded_lamp: true } });
  lamp.step({ kind: 'stranded_settle' }, () => S1.strandedSettle(lamp.g));
  assert.equal(lamp.g.stranded!.trip!.backTurns, back);

  const council = make('captain-defers-once-then-council', 7, 'st-bot-1', 'seg=3; captain away; long trip; councilOwed once', g => {
    stopped(g, 150); g.seg = 3; S1.startTrip(g, 'captain'); g.phase = 'travel'; g.food = 500;
  });
  advance(council); assert.equal(council.g.councilOwed, true);
  setup(council, { phase: 'travel', cards: [], seg: 4 }); advance(council);
  assert.equal(council.g.journal.filter(j => j.text === '열차장이 돌아오면 회기를 연다.').length, 1);
  const backState = plain(council.g.stranded!); backState.captainAway = false; backState.trip = null;
  setup(council, { stranded: backState, phase: 'travel', cards: [], seg: 5 }); advance(council);
  assert.equal(council.g.phase, 'council'); assert.equal(council.g.councilOwed, false);
  const filtered = make('captain-view-filters', 7, 'st-bot-1', 'captainAway=true; tension/protest/snow', g => { stopped(g); g.stranded!.captainAway = true; });
  for (const card of [{ uid: 700, kind: 'tension_crisis', comm: 'tail' }, { uid: 701, kind: 'protest', comm: 'tail' }, { uid: 702, kind: 'protest', comm: 'tail', text: 'riot' }, { uid: 703, kind: 'content', text: 'ev_str_snow', comm: 'engine' }] as Card[]) view(filtered, card);

  for (const lowFood of [false, true]) {
    const r = make(`event-order-low-food-${lowFood}`, 8, 'st-bot-1', `climate off (snow); active trip; food=${lowFood ? 30 : 200}`, g => {
      stopped(g, 150); g.climate = false; S1.startTrip(g, 'crew'); g.food = lowFood ? 30 : 200;
    });
    for (let i = 0; i < 4; i++) {
      if (i) setup(r, { cards: [], phase: 'prep' });
      r.step({ kind: 'stranded_depart' }, () => S1.strandedDepart(r.g));
      const card = r.g.cards.find(c => c.kind === 'content')!;
      assert(card); choose(r, card, 0);
      r.step({ kind: 'stranded_settle' }, () => S1.strandedSettle(r.g));
      if (r.g.contentFlags?.stranded_promise) tick(r);
    }
    assert.deepEqual(r.g.stranded!.seen, lowFood ? ['ev_str_half_bowl', 'ev_str_lamp', 'ev_str_snow', 'ev_str_promise'] : ['ev_str_lamp', 'ev_str_snow', 'ev_str_promise', 'ev_str_half_bowl']);
  }
  const loss = tripRun('finish-lost_captain-in-settle', 9, 'lost', 0, 'captain');
  while (loss.g.stranded!.trip!.turn < loss.g.stranded!.trip!.goTurns + loss.g.stranded!.trip!.searchTurns + loss.g.stranded!.trip!.backTurns) tick(loss);
  setup(loss, { seg: 2, phase: 'council', cards: [], council: null, raised: { '표본의 아이': 'tail' } });
  advance(loss); assert.equal(loss.g.end, 'lost_captain'); assert.equal(loss.g.phase, 'end');
  for (const end of ['revolt', 'ousted'] as const) {
    const r = make(`finish-${end}-in-settle`, 9, 'st-bot-1', `stranded seg=2; ${end} threshold; raised record`, g => {
      stopped(g); g.seg = 2; g.phase = 'council'; g.raised = { '표본의 아이': 'tail' };
      if (end === 'revolt') { rels(g, -60); g.tension = 100; g.tensionCrisisUsed = 2; } else { g.trust = 0; g.trustCrisis = 2; }
    }); advance(r); assert.equal(r.g.end, end);
  }
  const revolt = make('revolt-card-common-finish', 9, 'st-bot-1', 'stranded tension crisis last choice', g => { stopped(g); });
  const crisis = add(revolt, { kind: 'tension_crisis', comm: 'tail' });
  choose(revolt, crisis, S1.viewCard(revolt.g, crisis).choices.findIndex(c => c.special === 'revolt'));
  assert.equal(revolt.g.end, 'revolt');
  const runningEnd = make('finish-ousted-from-travel', 9, 'st-bot-1', 'travel; strike sends directly to settle; expired trust crisis; coal remains', g => {
    g.phase = 'travel'; g.inStrike = true; g.trust = 0; g.trustCrisis = g.seg;
  });
  advance(runningEnd); assert.equal(runningEnd.g.end, 'ousted'); assert.equal(runningEnd.g.stranded, undefined);
  const finish = make('finish-first-ending-wins-and-education', 9, 'st-bot-1', 'S1a ending; optional pre-existing edu/raised records', g => {
    g.edu = { segs: 2, early: 1, hands: 1 } as never; g.raised = { '기록의 아이': 'medtech' }; g.food = 20;
  });
  finish.step({ kind: 'finish', end: 'coup' }, () => END_LINK.finish(finish.g, 'coup'));
  const ended = plain(finish.g);
  finish.step({ kind: 'finish', end: 'revolt' }, () => END_LINK.finish(finish.g, 'revolt'));
  assert.deepEqual(finish.g, ended);
  for (const [id, skip, thin] of [
    ['no-insulation', { noInsulate: 2 }, false], ['breakdown', { breakdown: 1 }, false],
    ['tail-heat', { tailHeat: 3 }, false], ['heat-quota', { heatQuota: 3 }, false],
    ['tail-ration', { tailRation: 4 }, false], ['contribution', { contribution: 4 }, false],
    ['outsiders', { noOutsiders: 4 }, false], ['thin-route', { tailHeat: 8 }, true],
  ] as const) {
    const r = make(`lookback-${id}`, 9, 'st-bot-1', `S1 finish text branch: ${id}`, g => {
      g.seg = 8; g.coal = g.food = 50;
      g.comms.tail.heat = g.comms.tail.ration = 2;
      g.look = { low: { coal: 2, food: 3 }, skip: { ...skip }, coalStops: thin ? 0 : 10 };
      if (thin) g.look.low.coal = 8;
    });
    r.step({ kind: 'finish', end: 'revolt' }, () => END_LINK.finish(r.g, 'revolt'));
  }
  for (const coalLow of [false, true]) {
    const r = make(`lookback-existing-stores-${coalLow}`, 9, 'st-bot-1', 'finish reads pre-existing wood/scrap/insulation records; no domestic tick', g => {
      g.coal = coalLow ? 10 : 50; g.food = 50;
      g.dom = { wood: coalLow ? 8 : 3, scrap: coalLow ? 10 : 3, insulated: [], stats: { breakdowns: 0 } } as never;
    });
    r.step({ kind: 'finish', end: 'revolt' }, () => END_LINK.finish(r.g, 'revolt'));
  }

  const exact = make('exact-coal-en-route', 10, 'st-bot-1', 'coal exactly forecast; travel', g => { g.phase = 'travel'; g.coal = S1.forecast(g).coal; });
  advance(exact); assert.equal(exact.g.stranded!.atKm, 29);
  const strike = make('strike-overlaps-stranded', 10, 'st-bot-1', 'already stranded; inStrike; no stranded warmth/tension tick', g => { stopped(g); g.seg = 2; g.phase = 'council'; g.inStrike = true; });
  advance(strike); assert.equal(strike.g.stranded!.turns, 0);
  const twice = tripRun('second-stranding-after-resume', 10, 'coal');
  choose(twice, toReturn(twice), 0);
  setup(twice, { seg: 2, phase: 'travel', coal: 1, cards: [] }); advance(twice);
  assert.equal(twice.g.stranded!.since, 2); assert.equal(twice.g.stranded!.turns, 0);
  const flags = make('ordinary-depart-materializes-empty-flags', 10, 'st-bot-1', 'ordinary departure; event pack off; all travel definitions installed', g => { delete g.contentFlags; });
  assert(!Object.hasOwn(flags.g, 'contentFlags')); advance(flags); assert.deepEqual(flags.g.contentFlags, {});
  for (const variant of ['absent', 'stranded', 'away', 'resumed', 'old-burned'] as const) {
    const r = make(`save-${variant}`, 9, 'st-bot-1', `save roundtrip ${variant}`, g => {
      if (variant !== 'absent') stopped(g);
      if (variant === 'away') S1.startTrip(g, 'captain');
      if (variant === 'resumed') S1.resumeRun(g);
      if (variant === 'old-burned') delete g.stranded!.burned;
    });
    r.step({ kind: 'save' }, () => { const read = readSave(plain(r.g)); assert(read.ok); return read.ok ? read.g.stranded ?? null : null; });
  }
  const six = make('six-stranded-turns-budget-once-per-segment', 10, 'st-bot-1', 'long captain trip; food=500; six full stranded settles; budget enabled', g => {
    stopped(g, 150); g.climate = false; S1.startTrip(g, 'captain'); g.phase = 'settle'; g.food = 500; g.trust = 80;
    for (const c of S1.COMMS) g.comms[c].base[0] = 70;
    S1.enableBudget(g);
  });
  for (let turn = 0; turn < 6; turn++) {
    advance(six);
    const once = plain(six.g);
    six.step({ kind: 'budget_next' }, () => S1.budgetNextSeg(six.g)); assert.deepEqual(six.g, once);
    drain(six); // Cards brought back by this new segment precede departure.
    advance(six);
    drain(six);
    advance(six);
    drain(six);
    assert.equal(six.g.phase, 'settle'); assert.equal(six.g.stranded!.turns, turn + 1);
  }
  const duplicate = make('budget-second-call-keeps-deferred-stats', 10, 'st-bot-1', 'deferred overflow; same-segment second call must do nothing', g => {
    S1.enableBudget(g); g.budget!.picked = 3;
    // Five grade-3 slots survive deferral; perSeg=3 leaves two still pending after the first call.
    for (const comm of S1.COMMS) S1.addCard(g, { kind: 'keepsake', comm, who: g.comms[comm].leader.name });
    g.cards = []; g.seg += 1;
  });
  duplicate.step({ kind: 'budget_next' }, () => S1.budgetNextSeg(duplicate.g));
  assert.equal(duplicate.g.deferred!.length, 2, 'non-vacuous duplicate-call regression: two cards remain deferred');
  const once = plain(duplicate.g);
  duplicate.step({ kind: 'budget_next' }, () => S1.budgetNextSeg(duplicate.g)); assert.deepEqual(duplicate.g, once);
  const tripBudget = make('trip-cards-use-budget-grade', 10, 'st-bot-1', 'budget picked=3; all four trip kinds still use onAdd and remain required', g => {
    stopped(g); S1.enableBudget(g); g.budget!.picked = 3;
  });
  for (const kind of S1.STRANDED_CARD_KINDS) add(tripBudget, { kind, comm: 'tail' });
  assert.equal(tripBudget.g.cards.length, 4); assert.equal(tripBudget.g.deferred!.length, 0);
}

function buildSaveContinuationCases(): void {
  const find = (id: string) => { const row = cases.find(c => c.id === id); assert(row); return row; };
  const atStation = find('coal-extend-0-radio-false').steps.find(s => s.after.stranded?.trip?.outcome === 'coal')!.after;
  const unknownExtend = find('coal-extend-1-radio-false').steps.find(s => (s.after.stranded?.trip?.extends ?? 0) > 0 && !s.after.stranded!.trip!.known)!.after;
  const starts = [
    ['no-trip', find('save-stranded').steps[0].before], ['going', find('save-away').steps[0].before],
    ['station-result', atStation], ['unknown-extension', unknownExtend],
  ] as const;
  for (const [id, state] of starts) {
    const r = make(`save-next-${id}`, 9, state.seed, `save ${id}, reload, then the same complete next settlement`, g => {
      Object.assign(g, plain(state)); g.phase = 'council'; g.council = null; g.cards = []; g.seg = g.stranded!.since + 1;
    });
    r.step({ kind: 'save_next' }, () => {
      const read = readSave(plain(r.g)); assert(read.ok);
      const canonical = plain(read.g);
      const direct = plain(canonical); S1.advance(direct);
      const reloaded = readSave(plain(canonical)); assert(reloaded.ok); S1.advance(reloaded.g);
      assert.deepEqual(plain(reloaded.g), direct, `save ${id}: next state and RNG unchanged`);
      return { before: canonical, after: plain(reloaded.g) };
    });
  }
}

function buildContentCases() {
  const out = [];
  for (const id of S1.STRANDED_EVENTS) for (const variant of ['normal', ...(id === 'ev_str_lamp' ? ['poor'] : []), ...(id === 'ev_str_snow' ? ['captain-away'] : [])]) {
    const g = fresh(`stranded-content-${id}-${variant}`); stopped(g); g.climate = false; S1.startTrip(g, 'crew'); g.phase = 'travel';
    if (variant === 'poor') g.lux = 0;
    if (variant === 'captain-away') g.stranded!.captainAway = true;
    const before = plain(g);
    assert(S1.addContentCard(g, id, false, true), `${id}: eligible`);
    const card = g.cards.at(-1)!;
    const view = projectedView(g, card);
    const choices = S1.viewCard(g, card).choices.flatMap((c, index) => {
      if (c.disabled) return [];
      const after = plain(g); assert(S1.chooseCard(after, card.uid, index));
      return [{ index, after: plain(after) }];
    });
    out.push({ id, variant, before, state: plain(g), card: plain(card), view, choices });
  }
  return { format: 'stranded-content-v1', events: [...S1.STRANDED_EVENTS], cases: out };
}
function write(path: string, value: unknown): number {
  const text = JSON.stringify(value) + '\n';
  const bytes = Buffer.byteLength(text);
  assert(bytes < 30 * 1024 * 1024, 'fixture size limit');
  let old = ''; try { old = readFileSync(resolve(ROOT, path), 'utf8'); } catch { /* new artifact */ }
  if (old !== text) writeFileSync(resolve(ROOT, path), text, 'utf8');
  return bytes;
}
function main(): void {
  const bundle = buildContentBundle();
  const saved = { events: [...S1.CONTENT_EVENTS], secrets: [...S1.CONTENT_SECRETS], deals: [...S1.CONTENT_DEALS], profiles: JSON.stringify(S1.PROFILES) };
  S1.CONTENT_EVENTS.length = S1.CONTENT_SECRETS.length = S1.CONTENT_DEALS.length = 0;
  try {
    S1.registerContentEvents(bundle.events); S1.registerContentSecrets(bundle.secrets); S1.registerContentDeals(bundle.deals);
    buildCases();
    buildSaveContinuationCases();
    const blocked = [22, 24, 25].map(seg => {
      const g = fresh('st-bot-1'); stopped(g); g.phase = 'settle'; g.seg = seg;
      const before = plain(g); S1.advance(g);
      return { seg, before, s1After: plain(g), s2: 'F-NOT-PORTED: nextSegment: terminal/decree expiry' };
    });
    assert.deepEqual([...new Set(cases.map(c => c.scene))].sort((a, b) => a - b), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    assert.equal(JSON.stringify(S1.PROFILES), saved.profiles, 'fixture age overrides restored');
    const content = buildContentCases();
    const data = { format: 'stranded-vectors-v1', source: SOURCE, sourceJsonSha256: createHash('sha256').update(JSON.stringify(source)).digest('hex'), baselineSeed: source.seed,
      botSeedEvidence: 'st-bot-1: existing S1 stranded.test.ts playGame caretaking regression; this corpus applies explicit coal/lever setup to the slice board',
      cases, blocked, seedSearch: Object.fromEntries(seedCache) };
    const bytes = [write(OUTPUTS[0], data), write(OUTPUTS[1], content)];
    console.log(JSON.stringify({ cases: cases.length, steps: cases.reduce((n, c) => n + c.steps.length, 0), scenes: 10, blocked: blocked.length,
      contentCases: content.cases.length, contentChoices: content.cases.reduce((n, c) => n + c.choices.length, 0), bytes, seedSearch: Object.fromEntries(seedCache) }));
  } finally {
    S1.CONTENT_EVENTS.splice(0, S1.CONTENT_EVENTS.length, ...saved.events);
    S1.CONTENT_SECRETS.splice(0, S1.CONTENT_SECRETS.length, ...saved.secrets);
    S1.CONTENT_DEALS.splice(0, S1.CONTENT_DEALS.length, ...saved.deals);
  }
}
if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
