import type { Game } from '../state';
import { D } from './data';

// 의무칸 침상의 셈만 둔다(4.1, 4.6). 처지 보정(sit.ts)과 침상 규칙(medbay.ts)이 같이 읽는다.
// state.ts를 부르지 않는다: refreshSit ↔ 침상 규칙 사이의 실행 시 import 순환을 끊으려고 따로 뺐다.

export function typhusPatients(g: Game): number {
  return (g.dom?.typhus ?? []).reduce((s, t) => s + t.patients.length, 0);
}

/** 눕힐 사람. '다친 사람 먼저'면 병자는 제 칸에서 앓아 침상을 쓰지 않는다. */
export function bedNeed(g: Game): number {
  const sick = g.dom?.bedOrder === 'workers' ? 0 : typhusPatients(g);
  return Math.max(0, g.injured) + sick;
}

export function bedOverflow(g: Game): number {
  return Math.max(0, bedNeed(g) - D.beds);
}

/** 넘친 침상이 만드는 과밀(refreshSit에서 더한다): 기술·의무진 +5/명, 순번이면 넘친 사람이 제 칸으로(꼬리칸 +5). */
export function bedCrowd(g: Game): { medtech: number; tail: number } {
  const over = bedOverflow(g);
  if (over === 0) return { medtech: 0, tail: 0 };
  if (g.dom?.bedOrder === 'rota') return { medtech: D.bedCrowd * Math.min(over, 2), tail: D.bedRotaCrowd };
  return { medtech: D.bedCrowd * over, tail: 0 };
}
