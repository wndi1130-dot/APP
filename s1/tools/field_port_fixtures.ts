// S3 연결 이식 표본(S1 쪽). 결정 402로 폰 데모의 열차 쪽을 Godot로 옮기며, 귀환 반영·특별 회기·도착·저장 계산을
// GDScript가 같은 값을 내는지 맞대 볼 기준 값을 TS 구현으로 만든다. 규칙 코드는 읽기만 한다. 셈을 여기서 다시 적지 않고,
// S1이 내보내는 함수를 그대로 불러 그 답을 적는다.
// 사용: npx tsx tools/field_port_fixtures.ts [출력 경로=../s2/tests/game/fixtures/field_port/field_vectors.json]
//
// 판은 S1a 판(createGame 그대로: 내정·어두운 길·죽음의 무게 등 꺼짐)이다. 그래서 상징물 「걸어 두기」는 늘 잠겨 있다.
// 판 상태는 통째로(JSON) 적는다. 한 단계의 입력은 바로 앞 단계의 after이고, GDScript는 그 상태를 받아 같은 after를 내야 한다
// (정수 같음, 실수 1e-6, 일지 글까지 같음). 표결은 판의 rng 칸으로 난수를 뽑으니 rng.gd로 맞댈 수 있다.
// 차례(사례마다): apply(영수증 반영) → duplicate(같은 영수증 다시) → symbol(쓰임 고르기, 상징물 있을 때) → open(특별 회기 열기)
// → preview(후보마다 입장·표 덩어리·예상) → votes(후보마다 그 안건을 골라 표결, open.after에서 갈라짐) → leave(첫 후보 표결 뒤 닫기)
// → arrival(S1 열차 턴으로 둘째 역까지 달린 상태에서 도착 화면·끝 카드·「계속」). 열차 턴(advance)은 이 묶음 밖이라
// arrival.state는 S1이 달린 결과를 입력으로 준다.
// open의 보통 안건(agendaOptions)도 정치 전체 이식 밖이라 입력(regular)으로 준다: 회기를 연 직후(회기 수 +1, 적의 시계 +1 뒤) 값이다.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  advance, agendaOptions, blocs, castVote, cloneGame, COMM_NAME, COMMS, CORPSE_LAWS, createGame, expected, IDEO, LAW_VARIANT_OF, LAWS, P,
  PROFILES, PROLOGUE, resolveStop, stance, STAGES,
} from '../src/game';
import type { Game } from '../src/game';
import { applyFieldReturn, chooseSymbolUse, FIELD, snapshot, symbolOptions } from '../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../src/game/field_receipt';
import { leaveSpecialCouncil, nextFieldStep, specialCandidates, specialReasons } from '../src/game/field_council';
import { arrivalSummary, endCard, finishSlice, secondStationReached } from '../src/game/field_arrival';
import { buildDeparture } from '../src/game/field_departure';
import type { FieldDepartureV2 } from '../src/game/field_departure';
import { enableDomestic } from '../src/game/domestic/state';

export const FORMAT = 'field-vectors-v1';
const SEEDS = ['slice-seed-a', 'train-0', 'train-1'];
// [영수증, 출발 명세, 상징물을 회기 앞에 내거나]
const PAIRS: [string, string, boolean][] = [
  ['case1_symbol_kept', 'departure_prologue', true],
  ['case1_symbol_kept', 'departure_prologue', false],
  ['case2_symbol_broken', 'departure_prologue', true],
  ['case3_nosymbol_kept', 'departure_prologue', false],
  ['case4_nosymbol_broken', 'departure_prologue', false],
  ['skip_kept', 'departure_skip_kept', false],
  ['skip_broken', 'departure_skip_broken', false],
  ['witness_none_back', 'departure_prologue', false],
  ['witness_one_back', 'departure_prologue', false],
];

const here = dirname(fileURLToPath(import.meta.url));
const fixDir = resolve(here, '../../s2/tests/game/fixtures/field_v4');
const read = <T>(name: string): T => JSON.parse(readFileSync(join(fixDir, `${name}.json`), 'utf8')) as T;
const plain = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T;
const clear = (g: Game) => { g.cards = []; };
const step = (g: Game) => { clear(g); advance(g); clear(g); };

/** 첫 정차(2구간)를 마친 판. field_arrival.test.ts의 slice()와 같은 차림이다. */
function startGame(seed: string): Game {
  const g = createGame(seed);
  g.seg = 2;
  step(g); step(g);
  resolveStop(g, true);
  clear(g);
  return g;
}

