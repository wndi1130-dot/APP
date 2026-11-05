// 법 기술 이식 표본(결정 426 PR 7 S2 넷째 판, 결정 446). S2가 domestic/lawtech.ts와 laws.ts의 변형 법 셋을 옮길 때 맞대 볼 기준 값.
// 규칙 코드는 읽기만 한다. 답은 모두 S1 함수가 내고, 여기서는 기술 상태·법·단열·숙련을 섞어 비추기만 한다.
// 사용: npx tsx tools/lawtech_port_fixtures.ts [출력 경로=../s2/tests/fixtures/train/lawtech_vectors.json]
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { cancelRestore, runWorkshop, startRestore, workPower } from '../src/game/domestic/workshop';
import { pipePending, ratifyPipe } from '../src/game/domestic/pipe';
import { contentPool } from '../src/game/content';
import { enableEventPack } from '../src/game/event_pack';
import { loadContentEvents } from './content_fs';
import { assertNoSuppliesHooks, projectDom, relations, restorationBoard, restoreStats } from './restore_port_fixture_helpers';
assertNoSuppliesHooks();
import { dirname, resolve } from 'node:path';
import { createRng, randomInt } from '../src/core/rng';
import * as S1 from '../src/game';
import type { Comm, Game, LawId } from '../src/game';
import { CAR_COMM, TECHS } from '../src/game/domestic/data';
import type { TechId, Variant } from '../src/game/domestic/data';
import { lawTechCoal, lawTechFood, lawTechLines, lawTechNews, lawTechRes, techUseLine } from '../src/game/domestic/lawtech';
import { refreshSit } from '../src/game/domestic/sit';
import { createS1cGame } from '../src/game/domestic/state';
import { council } from './law_port_fixtures';
import { tables } from './turn_port_fixtures';

// S2 always has the content events (content_events.json, made by content_port.ts from the same files);
// the pipe-settle sequences run on to the next stretch's travel draw, which reads them.
loadContentEvents();
const FORMAT = 'lawtech-vectors-v1';
// mulberry32: each draw adds this to the state (s1/src/core/rng.ts STATE_INCREMENT).
const RNG_INC = 0x6d2b79f5;
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
const plain = <T>(v: T): T => {
  if (v && typeof v === 'object' && 'comms' in v) assertNoSuppliesHooks(v as unknown as Game);
  const copy = JSON.parse(JSON.stringify(v)) as T;
  if (copy && typeof copy === 'object' && 'comms' in copy) assertNoSuppliesHooks(copy as unknown as Game);
  return copy;
};
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
  assertNoSuppliesHooks(g);
  const domestic = createS1cGame(`${g.seed}-dom`); assertNoSuppliesHooks(domestic);
  g.dom = plain(domestic.dom!);
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
  (out as Record<string, unknown>).dom = projectDom(g);
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

type Action = { kind: 'enact' | 'repeal'; law: LawId }
  | { kind: 'cast_vote' | 'cancel_restore' | 'achieved_pool' }
  | { kind: 'advance' }
  | { kind: 'start_restore'; id: TechId; mode: 'full' | 'defect'; variant?: Variant }
  | { kind: 'open_pipe_vote' | 'ratify_pipe'; passed: boolean }
  | { kind: 'run_workshop'; workDebt?: number };
/** 변형 법의 통과·개정·폐지·표결. 기술은 셋 다 완성판, 숙련은 모두 3(변형이 열리는 판). */
function variantCases(base: Game) {
  const cases: { name: string; action: Action; before: unknown; result: unknown; after: unknown }[] = [];
  const ready = plain(base);
  attachDom(ready, () => 3);
  for (const id of ['m2', 'm3', 'x1'] as TechId[]) ready.dom!.techs[id] = { stage: 'done', defect: false, progress: 3, need: 3, ...(id === 'm3' ? { variant: 'a' as Variant } : {}) };
  refreshSit(ready);
  const add = (name: string, g: Game, action: Action, run: () => unknown) => {
    assertNoSuppliesHooks(g);
    const before = s2State(g), result = run() ?? null;
    cases.push({ name, action, before, result, after: s2State(g) });
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
      add(`vote/${base.seed}/${variant}`, v, { kind: 'cast_vote' }, () => S1.castVote(v));
    }
    const up = standing(root);
    const amend = plain(up);
    add(`amend/${base.seed}/${variant}`, amend, { kind: 'enact', law: variant }, () => S1.enactLaw(amend, variant, []));
    const vote = plain(up);
    vote.council = { options: [{ law: variant, repeal: false, amend: root }], idx: 0, locked: false, deals: [], result: null };
    add(`vote-amend/${base.seed}/${variant}`, vote, { kind: 'cast_vote' }, () => S1.castVote(vote));
    const down = standing(variant);
    add(`repeal/${base.seed}/${variant}`, down, { kind: 'repeal', law: variant }, () => S1.repealLaw(down, variant));
  }
  return cases;
}

