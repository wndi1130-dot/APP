import { describe, expect, it } from 'vitest';
import { createGame, DISEMBARK_LINES, disembarkMood, sendStop, stopScene } from '../../src/game';

// 수색대가 내리는 문장은 '보낸다'를 누른 뒤에 뜬다(사용자 2026-10-09 폰 플레이).
// 보내기 전 정차 서류엔 바깥 문장만 있고, 보낸 결과에만 그 순간의 처지로 고른 문장이 담긴다.

function stopGame(seed: string) {
  const g = createGame(seed);
  g.phase = 'stop';
  g.stop = { place: 'freight', target: 'food', stay: 'short', crewComm: 'tail', crewSize: 4, scout: false, threat: 1, done: false, result: null };
  return g;
}

describe('수색대가 내리는 문장', () => {
  it('보내기 전 정차 장면엔 바깥 문장만 있다', () => {
    const g = stopGame('disembark-before');
    expect(Object.keys(stopScene(g)!)).toEqual(['outside']);
  });

  it('보냈으면 결과에 보낸 순간 처지의 문장이 담긴다', () => {
    const g = stopGame('disembark-go');
    g.trust = 20; // 불신임 직전: 어깨가 처진 장면
    expect(disembarkMood(g, 'tail')).toBe('cornered');
    const r = sendStop(g, true)!;
    expect(r.passed).toBe(false);
    expect(r.disembark).toBe(DISEMBARK_LINES.cornered);
    expect(g.stop!.result!.disembark).toBe(DISEMBARK_LINES.cornered);
  });

  it('보낸 집단의 마음에 따라 문장이 달라진다', () => {
    const cold = stopGame('disembark-cold');
    cold.comms.tail.rel = -50;
    expect(sendStop(cold, true)!.disembark).toBe(DISEMBARK_LINES.cold);
    const warm = stopGame('disembark-warm');
    warm.comms.tail.rel = 30;
    expect(sendStop(warm, true)!.disembark).toBe(DISEMBARK_LINES.warm);
  });

  it('지나쳤으면 아무도 내리지 않아 문장이 없다', () => {
    const g = stopGame('disembark-pass');
    g.trust = 20;
    const r = sendStop(g, false)!;
    expect(r.passed).toBe(true);
    expect(r.disembark).toBeUndefined();
    expect('disembark' in r).toBe(false);
  });

  it('목표 없이 보내도 지나친 것과 같다', () => {
    const g = stopGame('disembark-notarget');
    g.stop!.target = null;
    const r = sendStop(g, true)!;
    expect(r.passed).toBe(true);
    expect(r.disembark).toBeUndefined();
  });
});
