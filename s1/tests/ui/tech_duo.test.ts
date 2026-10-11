import { describe, expect, it } from 'vitest';
import type { TechId } from '../../src/game';
import { TECHS } from '../../src/game';
import { TECH_PAIRS, duoStates, tierCells } from '../../src/ui/tech_pairs';

// 기술 둘을 한 틀로 묶는 「둘 중 하나」 칸(결정 068). 짝 표는 아직 비어 있고, 틀과 자료를 받는 자리만 있다.

const ids = ['e2', 'e3', 'e4'] as TechId[];

describe('기술 짝 칸', () => {
  it('짝이 없으면 기술 하나가 칸 하나다', () => {
    expect(tierCells(ids, [])).toEqual(ids.map(id => ({ kind: 'one', id })));
  });

  it('짝의 두 쪽이 한 단계에 다 있으면 한 칸으로 묶고 차례는 먼저 나온 쪽을 따른다', () => {
    const cells = tierCells(ids, [['e4', 'e2']]);
    expect(cells).toEqual([{ kind: 'duo', ids: ['e4', 'e2'] }, { kind: 'one', id: 'e3' }]);
    expect(cells.length).toBe(2);
  });

  it('한쪽이 이 단계에 없으면 묶지 않는다', () => {
    expect(tierCells(['e2', 'e3'] as TechId[], [['e2', 'e4']])).toEqual([{ kind: 'one', id: 'e2' }, { kind: 'one', id: 'e3' }]);
  });

  it('얻은 쪽이 없으면 둘 다 열려 있고, 한쪽을 얻으면 다른 쪽은 닫힌다', () => {
    const pair = ['e2', 'e3'] as const;
    expect(duoStates(pair, () => false)).toEqual(['open', 'open']);
    expect(duoStates(pair, id => id === 'e3')).toEqual(['shut', 'on']);
  });

  it('짝 표에 든 기술은 코드에 있고 같은 가지, 같은 단계다', () => {
    for (const [a, b] of TECH_PAIRS) {
      expect(TECHS[a]).toBeDefined();
      expect(TECHS[b]).toBeDefined();
      expect(TECHS[a].branch).toBe(TECHS[b].branch);
      expect(TECHS[a].tier).toBe(TECHS[b].tier);
    }
  });
});
