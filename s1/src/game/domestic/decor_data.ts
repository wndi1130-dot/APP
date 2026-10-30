import type { Game } from '../state';
import { D, FURNISH_CARS, FURNITURE, FURNITURE_SIZE } from './data';
import type { FurnitureSize } from './data';

// The catalog, the store and the save shape. It imports nothing that comes back here, so state.ts and
// lawtech.ts can read the table; placing (decor.ts) sits above the workshop.
export type DecorSpot = 'floor' | 'wall' | 'surface';
export type DecorRes = 'lux' | 'food' | 'med' | 'sup';
export type DecorAt = [number, number];
export interface DecorTag { v: number; at: number }
export interface DecorStockEntry { n: number; tags?: DecorTag[] }
export type DecorStore = Record<string, DecorStockEntry>;
export interface DecorStock {
  dom?: { store?: DecorStore };
  lux: number; food: number; med: number; sup?: number;
}
interface DecorDef {
  spot: DecorSpot; size: FurnitureSize; surface: boolean; furniture: boolean;
  warm: number; crowd: number; piano: boolean; model: string;
  res?: DecorRes; v?: number; light?: 'lamp' | 'stove';
}
const furniture = (kind: keyof typeof FURNITURE, spot: DecorSpot = 'floor', surface = false, light?: 'lamp' | 'stove'): DecorDef =>
  ({ ...FURNITURE[kind], spot, surface, furniture: true, model: '', ...(light ? { light } : {}) });
const find = (spot: DecorSpot, res: DecorRes, v: number): DecorDef =>
  ({ spot, size: 'small', surface: false, furniture: false, warm: 0, crowd: 0, piano: false, model: '',
    ...(v > 0 ? { res, v } : {}) });

/** FieldItems.stock_of + STATE_WORTH per object, as the field credits it — never rounded up, or a tag would be worth
 *  more than what came in and melt on arrival. bottle_spirit uses the field's legacy STOCK_OF. */
