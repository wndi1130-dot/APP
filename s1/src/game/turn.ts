import { addCard, END_LINK } from './state';
import { drawTravelEvent } from './cards';
import { addContentCard, contentAwayTick, contentFollowupTick, contentPool } from './content';
import { onDeath, strangerCorpse, takeKinBody } from './death';
import { arriveHub, hubLeakTick, hubOmenTick } from './hub';
import { josa } from './josa';
import { needTick } from './needs';
import { mourners, peopleCardRecent, peopleTick, pickVictims, raisedLines } from './people';
import { hash, markSeen, rollStopView } from './omens';
import type { RiskLevel } from './omens';
import { BRIBE_EXPOSE, CHORE_COMMS, COMMS, COMM_NAME, CREW_HAUL, FETCH_WANT, LAWS, LOOT_KEYS, LOOT_NAME, P, PLACES, PROTEST, REST_FLOOR, STAY } from './data';
import type { Comm, LootKey, StayId } from './data';
import { agendaOptions, agendaTitle, canDecree, dealHolds, isLawAgenda, dropUnratified, endEmergencyPowers, exposeBribe, finishPreVote, offend, openCouncil, preVote, stance, aiAgendaPick } from './politics';
import {
  addSecret, clamp, CREW_BUSY, CREW_EXTRAS, isGone, isSessionSeg, journal, lawActive, PROFILES, rnd, seats, situation, stageOf, storyOf,
} from './state';
import type { Game, StopResult, StopState } from './state';
// S1c 내정 훅(domestic/hooks.ts). g.dom이 없으면 모두 S1a 그대로 돌려준다.
import {
  domesticBroadcast, domesticDepart, domesticForecast, domesticPyreWood, domesticHaulMult, domesticHealRate, domesticPromise, domesticRiskMult, domesticSettle,
  domesticStop, domesticStrikeLine, domesticStrikeRuns, domesticThawMult,
} from './domestic/hooks';
import { lawTechRes } from './domestic/lawtech';
import { techMult } from './domestic/state';
// S1b 어두운 길 훅(dark/hooks.ts). g.dark가 없으면 아무 일도 안 한다.
import './decree'; // 비상대권 중 카드의 '포고로 정한다'(모든 판, 불러오면 등록된다)
import { darkFinish, darkHaulMult, darkPowersEnd, darkPrep, darkSettle, darkStop, darkStopTarget, darkTravel } from './dark/hooks';
import { darkPyreWeights, darkStoredWeight } from './dark/corpses';

// 한 구간의 다섯 단계: 출발 전 운영 → 이동 → 정차 → 의회(회기일 때) → 정산(S1 기획서 3장).

export const PHASES = ['prep', 'travel', 'stop', 'council', 'settle'] as const;
export const PHASE_NAME: Record<string, string> = {
  prep: '출발 전 운영', travel: '이동', stop: '정차', council: '의회', settle: '정산', end: '끝',
};

export function pendingCards(g: Game): number {
  return g.cards.length;
}

export interface Primary { label: string; ok: boolean; why?: string }

export function primaryAction(g: Game): Primary {
  if (g.phase === 'end') return { label: '끝', ok: false };
  if (g.cards.length > 0) return { label: `서류 ${g.cards.length}장`, ok: false, why: '먼저 서류를 처리한다' };
  switch (g.phase) {
    case 'prep': return { label: '출발', ok: true };
    case 'travel': return g.inStrike ? { label: isSessionSeg(g.seg) ? '식당칸으로' : '정산으로', ok: true } : { label: '정차', ok: true };
    case 'stop': return g.stop?.done ? { label: isSessionSeg(g.seg) ? '식당칸으로' : '정산으로', ok: true } : { label: '정차 결정', ok: false, why: '정차 카드를 고른다' };
    case 'council': {
      const council = g.council;
      if (council?.pre && !council.pre.result && council.result) return { label: '다음 안건', ok: true };
      if (council && !council.martial && (council.options.length > 0 || preVote(g)) && !council.result) return { label: '표결', ok: false, why: '표결을 한다' };
      return { label: '정산으로', ok: true };
    }
    case 'settle': return { label: g.seg >= P.segments ? (g.hub?.plan ? '열차를 돌린다' : '라이프치히 도착') : '다음 구간', ok: true };
    default: return { label: '', ok: false };
  }
}

/** 주 단추. 단계를 하나 넘긴다. */
export function advance(g: Game): void {
  if (!primaryAction(g).ok) return;
  switch (g.phase) {
    case 'prep':
      depart(g);
      if ((g.phase as Game['phase']) === 'travel') darkTravel(g);
      return;
    case 'travel': return g.inStrike ? afterStop(g) : arriveStop(g);
    case 'stop': return afterStop(g);
    case 'council': return preVote(g) ? finishPreVote(g) : settle(g);
    case 'settle': return nextSegment(g);
    default: return;
  }
}

// ---- 출발 전 운영 ----
export function setLever(g: Game, c: Comm, which: 'heat' | 'ration', value: number): void {
  // S1b 계엄 중엔 경비대 배급 레버를 계엄이 올린 값 아래로 못 내린다(5.3 유지비). 거절이면 값은 그대로다.
  const lock = g.dark?.martial;
  if (lock && c === 'guard' && which === 'ration' && Math.round(value) < lock.rationLocked) return;
  const floor = which === 'heat' ? lawFloor(g, 'heatFloor') : lawFloor(g, 'rationFloor');
  g.comms[c][which] = clamp(Math.round(value), floor, 4);
}

export function lawFloor(g: Game, key: 'heatFloor' | 'rationFloor'): number {
  let floor = 0;
  for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) floor = Math.max(floor, lawTechRes(g, law)[key] ?? 0);
  return floor;
}

function applyFloors(g: Game): void {
  const hf = lawFloor(g, 'heatFloor');
  const rf = lawFloor(g, 'rationFloor');
  for (const c of COMMS) {
    g.comms[c].heat = Math.max(g.comms[c].heat, hf);
    g.comms[c].ration = Math.max(g.comms[c].ration, rf);
  }
}

/** 배급장에게 맡기기: 시뮬레이터의 돌보는 정책과 같은 규칙으로 레버를 움직인다. */
export function autoLevers(g: Game): string[] {
  const changes: string[] = [];
  const hf = lawFloor(g, 'heatFloor');
  const rf = lawFloor(g, 'rationFloor');
  for (const c of COMMS) {
    const s = g.comms[c];
    const [w, r] = situation(g, c);
    if (w < 45 && g.coal > 50 && s.heat < 4) { s.heat += 1; changes.push(`${COMM_NAME[c]} 난방 +1`); }
    if (r < 45 && g.food > 50 && s.ration < 4) { s.ration += 1; changes.push(`${COMM_NAME[c]} 배급 +1`); }
    if (w > 65 && g.coal < 40 && s.heat > Math.max(1, hf)) { s.heat -= 1; changes.push(`${COMM_NAME[c]} 난방 −1`); }
    if (r > 65 && g.food < 40 && s.ration > Math.max(1, rf, c === 'guard' ? g.dark?.martial?.rationLocked ?? 0 : 0)) { s.ration -= 1; changes.push(`${COMM_NAME[c]} 배급 −1`); }
  }
  return changes;
}

/** 배급장 맡기기가 열리는 조건(s1c_domestic 6.4, 제안): 지나온 정차 6번 이상, 배급장이 사는 공동체가 호의(+15) 이상이고 적의가 없다.
 * 지지가 떨어져 꺼진 뒤 다시 켜는 선은 +20이다(공방장과 같다, J10 6번). 켜 둔 동안 끄는 선은 +15 그대로다.
 * 인구 조건은 S1에서 인구가 거의 늘지 않아 빼 두었다(S1c 시험판에서 '시작 인구 + 5'로 다시 본다). */
