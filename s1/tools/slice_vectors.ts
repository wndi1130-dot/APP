// 세로 조각(slice_flow.gd)의 시작 판과 맞대기 표본(S1 쪽). 규칙은 S1을 그대로 부르고 셈을 여기서 다시 적지 않는다.
// 사용: node s2/.godot/turn_port_2_loader.mjs 꼴의 로더로 이 파일을 돌린다(또는 npx tsx tools/slice_vectors.ts).
//
// 1) s2/game/train/slice_start.json: 조각이 여는 판(createGame 그대로)과 S1 상수 표. 게임이 읽는 자산이다(시험 표본이 아니다).
// 2) s2/tests/fixtures/train/slice_vectors.json: 그 판에서 조각이 밟는 차례(첫 정차까지 → 출발 계약 → 영수증 반영 → 특별 회기 →
//    표결 → 회기 닫기 → 둘째 역 → 끝)를 S1이 직접 낸 전/후. 같은 계약에 영수증 셋(가져옴 많음 / 빈손 / 사람 하나 잃음)을 넣어
//    서로 다른 회기·둘째 역이 나오는지 본다(s3_departure_receipt_contract.md 5장, J01 받아들임).
// 정차는 필드가 대신 나가므로 resolveStop을 부르지 않는다. 열차 서류는 조각에 화면이 없어 걸음마다 비운다(field_arrival.test.ts slice()와 같다).

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as S1 from '../src/game';
import type { Game } from '../src/game';
import { applyFieldReturn, snapshot } from '../src/game/field_receipt';
import { buildDeparture } from '../src/game/field_departure';
import type { FieldDepartureV2 } from '../src/game/field_departure';
import { leaveSpecialCouncil, nextFieldStep, specialCandidates, specialReasons } from '../src/game/field_council';
import { arrivalSummary, endCard, finishSlice, secondStationReached } from '../src/game/field_arrival';
import { tables } from './turn_port_fixtures';

export const SEED = 'slice-seed-a';
export const PLACE_ID = 'sulechow_station';
const plain = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T;
const clear = (g: Game) => { g.cards = []; };
const step = (g: Game) => { clear(g); S1.advance(g); clear(g); };

/** 조각의 첫 정차에 선 판(정차를 풀기 전): 2구간으로 두고 두 걸음. */
export function firstStop(g: Game): Game {
  g.seg = 2;
  step(g); step(g);
  return g;
}

type Case = { name: string; stock: Record<string, number>; dead: number[]; injured: number[]; witnessed: boolean };
const CASES: Case[] = [
  { name: 'haul', stock: { coal: 6, wood: 4, food: 3 }, dead: [], injured: [], witnessed: true },
  { name: 'empty', stock: {}, dead: [], injured: [1], witnessed: false },
  { name: 'loss', stock: { coal: 2 }, dead: [1], injured: [2], witnessed: true },
];

/** 계약에 맞춘 판 5 영수증. 수색대 전부 + 운송조 둘이 나가고, dead·injured는 수색대 자리 번호다. */
function receiptOf(d: FieldDepartureV2, c: Case): Record<string, unknown> {
  const carriers = d.workCrew.filter(p => p.role === 'carrier').slice(0, 2).map(p => p.id);
  const sent = [...d.roster.map(p => p.id), ...carriers];
  const dead = c.dead.map(i => d.roster[i].id);
  const injured = c.injured.map(i => d.roster[i].id);
  const back = sent.filter(id => !dead.includes(id));
  const everyone = [...d.roster, ...d.workCrew];
  return {
    version: 5, receiptId: `ret_${d.placeId}_${d.segment}_${c.name}`, departureId: d.departureId, stopId: d.stopId, source: 'direct', endReason: 'departed',
    place: { id: d.placeId, type: 'freight', variant: 's2_graybox' },
    time: { arrive: 'D1 10:30', depart: 'D1 12:40', stayGameMinutes: 130 },
    stock: c.stock, items: { gained: [], lost: [] },
    people: {
      sent, injured, bitten: [], dead, missing: [], leftBehind: [], rescued: [],
      wounds: injured.map(id => ({ person: id, part: 'leg_right', kind: 'laceration', treat: { disinfected: true, bandaged: true } })),
    },
    witnessed: [], placeState: { looted: 0.3, remainingRisk: 2 }, promises: [],
    goal: { kind: 'coal', required: 4, earned: Number(c.stock.coal ?? 0), status: Number(c.stock.coal ?? 0) >= 4 ? 'done' : Number(c.stock.coal ?? 0) > 0 ? 'part' : 'retreat' },
    extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
    symbol: null,
    fieldPromises: d.promises.map(p => ({ id: p.id, kind: p.kind, witnesses: c.witnessed ? back.slice(0, 1) : [] })),
    crew: back.map(id => ({
      person: id, exhaustion: injured.includes(id) ? 1 : 0, hunger: 0, bodyUse: {},
      gearBack: { hands: everyone.find(p => p.id === id)!.gear.hands.map(h => [...h]), items: {} },
    })),
    defense: null,
  };
}

