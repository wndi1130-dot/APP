import { describe, expect, it } from 'vitest';
import {
  cancelJob, COMMS, createS1cGame, FURNISH_CARS, FURNISH_WORK,
  furnishComparison, furnishOf, furnishScore, furnishTick, jobCheck, jobTitle, LAW_ONLY_TECHS,
  lawTechSit, migrateDomestic, placeFurniture, prereqs, PREREQ, refreshSit, removeFurniture, restoreBlock,
  restoreCost, runWorkshop, startJob, techAdopted, techUseLine, TECH_IDS, TECHS, usefulVariant, zeroSit,
} from '../../src/game';
import type { FurnitureKind, Game, TechId } from '../../src/game';

function fresh(): Game {
  const g = createS1cGame('furnish-test');
  Object.assign(g.dom!, { wood: 200, scrap: 200, parts: 30, target: 0, order: ['modify'] });
  return g;
}
function done(g: Game, id: TechId, defective = false): void {
  g.dom!.techs[id] = { stage: defective ? 'defective' : 'done', defect: defective, need: 0, progress: 0 };
}
function finish(g: Game): void {
  for (let i = 0; g.dom!.job && i < 20; i += 1) runWorkshop(g);
  expect(g.dom!.job).toBeNull();
}
function level(g: Game, car: string, n: number): void {
  done(g, 'w5');
  done(g, 'w1');
  g.dom!.insulated.push(car);
  for (let i = 0; i < n; i += 1) { expect(startJob(g, 'furnish', car)).toBe(true); finish(g); }
}
function place(g: Game, car: string, kind: FurnitureKind): void {
  expect(placeFurniture(g, car, kind)).toEqual({ ok: true });
}

