import { describe, expect, it } from 'vitest';
import {
  allocateSeats,
  buildCouncilGroups,
  calculateAvailableVotes,
  passesLaw,
  requiredVotes,
  resolveCouncilVote,
} from '../../src/core/council';
import type {
  CouncilGroup,
  LawKind,
  PopulationGroup,
  TurnoutPolicy,
  VoteMode,
} from '../../src/core/council';
import { createRng, nextRandom, randomInt } from '../../src/core/rng';
import { createInitialState } from '../../src/core/state';

function group(overrides: Partial<CouncilGroup> = {}): CouncilGroup {
  return {
    id: 'tail', population: 100, present: 100, cohesion: 1, promisedVotes: 100,
    ...overrides,
  };
}

function vote(groups: readonly CouncilGroup[], kind: LawKind = 'normal', mode: VoteMode = 'public') {
  return resolveCouncilVote(groups, { kind, mode, rng: createRng(1) });
}

describe('의석 배분', () => {
  it('시드로 뽑은 무작위 인구 1000번에서 의석 합계가 100이고 각 집단은 할당량의 내림 또는 올림이다', () => {
    let rng = createRng('allocation-1000');
    for (let trial = 0; trial < 1_000; trial += 1) {
      const size = randomInt(rng, 1, 20);
      rng = size.rng;
      const groups: PopulationGroup[] = [];
      for (let index = 0; index < size.value; index += 1) {
        const draw = randomInt(rng, 0, 1_000_000);
        rng = draw.rng;
        groups.push({ id: `group_${index}`, population: index % 7 === 0 ? 0 : draw.value });
      }
      groups[0].population += 1;
      const total = groups.reduce((sum, item) => sum + BigInt(item.population), 0n);
      const seats = allocateSeats(groups);
      expect(seats.reduce((sum, item) => sum + item.seats, 0)).toBe(100);
      for (const item of seats) {
        const numerator = BigInt(item.population) * 100n;
        const lower = Number(numerator / total);
        const upper = Number((numerator + total - 1n) / total);
        expect(item.seats === lower || item.seats === upper).toBe(true);
      }
    }
  });

  it('잔여가 같으면 인구가 큰 집단을 먼저 고르고 그다음 id 순으로 고른다', () => {
    expect(allocateSeats([
      { id: 'a', population: 1 }, { id: 'b', population: 1 }, { id: 'z', population: 4 },
    ])).toEqual([
      { id: 'a', population: 1, seats: 17 },
      { id: 'b', population: 1, seats: 16 },
      { id: 'z', population: 4, seats: 67 },
    ]);
  });

  it('잔여와 인구가 모두 같으면 로케일과 무관한 id 순으로 고르고 입력 순서를 유지한다', () => {
    const inputs = [
      { id: 'z', population: 1 }, { id: 'ä', population: 1 }, { id: 'b', population: 1 },
    ];
    expect(allocateSeats(inputs)).toEqual([
      { id: 'z', population: 1, seats: 33 },
      { id: 'ä', population: 1, seats: 33 },
      { id: 'b', population: 1, seats: 34 },
    ]);
    expect(allocateSeats([inputs[0], inputs[1]])).toEqual([
      { id: 'z', population: 1, seats: 50 }, { id: 'ä', population: 1, seats: 50 },
    ]);
  });

  it('작은 인구와 0인 집단을 다루며 의석은 인원보다 많아도 된다', () => {
    expect(allocateSeats([{ id: 'empty', population: 0 }, { id: 'one', population: 1 }]))
      .toEqual([{ id: 'empty', population: 0, seats: 0 }, { id: 'one', population: 1, seats: 100 }]);
  });

  it('안전 정수 한계 부근의 인구와 안전 정수를 넘는 전체 인구도 정확히 계산한다', () => {
    const maximum = Number.MAX_SAFE_INTEGER;
    expect(allocateSeats([
      { id: 'a', population: maximum - 2 },
      { id: 'b', population: maximum - 1 },
      { id: 'z', population: maximum },
    ]).map(item => item.seats)).toEqual([33, 33, 34]);
    expect(allocateSeats([
      { id: 'a', population: maximum },
      { id: 'b', population: maximum },
      { id: 'c', population: maximum },
    ]).map(item => item.seats)).toEqual([34, 33, 33]);
  });

  it('입력 목록과 입력 객체를 수정하지 않는다', () => {
    const groups = Object.freeze([
      Object.freeze({ id: 'z', population: 2 }), Object.freeze({ id: 'a', population: 1 }),
    ]);
    const original = JSON.stringify(groups);
    const result = allocateSeats(groups);
    expect(JSON.stringify(groups)).toBe(original);
    expect(result[0]).not.toBe(groups[0]);
    expect(result.map(item => item.id)).toEqual(['z', 'a']);
  });

  it.each([
    [],
    [{ id: 'a', population: 0 }],
    [{ id: 'a', population: 0 }, { id: 'b', population: 0 }],
    [{ id: 'a', population: 1 }, { id: 'a', population: 2 }],
    [{ id: '', population: 1 }],
    [{ id: '   ', population: 1 }],
    [{ id: 'a', population: -1 }],
    [{ id: 'a', population: 1.2 }],
    [{ id: 'a', population: NaN }],
    [{ id: 'a', population: Infinity }],
    [{ id: 'a', population: -Infinity }],
    [{ id: 'a', population: Number.MAX_SAFE_INTEGER + 1 }],
  ].map(groups => ({ groups })))('배분할 수 없거나 잘못된 입력은 오류로 막는다: %j', ({ groups }) => {
    expect(() => allocateSeats(groups)).toThrow();
  });
});

