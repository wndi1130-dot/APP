import { bump, bumpRel } from '../ledger';
import { COMMS } from '../data';
import { addCard, journal, lawActive, rnd } from '../state';
import type { Game } from '../state';
import type { DomPerson } from './state';
import { D } from './data';
import { refreshSit } from './sit';

// 식당칸 솥의 불리기(food_cooking 4.5). 칸이 아니라 식당칸의 솥 자리이고, 조리는 절약 기술이 아니다.
// 기본은 '그대로'이고 건드리지 않은 판은 숫자도 난수도 그대로다(골든 불변).
// 여기 든 것은 셋이다: 그대로(plain), 묽게(thin), 섞어서(mixed). '밝히고 섞어서'는 법이 하나 느는 일이라 정치 쪽 몫으로 남겼다.
// 숫자는 모두 제안이다(domestic/data.ts의 pot* 값).
// 탈이 났을 때의 까닭은 빵이다. 사람이나 칸 탓으로 쓰지 않고, 섞는 몫을 칸마다 가르지 않는다(브리프 8장).

export const POT_MODES = ['plain', 'thin', 'mixed'] as const;
export type PotMode = typeof POT_MODES[number];

export interface PotState {
  mode: PotMode;
  /** 쌓인 들킬 확률(기본 확률에 더한다). 섞은 구간마다 오르고 쉬면 내린다 */
  heat: number;
  /** 묽게를 잇달아 쓴 구간 수 */
  thinRun: number;
  /** 판에서 묽게·섞어서를 쓴 구간 수와 들킨 횟수(재기) */
  thinSegs: number;
  mixedSegs: number;
  caught: number;
  /** 마지막으로 들킨 구간 */
  caughtAt?: number;
  /** 조리 담당(내정 사람 id). 시제품 */
  cook?: string;
}

const NONE: Readonly<PotState> = { mode: 'plain', heat: 0, thinRun: 0, thinSegs: 0, mixedSegs: 0, caught: 0 };

/** 솥의 지금 상태. 고른 적 없는 판(옛 저장 포함)은 '그대로'로 읽는다. 판에 칸을 만들지 않는다. */
export function potOf(g: Game): Readonly<PotState> {
  return g.dom?.pot ?? NONE;
}

/** 그 방식을 지금 고를 수 있나. 식량이 0이면 불릴 것이 없고, 섞으려면 목재가 있어야 한다. */
export function potUsable(g: Game, mode: PotMode): { ok: boolean; why?: string } {
  const d = g.dom;
  if (mode === 'plain') return { ok: true };
  if (!d) return { ok: false, why: '내정을 켠 판에서만 고른다' };
  if (D.potCook && !potCook(g)) return { ok: false, why: '담당 없음' };
  if (g.food <= 0) return { ok: false, why: '불릴 식량이 없다' };
  if (mode === 'mixed' && d.wood < D.potMixWood) return { ok: false, why: '섞을 목재가 없다' };
  return { ok: true };
}

/** 조리 담당(살아서 열차에 있는 사람만). 시제품 */
export function potCook(g: Game): DomPerson | undefined {
  const id = g.dom?.pot?.cook;
  return id ? g.dom?.people.find(p => p.id === id && p.alive && !p.gone) : undefined;
}

/** 조리 담당을 세우거나(id) 내린다(null). 시제품 */
export function setPotCook(g: Game, id: string | null): void {
  const d = g.dom;
  if (!d) return;
  if (id && !d.people.some(p => p.id === id && p.alive && !p.gone)) return;
  d.pot = { ...potOf(g), cook: id ?? undefined };
}

/** 솥의 방식을 고른다(열차 전체에 하나). 못 고르는 방식이면 그대로 둔다. */
export function setPot(g: Game, mode: PotMode): void {
  const d = g.dom;
  if (!d || !potUsable(g, mode).ok) return;
  if (mode === 'plain' && !d.pot) return;
  d.pot = { ...potOf(g), mode };
  refreshSit(g);
}

