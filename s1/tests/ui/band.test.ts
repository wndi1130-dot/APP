import { describe, expect, it } from 'vitest';
import { COMMS, createGame, standings } from '../../src/game';
import { fxDiff, fxSnap } from '../../src/ui/fx';
import { SIDE_LINE, segFill } from '../../src/ui/hud';

// 위 띠의 불만·중립·지지(사용자 2026-10-10 '불만이 반영이 안 된다'): 석수는 관계가 선을 넘을 때만 바뀌니,
// 그 사이의 움직임은 조각 안 채움(segFill)과 관계 쪽지(fx.rel)로 보여야 한다.

describe('띠 조각 채움', () => {
  it('선 안쪽에서는 관계가 내려갈수록 불만 쪽 채움이, 올라갈수록 지지 쪽 채움이 찬다', () => {
    expect(segFill(0)).toEqual({ side: 0, ratio: 0 });
    expect(segFill(-5).side).toBe(-1);
    expect(segFill(-5).ratio).toBeCloseTo(5 / 15);
    expect(segFill(-14).ratio).toBeGreaterThan(segFill(-9).ratio);
    expect(segFill(9)).toEqual({ side: 1, ratio: 9 / 15 });
  });

  it('이미 선을 넘은 칸은 조각 색이 말하니 채움이 없다', () => {
    for (const rel of [-15, -40, 15, 60]) expect(segFill(rel)).toEqual({ side: 0, ratio: 0 });
  });

  it('선은 standings()가 칸을 가르는 선과 같다', () => {
    const g = createGame('band');
    const c = COMMS[0];
    const side = (rel: number) => { g.comms[c].rel = rel; return standings(g).byComm.find(x => x.c === c)!.side; };
    expect([side(-SIDE_LINE), side(-SIDE_LINE + 1), side(SIDE_LINE - 1), side(SIDE_LINE)]).toEqual([-1, 0, 0, 1]);
  });
});

describe('석수가 그대로여도 관계 움직임은 보인다', () => {
  it('중립 칸의 관계가 −5 되면 불만 석수는 그대로지만 관계 쪽지와 채움이 바뀐다', () => {
    const g = createGame('band');
    const c = COMMS[0];
    g.comms[c].rel = -4;
    const before = fxSnap(g);
    const fill0 = segFill(g.comms[c].rel).ratio;
    g.comms[c].rel -= 5;
    const fx = fxDiff(before, g);
    expect(fx?.seats.unrest).toBe(0);
    expect(fx?.rel[c]).toBe(-5);
    expect(segFill(g.comms[c].rel).side).toBe(-1);
    expect(segFill(g.comms[c].rel).ratio).toBeGreaterThan(fill0);
  });

  it('선을 넘으면 그때 불만 석수가 한 번에 는다', () => {
    const g = createGame('band');
    const c = COMMS[0];
    g.comms[c].rel = -12;
    const before = fxSnap(g);
    g.comms[c].rel -= 5;
    const fx = fxDiff(before, g);
    expect(fx?.seats.unrest).toBeGreaterThan(0);
    expect(segFill(g.comms[c].rel)).toEqual({ side: 0, ratio: 0 });
  });
});
