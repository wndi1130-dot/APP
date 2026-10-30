import { describe, expect, it } from 'vitest';
import { COMMS } from '../../src/game/data';
import { createS1cGame, furnishOf } from '../../src/game/domestic/state';
import { CAR_COMM, COMM_CARS, D, FURNISH_CARS } from '../../src/game/domestic/data';
import { DECOR, DECOR_CARS, FURNISH80, FURNISH_FLOOR_MAX, FURNISH_WALL_MAX,
  decorBand, decorItems, decorParts, decorPercent } from '../../src/game/domestic/decor';
import type { DecorCar, DecorItem, DecorKind } from '../../src/game/domestic/decor';
import { decorRelGain, decorVoice, furnishTick } from '../../src/game/domestic/lawtech';
import type { Game } from '../../src/game/state';
import { readSave, SAVE_VERSION } from '../../src/ui/repro';

const item = (kind: DecorKind, on?: number): DecorItem => ({
  kind, size: DECOR[kind].size, spot: DECOR[kind].spot,
  ...(on === undefined ? {} : { on }), ...(DECOR[kind].v ? { v: DECOR[kind].v } : {}),
});
function fresh(): Game {
  const g = createS1cGame('decor-effect');
  for (const car of FURNISH_CARS)
    g.dom!.furnish![car] = { work: 3, jobs: [1, 2, 3], furnPts: 0, tier: 3, best: 3, items: [] };
  for (const c of COMMS) { g.comms[c].rel = 0; g.comms[c].pop = 10; }
  g.journal = []; g.ledger = [];
  return g;
}
function putItems(g: Game, car: string, items: DecorItem[]): void {
  if (g.dom!.furnish![car]) g.dom!.furnish![car].items = items;
  else g.dom!.furnish![car] = { items };
}
function decorated(g: Game, car: DecorCar, small = 66): void {
  const floors: DecorKind[] = ['side_table', 'small_shelf', 'drawer', 'table', 'bookshelf', 'cupboard',
    'oil_lamp', 'small_stove', 'chair', 'small_box'];
  while (floors.length < Math.min(25, FURNISH_FLOOR_MAX[car])) floors.push('side_table');
  const items = floors.map(k => item(k));
  const surfaces = floors.flatMap((k, i) => DECOR[k].surface ? [i] : []);
  const walls: DecorKind[] = ['frame', 'painting', 'rare_violin'];
  while (walls.length < Math.min(8, FURNISH_WALL_MAX[car])) walls.push('painting');
  items.push(...walls.map(k => item(k)));
  const smallKinds = (Object.keys(DECOR) as DecorKind[]).filter(k => DECOR[k].spot === 'surface');
  for (let i = 0; i < small; i++) items.push(item(smallKinds[i % smallKinds.length], surfaces[i % surfaces.length]));
  putItems(g, car, items);
  if (FURNISH_CARS.some(c => c === car)) furnishOf(g, car).furnPts = 4;
}

