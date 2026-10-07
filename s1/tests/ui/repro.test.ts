import { describe, expect, it } from 'vitest';
import { cloneGame, createGame } from '../../src/game';
import type { Game } from '../../src/game';
import { applyStep, makeBundle, replayBundle } from '../../src/ui/repro';
import type { Step, TrailEntry } from '../../src/ui/repro';

// 오류 재현 묶음(r8 출시 실무 3): 직전 저장에 마지막 행동을 다시 하면 같은 판이 나와야 한다.

/** app.ts의 step처럼: 사본에 하고, 기록을 남기고, 바꿔 끼운다. */
function run(g: Game, steps: Step[]) {
  const trail: TrailEntry[] = [];
  let prev: Game | null = null;
  for (const st of steps) {
    const next = cloneGame(g);
    trail.push({ ...st, seg: g.seg, phase: g.phase, t: 0 });
    prev = g;
    applyStep(next, st);
    g = next;
  }
  return { g, prev, trail };
}

describe('오류 재현 묶음', () => {
  it('직전 저장에 마지막 행동을 다시 하면 지금 저장과 같다', () => {
    let g = createGame('repro-1');
    const steps: Step[] = [];
    // 서류가 있으면 첫 선택지를 고르고, 없으면 다음으로 넘긴다. JSON을 거쳐도 같은지 본다.
    for (let i = 0; i < 40 && g.phase !== 'end'; i += 1) {
      const card = g.cards[0];
      const st: Step = card ? { a: 'choose', d: { uid: String(card.uid), index: '0' } } : { a: 'advance', d: {} };
      if (g.phase === 'council' && !card) st.a = 'vote';
      const r = run(g, [st]);
      steps.push(st);
      const b = JSON.parse(JSON.stringify(makeBundle(r.g, r.prev, r.trail, null)));
      const back = replayBundle(b);
      expect(back.thrown).toBeUndefined();
      expect(back.diff).toEqual([]);
      g = r.g;
    }
    expect(steps.length).toBeGreaterThan(10);
  });

  it('행동이 던지면 다시 할 때도 같은 오류가 난다', () => {
    const g = createGame('repro-2');
    const bad: Step = { a: '없는-행동', d: {} };
    const b = makeBundle(g, g, [{ ...bad, seg: g.seg, phase: g.phase, t: 0 }], { msg: '모르는 행동: 없는-행동', step: bad, t: 0 });
    const back = replayBundle(JSON.parse(JSON.stringify(b)));
    expect(back.thrown?.message).toBe('모르는 행동: 없는-행동');
  });

  it('레버와 거래도 같은 길로 간다', () => {
    const g = createGame('repro-3');
    const r = run(g, [{ a: 'lever', d: { comm: 'tail', which: 'ration', value: '2' } }]);
    expect(r.g.comms.tail.ration).toBe(2);
    expect(() => applyStep(cloneGame(g), { a: 'deal', d: { comm: 'tail', tool: 'bribe' } })).not.toThrow();
  });
});
