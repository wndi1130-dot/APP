// S1a 한 바퀴의 전체 JSON 전/후. 규칙은 S1에서 직접 실행한다.
// --climate: 같은 씨앗을 바깥 기온 켠 판(enableClimate, 결빙 켬 CL.freezeOn 1)으로 돌려 turn_vectors_climate.json에 쓴다
// (S2 기온·선로 결빙 이식 train_climate.gd의 맞대기). 서막 30걸음 안에는 결빙이 안 서서, 결빙이 서는 17구간 출발부터
// 풀릴 때까지를 판 하나(turn-climate-freeze)로 더 돌린다.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import { FIELD } from '../src/game/field_receipt';
import type { Game } from '../src/game';
import { onDeath } from '../src/game/death';
import type { DeathCause } from '../src/game/death';
import type { Comm } from '../src/game/data';
import { addWound, woundTick } from '../src/game/wounds';
import { lateNextSeg } from '../src/game/late';
import { readSave } from '../src/ui/repro';

const SEEDS = ['slice-seed-a', 'train-0', 'train-1', 'train-2'];
const MAX_STEPS = 30;
const LIMIT = 30 * 1024 * 1024;
const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
type Action = { kind: 'advance' | 'resolve_stop' | 'choose_card' | 'cast_vote'; uid?: number; index?: number; go?: boolean };

export function tables(): Record<string, unknown> {
  // 상수의 선언 순서와 배열 순서를 보존한다. 함수인 사건 조건/효과는 JSON 표가 아니다.
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(S1)) {
    if (/^[A-Z][A-Z0-9_]*$/.test(key) && typeof value !== 'function' && !key.endsWith('_HOOKS') && !key.endsWith('_LINK')) out[key] = value;
  }
  out.FIELD = FIELD;
  out.LAWS_RES = Object.fromEntries(Object.entries(S1.LAWS).map(([id, law]) => [id, law.res]));
  out.LOCO_COAL = Object.fromEntries(Object.entries(S1.LOCO).map(([id, loco]) => [id, loco.coal]));
  out.DELEGATE = { after: S1.DELEGATE_AFTER, on: S1.DELEGATE_ON, reOn: S1.DELEGATE_RE_ON };
  return plain(out);
}

/** setup은 기온을 켠 뒤 판을 고친다. until이 참이 되는 걸음에서 멈춘다(그 걸음까지 적는다). */
function play(seed: string, limit: number, climate = false, setup?: (g: Game) => void, until?: (before: Game, after: Game) => boolean) {
  const g = S1.createGame(seed);
  if (climate) S1.enableClimate(g);
  setup?.(g);
  const steps = [];
  for (let step = 0; step < limit && g.phase !== 'end'; step += 1) {
    const before = plain(g);
    const agenda = plain(S1.agendaOptions(g));
    let action: Action;
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const index = S1.viewCard(g, card).choices.findIndex(c => !c.disabled);
      if (index < 0) throw new Error(`선택 불가: ${seed}/${step}/${card.kind}`);
      action = { kind: 'choose_card', uid: card.uid, index };
      if (!S1.chooseCard(g, card.uid, index)) throw new Error(`선택 실패: ${seed}/${step}`);
    } else if (g.phase === 'stop' && g.stop && !g.stop.done) {
      action = { kind: 'resolve_stop', go: true };
      S1.resolveStop(g, true);
    } else if (g.phase === 'council' && g.council && !g.council.result && S1.currentAgenda(g)) {
      const voted = S1.castVote(g);
      action = { kind: voted ? 'cast_vote' : 'advance' };
      if (!voted) S1.advance(g);
    } else {
      if (!S1.primaryAction(g).ok) throw new Error(`진행 불가: ${seed}/${step}/${g.phase}`);
      action = { kind: 'advance' };
      S1.advance(g);
    }
    if (g.dom || g.dark) throw new Error('S1a 밖의 표본');
    steps.push({ seed, step, action, before, after: plain(g), agenda });
    if (until?.(before, g)) break;
  }
  return { seed, steps, finalPhase: g.phase, ended: g.phase === 'end' };
}

type PartAction = Action | { kind: 'death'; comm: Comm; names: string[]; cause: DeathCause; witness: boolean; quiet: boolean }
  | { kind: 'wound_tick'; medMult: number } | { kind: 'late_next' | 'read_save' | 'repeal_ration' | 'draw_event' | 'budget_pass' | 'budget_next' }
  | { kind: 'add_card'; card: Omit<S1.Card, 'uid'> };

