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

  it('변형을 바꿔 다시 시작하면 그 변형 쪽이 움직이고, 오가도 쌓이지 않는다', () => {
    const g = createS1cGame('rel-variant');
    const d = g.dom!;
    d.parts = 50; d.frags.engine = 10;
    d.techs.e1 = { stage: 'done' } as NonNullable<typeof d.techs.e1>;
    const tail0 = g.comms.tail.rel;
    const front0 = g.comms.front.rel;
    const go = (v: 'a' | 'b') => { expect(startRestore(g, 'e3', 'full', v)).toBe(true); cancelRestore(g); };
    go('a'); go('a'); go('b'); go('a');
    expect(g.comms.tail.rel).toBe(tail0 + 5);
    expect(g.comms.front.rel).toBe(front0 - 5);
  });
});
