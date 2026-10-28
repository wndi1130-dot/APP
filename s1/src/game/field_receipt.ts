import Ajv2020 from 'ajv/dist/2020.js';
import commonSchema from '../../schema/common.schema.json';
import placeSchema from '../../schema/place.schema.json';
import chronicleSchema from '../../schema/chronicle.schema.json';
import receiptSchema from '../../schema/receipt.schema.json';
import { bump, bumpRel } from './ledger';
import { addSupplies } from './supplies';
import { COMMS, COMM_NAME, LOOT_NAME, PLACES, REP_AGE, STAY, TRAIT_BAN, TRAITS } from './data';
import type { Comm, LootKey } from './data';
import { onDeath } from './death';
import { repGone } from './dark/state';
import { PROLOGUE } from './prologue';
import { hangWhy, hangSymbol } from './domestic/symbols';
import { drawPerson, isGone, journal, pick, PROFILES, situation, storyOf } from './state';
import type { Game, LootDeck, Phase } from './state';
import { breakPromise, burnPyre, checkStopPromises, crewAwayOf, crewRest, keepPromise, noteTarget } from './turn';
import { noteBroken } from './council_log';
import { canonical, decodeReceipt, v3Schema } from './stop_receipt';
import type { StopReceipt } from './stop_receipt';
import { CAPTAIN, recordFieldWound } from './wounds';
import type { Wound, WoundGrade, WoundPart } from './wounds';
import type { FieldDepartureV2 } from './field_departure';

/** 명부 밖의 열차장 id 하나(출발 계약·영수증의 사람 id). 열차 명부의 부상 기록은 이름(CAPTAIN)으로 남는다. */
export const CAPTAIN_ID = 'captain';
const CAPTAIN_COMM: Comm = 'front';

// S3 연결의 영수증 계약(구현명세 S3 연결 v1 2절, 결정 294·301·302·304).
// 열차가 필드에 넘기는 「출발 명세」와 필드가 돌려주는 「귀환 영수증」(판 4)을 따로 둔다.
// 필드는 일어난 일만 적는다(누가 나갔고 누가 돌아왔고 무엇을 들고 왔고 약속을 누가 봤나). 약속의 지킴·어김·알 수 없음과
// 상징물의 쓰임은 열차가 정한다. 그래서 같은 영수증을 두 번 받아도, 자동 풀이가 만든 영수증이어도 판정은 한 길이다.
// 남겨진 대표를 이을 때만 난수를 쓴다(사용자 답 2026-10-29). 주사위 정차만 도는 판(봇·시뮬)은 이 길을 지나지 않는다.

export const FIELD_PROMISE_KINDS = ['prologue', 'skip_dispatch'] as const;
export type FieldPromiseKind = typeof FIELD_PROMISE_KINDS[number];
export type PromiseVerdict = 'kept' | 'broken' | 'unknown';
export const SYMBOL_USES = ['hang_before_session', 'hang_in_car'] as const;
export type SymbolUse = typeof SYMBOL_USES[number];

/** 값 자리(가안, 사용자 확인 전). 결정 407 A4(사용자): 네 사례가 더 갈리게 다시 잡았다. 내걸기 +10이면 지킴 판의 꼬리칸이 의심 띠를 벗어난다. 네 사례 표는 tools/field_slice_table.ts. */
export const FIELD: Readonly<Record<'hangRel' | 'symbolLean' | 'symbolRel' | 'promiseLean' | 'pressLean' | 'promiseTrust' | 'promiseRel', number>> = Object.freeze({
  /** 특별 회기 앞에 내건 상징물이 그 집단 관계를 한 번 바꾸는 폭(hang_relation_delta) */
  hangRel: 10,
  /** 특별 회기 상징물 안건(field_council.ts): 상징물 주인 칸의 물질 입장, 가결·부결 때 그 칸 관계 ± */
  symbolLean: 3,
  symbolRel: 5,
  /** 특별 회기 약속 안건: 약속받은 칸의 물질 입장, 가결 때 신임 ±(지킴이면 +, 어김 추궁이면 −), 어김 추궁의 가결·부결 때 그 칸 관계 ± */
  promiseLean: 2,
  /** 어김 추궁 안건에서 약속받은 칸의 물질 입장(따지는 쪽이라 지킴 기록보다 세게 민다) */
  pressLean: 4,
  promiseTrust: 3,
  promiseRel: 5,
});

/** 열차가 필드에 넘기는 약속 하나. subjects는 서막 약속이 데려오기로 한 사람(프로필 id)이다. */
export interface FieldPromiseSpec { id: string; kind: FieldPromiseKind; madeTo: Comm; label: string; subjects: string[] }
/** 출발 명세(열차 → 필드). 정차·명단·약속은 나가기 전에 정해지고 귀환에서 바뀌지 않는다(s3_first_trial_scope 4절 「출발 명세와 귀환 결과」). */
export interface FieldDeparture {
  version: 1;
  departureId: string;
  stopId: string;
  placeId: string;
  segment: number;
  /** 나가는 사람(프로필 id)과 그 칸 */
  roster: { id: string; comm: Comm }[];
  promises: FieldPromiseSpec[];
  /** 내정을 켠 판인가(상징물 「걸어 두기」를 고를 수 있나) */
  domestic: boolean;
}
/** 영수증의 약속 칸: 그 약속을 본 사람과, 공동체가 들은 칸. 판정은 없다. */
export interface FieldPromiseSeen { id: string; kind: FieldPromiseKind; witnesses: string[]; heardBy: Comm[] }
export interface FieldSymbol { id: string; groupId: Comm; carriedBy: string }
type ReceiptV4 = Extract<StopReceipt, { version: 3 }> extends infer V3
  ? Omit<V3, 'version'> & { version: 4; departureId: string; symbol: FieldSymbol | null; fieldPromises: FieldPromiseSeen[] }
  : never;

