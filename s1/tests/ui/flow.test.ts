import { describe, expect, it } from 'vitest';
import {
  COUNCIL_INTERVAL, PHASES, RUN_SEGMENTS, assertFlow, councilCount, createFlow, isCouncilSegment, nextCouncilSegment,
  nextFlow, phasesOf, segmentsUntilCouncil, stepStatuses,
} from '../../src/ui/model/flow';
import type { FlowState } from '../../src/ui/model/flow';

function runAll(): FlowState[] {
  const visited: FlowState[] = [];
  let flow = createFlow();
  visited.push(flow);
  while (!flow.ended) {
    flow = nextFlow(flow);
    visited.push(flow);
  }
  return visited;
}

describe('구간과 단계', () => {
  it('출발 전 운영 → 이동 → 정차 → 의회 → 정산 순서다', () => {
    expect(PHASES).toEqual(['prep', 'travel', 'stop', 'council', 'settle']);
    expect(createFlow()).toEqual({ segment: 1, phase: 'prep', ended: false });
  });

  it('의회는 3, 6, 9, ... 구간에만 열리고 한 판에 8번이다', () => {
    const councilSegments = Array.from({ length: RUN_SEGMENTS }, (_, index) => index + 1).filter(isCouncilSegment);
    expect(COUNCIL_INTERVAL).toBe(3);
    expect(councilSegments).toEqual([3, 6, 9, 12, 15, 18, 21, 24]);
    expect(councilCount()).toBe(8);
    expect(phasesOf(1)).toEqual(['prep', 'travel', 'stop', 'settle']);
    expect(phasesOf(3)).toEqual(['prep', 'travel', 'stop', 'council', 'settle']);
  });

  it('회기가 아닌 구간은 정차 다음이 바로 정산이다', () => {
    expect(nextFlow({ segment: 2, phase: 'stop', ended: false })).toEqual({ segment: 2, phase: 'settle', ended: false });
    expect(nextFlow({ segment: 3, phase: 'stop', ended: false })).toEqual({ segment: 3, phase: 'council', ended: false });
    expect(nextFlow({ segment: 3, phase: 'council', ended: false })).toEqual({ segment: 3, phase: 'settle', ended: false });
  });

  it('정산 뒤엔 다음 구간의 출발 전 운영으로 간다', () => {
    expect(nextFlow({ segment: 4, phase: 'settle', ended: false })).toEqual({ segment: 5, phase: 'prep', ended: false });
  });

  it('한 판 전체를 돌면 24구간, 의회 단계 8번을 거쳐 끝난다', () => {
    const visited = runAll();
    const councils = visited.filter(flow => flow.phase === 'council' && !flow.ended);
    expect(councils.map(flow => flow.segment)).toEqual([3, 6, 9, 12, 15, 18, 21, 24]);
    expect(visited.at(-1)).toEqual({ segment: RUN_SEGMENTS, phase: 'settle', ended: true });
    // 24구간 × 4단계 + 회기 8번 + 시작 상태와 끝 상태
    expect(visited.length).toBe(RUN_SEGMENTS * 4 + 8 + 1);
    expect(nextFlow(visited.at(-1) as FlowState)).toEqual(visited.at(-1));
  });

  it('다음 회기까지 남은 구간을 센다', () => {
    expect(segmentsUntilCouncil({ segment: 1, phase: 'prep', ended: false })).toBe(2);
    expect(segmentsUntilCouncil({ segment: 2, phase: 'settle', ended: false })).toBe(1);
    expect(segmentsUntilCouncil({ segment: 3, phase: 'travel', ended: false })).toBe(0);
    expect(segmentsUntilCouncil({ segment: 3, phase: 'council', ended: false })).toBe(0);
    expect(segmentsUntilCouncil({ segment: 3, phase: 'settle', ended: false })).toBe(3);
    expect(nextCouncilSegment({ segment: 22, phase: 'prep', ended: false })).toBe(24);
    expect(nextCouncilSegment({ segment: 24, phase: 'settle', ended: false })).toBeNull();
    expect(segmentsUntilCouncil({ segment: 24, phase: 'settle', ended: true })).toBeNull();
  });

  it('단계 표시줄은 지난 단계, 지금 단계, 건너뛰는 의회를 구분한다', () => {
    expect(stepStatuses({ segment: 2, phase: 'stop', ended: false })).toEqual({
      prep: 'done', travel: 'done', stop: 'current', council: 'skipped', settle: 'upcoming',
    });
    expect(stepStatuses({ segment: 6, phase: 'council', ended: false })).toEqual({
      prep: 'done', travel: 'done', stop: 'done', council: 'current', settle: 'upcoming',
    });
    expect(Object.values(stepStatuses({ segment: 24, phase: 'settle', ended: true }))).toEqual(
      ['done', 'done', 'done', 'done', 'done'],
    );
  });

  it('잘못된 흐름 상태는 막는다', () => {
    expect(() => assertFlow({ segment: 0, phase: 'prep', ended: false })).toThrow();
    expect(() => assertFlow({ segment: 25, phase: 'prep', ended: false })).toThrow();
    expect(() => assertFlow({ segment: 4, phase: 'council', ended: false })).toThrow();
    expect(() => assertFlow({ segment: 5, phase: 'settle', ended: true })).toThrow();
    expect(() => assertFlow({ segment: 1, phase: 'lunch' as never, ended: false })).toThrow();
    expect(() => nextFlow({ segment: 1.5, phase: 'prep', ended: false })).toThrow();
  });
});
