import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import { SLIP_MAX, fxDiff, fxSnap, slipItems } from '../../src/ui/fx';

// 바뀐 것 쪽지(사용자 2026-10-11): 선택 직후 바뀐 것을 한 줄에 모은다.

describe('바뀐 것 쪽지', () => {
  it('수치 먼저, 그다음 집단 관계를 크게 바뀐 것부터 적는다', () => {
    const g = createS1cGame('slip-1');
    const before = fxSnap(g);
    g.trust += 4; g.coal -= 10; g.comms.tail.rel -= 6; g.comms.front.rel += 2;
    const { items, more } = slipItems(fxDiff(before, g)!);
    expect(items.map(i => `${i.label} ${i.text}`)).toEqual(['신임 +4', '석탄 −10', '꼬리칸 관계 −6', '앞칸 관계 +2']);
    expect(items.map(i => i.up)).toEqual([true, false, false, true]);
    expect(more).toBe(0);
  });

  it('보이는 값이 그대로면 적지 않는다', () => {
    const g = createS1cGame('slip-2');
    const before = fxSnap(g);
    g.trust += 0.2; g.comms.tail.rel -= 0.3;
    expect(fxDiff(before, g)).toBeNull();
  });

  it('칸이 넘치면 앞의 것만 적고 나머지는 수로 센다', () => {
    const g = createS1cGame('slip-3');
    const before = fxSnap(g);
    g.trust -= 3; g.tension += 5; g.coal -= 4; g.food -= 4; g.med -= 1; g.lux -= 1;
    g.comms.tail.rel -= 6; g.comms.front.rel += 2; g.comms.guard.rel += 9;
    const { items, more } = slipItems(fxDiff(before, g)!);
    expect(items.length).toBe(SLIP_MAX);
    expect(more).toBe(3);
    expect(items[0].label).toBe('신임');
  });
});
