import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import Ajv2020 from 'ajv/dist/2020.js';
import {
  COMMUNITY_IDS, COMMUNITY_METRICS, DEAL_TOOLS, EFFECT_DEFAULTS,
  STATE_LIMITS,
} from '../../src/core/constants';
import {
  applyEffect, applyEffects, evaluateCondition, evaluateConditions,
} from '../../src/core/effects';
import type {
  Condition, ConditionOperator, Effect, EffectContext, EffectDealDefinition,
} from '../../src/core/effects';
import { cloneGameState, createInitialState } from '../../src/core/state';
import type { GameState } from '../../src/core/state';

const initialState = () => createInitialState({
  seed: 'effects_test',
  segment: 7,
  persons: [
    { id: 'p_alive', community: 'tail' },
    { id: 'p_injured', community: 'engine', state: 'injured' },
    { id: 'p_dead', community: 'guard', state: 'dead' },
    { id: 'p_away', community: 'medtech', state: 'away', awaySegments: 3, returnState: 'injured' },
  ],
  groups: [
    { id: 'tail', members: ['p_alive'], leaderId: 'p_alive' },
    { id: 'engine', members: ['p_injured'], leaderId: 'p_injured' },
    { id: 'guard', members: ['p_dead'] },
    { id: 'medtech', members: ['p_away'] },
    { id: 'front', members: [] },
  ],
});

const context: EffectContext = {
  deals: {
    deal_heat: { id: 'deal_heat', from: 'tail', tool: 'open', deadline: 3 },
  },
};

interface EffectCase {
  effect: Effect;
  result: (state: GameState) => unknown;
  expected: unknown;
}

const effectCases: EffectCase[] = [
  { effect: { type: 'coal', amount: 2.5 }, result: state => state.resources.coal, expected: 102.5 },
  { effect: { type: 'food', amount: -2.5 }, result: state => state.resources.food, expected: 97.5 },
  { effect: { type: 'medicine', amount: 3 }, result: state => state.resources.medicine, expected: 23 },
  { effect: { type: 'luxury', amount: 4 }, result: state => state.resources.luxury, expected: 14 },
  { effect: { type: 'symbol', id: 'item_bell', amount: 2 }, result: state => [state.symbols, state.acquiredSymbols], expected: [['item_bell'], ['item_bell']] },
  { effect: { type: 'secret', id: 'secret_debt', amount: 2 }, result: state => state.secrets, expected: ['secret_debt'] },
  { effect: { type: 'community.warmth', target: 'tail', amount: 5 }, result: state => state.communities.tail.warmth, expected: 55 },
  { effect: { type: 'community.ration', target: 'engine', amount: -5 }, result: state => state.communities.engine.ration, expected: 45 },
  { effect: { type: 'community.crowding', target: 'guard', amount: 6 }, result: state => state.communities.guard.crowding, expected: 6 },
  { effect: { type: 'community.exposure', target: 'medtech', amount: 7 }, result: state => state.communities.medtech.exposure, expected: 7 },
  { effect: { type: 'trust', amount: -4 }, result: state => state.trust, expected: 46 },
  { effect: { type: 'tension', amount: 4 }, result: state => state.tension, expected: 4 },
  { effect: { type: 'fear', amount: 5 }, result: state => state.fear, expected: 5 },
  { effect: { type: 'relation', target: 'tail', amount: -7.5 }, result: state => state.groups.tail.relation, expected: -7.5 },
  { effect: { type: 'cohesion', target: 'tail', amount: 0.1 }, result: state => state.groups.tail.cohesion, expected: 0.85 },
  { effect: { type: 'votes', target: 'tail', amount: 1.5 }, result: state => state.groups.tail.votes, expected: 1.5 },
  { effect: { type: 'person.state', target: 'p_alive', state: 'injured' }, result: state => [state.persons.p_alive.state, state.persons.p_alive.awaySegments, state.persons.p_alive.returnState], expected: ['injured', 0, 'injured'] },
  { effect: { type: 'person.away', target: 'p_injured', segments: 2 }, result: state => [state.persons.p_injured.state, state.persons.p_injured.awaySegments, state.persons.p_injured.returnState], expected: ['away', 2, 'injured'] },
  { effect: { type: 'flag', id: 'heat_requested', value: false }, result: state => state.flags, expected: { heat_requested: false } },
  { effect: { type: 'followup', id: 'event_reply', delay: 2 }, result: state => state.followups, expected: [{ id: 'event_reply', remainingSegments: 2 }] },
  { effect: { type: 'deal', id: 'deal_heat' }, result: state => [state.deals, state.promises], expected: [[{ id: 'deal_heat', from: 'tail', tool: 'open', openedAtSegment: 7, deadlineSegment: 10 }], [{ id: 'deal_heat', dealId: 'deal_heat', target: 'tail', deadlineSegment: 10 }]] },
  { effect: { type: 'chronicle', id: 'chronicle_heat' }, result: state => state.chronicle, expected: ['chronicle_heat'] },
];

