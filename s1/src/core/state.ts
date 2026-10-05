import {
  COMMUNITY_IDS, EFFECT_DEFAULTS, INITIAL_VALUES, PERSON_STATES, STATE_LIMITS,
} from './constants';
import { createRng } from './rng';
import type { RngSeed, RngState } from './rng';
import type { COMMUNITY_METRICS, DEAL_TOOLS, RESOURCE_TYPES } from './constants';

export type CommunityId = typeof COMMUNITY_IDS[number];
export type CommunityMetric = typeof COMMUNITY_METRICS[number];
export type ResourceType = typeof RESOURCE_TYPES[number];
export type PersonStatus = typeof PERSON_STATES[number];
export type DealTool = typeof DEAL_TOOLS[number];
export type FlagValue = boolean | number | string;
export type CommunityState = Record<CommunityMetric, number>;
export type Resources = Record<ResourceType, number>;

export interface PersonState {
  id: string;
  community: CommunityId;
  age?: number;
  state: PersonStatus;
  awaySegments: number;
  // 파견 전 부상을 기억한다. 귀환이 자동 치료가 되지 않게 한다.
  returnState: 'alive' | 'injured';
}

export interface GroupState {
  id: string;
  members: string[];
  leaderId?: string;
  relation: number;
  cohesion: number;
  // 약속한 표의 변화량을 보존한다. 정수화는 표결 시점에 한다.
  votes: number;
}

export interface ScheduledFollowup {
  id: string;
  remainingSegments: number;
}

export interface ActiveDeal {
  id: string;
  from: string;
  tool: DealTool;
  openedAtSegment: number;
  deadlineSegment: number;
}

export interface ActivePromise {
  id: string;
  dealId: string;
  target: string;
  deadlineSegment: number;
}

export interface GameState {
  segment: number;
  rng: RngState;
  communities: Record<CommunityId, CommunityState>;
  trust: number;
  tension: number;
  fear: number;
  resources: Resources;
  symbols: string[];
  secrets: string[];
  // 사용하거나 넘긴 상징물도 획득 이력에 남긴다. 이후 전리품 추첨의 제외 목록이다.
  acquiredSymbols: string[];
  persons: Record<string, PersonState>;
  groups: Record<string, GroupState>;
  flags: Record<string, FlagValue>;
  followups: ScheduledFollowup[];
  deals: ActiveDeal[];
  promises: ActivePromise[];
  chronicle: string[];
}

export interface PersonInput {
  id: string;
  community: CommunityId;
  age?: number;
  state?: PersonStatus;
  awaySegments?: number;
  returnState?: 'alive' | 'injured';
}

export interface GroupInput {
  id: string;
  members: readonly string[];
  leaderId?: string;
  relation?: number;
  cohesion?: number;
  votes?: number;
}

export interface InitialStateOptions {
  seed?: RngSeed;
  segment?: number;
  persons?: readonly PersonInput[];
  // 지정한 집단은 그대로 쓴다. 세력원을 공동체 의석에 다시 더하지 않는다.
  groups?: readonly GroupInput[];
}

export function assertId(value: unknown): asserts value is string {
  if (typeof value !== 'string' || !/^[a-z][a-z0-9_]*$/.test(value)) {
    throw new Error('id는 영문 소문자로 시작하고 소문자·숫자·밑줄만 써야 합니다.');
  }
}

export function assertInRange(value: number, range: { min: number; max: number }, name: string): void {
  if (!Number.isFinite(value) || value < range.min || value > range.max) {
    throw new Error(`${name}: ${range.min} 이상 ${range.max} 이하의 유한한 수가 필요합니다.`);
  }
}

export function assertSegment(value: number): void {
  assertInRange(value, STATE_LIMITS.segment, '구간');
  if (!Number.isSafeInteger(value)) throw new Error('구간은 안전한 정수여야 합니다.');
}

