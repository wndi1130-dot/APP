import type { Comm } from './data';
import { lawActive } from './state';
import type { Game } from './state';

// 비상식량감축법(결정 083·091·430)이 선 뒤 꼬리칸이 내는 요구 카드(cards.ts 'ration_cut')의 답.
// 답 셋: 꼬리칸은 뺀다 / 앞칸이 먼저 낸다 / 거절. 고른 답은 칸 배급 처지와 아끼는 식량을 바꾸고,
// 법을 폐지하면 처지 보정을 되돌린다(politics.ts repealLaw). 값은 새로 넣은 제안 값이다.

export type RationCutPick = 'spare_tail' | 'front_first' | 'refuse';

export const RATION_CUT = {
  /** 법이 모든 칸 배급 처지에서 깎는 값(반 단). LAWS.emergency_ration.mats와 같다 */
  sit: 6,
  /** 꼬리칸을 빼면 구간마다 아끼는 식량. 고르게일 때는 LAWS의 foodAdd(−2.5) */
  spareFood: -1.5,
  /** 답마다 관계·긴장(카드 효과) */
  spareRel: { tail: 6, front: -3 },
  frontRel: { tail: 4, front: -10 },
  refuseRel: -4,
  refuseTension: 2,
} as const;

export interface RationCutState {
  pick: RationCutPick;
  /** 이 답이 칸 처지(base[1])에 더한 값. 폐지 때 그대로 뺀다 */
  base: Partial<Record<Comm, number>>;
}

/** 요구 카드에서 고른 답을 적용한다. 법이 이미 내려갔으면(카드가 늦게 골라졌으면) 아무것도 하지 않는다. */
export function applyRationCut(g: Game, pick: RationCutPick): void {
  if (!lawActive(g, 'emergency_ration') || g.rationCut) return;
  const base: Partial<Record<Comm, number>> = pick === 'spare_tail' ? { tail: RATION_CUT.sit }
    : pick === 'front_first' ? { tail: RATION_CUT.sit, front: -RATION_CUT.sit } : {};
  for (const [c, v] of Object.entries(base) as [Comm, number][]) g.comms[c].base[1] += v;
  g.rationCut = { pick, base };
}

/** 법을 폐지할 때: 답이 더한 처지를 되돌리고, 아직 안 고른 요구 카드는 거둔다. */
export function revertRationCut(g: Game): void {
  g.cards = g.cards.filter(card => card.kind !== 'ration_cut');
  if (g.lateOn && g.lateCards) g.lateCards = g.lateCards.filter(card => card.kind !== 'ration_cut');
  const rc = g.rationCut;
  if (!rc) return;
  for (const [c, v] of Object.entries(rc.base) as [Comm, number][]) g.comms[c].base[1] -= v;
  delete g.rationCut;
}

/** 법의 foodAdd를 답에 맞춘다: 꼬리칸을 빼면 덜 아낀다. */
export function rationCutFood(g: Game, v: number): number {
  return g.rationCut?.pick === 'spare_tail' ? RATION_CUT.spareFood : v;
}
