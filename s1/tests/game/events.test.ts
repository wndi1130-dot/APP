import { describe, expect, it } from 'vitest';
import { chooseCard, createGame, drawTravelEvent, EVENT_COOLDOWN, TRAVEL_EVENTS, viewCard } from '../../src/game';
import type { Card } from '../../src/game';

// 같은 사건이 다시 나오면 지난번 고른 것에 따라 본문이 달라지고, 다섯 구간 안에는 다시 나오지 않는다(2026-10-07 사용자 후기).

function play(g: ReturnType<typeof createGame>, card: Omit<Card, 'uid'>, index: number) {
  const uid = g.nextCardUid++;
  g.cards.push({ uid, ...card });
  const view = viewCard(g, g.cards[g.cards.length - 1]);
  expect(chooseCard(g, uid, index)).toBe(true);
  return view;
}

describe('사건 기억', () => {
  it('이동 사건은 다시 나오면 지난 선택에 따라 본문이 바뀐다', () => {
    for (const ev of TRAVEL_EVENTS) {
      const g = createGame(`memo-${ev.id}`);
      g.med = 20; g.coal = 60;
      const first = play(g, { kind: 'travel', text: ev.id }, 0);
      const second = viewCard(g, { uid: 999, kind: 'travel', text: ev.id });
      expect(second.body, ev.id).not.toBe(first.body);
      expect(g.eventLog[ev.id]).toMatchObject({ n: 1, pick: first.choices[0].label });
    }
  });

  it('거절을 거듭하면 대가가 커진다', () => {
    const g = createGame('memo-refuse');
    const rel = (v: ReturnType<typeof viewCard>) => v.choices[2].effs.find(e => e.t === 'rel');
    const first = play(g, { kind: 'travel', text: 'tail_cold' }, 2);
    const second = viewCard(g, { uid: 999, kind: 'travel', text: 'tail_cold' });
    expect((rel(second) as { v: number }).v).toBeLessThan((rel(first) as { v: number }).v);
  });

  it('한 번 나온 이동 사건은 정해진 구간 동안 다시 뽑히지 않는다', () => {
    const g = createGame('memo-cool');
    g.seg = 6;
    const id = drawTravelEvent(g);
    expect(id).not.toBeNull();
    g.eventLog[id!] = { n: 1, seg: g.seg, pick: '' };
    g.recentEvents = [];
    for (let i = 0; i < 40; i += 1) {
      g.seg = 6 + (i % (EVENT_COOLDOWN - 1));
      expect(drawTravelEvent(g)).not.toBe(id);
      g.recentEvents = [];
    }
  });

  it('물린 곳과 자르는 선택지가 맞는다', () => {
    const g = createGame('memo-bite');
    for (let uid = 1; uid <= 3; uid += 1) {
      const v = viewCard(g, { uid, kind: 'bitten', comm: 'tail', who: '대원' });
      const part = v.choices[0].label.split(/[을를] /)[0];
      expect(v.body).toContain(`${part}`);
    }
  });

  it('부탁은 두 번째부터 다른 부탁이 온다', () => {
    const g = createGame('memo-favor');
    const first = play(g, { kind: 'favor', comm: 'front' }, 1);
    const second = viewCard(g, { uid: 999, kind: 'favor', comm: 'front' });
    expect(second.body).not.toBe(first.body);
  });
});
