import { COMM_NAME, COMMS } from '../data';
import type { Comm } from '../data';
import { onDeath } from '../death';
import { pickFresh, markSeen } from '../omens';
import { revertLater } from '../people';
import { clamp, journal, lawActive, situation as situationOf } from '../state';
import type { Game } from '../state';
import { CAR_COMM } from '../domestic/data';
import { B } from './data';
import { ACT_LINES, SIGN_LINES, SIGN_READ } from './lines';
import type { SignKind } from './lines';
import { EMBER_LINK, openCase, caught } from './cases';
import {
  adults, alive, commOf, darkCard, dpick, dr, eun, killEmber, nameOf, newId, segFull,
} from './state';
import type { Ember, EmberCause, SabKind, Stage, Target } from './state';

// 4.1 불씨와 사다리, 4.2 징후, 4.3 사보타주. 새 숨은 수치 없이 열기·적의·처지·원수 관계에서 불씨가 생긴다.
// 징후 없이 폭력은 없다: 불씨가 생기면 기척, 단계가 오르면 임박이 뜨고, 임박은 이번 구간 이동 단계에 반드시 일어난다.
// (문서는 '다음 구간'이라 썼지만 시뮬레이터 s1b_dark.py는 같은 구간 이동에서 일어난다. 출발 전에 경비를 붙이고 출발하면 결과가 보이는 쪽이
//  카드 흐름에 맞아 시뮬레이터를 따랐다. S1b 스레드에 확인을 물을 것.)

/** 불씨의 '누구에게'가 사람이면 그 사람(프로필 id). 열차장은 'chief'. */
function markOf(g: Game, who: Comm, target: Target): string {
  const d = g.dark!;
  if (target === 'chief') return 'chief';
  if (target === 'store') return alive(g, d.staff.ration) ? d.staff.ration : 'chief';
  if (target === 'aide') {
    // 자기 칸 사람은 노리지 않는다(앞칸의 원한이면 경비대장이나 열차장).
    const pool = [g.comms.guard.leader.personId, d.staff.deputy, d.staff.ration].filter(id => alive(g, id) && commOf(g, id) !== who);
    return pool.length ? dpick(g, pool) : 'chief';
  }
  return g.comms[target].leader.personId;
}

/** 일을 할 사람. 원인이 대표의 일(목줄, 뇌물, 원수 표결)이면 대표, 아니면 그 칸의 어른 하나. */
function actorOf(g: Game, who: Comm, cause: EmberCause): string {
  if (cause === 'leash' || cause === 'bribe' || cause === 'rival') return g.comms[who].leader.personId;
  const pool = adults(g, who, { noRep: true, except: g.dark!.confined.map(x => x.id) });
  return pool.length ? dpick(g, pool).id : g.comms[who].leader.personId;
}

/** 사보타주 종류(4.3: 누가 하기 쉬운가). 기척 글이 그 일을 비추게 불씨가 생길 때 정한다. */
function sabOf(g: Game, who: Comm, target: Target, cause: EmberCause): SabKind {
  if (cause === 'lack' || target === 'store' || target === 'front' || target === 'aide') return 'poison';
  if (who === 'tail') return dr(g) < 0.5 ? 'coupling' : 'heating';
  if (who === 'engine') return 'boiler';
  return dr(g) < 0.5 ? 'heating' : 'poison';
}

/** 피해 칸: 칸이면 그 칸, 창고면 앞칸, 열차장·측근이면 그 사람의 칸(열차장은 경비대가 지킨다). */
export function victimComm(g: Game, e: Ember): Comm {
  if (COMMS.includes(e.target as Comm)) return e.target as Comm;
  if (e.mark === 'chief') return 'guard';
  return commOf(g, e.mark);
}

/** 사건이 날 자리(글에 쓴다). */
function placeOf(e: Ember, stage: Stage): string {
  if (stage === 2) return { boiler: '탄수차', coupling: '꼬리칸 끝 승강대', poison: '창고칸', heating: `${COMM_NAME[e.target as Comm] ?? '앞칸'}` }[e.sab];
  if (stage === 3) return e.who === 'tail' ? '화장실 칸' : '통로';
  return '통로';
}

/** 피해 사건이 판당 상한에 닿았나(1.2) */
export function harmCapped(g: Game): boolean {
  return g.dark!.harm >= B.harmCap;
}

/** 다른 일(수사·군중 시계, 다른 불씨의 폭행·암살 임박)이 진행 중이면 그 일에 걸리지 않은 불씨는 사보타주 위로 못 오른다(1.2).
 * 같은 출발 전에 불씨 둘이 함께 폭행·암살 임박이 되지 않게 한다. */