const commonSchema = JSON.parse(readFileSync(new URL('../../schema/common.schema.json', import.meta.url), 'utf8'));
const effectsSchema = JSON.parse(readFileSync(new URL('../../schema/effects.schema.json', import.meta.url), 'utf8'));
const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
ajv.addSchema(commonSchema);
ajv.addSchema(effectsSchema);
const validateEffectSchema = ajv.getSchema('urn:s1:schema:effects')!;
const validateConditionSchema = ajv.getSchema('urn:s1:schema:common#/$defs/condition')!;

function deepFreeze<T>(value: T): T {
  if (typeof value === 'object' && value !== null && !Object.isFrozen(value)) {
    for (const item of Object.values(value)) deepFreeze(item);
    Object.freeze(value);
  }
  return value;
}

describe('효과 스키마와 실제 상태 변화', () => {
  it('등록된 22가지 type과 실제 적용 사례가 정확히 일치한다', () => {
    const registered: string[] = effectsSchema.oneOf.flatMap(
      (branch: { properties: { type: { enum?: string[]; const?: string } } }) =>
        branch.properties.type.enum ?? [branch.properties.type.const!],
    );
    expect(registered).toHaveLength(22);
    expect(effectCases).toHaveLength(22);
    expect(effectCases.map(item => item.effect.type).sort()).toEqual(registered.sort());
  });

  it.each(effectCases)('$effect.type의 스키마 유효성과 실제 변경 필드를 확인한다', ({ effect, result, expected }) => {
    expect(validateEffectSchema(effect), JSON.stringify(validateEffectSchema.errors)).toBe(true);
    const original = deepFreeze(initialState());
    const next = applyEffect(original, deepFreeze(effect), deepFreeze(context));
    expect(result(next)).toEqual(expected);
    expect(next.rng).toEqual(original.rng);
  });

  it('다섯 공동체의 네 수치를 각각 독립적으로 변경한다', () => {
    for (const target of COMMUNITY_IDS) {
      for (const metric of COMMUNITY_METRICS) {
        const original = initialState();
        const next = applyEffect(original, { type: `community.${metric}`, target, amount: 9 });
        expect(next.communities[target][metric]).toBe(original.communities[target][metric] + 9);
        for (const other of COMMUNITY_IDS.filter(id => id !== target)) {
          expect(next.communities[other]).toEqual(original.communities[other]);
        }
      }
    }
  });

  it('모든 숫자 효과를 정해진 상하한에 고정하며 중간 소수는 보존한다', () => {
    for (const entry of effectCases) {
      if (!('amount' in entry.effect) || entry.effect.type === 'symbol' || entry.effect.type === 'secret') continue;
      const original = initialState();
      const upper = applyEffect(original, { ...entry.effect, amount: Number.MAX_VALUE });
      const lower = applyEffect(original, { ...entry.effect, amount: -Number.MAX_VALUE });
      const type = entry.effect.type;
      const limits = type === 'relation' || type === 'cohesion' || type === 'votes'
        ? STATE_LIMITS[type]
        : ['coal', 'food', 'medicine', 'luxury'].includes(type) ? STATE_LIMITS.resource : STATE_LIMITS.metric;
      expect(entry.result(upper)).toBe(limits.max);
      expect(entry.result(lower)).toBe(limits.min);
    }
    const votes = applyEffect(initialState(), { type: 'votes', target: 'tail', amount: 2.75 });
    expect(votes.groups.tail.votes).toBe(2.75);
  });

  it('구간 수와 기한은 구간 상한에 고정하고 숫자 플래그의 의미는 보존한다', () => {
    const state = initialState();
    const next = applyEffects(state, [
      { type: 'person.away', target: 'p_alive', segments: 1e20 },
      { type: 'followup', id: 'event_later', delay: 1e20 },
      { type: 'flag', id: 'large_number', value: 1e20 },
      { type: 'deal', id: 'deal_later' },
    ], { deals: { deal_later: { id: 'deal_later', from: 'tail', tool: 'open', deadline: 1e20 } } });
    expect(next.persons.p_alive.awaySegments).toBe(STATE_LIMITS.segment.max);
    expect(next.followups[0].remainingSegments).toBe(STATE_LIMITS.segment.max);
    expect(next.deals[0].deadlineSegment).toBe(STATE_LIMITS.segment.max);
    expect(next.flags.large_number).toBe(1e20);
  });
});

