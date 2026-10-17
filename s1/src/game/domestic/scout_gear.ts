import { P } from '../data';
import type { Weather } from '../omens';
import { journal } from '../state';
import type { Game, StopState } from '../state';
import { D } from './data';
import { techMult, variantOf } from './state';

// 정찰 장비와 소음(결정 360·371·373, coord fun 구현명세_정찰_연구_v2). 장비는 정찰 한 번의 대가(산출 깎임·표결 빠짐·정찰조 사상)를 덜어 주고,
// 소리 나는 장비(페달·발동기 핸드카)는 바깥 기척을 한 단계 올린다. 기척은 stop.threat를 그대로 두고 stop.noise로 단계만 옮긴다.
// 장비 없이 하거나 소리 없는 장비(망원경·수신호)로 하는 정찰은 지금처럼 피해를 안 바꾼다(정찰은 드러내기만 한다, 결정 371 1 가).

/** 바깥 기척 세 단계(turn.ts arriveStop): 고요 0.8, 보통 1, 짙음 1.4 */
export const THREAT_STEPS = [0.8, 1, 1.4] as const;
export const THREAT_STEP_NAME = ['고요', '보통', '짙음'] as const;
/** 망원경이 멀리 못 보는 정차 날씨(결정 373) */
export const GLASS_BLIND: Weather[] = ['fog', 'blizzard', 'sleet'];
const BLIND_NAME: Partial<Record<Weather, string>> = { fog: '안개', blizzard: '눈보라', sleet: '진눈깨비' };

export type GearKey = 'glass' | 'signal' | 'cart';
/** 가진 장비마다 techMult(완성판 1, 결함판 0.5). 없으면 0 */
export interface GearOwned { glass: number; signal: number; pedal: number; motor: number; lure: number }
/** 정찰을 보낼 때 쓴 장비와 그 값. 산출 깎임은 보낸 순간의 값으로 정산한다 */
export interface ScoutGearUsed { glass: number; signal: number; pedal: number; motor: number; blind: boolean; noise: number; haul: number }

const NONE: GearOwned = { glass: 0, signal: 0, pedal: 0, motor: 0, lure: 0 };

export function threatStep(t: number): number {
  return t <= THREAT_STEPS[0] ? 0 : t < THREAT_STEPS[2] ? 1 : 2;
}

/** 소음을 더한 지금 기척. 소음이 없으면 원래 값 그대로다(장비 없는 판의 숫자가 바뀌지 않게). 짙음 위·고요 아래로는 안 간다 */
export function effThreat(stop: StopState | null | undefined): number {
  const t = stop?.threat ?? 1;
  const n = stop?.noise ?? 0;
  if (!n) return t;
  return THREAT_STEPS[Math.max(0, Math.min(2, threatStep(t) + n))];
}

/** 정찰 장비를 켠다. 켜지 않은 판은 r4·w4를 못 복원하고 핸드카에 갈래가 없어 지금과 똑같다 */
export function enableScoutGear(g: Game): void {
  g.gearOn = true;
}

export function gearOwned(g: Game): GearOwned {
  if (!g.dom || !g.gearOn) return NONE;
  const r4 = techMult(g, 'r4');
  const x2 = techMult(g, 'x2');
  const v4 = variantOf(g, 'r4');
  const vx = variantOf(g, 'x2') ?? 'a'; // 변형이 없는 옛 저장은 페달
  return { glass: v4 === 'a' ? r4 : 0, signal: v4 === 'b' ? r4 : 0, pedal: vx === 'a' ? x2 : 0, motor: vx === 'b' ? x2 : 0, lure: techMult(g, 'w4') };
}

/** 이번 정찰에 가져가는 장비. 가진 장비는 기본으로 가져가고, 정차 화면에서 하나씩 두고 갈 수 있다(stop.gear) */
export function gearTaken(g: Game, stop: StopState): GearOwned {
  const o = gearOwned(g);
  const off = stop.gear ?? {};
  return { glass: off.glass === false ? 0 : o.glass, signal: off.signal === false ? 0 : o.signal, pedal: off.cart === false ? 0 : o.pedal, motor: off.cart === false ? 0 : o.motor, lure: o.lure };
}

/** 장비 하나를 두고 가거나 다시 가져간다. 정찰을 보낸 뒤엔 못 바꾼다 */
export function toggleGear(g: Game, key: GearKey): void {
  const stop = g.stop;
  if (!stop || stop.done || stop.scoutReport) return;
  const gear = (stop.gear ??= {});
  gear[key] = gear[key] === false;
}

