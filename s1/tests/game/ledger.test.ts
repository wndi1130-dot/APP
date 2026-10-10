import { describe, expect, it } from 'vitest';
import { bump, bumpRel, createS1cGame, drain, LEDGER_MAX, put, viewCard } from '../../src/game';
import { RUNS, start, stepOnce } from '../golden/trace';
import { WHY_NAME } from '../../src/ui/why_names';
import { applyStep, namedSums } from '../../src/ui/repro';

// 까닭 장부(ledger.ts): 숫자는 그대로 두고 「무엇 때문에」만 같이 적는다. 숫자 불변은 golden.test.ts가 본다.

describe('까닭 장부', () => {
  it('실제로 바뀐 만큼만 적는다: 잘린 값, 0은 안 적음, 통째로 놓기', () => {
    const g = createS1cGame('led-1');
    g.trust = 98; g.med = 2; g.coal = 5; g.tension = 30;
    bump(g, 'trust', 5, 'promise');
    bump(g, 'med', -5, 'sick', { floor0: true });
    bump(g, 'coal', -9, 'need');
    bump(g, 'food', 0, 'need');
    put(g, 'tension', 65, 'card');
    g.comms.tail.rel = 97;
    bumpRel(g, 'tail', 10, 'tech');
    expect([g.trust, g.med, g.coal, g.tension, g.comms.tail.rel]).toEqual([100, 0, -4, 65, 100]);
    expect(drain(g)).toEqual([
      { k: 'trust', d: 2, why: 'promise' }, { k: 'med', d: -2, why: 'sick' }, { k: 'coal', d: -9, why: 'need' },
      { k: 'tension', d: 35, why: 'card' }, { k: 'rel:tail', d: 3, why: 'tech' },
    ]);
    expect('ledger' in g).toBe(false);
    expect(drain(g)).toEqual([]);
  });

  it('화면 없이 오래 돌려도 상한을 넘지 않는다', () => {
    const g = createS1cGame('led-2');
    for (let i = 0; i < LEDGER_MAX * 3; i += 1) bump(g, 'coal', 1, 'need');
    expect(g.ledger?.length).toBe(LEDGER_MAX);
  });

  it('이름별로 모으면 반올림한 정수가 되고, 이름 없는 까닭(card)은 빠진다', () => {
    const sums = namedSums([
      { k: 'med', d: -1, why: 'sick' }, { k: 'med', d: -2, why: 'sick' }, { k: 'trust', d: 0.6, why: 'promise' },
      { k: 'rel:tail', d: -4, why: 'need' }, { k: 'coal', d: 9, why: 'card' },
    ]);
    expect(sums.get(WHY_NAME.sick)?.med).toBe(-3);
    expect(sums.get(WHY_NAME.promise)?.trust).toBe(1);
    expect(sums.get(WHY_NAME.need)?.rel.tail).toBe(-4);
    expect(sums.size).toBe(3);
  });

  it('장부가 쓰는 열쇠는 모두 화면 이름이 있거나 card다', () => {
    const seen = new Set<string>();
    for (const r of RUNS) {
      const g = start(r);
      for (let n = 0; n < 4000 && stepOnce(g, r, n); n += 1) for (const row of drain(g)) seen.add(row.why);
    }
    expect(seen.size).toBeGreaterThan(3);
    for (const why of seen) expect(why === 'card' || why in WHY_NAME, why).toBe(true);
  });

  it('화면 행동마다 까닭 줄의 합은 보이는 값의 차이와 같고, 판에 장부가 남지 않는다', () => {
    const g = createS1cGame('led-3');
    let split = 0;
    const names = new Set<string>();
    for (let n = 0; n < 400 && g.phase !== 'end'; n += 1) {
      const was = { trust: Math.round(g.trust), tension: Math.round(g.tension), med: Math.round(g.med), coal: Math.round(g.coal), m: g.meterLog?.length ?? 0, r: g.resLog?.length ?? 0 };
      const card = g.cards.find(c => viewCard(g, c).choices.some(ch => !ch.disabled));
      if (card) applyStep(g, { a: 'choose', d: { uid: String(card.uid), index: String(viewCard(g, card).choices.findIndex(ch => !ch.disabled)) } });
      else if (g.phase === 'stop' && g.stop && !g.stop.done) applyStep(g, { a: 'stop-go', d: { go: '1' } });
      else if (g.phase === 'council' && g.council && !g.council.result) applyStep(g, { a: 'vote', d: {} });
      else applyStep(g, { a: 'advance', d: {} });
      expect('ledger' in g).toBe(false);
      // 기록이 상한에 닿기 전까지만 줄 수로 새 줄을 가려낸다
      const meter = (g.meterLog ?? []).slice(was.m);
      const res = (g.resLog ?? []).slice(was.r);
      if ((g.meterLog?.length ?? 0) < 12) expect(meter.reduce((a, x) => a + x.trust, 0)).toBe(Math.round(g.trust) - was.trust);
      if ((g.resLog?.length ?? 0) < 24) expect(res.reduce((a, x) => a + x.med, 0)).toBe(Math.round(g.med) - was.med);
      for (const x of [...meter, ...res]) if (x.sys && x.label !== '구간 정산') { split += 1; names.add(x.label); }
    }
    expect(split, [...names].join(', ')).toBeGreaterThan(0);
    for (const name of names) expect(Object.values(WHY_NAME)).toContain(name);
  });
});
