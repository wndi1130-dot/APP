import type { Game } from '../state';
import { FURNISH_CARS, FURNITURE } from './data';
import type { FurnitureKind, FurnishTier } from './data';
import { furnishOf, furnishTier } from './state';
import { refreshSit } from './sit';
import { updateFurnish } from './workshop';
import type { JobCheck } from './workshop';
import {
  amount, addStored, DECOR, DECOR_SLOT_TABLE, DECOR_SLOTS, decorItems, FURNISH_FLOOR_MAX, FURNISH_WALL_MAX,
  isDecorKind, readStore, spotOf,
} from './decor_data';
import type { DecorAt, DecorCar, DecorItem, DecorKind, DecorSpot, DecorStockEntry, DecorTag } from './decor_data';

export * from './decor_data';
export type DecorCheck = { ok: boolean; why?: string };

export function commonTier(g: Game): FurnishTier {
  return Math.max(...FURNISH_CARS.map(car => furnishOf(g, car).tier)) as FurnishTier;
}
function isCar(car: string): car is DecorCar { return Object.hasOwn(DECOR_SLOT_TABLE, car); }
function tierOf(g: Game, car: DecorCar): FurnishTier {
  return DECOR_SLOT_TABLE[car] === 'common' ? commonTier(g) : furnishOf(g, car).tier;
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
function slotsFit(car: string, items: readonly DecorItem[], tier: FurnishTier): boolean {
  const slots = DECOR_SLOTS[tier];
  const surfaces = new Map<number, number>();
  for (const item of items) if (spotOf(item) === 'surface') {
    const used = (surfaces.get(item.on!) ?? 0) + 1;
    if (used > slots.surface) return false;
    surfaces.set(item.on!, used);
  }
  return items.filter(item => spotOf(item) === 'floor').length <= Math.min(slots.floor, FURNISH_FLOOR_MAX[car])
    && items.filter(item => spotOf(item) === 'wall').length <= Math.min(slots.wall, FURNISH_WALL_MAX[car]);
}
export function takeBack(g: Game, car: string, i: number): DecorCheck {
  const item = placed(g, car, i);
  if (!item) return fail('그 자리에 물건이 없다');
  const items = decorItems(g, car);
  const children = items.map((row, j) => row.on === i && spotOf(row) === 'surface' ? j : -1).filter(j => j >= 0);
  const removed = new Set([...children, i]);
  const kept = items.filter((_, j) => !removed.has(j));
  if (DECOR_SLOT_TABLE[car as DecorCar] === 'tier') {
    // A drop is measured against what the placed items reach now: an old save may still keep a higher tier.
    const tier = furnishTier(g, car, kept);
    if (tier < furnishTier(g, car)) {
      const now = FURNISH_CARS.map(other => furnishTier(g, other));
      const common = Math.max(...FURNISH_CARS.map((other, k) => other === car ? tier : now[k])) as FurnishTier;
      if (!slotsFit(car, kept, tier) || (common < Math.max(...now)
        && ['captain', 'dining'].some(other => !slotsFit(other, decorItems(g, other), common)))) {
        return fail('살림이 내려가면 자리가 모자란다. 다른 것부터 거둬라');
      }
    }
  }
  // A rejected removal must not even reconcile stored resource tags.
  const store = readStore(g);
  for (const j of [...children, i]) {
    const row = items[j], def = DECOR[row.kind];
    if (def.res && row.v !== undefined) g[def.res] = amount(g, def.res) + row.v;
    addStored(store, row.kind, def.res ? row.v : undefined);
  }
  const remap = new Map<number, number>();
  let next = 0;
  items.forEach((_, j) => { if (!removed.has(j)) remap.set(j, next++); });
  for (const row of kept) if (row.on !== undefined) row.on = remap.get(row.on)!;
  g.dom!.furnish![car].items = kept;
  changed(g, car as DecorCar);
  return { ok: true };
}

// The old furniture calls, now thin wrappers: a piece must be in the store first.
export function placeFurniture(g: Game, car: string, kind: FurnitureKind): JobCheck {
  if (!Object.hasOwn(FURNITURE, kind)) return { ok: false, why: '알 수 없는 가구' };
  return place(g, car, kind, DECOR[kind].spot);
}

export function removeFurniture(g: Game, car: string, index: number): JobCheck {
  return takeBack(g, car, index);
}
