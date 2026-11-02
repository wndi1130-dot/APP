// PR 1: S1a supplies answers come only from S1 functions. No workshop or S1 rule edits.
// Run: node --import tsx tools/supplies_port_fixtures.ts
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Card, Comm, Game, StayId } from '../src/game';
import { bump, bumpParts, put } from '../src/game/ledger';
import { workShare } from '../src/game/hands';
import { buildDeparture } from '../src/game/field_departure';
import { applyFieldReturn } from '../src/game/field_receipt';
import type { FieldDeparture } from '../src/game/field_receipt';
import { addSupplies, enableSupplies, SUP_YIELD, suppliesAsks, suppliesHygieneShort, suppliesNeed, suppliesRelations, suppliesUse } from '../src/game/supplies';
import { tables } from './turn_port_fixtures';

const plain = <T>(x: T): T => JSON.parse(JSON.stringify(x)) as T;
const groups: Record<string, unknown[]> = { enable: [], use: [], ledger: [], stops: [], fields: [], departures: [], cards: [], conditions: [], settles: [] };
function fresh(on = true): Game {
  const g = S1.createGame('sup-port-pr1');
  if (on) enableSupplies(g);
  return g;
}
function mutate(group: string, name: string, g: Game, run: (g: Game) => unknown) {
  const before = plain(g);
  const value = run(g) ?? null;
  groups[group].push({ name, before, value: plain(value), after: plain(g) });
}
for (const flag of [undefined, false, true]) {
  const g = fresh(false);
  if (flag !== undefined) g.supOn = flag;
  mutate('enable', `enable/${String(flag)}`, g, enableSupplies);
}

function useCase(name: string, g: Game) {
  mutate('use', name, g, board => {
    const need = suppliesNeed(board);
    const hygieneBefore = Object.fromEntries(S1.COMMS.map(c => [c, suppliesHygieneShort(board, c)]));
    const turn = suppliesUse(board);
    suppliesRelations(board, turn);
    return { need, turn: turn ?? {}, asks: suppliesAsks(board), hygieneBefore,
      hygiene: Object.fromEntries(S1.COMMS.map(c => [c, suppliesHygieneShort(board, c)])) };
  });
}
for (const flag of [undefined, false]) {
  const g = fresh(false);
  if (flag !== undefined) g.supOn = flag;
  useCase(`off/${String(flag)}`, g);
  mutate('ledger', `off/${String(flag)}`, g, board => {
    addSupplies(board, 9, 'field.loot'); bump(board, 'sup', 3, 'sup.search');
    bumpParts(board, 'sup', 4, [['sup.search', 1]]); put(board, 'sup', 7, 'sup.use');
  });
}
for (const stock of [0, 1.5, 8, 12, 11.999]) {
  const g = fresh(); g.sup = stock; useCase(`stock/${stock}`, g);
}
{
  const g = fresh(); delete g.sup; useCase('missing-stock', g);
  const zero = fresh(); for (const c of S1.COMMS) zero.comms[c].pop = 0;
  useCase('zero-population', zero);
  const small = fresh(); for (const c of S1.COMMS) small.comms[c].pop = 0;
  small.comms.tail.pop = 15; small.sup = suppliesNeed(small) * 3;
  useCase('need-0.3-epsilon', small);
}
for (const law of [null, 'common_kitchen', 'contribution_ration'] as const) {
  const g = fresh(); g.sup = 1.5; if (law) g.passed[law] = 0;
  useCase(`law/${law ?? 'none'}`, g);
}
{
  const g = fresh(); g.passed.contribution_ration = 0; g.sup = 1.5; g.comms.tail.away = 79;
  useCase('contribution/away-79', g);
  const half = fresh(); half.passed.contribution_ration = 0; half.sup = 0.7;
  for (const c of S1.COMMS) half.comms[c].pop = 0;
  half.comms.tail.pop = 30; half.comms.tail.away = 29; half.comms.medtech.pop = 10;
  useCase('contribution/exact-half', half);
  const tie = fresh(); tie.passed.contribution_ration = 0;
  // Integer populations survive Godot JSON parsing without a last-bit near tie.
  // 188496 is a common working-age count whose five products are exactly equal.
  const tieHands = 188496;
  for (const c of S1.COMMS) {
    const people = S1.PROFILES.filter(p => p.community === c);
    const working = people.filter(p => p.age >= 16 && p.age <= 65).length;
    const pop = tieHands * people.length / working;
    assert.ok(Number.isSafeInteger(pop));
    Object.assign(tie.comms[c], { pop, rel: 0, heat: 2, ration: 2, away: 79 });
  }
  assert.ok(S1.COMMS.every(c => tie.comms[c].pop * workShare(c) === tieHands));
  tie.sup = (tie.comms.tail.pop + tie.comms.medtech.pop / 2) / 100 * S1.P.supPer100;
  useCase('contribution/tie-comms-order', tie);
}
for (const method of ['bump', 'parts', 'put', 'add'] as const) {
  const g = fresh(); delete g.sup;
  const before = plain(g);
  if (method === 'bump') { bump(g, 'sup', 1.5, 'sup.search'); bump(g, 'sup', -9, 'sup.use'); }
  if (method === 'parts') { bumpParts(g, 'sup', 1.5, [['stop.loot', 1], ['sup.search', 2]]); bumpParts(g, 'sup', -9, [['sup.use', 1]]); }
  if (method === 'put') { put(g, 'sup', 1.5, 'sup.search'); put(g, 'sup', -9, 'sup.use'); }
  if (method === 'add') { addSupplies(g, 1.5, 'field.loot'); addSupplies(g, -9, 'field.loot'); }
  groups.ledger.push({ name: method, method, before, after: plain(g) });
}

