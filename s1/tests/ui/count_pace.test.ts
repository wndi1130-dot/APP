import { describe, expect, it } from 'vitest';
import type { VoteResult } from '../../src/game';
import { countSchedule, countSeconds, noiseStage } from '../../src/ui/count_pace';

// 개표 박자(presentation_motion.md 5b절 4).

function result(fixedYes: number, flips: boolean[], need = 51, decree = false): VoteResult {
  const yes = fixedYes + flips.filter(Boolean).length;
  return {
    yes, no: 100 - yes, absent: 0, need, passed: decree || yes >= need, decree,
    byComm: {} as VoteResult['byComm'], flips: flips.map(v => ({ comm: 'tail', yes: v })),
  };
}
const secs = (plan: [number, number][]) => plan.reduce((sum, [ms]) => sum + ms, 0) / 1000;

describe('개표 박자', () => {
  it('미정 표를 소란 단계 시간 안에 열고, 처음엔 느리고 점점 빠르다', () => {
    // 확정 찬성 45, 미정 30 중 찬성 10: 여섯 번째 찬성 돌(16번째 돌)에서 51이 되어 정해진다.
    const flips = Array.from({ length: 30 }, (_, i) => i % 3 === 0);
    const plan = countSchedule(result(45, flips), 0, 1);
    expect(plan[plan.length - 1][1]).toBe(30);
    expect(plan[0][0]).toBeGreaterThan(plan[5][0]);
    expect(plan.every(([ms]) => ms >= 50 && ms <= 600)).toBe(true);
    expect(secs(plan)).toBeLessThanOrEqual(2.5 + 0.6 * 5 + 0.01);
  });
  it('정해지는 순간 남은 돌을 한꺼번에 연다', () => {
    // 확정 찬성 50, 필요 51: 첫 찬성 돌에서 통과가 정해진다.
    const plan = countSchedule(result(50, [false, true, false, false, true, false, false, false]), 2, 1);
    expect(plan).toEqual([[expect.any(Number), 1], [expect.any(Number), 2], [600, 8]]);
  });
  it('뒤집힐 수 있는 마지막 다섯 돌은 0.6초씩, 반복 회기엔 없다', () => {
    const flips = [true, false, true, false, true, false, true, false, true, true];
    const plan = countSchedule(result(45, flips), 1, 2);
    expect(plan.slice(-3).map(([ms]) => ms)).toContain(600);
    const later = countSchedule(result(45, flips), 1, 8);
    expect(later.slice(0, -1).every(([ms]) => ms < 600)).toBe(true);
  });
  it('포고는 처음부터 정해져 있다', () => {
    expect(countSchedule(result(10, [true, false, true], 51, true), 0, 1)).toEqual([[600, 3]]);
  });
  it('반복과 소란 단계에 따라 미정 시간이 준다', () => {
    expect([0, 2, 4].map(st => countSeconds(st, 1))).toEqual([2.5, 3, 3.5]);
    expect(countSeconds(4, 5)).toBe(2);
    expect(countSeconds(4, 13)).toBe(1);
    expect([0, 19, 20, 79, 100].map(noiseStage)).toEqual([0, 0, 1, 3, 4]);
  });
});