describe('살림 작업과 가구', () => {
  it('옛 저장의 없는 키는 빈 살림으로 읽고 이주해도 RNG와 처지는 같다', () => {
    const g = fresh();
    delete g.dom!.furnish;
    const rng = structuredClone(g.rng);
    expect(furnishOf(g, 'front')).toMatchObject({ work: 0, furnPts: 0, tier: 0, best: 0, items: [] });
    const before = structuredClone(g.dom!.sit);
    refreshSit(g);
    expect(g.dom!.sit).toEqual(before);
    migrateDomestic(g);
    expect(g.dom!.furnish).toEqual({});
    expect(g.rng).toEqual(rng);
  });

  it('1단은 연구 없이 시작하고 천은 S1에서 셈하지 않는다(furnishClothWood 0)', () => {
    const g = fresh();
    expect(startJob(g, 'furnish', 'front')).toBe(true);
    expect(g.dom!.job).toMatchObject({ kind: 'furnish', need: 1, furnishStep: 1, paid: { wood: 1, scrap: 3, parts: 0 } });
    expect([g.dom!.wood, g.dom!.scrap]).toEqual([199, 197]);
    expect(jobCheck(g, 'furnish', 'tail1').why).toContain('이미');
    expect(jobTitle('furnish', 'front')).toContain('살림');
    expect(jobTitle('furnish', 'front')).not.toContain('온실');
  });

  it('2단은 1단·그 칸 단열·사용 중인 w5가 모두 필요하다', () => {
    const g = fresh();
    expect(jobCheck(g, 'furnish', 'front', 2).ok).toBe(false);
    startJob(g, 'furnish', 'front'); finish(g);
    expect(jobCheck(g, 'furnish', 'front').why).toContain('단열');
    g.dom!.insulated.push('front');
    expect(jobCheck(g, 'furnish', 'front').why).toContain('객차 목공');
    done(g, 'w5', true);
    expect(jobCheck(g, 'furnish', 'front').ok).toBe(true);
    g.dom!.techs.w5!.off = true;
    expect(jobCheck(g, 'furnish', 'front').ok).toBe(false);
  });

  it('3단은 2단·사용 중인 w5·공구 수리가 필요하고 시작 뒤 연구를 세워도 마친다', () => {
    const g = fresh();
    expect(jobCheck(g, 'furnish', 'front', 3).why).toBe('살림 2단부터');
    level(g, 'front', 2);
    delete g.dom!.techs.w1;
    done(g, 'w5', true);
    expect(jobCheck(g, 'furnish', 'front').why).toBe('공구 수리부터');
    done(g, 'w1', true);
    expect(jobCheck(g, 'furnish', 'front').ok).toBe(true);
    g.dom!.techs.w5!.off = true;
    expect(jobCheck(g, 'furnish', 'front').why).toContain('객차 목공');
    g.dom!.techs.w5!.off = false;
    expect(startJob(g, 'furnish', 'front')).toBe(true);
    g.dom!.techs.w5!.off = true;
    g.dom!.techs.w1!.off = true;
    finish(g);
    expect(furnishOf(g, 'front')).toMatchObject({ work: 3, tier: 3, best: 3 });
    expect(furnishScore(g, 'front')).toBe(15);
    expect(jobCheck(g, 'furnish', 'front').ok).toBe(false);
  });

  it('2·3단 값과 3단을 내리면 부품까지 모두 돌려준다', () => {
    const g = fresh(); level(g, 'front', 1);
    startJob(g, 'furnish', 'front');
    expect(g.dom!.job).toMatchObject({ need: 3, paid: { wood: 1, scrap: 6, parts: 0 } });
    finish(g);
    const before = [g.dom!.wood, g.dom!.scrap, g.dom!.parts];
    startJob(g, 'furnish', 'front');
    expect(g.dom!.job).toMatchObject({ need: 4, paid: { wood: 2, scrap: 8, parts: 2 } });
    expect(cancelJob(g)).toBe(true);
    expect([g.dom!.wood, g.dom!.scrap, g.dom!.parts]).toEqual(before);
    expect(g.dom!.greenhouse).toBeNull();
    expect(g.journal.at(-1)!.text).toContain('살림');
    startJob(g, 'furnish', 'front'); runWorkshop(g);
    expect(cancelJob(g)).toBe(false);
  });

  it('목재·고철·부품 부족을 각각 막고 작업이 끝나면 그 칸만 오른다', () => {
    const g = fresh(); level(g, 'front', 2);
    for (const key of ['wood', 'scrap', 'parts'] as const) {
      const before = g.dom![key]; g.dom![key] = 0;
      expect(jobCheck(g, 'furnish', 'front').ok).toBe(false);
      g.dom![key] = before;
    }
    startJob(g, 'furnish', 'front'); finish(g);
    expect(furnishOf(g, 'tail1').tier).toBe(0);
    expect(g.dom!.greenhouse).toBeNull();
    expect(g.dom!.armored).toEqual([]);
    expect(FURNISH_WORK[3].points).toBe(7);
  });

  it('기관실·화물칸·덧단 객차에는 살림을 놓거나 작업하지 않는다', () => {
    const g = fresh();
    for (const car of ['engine', 'store', 'extra-coach', 'missing']) {
      expect(jobCheck(g, 'furnish', car).ok).toBe(false);
      expect(placeFurniture(g, car, 'chair').ok).toBe(false);
    }
  });

  it('가구는 크기별 작은 4·중간 2·큰 1 자리이고 넘치면 바꾸지 않는다', () => {
    const g = fresh();
    for (const [kind, count] of [['chair', 4], ['table', 2], ['wardrobe', 1]] as const) {
      for (let i = 0; i < count; i += 1) place(g, 'front', kind);
      const before = JSON.stringify(g.dom!.furnish);
      expect(placeFurniture(g, 'front', kind).ok).toBe(false);
      expect(JSON.stringify(g.dom!.furnish)).toBe(before);
    }
    expect(furnishOf(g, 'front').items).toHaveLength(7);
  });

  it('가구는 4점까지만 세므로 2단 작업을 건너뛰지 못한다', () => {
    const g = fresh(); startJob(g, 'furnish', 'front'); finish(g);
    place(g, 'front', 'wardrobe'); place(g, 'front', 'table'); place(g, 'front', 'chair');
    expect(furnishOf(g, 'front')).toMatchObject({ furnPts: 4, tier: 1 });
    expect(furnishScore(g, 'front')).toBe(7);
    expect(startJob(g, 'furnish', 'front', 3)).toBe(false);
  });

  it('가구가 1단 작업을 대신하면 2단 작업의 5점만 더한다', () => {
    const g = fresh(); place(g, 'front', 'wardrobe');
    done(g, 'w5'); g.dom!.insulated.push('front');
    startJob(g, 'furnish', 'front'); finish(g);
    expect(furnishOf(g, 'front').jobs).toEqual([2]);
    expect(furnishScore(g, 'front')).toBe(8);
    expect(furnishOf(g, 'front').tier).toBe(2);
    expect(startJob(g, 'furnish', 'front', 2)).toBe(false);
    done(g, 'w1');
    startJob(g, 'furnish', 'front', 3); finish(g);
    const rel = g.comms.front.rel;
    // N단의 조건은 단 >= N-1와 미완료 작업이다. 이미 3단이어도 안 한 1단 작업을 명시하면 할 수 있다.
    expect(startJob(g, 'furnish', 'front', 1)).toBe(true); finish(g);
    expect(furnishScore(g, 'front')).toBe(18);
    expect(g.comms.front.rel).toBe(rel);
  });

  it('가구를 빼고 w5를 세워도 단은 유지되며 다시 놓아도 보너스가 없다', () => {
    const g = fresh(); const before = g.comms.front.rel;
    place(g, 'front', 'wardrobe');
    expect(g.comms.front.rel - before).toBe(2);
    expect(removeFurniture(g, 'front', 0).ok).toBe(true);
    done(g, 'w5'); g.dom!.techs.w5!.off = true;
    expect(furnishScore(g, 'front')).toBe(0);
    expect(furnishOf(g, 'front')).toMatchObject({ tier: 1, best: 1 });
    place(g, 'front', 'wardrobe');
    expect(g.comms.front.rel - before).toBe(2);
    expect(removeFurniture(g, 'front', -1).ok).toBe(false);
    expect(removeFurniture(g, 'front', 0.5).ok).toBe(false);
    expect(removeFurniture(g, 'front', 5).ok).toBe(false);
    expect(g.journal.filter(e => e.text.includes('그 소리를 들었다'))).toHaveLength(1);
  });

  it('가구를 뺀 뒤 점수가 모자라면 빠진 1단 작업으로 보충할 수 있다', () => {
    const g = fresh(); place(g, 'front', 'wardrobe');
    done(g, 'w5'); g.dom!.insulated.push('front');
    startJob(g, 'furnish', 'front'); finish(g);
    removeFurniture(g, 'front', 0);
    done(g, 'w1');
    startJob(g, 'furnish', 'front'); finish(g);
    expect(furnishScore(g, 'front')).toBe(12);
    expect(furnishOf(g, 'front').tier).toBe(2);
    startJob(g, 'furnish', 'front'); finish(g);
    expect(furnishScore(g, 'front')).toBe(15);
    expect(furnishOf(g, 'front').tier).toBe(3);
  });
});

