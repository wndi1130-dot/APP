// 법 기술 이식 표본(결정 426 PR 7 S2 넷째 판, 결정 446). S2가 domestic/lawtech.ts와 laws.ts의 변형 법 셋을 옮길 때 맞대 볼 기준 값.
// 규칙 코드는 읽기만 한다. 답은 모두 S1 함수가 내고, 여기서는 기술 상태·법·단열·숙련을 섞어 비추기만 한다.
// 사용: npx tsx tools/lawtech_port_fixtures.ts [출력 경로=../s2/tests/fixtures/train/lawtech_vectors.json]
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { createRng, randomInt } from '../src/core/rng';
import * as S1 from '../src/game';
import type { Comm, Game, LawId } from '../src/game';
import { CAR_COMM } from '../src/game/domestic/data';
import type { TechId, Variant } from '../src/game/domestic/data';
import { lawTechCoal, lawTechFood, lawTechLines, lawTechNews, lawTechRes, techUseLine } from '../src/game/domestic/lawtech';
import { refreshSit } from '../src/game/domestic/sit';
import { createS1cGame } from '../src/game/domestic/state';
import { council } from './law_port_fixtures';
import { tables } from './turn_port_fixtures';

const FORMAT = 'lawtech-vectors-v1';
const SEEDS = ['lawtech-0', 'lawtech-1'];
const PROFILES = 60;
const LIMIT = 8 * 1024 * 1024;
/** 법에 걸린 기술(lawtech.ts TOUCHES·OPENS의 기술 전부). */
const LAW_TECHS: TechId[] = ['e1', 'e2', 'e3', 'e4', 'e5', 'm2', 'm3', 'm5', 'x1'];
const VARIANT_TECHS: TechId[] = ['e3', 'm3'];
/** 기술이 바꾸는 법(TOUCHES의 법). */
const TOUCH_LAWS: LawId[] = ['snow_duty', 'heat_quota', 'common_heating', 'common_kitchen', 'treat_all'];
/** 변형 셋과 그 원래 법(OPENS). 열림은 S1 lawOpen 전체로 맞댄다. */
const PAIRS: [LawId, LawId][] = [['seed_half', 'seed_grain'], ['child_pack', 'child_labor'], ['triage_std', 'triage']];
const OPEN_LAWS: LawId[] = PAIRS.flat();
const RESIDENTS = Object.keys(CAR_COMM);
const plain = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T;
const byComm = <T>(f: (c: Comm) => T) => Object.fromEntries(S1.COMMS.map(c => [c, f(c)]));
let rng = createRng('lawtech-port-v1');
function n(lo: number, hi: number): number {
  const next = randomInt(rng, lo, hi);
  rng = next.rng;
  return next.value;
}
const pick = <T>(xs: readonly T[]): T => xs[n(0, xs.length - 1)];

/** 법 기술 밖의 처지 보정(침구·장갑·솥·폭동·침대)은 0으로 둔 내정. 사람 명부는 숙련만 흔든다. */
function attachDom(g: Game, skill: () => number): void {
  g.dom = plain(createS1cGame(`${g.seed}-dom`).dom!);
  const d = g.dom;
  d.bedding = {}; d.armored = []; d.typhus = []; d.bedOrder = null;
  delete d.pot; delete d.elder; g.riot.scorched = [];
  delete (g as Game & { wounds?: unknown[] }).wounds;
  d.techs = {}; d.restoring = null; d.insulated = []; d.job = null;
  for (const p of d.people) {
    delete p.pupil; delete p.learn; delete p.writing; delete p.resting;
    p.skill = skill();
  }
}

/** 기술 하나의 상태: 없음 / 복원 중 / 결함판 / 완성판 / 세워 둠 / 유지비 못 냄. 변형 기술은 가·나 중 하나. */
function techState(g: Game, id: TechId, kind: number): void {
  if (kind === 0) return;
  const variant: Variant | undefined = VARIANT_TECHS.includes(id) ? pick(['a', 'b'] as Variant[]) : undefined;
  g.dom!.techs[id] = {
    stage: kind === 1 ? 'restoring' : kind === 2 ? 'defective' : 'done', defect: kind === 2,
    progress: kind === 1 ? 1 : 3, need: 3, ...(variant ? { variant } : {}),
    ...(kind === 4 ? { off: true } : {}), ...(kind === 5 ? { starved: true } : {}),
  };
}

function prepare(base: Game, profile: number): Game {
  const g = plain(base);
  attachDom(g, () => n(0, 3));
  g.passed = {};
  for (const law of ['snow_duty', 'heat_quota', 'common_heating', 'common_kitchen', 'treat_all'] as LawId[]) if (n(0, 1)) g.passed[law] = 0;
  // 원래 법과 변형은 하나만 선다.
  for (const pair of PAIRS) { const k = n(0, 2); if (k > 0) g.passed[pair[k - 1]] = 0; }
  for (const id of LAW_TECHS) techState(g, id, profile < 3 ? 3 : n(0, 5));
  g.dom!.insulated = RESIDENTS.filter(() => n(0, 2) === 0);
  g.food = pick([20, 40, 41, 50, 51, 80]); g.coal = pick([30, 40, 41, 60]);
  g.med = pick([3, 5, 6, 20]); g.injured = pick([0, 3, 6]);
  for (const c of S1.COMMS) {
    g.comms[c].heat = n(0, 4); g.comms[c].ration = n(0, 4);
    g.comms[c].base[0] = pick([0, 3, 45, 97, 100]);
    g.comms[c].base[3] = pick([0, 2, 40, 98, 100]);
  }
  g.journal = [];
  // 법 기술 밖의 처지 보정이 끼어들었으면 뽑기를 멈춘다.
  const bare = plain(g);
  bare.dom!.techs = {}; bare.dom!.insulated = [];
  refreshSit(bare);
  if (Object.values(bare.dom!.sit).some(v => v.some(x => x !== 0))) throw new Error('Non-law-tech situation term');
  refreshSit(g);
  return g;
}

