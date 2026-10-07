import { platformNote } from '../game';
import { cx, h } from './dom';
import type { View } from './common';

// 출발 레버와 승강장 확인 쪽지(presentation_motion 5b.5 '출발 단추 자리', 2026-10-07 18:37, 제안).
// 출발은 기적을 울리고 승강장에 남은 사람을 두고 갈 수 있는 되돌릴 수 없는 일이라, 툭 닿아서는 떠나지 않는다.
// S1a에는 소리와 흐르는 필드 시간이 없다. 낮은 타격은 쪽지 흔들림, 기적은 알림 글로 대신한다.

/** 레버가 걸리는 끌기 길이. CSS 96px/in 기준 약 12mm다. 폰마다 실제 길이는 조금 다르다(추정). */
export const PULL_PX = 45;
/** '두 번 눌러 출발'에서 두 번째 누름을 기다리는 시간 */
export const TAP_GAP_MS = 600;

// ---- 설정: 레버를 끌기 어려운 사람은 '두 번 눌러 출발'. 브라우저에만 남는 개인 설정이다 ----
const TAP_KEY = 's1a.departTap';
let tapMode: boolean | null = null;

export function departTapOn(): boolean {
  if (tapMode === null) {
    try {
      tapMode = globalThis.localStorage?.getItem(TAP_KEY) === '1';
    } catch {
      tapMode = false;
    }
  }
  return tapMode;
}

export function setDepartTap(on: boolean): void {
  tapMode = on;
  try {
    globalThis.localStorage?.setItem(TAP_KEY, on ? '1' : '0');
  } catch {
    // 저장 못 해도 이번 창에선 따른다.
  }
}

/** 아래 막대 오른쪽 구석의 놋쇠 출발 레버. 출발 전(prep)에 주 단추 자리에 선다. */
export function departLever(): HTMLElement {
  const tap = departTapOn();
  return h('button', {
    class: 'primary primary--depart', 'data-action': 'depart', 'data-lever': 'depart',
    'aria-label': tap ? '출발. 두 번 누른다' : '출발. 레버를 아래로 당겨 내린다',
  },
  h('span', { class: 'depart__slot', 'aria-hidden': 'true' }, h('i', { class: 'depart__handle' })),
  h('span', { class: 'depart__text' }, h('span', null, '출발'), h('small', null, tap ? '두 번 누른다' : '당겨 내린다')));
}

/** 레버가 걸렸는데 승강장에 사람이 남아 있으면 기적 전에 한 번 더 묻는 종이 쪽지.
 *  '기다린다'는 레버 가까이(오른쪽), '떠난다'는 반대쪽(왼쪽)에 둔다. 같은 손가락이 같은 자리를 또 눌러도 떠나지 않게. */
export function platformSheet(view: View): HTMLElement | null {
  const { g, ui } = view;
  if (!ui.departAsk) return null;
  const note = platformNote(g);
  if (!note) return null;
  const leaving = ui.departAsk === 'leaving';
  return h('div', { class: 'pnote-wrap' },
    h('div', { class: 'scrim scrim--pnote' }),
    h('div', { class: cx('pnote', leaving && 'is-leaving'), role: 'alertdialog', 'aria-modal': 'true', 'aria-labelledby': 'pnote-head' },
      note.near ? h('p', { class: 'pnote__near' }, '무리가 가깝다') : null,
      h('p', { class: 'pnote__head', id: 'pnote-head' }, `승강장에 ${note.names.length}명 남음`),
      h('p', { class: 'pnote__names' }, note.names.map((n, i) => [i > 0 ? ', ' : null, h('span', { class: 'pnote__name' }, n)])),
      h('div', { class: 'pnote__actions' },
        h('button', { class: 'btn btn--ghost pnote__leave', 'data-action': 'depart-leave', disabled: leaving }, '떠난다'),
        h('button', { class: 'btn pnote__wait', 'data-action': 'depart-wait', disabled: leaving }, '기다린다'))));
}

/** 레버 손맛. 누르기가 아니라 아래로 끌어 내려야 걸리고, 걸린 채로 손을 떼면 onPull.
 *  키보드(Enter·Space)는 끌 수 없으니 누름으로 받는다. 손가락이나 마우스로 툭 누르면 안내만 한다. */
export function departInput(root: HTMLElement, onPull: () => void, onHint: (text: string) => void): { click(e: MouseEvent): void } {
  let drag: { id: number; y: number; el: HTMLElement; caught: boolean } | null = null;
  let swallowUntil = -Infinity;
  let lastTap = -Infinity;

  root.addEventListener('pointerdown', e => {
    const el = (e.target as Element | null)?.closest<HTMLElement>('[data-lever="depart"]');
    if (!el || departTapOn() || (e.pointerType === 'mouse' && e.button !== 0)) return;
    drag = { id: e.pointerId, y: e.clientY, el, caught: false };
    try { el.setPointerCapture(e.pointerId); } catch { /* 이미 놓친 손가락 */ }
    el.classList.add('is-grab');
  });
  root.addEventListener('pointermove', e => {
    if (!drag || e.pointerId !== drag.id) return;
    const k = Math.min(1, Math.max(0, e.clientY - drag.y) / PULL_PX);
    drag.el.style.setProperty('--pull', k.toFixed(2));
    if (k >= 1 && !drag.caught) { drag.caught = true; drag.el.classList.add('is-caught'); }
    if (k < 1 && drag.caught) { drag.caught = false; drag.el.classList.remove('is-caught'); }
  });
  const release = (e: PointerEvent, cancel: boolean) => {
    if (!drag || e.pointerId !== drag.id) return;
    const d = drag;
    drag = null;
    d.el.classList.remove('is-grab', 'is-caught');
    d.el.style.removeProperty('--pull');
    if (cancel) return;
    // 끌고 난 뒤 오는 click은 삼킨다. 걸렸으면 떠나고, 덜 끌었으면 click이 안내를 띄운다.
    if (d.caught) { swallowUntil = performance.now() + 500; onPull(); }
  };
  root.addEventListener('pointerup', e => release(e, false));
  root.addEventListener('pointercancel', e => release(e, true));

  return {
    click(e: MouseEvent) {
      if (performance.now() < swallowUntil) return;
      if (e.detail === 0) return onPull(); // 키보드
      if (departTapOn()) {
        const now = performance.now();
        if (now - lastTap <= TAP_GAP_MS) { lastTap = -Infinity; return onPull(); }
        lastTap = now;
        return onHint('한 번 더 누르면 출발한다.');
      }
      onHint('레버를 아래로 당겨 내린다. 끌기 어려우면 메뉴에서 \'두 번 눌러 출발\'로 바꾼다.');
    },
  };
}