// 판 5(docs/design/briefs/s3_departure_receipt_contract.md 3절) = 판 4 + 상처마다 처치 + 사람마다 끝 상태 + 열차 방어.
export const WOUND_TREATS = ['bandaged', 'disinfected', 'sutured', 'splinted', 'tourniquet', 'pulled', 'quick'] as const;
export type WoundTreat = Partial<Record<typeof WOUND_TREATS[number], true>>;
export interface FieldWound { person: string; part: string; kind: string; festering?: boolean; treat?: WoundTreat }
/** 살아서 열차에 오른 사람의 끝 상태. bodyUse는 쓰면 오르는 규칙이 들어올 자리(지금은 빈 칸). */
export interface FieldCrewRow {
  person: string;
  exhaustion: 0 | 1 | 2;
  hunger: 0 | 1 | 2;
  bodyUse: Record<string, number>;
  gearBack: { hands: [string, string, number][]; items: Record<string, number>; wear?: FieldWearBack };
}
/** 옷장 자리 옷 한 벌(파밍 손맛 줄기의 옷장 꼴). holes는 해진 부위. */
export interface FieldGarment { id: string; condition: number; holes?: Record<string, true> }
/** 입고 돌아온 옷장 자리 옷. "" = 맨몸, coat는 필드에서 주워 입은 긴 외투가 있을 때만. */
export interface FieldWearBack { jacket: FieldGarment | ''; hands: FieldGarment | ''; coat?: FieldGarment | '' }
/** 열차 방어(결정 416, 정차 소리 줄기가 채운다). 방어에 선 사람은 출발 명단이 아니라 열차에 남은 사람이다. */
export interface FieldDefense { held: boolean; people: string[]; hurt: string[]; dead: string[]; wounds: FieldWound[] }
export type FieldReceiptV5 = Omit<ReceiptV4, 'version'> & {
  version: 5; crew: FieldCrewRow[]; defense: FieldDefense | null;
  /** 승강장에서 실은 옷장 자리 옷, 남은 미끼, 실은 음식의 이름별 개수(계약 글 3절). 없으면 빈 것 */
  wardrobeIn?: FieldGarment[]; luresBack?: Record<string, number>; foodIn?: Record<string, number>;
  /** 갈래별 보장 몫(덱)의 쓴 뒤 자리(결정 474 S1). 반영하면 판 상태 lootDeck을 이것으로 바꾼다 */
  lootDeck?: LootDeck;
};
export type FieldReceipt = ReceiptV4 | FieldReceiptV5;
/** 출발 계약 판 1(시험 표본) 또는 판 2(field_departure.ts buildDeparture). */
export type AnyDeparture = FieldDeparture | FieldDepartureV2;

export interface FieldVerdict { id: string; kind: FieldPromiseKind; madeTo: Comm; verdict: PromiseVerdict; witnessesBack: string[] }
export interface FieldSnapshot {
  trust: number; tension: number; coal: number; food: number; med: number; lux: number; symbols: number; injured: number;
  rel: Record<Comm, number>; pop: Record<Comm, number>;
  /** 칸마다 처지의 온기(situation 첫 값, 0~100 반올림). 도착 화면의 「온기」 */
  warm: Record<Comm, number>;
}
/** 반영의 까닭 한 줄. 도착 화면과 회기 전망이 이 줄을 그대로 읽는다(화면은 상태를 바꾸지 않는다). */
export interface FieldLine { k: 'stock' | 'people' | 'promise' | 'symbol'; comm?: Comm; text: string }
/** 귀환 한 번의 반영 기록: 반영 전과 후, 판정, 상징물 쓰임. */
export interface FieldReturnRecord {
  receiptId: string;
  departureId: string;
  stopId: string;
  seg: number;
  verdicts: FieldVerdict[];
  /** 이 정차에서 죽은 사람(이름). 특별 회기의 시신 안건 후보를 가른다 */
  dead: string[];
  symbol: (FieldSymbol & { use: SymbolUse | null }) | null;
  before: FieldSnapshot;
  after: FieldSnapshot;
  lines: FieldLine[];
  /** 이 정차에 나간 사람(영수증 people.sent). 다음 출발의 근육통·휴식이 읽는다(field_departure.ts) */
  sent?: string[];
  /** 판 5의 끝 상태(살아서 오른 사람) */
  crew?: FieldCrewRow[];
}
export interface FieldReturns {
  /** 반영한 영수증 id → 정규화한 내용. 같은 id가 다시 오면 내용을 견주고 아무것도 하지 않는다(T07·T08). */
  applied: Record<string, string>;
  records: FieldReturnRecord[];
  /** 첫 귀환 뒤의 특별 회기 한 번(결정 290·303, field_council.ts). 있으면 다시 열지 않는다 */
  special?: SpecialCouncilRecord;
  /** 둘째 역에 닿아 끝 카드로 닫은 구간(field_arrival.ts finishSlice) */
  arrived?: { seg: number };
}
/** 특별 회기 기록: 어느 귀환 뒤에 열렸고, 무엇이 후보였고, 무엇을 골라 어떻게 됐나. 도착 화면이 이 기록을 읽는다. */
export interface SpecialCouncilRecord {
  receiptId: string;
  seg: number;
  /** 열린 회기(opened), 의회가 닫혀(계엄) 또는 올릴 안건이 없어 열지 못함(skipped) */
  status: 'opened' | 'skipped';
  why?: string;
  /** 후보 안건 제목과 그 출처(receipt: 영수증에서 뽑힘, regular: 보통 안건으로 채움) */
  candidates: { title: string; from: 'corpse' | 'symbol' | 'promise' | 'regular' }[];
  /** 회기에서 돌아갈 단계 */
  back: Exclude<Phase, 'council' | 'end'>;
  picked?: string;
  result?: { yes: number; no: number; need: number; passed: boolean };
  before?: FieldSnapshot;
  after?: FieldSnapshot;
}

const id = { $ref: 'urn:s1:schema:common#/$defs/id' };
const ids = { type: 'array', items: id, uniqueItems: true };
const comm = { enum: [...COMMS] };
const object = (properties: Record<string, unknown>, required = Object.keys(properties)) =>
  ({ type: 'object', properties, required, additionalProperties: false });
