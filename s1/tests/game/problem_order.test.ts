import { describe, expect, it } from 'vitest';
import { createS1cGame, D, pickPlace, prereqs, restoreCheck, restoreCost, ROUTE, TECHS } from '../../src/game';
import type { TechId } from '../../src/game';

// 문제의 차례(결정 136·140·144·145): 장소는 구간 묶음마다 무게가 다르고, 한 곳은 풀어 주는 구간에 못 박힌다.
// 「나」: 복원 재료가 부품 하나에서 부품·목재·고철로 나뉜다.

function counts(seg: number, n = 2000, exclude?: string): Record<string, number> {
  const out: Record<string, number> = {};
  for (let i = 0; i < n; i += 1) {
    const g = createS1cGame(`route-${seg}-${i}`);
    g.seg = seg;
    const id = pickPlace(g, exclude).id;
    out[id] = (out[id] ?? 0) + 1;
  }
  return out;
}

describe('정차 장소는 구간 묶음의 무게로 정한다', () => {
  it('묶음 끝은 6·12·18·24이고 무게 0인 장소는 그 묶음에서 나오지 않는다', () => {
    expect(ROUTE.map(b => b.to)).toEqual([6, 12, 18, 24]);
    for (const [seg, none] of [[3, ['freight', 'factory']], [9, []], [15, ['houses']], [20, ['factory']]] as [number, string[]][]) {
      const c = counts(seg);
      for (const id of none) expect(c[id] ?? 0).toBe(0);
    }
  });

  it('무게가 큰 장소가 더 자주 나온다(구간 15: 공장 30이 주택가 0·화물역 5보다 많다)', () => {
    const c = counts(15);
    expect(c.factory).toBeGreaterThan(c.freight ?? 0);
    expect(c.hospital).toBeGreaterThan(c.freight ?? 0);
  });

  it('풀어 주는 구간은 정해 둔 장소 가운데서만 나온다', () => {
    for (const b of ROUTE) {
      const c = counts(b.relief.seg, 400);
      for (const id of Object.keys(c)) expect(b.relief.places).toContain(id);
    }
  });

  it('풀어 주는 구간이라도 뺀 장소(수동차 후보)는 나오지 않고, 남는 곳이 없으면 무게로 돌아간다', () => {
    const c = counts(6, 400, 'freight');
    expect(c.freight ?? 0).toBe(0);
    expect(c.factory).toBeGreaterThan(0);
    const only = counts(12, 400, 'houses'); // 구간 12의 풀어 주는 장소는 houses 하나뿐이라 무게로 돌아간다
    expect(only.houses ?? 0).toBe(0);
    expect(Object.keys(only).length).toBeGreaterThan(0);
  });

  it('구간 24를 넘으면 마지막 묶음을 쓴다', () => {
    const c = counts(30, 600);
    expect(c.factory ?? 0).toBe(0);
    expect(c.houses).toBeGreaterThan(0);
  });

  it('같은 판·같은 구간이면 같은 장소다(무작위는 한 번만 쓴다)', () => {
    const a = createS1cGame('same'); a.seg = 9;
    const b = createS1cGame('same'); b.seg = 9;
    expect(pickPlace(a).id).toBe(pickPlace(b).id);
  });
});

describe('복원 재료가 부품·목재·고철로 나뉜다', () => {
  it('단계마다 쓰는 재료가 다르다', () => {
    const ids = Object.keys(TECHS) as TechId[];
    const by = (tier: number) => TECHS[ids.find(id => TECHS[id].tier === tier)!].id;
    const c1 = restoreCost(by(1)); const c2 = restoreCost(by(2)); const c3 = restoreCost(by(3));
    expect([c1.parts, c1.wood, c1.scrap]).toEqual([D.restoreParts[1], D.restoreWood[1], D.restoreScrap[1]]);
    expect(c1.parts).toBe(0); expect(c1.wood).toBeGreaterThan(0); expect(c1.scrap).toBe(0);
    expect(c2.parts).toBe(0); expect(c2.wood).toBeGreaterThan(0); expect(c2.scrap).toBeGreaterThan(0);
    expect(c3.parts).toBeGreaterThan(0); expect(c3.wood).toBe(0); expect(c3.scrap).toBeGreaterThan(0);
  });

  it('목재나 고철이 모자라면 복원을 시작할 수 없다', () => {
    const g = createS1cGame('rc');
    g.seg = 8;
    const id = (Object.keys(TECHS) as TechId[]).find(t => TECHS[t].tier === 2 && !TECHS[t].variants)!;
    const d = g.dom!;
    for (const pre of prereqs(id)) d.techs[pre] = { stage: 'done', defect: false, progress: 0, need: 0 };
    d.frags[TECHS[id].branch] = 9;
    d.wood = 200; d.scrap = 0;
    const need = restoreCost(id);
    expect(need.scrap).toBeGreaterThan(0);
    expect(restoreCheck(g, id).full).toBe('고철이 모자라다');
    d.scrap = 200; d.wood = 0;
    expect(restoreCheck(g, id).full).toBe('목재가 모자라다');
  });
});
