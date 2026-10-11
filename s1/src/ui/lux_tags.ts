import type { Game } from '../game';

// 사치품 이름표(결정 071): 규칙의 사치품은 숫자 하나(g.lux) 그대로고, 화면만 얻은 곳에 따라 이름표를 붙여 갈라 보인다.
// 이름표는 화면이 행동을 적용할 때(repro.ts applyStep) 붙이고 뗀다. 규칙은 읽지 않고 난수도 쓰지 않는다.

/** 정차 장소마다 나오는 사치품 이름. 차례대로 돌아가며 붙는다. 상징물(깃발·종·사진)과 종교 물건은 넣지 않는다. */
export const LUX_POOL: Record<string, string[]> = {
  houses: ['술', '담배', '커피', '축음기판', '그림'],
  office: ['시계', '은수저'],
  church: ['악보', '양초'],
  freight: ['담배', '커피'],
  factory: ['담배', '술'],
};
const POOL_ELSE = ['술', '담배', '커피'];
/** 이름표가 없는 몫(시작할 때 실려 있던 것, 거래로 받은 것, 옛 저장) */
export const LUX_REST = '그 밖';

type Bag = Pick<Game, 'lux' | 'luxTags'>;

/** 얻은 사치품 n개에 붙일 이름표. 그 장소의 묶음을 지금 가진 수에서 이어 돌린다. */
export function luxGain(have: number, place: string | undefined, n: number): string[] {
  const pool = (place && LUX_POOL[place]) || POOL_ELSE;
  return Array.from({ length: Math.max(0, Math.round(n)) }, (_, i) => pool[(have + i) % pool.length]!);
}

/** 지금 가진 사치품을 낱개 이름으로 편다. 앞이 먼저 나간다. 이름표가 모자라면 「그 밖」으로 채우고 남으면 뒤를 자른다. */
export function luxItems(g: Bag): string[] {
  const n = Math.max(0, Math.round(g.lux));
  const tags = (g.luxTags ?? []).slice(0, n);
  return [...tags, ...Array.from({ length: n - tags.length }, () => LUX_REST)];
}

function grouped(items: string[]): string {
  const count = new Map<string, number>();
  for (const t of items) count.set(t, (count.get(t) ?? 0) + 1);
  const rest = count.get(LUX_REST);
  count.delete(LUX_REST);
  const parts = [...count].map(([t, v]) => `${t} ${v}`);
  if (rest) parts.push(`${LUX_REST} ${rest}`);
  return parts.join(' · ');
}

/** 「술 4 · 담배 3 · 그 밖 1」. 이름표가 하나도 없으면 빈 글. */
export function luxBreakdown(g: Bag): string {
  const items = luxItems(g);
  return items.some(t => t !== LUX_REST) ? grouped(items) : '';
}

/** 값 n을 치르면 무엇이 나가나(앞에서부터). 이름표가 하나도 안 걸리면 빈 글. */
export function luxFront(g: Bag, n: number): string {
  const items = luxItems(g).slice(0, Math.max(0, Math.round(n)));
  return items.some(t => t !== LUX_REST) ? grouped(items) : '';
}

/** 행동 하나 뒤에 이름표를 맞춘다. 줄면 앞에서부터 떼고, 정차 수확으로 늘면 그 장소의 이름을 붙인다. 그 밖에 는 몫은 이름표 없이 둔다. */
export function syncLuxTags(g: Game, was: number, now: number, loot: { place: string; n: number } | null): void {
  const d = now - was;
  if (d === 0) return;
  let tags = luxItems({ lux: was, luxTags: g.luxTags });
  if (d < 0) tags = tags.slice(-d);
  if (d > 0) {
    const named = loot ? luxGain(tags.length, loot.place, Math.min(d, loot.n)) : [];
    tags = [...tags, ...named, ...Array.from({ length: d - named.length }, () => LUX_REST)];
  }
  // 뒤쪽의 「그 밖」은 적지 않아도 읽을 때 채워진다. 이름표가 하나도 없으면 칸을 만들지 않는다.
  while (tags.length && tags[tags.length - 1] === LUX_REST) tags.pop();
  if (tags.length) g.luxTags = tags; else delete g.luxTags;
}
