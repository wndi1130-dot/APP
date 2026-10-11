import type { TechId } from '../game';

// 기술 화면의 「둘 중 하나」 짝(결정 068): 서로 다른 기술 둘을 한 틀에 묶어 칸 하나로 보인다.
// 여기는 화면이 짝 자료를 받는 자리다. 「하나를 고르면 다른 쪽이 닫힌다」는 규칙은 규칙 쪽 몫이고, 화면은 이미 얻은 쪽이 있으면 다른 쪽을 흐리게만 그린다.
// 한 기술 안의 변형 둘(난방 배관 같은 것)은 짝이 아니다. 그 칸은 domestic.ts의 pairHalves가 그린다.

/** 짝 표. 같은 가지, 같은 단계의 기술 둘씩. 짝 표가 규칙에 들어오면 그 자료로 바꾼다. */
export const TECH_PAIRS: readonly (readonly [TechId, TechId])[] = [];

export type TierCell =
  | { kind: 'one'; id: TechId }
  | { kind: 'duo'; ids: readonly [TechId, TechId] };

/** 한 단계의 기술을 화면 칸으로 묶는다. 짝의 두 쪽이 다 이 단계에 있을 때만 한 칸이 되고, 차례는 먼저 나온 쪽을 따른다. */
export function tierCells(ids: readonly TechId[], pairs: readonly (readonly [TechId, TechId])[] = TECH_PAIRS): TierCell[] {
  const cells: TierCell[] = [];
  const used = new Set<TechId>();
  for (const id of ids) {
    if (used.has(id)) continue;
    const pair = pairs.find(p => p.includes(id) && p[0] !== p[1] && ids.includes(p[0]) && ids.includes(p[1]) && !used.has(p[0]) && !used.has(p[1]));
    if (pair) {
      used.add(pair[0]);
      used.add(pair[1]);
      cells.push({ kind: 'duo', ids: pair });
    } else {
      used.add(id);
      cells.push({ kind: 'one', id });
    }
  }
  return cells;
}

/** 짝의 두 쪽이 어떤 꼴인가: 아무것도 안 얻었으면 둘 다 열림, 한쪽을 얻었으면 그쪽만 남고 다른 쪽은 닫힘. */
export function duoStates(ids: readonly [TechId, TechId], taken: (id: TechId) => boolean): ['open' | 'on' | 'shut', 'open' | 'on' | 'shut'] {
  const a = taken(ids[0]);
  const b = taken(ids[1]);
  if (!a && !b) return ['open', 'open'];
  return [a ? 'on' : 'shut', b ? 'on' : 'shut'];
}
