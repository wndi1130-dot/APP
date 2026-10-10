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
    expect(plan.every(([ms]) => ms >= 30 && ms <= 600)).toBe(true);
    expect(secs(plan)).toBeLessThanOrEqual(2.5 + 0.6 * 5 + 0.01);
  });
  it('정해진 뒤 남은 돌도 건너뛰지 않고 하나씩 빠르게 잇는다(0.6초 안)', () => {
    // 확정 찬성 50, 필요 51: 첫 찬성 돌에서 통과가 정해진다. 남은 여섯 돌이 한 번에 켜지지 않는다.
    const plan = countSchedule(result(50, [false, true, false, false, true, false, false, false]), 2, 1);
    expect(plan.map(([, shown]) => shown)).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
    const tail = plan.slice(2);
    expect(tail.every(([ms]) => ms >= 30 && ms <= 120)).toBe(true);
    expect(secs(tail)).toBeLessThanOrEqual(0.6 + 0.001);
  });
  it('어느 박자에서도 열린 돌 수가 한 번에 크게 뛰지 않는다', () => {
    // 미정 60, 처음부터 정해진 판(확정 찬성 80): 남은 돌이 많아도 0.6초 안에 스무 박자로 나눠 연다.
    const many = countSchedule(result(80, Array.from({ length: 60 }, (_, i) => i % 2 === 0)), 0, 1);
    const jumps = many.map(([, shown], k) => shown - (k ? many[k - 1][1] : 0));
    expect(Math.max(...jumps)).toBeLessThanOrEqual(3);
    expect(many[many.length - 1][1]).toBe(60);
    expect(secs(many)).toBeLessThanOrEqual(0.6 + 0.001);
    // 열린 수는 늘 늘기만 한다.
    expect(jumps.every(j => j >= 1)).toBe(true);
  });
  it('뒤집힐 수 있는 마지막 다섯 돌은 0.6초씩, 반복 회기엔 없다', () => {
    const flips = [true, false, true, false, true, false, true, false, true, true];
    const plan = countSchedule(result(45, flips), 1, 2);
    expect(plan.slice(-3).map(([ms]) => ms)).toContain(600);
    const later = countSchedule(result(45, flips), 1, 8);
    expect(later.slice(0, -1).every(([ms]) => ms < 600)).toBe(true);
  });
  it('포고는 처음부터 정해져 있다', () => {
    expect(countSchedule(result(10, [true, false, true], 51, true), 0, 1)).toEqual([[120, 1], [120, 2], [120, 3]]);
  });
  it('반복과 소란 단계에 따라 미정 시간이 준다', () => {
    expect([0, 2, 4].map(st => countSeconds(st, 1))).toEqual([2.5, 3, 3.5]);
    expect(countSeconds(4, 5)).toBe(2);
    expect(countSeconds(4, 13)).toBe(1);
    expect([0, 19, 20, 79, 100].map(noiseStage)).toEqual([0, 0, 1, 3, 4]);
  });
});