function harmBusy(g: Game, e: Ember): boolean {
  const d = g.dark!;
  return d.cases.some(c => (c.status === 'open' || c.status === 'trial') && c.ember !== e.id)
    || d.embers.some(x => x.id !== e.id && x.imm >= 3);
}

export function guarded(g: Game, e: Ember): boolean {
  return e.guardUntil >= g.seg;
}
export function guardsOut(g: Game): number {
  return g.dark!.embers.filter(e => guarded(g, e)).length;
}
/** 묶인 사람(K02 5): 근신 중인 사람과 경비를 서는 사람. 정차 작업조와 명령 실행자에서 빠진다. */
export function busyIds(g: Game): string[] {
  const d = g.dark;
  if (!d) return [];
  return [...d.confined.map(x => x.id), ...d.embers.filter(e => guarded(g, e)).flatMap(e => e.guardIds ?? [])];
}
/** 경비로 세울 수 있는 경비대 사람(대표와 묶인 사람 빼고). */
export function freeGuards(g: Game): string[] {
  const exe = g.dark?.order?.exeId;
  return adults(g, 'guard', { noRep: true, except: [...busyIds(g), ...(exe ? [exe] : [])] }).map(p => p.id);
}

/** 불씨 하나. 같은 칸·같은 대상이 이미 있으면 새로 안 생긴다. 생기면 기척 징후 쪽지. */
export function newEmber(g: Game, who: Comm, target: Target, cause: EmberCause, p = B.emberP): Ember | null {
  const d = g.dark!;
  if (harmCapped(g)) return null;
  let chance = p;
  if (g.fear >= 80) chance *= 0.7;
  if (dr(g) >= Math.min(1, chance)) return null;
  if (d.embers.some(e => e.who === who && e.target === target)) return null;
  if (d.embers.length >= B.emberMax) return null;
  const mark = markOf(g, who, target);
  const e: Ember = {
    id: newId(g), who, actor: actorOf(g, who, cause), target, mark, cause, stage: g.fear >= 80 ? 1 : 0, imm: 0, quiet: 0, guardUntil: -1,
    sab: sabOf(g, who, target, cause), blocked: false, born: g.seg,
  };
  d.embers.push(e);
  sign(g, e, 'kiche');
  return e;
}

// cases.ts가 불씨를 만들 때 쓰는 자리를 채운다(cases ↔ embers import 순환을 끊는다).
EMBER_LINK.born = newEmber;

/** 다음에 오를 일의 종류(징후 글) */
function signKind(e: Ember, stage: Stage): SignKind {
  if (stage <= 1) return stage === 0 ? kicheKind(e) : 'threat';
  if (stage === 2) return e.sab;
  if (stage === 3) return 'assault';
  return 'assn';
}
/** 기척은 이 불씨가 갈 길을 비춘다. 대표를 노리는 원인은 사람을 노림, 굶주림은 창고, 그 밖엔 위협. */
function kicheKind(e: Ember): SignKind {
  if (e.cause === 'leash' || e.cause === 'bribe' || e.cause === 'executor' || e.target === 'chief') return 'assn';
  if (e.cause === 'lack') return 'poison';
  return e.sab === 'boiler' ? 'boiler' : 'threat';
}

export function fill(g: Game, text: string, e: Ember, stage: Stage): string {
  return text.replaceAll('{mark}', nameOf(g, e.mark)).replaceAll('{comm}', COMM_NAME[e.who]).replaceAll('{place}', placeOf(e, stage));
}

/** 징후 쪽지. 기척은 이번 구간 필수 결정이 셋이면 일지 한 줄로 줄인다(약속이 아니라서). 임박은 줄이지 않는다. */
function sign(g: Game, e: Ember, tier: 'kiche' | 'imm'): void {
  const d = g.dark!;
  const stage = tier === 'kiche' ? 0 : e.imm;
  const kind = signKind(e, stage);
  const pool = SIGN_LINES[kind][tier];
  const fresh = pool.filter(t => !g.linesSeen.includes(t));
  d.stats.signs += 1;
  if (tier === 'imm') d.stats.imminent += 1;
  // 같은 구간의 징후 둘은 쪽지 한 장에 두 줄로 묶는다(4.2). 묶인 둘째 줄은 필수 결정 수에 따로 세지 않는다.
  const open = g.cards.find(k => k.kind === 'dark:sign' && k.n !== undefined && k.n !== e.id && !k.vals?.n2);
  if (tier === 'kiche' && (fresh.length === 0 || (segFull(g) && !open))) {
    if (segFull(g)) d.stats.cardsDeferred += 1;
    journal(g, `${COMM_NAME[e.who]}에 무언가 끓고 있다는 말이 돈다.`, 'dark');
    return;
  }
  const text = pickFresh(pool, g.linesSeen, `${g.seed}|${e.id}|${tier}|${stage}`);
  markSeen(g, text);
  const line = fill(g, text, e, stage);
  if (open) {
    open.vals = { ...(open.vals ?? {}), n2: String(e.id), tier2: tier, who2: line };
    return;
  }
  darkCard(g, { kind: 'dark:sign', comm: e.who, n: e.id, text: tier, who: line });
}

