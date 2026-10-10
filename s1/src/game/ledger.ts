import { clamp } from './state';
import type { Game } from './state';
import type { Comm } from './data';

// 까닭 장부: 규칙이 수치를 바꾸는 그 자리에서 「무엇 때문에」를 같이 적는다.
// 숫자는 한 톨도 바꾸지 않는다. 자르는 방식은 옮기기 전 그 자리의 것을 그대로 따른다
// (신임·긴장은 늘 0..100, 자원은 그대로 두되 그 자리가 0에서 막았으면 floor0, 관계는 −100..100).
// 숫자가 그대로인지는 tests/game/golden.test.ts가 본다.
// 까닭 열쇠는 영어로 두고 화면에 보이는 이름은 화면 쪽 표(ui/why_names.ts)에 둔다.
// 'card'는 「지금 한 행동 그 자체」라는 뜻이라 화면이 행동 이름으로 적는다.

export type Stat = 'trust' | 'tension' | 'coal' | 'food' | 'med' | 'lux';
export type LedgerKey = Stat | `rel:${Comm}`;
export interface LedgerRow { k: LedgerKey; d: number; why: string }

/** 장부에 남기는 줄 수. 화면이 행동마다 비운다. 화면 없이 수천 구간을 돌려도 끝없이 자라지 않게 한다. */
export const LEDGER_MAX = 64;

function note(g: Game, k: LedgerKey, d: number, why: string): void {
  if (d === 0) return;
  const rows = (g.ledger ??= []);
  rows.push({ k, d, why });
  if (rows.length > LEDGER_MAX) rows.splice(0, rows.length - LEDGER_MAX);
}

/** 수치를 d만큼 바꾸고 실제로 바뀐 만큼을 까닭과 함께 적는다. */
export function bump(g: Game, k: Stat, d: number, why: string, opt?: { floor0?: boolean }): void {
  const before = g[k];
  const raw = before + d;
  g[k] = k === 'trust' || k === 'tension' ? clamp(raw, 0, 100) : opt?.floor0 ? Math.max(0, raw) : raw;
  note(g, k, g[k] - before, why);
}

/** 수치를 d만큼 한 번에 바꾸되(자르기도 한 번), 까닭은 여럿으로 나눠 적는다. parts는 [까닭, 몫]이고 몫의 비율대로 나눈다.
 *  여러 몫을 곱하고 더해 한 숫자로 움직이는 자리(구간 정산의 긴장, 운행·난방·배급을 한꺼번에 빼는 석탄)에 쓴다.
 *  몫마다 따로 bump하면 자르는 횟수가 달라져 숫자가 바뀐다. 마지막 까닭이 나머지를 받아 적은 합이 실제 변화와 꼭 같다. */
export function bumpParts(g: Game, k: Stat, d: number, parts: [string, number][], opt?: { floor0?: boolean }): void {
  const before = g[k];
  const raw = before + d;
  g[k] = k === 'trust' || k === 'tension' ? clamp(raw, 0, 100) : opt?.floor0 ? Math.max(0, raw) : raw;
  const real = g[k] - before;
  const total = parts.reduce((a, [, w]) => a + w, 0);
  if (real === 0 || parts.length === 0) return;
  let left = real;
  parts.forEach(([why, w], i) => {
    const share = i === parts.length - 1 || total === 0 ? left : real * (w / total);
    left -= share;
    note(g, k, share, why);
  });
}

/** 값을 통째로 놓는 자리(긴장을 65로, 의약품을 0으로). 차이를 적는다. */
export function put(g: Game, k: Stat, v: number, why: string): void {
  const before = g[k];
  g[k] = v;
  note(g, k, v - before, why);
}

/** 집단 관계를 d만큼 바꾼다(−100..100). */
export function bumpRel(g: Game, c: Comm, d: number, why: string): void {
  const s = g.comms[c];
  const before = s.rel;
  s.rel = clamp(before + d, -100, 100);
  note(g, `rel:${c}`, s.rel - before, why);
}

/** 쌓인 줄을 꺼내고 비운다(판에 칸을 남기지 않는다). */
export function drain(g: Game): LedgerRow[] {
  const rows = (g.ledger ?? []) as LedgerRow[];
  delete g.ledger;
  return rows;
}
