import SEASON from './season_table.json';
import type { Weather } from './omens';

// 계절표 한 벌(season_table.json)의 구간 줄을 읽는 곳. 기후(climate.ts), 정차 날씨·창밖 글(omens.ts), 재난(disaster.ts)이 함께 읽는다.
// 이 파일은 표만 읽고 판 상태를 바꾸지 않는다. 판이 표를 따를지(기온 켠 판인지)는 부르는 쪽이 정한다.

export type SeasonRow = { seg: number; region: string; temp: number; stage: number; season: string; night_freeze: boolean; snow: boolean; blizzard: boolean; note: string };
/** S1 24구간이 따르는 곡선: 서막(본래) 또는 시험 판의 막(결정 447 카드 3) */
export type SeasonAct = 'prologue' | 'act1' | 'act2' | 'act3';
const PROLOGUE_ROWS = SEASON.prologue as SeasonRow[];
/** 지금 판들이 읽는 구간 줄. 본래 서막 그대로이고, 시험 판 스위치(climate.ts useSeasonAct)만 막 곡선으로 바꾼다 */
export const SEASON_ROWS: SeasonRow[] = [...PROLOGUE_ROWS];

/** 막 하나의 곡선(season_table.json acts)을 서막과 같은 24구간 줄로 편다: 한낮 기온은 막의 처음→끝을 곧게,
 * 단계는 기온이 가장 가까운 단계(같으면 추운 쪽), 계절은 막 안의 진행으로, 결빙·눈·눈보라는 막의 칸 그대로.
 * 지역은 서막 줄을 빌린다(S1 노선은 하나다) */
export function actRows(act: Exclude<SeasonAct, 'prologue'>): SeasonRow[] {
  const a = (SEASON.acts as unknown as Record<string, { temp: number[]; season: [number, string][]; night_freeze: boolean; snow: boolean; blizzard: boolean }>)[act];
  const n = PROLOGUE_ROWS.length;
  return PROLOGUE_ROWS.map((r, i) => {
    const p = n > 1 ? i / (n - 1) : 0;
    const temp = Math.round(a.temp[0] + (a.temp[1] - a.temp[0]) * p);
    let stage = 0;
    SEASON.stages.forEach((s, k) => { if (Math.abs(s.temp - temp) <= Math.abs(SEASON.stages[stage].temp - temp)) stage = k; });
    let season = a.season[0][1];
    for (const [from, name] of a.season) if (p >= from) season = name;
    return { seg: r.seg, region: r.region, temp, stage, season, night_freeze: a.night_freeze, snow: a.snow, blizzard: a.blizzard, note: `${act} 시험 곡선` };
  });
}

/** 구간 줄을 서막이나 막 곡선으로 바꾼다. 모든 판이 함께 읽으므로 climate.ts useSeasonAct로만 부른다 */
export function setSeasonRows(act: SeasonAct): void {
  SEASON_ROWS.splice(0, SEASON_ROWS.length, ...(act === 'prologue' ? PROLOGUE_ROWS : actRows(act)));
}
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