export function signRead(e: Ember, tier: string): string {
  if (tier === 'kiche') return SIGN_READ.kiche;
  if (e.imm === 4) return SIGN_READ.immAssn;
  if (e.imm === 3) return SIGN_READ.immAssault;
  return SIGN_READ.imm;
}

/** 오르는 확률(4.1) */
export function escProb(g: Game, e: Ember): number {
  const [w, r] = situationOf(g, e.who);
  let p = B.escBase + B.escLack * ((w <= B.lackLine ? 1 : 0) + (r <= B.lackLine ? 1 : 0));
  const guardProtest = g.comms.guard.fervor >= 1 && g.comms.guard.rel <= -40;
  p += B.escOpp * (guardProtest ? 1 : 0);
  p -= B.escGuard * (guarded(g, e) ? 1 : 0) + B.escPatrol * (lawActive(g, 'patrol') ? 1 : 0);
  return clamp(p, B.escMin, B.escMax);
}

/** 출발 전: 불씨마다 한 칸 오를지 본다. 오르면 임박 징후. */
export function escalate(g: Game): void {
  const d = g.dark!;
  for (const e of [...d.embers]) {
    if (e.imm) continue;
    const nxt = (e.stage + 1) as Stage;
    if (nxt > 4) continue;
    // 실행할 사람과 노리는 사람이 다음 이동에도 열차에 있어야 띄운다(4.2 띄우기 전에 성립을 본다).
    if (!alive(g, e.actor) || (e.mark !== 'chief' && !alive(g, e.mark))) { killEmber(g, e); continue; }
    if (d.confined.some(x => x.id === e.actor)) { e.quiet += 1; continue; }
    const capped = (nxt >= 3 && d.violentUsed >= B.violentCap) || (nxt === 4 && e.mark === 'chief' && d.chiefAttacked);
    if (capped || (nxt >= 3 && harmBusy(g, e))) { e.quiet += 1; continue; }
    if (dr(g) < escProb(g, e)) {
      e.imm = nxt;
      if (nxt >= 3) d.violentUsed += 1;
      if (nxt === 4 && e.mark === 'chief') d.chiefAttacked = true;
      e.blocked = false;
      sign(g, e, 'imm');
      // 무기고 관행은 미룰 수 있는 카드다: 필수 결정이 셋이면 다음 폭행 임박 때 묻는다. 한 번에 한 장.
      if (nxt === 3 && d.armory === null && !g.cards.some(k => k.kind === 'dark:armory')) {
        if (segFull(g)) d.armoryDue = true;
        else darkCard(g, { kind: 'dark:armory' });
      }
    } else {
      e.quiet += 1;
    }
  }
}

export { killEmber };

/** 경비 2명이 2구간 그 자리에 선다(4.2). 동시에 두 곳까지. */
export function postGuard(g: Game, e: Ember): boolean {
  if (guarded(g, e)) return true;
  if (guardsOut(g) >= B.guardMax) return false;
  const free = freeGuards(g);
  if (free.length < B.guardPair) return false;
  const ids: string[] = [];
  while (ids.length < B.guardPair) { const id = dpick(g, free.filter(x => !ids.includes(x))); ids.push(id); }
  e.guardIds = ids;
  e.guardUntil = g.seg + B.guardLen - 1;
  g.fear = clamp(g.fear + B.guardFear, 0, 100);
  g.comms.guard.base[3] += B.guardExpo;
  // 연결기를 보는 경비는 창고칸 승강대에 선다. 꼬리칸이 싫어한다(4.3).
  if (e.imm === 2 && e.sab === 'coupling') g.comms.tail.rel = clamp(g.comms.tail.rel - 3, -100, 100);
  return true;
}

/** 이동 단계: 임박했던 일이 일어난다. 막혔으면 시도로 보인다. */
export function actAll(g: Game): void {
  for (const e of [...g.dark!.embers]) if (e.imm) act(g, e);
}

