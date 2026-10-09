import { describe, expect, it } from 'vitest';
import { createGame, enableDark, isGone, PLACES, resolveStop, sendScouts, STAY } from '../../src/game';
import type { Game } from '../../src/game';
import { adults, byName, isRep } from '../../src/game/dark/state';
import { crewNames, stopCrew, stopRisk } from '../../src/game/turn';

// 정차 해결에서 하차 대기자와 정차 명령이 얽힌 세 틈.

function stopGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  g.seg = 4;
  g.stop = {
    place: PLACES[0].id, target: 'coal', stay: Object.keys(STAY)[0] as never, crewComm: 'tail', crewSize: 6,
    done: false, result: null, threat: 1.4,
  };
  return g;
}

describe('정차 명령이 취소돼도 약속한 부상은 남는다', () => {
  // 약속한 부상자 가운데 대표가 아닌 사람을 대상으로 잡을 수 있는 씨앗을 결정적으로 찾는다.
  function promisedHurt() {
    for (let i = 0; i < 300; i += 1) {
      const g = stopGame(`stop-exile-hurt-${i}`);
      const fate = stopRisk(g).fate;
      const target = fate.hurt.map(n => byName(n)).find(p => p && !isRep(g, p.id) && !fate.dead.includes(p.name));
      if (target) return { g, target };
    }
    throw new Error('약속한 부상자가 나오는 씨앗이 없다');
  }

  it('실행자가 하차 대기라 명령이 취소돼도 대상은 부상으로 센다', () => {
    const { g, target } = promisedHurt();
    const exe = adults(g, 'guard', { noRep: true })[0];
    g.dark!.order = { target: target.id, why: 'hostile', exe: 'guard', exeId: exe.id, method: 'stop', at: g.seg };
    g.dark!.exile.push({ id: exe.id, comm: 'guard' });
    const before = g.injured;
    const res = resolveStop(g, true)!;
    expect(g.dark!.order).toBeNull();
    expect(isGone(g, exe.name)).toBe(true);
    expect(res.injured).toContain(target.name);
    expect(g.injured - before).toBe(res.injured.length);
  });
});

describe('하차를 기다리는 사람은 작업조로 안 나간다', () => {
  it('작업조 명단과 위험 명단에 들어가지 않는다', () => {
    const g = stopGame('stop-exile-crew');
    const p = byName(crewNames(g, 'tail', 6)[0])!;
    expect(crewNames(g, 'tail', 6)).toContain(p.name);
    g.dark!.exile.push({ id: p.id, comm: 'tail' });
    expect(crewNames(g, 'tail', 6)).not.toContain(p.name);
    expect(stopCrew(g)).not.toContain(p.name);
    const { fate } = stopRisk(g);
    expect(fate.hurt).not.toContain(p.name);
    expect(fate.dead).not.toContain(p.name);
  });
});

describe('하차한 정찰조는 자리 비움에 안 센다', () => {
  // 바깥이 고요하면 정찰조는 다 돌아온다.
  function scouted(seed: string) {
    const g = stopGame(seed);
    g.stop!.threat = 0.8;
    const rep = sendScouts(g)!;
    expect(rep.dead).toHaveLength(0);
    const out = rep.names[0];
    g.dark!.exile.push({ id: byName(out)!.id, comm: 'tail' });
    g.comms.tail.away = 0;
    return { g, rep, out };
  }

  it('정차하면 하차한 정찰조는 빼고 센다', () => {
    const { g, rep, out } = scouted('stop-exile-scout-go');
    const names = crewNames(g, 'tail', 6);
    resolveStop(g, true);
    expect(isGone(g, out)).toBe(true);
    const crewBack = names.filter(n => !isGone(g, n)).length;
    expect(g.comms.tail.away).toBe(crewBack + rep.names.length - 1);
  });

  it('지나쳐도 하차한 정찰조는 빼고 센다', () => {
    const { g, rep, out } = scouted('stop-exile-scout-pass');
    resolveStop(g, false);
    // 지나치면 서지 않아 하차는 미뤄진다. 서지 않았으니 정찰조는 모두 돌아온 채로 센다.
    expect(isGone(g, out)).toBe(false);
    expect(g.comms.tail.away).toBe(rep.names.length);
  });
});