export const DELEGATE_AFTER = 6;
export const DELEGATE_ON = 15;
export const DELEGATE_RE_ON = 20;
/** 배급장이 사는 공동체. S1b 판이면 정해 둔 배급장의 칸, 아니면 앞칸(S1a 6장 #3: 앞칸이거나 기술·의무진). */
export function rationComm(g: Game): Comm {
  const id = g.dark?.staff.ration;
  return (id ? PROFILES.find(p => p.id === id)?.community : undefined) ?? 'front';
}
export function autoLeverStatus(g: Game): { ok: boolean; why?: string } {
  if (g.seg - 1 < DELEGATE_AFTER) return { ok: false, why: `정차 ${DELEGATE_AFTER}번을 지나면 맡길 수 있다` };
  const c = rationComm(g);
  const s = g.comms[c];
  const line = !g.autoLevers && g.autoDropped ? DELEGATE_RE_ON : DELEGATE_ON;
  if (s.rel < line || s.grudge > 0) {
    return { ok: false, why: `배급장이 사는 ${COMM_NAME[c]}${josa(COMM_NAME[c], '이/가')} 열차장을 따르지 않는다${line > DELEGATE_ON ? `(한 번 내려놓아서 관계 +${line}부터)` : ''}` };
  }
  return { ok: true };
}

export function setAutoLevers(g: Game, on: boolean): void {
  if (on && !autoLeverStatus(g).ok) return;
  g.autoLevers = on;
  if (on) g.autoDropped = false;
  if (on) {
    const changes = autoLevers(g);
    if (changes.length > 0) journal(g, `배급장이 레버를 움직였다: ${changes.join(', ')}.`);
  }
}

export function heatCost(g: Game): number {
  return COMMS.reduce((sum, c) => sum + (g.comms[c].heat * g.comms[c].pop) / 40, 0) * P.coalHeatPerLever;
}
export function foodCost(g: Game): number {
  return COMMS.reduce((sum, c) => sum + g.comms[c].pop * g.comms[c].ration, 0) * P.foodPerPersonLever;
}

function lawSum(g: Game, key: 'tensionAdd' | 'foodAdd' | 'coalAdd' | 'fearAdd'): number {
  let sum = 0;
  for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) sum += lawTechRes(g, law)[key] ?? 0;
  return sum;
}
function lawMult(g: Game, key: 'heatMult' | 'haulMult' | 'medMult' | 'deathMult'): number {
  let m = 1;
  for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) m *= lawTechRes(g, law)[key] ?? 1;
  return m;
}

/** 이번 구간에 들 석탄과 식량(정차 제외). 화면의 예고에 쓴다. */
export function forecast(g: Game): { coal: number; food: number } {
  const coal = heatCost(g) * lawMult(g, 'heatMult') + lawSum(g, 'coalAdd') + (g.inStrike ? P.coalStrike : P.coalRun) - (g.forcedRun ? 2 : 0);
  const food = foodCost(g) + lawSum(g, 'foodAdd');
  const dom = domesticForecast(g); // S1c 내정 훅
  return { coal: coal + dom.coal, food: food * dom.foodMult + dom.food };
}

function depart(g: Game): void {
  delete g.platform; // 승강장에 남은 사람은 떠나면서 일지에 그어졌다(5b.5)
  if (g.seg % P.winterEvery === 0) {
    for (const c of COMMS) g.comms[c].base[0] -= P.winterDrop;
    journal(g, '추위가 한 단계 깊어졌다. 모든 칸 온기 −5.', 'bad');
  }
  // S1c 내정 훅: 기관 숙련자가 없으면 선다(매뉴얼도 없으면 끝), 고장 판정.
  const domStall = domesticDepart(g);
  if (domStall === 'end') return finish(g, 'stranded');
  if (domStall === 'stall') {
    g.inStrike = true;
    g.lostSegments += 1;
    journal(g, '기관을 아는 사람이 없다. 열차가 섰다.', 'bad');
    g.phase = 'travel';
    return;
  }
  const engine = g.comms.engine;
  const striking = engine.fervor >= 1 && engine.rel <= domesticStrikeLine(g, P.strikeRel);
  if (striking && lawActive(g, 'strike_ban')) {
    engine.fervor = 0;
    engine.rel = clamp(engine.rel - 10, -100, 100);
    g.fear = clamp(g.fear + 10, 0, 100);
    journal(g, '파업 금지법에 따라 경비대가 기관실 문을 열었다. 화부들이 불 앞으로 끌려갔다.', 'dark');
  } else if (striking && !domesticStrikeRuns(g)) {
    if (!g.inStrike) g.strikes += 1;
    g.inStrike = true;
    g.lostSegments += 1;
    addCard(g, { kind: 'strike', comm: 'engine' });
    journal(g, '기관실이 파업했다. 열차가 섰다.', 'bad');
    g.phase = 'travel';
    return;
  }
  g.inStrike = false;
  // 서막을 거친 판의 첫 출발: 열차 안 첫 거래가 이 구간의 사건이다(first_leg_story 5장 서막 흐름 6번, prologue.ts).
  if (g.seg === 1 && storyOf(g).flags.depot_promise) {
    addCard(g, { kind: 'pro_deal', comm: 'tail' });
    g.phase = 'travel';
    return;
  }
  // 사람 카드가 막 왔으면 이동 사건을 쉰다(사람의 무게 6.0: 카드 수를 늘리지 않는다).
  contentAwayTick(g);
  contentFollowupTick(g);
  const event = peopleCardRecent(g) ? null : drawTravelEvent(g, contentPool(g).map(e => `content:${e.id}`));
  if (event?.startsWith('content:')) addContentCard(g, event.slice('content:'.length));
  else if (event) addCard(g, { kind: 'travel', text: event });
  g.phase = 'travel';
}

/** 장작불을 기다리는 시신 수(냉동칸 + 살던 칸). */
export function pyreCount(g: Game): number {
  return (g.pyre ?? 0) + Object.values(g.pyreKin ?? {}).reduce((a, b) => a + (b ?? 0), 0);
}

/** 장작불 법: 내린 정차에서 기다리던 시신을 태운다. 불쏘시개로 석탄을 쓴다. */
export function burnPyre(g: Game): void {
  const n = pyreCount(g);
  if (n <= 0) return;
  const byWood = domesticPyreWood(g, n); // S1c 내정 훅: 목재 먼저(4.1)
  g.coal -= Math.min(Math.max(0, g.coal), P.pyreCoal * (n - byWood));
  g.pyre = 0;
  darkPyreWeights(g, 0, 0); // S1b: 태운 시신의 확인 수도 비운다
  while (pyreCount(g) > 0) takeKinBody(g);
  journal(g, `선로 옆 장작불에 시신 ${n}구를 태웠다.`, 'dark');
}

// ---- 정차(S1 기획서 7장, 필드 결정 카드) ----
export function crewNames(g: Game, c: Comm, size: number): string[] {
  // 먼저 다녀온 정찰조는 작업조에 다시 넣지 않는다.
  const scouts = g.stop?.scoutReport?.names ?? [];
  // 앓아누운 원래 대표도 내보내지 않는다(사람의 무게 A2).
  const sickRep = g.comms[c].sick?.rep.name;
  // 근신 중이거나 경비를 서는 사람도 못 나간다(S1b, K02 5).
  const busy = CREW_BUSY.flatMap(f => f(g));
  const alive = PROFILES.filter(p => p.community === c && !isGone(g, p.name) && p.age >= 16 && p.age <= 65 && !scouts.includes(p.name) && p.name !== sickRep && !busy.includes(p.name));
  if (alive.length === 0) return [];
  const start = (g.seg * 7) % alive.length;
  return Array.from({ length: Math.min(size, alive.length) }, (_, i) => alive[(start + i) % alive.length].name);
}

/** 이번 정차에 실제로 나가는 명단: 작업조 + 붙는 사람(CREW_EXTRAS). 인원 셈(crewSize)과 위험 굴림은 작업조만 본다. */
export function stopCrew(g: Game): string[] {
  const stop = g.stop;
  if (!stop) return [];
  const names = crewNames(g, stop.crewComm, stop.crewSize);
  for (const n of CREW_EXTRAS.flatMap(f => f(g))) if (!names.includes(n)) names.push(n);
  return names;
}

