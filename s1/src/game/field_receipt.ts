import Ajv2020 from 'ajv/dist/2020.js';
import commonSchema from '../../schema/common.schema.json';
import placeSchema from '../../schema/place.schema.json';
import chronicleSchema from '../../schema/chronicle.schema.json';
import receiptSchema from '../../schema/receipt.schema.json';
import { bump, bumpRel } from './ledger';
import { COMMS, COMM_NAME } from './data';
import type { Comm } from './data';
import { onDeath } from './death';
import { PROLOGUE } from './prologue';
import { hangWhy, hangSymbol } from './domestic/symbols';
import { journal, PROFILES, situation, storyOf } from './state';
import type { Game, Phase } from './state';
import { breakPromise, keepPromise } from './turn';
import { canonical, decodeReceipt, v3Schema } from './stop_receipt';
import type { StopReceipt } from './stop_receipt';
import { noteInjury } from './wounds';

// S3 연결의 영수증 계약(구현명세 S3 연결 v1 2절, 결정 294·301·302·304).
// 열차가 필드에 넘기는 「출발 명세」와 필드가 돌려주는 「귀환 영수증」(판 4)을 따로 둔다.
// 필드는 일어난 일만 적는다(누가 나갔고 누가 돌아왔고 무엇을 들고 왔고 약속을 누가 봤나). 약속의 지킴·어김·알 수 없음과
// 상징물의 쓰임은 열차가 정한다. 그래서 같은 영수증을 두 번 받아도, 자동 풀이가 만든 영수증이어도 판정은 한 길이다.
// 이 모듈은 난수를 쓰지 않는다. 주사위 정차만 도는 판(봇·시뮬)은 이 길을 지나지 않으니 그 판들의 값은 그대로다.

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
export type FieldReceipt = Extract<StopReceipt, { version: 3 }> extends infer V3
  ? Omit<V3, 'version'> & { version: 4; departureId: string; symbol: FieldSymbol | null; fieldPromises: FieldPromiseSeen[] }
  : never;

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
const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
for (const schema of [commonSchema, placeSchema, chronicleSchema, receiptSchema]) ajv.addSchema(schema);
const v4Validator = ajv.compile(v4Schema);

/** 판 4 영수증을 검사하고 독립 사본으로 돌려준다. 판 3의 검사(목표·문서)는 판 번호만 바꿔 그대로 거친다. 오류에는 본문을 싣지 않는다. */
export function decodeFieldReceipt(input: unknown): FieldReceipt {
  const value: unknown = typeof input === 'string' ? JSON.parse(input) : input;
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('영수증은 객체여야 한다');
  const record = value as Record<string, unknown>;
  if (record.version !== 4 || !v4Validator(record)) throw new Error('필드 영수증 계약이 올바르지 않다');
  const { departureId: _d, symbol: _s, fieldPromises: _p, ...rest } = record;
  decodeReceipt({ ...rest, version: 3 });
  const receipt = structuredClone(record) as unknown as FieldReceipt;
  if (receipt.symbol && (receipt.stock.symbol ?? 0) < 1) throw new Error('상징물을 들고 왔는데 장부에 없다');
  if (new Set(receipt.fieldPromises.map(p => p.id)).size !== receipt.fieldPromises.length) throw new Error('영수증에 같은 약속이 두 번 있다');
  return receipt;
}

