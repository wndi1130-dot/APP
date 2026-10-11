import type { Comm } from './data';
import { lawActive, PROFILES } from './state';
import type { Game } from './state';
import { D } from './domestic/data';
import { domesticForecast } from './domestic/hooks';
import { POT_MODES, potActive, potMult, potOf, potRisk, potUsable } from './domestic/pot';
import type { PotMode } from './domestic/pot';
import { forecast, rationComm } from './turn';

// 식당칸 솥을 화면이 읽는 값(읽기만 한다. 판을 바꾸지 않는다). 고르는 일은 domestic/pot.ts의 setPot이 한다.

export interface PotChoice {
  mode: PotMode;
  /** 지금 고를 수 있나. 못 고르면 why에 까닭 한 줄 */
  ok: boolean;
  why?: string;
  /** 이 방식이면 다음 구간에 드는 식량과, 그대로일 때보다 덜 드는 양 */
  food: number;
  saved: number;
  /** 구간마다 드는 목재 */
  wood: number;
  /** 이번 구간에 들킬 확률(0~1). 섞어서만 0이 아니다 */
  risk: number;
}

export interface PotView {
  /** 솥을 고를 수 있는 판인가(내정을 켠 판) */
  on: boolean;
  /** 고른 방식과, 이번 구간 실제로 도는 방식(목재가 떨어지면 그대로) */
  mode: PotMode;
  active: PotMode;
  /** 다음 구간 식량 소모와 그대로일 때보다 덜 드는 양 */
  food: number;
  saved: number;
  /** 이번 구간에 들킬 확률(0~1) */
  risk: number;
  /** 들키면 신임 벌이 곱절인가(공동 식당 법이 서 있다) */
  lawDouble: boolean;
  /** 묽게를 잇달아 쓴 구간 수, 들킨 횟수 */
  thinRun: number;
  caught: number;
  /** 가진 목재 */
  wood: number;
  /** 조리 담당(배급장). 이름을 정해 둔 판이 아니면 name은 null이고 사는 칸만 있다 */
  cook: { comm: Comm; name: string | null };
  choices: PotChoice[];
}

export function potView(g: Game): PotView {
  const d = g.dom;
  const pot = potOf(g);
  const active = potActive(g);
  const dom = domesticForecast(g);
  // forecast의 식량 = (배급 + 법) × 솥 곱 + 내정의 덧셈 몫. 솥 곱만 바꿔 방식별로 다시 센다.
  const base = (forecast(g).food - dom.food) / dom.foodMult;
  const foodAt = (m: PotMode): number => base * potMult(m) + dom.food;
  const plain = foodAt('plain');
  const riskAt = (m: PotMode): number => (m === 'mixed' ? potRisk(g) : 0);
  const cookId = g.dark?.staff.ration;
  return {
    on: !!d, mode: pot.mode, active,
    food: foodAt(active), saved: plain - foodAt(active), risk: riskAt(active),
    lawDouble: lawActive(g, 'common_kitchen'), thinRun: pot.thinRun, caught: pot.caught, wood: d?.wood ?? 0,
    cook: { comm: rationComm(g), name: (cookId ? PROFILES.find(p => p.id === cookId)?.name : undefined) ?? null },
    choices: (d ? POT_MODES : (['plain'] as const)).map(mode => ({
      mode, ...potUsable(g, mode), food: foodAt(mode), saved: plain - foodAt(mode),
      wood: mode === 'mixed' ? D.potMixWood : 0, risk: riskAt(mode),
    })),
  };
}
