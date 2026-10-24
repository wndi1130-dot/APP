import { describe, expect, it } from 'vitest';
import {
  chooseCard, COMMS, createGame, enactLaw, lawOpen, LAWS, rationCutFood, repealLaw, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';

// 비상식량감축법(결정 083·091·430): 고르게 반 단, 식량 40 이하에서만, 공동 식당·기여 배급과 함께 못 섬,
// 통과하면 꼬리칸 요구 카드(꼬리칸은 뺀다 / 앞칸이 먼저 낸다 / 거절), 폐지하면 처지가 돌아온다.

const rations = (g: Game) => Object.fromEntries(COMMS.map(c => [c, g.comms[c].base[1]]));

function passed(seed: string): { g: Game; before: Record<string, number> } {
  const g = createGame(seed);
  g.food = 35;
  const before = rations(g);
  enactLaw(g, 'emergency_ration', []);
  return { g, before };
}

function answer(g: Game, label: string): void {
  const card = g.cards.find(c => c.kind === 'ration_cut')!;
  const idx = viewCard(g, card).choices.findIndex(ch => ch.label === label);
  expect(idx).toBeGreaterThanOrEqual(0);
  expect(chooseCard(g, card.uid, idx)).toBe(true);
}

describe('비상식량감축법의 꼴', () => {
  it('반 단: 모든 칸 배급 처지 −6, 식량 2.5 아낌, 긴장 +1, 정차 산출 ×0.8, 꼬리칸 관계 −8', () => {
    const law = LAWS.emergency_ration;
    expect(law.title).toBe('비상식량감축법');
    expect(law.res).toEqual({ foodAdd: -2.5, tensionAdd: 1, haulMult: 0.8 });
    for (const c of COMMS) expect(law.mats[c]).toEqual([0, -6, 0, 0]);
    expect(law.rels).toEqual({ tail: -8 });
    expect(law.crisis).toEqual(['food']);
  });
});

describe('열리는 때', () => {
  it('식량 40 이하에서만 오른다', () => {
    const g = createGame('er-open');
    g.food = 41;
    expect(lawOpen(g, 'emergency_ration')).toBe(false);
    g.food = 40;
    expect(lawOpen(g, 'emergency_ration')).toBe(true);
  });

  it('공동 식당·기여 배급과 함께 못 선다', () => {
    const g = createGame('er-excl');
    g.food = 30;
    g.passed.common_kitchen = 0;
    expect(lawOpen(g, 'emergency_ration')).toBe(false);
    delete g.passed.common_kitchen;
    g.passed.contribution_ration = 0;
    expect(lawOpen(g, 'emergency_ration')).toBe(false);
    delete g.passed.contribution_ration;
    g.passed.emergency_ration = 0;
    expect(lawOpen(g, 'common_kitchen')).toBe(false);
    expect(lawOpen(g, 'contribution_ration')).toBe(false);
  });
});

describe('통과하면', () => {
  it('모든 칸 배급 처지가 6 내려가고 꼬리칸 관계가 떨어지며 꼬리칸 요구 카드가 선다', () => {
    const g = createGame('er-pass');
    g.food = 35;
    const before = rations(g);
    const rel = g.comms.tail.rel;
    enactLaw(g, 'emergency_ration', []);
    for (const c of COMMS) expect(g.comms[c].base[1]).toBe(before[c] - 6);
    expect(g.comms.tail.rel).toBeLessThan(rel);
    const card = g.cards.find(c => c.kind === 'ration_cut');
    expect(card).toBeTruthy();
    expect(viewCard(g, card!).choices.map(ch => ch.label)).toEqual(['꼬리칸은 뺀다', '앞칸이 먼저 낸다', '거절한다']);
  });
});

describe('꼬리칸 요구의 답', () => {
  it('꼬리칸은 뺀다: 꼬리칸 처지는 그대로, 아끼는 식량은 1.5', () => {
    const { g, before } = passed('er-spare');
    answer(g, '꼬리칸은 뺀다');
    expect(g.comms.tail.base[1]).toBe(before.tail);
    expect(g.comms.front.base[1]).toBe(before.front - 6);
    expect(g.rationCut?.pick).toBe('spare_tail');
    expect(rationCutFood(g, -2.5)).toBe(-1.5);
  });

  it('앞칸이 먼저 낸다: 꼬리칸 처지는 그대로, 앞칸은 −12, 아끼는 식량은 그대로', () => {
    const { g, before } = passed('er-front');
    answer(g, '앞칸이 먼저 낸다');
    expect(g.comms.tail.base[1]).toBe(before.tail);
    expect(g.comms.front.base[1]).toBe(before.front - 12);
    expect(g.comms.engine.base[1]).toBe(before.engine - 6);
    expect(rationCutFood(g, -2.5)).toBe(-2.5);
  });

  it('거절: 모두 −6 그대로, 긴장이 오른다', () => {
    const { g, before } = passed('er-refuse');
    const tension = g.tension;
    answer(g, '거절한다');
    for (const c of COMMS) expect(g.comms[c].base[1]).toBe(before[c] - 6);
    expect(g.tension).toBeGreaterThan(tension);
    expect(g.rationCut?.pick).toBe('refuse');
  });
});

describe('폐지하면', () => {
  it('법과 답이 바꾼 처지가 모두 돌아오고 답 기록이 지워진다', () => {
    const { g, before } = passed('er-repeal');
    answer(g, '앞칸이 먼저 낸다');
    repealLaw(g, 'emergency_ration');
    expect(rations(g)).toEqual(before);
    expect(g.rationCut).toBeUndefined();
  });

  it('요구 카드를 고르기 전에 폐지하면 카드를 거둔다', () => {
    const { g, before } = passed('er-repeal-early');
    repealLaw(g, 'emergency_ration');
    expect(g.cards.some(c => c.kind === 'ration_cut')).toBe(false);
    expect(rations(g)).toEqual(before);
  });
});
