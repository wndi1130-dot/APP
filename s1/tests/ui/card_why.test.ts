import { describe, expect, it } from 'vitest';
import { CONTENT_EVENTS, createS1cGame, registerContentEvents, viewCard } from '../../src/game';
import type { Card, Game } from '../../src/game';
import handle from '../../data/events/ev_b01_cracked_handle.json';

// 선택지 밑 사정 한 줄(결정 037): 글은 사건 데이터에서 읽기만 한다. 없으면 줄을 안 그린다.

function withCard(evId: string): { g: Game; card: Card } {
  const g = createS1cGame('card-why');
  const card = { uid: 9001, kind: 'content', text: evId, comm: 'engine', vals: {} } as unknown as Card;
  g.cards = [card];
  return { g, card };
}

describe('카드의 까닭·나중 줄', () => {
  registerContentEvents([handle].flat());
  const ev = CONTENT_EVENTS.find(e => e.choices.some(c => c.why) && e.choices.some(c => c.later) && e.choices.some(c => !c.later))!;

  it('사건 데이터에 까닭과 나중 글이 있다', () => {
    expect(ev).toBeTruthy();
  });

  it('viewCard가 두 글을 선택지에 싣는다', () => {
    const { g, card } = withCard(ev.id);
    const v = viewCard(g, card);
    for (const ch of v.choices) {
      const src = ev.choices.find(c => `content:${c.id}` === ch.special)!;
      expect(!!ch.why).toBe(!!src.why);
      expect(!!ch.later).toBe(!!src.later);
    }
    expect(v.choices.some(c => c.why)).toBe(true);
  });

  it('글을 채울 때 빈 글은 싣지 않는다(화면은 없는 줄을 안 그린다)', () => {
    const { g, card } = withCard(ev.id);
    for (const ch of viewCard(g, card).choices) {
      if ('why' in ch) expect(ch.why).toBeTruthy();
      if ('later' in ch) expect(ch.later).toBeTruthy();
    }
  });
});