export function createInitialState(options: InitialStateOptions = {}): GameState {
  const segment = options.segment ?? INITIAL_VALUES.segment;
  assertSegment(segment);
  const persons: Record<string, PersonState> = {};
  for (const input of options.persons ?? []) {
    assertId(input.id);
    if (Object.hasOwn(persons, input.id)) throw new Error(`사람 id가 중복됩니다: ${input.id}`);
    if (!COMMUNITY_IDS.includes(input.community)) throw new Error(`모르는 공동체입니다: ${input.community}`);
    const status = input.state ?? INITIAL_VALUES.personState;
    if (!PERSON_STATES.includes(status)) throw new Error(`모르는 사람 상태입니다: ${status}`);
    const awaySegments = input.awaySegments
      ?? (status === 'away' ? EFFECT_DEFAULTS.awaySegments : INITIAL_VALUES.awaySegments);
    assertSegment(awaySegments);
    if ((status === 'away') !== (awaySegments > 0)) {
      throw new Error('파견 중일 때만 양수인 남은 구간 수를 지정해야 합니다.');
    }
    if (input.age !== undefined) {
      assertInRange(input.age, STATE_LIMITS.age, '나이');
      if (!Number.isInteger(input.age)) throw new Error('나이는 정수여야 합니다.');
    }
    const returnState = input.returnState ?? (status === 'injured' ? 'injured' : INITIAL_VALUES.returnState);
    if (returnState !== 'alive' && returnState !== 'injured') throw new Error('귀환 상태가 올바르지 않습니다.');
    persons[input.id] = {
      id: input.id, community: input.community, state: status, awaySegments, returnState,
      ...(input.age === undefined ? {} : { age: input.age }),
    };
  }

  const inputs: readonly GroupInput[] = options.groups ?? COMMUNITY_IDS.map(id => ({
    id, members: Object.values(persons).filter(person => person.community === id).map(person => person.id),
  }));
  const groups: Record<string, GroupState> = {};
  const assigned = new Set<string>();
  for (const input of inputs) {
    assertId(input.id);
    if (Object.hasOwn(groups, input.id)) throw new Error(`집단 id가 중복됩니다: ${input.id}`);
    const members = [...input.members];
    for (const id of members) {
      if (!Object.hasOwn(persons, id)) throw new Error(`집단에 등록되지 않은 사람이 있습니다: ${id}`);
      if (assigned.has(id)) throw new Error(`사람을 의석 집단에 중복 배정할 수 없습니다: ${id}`);
      assigned.add(id);
    }
    if (input.leaderId !== undefined && !members.includes(input.leaderId)) {
      throw new Error(`지도자는 해당 집단의 구성원이어야 합니다: ${input.leaderId}`);
    }
    const relation = input.relation ?? INITIAL_VALUES.relation;
    const cohesion = input.cohesion ?? INITIAL_VALUES.cohesion;
    const votes = input.votes ?? INITIAL_VALUES.votes;
    assertInRange(relation, STATE_LIMITS.relation, '집단 관계');
    assertInRange(cohesion, STATE_LIMITS.cohesion, '결속도');
    assertInRange(votes, STATE_LIMITS.votes, '약속표');
    groups[input.id] = {
      id: input.id, members, relation, cohesion, votes,
      ...(input.leaderId === undefined ? {} : { leaderId: input.leaderId }),
    };
  }

  return {
    segment,
    rng: createRng(options.seed ?? INITIAL_VALUES.seed),
    communities: Object.fromEntries(COMMUNITY_IDS.map(id => [id, { ...INITIAL_VALUES.community }])) as Record<CommunityId, CommunityState>,
    trust: INITIAL_VALUES.trust,
    tension: INITIAL_VALUES.tension,
    fear: INITIAL_VALUES.fear,
    resources: { ...INITIAL_VALUES.resources },
    symbols: [], secrets: [], acquiredSymbols: [], persons, groups, flags: {},
    followups: [], deals: [], promises: [], chronicle: [],
  };
}

export function cloneGameState(state: GameState): GameState {
  return {
    ...state,
    rng: { ...state.rng },
    communities: Object.fromEntries(COMMUNITY_IDS.map(id => [id, { ...state.communities[id] }])) as Record<CommunityId, CommunityState>,
    resources: { ...state.resources },
    symbols: [...state.symbols], secrets: [...state.secrets], acquiredSymbols: [...state.acquiredSymbols],
    persons: Object.fromEntries(Object.entries(state.persons).map(([id, person]) => [id, { ...person }])),
    groups: Object.fromEntries(Object.entries(state.groups).map(([id, group]) => [id, { ...group, members: [...group.members] }])),
    flags: { ...state.flags },
    followups: state.followups.map(item => ({ ...item })),
    deals: state.deals.map(item => ({ ...item })),
    promises: state.promises.map(item => ({ ...item })),
    chronicle: [...state.chronicle],
  };
}
