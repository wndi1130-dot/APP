import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { createS1cGame, furnishOf, migrateDomestic, zeroSit } from '../../src/game/domestic/state';
import { FURNISH_CARS } from '../../src/game/domestic/data';
import type { FurnishTier } from '../../src/game/domestic/data';
import type { Game } from '../../src/game/state';
import { lawTechSit } from '../../src/game/domestic/lawtech';
import { jobCheck, placeFurniture, removeFurniture } from '../../src/game/domestic/workshop';
import { applyFieldReturn } from '../../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../../src/game/field_receipt';
import { applyStopResult } from '../../src/game/stop_receipt';
import type { StopLedger, StopRequest } from '../../src/game/stop_receipt';
import { readSave, SAVE_VERSION } from '../../src/ui/repro';
import {
  DECOR, DECOR_CARS, DECOR_SLOT_TABLE, canPlace, commonTier, decorCrowd, decorItems,
  move, place, readStore, receiveDecor, reconcileStore, rotate, slotsOpen, takeBack,
} from '../../src/game/domestic/decor';
import type { DecorKind } from '../../src/game/domestic/decor';

function fresh(): Game {
  const g = createS1cGame('decor-test');
  g.food = 100; g.lux = 100; g.med = 10;
  return g;
}
function tier(g: Game, car: string, n: FurnishTier): void {
  g.dom!.furnish![car] = { work: n, jobs: ([1, 2, 3] as const).filter(i => i <= n), furnPts: 0, tier: n, best: n, items: [] };
}
function put(g: Game, car: string, kind: DecorKind, on?: number): void {
  receiveDecor(g, [kind]);
  expect(place(g, car, kind, DECOR[kind].spot, [2, 0], 0, on)).toEqual({ ok: true });
}
const fixture = <T>(name: string): T => JSON.parse(readFileSync(new URL(`../../../s2/tests/game/fixtures/field_v4/${name}.json`, import.meta.url), 'utf8')) as T;