/** 이번 구간 솥이 실제로 도는 방식. 섞어서를 골랐어도 목재가 떨어졌으면 그대로다. */
export function potActive(g: Game): PotMode {
  const d = g.dom;
  const mode = d?.pot?.mode ?? 'plain';
  return mode === 'mixed' && (d?.wood ?? 0) < D.potMixWood ? 'plain' : mode;
}

/** 방식별 식량 소모 곱. */
export function potMult(mode: PotMode): number {
  return mode === 'thin' ? D.potThinFood : mode === 'mixed' ? D.potMixFood : 1;
}

/** 이번 구간 식량 소모에 곱하는 값(domesticForecast가 읽는다). */
export function potFoodMult(g: Game): number {
  return potMult(potActive(g));
}

/** 이번 구간에 섞으면 들킬 확률(0~1). */
export function potRisk(g: Game): number {
  const cook = D.potCook ? potCook(g) : undefined;
  const sour = cook && g.comms[cook.comm].rel < 0 ? D.potCookRisk : 0;
  return Math.min(1, D.potRisk0 + potOf(g).heat + sour);
}

/** 정산 때 솥 한 구간. 공방이 목재를 쓰기 전에 부른다(예고와 같은 목재를 본다). '그대로'면 아무것도 하지 않고 난수도 굴리지 않는다. */
export function potTick(g: Game, notes: string[]): void {
  const d = g.dom;
  const pot = d?.pot;
  if (!d || !pot) return;
  if (D.potCook && pot.mode !== 'plain' && !potCook(g)) {
    pot.mode = 'plain';
    notes.push('솥을 맡은 사람이 없어 솥이 그대로로 돌아갔다.');
  }
  const mode = potActive(g);
  if (pot.mode === 'mixed' && mode !== 'mixed') {
    pot.mode = 'plain';
    notes.push('섞을 목재가 떨어져 솥이 그대로로 돌아갔다.');
  }
  if (mode === 'mixed') {
    d.wood -= D.potMixWood;
    pot.mixedSegs += 1;
    const risk = potRisk(g);
    pot.heat += D.potRiskUp;
    if (rnd(g) < risk) caught(g, pot, notes);
  } else {
    pot.heat = Math.max(0, pot.heat - D.potRiskDown);
  }
  if (mode === 'thin') { pot.thinRun += 1; pot.thinSegs += 1; } else pot.thinRun = 0;
  if (pot.mode !== 'plain' && g.food <= 0) {
    pot.mode = 'plain';
    notes.push('불릴 식량이 없어 솥이 그대로로 돌아갔다.');
  }
}

/** 섞은 것이 드러났다: 신임, 모든 칸 관계, 긴장. 공동 식당 법이 서 있었으면 법을 속인 것이라 신임 벌이 곱절이다. */
function caught(g: Game, pot: PotState, notes: string[]): void {
  const law = lawActive(g, 'common_kitchen');
  bump(g, 'trust', -D.potCaughtTrust * (law ? D.potCaughtLaw : 1), 'pot');
  for (const c of COMMS) bumpRel(g, c, -D.potCaughtRel, 'pot');
  bump(g, 'tension', D.potCaughtTension, 'pot');
  pot.mode = 'plain';
  pot.caught += 1;
  pot.caughtAt = g.seg;
  const text = law
    ? '빵에서 나무 맛이 난다는 말이 칸마다 돌았다. 솥에 톱밥을 섞은 것이 드러났다. 공동 식당 법을 세워 놓고 속인 일이라 더 크게 번진다.'
    : '빵에서 나무 맛이 난다는 말이 칸마다 돌았다. 솥에 톱밥을 섞은 것이 드러났다.';
  addCard(g, { kind: 'info', who: '섞은 빵이 드러났다', text });
  journal(g, '솥에 톱밥을 섞은 것이 드러났다. 솥은 그대로로 돌아갔다.', 'bad');
  notes.push('섞은 빵이 드러났다.');
}
