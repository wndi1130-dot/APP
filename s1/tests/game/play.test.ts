import { describe, expect, it } from 'vitest';
import {
  advance, castVote, chooseCard, COMMS, createGame, currentAgenda, disembarkMood, makeDeal, onDeath, primaryAction, relationLine, resolveStop,
  toolStatus, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';

/** 단순한 자동 플레이어. 첫 번째 가능한 선택지를 고르고, 의회에서는 공개 협상을 해 본다. */
function autoplay(seed: string, deal: boolean): Game {
  const g = createGame(seed);
  for (let guard = 0; guard < 2000 && g.phase !== 'end'; guard += 1) {
    if (g.cards.length > 0) {
      const card = g.cards[0];
      const view = viewCard(g, card);
      const idx = view.choices.findIndex(c => !c.disabled);
      expect(idx).toBeGreaterThanOrEqual(0);
      expect(chooseCard(g, card.uid, idx)).toBe(true);
      continue;
    }
    if (g.phase === 'stop' && g.stop && !g.stop.done) {
      resolveStop(g, true);
      continue;
    }
    if (g.phase === 'council' && g.council && !g.council.result && currentAgenda(g)) {
      if (deal) {
        for (const c of COMMS) {
          if (toolStatus(g, c, 'open').ok) makeDeal(g, c, 'open', 0);
        }
      }
      castVote(g);
      continue;
    }
    const primary = primaryAction(g);
    expect(primary.ok, `${g.phase} ${primary.label} ${primary.why ?? ''}`).toBe(true);
    advance(g);
  }
  return g;
}

describe('S1a 한 판', () => {
  it('끝까지 돌고 끝 조건으로 끝난다', () => {
    for (let i = 0; i < 40; i += 1) {
      const g = autoplay(`seed-${i}`, i % 2 === 0);
      expect(g.phase).toBe('end');
      expect(g.end).not.toBeNull();
      expect(Number.isFinite(g.coal) && Number.isFinite(g.trust) && Number.isFinite(g.tension)).toBe(true);
    }
  });

  it('같은 시드와 같은 선택이면 같은 판이다', () => {
    const a = autoplay('same', true);
    const b = autoplay('same', true);
    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
  });

  it('상태를 JSON으로 저장하고 되살릴 수 있다', () => {
    const g = autoplay('json', false);
    expect(JSON.parse(JSON.stringify(g))).toEqual(g);
  });
});

describe('정차 장면과 관계 문장', () => {
  it('관계 일곱 단계마다 문장이 있다', () => {
    for (const rel of [90, 50, 20, 0, -20, -50, -90]) expect(relationLine(rel)).not.toBe('');
  });

  it('불신임 직전이면 어깨가 처진 장면, 크게 지지받으면 개선장군 장면이다', () => {
    const g = createGame('scene');
    g.trust = 20;
    expect(disembarkMood(g, 'tail')).toBe('cornered');
    g.trust = 80;
    g.tension = 10;
    for (const c of COMMS) g.comms[c].rel = 60;
    expect(disembarkMood(g, 'tail')).toBe('triumph');
    g.trust = 50;
    g.comms.tail.rel = -50;
    expect(disembarkMood(g, 'tail')).toBe('cold');
  });

  it('열차장이 고른 죽음엔 죄책감, 그 밖의 죽음엔 애도 장면이다(목격자가 있으면 죄책감이 3구간)', () => {
    const g = createGame('scene-death');
    g.seg = 5;
    onDeath(g, 'tail', ['추위에 죽은 노인']);
    expect(disembarkMood(g, 'tail')).toBe('grief');
    onDeath(g, 'guard', ['쏘아 죽인 대원'], 'chosen', true);
    expect(disembarkMood(g, 'tail')).toBe('guilt');
    g.seg = 7;
    expect(disembarkMood(g, 'tail')).toBe('guilt');
    g.seg = 8;
    expect(disembarkMood(g, 'tail')).not.toBe('guilt');
  });
});
