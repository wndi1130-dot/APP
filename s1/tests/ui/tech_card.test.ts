import { describe, expect, it } from 'vitest';
import { TECHS, TECH_IDS } from '../../src/game';
import { shortEffect } from '../../src/ui/domestic';

// 기술 카드(설계 2-3): 효과는 첫 마디만 적고 나머지는 「더」로 편다. 글은 자르기만 하고 바꾸지 않는다.

describe('기술 카드의 효과 첫 마디', () => {
  const all = TECH_IDS.flatMap(id => {
    const def = TECHS[id];
    return def.variants ? [def.variants.a.effect, def.variants.b.effect] : [def.effect];
  });

  it('서른 자 안의 글은 그대로 둔다', () => {
    for (const t of all.filter(x => x.length <= 30)) expect(shortEffect(t)).toBe(t);
  });

  it('긴 글은 원문의 앞머리이고 서른 자를 넘지 않는다', () => {
    const long = all.filter(x => x.length > 30);
    expect(long.length).toBeGreaterThan(0);
    for (const t of long) {
      const s = shortEffect(t);
      expect(t.startsWith(s)).toBe(true);
      expect(s.length).toBeLessThanOrEqual(30);
      expect(s.length).toBeGreaterThan(8);
    }
  });
});