describe('파견과 실제 표수', () => {
  it('일부 파견은 비례 내림하고 전체 파견은 0표가 된다', () => {
    expect(calculateAvailableVotes(33, 40, 31)).toBe(25);
    expect(calculateAvailableVotes(33, 40, 0)).toBe(0);
    expect(calculateAvailableVotes(33, 40, 40)).toBe(33);
    expect(calculateAvailableVotes(0, 0, 0)).toBe(0);
  });

  it('작은 소수 비율과 큰 정수에서도 정수 경계의 표를 잃지 않는다', () => {
    expect(calculateAvailableVotes(100, 100, 29)).toBe(29);
    expect(calculateAvailableVotes(100, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER)).toBe(100);
    expect(calculateAvailableVotes(100, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER - 1)).toBe(99);
    expect(calculateAvailableVotes(100, 100, 100, { participationRate: 0.29 })).toBe(29);
    expect(calculateAvailableVotes(100, 100, 100, { participationRate: 1e-7, turnoutRounding: 'ceil' })).toBe(1);
  });

  it('참여비율과 내림·올림·반올림을 주입할 수 있다', () => {
    expect(calculateAvailableVotes(100, 3, 2)).toBe(66);
    expect(calculateAvailableVotes(100, 3, 2, { turnoutRounding: 'ceil' })).toBe(67);
    expect(calculateAvailableVotes(100, 3, 2, { turnoutRounding: 'round' })).toBe(67);
    expect(calculateAvailableVotes(100, 4, 1, { participationRate: 0.5, turnoutRounding: 'round' })).toBe(13);
    expect(calculateAvailableVotes(100, 3, 2, { participationRate: 0.5 })).toBe(33);
    expect(calculateAvailableVotes(100, 3, 2, { participationRate: 0 })).toBe(0);
  });

  it('파견으로 빈 표는 다른 집단에 재배분하지 않고 기준표수도 내리지 않는다', () => {
    const result = vote([
      group({ id: 'tail', population: 100, present: 0 }),
      group({ id: 'engine', population: 100, present: 100 }),
    ]).record;
    expect(result).toMatchObject({ yes: 50, no: 0, abstain: 0, absent: 50, requiredVotes: 51, passed: false });
    if (result.mode !== 'public') throw new Error('공개 기록이 필요합니다.');
    expect(result.groups.map(item => item.seats)).toEqual([50, 50]);
    expect(result.groups.map(item => item.availableVotes)).toEqual([0, 50]);
  });

  it('모두 파견되어도 100석을 유지하고 두 종류의 법 모두 부결된다', () => {
    for (const kind of ['normal', 'rule'] as const) {
      expect(vote([group({ present: 0 })], kind).record)
        .toMatchObject({ yes: 0, no: 0, abstain: 0, absent: 100, passed: false });
    }
  });

  it.each([
    [-1, 10, 10], [101, 10, 10], [1.5, 10, 10],
    [10, -1, 0], [10, 10.5, 10], [10, Infinity, 0],
    [10, 10, -1], [10, 10, 11], [10, 10, 1.5], [10, 10, NaN],
  ])('잘못된 의석·인원 입력을 거부한다: %j', (seats, population, present) => {
    expect(() => calculateAvailableVotes(seats, population, present)).toThrow();
  });

  it.each([
    { participationRate: -0.1 }, { participationRate: 1.1 }, { participationRate: NaN },
    { participationRate: Infinity }, { turnoutRounding: 'truncate' },
  ])('잘못된 참여비율이나 반올림 방식을 거부한다: %j', policy => {
    expect(() => calculateAvailableVotes(100, 10, 10, policy as Partial<TurnoutPolicy>)).toThrow();
  });
});

