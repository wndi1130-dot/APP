import { describe, expect, it } from 'vitest';
import { chiefPick, createS1cGame, D, delegateStatus, delegateTick, LAW_ONLY_TECHS, setDelegate, TECH_IDS, usefulVariant, workshopChief } from '../../src/game';

// 공방장 맡기기의 켜는 선과 끄는 선(s1c_domestic 6.4 조건 2, 레퍼런스 수집 r4 13번). 숫자는 제안.

function ready(seed: string) {
  const g = createS1cGame(seed);
  g.seg = D.delegateAfter + 2;
  const c = workshopChief(g)!.comm;
  g.comms[c].grudge = 0;
  g.comms[c].rel = 30;
  return { g, c };
}

describe('공방장 맡기기 히스테리시스', () => {
  it('처음엔 호의(+15)면 맡길 수 있다', () => {
    const { g, c } = ready('d1');
    g.comms[c].rel = D.delegateOff;
    expect(delegateStatus(g).ok).toBe(true);
  });

  it('+15 아래로 떨어지면 꺼지고, +20 이상이 돼야 다시 켜진다', () => {
    const { g, c } = ready('d2');
    expect(setDelegate(g, true)).toBe(true);
    g.comms[c].rel = 18; // 끄는 선 위: 그대로
    delegateTick(g);
    expect(g.dom!.delegate.on).toBe(true);
    g.comms[c].rel = 14;
    delegateTick(g);
    expect(g.dom!.delegate.on).toBe(false);
    expect(g.journal.some(j => j.text.includes('장부를 내려놓았다'))).toBe(true);
    g.comms[c].rel = 17;
    expect(delegateStatus(g).ok).toBe(false);
    expect(delegateStatus(g).why).toContain(`+${D.delegateOn}`);
    expect(setDelegate(g, true)).toBe(false);
    g.comms[c].rel = D.delegateOn;
    expect(setDelegate(g, true)).toBe(true);
    // 다시 켠 뒤엔 끄는 선(+15)만 본다
    g.comms[c].rel = 16;
    delegateTick(g);
    expect(g.dom!.delegate.on).toBe(true);
  });
});

describe('3단계 공방장은 쓸 법이 없는 기술을 안 깎는다(6.4, 2f1f64e)', () => {
  function rich(seed: string) {
    const { g, c } = ready(seed);
    const d = g.dom!;
    for (const p of d.people) p.skill = 3;
    for (const f of Object.keys(d.frags) as (keyof typeof d.frags)[]) d.frags[f] = 99;
    d.parts = 99; d.wood = 99; d.cores = 9;
    return { g, c, d };
  }

  it('법이 하나도 없으면 법에만 걸린 기술은 고르지 않는다', () => {
    for (const seed of ['p1', 'p2', 'p3', 'p4']) {
      const { g } = rich(seed);
      g.passed = {};
      const id = chiefPick(g);
      if (id) expect(LAW_ONLY_TECHS).not.toContain(id);
    }
  });

  it('난방 배당이 서 있으면 E3을 그 법 쪽 변형(나)으로 맡는다', () => {
    const { g, d } = rich('p5');
    g.passed = {};
    for (const id of TECH_IDS) if (id !== 'e3' && !d.techs[id]) d.techs[id] = { stage: 'done', defect: false, progress: 0, need: 0 };
    expect(chiefPick(g)).toBe(null);
    g.passed.heat_quota = g.session;
    expect(chiefPick(g)).toBe('e3');
    expect(usefulVariant(g, 'e3')).toBe('b');
    expect(setDelegate(g, true)).toBe(true);
    delegateTick(g);
    expect(d.restoring).toBe('e3');
    expect(d.techs.e3?.variant).toBe('b');
  });
});
