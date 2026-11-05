// 내정 출발 훅 이식 표본(설계 coord/review/내정출발훅_설계_20261105.md 8·10장). S2가 domesticDepart·
// domesticStrikeRuns를 옮길 때 맞댈 S1 출발 결과. 규칙 코드는 읽기만 하고, 답은 모두 S1.advance가 낸다.
// 판마다 S2가 S1과 판 통째로 같아야 하는지(match), 이식 안 됨으로 거절해야 하는지(refuse)와 그 낱말을 적는다.
// 사용: npx tsx tools/depart_port_fixtures.ts [출력 경로=../s2/tests/fixtures/train/depart_vectors.json]
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Game } from '../src/game';
import type { LocoId } from '../src/game/data';
import type { DomPerson } from '../src/game/domestic/state';
import { domesticDepart } from '../src/game/domestic/hooks';
import { storyOf } from '../src/game/state';
import { enableEventPack } from '../src/game/event_pack';
import { loadContentEvents } from './content_fs';
import { assertNoSuppliesHooks, projectDom, restorationBoard } from './restore_port_fixture_helpers';
import { tables } from './turn_port_fixtures';

// S2 게임 판은 새 사건 묶음을 켠다(slice_flow.gd eventPack). 출발이 이동 사건을 뽑는 갈래까지 같게 본다.
loadContentEvents();
assertNoSuppliesHooks();
const FORMAT = 'depart-vectors-v1';
// mulberry32: 뽑을 때마다 상태에 이 값을 더한다(s1/src/core/rng.ts STATE_INCREMENT).
const RNG_INC = 0x6d2b79f5;
const SEEDS = ['depart-0', 'depart-1'];
const LIMIT = 4 * 1024 * 1024;

const plain = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T;
const draws = (from: number, to: number): number => {
  for (let k = 0; k <= 8; k += 1) if (((from + k * RNG_INC) >>> 0) === to) return k;
  throw new Error(`난수 상태가 8번 안에 닿지 않음: ${from} → ${to}`);
};

/** S2 계약 꼴(PR 4·6 내정 몫, 사람 명부는 experts). 투영이 지우는 기관 매뉴얼은 출발을 가르므로(설계 10장 H3)
 *  매뉴얼을 쥔 판은 비추지 않고 멈춘다 — S2가 받은 판으로는 매뉴얼 있음·없음을 가를 수 없다. */
function s2State(g: Game): Record<string, unknown> {
  assertNoSuppliesHooks(g);
  if (g.dom?.manuals.engine) throw new Error('F-NOT-PROJECTABLE: engine manual (the S2 projection drops manuals)');
  const out = plain(g) as unknown as Record<string, unknown>;
  if (g.dom) out.dom = projectDom(g);
  return out;
}

const engineHands = (g: Game): DomPerson[] => g.dom!.people.filter(p => p.field === 'engine');

/** 출발 바로 앞 판: 자재가 넉넉한 내정(restorationBoard, 숙련 모두 3), 둘째 구간(첫 구간의 서막 거래는 따로 본다). */
function board(seed: string): Game {
  const g = restorationBoard(seed, []);
  g.phase = 'prep'; g.cards = []; g.proposals = []; g.council = null;
  g.coal = g.food = g.med = 1000;
  g.seg = 2;
  g.journal = [];
  enableEventPack(g);
  assert.equal(engineHands(g).length >= 2, true, '기관 숙련자가 둘 이상인 시작 명부');
  assert.equal(S1.primaryAction(g).ok, true);
  return g;
}

type Expect = { expect: 'match' } | { expect: 'refuse'; refusal: string };
type Row = { name: string; seed: string; hookDraws: number; before: unknown; after: unknown; end: string | null } & Expect;

function record(rows: Row[], name: string, seed: string, g: Game, want: Expect, check: (g: Game, hook: number) => void): void {
  const before = s2State(g);
  // 훅 하나만 쓴 난수: 출발 앞의 기후·결빙은 게임 난수를 쓰지 않는다(6.1 Sol 점검 확인) — 같은 판의 사본에서 훅만 돌려 센다.
  const probe = plain(g);
  const s0 = probe.rng.state;
  domesticDepart(probe);
  const hook = draws(s0, probe.rng.state);
  S1.advance(g);
  check(g, hook);
  rows.push({ name: `${name}/${seed}`, seed, hookDraws: hook, before, after: s2State(g), end: g.end ?? null, ...want });
}

