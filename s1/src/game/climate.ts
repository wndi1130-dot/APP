import { COMMS } from './data';
import SEASON from './season_table.json';
import { hash } from './omens';
import type { Weather } from './omens';
import { rowAt, SEASON_ROWS } from './season';
import type { SeasonRow } from './season';
import { journal } from './state';
import type { Game } from './state';

// 바깥 기온과 결빙(coord fun/구현명세_바깥기온_결빙_v1, 결정 351·357·370). 기본은 꺼져 있다.
// 켜는 길: enableClimate(g). 꺼진 판은 이 파일의 어떤 함수도 상태를 만들거나 일지를 쓰지 않는다(골든 그대로).
// 계절표는 판 씨앗과 상관없이 늘 같다(정해진 날). 하강과 결빙은 미리 알리지 않는다(결정 357): 다음 바뀜 구간을 어디에도 적지 않는다.
// 기온 켠 판은 정기 한파(P.winterEvery마다 온기 −5)가 없고, 단계가 바뀔 때 온기 ∓5×차와 난방 석탄 곱이 함께 움직인다(결정 370 1).
// 숫자는 가안이고 500판 숫자를 사용자에게 보인 뒤 정한다. tools/s1c_sim.ts의 --cl=키:값으로 바꿀 수 있다(배열은 쉼표).
// 단계·계절표·구간 기온은 계절표 한 벌(season_table.json, S2 열차·필드 그림과 같은 파일)에서 온다(코디네이터 10-25, 결정 423·서막 (나)).

const STAGES = SEASON.stages;
const ROWS = SEASON_ROWS;

/** 계절표의 구간별 단계에서, 단계가 바뀌는 구간만 [이 구간 출발부터, 단계]로 */
function stageTable(rows: SeasonRow[]): [number, number][] {
  const out: [number, number][] = [];
  for (const r of rows) if (!out.length || out[out.length - 1][1] !== r.stage) out.push([r.seg, r.stage]);
  return out;
}

export const CL = {
  /** 단계의 이름(가제), 기준 기온. 따뜻한 것부터(번호가 클수록 춥다) */
  names: STAGES.map(s => s.name),
  temp: STAGES.map(s => s.temp),
  /** 단계의 난방 석탄 곱(결정 370 2의 약안에 늦가을 0.8을 더함) */
  mult: STAGES.map(s => s.mult),
  /** 단계를 떠나는 출발이 젖은 출발인가(결빙 조건, 결정 370 3: 옛 '풀림 단계'). 늦가을이 젖어 있다 */
  wet: STAGES.map(s => (s.wet ? 1 : 0)),
  /** 계절표: [이 구간 출발부터, 단계]. 24구간 판(P.segments) = 서막 */
  table: stageTable(ROWS),
  /** 구간 1~24의 한낮 바깥 기온(표시). 판 끝 너머는 마지막 값 */
  segTemp: ROWS.map(r => r.temp),
  /** 단계 하나에 모든 칸 기준 온기가 바뀌는 양 */
  warmStep: 5,
  /** 1이면 결빙이 있다(0이면 결빙만 끈다, 500판 D줄) */
  freezeOn: 1,
  /** 결빙이 이어지는 구간 수, 구간마다 더 드는 석탄, 식량(foodCost에 곱하는 몫, 반나절치), 선로 사건이 후보에 드는 수 */
  freezeLen: 1, freezeCoal: 1, freezeFood: 0.5, freezeTrack: 2,
};

/** 표시 기온의 날씨 보정(표시만, 석탄·온기는 안 읽는다) */
const WEATHER_TEMP: Record<Weather, number> = { overcast: 0, snow: -2, fog: 2, sleet: 5, clear: -4, cold_front: -6, blizzard: -5, cold: -12 };
/** 결빙 구간에 두 배로 드는 선로 사건 */
const TRACK_EVENTS = ['water_tower', 'snow_drift'];