/** 같은 판을 단계 끝까지 이어서 저장한다. 초기 입력 뒤에 답을 손으로 넣지 않는다. */
function pipeSequences() {
  const sequences: { name: string; initial: unknown; steps: unknown[] }[] = [];
  const sequence = (name: string, variant: Variant, run: (g: Game, step: (action: Action, f: () => unknown) => unknown) => void, activeLaw: LawId = 'common_heating') => {
    const g = restorationBoard(name, ['e3']);
    g.phase = 'council'; g.cards = []; g.proposals = []; g.council = null;
    g.coal = g.food = g.med = 1000;
    g.passed[activeLaw] = 0;
    // 정산 시퀀스는 다음 구간의 이동 사건 뽑기까지 간다. S2 게임 판은 새 사건 묶음을 켜고(slice_flow.gd
    // eventPack), 「이룬 뒤」 사건(ev_b01_*, 깃발 ev_achieved)은 그 묶음에만 있다.
    if (name.startsWith('pipe-settle/')) enableEventPack(g);
    const initial = s2State(g), steps: unknown[] = [];
    const step = (action: Action, f: () => unknown) => {
      assertNoSuppliesHooks(g);
      const before = s2State(g), result = f() ?? null;
      steps.push({ action, before, result: plain(result), after: s2State(g) });
      return result;
    };
    assert.equal(g.dom!.pipeMoved, undefined); assert.equal(g.dom!.pipeFlip, undefined);
    assert.equal(step({ kind: 'start_restore', id: 'e3', mode: 'full', variant }, () => startRestore(g, 'e3', 'full', variant)), true);
    assert.equal(pipePending(g), variant);
    run(g, step);
    sequences.push({ name, initial, steps });
  };
  type Step = Parameters<Parameters<typeof sequence>[2]>[1];
  const vote = (g: Game, step: Step, passed: boolean) => {
    assert.ok(pipePending(g));
    // 실제 표결 함수를 쓰되 기존 표 이동 입력으로 찬반을 확정한다. 관계는 건드리지 않는다.
    step({ kind: 'open_pipe_vote', passed }, () => {
      g.council = { options: [{ kind: 'motion', motion: 'pipe' }], idx: 0, locked: false, deals: [], result: null };
      g.voteShift = S1.COMMS.map(comm => ({ comm, n: 1000, side: passed ? 'yes' : 'no' }));
    });
    const result = step({ kind: 'cast_vote' }, () => S1.castVote(g)) as ReturnType<typeof S1.castVote>;
    assert.ok(result); assert.equal(result.passed, passed, '원하는 찬반 표본이 아님');
    assert.equal(pipePending(g), null);
    if (passed) assert.equal(g.contentFlags?.ev_achieved, true);
  };
  const work = (g: Game, step: Step) => {
    const d = g.dom!;
    for (let i = 0; d.restoring && d.techs.e3!.progress < d.techs.e3!.need - 1e-9 && i < 32; i++)
      step({ kind: 'run_workshop' }, () => runWorkshop(g));
    assert.ok(d.techs.e3!.progress >= d.techs.e3!.need - 1e-9);
  };
  const cancel = (g: Game, step: Step) => {
    assert.equal(g.dom!.restoring, 'e3'); assert.ok(g.dom!.techs.e3!.progress < g.dom!.techs.e3!.need);
    const rel = relations(g), history = plain(g.dom!.log.restores);
    step({ kind: 'cancel_restore' }, () => cancelRestore(g));
    assert.equal(g.dom!.restoring, null); assert.equal(g.dom!.techs.e3, undefined);
    assert.deepEqual(relations(g), rel); assert.deepEqual(g.dom!.log.restores, history);
    assert.equal(g.journal.at(-1)?.tone, 'bad');
  };
  for (const variant of ['a', 'b'] as const) {
    sequence(`pipe-restart/rejected/${variant}`, variant, (g, step) => {
      vote(g, step, false);
      assert.equal(g.dom!.restoring, 'e3'); assert.equal(g.dom!.techs.e3!.stage, 'restoring');
      const fixed = g.dom!.pipeFlip;
      assert.equal(fixed, variant === 'a' ? 'b' : 'a');
      cancel(g, step);
      assert.equal(g.dom!.pipeFlip, fixed); assert.equal(g.dom!.pipeMoved, fixed);
      assert.equal(step({ kind: 'start_restore', id: 'e3', mode: 'full', variant }, () => startRestore(g, 'e3', 'full', variant)), true);
      assert.equal(g.dom!.techs.e3!.variant, fixed); assert.equal(g.dom!.techs.e3!.pending, undefined);
      assert.equal(pipePending(g), null);
    });
  }
  for (const passed of [true, false]) {
    sequence(`pipe-restart/approved/revote=${passed}`, 'a', (g, step) => {
      vote(g, step, true);
      assert.equal(g.dom!.pipeMoved, 'a'); assert.equal(g.dom!.pipeFlip, undefined);
      cancel(g, step);
      assert.equal(g.dom!.pipeMoved, 'a'); assert.equal(g.dom!.pipeFlip, undefined);
      assert.equal(step({ kind: 'start_restore', id: 'e3', mode: 'full', variant: 'a' }, () => startRestore(g, 'e3', 'full', 'a')), true);
      assert.equal(pipePending(g), 'a');
      const rel = relations(g);
      vote(g, step, passed);
      if (passed) assert.deepEqual(relations(g), rel);
      else { assert.notDeepEqual(relations(g), rel); assert.equal(g.dom!.pipeFlip, 'b'); }
    });
  }
  for (const kind of ['matrix', 'settle'] as const)
    for (const variant of (kind === 'matrix' ? ['a', 'b'] : ['a']) as Variant[])
      for (const passed of [true, false]) for (const complete of [true, false]) {
        sequence(`pipe-${kind}/${variant}/passed=${passed}/complete=${complete}`, variant, (g, step) => {
          const d = g.dom!, stats = restoreStats(g), journalAt = g.journal.length, seg = g.seg;
          if (complete) work(g, step);
          assert.equal(d.restoring, 'e3'); assert.equal(d.techs.e3!.stage, 'restoring');
          assert.equal(pipePending(g), variant);
          assert.equal(d.techs.e3!.progress >= d.techs.e3!.need - 1e-9, complete);
          vote(g, step, passed);
          const result = passed ? variant : variant === 'a' ? 'b' : 'a';
          assert.equal(d.techs.e3!.variant, result); assert.equal(d.pipeMoved, result);
          assert.equal(d.pipeFlip, passed ? undefined : result);
          assert.equal(d.techs.e3!.stage, complete ? 'done' : 'restoring');
          assert.equal(d.restoring, complete ? null : 'e3');
          assert.equal(d.stats.restored, stats.restored + (complete ? 1 : 0));
          const beforeAgain = plain(g);
          step({ kind: 'ratify_pipe', passed }, () => ratifyPipe(g, passed));
          assert.deepEqual(plain(g), beforeAgain, 'pending 없는 재추인은 아무 효과가 없어야 함');
          if (kind === 'matrix') return;
          if (!complete) work(g, step);
          assert.equal(d.restoring, null); assert.equal(d.techs.e3!.stage, 'done');
          const news = lawTechNews(g, 'e3');
          assert.ok(news.length > 0, '활성 법 소식이 없는 정산 입력');
          const assertOnce = () => {
            assert.deepEqual(restoreStats(g), { ...stats, restored: stats.restored + 1 });
            const rows = g.journal.slice(journalAt);
            assert.equal(rows.filter(r => r.text.includes(TECHS.e3.name) && r.text.includes('복원했다.')).length, 1);
            for (const line of news) assert.equal(rows.filter(r => r.text === line).length, 1);
          };
          assertOnce();
          assert.equal(S1.primaryAction(g).ok, true, '정산으로 갈 수 없는 입력');
          const forecast = S1.forecast(g), coal = g.coal, food = g.food;
          step({ kind: 'advance' }, () => S1.advance(g));
          assert.equal(g.phase, 'settle'); assert.equal(g.seg, seg);
          assert.ok(g.lastSettle); assert.equal(g.lastSettle.coal, g.coal - coal); assert.equal(g.lastSettle.food, g.food - food);
          assert.equal(g.coal, coal - forecast.coal); assert.equal(g.food, food - forecast.food);
          assertOnce();
          // 설계 10-7: 깃발을 실제 사건 뽑기가 읽는 때까지 잇는다 — 다음 구간으로 넘어가(nextSegment) 출발하며
          // 이동 사건을 뽑는 데(depart → drawTravelEvent)까지. 뽑기 바로 앞의 「이룬 뒤」 사건 풀을 단계로 남기고,
          // 가결 판엔 그런 사건이 들고 부결 판엔 없는지 여기서 확인한다(양쪽 다 없어 통과하는 표본을 막음).
          step({ kind: 'advance' }, () => S1.advance(g));
          assert.equal(g.phase, 'prep'); assert.equal(g.seg, seg + 1);
          const gated = step({ kind: 'achieved_pool' }, () => contentPool(g)
            .filter(ev => ev.trigger.some(c => c.type === 'flag' && c.id === 'ev_achieved')).map(ev => ev.id)) as string[];
          assert.equal(gated.length > 0, passed, passed ? '가결 판인데 「이룬 뒤」 사건이 풀에 없음' : '부결 판인데 「이룬 뒤」 사건이 풀에 있음');
          assert.equal(S1.primaryAction(g).ok, true, '출발할 수 없는 입력');
          // 출발: 내정 훅(domesticDepart)의 기관 고장 판정 난수 하나(기본 기관차 c3라 고장은 안 남) + 이동 사건 뽑기
          // 하나. S2도 같은 자리에서 같은 둘을 뽑아야 뽑힌 카드까지 같다.
          const s0 = g.rng.state, breakdowns = g.dom!.stats.breakdowns ?? 0;
          step({ kind: 'advance' }, () => S1.advance(g));
          assert.equal(g.rng.state, (s0 + 2 * RNG_INC) >>> 0, '출발 난수가 고장 판정 하나 + 사건 뽑기 하나가 아님');
          assert.equal(g.dom!.stats.breakdowns ?? 0, breakdowns, '기본 기관차인데 고장이 남');
          assert.equal(g.phase, 'travel'); assert.equal(g.seg, seg + 1);
          assert.ok(g.cards.length > 0, '출발에서 뽑힌 카드가 없음');
        }, (passed ? variant : variant === 'a' ? 'b' : 'a') === 'a' ? 'common_heating' : 'heat_quota');
      }
  // need - 1e-9는 공방의 실제 작업량을 조절해 만든다(진행 결과를 직접 대입하지 않음).
  for (const passed of [true, false]) {
    sequence(`pipe-boundary/epsilon/passed=${passed}`, 'a', (g, step) => {
      const d = g.dom!, st = d.techs.e3!;
      assert.ok(workPower(g) > 0);
      for (let i = 0; st.need - st.progress > workPower(g) && i < 32; i++)
        step({ kind: 'run_workshop' }, () => runWorkshop(g));
      assert.ok(st.need - st.progress <= workPower(g));
      const debt = workPower(g) - (st.need - st.progress - 1e-9);
      // 작업 부채는 이 단계의 입력. 앞 단계의 결과를 조작하지 않도록 행동에도 남긴다.
      step({ kind: 'run_workshop', workDebt: debt }, () => { d.workDebt = debt; return runWorkshop(g); });
      assert.ok(Math.abs(st.progress - (st.need - 1e-9)) < 1e-12);
      assert.equal(d.restoring, 'e3');
      vote(g, step, passed);
      assert.equal(d.restoring, null); assert.equal(st.stage, 'done');
    });
  }
  return sequences;
}

export function lawtechPortVectors() {
  assertNoSuppliesHooks();
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
    tables: tables(), cases, variants, sequences: pipeSequences() };
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
  console.log(JSON.stringify({ format: FORMAT, bytes: bytes.length, identical, cases: data.cases.length, variants: data.variants.length, sequences: data.sequences.length }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
