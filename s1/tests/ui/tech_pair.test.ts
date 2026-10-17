import { describe, expect, it } from 'vitest';
import { TECHS, TECH_IDS, createS1cGame, enableScoutGear } from '../../src/game';
import { pairHalves } from '../../src/ui/domestic';

// 기술 화면의 「둘 중 하나」 칸(결정 068): 두 쪽이 나란히 서고, 한쪽을 고르면 다른 쪽은 닫힌다.

describe('둘 중 하나 칸', () => {
  const paired = TECH_IDS.filter(id => TECHS[id].variants);
  const single = TECH_IDS.filter(id => !TECHS[id].variants);

  it('변형이 있는 기술만 두 쪽으로 그린다', () => {
    // 핸드카(x2)의 두 갈래는 정찰 장비를 켠 판에만 있다(결정 371). 켠 판에서 본다.
    const g = createS1cGame('pair');
    enableScoutGear(g);
    expect(pairHalves(createS1cGame('pair'), 'x2')).toBeNull();
    expect(paired.length).toBeGreaterThan(0);
    for (const id of paired) expect(pairHalves(g, id)?.map(x => x.name)).toEqual([TECHS[id].variants!.a.name, TECHS[id].variants!.b.name]);
    for (const id of single) expect(pairHalves(g, id)).toBeNull();
  });

  it('고르기 전에는 둘 다 열려 있고, 고르면 고른 쪽만 남는다', () => {
    const g = createS1cGame('pair');
    const id = paired[0]!;
    expect(pairHalves(g, id)!.map(x => x.state)).toEqual(['open', 'open']);
    g.dom!.techs[id] = { ...(g.dom!.techs[id] ?? {}), variant: 'b' } as NonNullable<typeof g.dom>['techs'][typeof id];
    expect(pairHalves(g, id)!.map(x => x.state)).toEqual(['shut', 'on']);
  });
});
