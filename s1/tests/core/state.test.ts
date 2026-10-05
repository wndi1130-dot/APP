import { describe, expect, it } from 'vitest';
import { COMMUNITY_IDS, EFFECT_DEFAULTS, INITIAL_VALUES } from '../../src/core/constants';
import { createRng } from '../../src/core/rng';
import { cloneGameState, createInitialState } from '../../src/core/state';
import type { GroupInput, PersonInput } from '../../src/core/state';

describe('게임의 처음 상태', () => {
  it('다섯 공동체와 임시 초기값, 비어 있는 기록을 만든다', () => {
    const state = createInitialState();
    expect(Object.keys(state.communities)).toEqual([...COMMUNITY_IDS]);
    expect(Object.keys(state.groups)).toEqual([...COMMUNITY_IDS]);
    for (const id of COMMUNITY_IDS) {
      expect(state.communities[id]).toEqual(INITIAL_VALUES.community);
      expect(state.groups[id]).toEqual({
        id, members: [], relation: INITIAL_VALUES.relation,
        cohesion: INITIAL_VALUES.cohesion, votes: INITIAL_VALUES.votes,
      });
    }
    expect(state).toMatchObject({
      segment: INITIAL_VALUES.segment,
      trust: INITIAL_VALUES.trust,
      tension: INITIAL_VALUES.tension,
      fear: INITIAL_VALUES.fear,
      resources: INITIAL_VALUES.resources,
      persons: {}, flags: {}, symbols: [], secrets: [], acquiredSymbols: [],
      followups: [], deals: [], promises: [], chronicle: [],
    });
    expect(state.rng).toEqual(createRng(INITIAL_VALUES.seed));
  });

  it('같은 시드와 같은 입력은 같은 상태를 만들고 저장 가능한 객체만 담는다', () => {
    const options = { seed: '여섯 번째 겨울', segment: 3 };
    const state = createInitialState(options);
    expect(state).toEqual(createInitialState(options));
    expect(state.rng).toEqual(createRng(options.seed));
    expect(state.segment).toBe(3);
    expect(JSON.parse(JSON.stringify(state))).toEqual(state);
  });

  it('초기 상태끼리, 공동체끼리, 상수와 가변 객체를 공유하지 않는다', () => {
    const first = createInitialState();
    const second = createInitialState();
    first.communities.tail.warmth = 7;
    first.groups.tail.members.push('p_local');
    first.resources.coal = 0;
    first.symbols.push('symbol_local');
    expect(second).toEqual(createInitialState());
    expect(first.communities.engine.warmth).toBe(INITIAL_VALUES.community.warmth);
    expect(INITIAL_VALUES.resources.coal).toBe(100);
  });

  it('입력 프로필의 신분을 유지하고 아이도 집단에 넣는다', () => {
    const persons: PersonInput[] = [
      { id: 'p_child', community: 'tail', age: 0 },
      { id: 'p_injured', community: 'engine', age: 67, state: 'injured' },
      { id: 'p_away', community: 'guard', state: 'away', awaySegments: 2, returnState: 'injured' },
      { id: 'p_dead', community: 'front', state: 'dead' },
    ];
    const saved = structuredClone(persons);
    const state = createInitialState({ persons });
    expect(state.groups.tail.members).toEqual(['p_child']);
    expect(state.persons.p_child).toMatchObject({ state: 'alive', age: 0, awaySegments: 0 });
    expect(state.persons.p_injured).toMatchObject({ state: 'injured', returnState: 'injured' });
    expect(state.persons.p_away).toMatchObject({ state: 'away', awaySegments: 2, returnState: 'injured' });
    expect(state.persons.p_dead.state).toBe('dead');
    state.persons.p_away.awaySegments = 1;
    expect(persons).toEqual(saved);
  });

  it('프로필의 away에 기간이 없으면 명시한 임시 기본 기간을 쓴다', () => {
    const state = createInitialState({ persons: [{ id: 'p_away', community: 'tail', state: 'away' }] });
    expect(state.persons.p_away.awaySegments).toBe(EFFECT_DEFAULTS.awaySegments);
  });

  it('지정한 의석 집단을 그대로 쓰고 세력원을 공동체에 중복 편성하지 않는다', () => {
    const persons: PersonInput[] = [
      { id: 'p_one', community: 'tail' }, { id: 'p_two', community: 'tail' },
    ];
    const groups: GroupInput[] = [
      { id: 'tail', members: ['p_one'], leaderId: 'p_one' },
      { id: 'faction_one', members: ['p_two'], leaderId: 'p_two', relation: -10, cohesion: 1, votes: 12.5 },
    ];
    const state = createInitialState({ persons, groups });
    expect(Object.keys(state.groups)).toEqual(['tail', 'faction_one']);
    expect(Object.keys(state.communities)).toEqual([...COMMUNITY_IDS]);
    expect(state.groups.tail.members).toEqual(['p_one']);
    expect(state.groups.faction_one).toEqual({
      id: 'faction_one', members: ['p_two'], leaderId: 'p_two', relation: -10, cohesion: 1, votes: 12.5,
    });
    state.groups.tail.members.push('p_two');
    expect(groups[0].members).toEqual(['p_one']);
  });

  it.each([-1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1])(
    '올바르지 않은 시작 구간 %s를 거부한다', segment => {
      expect(() => createInitialState({ segment })).toThrow();
    },
  );

  it.each([
    { id: 'Bad-ID', community: 'tail' },
    { id: 'p_one', community: 'missing' },
    { id: 'p_one', community: 'tail', state: 'missing' },
    { id: 'p_one', community: 'tail', state: 'alive', awaySegments: 1 },
    { id: 'p_one', community: 'tail', state: 'away', awaySegments: 0 },
    { id: 'p_one', community: 'tail', state: 'away', awaySegments: -1 },
    { id: 'p_one', community: 'tail', age: 86 },
    { id: 'p_one', community: 'tail', age: 1.5 },
    { id: 'p_one', community: 'tail', age: NaN },
    { id: 'p_one', community: 'tail', returnState: 'dead' },
  ])('잘못된 프로필 %j를 거부한다', person => {
    expect(() => createInitialState({ persons: [person as PersonInput] })).toThrow();
  });

  it('사람 id 중복을 거부한다', () => {
    const person: PersonInput = { id: 'p_one', community: 'tail' };
    expect(() => createInitialState({ persons: [person, person] })).toThrow(/중복/);
  });

  it.each([
    [{ id: 'tail', members: [] }, { id: 'tail', members: [] }],
    [{ id: 'tail', members: ['p_missing'] }],
    [{ id: 'tail', members: ['p_one', 'p_one'] }],
    [{ id: 'tail', members: ['p_one'] }, { id: 'front', members: ['p_one'] }],
    [{ id: 'tail', members: ['p_one'], leaderId: 'p_missing' }],
    [{ id: 'tail', members: ['p_one'], relation: -101 }],
    [{ id: 'tail', members: ['p_one'], cohesion: 1.1 }],
    [{ id: 'tail', members: ['p_one'], votes: NaN }],
  ])('중복·없는 대상·범위 밖 집단 입력을 거부한다: %j', (...groups) => {
    expect(() => createInitialState({
      persons: [{ id: 'p_one', community: 'tail' }], groups: groups as GroupInput[],
    })).toThrow();
  });

  it('자바스크립트 상속 속성과 같은 유효 id도 보통 id로 처리한다', () => {
    const state = createInitialState({
      persons: [{ id: 'constructor', community: 'tail' }],
      groups: [{ id: 'constructor', members: ['constructor'] }],
    });
    expect(state.persons.constructor).toMatchObject({ id: 'constructor', state: 'alive' });
    expect(state.groups.constructor).toMatchObject({ id: 'constructor', members: ['constructor'] });
  });
});

