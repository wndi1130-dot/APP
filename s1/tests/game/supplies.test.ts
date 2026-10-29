import { afterEach, describe, expect, it, vi } from 'vitest';
import { advance, COMMS, createGame, createS1cGame, D, P, resolveStop, STAY } from '../../src/game';
import type { Game, StayId } from '../../src/game';
import { bump, bumpParts, put } from '../../src/game/ledger';
import { applyFieldReturn, decodeFieldReceipt } from '../../src/game/field_receipt';
import type { FieldDeparture, FieldReceipt } from '../../src/game/field_receipt';
import { hygieneScore, hygieneWhy } from '../../src/game/domestic/hygiene';
import { addSupplies, enableSupplies, SUP_YIELD, SUPPLIES_PROBE, suppliesHygieneShort, suppliesNeed, suppliesRelations, suppliesUse } from '../../src/game/supplies';
import { playGame } from '../../tools/s1c_bot';
import type { BotOptions } from '../../tools/s1c_bot';

afterEach(() => {
  delete SUPPLIES_PROBE.beforeUse;
  delete SUPPLIES_PROBE.afterUse;
  delete SUPPLIES_PROBE.onGain;
});

function enabled(seed = 'sup-unit'): Game {
  const g = createGame(seed);
  enableSupplies(g);
  return g;
}

function atStop(place = 'houses', stay: StayId = 'normal', domestic = false): Game {
  const g = domestic ? createS1cGame('sup-stop') : createGame('sup-stop');
  enableSupplies(g);
  g.sup = 0;
  g.phase = 'stop';
  g.stop = { place, target: 'food', stay, crewComm: 'tail', crewSize: 4, threat: 0.8, weather: 'snow', done: false, result: null };
  return g;
}

function forDemand(stock: number): Game {
  const g = enabled('sup-demand');
  g.seg = 2;
  g.phase = 'council';
  g.coal = g.food = g.med = 10000;
  g.sup = stock;
  for (const c of COMMS) {
    Object.assign(g.comms[c], { base: [60, 60, 40, 30], rel: 0, demandCool: 0, favorCool: 99, agitateCool: 99 });
  }
  g.comms.tail.base = [0, 0, 40, 30];
  return g;
}

const departure = (): FieldDeparture => ({
  version: 1, departureId: 'dep_sup', stopId: 'stop_sup', placeId: 'place_sup', segment: 1,
  roster: [], promises: [], domestic: false,
});
const receipt = (supplies: number): FieldReceipt => ({
  version: 4, receiptId: 'ret_sup', stopId: 'stop_sup', departureId: 'dep_sup', source: 'direct', endReason: 'departed',
  place: { id: 'place_sup', type: 'factory', variant: 'variant_a' },
  time: { arrive: 'D1 10:00', depart: 'D1 10:30', stayGameMinutes: 30 },
  stock: { supplies }, items: { gained: [], lost: [] },
  people: { sent: [], injured: [], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [] },
  witnessed: [], placeState: { looted: 0, remainingRisk: 1 }, promises: [],
  goal: { kind: null, required: 0, earned: 0, status: 'retreat' },
  extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
  symbol: null, fieldPromises: [],
});

