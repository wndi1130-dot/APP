import { bump } from './ledger';
import { COMMS, CORPSE_LAWS, FAREWELL_LAWS } from './data';
import type { Comm, LawId } from './data';
import { addPeopleCard, DEATH_WEIGHT_HOOK, familyOf } from './people';
import { lawActive, PROFILES, storyOf } from './state';
import type { Card, DeathChain, DeathSlot, Game } from './state';

// 죽음의 무게(결정 353·354·355, 값은 결정 367). 명세 coord fun\구현명세_죽음의_무게_v1.md 2~5절.
// 기본은 꺼져 있다. 켜는 길: enableDeathWeight(g). 꺼진 판은 이 파일이 상태를 만들거나 카드를 내지 않는다(옛 판과 장부가 같다).
// 켠 판: 죽은 사람의 자리(대표·부모·아이·일손)에 따라 다른 뒷사건 카드가 오고, 칸마다 2~3구간 이어지는 사건 줄
// (원인 → 반발 → 고칠 길)이 열린다. 죽음은 열차장 신임을 깎고, 최근 죽음이 많을수록 비상 소집이 비싸다.
// 「배웅」 법 한 쌍이 남은 사람이 죽음을 치르는 방식을 정한다. 카드 글에 뒷사건을 미리 적지 않는다(결정 364).

/** 값(결정 367). 안 얼려 둬서 시뮬이 0으로 끈 판과 견줄 수 있다. 0이면 그 몫은 옛 동작이다. */
export const DW = {
  /** 죽음 한 명당 신임 깎임(결정 376: 난이도에 따라 쉬움 1·보통 2·어려움 3, 기본은 보통. 난이도 고르기는 뒤 줄기 몫이라 아직 TRUST_BY_LEVEL을 읽는 곳이 없다), 한 구간 합계 상한(난이도로 가르지 않는다) */
  trust: 2, trustCap: 6,
  /** 최근 6구간 죽음 한 명마다 비상 소집 비용 +이만큼 */
  emerg: 1,
  /** 사건 줄 반발 단계의 긴장: 원인 카드에서 거절했으면 이만큼, 아니면 chainTensionSoft */
  chainTension: 4, chainTensionSoft: 2,
  /** 같은 칸에 새 죽음이 나면 그 줄의 반발 긴장을 이만큼 더(줄마다 한 번) */
  chainBump: 2,
  /** 칸마다 줄 하나, 판 전체 동시 줄 상한, 줄이 시작한 뒤 끊기는 구간 수 */
  chainMax: 2, chainLife: 4,
  /** 원인 카드에서 들어줬고 그 칸 관계가 줄 시작 때보다 이만큼 오르면 반발을 건너뛴다 */
  chainSkipRel: 6,
};

/** 죽음 한 명당 신임 깎임의 난이도별 값(결정 376). DW.trust가 보통 값이다 */
export const TRUST_BY_LEVEL = { easy: 1, normal: 2, hard: 3 } as const;

export const DEATH_CARD_KINDS = ['loss_rep', 'loss_child', 'loss_hand', 'chain_push', 'chain_fix', 'heat_after'] as const;

export function enableDeathWeight(g: Game): void {
  g.deathWeight = true;
  g.deathChains = [];
  g.deathStats = { opened: 0, fixed: 0, unfixed: 0, broken: 0, maxOpen: 0, cards: 0 };
}

export function deathWeightOn(g: Game): boolean {
  return !!g.deathWeight;
}

// ---- 자리 ----
/** 지금 대표이거나 앓아누운 대표인 칸(아니면 null). */
export function repCommOf(g: Game, name: string): Comm | null {
  return COMMS.find(c => g.comms[c].leader.name === name || g.comms[c].sick?.rep.name === name) ?? null;
}

/** 내정 판에서 그 이름의 사람이 숙련(2) 이상인가. */
export function skilledHand(g: Game, name: string): boolean {
  return !!g.dom?.people.some(p => p.name === name && p.skill >= 2);
}