describe('법안 통과 기준', () => {
  it.each([
    ['normal', 50, false], ['normal', 51, true], ['rule', 66, false], ['rule', 67, true],
  ] as const)('%s 법의 찬성 %s표가 경계에 맞게 판정된다', (kind, yes, passed) => {
    expect(passesLaw(yes, kind)).toBe(passed);
    expect(vote([group({ promisedVotes: yes })], kind).record).toMatchObject({ yes, passed });
  });

  it('기준을 51표와 67표로 제공하고 잘못된 법 종류·찬성표는 거부한다', () => {
    expect(requiredVotes('normal')).toBe(51);
    expect(requiredVotes('rule')).toBe(67);
    expect(() => requiredVotes('unknown' as LawKind)).toThrow();
    for (const value of [-1, 1.5, 101, NaN, Infinity]) {
      expect(() => passesLaw(value, 'normal')).toThrow();
    }
  });
});

describe('결속도와 약속표', () => {
  it('결속도 0이면 전부 이탈하고 1이면 모든 약속표가 따라온다', () => {
    expect(vote([group({ cohesion: 0 })]).record).toMatchObject({ yes: 0, abstain: 100 });
    expect(vote([group({ cohesion: 1 })]).record).toMatchObject({ yes: 100, abstain: 0 });
  });

  it('약속표 한 표마다 난수를 뽑아 결속도를 적용하고 고정 시드를 재현한다', () => {
    const groups = [group({ cohesion: 0.5, promisedVotes: 6 })];
    const first = vote(groups);
    expect(first).toEqual(vote(groups));
    expect(first.record).toMatchObject({ yes: 2, abstain: 98 });
    let expectedRng = createRng(1);
    for (let index = 0; index < 6; index += 1) expectedRng = nextRandom(expectedRng).rng;
    expect(first.rng).toEqual(expectedRng);
  });

  it('결속도 경계에서도 약속표 수만큼 난수를 소비한다', () => {
    const zero = vote([group({ cohesion: 0, promisedVotes: 12 })]);
    const one = vote([group({ cohesion: 1, promisedVotes: 12 })]);
    expect(zero.rng).toEqual(one.rng);
    expect(zero.record.yes).toBe(0);
    expect(one.record.yes).toBe(12);
  });

  it('약속표는 소수를 내림하고 파견을 뺀 실제 표수를 넘기지 않는다', () => {
    expect(vote([group({ promisedVotes: 51.9 })]).record).toMatchObject({ yes: 51, abstain: 49 });
    const record = vote([group({ promisedVotes: 200.9, present: 25 })]).record;
    expect(record).toMatchObject({ yes: 25, abstain: 0, absent: 75 });
    if (record.mode !== 'public') throw new Error('공개 기록이 필요합니다.');
    expect(record.groups[0]).toMatchObject({ promisedVotes: 25, deliveredVotes: 25 });
  });

  it('반대·기권 약속과 미약속표의 선택을 지원하며 이탈표는 기권한다', () => {
    expect(vote([group({ promisedVotes: 40, choice: 'no', unpromisedChoice: 'yes' })]).record)
      .toMatchObject({ yes: 60, no: 40, abstain: 0 });
    expect(vote([group({ promisedVotes: 40, choice: 'abstain', unpromisedChoice: 'no' })]).record)
      .toMatchObject({ yes: 0, no: 60, abstain: 40 });
    expect(vote([group({ promisedVotes: 40, choice: 'no', cohesion: 0, unpromisedChoice: 'yes' })]).record)
      .toMatchObject({ yes: 60, no: 0, abstain: 40 });
    expect(vote([group({ promisedVotes: 0 })]).record).toMatchObject({ yes: 0, no: 0, abstain: 100 });
  });

  it('저장한 난수 상태로 다음 표결을 이어서 재현한다', () => {
    const groups = [group({ cohesion: 0.62, promisedVotes: 70 })];
    const first = vote(groups);
    const saved = JSON.parse(JSON.stringify(first.rng));
    const next = resolveCouncilVote(groups, { mode: 'public', kind: 'rule', rng: saved });
    const repeated = resolveCouncilVote(groups, { mode: 'public', kind: 'rule', rng: first.rng });
    expect(next).toEqual(repeated);
    expect(next.rng).not.toEqual(first.rng);
  });

  it.each([
    { cohesion: -0.01 }, { cohesion: 1.01 }, { cohesion: NaN }, { cohesion: Infinity },
    { promisedVotes: -1 }, { promisedVotes: NaN }, { promisedVotes: Infinity },
    { present: -1 }, { present: 101 }, { present: 1.1 }, { present: Infinity },
    { choice: 'unknown' }, { unpromisedChoice: 'unknown' }, { leaderId: '' },
  ])('잘못된 표결 입력을 오류로 막는다: %j', overrides => {
    expect(() => vote([group(overrides as Partial<CouncilGroup>)])).toThrow();
  });
});

