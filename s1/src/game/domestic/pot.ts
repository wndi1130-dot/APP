import { bump } from '../ledger';
import { COMMS } from '../data';
import { addCard, journal, lawActive, rnd } from '../state';
import type { Game } from '../state';
import { bumpRel } from '../ledger';
import { D } from './data';
import { refreshSit } from './sit';
import type { DomPerson } from './state';

// 식당칸 솥의 불리기(food_cooking 4.5). 칸이 아니라 식당칸의 솥 자리이고, 조리는 절약 기술이 아니다.
// 기본은 '그대로'이고 건드리지 않은 판은 숫자도 난수도 그대로다(골든 불변).
// 여기 든 것은 셋이다: 그대로(plain), 묽게(thin), 섞어서(mixed). '밝히고 섞어서'는 법이 하나 느는 일이라 정치 쪽 몫으로 남겼다.
// 대가의 갈래를 가른다: 묽게는 불만(처지 벌, 잇달아 쓰면 '묽은 죽' 긴장), 섞어서는 몸(탈이 나 일손이 빠지고 침상을 쓴다)과 들킴.
// 숫자는 모두 제안이다(domestic/data.ts의 pot* 값).
// 탈이 났을 때의 까닭은 빵이다. 사람이나 칸 탓으로 쓰지 않고, 섞는 몫을 칸마다 가르지 않으며, 탈은 옮지 않는다(브리프 8장).

export const POT_MODES = ['plain', 'thin', 'mixed'] as const;
export type PotMode = typeof POT_MODES[number];

export interface PotState {
  mode: PotMode;
  /** 쌓인 들킬 확률(기본 확률에 더한다). potRiskUp이 0이면 늘 0이다 */
  heat: number;
  /** 묽게를 잇달아 쓴 구간 수('묽은 죽'이 나면 0으로) */
  thinRun: number;
  /** 섞어서를 잇달아 쓴 구간 수(탈 확률이 오른다) */
  mixedRun?: number;
  /** 판에서 묽게·섞어서를 쓴 구간 수와 들킨 횟수(재기) */
  thinSegs: number;
  mixedSegs: number;
  caught: number;
  /** 마지막으로 들킨 구간 */
  caughtAt?: number;
  /** 들킨 뒤 이 구간까지 섞어서를 못 고른다 */
  lockUntil?: number;
  /** 조리 담당(내정 사람 id) */
  cook?: string;
  /** 탈이 나 누운 사람 수와 그들이 일어나는 구간 */
  sick?: number;
  sickUntil?: number;
  /** 판에서 '묽은 죽' 불만이 난 횟수, 탈이 난 횟수(재기) */
  gruel?: number;
  sickHits?: number;
}

const NONE: Readonly<PotState> = { mode: 'plain', heat: 0, thinRun: 0, thinSegs: 0, mixedSegs: 0, caught: 0 };

/** 솥의 지금 상태. 고른 적 없는 판(옛 저장 포함)은 '그대로'로 읽는다. 판에 칸을 만들지 않는다. */
export function potOf(g: Game): Readonly<PotState> {
  return g.dom?.pot ?? NONE;
}

/** 조리 담당(살아서 열차에 있는 사람만). */
export function potCook(g: Game): DomPerson | undefined {
  const id = g.dom?.pot?.cook;
  return id ? g.dom?.people.find(p => p.id === id && p.alive && !p.gone) : undefined;
}

/** 조리 담당을 세우거나(id) 내린다(null). 담당이 있는 동안 공방 손 하나가 솥으로 빠진다. */
export function setPotCook(g: Game, id: string | null): void {
  const d = g.dom;
  if (!d) return;
  if (id && !d.people.some(p => p.id === id && p.alive && !p.gone)) return;
  if (!id && !d.pot) return;
  d.pot = { ...potOf(g), cook: id ?? undefined };
}

/** 탈이 나 누운 사람 수(침상 셈과 공방 작업량이 읽는다). */
export function potSick(g: Game): number {
  const pot = g.dom?.pot;
  return pot?.sick && (pot.sickUntil ?? 0) >= g.seg ? pot.sick : 0;
}

/** 이번 구간에 섞으면 탈이 날 확률(0~1). 잇달아 섞을수록 오른다. */
export function potSickRisk(g: Game): number {
  return Math.min(D.potSickMax, D.potSick0 + D.potSickUp * (potOf(g).mixedRun ?? 0));
}

