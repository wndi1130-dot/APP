import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import { backdrop, tick } from '../../src/ui/backdrop';
import type { Clock } from '../../src/ui/backdrop';

// 달리는 배경(사용자 2026-10-11): 창밖 날씨와 재난을 따르고, 달린 시간만 센다.

describe('달리는 배경', () => {
  it('정차의 날씨를 따르고, 달리는 동안은 마지막에 본 날씨가 이어지고, 아무것도 없으면 눈이다', () => {
    const g = createS1cGame('bg-1');
    g.stop = null;
    expect(backdrop(g)).toEqual({ sky: 'snow', omen: false, pace: 1 });
    expect(backdrop(g, 'fog').sky).toBe('fog');
    expect(backdrop(g, 'fog').pace).toBeGreaterThan(1);
    expect(backdrop(g, 'sleet').sky).toBe('sleet');
  });

  it('눈보라가 닥친 구간은 날씨보다 먼저고 겹이 느려진다. 예고 때는 하늘만 내려앉는다', () => {
    const g = createS1cGame('bg-2');
    g.stop = null;
    g.disasters = true;
    g.disaster = { ...(g.disaster ?? {}), kind: 'blizzard', stage: 'warn', left: 1 } as NonNullable<typeof g.disaster>;
    expect(backdrop(g, 'clear')).toEqual({ sky: 'clear', omen: true, pace: 1 });
    g.disaster.stage = 'active';
    expect(backdrop(g, 'clear').sky).toBe('storm');
    expect(backdrop(g, 'clear').pace).toBeGreaterThan(2);
    g.disaster.kind = 'cold';
    expect(backdrop(g)).toEqual({ sky: 'cold', omen: false, pace: 1 });
    g.disasters = false; // 재난을 끈 판에서는 남은 상태를 읽지 않는다
    expect(backdrop(g, 'clear').sky).toBe('clear');
  });

  it('달린 시간만 모은다: 서 있는 동안은 흐르지 않아 겹이 그 자리에 멎는다', () => {
    const c: Clock = { t: 0, last: 0, moving: false };
    expect(tick(c, true, 1000)).toBe(0); // 출발
    expect(tick(c, true, 4000)).toBe(3000); // 달리는 중 다시 그림
    expect(tick(c, false, 6000)).toBe(5000); // 섬
    expect(tick(c, false, 60000)).toBe(5000); // 서 있음
    expect(tick(c, true, 61000)).toBe(5000); // 다시 출발
    expect(tick(c, true, 62500)).toBe(6500);
  });
});