export const DECOR = {
  chair: furniture('chair'), side_table: furniture('side_table', 'floor', true),
  small_shelf: furniture('small_shelf', 'floor', true), oil_lamp: furniture('oil_lamp', 'floor', false, 'lamp'),
  small_box: furniture('small_box'), frame: furniture('frame', 'wall'),
  drawer: furniture('drawer', 'floor', true), bed_frame: furniture('bed_frame'),
  table: furniture('table', 'floor', true), bookshelf: furniture('bookshelf', 'floor', true),
  small_stove: furniture('small_stove', 'floor', false, 'stove'), wardrobe: furniture('wardrobe'), piano: furniture('piano'),
  cupboard: furniture('cupboard', 'floor', true), iron_stove: furniture('iron_stove', 'floor', false, 'stove'), safe: furniture('safe'),
  painting: find('wall', 'lux', 0.75), record: find('surface', 'lux', 0.5),
  can_beans: find('surface', 'food', 0.5), can_meat: find('surface', 'food', 0.5),
  jar_cabbage: find('surface', 'food', 0.5), jar_jam: find('surface', 'food', 0.5),
  bottle_spirit: find('surface', 'lux', 0.5), rare_violin: find('wall', 'lux', 1.5),
  rare_wine_case: find('surface', 'lux', 2),
} satisfies Record<string, DecorDef>;
export type DecorKind = keyof typeof DECOR;
export interface DecorItem {
  kind: DecorKind; size: FurnitureSize;
  /** Absent only in old saves; reading/migration supplies the catalog spot. */
  spot?: DecorSpot; at?: DecorAt; rot?: number; on?: number; v?: number;
}
export interface DecorCarState { items: DecorItem[] }
export const DECOR_CARS = [...FURNISH_CARS, 'captain', 'dining'] as const;
export type DecorCar = typeof DECOR_CARS[number];
export const FURNISH80: Record<'tail1' | 'tail2' | 'tail3' | 'medtech' | 'guard' | 'front' | 'captain' | 'dining', { journal: string; say: string[] }> = {
  tail1: { journal: '꼬리칸 선반에 인형과 장난감 차가 서고 전구 줄이 켜졌다. 아이들이 처음으로 늦게까지 논다.', say: ['우리 칸도 이제 사람 사는 데 같다.', '열차장이 손수 놓은 거, 우리도 다 봤다.', '꾸며 준다고 빚이 없어지진 않는다. 그래도 고맙다.'] },
  tail2: { journal: '꼬리칸 벽에 작은 그림이 줄지어 걸렸다. 사람들이 서로 자리를 비켜 앉는다.', say: ['우리 칸도 이제 사람 사는 데 같다.', '열차장이 손수 놓은 거, 우리도 다 봤다.', '꾸며 준다고 빚이 없어지진 않는다. 그래도 고맙다.'] },
  tail3: { journal: '꼬리칸 선반에 고무 오리와 병이 섰다. 처음으로 누가 노래를 흥얼거린다.', say: ['우리 칸도 이제 사람 사는 데 같다.', '열차장이 손수 놓은 거, 우리도 다 봤다.', '꾸며 준다고 빚이 없어지진 않는다. 그래도 고맙다.'] },
  medtech: { journal: '의무칸 선반에 약병이 크기대로 섰다. 환자들이 처음으로 창 쪽을 보고 눕는다.', say: ['이 칸에서 웃는 환자는 처음 봤다. 적어 둔다.', '손 닿는 데 다 있다. 열차장 몫으로 적어 두겠다.', '보기 좋다. 그래도 침상 수는 그대로다.'] },
  guard: { journal: '경비대 칸 벽에 지도와 작은 그림이 걸렸다. 교대하는 대원마다 멈춰 서서 한 번씩 본다.', say: ['초소 같지 않다. 집 같다.', '대원들이 고맙다고 전해 달란다. 나도다.', '꾸밈은 받았다. 할 말은 회기에서 한다.'] },
  front: { journal: '앞칸 탁자마다 등잔이 켜지고 레코드가 돈다. 앞칸 사람들이 다시 손님을 들이기 시작했다.', say: ['이제야 손님을 맞을 만합니다.', '손수 놓으셨다지요. 앞칸이 기억해 두겠습니다.', '보기엔 좋지요. 그래도 셈은 따로 하겠습니다.'] },
  captain: { journal: '열차장실 책상에 노선도가 펼쳐지고 등잔이 켜졌다. 찾아온 대표들이 처음으로 앉아서 말한다.', say: [] },
  dining: { journal: '식당칸 탁자마다 등잔이 켜지고 벽에 그림이 걸렸다. 칸이 다른 사람들이 처음으로 한 탁자에 앉는다.', say: ['여기서 먹으니 같은 열차 사람 같다.', '열차장이 손수 걸었다더라. 오늘은 다 같이 먹자.', '탁자는 좋아졌다. 그릇이 차야 웃는다.'] },
};
export const DECOR_SLOT_TABLE: Record<DecorCar, 'tier' | 'common'> = {
  tail1: 'tier', tail2: 'tier', tail3: 'tier', medtech: 'tier', guard: 'tier', front: 'tier',
  captain: 'common', dining: 'common',
};
export const DECOR_SLOTS = [
  { floor: 8, wall: 0, surface: 2 }, { floor: 14, wall: 4, surface: 4 },
  { floor: 21, wall: 7, surface: 6 }, { floor: 29, wall: 10, surface: 8 },
] as const;
export const FURNISH_WALL_MAX: Record<string, number> = {
  tail1: 6, tail2: 7, tail3: 5, medtech: 12, guard: 10, front: 12, captain: 11, dining: 11,
};
/** The dining car keeps its four-way walkway clear (row iz 4 is the aisle), so only 13 floor pieces fit. */
export const FURNISH_FLOOR_MAX: Record<string, number> = {
  tail1: 29, tail2: 29, tail3: 29, medtech: 29, guard: 29, front: 29, captain: 29, dining: 13,
};

export function isDecorKind(kind: string): kind is DecorKind { return Object.hasOwn(DECOR, kind); }
export function decorItems(g: Game, car: string): DecorItem[] { return g.dom?.furnish?.[car]?.items ?? []; }
export const spotOf = (item: DecorItem): DecorSpot => item.spot ?? DECOR[item.kind].spot;
export const amount = (g: DecorStock, res: DecorRes): number => g[res] ?? 0;

