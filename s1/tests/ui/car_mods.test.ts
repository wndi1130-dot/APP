import { describe, expect, it } from 'vitest';
import { D, createS1cGame, jobCheck } from '../../src/game';
import { carModChips } from '../../src/ui/domestic';

// 칸 판 「개조」 덩이(설계 4부 5-5): 그 칸에 올릴 수 있는 개조만 칩으로, 못 올리면 까닭과 드는 값이 보인다.

describe('칸 판의 개조 칩', () => {
  it('사람 사는 칸에는 단열과 장갑이 드는 값과 함께 뜬다', () => {
    const g = createS1cGame('mods');
    const chips = carModChips(g, 'tail1');
    expect(chips.map(c => c.name)).toEqual(['단열', '장갑']);
    expect(chips[0].cost).toBe(`목재 ${D.insulateWood}`);
    expect(chips[1].cost).toBe(`고철 ${D.armorScrap}`);
  });

  it('규칙이 막으면 칩도 막히고 까닭이 같다', () => {
    const g = createS1cGame('mods');
    for (const c of carModChips(g, 'tail1')) {
      const chk = jobCheck(g, c.k, 'tail1');
      expect(c.ok).toBe(chk.ok);
      expect(c.why).toBe(chk.why);
    }
  });

  it('끝난 개조는 done이고 다시 못 올린다', () => {
    const g = createS1cGame('mods');
    g.dom!.insulated.push('tail1');
    const c = carModChips(g, 'tail1')[0];
    expect(c.done).toBe(true);
    expect(c.ok).toBe(false);
    expect(c.why).toBeUndefined();
  });

  it('기관차와 사람이 안 사는 칸에는 칩이 없다', () => {
    const g = createS1cGame('mods');
    expect(carModChips(g, 'engine')).toEqual([]);
    expect(carModChips(g, 'workshop')).toEqual([]);
  });
});