function atStop(place: string, stay: StayId, on = true): Game {
  const g = fresh(on); if (on) g.sup = 0;
  g.phase = 'stop';
  g.stop = { place, target: 'food', stay, crewComm: 'tail', crewSize: 4, threat: 0.8, weather: 'snow', done: false, result: null };
  return g;
}
for (const place of Object.keys(SUP_YIELD)) {
  for (const stay of Object.keys(S1.STAY) as StayId[]) for (const cut of [false, true]) {
    const g = atStop(place, stay); if (cut) g.passed.emergency_ration = 0;
    mutate('stops', `${place}/${stay}/cut=${cut}`, g, board => S1.resolveStop(board, true));
  }
  for (const mode of ['pass', 'empty', 'off', 'no-target'] as const) {
    const g = atStop(place, 'normal', mode !== 'off');
    if (mode === 'empty') { g.stop!.crewSize = 0; g.comms.tail.pop = 0; }
    if (mode === 'no-target') g.stop!.target = null;
    const before = plain(g), go = mode !== 'pass'; S1.resolveStop(g, go);
    groups.stops.push({ name: `${place}/${mode}`, before, go, after: plain(g) });
  }
}

const departure = (): FieldDeparture => ({ version: 1, departureId: 'dep_sup', stopId: 'stop_sup', placeId: 'place_sup', segment: 1, roster: [], promises: [], domestic: false });
const receipt = (supplies: number) => ({
  version: 4, receiptId: 'ret_sup', stopId: 'stop_sup', departureId: 'dep_sup', source: 'direct', endReason: 'departed',
  place: { id: 'place_sup', type: 'factory', variant: 'variant_a' }, time: { arrive: 'D1 10:00', depart: 'D1 10:30', stayGameMinutes: 30 },
  stock: { supplies }, items: { gained: [], lost: [] },
  people: { sent: [], injured: [], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [] },
  witnessed: [], placeState: { looted: 0, remainingRisk: 1 }, promises: [], goal: { kind: null, required: 0, earned: 0, status: 'retreat' },
  extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 }, symbol: null, fieldPromises: [],
});
function fieldCase(name: string, g: Game, input: unknown) {
  const before = plain(g), dep = departure(); let status = '', record: unknown = null, error = '';
  try { const out = applyFieldReturn(g, dep, input); status = out.status; record = out.record; }
  catch (e) { status = 'rejected'; error = (e as Error).message; assert.deepEqual(g, before, name); }
  groups.fields.push({ name, before, departure: dep, input: plain(input), status, record: plain(record), error, after: plain(g) });
}
for (const on of [false, true]) for (const delta of [3, -10]) fieldCase(`signed/${on}/${delta}`, fresh(on), receipt(delta));
{
  const g = fresh(); const r = receipt(3); fieldCase('first', g, r);
  fieldCase('duplicate', plain(g), r);
  fieldCase('same-id-other-content', plain(g), receipt(4));
  fieldCase('other-id-same-stop-plus3', plain(g), { ...r, receiptId: 'ret_other' });
  fieldCase('fraction-rejected', fresh(), receipt(0.5));
  fieldCase('typo-rejected', fresh(), { ...r, stock: { supply: 3 } });
}
for (const on of [false, true]) {
  const g = atStop('houses', 'normal', on), opts = { placeId: 'place_sup' };
  const before = plain(g), value = buildDeparture(g, opts);
  groups.departures.push({ name: `departure/${on}`, before, opts, value: plain(value) });
}