function suggestTarget(g: Game, loot: Record<LootKey, number>): LootKey {
  const need: Partial<Record<LootKey, number>> = { coal: g.coal / 252, food: g.food / 240 };
  if (g.med < 8) need.medicine = g.med / 20;
  const sorted = (Object.keys(need) as LootKey[]).sort((a, b) => (need[a] ?? 1) - (need[b] ?? 1));
  for (const k of sorted) if (loot[k] >= 25) return k;
  return loot.coal / (g.coal + 1) > loot.food / (g.food + 1) ? 'coal' : 'food';
}

function arriveStop(g: Game): void {
  const place = PLACES[Math.floor(rnd(g) * PLACES.length)];
  const tail = g.comms.tail.promise?.cond.kind === 'skip_dispatch';
  // 같은 장소라도 정차마다 바깥 기척이 다르다. 무리 흔적이 있으면 기본 준비로도 죽음 줄이 뜰 수 있다.
  const roll = rnd(g);
  const threat = roll < 0.25 ? 0.8 : roll < 0.8 ? 1 : 1.4;
  g.stop = {
    place: place.id, target: suggestTarget(g, place.loot), stay: 'normal',
    crewComm: tail ? 'guard' : 'tail', crewSize: 4, threat, done: false, result: null,
  };
  rollStopView(g, g.stop, 1 + P.thrownHorde * g.thrown > 1.2);
  // 핸드카 정찰(X2): 장소 후보가 하나 더 있다(7.3, J10 3번). X2가 없으면 주사위를 더 굴리지 않는다.
  if (g.dom) {
    g.dom.altPlace = null;
    if (techMult(g, 'x2') > 0) {
      const others = PLACES.filter(p => p.id !== place.id);
      g.dom.altPlace = others[Math.floor(rnd(g) * others.length)].id;
    }
  }
  g.phase = 'stop';
}

/** 핸드카가 본 다른 곳으로 간다. 정찰을 보내기 전에 한 번만 고른다(되돌리면 바깥 기척을 다시 뽑게 되니 막는다). */
export function takeAltPlace(g: Game): void {
  const stop = g.stop;
  const alt = g.dom?.altPlace;
  if (!stop || stop.done || stop.scoutReport || !alt) return;
  const place = PLACES.find(p => p.id === alt);
  if (!place) return;
  g.dom!.altPlace = null;
  stop.place = place.id;
  stop.target = suggestTarget(g, place.loot);
  rollStopView(g, stop, 1 + P.thrownHorde * g.thrown > 1.2);
  journal(g, `핸드카가 본 ${place.name}에 섰다.`);
}

export function setStop(g: Game, patch: Partial<{ target: LootKey; stay: StayId; crewComm: Comm; crewSize: number; scout: boolean }>): void {
  if (!g.stop || g.stop.done) return;
  // 정찰은 끄고 켜는 단추가 아니라 먼저 보내는 일이다(sendScouts). 옛 재현 기록의 scout: true는 보내기로 읽는다.
  const { scout, ...rest } = patch;
  // 기관실은 화부가 빠지면 열차가 못 가서 작업조로 못 낸다(first_leg_story 6.4).
  if (rest.crewComm && !CREW_COMMS.includes(rest.crewComm)) delete rest.crewComm;
  Object.assign(g.stop, rest);
  g.stop.crewSize = clamp(g.stop.crewSize, 2, 8);
  if (scout) sendScouts(g);
}

/** 정찰조 2명을 먼저 보낸다(2026-10-07 사용자). 정찰조도 다치거나 못 돌아올 수 있다. 하나라도 돌아오면 바깥 기척을 알고
 * 위험 줄이 약속이 된다. 아무도 못 돌아오면 기척은 모른 채로 남는다. 정찰조는 이번 회기 표결에 빠지고, 작업 시간이 줄어 산출이 준다.
 * 결과는 사람마다 정해 둔 난수라 난수 흐름을 건드리지 않는다. */
export function sendScouts(g: Game): StopState['scoutReport'] | null {
  const stop = g.stop;
  if (!stop || stop.done || stop.scoutReport) return null;
  const place = PLACES.find(p => p.id === stop.place) ?? PLACES[0];
  const c = stop.crewComm;
  const names = crewNames(g, c, stop.crewSize + P.scoutSize).slice(stop.crewSize);
  const pool = names.length ? names : crewNames(g, c, P.scoutSize);
  const guard = g.comms.guard;
  const danger = place.risk * (stop.threat ?? 1) * Math.min(1.5, 1 + P.thrownHorde * g.thrown) * (guard.fervor >= 1 && guard.rel <= -40 ? 1.5 : 1);
  // 바깥이 실제로 고요하면(기척 0.8) 정찰조도 다치지 않는다. 다쳐 돌아온 정찰조 옆에 '괜찮을 것 같다'가 뜨면 정찰한 곳의 정직이 깨진다(파밍 스레드 17:11, 제안).
  const calm = (stop.threat ?? 1) <= 0.8;
  const qd = calm ? 0 : P.scoutDeath * danger;
  const qh = calm ? 0 : Math.min(0.5, P.scoutHurt * danger);
  const dead = pool.filter(n => fateRoll(g, n, 'sd') < qd);
  const hurt = pool.filter(n => !dead.includes(n) && fateRoll(g, n, 'sh') < qh);
  stop.scoutReport = { comm: c, names: pool, hurt, dead };
  stop.scout = dead.length < pool.length;
  if (stop.scout && stop.omen) markSeen(g, stop.omen);
  g.injured += hurt.length;
  if (dead.length > 0) onDeath(g, c, dead, 'other');
  journal(g, `${place.name}에 정찰조(${pool.join(', ')})를 먼저 보냈다.${stop.scout ? ' 돌아왔다.' : ' 아무도 돌아오지 않았다.'}${hurt.length ? ` ${hurt.join(', ')}이(가) 크게 다쳤다.` : ''}${dead.length && stop.scout ? ` ${dead.join(', ')}은(는) 돌아오지 못했다.` : ''}`, dead.length || hurt.length ? 'bad' : undefined);
  return stop.scoutReport;
}

export interface StopRisk {
  /** 기대 부상자 수(중상) */
  lam: number;
  pDeath: number;
  /** 이 준비로 가면 크게 다칠 사람 수. 정찰하든 안 하든 같다(정찰은 드러내기만 한다). */
  maxHurt: number;
  /** 이 준비로 가면 죽을 사람 수. */
  maxDead: number;
  /** 정해 둔 결과: 누가 죽고 누가 크게 다치나. */
  fate: { dead: string[]; hurt: string[] };
  guardRefused: boolean;
  horde: boolean;
  /** 이번 정차에 무리 흔적이 새롭다 */
  fresh: boolean;
  /** 태울 시신이 있어 장작불이 무리를 끈다 */
  pyre: boolean;
  /** 정찰로 바깥 기척을 안다. 모르면 줄 대신 '위험 모름'이 뜨고, 결과는 정찰했을 때와 같다. */
  known: boolean;
}

/** 이 정차에서 이 사람에게 정해 둔 난수(0~1). 난수 흐름을 건드리지 않게 판 씨앗으로 만든다. */
function fateRoll(g: Game, name: string, kind: 'd' | 'h' | 'sd' | 'sh'): number {
  return hash(`${g.seed}|${g.seg}|${g.stop?.place ?? ''}|${name}|${kind}`) / 4294967296;
}

/** 정차 위험. 장소 위험도, 체류, 인원, 던진 시신이 키운 무리, 경비대의 경계 거부와 호위로 정해진다.
 * 준비(무엇을·얼마나·누구를·몇 명)를 바꾸면 바로 다시 계산되고, 결과는 이 줄이 약속한 범위를 벗어나지 않는다. */