describe('꾸밈 여섯 몫', () => {
  it('빈 칸·알 수 없는 칸은 0이고 읽기는 상태를 바꾸지 않는다', () => {
    const g = fresh(), before = structuredClone(g);
    for (const car of [...DECOR_CARS, 'engine', 'unknown']) expect(decorPercent(g, car)).toBe(0);
    expect(g).toEqual(before);
  });
  it('갈래 20에서 차고, 목록이 늘면 22까지만 줄이 오른다', () => {
    const g = fresh(), kinds = Object.keys(DECOR) as DecorKind[];
    for (const n of [19, 20, 25]) {
      putItems(g, 'front', kinds.slice(0, n).map(k => item(k)));
      expect(decorParts(g, 'front')[0]).toBe(Math.min(1, n / 20));
    }
    const table = DECOR as Record<string, typeof DECOR.chair>;
    try {
      for (let i = 0; i < 10; i++) table['test_kind_' + i] = DECOR.chair;
      putItems(g, 'front', kinds.slice(0, 20).map(k => item(k)));
      expect(decorParts(g, 'front')[0]).toBe(20 / 22);
    } finally { for (let i = 0; i < 10; i++) delete table['test_kind_' + i]; }
  });
  it.each(DECOR_CARS)('%s 바닥·벽은 칸 최대에서 자른 줄을 쓴다', car => {
    const g = fresh();
    for (const [spot, kind, target, index] of [
      ['floor', 'chair', Math.min(25, FURNISH_FLOOR_MAX[car]), 1],
      ['wall', 'frame', Math.min(8, FURNISH_WALL_MAX[car]), 2],
    ] as const) for (const n of [target - 1, target, target + 1]) {
      putItems(g, car, Array.from({ length: n }, () => item(kind)));
      expect(decorParts(g, car)[index], spot).toBe(Math.min(1, n / target));
    }
  });
  it('면 보임은 면 가구별 한 번, 80%에서 자르고 면 가구가 없으면 0', () => {
    const g = fresh();
    expect(decorParts(g, 'front')[3]).toBe(0);
    for (const n of [0, 1, 3, 4, 5]) {
      putItems(g, 'front', [...Array.from({ length: 5 }, () => item('table')),
        ...Array.from({ length: n }, (_, i) => item('record', i)), ...(n ? [item('record', 0)] : [])]);
      expect(decorParts(g, 'front')[3]).toBeCloseTo(Math.min(1, n / 5 / 0.8), 12);
    }
  });
  it('작은 물건 66개에서 차고, 난로 두 종류는 빛 한 갈래', () => {
    const g = fresh();
    for (const n of [65, 66, 67]) {
      putItems(g, 'front', [item('table'), ...Array.from({ length: n }, () => item('record', 0))]);
      expect(decorParts(g, 'front')[4]).toBe(Math.min(1, n / 66));
    }
    for (const [kinds, expected] of [
      [[], 0], [['small_stove', 'iron_stove'], 0.5], [['oil_lamp', 'oil_lamp'], 0.5],
      [['small_stove', 'iron_stove', 'oil_lamp', 'oil_lamp'], 1],
    ] as [DecorKind[], number][]) {
      putItems(g, 'front', kinds.map(k => item(k)));
      expect(decorParts(g, 'front')[5]).toBe(expected);
    }
  });
  it.each(DECOR_CARS)('%s는 여섯 몫 모두 채워 100%에 닿는다', car => {
    const g = fresh(); decorated(g, car);
    expect(decorParts(g, car)).toEqual([1, 1, 1, 1, 1, 1]);
    expect(decorPercent(g, car)).toBe(1);
  });
});

