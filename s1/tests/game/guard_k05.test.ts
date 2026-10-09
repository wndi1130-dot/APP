import { describe, expect, it } from 'vitest';
import { createGame, enableDark, PROFILES } from '../../src/game';
import { flagged } from '../../src/game/dark/cases';
import type { Fact, Suspect } from '../../src/game/dark/state';

// 금지선 점검 K05(공유 폴더 guard/k05_owners.md)의 s1/ 몫 가운데 규칙 하나:
// 칸 소속(사건 칸이나 옆 칸 사람)과 처지(늦게 탐·구조됨·벌받음)만으로는 희생양 후보가 켜지지 않는다.

const adult = PROFILES.find(p => p.age >= 20 && ['pl', 'de', 'cz'].includes(p.name_lang ?? ''))!;
const sus = (facts: Fact[], clues = 0): Suspect => ({
  id: adult.id, culprit: false, facts, acq: false,
  clues: Array.from({ length: clues }, (_, i) => ({ kind: 'foot' as const, truth: false, line: `단서 ${i}`, seg: 1 })),
});

describe('K05 칸 소속과 칸끼리의 원한은 희생양 후보 표시를 켜지 않는다', () => {
  const g = createGame('k05');
  enableDark(g);

  it('같은 칸·옆 칸에 늦게 탔거나 구조됐거나 벌받은 사람이라는 것만으로는 안 켜진다', () => {
    for (const extra of ['joined', 'rescued', 'punished'] as const) expect(flagged(g, sus(['car', extra]))).toBe(false);
    // 원수 칸 사람이라는 것도 칸의 사실이다
    expect(flagged(g, sus(['car', 'rival']))).toBe(false);
    expect(flagged(g, sus(['rival', 'joined']))).toBe(false);
  });

  it('사건에 닿은 개별 사실(드나듦)이나 그 사람을 가리킨 단서가 있으면 그대로 켜진다', () => {
    expect(flagged(g, sus(['access']))).toBe(true);
    expect(flagged(g, sus(['car'], 1))).toBe(true);
  });
});