function partVectors(runs: ReturnType<typeof play>[]) {
  const parts: { name: string; action: PartAction; before: Game; after: Game; notes?: string[] }[] = [];
  const add = (name: string, g: Game, action: PartAction, run: () => void, notes?: string[]) => {
    const before = plain(g);
    run();
    parts.push({ name, action, before, after: plain(g), ...(notes ? { notes } : {}) });
  };
  const seen = new Set<string>();
  for (const row of runs.flatMap(r => r.steps)) {
    if (row.action.kind !== 'choose_card') continue;
    const card = row.before.cards.find(c => c.uid === row.action.uid)!;
    const key = `${card.kind}:${card.comm ?? ''}:${card.text ?? ''}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const probe = plain(row.before);
    const choices = S1.viewCard(probe, probe.cards.find(c => c.uid === card.uid)!).choices;
    for (let index = 0; index < choices.length; index += 1) {
      const g = plain(row.before);
      add(`card/${key}/${index}`, g, { kind: 'choose_card', uid: card.uid, index }, () => { S1.chooseCard(g, card.uid, index); });
    }
    const invalid = plain(row.before);
    add(`card/${key}/invalid`, invalid, { kind: 'choose_card', uid: card.uid, index: -1 }, () => { S1.chooseCard(invalid, card.uid, -1); });
  }
  const parentGame = S1.createGame('turn-parts-death');
  const parent = S1.FAMILIES.flatMap(f => f.parents).map(id => S1.PROFILES.find(p => p.id === id)!)
    .find(p => p && S1.familyOf(parentGame, p.name)?.kids.length && !S1.COMMS.some(c => parentGame.comms[c].leader.name === p.name));
  if (!parent) throw new Error('F-INPUT-MISSING: family death fixture');
  for (const law of [null, 'corpse_throw', 'corpse_store', 'corpse_burn'] as const) {
    const g = plain(parentGame);
    if (law) g.passed[law] = 0;
    if (law === 'corpse_burn') g.stored = 6;
    addWound(g, { who: parent.name, comm: parent.community, grade: 'deep', part: 'armL', septic: false, from: 'stop', where: '표본' });
    const action: PartAction = { kind: 'death', comm: parent.community, names: [parent.name], cause: 'warned', witness: true, quiet: law === 'corpse_store' };
    add(`death/${law ?? 'no-law'}`, g, action, () => onDeath(g, action.comm, action.names, action.cause, action.witness, action.quiet));
  }
  for (const med of [0, 20]) {
    const g = S1.createGame(`turn-parts-wounds-${med}`);
    const adults = S1.PROFILES.filter(p => p.age >= 16 && p.age <= 65 && !S1.COMMS.some(c => g.comms[c].leader.name === p.name)).slice(0, 7);
    adults.forEach((p, i) => addWound(g, { who: p.name, comm: p.community, from: 'stop', where: '표본', grade: i === 0 ? 'amputation' : i % 2 ? 'fracture' : 'deep', part: 'armL', septic: i % 2 === 0 }));
    g.seg = 3;
    g.med = med;
    const notes: string[] = [];
    add(`wounds/med-${med}`, g, { kind: 'wound_tick', medMult: 1 }, () => woundTick(g, notes, 1), notes);
  }
  for (const mode of ['child', 'heat', 'need-hit', 'calm', 'bribe', 'hub'] as const) {
    const g = S1.createGame(`turn-parts-settle-${mode}`);
    g.phase = 'council';
    g.council = { options: [], idx: 0, locked: false, deals: [], result: null };
    if (mode === 'child') { g.passed.child_labor = 0; g.passed.edu_letters = 0; }
    if (mode === 'heat') { g.passed.heat_quota = 0; for (const c of S1.COMMS) g.comms[c].base[0] = 0; }
    if (mode === 'need-hit') { g.seg = 7; g.coal = 40; g.food = 40; g.needs = { coal: { since: 1, due: 2, hits: 1 }, food: { since: 1, due: 2, hits: 2 } }; }
    if (mode === 'calm') { g.passed.evening_pot = 0; g.passed.wall_ledger = 0; g.passed.night_of_names = 0; g.deathLog = [{ seg: 1, name: parent.name, cause: 'chosen', comm: parent.community }]; }
    if (mode === 'bribe') g.council.deals = [{ comm: 'tail', tool: 'bribe', label: '표본' }, { comm: 'front', tool: 'favor', label: '표본' }];
    if (mode === 'hub') { g.seg = S1.P.segments - 1; g.hub = { warned: ['tail'], stash: {}, agreed: [] }; g.comms.tail.rel = -80; }
    add(`settle/${mode}`, g, { kind: 'advance' }, () => { S1.advance(g); });
  }
  const stopRow = runs.flatMap(r => r.steps).find(s => s.action.kind === 'resolve_stop')!;
  for (const mode of ['death', 'child'] as const) {
    const g = plain(stopRow.before);
    if (mode === 'death') { g.stop!.threat = 10; g.stop!.scout = true; }
    else { g.passed.child_labor = 0; g.passed.edu_letters = 0; }
    add(`stop/${mode}`, g, { kind: 'resolve_stop', go: true }, () => { S1.resolveStop(g, true); });
  }
  // 결정 514: 기존 입력 뒤에 미룸, 실제 복귀, 다시 미룸, 기한 초과를 같은 상태로 잇는다.
  const templates: Omit<S1.Card, 'uid'>[] = S1.COMMS.flatMap(comm => [
    { kind: 'demand', comm }, { kind: 'favor', comm }, { kind: 'promise_ledger', comm },
  ]);
  templates.push({ kind: 'ration_cut' }, { kind: 'travel', text: 'front_curtain' });
  // 돌아온 카드를 미루지 않고 답하는 길(커진 효과, 부탁의 누설 난수)은 복귀 직후 상태를 갈라 두었다가 미루기 표본 맨 뒤에 붙인다.
  const answers: { name: string; g: Game; uid: number; index: number }[] = [];
  for (const patch of templates) {
    const g = S1.createGame(`turn-late-${patch.kind}-${patch.comm ?? 'tail'}`);
    S1.enableLate(g); g.phase = 'settle'; g.seg = 3; g.passed.emergency_ration = 1;
    for (const c of S1.COMMS) { g.comms[c].heat = 0; g.comms[c].ration = 0; }
    const card: S1.Card = { uid: g.nextCardUid++, ...patch };
    g.cards = [card];
    const tag = `late/${patch.kind}/${patch.comm ?? 'tail'}`;
    for (let n = 0; n <= 2; n++) {
      const index = S1.viewCard(g, g.cards[0]).choices.findIndex(c => c.id === 'later');
      add(`${tag}/defer-${n + 1}`, g, { kind: 'choose_card', uid: card.uid, index }, () => { S1.chooseCard(g, card.uid, index); });
      if (n < 2) {
        g.phase = 'settle';
        add(`${tag}/return-${n + 1}`, g, { kind: 'advance' }, () => { S1.advance(g); });
        const back = g.cards.find(c => c.uid === card.uid)!;
        S1.viewCard(g, back).choices.forEach((c, index) => {
          if (c.id !== 'later') answers.push({ name: `${tag}/answer-${n + 1}-${index}`, g: plain(g), uid: card.uid, index });
        });
      }
    }
  }
  for (const kind of ['rescue', 'bitten', 'info']) {
    const g = S1.createGame('turn-late-unsupported'); S1.enableLate(g);
    const card = { uid: g.nextCardUid++, kind, comm: 'tail' as const }; g.cards = [card];
    const index = S1.viewCard(g, card).choices.length;
    add(`late/unsupported/${kind}`, g, { kind: 'choose_card', uid: card.uid, index }, () => { S1.chooseCard(g, card.uid, index); });
  }
  for (const mode of ['old', 'held'] as const) {
    const g = S1.createGame(`turn-late-save-${mode}`);
    if (mode === 'held') {
      S1.enableLate(g);
      g.lateCards = [{ uid: g.nextCardUid++, kind: 'favor', comm: 'front', late: 1, who: g.comms.front.leader.personId }];
      g.cards = [{ uid: g.nextCardUid++, kind: 'promise_ledger', comm: 'tail', late: 2 }];
    }
    add(`late/save/${mode}`, g, { kind: 'read_save' }, () => {
      const read = readSave(plain(g)); if (!read.ok) throw new Error(read.why);
      Object.assign(g, read.g);
    });
  }
  for (const mode of ['gone', 'former', 'law-down', 'answered', 'duplicate', 'order'] as const) {
    const g = S1.createGame(`turn-late-return-${mode}`); S1.enableLate(g);
    g.lateCards = [{ uid: g.nextCardUid++, kind: 'favor', comm: 'front', late: 1, who: g.comms.front.leader.personId }];
    if (mode === 'gone') g.comms.front.pop = 0;
    if (mode === 'former') g.lateCards[0].who = 'former-rep';
    if (mode === 'law-down' || mode === 'answered') g.lateCards[0] = { uid: 1, kind: 'ration_cut', late: 1 };
    if (mode === 'answered') { g.passed.emergency_ration = 1; g.rationCut = { pick: 'refuse', base: {} }; }
    if (mode === 'duplicate') g.cards = plain(g.lateCards);
    if (mode === 'order') {
      g.lateCards.push({ uid: g.nextCardUid++, kind: 'travel', text: 'front_curtain', late: 2 });
      g.cards = [{ uid: g.nextCardUid++, kind: 'info' }];
    }
    add(`late/return/${mode}`, g, { kind: 'late_next' }, () => { lateNextSeg(g); });
  }
  const repeal = S1.createGame('turn-late-repeal'); S1.enableLate(repeal); S1.enactLaw(repeal, 'emergency_ration', []);
  repeal.lateCards = [{ uid: repeal.nextCardUid++, kind: 'ration_cut', late: 1 }, { uid: repeal.nextCardUid++, kind: 'favor', comm: 'front', late: 1 }];
  add('late/repeal', repeal, { kind: 'repeal_ration' }, () => { S1.repealLaw(repeal, 'emergency_ration'); });
  for (let i = 0; i < 12; i++) {
    const g = S1.createGame(`turn-late-dup-${i}`); S1.enableLate(g); g.phase = 'council';
    for (const c of S1.COMMS) { g.comms[c].rel = 30; g.comms[c].demandCool = 0; g.comms[c].favorCool = 0; }
    g.comms.tail.base[0] = -30;
    g.lateCards = [{ uid: 900, kind: 'demand', comm: 'tail', late: 1 }, { uid: 901, kind: 'favor', comm: 'front', late: 1 }];
    add(`late/settle-duplicate/${i}`, g, { kind: 'advance' }, () => { S1.advance(g); });
    const travel = S1.createGame(`turn-late-travel-${i}`); S1.enableLate(travel);
    travel.lateCards = [{ uid: 1, kind: 'travel', text: 'front_curtain', late: 1 }];
    add(`late/travel-duplicate/${i}`, travel, { kind: 'draw_event' }, () => { S1.drawTravelEvent(travel); });
  }
  const budget = S1.createGame('turn-late-budget'); S1.enableLate(budget); S1.enableBudget(budget);
  budget.phase = 'settle'; budget.seg = 3; budget.budget!.seg = 3; budget.budget!.picked = 2;
  budget.cards = [{ uid: 1, kind: 'favor', comm: 'front' }, { uid: 2, kind: 'travel', text: 'front_curtain' }, { uid: 3, kind: 'keepsake', comm: 'tail', who: '한별' }];
  budget.nextCardUid = 4;
  add('late/budget/pick', budget, { kind: 'choose_card', uid: 1, index: 2 }, () => { S1.chooseCard(budget, 1, 2); });
  add('late/budget/return-order', budget, { kind: 'advance' }, () => { S1.advance(budget); });
  budget.budget!.picked = 99;
  add('late/budget/protect-returned', budget, { kind: 'budget_pass' }, () => { S1.budgetPass(budget); });
  const expired = S1.createGame('turn-late-budget-expiry'); S1.enableLate(expired); S1.enableBudget(expired);
  expired.budget!.picked = 3;
  expired.cards = [{ uid: 1, kind: 'favor', comm: 'front', late: 2 }, { uid: 2, kind: 'travel', text: 'front_curtain', pushed: 1 }];
  expired.nextCardUid = 3;
  add('late/budget/expiry', expired, { kind: 'choose_card', uid: 1, index: 2 }, () => { S1.chooseCard(expired, 1, 2); });
  const merge = S1.createGame('turn-late-budget-merge'); S1.enableLate(merge); S1.enableBudget(merge);
  merge.deferred = [{ uid: 1, kind: 'travel', text: 'front_curtain', n: 1, pushed: 1 }]; merge.nextCardUid = 2;
  const replacement = { kind: 'travel', text: 'front_curtain', n: 2 };
  add('late/budget/merge', merge, { kind: 'add_card', card: replacement }, () => { S1.addCard(merge, replacement); });
  const dropped = S1.createGame('turn-late-budget-gone'); S1.enableLate(dropped); S1.enableBudget(dropped);
  dropped.comms.guard.heat = 4; dropped.comms.guard.ration = 4;
  dropped.deferred = [{ uid: 1, kind: 'demand', comm: 'guard', pushed: 1 }];
  dropped.lateCards = [{ uid: 2, kind: 'demand', comm: 'guard', late: 1 }];
  add('late/budget/gone', dropped, { kind: 'budget_next' }, () => { S1.budgetNextSeg(dropped); });
  add('late/budget/gone-player', dropped, { kind: 'late_next' }, () => { lateNextSeg(dropped); });
  for (const a of answers) add(a.name, a.g, { kind: 'choose_card', uid: a.uid, index: a.index }, () => { S1.chooseCard(a.g, a.uid, a.index); });
  return parts;
}

export function turnVectors() {
  const runs = SEEDS.map(seed => play(seed, MAX_STEPS));
  return { format: 'turn-vectors-v1', seeds: SEEDS, maxSteps: MAX_STEPS, tables: tables(), runs, parts: partVectors(runs) };
}

/** 기온 켠 판의 출발 표본: 서막 30걸음 안에는 계절표가 한 번 풀리기만 하므로(3구간 첫 추위 → 늦가을), 추워지는 출발
 * (17구간 늦가을 → 첫 추위 — 늦가을이 젖은 단계라 선로가 언다), 단계가 그대로인 출발, 정기 한파 구간(winterEvery)의 출발을 따로 만든다. */
function climateParts() {
  const parts: { name: string; action: Action; before: Game; after: Game }[] = [];
  const cases: [string, number, number][] = [['drop', 17, 0], ['same', 5, 0], ['winter', S1.P.winterEvery, S1.stageAt(S1.P.winterEvery)]];
  for (const [name, seg, outside] of cases) {
    const g = S1.createGame(`turn-climate-${name}`);
    S1.enableClimate(g);
    g.seg = seg;
    g.outside = outside;
    const before = plain(g);
    S1.advance(g);
    parts.push({ name: `climate/${name}`, action: { kind: 'advance' }, before, after: plain(g) });
  }
  return parts;
}

/** 결빙 판: 17구간 늦가을에서 떠나 선로가 얼고(석탄 +1, 식량 +반나절, 선로 사건 두 배), 그 구간 정산 끝에 풀릴 때까지 */
const FREEZE_SEED = 'turn-climate-freeze';
function freezeRun(limit: number) {
  return play(FREEZE_SEED, limit, true, g => { g.seg = 17; g.outside = 0; },
    (before, after) => (before.freeze ?? 0) > 0 && (after.freeze ?? 0) === 0);
}

function climateRuns(limit: number) {
  return [...SEEDS.map(seed => play(seed, limit, true)), freezeRun(limit)];
}

/** 기온 켠 판(결빙 켬)의 같은 네 씨앗, 결빙 판 하나, 출발 표본 */
export function climateVectors() {
  if (!S1.CL.freezeOn) throw new Error('F-INPUT: 결빙을 켜고 부른다');
  return { format: 'turn-vectors-climate-v2', seeds: [...SEEDS, FREEZE_SEED], maxSteps: MAX_STEPS, freezeOn: S1.CL.freezeOn, tables: tables(), runs: climateRuns(MAX_STEPS), parts: climateParts() };
}

function main(): void {
  const climate = process.argv.includes('--climate');
  const out = resolve(import.meta.dirname, `../../s2/tests/fixtures/train/${climate ? 'turn_vectors_climate' : 'turn_vectors'}.json`);
  const data = climate ? climateVectors() : turnVectors();
  let bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  // 씨앗 네 개는 보존하고 걸음만 줄인다. 줄인 길이는 파일과 실행 출력에 남긴다.
  while (bytes.length > LIMIT && data.maxSteps > 1) {
    data.maxSteps -= 1;
    data.runs = climate ? climateRuns(data.maxSteps) : SEEDS.map(seed => play(seed, data.maxSteps));
    bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  }
  if (bytes.length > LIMIT) throw new Error('F-FIXTURE-SIZE: 한 걸음도 30 MiB를 넘는다');
  mkdirSync(dirname(out), { recursive: true });
  // 같은 내용은 다시 쓰지 않는다. 두 번째 실행도 전체 S1 계산과 바이트 대조를 한다.
  let identical = false;
  try { identical = readFileSync(out).equals(bytes); } catch { /* 첫 실행 */ }
  if (!identical) writeFileSync(out, bytes);
  console.log(JSON.stringify({ bytes: bytes.length, identical, maxSteps: data.maxSteps, parts: data.parts.length, runs: data.runs.map(r => ({ seed: r.seed, steps: r.steps.length, finalPhase: r.finalPhase, ended: r.ended })) }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