// 판 4 = 판 3 + 출발 id·상징물·약속 칸. 판 3의 꼴은 stop_receipt.ts에서 그대로 가져온다.
const v4Schema = {
  ...v3Schema, $id: 'urn:s1:prep:field-receipt-v4',
  properties: {
    ...v3Schema.properties, version: { const: 4 }, departureId: id,
    symbol: { anyOf: [{ type: 'null' }, object({ id, groupId: comm, carriedBy: id })] },
    fieldPromises: { type: 'array', items: object({
      id, kind: { enum: [...FIELD_PROMISE_KINDS] }, witnesses: ids, heardBy: { type: 'array', items: comm, uniqueItems: true },
    }) },
  },
  required: [...v3Schema.required, 'departureId', 'symbol', 'fieldPromises'],
};
const level = { enum: [0, 1, 2] };
const handRow = { type: 'array', prefixItems: [{ type: 'string' }, { type: 'string' }, { type: 'number' }], minItems: 3, maxItems: 3 };
const count = { type: 'integer', minimum: 0 };
const counts = { type: 'object', additionalProperties: count };
const treat = { type: 'object', properties: Object.fromEntries(WOUND_TREATS.map(k => [k, { const: true }])), additionalProperties: false };
const woundV5 = { ...receiptSchema.$defs.wound, properties: { ...receiptSchema.$defs.wound.properties, treat } };
const garment = object({
  id, condition: { type: 'number', minimum: 0, maximum: 1 },
  holes: { type: 'object', additionalProperties: { const: true } },
}, ['id', 'condition']);
const wearSlot = { anyOf: [{ const: '' }, garment] };
const wearBack = object({ jacket: wearSlot, hands: wearSlot, coat: wearSlot }, ['jacket', 'hands']);
const v5Schema = {
  ...v4Schema, $id: 'urn:s1:prep:field-receipt-v5',
  $defs: { ...receiptSchema.$defs, wound: woundV5 },
  properties: {
    ...v4Schema.properties, version: { const: 5 },
    crew: { type: 'array', items: object({
      person: id, exhaustion: level, hunger: level, bodyUse: { type: 'object', additionalProperties: { type: 'number', minimum: 0 } },
      gearBack: object({ hands: { type: 'array', items: handRow }, items: counts, wear: wearBack }, ['hands', 'items']),
    }) },
    defense: { anyOf: [{ type: 'null' }, object({ held: { type: 'boolean' }, people: ids, hurt: ids, dead: ids, wounds: { type: 'array', items: woundV5 } })] },
    wardrobeIn: { type: 'array', items: garment },
    luresBack: counts,
    foodIn: counts,
    lootDeck: { type: 'object', additionalProperties: object({ n: count, k: count, seen: count, hit: count }) },
  },
  required: [...v4Schema.required, 'crew', 'defense'],
};
const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
for (const schema of [commonSchema, placeSchema, chronicleSchema, receiptSchema]) ajv.addSchema(schema);
const v4Validator = ajv.compile(v4Schema);
const v5Validator = ajv.compile(v5Schema);

/** 판 4·5 영수증을 검사하고 독립 사본으로 돌려준다. 판 3의 검사(목표·문서)는 판 번호만 바꿔 그대로 거친다. 오류에는 본문을 싣지 않는다. */
export function decodeFieldReceipt(input: unknown): FieldReceipt {
  const value: unknown = typeof input === 'string' ? JSON.parse(input) : input;
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('영수증은 객체여야 한다');
  const record = value as Record<string, unknown>;
  const ok = record.version === 4 ? v4Validator(record) : record.version === 5 ? v5Validator(record) : false;
  if (!ok) throw new Error('필드 영수증 계약이 올바르지 않다');
  const { departureId: _d, symbol: _s, fieldPromises: _p, crew: _c, defense: _f, wardrobeIn: _w, luresBack: _l, foodIn: _fi, lootDeck: _ld, ...rest } = record;
  // 판 3 검사는 처치 칸을 모른다: 상처 줄에서 처치만 떼어 넘긴다(검사만, 돌려주는 값은 그대로).
  const people = rest.people as { wounds?: Record<string, unknown>[] };
  const bare = people.wounds ? { ...people, wounds: people.wounds.map(({ treat: _t, ...w }) => w) } : people;
  decodeReceipt({ ...rest, people: bare, version: 3 });
  const receipt = structuredClone(record) as unknown as FieldReceipt;
  if (receipt.symbol && (receipt.stock.symbol ?? 0) < 1) throw new Error('상징물을 들고 왔는데 장부에 없다');
  if (new Set(receipt.fieldPromises.map(p => p.id)).size !== receipt.fieldPromises.length) throw new Error('영수증에 같은 약속이 두 번 있다');
  return receipt;
}

/** 나갈 수 있는 사람 전부: 판 1은 명단, 판 2는 수색대와 작업조. */
export function departurePeople(d: AnyDeparture): { id: string; comm: Comm }[] {
  return d.version === 2 ? [...d.roster, ...d.workCrew] : d.roster;
}

/** 출발 명세의 모양을 본다. */
export function checkDeparture(d: AnyDeparture): void {
  const re = /^[a-z][a-z0-9_]*$/;
  const okId = (v: unknown) => typeof v === 'string' && re.test(v);
  if ((d.version !== 1 && d.version !== 2) || ![d.departureId, d.stopId, d.placeId].every(okId) || !Number.isSafeInteger(d.segment) || d.segment < 0) {
    throw new Error('출발 명세가 올바르지 않다');
  }
  const people = departurePeople(d);
  if (!people.every(r => okId(r.id) && COMMS.includes(r.comm)) || new Set(people.map(r => r.id)).size !== people.length) {
    throw new Error('출발 명단이 올바르지 않다');
  }
  for (const p of d.promises) {
    if (!okId(p.id) || !FIELD_PROMISE_KINDS.includes(p.kind) || !COMMS.includes(p.madeTo) || !p.subjects.every(okId)) {
      throw new Error('출발 약속이 올바르지 않다');
    }
  }
  if (new Set(d.promises.map(p => p.id)).size !== d.promises.length) throw new Error('출발 약속 id가 겹친다');
}

/** 살아서 열차에 오른 사람: 나간 사람과 구한 사람 가운데 죽거나 사라지거나 남겨지지 않은 사람. */
export function returnedOf(r: FieldReceipt): string[] {
  const gone = new Set([...r.people.dead, ...r.people.missing, ...r.people.leftBehind]);
  return [...new Set([...r.people.sent, ...r.people.rescued])].filter(p => !gone.has(p));
}