function actLine(g: Game, e: Ember, st: Stage, blocked: boolean): string {
  const kind = signKind(e, st);
  const pool = ACT_LINES[kind][blocked ? 'blocked' : 'done'];
  return fill(g, dpick(g, pool), e, st);
}

function act(g: Game, e: Ember): void {
  const d = g.dark!;
  const st = e.imm;
  e.imm = 0;
  e.quiet = 0;
  // 임박이 뜬 뒤 진범이 벌받았다(J09 1번, 4.2): 일은 오지 않는다. 폭행·암살 자리는 돌려주고, 열차장을 노린 첫 시도 기록은 남긴다.
  if (e.defused) {
    if (st >= 3) d.violentUsed = Math.max(0, d.violentUsed - 1);
    darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: `${placeOf(e, st)}${eun(placeOf(e, st))} 조용했다. 기다리던 사람은 이미 벌받은 뒤였다.` });
    killEmber(g, e);
    return;
  }
  const isGuarded = guarded(g, e);
  const v = victimComm(g, e);
  d.stats.acts += 1;
  // 대상 없는 시도: 띄운 뒤에 대상이 죽거나 내렸다(4.2).
  if (e.mark !== 'chief' && !alive(g, e.mark) && st >= 3) {
    if (st >= 3) d.violentUsed = Math.max(0, d.violentUsed - 1);
    darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: `${nameOf(g, e.mark)}의 빈 침상 앞에서 ${COMM_NAME[e.who]} 사람 하나가 붙잡혔다. 노리던 사람은 이미 없었다.` });
    killEmber(g, e);
    return;
  }
  if (e.blocked || (st <= 2 && isGuarded)) {
    e.blocked = false;
    d.stats.blocked += 1;
    // 막혀도 사다리는 오른 것으로 센다(4.2, 2026-10-09 사용자 결정 '오르게 하기'): 경비는 피해만 막고 다음 임박은 한 칸 위다.
    // 카드 끝 한 줄로 알린다(경비가 헛일로 읽히지 않게). blockClimb 0은 옛 규칙(시뮬 비교용).
    const climbs = B.blockClimb > 0 && st <= 2;
    if (climbs) e.stage = st;
    if (st >= 3) d.violentUsed = Math.max(0, d.violentUsed - 1);
    if (st === 4 && e.mark === 'chief') d.chiefAttacked = false;
    darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: `${actLine(g, e, st, true)}${climbs ? ' 이번엔 막았다. 다음엔 더 세게 온다.' : ''}` });
    return;
  }
  e.stage = st;
  if (st === 1) {
    g.tension = clamp(g.tension + B.threatTension, 0, 100);
    g.fear = clamp(g.fear + B.threatFear, 0, 100);
    g.comms[v].rel = clamp(g.comms[v].rel - B.threatRel, -100, 100);
    darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: actLine(g, e, st, false) });
    return;
  }
  if (st === 2) {
    const sick = sabotage(g, e, v);
    if (sick > 0) {
      // 사람이 다친 사보타주는 피해 사건이라 수사가 바로 열리고 군중 시계가 돈다(4.3·4.4, K02 2).
      const kind = (e.sab ?? 'poison') as 'boiler' | 'coupling' | 'poison' | 'heating';
      openCase(g, { kind, culprit: e.actor, victimComm: v, dead: false, clock: B.clockInjury, ember: e.id, where: placeOf(e, 2) });
      darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: `${actLine(g, e, st, false)} ${sick}명이 앓아누웠다. 수사가 열린다.` });
      return;
    }
    // 사람이 안 다친 사보타주는 수사가 선택이다(카드에서 고른다).
    darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: actLine(g, e, st, false), vals: { sab: e.sab, v } });
    return;
  }
  d.harm += 1;
  d.stats.violent += 1;
  if (st === 3) {
    const hurt = adults(g, v, { noRep: true, except: [e.actor] });
    const victim = hurt.length ? dpick(g, hurt) : null;
    const n = isGuarded ? 1 : dr(g) < 0.5 ? 1 : 2;
    g.tension = clamp(g.tension + B.assaultTension, 0, 100);
    const pd = (d.armory ? B.assaultDeathArmory : B.assaultDeath) * (isGuarded ? 0.5 : 1);
    const dead = !!victim && dr(g) < pd;
    g.injured += n - (dead ? 1 : 0);
    const line = actLine(g, e, st, false);
    if (dead && victim) {
      d.stats.violentDeaths += 1;
      onDeath(g, v, [victim.name], 'other');
    }
    const c = openCase(g, { kind: 'assault', culprit: e.actor, victimComm: v, victim: victim?.id, dead, clock: dead ? B.clockDeath : B.clockInjury, ember: e.id, where: placeOf(e, 3) });
    if (isGuarded) caught(g, c);
    const who = victim ? victim.name : `${COMM_NAME[v]} 사람`;
    darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: `${line} ${dead ? `${who}이(가) 죽었다.` : `${who}${n > 1 ? ' 외 한 명' : ''}이(가) 다쳤다.`}${isGuarded ? ' 경비가 그 자리에서 한 사람을 붙잡았다.' : ''} 수사가 열린다.` });
    return;
  }
  // 4 암살 시도
  g.tension = clamp(g.tension + B.assnTension, 0, 100);
  killEmber(g, e);
  const markName = nameOf(g, e.mark);
  if (e.mark === 'chief') {
    // 열차장을 노린 첫 시도는 늘 부상으로 끝난다(4.1 제동: 무경고 즉사 없음).
    const c = openCase(g, { kind: 'assn', culprit: e.actor, victimComm: 'guard', victim: 'chief', dead: false, clock: B.clockInjury, ember: e.id, where: '열차장실 앞' });
    if (isGuarded) caught(g, c);
    darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: `밤에 누군가 열차장을 노렸다. 열차장이 다쳤다.${isGuarded ? ' 경비가 한 사람을 붙잡았다.' : ''} 수사가 열린다.` });
    return;
  }
  // 장인을 노린 첫 시도는 부상(4.1). 장인이 죽으면 그 지식이 사라진다.
  const craft = (g.dom?.people ?? []).some(p => p.alive && p.name === markName && p.skill >= 3);
  let p = B.assnBase - B.assnGuard * (isGuarded ? 1 : 0);
  if (e.mark === g.comms.guard.leader.personId) p -= B.assnGuardCap;
  const firstCraft = craft && !d.craftHit.includes(e.mark);
  if (craft) d.craftHit.push(e.mark);
  const killed = !firstCraft && dr(g) < p;
  if (killed) {
    d.stats.violentDeaths += 1;
    onDeath(g, v, [markName], 'other'); // 대표였으면 죽음 훅(hooks.ts)이 승계한다
  } else {
    g.injured += 1;
  }
  const c = openCase(g, { kind: 'assn', culprit: e.actor, victimComm: v, victim: e.mark, dead: killed, clock: killed ? B.clockDeath : B.clockInjury, ember: e.id, where: '통로' });
  if (isGuarded) caught(g, c);
  darkCard(g, { kind: 'dark:act', comm: e.who, n: e.id, text: `${actLine(g, e, 4, false)} ${killed ? `${markName}이(가) 죽었다.` : `${markName}이(가) 다쳤다.`}${isGuarded ? ' 경비가 한 사람을 붙잡았다.' : ''} 수사가 열린다.` });
}

