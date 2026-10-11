import { describe, expect, it } from 'vitest';
import { POT_MODES, createS1cGame, potView } from '../../src/game';
import { POT_NAME, potFacts } from '../../src/ui/domestic';
import { applyStep } from '../../src/ui/repro';

// 식당칸 판의 솥 덩이(결정 067): 방식은 식당칸에서만 고르고, 누르기 전에 바뀔 값이 숫자로 보인다.

describe('식당칸 솥 덩이', () => {
  it('방식 셋에 이름이 있다', () => {
    expect(POT_MODES.map(m => POT_NAME[m])).toEqual(['그대로', '묽게', '섞어서']);
  });

  it('그대로는 곱 1이고 들킬 일이 없다. 묽게는 식량이 덜 든다', () => {
    const g = createS1cGame('pot');
    const plain = potFacts(g, 'plain');
    expect(plain.mult).toBe('×1.00');
    expect(plain.risk).toBe(0);
    expect(plain.cells).toBe(0);
    const thin = potFacts(g, 'thin');
    expect(thin.mult).toBe('×0.85');
    expect(parseFloat(thin.food.slice(3))).toBeLessThan(parseFloat(plain.food.slice(3)));
  });

  it('섞어서는 목재가 들고 들킬 눈금이 한 칸 이상 찬다', () => {
    const g = createS1cGame('pot');
    const mixed = potFacts(g, 'mixed');
    expect(mixed.wood).toMatch(/^목재 /);
    expect(mixed.risk).toBeGreaterThan(0);
    expect(mixed.cells).toBeGreaterThanOrEqual(1);
    expect(mixed.cells).toBeLessThanOrEqual(5);
  });

  it('칩을 누르면 규칙의 고르기 함수로 방식이 바뀐다', () => {
    const g = createS1cGame('pot');
    applyStep(g, { a: 'dom-pot', d: { mode: 'thin' } });
    expect(potView(g).mode).toBe('thin');
    applyStep(g, { a: 'dom-pot', d: { mode: 'plain' } });
    expect(potView(g).mode).toBe('plain');
  });
});
