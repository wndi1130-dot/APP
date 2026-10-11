import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import { addWound, unnamedInjured, woundView } from '../../src/game/wounds';
import type { Ui, View } from '../../src/ui/common';
import { trainCars } from '../../src/ui/domestic';
import { trainButtons, woundRows } from '../../src/ui/train';

// 의료 단추의 부상 명부(결정 042): 화면은 받은 줄을 그대로 적고, 누른 칸 사람만 위로 올린다.

function mk(seed: string) {
  const g = createS1cGame(seed);
  const ui = { screen: 'train', panel: null, carPop: 'tail1', cardOpen: false, stopSeen: false } as unknown as Ui;
  const view = { g, ui } as View;
  const car = (id: string) => trainCars(g).find(c => c.id === id)!;
  return { g, ui, view, car };
}

describe('부상 명부 판', () => {
  it('의무칸에서 열면 받은 순서 그대로다', () => {
    const { g, view, car } = mk('med-1');
    addWound(g, { who: '가', comm: 'tail', from: 'stop', where: '화물역', grade: 'deep', part: 'legL', septic: false });
    addWound(g, { who: '나', comm: 'guard', from: 'stop', where: '화물역', grade: 'fracture', part: 'armR', septic: false });
    expect(woundRows(view, car('medtech')).map(r => r.id)).toEqual(woundView(g).map(r => r.id));
  });

  it('다른 칸에서 열면 그 칸 사람만 위로 올리고 나머지 순서는 안 바꾼다', () => {
    const { g, view, car } = mk('med-2');
    addWound(g, { who: '가', comm: 'tail', from: 'stop', where: '화물역', grade: 'deep', part: 'legL', septic: false });
    addWound(g, { who: '나', comm: 'guard', from: 'stop', where: '화물역', grade: 'fracture', part: 'armR', septic: false });
    addWound(g, { who: '다', comm: 'tail', from: 'stop', where: '화물역', grade: 'light', part: 'head', septic: false });
    expect(woundRows(view, car('guard')).map(r => r.who)).toEqual(['나', '가', '다']);
    expect(woundRows(view, car('tail1')).map(r => r.who)).toEqual(['가', '다', '나']);
  });

  it('명부에 이름이 없는 몫은 수로만 남는다', () => {
    const { g } = mk('med-3');
    g.injured = 3;
    expect(woundView(g)).toEqual([]);
    expect(unnamedInjured(g)).toBe(3);
  });

  it('의료 단추는 명부를 펼쳤을 때만 눌린 꼴이고 다친 수를 단다', () => {
    const { g, ui, view, car } = mk('med-4');
    g.injured = 2;
    const btn = () => trainButtons(view, car('tail1')).find(b => b.id === 'medical')!;
    expect(btn().on).toBe(false);
    expect(btn().badge).toBe('2');
    expect(btn().data['data-action']).toBe('dom-med');
    ui.dom = { tab: 'workshop', node: null, order: null, mats: false, med: true };
    expect(btn().on).toBe(true);
  });
});