describe('생필품: 꺼진 판과 초기화', () => {
  it.each([false, true])('깃발 없음과 false는 여러 정산의 수치·카드·난수 및 판 끝 전체가 같다 (S1c=%s)', s1c => {
    const opts: BotOptions = { s1c, policy: 'caretaker', dom: 'engaged' };
    const trace = (sup?: boolean) => {
      const turns: unknown[] = [];
      const result = playGame('sp-off-proof', { ...opts, ...(sup === undefined ? {} : { sup }), probe: {
        onSettle: g => turns.push(structuredClone({ seg: g.seg, rng: g.rng, cards: g.cards, comms: g.comms,
          coal: g.coal, food: g.food, med: g.med, lux: g.lux, trust: g.trust, tension: g.tension, lastSettle: g.lastSettle })),
      } });
      return { turns, ...result };
    };
    const baseline = trace();
    expect(baseline.turns.length).toBeGreaterThan(3);
    expect(trace(false)).toEqual(baseline);
    expect(baseline.g).not.toHaveProperty('sup');
    expect(baseline.g).not.toHaveProperty('supCover');
    expect(baseline.g).not.toHaveProperty('supOn');
  });

  it('꺼진 판의 새 함수·장부는 관찰점도 상태도 난수도 건드리지 않는다', () => {
    const g = createGame('sup-noop');
    const before = structuredClone(g);
    const called = vi.fn();
    Object.assign(SUPPLIES_PROBE, { beforeUse: called, afterUse: called, onGain: called });
    expect(suppliesUse(g)).toBeUndefined();
    suppliesRelations(g, { need: 4, use: 0, cover: { tail: 0 }, plenty: true });
    addSupplies(g, 9, 'field.loot');
    bump(g, 'sup', 3, 'sup.search');
    bumpParts(g, 'sup', 4, [['sup.search', 1]]);
    put(g, 'sup', 7, 'sup.use');
    expect(called).not.toHaveBeenCalled();
    expect(g).toEqual(before);
  });

  it('켜면 8로 시작하고 아직 정산하지 않은 위생은 그대로다', () => {
    const g = createGame('sup-start');
    const rng = structuredClone(g.rng);
    const hygiene = COMMS.map(c => hygieneScore(g, c));
    enableSupplies(g);
    expect(g.sup).toBe(8);
    expect(g.supCover).toEqual({});
    expect(g.rng).toEqual(rng);
    expect(COMMS.map(c => hygieneScore(g, c))).toEqual(hygiene);
    expect(suppliesNeed(g)).toBe(4);
  });
});

describe('생필품: 소비와 배급', () => {
  it('200명은 4를 쓰고 실제 정산에서도 한 번만 쓴다', () => {
    const g = forDemand(8);
    advance(g);
    expect(g.lastSettle).not.toBeNull();
    expect(g.sup).toBe(4);
    expect(COMMS.map(c => g.supCover?.[c])).toEqual([1, 1, 1, 1, 1]);
    expect(g.ledger?.filter(r => r.k === 'sup')).toEqual([{ k: 'sup', d: -4, why: 'sup.use' }]);
  });

  it.each([false, true])('법 없음·공동 식당은 인구 비례로 같은 충족률을 받는다 (식당=%s)', kitchen => {
    const g = enabled();
    if (kitchen) g.passed.common_kitchen = 1;
    g.sup = 1.5;
    const t = suppliesUse(g)!;
    expect(t.use).toBe(1.5);
    expect(g.sup).toBe(0);
    for (const c of COMMS) expect(g.supCover?.[c]).toBe(0.375);
  });

  it('기여 배급은 일을 낸 칸부터 채우고, 쉬러 돌아온 작업조도 일한 사람으로 센다', () => {
    const g = enabled();
    for (const c of COMMS) g.comms[c].pop = 0;
    Object.assign(g.comms.tail, { pop: 80, away: 79, rel: 0 });
    Object.assign(g.comms.engine, { pop: 20, away: 0, rel: 0 });
    g.passed.contribution_ration = 1;
    g.sup = 1.8; // 꼬리칸 1.6을 먼저(작업조가 쉬러 와 있어도), 기관실 0.4의 절반을 다음으로.
    suppliesUse(g);
    expect(g.supCover?.tail).toBe(1);
    expect(g.supCover?.engine).toBeCloseTo(0.5, 12);
    expect(Object.keys(g.supCover!)).toHaveLength(2);
    expect(g.sup).toBe(0);
  });

  it('기여 배급에서 정확히 절반을 받은 칸은 뺄셈 오차로 위생 벌을 받지 않는다', () => {
    const g = enabled();
    for (const c of COMMS) g.comms[c].pop = 0;
    Object.assign(g.comms.tail, { pop: 30, away: 0 });
    Object.assign(g.comms.engine, { pop: 10, away: 0 });
    g.passed.contribution_ration = 1;
    g.sup = 0.7; // 0.7 − 0.6은 0.09999…라 그대로 나누면 0.4999…가 된다.
    suppliesUse(g);
    expect(g.supCover?.tail).toBe(1);
    expect(g.supCover?.engine).toBe(0.5);
    expect(suppliesHygieneShort(g, 'engine')).toBe(false);
  });

  it('기여 배급 나눔은 난수를 쓰지 않고 같은 판이면 같은 몫이다', () => {
    const a = enabled(), b = enabled();
    for (const g of [a, b]) { g.passed.contribution_ration = 1; g.sup = 1.8; }
    const rng = structuredClone(a.rng);
    suppliesUse(a); suppliesUse(b);
    expect(a.supCover).toEqual(b.supCover);
    expect(Object.values(a.supCover!).filter(f => f === 1).length).toBeGreaterThan(0);
    expect(a.rng).toEqual(rng);
  });

  it('인구 0인 칸은 필요량·관계·위생에서 빠지고 이전 몫도 지운다', () => {
    const g = enabled();
    g.comms.tail.pop = 0;
    g.supCover = { tail: 0 };
    g.sup = 0;
    const before = g.comms.tail.rel;
    const score = hygieneScore(g, 'tail');
    const t = suppliesUse(g)!;
    suppliesRelations(g, t);
    expect(t.need).toBeCloseTo(2.2, 12);
    expect(t.cover).not.toHaveProperty('tail');
    expect(g.comms.tail.rel).toBe(before);
    expect(hygieneScore(g, 'tail')).toBe(score);
    for (const c of COMMS) g.comms[c].pop = 0;
    expect(suppliesUse(g)).toEqual({ need: 0, use: 0, cover: {}, plenty: false });
  });

  it('소수 재고를 보존하고 모든 장부 쓰기 길에서 0 아래로 내려가지 않는다', () => {
    const g = enabled();
    g.comms.tail.pop = 91;
    const t = suppliesUse(g)!;
    expect(t.need).toBeCloseTo(4.02, 12);
    expect(g.sup).toBeCloseTo(3.98, 12);
    bump(g, 'sup', -100, 'sup.use');
    expect(g.sup).toBe(0);
    put(g, 'sup', -1, 'sup.use');
    expect(g.sup).toBe(0);
    bumpParts(g, 'sup', -1, [['sup.use', 1]]);
    expect(g.sup).toBe(0);
  });
});

