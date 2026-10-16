import Ajv2020 from 'ajv/dist/2020.js';
import commonSchema from '../../schema/common.schema.json';
import placeSchema from '../../schema/place.schema.json';
import chronicleSchema from '../../schema/chronicle.schema.json';
import receiptSchema from '../../schema/receipt.schema.json';
import { FIELDS } from './domestic/data';
import type { Field } from './domestic/data';
import { receiveDocument } from './info_documents';
import type { InfoDocument, RecurringRoles } from './info_documents';
import { goalStatus } from './stop_goals';
import type { GoalStatus, StopEnd, StopGoal } from './stop_goals';

export type StockKey = 'coal' | 'food' | 'medicine' | 'luxury' | 'symbol' | 'info' | 'scrap' | 'wood'
  | 'ammo_pistol' | 'ammo_shell' | 'ammo_craft';
export interface ReceiptPeople {
  sent: string[]; injured: string[]; bitten: string[]; dead: string[];
  missing: string[]; leftBehind: string[]; rescued: string[]; wounds?: Record<string, unknown>[];
}
interface ReceiptBase {
  place: { id: string; type: string; variant: string };
  time: { arrive: string; depart: string; stayGameMinutes: number };
  stock: Partial<Record<StockKey, number>>;
  items: { gained: string[]; lost: string[] };
  people: ReceiptPeople;
  witnessed: Record<string, unknown>[];
  placeState: { looted: number; remainingRisk: number; [key: string]: unknown };
  promises: { leader: string; condition: string; kept: boolean }[];
  source?: 'direct' | 'auto';
  endReason?: StopEnd;
  decisions?: { id: string; choice: string }[];
  content_type?: 'receipt';
}
export interface ReceiptGoal { kind: StopGoal | null; required: number; earned: number; status: GoalStatus }
export interface ReceiptExtras { documents: InfoDocument[]; symbolCount: number; fragments: Field[]; coreCount: number }
export type StopReceipt = ReceiptBase & (
  | { version: 1 | 2 }
  | { version: 3; receiptId: string; stopId: string; goal: ReceiptGoal; extras: ReceiptExtras }
);
export interface StopRequest {
  stopId: string;
  placeId: string;
  goal: StopGoal | null;
  required: number;
  go: boolean;
  segment?: number;
  sentIds?: readonly string[];
  roles?: RecurringRoles;
  // 구형 판에는 식별자가 없으므로 수신자가 안정된 키를 한 번 고정한다.
  legacyReceiptId?: string;
}
export interface NormalizedStopResult {
  receiptId: string;
  stopId: string;
  receipt: StopReceipt;
  fingerprint: string;
  goal: ReceiptGoal | null;
  extras: ReceiptExtras;
}
/** 기존 판에 연결하기 전의 독립 장부다. 피해·장소·약속은 결과에 원형대로 남긴다. */
export interface StopLedger {
  stock: Partial<Record<StockKey, number>>;
  documents: InfoDocument[];
  fragments: Record<Field, number>;
  coreCount: number;
  items: string[];
  receipts: Record<string, string>;
  stops: Record<string, string>;
  results: Record<string, NormalizedStopResult>;
}
export interface ReceiptApplication { status: 'applied' | 'duplicate'; ledger: StopLedger; result: NormalizedStopResult }

const id = { $ref: 'urn:s1:schema:common#/$defs/id' };
const amount = { type: 'integer', minimum: 0, maximum: Number.MAX_SAFE_INTEGER };
const ids = { type: 'array', items: id, uniqueItems: true };
const object = (properties: Record<string, unknown>, required = Object.keys(properties)) =>
  ({ type: 'object', properties, required, additionalProperties: false });
