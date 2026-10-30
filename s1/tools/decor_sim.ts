// Decisions 507/512/517. Fixed fu-* seeds; furniture draw and tail work policy match furnish_sim.
// Usage: npx tsx tools/decor_sim.ts [games=300]. JSON goes to stdout; no output files.
import { createHash } from 'node:crypto';
import { CAR_COMM, D, FURNISH_CARS, FURNITURE, FURNITURE_SIZE } from '../src/game/domestic/data';
import type { FurnitureKind, FurnitureSize } from '../src/game/domestic/data';
import { createS1cGame, furnishOf, nextFurnishWork, techMult, techUsable } from '../src/game/domestic/state';
import { finishCheck, restoreCheck, startFinish, startRestore, startJob } from '../src/game/domestic/workshop';
import { decorRelGain, furnishTick } from '../src/game/domestic/lawtech';
import { DECOR, DECOR_CARS, DECOR_SLOTS, FURNISH_FLOOR_MAX, FURNISH_WALL_MAX, commonTier,
  decorCrowd, decorItems, decorParts, decorPercent, place, placeFurniture, readStore, receiveDecor, slotsOpen, takeBack } from '../src/game/domestic/decor';
import type { DecorCar, DecorKind, DecorSpot } from '../src/game/domestic/decor';
import { COMMS } from '../src/game/data';
import { situation } from '../src/game/state';
import type { Game } from '../src/game/state';
import type { LedgerRow } from '../src/game/ledger';
import { playGame } from './s1c_bot';

const ARMS = ['none', 'furnish_max', 'walls_first', 'rotate_set'] as const;
type Arm = typeof ARMS[number];
const TAIL_ORDER = ['tail1', 'tail2', 'tail3', 'guard', 'medtech', 'front'] as const;
const INSULATE_ORDER = ['tail1', 'tail2', 'tail3', 'medtech', 'guard', 'front'] as const;
const TRANSPORT = [
  { kind: 'sled', tech: 'x1', count: 2, wood: 2, scrap: 1, parts: 0 },
  { kind: 'stretcher', tech: 'x1', count: 1, wood: 3, scrap: 0, parts: 0 },
  { kind: 'cart', tech: 'x4', count: 1, wood: 3, scrap: 2, parts: 1 },
  { kind: 'runner', tech: 'x4', count: 2, wood: 0, scrap: 2, parts: 0 },
] as const;
const KINDS = Object.keys(DECOR) as DecorKind[];
const COLLECTIBLES = KINDS.filter(k => !DECOR[k].furniture);
const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / Math.max(1, xs.length);
const median = (xs: number[]): number | null => {
  if (!xs.length) return null;
  const sorted = [...xs].sort((a, b) => a - b);
  return (sorted[Math.floor((sorted.length - 1) / 2)] + sorted[Math.floor(sorted.length / 2)]) / 2;
};
function draw(seed: string, stop: number, lane: string): number {
  let h = 2166136261;
  for (const c of `${seed}:furniture:${stop}:${lane}`) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  h ^= h >>> 16; h = Math.imul(h, 0x7feb352d); h ^= h >>> 15; h = Math.imul(h, 0x846ca68b); h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}
function rolledFurniture(seed: string, stop: number): FurnitureKind | undefined {
  if (draw(seed, stop, 'arrive') >= 0.4) return undefined;
  const u = draw(seed, stop, 'size');
  const size: FurnitureSize = u < 0.6 ? 'small' : u < 0.9 ? 'medium' : 'large';
  const kinds = (Object.keys(FURNITURE) as FurnitureKind[]).filter(k => FURNITURE[k].size === size);
  return kinds[Math.floor(draw(seed, stop, 'kind') * kinds.length)];
}
function suppliedDecor(seed: string, stop: number): DecorKind[] {
  // Binomial(24, .5), mean 12. Neither game RNG nor the existing furniture stream is touched.
  return Array.from({ length: 24 }, (_, i) => i)
    .filter(i => draw(seed + ':decor', stop, 'arrive-' + i) < 0.5)
    .map(i => COLLECTIBLES[Math.floor(draw(seed + ':decor', stop, 'kind-' + i) * COLLECTIBLES.length)]);
}

