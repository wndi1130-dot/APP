import { describe, expect, it } from 'vitest';
import { cancelRestore, createS1cGame, startRestore } from '../../src/game';

describe('7.5 취소 악용: 같은 기술을 다시 시작해도 관계가 또 움직이지 않는다', () => {
  it('M5를 시작·취소해도 꼬리칸 +5는 한 번뿐', () => {
    const g = createS1cGame('rel-once');
    g.dom!.wood = 20;
    const tail0 = g.comms.tail.rel;
    const med0 = g.comms.medtech.rel;
    for (let i = 0; i < 3; i++) {
      expect(startRestore(g, 'm5', 'full')).toBe(true);
      cancelRestore(g);
    }
    expect(g.comms.tail.rel).toBe(tail0 + 5);
    expect(g.comms.medtech.rel).toBe(med0 - 5);
    expect(g.dom!.wood).toBe(14); // 목재는 매번 든다
  });

  it('변형을 바꿔 다시 시작하면 그 변형 쪽이 움직이고, 같은 변형을 되풀이하면 쌓이지 않는다', () => {
    // E3은 관계가 시작이 아니라 추인 표결 때 움직여서(7.3, elder_pipe.test.ts) 양쪽이 있는 변형 기술 R2로 본다.
    const g = createS1cGame('rel-variant');
    const d = g.dom!;
    d.parts = 50; d.frags.radio = 10;
    d.techs.r1 = { stage: 'done' } as NonNullable<typeof d.techs.r1>;
    const [guard0, tail0, engine0, med0] = [g.comms.guard.rel, g.comms.tail.rel, g.comms.engine.rel, g.comms.medtech.rel];
    const go = (v: 'a' | 'b') => { expect(startRestore(g, 'r2', 'full', v)).toBe(true); cancelRestore(g); };
    go('a'); go('a'); go('b'); go('a'); // 가(움직임) · 가(그대로) · 나(움직임) · 가(움직임)
    expect(g.comms.guard.rel).toBe(guard0 + 15);
    expect(g.comms.tail.rel).toBe(tail0 - 15);
    expect(g.comms.engine.rel).toBe(engine0 + 5);
    expect(g.comms.medtech.rel).toBe(med0 - 5);
  });
});