export function stopRisk(g: Game): StopRisk {
  const stop = g.stop;
  const place = PLACES.find(p => p.id === stop?.place) ?? PLACES[0];
  const stay = STAY[stop?.stay ?? 'normal'];
  const crew = stop?.crewSize ?? 4;
  const guard = g.comms.guard;
  const guardRefused = guard.fervor >= 1 && guard.rel <= -40;
  const guardMult = guardRefused ? 1.5 : 1;
  const horde = Math.min(1.5, 1 + P.thrownHorde * g.thrown);
  const escort = g.guardEscort ? 0.5 : 1;
  // 장작불의 불빛과 연기가 무리를 끈다(s1c_domestic 4.1). 태울 시신이 있으면 내리는 정차에 붙는다.
  const threat = (stop?.threat ?? 1) * (pyreCount(g) > 0 ? P.pyreLight : 1);
  const dm = domesticRiskMult(g); // S1c 내정 훅
  const lam = place.risk * P.injuryRate * guardMult * horde * stay.risk * (crew / 4) * escort * threat * dm.injury;
  const pDeath = place.risk * P.deathRate * guardMult * horde * lawMult(g, 'deathMult') * stay.risk * escort * threat * dm.death;
  // 결과는 사람마다 정해 둔 난수로 먼저 정한다. 정찰은 이 결과를 드러내기만 해서 정찰 여부가 피해를 바꾸지 않는다
  // (07_outside_eye_triage N2). 준비를 바꾸면 같은 난수로 다시 계산하니 다시 굴리는 길도 없다.
  // 사람 하나의 죽을 확률은 pDeath/4(4명 기준 기대 사망 pDeath), 크게 다칠 확률은 lam/인원(기대 중상 lam).
  const fate = { dead: [] as string[], hurt: [] as string[] };
  if (stop) {
    const names = crewNames(g, stop.crewComm, crew);
    const qd = pDeath / 4;
    const qh = Math.min(0.9, lam / Math.max(1, names.length));
    // 한 명은 반드시 살아 돌아온다.
    fate.dead = names.filter(n => fateRoll(g, n, 'd') < qd).slice(0, Math.max(0, names.length - 1));
    fate.hurt = names.filter(n => !fate.dead.includes(n) && fateRoll(g, n, 'h') < qh);
  }
  return {
    lam, pDeath, maxHurt: fate.hurt.length, maxDead: fate.dead.length, fate,
    guardRefused, horde: horde > 1.2, fresh: (stop?.threat ?? 1) > 1, known: !!stop?.scout, pyre: pyreCount(g) > 0,
  };
}

/** 약속 단계. dead와 hurt면 그 피해가 1명 이상 반드시 일어나고 내부 최악을 넘지 않는다.
 * light와 calm이면 죽음과 중상은 없다(light는 긁히고 삐는 정도가 있다). */
export function riskLevel(r: StopRisk): RiskLevel {
  if (r.maxDead > 0) return 'dead';
  if (r.maxHurt > 0) return 'hurt';
  return r.lam >= 0.2 ? 'light' : 'calm';
}

/** 정찰 여부와 상관없이 알 수 있는 까닭(정치가 키운 위험). */
export function riskWhy(r: StopRisk): string[] {
  const why: string[] = [];
  if (r.guardRefused) why.push('경비대가 경계를 서지 않는다');
  if (r.horde) why.push('던진 시신에 무리가 몰려 있다');
  if (r.pyre) why.push('장작불 불빛이 무리를 끈다');
  return why;
}

/** 작업조를 낸 칸이 지친다: 노출 +gain, 늘 하던 일이 아닌 칸(의무진·앞칸)은 관계 −3(first_leg_story 6.4). 반감 줄을 돌려준다. */
export function crewWork(g: Game, c: Comm, gain: number): string | null {
  const s = g.comms[c];
  // 이미 한계 위면 그대로 두고, 아래면 한계까지만 오른다.
  s.base[3] = Math.max(s.base[3], Math.min(P.crewCap, s.base[3] + gain));
  if (!CHORE_COMMS.includes(c)) return null;
  s.rel = clamp(s.rel + P.choreRel, -100, 100);
  return `${COMM_NAME[c]}${josa(COMM_NAME[c], '은/는')} 손에 안 익은 짐을 날랐다. 불만이 나온다.`;
}

/** 안 나간 칸은 쉰다: 노출 −10, 쉼 바닥(꼬리칸 35, 의무진 25, 앞칸 10) 아래로는 안 내려간다. 지나친 정차면 모두 쉰다. */
export function crewRest(g: Game, busy: Comm | null): void {
  for (const c of COMMS) {
    const floor = REST_FLOOR[c];
    if (floor === undefined || c === busy) continue;
    const b = g.comms[c].base;
    b[3] = Math.max(Math.min(floor, b[3]), b[3] - P.crewRest);
  }
}

/** 작업조로 낼 수 있는 칸. 기관실은 못 낸다(6.4). */
export const CREW_COMMS: readonly Comm[] = COMMS.filter(c => CREW_HAUL[c] !== undefined);

/** 정차 카드에 미리 적는 작업조 값(6.4): 이 칸을 내면 노출이 얼마가 되고, 무엇을 잃고, 누가 쉬나. */
export function crewPreview(g: Game, c: Comm): { from: number; to: number; rel: number; haul: number; rest: Comm[] } {
  const from = Math.round(situation(g, c)[3]);
  const to = Math.round(situation(g, c)[3] + Math.max(0, Math.min(P.crewCap, g.comms[c].base[3] + P.crewGain) - g.comms[c].base[3]));
  const rest = COMMS.filter(o => o !== c && REST_FLOOR[o] !== undefined && g.comms[o].base[3] > REST_FLOOR[o]!);
  return { from, to, rel: CHORE_COMMS.includes(c) ? P.choreRel : 0, haul: CREW_HAUL[c] ?? 1, rest };
}