const travelled = (g: Game) => { assert.equal(g.phase, 'travel'); assert.notEqual(g.end, 'stranded'); };

function rowsFor(seed: string): Row[] {
  const rows: Row[] = [];
  const match: Expect = { expect: 'match' };
  const base = (): Game => board(seed);

  // ① 기본 기관차(고르지 않음 = c3), 기관 최고 3: 고장 판정 난수 하나, 고장은 안 남.
  record(rows, 'c3/default', seed, base(), match, (g, hook) => {
    travelled(g); assert.equal(hook, 1); assert.equal(g.dom!.stats.breakdowns, 0);
  });
  // 명시한 c3와 null(옛 저장의 빈 칸)도 기본으로 읽는다.
  { const g = base(); g.loco = 'c3';
    record(rows, 'c3/explicit', seed, g, match, (after, hook) => { travelled(after); assert.equal(hook, 1); }); }
  { const g = base(); (g as unknown as { loco: LocoId | null }).loco = null;
    record(rows, 'c3/null', seed, g, match, (after, hook) => { travelled(after); assert.equal(hook, 1); }); }
  // ② 결함판 여럿: 확률식에 결함 몫이 붙어도 c3 곱 0이라 여전히 난수 하나·고장 없음.
  { const g = base();
    for (const id of ['e1', 'm1', 'w1'] as const) g.dom!.techs[id] = { stage: 'defective', defect: true, progress: 3, need: 3 };
    record(rows, 'c3/defective-techs', seed, g, match, (after, hook) => {
      travelled(after); assert.equal(hook, 1); assert.equal(after.dom!.stats.breakdowns, 0);
    }); }
  // ④ 기관 숙련 0·매뉴얼 없음: S1 'end' → 선 열차로 끝(훅 난수 0).
  { const g = base(); for (const p of engineHands(g)) p.skill = 0;
    assert.equal(g.dom!.manuals.engine, false);
    record(rows, 'engine-0/no-manual', seed, g, match, (after, hook) => {
      assert.equal(hook, 0); assert.equal(after.phase, 'end'); assert.equal(after.end, 'stranded');
    }); }
  // ③ 기관 최고 1: S1은 압력 경고 난수를 하나 더 뽑는다(카드는 확률). S2는 압력 카드를 옮기지 않아 거절.
  { const g = base(); for (const p of engineHands(g)) p.skill = 1;
    record(rows, 'engine-1/pressure', seed, g, { expect: 'refuse', refusal: 'domesticDepart: dom:pressure' }, (_after, hook) => {
      assert.equal(hook, 2);
    }); }
  // ⑥ 다른 기관차: c4는 누구나 몰아 정지 검사를 건너뛰고(기관 0이어도 감), c1·c2는 고장이 날 수 있다.
  { const g = base(); g.loco = 'c4';
    record(rows, 'loco-c4', seed, g, { expect: 'refuse', refusal: 'domesticDepart: anyoneDrives (c4)' }, (_after, hook) => assert.ok(hook >= 1)); }
  { const g = base(); g.loco = 'c4'; for (const p of engineHands(g)) p.skill = 0;
    record(rows, 'loco-c4/engine-0', seed, g, { expect: 'refuse', refusal: 'domesticDepart: anyoneDrives (c4)' }, (after, hook) => {
      assert.ok(hook >= 1); assert.notEqual(after.end, 'stranded', 'c4는 기관 0이어도 서지 않음');
    }); }
  for (const id of ['c1', 'c2'] as const) {
    const g = base(); g.loco = id;
    record(rows, `loco-${id}`, seed, g, { expect: 'refuse', refusal: `domesticDepart: breakdown (${id})` }, (_after, hook) => assert.ok(hook >= 1));
  }
  // 파업 갈래: 기관실이 기본 문턱(매뉴얼 없음) 아래로 성났다. 사건을 뽑지 않는 갈래에서도 훅 난수는 하나.
  const strike = (g: Game) => { g.comms.engine.fervor = 1; g.comms.engine.rel = S1.P.strikeRel; };
  { const g = base(); strike(g);
    record(rows, 'strike/stops', seed, g, match, (after, hook) => {
      assert.equal(hook, 1); assert.equal(after.inStrike, true); assert.ok(after.cards.some(c => c.kind === 'strike'));
    }); }
  { const g = base(); strike(g); g.passed.strike_ban = 0;
    record(rows, 'strike/ban', seed, g, match, (after, hook) => {
      assert.equal(hook, 1); assert.equal(after.comms.engine.fervor, 0);
      assert.ok(after.journal.some(r => r.text === '파업 금지법을 내밀자 화부들이 말없이 불 앞으로 돌아갔다.'));
    }); }
  // ⑤ 대체 기관사(기관실 밖 기관 숙련 2): 파업이고 금지법이 없을 때만 S1이 strikeRuns를 불러 화부 카드로 간다.
  const substitute = (g: Game) => {
    const hands = engineHands(g);
    const second = hands.find(p => p.comm === 'engine' && p !== hands[0])!;
    second.comm = 'tail'; second.skill = 2;
    assert.ok(hands.some(p => p.comm === 'engine' && p.skill === 3), '기관 최고 3은 기관실에 남음(압력 갈래 아님)');
  };
  { const g = base(); substitute(g); strike(g);
    record(rows, 'substitute/strike', seed, g, { expect: 'refuse', refusal: 'domesticStrikeRuns: stoker' }, (after, hook) => {
      assert.equal(hook, 1); assert.ok(after.cards.some(c => c.kind === 'dom:stoker'));
    }); }
  { const g = base(); substitute(g);
    record(rows, 'substitute/calm', seed, g, match, (after, hook) => { travelled(after); assert.equal(hook, 1); }); }
  { const g = base(); substitute(g); strike(g); g.passed.strike_ban = 0;
    record(rows, 'substitute/strike-ban', seed, g, match, (after, hook) => { assert.equal(hook, 1); assert.equal(after.comms.engine.fervor, 0); }); }
  // 첫 구간 서막 거래(사건 대신 거래 카드): 훅 난수 하나 뒤 사건을 뽑지 않는다.
  { const g = base(); g.seg = 1; g.loco = 'c3';
    storyOf(g).flags.depot_promise = 'kept';
    record(rows, 'prologue-deal', seed, g, match, (after, hook) => {
      assert.equal(hook, 1); assert.ok(after.cards.some(c => c.kind === 'pro_deal'));
    }); }
  // 내정 없는 판: S1은 훅을 건너뛴다(난수 0). S2 시험은 같은 판에 자재 사전(TrainDom.empty())을 붙여도 같은지 본다.
  { const g = base(); delete g.dom;
    record(rows, 'no-dom', seed, g, match, (after, hook) => { travelled(after); assert.equal(hook, 0); }); }
  return rows;
}

