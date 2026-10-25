import SEASON from './season_table.json';
import type { Weather } from './omens';

// 계절표 한 벌(season_table.json)의 구간 줄을 읽는 곳. 기후(climate.ts), 정차 날씨·창밖 글(omens.ts), 재난(disaster.ts)이 함께 읽는다.
// 이 파일은 표만 읽고 판 상태를 바꾸지 않는다. 판이 표를 따를지(기온 켠 판인지)는 부르는 쪽이 정한다.

export type SeasonRow = { seg: number; temp: number; stage: number; season: string; night_freeze: boolean; snow: boolean; blizzard: boolean; note: string };
export const SEASON_ROWS = SEASON.prologue as SeasonRow[];
/** 내리는 것은 기온으로: rain_above보다 높으면 비, snow_below 이하면 눈, 사이는 진눈깨비 */
export const FALLS = SEASON.falls;

/** 이 구간의 계절표 줄. 판 끝 너머는 마지막 줄, 0 이하는 첫 줄 */
export function rowAt(seg: number): SeasonRow {
  return SEASON_ROWS[Math.min(Math.max(seg, 1), SEASON_ROWS.length) - 1];
}

/** 계절표 날씨 중 정차에서 해시로 뽑는 다섯과 그 차례(옛 고정 비율과 같은 차례라 씨앗마다 덜 흔들린다). 눈보라는 재난으로만 온다. */
const DRAWN: Weather[] = ['snow', 'fog', 'sleet', 'overcast', 'clear'];

/** 이 구간 계절의 정차 날씨 비율 */
export function weatherWeights(seg: number): [Weather, number][] {
  const w = (SEASON.seasons as Record<string, { weather: Record<string, number> }>)[rowAt(seg).season].weather;
  return DRAWN.map(k => [k, w[k] ?? 0]);
}

/** 내리는 날씨(눈·진눈깨비)는 그 구간 한낮 기온이 정한다. 비는 sleet로 두고 글만 비가 된다(rainAt). 다른 날씨는 그대로 */
export function fallsAt(seg: number, w: Weather): Weather {
  if (w !== 'snow' && w !== 'sleet') return w;
  const t = rowAt(seg).temp;
  return t <= FALLS.snow_below ? 'snow' : 'sleet';
}

/** 이 구간의 진눈깨비가 비인가(한낮 기온이 rain_above보다 높다. S2 그림 fx/atmosphere.gd와 같은 경계) */
export function rainAt(seg: number): boolean {
  return rowAt(seg).temp > FALLS.rain_above;
}
