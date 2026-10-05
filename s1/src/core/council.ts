import { COUNCIL_DEFAULTS } from './constants';
import { nextRandom, restoreRng } from './rng';
import type { RngState } from './rng';
import type { GameState } from './state';

export type LawKind = 'normal' | 'rule';
export type VoteMode = 'public' | 'secret';
export type VoteChoice = 'yes' | 'no' | 'abstain';
export type VoteRounding = 'floor' | 'ceil' | 'round';

export interface PopulationGroup {
  id: string;
  population: number;
}

export interface SeatAllocation extends PopulationGroup {
  seats: number;
}

export interface TurnoutPolicy {
  participationRate: number;
  turnoutRounding: VoteRounding;
}

export interface CouncilGroup extends PopulationGroup {
  present: number;
  cohesion: number;
  promisedVotes: number;
  leaderId?: string;
  /** 거래로 얻은 약속표는 기본적으로 찬성표다. 반대·기권 약속도 지정할 수 있다. */
  choice?: VoteChoice;
  unpromisedChoice?: VoteChoice;
}

export interface VoteCounts {
  yes: number;
  no: number;
  abstain: number;
}

export interface VoteTotals extends VoteCounts {
  absent: number;
}

export interface GroupVoteRecord extends VoteTotals {
  groupId: string;
  leaderId?: string;
  seats: number;
  availableVotes: number;
  choice: VoteChoice;
  promisedVotes: number;
  deliveredVotes: number;
  defectorVotes: number;
  defectorChoice: VoteChoice;
  unpromisedVotes: number;
  unpromisedChoice: VoteChoice;
}

/** 지도자가 약속한 표 묶음의 내역이다. 집단 기록에 이미 포함되어 있으므로 다시 더하지 않는다. */
export interface LeaderVoteRecord extends VoteCounts {
  groupId: string;
  leaderId: string;
  choice: VoteChoice;
  promisedVotes: number;
  deliveredVotes: number;
  defectorVotes: number;
  defectorChoice: VoteChoice;
}

interface VoteSummary extends VoteTotals {
  kind: LawKind;
  requiredVotes: number;
  passed: boolean;
}

export interface PublicVoteRecord extends VoteSummary {
  mode: 'public';
  groups: GroupVoteRecord[];
  leaders: LeaderVoteRecord[];
}

export interface SecretVoteRecord extends VoteSummary {
  mode: 'secret';
}

export type CouncilVoteRecord = PublicVoteRecord | SecretVoteRecord;

export interface CouncilVoteOptions {
  kind: LawKind;
  mode: VoteMode;
  rng: RngState;
  turnoutPolicy?: Partial<TurnoutPolicy>;
}

export interface CouncilVoteResult {
  record: CouncilVoteRecord;
  rng: RngState;
}

function assertCount(value: number, name: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new RangeError(`${name}은 0 이상의 안전한 정수여야 합니다.`);
  }
}

function assertNonemptyId(value: string, name: string): void {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new TypeError(`${name}는 빈 문자열일 수 없습니다.`);
  }
}

function compareId(first: string, second: string): number {
  return first < second ? -1 : first > second ? 1 : 0;
}

function assertUnitInterval(value: number, name: string): void {
  if (!Number.isFinite(value) || value < 0 || value > 1) {
    throw new RangeError(`${name}는 0 이상 1 이하의 유한한 수여야 합니다.`);
  }
}

function assertChoice(value: VoteChoice): void {
  if (value !== 'yes' && value !== 'no' && value !== 'abstain') {
    throw new TypeError(`모르는 투표 선택입니다: ${value}`);
  }
}

function assertRounding(value: VoteRounding): void {
  if (value !== 'floor' && value !== 'ceil' && value !== 'round') {
    throw new TypeError(`모르는 표 반올림 방식입니다: ${value}`);
  }
}