function cardView(g: Game, card: Card) {
  const v = S1.viewCard(g, card);
  const tuple = (e: (typeof v.choices)[number]['effs'][number]): unknown[] => {
    if (e.t === 'base') return [e.t, e.c, e.i, e.v];
    if (e.t === 'lever') return [e.t, e.c, e.which, e.v];
    if (e.t === 'debt' || e.t === 'grudge') return [e.t, e.c];
    if ('c' in e && 'v' in e) return [e.t, e.c, e.v];
    return [e.t, 'v' in e ? e.v : null];
  };
  return { title: v.title, body: v.body, required: v.required, speaker: v.speaker ?? null, focus: v.focus ?? null, key: v.key ?? null,
    choices: v.choices.map(ch => ({ id: ch.id ?? '', label: ch.label, say: ch.say ?? '', log: ch.log, disabled: ch.disabled ?? '',
      special: ch.special ?? '', effs: ch.effs.map(tuple), costs: S1.costLines(ch), politics: S1.politicsLines(ch) })) };
}
for (const c of S1.COMMS) for (const again of [false, true]) for (const on of [false, true]) for (const fine of [0, 1]) {
  const g = fresh(on); g.supFine = fine;
  if (again) g.eventLog = { [`favor:${c}`]: { n: 1, seg: 0, pick: 'grant' } };
  S1.addCard(g, { kind: 'favor', comm: c }); const card = g.cards.at(-1)!;
  const before = plain(g), view = cardView(g, card);
  const choices = view.choices.map((_, index) => { const next = plain(g); const ok = S1.chooseCard(next, card.uid, index); return { index, ok, after: plain(next) }; });
  groups.cards.push({ name: `favor/${c}/again=${again}/on=${on}/fine=${fine}`, before, card: plain(card), view, choices });
}
for (const c of ['tail', 'medtech'] as Comm[]) {
  const g = fresh(); g.sup = 0; S1.addCard(g, { kind: 'favor', comm: c }); const card = g.cards.at(-1)!;
  groups.cards.push({ name: `favor/short/${c}`, before: plain(g), card: plain(card), view: cardView(g, card), choices: [] });
}
for (const c of S1.COMMS) for (const on of [false, true]) for (const fine of [0, 1]) {
  const g = fresh(on); g.supFine = fine;
  const rounds = Array.from({ length: 12 }, (_, session) => { g.session = session; return { session, value: plain(S1.openConditions(g, c)) }; });
  groups.conditions.push({ name: `${c}/${on}/${fine}`, before: plain(g), comm: c, rounds });
}
function forSettle(stock: number): Game {
  const g = fresh(); g.seg = 2; g.phase = 'council'; g.cards = []; g.sup = stock;
  g.coal = g.food = g.med = 10000;
  for (const c of S1.COMMS) Object.assign(g.comms[c], { base: [60, 60, 40, 30], rel: 0, demandCool: 0, favorCool: 99, agitateCool: 99 });
  g.comms.tail.base = [0, 0, 40, 30]; return g;
}
for (const stock of [0, 8, 12, 11.999]) mutate('settles', `demand/${stock}`, forSettle(stock), S1.advance);
for (const c of ['tail', 'front'] as Comm[]) for (const enough of [false, true]) for (const on of [false, true]) {
  const g = forSettle(100); g.supOn = on; g.seg = 3;
  const cond = S1.CONDITIONS[c].find(x => x.sup)!;
  const amount = cond.amount!, stock = enough ? amount : amount - 0.5;
  if (c === 'tail') g.sup = suppliesNeed(g) + stock; else g.supFine = stock;
  g.comms[c].promise = { kind: 'open', cond, label: cond.label, due: g.seg, madeSession: 0 };
  mutate('settles', `promise/${c}/${enough}/${on}`, g, S1.advance);
}