describe('효과 적용의 원본 보존', () => {
  it('모든 효과를 함께 적용해도 원본과 효과 및 거래 정의를 변경하지 않는다', () => {
    const original = deepFreeze(initialState());
    const before = cloneGameState(original);
    const effects = deepFreeze(effectCases.map(entry => entry.effect));
    const definitions = deepFreeze(context);
    const next = applyEffects(original, effects, definitions);
    expect(original).toEqual(before);
    expect(next).not.toBe(original);
    expect(next.resources).not.toBe(original.resources);
    expect(next.rng).not.toBe(original.rng);
    for (const id of COMMUNITY_IDS) expect(next.communities[id]).not.toBe(original.communities[id]);
    for (const id of Object.keys(original.persons)) expect(next.persons[id]).not.toBe(original.persons[id]);
    for (const id of Object.keys(original.groups)) {
      expect(next.groups[id]).not.toBe(original.groups[id]);
      expect(next.groups[id].members).not.toBe(original.groups[id].members);
    }
    expect(next.flags).not.toBe(original.flags);
    expect(next.followups).not.toBe(original.followups);
    expect(next.deals).not.toBe(original.deals);
    expect(next.promises).not.toBe(original.promises);
    expect(next.chronicle).not.toBe(original.chronicle);
  });

  it('빈 효과 목록도 중첩 상태 전체를 복사한다', () => {
    const populated = applyEffects(initialState(), [
      { type: 'followup', id: 'event_later', delay: 2 },
      { type: 'deal', id: 'deal_heat' },
      { type: 'symbol', id: 'item_bell', amount: 1 },
      { type: 'secret', id: 'secret_debt', amount: 1 },
      { type: 'chronicle', id: 'chronicle_heat' },
    ], context);
    const original = deepFreeze(populated);
    const before = cloneGameState(original);
    const next = applyEffects(original, []);
    expect(next).toEqual(original);
    expect(next).not.toBe(original);
    next.followups[0].remainingSegments = 99;
    next.deals[0].deadlineSegment = 99;
    next.promises[0].deadlineSegment = 99;
    next.groups.tail.members.push('p_new');
    next.symbols.push('item_new');
    next.secrets.push('secret_new');
    next.acquiredSymbols.push('item_new');
    next.chronicle.push('chronicle_new');
    next.persons.p_alive.state = 'dead';
    next.communities.tail.warmth = 0;
    next.resources.coal = 0;
    next.flags.new_flag = true;
    expect(original).toEqual(before);
  });

  it.each([
    { type: 'unknown' },
    { type: 'person.state', target: 'p_missing', state: 'dead' },
    { type: 'deal', id: 'deal_missing' },
  ])('목록 중간의 오류에서도 먼저 적용한 변화가 원본에 남지 않는다: $type', invalid => {
    const original = deepFreeze(initialState());
    const before = cloneGameState(original);
    expect(() => applyEffects(original, [
      { type: 'coal', amount: -20 },
      { type: 'person.away', target: 'p_alive', segments: 2 },
      { type: 'flag', id: 'started', value: true },
      invalid as Effect,
    ], context)).toThrow();
    expect(original).toEqual(before);
  });
});