/** Observe actual, clamped ledger deltas without changing a value, tag or game save.
 * V8 call sites retain the two domain function names. The self-check below
 * fails if this runtime cannot identify both sources, instead of silently reporting zero. */
function effectSource(): 'residential' | 'dining' | undefined {
  const previous = Error.prepareStackTrace;
  try {
    // Synchronous, restored before returning; avoid source-map rendering on every ledger entry.
    Error.prepareStackTrace = (_error, sites) => sites;
    const sites = new Error().stack as unknown as NodeJS.CallSite[];
    if (sites.some(site => site.getFunctionName() === 'residentialDecorTick')) return 'residential';
    if (sites.some(site => site.getFunctionName() === 'diningDecorTick')) return 'dining';
  } finally { Error.prepareStackTrace = previous; }
}
function meter(g: Game) {
  const totals = { residential: 0, dining: 0 };
  const rows = g.ledger ??= [];
  const push = rows.push;
  Object.defineProperty(rows, 'push', { configurable: true, value: function (...entries: LedgerRow[]) {
    for (const row of entries) if (row.why === 'furnish' && row.d > 0) {
      const source = effectSource();
      if (source) totals[source] += row.d;
    }
    return push.apply(this, entries);
  } });
  return totals;
}
function priority(g: Game): DecorCar[] {
  return [...TAIL_ORDER].sort((a, b) => furnishOf(g, b).tier - furnishOf(g, a).tier);
}
function stocked(g: Game, spot: DecorSpot): DecorKind[] {
  const store = readStore(g);
  return KINDS.filter(k => DECOR[k].spot === spot && (store[k]?.n ?? 0) > 0);
}
function put(g: Game, car: DecorCar, kind: DecorKind): boolean {
  const spot = DECOR[kind].spot;
  if (spot !== 'surface') return place(g, car, kind, spot).ok;
  const items = decorItems(g, car);
  const limit = DECOR_SLOTS[car === 'dining' || car === 'captain' ? commonTier(g) : furnishOf(g, car).tier].surface;
  // Fill the emptiest surface first so the occupied-surface share is not needlessly lost.
  const parents = items.flatMap((item, i) => DECOR[item.kind].surface
    ? [{ i, used: items.filter(other => other.spot === 'surface' && other.on === i).length }] : [])
    .filter(p => p.used < limit).sort((a, b) => a.used - b.used || a.i - b.i);
  return parents.length > 0 && place(g, car, kind, spot, undefined, undefined, parents[0].i).ok;
}
function fill(g: Game, car: DecorCar, spot: DecorSpot): number {
  let count = 0;
  while (slotsOpen(g, car)[spot] > 0) {
    const kinds = stocked(g, spot);
    const present = new Set(decorItems(g, car).map(item => item.kind));
    kinds.sort((a, b) => Number(present.has(a)) - Number(present.has(b)));
    if (!kinds.some(kind => put(g, car, kind))) break;
    count++;
  }
  return count;
}
function arrange(g: Game, arm: Arm): number {
  const cars: DecorCar[] = [...priority(g), 'dining', 'captain'];
  let placed = 0;
  if (arm === 'furnish_max') {
    for (const car of cars) for (const spot of ['floor', 'wall', 'surface'] as const) placed += fill(g, car, spot);
  } else if (arm === 'walls_first') {
    for (const car of cars) placed += fill(g, car, 'wall');
    for (const car of cars) {
      placed += fill(g, car, 'surface');
      while (stocked(g, 'surface').length && slotsOpen(g, car).floor > 0) {
        const surfaces = stocked(g, 'floor').filter(k => DECOR[k].surface)
          .sort((a, b) => decorCrowd([{ kind: a, size: DECOR[a].size }]) - decorCrowd([{ kind: b, size: DECOR[b].size }]));
        if (!surfaces.some(k => put(g, car, k))) break;
        placed++; placed += fill(g, car, 'surface');
      }
    }
  }
  return placed;
}

