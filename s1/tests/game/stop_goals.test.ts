import { describe, expect, it, vi } from 'vitest';
import { createGame } from '../../src/game/state';
import {
  GOAL_AMOUNT, GOAL_NAME, STOP_GOALS, goalStatus, splitMaterials, suggestGoal,
} from '../../src/game/stop_goals';
import type { GoalSuggestion } from '../../src/game/stop_goals';

const suggestion = (): GoalSuggestion => ({
  stock: { coal: 0, food: 0, medicine: 0, wood: 0, scrap: 0, parts: 100 },
  consumption: { coal: 6, food: 6 },
  weights: { coal: 30, food: 30, medicine: 30, wood: 3, scrap: 3 },
});

describe('정차 목표 준비', () => {
  it('목표는 자재까지 넷이다', () => {
    expect(STOP_GOALS).toEqual(['coal', 'food', 'medicine', 'materials']);
    expect(Object.values(GOAL_NAME)).toEqual(['석탄', '식량', '의약품', '자재']);
    expect(GOAL_AMOUNT).toEqual({ coal: 12, food: 12, medicine: 4, materials: 6 });
    for (const selected of ['info', 'secret', 'symbol', 'luxury']) {
      expect(suggestGoal({ ...suggestion(), selected })).toBe('coal');
    }
  });

  it('부족량과 장소로 추천하되 선택은 보존한다', () => {
    const input = suggestion();
    expect(suggestGoal(input)).toBe('coal');
    expect(suggestGoal({ ...input, selected: 'medicine' })).toBe('medicine');
    expect(suggestGoal({ ...input, weights: { ...input.weights, food: 100 } })).toBe('food');
    expect(suggestGoal({ ...input, stock: { ...input.stock, coal: 11 } })).toBe('food');
    expect(suggestGoal({ ...input, weights: { ...input.weights, wood: 20 }, selected: 'unknown' })).toBe('materials');
    expect(suggestGoal({ ...input, stock: { ...input.stock, wood: 5, scrap: 5 }, weights: { ...input.weights, wood: 20 } })).toBe('coal');
    expect(suggestGoal({ ...input, stock: { ...input.stock, wood: 5, scrap: 5 }, materialNeed: 40,
      weights: { ...input.weights, wood: 20 } })).toBe('materials');
    const full = { coal: 100, food: 100, medicine: 100, wood: 100, scrap: 100 };
    expect(suggestGoal({ ...input, stock: full, weights: { ...input.weights, medicine: 80 } })).toBe('medicine');
    expect(suggestGoal({ ...input, stock: full })).toBe('coal');
    const empty = { coal: 0, food: 0, medicine: 0, wood: 0, scrap: 0 };
    expect(suggestGoal({ ...input, weights: empty, selected: 'food' })).toBeUndefined();
    expect(suggestGoal({ ...input, weights: { ...empty, food: 10 }, selected: 'coal' })).toBe('food');
    expect(suggestGoal({ ...input, consumption: { coal: 0, food: 0 } })).toBe('coal');
  });

  it('목표 때문에 노선을 다시 뽑지 않는다', () => {
    const game = createGame('goal_rule');
    const before = structuredClone(game);
    const input = Object.freeze(suggestion());
    const random = vi.spyOn(Math, 'random').mockImplementation(() => { throw new Error('난수를 쓰면 안 된다'); });
    try {
      for (let count = 0; count < 20; count += 1) suggestGoal(input);
      expect(game).toEqual(before);
      expect(game.rng).toEqual(before.rng);
      expect(random).not.toHaveBeenCalled();
    } finally {
      random.mockRestore();
    }
  });

  it('목재와 고철 합을 한 번만 얻는다', () => {
    expect(splitMaterials(5.6, 1, 3)).toEqual({ wood: 2, scrap: 4 });
    expect(splitMaterials(1, 1, 1)).toEqual({ wood: 1, scrap: 0 });
    expect(splitMaterials(7, 0, 3)).toEqual({ wood: 0, scrap: 7 });
    expect(splitMaterials(0, 0, 0)).toEqual({ wood: 0, scrap: 0 });
    expect(() => splitMaterials(1, 0, 0)).toThrow();
    for (let total = 0; total < 30; total += 0.3) {
      const gains = splitMaterials(total, 3, 7);
      expect(gains.wood + gains.scrap).toBe(Math.round(total));
      expect(gains.wood).toBeGreaterThanOrEqual(0);
      expect(gains.scrap).toBeGreaterThanOrEqual(0);
    }
    const gains = { wood: 2, scrap: 4, parts: 100 };
    expect(goalStatus('materials', 6, gains)).toBe('done');
    expect(goalStatus('materials', 7, gains)).toBe('part');
    expect(goalStatus('materials', 6, { parts: 100 }, 'limit')).toBe('retreat');
    expect(goalStatus('materials', 6, gains, 'wiped')).toBe('failed');
    expect(goalStatus('coal', 12, { coal: 12 })).toBe('done');
    expect(goalStatus('food', 12, { food: 1 })).toBe('part');
    expect(goalStatus('medicine', 4, {})).toBe('retreat');
    expect(goalStatus(null, 0, gains)).toBe('retreat');
    expect(gains).toEqual({ wood: 2, scrap: 4, parts: 100 });
  });
});
