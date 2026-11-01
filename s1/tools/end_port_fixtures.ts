// S1 alone computes the answers. Gameplay keeps the dark path disabled.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Game } from '../src/game';
import { checkEnd } from '../src/game/turn';
import { END_LINK } from '../src/game/state';
import { cross, closeChronicle, darkEnd, logPick, wallLine } from '../src/game/dark/chronicle';
import type { H7Pick } from '../src/game/dark/chronicle';
import { logCardPick } from '../src/game/dark/h7';
import { MEANS } from '../src/game/dark/data';
import { playGame } from './s1c_bot';

const ROOT = resolve(import.meta.dirname, '../..');
const OUTPUT = resolve(ROOT, 's2/tests/fixtures/train/end_vectors.json');
const source = JSON.parse(readFileSync(resolve(ROOT, 's2/game/train/slice_start.json'), 'utf8')) as { state: Game };
const plain = <T>(x: T): T => JSON.parse(JSON.stringify(x)) as T;
const STAT_KEYS = ['signs', 'imminent', 'violent', 'violentDeaths', 'cases', 'solved', 'misjudged', 'trials', 'scapegoats', 'lynches', 'orders', 'revealed', 'risen', 'cardsDeferred'];
function fresh(seed: string): Game {
  const g = plain(source.state);
  g.seed = seed;
  g.rng = plain(S1.createGame(seed).rng);
  g.cards = [];
  g.loco = 'c3';
  assert(!g.dark);
  return g;
}
// This detached input only exercises chronicle functions; no dark gameplay runs.
function oracle(g: Game): Game {
  const out = plain(g);
  out.dark = {
    means: {}, crossed: [], nightmareUntil: -1, nightmareCards: 0, numb: false,
    h7: [], stats: Object.fromEntries(STAT_KEYS.map(k => [k, 0])),
    joined: [], scenes: [], closed: false,
  } as unknown as NonNullable<Game['dark']>;
  return out;
}
function answer(g: Game) {
  const d = darkEnd(g);
  const at = g.journal.length;
  closeChronicle(g);
  closeChronicle(g);
  assert.equal(g.journal.length, at + 1);
  return { tone: d.tone, toneLine: d.toneLine, means: d.means, layer: d.layer,
    h7: d.h7, wall: d.wall, wallLines: d.wall.map(wallLine), closeLine: g.journal.at(-1)!.text };
}
type Action = { kind: string; uid?: number; index?: number };
const cases: { id: string; action: Action; before: Game; after: Game; lookback: string[]; reason: string; panelLines: string[] }[] = [];
function record(id: string, before: Game, after: Game, action: Action) {
  assert.equal(after.phase, 'end', id);
  assert(!after.dark, id + ': dark gameplay stays off');
  assert.equal(after.loco ?? S1.LOCO_DEFAULT, 'c3');
  const reason = after.end === 'revolt' && after.stranded
    ? '솥에 넣을 것이 없었다. 열차장은 끌려 내려왔다.'
    : [...after.journal].reverse().find(x => x.text === ({
      ousted: '의회가 열차장을 끌어내렸다. 아무도 소리치지 않았다. 사람들이 길을 비켜 섰다.',
      revolt: '반란이 일어났다. 식당칸 탁자가 엎어지고 고함이 칸을 넘어왔다.',
      lost_captain: '열차장은 돌아오지 않았다. 선로 끝에 수동차 자국만 남았다.',
    } as Record<string, string>)[after.end!])?.text ?? '';
  assert(!after.journal.some(x => x.text.startsWith('기록: 징후')), id + ': no dark closing line');
  const lookback = S1.lookbackLines(after);
  cases.push({ id, action, before: plain(before), after: plain(after), lookback,
    reason, panelLines: [reason, ...lookback.slice(0, 1)] });
}
for (const [i, kind] of ['ousted', 'revolt', 'stopped-revolt'].entries()) {
  const g = fresh('end-check-' + i);
  g.phase = 'settle'; g.seg = 4; g.trust = 60; g.food = 20; g.coal = 10;
  if (kind === 'ousted') { g.trust = 10; g.trustCrisis = g.seg; }
  else { g.tension = 100; g.tensionCrisisUsed = 2; g.tensionWarned = true; }
  if (kind === 'stopped-revolt') S1.enterStranded(g, 5, 10);
  const before = plain(g);
  checkEnd(g);
  record(kind, before, g, { kind: 'check_end' });
}
let foundLost = false;
for (let seed = 0; seed < 200 && !foundLost; seed++) {
  const g = fresh('end-captain-' + seed);
  g.food = 200;
  for (const c of S1.COMMS) g.comms[c].rel = 30;
  S1.enterStranded(g, 5, 10);
  assert(S1.startTrip(g, 'captain'));
  for (let tick = 0; tick < 64 && g.phase !== 'end'; tick++) {
    const before = plain(g);
    S1.tripTick(g);
    if (g.end === 'lost_captain') {
      record('captain-lost-' + seed, before, g, { kind: 'trip_tick' });
      foundLost = true;
      break;
    }
    if (!g.stranded?.trip) break;
  }
}
assert(foundLost, 'a seeded captain trip must reach its lost ending');
// Full unmodified games complement the isolated end transitions.
for (let i = 0; i < 3; i++) {
  const { g } = playGame('end-full-' + i, { s1c: false, policy: 'first', dom: 'idle',
    loco: 'c3', late: false, noPrologue: true });
  assert.equal(g.phase, 'end', 'full run reaches an ending');
  record('full-' + i, g, g, { kind: 'ended' });
}
const math: { id: string; input: Game; operations: string[]; expectedState: unknown; expected: ReturnType<typeof answer> }[] = [];
for (const [i, operations] of [
  [], ['exiles'], ['assn_ordered', 'executions'], ['martial', 'exiles', 'blackmail'],
  ['martial', 'martial_lifted', 'martial_lifted', 'martial_lifted'],
  ['harsh_chosen'], Object.keys(MEANS),
].entries()) {
  for (const end of ['complete', 'ousted'] as const) {
    const g = fresh('end-math-' + i);
    g.end = end; g.phase = 'end'; g.seg = 5;
    g.deaths = i === 5 ? Array.from({ length: 7 }, (_, n) => '이름 ' + n) : [];
    g.stats.blackmails = i === 5 ? 9 : 0;
    const input = plain(g);
    const o = oracle(g);
    for (const key of operations) cross(o, key as keyof typeof MEANS);
    const d = o.dark!;
    const expectedState = plain({ means: d.means, crossed: d.crossed, nightmareUntil: d.nightmareUntil,
      nightmareCards: d.nightmareCards, numb: d.numb });
    math.push({ id: i + '-' + end, input, operations, expectedState, expected: answer(o) });
  }
}
const h = oracle(fresh('end-h7'));
const picks: Omit<H7Pick, 'seg'>[] = [
  { kind: 'plain', chars: 100, ms: 1000, choices: 2, crossing: false, picked: false, alt: true },
  { kind: 'plain', chars: 100, ms: 2000, choices: 2, crossing: false, picked: false, alt: true },
  { kind: 'cross', chars: 100, ms: 6000, choices: 2, crossing: true, picked: true, alt: true },
  { kind: 'cross', chars: 100, ms: 4000, choices: 2, crossing: true, picked: false, alt: false },
  { kind: 'different', chars: 300, ms: 12000, choices: 2, crossing: true, picked: true, alt: false },
  { kind: 'choices', chars: 100, ms: 12000, choices: 3, crossing: true, picked: true, alt: true },
];
for (const p of picks) logPick(h, p);
const cardInput = fresh('end-h7-card');
S1.addCard(cardInput, { kind: 'demand', comm: 'tail' });
const uid = cardInput.cards[0].uid;
const index = S1.viewCard(cardInput, cardInput.cards[0]).choices.findIndex(c => !c.disabled);
assert(index >= 0);
const cardOracle = oracle(cardInput);
logCardPick(cardOracle, uid, index, 1200.5);
assert.equal(cardOracle.dark!.h7.length, 1);
const roundValues = [0, 0.005, 1.005, 1.125, 2.675, 2.685, 0.00001, 1234.56789];
// Isolated rule hooks verify journal order without enabling dark gameplay.
const ruleHooks = ['finish', 'write_lookback'].map(kind => {
  const g = oracle(fresh('end-hook-' + kind));
  g.seg = 4; g.coal = 10; g.food = 20;
  g.raised = { '기록 시험 이름': 'tail' };
  if (kind === 'write_lookback') { g.end = 'revolt'; g.phase = 'end'; }
  const input = plain(g);
  if (kind === 'finish') END_LINK.finish(g, 'ousted');
  else { S1.writeLookback(g); closeChronicle(g); }
  return { kind, input, end: g.end, journal: plain(g.journal), h7: darkEnd(g).h7, toneLine: darkEnd(g).toneLine };
});
const coverage = new Set(cases.map(c => c.after.end));
for (const end of ['ousted', 'revolt', 'lost_captain']) assert(coverage.has(end as Game['end']));
assert(cases.some(c => c.after.stranded && c.after.end === 'revolt'));
const wallInput = plain(cases.find(c => c.after.end === 'lost_captain')!.after);
const output = { format: 'end-vectors-v2', darkGameplay: false, loco: 'c3', cases, math, ruleHooks,
	wall: { input: wallInput, expected: answer(oracle(wallInput)) },
  h7: { input: fresh('end-h7'), picks, expected: answer(h) },
  card: { input: cardInput, uid, index, ms: 1200.5, expected: cardOracle.dark!.h7 },
  rounding: roundValues.map(value => ({ value, expected: +value.toFixed(2) })) };
writeFileSync(OUTPUT, JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ output: OUTPUT, cases: cases.length, ends: [...coverage], math: math.length }));