/**
 * 약속 판정(결정 301·304). 본 사람이 한 명도 돌아오지 못했으면 알 수 없음이다(사람이 돌아와야 말이 돌아온다).
 * 한 명이라도 돌아왔으면 그 사람들 기준으로 증거를 본다.
 * - 서막 약속: 데려오기로 한 사람이 모두 살아서 열차에 올랐으면 지킴, 하나라도 못 오르면 어김.
 * - 교대 약속: 실제로 나간 사람(판 1은 출발 명단, 판 2는 불린 작업조까지) 가운데 약속받은 칸 사람이 없으면 지킴, 있으면 어김.
 */
export function judgePromises(d: AnyDeparture, r: FieldReceipt): FieldVerdict[] {
  const back = new Set(returnedOf(r));
  const went = d.version === 2 ? departurePeople(d).filter(x => r.people.sent.includes(x.id)) : d.roster;
  return d.promises.map(p => {
    const seen = r.fieldPromises.find(x => x.id === p.id);
    const witnessesBack = (seen?.witnesses ?? []).filter(w => back.has(w));
    let verdict: PromiseVerdict;
    if (witnessesBack.length === 0) verdict = 'unknown';
    else if (p.kind === 'prologue') verdict = p.subjects.every(s => back.has(s)) ? 'kept' : 'broken';
    else verdict = went.some(x => x.comm === p.madeTo) ? 'broken' : 'kept';
    return { id: p.id, kind: p.kind, madeTo: p.madeTo, verdict, witnessesBack };
  });
}

/**
 * 영수증이 출발 명세와 같은 정차·같은 명단·같은 약속을 말하는지 본다.
 * 판 1은 나간 사람이 명단과 똑같아야 하고, 판 2는 수색대 전부에 불린 작업조만 더할 수 있다.
 */
export function matchDeparture(d: AnyDeparture, r: FieldReceipt): void {
  if (r.departureId !== d.departureId || r.stopId !== d.stopId || r.place.id !== d.placeId) throw new Error('출발 명세와 영수증의 정차가 다르다');
  const sent = new Set(r.people.sent);
  const may = new Set(departurePeople(d).map(x => x.id));
  const exact = d.version === 1 && sent.size !== d.roster.length;
  if (exact || d.roster.some(x => !sent.has(x.id)) || [...sent].some(x => !may.has(x))) throw new Error('출발 명단과 영수증의 명단이 다르다');
  const want = new Set(d.promises.map(p => p.id));
  if (r.fieldPromises.length !== want.size || r.fieldPromises.some(p => !want.has(p.id) || d.promises.find(q => q.id === p.id)!.kind !== p.kind)) {
    throw new Error('출발 약속과 영수증의 약속이 다르다');
  }
  if (r.symbol && !returnedOf(r).includes(r.symbol.carriedBy)) throw new Error('상징물을 든 사람이 열차에 오르지 않았다');
}

export function snapshot(g: Game): FieldSnapshot {
  return {
    trust: g.trust, tension: g.tension, coal: g.coal, food: g.food, med: g.med, lux: g.lux, symbols: g.symbols, injured: g.injured,
    rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>,
    pop: Object.fromEntries(COMMS.map(c => [c, g.comms[c].pop])) as Record<Comm, number>,
    warm: Object.fromEntries(COMMS.map(c => [c, Math.round(situation(g, c)[0])])) as Record<Comm, number>,
  };
}

/** 프로필 id → 이름·칸. 열차장은 CAPTAIN·앞칸, 모르는 id는 명단의 칸으로 읽고 이름은 id 그대로 둔다. */
function personOf(d: AnyDeparture, pid: string): { name: string; comm: Comm } {
  if (pid === CAPTAIN_ID) return { name: CAPTAIN, comm: CAPTAIN_COMM };
  const p = PROFILES.find(x => x.id === pid);
  return { name: p?.name ?? pid, comm: p?.community ?? departurePeople(d).find(x => x.id === pid)?.comm ?? 'tail' };
}

function byComm(d: AnyDeparture, list: readonly string[]): Map<Comm, string[]> {
  const out = new Map<Comm, string[]>();
  for (const pid of list) {
    const { name, comm } = personOf(d, pid);
    out.set(comm, [...(out.get(comm) ?? []), name]);
  }
  return out;
}

export type FieldApplyStatus = 'applied' | 'duplicate';

/** 귀환 반영 끝에 붙는 자리. memory.ts를 불러오면 채워진다(그 파일이 이 파일을 읽으니 import 순환을 피한다). 같은 귀환이 두 번 오면 부르지 않는다. */
export const RETURN_HOOK: { after?: (g: Game, departure: AnyDeparture, r: FieldReceipt) => void } = {};

/**
 * 귀환 한 번을 판에 반영한다. 같은 영수증 id가 다시 오면(앱을 껐다 켜서 또 받아도) 아무것도 하지 않고 'duplicate'다(확인 줄 9, T07·T08).
 * 같은 id에 다른 내용이 오면 판을 건드리지 않고 오류로 알린다. 검사가 모두 끝난 뒤에만 판을 바꾼다.
 * 차례: 물자 → 사람 → 약속. 상징물은 장부에만 넣고 쓰임은 chooseSymbolUse로 따로 고른다(결정 302).
 */
/** 필드 상처 부위 → 열차 명부 부위(s3_departure_receipt_contract.md 4절). 손은 팔, 발은 다리에 묶여 있다. */
export const FIELD_PART: Readonly<Record<string, WoundPart>> = Object.freeze({
  head_neck: 'head', torso: 'torso', arm_left: 'armL', arm_right: 'armR', leg_left: 'legL', leg_right: 'legR',
});
const LIMB_PARTS: readonly WoundPart[] = ['armL', 'armR', 'legL', 'legR'];