/**
 * 인구의 최대 잔여법으로 100석을 배분한다. 아이와 세력원의 소속은 호출자가
 * 정한 집단 목록에 반영되어 있어야 한다. 잔여는 인구 큰 순, id 사전순으로 푼다.
 * 정수 분자·분모를 쓰므로 개별 인구나 총인구가 클 때도 잔여 비교가 정확하다.
 * 결과 순서는 입력 순서이며, 빈 집단 목록과 총인구 0은 오류다.
 */
export function allocateSeats(groups: readonly PopulationGroup[]): SeatAllocation[] {
  if (groups.length === 0) throw new RangeError('의석을 배분할 집단이 없습니다.');
  const ids = new Set<string>();
  let totalPopulation = 0n;
  for (const group of groups) {
    assertNonemptyId(group.id, '집단 id');
    if (ids.has(group.id)) throw new Error(`집단 id가 중복됩니다: ${group.id}`);
    ids.add(group.id);
    assertCount(group.population, '집단 인구');
    totalPopulation += BigInt(group.population);
  }
  if (totalPopulation === 0n) throw new RangeError('전체 인구가 0이면 의석을 배분할 수 없습니다.');

  const allocations = groups.map(group => {
    const numerator = BigInt(group.population) * BigInt(COUNCIL_DEFAULTS.totalSeats);
    return {
      id: group.id,
      population: group.population,
      seats: Number(numerator / totalPopulation),
      remainder: numerator % totalPopulation,
    };
  });
  const remaining = COUNCIL_DEFAULTS.totalSeats - allocations.reduce((sum, group) => sum + group.seats, 0);
  const ranked = [...allocations].sort((first, second) => {
    if (first.remainder !== second.remainder) return first.remainder > second.remainder ? -1 : 1;
    if (first.population !== second.population) return first.population > second.population ? -1 : 1;
    return compareId(first.id, second.id);
  });
  for (let index = 0; index < remaining; index += 1) ranked[index].seats += 1;
  return allocations.map(({ id, population, seats }) => ({ id, population, seats }));
}

/** 입력한 참여비율의 십진 표기를 분수로 바꾸어 정수 경계에서의 오차를 피한다. */
function rateFraction(rate: number): { numerator: bigint; denominator: bigint } {
  const [mantissa, exponent = '0'] = rate.toString().split('e');
  const [whole, fraction = ''] = mantissa.split('.');
  const numerator = BigInt(whole + fraction);
  const scale = fraction.length - Number(exponent);
  return scale >= 0
    ? { numerator, denominator: 10n ** BigInt(scale) }
    : { numerator: numerator * 10n ** BigInt(-scale), denominator: 1n };
}

function roundRatio(numerator: bigint, denominator: bigint, rounding: VoteRounding): number {
  const quotient = numerator / denominator;
  const remainder = numerator % denominator;
  const roundUp = rounding === 'ceil' ? remainder > 0n : rounding === 'round' && remainder * 2n >= denominator;
  return Number(quotient + (roundUp ? 1n : 0n));
}

/**
 * 실제 표 = 의석 × 현재 인원 / 전체 인원 × 참여비율. 기본값은 참여비율 1과 내림이다.
 * 부재로 비는 표는 다른 집단에 넘기지 않는다. 인구가 0인 집단은 실제 표도 0이다.
 */
export function calculateAvailableVotes(
  seats: number,
  population: number,
  present: number,
  policy: Partial<TurnoutPolicy> = {},
): number {
  assertCount(seats, '의석');
  if (seats > COUNCIL_DEFAULTS.totalSeats) throw new RangeError('집단 의석은 전체 의석을 넘을 수 없습니다.');
  assertCount(population, '전체 인원');
  assertCount(present, '현재 인원');
  if (present > population) throw new RangeError('현재 인원은 전체 인원을 넘을 수 없습니다.');
  const rate = policy.participationRate ?? COUNCIL_DEFAULTS.participationRate;
  const rounding = policy.turnoutRounding ?? COUNCIL_DEFAULTS.turnoutRounding;
  assertUnitInterval(rate, '참여비율');
  assertRounding(rounding);
  if (population === 0) return 0;
  const { numerator, denominator } = rateFraction(rate);
  return roundRatio(
    BigInt(seats) * BigInt(present) * numerator,
    BigInt(population) * denominator,
    rounding,
  );
}

