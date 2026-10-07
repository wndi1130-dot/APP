import { describe, expect, it } from 'vitest';
import { plainNumbers } from '../../src/ui/plain';

// 화면 글에 소수점이 나오지 않는다(2026-10-07 사용자).
describe('plainNumbers', () => {
  it('남은 자원을 반올림한다', () => {
    expect(plainNumbers('석탄은 91.2588888 남았다.')).toBe('석탄은 91 남았다.');
  });
  it('배수는 퍼센트로', () => {
    expect(plainNumbers('정차 사망 ×0.85')).toBe('정차 사망 −15%');
    expect(plainNumbers('공방 작업량 ×1.25')).toBe('공방 작업량 +25%');
    expect(plainNumbers('의약품 소모 ×1.6 → ×1.3')).toBe('의약품 소모 +60% → +30%');
  });
  it('1보다 작은 구간당 값은 몇 구간에 하나로', () => {
    expect(plainNumbers('달리기 석탄 +0.4/구간')).toBe('달리기 석탄 3구간에 +1');
    expect(plainNumbers('식량 −0.5/구간(6구간)')).toBe('식량 2구간에 −1(6구간)');
    expect(plainNumbers('온실 식량 +1.5/구간')).toBe('온실 식량 +2/구간');
  });
  it('0으로 반올림되는 양은 1로 둔다', () => {
    expect(plainNumbers('자재 0.3을 버렸다')).toBe('자재 1을 버렸다');
  });
  it('소수가 없으면 그대로', () => {
    expect(plainNumbers('긴장 −1/구간, 40% → 25%')).toBe('긴장 −1/구간, 40% → 25%');
  });
});
