import type { Game } from '../state';
import { FURNISH_CARS, FURNITURE, FURNITURE_SIZE } from './data';
import type { FurnitureSize, FurnishTier } from './data';
import { furnishOf } from './state';
import { refreshSit } from './sit';
import { updateFurnish } from './workshop';

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
    ...(v >= 1 ? { res, v } : {}) });

/** FieldItems.stock_of + STATE_WORTH, rounded per object; bottle_spirit uses the field's legacy STOCK_OF. */
export const DECOR = {
  chair: furniture('chair'), side_table: furniture('side_table', 'floor', true),
  small_shelf: furniture('small_shelf', 'floor', true), oil_lamp: furniture('oil_lamp'),
  small_box: furniture('small_box'), frame: furniture('frame', 'wall'),
  drawer: furniture('drawer', 'floor', true), bed_frame: furniture('bed_frame'),
  table: furniture('table', 'floor', true), bookshelf: furniture('bookshelf', 'floor', true),
  small_stove: furniture('small_stove'), wardrobe: furniture('wardrobe'), piano: furniture('piano'),
  cupboard: furniture('cupboard', 'floor', true), iron_stove: furniture('iron_stove'), safe: furniture('safe'),
  painting: find('wall', 'lux', 1), record: find('surface', 'lux', 1),
  can_beans: find('surface', 'food', 1), can_meat: find('surface', 'food', 1),
  jar_cabbage: find('surface', 'food', 1), jar_jam: find('surface', 'food', 1),
  bottle_spirit: find('surface', 'lux', 1), rare_violin: find('wall', 'lux', 2),
  rare_wine_case: find('surface', 'lux', 2),
} satisfies Record<string, DecorDef>;
export type DecorKind = keyof typeof DECOR;
export interface DecorItem {
  kind: DecorKind; size: FurnitureSize;
  /** Absent only in old saves; reading/migration supplies the catalog spot. */
  spot?: DecorSpot; at?: DecorAt; rot?: number; on?: number; v?: number;
}
export interface DecorCarState { items: DecorItem[] }
export type DecorCheck = { ok: boolean; why?: string };
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
export function commonTier(g: Game): FurnishTier {
  return Math.max(...FURNISH_CARS.map(car => furnishOf(g, car).tier)) as FurnishTier;
}
function isCar(car: string): car is DecorCar { return Object.hasOwn(DECOR_SLOT_TABLE, car); }
function tierOf(g: Game, car: DecorCar): FurnishTier {
  return DECOR_SLOT_TABLE[car] === 'common' ? commonTier(g) : furnishOf(g, car).tier;
}
export function decorItems(g: Game, car: string): DecorItem[] { return g.dom?.furnish?.[car]?.items ?? []; }
const spotOf = (item: DecorItem): DecorSpot => item.spot ?? DECOR[item.kind].spot;
const amount = (g: DecorStock, res: DecorRes): number => g[res] ?? 0;

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
function addStored(store: DecorStore, kind: DecorKind, v?: number): void {
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
export function slotsOpen(g: Game, car: string): { floor: number; wall: number; surface: number } {
  if (!g.dom || !isCar(car)) return { floor: 0, wall: 0, surface: 0 };
  const slots = DECOR_SLOTS[tierOf(g, car)];
  const items = decorItems(g, car);
  return {
    floor: Math.max(0, Math.min(slots.floor, FURNISH_FLOOR_MAX[car]) - items.filter(item => spotOf(item) === 'floor').length),
    wall: Math.max(0, Math.min(slots.wall, FURNISH_WALL_MAX[car]) - items.filter(item => spotOf(item) === 'wall').length),
    surface: Math.max(0, items.filter(item => DECOR[item.kind].surface).length * slots.surface - items.filter(item => spotOf(item) === 'surface').length),
  };
}
const validAt = (at: DecorAt | undefined): boolean => at === undefined || (Array.isArray(at) && at.length === 2 && at.every(Number.isSafeInteger));
const validRot = (rot: number | undefined): boolean => rot === undefined || (Number.isInteger(rot) && rot >= 0 && rot <= 3);
const fail = (why: string): DecorCheck => ({ ok: false, why });
function oldest(entry: DecorStockEntry): DecorTag | undefined {
  return entry.tags?.reduce<DecorTag | undefined>((first, tag) => !first || tag.at < first.at ? tag : first, undefined);
}
export function canPlace(g: Game, car: string, kind: string, spot: DecorSpot, at?: DecorAt, rot?: number, on?: number): DecorCheck {
  if (!g.dom || !isCar(car)) return fail('꾸미기는 객차 여덟 칸만');
  if (!isDecorKind(kind)) return fail('알 수 없는 물건');
  const def = DECOR[kind];
  if (spot !== def.spot) return fail('이 물건을 놓는 면이 아니다');
  if (!validAt(at) || !validRot(rot)) return fail('자리나 회전 값이 올바르지 않다');
  if (spot === 'surface') {
    const items = decorItems(g, car);
    if (on === undefined || !Number.isInteger(on) || on < 0 || on >= items.length || !DECOR[items[on].kind].surface || spotOf(items[on]) !== 'floor') return fail('올려놓을 면 가구가 없다');
    if (items.filter(item => spotOf(item) === 'surface' && item.on === on).length >= DECOR_SLOTS[tierOf(g, car)].surface) return fail('그 가구 위에 자리가 없다');
  } else {
    if (on !== undefined) return fail('면 위 물건만 가구를 고른다');
    if (slotsOpen(g, car)[spot] <= 0) return fail('이 면에 물건을 놓을 자리가 없다');
  }
  const entry = readStore(g)[kind];
  if (!entry || entry.n < 1) return fail('창고에 그 물건이 없다');
  if (def.res) {
    const tag = oldest(entry);
    if (!tag || amount(g, def.res) < tag.v) return fail('이름표 몫의 물자가 모자라다');
  }
  return { ok: true };
}
function changed(g: Game, car: DecorCar): void {
  if (DECOR_SLOT_TABLE[car] === 'tier') {
    updateFurnish(g, car);
    refreshSit(g);
  }
}
export function place(g: Game, car: string, kind: string, spot: DecorSpot, at?: DecorAt, rot?: number, on?: number): DecorCheck {
  const check = canPlace(g, car, kind, spot, at, rot, on);
  if (!check.ok) return check;
  const id = kind as DecorKind;
  const def = DECOR[id];
  const store = g.dom!.store!;
  const entry = store[id];
  const tag = def.res ? oldest(entry)! : undefined;
  const item: DecorItem = { kind: id, size: def.size, spot,
    ...(at !== undefined ? { at: [...at] as DecorAt } : {}), ...(rot !== undefined ? { rot } : {}),
    ...(on !== undefined ? { on } : {}), ...(tag ? { v: tag.v } : {}) };
  if (tag) { g[def.res!] = amount(g, def.res!) - tag.v; entry.tags!.splice(entry.tags!.indexOf(tag), 1); }
  entry.n -= 1;
  if (entry.n === 0) delete store[id];
  const states = g.dom!.furnish ??= {};
  states[car] ??= DECOR_SLOT_TABLE[car as DecorCar] === 'tier' ? furnishOf(g, car) : { items: [] };
  states[car].items.push(item);
  changed(g, car as DecorCar);
  return { ok: true };
}
function placed(g: Game, car: string, i: number): DecorItem | undefined {
  return g.dom && isCar(car) && Number.isInteger(i) && i >= 0 ? decorItems(g, car)[i] : undefined;
}
export function move(g: Game, car: string, i: number, at: DecorAt, rot?: number): DecorCheck {
  const item = placed(g, car, i);
  if (!item) return fail('그 자리에 물건이 없다');
  if (at === undefined || !validAt(at) || !validRot(rot)) return fail('자리나 회전 값이 올바르지 않다');
  item.at = [...at];
  if (rot !== undefined) item.rot = rot;
  return { ok: true };
}
export function rotate(g: Game, car: string, i: number, rot: number): DecorCheck {
  const item = placed(g, car, i);
  if (!item) return fail('그 자리에 물건이 없다');
  if (rot === undefined || !validRot(rot)) return fail('자리나 회전 값이 올바르지 않다');
  item.rot = rot;
  return { ok: true };
}
export function takeBack(g: Game, car: string, i: number): DecorCheck {
  const item = placed(g, car, i);
  if (!item) return fail('그 자리에 물건이 없다');
  const items = decorItems(g, car);
  const store = readStore(g);
  const children = items.map((row, j) => row.on === i && spotOf(row) === 'surface' ? j : -1).filter(j => j >= 0);
  const removed = new Set([...children, i]);
  for (const j of [...children, i]) {
    const row = items[j], def = DECOR[row.kind];
    if (def.res && row.v !== undefined) g[def.res] = amount(g, def.res) + row.v;
    addStored(store, row.kind, def.res ? row.v : undefined);
  }
  const remap = new Map<number, number>();
  const kept = items.filter((_, j) => !removed.has(j));
  let next = 0;
  items.forEach((_, j) => { if (!removed.has(j)) remap.set(j, next++); });
  for (const row of kept) if (row.on !== undefined) row.on = remap.get(row.on)!;
  g.dom!.furnish![car].items = kept;
  changed(g, car as DecorCar);
  return { ok: true };
}
/** Only furniture contributes furnishing points; collectibles have no tier or numeric effect. */
export function furniturePoints(items: readonly DecorItem[]): number {
  return items.reduce((sum, item) => sum + (DECOR[item.kind].furniture ? FURNITURE_SIZE[item.size].points : 0), 0);
}
export function decorCrowd(items: readonly DecorItem[]): number {
  return items.reduce((sum, item) => sum + (spotOf(item) === 'floor'
    ? (DECOR[item.kind].furniture ? FURNITURE_SIZE[item.size].crowd + DECOR[item.kind].crowd : item.size === 'large' ? 0.5 : 0) : 0), 0);
}