type Action = { kind: 'advance' | 'resolve_stop' | 'choose_card' | 'cast_vote'; uid?: number; index?: number; go?: boolean };
function play(flag: boolean | undefined) {
  const g = fresh(false); if (flag === true) enableSupplies(g); else if (flag === false) g.supOn = false;
  const initial = plain(g), steps = []; let settles = 0;
  for (let step = 0; step < 90 && g.phase !== 'end' && settles < 4; step++) {
    let action: Action;
    if (g.cards.length) {
      const card = g.cards[0], index = S1.viewCard(g, card).choices.findIndex(ch => !ch.disabled);
      action = { kind: 'choose_card', uid: card.uid, index }; assert.ok(index >= 0 && S1.chooseCard(g, card.uid, index));
    } else if (g.phase === 'stop' && g.stop && !g.stop.done) { action = { kind: 'resolve_stop', go: true }; S1.resolveStop(g, true); }
    else if (g.phase === 'council' && g.council && !g.council.result && S1.currentAgenda(g) && S1.castVote(g)) action = { kind: 'cast_vote' };
    else { action = { kind: 'advance' }; assert.ok(S1.primaryAction(g).ok); S1.advance(g); if (g.phase === 'settle') settles++; }
    assert.ok(!g.dom); steps.push({ action, after: plain(g) });
  }
  assert.equal(settles, 4); return { name: `run/${String(flag)}`, flag: flag ?? null, initial, steps, settles };
}
const runs = [play(undefined), play(false), play(true)];
const withoutFlag = (g: Game) => { const out = plain(g); delete out.supOn; return out; };
assert.deepEqual(runs[0].steps.map(x => withoutFlag(x.after)), runs[1].steps.map(x => withoutFlag(x.after)));
const gaugeBoard = fresh(); gaugeBoard.climate = true;
const data = { format: 'supplies-vectors-v1', tables: tables(), yield: SUP_YIELD, groups, runs,
  gauges: { board: gaugeBoard, forecast: S1.forecast(gaugeBoard) } };
const output = resolve(import.meta.dirname, '../../s2/tests/fixtures/train/supplies_vectors.json');
const bytes = Buffer.from(JSON.stringify(data) + '\n');
if (bytes.length > 30 * 1024 * 1024) throw new Error('supplies fixture exceeds 30 MiB');
mkdirSync(dirname(output), { recursive: true });
let identical = false; try { identical = readFileSync(output).equals(bytes); } catch { /* first generation */ }
if (!identical) writeFileSync(output, bytes);
console.log(JSON.stringify({ output, bytes: bytes.length, identical, cases: Object.fromEntries(Object.entries(groups).map(([k, rows]) => [k, rows.length])), runs: runs.map(r => ({ name: r.name, steps: r.steps.length, settles: r.settles })) }));
