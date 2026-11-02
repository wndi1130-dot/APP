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
import { registerContentDeals } from '../src/game/content';
import type { ContentDeal } from '../src/game/content';
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
  const wasClosed = g.dark!.closed;
  closeChronicle(g);
  closeChronicle(g);
  assert.equal(g.journal.length, at + (wasClosed ? 0 : 1));
  return { tone: d.tone, toneLine: d.toneLine, means: d.means, layer: d.layer,
    h7: d.h7, wall: d.wall, wallLines: d.wall.map(wallLine), closeLine: g.journal.at(-1)!.text };
}
type Action = { kind: string; uid?: number; index?: number };
const cases: { id: string; action: Action; before: Game; after: Game; lookback: string[]; reason: string; panelLines: string[] }[] = [];
// The S2 end panel names an ending with finish()'s own sentence. A card-picked revolt ends
// without writing it, so ask finish() on a copy of the ended game instead of searching the journal.
function finishLine(id: string, after: Game): string {
  const probe = plain(after);
  probe.phase = 'settle';
  const at = probe.journal.length;
  END_LINK.finish(probe, after.end!);
  const line = probe.journal[at];
  assert.equal(line?.tone, after.end === 'complete' ? 'good' : 'bad', id + ': finish line tone');
  assert(line.text.length > 0, id + ': empty finish line');
  return line.text;
}
function record(id: string, before: Game, after: Game, action: Action) {
  assert.equal(after.phase, 'end', id);
  assert(!after.dark, id + ': dark gameplay stays off');
  assert.equal(after.loco ?? S1.LOCO_DEFAULT, 'c3');
  assert(!after.journal.some(x => x.text.startsWith('기록: 징후')), id + ': no dark closing line');
  const lookback = S1.lookbackLines(after);
  assert(lookback.length > 0, id + ': finish must write a lookback');
  let at = -1;
  for (let i = after.journal.length - 1; i >= 0; i--) {
    if (after.journal[i].tone === 'dark'
      && lookback.every((line, n) => after.journal[i + n]?.text === line)) { at = i; break; }
  }
  assert(at > 0, id + ': missing lookback in the journal');
  const reason = finishLine(id, after);
  // An ending reached through finish() wrote the same sentence just before its lookback.
  const ending = after.journal[at - 1];
  const viaFinish = ending.text === reason && ending.seg === after.seg;
  assert(viaFinish || action.kind === 'ended', id + ': finish journal before lookback');
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
    const input = oracle(g);
    const o = plain(input);
    for (const key of operations) cross(o, key as keyof typeof MEANS);
    const d = o.dark!;
    const expectedState = plain(d);
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
function cardSample(id: string, input: Game) {
  const card = input.cards[0];
  const view = S1.viewCard(input, card);
  const index = view.choices.findIndex(c => !c.disabled);
  assert(index >= 0, id + ': an open choice');
  const g = plain(input);
  logCardPick(g, card.uid, index, 1200.5);
  assert.equal(g.dark!.h7.length, 1);
  return { id, input, uid: card.uid, index, ms: 1200.5, expected: plain(g.dark!.h7) };
}
const cardInput = oracle(fresh('end-h7-card'));
S1.addCard(cardInput, { kind: 'demand', comm: 'tail' });
const cards = [cardSample('demand', cardInput)];
// Use the repository's valid S1 deal input even when optional data/deals is absent.
const deals = [JSON.parse(readFileSync(resolve(ROOT, 's1/fixtures/valid/deal.json'), 'utf8')) as ContentDeal];
registerContentDeals(deals);
const dealInput = oracle(fresh('end-h7-deal'));
S1.addCard(dealInput, { kind: 'content-deal', text: deals[0].id, comm: 'tail' });
const dealView = S1.viewCard(dealInput, dealInput.cards[0]);
assert.equal(dealView.choices.length, 2);
assert(dealView.choices.every(c => !c.disabled && c.say === undefined));
cards.push(cardSample('deal-open', dealInput));
const blockedInput = oracle(fresh('end-h7-blocked'));
blockedInput.food = 0; blockedInput.coal = 0;
S1.addCard(blockedInput, { kind: 'tension_crisis', comm: 'tail' });
assert(S1.viewCard(blockedInput, blockedInput.cards[0]).choices.some(c => c.disabled));
cards.push(cardSample('blocked-choice', blockedInput));
for (const row of cards) {
  for (const dark of [undefined, false]) {
    const g = plain(row.input);
    delete g.dark;
    if (dark === false) Object.assign(g, { dark });
    const before = plain(g);
    logCardPick(g, row.uid, row.index, row.ms);
    logPick(g, picks[0]);
    assert.deepEqual(g, before, row.id + ': disabled H7 does not mutate any field');
  }
}
const restoredInput = oracle(fresh('end-restored'));
restoredInput.end = 'complete'; restoredInput.phase = 'end'; restoredInput.seg = 5;
cross(restoredInput, 'exiles');
const restoredExpected = answer(plain(restoredInput));
assert.equal(restoredExpected.tone, 'shade');
const closedInput = plain(restoredInput);
closeChronicle(closedInput);
const closedBefore = plain(closedInput);
closeChronicle(closedInput);
assert.deepEqual(closedInput, closedBefore, 'already closed S1 state stays unchanged');
const restored = [
  { id: 's1-shade', input: restoredInput, expected: restoredExpected },
  { id: 's1-closed', input: closedInput, expected: answer(plain(closedInput)) },
];
const roundValues = [0, 0.005, 1.005, 1.125, 2.675, 2.685, 0.00001, 1234.56789];
// Isolated rule hooks verify journal order without enabling dark gameplay.
const ruleHooks = ['finish', 'write_lookback', 'choose_card', 'choose_card_off'].map(kind => {
  const g = kind === 'choose_card_off' ? fresh('end-hook-' + kind) : oracle(fresh('end-hook-' + kind));
  g.seg = 4; g.coal = 10; g.food = 20;
  g.raised = { '기록 시험 이름': 'tail' };
  let uid = -1; let index = -1;
  if (kind.startsWith('choose_card')) {
    S1.addCard(g, { kind: 'tension_crisis', comm: 'tail' });
    uid = g.cards[0].uid;
    index = S1.viewCard(g, g.cards[0]).choices.findIndex(c => c.special === 'revolt');
    assert(index >= 0, 'real revolt choice');
  }
  if (kind === 'write_lookback') { g.end = 'revolt'; g.phase = 'end'; }
  const input = plain(g);
  if (kind === 'finish') END_LINK.finish(g, 'ousted');
  else if (kind === 'write_lookback') S1.writeLookback(g);
  else assert(S1.chooseCard(g, uid, index), 'real chooseCard succeeds');
  assert.equal(g.dark?.closed ?? false, kind === 'finish' || kind === 'choose_card');
  return { kind, input, uid, index, end: g.end, journal: plain(g.journal), dark: plain(g.dark ?? null),
    toneLine: g.dark ? darkEnd(g).toneLine : '' };
});
const coverage = new Set(cases.map(c => c.after.end));
for (const end of ['ousted', 'revolt', 'lost_captain']) assert(coverage.has(end as Game['end']));
assert(cases.some(c => c.after.stranded && c.after.end === 'revolt'));
const wallInput = plain(cases.find(c => c.after.end === 'lost_captain')!.after);
const output = { format: 'end-vectors-v3', darkGameplay: false, loco: 'c3', cases, math, ruleHooks,
	wall: { input: oracle(wallInput), expected: answer(oracle(wallInput)) },
  h7: { input: oracle(fresh('end-h7')), picks, expected: answer(h) },
  cards, restored, deals,
  rounding: roundValues.map(value => ({ value, expected: +value.toFixed(2) })) };
writeFileSync(OUTPUT, JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ output: OUTPUT, cases: cases.length, ends: [...coverage], math: math.length, cards: cards.length, restored: restored.length, ruleHooks: ruleHooks.length }));

