import type { Game } from '../state';
import { FURNISH_CARS, FURNITURE, FURNITURE_SIZE } from './data';
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
  res?: DecorRes; v?: number;
}
const furniture = (kind: keyof typeof FURNITURE, spot: DecorSpot = 'floor', surface = false): DecorDef =>
  ({ ...FURNITURE[kind], spot, surface, furniture: true, model: '' });
const find = (spot: DecorSpot, res: DecorRes, v: number): DecorDef =>
  ({ spot, size: 'small', surface: false, furniture: false, warm: 0, crowd: 0, piano: false, model: '',
    ...(v > 0 ? { res, v } : {}) });

/** FieldItems.stock_of + STATE_WORTH per object, as the field credits it — never rounded up, or a tag would be worth
 *  more than what came in and melt on arrival. bottle_spirit uses the field's legacy STOCK_OF. */
export const DECOR = {
  chair: furniture('chair'), side_table: furniture('side_table', 'floor', true),
  small_shelf: furniture('small_shelf', 'floor', true), oil_lamp: furniture('oil_lamp'),
  small_box: furniture('small_box'), frame: furniture('frame', 'wall'),
  drawer: furniture('drawer', 'floor', true), bed_frame: furniture('bed_frame'),
  table: furniture('table', 'floor', true), bookshelf: furniture('bookshelf', 'floor', true),
  small_stove: furniture('small_stove'), wardrobe: furniture('wardrobe'), piano: furniture('piano'),
  cupboard: furniture('cupboard', 'floor', true), iron_stove: furniture('iron_stove'), safe: furniture('safe'),
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
  for (const f of Object.values(g.dom.furnish ?? {})) for (const item of f.items) {
    if (isDecorKind(item.kind)) item.spot ??= DECOR[item.kind].spot;
  }
  reconcileStore(g);
}
/** Only furniture contributes furnishing points; collectibles have no tier or numeric effect. */
export function furniturePoints(items: readonly DecorItem[]): number {
  return items.reduce((sum, item) => sum + (DECOR[item.kind].furniture ? FURNITURE_SIZE[item.size].points : 0), 0);
}
export function decorCrowd(items: readonly DecorItem[]): number {
  return items.reduce((sum, item) => sum + (spotOf(item) === 'floor'
    ? (DECOR[item.kind].furniture ? FURNITURE_SIZE[item.size].crowd + DECOR[item.kind].crowd : item.size === 'large' ? 0.5 : 0) : 0), 0);
}
