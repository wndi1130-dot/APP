import { describe, expect, it } from 'vitest';
import { applyStopResult, consumeStopReceipt, decodeReceipt, normalizeStopResult } from '../../src/game/stop_receipt';
import type { StopLedger, StopReceipt, StopRequest } from '../../src/game/stop_receipt';

type V3Receipt = Extract<StopReceipt, { version: 3 }>;
const request = (): StopRequest => ({
  stopId: 'stop_a', placeId: 'place_a', goal: 'materials', required: 6, go: true,
  segment: 1, sentIds: ['worker_a'],
});
const ledger = (): StopLedger => ({
  stock: { coal: 10, wood: 0, scrap: 0, symbol: 0, info: 0 }, documents: [],
  fragments: { engine: 0, med: 0, radio: 0, expedition: 0, craft: 0 },
  coreCount: 0, items: [], receipts: {}, stops: {}, results: {},
});
const receipt = (source: 'direct' | 'auto' = 'direct'): V3Receipt => ({
  version: 3, receiptId: `receipt_${source}`, stopId: 'stop_a', source, endReason: 'departed',
  place: { id: 'place_a', type: 'factory', variant: 'variant_a' },
  time: { arrive: 'D1 10:00', depart: 'D1 10:30', stayGameMinutes: 30 },
  // 획득 자재는 6이지만 소비 후 장부 증감은 5다.
  stock: { coal: -2, wood: 2, scrap: 3, symbol: 1 },
  items: { gained: ['fragment_label', 'core_label', 'symbol_label', 'doc_label'], lost: [] },
  people: { sent: ['worker_a'], injured: ['worker_a'], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [] },
  witnessed: [], placeState: { looted: 0.5, remainingRisk: 1 }, promises: [],
  goal: { kind: 'materials', required: 6, earned: 6, status: 'done' },
  extras: {
    documents: [{ id: 'doc_a', kind: 'technology', sourcePlaceId: 'place_a', segment: 1,
      bodyKey: '', choices: [], targetId: null, state: 'pending', technology: { branchCandidates: [], consumeAt: null } }],
    symbolCount: 1, fragments: ['craft', 'craft'], coreCount: 1,
  },
});
function legacy(version?: 1 | 2): Record<string, unknown> {
  const { receiptId: _receiptId, stopId: _stopId, goal: _goal, extras: _extras, ...value } = receipt();
  const result: Record<string, unknown> = { ...value, stock: { wood: 2, scrap: 3, symbol: 1, info: 2 } };
  if (version === undefined) delete result.version;
  else result.version = version;
  return result;
}
function freeze<T>(value: T): T {
  if (value && typeof value === 'object') {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

describe('정차 영수증 준비', () => {
  it('직접과 자동 결과는 한 번만 반영된다', () => {
    for (const source of ['direct', 'auto'] as const) {
      const original = freeze(ledger());
      const input = freeze(receipt(source));
      const normalized = normalizeStopResult(input, request());
      expect(normalized.goal).toEqual(input.goal);
      const applied = source === 'direct' ? consumeStopReceipt(original, () => JSON.stringify(input), request())
        : applyStopResult(original, input, request());
      expect(applied.status).toBe('applied');
      expect(applied.ledger.stock).toEqual({ coal: 8, wood: 2, scrap: 3, symbol: 1, info: 0 });
      expect(applied.ledger.fragments.craft).toBe(2);
      expect(applied.ledger.coreCount).toBe(1);
      expect(applied.ledger.documents).toHaveLength(1);
      expect(applied.ledger.documents[0].state).toBe('pending');
      expect(applied.ledger.items).toEqual(input.items.gained);
      expect(applied.result.receipt.people.injured).toEqual(['worker_a']);
      expect(original).toEqual(ledger());
      const reopened = JSON.parse(JSON.stringify(applied.ledger)) as StopLedger;
      const reordered = Object.fromEntries(Object.entries(input).reverse());
      const duplicate = consumeStopReceipt(reopened, reordered, request());
      expect(duplicate.status).toBe('duplicate');
      expect(duplicate.ledger).toBe(reopened);
      // 같은 정차에 다른 키가 오면 중복으로 삼키지 않고 오류로 알리며 장부는 그대로다.
      const reopenedBefore = JSON.stringify(reopened);
      expect(() => consumeStopReceipt(reopened, { ...input, receiptId: 'receipt_again' }, request())).toThrow('다른 영수증');
      expect(JSON.stringify(reopened)).toBe(reopenedBefore);
      expect(consumeStopReceipt(reopened, input, { ...request(), stopId: 'stop_next' }).status).toBe('duplicate');
    }
    const next = receipt();
    next.stopId = 'stop_next'; next.receiptId = 'receipt_next';
    const first = consumeStopReceipt(ledger(), receipt(), request());
    const second = consumeStopReceipt(first.ledger, next, { ...request(), stopId: 'stop_next' });
    expect(second.ledger.stock.wood).toBe(4);
    expect(second.ledger.stock.symbol).toBe(2);
    expect(second.ledger.documents).toHaveLength(1);
    expect(second.ledger.fragments.craft).toBe(4);
    const noGoal = receipt();
    noGoal.goal = { kind: null, required: 0, earned: 0, status: 'retreat' };
    expect(normalizeStopResult(noGoal, { ...request(), goal: null, required: 0 }).goal?.kind).toBeNull();
    for (const version of [undefined, 1, 2] as const) {
      const old = legacy(version);
      const oldRequest = { ...request(), legacyReceiptId: 'receipt_old' };
      if (version === 2) (old.people as Record<string, unknown>).wounds = [{ person: 'worker_a', part: 'arm_left', kind: 'deep' }];
      const applied = consumeStopReceipt(ledger(), old, oldRequest);
      expect(applied.result.goal).toBeNull();
      expect(applied.ledger.documents).toEqual([]);
      expect(applied.ledger.stock.info).toBe(2);
      expect(applied.ledger.stock.symbol).toBe(1);
      expect(applied.ledger.coreCount).toBe(0);
      expect(applied.result.receipt.people.injured).toEqual(['worker_a']);
      if (version === 2) expect(applied.result.receipt.people.wounds).toHaveLength(1);
      expect(consumeStopReceipt(applied.ledger, old, oldRequest).status).toBe('duplicate');
    }
  });

  it('같은 정차에 다른 영수증이 오면 충돌로 알리고 장부를 바꾸지 않는다', () => {
    const first = applyStopResult(ledger(), receipt('auto'), request());
    const before = JSON.stringify(first.ledger);
    // 같은 키·같은 내용은 그대로 중복이다.
    expect(applyStopResult(first.ledger, receipt('auto'), request()).status).toBe('duplicate');
    // 같은 정차에 직접 영수증이 나중에 와도 조용히 무시하지 않는다.
    expect(() => applyStopResult(first.ledger, receipt('direct'), request())).toThrow('다른 영수증');
    expect(JSON.stringify(first.ledger)).toBe(before);
    const oldRequest = { ...request(), legacyReceiptId: 'receipt_old' };
    const old = applyStopResult(ledger(), legacy(), oldRequest);
    expect(applyStopResult(old.ledger, legacy(), oldRequest).status).toBe('duplicate');
    expect(() => applyStopResult(old.ledger, legacy(), { ...oldRequest, legacyReceiptId: 'receipt_old_2' })).toThrow('다른 영수증');
  });

  it('이미 반영된 정차에서는 자동 풀이 함수를 부르지 않는다', () => {
    let calls = 0;
    const generate = () => { calls += 1; return receipt('auto'); };
    const first = consumeStopReceipt(ledger(), generate, request());
    expect(first.status).toBe('applied');
    expect(calls).toBe(1);
    const again = consumeStopReceipt(first.ledger, generate, request());
    expect(again.status).toBe('duplicate');
    expect(again.ledger).toBe(first.ledger);
    expect(again.result).toBe(first.result);
    expect(calls).toBe(1);
  });

  it('나쁜 영수증은 장부를 바꾸지 않는다', () => {
    const original = freeze(ledger());
    const before = JSON.stringify(original);
    const mutations: ((value: V3Receipt) => void)[] = [
      value => { (value as unknown as Record<string, unknown>).version = 4; },
      value => { value.stopId = 'stop_other'; },
      value => { value.place.id = 'place_other'; },
      value => { value.goal.kind = 'coal'; },
      value => { value.goal.required = 7; },
      value => { value.goal.earned = -1; },
      value => { value.goal.earned = 1.5; },
      value => { value.goal.status = 'part'; },
      value => { value.goal.kind = null; },
      value => { value.extras.coreCount = -1; },
      value => { value.extras.symbolCount = 0.5; },
      value => { value.stock.wood = 0.5; },
      value => { value.stock.coal = -100; },
      value => { value.stock.wood = Number.MAX_SAFE_INTEGER + 1; },
      value => { value.stock.info = 1; },
      value => { (value as unknown as Record<string, unknown>).unknown = true; },
      value => { (value.stock as Record<string, unknown>).parts = 1; },
      value => { value.extras.documents.push(structuredClone(value.extras.documents[0])); },
      value => { value.extras.documents[0].state = 'used'; },
      value => { value.extras.documents[0].sourcePlaceId = 'place_other'; },
      value => { value.extras.documents[0].segment = 2; },
      value => { (value.extras.documents[0] as unknown as Record<string, unknown>).kind = 'story'; },
      value => { (value.extras.documents[0] as unknown as Record<string, unknown>).cost = 1; },
      value => { (value.extras as unknown as Record<string, unknown>).effect = true; },
      value => { value.extras.fragments = ['unknown'] as never; },
      value => { value.people.sent = ['worker_other']; },
      value => { value.time.stayGameMinutes = -1; },
      value => { delete (value as unknown as Record<string, unknown>).extras; },
      value => { value.endReason = 'wiped'; },
      value => { value.stock.wood = NaN; },
    ];
    for (const mutate of mutations) {
      const value = receipt();
      mutate(value);
      expect(() => consumeStopReceipt(original, value, request())).toThrow();
      expect(JSON.stringify(original)).toBe(before);
    }
    for (const input of [null, [], 1, '{', '{}']) expect(() => decodeReceipt(input)).toThrow();
    expect(() => consumeStopReceipt(original, receipt(), { ...request(), go: false })).toThrow();
    expect(() => consumeStopReceipt(original, legacy(), request())).toThrow();
    const oldWound = legacy(1);
    (oldWound.people as Record<string, unknown>).wounds = [];
    expect(() => decodeReceipt(oldWound)).toThrow();
    const oldNewGoal = { ...legacy(2), goal: receipt().goal };
    expect(() => decodeReceipt(oldNewGoal)).toThrow();
    const applied = consumeStopReceipt(original, receipt(), request());
    const conflict = receipt();
    conflict.stock.wood = 4;
    const appliedBefore = JSON.stringify(applied.ledger);
    expect(() => consumeStopReceipt(applied.ledger, conflict, request())).toThrow();
    expect(JSON.stringify(applied.ledger)).toBe(appliedBefore);
    const documentConflict = receipt();
    documentConflict.receiptId = 'receipt_other'; documentConflict.stopId = 'stop_other';
    documentConflict.extras.documents[0].bodyKey = 'body_changed';
    expect(() => consumeStopReceipt(applied.ledger, documentConflict, { ...request(), stopId: 'stop_other' })).toThrow();
    expect(JSON.stringify(applied.ledger)).toBe(appliedBefore);
    expect(JSON.stringify(original)).toBe(before);
  });
});
