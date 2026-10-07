import { COMM_NAME, P, isSessionSeg, relStage, situation, viewCard } from '../game';
import type { Comm, Game } from '../game';
import { cx, h } from './dom';
import { icon } from './icons';
import { CARS, fmt } from './common';
import type { CarDef, View } from './common';
import { bar, lever } from './widgets';

// 홈: 옆에서 본 열차 단면. 화면보다 길어서 좌우로 스크롤한다. 칸 문 위 명판으로 칸을 구별한다.
// 칸의 수치와 조절은 칸을 누르면 뜨는 작은 창에만 있다. 그림은 회색 상자 수준의 자리표시다.

function warmthTone(w: number): string {
  if (w < 30) return 'is-freezing';
  if (w < 45) return 'is-cold';
  if (w > 70) return 'is-warm';
  return '';
}

function figures(g: Game, car: CarDef): HTMLElement {
  let count = 3;
  if (car.comm) {
    const share = car.comm === 'tail' ? 3 : 1;
    const crowd = situation(g, car.comm)[2];
    count = Math.max(2, Math.min(16, Math.round((g.comms[car.comm].pop / share) * (0.25 + crowd / 250))));
    const away = g.comms[car.comm].away;
    if (away > 0 && (car.comm !== 'tail' || car.id === 'tail1')) count = Math.max(1, count - away);
  } else if (car.kind === 'dining') {
    count = g.phase === 'council' ? 12 : 4;
  } else if (car.kind === 'captain') {
    count = 2;
  } else if (car.kind === 'loco') {
    count = 0;
  }
  return h('div', { class: 'car__people' }, Array.from({ length: count }, (_, i) => h('i', { class: 'fig', style: `--i:${i}` })));
}

function carEl(view: View, car: CarDef): HTMLElement {
  const { g, ui } = view;
  const sit = car.comm ? situation(g, car.comm) : null;
  const striking = g.inStrike && car.kind === 'loco';
  const session = car.kind === 'dining' && g.phase === 'council';
  return h('button', {
    class: cx('car', `car--${car.kind}`, car.comm && `c-${car.comm}`, sit && warmthTone(sit[0]), ui.carPop === car.id && 'is-open', session && 'is-session', striking && 'is-strike'),
    'data-action': 'car', 'data-car': car.id, 'data-car-id': car.id, 'aria-label': car.name,
  },
    car.plate ? h('span', { class: 'car__plate' }, car.plate) : null,
    h('span', { class: 'car__windows' }, h('i'), h('i'), h('i')),
    figures(g, car),
    car.kind === 'loco' ? h('span', { class: 'loco__stack' }, striking ? null : h('i', { class: 'smoke' })) : null,
    h('span', { class: 'car__wheels' }, h('i'), h('i')));
}