/**
 * 부상자 한 사람의 열차 기록 하나(J02, 몸과 부상 4.1·4.6). 필드가 적은 상처 줄에서 가장 무거운 것이 등급·부위가 되고, 나머지는 field 칸에 붙는다.
 * - 절단 → 절단. 무엇보다 무겁다. 필드는 팔·다리만 자른다(영수증도 팔·다리만 받는다).
 * - 골절 → 골절. 빠른 처치로 부목을 댔으면 가벼운 상처(4장 「빠른 처치」). 팔다리가 아닌 골절은 깊은 상처로 친다(열차의 골절은 팔다리뿐).
 * - 깊은 상처·박힌 것 → 깊은 상처.
 * - 긁힘·찢김뿐인데 부상자 목록에 든 사람(출혈 심함·쓰러짐) → 깊은 상처(결정 카드 C, 2026-10-25 사용자 답). 상처 줄이 없으면 몸통.
 * - 곪음은 그 사람의 상처 줄 가운데 하나라도 곪았으면. 아무것도 굴리지 않는다.
 */
export function fieldWoundOf(rows: readonly FieldWound[], pid: string): { grade: WoundGrade; part: WoundPart; septic: boolean; field: NonNullable<Wound['field']> } {
  const mine = rows.filter(w => w.person === pid);
  const quick = (w: FieldWound) => !!(w.treat?.splinted && w.treat?.quick);
  const rank = (w: FieldWound) => w.kind === 'amputation' ? 3 : w.kind === 'fracture' ? (quick(w) ? 0.5 : 2) : w.kind === 'deep' || w.kind === 'embedded' ? 1 : 0;
  let top: FieldWound | undefined;
  for (const w of mine) if (!top || rank(w) > rank(top)) top = w;
  const part = top ? FIELD_PART[top.part] ?? 'torso' : 'torso';
  let grade: WoundGrade = !top ? 'deep' : rank(top) === 3 ? 'amputation' : rank(top) === 2 ? 'fracture' : rank(top) === 0.5 ? 'light' : 'deep';
  if ((grade === 'fracture' || grade === 'amputation') && !LIMB_PARTS.includes(part)) grade = 'deep';
  return { grade, part, septic: mine.some(w => !!w.festering), field: mine.map(({ person: _p, ...w }) => w) };
}

