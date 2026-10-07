import { COMM_NAME, COMMS } from '../data';
import type { Comm } from '../data';
import { familyOf } from '../people';
import { clamp, journal, lawActive } from '../state';
import type { Game } from '../state';
import { B } from './data';
import { CHECK_LINES } from './lines';
import { byName, darkCard, dpick, dr, segFull } from './state';

// 9장 칸 안에서 죽은 사람. 확인(9.1)과 밤샘(9.2)만 카드가 되고, 나머지는 일지 한 줄이다.
// 글과 그림은 '확인했다'까지만 쓴다. 무엇으로 어떻게 했는지 쓰지 않고 소리 하나로 끝낸다(1.4).
// 확인한 시신은 어디에 두든 일어나지 않는다. 확인하지 않은 시신만 일어난다: 살던 칸이면 다음 정산에 25%(경비가 지킨 밤샘은 10%),
// 냉동칸·찬 객차면 S1a 시신 법의 3%/구간(turn.ts가 darkStoredWeight로 무게를 받는다).

export type Practice = 'guard' | 'medtech' | 'car';

/** 칸 안 죽음 하나를 적는다(death.ts 훅). 정차에서 죽어 실려 온 시신은 확인을 거치지 않는다(9.3). */
export function noteDeath(g: Game, c: Comm, names: readonly string[]): void {
  const d = g.dark;
  if (!d || g.phase === 'stop') return;
  for (const name of names) {
    // 숨긴 물림은 이미 일어났거나 경비대가 처리했다(biteTick).
    if ((g.hiddenBites ?? []).some(b => b.who === name)) continue;
    d.fresh.push({ comm: c, name });
    d.stats.corpses += 1;
  }
}

/** 이 시신은 어디에 놓이나: 냉동칸·찬 객차 법이면 'cold', 아니면 밖(던지는 법이거나 법이 없으면 S1a가 일단 밖으로 던진다).
 * 밤샘(9.2)을 허락한 시신만 하룻밤 살던 칸에 남는다. */
function placeOf(g: Game): 'cold' | 'out' {
  if (lawActive(g, 'corpse_store') || lawActive(g, 'corpse_burn')) return 'cold';
  return 'out';
}

/** 관행의 값(9.1 표). 한 죽음마다. */
function practiceCost(g: Game, p: Practice, c: Comm): void {
  if (p === 'guard') {
    g.comms.guard.base[3] += 1;
    g.comms.guard.rel = clamp(g.comms.guard.rel - 2, -100, 100);
  } else if (p === 'medtech') {
    g.comms.medtech.rel = clamp(g.comms.medtech.rel - 3, -100, 100);
    g.comms.medtech.coh = clamp(g.comms.medtech.coh - 0.02, 0, 1);
  } else {
    g.comms[c].rel = clamp(g.comms[c].rel - 1, -100, 100);
    g.fear = clamp(g.fear + 2, 0, 100);
  }
}

/** 냉동칸·찬 객차에 놓인 시신 하나를 S1a 굴림에서 뺀다(확인했거나, S1b가 밤샘 굴림으로 맡았다). n이 −1이면 되돌린다. */
function holdCold(g: Game, n: 1 | -1 = 1): void {
  const d = g.dark!;
  if (placeOf(g) !== 'cold') return;
  if (lawActive(g, 'corpse_burn')) d.checkedPyre = Math.max(0, d.checkedPyre + n);
  else d.checkedStored = Math.max(0, d.checkedStored + n);
}

/** 확인을 마친다. 그 칸이 하는 관행은 가족이 있으면 10%로 빠뜨린다. held면 밤샘 카드를 띄울 때 이미 S1a 굴림에서 뺐다. */
export function checkBody(g: Game, x: { comm: Comm; name: string }, held = false): void {
  const d = g.dark!;
  const p = d.practice ?? 'guard';
  practiceCost(g, p, x.comm);
  const missed = p === 'car' && !!familyOf(g, x.name) && dr(g) < B.carMiss;
  if (missed) {
    if (held) holdCold(g, -1); // 빠뜨린 시신은 S1a 냉동칸 위험으로 돌아간다
    leaveUnchecked(g, x, B.corpseRise, false);
    return;
  }
  if (!held) holdCold(g);
  journal(g, dpick(g, CHECK_LINES).replaceAll('{who}', x.name), 'dark');
}

/** 확인하지 않은 시신. 밤샘이면 살던 칸에서 다음 정산에 p로 한 번 굴린다(9.1 '한 시신의 위험은 한 번만 굴린다').
 * 그 시신이 S1a 냉동칸 수에도 들어 있으면 S1a 굴림에서 빼 둔다(checked 수에 넣는다). 일어나면 냉동칸 수에서도 빠진다.
 * 밤샘이 아니면 놓인 자리를 따른다: 냉동칸·찬 객차는 S1a 시신 법의 위험(3%/구간, 확인 안 된 시신만 센다), 밖이면 일어날 데가 없다. */
function leaveUnchecked(g: Game, x: { comm: Comm; name: string }, p: number, inCar: boolean): void {
  if (!inCar) return;
  const cold = placeOf(g) === 'cold';
  const burn = cold && lawActive(g, 'corpse_burn');
  g.dark!.unchecked.push({ comm: x.comm, name: x.name, p, ...(cold ? { cold, burn } : {}) });
}

