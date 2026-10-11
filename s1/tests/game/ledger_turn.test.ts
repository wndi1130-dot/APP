import { describe, expect, it } from 'vitest';
import { advance, breakPromise, burnPyre, callEmergency, createGame, crewWork, drain, emergencyStatus, keepPromise, P } from '../../src/game';
import type { Game } from '../../src/game';

// turn.ts의 수치 변경이 까닭 장부를 거쳐도 숫자가 그대로인지(golden.test.ts와 여러 판 비교가 못 밟는 자리). 값은 옮기기 전 식에서 손으로 셈한 것이다.

function fresh(seed: string): Game {
  const g = createGame(seed);
  g.cards = [];
  return g;
}

const rowsOf = (g: Game, why: string) => drain(g).filter(r => r.why === why);

describe('turn.ts 장부: 골든 판이 안 밟는 자리', () => {
  it('약속을 지키면 신임 +4와 그 칸 관계 +5, 어기면 신임 −8(큰 칸 −12)·관계 −20·긴장 +3이 「약속」으로 적힌다', () => {
    const g = fresh('lt-promise');
    g.trust = 50; g.tension = 20; g.comms.tail.rel = 0; g.comms.front.rel = 0;
    keepPromise(g, 'front', '시험');
    expect([g.trust, g.comms.front.rel]).toEqual([54, 5]);
    expect(drain(g)).toEqual([{ k: 'trust', d: 4, why: 'promise' }, { k: 'rel:front', d: 5, why: 'promise' }]);
    breakPromise(g, 'front', '시험'); // 앞칸은 의석 30 미만이라 −8
    expect([g.trust, g.comms.front.rel, g.tension]).toEqual([46, -15, 23]);
    const rows = drain(g);
    expect(rows.map(r => [r.k, r.d, r.why])).toEqual([['trust', -8, 'promise'], ['rel:front', -20, 'promise'], ['tension', 3, 'promise']]);
  });

  it('비상 소집은 신임을 비용만큼 깎고 「비상 소집」으로 적는다', () => {
    const g = fresh('lt-emergency');
    g.phase = 'stop';
    g.stop = { done: true } as never;
    g.trust = 80;
    const st = emergencyStatus(g);
    expect(st.ok).toBe(true);
    expect(callEmergency(g)).toBe(true);
    expect(g.trust).toBe(80 - st.cost);
    expect(rowsOf(g, 'emergency')).toEqual([{ k: 'trust', d: -st.cost, why: 'emergency' }]);
  });

  it('허드렛일 불만은 의무진 관계를 choreRel만큼 깎는다(꼬리칸은 늘 하던 일이라 안 깎인다)', () => {
    const g = fresh('lt-chore');
    g.comms.medtech.rel = 10;
    g.comms.tail.rel = 10;
    expect(crewWork(g, 'medtech', P.crewGain)).not.toBeNull();
    expect(g.comms.medtech.rel).toBe(10 + P.choreRel);
    expect(crewWork(g, 'tail', P.crewGain)).toBeNull();
    expect(g.comms.tail.rel).toBe(10);
    expect(rowsOf(g, 'stop.loot')).toEqual([{ k: 'rel:medtech', d: P.choreRel, why: 'stop.loot' }]);
  });

  it('장작불은 가진 석탄 안에서만 태운다: 석탄이 음수면 한 톨도 안 뺀다', () => {
    const g = fresh('lt-pyre');
    g.passed.corpse_burn = 1;
    g.pyre = 2;
    g.coal = -3;
    burnPyre(g);
    expect(g.coal).toBe(-3);
    expect(drain(g).filter(r => r.k === 'coal')).toEqual([]);
    g.pyre = 2;
    g.coal = 1;
    burnPyre(g);
    expect(g.coal).toBe(1 - Math.min(1, 2 * P.pyreCoal));
    expect(rowsOf(g, 'pyre')).toEqual([{ k: 'coal', d: -1, why: 'pyre' }]);
  });

  it('파업 금지법으로 기관실을 열면 관계 −10이 「일손을 놓음」으로 적히고 열기는 0이 된다', () => {
    const g = fresh('lt-ban');
    g.passed.strike_ban = 1;
    const e = g.comms.engine;
    e.fervor = 1;
    e.rel = -50;
    g.fear = 20;
    advance(g); // prep → 출발
    const rows = rowsOf(g, 'strike').filter(r => r.k === 'rel:engine');
    expect(rows).toEqual([{ k: 'rel:engine', d: -10, why: 'strike' }]);
    expect(e.fervor).toBe(0);
    expect(g.fear).toBe(30);
  });
});