export function resolveStop(g: Game, go: boolean): StopResult | null {
  const stop = g.stop;
  if (!stop || stop.done) return null;
  const place = PLACES.find(p => p.id === stop.place) ?? PLACES[0];
  stop.done = true;
  // 먼저 다녀온 정찰조는 지쳐 쓰러져 이번 회기 표결에 빠진다(지나쳐도 마찬가지).
  const scoutsBack = stop.scoutReport ? stop.scoutReport.names.length - stop.scoutReport.dead.length : 0;
  if (stop.scoutReport) g.comms[stop.scoutReport.comm].away += scoutsBack;
  // 위험은 어두운 길 훅이 사람을 빼기 전에 정한다(K01 4와 같은 까닭). 하차나 정차 명령으로 사람이 빠지면 작업조 명단이 돌고,
  // 시신이 생기면 불빛 배수가 붙어 정찰이 약속한 피해와 달라진다. stopRisk는 난수 흐름을 쓰지 않는다.
  const risk = stopRisk(g);
  const orderTarget = darkStopTarget(g);
  const darkNotes = darkStop(g, !!(go && stop.target), go && stop.target ? stopCrew(g) : []);
  if (!go || !stop.target) {
    stop.result = { passed: true, gains: {}, injured: [], dead: [], notes: ['정차하지 않고 지나쳤다.'] };
    journal(g, `${place.name}을(를) 지나쳤다.`);
    crewRest(g, null);
    stop.result.notes.push(...domesticStop(g, true, 0)); // S1c 내정 훅
    checkStopPromises(g, null, {});
    return stop.result;
  }
  // 위험은 위에서 정차 상태를 바꾸기 전에 정했다(K01 4). 장작불이 시신을 태우면 불빛 배수가 빠져 예고한 피해와 달라진다.
  const stay = STAY[stop.stay];
  g.coal -= stay.coal;
  burnPyre(g);
  const weights = Object.fromEntries(LOOT_KEYS.map(k => [k, place.loot[k] * (k === stop.target ? P.targetBoost : 1)])) as Record<LootKey, number>;
  const tot = LOOT_KEYS.reduce((sum, k) => sum + weights[k], 0);
  let haul = P.haulTotal * (0.7 + rnd(g) * 0.6) * stay.mult * (0.7 + 0.075 * stop.crewSize) * lawMult(g, 'haulMult') * (stop.scoutReport ? P.scoutHaul : 1) * domesticHaulMult(g) * darkHaulMult(g)
    * (CREW_HAUL[stop.crewComm] ?? 1);
  // 정차로 정한 명령의 결과는 정찰이 약속한 위험 밖이라 영수증에 따로 한 줄로 적는다(s1b 4.7, K02 3).
  const notes: string[] = [...darkNotes];
  const tail = g.comms.tail;
  // 꼬리칸 작업 거부는 꼬리칸이 작업조로 나갈 때만(J11). 다른 칸을 보내면 쉬는 꼬리칸의 거부가 운반량을 깎지 않는다.
  if (stop.crewComm === 'tail' && tail.fervor >= 1 && tail.rel <= -40) { haul *= 0.7; notes.push('꼬리칸이 작업을 거부했다(−30%).'); }
  // 상중인 사람은 손이 느리다(사람의 무게 A1).
  const grieving = crewNames(g, stop.crewComm, stop.crewSize).filter(n => mourners(g).includes(n));
  if (grieving.length > 0) { haul *= 1 - 0.1 * grieving.length; notes.push(`${grieving.join(', ')}은(는) 상중이라 손이 느렸다.`); }
  const gains: Partial<Record<LootKey, number>> = {};
  for (const k of LOOT_KEYS) {
    const amt = (haul * weights[k]) / tot;
    if (k === 'coal' || k === 'food' || k === 'medicine') {
      const v = Math.round(amt);
      if (v > 0) gains[k] = v;
    } else if (k === 'luxury') {
      const v = Math.round(amt / 3);
      if (v > 0) gains[k] = v;
    } else {
      const v = Math.min(2, Math.floor(amt / 10) + (rnd(g) < (amt % 10) / 10 ? 1 : 0));
      if (v > 0) gains[k] = v;
    }
  }
  g.coal += gains.coal ?? 0;
  g.food += gains.food ?? 0;
  g.med += gains.medicine ?? 0;
  g.lux += gains.luxury ?? 0;
  g.symbols += gains.symbol ?? 0;
  for (let i = 0; i < (gains.secret ?? 0); i += 1) {
    const s = addSecret(g);
    notes.push(`문서에서 ${COMM_NAME[s.about]} 대표의 약점을 찾았다.`);
  }
  if (risk.guardRefused) notes.push('경비대가 경계를 거부했다.');
  const names = crewNames(g, stop.crewComm, stop.crewSize);
  // 정해 둔 결과 그대로. 정찰했으면 위험 줄이 이걸 미리 보여 줬다.
  // 정차 명령이나 하차로 이미 열차에 없는 사람은 약속한 피해에서 뺀다(같은 사람이 두 번 죽지 않는다).
  const dead = risk.fate.dead.filter(n => !isGone(g, n));
  // 정차 명령이 실행돼 대상이 이미 다쳤으면(runOrder가 셌다) 약속한 부상에서 또 세지 않는다.
  const orderHit = orderTarget && !g.dark?.order ? orderTarget : null;
  const hurt = risk.fate.hurt.filter(n => !isGone(g, n) && n !== orderHit);
  if (!hurt.length && !dead.length && risk.lam >= 0.2) notes.push('몇이 긁히고 삐었다. 크게 다친 사람은 없다.');
  const injuredOnly = hurt.filter(n => !dead.includes(n));
  g.injured += injuredOnly.length;
  // 열차장 명령으로 나갔다가 크게 다쳤다(body_injury 4.3, 제안).
  if (injuredOnly.length > 0) g.comms[stop.crewComm].rel = clamp(g.comms[stop.crewComm].rel + P.hurtRel * injuredOnly.length, -100, 100);
  // '매우 불길하다'를 보고도 보냈으면 열차장이 고른 죽음이다.
  if (dead.length > 0) onDeath(g, stop.crewComm, dead, risk.known && risk.maxDead > 0 ? 'warned' : 'other');
  const scouts = scoutsBack;
  g.comms[stop.crewComm].away += stop.crewSize - dead.length;
  const chore = crewWork(g, stop.crewComm, P.crewGain);
  if (chore) notes.push(chore);
  crewRest(g, stop.crewComm);
  g.lastCrew = stop.crewComm;
  notes.push(...domesticStop(g, false, dead.length)); // S1c 내정 훅
  stop.result = { passed: false, gains, injured: injuredOnly, dead, notes };
  const got = (Object.keys(gains) as LootKey[]).map(k => `${LOOT_NAME[k]} ${gains[k]}`).join(', ');
  journal(g, `${place.name}에 ${stay.name} 머물렀다(${COMM_NAME[stop.crewComm]} ${stop.crewSize}명${scouts ? `, 정찰 ${scouts}명` : ''}). ${got || '빈손'}.${injuredOnly.length ? ` 부상 ${injuredOnly.length}.` : ''}`);
  // 도덕 카드: 부상자 발견, 물림.
  // 같은 도덕 카드가 정차마다 나오지 않게 간격을 둔다(2026-10-07 사용자 후기).
  const since = (key: string) => g.seg - (g.eventLog?.[key]?.seg ?? -99);
  if (since('rescue') >= 4 && rnd(g) < P.rescueRate) addCard(g, { kind: 'rescue', comm: stop.crewComm, who: names[0] });
  if (since('bitten') >= 3 && injuredOnly.length > 0 && rnd(g) < 0.35) addCard(g, { kind: 'bitten', comm: stop.crewComm, who: injuredOnly[0] });
  checkStopPromises(g, stop.target, gains);
  return stop.result;
}

function checkStopPromises(g: Game, target: LootKey | null, gains: Partial<Record<LootKey, number>>): void {
  for (const c of COMMS) {
    const p = g.comms[c].promise;
    if (!p || p.due > g.seg) continue;
    if (p.kind === 'fetch') {
      const want = FETCH_WANT[c];
      if ((gains[want.target] ?? 0) >= want.amount) {
        keepPromise(g, c);
        g.comms[c].rel = clamp(g.comms[c].rel + 10, -100, 100);
      } else {
        breakPromise(g, c);
      }
    } else if (p.cond.kind === 'target') {
      if (target === p.cond.target) keepPromise(g, c); else breakPromise(g, c);
    } else if (p.cond.kind === 'skip_dispatch') {
      if (g.stop?.crewComm !== 'tail' || !target) keepPromise(g, c); else breakPromise(g, c);
    }
  }
}

/** 약속을 지켰다(S1a 3.7). label을 주면 거래창 밖의 약속(서막)이다. */
export function keepPromise(g: Game, c: Comm, label = g.comms[c].promise?.label ?? ''): void {
  const s = g.comms[c];
  s.promise = null;
  g.trust = clamp(g.trust + 4, 0, 100);
  s.rel = clamp(s.rel + 5, -100, 100);
  if (s.grudge === 1) s.grudge = 0;
  g.stats.promisesKept += 1;
  if (g.dark) g.dark.kept[c] += 1; // S1b 신임 입장(5.3): 칸마다 지킨 약속
  journal(g, `${COMM_NAME[c]}과(와)의 약속을 지켰다: ${label}.`, 'good');
}

/** 약속을 어겼다(S1a 3.7). label을 주면 거래창 밖의 약속(서막)이다. */
export function breakPromise(g: Game, c: Comm, label = g.comms[c].promise?.label ?? ''): void {
  const s = g.comms[c];
  s.promise = null;
  g.trust = clamp(g.trust - (seats(g)[c] >= 30 ? 12 : 8), 0, 100);
  s.rel = clamp(s.rel - 20, -100, 100);
  s.fervor = Math.min(3, s.fervor + 1);
  g.tension = clamp(g.tension + 3, 0, 100);
  g.stats.promisesBroken += 1;
  if (g.dark) g.dark.broken[c] += 1;
  offend(g, c);
  journal(g, `${COMM_NAME[c]}과(와)의 약속을 어겼다: ${label}.`, 'bad');
}

function afterStop(g: Game): void {
  strangerCorpse(g);
  if (isSessionSeg(g.seg)) {
    openCouncil(g);
    g.phase = 'council';
  } else {
    settle(g);
  }
}

