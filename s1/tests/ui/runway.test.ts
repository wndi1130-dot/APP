import { describe, expect, it } from 'vitest';
import { runway } from '../../src/ui/hud';

// 위 자원 줄: 줄어드는 자원은 '몇 구간 뒤 바닥'을 붙인다(사용자 2026-10-09).
describe('runway', () => {
  it('남은 양을 구간당 소모로 나눠 내림한다', () => {
    expect(runway(100, -6.6)).toBe(14);
    expect(runway(20, -7)).toBe(2);
  });
  it('이번 구간에 못 버티면 0', () => {
    expect(runway(5, -7)).toBe(0);
  });
  it('늘거나 그대로면 표시하지 않는다', () => {
    expect(runway(50, 0)).toBeNull();
    expect(runway(50, 3)).toBeNull();
    expect(runway(50, -0.4)).toBeNull();
  });
});
