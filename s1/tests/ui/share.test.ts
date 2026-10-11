import { describe, expect, it } from 'vitest';
import { COMMS, createGame, createS1cGame, seats, standings } from '../../src/game';
import { moodMean, scalePos, seatLine, sharePcts } from '../../src/ui/share';

// 의석을 비율로 보이기(사용자 2026-10-11). 띠의 세 숫자는 합이 100이어야 하고 조각 너비(석수)와 같은 것을 말해야 한다.

describe('의석 비율', () => {
  it('합이 늘 100이다(반올림으로 99나 101이 되지 않는다)', () => {
    expect(sharePcts([45, 40, 15])).toEqual([45, 40, 15]);
    expect(sharePcts([1, 1, 1])).toEqual([34, 33, 33]);
    expect(sharePcts([46, 13, 42]).reduce((a, b) => a + b, 0)).toBe(100);
    expect(sharePcts([0, 85, 15])).toEqual([0, 85, 15]);
    expect(sharePcts([0, 0, 0])).toEqual([0, 0, 0]);
  });

  it('새 판의 띠 세 숫자와 칸별 비율은 석수와 같은 차례·같은 크기 관계를 지킨다', () => {
    for (const g of [createGame('share'), createS1cGame('share')]) {
      const st = standings(g);
      const [u, n, s] = sharePcts([st.unrest, st.neutral, st.support]);
      expect(u + n + s).toBe(100);
      const map = seats(g);
      const per = sharePcts(COMMS.map(c => map[c]));
      expect(per.reduce((a, b) => a + b, 0)).toBe(100);
      COMMS.forEach((a, i) => COMMS.forEach((b, j) => { if (map[a] > map[b]) expect(per[i]).toBeGreaterThanOrEqual(per[j]); }));
    }
  });

  it('석수는 쪽지 글로 내린다', () => {
    expect(seatLine([{ name: '꼬리칸', seats: 45 }, { name: '앞칸', seats: 15 }])).toBe('꼬리칸 45석, 앞칸 15석');
    expect(seatLine([])).toBe('없음');
  });
});

// 여론(결정 058): 위 띠는 의석 합이 아니라 「정도」를 보인다. 의석으로 무게를 준 관계 평균이다.
describe('여론 평균', () => {
  it('의석이 큰 집단의 관계가 더 무겁다', () => {
    expect(moodMean([{ seats: 50, rel: -20 }, { seats: 50, rel: 20 }])).toBe(0);
    expect(moodMean([{ seats: 75, rel: -20 }, { seats: 25, rel: 20 }])).toBe(-10);
    expect(moodMean([{ seats: 100, rel: 14 }])).toBe(14);
    expect(moodMean([])).toBe(0);
  });

  it('선을 넘지 않은 움직임도 값에 잡힌다(의석 판세는 그대로여도)', () => {
    const g = createS1cGame('mood');
    const row = () => COMMS.map(c => ({ seats: seats(g)[c], rel: g.comms[c].rel }));
    const before = moodMean(row());
    const st = standings(g);
    const c = COMMS.find(x => Math.abs(g.comms[x].rel) < 5 && seats(g)[x] >= 10) ?? COMMS[0];
    g.comms[c].rel -= 8;
    expect(moodMean(row())).toBeLessThan(before);
    if (Math.abs(g.comms[c].rel) < 15) expect(standings(g).unrest).toBe(st.unrest);
  });

  it('눈금 자리는 가운데가 0이고 끝에서 멈춘다', () => {
    expect(scalePos(0)).toBe(50);
    expect(scalePos(-25)).toBe(25);
    expect(scalePos(50)).toBe(100);
    expect(scalePos(-90)).toBe(0);
    expect(scalePos(50, 100)).toBe(75);
  });
});
