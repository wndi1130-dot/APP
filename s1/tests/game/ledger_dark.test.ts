import { describe, expect, it } from 'vitest';
import { COMMS, createGame, drain, enableDark } from '../../src/game';
import { answerThreat } from '../../src/game/dark/order';
import { commOf } from '../../src/game/dark/state';

// dark/ 의 수치 변경이 까닭 장부를 거쳐도 숫자가 그대로인지(봇 판과 골든이 안 밟는 자리). 기대값은 옮기기 전 식에서 손으로 셈한 것이다.

function fresh(seed: string) {
  const g = createGame(seed);
  g.cards = [];
  enableDark(g);
  drain(g);
  const id = g.comms.front.leader.personId;
  g.dark!.executors = [{ id } as never];
  return { g, id, c: commOf(g, id) };
}

const rows = (g: ReturnType<typeof fresh>['g']) => drain(g).map(r => [r.k, r.d, r.why]);

describe('dark/ 장부: 봇 판이 안 밟는 자리', () => {
  it('실행자 협박에 내주면 사치품을 3까지만 덜고(0 아래로 안 내려감) 그 칸 관계가 5 오른다', () => {
    const { g, id, c } = fresh('ld-give');
    g.lux = 2; g.comms[c].rel = 10;
    answerThreat(g, id, 'give');
    expect([g.lux, g.comms[c].rel]).toEqual([0, 15]);
    expect(rows(g)).toEqual([['lux', -2, 'order'], [`rel:${c}`, 5, 'order']]);
  });

  it('털어놓으면 신임 −10, 이상주의 지도자 칸마다 관계 +5가 「질서 잡기」로 적힌다', () => {
    const { g, id } = fresh('ld-confess');
    g.trust = 40;
    for (const k of COMMS) g.comms[k].rel = 0;
    const ideal = COMMS.filter(k => g.comms[k].leader.trait === 'ideal');
    answerThreat(g, id, 'confess');
    expect(g.trust).toBe(30);
    expect(rows(g)).toEqual([['trust', -10, 'order'], ...ideal.map(k => [`rel:${k}`, 5, 'order'])]);
  });
});