const documentBase = {
  id, sourcePlaceId: id, segment: amount, bodyKey: { type: 'string' }, choices: ids,
  targetId: { anyOf: [id, { type: 'null' }] }, state: { const: 'pending' },
};
const documents = {
  type: 'array', items: { oneOf: [
    object({ ...documentBase, kind: { const: 'next_stop' }, nextStop: object({
      stopId: id, observedSegment: amount, blankKey: id, confirmed: { type: 'boolean' },
    }) }),
    object({ ...documentBase, targetId: id, kind: { const: 'history' }, history: object({
      conditionKey: { type: 'string' }, workKey: { type: 'string' }, objectKey: { type: 'string' }, allowedActionIds: ids,
    }) }),
    object({ ...documentBase, kind: { const: 'technology' }, technology: object({
      branchCandidates: ids, consumeAt: { anyOf: [id, { type: 'null' }] },
    }) }),
  ] },
};
// 판 3의 추가 꼴은 이 모듈에만 둔다. 구형 계약과 참조 스키마는 읽어서 재사용한다.
const v3Schema = {
  ...receiptSchema, $id: 'urn:s1:prep:stop-receipt-v3',
  properties: {
    ...receiptSchema.properties, version: { const: 3 }, receiptId: id, stopId: id,
    goal: object({ kind: { enum: ['coal', 'food', 'medicine', 'materials', null] }, required: amount, earned: amount,
      status: { enum: ['done', 'part', 'retreat', 'failed'] } }),
    extras: object({ documents, symbolCount: amount,
      fragments: { type: 'array', items: { enum: [...FIELDS] } }, coreCount: amount }),
  },
  required: [...receiptSchema.required, 'version', 'receiptId', 'stopId', 'goal', 'extras'],
};
const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
for (const schema of [commonSchema, placeSchema, chronicleSchema, receiptSchema]) ajv.addSchema(schema);
const legacyValidator = ajv.getSchema('urn:s1:schema:receipt')!;
const v3Validator = ajv.compile(v3Schema);

function canonical(value: unknown): string {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value !== null && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    return '{' + Object.keys(record).sort().map(key => JSON.stringify(key) + ':' + canonical(record[key])).join(',') + '}';
  }
  if (typeof value === 'number' && !Number.isFinite(value)) throw new Error('유한하지 않은 수량이다');
  const serialized = JSON.stringify(value);
  if (serialized === undefined) throw new Error('저장할 수 없는 영수증 값이다');
  return serialized;
}

/** 문자열 또는 주입된 값을 검사하고 독립 사본으로 돌려준다. 오류에는 입력 본문을 싣지 않는다. */
export function decodeReceipt(input: unknown): StopReceipt {
  const value: unknown = typeof input === 'string' ? JSON.parse(input) : input;
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('영수증은 객체여야 한다');
  const record = value as Record<string, unknown>;
  const version = record.version ?? 1;
  if (!(version === 3 ? v3Validator(record) : legacyValidator(record))) throw new Error('영수증 계약이 올바르지 않다');
  const receipt = structuredClone({ ...record, version }) as StopReceipt;
  for (const delta of Object.values(receipt.stock)) {
    if (!Number.isSafeInteger(delta)) throw new Error('장부 증감은 안전한 정수여야 한다');
  }
  canonical(receipt);
  if (receipt.version === 3) {
    if ('info' in receipt.stock) throw new Error('새 문서는 구형 정보 수량에 넣을 수 없다');
    const goal = receipt.goal;
    const gains = goal.kind === 'materials' ? { wood: goal.earned } : goal.kind ? { [goal.kind]: goal.earned } : {};
    if ((goal.kind === null && (goal.required !== 0 || goal.earned !== 0))
      || goal.status !== goalStatus(goal.kind, goal.required, gains, receipt.endReason ?? 'departed')) {
      throw new Error('목표 달성 판정이 획득량과 맞지 않는다');
    }
    if (new Set(receipt.extras.documents.map(document => document.id)).size !== receipt.extras.documents.length) {
      throw new Error('영수증에 중복 문서가 있다');
    }
  }
  return receipt;
}

