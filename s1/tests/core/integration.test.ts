import { describe, expect, it } from 'vitest';
import {
  applyEffect, applyEffects, buildCouncilGroups, createInitialState,
  evaluateConditions, resolveCouncilVote, restoreRng,
} from '../../src/core';
import type { EffectContext, GameState } from '../../src/core';

function preparedState(): GameState {
  return createInitialState({
    seed: 'council-integration',
    persons: [
      { id: 'p_tail_leader', community: 'tail', age: 40 },
      { id: 'p_child', community: 'tail', age: 5 },
      { id: 'p_engine_leader', community: 'engine', age: 65, state: 'injured' },
    ],
    groups: [
      { id: 'tail', members: ['p_tail_leader', 'p_child'], leaderId: 'p_tail_leader', cohesion: 1 },
      { id: 'engine', members: ['p_engine_leader'], leaderId: 'p_engine_leader', cohesion: 0 },
    ],
  });
}

describe('공개 API를 통한 핵심 로직 연결', () => {
  it('효과로 얻은 약속표를 의회에 연결하고 파견 인원을 그 회기에서 제외한다', () => {
    const initial = preparedState();
    const promised = applyEffects(initial, [
      { type: 'votes', target: 'tail', amount: 67 },
      { type: 'votes', target: 'engine', amount: 33 },
      { type: 'flag', id: 'council_open', value: true },
    ]);
    expect(evaluateConditions(promised, [
      { type: 'segment', min: 0, max: 0 },
      { type: 'flag', id: 'council_open', value: true },
      { type: 'community', community: 'tail', metric: 'warmth', operator: 'gte', value: 50 },
    ])).toBe(true);
    const before = resolveCouncilVote(buildCouncilGroups(promised), {
      kind: 'rule', mode: 'public', rng: promised.rng,
    });
    expect(before.record).toMatchObject({ yes: 67, abstain: 33, absent: 0, passed: true });
    const dispatched = applyEffect(promised, { type: 'person.away', target: 'p_child', segments: 2 });
    const after = resolveCouncilVote(buildCouncilGroups(dispatched), {
      kind: 'rule', mode: 'secret', rng: dispatched.rng,
    });
    expect(after.record).toEqual({
      yes: 33, no: 0, abstain: 33, absent: 34,
      requiredVotes: 67, kind: 'rule', mode: 'secret', passed: false,
    });
    expect(initial).toEqual(preparedState());
    expect(promised.persons.p_child.state).toBe('alive');
  });

  it('효과·표결 후 저장한 상태로 다음 표결을 그대로 이어 간다', () => {
    const initial = applyEffects(preparedState(), [
      { type: 'votes', target: 'tail', amount: 67 },
      { type: 'cohesion', target: 'tail', amount: -0.4 },
    ]);
    const first = resolveCouncilVote(buildCouncilGroups(initial), {
      kind: 'normal', mode: 'secret', rng: initial.rng,
    });
    const saved: GameState = { ...initial, rng: first.rng };
    const restored: GameState = JSON.parse(JSON.stringify(saved));
    restored.rng = restoreRng(restored.rng);
    const next = (state: GameState) => resolveCouncilVote(buildCouncilGroups(state), {
      kind: 'normal', mode: 'public', rng: state.rng,
    });
    expect(next(restored)).toEqual(next(saved));
  });

  it('거래 참조를 정의와 연결하고 효과를 재적용해도 기한을 연장하지 못한다', () => {
    const context: EffectContext = {
      deals: { deal_heat: { id: 'deal_heat', tool: 'open', from: 'tail', deadline: 3 } },
    };
    const initial = preparedState();
    const opened = applyEffect(initial, { type: 'deal', id: 'deal_heat' }, context);
    expect(opened.deals[0]).toMatchObject({ id: 'deal_heat', openedAtSegment: 0, deadlineSegment: 3 });
    expect(opened.promises[0]).toMatchObject({ target: 'tail', deadlineSegment: 3 });
    expect(() => applyEffect({ ...opened, segment: 2 }, { type: 'deal', id: 'deal_heat' }, context)).toThrow();
    expect(opened.deals[0].deadlineSegment).toBe(3);
    expect(initial.deals).toEqual([]);
  });
});
