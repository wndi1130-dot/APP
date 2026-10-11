import type { Comm } from './data';
import { lawActive, PROFILES } from './state';
import type { Game } from './state';
import { D } from './domestic/data';
import { domesticForecast } from './domestic/hooks';
import { POT_MODES, potActive, potCook, potMult, potOf, potRisk, potSick, potSickRisk, potUsable } from './domestic/pot';
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
  /** 이번 구간에 탈이 날 확률(0~1). 섞어서만 0이 아니다 */
  sickRisk: number;
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
  /** 솥을 맡은 사람(setPotCook으로 세운다). 없으면 null. cookNeeded면 담당이 있어야 묽게·섞어서를 고른다 */
  potCook: { id: string; name: string; comm: Comm } | null;
  cookNeeded: boolean;
  /** 이번 구간에 탈이 날 확률(0~1), 탈이 나 누운 사람 수, 그들이 일어나기까지 남은 구간 */
  sickRisk: number;
  sick: number;
  sickLeft: number;
  /** 들킨 뒤 섞어서를 못 고르는 남은 구간(0이면 안 잠김) */
  lockLeft: number;
  /** 묽게를 이대로 이으면 '묽은 죽' 불만이 나기까지 남은 구간(이번 구간이면 1). 묽게가 아니거나 그 규칙을 끈 판이면 null */
  gruelIn: number | null;
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
  const sickAt = (m: PotMode): number => (m === 'mixed' ? potSickRisk(g) : 0);
  const cookId = g.dark?.staff.ration;
  const cook = potCook(g);
  const sick = potSick(g);
  return {
    potCook: cook ? { id: cook.id, name: cook.name, comm: cook.comm } : null, cookNeeded: !!D.potCook,
    sickRisk: sickAt(active), sick, sickLeft: sick ? (pot.sickUntil ?? 0) - g.seg + 1 : 0,
    lockLeft: Math.max(0, (pot.lockUntil ?? -1) - g.seg + 1),
    gruelIn: active === 'thin' && D.potGruelRun > 0 ? Math.max(1, D.potGruelRun - pot.thinRun) : null,
    on: !!d, mode: pot.mode, active,
    food: foodAt(active), saved: plain - foodAt(active), risk: riskAt(active),
    lawDouble: lawActive(g, 'common_kitchen'), thinRun: pot.thinRun, caught: pot.caught, wood: d?.wood ?? 0,
    cook: { comm: rationComm(g), name: (cookId ? PROFILES.find(p => p.id === cookId)?.name : undefined) ?? null },
    choices: (d ? POT_MODES : (['plain'] as const)).map(mode => ({
      mode, ...potUsable(g, mode), food: foodAt(mode), saved: plain - foodAt(mode),
      wood: mode === 'mixed' ? D.potMixWood : 0, risk: riskAt(mode), sickRisk: sickAt(mode),
    })),
  };
}
