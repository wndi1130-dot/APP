import { describe, expect, it } from 'vitest';
import { createGame, crewNames } from '../../src/game';
import type { Game } from '../../src/game';
import { addWound } from '../../src/game/wounds';
import type { WoundGrade } from '../../src/game/wounds';

// 다친 사람 명세 4절 첫 줄: 깊은 상처·골절·절단이 낫는 동안에는 정차 명단에 들지 않는다. 가벼운 상처는 그대로 나간다.

function fresh(seed: string): Game {
  const g = createGame(seed);
  g.cards = [];
  return g;
}

const hurt = (g: Game, who: string, grade: WoundGrade) =>
  addWound(g, { who, comm: 'tail', from: 'stop', where: '시험', grade, part: 'torso', septic: false });

describe('깊은 상처는 파견에서 빠진다', () => {
  it('깊음·골절·절단은 낫는 동안 명단에 없고, 가벼움은 그대로 든다', () => {
    for (const grade of ['deep', 'fracture', 'amputation'] as const) {
      const g = fresh(`wc-${grade}`);
      const before = crewNames(g, 'tail', 4);
      expect(before.length).toBe(4);
      hurt(g, before[0], grade);
      const after = crewNames(g, 'tail', 4);
      expect(after).not.toContain(before[0]);
      expect(after.length).toBe(4);
    }
    const g = fresh('wc-light');
    const before = crewNames(g, 'tail', 4);
    hurt(g, before[0], 'light');
    expect(crewNames(g, 'tail', 4)).toEqual(before);
  });

  it('다 나으면 다시 든다', () => {
    const g = fresh('wc-heal');
    const before = crewNames(g, 'tail', 4);
    const w = hurt(g, before[0], 'deep');
    expect(crewNames(g, 'tail', 4)).not.toContain(before[0]);
    w.state = 'healed';
    expect(crewNames(g, 'tail', 4)).toEqual(before);
  });

  it('앓는 사람이 없으면 명단이 옛 것과 같다', () => {
    const g = fresh('wc-none');
    const a = crewNames(g, 'tail', 6);
    hurt(g, '명단에 없는 사람', 'deep');
    expect(crewNames(g, 'tail', 6)).toEqual(a);
  });
});
