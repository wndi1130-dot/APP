import {
  COUNCIL_DEFAULTS, allocateSeats, buildCouncilGroups, calculateAvailableVotes, requiredVotes, resolveCouncilVote,
} from '../../core';
import type {
  CouncilGroup, CouncilVoteRecord, GameState, GroupVoteRecord, LawKind, RngState, VoteChoice, VoteMode,
} from '../../core';
import { GROUP_META, orderedGroupIds } from './groups';
import type { DummyBill } from './dummy';

// 의회 화면의 계산. 의석 배분과 표결은 A2(core/council.ts)를 그대로 쓰고, 여기선 화면에 맞게 묶기만 한다.

export interface GroupProjection {
  id: string;
  population: number;
  present: number;
  seats: number;
  /** 열차에 남은 인원 비율로 줄어든 실제 표. */
  available: number;
  /** 파견 등으로 빠진 표. */
  absent: number;
  promised: number;
  cohesion: number;
  leaderId?: string;
  /** 약속하지 않은 표의 입장. */
  stance: VoteChoice;
  yes: number;
  no: number;
  undecided: number;
}

export interface ProjectionTotals {
  yes: number;
  no: number;
  undecided: number;
  absent: number;
}

export interface CouncilProjection {
  kind: LawKind;
  required: number;
  groups: GroupProjection[];
  totals: ProjectionTotals;
}

/** 상태의 의석 집단을 반원 순서(열차 뒤 → 앞, 세력은 끝)로 세우고 더미 안건의 약속표와 입장을 얹는다. */
export function councilInputs(game: GameState, bill: DummyBill): CouncilGroup[] {
  const built = buildCouncilGroups(game);
  const byId = new Map(built.map(group => [group.id, group]));
  const ordered = orderedGroupIds(byId.keys());
  if (ordered.length !== built.length) {
    const unknown = built.map(group => group.id).filter(id => !Object.hasOwn(GROUP_META, id));
    throw new Error(`화면이 모르는 의석 집단이 있습니다: ${unknown.join(', ')}`);
  }
  return ordered.map(id => {
    const group = byId.get(id) as CouncilGroup;
    return {
      ...group,
      promisedVotes: bill.promised[id] ?? group.promisedVotes,
      choice: 'yes' as const,
      unpromisedChoice: bill.stance[id] ?? COUNCIL_DEFAULTS.unpromisedChoice,
    };
  });
}

/** 표결 전 예상. 약속표는 찬성으로 세고, 결속도에 따른 이탈은 표결에서 정해진다. */
export function projectCouncil(inputs: readonly CouncilGroup[], kind: LawKind): CouncilProjection {
  const allocations = allocateSeats(inputs);
  const groups = inputs.map((group, index): GroupProjection => {
    const seats = allocations[index].seats;
    const available = calculateAvailableVotes(seats, group.population, group.present);
    const promised = Math.min(available, Math[COUNCIL_DEFAULTS.promisedVotesRounding](group.promisedVotes));
    const unpromised = available - promised;
    const choice = group.choice ?? 'yes';
    const stance = group.unpromisedChoice ?? COUNCIL_DEFAULTS.unpromisedChoice;
    const counts = { yes: 0, no: 0, undecided: 0 };
    const bucket = (value: VoteChoice) => (value === 'abstain' ? 'undecided' : value);
    counts[bucket(choice)] += promised;
    counts[bucket(stance)] += unpromised;
    return {
      id: group.id, population: group.population, present: group.present, seats, available,
      absent: seats - available, promised, cohesion: group.cohesion, stance, ...counts,
      ...(group.leaderId === undefined ? {} : { leaderId: group.leaderId }),
    };
  });
  const totals = groups.reduce<ProjectionTotals>((acc, group) => ({
    yes: acc.yes + group.yes,
    no: acc.no + group.no,
    undecided: acc.undecided + group.undecided,
    absent: acc.absent + group.absent,
  }), { yes: 0, no: 0, undecided: 0, absent: 0 });
  return { kind, required: requiredVotes(kind), groups, totals };
}

export function runCouncilVote(
  inputs: readonly CouncilGroup[],
  kind: LawKind,
  mode: VoteMode,
  rng: RngState,
): { record: CouncilVoteRecord; rng: RngState } {
  return resolveCouncilVote(inputs, { kind, mode, rng });
}

export type SeatMark = 'yes' | 'undecided' | 'abstain' | 'unknown' | 'no' | 'absent';
export type MarkCounts = Partial<Record<SeatMark, number>>;

/** 한 쐐기 안의 표시 순서: 찬성 → 미정·기권·비공개 → 반대 → 부재. */
export const MARK_ORDER: readonly SeatMark[] = Object.freeze(['yes', 'undecided', 'abstain', 'unknown', 'no', 'absent']);

export function marksForGroup(counts: MarkCounts, seats: number): SeatMark[] {
  const marks: SeatMark[] = [];
  for (const mark of MARK_ORDER) {
    const count = counts[mark] ?? 0;
    if (!Number.isSafeInteger(count) || count < 0) throw new RangeError(`표시 수가 올바르지 않습니다: ${mark}`);
    for (let index = 0; index < count; index += 1) marks.push(mark);
  }
  if (marks.length !== seats) throw new RangeError(`표시 수의 합(${marks.length})이 의석(${seats})과 다릅니다.`);
  return marks;
}

/** 표결 전: 집단마다 찬성·미정·반대·부재. */
export function projectionMarks(projection: CouncilProjection): SeatMark[] {
  return projection.groups.flatMap(group => marksForGroup(
    { yes: group.yes, undecided: group.undecided, no: group.no, absent: group.absent }, group.seats,
  ));
}

/**
 * 표결 뒤. 공개 투표는 집단 기록대로 찍고, 비밀 투표는 집단별 표가 없어서
 * 출석 여부(부재는 표결 전에도 알려진 값)만 찍는다.
 */
export function recordMarks(record: CouncilVoteRecord, projection: CouncilProjection): SeatMark[] {
  if (record.mode === 'public') {
    return record.groups.flatMap((group: GroupVoteRecord) => marksForGroup(
      { yes: group.yes, abstain: group.abstain, no: group.no, absent: group.absent }, group.seats,
    ));
  }
  return projection.groups.flatMap(group => marksForGroup(
    { unknown: group.available, absent: group.absent }, group.seats,
  ));
}