/** 4.3 사보타주의 손해. 앓아누운 사람 수를 돌려준다(식량 오염만 사람을 다치게 한다). */
function sabotage(g: Game, e: Ember, v: Comm): number {
  const d = g.dark!;
  switch (e.sab) {
    case 'boiler':
      g.coal -= B.boilerCoal;
      if (dr(g) < B.boilerBreak) { d.haul *= 0.5; journal(g, '보일러가 상했다. 이번 정차는 반만 일한다.', 'bad'); }
      break;
    case 'coupling':
      g.coal -= B.couplingCoal;
      d.haul *= B.couplingHaul;
      g.fear = clamp(g.fear + B.couplingFear, 0, 100);
      break;
    case 'poison':
      g.food -= B.poisonFood;
      if (dr(g) < B.poisonSick) { const n = dr(g) < 0.5 ? 1 : 2; g.injured += n; d.harm += 1; return n; }
      break;
    case 'heating': {
      const c = COMMS.includes(e.target as Comm) ? (e.target as Comm) : v;
      // 장갑 객차(W3)는 칸을 겨누는 사보타주 피해가 절반이다. 공동체가 사는 칸 가운데 장갑 댄 비율만큼 준다(J10 13번).
      const warm = Math.round(B.heatingWarm * (1 - B.armorCut * armoredShare(g, c)));
      g.comms[c].base[0] -= warm;
      revertLater(g, c, 0, -warm, B.heatingSegs);
      break;
    }
  }
  return 0;
}

/** 그 공동체가 사는 칸 가운데 장갑을 댄 비율(0~1). S1c 내정이 없는 판이면 0. */
function armoredShare(g: Game, c: Comm): number {
  const d = g.dom;
  if (!d || d.armored.length === 0) return 0;
  const cars = d.cars.filter(id => CAR_COMM[id] === c);
  return cars.length ? cars.filter(id => d.armored.includes(id)).length / cars.length : 0;
}