/** 한 사람의 자리. 위에서부터 먼저 맞는 것 하나(명세 2절 표): 대표 > 부모 > 아이 > 일손 > 그 밖(65세 이상). */
export function deathSlot(g: Game, name: string): DeathSlot | 'elder' {
  if (repCommOf(g, name)) return 'rep';
  const f = familyOf(g, name);
  if (f && f.isParent && f.kids.length > 0) return 'parent';
  const age = PROFILES.find(p => p.name === name)?.age;
  if (age === undefined) return 'elder';
  if (age < 16) return 'child';
  if (age < 65) return 'hand';
  return 'elder';
}

/** 한 정산에 여럿이 죽었을 때 어느 카드를 띄우나(명세 2절 25줄): 부모 > 대표 > 아이 > 일손 > 유품. */
const CARD_RANK: Record<string, number> = { orphan: 5, loss_rep: 4, loss_child: 3, loss_hand: 2, keepsake: 1 };
const LOSS_KINDS = Object.keys(CARD_RANK);

function lossKindOf(slot: DeathSlot | 'elder'): string {
  return slot === 'parent' ? 'orphan' : slot === 'rep' ? 'loss_rep' : slot === 'child' ? 'loss_child' : slot === 'hand' ? 'loss_hand' : 'keepsake';
}

/** 뒷사건 카드 하나를 올린다. 이미 기다리는 뒷사건 카드가 있으면 더 앞선 쪽 하나만 남긴다. 올렸거나 바꿨으면 true. */
function raiseLoss(g: Game, card: Omit<Card, 'uid'>): boolean {
  const waiting = g.cards.find(x => LOSS_KINDS.includes(x.kind));
  if (waiting) {
    if ((CARD_RANK[card.kind] ?? 0) <= (CARD_RANK[waiting.kind] ?? 0)) return false;
    waiting.kind = card.kind;
    waiting.comm = card.comm;
    waiting.who = card.who;
    if (card.text === undefined) delete waiting.text; else waiting.text = card.text;
    return true;
  }
  addPeopleCard(g, card);
  return true;
}

// ---- 사건 줄 ----
function chains(g: Game): DeathChain[] {
  return (g.deathChains ??= []);
}

export function chainOf(g: Game, c: Comm): DeathChain | undefined {
  return (g.deathChains ?? []).find(x => x.comm === c);
}

/** 그 칸에 사건 줄을 연다. 같은 칸에 이미 줄이 있으면 반발 긴장만 한 번 더 올리고, 판 전체 상한이면 열지 않는다. */
export function openChain(g: Game, c: Comm, slot: DeathSlot): DeathChain | null {
  const have = chainOf(g, c);
  if (have) {
    if (!have.bumped) have.bumped = true;
    return null;
  }
  if (chains(g).length >= DW.chainMax) return null;
  const ch: DeathChain = { comm: c, slot, step: 0, seg: g.seg, refused: false, rel0: g.comms[c].rel, heat0: g.comms[c].heat, last: g.seg };
  chains(g).push(ch);
  const st = g.deathStats;
  if (st) { st.opened += 1; st.maxOpen = Math.max(st.maxOpen, chains(g).length); }
  return ch;
}

export function dropChain(g: Game, ch: DeathChain, why: 'fixed' | 'unfixed' | 'broken'): void {
  g.deathChains = chains(g).filter(x => x !== ch);
  const st = g.deathStats;
  if (st) st[why] += 1;
}

/** 요구가 이미 채워졌나(명세 3절 끊김): 아이 줄은 그 칸 난방 레버가 올라갔으면, 난방 줄은 난방 배당이 내려졌으면. */
function satisfied(g: Game, ch: DeathChain): boolean {
  if (ch.slot === 'child') return g.comms[ch.comm].heat > ch.heat0;
  if (ch.slot === 'heat') return !lawActive(g, 'heat_quota');
  return false;
}