// ---- 정산 ----
function settle(g: Game): void {
  const before = { coal: g.coal, food: g.food, med: g.med, trust: g.trust, tension: g.tension, rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel])) as Record<Comm, number> };
  const notes: string[] = [];
  const f = forecast(g);
  g.coal -= f.coal;
  g.food -= f.food;
  if (!g.inStrike) g.comms.engine.base[3] += P.engineFatigue;
  else g.tension = clamp(g.tension + 3, 0, 100);
  // 공간을 내준 칸은 당겨 둔 동안 구간마다 단당 관계 −1(first_leg_story 6.4).
  if (g.space?.giver && g.space.step > 0) {
    const giver = g.comms[g.space.giver];
    giver.rel = clamp(giver.rel + P.spaceHoldRel * g.space.step, -100, 100);
  }
  g.forcedRun = false;
  g.guardEscort = false;
  medicineTick(g, notes);
  domesticSettle(g, notes); // S1c 내정 훅
  hubLeakTick(g, notes); // 라이프치히 두 구간 전부터 창고 유출
  drift(g);
  checkDuePromises(g);
  hungerTick(g, notes);
  biteTick(g);
  needTick(g, notes);
  peopleTick(g, () => rnd(g));
  if (g.council && !g.council.emergency && !g.council.martial) dropUnratified(g);
  if (g.council) bribeDetection(g);
  leashTick(g);
  aiLeaders(g);
  darkSettle(g); // S1b 훅: 시신, 군중 시계, 진실, 도둑질, 불씨
  meters(g);
  for (const c of COMMS) g.comms[c].away = 0;
  if (g.phase !== 'end') checkEnd(g); // 정산 도중 쿠데타로 이미 끝났으면 다른 끝이 덮지 않는다
  g.lastSettle = {
    coal: g.coal - before.coal, food: g.food - before.food, med: g.med - before.med,
    trust: g.trust - before.trust, tension: g.tension - before.tension,
    rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel - before.rel[c]])) as Record<Comm, number>, notes,
  };
  if (g.phase !== 'end') g.phase = 'settle';
}

/** 숨긴 물림의 시계(body_injury 4.4, 숫자는 제안). 귀환 검사 법이 있으면 바로, 없으면 열이 올라 구간마다 반쯤 들킨다.
 * 기한까지 안 들키면 그 칸 안에서 일어난다. 격리했으면 조용히 끝난다. */
function biteTick(g: Game): void {
  const keep: typeof g.hiddenBites = [];
  for (const b of g.hiddenBites ?? []) {
    if (g.seg >= b.due) {
      if (b.isolated) {
        journal(g, `격리된 ${b.who}이(가) 숨을 거뒀다. 일어나기 전에 경비대가 처리했다.`, 'dark');
      } else if (!b.found || !g.cards.some(k => k.kind === 'bite_found' && k.who === b.who)) {
        // 숨긴 물림, 또는 드러났는데 아무도 처리하지 않은 채 기한이 온 물림(K02 1 보험: 무기한으로 남지 않는다).
        const bitten = 1 + (rnd(g) < 0.5 ? 1 : 0);
        g.injured += bitten;
        g.tension = clamp(g.tension + 8, 0, 100);
        g.fear = clamp(g.fear + 5, 0, 100);
        journal(g, `${b.who}이(가) ${COMM_NAME[b.comm]} 안에서 일어났다. ${bitten}명이 물렸다.`, 'bad');
      } else {
        keep.push(b);
        continue;
      }
      onDeath(g, b.comm, [b.who], 'chosen');
      continue;
    }
    if (!b.found && (lawActive(g, 'patrol') || rnd(g) < 0.5)) {
      b.found = true;
      const how = lawActive(g, 'patrol') ? '귀환 검사에서 드러났다.' : '열이 오르는 걸 의무장이 알아챘다.';
      addCard(g, { kind: 'bite_found', comm: b.comm, who: b.who, text: how });
    }
    keep.push(b);
  }
  g.hiddenBites = keep;
}

/** 식량이 0이어도 사람들은 얼마간 버틴다. 버틴 구간이 길어지면 굶어 죽는 사람이 나온다(제안, 프로스트펑크식). */
export const HUNGER_GRACE = 3;

function hungerTick(g: Game, notes: string[]): void {
  if (g.food > 0) { g.hunger = 0; return; }
  g.hunger = (g.hunger ?? 0) + 1;
  if (g.hunger === 1) {
    addCard(g, { kind: 'info', who: '식량이 떨어졌다', text: `사람들은 허리띠를 졸라매고 버틴다. ${HUNGER_GRACE}구간을 넘기면 굶어 죽는 사람이 나온다.` });
    return;
  }
  if (g.hunger <= HUNGER_GRACE) { notes.push(`굶은 지 ${g.hunger}구간째다.`); return; }
  const [p] = pickVictims(g, 1, 'hunger', () => rnd(g));
  if (p) {
    onDeath(g, p.community, [p.name]);
    journal(g, `${COMM_NAME[p.community]}의 ${p.name}(${p.age})이(가) 굶어 죽었다.`, 'bad');
    notes.push('굶어 죽은 사람이 나왔다.');
  }
}

// ---- 비상 소집(2026-10-07 사용자 후기) ----
// 회기가 아닌 구간에도 정차를 마친 뒤 의회를 부를 수 있다. 신임을 쓰고, 최근에 자주 불렀을수록 비싸다(제안).
// 파견 나간 칸의 표는 빠지므로, 반대하는 칸이 밖에 있을 때 부르면 '기습 표결'로 기억된다.
export function emergencyCost(g: Game): number {
  // 대권 중엔 열차장이 바로 부른다(포고하려고). 그 밖엔 신임을 쓴다.
  if (canDecree(g)) return 0;
  const recent = (g.emergencyCalls ?? []).filter(at => g.seg - at < 6).length;
  return 6 + 4 * recent;
}

export function emergencyStatus(g: Game): { show: boolean; ok: boolean; cost: number; why?: string } {
  const cost = emergencyCost(g);
  const show = g.phase === 'stop' && !!g.stop?.done && !isSessionSeg(g.seg);
  if (!show) return { show, ok: false, cost };
  if (g.cards.length > 0) return { show, ok: false, cost, why: '먼저 서류를 처리한다' };
  if (g.dark?.martial) return { show, ok: false, cost, why: '의회가 닫혀 있다' };
  if (g.trust <= cost) return { show, ok: false, cost, why: '신임이 모자라다' };
  if (agendaOptions(g).options.length === 0) return { show, ok: false, cost, why: '올릴 안건이 없다' };
  return { show, ok: true, cost };
}

export function callEmergency(g: Game): boolean {
  const st = emergencyStatus(g);
  if (!st.ok) return false;
  g.trust = clamp(g.trust - st.cost, 0, 100);
  (g.emergencyCalls ??= []).push(g.seg);
  openCouncil(g, true);
  g.phase = 'council';
  const away = COMMS.filter(c => g.comms[c].away > 0).map(c => COMM_NAME[c]);
  journal(g, `열차장이 비상 소집을 불렀다(신임 −${st.cost}).${away.length ? ` ${away.join(', ')}의 작업조는 돌아와 쓰러져 잔다.` : ''}`, 'dark');
  return true;
}

function medicineTick(g: Game, notes: string[]): void {
  const need = g.injured * P.medPerInjured * lawMult(g, 'medMult');
  const med = g.comms.medtech;
  const refusing = med.fervor >= 1 && med.rel <= -40;
  if (g.med >= need) {
    g.med -= need;
    if (refusing) {
      notes.push('의무진이 진료를 거부했다.');
    } else {
      let heal = 0.4;
      for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) heal = Math.max(heal, lawTechRes(g, law).heal ?? 0);
      heal = domesticHealRate(g, heal); // S1c 내정 훅
      let healed = 0;
      for (let i = 0; i < g.injured; i += 1) if (rnd(g) < heal) healed += 1;
      g.injured -= healed;
    }
  } else {
    g.med = 0;
    let dead = 0;
    for (let i = 0; i < g.injured; i += 1) if (rnd(g) < 0.1) dead += 1;
    g.injured -= dead;
    if (dead > 0) {
      for (const p of pickVictims(g, dead, 'wound', () => rnd(g))) onDeath(g, p.community, [p.name]);
    }
    notes.push('의약품이 떨어졌다.');
  }
  // 장작불을 기다리는 시신도 일어난다. 냉동칸은 안치와 같은 확률, 살던 칸은 따뜻해서 두 배(s1c_domestic 4.1).
  const kinBodies = pyreCount(g) - (g.pyre ?? 0);
  // S1b: 머리를 확인한 시신은 일어나지 않는다(dark/corpses.ts). 칸마다 몫을 나눠 받는다. S1a 판이면 그대로.
  const w = darkPyreWeights(g, g.pyre ?? 0, kinBodies);
  const pyreWeight = w.cold + 2 * w.kin;
  if (pyreWeight > 0 && rnd(g) < Math.min(0.3, P.storeRisk * pyreWeight)) {
    const inKin = w.kin > 0 && rnd(g) < (2 * w.kin) / pyreWeight;
    if (inKin) takeKinBody(g);
    else g.pyre = (g.pyre ?? 0) - 1;
    g.injured += 1;
    g.tension = clamp(g.tension + 5, 0, 100);
    journal(g, inKin ? '칸에 두었던 시신 하나가 일어났다. 하나가 다쳤다.' : '냉동칸에서 태우려고 기다리던 시신 하나가 일어났다. 경비 하나가 다쳤다.', 'bad');
  }
  // S1b: 무게를 늘 먼저 셈해 냉동칸이 비면 확인 수도 0으로 돌린다. S1a 판이면 무게가 곧 시신 수다.
  const storedWeight = darkStoredWeight(g, g.stored);
  if (storedWeight > 0 && rnd(g) < Math.min(0.3, P.storeRisk * storedWeight) * domesticThawMult(g)) {
    g.injured += 2;
    g.tension = clamp(g.tension + 8, 0, 100);
    g.stored = 0;
    darkStoredWeight(g, 0);
    journal(g, '냉동칸의 시신이 녹아 일어났다. 둘이 다쳤다.', 'bad');
  }
}