export function normalizeStopResult(input: unknown, request: StopRequest): NormalizedStopResult {
  const receipt = decodeReceipt(input);
  if (!request.stopId || !request.placeId || !Number.isSafeInteger(request.required) || request.required < 0) {
    throw new Error('현재 정차 요청이 올바르지 않다');
  }
  if (receipt.place.id !== request.placeId) throw new Error('현재 장소와 영수증이 다르다');
  if (request.sentIds && (new Set(request.sentIds).size !== receipt.people.sent.length
    || receipt.people.sent.some(person => !request.sentIds!.includes(person)))) throw new Error('파견 명단이 다르다');
  const receiptId = receipt.version === 3 ? receipt.receiptId : request.legacyReceiptId;
  if (!receiptId) throw new Error('구형 영수증의 안정된 수신 키가 필요하다');
  if (receipt.version === 3) {
    if (receipt.stopId !== request.stopId || receipt.goal.kind !== request.goal || receipt.goal.required !== request.required) {
      throw new Error('현재 정차·목표·기준량이 다르다');
    }
    const extras = receipt.extras;
    if (!request.go && (extras.documents.length || extras.symbolCount || extras.fragments.length || extras.coreCount)) {
      throw new Error('지나치기에는 새 덤이 없다');
    }
    for (const document of extras.documents) {
      if (document.sourcePlaceId !== request.placeId || (request.segment !== undefined && document.segment !== request.segment)) {
        throw new Error('문서 획득 장소나 구간이 다르다');
      }
      receiveDocument([], document, { roles: request.roles });
    }
  }
  return {
    receiptId, stopId: receipt.version === 3 ? receipt.stopId : request.stopId,
    receipt, fingerprint: canonical(receipt), goal: receipt.version === 3 ? receipt.goal : null,
    extras: receipt.version === 3 ? receipt.extras : { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
  };
}

/** 직접·자동 모두 이 경로를 사용한다. 모든 검사가 끝난 뒤 새 장부만 돌려준다. */
export function applyStopResult(ledger: StopLedger, input: unknown, request: StopRequest): ReceiptApplication {
  const receipt = decodeReceipt(input);
  const key = receipt.version === 3 ? receipt.receiptId : request.legacyReceiptId;
  const fingerprint = canonical(receipt);
  if (key && Object.hasOwn(ledger.receipts, key)) {
    if (ledger.receipts[key] !== fingerprint) throw new Error('같은 영수증 키의 내용이 다르다');
    return { status: 'duplicate', ledger, result: ledger.results[key] };
  }
  const result = normalizeStopResult(receipt, request);
  if (Object.hasOwn(ledger.stops, result.stopId)) {
    return { status: 'duplicate', ledger, result: ledger.results[ledger.stops[result.stopId]] };
  }
  const next = structuredClone(ledger);
  for (const [stockKey, delta] of Object.entries(receipt.stock)) {
    const typedKey = stockKey as StockKey;
    const amount = (next.stock[typedKey] ?? 0) + delta;
    if (!Number.isFinite(amount) || amount < 0 || amount > Number.MAX_SAFE_INTEGER) throw new Error('장부 수량을 반영할 수 없다');
    next.stock[typedKey] = amount;
  }
  for (const document of result.extras.documents) {
    next.documents = receiveDocument(next.documents, document, { roles: request.roles }).documents;
  }
  // 상징물·자재는 stock만 적용한다. 조각·코어는 extras만 적용하며 items 표시와 별개다.
  for (const field of result.extras.fragments) next.fragments[field] += 1;
  next.coreCount += result.extras.coreCount;
  if (!Number.isSafeInteger(next.coreCount) || Object.values(next.fragments).some(value => !Number.isSafeInteger(value) || value < 0)) {
    throw new Error('조각·코어 장부가 올바르지 않다');
  }
  for (const item of receipt.items.lost) {
    const index = next.items.indexOf(item);
    if (index >= 0) next.items.splice(index, 1);
  }
  next.items.push(...receipt.items.gained);
  Object.defineProperty(next.receipts, result.receiptId, { value: result.fingerprint, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(next.stops, result.stopId, { value: result.receiptId, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(next.results, result.receiptId, { value: result, enumerable: true, configurable: true, writable: true });
  return { status: 'applied', ledger: next, result };
}

/** 수신 원천을 주입해도 부작용 없는 공통 적용 경로를 거친다. */
export function consumeStopReceipt(ledger: StopLedger, input: unknown | (() => unknown), request: StopRequest): ReceiptApplication {
  return applyStopResult(ledger, typeof input === 'function' ? input() : input, request);
}
