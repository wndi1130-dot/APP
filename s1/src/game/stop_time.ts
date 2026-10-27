import { WEATHER_NAME, hash, pickWeather } from './omens';
import { rainAt } from './season';
import type { Weather } from './omens';
import type { Game } from './state';

// 결정 471 B0(사용자 확정): 정차 도착 시각을 정차마다 굴린다. 띠와 몫은 S2 field_clock.gd ARRIVALS와 같다 —
// 아침 40%(09:00~09:50) · 한낮 35%(10:00~12:30) · 늦은 오후 20%(13:00~14:20) · 해 질 녘 5%(14:50~15:30), 10분 단위.
// 판 씨앗과 구간으로만 정해서(난수 흐름을 건드리지 않음) 도착 전에 노선표에 미리 보일 수 있다.

/** [몫 %, 처음 분, 끝 분] — 분은 0시부터 */
export const ARRIVALS: readonly (readonly [number, number, number])[] = [[40, 540, 590], [35, 600, 750], [20, 780, 860], [5, 890, 930]];
/** 도착 시각이 없던 옛 정차의 시각(10:30) */
export const ARRIVE_MIN_DEFAULT = 630;

/** 구간 seg의 정차에 열차가 닿는 시각(분). 같은 씨앗·구간이면 늘 같다. */
export function arrivalMin(seed: string, seg: number): number {
  let x = hash(`${seed}:arr:${seg}`) % 100;
  for (const [share, from, to] of ARRIVALS) {
    if (x < share) return from + (hash(`${seed}:arr:${seg}:m`) % ((to - from) / 10 + 1)) * 10;
    x -= share;
  }
  return ARRIVE_MIN_DEFAULT;
}

/** 분을 「HH:MM」으로 */
export function clockText(min: number): string {
  return `${String(Math.floor(min / 60)).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}`;
}

/** 다음 정차 예보: 이 구간에서 아직 서지 않았으면 그 정차의 도착 시각과 날씨, 아니면 null.
 *  날씨는 도착할 때 굴릴 것과 같은 함수로 미리 본다(가는 길에 재난이 닥치면 도착 때 바뀔 수 있다). */
export function nextStopForecast(g: Game): { seg: number; arriveMin: number; weather: Weather } | null {
  if (g.phase !== 'prep' && g.phase !== 'travel') return null;
  if (g.stranded || g.end) return null;
  return { seg: g.seg, arriveMin: arrivalMin(g.seed, g.seg), weather: pickWeather(g) };
}

/** 노선표에 적는 다음 정차: 「HH:MM」과 날씨 이름(기온 켠 판의 따뜻한 진눈깨비는 비). 없으면 null */
export function nextStopLine(g: Game): { time: string; weather: string } | null {
  const next = nextStopForecast(g);
  if (!next) return null;
  const weather = next.weather === 'sleet' && g.climate && rainAt(next.seg) ? '비' : WEATHER_NAME[next.weather];
  return { time: clockText(next.arriveMin), weather };
}