describe('상징물과 비밀의 고유 id 정책', () => {
  it.each(['symbol', 'secret'] as const)('%s은 정수 변화량의 부호로만 소유를 바꾼다', type => {
    const key = type === 'symbol' ? 'symbols' : 'secrets';
    let state = applyEffects(initialState(), [
      { type, id: 'item_one', amount: 2 },
      { type, id: 'item_one', amount: 1 },
      { type, id: 'item_two', amount: 0 },
    ]);
    expect(state[key]).toEqual(['item_one']);
    state = applyEffect(state, { type, id: 'item_one', amount: 0 });
    expect(state[key]).toEqual(['item_one']);
    state = applyEffect(state, { type, id: 'item_one', amount: -2 });
    expect(state[key]).toEqual([]);
    state = applyEffect(state, { type, id: 'item_missing', amount: -1 });
    expect(state[key]).toEqual([]);
  });

  it('상징물을 넘겨도 획득 이력은 남고 명시적 반환 효과는 재소유를 허용한다', () => {
    const acquired = applyEffect(initialState(), { type: 'symbol', id: 'item_bell', amount: 1 });
    const given = applyEffect(acquired, { type: 'symbol', id: 'item_bell', amount: -1 });
    expect(given.symbols).toEqual([]);
    expect(given.acquiredSymbols).toEqual(['item_bell']);
    const returned = applyEffect(given, { type: 'symbol', id: 'item_bell', amount: 1 });
    expect(returned.symbols).toEqual(['item_bell']);
    expect(returned.acquiredSymbols).toEqual(['item_bell']);
  });
});

describe('사람 상태와 파견', () => {
  it('기간 없는 away 지시는 기본 기간을 쓰고 기존 파견 기간은 보존한다', () => {
    const state = applyEffects(initialState(), [
      { type: 'person.state', target: 'p_alive', state: 'away' },
      { type: 'person.state', target: 'p_away', state: 'away' },
    ]);
    expect(state.persons.p_alive).toMatchObject({
      state: 'away', awaySegments: EFFECT_DEFAULTS.awaySegments, returnState: 'alive',
    });
    expect(state.persons.p_away).toMatchObject({ state: 'away', awaySegments: 3, returnState: 'injured' });
  });

  it('파견 기간을 바꿔도 부상을 기억하며 0구간이면 부상 상태로 돌아온다', () => {
    const away = applyEffects(initialState(), [
      { type: 'person.away', target: 'p_injured', segments: 4 },
      { type: 'person.away', target: 'p_injured', segments: 2 },
    ]);
    expect(away.persons.p_injured).toMatchObject({ state: 'away', awaySegments: 2, returnState: 'injured' });
    const returned = applyEffect(away, { type: 'person.away', target: 'p_injured', segments: 0 });
    expect(returned.persons.p_injured).toMatchObject({ state: 'injured', awaySegments: 0, returnState: 'injured' });
    const healthy = applyEffects(initialState(), [
      { type: 'person.away', target: 'p_alive', segments: 1 },
      { type: 'person.away', target: 'p_alive', segments: 0 },
    ]);
    expect(healthy.persons.p_alive).toMatchObject({ state: 'alive', awaySegments: 0, returnState: 'alive' });
  });

  it('사망자는 파견할 수 없고 귀환 효과가 되살리지 않는다', () => {
    const state = initialState();
    expect(() => applyEffect(state, { type: 'person.away', target: 'p_dead', segments: 1 })).toThrow(/사망/);
    expect(() => applyEffect(state, { type: 'person.state', target: 'p_dead', state: 'away' })).toThrow(/사망/);
    const returned = applyEffect(state, { type: 'person.away', target: 'p_dead', segments: 0 });
    expect(returned.persons.p_dead).toEqual(state.persons.p_dead);
    const killed = applyEffect(state, { type: 'person.state', target: 'p_away', state: 'dead' });
    expect(killed.persons.p_away).toMatchObject({ state: 'dead', awaySegments: 0 });
    expect(applyEffect(killed, { type: 'person.away', target: 'p_away', segments: 0 }).persons.p_away.state).toBe('dead');
  });

  it('명시적 alive 지정은 사망 이후에도 허용하며 파견 정보는 지운다', () => {
    const state = applyEffects(initialState(), [
      { type: 'person.state', target: 'p_dead', state: 'alive' },
      { type: 'person.state', target: 'p_away', state: 'injured' },
    ]);
    expect(state.persons.p_dead).toMatchObject({ state: 'alive', awaySegments: 0, returnState: 'alive' });
    expect(state.persons.p_away).toMatchObject({ state: 'injured', awaySegments: 0, returnState: 'injured' });
  });
});