export function applyFieldReturn(g: Game, departure: AnyDeparture, input: unknown): { status: FieldApplyStatus; record: FieldReturnRecord } {
  const r = decodeFieldReceipt(input);
  const fingerprint = canonical(r);
  const known = g.fieldReturns?.applied[r.receiptId];
  if (known !== undefined) {
    if (known !== fingerprint) throw new Error('같은 귀환 id에 다른 영수증이 왔다');
    return { status: 'duplicate', record: g.fieldReturns!.records.find(x => x.receiptId === r.receiptId)! };
  }
  checkDeparture(departure);
  matchDeparture(departure, r);
  if (g.fieldReturns?.records.some(x => x.stopId === r.stopId || x.departureId === r.departureId)) throw new Error('이미 반영한 정차에 다른 영수증이 왔다');
  const verdicts = judgePromises(departure, r);

  const before = snapshot(g);
  const lines: FieldLine[] = [];
  // 물자: 영수증 장부 증감을 그대로 더한다. 석탄은 쓴 몫을 이미 뺀 값이다.
  // 잔액보다 큰 음수는 0에서 멈추고(시작 + 순증감 = 잔액, 모자라면 0과 부족분) 귀환 줄에 부족분을 적는다.
  const s = r.stock;
  const have: Partial<Record<keyof typeof s, number>> = {
    coal: g.coal, food: g.food, medicine: g.med, luxury: g.lux, ...(g.dom ? { wood: g.dom.wood, scrap: g.dom.scrap, parts: g.dom.parts } : {}),
    ...(g.supOn ? { supplies: g.sup ?? 0 } : {}),
  };
  if (s.coal) bump(g, 'coal', s.coal, 'field.loot', { floor0: true });
  if (s.food) bump(g, 'food', s.food, 'field.loot', { floor0: true });
  if (s.medicine) bump(g, 'med', s.medicine, 'field.loot', { floor0: true });
  if (s.luxury) bump(g, 'lux', s.luxury, 'field.loot', { floor0: true });
  if (s.supplies) addSupplies(g, s.supplies, 'field.loot'); // 꺼진 판에서는 천처럼 받아도 재고에 담지 않는다
  if (s.symbol) g.symbols = Math.max(0, g.symbols + s.symbol);
  if (g.dom) {
    if (s.wood) g.dom.wood = Math.max(0, g.dom.wood + s.wood);
    if (s.scrap) g.dom.scrap = Math.max(0, g.dom.scrap + s.scrap);
    if (s.parts) g.dom.parts = Math.max(0, g.dom.parts + s.parts);
    // 천(cloth)은 S1 내정 그릇에 칸이 없다: 받기만 하고 S2 열차(train_dom.gd)가 담는다(결정 426 D②).
  }
  // 덱의 자리(결정 474 S1): 필드가 쓴 뒤 자리를 그대로 들고 다음 정차 계약에 싣는다 — 정차를 넘어 n곳마다 정확히 k곳.
  if (r.version === 5 && r.lootDeck) g.lootDeck = structuredClone(r.lootDeck);
  const got = ([['coal', '석탄'], ['food', '식량'], ['medicine', '의약품'], ['luxury', '사치품'], ['supplies', '생필품'], ['wood', '목재'], ['scrap', '고철'], ['parts', '부품']] as const)
    .filter(([k]) => s[k] && (k !== 'supplies' || g.supOn)).map(([k, name]) => {
      const lack = have[k] === undefined ? 0 : Math.max(0, -(have[k]! + s[k]!));
      return `${name} ${s[k]! > 0 ? '+' : ''}${s[k]}${lack > 0 ? ` (모자라 0, 부족 ${lack})` : ''}`;
    });
  if (got.length) lines.push({ k: 'stock', text: got.join(', ') });

  // 사람: 죽음은 그 칸의 죽음으로, 크게 다친 사람은 부상으로, 남겨지거나 사라진 사람은 그 칸에서 빠진다.
  // 남긴 사람의 신임 값(결정 147)은 S1에 아직 규칙이 없어 기록만 한다(슬라이스의 대표 사례가 아니다, 결정 294).
  const place = r.place.id;
  for (const [c, names] of byComm(departure, r.people.dead)) {
    onDeath(g, c, names, 'other');
    lines.push({ k: 'people', comm: c, text: `${COMM_NAME[c]} ${names.join(', ')}이(가) 돌아오지 못했다(죽음).` });
  }
  const gone = new Set([...r.people.dead, ...r.people.missing, ...r.people.leftBehind]);
  // 크게 다친 사람: 필드가 적은 부위·종류·처치·곪음을 그대로 명부에 옮긴다(J02: 등급·부위를 다시 뽑지 않는다).
  const hurt = r.people.injured.filter(p => !gone.has(p));
  const rows = (r.people.wounds ?? []) as unknown as FieldWound[];
  const hurtBy = new Map<Comm, string[]>();
  for (const pid of hurt) {
    const c = personOf(departure, pid).comm;
    hurtBy.set(c, [...(hurtBy.get(c) ?? []), pid]);
  }
  for (const [c, pids] of hurtBy) {
    const names = pids.map(pid => personOf(departure, pid).name);
    g.injured += names.length;
    for (const pid of pids) {
      const { field, ...fw } = fieldWoundOf(rows, pid);
      recordFieldWound(g, { who: personOf(departure, pid).name, comm: c, from: 'stop', where: place, ...fw }, field);
    }
    lines.push({ k: 'people', comm: c, text: `${COMM_NAME[c]} ${names.join(', ')}이(가) 크게 다쳐 돌아왔다.` });
  }
  // 물린 채 돌아온 사람: 열차의 숨은 물림 규칙으로(2구간 안에 드러나거나 칸 안에서 일어난다, 결정 카드 C).
  for (const pid of r.people.bitten.filter(p => !gone.has(p))) {
    const { name, comm: c } = personOf(departure, pid);
    if ((g.hiddenBites ?? []).some(b => b.who === name)) continue;
    (g.hiddenBites ??= []).push({ who: name, comm: c, at: g.seg, due: g.seg + 2 });
    journal(g, `${name}이(가) 물린 채 돌아왔다. 아는 사람은 수색대뿐이다.`, 'dark');
    lines.push({ k: 'people', comm: c, text: `${COMM_NAME[c]} ${name}이(가) 물린 채 돌아왔다. 2구간 안에 드러나거나 일어난다.` });
  }
  const lost = [...r.people.leftBehind, ...r.people.missing].filter(p => !r.people.dead.includes(p));
  for (const [c, names] of byComm(departure, lost)) {
    g.comms[c].pop = Math.max(1, g.comms[c].pop - names.length);
    lines.push({ k: 'people', comm: c, text: `${COMM_NAME[c]} ${names.join(', ')}이(가) 필드에 남았다.` });
    journal(g, `${names.join(', ')}이(가) 필드에 남았다. 열차는 그들 없이 떠났다.`, 'dark');
  }
  // 앞 정차에 남았다가 살아서 구해져 돌아온 사람: 떠난 사람 명단에서 빼고 칸 인원으로 돌린다(서막 「기다렸다 태운다」와 같은 꼴).
  const rejoined = returnedOf(r).filter(p => p !== CAPTAIN_ID && r.people.rescued.includes(p) && (g.left ?? []).includes(personOf(departure, p).name));
  for (const [c, names] of byComm(departure, rejoined)) {
    g.left = (g.left ?? []).filter(n => !names.includes(n));
    g.comms[c].pop += names.length;
    lines.push({ k: 'people', comm: c, text: `${COMM_NAME[c]} ${names.join(', ')}이(가) 살아서 다시 열차에 올랐다.` });
    journal(g, `${names.join(', ')}이(가) 살아서 다시 열차에 올랐다.`, 'good');
  }

  // 약속: 지킴·어김은 기존 약속 규칙의 값을 그대로 쓴다(서막 어김은 신임 −4·관계 −10, 결정 184·저장소 119).
  // 알 수 없음은 신임·관계에 닿지 않고 일지 한 줄만 남는다(결정 304).
  for (const v of verdicts) {
    const spec = departure.promises.find(p => p.id === v.id)!;
    if (v.kind === 'prologue') storyOf(g).flags.depot_promise = v.verdict;
    const live = g.comms[v.madeTo].promise;
    const liveHere = v.kind === 'skip_dispatch' && live?.kind !== 'fetch' && live?.cond.kind === 'skip_dispatch';
    // 약속 규칙은 그 칸에 걸린 약속을 지운다. 이 판정이 그 약속의 것이 아니면(서막 약속, 거래로 맺지 않은 교대 약속) 걸린 약속은 그대로 둔다.
    const restore = () => { if (!liveHere) g.comms[v.madeTo].promise = live; };
    if (v.verdict === 'kept') {
      keepPromise(g, v.madeTo, spec.label);
      restore();
      lines.push({ k: 'promise', comm: v.madeTo, text: `${COMM_NAME[v.madeTo]}과(와)의 약속을 지켰다: ${spec.label}. 본 사람 ${v.witnessesBack.length}명이 돌아와 말했다.` });
    } else if (v.verdict === 'broken') {
      if (v.kind === 'prologue') breakPrologueVow(g, v.madeTo, spec.label);
      else breakPromise(g, v.madeTo, spec.label);
      restore();
      lines.push({ k: 'promise', comm: v.madeTo, text: `${COMM_NAME[v.madeTo]}과(와)의 약속을 어겼다: ${spec.label}. 본 사람 ${v.witnessesBack.length}명이 돌아와 말했다.` });
    } else {
      if (liveHere) g.comms[v.madeTo].promise = null;
      journal(g, `${spec.label}: 그 약속을 본 사람이 아무도 돌아오지 못했다. 지켰는지 어겼는지 열차는 모른다.`);
      lines.push({ k: 'promise', comm: v.madeTo, text: `${COMM_NAME[v.madeTo]}과(와)의 약속: 본 사람이 돌아오지 못해 알 수 없다.` });
    }
  }

  bodySearches(g, departure, r);
  residentScenes(g, departure, r);
  RETURN_HOOK.after?.(g, departure, r); // 사람 기억(memory.ts): 그 정차에서 사람마다 겪거나 본 일
  // 남겨지거나 사라진 사람은 떠난 사람 명단에도 넣는다: 다음 작업조와 열차 사람 판정(isGone)이 인구와 같은 사람을 본다.
  // 사람 기억이 이번 귀환의 가족을 찾은 뒤에 넣는다. 열차장은 제외하고, 전원을 먼저 넣어 함께 남겨진 사람이 후임으로 뽑히지 않게 한다.
  for (const pid of lost) {
    const name = personOf(departure, pid).name;
    if (pid !== CAPTAIN_ID && !isGone(g, name)) (g.left ??= []).push(name);
  }
  closeFieldStop(g, departure, r);
  // 사용자 답 2026-10-29: 남겨진 대표는 하차 명령처럼 그 칸의 다른 사람이 잇는다. 정차를 닫은 뒤에 잇는다:
  // 이번 정차가 기한인 그 칸 약속은 떠난 대표 앞에서 지킴·어김으로 먼저 판정하고, 새 대표는 약속 없이 시작한다.
  for (const pid of lost) {
    if (pid === CAPTAIN_ID) continue;
    const c = COMMS.find(c => g.comms[c].leader.personId === pid);
    if (!c) continue;
    if (g.dark) repGone(g, c, pid);
    else {
      const s = g.comms[c];
      const p = drawPerson(g, c, REP_AGE[c]);
      const traits = TRAITS.filter(t => t !== TRAIT_BAN[c] && t !== s.leader.trait);
      s.leader = { personId: p.id, name: p.name, age: p.age, trait: pick(g, traits), traitShown: 0 };
      s.sick = undefined;
      s.debt = false;
      s.promise = null;
      journal(g, `${p.name}이(가) ${COMM_NAME[c]} 대표 자리를 이었다.`, 'dark');
    }
  }
  if (r.symbol) {
    lines.push({ k: 'symbol', comm: r.symbol.groupId, text: `${COMM_NAME[r.symbol.groupId]}의 상징물을 가져왔다. 쓰임을 고른다.` });
  }
  const record: FieldReturnRecord = {
    receiptId: r.receiptId, departureId: r.departureId, stopId: r.stopId, seg: g.seg, verdicts,
    dead: r.people.dead.map(pid => personOf(departure, pid).name),
    symbol: r.symbol ? { ...r.symbol, use: null } : null, before, after: snapshot(g), lines,
    ...(departure.version === 2 ? { sent: [...r.people.sent] } : {}),
    ...(r.version === 5 ? { crew: structuredClone(r.crew) } : {}),
  };
  g.fieldReturns ??= { applied: {}, records: [] };
  Object.defineProperty(g.fieldReturns.applied, r.receiptId, { value: fingerprint, enumerable: true, configurable: true, writable: true });
  g.fieldReturns.records.push(record);
  return { status: 'applied', record };
}