/** 그 방식을 지금 고를 수 있나. 담당이 있어야 하고, 식량이 0이면 불릴 것이 없고, 섞으려면 목재가 있어야 한다. */
export function potUsable(g: Game, mode: PotMode): { ok: boolean; why?: string } {
  const d = g.dom;
  if (mode === 'plain') return { ok: true };
  if (!d) return { ok: false, why: '내정을 켠 판에서만 고른다' };
  if (D.potCook && !potCook(g)) return { ok: false, why: '담당 없음' };
  if (g.food <= 0) return { ok: false, why: '불릴 식량이 없다' };
  if (mode === 'mixed' && (d.pot?.lockUntil ?? 0) >= g.seg) return { ok: false, why: `드러남 · ${(d.pot?.lockUntil ?? 0) - g.seg + 1}구간 잠금` };
  if (mode === 'mixed' && d.wood < D.potMixWood) return { ok: false, why: '섞을 목재가 없다' };
  return { ok: true };
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

/** 이번 구간에 섞으면 들킬 확률(0~1). 담당이 사는 칸이 열차장에게 등을 돌렸으면 더 잘 샌다. */
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
  if (pot.sick && (pot.sickUntil ?? 0) < g.seg) { pot.sick = 0; notes.push('탈이 났던 사람들이 일어났다.'); }
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
    const sickRisk = potSickRisk(g);
    pot.mixedRun = (pot.mixedRun ?? 0) + 1;
    if (D.potSickN > 0 && rnd(g) < sickRisk) sicken(g, pot, notes);
    const risk = potRisk(g);
    pot.heat += D.potRiskUp;
    if (rnd(g) < risk) caught(g, pot, notes);
  } else {
    pot.heat = Math.max(0, pot.heat - D.potRiskDown);
    pot.mixedRun = 0;
  }
  if (mode === 'thin') {
    pot.thinRun += 1;
    pot.thinSegs += 1;
    if (D.potGruelRun > 0 && pot.thinRun >= D.potGruelRun) gruel(g, pot, notes);
  } else pot.thinRun = 0;
  if (pot.mode !== 'plain' && g.food <= 0) {
    pot.mode = 'plain';
    notes.push('불릴 식량이 없어 솥이 그대로로 돌아갔다.');
  }
}

/** 묽은 죽이 이어졌다: 긴장이 오르고 세는 수는 처음으로 돌아간다. 글은 임시 한 줄이다(본문은 사건 줄기 몫). */
function gruel(g: Game, pot: PotState, notes: string[]): void {
  bump(g, 'tension', D.potGruelTension, 'pot');
  pot.thinRun = 0;
  pot.gruel = (pot.gruel ?? 0) + 1;
  journal(g, '묽은 죽이 이어지자 식당칸에서 볼멘소리가 커진다.', 'bad');
  notes.push('묽은 죽이 이어져 불만이 커졌다.');
}

/** 섞은 빵에 탈이 났다: 몇 사람이 누워 침상을 쓰고 일손이 빠진다. 약이 들고 긴장이 조금 오른다. 누구인지, 어느 칸인지는 적지 않는다. */
function sicken(g: Game, pot: PotState, notes: string[]): void {
  pot.sick = potSick(g) + D.potSickN;
  pot.sickUntil = g.seg + D.potSickSegs;
  pot.sickHits = (pot.sickHits ?? 0) + 1;
  bump(g, 'med', -Math.min(g.med, D.potSickMed), 'pot');
  bump(g, 'tension', D.potSickTension, 'pot');
  journal(g, `섞은 빵에 탈이 나 ${D.potSickN}명이 누웠다.`, 'bad');
  notes.push(`섞은 빵에 탈이 나 ${D.potSickN}명이 누웠다.`);
}

/** 섞은 것이 드러났다: 신임, 긴장, 그리고 한동안 다시 섞지 못한다. 공동 식당 법이 서 있었으면 법을 속인 것이라 신임 벌이 곱절이다. */
function caught(g: Game, pot: PotState, notes: string[]): void {
  const law = lawActive(g, 'common_kitchen');
  bump(g, 'trust', -D.potCaughtTrust * (law ? D.potCaughtLaw : 1), 'pot');
  if (D.potCaughtRel > 0) for (const c of COMMS) bumpRel(g, c, -D.potCaughtRel, 'pot');
  bump(g, 'tension', D.potCaughtTension, 'pot');
  pot.mode = 'plain';
  pot.caught += 1;
  pot.caughtAt = g.seg;
  if (D.potCaughtLock > 0) pot.lockUntil = g.seg + D.potCaughtLock;
  const text = law
    ? '빵에서 나무 맛이 난다는 말이 칸마다 돌았다. 솥에 톱밥을 섞은 것이 드러났다. 공동 식당 법을 세워 놓고 속인 일이라 더 크게 번진다.'
    : '빵에서 나무 맛이 난다는 말이 칸마다 돌았다. 솥에 톱밥을 섞은 것이 드러났다.';
  addCard(g, { kind: 'info', who: '섞은 빵이 드러났다', text });
  journal(g, '솥에 톱밥을 섞은 것이 드러났다. 솥은 그대로로 돌아갔다.', 'bad');
  notes.push('섞은 빵이 드러났다.');
}