describe('공개·비밀 투표 기록', () => {
  const groups = [
    group({ id: 'tail', population: 60, present: 60, leaderId: 'tail_leader', promisedVotes: 50, cohesion: 0.7 }),
    group({ id: 'engine', population: 40, present: 30, leaderId: 'engine_leader', promisedVotes: 40, choice: 'no' }),
  ];

  it('공개 기록에 집단·지도자·약속·실제 표 내역을 남기고 집단 합계만 전체에 더한다', () => {
    const result = vote(groups).record;
    if (result.mode !== 'public') throw new Error('공개 기록이 필요합니다.');
    expect(result.groups.map(item => item.groupId)).toEqual(['tail', 'engine']);
    expect(result.leaders.map(item => item.leaderId)).toEqual(['tail_leader', 'engine_leader']);
    expect(result.groups[1]).toMatchObject({
      groupId: 'engine', leaderId: 'engine_leader', choice: 'no',
      seats: 40, availableVotes: 30, promisedVotes: 30, deliveredVotes: 30, no: 30, absent: 10,
    });
    expect(result.leaders[1]).toMatchObject({
      groupId: 'engine', leaderId: 'engine_leader', choice: 'no',
      promisedVotes: 30, deliveredVotes: 30, no: 30,
    });
    for (const key of ['yes', 'no', 'abstain', 'absent'] as const) {
      expect(result[key]).toBe(result.groups.reduce((sum, item) => sum + item[key], 0));
    }
    expect(result.yes + result.no + result.abstain + result.absent).toBe(100);
  });

  it('지도자 표는 집단 표와 중복 집계되지 않는다', () => {
    const result = vote([
      group({ id: 'tail', population: 60, present: 60, leaderId: 'tail_leader' }),
      group({ id: 'engine', population: 40, present: 40, leaderId: 'engine_leader' }),
    ]).record;
    if (result.mode !== 'public') throw new Error('공개 기록이 필요합니다.');
    expect(result.yes).toBe(100);
    expect(result.leaders.reduce((sum, item) => sum + item.yes, 0)).toBe(100);
    expect(result.groups.reduce((sum, item) => sum + item.yes, 0)).toBe(100);
  });

  it('비밀 기록은 정확히 합계와 판정만 남겨 집단·지도자·난수·약속표를 유출하지 않는다', () => {
    const secret = vote(groups, 'normal', 'secret');
    const open = vote(groups);
    expect(Object.keys(secret.record).sort()).toEqual([
      'absent', 'abstain', 'kind', 'mode', 'no', 'passed', 'requiredVotes', 'yes',
    ]);
    for (const key of ['yes', 'no', 'abstain', 'absent', 'kind', 'requiredVotes', 'passed'] as const) {
      expect(secret.record[key]).toEqual(open.record[key]);
    }
    const serialized = JSON.stringify(secret.record);
    for (const word of ['tail', 'engine', 'leader', 'promised', 'delivered', 'cohesion', 'rng', 'state']) {
      expect(serialized).not.toContain(word);
    }
    expect(secret.rng).toEqual(open.rng);
    expect(JSON.parse(serialized)).toEqual(secret.record);
  });

  it('원래 집단·옵션·난수 상태를 수정하지 않는다', () => {
    const input = Object.freeze(groups.map(item => Object.freeze({ ...item })));
    const options = Object.freeze({
      kind: 'normal' as const, mode: 'public' as const, rng: Object.freeze(createRng(1)),
      turnoutPolicy: Object.freeze({ participationRate: 0.8 }),
    });
    const original = JSON.stringify({ input, options });
    const first = resolveCouncilVote(input, options);
    expect(JSON.stringify({ input, options })).toBe(original);
    expect(first).toEqual(resolveCouncilVote(input, options));
    expect(first.rng).not.toBe(options.rng);
  });

  it('중복 지도자와 모르는 투표 방식을 거부한다', () => {
    expect(() => vote([
      group({ id: 'a', leaderId: 'same' }), group({ id: 'b', leaderId: 'same' }),
    ])).toThrow(/중복/);
    expect(() => vote([group()], 'normal', 'unknown' as VoteMode)).toThrow(/투표 방식/);
  });
});