describe('꾸미기 자리와 조작', () => {
  it.each(FURNISH_CARS)('%s의 0~3단 바닥·벽·면 자리는 단과 벽 최대를 따른다', car => {
    const walls = { tail1: [0, 4, 6, 6], tail2: [0, 4, 7, 7], tail3: [0, 4, 5, 5],
      medtech: [0, 4, 7, 10], guard: [0, 4, 7, 10], front: [0, 4, 7, 10] };
    for (const n of [0, 1, 2, 3] as const) {
      const g = fresh(); tier(g, car, n);
      expect(slotsOpen(g, car)).toEqual({ floor: [8, 14, 21, 29][n], wall: walls[car][n], surface: 0 });
      put(g, car, 'side_table');
      expect(slotsOpen(g, car)).toEqual({ floor: [7, 13, 20, 28][n], wall: walls[car][n], surface: [2, 4, 6, 8][n] });
    }
  });

  it('꾸밀 칸 여덟과 살림 칸 여섯을 구분하고 없는 칸은 거절한다', () => {
    const g = fresh(); receiveDecor(g, ['chair']);
    expect(DECOR_CARS).toEqual([...FURNISH_CARS, 'captain', 'dining']);
    expect(DECOR_SLOT_TABLE.captain).toBe('common');
    expect(DECOR_SLOT_TABLE.dining).toBe('common');
    for (const car of ['engine', 'store', 'cold', 'workshop', 'tail4', 'missing']) {
      expect(canPlace(g, car, 'chair', 'floor').ok).toBe(false);
      expect(slotsOpen(g, car)).toEqual({ floor: 0, wall: 0, surface: 0 });
    }
    expect(place(g, 'front', 'not_a_kind', 'floor').ok).toBe(false);
    expect(place(g, 'front', 'chair', 'wall').ok).toBe(false);
    expect(g.dom!.store!.chair.n).toBe(1);
  });

  it('바닥·벽 한도까지 놓은 뒤에는 창고를 더 소비하지 않는다', () => {
    for (const n of [1, 2, 3] as const) {
      const g = fresh(); tier(g, 'front', n);
      const count = [8, 14, 21, 29][n];
      receiveDecor(g, Array<string>(count + 1).fill('chair'));
      for (let i = 0; i < count; i++) expect(place(g, 'front', 'chair', 'floor').ok).toBe(true);
      expect(slotsOpen(g, 'front').floor).toBe(0);
      expect(place(g, 'front', 'chair', 'floor').ok).toBe(false);
      expect(readStore(g).chair.n).toBe(1);
    }
    for (const [car, count] of [['tail1', 6], ['tail2', 7], ['tail3', 5]] as const) {
      const g = fresh(); tier(g, car, 3);
      receiveDecor(g, Array<string>(count + 1).fill('frame'));
      for (let i = 0; i < count; i++) expect(place(g, car, 'frame', 'wall').ok).toBe(true);
      expect(place(g, car, 'frame', 'wall').ok).toBe(false);
      expect(readStore(g).frame.n).toBe(1);
    }
  });

  it.each(['captain', 'dining'])('%s은 여섯 칸 가운데 가장 높은 단의 표만 쓰고 작업·점수·효과를 갖지 않는다', car => {
    const g = fresh();
    expect(commonTier(g)).toBe(0);
    expect(slotsOpen(g, car)).toEqual({ floor: 8, wall: 0, surface: 0 });
    tier(g, 'front', 1); tier(g, 'tail3', 2);
    expect(commonTier(g)).toBe(2);
    expect(slotsOpen(g, car)).toEqual({ floor: car === 'dining' ? 13 : 21, wall: 7, surface: 0 });
    tier(g, 'guard', 3);
    expect(commonTier(g)).toBe(3);
    expect(slotsOpen(g, car)).toEqual({ floor: car === 'dining' ? 13 : 29, wall: 10, surface: 0 });
    const before = structuredClone({ comms: g.comms, sit: g.dom!.sit, ledger: g.ledger, journal: g.journal });
    put(g, car, 'piano');
    expect(g.dom!.furnish![car]).toEqual({ items: [{ kind: 'piano', size: 'large', spot: 'floor', at: [2, 0], rot: 0 }] });
    expect(jobCheck(g, 'furnish', car).ok).toBe(false);
    expect({ comms: g.comms, sit: g.dom!.sit, ledger: g.ledger, journal: g.journal }).toEqual(before);
    expect(takeBack(g, car, 0)).toEqual({ ok: true });
  });

  it('놓기·옮기기·회전·거두기는 창고와 자리 수를 보존하며 좌표의 겹침은 판단하지 않는다', () => {
    const g = fresh(); tier(g, 'front', 1);
    const at: [number, number] = [0, 0];
    receiveDecor(g, ['chair', 'frame']);
    expect(place(g, 'front', 'chair', 'floor', at, 1)).toEqual({ ok: true });
    at[0] = 9;
    expect(decorItems(g, 'front')[0].at).toEqual([0, 0]);
    expect(place(g, 'front', 'frame', 'wall', [-1, 1], 0)).toEqual({ ok: true });
    expect(slotsOpen(g, 'front')).toEqual({ floor: 13, wall: 3, surface: 0 });
    expect(move(g, 'front', 0, [300, -7], 2)).toEqual({ ok: true });
    expect(rotate(g, 'front', 0, 3)).toEqual({ ok: true });
    expect(decorItems(g, 'front')[0]).toMatchObject({ at: [300, -7], rot: 3 });
    const before = structuredClone(g);
    expect(move(g, 'front', 0.5, [0, 0]).ok).toBe(false);
    expect(move(g, 'front', 0, [0.5, 0]).ok).toBe(false);
    expect(rotate(g, 'front', 0, 4).ok).toBe(false);
    expect(g).toEqual(before);
    expect(takeBack(g, 'front', 0)).toEqual({ ok: true });
    expect(takeBack(g, 'front', 0)).toEqual({ ok: true });
    expect(slotsOpen(g, 'front')).toEqual({ floor: 14, wall: 4, surface: 0 });
    expect(readStore(g)).toMatchObject({ chair: { n: 1 }, frame: { n: 1 } });
    expect(takeBack(g, 'front', 0).ok).toBe(false);
  });

  it('면은 가구별로 제한하고 면 가구를 거두면 위 물건을 먼저 회수하며 나머지 on을 고친다', () => {
    const g = fresh(); tier(g, 'front', 1);
    put(g, 'front', 'chair'); put(g, 'front', 'side_table'); put(g, 'front', 'table');
    for (let i = 0; i < 4; i++) put(g, 'front', 'record', 2);
    receiveDecor(g, ['record']);
    expect(canPlace(g, 'front', 'record', 'surface', undefined, undefined, 2).ok).toBe(false);
    expect(canPlace(g, 'front', 'record', 'surface', undefined, undefined, 1).ok).toBe(true);
    expect(canPlace(g, 'front', 'record', 'surface', undefined, undefined, 0).ok).toBe(false);
    expect(canPlace(g, 'front', 'record', 'surface').ok).toBe(false);
    put(g, 'front', 'can_beans', 1);
    const food = g.food;
    expect(slotsOpen(g, 'front').surface).toBe(3);
    takeBack(g, 'front', 0);
    expect(decorItems(g, 'front').filter(i => i.kind === 'record').every(i => i.on === 1)).toBe(true);
    expect(decorItems(g, 'front').at(-1)!.on).toBe(0);
    takeBack(g, 'front', 0);
    expect(decorItems(g, 'front').map(i => i.kind)).toEqual(['table', 'record', 'record', 'record', 'record']);
    expect(decorItems(g, 'front').slice(1).every(i => i.on === 0)).toBe(true);
    expect(g.food).toBe(food + 1);
    expect(readStore(g).can_beans.n).toBe(1);
    expect(slotsOpen(g, 'front').surface).toBe(0);
  });

  it('감싸기도 창고를 소비하고 가구 점수는 4까지만 센다', () => {
    const g = fresh();
    expect(placeFurniture(g, 'front', 'chair').ok).toBe(false);
    receiveDecor(g, ['wardrobe', 'table', 'chair']);
    for (const kind of ['wardrobe', 'table', 'chair'] as const) expect(placeFurniture(g, 'front', kind).ok).toBe(true);
    expect(furnishOf(g, 'front')).toMatchObject({ furnPts: 4, tier: 1, work: 0, jobs: [] });
    expect(removeFurniture(g, 'front', 0).ok).toBe(true);
    expect(readStore(g).wardrobe.n).toBe(1);
  });
});

