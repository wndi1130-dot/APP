import { describe, expect, it } from 'vitest';
import { LOCO, LOCO_IDS } from '../../src/game';
import { locoDetailLines } from '../../src/ui/loco_pick';

describe('기관차 고르는 화면의 「자세히」', () => {
  it('얻는 것·잃는 것 글에는 숫자가 없고, 숫자는 자세히 줄에만 있다', () => {
    for (const id of LOCO_IDS) {
      expect(LOCO[id].gain).not.toMatch(/\d/);
      expect(LOCO[id].loss).not.toMatch(/\d/);
      expect(locoDetailLines(id).length).toBeGreaterThan(0);
    }
    expect(locoDetailLines('c1').join(' ')).toContain('+2');
    expect(locoDetailLines('c2').join(' ')).toContain('40%');
  });
});
