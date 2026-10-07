import { describe, expect, it } from 'vitest';
import { advance, chooseCard, cloneGame, createGame, createS1cGame } from '../../src/game';
import type { Game } from '../../src/game';
import { CARS } from '../../src/ui/common';
import type { Ui } from '../../src/ui/common';
import {
  H6_IDLE_MS, domesticActive, domesticOp, h6Input, h6Render, h6Summary, handleDomestic, newGame, stayLocked, trainCars,
} from '../../src/ui/domestic';
import type { DomCtx, H6Clock } from '../../src/ui/domestic';
import { applyStep } from '../../src/ui/repro';

// S1c 내정 화면의 DOM 없이 볼 수 있는 규칙: 편성 순서, 칸 순서 바꾸기 입력, H6 재기(s1c_domestic 11장, 12장).

function ui(over: Partial<Ui> = {}): Ui {
  return {
    screen: 'home', panel: null, carPop: null, cardOpen: false, stopSeen: false, overviewSel: 'tail', numbersOnly: false,
    selComm: null, dealOpen: null, cutPick: null, count: null, toast: null, debug: false, person: null, braking: false, ...over,
  };
}

/** app.ts의 step처럼 사본에 하고 바꿔 끼운다. */
function ctxFor(start: Game, u: Ui) {
  const box = { g: start, toasts: [] as string[] };
  const ctx: DomCtx = {
    game: () => box.g, ui: () => u,
    step(st) { const next = cloneGame(box.g); const text = applyStep(next, st); box.g = next; return text; },
    toast(t) { box.toasts.push(t); },
    render() {},
    reset(next) { box.g = next; },
  };
  return { box, ctx };
}

/** 첫 정차가 화물역인 시드(fr4)를 정차 준비까지 돌린다. */
function atFreight(): Game {
  const g = createS1cGame('fr4');
  for (let n = 0; n < 20 && g.phase !== 'stop'; n += 1) {
    if (g.cards.length) chooseCard(g, g.cards[0].uid, 0); else advance(g);
  }
  return g;
}

describe('홈 편성', () => {
  it('S1a 판은 원래 칸 그대로, S1c 판의 시작 편성도 같은 순서다', () => {
    expect(trainCars(createGame('a'))).toBe(CARS);
    expect(trainCars(createS1cGame('a')).map(c => c.id)).toEqual(CARS.map(c => c.id));
  });

  it('칸 순서와 덧붙인 칸을 따른다(덧붙인 칸은 꼬리 끝, 기관차는 늘 오른쪽 끝)', () => {
    const g = createS1cGame('a');
    g.dom!.cars = ['workshop', 'front', 'captain', 'guard', 'tail1', 'dining', 'medtech', 'store', 'cold', 'tail2', 'tail3'];
    g.dom!.extraCars = ['store', 'coach'];
    const ids = trainCars(g).map(c => c.id);
    expect(ids.slice(0, 3)).toEqual(['extra1', 'extra0', 'tail3']);
    expect(ids.slice(-2)).toEqual(['engine', 'loco']);
    expect(ids.indexOf('tail1')).toBeGreaterThan(ids.indexOf('dining'));
    expect(trainCars(g).find(c => c.id === 'extra1')?.comm).toBe('tail');
  });

  it('새 판은 내정 스위치를 이어 간다', () => {
    expect(newGame('x', true).dom).toBeDefined();
    expect(newGame('x', false).dom).toBeUndefined();
  });
});

describe('칸 순서 바꾸기 입력', () => {
  it('화물역에서 꼬리칸 하나를 가운데로 올리고 확정하면 편성이 바뀌고 짧게를 못 고른다', () => {
    const g0 = atFreight();
    expect(g0.stop?.place).toBe('freight');
    const u = ui({ cardOpen: true });
    const { box, ctx } = ctxFor(g0, u);
    handleDomestic('dom-tab', { tab: 'move' }, ctx);
    expect(u.panel).toBe('dom');
    for (let i = 0; i < 3; i += 1) handleDomestic('dom-move', { car: 'tail1', step: '-1' }, ctx);
    expect(u.dom!.order!.indexOf('tail1')).toBe(5);
    handleDomestic('dom-move-apply', {}, ctx);
    expect(box.g.dom!.cars.indexOf('tail1')).toBe(5);
    expect(box.g.dom!.stats.moves).toBe(1);
    expect(u.panel).toBeNull();
    expect(stayLocked(box.g, 'short')).toBe(true);
    expect(stayLocked(box.g, 'long')).toBe(false);
    expect(box.g.stop?.stay).not.toBe('short');
  });

  it('S1a 판에선 내정 단추가 아무것도 바꾸지 않는다', () => {
    const g = createGame('a');
    const before = JSON.stringify(g);
    const { box, ctx } = ctxFor(g, ui());
    expect(handleDomestic('dom-hot', { value: '3' }, ctx)).toBe(true);
    expect(JSON.stringify(box.g)).toBe(before);
    expect(handleDomestic('choose', {}, ctx)).toBe(false);
  });
});

describe('H6 재기', () => {
  it('내정 화면이 열려 있던 시간만, 30초 넘게 손을 놓은 시간은 빼고 센다', () => {
    const g = createS1cGame('h6');
    const clock: H6Clock = { since: 0, seg: null };
    // 칸 창을 연다 → 10초 뒤 레버 → 100초 손을 놓았다가 닫는다.
    h6Input(g, clock, 1_000, 'car');
    h6Render(g, ui({ carPop: 'engine' }), clock, 1_000);
    h6Input(g, clock, 11_000, 'dom-hot');
    h6Render(g, ui({ carPop: 'engine' }), clock, 11_000);
    h6Input(g, clock, 111_000, 'car');
    h6Render(g, ui(), clock, 111_000);
    // 닫힌 동안은 세지 않는다.
    h6Input(g, clock, 500_000, 'advance');
    const seg = g.dom!.h6.segs[String(g.seg)];
    expect(seg.ms).toBe(10_000 + H6_IDLE_MS);
    expect(seg.ops).toBe(1);
    expect(h6Summary(g)!.maxS).toBe(40);
  });

  it('의회와 정차 카드는 내정 시간이 아니고, 내정 카드는 내정 시간이다', () => {
    const g = createS1cGame('h6');
    expect(domesticActive(g, ui({ screen: 'council', carPop: 'engine' }))).toBe(false);
    expect(domesticActive(g, ui({ panel: 'dom' }))).toBe(true);
    expect(domesticActive(g, ui({ screen: 'overview' }))).toBe(true);
    g.cards.push({ uid: 999, kind: 'dom:bed', n: 7 });
    expect(domesticActive(g, ui({ cardOpen: true }))).toBe(true);
    expect(domesticOp(g, 'choose')).toBe(true);
    g.cards.unshift({ uid: 998, kind: 'travel' });
    expect(domesticActive(g, ui({ cardOpen: true }))).toBe(false);
    expect(domesticOp(g, 'choose')).toBe(false);
    expect(domesticOp(g, 'dom-tab')).toBe(false);
    expect(domesticActive(createGame('a'), ui({ carPop: 'engine' }))).toBe(false);
  });
});