function runCase(start: Game, departure: FieldDepartureV2, c: Case) {
  const g = S1.cloneGame(start);
  const receipt = receiptOf(departure, c);
  const applied = applyFieldReturn(g, departure, receipt);
  const apply = { status: applied.status, record: plain(applied.record), after: plain(g) };
  const regular = plain(S1.agendaOptions(g));
  const nextStep = nextFieldStep(g);
  const opened = plain(g);
  const rec = g.fieldReturns!.records[0];
  const candidates = g.fieldReturns?.special?.status === 'opened' ? plain(specialCandidates(g, rec)) : [];
  const reasons = plain(specialReasons(g));
  let vote = null;
  let left = null;
  if (nextStep === 'council') {
    const result = S1.castVote(g);
    vote = { result: plain(result), after: plain(g) };
    const ok = leaveSpecialCouncil(g);
    left = { left: ok, after: plain(g) };
  }
  // 둘째 역까지 S1 열차 턴으로 달린다. 걸음마다 전/후를 남긴다.
  const steps = [];
  for (let i = 0; i < 12 && !secondStationReached(g) && g.phase !== 'end'; i += 1) {
    const before = plain(g);
    step(g);
    steps.push({ before, after: plain(g) });
  }
  let arrival = null;
  if (secondStationReached(g)) {
    const state = plain(g);
    const sections = plain(arrivalSummary(g));
    const card = plain(endCard(g));
    const finished = finishSlice(g);
    arrival = { state, now: plain(snapshot(g)), sections, endCard: card, finished, after: plain(g) };
  }
  return { name: c.name, receipt, apply, regular, nextStep, opened, candidates, reasons, vote, left, steps, arrival };
}

export function sliceVectors() {
  const t = tables();
  const start0 = S1.createGame(SEED);
  // 조각의 열차는 바깥 기온을 읽는다(S1 내정 판 domestic.ts와 같다, 결정 370·423): 계절표 단계가 난방 석탄과 온기를 움직인다.
  // 조각이 닿는 구간(서막 2~4)에는 결빙이 서지 않는다(추워지는 출발이 없다). 결빙은 S2에 아직 없다(train_climate.gd).
  S1.enableClimate(start0);
  const startAsset = { format: 'slice-start-v1', seed: SEED, placeId: PLACE_ID, state: plain(start0), tables: t };
  const g = firstStop(S1.cloneGame(start0));
  const stop = plain(g);
  const departure = plain(buildDeparture(g, { placeId: PLACE_ID }));
  const cases = CASES.map(c => runCase(g, departure, c));
  return { startAsset, vectors: { format: 'slice-vectors-v1', seed: SEED, placeId: PLACE_ID, stop, departure, cases } };
}

function writeIfChanged(path: string, data: unknown): { bytes: number; identical: boolean } {
  const bytes = Buffer.from(`${JSON.stringify(data)}\n`, 'utf8');
  mkdirSync(dirname(path), { recursive: true });
  let identical = false;
  try { identical = readFileSync(path).equals(bytes); } catch { /* 첫 실행 */ }
  if (!identical) writeFileSync(path, bytes);
  return { bytes: bytes.length, identical };
}

function main(): void {
  const root = resolve(import.meta.dirname, '../..');
  const { startAsset, vectors } = sliceVectors();
  const a = writeIfChanged(resolve(root, 's2/game/train/slice_start.json'), startAsset);
  const v = writeIfChanged(resolve(root, 's2/tests/fixtures/train/slice_vectors.json'), vectors);
  console.log(JSON.stringify({
    start: a, vectors: v, promises: vectors.departure.promises.length,
    cases: vectors.cases.map(c => ({ name: c.name, nextStep: c.nextStep, candidates: c.candidates.length, steps: c.steps.length, arrived: !!c.arrival })),
  }));
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) main();
