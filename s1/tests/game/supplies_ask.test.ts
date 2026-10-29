import { describe, expect, it } from 'vitest';
import {
  addCard, advance, chooseCard, COMMS, CONDITIONS, costLines, createGame, createS1cGame,
  openConditions, S1_IDLE_TECHS, usefulVariant, viewCard,
} from '../../src/game';
import type { Comm, Game } from '../../src/game';
import { enableSupplies, SUPPLIES_BOT, suppliesNeed } from '../../src/game/supplies';

function fresh(on = true): Game {
  const g = createGame('sup-ask');
  if (on) enableSupplies(g);
  return g;
}

function favor(g: Game, comm: Comm) {
  addCard(g, { kind: 'favor', comm });
  const card = g.cards[g.cards.length - 1];
  return { card, view: viewCard(g, card) };
}

describe('생필품 이름을 댄 공개 협상', () => {
  it.each(COMMS)('%s: 켠 판의 순환 조건에만 정한 이름과 값이 나온다', c => {
    const expected = {
      tail: ['give_sup', '아이들 겨울옷', 2], engine: ['give_sup', '장갑·헌 옷', 1],
      guard: ['give_sup', '면도칼·헌 옷', 1], medtech: ['give_sup', '비누·휴지', 2],
      front: ['give_fine', '책 한 권(좋은 물건)', 1],
    }[c];
    const [kind, label, amount] = expected;
    expect(CONDITIONS[c].filter(x => x.sup)).toEqual([{ kind, label, amount, now: false, sup: true }]);
    for (const domestic of [false, true]) {
      const g = domestic ? createS1cGame('sup-offer') : fresh(false);
      const off = Array.from({ length: 20 }, (_, i) => { g.session = i; return openConditions(g, c); });
      expect(off.flat().some(x => x.sup)).toBe(false);
      enableSupplies(g);
      const on = Array.from({ length: 20 }, (_, i) => { g.session = i; return openConditions(g, c); });
      expect(on.flat()).toContainEqual({ kind, label, amount, now: false, sup: true });
      expect(on.every(xs => xs.length === 3)).toBe(true);
      SUPPLIES_BOT.set(g, { make: 'last', ask: false });
      const previous = Array.from({ length: 20 }, (_, i) => { g.session = i; return openConditions(g, c); });
      expect(previous).toEqual(off);
    }
  });

  it.each([
    ['tail', 'sup', 2], ['front', 'supFine', 1],
  ] as const)('%s의 약속은 기한에 수량이 있으면 내고, 모자라면 내지 않고 깬다', (c, resource, amount) => {
    for (const enough of [true, false]) {
      const g = fresh();
      g.phase = 'council';
      g.seg = 3;
      g.coal = g.food = g.med = 10000;
      const stock = enough ? amount : amount - 0.5;
      // 생필품은 약속 판정 전에 생활 배급부터 한다. 그 뒤의 재고로 판정한다.
      g.sup = resource === 'sup' ? suppliesNeed(g) + stock : 100;
      if (resource === 'supFine') g.supFine = stock;
      const cond = CONDITIONS[c].find(x => x.sup)!;
      g.comms[c].promise = { kind: 'open', cond, label: cond.label, due: g.seg, madeSession: 0 };
      advance(g);
      expect(g[resource]).toBeCloseTo(enough ? 0 : stock);
      expect(g.comms[c].promise).toBeNull();
      expect(g.stats.promisesKept).toBe(enough ? 1 : 0);
      expect(g.stats.promisesBroken).toBe(enough ? 0 : 1);
      if (resource === 'sup') {
        expect(g.ledger?.filter(x => x.k === 'sup' && x.why === 'promise'))
          .toEqual(enough ? [{ k: 'sup', d: -amount, why: 'promise' }] : []);
      }
    }
  });
});