/** 바뀜마다 한 줄 글: [1인칭, 3인칭]. 지금 상태만 말한다(앞날 낱말 없음). 장소 이름을 넣지 않는다. */
const LINES = {
  drop: ['날씨가 추워지고 있어…', '창에 성에가 다시 낀다……'],
  deep: ['숨 쉬는 것도 아파…', '쇠붙이가 손에 들러붙는다……'],
  ease: ['바람이 좀 누그러졌어…', '지붕의 눈이 녹아 흘러내린다……'],
  freeze: ['바퀴가 자꾸 헛돌아…', '선로가 얼어붙고 있다……'],
  thaw: ['이제 좀 굴러가네…', '바퀴 밑 얼음이 갈라진다……'],
} as const;
export const CLIMATE_LINES: readonly string[] = Object.values(LINES).flat();

/** 판에 바깥 기온을 켠다. S1a·S1b·S1c 어느 판에든 얹을 수 있다. 시작 단계는 계절표의 지금 구간 값이다. */
export function enableClimate(g: Game): void {
  g.climate = true;
  g.outside = stageAt(g.seg);
  g.freeze = 0;
  g.climateStats = { drops: 0, freezes: 0 };
}

/** 계절표에서 이 구간의 표시 기온(날씨 보정 전) */
export function segTemp(seg: number): number {
  return CL.segTemp[Math.min(Math.max(seg, 1), CL.segTemp.length) - 1];
}

/** 계절표에서 이 구간 출발의 단계 */
export function stageAt(seg: number): number {
  let st = CL.table[0][1];
  for (const [from, s] of CL.table) if (seg >= from) st = s;
  return st;
}

/** 난방 석탄 곱(heatCost가 곱한다). 꺼진 판은 1. 적용된 단계(g.outside)를 읽어 출발 전 예고에 하강이 새지 않는다. */
export function tempMult(g: Game): number {
  return g.climate ? CL.mult[g.outside ?? 1] : 1;
}

/** 결빙 구간에 더 드는 석탄(forecast가 읽는다). 꺼진 판·결빙 아님은 0 */
export function freezeCoal(g: Game): number {
  return g.climate && (g.freeze ?? 0) > 0 ? CL.freezeCoal : 0;
}

/** 결빙 구간에 더 드는 식량 몫(foodCost에 곱한다). 꺼진 판·결빙 아님은 0 */
export function freezeFood(g: Game): number {
  return g.climate && (g.freeze ?? 0) > 0 ? CL.freezeFood : 0;
}

/** UI가 읽는 바깥 기온: 단계·이름·표시 기온, 이번 구간에 바뀌었으면 바뀐 폭(°, 내려가면 음수), 결빙 중인가. 꺼진 판은 null. 다음 바뀜은 담지 않는다. */
export function outsideView(g: Game): { stage: number; name: string; temp: number; delta: number | null; freezing: boolean } | null {
  if (!g.climate) return null;
  const stage = g.outside ?? 1;
  const d = g.disasters && g.disaster?.stage === 'active' ? g.disaster.kind : null;
  const weather: Weather | undefined = d ?? (g.stop ?? g.lastStop)?.weather;
  const ch = g.climateChange;
  return {
    stage, name: CL.names[stage], temp: segTemp(g.seg) + (weather ? WEATHER_TEMP[weather] : 0),
    delta: ch && ch.seg === g.seg ? segTemp(g.seg) - segTemp(g.seg - 1) : null,
    freezing: (g.freeze ?? 0) > 0,
  };
}

/** 같은 판에서 바로 앞 글과 다른 인칭을 쓴다. 판의 첫 글은 씨앗 해시로 고른다. */
function line(g: Game, pair: readonly [string, string]): string {
  const voice = g.climateVoice === undefined ? hash(`${g.seed}|cl-voice`) % 2 : 1 - g.climateVoice;
  g.climateVoice = voice;
  return pair[voice];
}

/** 출발 때: 계절표 단계가 바뀌었으면 적용된 단계를 갱신하고 모든 칸 온기를 ∓5×차만큼 옮기고 글 두 줄을 남긴다.
 * 선 열차는 부르지 않는다(선 동안 바뀐 단계는 다음 실제 출발에 한 번에 든다). 떠난 단계와 새 단계를 돌려준다. 꺼진 판은 null. */
