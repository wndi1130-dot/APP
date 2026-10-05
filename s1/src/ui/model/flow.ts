// 한 구간의 다섯 단계와 회기 주기. 순수 함수만 둔다.

export const PHASES = ['prep', 'travel', 'stop', 'council', 'settle'] as const;
export type Phase = typeof PHASES[number];

export const PHASE_LABELS: Readonly<Record<Phase, string>> = Object.freeze({
  prep: '출발 전 운영',
  travel: '이동',
  stop: '정차',
  council: '의회',
  settle: '정산',
});

/** S1a 한 판의 길이(기획서 3장). */
export const RUN_SEGMENTS = 24;
/** 의회 회기는 3구간마다 열린다(3, 6, 9, ... 구간). */
export const COUNCIL_INTERVAL = 3;

export interface FlowState {
  /** 1부터 센다. 화면엔 '○구간째'로 보인다. */
  segment: number;
  phase: Phase;
  /** 마지막 구간의 정산을 넘기면 판이 끝난다. */
  ended: boolean;
}

export type StepStatus = 'done' | 'current' | 'upcoming' | 'skipped';

export function assertSegmentNumber(segment: number): void {
  if (!Number.isSafeInteger(segment) || segment < 1 || segment > RUN_SEGMENTS) {
    throw new RangeError(`구간은 1부터 ${RUN_SEGMENTS}까지의 정수여야 합니다: ${segment}`);
  }
}

export function isPhase(value: unknown): value is Phase {
  return typeof value === 'string' && (PHASES as readonly string[]).includes(value);
}

export function createFlow(): FlowState {
  return { segment: 1, phase: 'prep', ended: false };
}

export function isCouncilSegment(segment: number): boolean {
  assertSegmentNumber(segment);
  return segment % COUNCIL_INTERVAL === 0;
}

/** 그 구간에 실제로 거치는 단계. 회기가 아닌 구간은 의회를 건너뛴다. */
export function phasesOf(segment: number): Phase[] {
  const council = isCouncilSegment(segment);
  return PHASES.filter(phase => phase !== 'council' || council);
}

export function assertFlow(flow: FlowState): void {
  assertSegmentNumber(flow.segment);
  if (!isPhase(flow.phase)) throw new TypeError(`모르는 단계입니다: ${String(flow.phase)}`);
  if (flow.phase === 'council' && !isCouncilSegment(flow.segment)) {
    throw new Error(`${flow.segment}구간은 회기가 아니라서 의회 단계가 없습니다.`);
  }
  if (typeof flow.ended !== 'boolean') throw new TypeError('ended는 참·거짓이어야 합니다.');
  if (flow.ended && (flow.segment !== RUN_SEGMENTS || flow.phase !== 'settle')) {
    throw new Error('끝난 판은 마지막 구간의 정산에 머물러야 합니다.');
  }
}

/** 다음 단계로 넘긴다. 정산 뒤엔 다음 구간의 출발 전 운영, 마지막 정산 뒤엔 판이 끝난다. */
export function nextFlow(flow: FlowState): FlowState {
  assertFlow(flow);
  if (flow.ended) return { ...flow };
  const phases = phasesOf(flow.segment);
  const index = phases.indexOf(flow.phase);
  if (index < phases.length - 1) return { ...flow, phase: phases[index + 1] };
  if (flow.segment >= RUN_SEGMENTS) return { ...flow, ended: true };
  return { segment: flow.segment + 1, phase: 'prep', ended: false };
}

/** 다음 회기가 열리는 구간. 이번 구간의 의회가 아직 안 지났으면 이번 구간이다. 남은 회기가 없으면 null. */
export function nextCouncilSegment(flow: FlowState): number | null {
  assertFlow(flow);
  if (flow.ended) return null;
  const councilPassed = PHASES.indexOf(flow.phase) > PHASES.indexOf('council');
  let segment = flow.segment;
  if (!isCouncilSegment(segment) || councilPassed) {
    segment = (Math.floor(flow.segment / COUNCIL_INTERVAL) + 1) * COUNCIL_INTERVAL;
  }
  return segment > RUN_SEGMENTS ? null : segment;
}

/** '다음 회기까지 N구간'의 N. 0이면 이번 구간에 회기가 있다. */
export function segmentsUntilCouncil(flow: FlowState): number | null {
  const next = nextCouncilSegment(flow);
  return next === null ? null : next - flow.segment;
}

/** 단계 표시줄의 상태. 회기가 아닌 구간의 의회는 skipped다. */
export function stepStatuses(flow: FlowState): Record<Phase, StepStatus> {
  assertFlow(flow);
  const council = isCouncilSegment(flow.segment);
  const currentIndex = PHASES.indexOf(flow.phase);
  const result = {} as Record<Phase, StepStatus>;
  PHASES.forEach((phase, index) => {
    if (phase === 'council' && !council) result[phase] = 'skipped';
    else if (flow.ended || index < currentIndex) result[phase] = 'done';
    else if (index === currentIndex) result[phase] = 'current';
    else result[phase] = 'upcoming';
  });
  return result;
}

/** 한 판에 열리는 회기 수(24구간이면 8번). */
export function councilCount(): number {
  return Math.floor(RUN_SEGMENTS / COUNCIL_INTERVAL);
}