function runCase(seed: string, receiptName: string, depName: string, hang: boolean) {
  const departure = read<FieldDeparture>(depName);
  const receipt = read<FieldReceipt>(receiptName);
  const g = startGame(seed);
  const start = plain(g);
  const applied = applyFieldReturn(g, departure, receipt);
  const apply = { status: applied.status, record: plain(applied.record), after: plain(g) };
  const again = applyFieldReturn(g, departure, receipt);
  const duplicate = { status: again.status, changed: JSON.stringify(g) !== JSON.stringify(apply.after) };

  const rec = g.fieldReturns!.records[0];
  let symbol: Record<string, unknown> | null = null;
  if (rec.symbol) {
    const options = plain(symbolOptions(g, rec.receiptId));
    const lockedTry = chooseSymbolUse(cloneGame(g), rec.receiptId, 'hang_in_car');
    const use = hang ? 'hang_before_session' : null;
    // 고르지 않으면 다음 걸음이 choose_symbol에 머물고 회기는 열리지 않는다(아래 open이 그것을 적는다).
    if (use) chooseSymbolUse(g, rec.receiptId, use);
    symbol = { options, hangInCarAccepted: lockedTry, use, after: plain(g) };
  }

  // 특별 회기 열기. 보통 안건은 회기를 연 직후 값이라 복제본에서 같은 두 셈을 하고 읽는다(입력으로 준다).
  const probe = cloneGame(g);
  probe.session += 1;
  for (const c of COMMS) probe.comms[c].lastOffense += 1;
  const regular = plain(agendaOptions(probe).options);
  const stepBefore = nextFieldStepPeek(g);
  const nextStep = nextFieldStep(g);
  const open = {
    stepBefore, nextStep, regular,
    candidates: g.fieldReturns!.special?.status === 'opened' ? plain(specialCandidates(cloneGame(probe), rec)) : [],
    reasons: plain(specialReasons(g)), after: plain(g),
  };
  if (nextStep !== 'council') {
    return { seed, receipt: receiptName, departure: depName, hang, start, apply, duplicate, symbol, open, preview: [], votes: [], leave: null, arrival: null };
  }

  const options = g.council!.options;
  const preview = options.map(agenda => {
    const map = blocs(g, agenda);
    return {
      agenda: plain(agenda),
      stance: Object.fromEntries(COMMS.map(c => [c, stance(g, c, agenda)])),
      blocs: plain(map), expected: expected(map),
    };
  });
  const votes = options.map((_, i) => {
    const v = cloneGame(g);
    v.council!.idx = i;
    const result = castVote(v);
    return { idx: i, result: plain(result), after: plain(v) };
  });

  castVote(g);
  const left = leaveSpecialCouncil(g);
  const leave = { left, after: plain(g), reasons: plain(specialReasons(g)) };

  // 둘째 역까지 S1 열차 턴으로 달린다(이 묶음 밖). 닿은 상태를 입력으로 준다.
  for (let i = 0; i < 12 && !secondStationReached(g) && g.phase !== 'end'; i += 1) step(g);
  let arrival = null;
  if (secondStationReached(g)) {
    const state = plain(g);
    const now = snapshot(g);
    const sections = plain(arrivalSummary(g));
    const card = endCard(g);
    const finished = finishSlice(g);
    arrival = { state, reached: true, now, sections, endCard: card, finished, after: plain(g), reachedAfter: secondStationReached(g) };
  }
  return { seed, receipt: receiptName, departure: depName, hang, start, apply, duplicate, symbol, open, preview, votes, leave, arrival };
}

/**
 * 출발 계약 판 2·영수증 판 5(docs/design/briefs/s3_departure_receipt_contract.md). 첫 정차에 선 판(정차를 풀기 전)에서 계약을 만들고,
 * 그 계약에 맞춘 판 5 영수증(수색대 + 운송조 둘이 나감, 동료 하나가 왼팔 골절에 곧바로 부목, 운송조 하나가 다리 골절과 곪은 박힌 것, 동료 하나는 물림)을 반영한 뒤 같은 판에서 계약을 다시 만든다
 * (다시 만든 계약의 근육통·휴식이 앞 귀환을 읽는다). 내정을 끈 판과 켠 판 둘.
 */
