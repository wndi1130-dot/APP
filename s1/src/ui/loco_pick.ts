// 첫 화면 「열차를 고른다」(결정 133). 열차장을 만들기 전에 나오고, 넷을 가로로 놓아 이름 아래 얻는 것·잃는 것을 숫자 없는 말로 한 줄씩 보인다.
// 숫자는 「자세히」를 누른 뒤에 보인다. 그림은 아직 없어서 임시 윤곽을 쓴다(트리포 기관차 손질이 오면 바꾼다). 이름은 가안.
import { LOCO, LOCO_IDS } from '../game';
import type { LocoId } from '../game';
import { cx, h, s } from './dom';
import type { View } from './common';

/** 「자세히」에 보이는 숫자 줄. 표(data.ts LOCO)에서 만든다. */
export function locoDetailLines(id: LocoId): string[] {
  const l = LOCO[id];
  const lines: string[] = [];
  if (l.coal !== 0) lines.push(`구간마다 석탄 ${l.coal > 0 ? '+' : '−'}${Math.abs(l.coal)}`);
  if (l.extraCarCoal === 0) lines.push('붙인 칸은 석탄을 안 먹는다');
  if (l.carChanceMult === 0) lines.push('쓸 만한 칸이 걸리지 않는다');
  else if (l.carChanceMult !== 1) lines.push(`쓸 만한 칸이 걸릴 확률 ×${l.carChanceMult}`);
  if (l.breakMult === 0) lines.push('고장이 없다');
  else if (l.breakMult !== 1) lines.push(`고장 확률 ×${l.breakMult}`);
  if (l.repairParts !== null) lines.push(`고장을 막는 부품 ${l.repairParts}`);
  if (l.pressureAlways) lines.push(`압력 경고 ${Math.round((l.pressureChance ?? 0) * 100)}%(숙련과 상관없이)`);
  if (l.ventCoal !== null) lines.push(`김 빼기 석탄 ${l.ventCoal}`);
  if (l.anyoneDrives) lines.push('기관 숙련이 없어도 서지 않고 파업 때도 간다');
  return lines;
}

/** 임시 윤곽: 몸통 꼴만 다르게 그은 선. 실제 기관차를 닮게 그리지 않는다. */
function outline(id: LocoId): SVGElement {
  const body: Record<LocoId, SVGElement[]> = {
    c1: [s('rect', { x: 6, y: 22, width: 88, height: 24, rx: 3 }), s('rect', { x: 62, y: 8, width: 26, height: 16, rx: 2 }), s('rect', { x: 14, y: 12, width: 10, height: 10 })],
    c2: [s('rect', { x: 6, y: 28, width: 88, height: 18, rx: 3 }), s('rect', { x: 20, y: 2, width: 8, height: 26 }), s('rect', { x: 66, y: 14, width: 24, height: 14, rx: 2 })],
    c3: [s('rect', { x: 8, y: 22, width: 84, height: 24, rx: 12 }), s('rect', { x: 64, y: 12, width: 22, height: 12, rx: 2 }), s('rect', { x: 22, y: 14, width: 8, height: 8 })],
    c4: [s('rect', { x: 6, y: 22, width: 88, height: 24, rx: 10 }), s('path', { d: 'M30 22 V46 M46 22 V46 M62 22 V46' }), s('rect', { x: 14, y: 12, width: 10, height: 10 }), s('rect', { x: 70, y: 12, width: 18, height: 10, rx: 2 })],
  };
  return s('svg', { class: 'lococ__art', viewBox: '0 0 100 56', 'aria-hidden': 'true', fill: 'none', stroke: 'currentColor', 'stroke-width': 1.6 },
    ...body[id], s('circle', { cx: 22, cy: 50, r: 4 }), s('circle', { cx: 48, cy: 50, r: 4 }), s('circle', { cx: 74, cy: 50, r: 4 }));
}

export function locoScreen(view: View): HTMLElement {
  const { ui } = view;
  const sel = ui.locoSel ?? null;
  return h('section', { class: 'locopick' },
    h('div', { class: 'locopick__head' },
      h('span', { class: 'kicker' }, '출발 전'),
      h('b', { class: 'locopick__title' }, '열차를 고른다'),
      h('p', { class: 'sub' }, '이 열차가 끝까지 간다. 하나를 얻으면 하나를 잃는다.')),
    h('div', { class: 'locopick__row', role: 'radiogroup', 'aria-label': '기관차' },
      LOCO_IDS.map(id => {
        const l = LOCO[id];
        const on = sel === id;
        return h('div', { class: cx('lococ', on && 'is-on') },
          h('button', { class: 'lococ__pick', type: 'button', role: 'radio', 'aria-checked': on ? 'true' : 'false', 'data-action': 'loco-sel', 'data-id': id },
            outline(id),
            h('b', { class: 'lococ__name' }, l.name),
            h('span', { class: 'lococ__gain' }, h('i', null, '얻는 것'), l.gain),
            h('span', { class: 'lococ__loss' }, h('i', null, '잃는 것'), l.loss),
            l.note ? h('span', { class: 'lococ__note' }, l.note) : null),
          h('button', { class: 'lococ__more', type: 'button', 'data-action': 'loco-more', 'data-id': id, 'aria-expanded': ui.locoMore === id ? 'true' : 'false' }, ui.locoMore === id ? '접기' : '자세히'),
          ui.locoMore === id ? h('ul', { class: 'lococ__nums num' }, locoDetailLines(id).map(t => h('li', null, t))) : null);
      })),
    h('div', { class: 'locopick__actions' },
      h('button', { class: 'btn', type: 'button', 'data-action': 'loco-go', disabled: sel ? null : true, title: sel ? '' : '기관차를 먼저 고른다' }, sel ? '이 기관차로 간다' : '기관차를 고른다')));
}