/** 정찰 한 번의 값: 정찰조 수, 정찰조 위험 곱, 보낼 때 더하는 소음, 정찰 산출 곱 */
export function scoutPlan(g: Game, stop: StopState): ScoutGearUsed & { size: number; risk: number } {
  const t = gearTaken(g, stop);
  const blind = t.glass > 0 && GLASS_BLIND.includes(stop.weather ?? 'snow');
  let risk = 1;
  if (t.glass > 0 && !blind) risk *= 1 - D.glassRisk * t.glass;
  if (t.signal > 0) risk *= D.signalRisk;
  if (t.motor > 0) risk *= 1 - D.motorRisk * t.motor;
  const calm = threatStep(stop.threat ?? 1) === 0;
  const noise = (t.pedal > 0 && calm ? 1 : 0) + (t.motor > 0 ? 1 : 0);
  const haul = Math.min(1, P.scoutHaul + D.pedalHaul * t.pedal + D.motorHaul * t.motor);
  return { size: t.signal > 0 ? D.signalSize : P.scoutSize, risk, noise, haul, blind, glass: t.glass, signal: t.signal, pedal: t.pedal, motor: t.motor };
}

/** 정산의 정찰 산출 곱. 정찰을 안 했으면 1, 장비 없이 했으면 P.scoutHaul */
export function scoutHaulNow(stop: StopState): number {
  if (!stop.scoutReport) return 1;
  return stop.scoutGear?.haul ?? P.scoutHaul;
}

/** sendScouts가 정찰조를 굴린 뒤 부른다: 쓴 장비를 적고 소음을 더한다. 소리는 이미 났으니 정찰조가 돌아오든 아니든 더한다 */
export function applyScoutGear(g: Game, stop: StopState, plan: ReturnType<typeof scoutPlan>): void {
  const used = (({ glass, signal, pedal, motor, blind, noise, haul }) => ({ glass, signal, pedal, motor, blind, noise, haul }))(plan);
  if (used.glass || used.signal || used.pedal || used.motor) stop.scoutGear = used;
  if (plan.noise) stop.noise = (stop.noise ?? 0) + plan.noise;
  if (plan.blind) journal(g, `${BLIND_NAME[stop.weather ?? 'fog'] ?? '안개'}에 가려 망원경으로 멀리 보지 못했다.`);
}

/** 미끼를 못 거는 까닭. 걸 수 있으면 undefined */
export function lureBlock(g: Game): string | undefined {
  const stop = g.stop;
  if (!g.dom || gearOwned(g).lure <= 0) return '미끼가 없다';
  if (!stop || stop.done || !stop.scoutReport) return '정찰 뒤에 건다';
  if (!stop.scout) return '정찰조가 돌아오지 않았다';
  if (stop.lured) return '이미 걸었다';
  if (threatStep(effThreat(stop)) === 0) return '이미 고요하다';
  if (g.dom.parts < D.lureParts) return '부품이 모자라다';
  return undefined;
}

/** 태엽 소리 미끼를 건다: 기척 한 단계 아래로, 부품 1 */
export function hangLure(g: Game): boolean {
  if (lureBlock(g)) return false;
  const stop = g.stop!;
  g.dom!.parts -= D.lureParts;
  stop.noise = (stop.noise ?? 0) - 1;
  stop.lured = true;
  journal(g, `태엽 소리가 망자를 반대편으로 끌었다. 지금 기척: ${THREAT_STEP_NAME[threatStep(effThreat(stop))]}.`);
  return true;
}

/** 정찰 뒤 「지금」 줄. 소음으로 단계가 바뀐 정차에서, 정찰조가 돌아와 기척을 알 때만 쓴다. 정차가 끝나면 소음도 끝난다 */
export function scoutNowText(stop: StopState): string | null {
  if (!stop.scout || !stop.noise) return null;
  const seen = threatStep(stop.threat ?? 1);
  const now = threatStep(effThreat(stop));
  if (seen === now && !stop.lured) return null;
  const u = stop.scoutGear;
  const cause = stop.lured && now < seen ? '태엽 소리가 망자를 반대편으로 끌었다.'
    : u?.motor ? '발동기 소리에 안쪽이 술렁인다.' : u?.pedal ? '쇠바퀴 소리에 안쪽이 술렁인다.' : '태엽 소리가 망자를 반대편으로 끌었다.';
  return `${cause} 지금 기척: ${THREAT_STEP_NAME[now]}(정찰조가 본 것: ${THREAT_STEP_NAME[seen]}).`;
}
