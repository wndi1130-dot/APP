import {
  COMMUNITY_IDS, COMMUNITY_METRICS, DEAL_TOOLS, EFFECT_DEFAULTS, PERSON_STATES,
  STATE_LIMITS,
} from './constants';
import { assertId, cloneGameState } from './state';
import type {
  CommunityId, CommunityMetric, DealTool, FlagValue, GameState, GroupState,
  PersonState, PersonStatus, ResourceType,
} from './state';

export type Effect =
  | { type: ResourceType; amount: number }
  | { type: 'symbol' | 'secret'; id: string; amount: number }
  | { type: `community.${CommunityMetric}`; target: CommunityId; amount: number }
  | { type: 'trust' | 'tension' | 'fear'; amount: number }
  | { type: 'relation' | 'cohesion' | 'votes'; target: string; amount: number }
  | { type: 'person.state'; target: string; state: PersonStatus }
  | { type: 'person.away'; target: string; segments: number }
  | { type: 'flag'; id: string; value: FlagValue }
  | { type: 'followup'; id: string; delay: number }
  | { type: 'deal' | 'chronicle'; id: string };

export type ConditionOperator = 'lt' | 'lte' | 'eq' | 'gte' | 'gt';

export type Condition =
  | { type: 'segment'; min: number; max: number }
  | {
    type: 'community'; community: CommunityId; metric: CommunityMetric;
    operator: ConditionOperator; value: number;
  }
  | { type: 'flag'; id: string; value: FlagValue }
  | { type: 'person'; id: string; state: PersonStatus }
  | { type: 'resource'; resource: 'coal' | 'food' | 'medicine' | 'luxury' | 'symbol'; operator: 'lte' | 'gte'; value: number };

// 효과에는 거래 id만 들어간다. 실행에 필요한 정의는 호출자가 주입한다.
export interface EffectDealDefinition {
  id: string;
  tool: DealTool;
  from: string;
  deadline: number;
  ask?: readonly Effect[];
  gives?: readonly Effect[];
  breach?: readonly Effect[];
  arc_tags?: readonly string[];
  content_type?: 'deal';
}

export interface EffectContext {
  deals?: Readonly<Record<string, EffectDealDefinition>>;
}

const CONDITION_OPERATORS: readonly ConditionOperator[] = ['lt', 'lte', 'eq', 'gte', 'gt'];

function objectValue(value: unknown, name: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError(name + '은 객체여야 합니다.');
  }
  return value as Record<string, unknown>;
}

function exactFields(value: Record<string, unknown>, fields: readonly string[]): void {
  for (const field of fields) {
    if (!Object.hasOwn(value, field)) throw new TypeError('필수 인자가 없습니다: ' + field);
  }
  for (const field of Object.keys(value)) {
    if (!fields.includes(field)) throw new TypeError('허용하지 않는 인자입니다: ' + field);
  }
}

function finiteNumber(value: unknown, name: string): asserts value is number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new TypeError(name + '은 유한한 수여야 합니다.');
  }
}

function integer(value: unknown, name: string, nonnegative = false): asserts value is number {
  finiteNumber(value, name);
  if (!Number.isInteger(value) || (nonnegative && value < 0)) {
    throw new TypeError(name + (nonnegative ? '은 0 이상의 정수여야 합니다.' : '은 정수여야 합니다.'));
  }
}

function flagValue(value: unknown): asserts value is FlagValue {
  if (typeof value === 'number') {
    finiteNumber(value, '플래그 값');
  } else if (typeof value !== 'boolean' && typeof value !== 'string') {
    throw new TypeError('플래그 값은 참·거짓, 수 또는 문자열이어야 합니다.');
  }
}

function personStatus(value: unknown): asserts value is PersonStatus {
  if (typeof value !== 'string' || !PERSON_STATES.includes(value as PersonStatus)) {
    throw new TypeError('모르는 사람 상태입니다: ' + String(value));
  }
}

function communityId(value: unknown): asserts value is CommunityId {
  if (typeof value !== 'string' || !COMMUNITY_IDS.includes(value as CommunityId)) {
    throw new TypeError('모르는 공동체입니다: ' + String(value));
  }
}