describe('후속 사건과 거래 및 약속', () => {
  it('지연 0인 후속 사건과 같은 기록 id를 반복해도 각각 남긴다', () => {
    const state = applyEffects(initialState(), [
      { type: 'followup', id: 'event_reply', delay: 0 },
      { type: 'followup', id: 'event_reply', delay: 2 },
      { type: 'chronicle', id: 'chronicle_reply' },
      { type: 'chronicle', id: 'chronicle_reply' },
    ]);
    expect(state.followups).toEqual([
      { id: 'event_reply', remainingSegments: 0 },
      { id: 'event_reply', remainingSegments: 2 },
    ]);
    expect(state.chronicle).toEqual(['chronicle_reply', 'chronicle_reply']);
  });

  it.each(DEAL_TOOLS)('%s 거래의 상대 기한을 기록하고 해당되는 약속만 추가한다', tool => {
    const from = tool === 'open' ? 'tail' : 'p_alive';
    const definition: EffectDealDefinition = {
      id: 'deal_one', from, tool, deadline: 0,
      ask: [{ type: 'coal', amount: -90 }],
      gives: [{ type: 'votes', target: 'tail', amount: 20 }],
      breach: [{ type: 'trust', amount: -50 }],
      arc_tags: [], content_type: 'deal',
    };
    const before = initialState();
    const next = applyEffect(before, { type: 'deal', id: 'deal_one' }, { deals: { deal_one: definition } });
    expect(next.deals).toEqual([{ id: 'deal_one', from, tool, openedAtSegment: 7, deadlineSegment: 7 }]);
    expect(next.promises).toEqual(['open', 'fetch', 'favor'].includes(tool)
      ? [{ id: 'deal_one', dealId: 'deal_one', target: from, deadlineSegment: 7 }] : []);
    expect(next.resources).toEqual(before.resources);
    expect(next.groups).toEqual(before.groups);
    expect(next.trust).toBe(before.trust);
  });

  it('같은 진행 거래 id를 다시 열어 기한을 연장할 수 없다', () => {
    const active = applyEffect(initialState(), { type: 'deal', id: 'deal_heat' }, context);
    const before = cloneGameState(active);
    expect(() => applyEffect(active, { type: 'deal', id: 'deal_heat' }, {
      deals: { deal_heat: { id: 'deal_heat', from: 'tail', tool: 'open', deadline: 99 } },
    })).toThrow(/이미 진행/);
    expect(active).toEqual(before);
    expect(active.deals[0].deadlineSegment).toBe(10);
  });

  it.each([
    ['tail', 'p_alive'],
    ['p_alive', 'tail'],
  ])('공개 약속의 집단을 정규화하여 %s에서 %s로 바꿔도 제한을 우회할 수 없다', (first, second) => {
    const definitions: EffectContext = { deals: {
      deal_first: { id: 'deal_first', from: first, tool: 'open', deadline: 2 },
      deal_second: { id: 'deal_second', from: second, tool: 'open', deadline: 3 },
      deal_other: { id: 'deal_other', from: 'p_injured', tool: 'open', deadline: 4 },
    } };
    const active = applyEffect(initialState(), { type: 'deal', id: 'deal_first' }, definitions);
    expect(active.promises[0].target).toBe('tail');
    expect(active.deals[0].from).toBe(first);
    expect(() => applyEffect(active, { type: 'deal', id: 'deal_second' }, definitions)).toThrow(/미이행 공개 약속/);
    const another = applyEffect(active, { type: 'deal', id: 'deal_other' }, definitions);
    expect(another.promises.map(promise => promise.target)).toEqual(['tail', 'engine']);
  });

  it('사적 부탁은 공개 약속 정원을 차지하지 않는다', () => {
    const definitions: EffectContext = { deals: {
      deal_favor: { id: 'deal_favor', from: 'tail', tool: 'favor', deadline: 2 },
      deal_heat: { id: 'deal_heat', from: 'tail', tool: 'open', deadline: 3 },
    } };
    const active = applyEffects(initialState(), [
      { type: 'deal', id: 'deal_favor' }, { type: 'deal', id: 'deal_heat' },
    ], definitions);
    expect(active.promises).toHaveLength(2);
  });

  it('한 사람이 여러 집단의 지도자이면 공개 거래 대상을 추측하지 않는다', () => {
    const state = initialState();
    state.groups.engine.leaderId = 'p_alive';
    expect(() => applyEffect(state, { type: 'deal', id: 'deal_ambiguous' }, {
      deals: { deal_ambiguous: { id: 'deal_ambiguous', from: 'p_alive', tool: 'open', deadline: 1 } },
    })).toThrow(/하나로 정할/);
  });

  it.each([
    undefined,
    {},
    { deals: {} },
    { deals: { deal_one: { id: 'other_id', from: 'tail', tool: 'open', deadline: 1 } } },
    { deals: { deal_one: { id: 'deal_one', from: 'missing', tool: 'open', deadline: 1 } } },
    { deals: { deal_one: { id: 'deal_one', from: 'missing', tool: 'favor', deadline: 1 } } },
    { deals: { deal_one: { id: 'deal_one', from: 'p_away', tool: 'open', deadline: 1 } } },
    { deals: { deal_one: { id: 'deal_one', from: 'tail', tool: 'unknown', deadline: 1 } } },
    { deals: { deal_one: { id: 'deal_one', from: 'tail', tool: 'open', deadline: -1 } } },
    { deals: { deal_one: { id: 'deal_one', from: 'tail', tool: 'open', deadline: 1.5 } } },
    { deals: { deal_one: { id: 'deal_one', from: 'tail', tool: 'open', deadline: Infinity } } },
  ])('정의나 거래 대상 또는 기한이 잘못되면 원본을 보존하며 거부한다: %j', invalidContext => {
    const state = deepFreeze(initialState());
    expect(() => applyEffect(state, { type: 'deal', id: 'deal_one' }, invalidContext as EffectContext)).toThrow();
    expect(state.deals).toEqual([]);
    expect(state.promises).toEqual([]);
  });
});

