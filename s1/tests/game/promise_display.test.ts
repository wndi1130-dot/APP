import { describe, expect, it } from 'vitest';
import { createGame, createS1cGame, domesticPromiseMade, isStopPromise, P, promiseWhen, researchPromise, resolveStop } from '../../src/game';
import type { Comm, Game, LootKey } from '../../src/game';

// 프펑2식 이식 1단계: 약속의 남은 때를 보이고, 확인할 파견이 없던 「다음 파견에서 제외」는 지킨 것으로 치지 않고 다음 정차로 미룬다.

function skipPromise(g: Game): void {
  const cond = { kind: 'skip_dispatch' as const, label: '다음 파견에서 제외', now: false };
  g.comms.tail.promise = { kind: 'open', cond, label: cond.label, due: g.seg, madeSession: 0 }; // 이 구간의 정차에서 판정할 차례
}

function stopAt(g: Game, crewComm: Comm, target: LootKey = 'food'): void {
  g.phase = 'stop';
  g.stop = { place: 'factory', target, stay: 'short', crewComm, crewSize: 2, scout: true, threat: 0, done: false, result: null };
}

describe('다음 파견에서 제외: 판정할 파견이 없던 구간', () => {
  it('정차 없이 지나치면 지킨 것으로 치지 않고 다음 정차로 미룬다', () => {
    const g = createGame('skip-pass');
    g.seg = 4;
    skipPromise(g);
    const kept = g.stats.promisesKept;
    stopAt(g, 'tail');
    resolveStop(g, false);
    expect(g.comms.tail.promise).not.toBeNull();
    expect(g.comms.tail.promise!.due).toBe(g.seg + 1);
    expect(g.stats.promisesKept).toBe(kept);
    expect(g.stats.promisesBroken).toBe(0);
  });

  it('목표를 안 정하고 보내지 않은 구간도 지킨 것으로 치지 않는다', () => {
    const g = createGame('skip-notarget');
    g.seg = 4;
    skipPromise(g);
    stopAt(g, 'tail');
    g.stop!.target = null as unknown as LootKey;
    resolveStop(g, true);
    expect(g.comms.tail.promise).not.toBeNull();
    expect(g.stats.promisesKept).toBe(0);
  });

  it('미룬 약속은 다음 정차에서 꼬리칸을 안 보내면 지킨 것이다', () => {
    const g = createGame('skip-later');
    g.seg = 4;
    skipPromise(g);
    stopAt(g, 'tail');
    resolveStop(g, false);
    g.seg += 1;
    stopAt(g, 'guard');
    resolveStop(g, true);
    expect(g.comms.tail.promise).toBeNull();
    expect(g.stats.promisesKept).toBe(1);
  });

  it('미룬 약속은 다음 정차에서 꼬리칸을 보내면 어긴 것이다', () => {
    const g = createGame('skip-broken');
    g.seg = 4;
    skipPromise(g);
    stopAt(g, 'tail');
    resolveStop(g, false);
    g.seg += 1;
    stopAt(g, 'tail');
    resolveStop(g, true);
    expect(g.comms.tail.promise).toBeNull();
    expect(g.stats.promisesBroken).toBe(1);
  });
});

describe('약속의 남은 때 표시', () => {
  it('정차 약속은 다음 정차, 그 밖은 남은 구간 수다', () => {
    const g = createGame('when');
    g.seg = 5;
    skipPromise(g);
    expect(isStopPromise(g.comms.tail.promise!)).toBe(true);
    expect(promiseWhen(g, g.comms.tail.promise!)).toBe('다음 정차');
    const cond = { kind: 'heat' as const, label: '꼬리칸 난방 +1', now: false };
    g.comms.tail.promise = { kind: 'open', cond, label: cond.label, due: g.seg + P.promiseSegments, madeSession: 0 };
    expect(isStopPromise(g.comms.tail.promise)).toBe(false);
    expect(promiseWhen(g, g.comms.tail.promise)).toBe(`남은 ${P.promiseSegments}구간`);
    g.seg += 2;
    expect(promiseWhen(g, g.comms.tail.promise)).toBe(`남은 ${P.promiseSegments - 2}구간`);
  });

  it('고른 복원 약속은 지정한 기술과 남은 구간을 돌려주고, 약속이 없으면 null이다', () => {
    const g = createS1cGame('rp-show');
    g.seg = 5;
    expect(researchPromise(g)).toBeNull();
    const cond = { kind: 'research_pick' as const, label: '연구 우선권', now: false, s1c: true };
    g.comms.medtech.promise = { kind: 'open', cond, label: cond.label, due: g.seg + P.promiseSegments, madeSession: 0 };
    domesticPromiseMade(g);
    const r = researchPromise(g);
    expect(r).not.toBeNull();
    expect(r!.tech).toBe(g.dom!.researchPick);
    expect(r!.left).toBe(P.promiseSegments);
    g.seg += 1;
    expect(researchPromise(g)!.left).toBe(P.promiseSegments - 1);
    g.comms.medtech.promise = null;
    expect(researchPromise(g)).toBeNull();
  });
});
