import { FX_FLY_MS, fxText, fxTone } from './fx';
import type { Fx } from './fx';

// 5b.6의 ②날아감과 ④숫자 셈. 다시 그려도 같은 연출이 두 번 돌지 않게 연출 번호로 한 번만 한다.
// 동작 감소 설정이면 날아감과 부풂을 끄고 꼬리표가 칸 옆에 바로 뜬다(CSS가 is-late 지연도 없앤다).

let played = 0;

/** 그린 뒤에 부른다. origin은 고른 선택지의 자리(화면 좌표). 없으면 날지 않고 칸 옆에 바로 뜬다. */
export function fxPlay(root: HTMLElement, fx: Fx | null | undefined, origin: DOMRect | null): void {
  if (!fx || fx.id === played) return;
  played = fx.id;
  const still = globalThis.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
  if (!still && origin) {
    fx.fly.forEach((key, i) => {
      const cell = root.querySelector<HTMLElement>(`[data-fx-cell="${key}"]`);
      const c = fx.d[key];
      if (!cell || !c) return;
      const to = cell.getBoundingClientRect();
      const tag = document.createElement('span');
      tag.className = `fx-flyer num ${fxTone(c)}${c.big ? ' is-big' : ''}`;
      tag.textContent = fxText(c.v);
      tag.setAttribute('aria-hidden', 'true');
      const x0 = origin.left + origin.width / 2;
      const y0 = origin.top + origin.height / 2;
      const x1 = to.left + to.width / 2;
      const y1 = to.top + to.height / 2;
      tag.style.left = `${x0}px`;
      tag.style.top = `${y0}px`;
      document.body.append(tag);
      // 곡선: 가운데 지점을 위로 들어 올린다.
      const mx = (x0 + x1) / 2 - x0;
      const my = Math.min(y0, y1) - 40 - y0;
      const anim = tag.animate([
        { transform: 'translate(-50%, -50%) scale(1)', opacity: 1 },
        { transform: `translate(calc(-50% + ${mx}px), calc(-50% + ${my}px)) scale(.85)`, opacity: 1, offset: 0.5 },
        { transform: `translate(calc(-50% + ${x1 - x0}px), calc(-50% + ${y1 - y0}px)) scale(.7)`, opacity: 0.9 },
      ], { duration: FX_FLY_MS, delay: i * 60, easing: 'cubic-bezier(.2,.7,.3,1)', fill: 'forwards' });
      anim.onfinish = () => tag.remove();
      anim.oncancel = () => tag.remove();
    });
  }
  for (const b of root.querySelectorAll<HTMLElement>('[data-roll]')) roll(b, still, origin ? FX_FLY_MS : 0);
}

/** 정수만 보이게 옛 값에서 새 값까지 센다. |Δ|≤2면 300ms, ≥10이면 600ms. */
function roll(b: HTMLElement, still: boolean, delay: number): void {
  const [, a, z] = (b.dataset.roll ?? '').split(':').map(Number);
  if (!Number.isFinite(a) || !Number.isFinite(z) || a === z || still) return;
  const n = Math.abs(z - a);
  const ms = 300 + (Math.min(Math.max(n, 2), 10) - 2) / 8 * 300;
  const final = b.textContent;
  b.textContent = String(a);
  const t0 = performance.now() + delay;
  const tick = (t: number): void => {
    if (!b.isConnected) return;
    const k = Math.min(1, Math.max(0, (t - t0) / ms));
    b.textContent = k >= 1 ? final : String(Math.round(a + (z - a) * k));
    if (k < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}