/** 정산 때(peopleTick). 줄마다 다음 단계를 한 구간에 한 칸씩, 한 구간에 사건 줄 카드는 많아야 한 장(먼저 연 줄부터). */
export function chainTick(g: Game): void {
  if (!g.deathWeight) return;
  for (const ch of [...chains(g)]) {
    if (g.seg - ch.seg >= DW.chainLife) dropChain(g, ch, 'broken');
    else if (satisfied(g, ch)) dropChain(g, ch, 'broken');
  }
  if (g.cards.some(x => x.kind === 'chain_push' || x.kind === 'chain_fix')) return;
  for (const ch of [...chains(g)].sort((a, b) => a.seg - b.seg)) {
    if (ch.last >= g.seg) continue;
    const skip = ch.step === 0 && !ch.refused && g.comms[ch.comm].rel >= ch.rel0 + DW.chainSkipRel;
    const next = ch.step === 0 && !skip ? 1 : 2;
    ch.step = next;
    ch.last = g.seg;
    if (next === 1) {
      const t = (ch.refused ? DW.chainTension : DW.chainTensionSoft) + (ch.bumped ? DW.chainBump : 0);
      bump(g, 'tension', riteHalf(g, t), 'death');
    }
    addPeopleCard(g, { kind: next === 1 ? 'chain_push' : 'chain_fix', comm: ch.comm, text: ch.slot });
    if (g.deathStats) g.deathStats.cards += 1;
    break;
  }
}

// ---- 「배웅」 법 ----
const rite = (g: Game): boolean => !!g.deathWeight && lawActive(g, 'farewell_rite');
export const hands = (g: Game): boolean => !!g.deathWeight && lawActive(g, 'farewell_hands');

/** 「함께 보낸다」가 서 있으면 죽음이 올리는 긴장을 절반(내림)으로. */
export function riteHalf(g: Game, v: number): number {
  return rite(g) ? Math.floor(v / 2) : v;
}

/** 「함께 보낸다」면 상중이 한 구간 길다(회기 결석이 길어진다). */
export function mournExtra(g: Game): number {
  return rite(g) ? 1 : 0;
}

/** 「배웅」 법이 열리나. 죽음의 무게가 꺼진 판에선 늘 닫혀 있다. 아니면 null(다른 법은 politics.ts가 정한다). */
export function deathLawOpen(g: Game, law: LawId): boolean | null {
  if (!FAREWELL_LAWS.includes(law)) return null;
  if (!g.deathWeight) return false;
  return !!storyOf(g).flags.first_death && CORPSE_LAWS.some(l => lawActive(g, l)) && !FAREWELL_LAWS.some(l => lawActive(g, l));
}

// ---- 죽음마다(death.ts onDeath가 부른다) ----
/** 신임 깎임, 「배웅」의 값, 사건 줄 겹침. 조용한 죽음도 센다. */
export function deathWeightOnDeath(g: Game, c: Comm, names: readonly string[]): void {
  if (!g.deathWeight) return;
  const n = names.length;
  // 신임: 한 명당 DW.trust, 「손을 보내 배웅한다」면 절반(내림), 한 구간 합계 DW.trustCap까지.
  let t = DW.trust * n;
  if (hands(g)) t = Math.floor(t / 2);
  const at = g.deathTrustAt && g.deathTrustAt.seg === g.seg ? g.deathTrustAt : (g.deathTrustAt = { seg: g.seg, sum: 0 });
  const take = Math.max(0, Math.min(t, DW.trustCap - at.sum));
  if (take > 0) { at.sum += take; bump(g, 'trust', -take, 'death'); }
  if (rite(g)) bump(g, 'coal', -n, 'death', { floor0: true });
  if (hands(g)) g.crewShort = (g.crewShort ?? 0) + names.reduce((s, x) => s + (skilledHand(g, x) ? 2 : 1), 0);
  // 같은 칸에 줄이 있으면 새 줄 대신 반발 긴장을 한 번 더.
  const have = chainOf(g, c);
  if (have && have.seg < g.seg) have.bumped = true;
}

/** 시신 법이 없을 때 죽음이 올리는 긴장(death.ts의 3×n). */
export function corpseTension(g: Game, n: number): number {
  return riteHalf(g, 3 * n);
}

