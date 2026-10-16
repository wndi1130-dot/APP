import { D, TECHS, skillNeed } from './data';
import type { Field, TechId } from './data';
import type { DomPerson } from './state';

// 추정: 부재 제한의 수치는 명세 값 표의 추천값이다.
export const FIELD_GATE = {
  engine: { heatCap: 2 }, med: '새 회복 단축', radio: '정찰 요청',
  expedition: { missingSeats: 1 }, craft: '숙련 복원',
} as const;
// 추정: 작은 보정은 총 넷이다. 공작에는 기존 작업량 차이만 둔다.
export const FIELD_BONUS = { engine: 0.98, med: 1, radio: 0.05, expedition: 1.03 } as const;

/** 치료 여부와 탑승 여부는 연결할 쪽에서 고정한 업무 상태를 주입한다. */
export type FieldWorker = Pick<DomPerson, 'id' | 'field' | 'skill' | 'alive' | 'gone' | 'resting'>
  & { treating?: boolean; aboard?: boolean };
const canWork = (person: FieldWorker): boolean => person.alive && !person.gone && !person.resting && !person.treating;
const available = (person: FieldWorker): boolean => canWork(person) && person.skill >= 1 && person.skill <= 3;
const train = (people: readonly FieldWorker[]): FieldWorker[] => people.filter(person => available(person) && person.aboard !== false);

export function fieldReady(field: Field, people: readonly FieldWorker[], teamIds: readonly string[] = []): boolean {
  return people.some(person => person.field === field && available(person)
    && (field === 'expedition' ? teamIds.includes(person.id) : person.aboard !== false));
}

export type FieldGateRequest =
  | { field: 'engine'; requestedHeat: number; lawFloor?: number; operationCap?: number; mode?: 'manual' | 'auto' }
  | { field: 'med'; baseDays: number; requestedDays: number; floor: number; newRecord: boolean; grade: 'deep' | 'fracture' | 'light' }
  | { field: 'radio' }
  | { field: 'expedition'; teamIds: readonly string[]; availableIds: readonly string[] }
  | { field: 'craft'; tech: TechId; manual?: boolean };
export interface FieldGateResult {
  allowed: boolean;
  value: number;
  requested: number;
  teamIds: string[];
  reason?: string;
}

/** 제한·위험·산출에 쓸 실제 명단을 돌려주며 기존 상태에는 쓰지 않는다. */
export function fieldGate(people: readonly FieldWorker[], request: FieldGateRequest): FieldGateResult {
  const ready = fieldReady(request.field, people, request.field === 'expedition' ? request.teamIds : []);
  let value = 0;
  let requested = 0;
  let allowed = ready;
  let teamIds: string[] = [];
  if (request.field === 'engine') {
    requested = Math.max(request.requestedHeat, request.lawFloor ?? 0);
    value = Math.min(requested, request.operationCap ?? Infinity, ready ? Infinity : FIELD_GATE.engine.heatCap);
    allowed = value >= requested;
  } else if (request.field === 'med') {
    requested = request.requestedDays;
    value = request.newRecord ? Math.max(request.floor, request.grade !== 'light' && !ready
      ? request.baseDays : requested) : requested;
    allowed = value <= requested;
  } else if (request.field === 'radio') {
    value = requested = ready ? 1 : 0;
  } else if (request.field === 'expedition') {
    teamIds = [...new Set(request.teamIds)].filter(id => request.availableIds.includes(id)
      && !people.some(person => person.id === id && !canWork(person)));
    requested = teamIds.length;
    if (!fieldReady('expedition', people, teamIds) && teamIds.length > 1) {
      teamIds = teamIds.slice(0, Math.max(1, teamIds.length - FIELD_GATE.expedition.missingSeats));
    }
    value = teamIds.length;
    allowed = value > 0;
  } else {
    const definition = TECHS[request.tech];
    const top = (field: Field): number => train(people).filter(person => person.field === field)
      .reduce((best, person) => Math.max(best, person.skill), 0);
    requested = skillNeed(request.tech);
    value = top(definition.branch);
    allowed = value >= requested || (definition.tier === 3 && definition.branch !== 'craft'
      && value >= 2 && top('craft') >= 3);
  }
  return { allowed, value, requested, teamIds, reason: allowed ? undefined : '담당자 부재 또는 기존 조건의 제한' };
}

export type FieldBenefitRequest =
  | { field: 'engine'; baseCost: number; round?: (value: number) => number }
  | { field: 'med'; baseDays: number; floor: number; classroomDays?: number; newRecord: boolean; grade: 'deep' | 'fracture' | 'light' }
  | { field: 'radio'; baseYield: number; scoutMultiplier: number; round?: (value: number) => number }
  | { field: 'expedition'; earned: number; teamIds: readonly string[]; round?: (value: number) => number }
  | { field: 'craft'; multiplier: number; classroomWork: number; restoreAllowed: boolean };
export interface FieldBenefit { before: number; after: number; benefit: number }

/** 같은 수업·기술·법·난수·반올림에서 해당 분야 몫만 뺀 값과 비교한다. */
export function fieldBenefit(people: readonly FieldWorker[], request: FieldBenefitRequest): FieldBenefit {
  const ready = fieldReady(request.field, people, request.field === 'expedition' ? request.teamIds : []);
  const round = 'round' in request && request.round ? request.round : (value: number) => value;
  let before: number;
  let after: number;
  if (request.field === 'engine') {
    before = round(request.baseCost);
    after = round(request.baseCost * (ready ? FIELD_BONUS.engine : 1));
  } else if (request.field === 'med') {
    const eligible = request.newRecord && request.grade !== 'light' && ready;
    before = request.newRecord ? Math.max(request.floor, request.baseDays - (eligible ? request.classroomDays ?? 0 : 0)) : request.baseDays;
    after = request.newRecord ? Math.max(request.floor, before - (eligible ? FIELD_BONUS.med : 0)) : before;
  } else if (request.field === 'radio') {
    const multiplier = Math.min(1, Math.max(0, request.scoutMultiplier));
    before = round(request.baseYield * multiplier);
    after = round(request.baseYield * Math.min(1, multiplier + (ready ? FIELD_BONUS.radio : 0)));
  } else if (request.field === 'expedition') {
    before = round(request.earned);
    after = round(request.earned * (ready ? FIELD_BONUS.expedition : 1));
  } else {
    const skill = train(people).filter(person => person.field === 'craft')
      .reduce((best, person) => Math.max(best, person.skill), 0);
    before = request.restoreAllowed ? D.work * D.workSkill[0] * request.multiplier + request.classroomWork : 0;
    after = request.restoreAllowed ? D.work * D.workSkill[skill] * request.multiplier + request.classroomWork : 0;
  }
  const saves = request.field === 'engine' || request.field === 'med';
  return { before, after, benefit: saves ? before - after : after - before };
}
