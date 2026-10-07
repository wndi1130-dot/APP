import { describe, expect, it } from 'vitest';
import { burnPyre, createGame, onDeath, P, pyreCount, resolveStop, stopRisk } from '../../src/game';
import type { Game } from '../../src/game';

// 장작불 법(2026-10-07 사용자 카드 답): 화실이 아니라 정차 때 선로 옆에서 태운다.
// 석탄을 얻지 않고 쓰며, 내린 정차까지 시신을 지킨다.

function withBurnLaw(seed: string): Game {
  const g = createGame(seed);
  g.passed.corpse_burn = 0;
  return g;
}

function stopAt(g: Game): void {
  g.phase = 'stop';
  g.stop = { place: 'factory', target: 'food', stay: 'short', crewComm: 'tail', crewSize: 2, scout: true, threat: 0.8, done: false, result: null };
}

describe('정차 때 장작불', () => {
  it('죽으면 석탄을 얻지 않고 지킬 시신으로 남는다', () => {
    const g = withBurnLaw('pyre-a');
    const coal = g.coal;
    const pop = g.comms.tail.pop;
    onDeath(g, 'tail', ['가', '나']);
    expect(g.pyre).toBe(2);
    expect(g.coal).toBe(coal);
    expect(g.comms.tail.pop).toBe(pop - 2);
  });

  it('지나치면 그대로 두고, 내린 정차에서 태운다', () => {
    const g = withBurnLaw('pyre-b');
    onDeath(g, 'tail', ['가', '나']);
    stopAt(g);
    resolveStop(g, false);
    expect(g.pyre).toBe(2);

    stopAt(g);
    resolveStop(g, true);
    expect(g.pyre).toBe(0);
    expect(g.journal.some(j => j.text.includes('장작불에 시신 2구'))).toBe(true);
  });

  it('태울 때 시신마다 석탄을 쓴다', () => {
    const g = withBurnLaw('pyre-e');
    onDeath(g, 'tail', ['가', '나']);
    const coal = g.coal;
    burnPyre(g);
    expect(coal - g.coal).toBe(2 * P.pyreCoal);
  });

  it('냉동칸이 차면 살던 칸에 두고 그 칸이 붐빈다. 태우면 되돌린다', () => {
    const g = withBurnLaw('pyre-c');
    g.stored = P.coldCap - 1;
    const crowd = g.comms.guard.base[2];
    onDeath(g, 'guard', ['가', '나', '다']);
    expect(g.pyre).toBe(1);
    expect(g.pyreKin?.guard).toBe(2);
    expect(pyreCount(g)).toBe(3);
    expect(g.comms.guard.base[2]).toBe(crowd + 2 * P.pyreKinCrowd);
    stopAt(g);
    resolveStop(g, true);
    expect(pyreCount(g)).toBe(0);
    expect(g.comms.guard.base[2]).toBe(crowd);
  });

  it('태울 시신이 있으면 내리는 정차가 조금 더 위험하다', () => {
    const g = withBurnLaw('pyre-d');
    stopAt(g);
    const before = stopRisk(g);
    onDeath(g, 'tail', ['가']);
    const after = stopRisk(g);
    expect(after.lam).toBeCloseTo(before.lam * P.pyreLight);
    expect(after.pDeath).toBeCloseTo(before.pDeath * P.pyreLight);
  });
});