describe('생필품: 관계·위생·요구', () => {
  it('모자람 관계는 각 칸의 충족률에 비례한다', () => {
    const g = enabled();
    g.sup = 1;
    const before = COMMS.map(c => g.comms[c].rel);
    suppliesRelations(g, suppliesUse(g));
    COMMS.forEach((c, i) => expect(g.comms[c].rel).toBeCloseTo(before[i] - P.supShortRel * 0.75, 9));
    expect(g.ledger?.filter(r => r.why === 'sup')).toHaveLength(5);
  });

  it.each([0, 0.4999, 0.5, 1])('위생 문턱은 엄격한 0.5 미만이다 (f=%s)', f => {
    const g = enabled();
    const score = hygieneScore(g, 'tail');
    const why = hygieneWhy(g, 'tail');
    g.sup = suppliesNeed(g) * f;
    suppliesUse(g);
    expect(hygieneScore(g, 'tail')).toBe(score - (f < 0.5 ? 1 : 0));
    expect(hygieneWhy(g, 'tail')).toBe(why + (f < 0.5 ? ' · 비누·휴지가 모자람' : ''));
    g.supOn = false;
    expect(hygieneScore(g, 'tail')).toBe(score);
    expect(hygieneWhy(g, 'tail')).toBe(why);
  });

  it('사용 후 두 구간분이 남는 경계에서 +supPlentyRel이며 관계 15 천장 밖이다', () => {
    const g = enabled();
    for (const c of COMMS) g.comms[c].rel = 20;
    g.sup = 12;
    const t = suppliesUse(g)!;
    expect(t.plenty).toBe(true);
    expect(g.sup).toBe(8);
    suppliesRelations(g, t);
    for (const c of COMMS) expect(g.comms[c].rel).toBeCloseTo(20 + P.supPlentyRel, 9);
    g.sup = 11.999;
    expect(suppliesUse(g)?.plenty).toBe(false);
    for (const c of COMMS) g.comms[c].pop = 0;
    g.comms.tail.pop = 15; // 필요량 0.3: 세 배를 채우면 쓴 뒤 0.5999…가 남아도 두 구간분이다.
    g.sup = (1 + P.supPlentyNeeds) * suppliesNeed(g);
    expect(suppliesUse(g)?.plenty).toBe(true);
  });

  it('요구를 낸 칸에만 demandCool을 +2 하고, 매 정산마다 계속 늘리지 않는다', () => {
    const normal = forDemand(8);
    const plenty = forDemand(12);
    advance(normal);
    advance(plenty);
    expect(normal.cards.find(c => c.kind === 'demand')?.comm).toBe('tail');
    expect(plenty.cards.find(c => c.kind === 'demand')?.comm).toBe('tail');
    expect(normal.comms.tail.demandCool).toBe(3);
    expect(plenty.comms.tail.demandCool).toBe(5);
    for (const c of COMMS.filter(c => c !== 'tail')) expect(plenty.comms[c].demandCool).toBe(0);
    plenty.cards = [];
    plenty.phase = 'council';
    plenty.sup = 12;
    advance(plenty);
    expect(plenty.comms.tail.demandCool).toBe(4);
  });
});