/** 이름 있는 인물(대표·측근)이나 가족이 있는 사람이면 밤샘을 청한다(9.2). */
function wantsVigil(g: Game, name: string): boolean {
  const named = COMMS.some(c => g.comms[c].leader.name === name) || [g.dark!.staff.deputy, g.dark!.staff.ration].some(id => byName(name)?.id === id);
  return named || !!familyOf(g, name);
}

/** 정산: 이번 구간 칸 안 죽음을 처리한다. 첫 죽음엔 관행 카드, 이름 있는 사람·가족이 있으면 밤샘 카드. */
export function corpseTick(g: Game): void {
  const d = g.dark!;
  // 지난 정산에 확인하지 않은 시신이 일어난다(한 시신의 위험은 한 번만 굴린다).
  for (const x of d.unchecked) {
    if (dr(g) >= x.p) continue;
    d.stats.risen += 1;
    // 일어난 시신은 냉동칸 수에서도 빠진다(S1a 굴림에서 빼 둔 몫도 같이).
    if (x.cold && x.burn && (g.pyre ?? 0) > 0) { g.pyre = (g.pyre ?? 0) - 1; d.checkedPyre = Math.max(0, d.checkedPyre - 1); }
    else if (x.cold && !x.burn && g.stored > 0) { g.stored -= 1; d.checkedStored = Math.max(0, d.checkedStored - 1); }
    const hit = victimNear(g, x.comm, x.name);
    g.tension = clamp(g.tension + 3, 0, 100);
    if (hit) {
      (g.hiddenBites ??= []).push({ who: hit, comm: x.comm, at: g.seg, due: g.seg + 2, found: true });
      journal(g, `${COMM_NAME[x.comm]}에 두었던 ${x.name}이(가) 일어났다. ${hit}이(가) 물렸다.`, 'bad');
    } else {
      g.injured += 1;
      journal(g, `${COMM_NAME[x.comm]}에 두었던 ${x.name}이(가) 일어났다. 하나가 다쳤다.`, 'bad');
    }
  }
  d.unchecked = [];
  // 첫 칸 안 죽음: 누가 확인할지 정하는 관행 카드 한 장. 고르면 이번 시신을 모두 확인한다(ruleChosen).
  if (d.practice === null) {
    if (d.fresh.length && !g.cards.some(k => k.kind === 'dark:corpse_rule')) darkCard(g, { kind: 'dark:corpse_rule', comm: d.fresh[0].comm, who: d.fresh[0].name });
    return;
  }
  const fresh = d.fresh;
  d.fresh = [];
  for (const x of fresh) {
    if (wantsVigil(g, x.name) && !segFull(g) && !g.cards.some(k => k.kind === 'dark:vigil')) {
      // 밤샘 답이 올 때까지 이 시신은 S1b가 맡는다(S1a 냉동칸 굴림에서 뺀다). 한 시신은 한 번만 굴린다.
      holdCold(g);
      darkCard(g, { kind: 'dark:vigil', comm: x.comm, who: x.name });
      continue;
    }
    checkBody(g, x);
  }
}

function victimNear(g: Game, c: Comm, name: string): string | null {
  const fam = familyOf(g, name);
  const pool = (fam?.others ?? []).filter(o => o.age >= 16);
  if (pool.length) return dpick(g, pool).name;
  return null;
}

/** 관행을 정했다(9.1). 기다리던 시신을 모두 확인한다. */
export function ruleChosen(g: Game, p: Practice): void {
  const d = g.dark!;
  d.practice = p;
  const fresh = d.fresh;
  d.fresh = [];
  for (const x of fresh) checkBody(g, x);
}

/** 밤샘의 답(9.2) */
export function vigil(g: Game, x: { comm: Comm; name: string }, how: 'allow' | 'guard' | 'refuse'): void {
  if (how === 'allow') {
    g.comms[x.comm].rel = clamp(g.comms[x.comm].rel + 4, -100, 100);
    leaveUnchecked(g, x, B.corpseRise, true);
  } else if (how === 'guard') {
    g.comms[x.comm].rel = clamp(g.comms[x.comm].rel + 2, -100, 100);
    g.comms.guard.base[3] += 1;
    leaveUnchecked(g, x, B.vigilGuarded, true);
  } else {
    g.comms[x.comm].rel = clamp(g.comms[x.comm].rel - 3, -100, 100);
    checkBody(g, x, true);
  }
}

/** S1a 시신 법의 냉동칸 위험이 실린 무게(turn.ts 훅): S1b면 확인을 마친 시신은 빼고 센다. */
export function darkStoredWeight(g: Game, stored: number): number {
  const d = g.dark;
  if (!d) return stored;
  d.checkedStored = Math.min(d.checkedStored, stored);
  // 이번 구간에 죽어 아직 정산 확인(corpseTick)을 기다리는 시신은 S1b가 굴린다. S1a 냉동칸 굴림이 먼저 돌아도 한 번 더 굴리지 않는다.
  const pending = lawActive(g, 'corpse_store') ? d.fresh.length : 0;
  return Math.max(0, stored - d.checkedStored - pending);
}
export function darkPyreWeight(g: Game, pyre: number): number {
  const d = g.dark;
  if (!d) return pyre;
  d.checkedPyre = Math.min(d.checkedPyre, pyre);
  const pending = lawActive(g, 'corpse_burn') ? d.fresh.length : 0;
  return Math.max(0, pyre - d.checkedPyre - pending);
}
