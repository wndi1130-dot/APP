import { describe, expect, it } from 'vitest';
import { createS1cGame, techMult } from '../../src/game';
import { workshopGauge, workshopHalt, workshopHands, workshopSlots } from '../../src/ui/domestic';

// 공방 판(설계 4부 1절): 세 덩이와 개량 자리에 올리는 값은 화면이 따로 셈하지 않고 있는 값을 읽는다.

describe('공방 판', () => {
  it('아무것도 안 올렸으면 계기가 없다', () => {
    const g = createS1cGame('wsb');
    g.dom!.restoring = null;
    g.dom!.job = null;
    expect(workshopGauge(g)).toBeNull();
  });

  it('복원과 개조가 다 있으면 차례가 앞인 것을 계기에 올린다', () => {
    const g = createS1cGame('wsb');
    const d = g.dom!;
    d.restoring = 'w1';
    d.techs.w1 = { stage: 'restoring', progress: 3, need: 6 } as NonNullable<typeof d.techs.w1>;
    d.job = { kind: 'armor', car: 'tail1', progress: 1, need: 4 } as NonNullable<typeof d.job>;
    d.order = ['parts', 'modify', 'restore'];
    expect(workshopGauge(g)!.head.startsWith('개조')).toBe(true);
    expect(workshopGauge(g)!.pct).toBe(25);
    d.order = ['parts', 'restore', 'modify'];
    expect(workshopGauge(g)!.head.startsWith('복원')).toBe(true);
    expect(workshopGauge(g)!.pct).toBe(50);
  });

  it('손은 살아서 열차에 있는 공작 분야 사람 수다', () => {
    const g = createS1cGame('wsb');
    const craft = g.dom!.people.filter(p => p.field === 'craft');
    const who = workshopHands(g);
    expect(who.hands).toBe(craft.length);
    expect(who.chief?.role).toBe('공방장');
    expect(who.pupil?.role).toBe('용접공');
    craft[craft.length - 1].alive = false;
    expect(workshopHands(g).hands).toBe(craft.length - 1);
  });

  it('개량 자리는 셋이고 코드에 없는 둘은 비어 있다', () => {
    const g = createS1cGame('wsb');
    const slots = workshopSlots(g);
    expect(slots.map(s => s.name)).toEqual(['공구', '—', '—']);
    expect(slots[0].state === 'on').toBe(techMult(g, 'w1') > 0);
    expect(slots.slice(1).every(s => s.state === 'none')).toBe(true);
  });

  it('고장을 못 고친 서류가 있으면 멈춤과 가진 부품 수를 적는다', () => {
    const g = createS1cGame('wsb');
    g.dom!.parts = 1;
    g.cards.push({ uid: 999, kind: 'dom:short', n: 0, text: 'break' } as (typeof g.cards)[number]);
    expect(workshopHalt(g)).toBe('멈춤 · 부품 1');
  });
});
