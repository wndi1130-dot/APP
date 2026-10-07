import { describe, expect, it } from 'vitest';
import { createS1cGame, D, delegateStatus, delegateTick, setDelegate, workshopChief } from '../../src/game';

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