export function climateDepart(g: Game): { from: number; to: number } | null {
  if (!g.climate) return null;
  const from = g.outside ?? stageAt(g.seg);
  const to = stageAt(g.seg);
  if (to === from) return { from, to };
  const diff = to - from; // 양수면 추워진다
  for (const c of COMMS) g.comms[c].base[0] -= CL.warmStep * diff;
  g.outside = to;
  g.climateChange = { seg: g.seg, from, to };
  if (diff > 0) (g.climateStats ??= { drops: 0, freezes: 0 }).drops += 1;
  journal(g, line(g, diff >= 2 ? LINES.deep : diff > 0 ? LINES.drop : LINES.ease), diff > 0 ? 'bad' : 'good');
  const warm = -CL.warmStep * diff;
  journal(g, `바깥 ${String(segTemp(g.seg)).replace('-', '−')}°. 모든 칸 온기 ${warm > 0 ? '+' : '−'}${Math.abs(warm)}, 난방 석탄 ×${CL.mult[to]}.`, diff > 0 ? 'bad' : 'good');
  return { from, to };
}

/** 출발 때(재난 출발 뒤): 단계가 내려갔거나 재난 한파가 이번 출발에 닥쳤고, 떠나는 정차가 젖어 있으면 선로가 언다.
 * 젖음 = 떠나는 정차의 날씨가 진눈깨비이거나, 떠날 때 적용돼 있던 단계가 젖은 단계(CL.wet, 늦가을)다(결정 370 3). */
export function freezeDepart(g: Game, shift: { from: number; to: number } | null, coldStart: boolean): void {
  if (!g.climate || !CL.freezeOn || !shift) return;
  if (!(shift.to > shift.from || coldStart)) return;
  const wet = g.lastStop?.weather === 'sleet' || !!CL.wet[shift.from];
  if (!wet) return;
  g.freeze = CL.freezeLen;
  (g.climateStats ??= { drops: 0, freezes: 0 }).freezes += 1;
  journal(g, line(g, LINES.freeze), 'bad');
  journal(g, `선로 결빙: 석탄 +${CL.freezeCoal}, 식량 +반나절.`, 'bad');
}

/** 정산 끝: 결빙 구간을 하나 지나 보내고, 다 지났으면 결빙 끝 글을 남긴다. */
export function climateSettle(g: Game): void {
  if (!g.climate || !(g.freeze ?? 0)) return;
  g.freeze = (g.freeze ?? 0) - 1;
  if (g.freeze <= 0) journal(g, line(g, LINES.thaw), 'good');
}

/** 사건의 눈·얼음 조건(콘텐츠 조건 season, TS 선로 사건 급수탑·눈더미)이 묻는 것: frost는 얼음이 서는가, snow는 눈이 쌓였는가,
 * bare는 얼음도 눈도 없는가(늦가을 선로 시련, 결정 447) */
export type SeasonNeed = 'frost' | 'snow' | 'bare';

/** 사건의 눈·얼음 조건. 기온 꺼진 판은 frost·snow가 늘 참이고 bare는 늘 거짓이다(옛 판은 처음부터 겨울이고 골든 그대로).
 * 켠 판의 frost는 계절표 그 구간의 밤 결빙(night_freeze)이거나, 한파가 닥쳤거나(재난·정차 날씨), 선로 결빙 중이다.
 * snow는 계절표 그 구간의 쌓인 눈(snow)이다. bare는 frost도 snow도 아닐 때다.
 * 창밖·조짐 글(omens.ts seasonCond)과 같은 칸을 읽는다. 난수를 쓰지 않는다. */
export function seasonHolds(g: Game, need: SeasonNeed): boolean {
  if (!g.climate) return need !== 'bare';
  const row = rowAt(g.seg);
  if (need === 'snow') return row.snow;
  const d = g.disasters && g.disaster?.stage === 'active' ? g.disaster.kind : undefined;
  const w = d ?? (g.stop ?? g.lastStop)?.weather;
  const frost = row.night_freeze || w === 'cold' || w === 'cold_front' || (g.freeze ?? 0) > 0;
  return need === 'bare' ? !frost && !row.snow : frost;
}

/** 이동 사건 후보(drawTravelEvent): 결빙 구간이면 이미 든 선로 사건을 더 넣어 뽑힐 몫을 키운다(쿨다운에 걸린 것은 안 든다). */
export function freezeTrackBoost(g: Game, pool: string[]): string[] {
  if (!g.climate || !(g.freeze ?? 0)) return pool;
  const out = [...pool];
  for (const id of TRACK_EVENTS) if (pool.includes(id)) for (let i = 1; i < CL.freezeTrack; i += 1) out.push(id);
  return out;
}