function carPopover(view: View, car: CarDef): HTMLElement | null {
  const { g } = view;
  if (car.kind === 'comm' || car.kind === 'engine') {
    const c = car.comm as Comm;
    const [w, r, cr, ex] = situation(g, c);
    const s = g.comms[c];
    return h('div', { class: 'carpop', role: 'dialog', 'aria-label': `${car.name} 창` },
      h('div', { class: 'carpop__head' },
        h('b', null, COMM_NAME[c]),
        h('span', { class: 'num' }, `${s.pop}명`),
        h('span', { class: cx('stage', `stage--${s.rel >= 15 ? 'up' : s.rel <= -15 ? 'down' : 'mid'}`) }, relStage(g, c)),
        h('button', { class: 'x', 'data-action': 'car', 'data-car': car.id, 'aria-label': '닫기' }, '×')),
      h('div', { class: 'carpop__stats' },
        h('span', null, '온기 ', h('b', { class: 'num' }, fmt(w)), bar(w, w < 45 ? '--discontent' : '--warm')),
        h('span', null, '배급 ', h('b', { class: 'num' }, fmt(r)), bar(r, r < 45 ? '--discontent' : '--ink-3')),
        h('span', null, '과밀 ', h('b', { class: 'num' }, fmt(cr)), bar(cr, cr > 60 ? '--discontent' : '--ink-3')),
        h('span', null, '노출 ', h('b', { class: 'num' }, fmt(ex)), bar(ex, ex > 50 ? '--discontent' : '--ink-3'))),
      h('div', { class: 'carpop__levers' }, lever(g, c, 'heat'), lever(g, c, 'ration')));
  }
  if (car.kind === 'dining') {
    const left = isSessionSeg(g.seg) ? 0 : P.sessionEvery - (g.seg % P.sessionEvery);
    return h('div', { class: 'carpop carpop--small', role: 'dialog' },
      h('div', { class: 'carpop__head' }, h('b', null, '식당칸 · 의회'),
        h('button', { class: 'x', 'data-action': 'car', 'data-car': car.id, 'aria-label': '닫기' }, '×')),
      h('p', { class: 'carpop__text' }, g.phase === 'council' ? '회기가 열렸다.' : left === 0 ? '이번 구간에 회기가 열린다.' : `다음 회기까지 ${left}구간.`),
      g.phase === 'council' ? h('button', { class: 'btn', 'data-action': 'go', 'data-screen': 'council' }, '의회로') : null);
  }
  if (car.kind === 'captain') {
    return h('div', { class: 'carpop carpop--small', role: 'dialog' },
      h('div', { class: 'carpop__head' }, h('b', null, '열차장실'),
        h('button', { class: 'x', 'data-action': 'car', 'data-car': car.id, 'aria-label': '닫기' }, '×')),
      h('p', { class: 'carpop__text' }, `일지 ${g.journal.length}줄. 쥔 비밀 ${g.secrets.length}. 상징물 ${g.symbols}.`),
      h('button', { class: 'btn', 'data-action': 'panel', 'data-panel': 'journal' }, '일지 펼치기'));
  }
  return null;
}

export function stackCount(g: Game, ui: View['ui']): number {
  const stopPending = g.phase === 'stop' && g.stop && (!g.stop.done || !ui.stopSeen) ? 1 : 0;
  return g.cards.length + stopPending;
}

function paperStack(view: View): HTMLElement | null {
  const { g, ui } = view;
  const n = stackCount(g, ui);
  if (n === 0 || ui.cardOpen) return null;
  const top = g.cards[0];
  const title = g.phase === 'stop' && g.stop && (!g.stop.done || !ui.stopSeen) ? '정차' : top ? viewCard(g, top).title : '';
  return h('button', { class: 'stack', 'data-action': 'open-stack', 'aria-label': `서류 ${n}장: ${title}` },
    Array.from({ length: Math.min(n, 4) }, (_, i) => h('i', { class: 'stack__sheet', style: `--i:${i}` })),
    h('span', { class: 'stack__count num' }, n),
    h('span', { class: 'stack__title' }, title));
}

export function homeScreen(view: View): HTMLElement {
  const { g, ui } = view;
  const moving = g.phase === 'travel' && !g.inStrike;
  const open = CARS.find(c => c.id === ui.carPop);
  return h('section', { class: cx('home', moving && 'is-moving', g.phase === 'stop' && 'is-stopped', g.inStrike && 'is-strike') },
    h('div', { class: 'sky' }, h('i', { class: 'layer layer--far' }), h('i', { class: 'layer layer--mid' }), h('i', { class: 'snow' })),
    h('div', { class: 'scroller', 'data-keep-scroll': 'train' },
      h('div', { class: 'train' },
        CARS.map(car => h('div', { class: 'slot', 'data-slot': car.id },
          open?.id === car.id ? carPopover(view, car) : null,
          carEl(view, car)))),
      h('div', { class: 'rails' })),
    h('i', { class: 'layer layer--near' }),
    paperStack(view),
    g.phase === 'stop' && g.stop ? h('div', { class: 'platform-tag' }, icon('symbol'), '정차 중') : null);
}
