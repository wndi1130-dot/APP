import { describe, expect, it } from 'vitest';
import {
  attachCar, chooseCard, createS1cGame, D, extraCarCoal, forecast, LOCO, LOCO_DEFAULT, LOCO_IDS, locoIdOf, locoPressureChance, locoUnchosen, rollBreakdown, rollUsefulCar, setLoco,
  viewCard,
} from '../../src/game';
import type { Game, LocoId } from '../../src/game';
import { playGame } from '../../tools/s1c_bot';

// 기관차 넷(결정 125·126·132). 이름·숫자는 가안이라 값이 아니라 기관차마다 달라지는 자리가 맞는지 본다.

function fresh(loco?: LocoId, seed = 'loco'): Game {
  const g = createS1cGame(seed);
  if (loco) setLoco(g, loco);
  return g;
}

describe('기관차 넷', () => {
  it('안 고른 판과 옛 저장은 c3이고, 고르면 일대기 첫 줄에 이름이 남는다', () => {
    const g = createS1cGame('loco');
    expect(g.loco).toBeUndefined();
    expect(locoIdOf(g)).toBe(LOCO_DEFAULT);
    expect(LOCO_DEFAULT).toBe('c3');
    setLoco(g, 'c2');
    expect(g.loco).toBe('c2');
    expect(g.journal.some(j => j.text.includes(LOCO.c2.name))).toBe(true);
    expect(JSON.parse(JSON.stringify(g)).loco).toBe('c2');
  });

  it('구간 석탄: c1은 c3보다 +0.5, c2는 −1. 이유 목록에 기관차 줄이 있다', () => {
    const base = forecast(fresh('c3')).coal;
    expect(forecast(fresh('c1')).coal).toBeCloseTo(base + 0.5);
    expect(forecast(fresh('c2')).coal).toBeCloseTo(base - 1);
    expect(forecast(fresh('c4')).coal).toBe(base);
  });

  it('붙인 칸의 석탄: c1은 0, 나머지는 기본값', () => {
    for (const id of LOCO_IDS) {
      const g = fresh(id);
      attachCar(g, 'store');
      attachCar(g, 'coach');
      expect(extraCarCoal(g)).toBeCloseTo(id === 'c1' ? 0 : 2 * D.extraCarCoal);
    }
  });

  it('측선 칸: c3은 안 붙고, c1은 기본의 두 배로 걸린다', () => {
    const count = (id: LocoId): number => {
      let n = 0;
      for (let i = 0; i < 400; i += 1) {
        const g = fresh(id, `car-${i}`);
        g.stop = { place: 'freight' } as never;
        rollUsefulCar(g);
        n += g.cards.filter(c => c.kind === 'dom:car').length;
      }
      return n;
    };
    expect(count('c3')).toBe(0);
    const c2 = count('c2');
    const c1 = count('c1');
    expect(c2).toBeGreaterThan(0);
    expect(c1).toBeGreaterThan(c2 * 1.3);
  });

  it('측선 칸은 자재를 내고 고쳐 단다: 모자라면 막히고, 고르면 목재·고철이 빠진다(결정 426 카드 ④ 나)', () => {
    for (const [n, kind] of [[1, 'coach'], [0, 'store']] as const) {
      const g = fresh('c2');
      g.cards = [];
      const [wood, scrap] = kind === 'coach' ? [D.coachWood, D.coachScrap] : [D.wagonWood, D.wagonScrap];
      g.dom!.wood = wood - 1;
      g.dom!.scrap = scrap + 5;
      g.cards.push({ uid: 900, kind: 'dom:car', n });
      expect(viewCard(g, g.cards[0]).choices[0].disabled, kind).toBe('목재가 모자라다');
      expect(chooseCard(g, 900, 0), kind).toBe(false);
      expect(g.dom!.extraCars, kind).toEqual([]);
      g.dom!.wood = wood + 2;
      const v = viewCard(g, g.cards[0]);
      expect(v.choices[0].disabled, kind).toBeUndefined();
      expect(v.choices[0].extra?.[0], kind).toContain(`목재 −${wood}`);
      expect(chooseCard(g, 900, 0), kind).toBe(true);
      expect(g.dom!.extraCars, kind).toEqual([kind]);
      expect(g.dom!.wood, kind).toBe(2);
      expect(g.dom!.scrap, kind).toBe(5);
    }
  });

  it('고장: c3은 안 나고, c4는 부품 4가 있어야 막는다', () => {
    D.breakChance = 1;
    try {
      const a = fresh('c3');
      a.dom!.parts = 0;
      rollBreakdown(a);
      expect(a.cards.some(c => c.kind === 'dom:short')).toBe(false);
      const b = fresh('c4');
      b.dom!.parts = 3;
      rollBreakdown(b);
      expect(b.cards.some(c => c.kind === 'dom:short')).toBe(true);
      const c = fresh('c4');
      c.dom!.parts = 5;
      rollBreakdown(c);
      expect(c.dom!.parts).toBe(1);
      expect(c.cards.some(x => x.kind === 'dom:short')).toBe(false);
    } finally {
      D.breakChance = 0.1;
    }
  });

  it('압력 경고: c2는 숙련과 상관없이 늘 뜰 수 있고, 다른 기관차는 숙련 1일 때만', () => {
    expect(locoPressureChance(fresh('c2'), 0)).toBe(LOCO.c2.pressureChance);
    expect(locoPressureChance(fresh('c3'), 0)).toBeNull();
    expect(locoPressureChance(fresh('c3'), 1)).toBe(D.pressureChance);
  });

  it('넷 모두 끝까지 돌고, 같은 시드·같은 기관차면 같은 판이다', () => {
    for (const id of LOCO_IDS) {
      const a = playGame('loco-run', { s1c: true, policy: 'caretaker', dom: 'engaged', loco: id }).g;
      const b = playGame('loco-run', { s1c: true, policy: 'caretaker', dom: 'engaged', loco: id }).g;
      expect(a.phase).toBe('end');
      expect(a.loco).toBe(id);
      expect(JSON.stringify(a)).toBe(JSON.stringify(b));
    }
  });
});

describe('첫 화면 「열차를 고른다」', () => {
  it('안 고른 새 판만 묻고, 고르면 묻지 않으며, 달리는 옛 저장은 묻지 않는다', () => {
    const g = createS1cGame('pick');
    expect(locoUnchosen(g)).toBe(true);
    setLoco(g, 'c1');
    expect(locoUnchosen(g)).toBe(false);
    const old = createS1cGame('pick-old');
    old.seg = 5;
    expect(locoUnchosen(old)).toBe(false);
  });
});