/** 처지가 관계를 움직인다(브리프 1.2). 열기도 여기서 오른다(1.6). */
function drift(g: Game): void {
  for (const c of COMMS) {
    const s = g.comms[c];
    const [w, r, cr, ex] = situation(g, c);
    let dr = -(Math.max(0, 45 - w) / 10) - Math.max(0, 45 - r) / 10 - Math.max(0, cr - 60) / 15 - Math.max(0, ex - 50) / 15;
    if (dr === 0) {
      const surplus = Math.max(0, w - 45) + Math.max(0, r - 45) + Math.max(0, 60 - cr) + Math.max(0, 50 - ex);
      dr = Math.min(P.recoverCap, P.recoverBase + surplus / 30);
      dr = Math.max(0, Math.min(dr, P.naturalCeiling - s.rel));
    }
    if (g.food <= 0) dr -= 5;
    if (c === 'front' && g.lux <= 0) dr -= 1;
    s.rel = clamp(s.rel + clamp(dr, -6, P.recoverCap), -100, 100);
    if (s.rel <= -40) {
      s.badStreak += 1;
      if (s.badStreak >= 3) {
        s.fervor = Math.min(3, s.fervor + 1);
        s.badStreak = 0;
        journal(g, `${COMM_NAME[c]}의 열기가 올랐다. ${PROTEST[c]}이(가) 시작될 수 있다.`, 'bad');
      }
    } else {
      s.badStreak = 0;
    }
    if (s.rel >= 15 && s.fervor > 0) s.fervor -= 1;
  }
}

function checkDuePromises(g: Game): void {
  for (const c of COMMS) {
    const s = g.comms[c];
    const p = s.promise;
    if (!p || p.due > g.seg) continue;
    if (p.kind === 'fetch' || p.cond.kind === 'target' || p.cond.kind === 'skip_dispatch') {
      // 정차가 없었으면(파업) 다음 정차로 미룬다.
      if (g.inStrike) p.due = g.seg + 1;
      continue;
    }
    const dom = domesticPromise(g, c, p); // S1c 내정 훅
    if (dom !== null) { if (dom) keepPromise(g, c); else breakPromise(g, c); continue; }
    let ok = false;
    if (p.cond.kind === 'heat') ok = s.heat >= (p.baseline ?? 0) + 1;
    else if (p.cond.kind === 'ration') ok = s.ration >= (p.baseline ?? 0) + 1;
    else if (p.cond.kind === 'keep_ration') ok = s.ration >= (p.baseline ?? 0);
    else if (p.cond.kind === 'give_med') { ok = g.med >= (p.cond.amount ?? 0); if (ok) g.med -= p.cond.amount ?? 0; }
    else if (p.cond.kind === 'give_lux') { ok = g.lux >= (p.cond.amount ?? 0); if (ok) g.lux -= p.cond.amount ?? 0; }
    if (ok) keepPromise(g, c); else breakPromise(g, c);
  }
}

function bribeDetection(g: Game): void {
  for (const deal of g.council?.deals ?? []) {
    if (deal.tool === 'bribe' && dealHolds(deal)) {
      const s = g.comms[deal.comm];
      if (rnd(g) < BRIBE_EXPOSE[s.leader.trait]) exposeBribe(g, deal.comm);
    } else if (deal.tool === 'favor' && rnd(g) < 0.15) {
      for (const o of COMMS) if (o !== deal.comm) g.comms[o].rel = clamp(g.comms[o].rel - 5, -100, 100);
      journal(g, `${g.comms[deal.comm].leader.name}의 표가 빚 때문이었다는 말이 돈다. 공정성 시비가 붙었다.`, 'bad');
    }
  }
  g.council = null;
}

function leashTick(g: Game): void {
  const keep = [];
  for (const leash of g.leashes) {
    const s = g.comms[leash.comm];
    if (rnd(g) < s.grudge * leash.weight * 0.04) {
      s.rel = clamp(s.rel - (g.seg - leash.since) * 3, -100, 100);
      g.trust = clamp(g.trust - 5, 0, 100);
      offend(g, leash.comm);
      addCard(g, { kind: 'leash', comm: leash.comm });
      journal(g, `${s.leader.name}이(가) 목줄을 끊었다. 협박이 드러났다.`, 'bad');
    } else {
      keep.push(leash);
    }
  }
  g.leashes = keep;
}

/** AI 지도자: 요구, 부탁, 선동, 안건 올리기, 파업 경고(브리프 4장, 5장). 구간마다 많아야 카드 두 장. */
function aiLeaders(g: Game): void {
  let cards = 0;
  // 요구: 처지가 가장 나쁜 집단 하나.
  let worst: Comm | null = null;
  let worstGap = 0;
  for (const c of COMMS) {
    const s = g.comms[c];
    if (s.demandCool > 0) { s.demandCool -= 1; continue; }
    const [w, r, , ex] = situation(g, c);
    // 레버를 이미 끝까지 올렸으면 그 레버로는 요구하지 않는다.
    const gap = c === 'engine' && ex > 50 ? ex - 50 + 5
      : (s.heat < 4 ? Math.max(0, 45 - w) : 0) + (s.ration < 4 ? Math.max(0, 45 - r) : 0);
    if (gap > worstGap) { worst = c; worstGap = gap; }
  }
  if (worst && !g.cards.some(x => x.kind === 'demand')) {
    addCard(g, { kind: 'demand', comm: worst });
    // 같은 요구를 여러 번 받았으면 다음 요구까지 조금 더 뜸하다.
    const seen = Math.max(g.eventLog?.[`demand:${worst}`]?.n ?? 0, worst === 'engine' ? g.eventLog?.['demand:engine_shift']?.n ?? 0 : 0);
    g.comms[worst].demandCool = 2 + Math.min(seen, 2);
    cards += 1;
  }
  // 파업 경고
  const engine = g.comms.engine;
  const [, er, , eex] = situation(g, 'engine');
  if (engine.fervor === 0 && engine.rel <= -8 && (eex > 50 || er < 45) && g.seg - g.strikeWarned >= 4 && cards < 2) {
    g.strikeWarned = g.seg;
    addCard(g, { kind: 'strike_warn', comm: 'engine' });
    cards += 1;
  }
  // 부탁
  for (const c of COMMS) {
    const s = g.comms[c];
    if (s.favorCool > 0) { s.favorCool -= 1; continue; }
    if (cards < 2 && s.rel >= 15 && !s.debt && !g.cards.some(x => x.kind === 'favor') && rnd(g) < 0.3) {
      addCard(g, { kind: 'favor', comm: c });
      s.favorCool = 4;
      cards += 1;
    }
  }
  // 선동
  for (const c of COMMS) {
    const s = g.comms[c];
    if (s.agitateCool > 0) { s.agitateCool -= 1; continue; }
    if (s.rel <= -15 && rnd(g) < 0.25) {
      g.tension = clamp(g.tension + 3, 0, 100);
      const n = COMMS[(COMMS.indexOf(c) + 1) % COMMS.length];
      g.comms[n].rel = clamp(g.comms[n].rel - 3, -100, 100);
      s.agitateCool = 3;
      journal(g, `밤중에 ${COMM_NAME[c]}에서 수상한 모임이 있었다.`, 'dark');
    }
  }
  // 안건 올리기: 다음 구간이 회기면 한 집단이 안건을 낸다.
  if (isSessionSeg(g.seg + 1)) {
    const saved = g.session;
    g.session += 1; // 다음 회기 기준으로 열린 안건을 본다.
    // AI는 법 안건만 낸다. 법이 아닌 안건은 저마다 나오는 곳이 있다(motions.ts).
    const options = agendaOptions(g).options.filter(isLawAgenda);
    g.session = saved;
    const best = aiAgendaPick(g, options);
    if (best) {
      const { c, idx } = best;
      g.proposals = [{ ...options[idx], by: c }];
      journal(g, `${g.comms[c].leader.name}(${COMM_NAME[c]})이(가) 다음 회기 안건을 냈다: ${agendaTitle(options[idx])}.`);
    }
  }
}