describe('꾸미기 이름표·영수증·저장', () => {
  it.each((Object.keys(DECOR) as DecorKind[]).filter(kind => DECOR[kind].res))('%s은 놓을 때 v를 빼고 거둘 때 같은 v만 돌려준다', kind => {
    const g = fresh(); tier(g, 'front', 1); put(g, 'front', 'table');
    const def = DECOR[kind], res = def.res!, before = g[res]!;
    receiveDecor(g, [kind]);
    expect(g[res]).toBe(before);
    expect(place(g, 'front', kind, def.spot, undefined, undefined, def.spot === 'surface' ? 0 : undefined)).toEqual({ ok: true });
    expect(g[res]).toBe(before - def.v!);
    expect(decorItems(g, 'front')[1].v).toBe(def.v);
    takeBack(g, 'front', 1);
    expect(g[res]).toBe(before);
    expect(readStore(g)[kind].tags![0].v).toBe(def.v);
    g[res] = def.v! - 0.25;
    expect(canPlace(g, 'front', kind, def.spot, undefined, undefined, def.spot === 'surface' ? 0 : undefined).ok).toBe(false);
    expect(g[res]).toBe(def.v! - 0.25);
  });

  it('표가 바뀌어도 이름표와 놓인 물건에 적힌 v를 보존한다', () => {
    const g = fresh(); tier(g, 'front', 1); put(g, 'front', 'table');
    g.dom!.store = { record: { n: 1, tags: [{ v: 3, at: 7 }] } };
    const before = g.lux;
    expect(place(g, 'front', 'record', 'surface', undefined, undefined, 0).ok).toBe(true);
    expect(g.lux).toBe(before - 3);
    expect(decorItems(g, 'front')[1].v).toBe(3);
    takeBack(g, 'front', 1);
    expect(g.lux).toBe(before);
    expect(readStore(g).record.tags![0].v).toBe(3);
  });

  it('소비 뒤 이름표는 갈래를 가로질러 새것부터 녹고 놓인 물건은 남는다', () => {
    const g = fresh(); tier(g, 'front', 1);
    g.lux = 4;
    receiveDecor(g, ['painting', 'record', 'rare_violin']);
    expect(place(g, 'front', 'rare_violin', 'wall').ok).toBe(true);
    g.lux = 1.5;
    const placed = structuredClone(decorItems(g, 'front'));
    const rng = structuredClone(g.rng);
    const store = readStore(g);
    expect(store.painting.tags).toEqual([{ v: 1, at: 0 }]);
    expect(store.record).toBeUndefined();
    expect(decorItems(g, 'front')).toEqual(placed);
    g.lux = 0;
    reconcileStore(g);
    expect(g.dom!.store).toEqual({});
    expect(decorItems(g, 'front')).toEqual(placed);
    expect(g.rng).toEqual(rng);
    takeBack(g, 'front', 0);
    expect(g.lux).toBe(2);
    expect(readStore(g).rare_violin.tags![0].v).toBe(2);
  });

  it('필드 영수증은 DECOR id만 받고 숫자는 중복 지급하지 않으며 재적용도 한 번이다', () => {
    const g = fresh();
    const departure = fixture<FieldDeparture>('departure_prologue');
    const receipt = fixture<FieldReceipt>('case3_nosymbol_kept');
    receipt.items.gained = ['chair', 'painting', 'can_beans', 'not_decor'];
    receipt.stock = { luxury: 1, food: 1 };
    const before = { food: g.food, lux: g.lux };
    expect(applyFieldReturn(g, departure, receipt).status).toBe('applied');
    expect(Object.keys(readStore(g)).sort()).toEqual(['can_beans', 'chair', 'painting']);
    expect(g.food).toBe(before.food + 1); expect(g.lux).toBe(before.lux + 1);
    const store = structuredClone(g.dom!.store);
    expect(applyFieldReturn(g, departure, receipt).status).toBe('duplicate');
    expect(g.dom!.store).toEqual(store);
  });

  it('분리된 정차 장부도 dom.store에 이름표를 한 번만 남긴다', () => {
    const { departureId: _d, symbol: _s, fieldPromises: _p, ...body } = fixture<FieldReceipt>('case3_nosymbol_kept');
    const receipt = { ...body, version: 3, stock: { luxury: 2 }, items: { gained: ['chair', 'record', 'not_decor'], lost: [] } };
    const ledger: StopLedger = { stock: {}, documents: [], fragments: { engine: 0, med: 0, craft: 0, radio: 0, expedition: 0 }, coreCount: 0, items: [], receipts: {}, stops: {}, results: {} };
    const request: StopRequest = { stopId: receipt.stopId, placeId: receipt.place.id, goal: receipt.goal.kind, required: receipt.goal.required, go: true, segment: 1, sentIds: receipt.people.sent };
    const applied = applyStopResult(ledger, receipt, request);
    expect(applied.ledger.dom!.store).toEqual({ chair: { n: 1 }, record: { n: 1, tags: [{ v: 1, at: 0 }] } });
    expect(applied.ledger.stock.luxury).toBe(2);
    expect(ledger.dom).toBeUndefined();
    expect(applyStopResult(applied.ledger, receipt, request).status).toBe('duplicate');
  });

  it('옛 저장은 버전·좌표·난수·단을 바꾸지 않고 spot과 빈 창고만 채운다', () => {
    const g = fresh();
    delete g.dom!.store;
    g.dom!.furnish!.front = { work: 0, jobs: [], furnPts: 1, tier: 0, best: 0, items: [{ kind: 'frame', size: 'small' }] };
    const rng = structuredClone(g.rng);
    const loaded = readSave(JSON.parse(JSON.stringify(g)));
    expect(loaded.ok).toBe(true);
    if (!loaded.ok) throw new Error(loaded.why);
    expect(SAVE_VERSION).toBe(1); expect(loaded.g.version).toBe(1);
    expect(loaded.g.dom!.store).toEqual({});
    expect(decorItems(loaded.g, 'front')).toEqual([{ kind: 'frame', size: 'small', spot: 'wall' }]);
    expect(loaded.g.rng).toEqual(rng);
    const once = structuredClone(loaded.g.dom);
    migrateDomestic(loaded.g);
    expect(loaded.g.dom).toEqual(once);
  });

  it('과밀은 바닥 가구만 세고 벽·면 전리품은 가구 점수와 효과를 더하지 않는다', () => {
    const g = fresh(); tier(g, 'front', 1);
    put(g, 'front', 'table'); put(g, 'front', 'bed_frame');
    const points = furnishOf(g, 'front').furnPts;
    const before = zeroSit(); lawTechSit(g, before);
    put(g, 'front', 'rare_violin'); put(g, 'front', 'record', 0);
    const after = zeroSit(); lawTechSit(g, after);
    expect(furnishOf(g, 'front').furnPts).toBe(points);
    expect(after).toEqual(before);
    expect(decorCrowd(decorItems(g, 'front'))).toBe(0);
    expect(after.front[2]).toBe(-0.5);
  });
});