/** Six independently capped shares: kinds, floor, wall, occupied surfaces, small objects, light kinds. */
export function decorParts(g: Game, car: string): number[] {
  if (!Object.hasOwn(DECOR_SLOT_TABLE, car)) return [0, 0, 0, 0, 0, 0];
  const items = decorItems(g, car);
  const surfaces = items.flatMap((item, i) => DECOR[item.kind].surface && spotOf(item) === 'floor' ? [i] : []);
  const small = items.filter(item => spotOf(item) === 'surface');
  const occupied = new Set(small.map(item => item.on));
  const lights = new Set(items.flatMap(item => DECOR[item.kind].light ? [DECOR[item.kind].light] : []));
  return [
    new Set(items.map(item => item.kind)).size / Math.min(D.decorKindMax, Math.floor(D.decorKindShare * Object.keys(DECOR).length)),
    items.filter(item => spotOf(item) === 'floor').length / Math.min(D.decorFloorTarget, FURNISH_FLOOR_MAX[car]),
    items.filter(item => spotOf(item) === 'wall').length / Math.min(D.decorWallTarget, FURNISH_WALL_MAX[car]),
    surfaces.length ? surfaces.filter(i => occupied.has(i)).length / surfaces.length / D.decorSurfaceTarget : 0,
    small.length / D.decorSmallTarget,
    lights.size / D.decorLightTarget,
  ].map(value => Math.min(1, value));
}
export function decorPercent(g: Game, car: string): number {
  return decorParts(g, car).reduce((sum, value) => sum + value, 0) / 6;
}
/** One tolerance for all three thresholds; -1 means no effect. */
export function decorBand(percent: number): number {
  return D.decorThresholds.reduce((band, line, i) => percent + D.decorEpsilon >= line ? i : band, -1);
}

/** One reconciliation for receipts, settlement and every inventory read. Placed items are outside this stock. */
export function reconcileStore(g: DecorStock): void {
  const store = g.dom?.store;
  if (!store) return;
  for (const res of ['lux', 'food', 'med', 'sup'] as const) {
    const tags = Object.entries(store).flatMap(([kind, entry]) =>
      isDecorKind(kind) && DECOR[kind].res === res ? (entry.tags ?? []).map((tag, i) => ({ kind, tag, i })) : []);
    let total = tags.reduce((sum, row) => sum + row.tag.v, 0);
    tags.sort((a, b) => b.tag.at - a.tag.at || (a.kind < b.kind ? -1 : a.kind > b.kind ? 1 : b.i - a.i));
    for (const { kind, tag } of tags) {
      if (total <= amount(g, res)) break;
      const entry = store[kind];
      entry.tags!.splice(entry.tags!.indexOf(tag), 1);
      entry.n -= 1;
      total -= tag.v;
      if (entry.n === 0) delete store[kind];
    }
  }
}
export function readStore(g: DecorStock): DecorStore {
  if (!g.dom) return {};
  const store = g.dom.store ??= {};
  reconcileStore(g);
  return store;
}
export function addStored(store: DecorStore, kind: DecorKind, v?: number): void {
  const entry = store[kind] ??= { n: 0 };
  entry.n += 1;
  if (v !== undefined) {
    const newest = Object.values(store).reduce((latest, row) =>
      (row.tags ?? []).reduce((n, tag) => Math.max(n, tag.at), latest), -1);
    (entry.tags ??= []).push({ v, at: newest + 1 });
  }
}
/** Stock numbers have already been credited by the receipt owner. */
export function receiveDecor(g: DecorStock, gained: readonly string[]): void {
  if (!g.dom) return;
  const store = g.dom.store ??= {};
  for (const kind of gained) if (isDecorKind(kind)) addStored(store, kind, DECOR[kind].res ? DECOR[kind].v : undefined);
  reconcileStore(g);
}
export function migrateDecor(g: Game): void {
  if (!g.dom) return;
  g.dom.store ??= {};
  g.dom.decor80 ??= [];
  for (const f of Object.values(g.dom.furnish ?? {})) {
    if ('tier' in f) f.best = Math.max(f.best ?? f.tier, f.tier) as typeof f.tier;
    for (const item of f.items) {
      if (isDecorKind(item.kind)) item.spot ??= DECOR[item.kind].spot;
    }
  }
  reconcileStore(g);
}
/** Only furniture contributes furnishing points; collectibles contribute to decoration instead. */
export function furniturePoints(items: readonly DecorItem[]): number {
  return items.reduce((sum, item) => sum + (DECOR[item.kind].furniture ? FURNITURE_SIZE[item.size].points : 0), 0);
}
export function decorCrowd(items: readonly DecorItem[]): number {
  return items.reduce((sum, item) => sum + (spotOf(item) === 'floor'
    ? (DECOR[item.kind].furniture ? FURNITURE_SIZE[item.size].crowd + DECOR[item.kind].crowd : item.size === 'large' ? 0.5 : 0) : 0), 0);
}
