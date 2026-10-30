import { COMMS, P } from './data';
import type { Comm } from './data';
import { handsWill, workShare } from './hands';
import { bump, bumpRel } from './ledger';
import { lawActive } from './state';
import type { Game } from './state';

/** 정차 부산물. 목표 자원(LOOT_KEYS)에는 넣지 않아 기존 배분·난수 순서를 보존한다. */
export const SUP_YIELD: Readonly<Record<string, number>> = Object.freeze({
  houses: 5, church: 2, office: 2, hospital: 2, freight: 1, factory: 1,
});

/** 결정 490 둘째 PR의 제안 값. 공방 생산량은 실수로 셈한다. */
export const SUP_MAKE = {
  supMakeWork: 0.5, supMakeScrap: 1, supMakeCap: 0.25, fineScrap: 2,
  variants: { a: { work: 0.7, scrap: 1.25, yield: 1 }, b: { work: 1.3, scrap: 1.5, yield: 1.5 } },
};

/** 봇만 거는 판별 정책. 저장 상태와 난수에 넣지 않고 일반 판에는 없다. */
export const SUPPLIES_BOT = new WeakMap<Game, {
  make: 'none' | 'last' | 'first';
  /** 셋째 PR 전 규칙을 재는 대조군만 false. 일반 판에는 이 정책이 없다. */
  ask?: boolean;
  beforeWork?: (g: Game) => void;
}>();

export function suppliesAsks(g: Game): boolean {
  return !!g.supOn && SUPPLIES_BOT.get(g)?.ask !== false;
}

export type SuppliesSource = 'stop.loot' | 'sup.search' | 'field.loot' | 'sup.make';
export interface SuppliesTurn {
  need: number;
  use: number;
  cover: Partial<Record<Comm, number>>;
  plenty: boolean;
}

/** 재기 도구가 잠깐 거는 관찰점. full의 보충은 도구 안에서만 하며 게임 옵션·규칙에는 없다. */
export const SUPPLIES_PROBE: {
  beforeUse?: (g: Game, need: number) => void;
  afterUse?: (g: Game, turn: SuppliesTurn) => void;
  onGain?: (g: Game, amount: number, source: SuppliesSource) => void;
  /** 좋은 물건도 포함한 공방 산출. onGain은 실제 생필품 입고만 센다. */
  onMake?: (g: Game, amount: number, fine: boolean) => void;
  onRestore?: (g: Game) => void;
} = {};

/** 정찰 장비·기온과 같은 명시적 켜기. 기본 판은 이 함수를 부르지 않는다. */
export function enableSupplies(g: Game): void {
  g.supOn = true;
  g.sup = P.sup0;
  g.supCover = {};
}

export function suppliesNeed(g: Game): number {
  return COMMS.reduce((sum, c) => sum + Math.max(0, g.comms[c].pop) / 100 * P.supPer100, 0);
}

/** 충족률은 백만분의 일로 맞춘다: 기여 배급의 뺄셈 오차가 정확히 절반을 0.4999…로 만들어 위생 문턱을 넘지 않게(PR 969 점검). */
const coverOf = (got: number, own: number): number => Math.round(got / own * 1e6) / 1e6;
/** 넉넉함 비교의 허용 오차: 필요량의 세 배를 채우면 쓴 뒤 0.5999…가 남는다. */
const SUP_EPS = 1e-9;

/** 위생 정산 전에 이번 구간의 몫을 남긴다. 난수를 뽑지 않는다. */
export function suppliesUse(g: Game): SuppliesTurn | undefined {
  if (!g.supOn) return;
  const living = COMMS.filter(c => g.comms[c].pop > 0);
  const need = suppliesNeed(g);
  SUPPLIES_PROBE.beforeUse?.(g, need);
  const use = Math.min(Math.max(0, g.sup ?? 0), need);
  const cover: Partial<Record<Comm, number>> = {};
  if (!lawActive(g, 'contribution_ration') || use === need) {
    for (const c of living) cover[c] = need > 0 ? coverOf(use, need) : 1;
  } else {
    // 일을 낸 손: 인구 × 일할 나이 몫 × 손을 내는 뜻. 정산 때 쉬러 돌아온 작업조(away)도 그 구간 일을 낸 사람이라
    // 빼지 않는다(handsOffered는 지금 자리에 있는 손만 세서, 방금 정차에 나간 칸이 뒤로 밀렸다 — PR 969 점검).
    const ranked = living.map(c => ({ c, hands: Math.max(0, g.comms[c].pop) * workShare(c) * handsWill(g, c) }))
      .sort((a, b) => b.hands - a.hands || COMMS.indexOf(a.c) - COMMS.indexOf(b.c));
    let left = use;
    for (const { c } of ranked) {
      const own = g.comms[c].pop / 100 * P.supPer100;
      const got = Math.min(left, own);
      cover[c] = coverOf(got, own);
      left = Math.max(0, left - got);
    }
  }
  bump(g, 'sup', -use, 'sup.use');
  g.supCover = cover;
  const turn = { need, use, cover, plenty: need > 0 && (g.sup ?? 0) >= P.supPlentyNeeds * need - SUP_EPS };
  SUPPLIES_PROBE.afterUse?.(g, turn);
  return turn;
}

/** 처지 회복의 관계 15 천장과 별개이므로 drift 뒤에 더한다. */
export function suppliesRelations(g: Game, turn: SuppliesTurn | undefined): void {
  if (!g.supOn || !turn) return;
  for (const c of COMMS) {
    const f = turn.cover[c];
    if (g.comms[c].pop <= 0 || f === undefined) continue;
    if (f < 1) bumpRel(g, c, -P.supShortRel * (1 - f), 'sup');
    if (turn.plenty) bumpRel(g, c, P.supPlentyRel, 'sup');
  }
}

export function suppliesHygieneShort(g: Game, c: Comm): boolean {
  return !!g.supOn && g.comms[c].pop > 0 && (g.supCover?.[c] ?? 1) < P.supHygieneCover;
}

/** 필드의 음수 증감도 장부 규칙대로 0에서 멈춘다. 재기에는 실제 양수 입고만 센다. */
export function addSupplies(g: Game, amount: number, source: SuppliesSource): void {
  if (!g.supOn) return;
  const before = g.sup ?? 0;
  bump(g, 'sup', amount, source);
  const gain = (g.sup ?? 0) - before;
  if (gain > 0) SUPPLIES_PROBE.onGain?.(g, gain, source);
}