describe('조건 종류와 경계', () => {
  it('빈 목록은 참이고 모든 조건이 참이어야 목록이 참이다', () => {
    const state = applyEffect(initialState(), { type: 'flag', id: 'ready', value: true });
    const conditions: Condition[] = [
      { type: 'segment', min: 7, max: 7 },
      { type: 'community', community: 'tail', metric: 'warmth', operator: 'eq', value: 50 },
      { type: 'flag', id: 'ready', value: true },
      { type: 'person', id: 'p_alive', state: 'alive' },
    ];
    for (const condition of conditions) {
      expect(validateConditionSchema(condition), JSON.stringify(validateConditionSchema.errors)).toBe(true);
    }
    expect(evaluateConditions(state, [])).toBe(true);
    expect(evaluateConditions(state, conditions)).toBe(true);
    expect(evaluateConditions(state, [...conditions, { type: 'person', id: 'p_alive', state: 'dead' }])).toBe(false);
  });

  it.each([
    [6, false], [7, true], [8, true], [9, true], [10, false],
  ] as const)('구간 %s에서 양쪽 끝을 포함한 7~9구간 조건을 평가한다', (segment, expected) => {
    const state = createInitialState({ segment });
    expect(evaluateCondition(state, { type: 'segment', min: 7, max: 9 })).toBe(expected);
  });

  it.each([
    ['lt', [false, false, true]],
    ['lte', [false, true, true]],
    ['eq', [false, true, false]],
    ['gte', [true, true, false]],
    ['gt', [true, false, false]],
  ] as const)('%s 비교의 낮음·같음·높음 경계를 모든 공동체 수치에서 확인한다', (operator, expected) => {
    const state = initialState();
    for (const community of COMMUNITY_IDS) {
      for (const metric of COMMUNITY_METRICS) {
        const actual = state.communities[community][metric];
        const outcomes = [actual - 1, actual, actual + 1].map(value => evaluateCondition(state, {
          type: 'community', community, metric, operator: operator as ConditionOperator, value,
        }));
        expect(outcomes).toEqual(expected);
      }
    }
  });

  it.each([false, 0, '', true, 1, '1'] as const)('플래그 %j는 타입을 바꾸지 않고 엄격하게 비교한다', value => {
    const empty = initialState();
    expect(evaluateCondition(empty, { type: 'flag', id: 'check', value })).toBe(false);
    const state = applyEffect(empty, { type: 'flag', id: 'check', value });
    for (const candidate of [false, 0, '', true, 1, '1'] as const) {
      expect(evaluateCondition(state, { type: 'flag', id: 'check', value: candidate })).toBe(candidate === value);
    }
  });

  it('모든 사람 상태를 검사하고 없는 사람은 거짓이다', () => {
    const state = initialState();
    for (const person of Object.values(state.persons)) {
      for (const status of ['alive', 'injured', 'dead', 'away'] as const) {
        expect(evaluateCondition(state, { type: 'person', id: person.id, state: status })).toBe(status === person.state);
      }
    }
    expect(evaluateCondition(state, { type: 'person', id: 'p_missing', state: 'alive' })).toBe(false);
  });

  it('앞 조건이 거짓이어도 뒤의 알 수 없는 type과 잘못된 인자를 거부한다', () => {
    const state = initialState();
    const first: Condition = { type: 'segment', min: 100, max: 200 };
    expect(evaluateCondition(state, first)).toBe(false);
    expect(() => evaluateConditions(state, [first, { type: 'unknown' } as unknown as Condition])).toThrow(/모르는 조건 type/);
    expect(() => evaluateConditions(state, [first, { type: 'segment', min: 3, max: 1 }])).toThrow(/뒤집/);
  });

  it('조건 평가는 상태를 바꾸지 않는다', () => {
    const state = deepFreeze(initialState());
    const before = cloneGameState(state);
    evaluateConditions(state, [
      { type: 'segment', min: 0, max: 24 },
      { type: 'person', id: 'p_away', state: 'away' },
    ]);
    expect(state).toEqual(before);
  });
});

