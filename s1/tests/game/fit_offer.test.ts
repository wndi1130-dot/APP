import { describe, expect, it } from 'vitest';
import { createS1cGame, fitHasChoice, offerRestores } from '../../src/game';

// '설계도가 맞았다'는 고를 게 있을 때만 카드로 온다. 없으면 일지 한 줄(H6 반복, s1c_domestic 10장 1·2번).
describe('설계도가 맞았다: 고를 게 있을 때만 카드', () => {
  it('싫어하는 쪽이 있는 기술은 카드, 없는 기술은 일지 한 줄. 둘 다 한 번뿐', () => {
    const g = createS1cGame('fit-offer');
    for (const b of Object.keys(g.dom!.frags)) (g.dom!.frags as Record<string, number>)[b] = 99;
    offerRestores(g);
    const fits = g.cards.filter(c => c.kind === 'dom:fit').map(c => c.text).sort();
    expect(fits).toEqual(['e5', 'm5']);
    expect(g.journal.some(j => j.text.includes('설계도가 맞았다') && j.text.includes('공방에서 복원할 수 있다'))).toBe(true);
    expect(g.dom!.offered).toEqual(expect.arrayContaining(['e1', 'e5', 'm1', 'm5']));
    const n = g.journal.length;
    offerRestores(g);
    expect(g.cards.filter(c => c.kind === 'dom:fit')).toHaveLength(2);
    expect(g.journal.length).toBe(n);
  });

  it('조각이 반만 맞으면(결함판으로 갈지 갈림) 싫어하는 쪽이 없어도 카드', () => {
    const g = createS1cGame('fit-half');
    g.dom!.frags.engine = 1;
    expect(fitHasChoice(g, 'e2')).toBe(true);
    g.dom!.frags.engine = 2;
    expect(fitHasChoice(g, 'e2')).toBe(false);
  });
});