describe('정산 사기·처음 80%', () => {
  it.each(D.decorThresholds.map((line, band) => ({ line, band })))('$line 문턱의 공통 오차 1e-9', ({ line, band }) => {
    expect(decorBand(line - 2e-9)).toBe(band - 1);
    expect(decorBand(line - 0.5e-9)).toBe(band);
    expect(decorBand(line)).toBe(band);
    expect(decorBand(line + 0.5e-9)).toBe(band);
  });
  it.each([0, 1, 2, 3] as const)('%s단의 50·80·100은 가장 큰 하나, 80·100 몫은 3단만', tier => {
    const g = fresh();
    for (const [small, reward] of [[1, 0.3], [24, 0.6], [66, 1]] as const) {
      decorated(g, 'front', small); furnishOf(g, 'front').tier = tier;
      expect(decorRelGain(g, 'front')).toBe(tier === 3 ? reward : 0.3);
    }
  });
  it.each(FURNISH_CARS)('%s 몫은 공동체 칸 수로 나눈다', car => {
    const g = fresh(); decorated(g, car); furnishTick(g);
    for (const c of COMMS) expect(g.comms[c].rel).toBeCloseTo(c === CAR_COMM[car] ? 1 / COMM_CARS[c] : 0, 12);
    expect(g.ledger!.every(row => row.why === 'furnish')).toBe(true);
  });
  it.each([[1, 0.1], [24, 0.2], [66, 0.3]])('식당 작은 물건 %s개: 단 조건 없이 공동체마다 %s', (small, reward) => {
    const g = fresh(); decorated(g, 'dining', small);
    for (const car of FURNISH_CARS) furnishOf(g, car).tier = 0;
    furnishTick(g);
    for (const c of COMMS) expect(g.comms[c].rel).toBeCloseTo(c === 'engine' ? 0 : reward, 12);
  });
  it('열차장실은 일지만, 사기와 말 없음', () => {
    const g = fresh(); decorated(g, 'captain'); furnishTick(g);
    for (const c of COMMS) expect(g.comms[c].rel).toBe(0);
    expect(g.journal).toEqual([{ seg: g.seg, text: FURNISH80.captain.journal, tone: 'good' }]);
  });
  it('꼬리칸 셋+식당은 1.3, 관계 상한에서는 실제 오른 만큼만 장부에 남긴다', () => {
    const g = fresh();
    for (const car of ['tail1', 'tail2', 'tail3', 'dining'] as const) decorated(g, car);
    furnishTick(g); expect(g.comms.tail.rel).toBeCloseTo(1.3, 12);
    g.comms.tail.rel = 99.95; g.ledger = [];
    furnishTick(g); expect(g.comms.tail.rel).toBe(100);
    expect(g.ledger!.filter(r => r.k === 'rel:tail').reduce((s, r) => s + r.d, 0)).toBeCloseTo(0.05, 12);
  });
  it('놓인 동안에는 기록하지 않고, 정산에서 한 번만; 내려갔다 다시 와도 반복 없음', () => {
    const g = fresh(), rng = structuredClone(g.rng);
    for (const car of DECOR_CARS) decorated(g, car);
    expect(g.dom!.decor80 ?? []).toEqual([]); expect(g.journal).toEqual([]);
    furnishTick(g); expect(g.dom!.decor80).toEqual([...DECOR_CARS]);
    const count = g.journal.length, items = structuredClone(g.dom!.furnish);
    for (const car of DECOR_CARS) putItems(g, car, []);
    furnishTick(g); g.dom!.furnish = items; furnishTick(g);
    expect(g.journal).toHaveLength(count); expect(count).toBe(8); expect(g.rng).toEqual(rng);
  });
  it.each([[0, 0], [14.999, 0], [15, 1], [-14.999, 0], [-15, 2]])('관계 %s에서 말 %s, 정산 효과를 받기 전 값', (rel, mood) => {
    const g = fresh(); decorated(g, 'tail1'); g.comms.tail.rel = rel;
    expect(decorVoice(g, 'tail1')).toBe(FURNISH80.tail1.say[mood]);
    furnishTick(g);
    expect(g.journal[0].text).toBe(FURNISH80.tail1.journal + ' 「' + FURNISH80.tail1.say[mood] + '」');
    expect(g.journal[0].tone).toBe('good');
  });
  it.each([[50, 0], [69.999, 0], [70, 1], [25, 0], [24.999, 2]])('식당 신임 %s에서 말 %s', (trust, mood) => {
    const g = fresh(); decorated(g, 'dining'); g.trust = trust;
    furnishTick(g);
    expect(g.journal[0].text).toBe(FURNISH80.dining.journal + ' 「' + FURNISH80.dining.say[mood] + '」');
  });
  it('옛 저장은 decor80=[]로 읽고 버전·RNG를 유지하며 새 기록도 다시 읽는다', () => {
    const g = fresh(); g.version = SAVE_VERSION; delete g.dom!.decor80;
    const old = readSave(JSON.parse(JSON.stringify(g))); expect(old.ok).toBe(true);
    if (!old.ok) return;
    expect(old.g.dom!.decor80).toEqual([]); expect(old.g.rng).toEqual(g.rng); expect(old.g.version).toBe(SAVE_VERSION);
    decorated(old.g, 'front'); furnishTick(old.g);
    const again = readSave(JSON.parse(JSON.stringify(old.g))); expect(again.ok).toBe(true);
    if (again.ok) { expect(again.g.dom!.decor80).toEqual(['front']); expect(decorItems(again.g, 'front')).toEqual(decorItems(old.g, 'front')); }
  });
});
