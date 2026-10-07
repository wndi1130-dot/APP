import { describe, expect, it } from 'vitest';
import { createGame, enableDark, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { openCase, punish } from '../../src/game/dark/cases';
import { actAll } from '../../src/game/dark/embers';
import { runOrder } from '../../src/game/dark/order';
import { adults } from '../../src/game/dark/state';
import type { Ember } from '../../src/game/dark/state';

// Codex J09 판정(/mnt/project-files/s1b_wip/j09_verdict.md)의 S1a 고칠 목록 회귀 테스트.

function darkGame(seed: string): Game {
  const g = createGame(seed);
  enableDark(g);
  g.seg = 4;
  return g;
}

describe('J09 2·11. 성공한 암살은 늘 수사를 연다', () => {
  function ordered(seed: string): { g: Game; exe: string } {
    const g = darkGame(seed);
    const target = adults(g, 'front', { noRep: true })[0].id;
    const exe = adults(g, 'guard', { noRep: true })[0].id;
    g.dark!.order = { target, why: 'hostile', exe: 'guard', exeId: exe, method: 'accident', at: g.seg };
    return { g, exe };
  }
  it('사고로 꾸며 들키지 않아도 사건이 열리고 실행자 단서는 없다. 들키면 실행자가 붙잡힌다', () => {
    let hidden = 0;
    let seen = 0;
    for (let i = 0; i < 200 && (hidden === 0 || seen === 0); i += 1) {
      const { g, exe } = ordered(`order-${i}`);
      runOrder(g, 'travel');
      if (g.dark!.stats.ordersOk !== 1) continue;
      expect(g.dark!.cases).toHaveLength(1);
      const c = g.dark!.cases[0];
      const s = c.sus.find(x => x.culprit)!;
      const card = g.cards.find(x => x.kind === 'dark:order_done')!;
      expect(card.n).toBe(c.id);
      const v = viewCard(g, card);
      expect(v.choices.length).toBe(3);
      if (card.text === 'hidden') {
        hidden += 1;
        expect(s.clues).toHaveLength(0);
        expect(v.body).toContain('사고라고 적혔다. 그래도 수사가 열린다.');
      } else {
        seen += 1;
        expect(s.id === exe || s.proxyFor === exe).toBe(true);
        expect(s.clues.length).toBeGreaterThanOrEqual(2);
        expect(v.body).toContain('붙잡혔다');
      }
    }
    expect(hidden).toBeGreaterThan(0);
    expect(seen).toBeGreaterThan(0);
  });
});

describe('J09 1. 진범을 벌하면 임박은 \'오지 않은 일\'로 끝난다', () => {
  it('임박을 띄운 뒤 진범을 벌하면 이동 때 카드 한 장이 나오고 아무도 다치지 않는다', () => {
    const g = darkGame('defuse');
    const d = g.dark!;
    const actor = adults(g, 'tail', { noRep: true })[0].id;
    const e: Ember = {
      id: 901, who: 'tail', actor, target: 'guard', mark: g.comms.guard.leader.personId, cause: 'fervor',
      stage: 2, imm: 3, quiet: 0, guardUntil: -1, sab: 'heating', blocked: false, born: g.seg,
    };
    d.embers.push(e);
    d.violentUsed = 1;
    const c = openCase(g, { kind: 'heating', culprit: actor, victimComm: 'front', dead: false, clock: 3, where: '앞칸', ember: e.id });
    const s = c.sus.find(x => x.culprit)!;
    punish(g, c, s, 'ration', 'summary');
    expect(d.embers.find(x => x.id === e.id)?.defused).toBe(true);
    const injured = g.injured;
    const deaths = (g.deathLog ?? []).length;
    g.cards = [];
    actAll(g);
    const cards = g.cards.filter(x => x.kind === 'dark:act');
    expect(cards).toHaveLength(1);
    expect(cards[0].text).toContain('이미 벌받은 뒤였다');
    expect(g.injured).toBe(injured);
    expect((g.deathLog ?? []).length).toBe(deaths);
    expect(d.embers.some(x => x.id === e.id)).toBe(false);
    expect(d.violentUsed).toBe(0);
  });
});