function validateEffect(value: unknown): asserts value is Effect {
  const effect = objectValue(value, '효과');
  switch (effect.type) {
    case 'coal': case 'food': case 'medicine': case 'luxury':
    case 'trust': case 'tension': case 'fear':
      exactFields(effect, ['type', 'amount']);
      finiteNumber(effect.amount, '변화량');
      return;
    case 'symbol': case 'secret':
      exactFields(effect, ['type', 'id', 'amount']);
      assertId(effect.id);
      integer(effect.amount, '변화량');
      return;
    case 'community.warmth': case 'community.ration':
    case 'community.crowding': case 'community.exposure':
      exactFields(effect, ['type', 'target', 'amount']);
      communityId(effect.target);
      finiteNumber(effect.amount, '변화량');
      return;
    case 'relation': case 'cohesion': case 'votes':
      exactFields(effect, ['type', 'target', 'amount']);
      assertId(effect.target);
      finiteNumber(effect.amount, '변화량');
      return;
    case 'person.state':
      exactFields(effect, ['type', 'target', 'state']);
      assertId(effect.target);
      personStatus(effect.state);
      return;
    case 'person.away':
      exactFields(effect, ['type', 'target', 'segments']);
      assertId(effect.target);
      integer(effect.segments, '파견 구간 수', true);
      return;
    case 'flag':
      exactFields(effect, ['type', 'id', 'value']);
      assertId(effect.id);
      flagValue(effect.value);
      return;
    case 'followup':
      exactFields(effect, ['type', 'id', 'delay']);
      assertId(effect.id);
      integer(effect.delay, '후속 사건 대기 구간 수', true);
      return;
    case 'deal': case 'chronicle':
      exactFields(effect, ['type', 'id']);
      assertId(effect.id);
      return;
    default:
      throw new TypeError('모르는 효과 type입니다: ' + String(effect.type));
  }
}

function validateCondition(value: unknown): asserts value is Condition {
  const condition = objectValue(value, '조건');
  switch (condition.type) {
    case 'segment':
      exactFields(condition, ['type', 'min', 'max']);
      integer(condition.min, '구간 범위의 최솟값', true);
      integer(condition.max, '구간 범위의 최댓값', true);
      if (condition.min > condition.max) throw new RangeError('구간 범위가 뒤집혔습니다.');
      return;
    case 'community':
      exactFields(condition, ['type', 'community', 'metric', 'operator', 'value']);
      communityId(condition.community);
      if (typeof condition.metric !== 'string'
        || !COMMUNITY_METRICS.includes(condition.metric as CommunityMetric)) {
        throw new TypeError('모르는 공동체 수치입니다: ' + String(condition.metric));
      }
      if (typeof condition.operator !== 'string'
        || !CONDITION_OPERATORS.includes(condition.operator as ConditionOperator)) {
        throw new TypeError('모르는 비교 연산자입니다: ' + String(condition.operator));
      }
      finiteNumber(condition.value, '조건 비교값');
      return;
    case 'flag':
      exactFields(condition, ['type', 'id', 'value']);
      assertId(condition.id);
      flagValue(condition.value);
      return;
    case 'person':
      exactFields(condition, ['type', 'id', 'state']);
      assertId(condition.id);
      personStatus(condition.state);
      return;
    case 'resource':
      exactFields(condition, ['type', 'resource', 'operator', 'value']);
      if (typeof condition.resource !== 'string' || !['coal', 'food', 'medicine', 'luxury', 'symbol'].includes(condition.resource)) {
        throw new TypeError('모르는 자원입니다: ' + String(condition.resource));
      }
      if (condition.operator !== 'lte' && condition.operator !== 'gte') throw new TypeError('모르는 비교 연산자입니다: ' + String(condition.operator));
      finiteNumber(condition.value, '조건 비교값');
      return;
    default:
      throw new TypeError('모르는 조건 type입니다: ' + String(condition.type));
  }
}

function clamp(value: number, limits: { min: number; max: number }): number {
  return Math.min(limits.max, Math.max(limits.min, value));
}

function groupFor(state: GameState, id: string): GroupState {
  if (!Object.hasOwn(state.groups, id)) throw new Error('효과 대상 집단이 없습니다: ' + id);
  return state.groups[id];
}

