import { describe, expect, it } from 'vitest';
import { createGame } from '../../src/game';
import { rnd } from '../../src/game/state';
import { liveWounds, noteDrop, noteInjury, noteRelief, unnamedInjured, woundView } from '../../src/game/wounds';
import { playGame } from '../../tools/s1c_bot';

// 잇기 ①: 옛 규칙이 g.injured를 바꾼 곁에 명부 기록만 남긴다. 숫자(g.injured·판 난수·저널)는 그대로여야 한다.

const fresh = (seed: string) => { const g = createGame(seed); g.cards = []; return g; };

describe('noteInjury / noteRelief / noteDrop', () => {
  it('기록만 남기고 g.injured·판 난수·저널을 건드리지 않는다', () => {
    const g = fresh('wn-1');
    g.injured = 2;
    const [rng, jl] = [g.rng.state, g.journal.length];
    noteInjury(g, 2, 'stop', '시험');
    expect(g.injured).toBe(2);
    expect([g.rng.state, g.journal.length]).toEqual([rng, jl]);
    expect(liveWounds(g)).toHaveLength(2);
    expect(unnamedInjured(g)).toBe(0);
  });

  it('이름을 주면 그 사람으로, 모자라면 겹치지 않게 채우고, 칸을 주면 그 칸에서 고른다', () => {
    const g = fresh('wn-2');
    const first = g.comms.tail.leader.name;
    noteInjury(g, 3, 'stop', '시험', { names: [first], comm: 'tail' });
    const who = liveWounds(g).map(w => w.who);
    expect(who[0]).toBe(first);
    expect(new Set(who).size).toBe(3);
    const g2 = fresh('wn-2b');
    noteInjury(g2, 2, 'brawl', '경비', { comm: 'guard' });
    expect(liveWounds(g2).every(w => w.comm === 'guard')).toBe(true);
  });

  it('같은 판이면 같은 기록이 나온다(판 난수와 무관)', () => {
    const a = fresh('wn-3'); const b = fresh('wn-3');
    for (let i = 0; i < 7; i += 1) rnd(b);
    noteInjury(a, 2, 'stop', '시험'); noteInjury(b, 2, 'stop', '시험');
    const key = (g: typeof a) => liveWounds(g).map(w => [w.who, w.grade, w.part, w.septic, w.daysLeft]);
    expect(key(a)).toEqual(key(b));
  });

  it('noteRelief는 가장 오래된 활성 기록부터 거두고, noteDrop은 그 사람의 가장 새 기록을 지운다', () => {
    const g = fresh('wn-4');
    noteInjury(g, 1, 'stop', 'a', { names: ['가'] });
    g.seg += 1;
    noteInjury(g, 1, 'stop', 'b', { names: ['나'] });
    noteInjury(g, 1, 'order', 'c', { names: ['나'] });
    noteRelief(g, 1);
    expect(woundView(g).map(r => r.who)).toEqual(['나', '나']);
    noteDrop(g, '나');
    expect(woundView(g).map(r => r.who)).toEqual(['나']);
    noteDrop(g, '없는사람');
    expect(woundView(g)).toHaveLength(1);
  });

  it('죽었거나 내린 사람의 기록은 화면 값에서 빠지고, 수는 이름 없는 부상자로 남는다', () => {
    const g = fresh('wn-5');
    g.injured = 1;
    noteInjury(g, 1, 'stop', '시험', { names: ['가'] });
    g.deaths.push('가');
    expect(woundView(g)).toEqual([]);
    expect(unnamedInjured(g)).toBe(1);
  });
});

describe('판을 끝까지 돌려도', () => {
  it('명부의 활성 기록은 g.injured를 넘지 않는다', () => {
    let bad = 0; let made = 0;
    const probe = { onSettle: (g: ReturnType<typeof createGame>) => { if (liveWounds(g).length > g.injured) bad += 1; } };
    for (const seed of ['wn-bot-1', 'wn-bot-2', 'wn-bot-3']) {
      const { g } = playGame(seed, { s1c: true, s1b: 'cruel', policy: 'caretaker', dom: 'engaged', probe } as never);
      made += (g as unknown as { wounds?: unknown[] }).wounds?.length ?? 0;
    }
    expect(bad).toBe(0);
    expect(made).toBeGreaterThan(0);
  }, 120000);
});
