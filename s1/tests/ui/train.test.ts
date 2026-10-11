import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import type { Ui } from '../../src/ui/common';
import { domesticActive, trainCars } from '../../src/ui/domestic';
import { stripName, trainButtons, trainSel } from '../../src/ui/train';

// 열차 관리 화면(사용자 2026-10-11): 칸을 누르면 화면 전체가 바뀐다. 위 띠, 칸 판, 아래 단추 여섯.

function mkUi(over: Partial<Ui> = {}): Ui {
  return {
    screen: 'train', panel: null, carPop: 'tail2', cardOpen: false, stopSeen: false, overviewSel: 'tail', numbersOnly: false,
    selComm: null, dealOpen: null, cutPick: null, count: null, toast: null, person: null, braking: false, debug: false, ...over,
  };
}

describe('열차 관리 화면', () => {
  it('띠의 칸 이름은 네 글자까지이고 꼬리칸 셋은 번호로 갈린다', () => {
    const g = createS1cGame('train-strip');
    const names = trainCars(g).map(stripName);
    for (const n of names) expect(n.length).toBeLessThanOrEqual(4);
    expect(names.filter(n => n.startsWith('꼬리')).sort()).toEqual(['꼬리1', '꼬리2', '꼬리3']);
    expect(new Set(names).size).toBe(names.length);
  });

  it('기관차나 없는 칸을 고르면 기관실 판을 보인다', () => {
    const g = createS1cGame('train-sel');
    expect(trainSel(g, 'tail2').id).toBe('tail2');
    expect(trainSel(g, 'loco').id).toBe('engine');
    expect(trainSel(g, null).id).toBe('engine');
    expect(trainSel(g, '없는칸').id).toBe('engine');
  });

  it('단추는 여섯이고 글은 다섯 자 안팎, 줄 전체는 서른 자를 안 넘는다', () => {
    const g = createS1cGame('train-btns');
    const ui = mkUi();
    const btns = trainButtons({ g, ui }, trainSel(g, ui.carPop));
    expect(btns.map(b => b.label)).toEqual(['연구', '개조', '공방', '사람·매뉴얼', '정치', '의료']);
    for (const b of btns) expect(b.label.length).toBeLessThanOrEqual(6);
    expect(btns.reduce((n, b) => n + b.label.length + (b.badge?.length ?? 0), 0)).toBeLessThanOrEqual(30);
  });

  it('정치 단추는 회기 밖에선 꺼져 있고 남은 구간을 적는다. 회기에는 의회로 가는 문이다', () => {
    const g = createS1cGame('train-pol');
    const ui = mkUi();
    const off = trainButtons({ g, ui }, trainSel(g, ui.carPop)).find(b => b.id === 'politics')!;
    expect(off.off).toBe(true);
    expect(off.badge).toMatch(/구간/);
    g.phase = 'council';
    const on = trainButtons({ g, ui }, trainSel(g, ui.carPop)).find(b => b.id === 'politics')!;
    expect(on.off).toBe(false);
    expect(on.data).toMatchObject({ 'data-action': 'go', 'data-screen': 'council' });
  });

  it('공방·의료 단추는 그 칸의 판을 열고, 그 칸을 보고 있으면 눌린 채로 보인다', () => {
    const g = createS1cGame('train-on');
    const at = (carPop: string) => trainButtons({ g, ui: mkUi({ carPop }) }, trainSel(g, carPop));
    expect(at('workshop').find(b => b.id === 'workshop')!.on).toBe(true);
    expect(at('medtech').find(b => b.id === 'medical')!.on).toBe(true);
    expect(at('tail2').filter(b => b.on)).toHaveLength(0);
    expect(at('tail2').find(b => b.id === 'workshop')!.data).toMatchObject({ 'data-car': 'workshop', 'data-keep': '1' });
  });

  it('열차 관리 화면에 있는 시간은 내정 시간으로 센다', () => {
    const g = createS1cGame('train-h6');
    expect(domesticActive(g, mkUi())).toBe(true);
    expect(domesticActive(g, mkUi({ carPop: null }))).toBe(true);
    expect(domesticActive(g, mkUi({ screen: 'home', carPop: null }))).toBe(false);
  });
});