function personFor(state: GameState, id: string): PersonState {
  if (!Object.hasOwn(state.persons, id)) throw new Error('효과 대상 사람이 없습니다: ' + id);
  return state.persons[id];
}

function changeInventory(items: string[], id: string, amount: number): string[] {
  if (amount > 0) return items.includes(id) ? items : [...items, id];
  if (amount < 0) return items.filter(item => item !== id);
  return items;
}

function dispatch(person: PersonState, segments: number): void {
  if (segments === 0) {
    if (person.state === 'away') {
      person.state = person.returnState;
      person.awaySegments = 0;
    }
    return;
  }
  if (person.state === 'dead') throw new Error('사망한 사람을 파견할 수 없습니다: ' + person.id);
  if (person.state !== 'away') person.returnState = person.state;
  person.state = 'away';
  person.awaySegments = clamp(segments, STATE_LIMITS.segment);
}

function publicPromiseTarget(state: GameState, from: string): string {
  const targets = new Set<string>();
  if (Object.hasOwn(state.groups, from)) targets.add(from);
  for (const group of Object.values(state.groups)) {
    if (group.leaderId === from) targets.add(group.id);
  }
  if (targets.size !== 1) {
    throw new Error('공개 거래를 제시한 집단을 하나로 정할 수 없습니다: ' + from);
  }
  if (!Object.hasOwn(state.groups, from)) personFor(state, from);
  return [...targets][0];
}

function openDeal(state: GameState, id: string, context?: EffectContext): void {
  const definitions = context?.deals;
  if (!definitions || !Object.hasOwn(definitions, id)) {
    throw new Error('거래 정의가 없습니다: ' + id);
  }
  const definition = objectValue(definitions[id], '거래 정의');
  assertId(definition.id);
  assertId(definition.from);
  if (definition.id !== id) throw new Error('거래 정의의 id가 참조와 다릅니다: ' + id);
  if (typeof definition.tool !== 'string' || !DEAL_TOOLS.includes(definition.tool as DealTool)) {
    throw new Error('모르는 거래 수단입니다: ' + String(definition.tool));
  }
  integer(definition.deadline, '거래 기한', true);
  const tool = definition.tool as DealTool;
  if (state.deals.some(deal => deal.id === id)) {
    throw new Error('이미 진행 중인 거래입니다: ' + id);
  }
  let promiseTarget = definition.from;
  if (tool === 'open') {
    promiseTarget = publicPromiseTarget(state, definition.from);
    const pending = state.promises.filter(promise => promise.target === promiseTarget
      && state.deals.some(deal => deal.id === promise.dealId && deal.tool === 'open')).length;
    if (pending >= EFFECT_DEFAULTS.maxOpenPromisesPerGroup) {
      throw new Error('이 집단에는 미이행 공개 약속이 이미 있습니다: ' + promiseTarget);
    }
  } else if (!Object.hasOwn(state.groups, definition.from)
    && !Object.hasOwn(state.persons, definition.from)) {
    throw new Error('거래를 제시한 사람이나 집단이 없습니다: ' + definition.from);
  }
  // 기한은 개시 뒤 구간 수다. 구간 범위 밖으로 넘치면 상한에 고정한다.
  const deadlineSegment = clamp(state.segment + definition.deadline, STATE_LIMITS.segment);
  state.deals.push({
    id, from: definition.from, tool, openedAtSegment: state.segment, deadlineSegment,
  });
  if (tool === 'open' || tool === 'fetch' || tool === 'favor') {
    state.promises.push({ id, dealId: id, target: promiseTarget, deadlineSegment });
  }
}