export function requiredVotes(kind: LawKind): number {
  if (kind !== 'normal' && kind !== 'rule') throw new TypeError(`모르는 법 종류입니다: ${kind}`);
  return COUNCIL_DEFAULTS.thresholds[kind];
}

/** 부재와 기권이 있어도 일반 법 51표, 통치 법 67표의 고정 기준은 낮아지지 않는다. */
export function passesLaw(yesVotes: number, kind: LawKind): boolean {
  assertCount(yesVotes, '찬성표');
  if (yesVotes > COUNCIL_DEFAULTS.totalSeats) throw new RangeError('찬성표는 전체 의석을 넘을 수 없습니다.');
  return yesVotes >= requiredVotes(kind);
}

function validateGroup(group: CouncilGroup): void {
  assertCount(group.present, '현재 인원');
  if (group.present > group.population) throw new RangeError('현재 인원은 전체 인원을 넘을 수 없습니다.');
  assertUnitInterval(group.cohesion, '결속도');
  if (!Number.isFinite(group.promisedVotes) || group.promisedVotes < 0) {
    throw new RangeError('약속표는 0 이상의 유한한 수여야 합니다.');
  }
  if (group.leaderId !== undefined) assertNonemptyId(group.leaderId, '지도자 id');
  if (group.choice !== undefined) assertChoice(group.choice);
  if (group.unpromisedChoice !== undefined) assertChoice(group.unpromisedChoice);
}

/**
 * 상태에 등록된 의석 집단을 그대로 읽는다. 아이·부상자는 인구와 현재 인원에,
 * 파견자는 인구에만 포함하고 사망자는 양쪽에서 뺀다. 세력원을 공동체에 다시 넣지 않는다.
 * 지도자의 파견에 따른 결속도 변화는 별도 효과로 적용하며 여기서 임의로 바꾸지 않는다.
 */
export function buildCouncilGroups(state: GameState): CouncilGroup[] {
  const assigned = new Set<string>();
  const ids = new Set<string>();
  return Object.values(state.groups).map(group => {
    assertNonemptyId(group.id, '집단 id');
    if (ids.has(group.id)) throw new Error(`집단 id가 중복됩니다: ${group.id}`);
    ids.add(group.id);
    let population = 0;
    let present = 0;
    for (const id of group.members) {
      if (assigned.has(id)) throw new Error(`사람을 의석 집단에 중복 배정할 수 없습니다: ${id}`);
      if (!Object.hasOwn(state.persons, id)) throw new Error(`집단에 등록되지 않은 사람이 있습니다: ${id}`);
      assigned.add(id);
      const person = state.persons[id];
      switch (person.state) {
        case 'alive':
        case 'injured':
          population += 1;
          present += 1;
          break;
        case 'away':
          population += 1;
          break;
        case 'dead':
          break;
        default:
          throw new TypeError(`모르는 사람 상태입니다: ${person.state}`);
      }
    }
    if (group.leaderId !== undefined && !group.members.includes(group.leaderId)) {
      throw new Error(`지도자는 해당 집단의 구성원이어야 합니다: ${group.leaderId}`);
    }
    const result: CouncilGroup = {
      id: group.id, population, present, cohesion: group.cohesion, promisedVotes: group.votes,
      ...(group.leaderId === undefined ? {} : { leaderId: group.leaderId }),
    };
    validateGroup(result);
    return result;
  });
}

