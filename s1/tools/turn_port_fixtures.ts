// S1a 한 바퀴의 전체 JSON 전/후. 규칙은 S1에서 직접 실행한다.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import { FIELD } from '../src/game/field_receipt';
import type { Game } from '../src/game';
import { onDeath } from '../src/game/death';
import type { DeathCause } from '../src/game/death';
import type { Comm } from '../src/game/data';
import { addWound, woundTick } from '../src/game/wounds';

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

function play(seed: string, limit: number) {
  const g = S1.createGame(seed);
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
  }
  return { seed, steps, finalPhase: g.phase, ended: g.phase === 'end' };
}

type PartAction = Action | { kind: 'death'; comm: Comm; names: string[]; cause: DeathCause; witness: boolean; quiet: boolean }
  | { kind: 'wound_tick'; medMult: number };

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
  return parts;
}

export function turnVectors() {
  const runs = SEEDS.map(seed => play(seed, MAX_STEPS));
  return { format: 'turn-vectors-v1', seeds: SEEDS, maxSteps: MAX_STEPS, tables: tables(), runs, parts: partVectors(runs) };
}

function main(): void {
  const out = resolve(import.meta.dirname, '../../s2/tests/fixtures/train/turn_vectors.json');
  const data = turnVectors();
  let bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  // 씨앗 네 개는 보존하고 걸음만 줄인다. 줄인 길이는 파일과 실행 출력에 남긴다.
  while (bytes.length > LIMIT && data.maxSteps > 1) {
    data.maxSteps -= 1;
    data.runs = SEEDS.map(seed => play(seed, data.maxSteps));
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
