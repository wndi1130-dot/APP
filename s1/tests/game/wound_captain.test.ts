import { describe, expect, it } from 'vitest';
import { createGame, PROFILES } from '../../src/game';
import { D } from '../../src/game/domestic/data';
import { addWound, CAPTAIN, hurtCaptain, rebalanceBeds, woundTick, woundView } from '../../src/game/wounds';
import type { Game } from '../../src/game';

// 결정 072 다: 열차장이 다치면 부상 기록에 오르고 의무칸 침상(여섯)을 다른 부상자와 다툰다.

const fresh = (seed: string): Game => { const g = createGame(seed); g.cards = []; return g; };

function fillBeds(g: Game, n: number): string[] {
  const names = PROFILES.slice(0, n).map(p => p.name);
  for (const who of names) addWound(g, { who, comm: 'tail', from: 'stop', where: '시험', grade: 'deep', part: 'torso', septic: false, cuts: 0 });
  return names;
}

describe('열차장 부상', () => {
  it('열차장이 부상 기록에 올라 화면 값과 부상자 수에 든다', () => {
    const g = fresh('wc-1');
    const w = hurtCaptain(g, 'stop', '시험', { grade: 'fracture', part: 'legL', septic: false, cuts: 0 } as never);
    expect(w).toMatchObject({ who: CAPTAIN, comm: 'front', state: 'bed' });
    expect(g.injured).toBe(1);
    expect(woundView(g).map(r => r.who)).toEqual([CAPTAIN]);
  });

  it('침상은 여섯이라 일곱째로 다치면 침상 순서대로 누가 제 칸으로 내려간다', () => {
    const g = fresh('wc-2');
    fillBeds(g, D.beds);
    g.seg += 1;
    hurtCaptain(g, 'stop', '시험', { grade: 'deep', part: 'torso', septic: false });
    rebalanceBeds(g);
    const care = Object.fromEntries(woundView(g).map(r => [r.who, r.care]));
    expect(care[CAPTAIN]).toBe('home');
    // 일할 손 순서로 바꾸면 열차장이 침상에 남고 다른 사람이 내려간다.
    g.dom = { ...(g.dom as object), bedOrder: 'workers' } as never;
    rebalanceBeds(g);
    expect(woundView(g).find(r => r.who === CAPTAIN)?.care).toBe('bed');
    expect(woundView(g).filter(r => r.care === 'bed')).toHaveLength(D.beds);
  });

  it('약이 떨어져도 열차장은 이 길로 죽지 않는다', () => {
    const g = fresh('wc-3');
    hurtCaptain(g, 'stop', '시험', { grade: 'amputation', part: 'torso', septic: true });
    for (let i = 0; i < 40; i += 1) { g.med = 0; g.seg += 1; woundTick(g, []); }
    expect(g.deaths).not.toContain(CAPTAIN);
  });
});
