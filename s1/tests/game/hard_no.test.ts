import { describe, expect, it } from 'vitest';
import { blocs, COMMS, createGame, hardShare, LAW_IDS, P, stance } from '../../src/game';
import type { Agenda, Comm, Deal, Game } from '../../src/game';

// 꿈쩍 않는 반대(사용자 2026-10-09): 뇌물·빚·협박·공개 약속·옮긴 표 어느 것도 이 표를 못 움직인다.
// 몫은 고정 수가 아니라 이념 충돌·관계·앙금에 따라 바뀐다.

/** 반대가 가장 많은 (안건, 칸) 하나 */
function opposed(g: Game): { a: Agenda; c: Comm } {
  let best: { a: Agenda; c: Comm; no: number } | null = null;
  for (const law of LAW_IDS) {
    const a = { law, repeal: false } as Agenda;
    const map = blocs(g, a);
    for (const c of COMMS) if (!best || map[c].no > best.no) best = { a, c, no: map[c].no };
  }
  return best!;
}

describe('꿈쩍 않는 반대', () => {
  it('반대가 있는 칸엔 꿈쩍 않는 몫이 있고, 반대표를 넘지 않는다', () => {
    const g = createGame('hard1');
    const { a, c } = opposed(g);
    const b = blocs(g, a)[c];
    expect(b.hard).toBeGreaterThan(0);
    expect(b.hard).toBeLessThanOrEqual(b.no);
    for (const law of LAW_IDS) for (const x of COMMS) {
      const y = blocs(g, { law, repeal: false } as Agenda)[x];
      expect(y.hard).toBeLessThanOrEqual(y.no);
    }
  });

  it('뇌물·빚·협박을 해도 꿈쩍 않는 몫은 반대로 남는다', () => {
    const g = createGame('hard2');
    const { a, c } = opposed(g);
    const hard = blocs(g, a)[c].hard;
    for (const tool of ['bribe', 'favor', 'blackmail', 'open'] as const) {
      const deals: Deal[] = [{ comm: c, tool, label: tool }];
      const b = blocs(g, a, deals)[c];
      expect(b.no, tool).toBeGreaterThanOrEqual(hard);
      if (tool !== 'open') expect(b.no, tool).toBe(hard);
    }
  });

  it('옮긴 표(사건)도 꿈쩍 않는 몫은 못 뺀다', () => {
    const g = createGame('hard3');
    const { a, c } = opposed(g);
    const hard = blocs(g, a)[c].hard;
    g.voteShift = [{ comm: c, n: 99, side: 'yes' }];
    expect(blocs(g, a)[c].no).toBe(hard);
  });

  it('몫은 관계와 이념에 따라 바뀐다', () => {
    const g = createGame('hard4');
    const c: Comm = 'tail';
    g.comms[c].rel = 50;
    const warm = hardShare(g, c, -2);
    g.comms[c].rel = -50;
    const cold = hardShare(g, c, -2);
    expect(cold).toBeGreaterThan(warm);
    expect(hardShare(g, c, -3)).toBeGreaterThan(hardShare(g, c, 0));
    expect(hardShare(g, c, -9)).toBeLessThanOrEqual(P.hardNoMax);
    expect(stance(g, c, { law: LAW_IDS[0], repeal: false } as Agenda).score).toBeTypeOf('number');
  });
});