/** afterDeath의 켠 판 몫. 조용한 죽음이면 상중만 하고(부른 쪽이 이미 했다) 카드를 내지 않는다. */
export function deathWeightAfter(g: Game, c: Comm, names: readonly string[], quiet: boolean): void {
  if (quiet) return;
  // 앓던 대표가 죽었으면 승계 줄(people.ts sickTick)이 빈 의석 카드를 낸다. 지금 대표는 death.ts가 훅 뒤에 본다.
  const known = names.filter(n => PROFILES.some(p => p.name === n));
  if (known.length === 0) return;
  const ranked = known.map(name => ({ name, slot: deathSlot(g, name) }))
    .filter(x => x.slot !== 'rep')
    .sort((a, b) => (CARD_RANK[lossKindOf(b.slot)] ?? 0) - (CARD_RANK[lossKindOf(a.slot)] ?? 0));
  const top = ranked[0];
  if (!top) return;
  const kind = lossKindOf(top.slot);
  const raised = raiseLoss(g, { kind, comm: c, who: top.name, ...(kind === 'keepsake' && g.phase === 'stop' ? { text: 'field' } : {}) });
  if (raised && top.slot !== 'elder') openChain(g, c, top.slot as DeathSlot);
}

/** 대표 자리가 바뀌었다(S1b 승계 훅 뒤, 앓던 대표 승계 줄). 빈 의석 카드와 대표 줄. */
export function repSucceeded(g: Game, c: Comm, old: string): void {
  if (!g.deathWeight) return;
  if (raiseLoss(g, { kind: 'loss_rep', comm: c, who: old })) openChain(g, c, 'rep');
}

// ---- 난방 배당(결정 354) ----
/** 난방 배당의 밤사이 죽음을 센다(heat_alloc.ts). 같은 정산의 peopleTick이 다음 구간 카드 하나를 낸다. */
export function noteHeatDeath(g: Game, c: Comm): void {
  if (!g.deathWeight) return;
  const h = g.heatAfter && g.heatAfter.seg === g.seg ? g.heatAfter : (g.heatAfter = { seg: g.seg, lost: {} });
  h.lost[c] = (h.lost[c] ?? 0) + 1;
}

const HEAT_ORDER: Comm[] = ['tail', 'medtech', 'guard'];

export function heatAfterTick(g: Game): void {
  const h = g.heatAfter;
  if (!g.deathWeight || !h || h.seg !== g.seg) return;
  delete g.heatAfter;
  if (!lawActive(g, 'heat_quota')) return;
  const total = Object.values(h.lost).reduce((s, v) => s + (v ?? 0), 0);
  if (total <= 0) return;
  const c = [...HEAT_ORDER].sort((a, b) => (h.lost[b] ?? 0) - (h.lost[a] ?? 0))[0];
  addPeopleCard(g, { kind: 'heat_after', comm: c, n: total });
  if (!openChain(g, c, 'heat')) { /* 같은 칸 줄이 이미 있으면 반발 긴장만 올라갔다 */ }
}

// ---- 비상 소집(turn.ts emergencyCost) ----
export function deathEmergCost(g: Game): number {
  if (!g.deathWeight || DW.emerg <= 0) return 0;
  const recent = (g.deathLog ?? []).filter(d => g.seg - d.seg < 6).length;
  return DW.emerg * recent;
}

// ---- 작업조(turn.ts resolveStop) ----
/** 다음 정차 작업조에서 빠지는 사람 수(「빈 손」을 나눠 진 칸, 「손을 보내 배웅한다」). 음수면 한 사람 더. */
export function crewShortNow(g: Game): number {
  return g.deathWeight ? g.crewShort ?? 0 : 0;
}

/** 정차가 끝나면 작업조 증감을 비운다. */
export function crewShortSpent(g: Game): void {
  if (g.crewShort) delete g.crewShort;
}


DEATH_WEIGHT_HOOK.after = deathWeightAfter;
DEATH_WEIGHT_HOOK.mournExtra = mournExtra;
DEATH_WEIGHT_HOOK.succeeded = repSucceeded;
DEATH_WEIGHT_HOOK.tick = g => { heatAfterTick(g); chainTick(g); };