/**
 * 필드가 다녀온 정차를 필드 결과로 닫는다(결정 카드 s3-link 10-26 F, 결정 442로 추천 적용). 아직 정차 단계이고 정차가 안 끝났을 때만.
 * 굴리지 않는다: 체류 석탄은 영수증 석탄이 이미 뺐고, 위험·전리품·부상·사망·구조·물림은 필드가 적었다.
 * 정차마다 같은 것(장작더미, 돌아온 사람의 자리비움, 쉬는 칸, 정차 약속)은 파견과 같이 센다.
 */
function closeFieldStop(g: Game, departure: AnyDeparture, r: FieldReceipt): void {
  const stop = g.stop;
  // 지난 구간에 나간 출발의 늦은 영수증은 물자·사람만 반영하고, 지금 정차를 닫거나 노린 갈래 줄에 세지 않는다.
  if (g.phase !== 'stop' || !stop || stop.done || departure.segment !== g.seg) return;
  stop.done = true;
  burnPyre(g);
  const back = new Set(returnedOf(r));
  const went = new Map<Comm, number>();
  const home = new Map<Comm, number>();
  for (const pid of r.people.sent) {
    const c = personOf(departure, pid).comm;
    went.set(c, (went.get(c) ?? 0) + 1);
    if (back.has(pid)) home.set(c, (home.get(c) ?? 0) + 1);
  }
  for (const [c, n] of home) g.comms[c].away += crewAwayOf(n);
  // 쉬지 못하는 칸은 가장 많이 나간 칸(같으면 먼저 나간 사람의 칸).
  let busy: Comm | null = null;
  for (const [c, n] of went) if (busy === null || n > went.get(busy)!) busy = c;
  crewRest(g, busy);
  if (busy) g.lastCrew = busy;
  // 내정 정차 훅(domesticStop: 호위·정차 하차 등)은 내정을 켠 판의 몫이라 여기서 부르지 않는다. 내정 줄기가 필드 정차에 붙일 자리다.
  const notes = ['필드에서 돌아왔다.'];
  const s = r.stock;
  const gains: Partial<Record<LootKey, number>> = {};
  for (const [k, v] of [['coal', s.coal], ['food', s.food], ['medicine', s.medicine], ['luxury', s.luxury]] as const) if ((v ?? 0) > 0) gains[k] = v;
  const gone = new Set([...r.people.dead, ...r.people.missing, ...r.people.leftBehind]);
  stop.result = {
    passed: false, gains, notes,
    injured: r.people.injured.filter(p => !gone.has(p)).map(p => personOf(departure, p).name),
    dead: r.people.dead.map(p => personOf(departure, p).name),
  };
  const place = PLACES.find(p => p.id === stop.place) ?? PLACES[0];
  const got = (Object.keys(gains) as LootKey[]).map(k => `${LOOT_NAME[k]} ${gains[k]}`).join(', ');
  journal(g, `${place.name}에 ${STAY[stop.stay].name} 머물렀다(필드 ${r.people.sent.length}명). ${got || '빈손'}.`);
  checkStopPromises(g, stop.target, gains);
  noteTarget(g, stop.target);
}

/**
 * 필드에서 시체를 뒤진 것을 본 사람이 돌아오면 그 칸이 그 일을 어떻게 여기나(결정 423 카드 12, 새 값).
 * 영수증 witnessed의 template 'body_search' 줄만 읽고, 한 귀환에 칸마다 한 번이다. S2 field_return.gd와 같은 값.
 */
