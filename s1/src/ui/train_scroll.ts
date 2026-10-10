// 열차 띠 넘기기(사용자 2026-10-11: 노트북에서 "앞차로 움직일 수가 없다").
// 띠는 손가락 끌기로만 넘어갔다. 마우스로도 넘길 수 있게 세 길을 더한다.
// - 휠: 세로 휠도 가로로 넘긴다.
// - 끌기: 마우스로 잡고 끈다. 끌다 뗀 것은 누름으로 치지 않는다.
// - 글쇠: 왼쪽·오른쪽 화살표.

/** 이만큼(px) 넘게 움직여야 끌기다. 그 아래는 누름이다. */
export const DRAG_MIN = 6;
/** 화살표 글쇠 한 번에 넘기는 폭(px) */
export const KEY_STEP = 240;

/** 휠 한 번이 띠를 가로로 얼마나 넘기나. 가로·세로 가운데 큰 쪽을 쓴다. 줄 단위 휠은 px로 바꾼다. */
export function wheelStep(e: { deltaX: number; deltaY: number; deltaMode: number }): number {
  const d = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
  return e.deltaMode === 1 ? d * 16 : e.deltaMode === 2 ? d * 400 : d;
}

/** 끌기 시작한 자리에서 지금까지 온 거리로 끌기인지 가린다. */
export function isDrag(startX: number, x: number): boolean {
  return Math.abs(x - startX) > DRAG_MIN;
}

export function installTrainScroll(root: HTMLElement): void {
  const scroller = (): HTMLElement | null => root.querySelector<HTMLElement>('.scroller');
  const canScroll = (el: HTMLElement | null | undefined): el is HTMLElement => !!el && el.scrollWidth > el.clientWidth;

  root.addEventListener('wheel', event => {
    const el = (event.target as Element | null)?.closest<HTMLElement>('.scroller');
    if (!canScroll(el) || event.ctrlKey) return;
    el.scrollLeft += wheelStep(event);
    event.preventDefault();
  }, { passive: false });

  let drag: { x: number; left: number; moved: boolean } | null = null;
  root.addEventListener('pointerdown', event => {
    if (event.pointerType !== 'mouse' || event.button !== 0) return;
    const target = event.target as Element | null;
    const el = target?.closest<HTMLElement>('.scroller');
    if (!canScroll(el) || target?.closest('input, select, textarea')) return;
    drag = { x: event.clientX, left: el.scrollLeft, moved: false };
  });
  window.addEventListener('pointermove', event => {
    if (!drag) return;
    if (!drag.moved && !isDrag(drag.x, event.clientX)) return;
    drag.moved = true;
    root.classList.add('is-dragging');
    const el = scroller();
    if (el) el.scrollLeft = drag.left - (event.clientX - drag.x);
  });
  const end = (): void => {
    if (!drag) return;
    const moved = drag.moved;
    drag = null;
    root.classList.remove('is-dragging');
    if (!moved) return;
    // 끌다 뗀 자리의 단추가 눌리지 않게 바로 뒤따르는 누름 한 번을 삼킨다.
    const swallow = (e: Event): void => { e.stopPropagation(); e.preventDefault(); };
    root.addEventListener('click', swallow, { capture: true, once: true });
    setTimeout(() => root.removeEventListener('click', swallow, { capture: true }), 0);
  };
  window.addEventListener('pointerup', end);
  window.addEventListener('pointercancel', end);

  window.addEventListener('keydown', event => {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
    if (event.target instanceof Element && event.target.closest('input, select, textarea, [contenteditable]')) return;
    const el = scroller();
    if (!canScroll(el)) return;
    el.scrollLeft += event.key === 'ArrowLeft' ? -KEY_STEP : KEY_STEP;
    event.preventDefault();
  });
}
