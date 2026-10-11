import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import { coldLine } from '../../src/ui/domestic';
import { CARS } from '../../src/ui/common';

// 찬 칸 판(결정 054·066): 이름은 「찬 칸」, 법이 서기 전에는 「얼음 n/20 · 안치 —」이고 죽은 사람 이야기는 법이 선 뒤에만 뜬다.

describe('찬 칸 판', () => {
  it('칸 이름은 「찬 칸」이다', () => {
    expect(CARS.find(c => c.id === 'cold')?.name).toBe('찬 칸');
  });

  it('시신 법이 없으면 안치 자리는 줄표이고 죽은 사람 글이 없다', () => {
    const g = createS1cGame('cold');
    const line = coldLine(g);
    expect(line.text).toBe('얼음 0/20 · 안치 —');
    expect(line.text + line.more).not.toMatch(/죽은|시신|구/);
  });

  it('안치법이 서면 자리 수가 뜨고, 장작불을 기다리는 수는 따로 센다', () => {
    const g = createS1cGame('cold');
    g.passed.corpse_store = g.seg;
    g.stored = 2;
    expect(coldLine(g).text).toBe('얼음 0/20 · 안치 2/6');
    g.pyre = 1;
    expect(coldLine(g).text).toBe('얼음 0/20 · 안치 3/6 · 장작불 기다림 1');
    expect(coldLine(g).more).toMatch(/모셔/);
  });
});