/** 출발 명세의 모양을 본다. */
export function checkDeparture(d: FieldDeparture): void {
  const re = /^[a-z][a-z0-9_]*$/;
  const okId = (v: unknown) => typeof v === 'string' && re.test(v);
  if (d.version !== 1 || ![d.departureId, d.stopId, d.placeId].every(okId) || !Number.isSafeInteger(d.segment) || d.segment < 0) {
    throw new Error('출발 명세가 올바르지 않다');
  }
  if (!d.roster.every(r => okId(r.id) && COMMS.includes(r.comm)) || new Set(d.roster.map(r => r.id)).size !== d.roster.length) {
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
 * - 교대 약속: 출발 명단에 약속받은 칸 사람이 없으면 지킴, 있으면 어김.
 */
export function judgePromises(d: FieldDeparture, r: FieldReceipt): FieldVerdict[] {
  const back = new Set(returnedOf(r));
  return d.promises.map(p => {
    const seen = r.fieldPromises.find(x => x.id === p.id);
    const witnessesBack = (seen?.witnesses ?? []).filter(w => back.has(w));
    let verdict: PromiseVerdict;
    if (witnessesBack.length === 0) verdict = 'unknown';
    else if (p.kind === 'prologue') verdict = p.subjects.every(s => back.has(s)) ? 'kept' : 'broken';
    else verdict = d.roster.some(x => x.comm === p.madeTo) ? 'broken' : 'kept';
    return { id: p.id, kind: p.kind, madeTo: p.madeTo, verdict, witnessesBack };
  });
}

/** 영수증이 출발 명세와 같은 정차·같은 명단·같은 약속을 말하는지 본다. */
export function matchDeparture(d: FieldDeparture, r: FieldReceipt): void {
  if (r.departureId !== d.departureId || r.stopId !== d.stopId || r.place.id !== d.placeId) throw new Error('출발 명세와 영수증의 정차가 다르다');
  const sent = new Set(r.people.sent);
  if (sent.size !== d.roster.length || d.roster.some(x => !sent.has(x.id))) throw new Error('출발 명단과 영수증의 명단이 다르다');
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

/** 프로필 id → 이름·칸. 모르는 id는 명단의 칸으로 읽고 이름은 id 그대로 둔다. */
function personOf(d: FieldDeparture, pid: string): { name: string; comm: Comm } {
  const p = PROFILES.find(x => x.id === pid);
  return { name: p?.name ?? pid, comm: p?.community ?? d.roster.find(x => x.id === pid)?.comm ?? 'tail' };
}

function byComm(d: FieldDeparture, list: readonly string[]): Map<Comm, string[]> {
  const out = new Map<Comm, string[]>();
  for (const pid of list) {
    const { name, comm } = personOf(d, pid);
    out.set(comm, [...(out.get(comm) ?? []), name]);
  }
  return out;
}

export type FieldApplyStatus = 'applied' | 'duplicate';

/**
 * 귀환 한 번을 판에 반영한다. 같은 영수증 id가 다시 오면(앱을 껐다 켜서 또 받아도) 아무것도 하지 않고 'duplicate'다(확인 줄 9, T07·T08).
 * 같은 id에 다른 내용이 오면 판을 건드리지 않고 오류로 알린다. 검사가 모두 끝난 뒤에만 판을 바꾼다.
 * 차례: 물자 → 사람 → 약속. 상징물은 장부에만 넣고 쓰임은 chooseSymbolUse로 따로 고른다(결정 302).
 */
export function applyFieldReturn(g: Game, departure: FieldDeparture, input: unknown): { status: FieldApplyStatus; record: FieldReturnRecord } {
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
    coal: g.coal, food: g.food, medicine: g.med, luxury: g.lux, ...(g.dom ? { wood: g.dom.wood, scrap: g.dom.scrap } : {}),
  };
  if (s.coal) bump(g, 'coal', s.coal, 'field.loot', { floor0: true });
  if (s.food) bump(g, 'food', s.food, 'field.loot', { floor0: true });
  if (s.medicine) bump(g, 'med', s.medicine, 'field.loot', { floor0: true });
  if (s.luxury) bump(g, 'lux', s.luxury, 'field.loot', { floor0: true });
  if (s.symbol) g.symbols = Math.max(0, g.symbols + s.symbol);
  if (g.dom) {
    if (s.wood) g.dom.wood = Math.max(0, g.dom.wood + s.wood);
    if (s.scrap) g.dom.scrap = Math.max(0, g.dom.scrap + s.scrap);
  }
  const got = ([['coal', '석탄'], ['food', '식량'], ['medicine', '의약품'], ['luxury', '사치품'], ['wood', '목재'], ['scrap', '고철']] as const)
    .filter(([k]) => s[k]).map(([k, name]) => {
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
  const hurt = r.people.injured.filter(p => !gone.has(p));
  for (const [c, names] of byComm(departure, hurt)) {
    g.injured += names.length;
    noteInjury(g, names.length, 'stop', place, { names, comm: c });
    lines.push({ k: 'people', comm: c, text: `${COMM_NAME[c]} ${names.join(', ')}이(가) 크게 다쳐 돌아왔다.` });
  }
  const lost = [...r.people.leftBehind, ...r.people.missing].filter(p => !r.people.dead.includes(p));
  for (const [c, names] of byComm(departure, lost)) {
    g.comms[c].pop = Math.max(1, g.comms[c].pop - names.length);
    lines.push({ k: 'people', comm: c, text: `${COMM_NAME[c]} ${names.join(', ')}이(가) 필드에 남았다.` });
    journal(g, `${names.join(', ')}이(가) 필드에 남았다. 열차는 그들 없이 떠났다.`, 'dark');
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
  if (r.symbol) {
    lines.push({ k: 'symbol', comm: r.symbol.groupId, text: `${COMM_NAME[r.symbol.groupId]}의 상징물을 가져왔다. 쓰임을 고른다.` });
  }
  const record: FieldReturnRecord = {
    receiptId: r.receiptId, departureId: r.departureId, stopId: r.stopId, seg: g.seg, verdicts,
    dead: r.people.dead.map(pid => personOf(departure, pid).name),
    symbol: r.symbol ? { ...r.symbol, use: null } : null, before, after: snapshot(g), lines,
  };
  g.fieldReturns ??= { applied: {}, records: [] };
  Object.defineProperty(g.fieldReturns.applied, r.receiptId, { value: fingerprint, enumerable: true, configurable: true, writable: true });
  g.fieldReturns.records.push(record);
  return { status: 'applied', record };
}

/**
 * 필드에서 시체를 뒤진 것을 본 사람이 돌아오면 그 칸이 그 일을 어떻게 여기나(결정 423 카드 12, 새 값).
 * 영수증 witnessed의 template 'body_search' 줄만 읽고, 한 귀환에 칸마다 한 번이다. S2 field_return.gd와 같은 값.
 */
export const BODY_SEARCH_REL: Readonly<Record<Comm, number>> = Object.freeze({ tail: 0, medtech: -1, guard: 0, front: -1, engine: 0 });

function bodySearches(g: Game, departure: FieldDeparture, r: FieldReceipt): void {
  const minded = new Set<Comm>();
  for (const row of r.witnessed) {
    if (row.template !== 'body_search' || !Array.isArray(row.witnesses)) continue;
    for (const w of row.witnesses as unknown[]) {
      const pid = typeof w === 'string' ? w : (w as { person?: unknown } | null)?.person;
      if (typeof pid !== 'string') continue;
      const c = departure.roster.find(x => x.id === pid)?.comm;
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
  if (g.dark) g.dark.broken[c] += 1;
  journal(g, `${COMM_NAME[c]}과(와)의 약속을 어겼다: ${label}.`, 'bad');
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