function run(seed: string, arm: Arm) {
  let stops = 0, settlements = 0, supplied = 0, furniture = 0, placed = 0;
  let observed: Game | undefined, totals = { residential: 0, dining: 0 };
  const crowd: number[] = [], made: Record<string, number> = {};
  const set: FurnitureKind[] = [];
  let rotatedCar: DecorCar | undefined;
  const observe = (g: Game) => {
    if (!observed) { observed = g; totals = meter(g); }
  };
  // The same restore/transport/insulate/furnish sequence as the existing tail arm.
  const policy = (g: Game) => {
    observe(g); if (g.phase === 'end') return;
    const d = g.dom!;
    if (!d.restoring) {
      for (const id of ['e5', 'w5'] as const) {
        if (d.techs[id]?.stage === 'defective' && !finishCheck(g, id) && startFinish(g, id)) break;
        if (!restoreCheck(g, id).full && startRestore(g, id, 'full')) break;
      }
      if (!d.restoring) for (const id of ['e5', 'w5'] as const)
        if (!restoreCheck(g, id).defect && startRestore(g, id, 'defect')) break;
    }
    for (const tool of TRANSPORT) {
      if (techMult(g, tool.tech) <= 0) continue;
      while ((made[tool.kind] ?? 0) < tool.count && d.wood >= tool.wood && d.scrap >= tool.scrap && d.parts >= tool.parts) {
        for (const key of ['wood', 'scrap', 'parts'] as const) d[key] -= tool[key];
        made[tool.kind] = (made[tool.kind] ?? 0) + 1;
      }
    }
    if (d.job) return;
    const nextInsulation = INSULATE_ORDER.find(car => !d.insulated.includes(car));
    if (nextInsulation && startJob(g, 'insulate', nextInsulation)) return;
    for (const car of TAIL_ORDER) {
      const step = nextFurnishWork(g, car);
      if (!step || (step >= 2 && !d.insulated.includes(car))) continue;
      if (startJob(g, 'furnish', car, step)) break;
    }
  };
  const { g, m } = playGame(seed, { s1c: true, policy: 'caretaker', dom: 'engaged', probe: {
    beforePick: observe, afterPick: policy, beforePrep: policy, afterPrep: observe,
    afterStop(g) {
      observe(g);
      const stop = stops++, kind = rolledFurniture(seed, stop);
      const gained = suppliedDecor(seed, stop); supplied += gained.length;
      receiveDecor(g, gained); // Tags for numbers already earned by the bot, never extra food/luxury.
      if (kind) { furniture++; receiveDecor(g, [kind]); }
      if (arm === 'none') {
        if (kind && TAIL_ORDER.some(car => placeFurniture(g, car, kind).ok)) placed++;
      } else if (arm === 'rotate_set') {
        if (rotatedCar) while (decorItems(g, rotatedCar).length) {
          if (!takeBack(g, rotatedCar, decorItems(g, rotatedCar).length - 1).ok) throw new Error('rotation removal failed');
        }
        let points = set.reduce((sum, k) => sum + FURNITURE_SIZE[FURNITURE[k].size].points, 0);
        const store = readStore(g);
        for (const k of Object.keys(FURNITURE) as FurnitureKind[]) {
          if (DECOR[k].spot !== 'floor') continue;
          const p = FURNITURE_SIZE[FURNITURE[k].size].points;
          let available = (store[k]?.n ?? 0) - set.filter(s => s === k).length;
          while (available-- > 0 && points + p <= D.furnishFurnitureCap) { set.push(k); points += p; }
        }
        rotatedCar = TAIL_ORDER[stop % TAIL_ORDER.length];
        for (const k of set) {
          if (!placeFurniture(g, rotatedCar, k).ok) throw new Error('rotation placement failed');
          placed++;
        }
      } else placed += arrange(g, arm);
      policy(g);
    },
    onSettle(g) {
      observe(g); settlements++;
      crowd.push(mean(FURNISH_CARS.map(car => situation(g, CAR_COMM[car])[2])));
      policy(g);
    },
  } });
  if (m.end === 'none') throw new Error('unfinished game: ' + arm + '/' + seed);
  const tier3 = FURNISH_CARS.filter(car => furnishOf(g, car).tier === 3).map(car => decorPercent(g, car));
  const rewards = g.journal.filter(row => /에 살림 [1-3]단:/.test(row.text) && row.text.includes('그 소리를 들었다.')).length;
  const best = FURNISH_CARS.reduce((sum, car) => sum + furnishOf(g, car).best, 0);
  if (rewards !== best || rewards > 18) throw new Error('furnishing reward history mismatch');
  return { seed, complete: m.end === 'complete', end: m.end, stops, settlements, supplied, furniture, placed,
    crowd: mean(crowd), tier3, reached80: tier3.some(p => p + D.decorEpsilon >= 0.8),
    decorRel: totals.residential, diningRel: totals.dining, rewards, diningPercent: decorPercent(g, 'dining') };
}
function wilson(wins: number, n: number): [number, number] {
  const p = wins / n, z = 1.959963984540054, d = 1 + z * z / n;
  const c = (p + z * z / (2 * n)) / d, half = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d;
  return [c - half, c + half];
}
function summarize(rows: ReturnType<typeof run>[]) {
  const wins = rows.filter(r => r.complete).length, tier3Games = rows.filter(r => r.tier3.length).length;
  const games80 = rows.filter(r => r.reached80).length;
  return { games: rows.length, wins, completion: wins / rows.length, wilson95: wilson(wins, rows.length),
    crowd: mean(rows.map(r => r.crowd)), tier3Median: median(rows.flatMap(r => r.tier3)),
    tier3Games, games80, share80: tier3Games ? games80 / tier3Games : null,
    decorRel: mean(rows.map(r => r.decorRel)), diningRel: mean(rows.map(r => r.diningRel)),
    rewardMean: mean(rows.map(r => r.rewards)), rewardMax: Math.max(...rows.map(r => r.rewards)),
    diningMedian: median(rows.map(r => r.diningPercent)), stops: mean(rows.map(r => r.stops)),
    suppliedPerStop: rows.reduce((s, r) => s + r.supplied, 0) / rows.reduce((s, r) => s + r.stops, 0),
    furniturePerGame: mean(rows.map(r => r.furniture)), placedPerGame: mean(rows.map(r => r.placed)),
    rowsHash: createHash('sha256').update(JSON.stringify(rows)).digest('hex') };
}

