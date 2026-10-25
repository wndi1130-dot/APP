import { rainAt, rowAt } from '../game';
import type { Game, Weather } from '../game';
import { cx, h } from './dom';

// 달리는 배경(사용자 2026-10-11: "실제로 가는 것처럼"). 열차 그림 뒤로 겹들이 다른 속도로 흐른다.
// 그림은 전부 CSS로 그린 단순한 도형이다(styles.css '달리는 배경'). 규칙은 읽기만 한다.
// - 겹: 지평선, 숲, 전신주와 전선, 눈. 기온 켠 판은 지역과 땅·잎·내리는 것도 계절표를 따른다.
// - 날씨: 정차에서 정해진 창밖 날씨(omens.ts)를 따르고 달리는 동안은 마지막에 본 날씨가 이어진다.
//   눈보라·한파가 닥친 구간에는 그것이 먼저다.
// - 눈보라 속에서는 열차가 기듯이 간다(겹이 느려진다). 규칙에는 속도가 없어 보이는 것만 그렇다.
// - 서면 그 자리에서 멎는다. 다시 그려도 겹이 제자리로 튀지 않게 달린 시간만 센다.

export type Sky = Exclude<Weather, 'blizzard' | 'cold_front'> | 'storm';
type Look = { kit: string; ground: 'wet' | 'frost' | 'snow'; falls: 'rain' | 'sleet' | 'snow' | 'none'; leaves: boolean };

/** 재난 날씨는 재난이 닥친 동안만 그 하늘이다. 끝난 뒤 남은 정차 날씨가 눈보라·한파면 갠 하늘(폭풍이 지나간 뒤)로 본다.
 *  한파 전조는 겉으로는 갠 하늘이다(바람이 멎은 것만 다르다). */
const calm = (w: Weather): Sky => (w === 'blizzard' || w === 'cold' || w === 'cold_front' ? 'clear' : w);

/** 지금 창밖: 하늘 종류, 눈보라 예고(서쪽 하늘이 낮다), 겹이 흐르는 빠르기(1이 보통, 클수록 느림).
 *  last는 마지막 정차에서 본 날씨다(달리는 동안은 판에 날씨가 없다). */
export function backdrop(g: Game, last?: Weather): { sky: Sky; omen: boolean; pace: number; look?: Look } {
  const d = g.disasters ? g.disaster : undefined;
  const sky: Sky = d?.stage === 'active' ? (d.kind === 'blizzard' ? 'storm' : 'cold') : calm(g.stop?.weather ?? last ?? (g.climate ? 'overcast' : 'snow'));
  // 두 구간 앞(어느 재난이든)과 눈보라 한 구간 앞은 바람 쪽 하늘이 내려앉는다. 한파 한 구간 앞은 오히려 갠다.
  const b = { sky, omen: d?.stage === 'brewing' || (d?.stage === 'warn' && d.kind === 'blizzard'), pace: sky === 'storm' ? 2.2 : sky === 'fog' ? 1.3 : 1 };
  if (!g.climate) return b;
  const row = rowAt(g.seg);
  const look: Look = {
    kit: row.region.toLowerCase(),
    ground: row.snow ? 'snow' : row.night_freeze ? 'frost' : 'wet',
    falls: sky === 'snow' || sky === 'storm' ? 'snow' : sky === 'sleet' ? (rainAt(g.seg) ? 'rain' : 'sleet') : 'none',
    leaves: row.season === 'late_autumn' && !row.snow,
  };
  return { ...b, look };
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
  seen = g.stop?.weather ?? g.lastStop?.weather ?? seen; // 앱을 다시 열어도 마지막 정차의 하늘이 이어진다
  const b = backdrop(g, seen);
  const t = tick(clock, moving, now);
  return h('div', {
    class: cx('sky', `sky--${b.sky}`, b.omen && 'is-omen', b.look && `sky--kit-${b.look.kit}`,
      b.look && `sky--ground-${b.look.ground}`, b.look && `sky--falls-${b.look.falls}`, b.look?.leaves && 'has-leaves'), 'aria-hidden': 'true',
    style: `--run:${(t / 1000).toFixed(2)};--pace:${b.pace}`,
  },
    h('i', { class: 'layer layer--far' }), h('i', { class: 'layer layer--wood' }),
    b.look ? h('i', { class: 'layer layer--field' }) : null, h('i', { class: 'layer layer--mid' }),
    h('i', { class: 'snow' }), h('i', { class: 'snow snow--gust' }), h('i', { class: 'veil' }));
}
