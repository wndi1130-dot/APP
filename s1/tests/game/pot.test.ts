import { describe, expect, it } from 'vitest';
import { createGame, drain, forecast, potView, rnd, situation } from '../../src/game';
import type { Game } from '../../src/game';
import { COMMS } from '../../src/game/data';
import { D } from '../../src/game/domestic/data';
import { potActive, potOf, potRisk, potTick, setPot } from '../../src/game/domestic/pot';
import { enableDomestic } from '../../src/game/domestic/state';
import { playGame } from '../../tools/s1c_bot';

// 식당칸 솥의 불리기 세 단계(food_cooking 4.5). 숫자는 제안이다(domestic/data.ts pot*).

const fresh = (seed: string): Game => { const g = createGame(seed); g.cards = []; enableDomestic(g); return g; };
/** 판 난수는 씨앗으로만 정해진다. 바라는 판정(들킴/안 들킴)이 나올 때까지 난수 흐름을 한 칸씩 넘긴 뒤 솥 한 구간을 돌린다. */
function tick(g: Game, want: boolean): string[] {
  for (let i = 0; i < 4000; i += 1) {
    const probe = structuredClone(g);
    const before = potOf(probe).caught;
    potTick(probe, []);
    if ((potOf(probe).caught > before) === want) {
      const notes: string[] = [];
      potTick(g, notes);
      return notes;
    }
    rnd(g);
  }
  throw new Error('바라는 판정이 나오는 난수를 못 찾았다');
}

describe('기본은 그대로다', () => {
  it('고르지 않은 판은 솥 칸이 없고 식량 예고·처지·난수가 그대로다', () => {
    const g = fresh('pot-0');
    const rng = JSON.stringify(g.rng);
    const before = forecast(g).food;
    const notes: string[] = [];
    potTick(g, notes);
    expect(g.dom?.pot).toBeUndefined();
    expect(forecast(g).food).toBe(before);
    expect(JSON.stringify(g.rng)).toBe(rng);
    expect(notes).toEqual([]);
    setPot(g, 'plain');
    expect(g.dom?.pot).toBeUndefined();
  });

  it('내정을 끈 판에서는 고를 수 없다', () => {
    const g = createGame('pot-off');
    setPot(g, 'thin');
    expect(potOf(g).mode).toBe('plain');
    expect(potView(g).on).toBe(false);
    expect(potView(g).choices.map(c => c.mode)).toEqual(['plain']);
  });

  it('봇이 솥을 건드리지 않으면 내정 판은 끝까지 솥 칸이 없다', () => {
    const { g } = playGame('pot-bot', { s1c: true, policy: 'caretaker', dom: 'engaged' });
    expect(g.dom?.pot).toBeUndefined();
  });
});

describe('묽게', () => {
  it('식량 소모가 ×0.85가 되고 모든 칸 배급 처지가 레버 반 칸만큼 내려간다', () => {
    const g = fresh('pot-1');
    const dom0 = forecast(g).food;
    const sit0 = COMMS.map(c => situation(g, c)[1]);
    setPot(g, 'thin');
    const v = potView(g);
    const plain = v.choices.find(c => c.mode === 'plain')!.food;
    expect(plain).toBeCloseTo(dom0, 10);
    expect(forecast(g).food).toBeCloseTo(v.food, 10);
    expect(v.saved).toBeGreaterThan(0);
    // 내정의 덧셈 몫(온실·가족 특혜)이 0인 새 판에서는 통째로 ×0.85다.
    expect(forecast(g).food).toBeCloseTo(dom0 * D.potThinFood, 10);
    COMMS.forEach((c, i) => expect(situation(g, c)[1]).toBe(Math.max(0, sit0[i] - D.potThinSit)));
    setPot(g, 'plain');
    COMMS.forEach((c, i) => expect(situation(g, c)[1]).toBe(sit0[i]));
    expect(forecast(g).food).toBeCloseTo(dom0, 10);
  });

  it('잇달아 쓴 구간을 세고, 난수는 굴리지 않는다', () => {
    const g = fresh('pot-2');
    setPot(g, 'thin');
    const rng = JSON.stringify(g.rng);
    potTick(g, []);
    potTick(g, []);
    expect(potOf(g).thinRun).toBe(2);
    expect(JSON.stringify(g.rng)).toBe(rng);
    setPot(g, 'plain');
    potTick(g, []);
    expect(potOf(g).thinRun).toBe(0);
    expect(potOf(g).thinSegs).toBe(2);
  });
});

