import { describe, expect, it } from 'vitest';
import { advance, chooseCard, createGame, isGone, primaryAction, PROLOGUE, startPrologue, storyOf, viewCard } from '../../src/game';
import type { Game } from '../../src/game';

// 서막(first_leg_story 5장 '서막 흐름', 2026-10-07 사용자 결정): 약속 → 저탄장 수색 → 출발 → 열차 안 첫 거래.

function pick(g: Game, label: string): void {
  const card = g.cards[0];
  const i = viewCard(g, card).choices.findIndex(c => c.label === label);
  expect(i, `${card.kind}: ${label}`).toBeGreaterThanOrEqual(0);
  expect(chooseCard(g, card.uid, i)).toBe(true);
}

function started(seed: string): Game {
  const g = createGame(seed);
  startPrologue(g);
  return g;
}

describe('서막', () => {
  it('약속 카드로 시작하고, 서류를 다 처리해야 출발한다', () => {
    const g = started('pro-1');
    expect(g.cards.map(c => c.kind)).toEqual(['pro_promise']);
    expect(primaryAction(g).ok).toBe(false);
    expect(g.journal.some(j => j.text.startsWith('볼슈틴 차고를 떠났다'))).toBe(false);
  });

  it('약속하고 다섯을 다 데려오면 지킨 것, 첫 거래는 난방 하나만 청한다', () => {
    // 다 데려오는 시드를 찾는다(운반조부터 부르면 3~5명).
    for (let i = 0; i < 50; i += 1) {
      const g = started(`pro-kept-${i}`);
      const rel0 = g.comms.tail.rel;
      pick(g, '약속한다');
      pick(g, '운반조부터 부른다');
      if (storyOf(g).flags.depot_left_behind) continue;
      expect(storyOf(g).flags.depot_promise).toBe('kept');
      expect(g.comms.tail.rel).toBe(rel0 + 5);
      expect(g.stats.promisesKept).toBe(1);
      advance(g);
      expect(g.cards[0].kind).toBe('pro_deal');
      const heat = g.comms.tail.heat;
      const ration = g.comms.tail.ration;
      pick(g, '들어준다');
      expect(g.comms.tail.heat).toBe(heat + 1);
      expect(g.comms.tail.ration).toBe(ration);
      return;
    }
    throw new Error('다 데려오는 판을 못 찾았다');
  });

  it('약속하고 하나라도 남기면 어긴 것(3.7 위반), 남은 사람은 승강장에 남고 첫 거래가 무겁다', () => {
    const g = started('pro-broken');
    const pop0 = g.comms.tail.pop;
    const trust0 = g.trust;
    pick(g, '약속한다');
    pick(g, '바로 돌아선다');
    const flags = storyOf(g).flags;
    expect(flags.depot_promise).toBe('broken');
    expect(flags.depot_left_behind).toBe(true);
    expect(g.comms.tail.pop).toBe(pop0 - PROLOGUE.crew);
    expect(g.left).toHaveLength(PROLOGUE.crew);
    for (const n of g.left ?? []) expect(isGone(g, n)).toBe(true);
    expect(g.trust).toBeLessThan(trust0);
    expect(g.comms.tail.fervor).toBe(1);
    expect(g.stats.promisesBroken).toBe(1);
    advance(g);
    const heat = g.comms.tail.heat;
    const ration = g.comms.tail.ration;
    pick(g, '들어준다');
    expect([g.comms.tail.heat, g.comms.tail.ration]).toEqual([heat + 1, ration + 1]);
  });

  it('약속하지 않으면 위반은 없고 첫 거래가 무겁다. 거절하면 관계만 깎인다', () => {
    const g = started('pro-refused');
    pick(g, '약속하지 않는다');
    pick(g, '운반조부터 부른다');
    expect(storyOf(g).flags.depot_promise).toBe('refused');
    expect(g.stats.promisesBroken).toBe(0);
    advance(g);
    const card = g.cards[0];
    expect(viewCard(g, card).choices[0].extra?.[0]).toContain('배급');
    const rel = g.comms.tail.rel;
    pick(g, '거절한다');
    expect(g.comms.tail.rel).toBe(rel + PROLOGUE.dealRefuseRel);
  });

  it('석탄은 주운 자루만큼 +0~8이다', () => {
    for (let i = 0; i < 30; i += 1) {
      const g = started(`pro-coal-${i}`);
      const coal0 = g.coal;
      pick(g, '약속하지 않는다');
      pick(g, '자루도 챙긴다');
      expect(g.coal - coal0).toBeGreaterThanOrEqual(3);
      expect(g.coal - coal0).toBeLessThanOrEqual(8);
    }
  });

  it('서막 없는 판은 첫 출발에 첫 거래가 없다', () => {
    const g = createGame('pro-none');
    advance(g);
    expect(g.cards.some(c => c.kind === 'pro_deal')).toBe(false);
  });
});