describe('살림 처지와 정치', () => {
  it('처음 닿은 각 단의 보너스만 칸 수로 나눈다', () => {
    const g = fresh(); const r = g.comms.tail.rel;
    level(g, 'tail1', 3);
    expect(g.comms.tail.rel - r).toBeCloseTo((2 + 4 + 6) / 3);
    expect(g.journal.filter(e => e.text.includes('그 소리를 들었다'))).toHaveLength(3);
    expect(startJob(g, 'furnish', 'tail1')).toBe(false);
    expect(g.comms.tail.rel - r).toBeCloseTo(4);
  });

  it('온기는 칸마다 단·작은 난로·무쇠 난로 중 큰 것 하나만 센다', () => {
    const g = fresh(); level(g, 'tail1', 3);
    place(g, 'tail1', 'small_stove'); place(g, 'tail1', 'small_stove'); place(g, 'tail1', 'iron_stove');
    g.dom!.insulated = [];
    const s = zeroSit(); lawTechSit(g, s);
    expect(s.tail[0]).toBeCloseTo(4 / 3);
    expect(s.tail[2]).toBeCloseTo(-1.5 + 0.5 + 0.5 + 1.5);
    expect(s.tail[3]).toBe(0);
  });

  it('과밀은 칸 수로 나누지 않고 침대 틀의 −1을 함께 센다', () => {
    const g = fresh(); place(g, 'tail1', 'bed_frame');
    const s = zeroSit(); lawTechSit(g, s);
    expect(s.tail[2]).toBe(-0.5);
    place(g, 'tail2', 'wardrobe');
    const t = zeroSit(); lawTechSit(g, t);
    expect(t.tail[2]).toBe(0.5); // 침대 −0.5 + 장롱 1.5 − 1단 0.5
  });

  it('비교는 공동체 칸 평균으로 보고 gap 1 미만이면 벌이 없다', () => {
    const g = fresh(); level(g, 'tail1', 1);
    expect(Object.values(furnishComparison(g)).every(v => v === 0)).toBe(true);
    level(g, 'front', 1);
    const p = furnishComparison(g);
    expect(p.tail).toBe(0); expect(p.guard).toBe(-0.5); expect(p.medtech).toBe(-0.5);
  });

  it('비교 불만은 공동체 최대 −1, 열차 합 −2에서 비례로 줄인다', () => {
    const g = fresh(); level(g, 'front', 3);
    const p = furnishComparison(g);
    expect(Object.values(p).reduce((a, b) => a + b, 0)).toBeCloseTo(-2);
    expect([p.tail, p.guard, p.medtech]).toEqual([-2 / 3, -2 / 3, -2 / 3]);
    g.comms.medtech.pop = 0;
    const q = furnishComparison(g);
    expect(q.tail).toBe(-1); expect(q.guard).toBe(-1); expect(q.medtech).toBe(0);
  });

  it('기관실과 인구 0인 공동체는 비교의 기준과 벌 양쪽에서 뺀다', () => {
    const g = fresh(); level(g, 'front', 3); g.comms.front.pop = 0;
    g.dom!.furnish!.engine = { ...furnishOf(g, 'front'), items: [], jobs: [] };
    expect(Object.values(furnishComparison(g)).every(v => v === 0)).toBe(true);
    const before = COMMS.map(c => g.comms[c].rel);
    furnishTick(g);
    expect(COMMS.map(c => g.comms[c].rel)).toEqual(before);
  });

  it('피아노는 정산마다 공동체 하나만 +0.3, 비교 불만은 별도로 장부에 남는다', () => {
    const g = fresh();
    for (const car of FURNISH_CARS) place(g, car, 'piano');
    const before = Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel]));
    furnishTick(g); furnishTick(g);
    for (const c of COMMS) expect(g.comms[c].rel - before[c]).toBeCloseTo(c === 'engine' ? 0 : 0.6);
    level(g, 'front', 2); // 가구 1단 위에 2·3단 작업
    furnishTick(g);
    expect(g.ledger!.some(r => r.why === 'furnish' && r.k === 'rel:tail' && r.d < 0)).toBe(true);
  });
});

