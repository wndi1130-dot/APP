import { describe, expect, it } from 'vitest';
import { DRAG_MIN, isDrag, wheelStep } from '../../src/ui/train_scroll';

// 열차 띠를 마우스로 넘기기(사용자 2026-10-11: 노트북에서 앞 칸으로 갈 수 없었다).

describe('열차 띠 넘기기', () => {
  it('세로 휠도 가로로 넘기고, 가로 휠(터치패드)은 그대로 쓴다', () => {
    expect(wheelStep({ deltaX: 0, deltaY: 100, deltaMode: 0 })).toBe(100);
    expect(wheelStep({ deltaX: -40, deltaY: 5, deltaMode: 0 })).toBe(-40);
    expect(wheelStep({ deltaX: 0, deltaY: -3, deltaMode: 1 })).toBe(-48);
  });

  it('조금 움직인 것은 누름이고, 넘게 움직여야 끌기다', () => {
    expect(isDrag(100, 100 + DRAG_MIN)).toBe(false);
    expect(isDrag(100, 100 - DRAG_MIN - 1)).toBe(true);
  });
});