function applyValidatedEffect(state: GameState, effect: Effect, context?: EffectContext): void {
  switch (effect.type) {
    case 'coal': case 'food': case 'medicine': case 'luxury':
      state.resources[effect.type] = clamp(state.resources[effect.type] + effect.amount, STATE_LIMITS.resource);
      return;
    case 'symbol': case 'secret': {
      const key = effect.type === 'symbol' ? 'symbols' : 'secrets';
      state[key] = changeInventory(state[key], effect.id, effect.amount);
      if (effect.type === 'symbol' && effect.amount > 0
        && !state.acquiredSymbols.includes(effect.id)) state.acquiredSymbols.push(effect.id);
      return;
    }
    case 'community.warmth': case 'community.ration':
    case 'community.crowding': case 'community.exposure': {
      const metric = effect.type.slice('community.'.length) as CommunityMetric;
      const community = state.communities[effect.target];
      community[metric] = clamp(community[metric] + effect.amount, STATE_LIMITS.metric);
      return;
    }
    case 'trust': case 'tension': case 'fear':
      state[effect.type] = clamp(state[effect.type] + effect.amount, STATE_LIMITS.metric);
      return;
    case 'relation': case 'cohesion': case 'votes': {
      const group = groupFor(state, effect.target);
      group[effect.type] = clamp(group[effect.type] + effect.amount, STATE_LIMITS[effect.type]);
      return;
    }
    case 'person.state': {
      const person = personFor(state, effect.target);
      if (effect.state === 'away') {
        dispatch(person, person.state === 'away' ? person.awaySegments : EFFECT_DEFAULTS.awaySegments);
      } else {
        // 명시적 상태 지정은 사망 이후에도 허용한다. 귀환 효과가 자동 부활시키지는 않는다.
        person.state = effect.state;
        person.awaySegments = 0;
        if (effect.state !== 'dead') person.returnState = effect.state;
      }
      return;
    }
    case 'person.away':
      dispatch(personFor(state, effect.target), effect.segments);
      return;
    case 'flag':
      state.flags[effect.id] = effect.value;
      return;
    case 'followup':
      state.followups.push({ id: effect.id, remainingSegments: clamp(effect.delay, STATE_LIMITS.segment) });
      return;
    case 'deal':
      openDeal(state, effect.id, context);
      return;
    case 'chronicle':
      state.chronicle.push(effect.id);
  }
}

/** 원본의 중첩 객체와 배열을 공유하지 않는 새 상태에 효과를 적용한다. */
export function applyEffect(state: GameState, effect: Effect, context?: EffectContext): GameState {
  return applyEffects(state, [effect], context);
}

/** 목록 전체가 실패하더라도 호출자가 넘긴 원본은 그대로 보존한다. */
export function applyEffects(
  state: GameState,
  effects: readonly Effect[],
  context?: EffectContext,
): GameState {
  if (!Array.isArray(effects)) throw new TypeError('효과 목록은 배열이어야 합니다.');
  for (const effect of effects) validateEffect(effect);
  const next = cloneGameState(state);
  for (const effect of effects) applyValidatedEffect(next, effect, context);
  return next;
}

function evaluateValidatedCondition(state: GameState, condition: Condition): boolean {
  switch (condition.type) {
    case 'segment':
      return state.segment >= condition.min && state.segment <= condition.max;
    case 'community': {
      const actual = state.communities[condition.community][condition.metric];
      switch (condition.operator) {
        case 'lt': return actual < condition.value;
        case 'lte': return actual <= condition.value;
        case 'eq': return actual === condition.value;
        case 'gte': return actual >= condition.value;
        case 'gt': return actual > condition.value;
      }
      break;
    }
    case 'flag':
      return Object.hasOwn(state.flags, condition.id) && state.flags[condition.id] === condition.value;
    case 'person':
      return Object.hasOwn(state.persons, condition.id) && state.persons[condition.id].state === condition.state;
    case 'resource': {
      const actual = condition.resource === 'symbol' ? state.symbols.length : state.resources[condition.resource];
      return condition.operator === 'lte' ? actual <= condition.value : actual >= condition.value;
    }
  }
  throw new TypeError('평가할 수 없는 조건입니다.');
}

export function evaluateCondition(state: GameState, condition: Condition): boolean {
  validateCondition(condition);
  return evaluateValidatedCondition(state, condition);
}

/** 빈 목록은 참이다. 거짓 조건 뒤의 잘못된 조건도 검사에서 걸러낸다. */
export function evaluateConditions(state: GameState, conditions: readonly Condition[]): boolean {
  if (!Array.isArray(conditions)) throw new TypeError('조건 목록은 배열이어야 합니다.');
  for (const condition of conditions) validateCondition(condition);
  return conditions.every(condition => evaluateValidatedCondition(state, condition));
}
