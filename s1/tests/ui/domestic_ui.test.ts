import { describe, expect, it } from 'vitest';
import { advance, chooseCard, cloneGame, createGame, createS1cGame } from '../../src/game';
import type { Game } from '../../src/game';
import { attachCar } from '../../src/game/domestic/cars';
import { CARS } from '../../src/ui/common';
import type { Ui } from '../../src/ui/common';
import {
  domesticActive, domesticOp, h6Input, h6Render, h6Summary, h6Visibility, handleDomestic, newGame, stayLocked, trainCars,
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

  it('칸 순서를 따른다(기관차는 늘 오른쪽 끝)', () => {
    const g = createS1cGame('a');
    g.dom!.cars = ['workshop', 'front', 'captain', 'guard', 'tail1', 'dining', 'medtech', 'store', 'cold', 'tail2', 'tail3'];
    const ids = trainCars(g).map(c => c.id);
    expect(ids.slice(0, 3)).toEqual(['tail3', 'tail2', 'cold']);
    expect(ids.slice(-2)).toEqual(['engine', 'loco']);
    expect(ids.indexOf('tail1')).toBeGreaterThan(ids.indexOf('dining'));
  });

  it('덧붙인 칸도 실제 id로 찾아 dom.cars 순서대로 그린다(꼬리 끝에 붙인 뒤 순서를 바꿔도)', () => {
    const g = createS1cGame('a');
    attachCar(g, 'store');
    attachCar(g, 'coach');
    expect(g.dom!.cars.slice(-2)).toEqual(['store1', 'coach2']);
    const ids = () => trainCars(g).map(c => c.id);
    // 붙인 직후: 오른쪽이 앞, 왼쪽이 꼬리 끝이니 d.cars를 뒤집은 순서 + 기관차
    expect(ids()).toEqual([...g.dom!.cars].reverse().concat(['engine', 'loco']));
    expect(ids().slice(0, 2)).toEqual(['coach2', 'store1']);
    // 칸 순서 바꾸기로 덧붙인 칸 둘을 가운데로 옮긴다
    const moved = g.dom!.cars.filter(c => c !== 'store1' && c !== 'coach2');
    moved.splice(5, 0, 'coach2', 'store1');
    g.dom!.cars = moved;
    expect(ids()).toEqual([...moved].reverse().concat(['engine', 'loco']));
    expect(ids().indexOf('store1')).toBeGreaterThan(0);
    const coach = trainCars(g).find(c => c.id === 'coach2');
    expect(coach?.comm).toBe('tail');
    expect(coach?.kind).toBe('comm');
    expect(trainCars(g).find(c => c.id === 'store1')?.kind).toBe('freight');
    // 기본 칸의 그림은 그대로
    for (const base of CARS) expect(trainCars(g).find(c => c.id === base.id)).toBe(base);
  });

  it('새 판은 내정 스위치를 이어 간다', () => {
    expect(newGame('x', true).dom).toBeDefined();
    expect(newGame('x', false).dom).toBeUndefined();
  });

  it('내정 켠 새 판은 새 이동 사건 묶음을 켠 채 시작하고, 내정 끈 판에는 그 칸이 없다', () => {
    expect(newGame('x', true).eventPack).toBe(true);
    expect('eventPack' in newGame('x', false)).toBe(false);
    // 끈 판을 따로 만들 수 있다(비교용). 서막을 건너뛴 판도 같다.
    expect('eventPack' in newGame('x', true, false, true, false)).toBe(false);
    expect(newGame('x', true, false, false).eventPack).toBe(true);
    expect(newGame('x', true, true).eventPack).toBe(true);
  });

  it("메뉴의 '사건 끈(켠) 새 판'은 사건만 바꾸고 시드·내정·어두운 길은 그대로 둔다", () => {
    const { box, ctx } = ctxFor(newGame('ev-1', true, true), ui());
    expect(box.g.eventPack).toBe(true);
    handleDomestic('dom-events', { on: '0' }, ctx);
    expect('eventPack' in box.g).toBe(false);
    expect([box.g.seed, !!box.g.dom, !!box.g.dark]).toEqual(['ev-1', true, true]);
    handleDomestic('dom-events', { on: '1' }, ctx);
    expect(box.g.eventPack).toBe(true);
    expect([box.g.seed, !!box.g.dom, !!box.g.dark]).toEqual(['ev-1', true, true]);
    expect(box.toasts).toEqual(['사건 끈 새 판: 시드 ev-1.', '사건 켠 새 판: 시드 ev-1.']);
  });

  it("메뉴의 '내정 켠(끈) 새 판'은 사건을 내정과 함께 켜고 끈다", () => {
    const { box, ctx } = ctxFor(newGame('ev-2', false), ui());
    handleDomestic('dom-new', { on: '1' }, ctx);
    expect([!!box.g.dom, box.g.eventPack]).toEqual([true, true]);
    handleDomestic('dom-new', { on: '0' }, ctx);
    expect(box.g.dom).toBeUndefined();
    expect('eventPack' in box.g).toBe(false);
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
  it('내정 화면이 열려 있던 시간만 센다. 손을 놓고 읽는 시간도 센다(30초 컷 없음)', () => {
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
    expect(seg.ms).toBe(110_000);
    expect(seg.ops).toBe(1);
    expect(h6Summary(g)!.maxS).toBe(110);
    // 구간 전체 시간은 화면과 상관없이 처음 그린 때부터 마지막 입력까지다.
    expect(seg.all).toBe(499_000);
  });

  it('앱이 뒤로 간 시간은 내정 시간과 구간 전체 시간에서 뺀다', () => {
    const g = createS1cGame('h6-hidden');
    const clock: H6Clock = { since: 0, seg: null };
    h6Render(g, ui({ carPop: 'engine' }), clock, 1_000);
    h6Visibility(g, clock, 21_000, true);
    h6Visibility(g, clock, 621_000, false);
    h6Input(g, clock, 631_000, 'dom-hot');
    const seg = g.dom!.h6.segs[String(g.seg)];
    expect(seg.ms).toBe(30_000);
    expect(seg.all).toBe(30_000);
  });

  it('구간 전체 시간은 평시와 위기 구간을 따로 요약한다', () => {
    const g = createS1cGame('h6-crisis');
    const clock: H6Clock = { since: 0, seg: null };
    h6Render(g, ui(), clock, 1_000);
    h6Input(g, clock, 41_000, 'advance');
    g.seg += 1;
    g.coal = 0; // 석탄 바닥: 위기 구간
    h6Render(g, ui(), clock, 41_000);
    h6Input(g, clock, 101_000, 'advance');
    const sm = h6Summary(g)!;
    expect(sm.allPeaceS).toBe(40);
    expect(sm.allCrisisS).toBe(60);
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
    expect(domesticOp(g, 'tip')).toBe(false); // 설명 글자 탭은 내정 조작이 아니다
    expect(domesticActive(createGame('a'), ui({ carPop: 'engine' }))).toBe(false);
  });
});