describe('생필품: 정차 입고', () => {
  it.each(Object.entries(SUP_YIELD))('%s 장소 표와 맡긴 수색 덤 +1을 장부에 따로 적는다', (place, yieldAmount) => {
    const g = atStop(place);
    const off = structuredClone(g);
    delete off.supOn; delete off.sup; delete off.supCover;
    resolveStop(off, true);
    resolveStop(g, true);
    expect(g.sup).toBe(yieldAmount + 1);
    expect(g.rng).toEqual(off.rng);
    expect(g.stop?.result?.gains).toEqual(off.stop?.result?.gains);
    expect(g.ledger?.filter(r => r.k === 'sup')).toEqual([
      { k: 'sup', d: yieldAmount, why: 'stop.loot' }, { k: 'sup', d: 1, why: 'sup.search' },
    ]);
    expect(resolveStop(g, true)).toBeNull();
    expect(g.sup).toBe(yieldAmount + 1);
  });

  it.each(['short', 'normal', 'long'] as const)('%s 체류는 부산물에만 곱하고 덤은 +1이다', stay => {
    const g = atStop('houses', stay);
    resolveStop(g, true);
    expect(g.sup).toBeCloseTo(5 * STAY[stay].mult + 1, 12);
  });

  it('비상식량감축법은 부산물과 수색 덤 양쪽에 ×0.8이다', () => {
    const g = atStop();
    g.passed.emergency_ration = 1;
    resolveStop(g, true);
    expect(g.sup).toBeCloseTo(4.8, 12);
    expect(g.ledger?.find(r => r.k === 'sup' && r.why === 'sup.search')?.d).toBeCloseTo(0.8, 12);
  });

  it('목재·고철과 같은 공방 동행 보정과 아동 노동 보정을 받는다', () => {
    const g = atStop('houses', 'long', true);
    g.dom!.escort = g.dom!.people.find(p => p.field === 'craft')!.id;
    g.passed.child_labor = 1;
    resolveStop(g, true);
    expect(g.sup).toBeCloseTo(5 * 1.4 * 1.15 * D.escortMaterials + 1, 12);
    expect(g.dom!.escort).toBeNull();
  });

  it('지나치기에는 수색 덤도 부산물도 없고 꺼진 판에는 재고를 만들지 않는다', () => {
    const g = atStop();
    resolveStop(g, false);
    expect(g.sup).toBe(0);
    const off = atStop();
    delete off.supOn; delete off.sup; delete off.supCover;
    resolveStop(off, true);
    expect(off).not.toHaveProperty('sup');
    expect(off.ledger?.some(r => r.k === 'sup')).toBe(false);
  });
});

describe('생필품: 필드 영수증', () => {
  it.each([false, true])('supplies를 검증하고 켠 판만 담는다 (켬=%s)', on => {
    const g = createGame('sup-field');
    if (on) enableSupplies(g);
    const r = receipt(3);
    expect(decodeFieldReceipt(r).stock.supplies).toBe(3);
    expect(applyFieldReturn(g, departure(), r).status).toBe('applied');
    expect(g.sup).toBe(on ? P.sup0 + 3 : undefined);
    expect(g.ledger?.filter(x => x.k === 'sup') ?? []).toEqual(on ? [{ k: 'sup', d: 3, why: 'field.loot' }] : []);
    expect(applyFieldReturn(g, departure(), r).status).toBe('duplicate');
    expect(g.sup).toBe(on ? P.sup0 + 3 : undefined);
  });

  it('음수는 가진 만큼만 빼고 소수·모르는 키는 영수증 검사에서 거른다', () => {
    const g = enabled('sup-field-negative');
    const result = applyFieldReturn(g, departure(), receipt(-10));
    expect(g.sup).toBe(0);
    expect(result.record.lines.find(l => l.k === 'stock')?.text).toContain('부족 2');
    expect(g.ledger?.find(r => r.k === 'sup')?.d).toBe(-8);
    expect(() => decodeFieldReceipt(receipt(1.5))).toThrow();
    expect(() => decodeFieldReceipt({ ...receipt(1), stock: { supplies_typo: 2 } })).toThrow();
  });
});
