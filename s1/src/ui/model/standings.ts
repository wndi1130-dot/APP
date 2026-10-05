import { allocateSeats, buildCouncilGroups } from '../../core';
import type { CommunityMetric, GameState } from '../../core';
import { orderedGroupIds, relationStance, urgentNeed } from './groups';
import type { GroupId, Stance } from './groups';

// 불만·지지 띠와 집단 패널에 쓰는 집단별 처지. 의석은 A2 allocateSeats로 센다.

export interface GroupStanding {
  id: GroupId;
  population: number;
  present: number;
  seats: number;
  relation: number;
  stance: Stance;
  cohesion: number;
  leaderId?: string;
  /** 공동체만: 가장 급한 처지. 세력은 이념으로 움직여서 없다. */
  need?: CommunityMetric;
}

export function groupStandings(game: GameState): GroupStanding[] {
  const built = buildCouncilGroups(game);
  const byId = new Map(built.map(group => [group.id, group]));
  const ordered = orderedGroupIds(byId.keys()).map(id => byId.get(id)!);
  const seats = allocateSeats(ordered);
  return ordered.map((group, index) => {
    const id = group.id as GroupId;
    const state = game.groups[id];
    const community = Object.hasOwn(game.communities, id) ? game.communities[id as keyof GameState['communities']] : undefined;
    return {
      id,
      population: group.population,
      present: group.present,
      seats: seats[index].seats,
      relation: state.relation,
      stance: relationStance(state.relation),
      cohesion: state.cohesion,
      ...(group.leaderId === undefined ? {} : { leaderId: group.leaderId }),
      ...(community ? { need: urgentNeed(community) } : {}),
    };
  });
}

export interface StanceTotals {
  discontent: number;
  neutral: number;
  support: number;
}

/** 불만·중립·지지별 의석 합. */
export function stanceSeats(standings: readonly GroupStanding[]): StanceTotals {
  const totals: StanceTotals = { discontent: 0, neutral: 0, support: 0 };
  for (const standing of standings) totals[standing.stance] += standing.seats;
  return totals;
}
