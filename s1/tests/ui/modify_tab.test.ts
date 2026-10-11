import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import type { Ui, View } from '../../src/ui/common';
import { carMods, trainCars } from '../../src/ui/domestic';
import { trainButtons } from '../../src/ui/train';

// 개조 단추(사용자 2026-10-11 「개조를 누르니 만들기가 뜬다」): 만들기가 아니라 개조 화면을 연다.

describe('개조 화면으로 가는 길', () => {
  it('열차 관리 화면의 개조 단추는 개조 탭을 열고, 그 탭일 때만 눌린 꼴이다', () => {
    const g = createS1cGame('mod-1');
    const ui = { screen: 'train', panel: null, carPop: 'tail1', cardOpen: false, stopSeen: false } as unknown as Ui;
    const view = { g, ui } as View;
    const car = trainCars(g).find(c => c.id === 'tail1')!;
    const btn = () => trainButtons(view, car).find(b => b.id === 'modify')!;
    expect(btn().data).toMatchObject({ 'data-action': 'dom-tab', 'data-tab': 'modify' });
    expect(btn().on).toBe(false);
    ui.panel = 'dom';
    ui.dom = { tab: 'workshop', node: null, order: null, mats: false };
    expect(btn().on).toBe(false);
    ui.dom.tab = 'modify';
    expect(btn().on).toBe(true);
  });

  it('칸에 한 개조를 이름으로 준다', () => {
    const g = createS1cGame('mod-2');
    expect(carMods(g, 'tail1')).toEqual([]);
    g.dom!.insulated.push('tail1');
    g.dom!.armored.push('tail1');
    expect(carMods(g, 'tail1')).toEqual(['단열', '장갑']);
    expect(carMods(g, 'tail2')).toEqual([]);
  });
});
