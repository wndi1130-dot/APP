import { describe, expect, it } from 'vitest';
import { createGame, onDeath, P, resolveStop } from '../../src/game';
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

  it('지나치면 그대로 두고, 내린 정차에서 태우며 석탄을 쓴다', () => {
    const g = withBurnLaw('pyre-b');
    onDeath(g, 'tail', ['가', '나']);
    stopAt(g);
    resolveStop(g, false);
    expect(g.pyre).toBe(2);

    // 같은 판에서 시신만 없는 쌍둥이와 비교한다. 태우는 데는 난수를 쓰지 않는다.
    const twin = structuredClone(g);
    twin.pyre = 0;
    stopAt(g);
    stopAt(twin);
    resolveStop(g, true);
    resolveStop(twin, true);
    expect(g.pyre).toBe(0);
    expect(twin.coal - g.coal).toBe(2 * P.pyreCoal);
    expect(g.journal.some(j => j.text.includes('장작불에 시신 2구'))).toBe(true);
  });
});
