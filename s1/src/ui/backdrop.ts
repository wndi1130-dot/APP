import type { Game, Weather } from '../game';
import { cx, h } from './dom';

// 달리는 배경(사용자 2026-10-11: "실제로 가는 것처럼"). 열차 그림 뒤로 겹들이 다른 속도로 흐른다.
// 그림은 전부 CSS로 그린 단순한 도형이다(styles.css '달리는 배경'). 규칙은 읽기만 한다.
// - 겹: 먼 산, 숲, 전신주와 전선, 눈. 가까울수록 빠르다.
// - 날씨: 정차에서 정해진 창밖 날씨(omens.ts)를 따르고 달리는 동안은 마지막에 본 날씨가 이어진다.
//   눈보라·한파가 닥친 구간에는 그것이 먼저다.
// - 눈보라 속에서는 열차가 기듯이 간다(겹이 느려진다). 규칙에는 속도가 없어 보이는 것만 그렇다.
// - 서면 그 자리에서 멎는다. 다시 그려도 겹이 제자리로 튀지 않게 달린 시간만 센다.

export type Sky = Weather | 'storm' | 'cold';

/** 지금 창밖: 하늘 종류, 눈보라 예고(서쪽 하늘이 낮다), 겹이 흐르는 빠르기(1이 보통, 클수록 느림).
 *  last는 마지막 정차에서 본 날씨다(달리는 동안은 판에 날씨가 없다). */
export function backdrop(g: Game, last?: Weather): { sky: Sky; omen: boolean; pace: number } {
  const d = g.disasters ? g.disaster : undefined;
  const sky: Sky = d?.stage === 'active' ? (d.kind === 'blizzard' ? 'storm' : 'cold') : g.stop?.weather ?? last ?? 'snow';
  return { sky, omen: d?.stage === 'warn' && d.kind === 'blizzard', pace: sky === 'storm' ? 2.2 : sky === 'fog' ? 1.3 : 1 };
}

export interface Clock { t: number; last: number; moving: boolean }

/** 달린 시간(ms)만 모은다. 서 있는 동안은 흐르지 않는다. */
export function tick(c: Clock, moving: boolean, now: number): number {
  if (c.moving) c.t += Math.max(0, now - c.last);
  c.last = now;
  c.moving = moving;
  return c.t;
}

const clock: Clock = { t: 0, last: 0, moving: false };
let seen: Weather | undefined;

/** 홈 화면의 하늘. moving이면 겹이 흐른다. */
export function backdropEl(g: Game, moving: boolean, now = Date.now()): HTMLElement {
  seen = g.stop?.weather ?? seen;
  const b = backdrop(g, seen);
  const t = tick(clock, moving, now);
  return h('div', {
    class: cx('sky', `sky--${b.sky}`, b.omen && 'is-omen'), 'aria-hidden': 'true',
    style: `--run:${(t / 1000).toFixed(2)};--pace:${b.pace}`,
  },
    h('i', { class: 'layer layer--far' }), h('i', { class: 'layer layer--wood' }), h('i', { class: 'layer layer--mid' }),
    h('i', { class: 'snow' }), h('i', { class: 'snow snow--gust' }), h('i', { class: 'veil' }));
}
