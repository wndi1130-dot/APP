import { COMMS } from '../game';
import type { Comm, Game } from '../game';

// 선택하면 위 막대에서 바뀐 수치가 튀어 오른다(2026-10-07 사용자: "위에 변하는 거 이펙트를 강하게"). 계산은 안 바꾸고 보이기만 한다.
// 바뀐 계기는 한 번 크게 부풀며 색이 번지고, 그 자리에서 +5/−3 숫자가 떠올랐다 사라진다. 관계가 바뀐 칸은 띠 밑에 칸 이름과 함께 뜬다.
// 크게 나쁜 일(신임 −5 이상, 긴장 +5 이상, 사람이 죽음)이면 위 막대가 짧게 흔들리고 폰이면 한 번 떨린다.

export type FxKey = 'trust' | 'tension' | 'coal' | 'food' | 'med' | 'lux';
export interface Fx { id: number; d: Partial<Record<FxKey, number>>; rel: Partial<Record<Comm, number>>; hard: boolean }
export interface FxSnap { v: Record<FxKey, number>; rel: Record<Comm, number>; deaths: number }

export const FX_MS = 1700;
/** 위 막대에서 좋은 쪽: 긴장은 오를수록 나쁘다 */
export const FX_GOOD_UP: Record<FxKey, boolean> = { trust: true, tension: false, coal: true, food: true, med: true, lux: true };

export function fxSnap(g: Game): FxSnap {
  return {
    v: { trust: g.trust, tension: g.tension, coal: g.coal, food: g.food, med: g.med, lux: g.lux },
    rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number>,
    deaths: g.deaths.length,
  };
}

let nextId = 1;
/** 고르기 전과 뒤를 견줘 보일 변화. 반올림해서 0이면 안 보인다. 아무것도 안 바뀌었으면 null */
export function fxDiff(before: FxSnap, g: Game): Fx | null {
  const after = fxSnap(g);
  const d: Fx['d'] = {};
  for (const k of Object.keys(after.v) as FxKey[]) {
    const v = Math.round(after.v[k] - before.v[k]);
    if (v !== 0) d[k] = v;
  }
  const rel: Fx['rel'] = {};
  for (const c of COMMS) {
    const v = Math.round(after.rel[c] - before.rel[c]);
    if (v !== 0) rel[c] = v;
  }
  if (Object.keys(d).length === 0 && Object.keys(rel).length === 0 && after.deaths === before.deaths) return null;
  const hard = (d.trust ?? 0) <= -5 || (d.tension ?? 0) >= 5 || after.deaths > before.deaths;
  return { id: nextId++, d, rel, hard };
}

/** 계기 하나의 연출 꼬리표: 좋음/나쁨 클래스와 떠오르는 숫자 글 */
export function fxTag(fx: Fx | null, key: FxKey): { cls: string; text: string } | null {
  const v = fx?.d[key];
  if (!fx || !v) return null;
  const good = v > 0 === FX_GOOD_UP[key];
  return { cls: good ? 'fx-good' : 'fx-bad', text: v > 0 ? `+${v}` : `−${Math.abs(v)}` };
}