export function departPortVectors() {
  assertNoSuppliesHooks();
  // 생성기 자체 확인(설계 10장 H3): 기관 매뉴얼을 쥔 판은 비추지 않는다.
  { const g = board('depart-guard'); for (const p of engineHands(g)) p.skill = 0; g.dom!.manuals.engine = true;
    assert.throws(() => s2State(g), /F-NOT-PROJECTABLE: engine manual/); }
  const rows = SEEDS.flatMap(rowsFor);
  return { format: FORMAT, seeds: SEEDS,
    scope: 'S1c restoration board at a later stretch\'s prep; domesticDepart / domesticStrikeRuns paths: c3 default/explicit/null, defective techs, engine 0 (no manual), engine 1 pressure, locomotives c1/c2/c4, strike stop/ban, substitute driver, prologue deal, no dom',
    tables: tables(), rows };
}

function main(): void {
  const out = resolve(process.argv.find(a => a.endsWith('.json')) ?? resolve(import.meta.dirname, '../../s2/tests/fixtures/train/depart_vectors.json'));
  const data = departPortVectors();
  const bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  if (bytes.length > LIMIT) throw new Error(`F-FIXTURE-SIZE: ${bytes.length} > ${LIMIT}`);
  mkdirSync(dirname(out), { recursive: true });
  let identical = false;
  try { identical = readFileSync(out).equals(bytes); } catch { /* 첫 실행 */ }
  if (!identical) writeFileSync(out, bytes);
  const counts = data.rows.reduce<Record<string, number>>((m, r) => { m[r.expect] = (m[r.expect] ?? 0) + 1; return m; }, {});
  console.log(JSON.stringify({ format: FORMAT, bytes: bytes.length, identical, rows: data.rows.length, ...counts }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
