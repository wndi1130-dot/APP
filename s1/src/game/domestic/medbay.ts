import { journal } from '../state';
import type { Game } from '../state';
import { D } from './data';
import { bedOverflow, typhusPatients } from './beds';
import { refreshSit } from './sit';
import { domCard, techMult } from './state';

export { bedCrowd, bedNeed, bedOverflow } from './beds';

// 의무칸 침상(4.1, 4.6)과 '누가 침상에 눕나'(10장 11번). 침상 6을 부상자와 발진티푸스 환자가 나눠 쓴다.
// 폐렴 환자(body_injury 4.5)는 S1a 판에 아직 없어서 셈에 넣지 않는다. 들어오면 bedNeed에 더한다.

export type BedOrder = 'workers' | 'sick' | 'rota';

/** 정산 때: 침상이 처음 넘치면 카드, 넘친 만큼 과밀은 refreshSit이 읽는다. */
export function bedTick(g: Game): void {
  const d = g.dom;
  if (!d) return;
  const need = Math.max(0, g.injured) + typhusPatients(g);
  if (d.bedOrder === null && need > D.beds && !g.cards.some(c => c.kind === 'dom:bed')) domCard(g, { kind: 'dom:bed', n: need });
}

export function setBedOrder(g: Game, order: BedOrder): void {
  const d = g.dom;
  if (!d) return;
  // 처음 정할 때의 관계(일할 손 먼저: 기관실·경비대 +2, 꼬리칸 −2 / 아픈 사람 먼저: 의무진 +2)는 카드의 효과 줄이 적용한다.
  d.bedOrder = order;
  journal(g, `의무칸 침상 순서: ${order === 'workers' ? '일할 손 먼저' : order === 'sick' ? '가장 아픈 사람 먼저' : '순번'}.`);
  refreshSit(g);
}

/** 부상 회복 확률(S1a 0.4 또는 법으로 오른 값)에 S1c가 더하는 것: M1 +0.1, 의무칸을 병자에게 내줬으면 멈춤,
 * '병자 먼저'로 침상이 넘치면 부상 회복 50% → 40%(10장 11번). */
export function domesticHeal(g: Game, heal: number): number {
  const d = g.dom;
  if (!d) return heal;
  if (d.typhus.some(t => t.bay && t.patients.length > 0)) return 0;
  let h = heal + 0.1 * techMult(g, 'm1');
  if (d.bedOrder === 'sick' && bedOverflow(g) > 0) h = Math.min(h, D.bedSickHeal);
  return h;
}