describe('사적인 부탁의 생필품과 좋은 물건', () => {
  it.each([
    ['tail', 2, '"아이들 겨울옷이 모자라다. 두 벌만."'],
    ['medtech', 1, '"비누가 없어 손을 못 씻는다. 한 상자만."'],
  ] as const)('%s의 첫 부탁만 생필품으로 낸다', (c, amount, body) => {
    const g = fresh();
    const before = { sup: g.sup!, med: g.med, lux: g.lux, base: structuredClone(g.comms) };
    const { card, view } = favor(g, c);
    expect(view.body).toBe(body);
    expect(costLines(view.choices[0])).toEqual([`생필품 −${amount}`]);
    expect(chooseCard(g, card.uid, 0)).toBe(true);
    expect(g.sup).toBe(before.sup - amount);
    expect(g.med).toBe(before.med);
    expect(g.lux).toBe(before.lux);
    for (const comm of COMMS) expect(g.comms[comm].base).toEqual(before.base[comm].base);
    expect(g.comms[c].debt).toBe(true);
    const off = structuredClone(g);
    off.supOn = false;
    expect(favor(g, c).view).toEqual(favor(off, c).view);
  });

  it.each(['engine', 'guard', 'front'] as const)('%s의 원래 첫 부탁은 그대로다', c => {
    const g = fresh();
    const off = structuredClone(g);
    off.supOn = false;
    expect(favor(g, c).view).toEqual(favor(off, c).view);
  });

  it('생필품이 모자란 부탁은 막고 거절은 남긴다', () => {
    const g = fresh();
    g.sup = 1;
    const { card, view } = favor(g, 'tail');
    expect(view.choices[0].disabled).toBe('생필품이 모자라다');
    const before = structuredClone(g);
    expect(chooseCard(g, card.uid, 0)).toBe(false);
    expect(g).toEqual(before);
    expect(view.choices.find(x => x.id === 'refuse')?.disabled).toBeUndefined();
  });

  it.each(COMMS)('%s: 좋은 물건은 첫·반복 부탁 모두 원래 값 전체를 대신하고 관계와 빚을 준다', c => {
    for (const repeat of [false, true]) {
      const g = fresh();
      if (repeat) {
        const first = favor(g, c);
        expect(chooseCard(g, first.card.uid, first.view.choices.findIndex(x => x.id === 'refuse'))).toBe(true);
      }
      g.sup = g.med = g.lux = 0;
      g.supFine = 1;
      const before = structuredClone(g);
      const { card, view } = favor(g, c);
      const index = view.choices.findIndex(x => x.id === 'grant_fine');
      expect(index).toBeGreaterThanOrEqual(0);
      expect(view.choices[index].effs).toEqual([{ t: 'supFine', v: -1 }, { t: 'debt', c }, { t: 'rel', c, v: 2 }]);
      expect(costLines(view.choices[index])).toEqual(['좋은 물건 −1']);
      expect(chooseCard(g, card.uid, index)).toBe(true);
      expect(g.supFine).toBe(0);
      expect([g.sup, g.med, g.lux]).toEqual([0, 0, 0]);
      for (const comm of COMMS) expect(g.comms[comm].base).toEqual(before.comms[comm].base);
      expect(g.comms[c].rel).toBe(before.comms[c].rel + 2);
      expect(g.comms[c].debt).toBe(true);
      expect(g.comms[c].favorCool).toBe(4);
      expect(g.eventLog[`favor:${c}`]?.pick).toBe('grant_fine');
    }
  });

  it.each([undefined, 0, 0.9])('좋은 물건 %s이면 선택지가 없다', stock => {
    const g = fresh();
    if (stock !== undefined) g.supFine = stock;
    for (const c of COMMS) expect(favor(g, c).view.choices.some(x => x.id === 'grant_fine')).toBe(false);
  });

  it('끈 판과 이전 규칙 대조군은 좋은 물건이 있어도 원래 부탁만 보인다', () => {
    const off = fresh(false);
    off.supFine = 1;
    const prior = structuredClone(off);
    enableSupplies(prior);
    SUPPLIES_BOT.set(prior, { make: 'last', ask: false });
    for (const c of COMMS) {
      const original = favor(off, c).view;
      expect(original.choices.map(x => x.id)).toEqual(['grant', 'refuse']);
      expect(favor(prior, c).view).toEqual(original);
    }
  });
});

it('w8은 놀리는 목록에서 빠지고 켠 판에서만 쓸모가 열린다', () => {
  expect(S1_IDLE_TECHS).not.toContain('w8');
  const g = createS1cGame('sup-w8');
  expect(usefulVariant(g, 'w8')).toBeNull();
  enableSupplies(g);
  expect(usefulVariant(g, 'w8')).toBeUndefined();
  SUPPLIES_BOT.set(g, { make: 'last', ask: false });
  expect(usefulVariant(g, 'w8')).toBeNull();
});