describe('섞어서', () => {
  it('식량 소모가 ×0.75가 되고 구간마다 목재 0.5가 든다. 처지 벌은 바로 오지 않는다', () => {
    const g = fresh('pot-3');
    const food0 = forecast(g).food;
    const sit0 = COMMS.map(c => situation(g, c)[1]);
    const wood0 = g.dom!.wood;
    setPot(g, 'mixed');
    expect(forecast(g).food).toBeCloseTo(food0 * D.potMixFood, 10);
    COMMS.forEach((c, i) => expect(situation(g, c)[1]).toBe(sit0[i]));
    tick(g, false);
    expect(g.dom!.wood).toBe(wood0 - D.potMixWood);
    expect(potOf(g).mode).toBe('mixed');
  });

  it('들킬 확률은 15%에서 섞은 구간마다 5%p 오르고 쉬면 5%p 내린다', () => {
    const g = fresh('pot-4');
    setPot(g, 'mixed');
    expect(potRisk(g)).toBeCloseTo(0.15, 10);
    expect(potView(g).risk).toBeCloseTo(0.15, 10);
    tick(g, false);
    tick(g, false);
    expect(potRisk(g)).toBeCloseTo(0.25, 10);
    setPot(g, 'plain');
    expect(potView(g).risk).toBe(0);
    potTick(g, []);
    expect(potRisk(g)).toBeCloseTo(0.2, 10);
    for (let i = 0; i < 10; i += 1) potTick(g, []);
    expect(potRisk(g)).toBeCloseTo(0.15, 10);
  });

  it('들키면 신임 −8, 모든 칸 관계 −5, 긴장 +5이고 까닭이 장부에 남으며 솥은 그대로로 돌아간다', () => {
    const g = fresh('pot-5');
    g.trust = 50; g.tension = 30;
    const rel0 = COMMS.map(c => g.comms[c].rel);
    setPot(g, 'mixed');
    drain(g);
    const notes = tick(g, true);
    expect(g.trust).toBe(50 - D.potCaughtTrust);
    expect(g.tension).toBe(30 + D.potCaughtTension);
    COMMS.forEach((c, i) => expect(g.comms[c].rel).toBe(rel0[i] - D.potCaughtRel));
    const rows = drain(g);
    expect(rows.every(r => r.why === 'pot')).toBe(true);
    expect(rows.map(r => r.k).sort()).toEqual(['tension', 'trust', ...COMMS.map(c => `rel:${c}`)].sort());
    expect(potOf(g).mode).toBe('plain');
    expect(potOf(g).caught).toBe(1);
    expect(notes).toContain('섞은 빵이 드러났다.');
    expect(g.cards.some(c => c.kind === 'info' && c.who === '섞은 빵이 드러났다')).toBe(true);
  });

  it('공동 식당 법이 서 있으면 신임 벌이 곱절이다', () => {
    const g = fresh('pot-6');
    g.trust = 50;
    g.passed.common_kitchen = g.session;
    setPot(g, 'mixed');
    expect(potView(g).lawDouble).toBe(true);
    tick(g, true);
    expect(g.trust).toBe(50 - D.potCaughtTrust * D.potCaughtLaw);
  });

  it('목재가 없으면 못 고르고, 쓰다 떨어지면 그대로로 돌아가며 식량도 덜 들지 않는다', () => {
    const g = fresh('pot-7');
    const food0 = forecast(g).food;
    g.dom!.wood = 0;
    setPot(g, 'mixed');
    expect(potOf(g).mode).toBe('plain');
    expect(potView(g).choices.find(c => c.mode === 'mixed')).toMatchObject({ ok: false, why: '섞을 목재가 없다' });
    g.dom!.wood = D.potMixWood;
    setPot(g, 'mixed');
    tick(g, false);
    expect(g.dom!.wood).toBe(0);
    expect(potActive(g)).toBe('plain');
    expect(forecast(g).food).toBeCloseTo(food0, 10);
    const notes: string[] = [];
    potTick(g, notes);
    expect(potOf(g).mode).toBe('plain');
    expect(notes).toEqual(['섞을 목재가 떨어져 솥이 그대로로 돌아갔다.']);
  });
});

describe('식량이 0이면 불릴 것이 없다', () => {
  it('못 고르고, 쓰던 솥은 그대로로 돌아간다', () => {
    const g = fresh('pot-8');
    setPot(g, 'thin');
    g.food = 0;
    const notes: string[] = [];
    potTick(g, notes);
    expect(potOf(g).mode).toBe('plain');
    expect(notes).toEqual(['불릴 식량이 없어 솥이 그대로로 돌아갔다.']);
    setPot(g, 'thin');
    expect(potOf(g).mode).toBe('plain');
    expect(potView(g).choices.find(c => c.mode === 'thin')).toMatchObject({ ok: false, why: '불릴 식량이 없다' });
  });
});

describe('판을 실제로 돌린다(봇)', () => {
  const BOT = { s1c: true, policy: 'caretaker', dom: 'idle' } as const;
  /** 첫 정산에서 식량이 얼마나 바뀌었나. thin이면 첫 카드를 고른 직후(첫 정산 전)에 묽게를 고른다. */
  const firstSettle = (thin: boolean): { food: number; g: Game } => {
    let food: number | null = null;
    let set = false;
    const { g } = playGame('pot-9', {
      ...BOT,
      probe: {
        afterPick: game => { if (thin && !set) { set = true; setPot(game, 'thin'); } },
        onSettle: game => { food ??= game.lastSettle?.food ?? null; },
      },
    });
    if (food === null) throw new Error('정산이 한 번도 없었다');
    return { food, g };
  };

  it('묽게 고른 판은 그대로인 판보다 첫 정산에서 식량이 덜 줄고, 쓴 구간이 세어진다', () => {
    const a = firstSettle(false);
    const b = firstSettle(true);
    expect(a.g.dom?.pot).toBeUndefined();
    expect(b.food).toBeGreaterThan(a.food);
    expect(potOf(b.g).thinSegs).toBeGreaterThan(0);
  });
});
