import { describe, expect, it } from 'vitest';
import { advance, chooseCard, createGame, viewCard } from '../../src/game';
import type { Game, LootDeck } from '../../src/game';
import { buildDeparture } from '../../src/game/field_departure';
import { applyFieldReturn, decodeFieldReceipt } from '../../src/game/field_receipt';

// 결정 474 S1: 갈래별 보장 몫(덱)의 자리가 영수증으로 돌아와 판 상태에 남고, 다음 출발 계약에 실린다 —
// 그래서 정차를 넘어서도 「n곳 중 정확히 k곳」이 지켜진다(값과 뽑기는 S2 loot_dress.gd 몫).

function atStop(g: Game): Game {
  for (let i = 0; i < 80 && !(g.phase === 'stop' && g.stop && !g.stop.done); i += 1) {
    if (g.cards.length) { const c = g.cards[0]; chooseCard(g, c.uid, viewCard(g, c).choices.findIndex(x => !x.disabled)); continue; }
    advance(g);
  }
  return g;
}

function receipt(d: ReturnType<typeof buildDeparture>, deck?: LootDeck) {
  return {
    version: 5, receiptId: `ret_${d.stopId}`, departureId: d.departureId, stopId: d.stopId, source: 'direct', endReason: 'departed',
    place: { id: d.placeId, type: 'freight', variant: 's2_graybox' }, time: { arrive: 'D1 10:30', depart: 'D1 12:00', stayGameMinutes: 90 },
    stock: {}, items: { gained: [], lost: [] },
    people: { sent: d.roster.map(p => p.id), injured: [], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [] },
    witnessed: [], placeState: { looted: 0, remainingRisk: 1 }, promises: [],
    goal: { kind: null, required: 0, earned: 0, status: 'retreat' }, extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
    symbol: null, fieldPromises: [], crew: [], defense: null,
    ...(deck ? { lootDeck: deck } : {}),
  };
}

const DECK: LootDeck = { food_shop: { n: 10, k: 7, seen: 4, hit: 3 }, garage_fuel: { n: 10, k: 3, seen: 2, hit: 0 } };

describe('덱 자리를 정차를 넘어 싣는다', () => {
  it('처음 판엔 덱 자리가 없고 계약에도 칸이 없다', () => {
    const g = atStop(createGame('deck-a'));
    expect(g.lootDeck).toBeUndefined();
    expect('lootDeck' in buildDeparture(g, { placeId: 'sulechow_station' })).toBe(false);
  });

  it('영수증의 덱 자리가 판 상태에 남고 다음 계약에 그대로 실린다(복사본)', () => {
    const g = atStop(createGame('deck-b'));
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    applyFieldReturn(g, d, receipt(d, DECK));
    expect(g.lootDeck).toEqual(DECK);
    const next = buildDeparture(g, { placeId: 'sulechow_station' });
    expect(next.lootDeck).toEqual(DECK);
    next.lootDeck!.food_shop.seen = 9;
    expect(g.lootDeck!.food_shop.seen).toBe(4);
  });

  it('덱 칸 없는 영수증은 판 상태의 덱을 건드리지 않는다', () => {
    const g = atStop(createGame('deck-c'));
    g.lootDeck = structuredClone(DECK);
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    applyFieldReturn(g, d, receipt(d));
    expect(g.lootDeck).toEqual(DECK);
  });

  it('꼴이 틀린 덱 자리는 영수증 검사에서 막힌다', () => {
    const g = atStop(createGame('deck-d'));
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    expect(() => decodeFieldReceipt(receipt(d, { pan: { n: 10, k: 5, seen: -1, hit: 0 } }))).toThrow();
    expect(() => decodeFieldReceipt({ ...receipt(d), lootDeck: { pan: { n: 10, k: 5 } } })).toThrow();
  });
});
