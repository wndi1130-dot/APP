import { describe, expect, it } from 'vitest';
import { createGame, enactLaw, repealLaw } from '../../src/game';
import type { Game } from '../../src/game';

// 시스템 통합 보고서 A23: 표를 사서 세운 법을 개정(변형 법)하면 그 거래가 변형 법으로 넘어간다.

function game(seed: string): Game {
  const g = createGame(seed);
  g.cards = [];
  return g;
}
const betrayed = (g: Game) => g.journal.some(j => j.text.includes('배신으로 기억한다'));

describe('개정과 약속으로 산 표(boughtBy)', () => {
  it('사서 세운 원래 법을 개정하면 거래가 변형 법으로 넘어가고, 변형을 3회기 안에 뒤집으면 배신이다', () => {
    const g = game('ba-1');
    g.session = 4;
    enactLaw(g, 'seed_grain', ['front']);
    expect(g.boughtBy.seed_grain).toEqual({ comms: ['front'], session: 4 });
    g.session = 5;
    enactLaw(g, 'seed_half', []);
    expect(g.boughtBy.seed_grain).toBeUndefined();
    expect(g.boughtBy.seed_half).toEqual({ comms: ['front'], session: 4 });
    g.session = 6;
    repealLaw(g, 'seed_half');
    expect(betrayed(g)).toBe(true);
    expect(g.boughtBy.seed_half).toBeUndefined();
  });

  it('산 지 3회기가 넘은 뒤에 변형을 뒤집으면 배신이 아니다', () => {
    const g = game('ba-2');
    g.session = 1;
    enactLaw(g, 'seed_grain', ['front']);
    g.session = 3;
    enactLaw(g, 'seed_half', []);
    g.session = 5;
    repealLaw(g, 'seed_half');
    expect(betrayed(g)).toBe(false);
  });

  it('개정 표결에서도 표를 샀으면 두 거래의 칸이 합쳐지고 구간은 이번 것이다', () => {
    const g = game('ba-3');
    g.session = 4;
    enactLaw(g, 'seed_grain', ['front']);
    g.session = 5;
    enactLaw(g, 'seed_half', ['engine', 'front']);
    expect(g.boughtBy.seed_half).toEqual({ comms: ['front', 'engine'], session: 5 });
  });

  it('산 적 없는 법의 개정은 변형에 거래를 만들지 않는다', () => {
    const g = game('ba-4');
    enactLaw(g, 'seed_grain', []);
    enactLaw(g, 'seed_half', []);
    expect(g.boughtBy).toEqual({});
  });
});
