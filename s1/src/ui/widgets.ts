import { LEVER_NAMES, lawFloor, situation } from '../game';
import type { Comm, Game } from '../game';
import { cx, h, s } from './dom';
import { icon } from './icons';
import { darkLeverFloor } from './dark_lock'; // S1b 계엄 중 경비대 배급 잠금

// 레버와 반원 계기(배의 기관 전령기 모양). 손잡이는 단계마다 딱 걸리고, 바늘은 충분하면 가운데,
// 최대로 당겨도 모자라면 빨간 왼쪽, 남으면 호박색 오른쪽으로 간다(decisions.md 홈 화면).

/** −1(모자람) ~ 0(충분) ~ +1(남음) */
export function gaugeValue(g: Game, c: Comm, which: 'heat' | 'ration'): number {
  const v = situation(g, c)[which === 'heat' ? 0 : 1];
  if (v < 45) return Math.max(-1, (v - 45) / 25);
  if (v > 70) return Math.min(1, (v - 70) / 25);
  return 0;
}

export function gauge(value: number, small = false): SVGSVGElement {
  const r = 26;
  const arc = (a0: number, a1: number) => {
    const p = (a: number) => `${30 + r * Math.cos(a)} ${32 - r * Math.sin(a)}`;
    return `M${p(a0)} A${r} ${r} 0 0 1 ${p(a1)}`;
  };
  const angle = Math.PI / 2 - value * (Math.PI / 2) * 0.9;
  return s('svg', { class: cx('gauge', small && 'gauge--small'), viewBox: '0 0 60 36', 'aria-hidden': 'true' },
    s('path', { d: arc(Math.PI, Math.PI * 0.62), class: 'gauge__red' }),
    s('path', { d: arc(Math.PI * 0.62, Math.PI * 0.38), class: 'gauge__mid' }),
    s('path', { d: arc(Math.PI * 0.38, 0), class: 'gauge__amber' }),
    s('line', { x1: 30, y1: 32, x2: 30 + 22 * Math.cos(angle), y2: 32 - 22 * Math.sin(angle), class: 'gauge__needle' }),
    s('circle', { cx: 30, cy: 32, r: 3, class: 'gauge__hub' }));
}

export function lever(g: Game, c: Comm, which: 'heat' | 'ration'): HTMLElement {
  const value = g.comms[c][which];
  const floor = Math.max(lawFloor(g, which === 'heat' ? 'heatFloor' : 'rationFloor'), darkLeverFloor(g, c, which));
  const label = which === 'heat' ? '난방' : '배급';
  return h('div', { class: 'lever' },
    h('div', { class: 'lever__head' },
      icon(which === 'heat' ? 'heat' : 'ration', 'lever__icon'),
      h('span', { class: 'lever__name' }, label)),
    gauge(gaugeValue(g, c, which)),
    h('input', {
      class: 'lever__input', type: 'range', min: 0, max: 4, step: 1, value,
      'data-input': 'lever', 'data-comm': c, 'data-which': which,
      'aria-label': `${label} 레버`, 'aria-valuetext': LEVER_NAMES[value],
    }),
    h('div', { class: 'lever__ticks' }, LEVER_NAMES.map((n, i) => h('span', { class: cx(i === value && 'is-on', i < floor && 'is-locked') }, n))),
    floor > 0 ? h('div', { class: 'lever__floor' }, `${floor > lawFloor(g, which === 'heat' ? 'heatFloor' : 'rationFloor') ? '계엄으로' : '법으로'} ${LEVER_NAMES[floor]} 아래 금지`) : null);
}

export function bar(value: number, tone: string, max = 100): HTMLElement {
  const ratio = Math.max(0, Math.min(1, value / max));
  return h('span', { class: 'mini-bar' }, h('i', { style: `width:${(ratio * 100).toFixed(1)}%;background:var(${tone})` }));
}

export function portrait(name: string, comm?: Comm, big = false): HTMLElement {
  const initial = name.trim().charAt(0);
  return h('div', { class: cx('portrait', comm && `c-${comm}`, big && 'portrait--big'), 'aria-hidden': 'true' },
    h('span', { class: 'portrait__head' }), h('span', { class: 'portrait__body' }), h('b', null, initial));
}

/** 탭하면 설명이 쪽지로 뜨는 글자(app.ts 'tip'). 단추지만 글자처럼 보이고 점선 밑줄만 준다. */
export function tip(label: string, text: string): HTMLElement {
  return h('button', { type: 'button', class: 'tip', 'data-action': 'tip', 'data-tip': text }, label);
}