/**
 * 약속표 한 표마다 결속도를 성공 확률로 난수를 한 번 뽑는다. 0과 1도 같은 수의
 * 난수를 소비한다. 소수 약속표는 상수의 방식으로 정수화하고 실제 표수를 넘기지 않는다.
 * 이탈표와 미약속표의 기본은 기권이며, 미약속표의 선택은 집단별로 바꿀 수 있다.
 * 입력 집단 순서대로 난수를 소비한다. 같은 입력과 저장한 난수 상태로 결과를 재현한다.
 * 공개 기록의 지도자 내역은 집단 내역의 일부다. 비밀 기록은 합계만 새로 만들고,
 * 이어 쓸 난수 상태는 기록 바깥에 돌려준다.
 */
export function resolveCouncilVote(
  groups: readonly CouncilGroup[],
  options: CouncilVoteOptions,
): CouncilVoteResult {
  const threshold = requiredVotes(options.kind);
  if (options.mode !== 'public' && options.mode !== 'secret') {
    throw new TypeError(`모르는 투표 방식입니다: ${options.mode}`);
  }
  let rng = restoreRng(options.rng);
  const allocations = allocateSeats(groups);
  const leaderIds = new Set<string>();
  for (const group of groups) {
    validateGroup(group);
    if (group.leaderId !== undefined) {
      if (leaderIds.has(group.leaderId)) throw new Error(`지도자 id가 중복됩니다: ${group.leaderId}`);
      leaderIds.add(group.leaderId);
    }
  }
  const groupRecords: GroupVoteRecord[] = [];
  const leaderRecords: LeaderVoteRecord[] = [];
  const totals: VoteTotals = { yes: 0, no: 0, abstain: 0, absent: 0 };
  for (let index = 0; index < groups.length; index += 1) {
    const group = groups[index];
    const seats = allocations[index].seats;
    const availableVotes = calculateAvailableVotes(seats, group.population, group.present, options.turnoutPolicy);
    const promisedVotes = Math.min(availableVotes, Math[COUNCIL_DEFAULTS.promisedVotesRounding](group.promisedVotes));
    const choice = group.choice ?? 'yes';
    const defectorChoice: VoteChoice = COUNCIL_DEFAULTS.defectorChoice;
    const unpromisedChoice = group.unpromisedChoice ?? COUNCIL_DEFAULTS.unpromisedChoice;
    let deliveredVotes = 0;
    for (let vote = 0; vote < promisedVotes; vote += 1) {
      const next = nextRandom(rng);
      rng = next.rng;
      if (next.value < group.cohesion) deliveredVotes += 1;
    }
    const defectorVotes = promisedVotes - deliveredVotes;
    const unpromisedVotes = availableVotes - promisedVotes;
    const promisedCounts: VoteCounts = { yes: 0, no: 0, abstain: 0 };
    promisedCounts[choice] += deliveredVotes;
    promisedCounts[defectorChoice] += defectorVotes;
    const counts: VoteTotals = { ...promisedCounts, absent: seats - availableVotes };
    counts[unpromisedChoice] += unpromisedVotes;
    totals.yes += counts.yes;
    totals.no += counts.no;
    totals.abstain += counts.abstain;
    totals.absent += counts.absent;
    if (options.mode === 'public') {
      groupRecords.push({
        ...counts, groupId: group.id, seats, availableVotes, choice, promisedVotes, deliveredVotes,
        defectorVotes, defectorChoice, unpromisedVotes, unpromisedChoice,
        ...(group.leaderId === undefined ? {} : { leaderId: group.leaderId }),
      });
      if (group.leaderId !== undefined) {
        leaderRecords.push({
          ...promisedCounts, groupId: group.id, leaderId: group.leaderId, choice,
          promisedVotes, deliveredVotes, defectorVotes, defectorChoice,
        });
      }
    }
  }
  const summary: VoteSummary = {
    ...totals, kind: options.kind, requiredVotes: threshold, passed: totals.yes >= threshold,
  };
  const record: CouncilVoteRecord = options.mode === 'public'
    ? { ...summary, mode: 'public', groups: groupRecords, leaders: leaderRecords }
    : { ...summary, mode: 'secret' };
  return { record, rng };
}