/** S2 계약 꼴로 비춘다: S1a 판 + PR 4·6의 내정 몫(기술·전문가·단열). S1 사람 명부는 experts로. */
function s2State(g: Game) {
  const out = plain(g) as Game & Record<string, unknown>;
  const d = g.dom!;
  (out as Record<string, unknown>).dom = plain({
    scrap: d.scrap, wood: d.wood, parts: d.parts, techs: d.techs, restoring: d.restoring, insulated: d.insulated, job: null,
    experts: d.people.filter(p => p.alive && !p.gone).map(({ name, comm, field, skill }) => ({ name, comm, field, skill })),
  });
  return out;
}

function lawCase(g: Game) {
  return {
    situation: byComm(c => S1.situation(g, c)),
    medMult: (Object.keys(g.passed) as LawId[]).reduce((m, law) => m * (lawTechRes(g, law).medMult ?? 1), 1),
    coal: lawTechCoal(g), food: lawTechFood(g),
    open: Object.fromEntries(OPEN_LAWS.map(l => [l, S1.lawOpen(g, l)])),
    use: Object.fromEntries(LAW_TECHS.flatMap(id => [undefined, ...(VARIANT_TECHS.includes(id) ? ['a', 'b'] as Variant[] : [])]
      .map(v => [`${id}${v ?? ''}`, techUseLine(g, id, v)]))),
    lines: Object.fromEntries(TOUCH_LAWS.map(l => [l, lawTechLines(g, l)])),
    news: Object.fromEntries(LAW_TECHS.map(id => [id, lawTechNews(g, id)])),
  };
}

type Action = { kind: 'enact' | 'repeal'; law: LawId } | { kind: 'cast_vote' };
/** 변형 법의 통과·개정·폐지·표결. 기술은 셋 다 완성판, 숙련은 모두 3(변형이 열리는 판). */
function variantCases(base: Game) {
  const cases: { name: string; action: Action; before: unknown; after: unknown }[] = [];
  const ready = plain(base);
  attachDom(ready, () => 3);
  for (const id of ['m2', 'm3', 'x1'] as TechId[]) ready.dom!.techs[id] = { stage: 'done', defect: false, progress: 3, need: 3, ...(id === 'm3' ? { variant: 'a' as Variant } : {}) };
  refreshSit(ready);
  const add = (name: string, g: Game, action: Action, run: () => void) => {
    const before = s2State(g);
    run();
    cases.push({ name, action, before, after: s2State(g) });
  };
  const standing = (law: LawId): Game => {
    const g = plain(ready);
    S1.enactLaw(g, law, []);
    g.session += S1.P.repealCool + 1;
    return g;
  };
  for (const [variant, root] of PAIRS) {
    if (!S1.lawActive(ready, variant)) {
      const g = plain(ready);
      add(`enact/${base.seed}/${variant}`, g, { kind: 'enact', law: variant }, () => S1.enactLaw(g, variant, []));
      const v = plain(ready);
      v.council = { options: [{ law: variant, repeal: false }], idx: 0, locked: false, deals: [], result: null };
      add(`vote/${base.seed}/${variant}`, v, { kind: 'cast_vote' }, () => { S1.castVote(v); });
    }
    const up = standing(root);
    const amend = plain(up);
    add(`amend/${base.seed}/${variant}`, amend, { kind: 'enact', law: variant }, () => S1.enactLaw(amend, variant, []));
    const vote = plain(up);
    vote.council = { options: [{ law: variant, repeal: false, amend: root }], idx: 0, locked: false, deals: [], result: null };
    add(`vote-amend/${base.seed}/${variant}`, vote, { kind: 'cast_vote' }, () => { S1.castVote(vote); });
    const down = standing(variant);
    add(`repeal/${base.seed}/${variant}`, down, { kind: 'repeal', law: variant }, () => S1.repealLaw(down, variant));
  }
  return cases;
}

export function lawtechPortVectors() {
  const cases = [];
  const variants = [];
  for (const seed of SEEDS) {
    const base = council(seed);
    for (let profile = 0; profile < PROFILES; profile += 1) {
      const g = prepare(base, profile);
      cases.push({ seed, profile, state: s2State(g), ...lawCase(g) });
    }
    variants.push(...variantCases(base));
  }
  return { format: FORMAT, seeds: SEEDS, profiles: PROFILES, techs: LAW_TECHS, openLaws: OPEN_LAWS, touchLaws: TOUCH_LAWS,
    scope: 'S1a council position + neutralized S1c dom (techs, experts, insulation only); law-tech situation, medMult, coal/food, variant opens, use/law/news lines; variant enact/amend/vote/repeal',
    tables: tables(), cases, variants };
}

function main(): void {
  const out = resolve(process.argv.find(a => a.endsWith('.json')) ?? resolve(import.meta.dirname, '../../s2/tests/fixtures/train/lawtech_vectors.json'));
  const data = lawtechPortVectors();
  const bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  if (bytes.length > LIMIT) throw new Error(`F-FIXTURE-SIZE: ${bytes.length} > ${LIMIT}`);
  mkdirSync(dirname(out), { recursive: true });
  let identical = false;
  try { identical = readFileSync(out).equals(bytes); } catch { /* 첫 실행 */ }
  if (!identical) writeFileSync(out, bytes);
  console.log(JSON.stringify({ format: FORMAT, bytes: bytes.length, identical, cases: data.cases.length, variants: data.variants.length }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