describe('런타임 입력 오류', () => {
  const invalidEffects: unknown[] = [
    null, [], {},
    { type: 'unknown' },
    { type: 'coal' },
    { type: 'coal', amount: '1' },
    { type: 'coal', amount: NaN },
    { type: 'coal', amount: Infinity },
    { type: 'coal', amount: 1, target: 'tail' },
    { type: 'symbol', id: 'item', amount: 1.5 },
    { type: 'secret', id: 'BAD_ID', amount: 1 },
    { type: 'community.warmth', target: 'unknown', amount: 1 },
    { type: 'community.unknown', target: 'tail', amount: 1 },
    { type: 'votes', target: 'missing_group', amount: 1 },
    { type: 'relation', target: 'p_alive', amount: 1 },
    { type: 'person.state', target: 'p_missing', state: 'injured' },
    { type: 'person.state', target: 'p_alive', state: 'unknown' },
    { type: 'person.away', target: 'p_alive', segments: -1 },
    { type: 'person.away', target: 'p_alive', segments: 1.5 },
    { type: 'flag', id: 'ready', value: null },
    { type: 'flag', id: 'ready', value: [] },
    { type: 'flag', id: 'ready', value: NaN },
    { type: 'followup', id: 'later', delay: -1 },
    { type: 'followup', id: 'later', segments: 1 },
    { type: 'deal', id: 'deal_heat', deadline: 3 },
    { type: 'chronicle', id: 1 },
  ];

  it.each(invalidEffects)('모르는 효과·잘못된 모양·잘못된 대상은 실패한다: %j', effect => {
    expect(() => applyEffect(initialState(), effect as Effect, context)).toThrow();
  });

  const invalidConditions: unknown[] = [
    null, [], {},
    { type: 'unknown' },
    { type: 'segment', min: 0 },
    { type: 'segment', min: -1, max: 2 },
    { type: 'segment', min: 1.5, max: 2 },
    { type: 'segment', min: 2, max: 1 },
    { type: 'segment', min: 0, max: 2, extra: true },
    { type: 'community', community: 'missing', metric: 'warmth', operator: 'eq', value: 50 },
    { type: 'community', community: 'tail', metric: 'missing', operator: 'eq', value: 50 },
    { type: 'community', community: 'tail', metric: 'warmth', operator: 'ne', value: 50 },
    { type: 'community', community: 'tail', metric: 'warmth', operator: 'eq', value: NaN },
    { type: 'flag', id: 'ready', value: null },
    { type: 'person', id: 'p_alive', state: 'unknown' },
    { type: 'person', id: 'BAD_ID', state: 'alive' },
  ];

  it.each(invalidConditions)('모르는 조건·잘못된 연산자·잘못된 모양은 실패한다: %j', condition => {
    expect(() => evaluateCondition(initialState(), condition as Condition)).toThrow();
  });

  it('효과와 조건 목록은 실제 배열이어야 한다', () => {
    expect(() => applyEffects(initialState(), null as unknown as Effect[])).toThrow(/배열/);
    expect(() => evaluateConditions(initialState(), {} as Condition[])).toThrow(/배열/);
  });

  it('constructor처럼 유효한 id도 원형에서 상속된 값을 대상으로 삼지 않는다', () => {
    const state = initialState();
    expect(evaluateCondition(state, { type: 'flag', id: 'constructor', value: false })).toBe(false);
    expect(evaluateCondition(state, { type: 'person', id: 'constructor', state: 'alive' })).toBe(false);
    expect(() => applyEffect(state, { type: 'votes', target: 'constructor', amount: 1 })).toThrow(/집단/);
    expect(() => applyEffect(state, { type: 'person.state', target: 'constructor', state: 'dead' })).toThrow(/사람/);
    expect(() => applyEffect(state, { type: 'deal', id: 'constructor' }, { deals: {} })).toThrow(/거래 정의/);
    const recorded = applyEffect(state, { type: 'flag', id: 'constructor', value: 0 });
    expect(evaluateCondition(recorded, { type: 'flag', id: 'constructor', value: 0 })).toBe(true);
  });

  it('명시적으로 등록한 constructor id는 사용할 수 있다', () => {
    const id = String('constructor');
    const state = createInitialState({
      persons: [{ id, community: 'tail' }],
      groups: [{ id, members: [id], leaderId: id }],
    });
    const next = applyEffects(state, [
      { type: 'votes', target: id, amount: 3 },
      { type: 'person.state', target: id, state: 'injured' },
      { type: 'deal', id },
    ], { deals: { [id]: { id, from: id, tool: 'open', deadline: 2 } } });
    expect(next.groups[id].votes).toBe(3);
    expect(next.persons[id].state).toBe('injured');
    expect(next.promises[0].target).toBe(id);
  });
});