describe('게임 상태 복사', () => {
  it('모든 중첩 목록과 객체를 복사해 외부 변경으로 원본이 바뀌지 않는다', () => {
    const original = createInitialState({ persons: [{ id: 'p_one', community: 'tail' }] });
    original.symbols.push('item_bell');
    original.secrets.push('secret_letter');
    original.acquiredSymbols.push('item_bell');
    original.flags.heat_promised = true;
    original.followups.push({ id: 'ev_heat', remainingSegments: 2 });
    original.deals.push({ id: 'deal_heat', from: 'tail', tool: 'open', openedAtSegment: 0, deadlineSegment: 2 });
    original.promises.push({ id: 'deal_heat', dealId: 'deal_heat', target: 'tail', deadlineSegment: 2 });
    original.chronicle.push('ch_heat');
    const saved = structuredClone(original);
    const copy = cloneGameState(original);
    expect(copy).toEqual(original);
    expect(copy.rng).not.toBe(original.rng);
    copy.communities.tail.warmth = 0;
    copy.resources.coal = 0;
    copy.symbols.length = 0;
    copy.secrets.length = 0;
    copy.acquiredSymbols.length = 0;
    copy.persons.p_one.state = 'injured';
    copy.groups.tail.members.length = 0;
    copy.flags.heat_promised = false;
    copy.followups[0].remainingSegments = 0;
    copy.deals[0].deadlineSegment = 99;
    copy.promises[0].deadlineSegment = 99;
    copy.chronicle.length = 0;
    expect(original).toEqual(saved);
  });
});