function liveReceipt(d: FieldDepartureV2): Record<string, unknown> {
  const hurt = d.roster[1].id;
  const carriers = d.workCrew.filter(p => p.role === 'carrier').slice(0, 2).map(p => p.id);
  const sent = [...d.roster.map(p => p.id), ...carriers];
  const everyone = [...d.roster, ...d.workCrew];
  return {
    version: 5, receiptId: `ret_${d.placeId}_${d.segment}`, departureId: d.departureId, stopId: d.stopId, source: 'direct', endReason: 'departed',
    place: { id: d.placeId, type: 'freight', variant: 's2_graybox' },
    time: { arrive: 'D1 10:30', depart: 'D1 12:40', stayGameMinutes: 130 },
    stock: { coal: 4, wood: 2, ammo_shell: -2 }, items: { gained: [], lost: [] },
    people: {
      sent, injured: [hurt, carriers[1]], bitten: [d.roster[3].id], dead: [], missing: [], leftBehind: [], rescued: [],
      wounds: [
        { person: hurt, part: 'arm_left', kind: 'fracture', treat: { splinted: true, quick: true } },
        { person: carriers[0], part: 'leg_right', kind: 'laceration', treat: { disinfected: true, bandaged: true } },
        { person: carriers[1], part: 'leg_left', kind: 'fracture', treat: { splinted: true } },
        { person: carriers[1], part: 'torso', kind: 'embedded', festering: true },
        { person: d.roster[3].id, part: 'arm_right', kind: 'bite', treat: { bandaged: true } },
      ],
    },
    witnessed: [{ who: d.roster[0].id, what: 'searched_body', where: 'siding', when: 'D1 11:05', why: 'loot', witnesses: [d.roster[2].id], template: 'body_search' }],
    placeState: { looted: 0.3, remainingRisk: 2 }, promises: [],
    goal: { kind: 'coal', required: 4, earned: 4, status: 'done' }, extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
    symbol: null, fieldPromises: [],
    crew: sent.map(id => ({
      person: id, exhaustion: id === hurt ? 2 : id === carriers[0] ? 1 : 0, hunger: 0, bodyUse: {},
      gearBack: { hands: everyone.find(p => p.id === id)!.gear.hands.map(h => [...h]), items: {} },
    })),
    defense: null,
  };
}

function contractCase(seed: string, domestic: boolean) {
  const g = createGame(seed);
  if (domestic) enableDomestic(g);
  g.seg = 2;
  step(g); step(g);
  const opts = { placeId: 'sulechow_station' };
  const state = plain(g);
  const departure = plain(buildDeparture(g, opts));
  const receipt = liveReceipt(departure);
  const applied = applyFieldReturn(g, departure, receipt);
  const apply = { status: applied.status, record: plain(applied.record), after: plain(g) };
  const again = plain(buildDeparture(g, opts));
  return { seed, domestic, opts, state, departure, receipt, apply, again };
}

/** nextFieldStep은 회기를 여는 부작용이 있어, 열기 전 걸음은 복제본으로 본다. */
function nextFieldStepPeek(g: Game): string {
  return nextFieldStep(cloneGame(g));
}

function main(): void {
  const out = process.argv[2] ? resolve(process.argv[2]) : resolve(here, '../../s2/tests/game/fixtures/field_port/field_vectors.json');
  const cases = [];
  for (const seed of SEEDS) for (const [r, d, h] of PAIRS) cases.push(runCase(seed, r, d, h));
  const contracts = SEEDS.flatMap(seed => [contractCase(seed, false), contractCase(seed, true)]);
  const tables = {
    COMMS, COMM_NAME, P, STAGES, IDEO, LAWS, LAW_VARIANT_OF, CORPSE_LAWS, PROLOGUE, FIELD,
    PROFILES: PROFILES.map(p => ({ id: p.id, name: p.name, community: p.community, age: p.age })),
  };
  const file = {
    format: FORMAT,
    note: 'S1 TS가 낸 참값. 다시 뽑기: cd s1 && npx tsx tools/field_port_fixtures.ts. 사례마다 단계의 입력은 앞 단계 after다(votes의 입력은 open.after에서 council.idx만 바꾼 것).',
    departures: Object.fromEntries([...new Set(PAIRS.map(p => p[1]))].map(n => [n, read(n)])),
    receipts: Object.fromEntries([...new Set(PAIRS.map(p => p[0]))].map(n => [n, read(n)])),
    tables: plain(tables),
    cases,
    contracts,
  };
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, `${JSON.stringify(file)}\n`);
  const votes = cases.reduce((n, c) => n + c.votes.length, 0);
  const arrivals = cases.filter(c => c.arrival).length;
  console.log(`${out}: 사례 ${cases.length}, 표결 ${votes}, 도착 ${arrivals}, 계약 ${contracts.length}, ${Buffer.byteLength(JSON.stringify(file))}바이트`);
}

main();
