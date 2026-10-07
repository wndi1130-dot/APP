import { describe, expect, it } from 'vitest';
import { COMMS, createGame, seats } from '../../src/game';

// 의석 배분의 기준은 game/state.ts의 seats()다(README, A2 코드 구조 점검 3번). core/council.ts의 allocateSeats는 플레이가 안 쓴다.
describe('의석 배분', () => {
  it('시작 200명: 꼬리칸 45, 앞칸 15, 기술·의무진 15, 기관실 12, 경비대 13(남은 의석 동률은 칸 순서로 푼다)', () => {
    const g = createGame('seats');
    expect(COMMS.map(c => g.comms[c].pop)).toEqual([90, 30, 25, 30, 25]);
    expect(seats(g)).toEqual({ tail: 45, medtech: 15, guard: 13, front: 15, engine: 12 });
  });

  it('언제나 100석이다', () => {
    const g = createGame('seats');
    for (const pops of [[1, 1, 1, 1, 1], [0, 0, 0, 0, 7], [33, 33, 33, 0, 1], [90, 31, 24, 30, 25]]) {
      COMMS.forEach((c, i) => { g.comms[c].pop = pops[i]; });
      expect(Object.values(seats(g)).reduce((a, b) => a + b, 0)).toBe(100);
    }
  });
});