describe('연구 줄과 채택', () => {
  it('기술은 23개이며 x4는 2단, w5는 목재 4·부품 1의 0단 적응이다', () => {
    expect(TECH_IDS).toHaveLength(23);
    expect(restoreCost('x4')).toMatchObject({ wood: 10, scrap: 4, frags: 2, work: 6 });
    expect(TECHS.w5).toMatchObject({ tier: 0, adapt: { parts: 1, wood: 4 } });
    expect(restoreCost('w5')).toMatchObject({ wood: 4, parts: 1, scrap: 0, frags: 0, defectFrags: 0, core: 0 });
    expect(restoreCost('w5').work).toBe(restoreCost('e5').work);
  });

  it('선행 표가 x4→x3와 w5→w3 우회를 막고 나머지는 기존 셈이다', () => {
    const g = fresh(); done(g, 'x4'); done(g, 'w5');
    expect(prereqs('x3')).toEqual(['x2']); expect(prereqs('w3')).toEqual(['w2']);
    expect(prereqs('x4')).toEqual(['x1']); expect(prereqs('w5')).toEqual([]);
    expect(PREREQ).not.toHaveProperty('w5');
    expect(restoreBlock(g, 'x3')).toContain('핸드카 정찰');
    expect(restoreBlock(g, 'w3')).toContain('사냥과 방어');
    expect(prereqs('e4')).toEqual(['e2', 'e3']);
  });

  it('x1은 S1에서 법 기술이라 봇·공방장은 법 없이 안 사고, 쓸모 줄은 법 쓸모로 단다(S2 공방 썰매·들것)', () => {
    const g = fresh();
    expect(LAW_ONLY_TECHS).toContain('x1');
    expect(usefulVariant(g, 'x1')).toBeNull();
    expect(techUseLine(g, 'x1')).toMatch(/^법 쓸모:/);
    expect(techUseLine(g, 'e1')).toMatch(/^쓸모:/);
  });

  it('w5·x4는 S1 봇·공방장이 고를 쓸모가 없다(살림은 플레이어·재기 도구, 운반 도구는 S2 공방)', () => {
    const g = fresh();
    expect(usefulVariant(g, 'w5')).toBeNull();
    expect(usefulVariant(g, 'x4')).toBeNull();
  });

  it('x4는 완성판 사용, w5는 실제 2단 작업 뒤 채택으로 친다', () => {
    const g = fresh(); done(g, 'x4'); done(g, 'w5');
    expect(techAdopted(g, 'x4')).toBe(true);
    expect(techAdopted(g, 'w5')).toBe(false);
    level(g, 'front', 2);
    expect(techAdopted(g, 'w5')).toBe(true);
    g.dom!.techs.w5!.off = true;
    expect(techAdopted(g, 'w5')).toBe(false);
    expect(furnishOf(g, 'front').tier).toBe(2);
  });
});