describe('게임 상태에서 의회 집단 만들기', () => {
  function stateWithPeople() {
    return createInitialState({
      persons: [
        { id: 'child', community: 'tail', age: 8 },
        { id: 'worker', community: 'tail', age: 40, state: 'injured' },
        { id: 'scout', community: 'tail', age: 25, state: 'away', awaySegments: 2 },
        { id: 'fallen', community: 'tail', age: 50, state: 'dead' },
        { id: 'recruit', community: 'tail', age: 21 },
        { id: 'captain', community: 'engine', age: 35 },
      ],
      groups: [
        { id: 'tail', members: ['child', 'worker', 'scout', 'fallen'], leaderId: 'worker', votes: 50, cohesion: 0.25 },
        { id: 'union', members: ['recruit', 'captain'], leaderId: 'captain', votes: 40, cohesion: 1 },
      ],
    });
  }

  it('아이·부상자는 포함하고 파견자는 현재 인원에서, 사망자는 전체와 현재 인원에서 뺀다', () => {
    expect(buildCouncilGroups(stateWithPeople())).toEqual([
      { id: 'tail', population: 3, present: 2, leaderId: 'worker', promisedVotes: 50, cohesion: 0.25 },
      { id: 'union', population: 2, present: 2, leaderId: 'captain', promisedVotes: 40, cohesion: 1 },
    ]);
  });

  it('세력원은 명시한 집단에만 들어가며 원래 공동체에 의석을 다시 만들지 않는다', () => {
    const groups = buildCouncilGroups(stateWithPeople());
    expect(groups.map(item => item.id)).toEqual(['tail', 'union']);
    expect(groups.reduce((sum, item) => sum + item.population, 0)).toBe(5);
    expect(allocateSeats(groups).map(item => item.seats)).toEqual([60, 40]);
    const record = vote(groups).record;
    expect(record.absent).toBe(20);
    if (record.mode !== 'public') throw new Error('공개 기록이 필요합니다.');
    expect(record.groups.map(item => item.availableVotes)).toEqual([40, 40]);
  });

  it('기본 다섯 공동체는 유지하며 인구가 없는 상태를 임의로 채우지 않는다', () => {
    const groups = buildCouncilGroups(createInitialState());
    expect(groups.map(item => item.id)).toEqual(['tail', 'engine', 'guard', 'medtech', 'front']);
    expect(groups.every(item => item.population === 0 && item.present === 0)).toBe(true);
    expect(() => vote(groups)).toThrow(/전체 인구/);
  });

  it('상태와 사람·집단 목록을 수정하지 않는다', () => {
    const state = stateWithPeople();
    const original = JSON.stringify(state);
    const result = buildCouncilGroups(state);
    result[0].population = 1000;
    expect(JSON.stringify(state)).toBe(original);
  });

  it('중복 배정되거나 알 수 없는 사람이 있으면 조용히 이중 집계하지 않는다', () => {
    const duplicate = stateWithPeople();
    duplicate.groups.union.members.push('child');
    expect(() => buildCouncilGroups(duplicate)).toThrow(/중복 배정/);
    const missing = stateWithPeople();
    missing.groups.tail.members.push('missing');
    expect(() => buildCouncilGroups(missing)).toThrow(/등록되지 않은 사람/);
    const leader = stateWithPeople();
    leader.groups.tail.leaderId = 'captain';
    expect(() => buildCouncilGroups(leader)).toThrow(/지도자/);
  });
});