/** 신임과 긴장(브리프 1.4, 1.5). */
function meters(g: Game): void {
  const seatMap = seats(g);
  const avg = COMMS.reduce((sum, c) => sum + g.comms[c].rel * seatMap[c], 0) / 100;
  g.trust = clamp(g.trust + clamp(avg / 40, -2.5, 2.5), 0, 100);
  let inc = 0;
  for (const c of COMMS) {
    const s = g.comms[c];
    if (s.rel <= -40) inc += c === 'tail' ? 3 : 2;
    else if (s.rel <= -15) inc += 1;
    const [w, r] = situation(g, c);
    if (w <= 25 || r <= 25) inc += 2;
  }
  if (g.food <= 0) inc += 8;
  inc += lawSum(g, 'tensionAdd');
  const cast = domesticBroadcast(g); // S1c 내정 훅: R2 나 열차 방송
  g.fear = clamp(g.fear + lawSum(g, 'fearAdd') + cast.fear, 0, 100);
  if (inc <= 0) g.tension -= 2;
  else g.tension += Math.max(0, inc - cast.tensionCut) * (1 - g.fear / 200);
  g.fear = clamp(g.fear - 1, 0, 100);
  g.tension = clamp(g.tension, 0, 100);
}

function checkEnd(g: Game): void {
  if (g.coal <= 0) {
    if (!g.emergencyUsed) {
      g.emergencyUsed = true;
      g.coal += 15;
      g.tension = clamp(g.tension + 10, 0, 100);
      journal(g, '석탄이 바닥났다. 가구와 책, 빈 객차 판자를 뜯어 보일러에 넣었다(석탄 +15).', 'dark');
    } else {
      return finish(g, 'stranded');
    }
  }
  if (g.food < 0) g.food = 0;
  // S1b 계엄 중엔 신임 대신 경비대의 충성을 쥔다. 신임 위기로 축출되지 않는다(5.3).
  const martial = !!g.dark?.martial;
  if (!martial && g.trust <= 0 && g.trustCrisis === null) {
    g.trustCrisis = g.seg + 3;
    addCard(g, { kind: 'trust_crisis' });
    journal(g, '신임이 바닥났다. 3구간 안에 25까지 되돌려야 한다.', 'bad');
  } else if (!martial && g.trustCrisis !== null) {
    if (g.trust >= 25) {
      g.trustCrisis = null;
      journal(g, '불신임의 말이 잦아들었다.', 'good');
    } else if (g.seg >= g.trustCrisis) {
      return finish(g, 'ousted');
    }
  }
  if (g.tension >= 60 && !g.tensionWarned) {
    g.tensionWarned = true;
    addCard(g, { kind: 'info', who: '긴장 경고', text: '칸 사이 문마다 사람이 서 있다. 긴장이 100에 닿으면 마지막 기회가 온다.' });
  }
  if (g.tension >= 100) {
    if (g.tensionCrisisUsed < 2) addCard(g, { kind: 'tension_crisis', comm: 'tail' });
    else return finish(g, 'revolt');
  }
}

END_LINK.finish = (g, end) => finish(g, end);
function finish(g: Game, end: Game['end']): void {
  // 먼저 난 끝이 남는다. 한 정산 안에선 쿠데타(darkSettle) → 좌초 → 축출 → 반란 순으로 판정하고, 완주는 다음 구간으로 넘어갈 때다.
  if (g.phase === 'end') return;
  g.end = end;
  g.phase = 'end';
  const text = { complete: '라이프치히 중앙역에 닿았다.', stranded: '석탄이 다 떨어졌다. 열차가 섰다.', ousted: '의회가 열차장을 끌어내렸다.', revolt: '반란이 일어났다.', coup: '경비대장이 열차를 잡았다. 열차장은 창고칸에 앉아 있다.' }[end ?? 'complete'];
  journal(g, text, end === 'complete' ? 'good' : 'bad');
  for (const line of raisedLines(g)) journal(g, line);
  darkFinish(g);
}

function nextSegment(g: Game): void {
  if (g.seg >= P.segments) {
    // 라이프치히 도착: 먼저 누가 내리는지 고르고(hub.ts), 다 고르면 판을 닫는다.
    if (!g.hub?.plan) {
      arriveHub(g);
      if (g.cards.length > 0) return;
    }
    return finish(g, 'complete');
  }
  g.seg += 1;
  g.stop = null;
  if (g.decreeLeft > 0) {
    g.decreeLeft -= 1;
    // S1b 판이면 대권이 끝나는 카드에서 고른 길(돌려준다·묻는다·연장한다)을 따른다. 아니면 S1a 그대로.
    if (g.decreeLeft === 0 && !darkPowersEnd(g)) endEmergencyPowers(g);
  }
  g.phase = 'prep';
  applyFloors(g);
  hubOmenTick(g); // 라이프치히 두 구간 전: 짐 싸는 징후
  darkPrep(g); // S1b 훅: 단서, 불씨가 오를지(임박 징후)
  if (g.autoLevers && !autoLeverStatus(g).ok) {
    g.autoLevers = false;
    g.autoDropped = true;
    const rc = COMM_NAME[rationComm(g)];
    addCard(g, { kind: 'info', who: '배급장이 장부를 내려놓았다', text: `${rc}의 지지가 떨어지자 배급장이 레버에서 손을 뗐다. 칸마다 레버를 다시 열차장이 잡는다.` });
  }
  if (g.autoLevers) {
    const changes = autoLevers(g);
    if (changes.length > 0) journal(g, `배급장이 레버를 움직였다: ${changes.join(', ')}.`);
  }
  // 열기 1 이상의 항의를 알린다(기관실은 파업으로 따로).
  for (const c of COMMS) {
    const s = g.comms[c];
    if (c !== 'engine' && s.fervor >= 1 && s.rel <= -40) journal(g, `${COMM_NAME[c]}: ${PROTEST[c]}.`, 'bad');
  }
}

export function relStage(g: Game, c: Comm): string {
  return stageOf(g.comms[c].rel).name;
}

/** 불만·지지 띠: 관계 단계를 의석으로 곱해 보여 준다(브리프 1.1). */
export function standings(g: Game): { unrest: number; neutral: number; support: number; byComm: { c: Comm; seats: number; side: -1 | 0 | 1 }[] } {
  const seatMap = seats(g);
  let unrest = 0;
  let neutral = 0;
  let support = 0;
  const byComm = COMMS.map(c => {
    const rel = g.comms[c].rel;
    const side: -1 | 0 | 1 = rel >= 15 ? 1 : rel <= -15 ? -1 : 0;
    if (side > 0) support += seatMap[c]; else if (side < 0) unrest += seatMap[c]; else neutral += seatMap[c];
    return { c, seats: seatMap[c], side };
  });
  return { unrest, neutral, support, byComm };
}
