import { describe, expect, it } from 'vitest';
import { createS1cGame, hangSymbol } from '../../src/game';
import { wallFacts } from '../../src/ui/domestic';

// 상징물을 거는 벽 못(결정 053의 3번): 걸기 전에는 남은 수, 걸린 뒤에는 내릴 때 깎이는 값이 숫자로 보인다.

describe('벽 못', () => {
  it('상징물이 없으면 남은 0이고 못 거는 까닭이 있다', () => {
    const g = createS1cGame('wall');
    g.symbols = 0;
    const f = wallFacts(g, 'tail');
    expect(f.on).toBe(false);
    expect(f.left).toBe(0);
    expect(f.why).toBeTruthy();
  });

  it('걸면 남은 수가 줄고, 건 칸은 내릴 때의 값을 보인다', () => {
    const g = createS1cGame('wall');
    g.symbols = 2;
    expect(wallFacts(g, 'tail').left).toBe(2);
    expect(hangSymbol(g, 'tail')).toBe(true);
    const f = wallFacts(g, 'tail');
    expect(f.on).toBe(true);
    expect(f.why).toBeNull();
    expect(f.loss).toBe('결속 −8 · 관계 −4');
    expect(wallFacts(g, 'front').left).toBe(1);
  });

  it('결속은 소수 없이 적는다', () => {
    const g = createS1cGame('wall');
    expect(wallFacts(g, 'tail').gain).toBe('결속 +1/구간');
  });
});