/** Exhaust all surface counts. Each count uses the largest possible kind and light diversity.
 * The six surface furniture kinds and nine other floor kinds make these bounds simultaneously attainable.
 * Build each winning witness through the real inventory/place functions to check the bound. */
function diningMaximum(tier: 1 | 2 | 3) {
  const slots = DECOR_SLOTS[tier], floor = Math.min(slots.floor, FURNISH_FLOOR_MAX.dining);
  const wall = Math.min(slots.wall, FURNISH_WALL_MAX.dining);
  const surfaces = KINDS.filter(k => DECOR[k].surface);
  const others = ['oil_lamp', 'small_stove', ...KINDS.filter(k => DECOR[k].spot === 'floor' && !DECOR[k].surface && !['oil_lamp', 'small_stove'].includes(k))] as DecorKind[];
  const smallKinds = KINDS.filter(k => DECOR[k].spot === 'surface');
  const walls = KINDS.filter(k => DECOR[k].spot === 'wall');
  const candidates = Array.from({ length: floor + 1 }, (_, surfaceCount) => {
    const other = floor - surfaceCount, small = Math.min(D.decorSmallTarget, surfaceCount * slots.surface);
    const kindCount = Math.min(surfaceCount, surfaces.length) + Math.min(other, others.length)
      + Math.min(wall, walls.length) + Math.min(small, smallKinds.length);
    const parts = [Math.min(1, kindCount / Math.min(D.decorKindMax, Math.floor(KINDS.length * D.decorKindShare))),
      Math.min(1, floor / Math.min(D.decorFloorTarget, FURNISH_FLOOR_MAX.dining)),
      Math.min(1, wall / Math.min(D.decorWallTarget, FURNISH_WALL_MAX.dining)),
      surfaceCount > 0 ? 1 : 0, small / D.decorSmallTarget, Math.min(2, other) / D.decorLightTarget];
    return { surfaceCount, other, small, kindCount, parts, percent: mean(parts) };
  });
  const best = candidates.reduce((a, b) => b.percent > a.percent ? b : a);
  const g = createS1cGame('dining-maximum-' + tier);
  g.dom!.furnish!.front = { work: tier, jobs: ([1, 2, 3] as const).filter(n => n <= tier), furnPts: 0, tier, best: tier, items: [] };
  g.food = 10000; g.lux = 10000;
  const add = (kind: DecorKind, on?: number) => {
    receiveDecor(g, [kind]);
    if (!place(g, 'dining', kind, DECOR[kind].spot, undefined, undefined, on).ok) throw new Error('maximum witness does not fit');
  };
  for (let i = 0; i < best.surfaceCount; i++) add(surfaces[i % surfaces.length]);
  for (let i = 0; i < best.other; i++) add(others[i % others.length]);
  for (let i = 0; i < wall; i++) add(walls[i % walls.length]);
  for (let i = 0; i < best.small; i++) add(smallKinds[i % smallKinds.length], i % best.surfaceCount);
  const actual = decorPercent(g, 'dining');
  if (Math.abs(actual - best.percent) > 1e-12) throw new Error('maximum witness does not reach bound');
  return { tier, floor, wall, perSurface: slots.surface, ...best, actualParts: decorParts(g, 'dining') };
}