export const BODY_SEARCH_REL: Readonly<Record<Comm, number>> = Object.freeze({ tail: 0, medtech: -1, guard: 0, front: -1, engine: 0 });

/**
 * 정차 사람 장면(J21): 그 정차에 사는 사람들의 겨울 몫을 가져간 것을 본 사람이 살아 돌아오면 그 칸이 한 귀환에 한 번 마음에 둔다
 * (결정 439 카드 3 「가」: 안건 없이 작게, 값은 정치 흐름과 맞춤). 돕기·지나치기는 칸 값이 없고 사람 기억(memory.ts)에만 남는다.
 */
export const RESIDENT_ROBBED_REL: Readonly<Record<Comm, number>> = Object.freeze({ tail: 0, medtech: -1, guard: 0, front: -1, engine: 0 });

function residentScenes(g: Game, departure: AnyDeparture, r: FieldReceipt): void {
  const back = new Set(returnedOf(r));
  const minded = new Set<Comm>();
  for (const row of r.witnessed) {
    if (row.template !== 'resident_robbed' || !Array.isArray(row.witnesses)) continue;
    for (const w of row.witnesses as unknown[]) {
      const pid = typeof w === 'string' ? w : (w as { person?: unknown } | null)?.person;
      if (typeof pid !== 'string' || !back.has(pid)) continue;
      const c = departurePeople(departure).find(x => x.id === pid)?.comm;
      if (!c || minded.has(c)) continue;
      minded.add(c);
      if (RESIDENT_ROBBED_REL[c]) bumpRel(g, c, RESIDENT_ROBBED_REL[c], 'field.resident');
    }
  }
}

function bodySearches(g: Game, departure: AnyDeparture, r: FieldReceipt): void {
  const back = new Set(returnedOf(r));
  const minded = new Set<Comm>();
  for (const row of r.witnessed) {
    if (row.template !== 'body_search' || !Array.isArray(row.witnesses)) continue;
    for (const w of row.witnesses as unknown[]) {
      const pid = typeof w === 'string' ? w : (w as { person?: unknown } | null)?.person;
      if (typeof pid !== 'string' || !back.has(pid)) continue;
      const c = departurePeople(departure).find(x => x.id === pid)?.comm;
      if (!c || minded.has(c)) continue;
      minded.add(c);
      if (BODY_SEARCH_REL[c]) bumpRel(g, c, BODY_SEARCH_REL[c], 'field.body');
    }
  }
}

/** 서막 약속 어김(prologue.ts의 breakPrologue와 같은 값·같은 기록). 「열기·긴장·적의」는 걸지 않는다(저장소 119). */
function breakPrologueVow(g: Game, c: Comm, label: string): void {
  bump(g, 'trust', PROLOGUE.brokenTrust, 'promise');
  bumpRel(g, c, PROLOGUE.brokenRel, 'promise');
  g.stats.promisesBroken += 1;
  g.comms[c].broken = (g.comms[c].broken ?? 0) + 1;
  if (g.dark) g.dark.broken[c] += 1;
  journal(g, `${COMM_NAME[c]}과(와)의 약속을 어겼다: ${label}.`, 'bad');
  noteBroken(g, c);
}

/** 상징물 쓰임 하나의 고를 수 있음과 까닭(결정 302·339: 선택지 밑에 사정과 나중에 돌아올 것 두 줄). */
export interface SymbolOption { use: SymbolUse; ok: boolean; why: string | null; now: string; later: string }

/** 귀환 기록의 상징물 쓰임 둘. 이미 골랐거나 상징물이 없으면 빈 목록이다. */
export function symbolOptions(g: Game, receiptId: string): SymbolOption[] {
  const rec = g.fieldReturns?.records.find(x => x.receiptId === receiptId);
  if (!rec?.symbol || rec.symbol.use) return [];
  const c = rec.symbol.groupId;
  const name = COMM_NAME[c];
  const caught = hangWhy(g, c);
  return [
    {
      use: 'hang_before_session', ok: true, why: null,
      now: `회기 앞에 ${name}의 상징물을 내건다. ${name}과(와)의 관계가 한 번 바뀌고 안건 전망에 보인다.`,
      later: '한 번 쓰고 끝난다. 칸에 걸어 두는 결속은 없다.',
    },
    {
      use: 'hang_in_car', ok: caught === null, why: caught,
      now: `${name} 칸에 걸어 둔다. 걸어 두는 동안 구간마다 그 칸 결속이 조금씩 오른다.`,
      later: '나중에 내리거나 잃으면 결속과 관계가 한 번 크게 깎인다. 회기 앞에 내걸 수는 없다.',
    },
  ];
}

/** 상징물 쓰임을 고른다. 한 판에 한 번이고 고른 뒤에는 바꾸지 않는다(결정 302). 고르지 못하면 false. */
export function chooseSymbolUse(g: Game, receiptId: string, use: SymbolUse): boolean {
  const rec = g.fieldReturns?.records.find(x => x.receiptId === receiptId);
  const opt = symbolOptions(g, receiptId).find(o => o.use === use);
  if (!rec?.symbol || !opt?.ok) return false;
  const c = rec.symbol.groupId;
  if (use === 'hang_in_car') {
    if (!hangSymbol(g, c)) return false;
    rec.lines.push({ k: 'symbol', comm: c, text: `${COMM_NAME[c]} 칸에 상징물을 걸었다. 구간마다 결속이 오른다.` });
  } else {
    if (FIELD.hangRel !== 0) bumpRel(g, c, FIELD.hangRel, 'symbol');
    journal(g, `회기 앞에 ${COMM_NAME[c]}의 상징물을 내걸었다.`, 'deal');
    rec.lines.push({ k: 'symbol', comm: c, text: `회기 앞에 ${COMM_NAME[c]}의 상징물을 내걸었다. 관계 ${FIELD.hangRel >= 0 ? '+' : ''}${FIELD.hangRel}.` });
  }
  rec.symbol.use = use;
  rec.after = snapshot(g);
  return true;
}
