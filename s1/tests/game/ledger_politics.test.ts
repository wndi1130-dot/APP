import { describe, expect, it } from 'vitest';
import { COMMS, LAWS, LAW_IDS, P, castVote, createGame, cutComm, drain, enactLaw, exposeBribe, isLawAgenda, openCouncil, repealLaw, setAgenda, setSpace, stance, supportComm, uniqueAction } from '../../src/game';
import type { Game } from '../../src/game';

// politics.ts의 수치 변경이 까닭 장부를 거쳐도 숫자가 그대로인지(golden.test.ts와 여러 판 비교가 못 밟는 자리). 기대값은 옮기기 전 식에서 손으로 셈한 것이다.

function fresh(seed: string): Game {
  const g = createGame(seed);
  g.cards = [];
  drain(g);
  return g;
}

const rows = (g: Game) => drain(g).map(r => [r.k, r.d, r.why]);

describe('politics.ts 장부: 골든 판이 안 밟는 자리', () => {
  it('지지: 사치품 2를 쓰고 그 칸 관계가 오르며 반대편 칸 관계가 3 깎인다(전부 「집단에 한 일」)', () => {
    const g = fresh('lp-support');
    g.lux = 5; g.comms.front.rel = 0; g.comms.tail.rel = 0; g.comms.front.supportedAt = -99;
    expect(supportComm(g, 'front')).toBeNull();
    expect([g.lux, g.comms.front.rel, g.comms.tail.rel]).toEqual([3, P.supportRel, -3]);
    expect(rows(g)).toEqual([['lux', -2, 'comm'], ['rel:front', P.supportRel, 'comm'], ['rel:tail', -3, 'comm']]);
  });

  it('칼질: 그 칸 관계 −15, 식량 +4, 반대편 칸 관계 +5', () => {
    const g = fresh('lp-cut');
    g.food = 10; g.comms.engine.rel = 0; g.comms.medtech.rel = 0;
    expect(cutComm(g, 'engine')).toBeNull();
    expect([g.food, g.comms.engine.rel, g.comms.medtech.rel]).toEqual([14, -15, 5]);
    expect(rows(g)).toEqual([['rel:engine', -15, 'comm'], ['food', 4, 'comm'], ['rel:medtech', 5, 'comm']]);
  });

  it('칸 고유 행동: 꼬리칸은 석탄 +3, 그 밖(앞칸)은 사치품 +2', () => {
    const g = fresh('lp-unique');
    g.coal = 10; g.lux = 1; g.comms.tail.rel = 20; g.comms.front.rel = 20;
    expect(uniqueAction(g, 'tail')).toBeNull();
    expect(g.coal).toBe(13);
    expect(rows(g)).toEqual([['coal', 3, 'comm']]);
    g.actedSeg = -1;
    expect(uniqueAction(g, 'front')).toBeNull();
    expect(g.lux).toBe(3);
    expect(rows(g)).toEqual([['lux', 2, 'comm']]);
  });

  it('공간 내주기: 내주는 칸 관계가 단 수만큼 깎인다', () => {
    const g = fresh('lp-space');
    g.comms.front.rel = 5;
    expect(setSpace(g, 2, 'front')).toBeNull();
    expect(g.comms.front.rel).toBe(5 + P.spacePullRel * 2);
    expect(rows(g)).toEqual([['rel:front', P.spacePullRel * 2, 'comm']]);
  });

  it('뇌물이 드러나면 신임 −10이 「들통난 거래」로 적히고, 신임이 5뿐이면 −5만 적힌다', () => {
    const g = fresh('lp-expose');
    g.trust = 60;
    exposeBribe(g, 'front');
    expect(g.trust).toBe(50);
    expect(drain(g).filter(r => r.k === 'trust')).toEqual([{ k: 'trust', d: -10, why: 'leak' }]);
    g.trust = 5;
    exposeBribe(g, 'front');
    expect(g.trust).toBe(0);
    expect(drain(g).filter(r => r.k === 'trust')).toEqual([{ k: 'trust', d: -5, why: 'leak' }]);
  });

  it('법을 세우면 법이 정한 관계 몫과 1회 효과가, 거두면 지지 칸 관계 −repealRel이 「의회 표결」로 적힌다', () => {
    const law = LAW_IDS.find(l => LAWS[l].res.trustOnce || LAWS[l].res.foodOnce)!;
    expect(law).toBeDefined();
    const def = LAWS[law];
    const g = fresh('lp-law');
    g.trust = 50; g.food = 30;
    for (const c of COMMS) g.comms[c].rel = 0;
    enactLaw(g, law, []);
    const got = drain(g);
    for (const c of COMMS) {
      const r = def.rels[c];
      expect(got.filter(x => x.k === `rel:${c}` && x.why === 'vote').reduce((s, x) => s + x.d, 0)).toBe(r ?? 0);
    }
    expect(got.filter(x => x.k === 'trust' && x.why === 'vote').reduce((s, x) => s + x.d, 0)).toBe(def.res.trustOnce ?? 0);
    expect(got.filter(x => x.k === 'food' && x.why === 'vote').reduce((s, x) => s + x.d, 0)).toBe(def.res.foodOnce ?? 0);
    expect(g.food).toBe(30 + (def.res.foodOnce ?? 0));
    for (const c of COMMS) g.comms[c].rel = 0;
    const supporters = COMMS.filter(c => stance(g, c, { law, repeal: false }, false).score >= 3);
    repealLaw(g, law);
    const gone = drain(g).filter(x => x.why === 'vote');
    expect(gone.map(x => [x.k, x.d])).toEqual(supporters.map(c => [`rel:${c}`, -P.repealRel]));
  });

  it('비상대권 포고는 긴장 +5가 「포고」로 적힌다(긴장이 98이면 +2만)', () => {
    const g = fresh('lp-decree');
    g.tension = 20;
    g.decreeLeft = 1;
    openCouncil(g);
    drain(g);
    const idx = g.council!.options.findIndex(a => isLawAgenda(a) && !a.ratify);
    expect(idx).toBeGreaterThanOrEqual(0);
    setAgenda(g, idx);
    expect(castVote(g, true)).not.toBeNull();
    expect(g.tension).toBe(25);
    expect(drain(g).filter(r => r.k === 'tension' && r.why === 'decree')).toEqual([{ k: 'tension', d: 5, why: 'decree' }]);
    // 긴장이 98이면 실제로 오른 만큼(+2)만 적힌다
    const h = fresh('lp-decree-2');
    h.tension = 98;
    h.decreeLeft = 1;
    openCouncil(h);
    setAgenda(h, h.council!.options.findIndex(a => isLawAgenda(a) && !a.ratify));
    drain(h);
    castVote(h, true);
    expect(h.tension).toBe(100);
    expect(drain(h).filter(r => r.k === 'tension' && r.why === 'decree')).toEqual([{ k: 'tension', d: 2, why: 'decree' }]);
  });
});