function checkMeter(): boolean {
  const g = createS1cGame('meter-check');
  for (const car of FURNISH_CARS) g.dom!.furnish![car] = { work: 3, jobs: [1, 2, 3], tier: 3, best: 3, furnPts: 0, items: [] };
  for (const c of COMMS) { g.comms[c].rel = 0; g.comms[c].pop = 10; }
  // Four kinds, full floor/wall and both light kinds: each selected car exceeds 50%.
  for (const car of ['front', 'dining']) {
    const kinds: DecorKind[] = ['oil_lamp', 'small_stove'];
    while (kinds.length < FURNISH_FLOOR_MAX[car]) kinds.push('chair');
    kinds.push(...Array<DecorKind>(8).fill('frame'));
    g.dom!.furnish![car] = { ...(car === 'front' ? furnishOf(g, car) : {}), items: kinds.map(kind => ({ kind, size: DECOR[kind].size, spot: DECOR[kind].spot })) };
  }
  const actual = meter(g), res = decorRelGain(g, 'front'), dining = 4 * decorRelGain(g, 'dining');
  furnishTick(g);
  if (res <= 0 || dining <= 0 || Math.abs(actual.residential - res) > 1e-12 || Math.abs(actual.dining - dining) > 1e-12)
    throw new Error('ledger source observation unavailable in this runtime');
  return true;
}
const n = Number(process.argv[2] ?? 300);
if (!Number.isInteger(n) || n <= 0 || process.argv.length > 3) throw new Error('usage: decor_sim.ts [positive game count]');
const selfCheck = checkMeter(), maximum = ([1, 2, 3] as const).map(diningMaximum);
const results = Object.fromEntries(ARMS.map(arm => [arm, summarize(Array.from({ length: n }, (_, i) => run('fu-' + i, arm)))])) as Record<Arm, ReturnType<typeof summarize>>;
const base = results.none, max = results.furnish_max, wall = results.walls_first, rotate = results.rotate_set;
const gates = {
  '1': max.completion - base.completion >= -0.03 - 1e-12,
  '2': wall.crowd < max.crowd && wall.tier3Median !== null && max.tier3Median !== null && wall.tier3Median >= max.tier3Median - 1e-12,
  '3': max.share80 !== null && max.share80 >= 0.5,
  '4': max.completion - base.completion < 0.06 - 1e-12,
  '5': rotate.rewardMax <= 18 && rotate.completion - base.completion < 0.06 - 1e-12,
};
console.log(JSON.stringify({ n, seeds: 'fu-0..fu-' + (n - 1), meterSelfCheck: selfCheck,
  supply: { distribution: 'Binomial(24, .5)', mean: 12, kinds: COLLECTIBLES, numbersAdded: 0 },
  results, maximum, gates }));
