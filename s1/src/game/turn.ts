import { addCard } from './state';
import { drawTravelEvent } from './cards';
import { onDeath } from './death';
import { BRIBE_EXPOSE, COMMS, COMM_NAME, FETCH_WANT, LAWS, LOOT_KEYS, LOOT_NAME, P, PLACES, PROTEST, STAY } from './data';
import type { Comm, LootKey, StayId } from './data';
import { agendaOptions, agendaTitle, exposeBribe, offend, openCouncil, stance } from './politics';
import {
  addSecret, clamp, isSessionSeg, journal, lawActive, PROFILES, rnd, seats, situation, stageOf,
} from './state';
import type { Game, StopResult } from './state';

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
      if (council && council.options.length > 0 && !council.result) return { label: '표결', ok: false, why: '표결을 한다' };
      return { label: '정산으로', ok: true };
    }
    case 'settle': return { label: g.seg >= P.segments ? '도착' : '다음 구간', ok: true };
    default: return { label: '', ok: false };
  }
}

/** 주 단추. 단계를 하나 넘긴다. */
export function advance(g: Game): void {
  if (!primaryAction(g).ok) return;
  switch (g.phase) {
    case 'prep': return depart(g);
    case 'travel': return g.inStrike ? afterStop(g) : arriveStop(g);
    case 'stop': return afterStop(g);
    case 'council': return settle(g);
    case 'settle': return nextSegment(g);
    default: return;
  }
}

// ---- 출발 전 운영 ----
export function setLever(g: Game, c: Comm, which: 'heat' | 'ration', value: number): void {
  const floor = which === 'heat' ? lawFloor(g, 'heatFloor') : lawFloor(g, 'rationFloor');
  g.comms[c][which] = clamp(Math.round(value), floor, 4);
}

export function lawFloor(g: Game, key: 'heatFloor' | 'rationFloor'): number {
  let floor = 0;
  for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) floor = Math.max(floor, LAWS[law].res[key] ?? 0);
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
    if (r > 65 && g.food < 40 && s.ration > Math.max(1, rf)) { s.ration -= 1; changes.push(`${COMM_NAME[c]} 배급 −1`); }
  }
  return changes;
}

export function setAutoLevers(g: Game, on: boolean): void {
  g.autoLevers = on;
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
  for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) sum += LAWS[law].res[key] ?? 0;
  return sum;
}
function lawMult(g: Game, key: 'heatMult' | 'haulMult' | 'medMult' | 'deathMult'): number {
  let m = 1;
  for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) m *= LAWS[law].res[key] ?? 1;
  return m;
}

/** 이번 구간에 들 석탄과 식량(정차 제외). 화면의 예고에 쓴다. */
export function forecast(g: Game): { coal: number; food: number } {
  const coal = heatCost(g) * lawMult(g, 'heatMult') + lawSum(g, 'coalAdd') + (g.inStrike ? P.coalStrike : P.coalRun) - (g.forcedRun ? 2 : 0);
  const food = foodCost(g) + lawSum(g, 'foodAdd');
  return { coal, food };
}

function depart(g: Game): void {
  if (g.seg % P.winterEvery === 0) {
    for (const c of COMMS) g.comms[c].base[0] -= P.winterDrop;
    journal(g, '추위가 한 단계 깊어졌다. 모든 칸 온기 −5.', 'bad');
  }
  const engine = g.comms.engine;
  const striking = engine.fervor >= 1 && engine.rel <= P.strikeRel;
  if (striking && lawActive(g, 'strike_ban')) {
    engine.fervor = 0;
    engine.rel = clamp(engine.rel - 10, -100, 100);
    g.fear = clamp(g.fear + 10, 0, 100);
    journal(g, '파업 금지법에 따라 경비대가 기관실 문을 열었다. 화부들이 불 앞으로 끌려갔다.', 'dark');
  } else if (striking) {
    if (!g.inStrike) g.strikes += 1;
    g.inStrike = true;
    g.lostSegments += 1;
    addCard(g, { kind: 'strike', comm: 'engine' });
    journal(g, '기관실이 파업했다. 열차가 섰다.', 'bad');
    g.phase = 'travel';
    return;
  }
  g.inStrike = false;
  const event = drawTravelEvent(g);
  if (event) addCard(g, { kind: 'travel', text: event });
  g.phase = 'travel';
}

// ---- 정차(S1 기획서 7장, 필드 결정 카드) ----
export function crewNames(g: Game, c: Comm, size: number): string[] {
  const alive = PROFILES.filter(p => p.community === c && !g.deaths.includes(p.name) && p.age >= 16 && p.age <= 65);
  if (alive.length === 0) return [];
  const start = (g.seg * 7) % alive.length;
  return Array.from({ length: Math.min(size, alive.length) }, (_, i) => alive[(start + i) % alive.length].name);
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
  g.stop = {
    place: place.id, target: suggestTarget(g, place.loot), stay: 'normal',
    crewComm: tail ? 'guard' : 'tail', crewSize: 4, done: false, result: null,
  };
  g.phase = 'stop';
}

export function setStop(g: Game, patch: Partial<{ target: LootKey; stay: StayId; crewComm: Comm; crewSize: number }>): void {
  if (!g.stop || g.stop.done) return;
  Object.assign(g.stop, patch);
  g.stop.crewSize = clamp(g.stop.crewSize, 2, 8);
}

export function resolveStop(g: Game, go: boolean): StopResult | null {
  const stop = g.stop;
  if (!stop || stop.done) return null;
  const place = PLACES.find(p => p.id === stop.place) ?? PLACES[0];
  stop.done = true;
  if (!go || !stop.target) {
    stop.result = { passed: true, gains: {}, injured: [], dead: [], notes: ['정차하지 않고 지나쳤다.'] };
    journal(g, `${place.name}을(를) 지나쳤다.`);
    checkStopPromises(g, null, {});
    return stop.result;
  }
  const stay = STAY[stop.stay];
  g.coal -= stay.coal;
  const weights = Object.fromEntries(LOOT_KEYS.map(k => [k, place.loot[k] * (k === stop.target ? P.targetBoost : 1)])) as Record<LootKey, number>;
  const tot = LOOT_KEYS.reduce((sum, k) => sum + weights[k], 0);
  let haul = P.haulTotal * (0.7 + rnd(g) * 0.6) * stay.mult * (0.7 + 0.075 * stop.crewSize) * lawMult(g, 'haulMult');
  const notes: string[] = [];
  const tail = g.comms.tail;
  if (tail.fervor >= 1 && tail.rel <= -40) { haul *= 0.7; notes.push('꼬리칸이 작업을 거부했다(−30%).'); }
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
  // 위험: 장소 위험도, 체류, 인원, 던진 시신이 키운 무리, 경비대의 경계 거부와 호위.
  const guard = g.comms.guard;
  const guardMult = guard.fervor >= 1 && guard.rel <= -40 ? 1.5 : 1;
  if (guardMult > 1) notes.push('경비대가 경계를 거부했다.');
  const horde = Math.min(1.5, 1 + P.thrownHorde * g.thrown);
  const escort = g.guardEscort ? 0.5 : 1;
  const lam = place.risk * P.injuryRate * guardMult * horde * stay.risk * (stop.crewSize / 4) * escort;
  const names = crewNames(g, stop.crewComm, stop.crewSize);
  const hurt: string[] = [];
  for (let i = 0; i < 6; i += 1) if (rnd(g) < lam / 6 && hurt.length < names.length) hurt.push(names[hurt.length]);
  const dead: string[] = [];
  if (rnd(g) < place.risk * P.deathRate * guardMult * horde * lawMult(g, 'deathMult') * stay.risk) {
    const who = names[names.length - 1];
    if (who) dead.push(who);
  }
  const injuredOnly = hurt.filter(n => !dead.includes(n));
  g.injured += injuredOnly.length;
  if (dead.length > 0) onDeath(g, stop.crewComm, dead);
  g.comms[stop.crewComm].away = stop.crewSize - dead.length;
  stop.result = { passed: false, gains, injured: injuredOnly, dead, notes };
  const got = (Object.keys(gains) as LootKey[]).map(k => `${LOOT_NAME[k]} ${gains[k]}`).join(', ');
  journal(g, `${place.name}에 ${stay.name} 머물렀다(${COMM_NAME[stop.crewComm]} ${stop.crewSize}명). ${got || '빈손'}.${injuredOnly.length ? ` 부상 ${injuredOnly.length}.` : ''}`);
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

function keepPromise(g: Game, c: Comm): void {
  const s = g.comms[c];
  const label = s.promise?.label ?? '';
  s.promise = null;
  g.trust = clamp(g.trust + 4, 0, 100);
  s.rel = clamp(s.rel + 5, -100, 100);
  if (s.grudge === 1) s.grudge = 0;
  g.stats.promisesKept += 1;
  journal(g, `${COMM_NAME[c]}과(와)의 약속을 지켰다: ${label}.`, 'good');
}

function breakPromise(g: Game, c: Comm): void {
  const s = g.comms[c];
  const label = s.promise?.label ?? '';
  s.promise = null;
  g.trust = clamp(g.trust - (seats(g)[c] >= 30 ? 12 : 8), 0, 100);
  s.rel = clamp(s.rel - 20, -100, 100);
  s.fervor = Math.min(3, s.fervor + 1);
  g.tension = clamp(g.tension + 3, 0, 100);
  g.stats.promisesBroken += 1;
  offend(g, c);
  journal(g, `${COMM_NAME[c]}과(와)의 약속을 어겼다: ${label}.`, 'bad');
}

function afterStop(g: Game): void {
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
  g.forcedRun = false;
  g.guardEscort = false;
  medicineTick(g, notes);
  drift(g);
  checkDuePromises(g);
  if (g.council) bribeDetection(g);
  leashTick(g);
  aiLeaders(g);
  meters(g);
  for (const c of COMMS) g.comms[c].away = 0;
  checkEnd(g);
  g.lastSettle = {
    coal: g.coal - before.coal, food: g.food - before.food, med: g.med - before.med,
    trust: g.trust - before.trust, tension: g.tension - before.tension,
    rel: Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel - before.rel[c]])) as Record<Comm, number>, notes,
  };
  if (g.phase !== 'end') g.phase = 'settle';
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
      for (const law of Object.keys(g.passed) as (keyof typeof LAWS)[]) heal = Math.max(heal, LAWS[law].res.heal ?? 0);
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
      const names = PROFILES.filter(p => p.community === 'tail' && !g.deaths.includes(p.name)).slice(0, dead).map(p => p.name);
      onDeath(g, 'tail', names);
    }
    notes.push('의약품이 떨어졌다.');
  }
  if (g.stored > 0 && rnd(g) < Math.min(0.3, P.storeRisk * g.stored)) {
    g.injured += 2;
    g.tension = clamp(g.tension + 8, 0, 100);
    g.stored = 0;
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
    if (deal.tool === 'bribe' && deal.label !== '뇌물을 거절당함') {
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
    const { options } = agendaOptions(g);
    g.session = saved;
    let best: { c: Comm; idx: number; score: number } | null = null;
    for (const c of [...COMMS].sort((a, b) => seats(g)[b] - seats(g)[a])) {
      const s = g.comms[c];
      options.forEach((o, idx) => {
        const own = stance(g, c, o, false).score;
        const hostileRepeal = s.grudge >= 3 && o.repeal;
        const score = own + (hostileRepeal ? 3 : 0);
        if ((own >= 3 || (o.repeal && own >= 2) || hostileRepeal) && (!best || score > best.score)) best = { c, idx, score };
      });
    }
    if (best) {
      const { c, idx } = best as { c: Comm; idx: number };
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
  g.fear = clamp(g.fear + lawSum(g, 'fearAdd'), 0, 100);
  if (inc <= 0) g.tension -= 2;
  else g.tension += inc * (1 - g.fear / 200);
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
  if (g.trust <= 0 && g.trustCrisis === null) {
    g.trustCrisis = g.seg + 3;
    addCard(g, { kind: 'trust_crisis' });
    journal(g, '신임이 바닥났다. 3구간 안에 25까지 되돌려야 한다.', 'bad');
  } else if (g.trustCrisis !== null) {
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

function finish(g: Game, end: Game['end']): void {
  g.end = end;
  g.phase = 'end';
  const text = { complete: '라이프치히 중앙역에 닿았다.', stranded: '석탄이 다 떨어졌다. 열차가 섰다.', ousted: '의회가 열차장을 끌어내렸다.', revolt: '반란이 일어났다.' }[end ?? 'complete'];
  journal(g, text, end === 'complete' ? 'good' : 'bad');
}

function nextSegment(g: Game): void {
  if (g.seg >= P.segments) return finish(g, 'complete');
  g.seg += 1;
  g.stop = null;
  if (g.decreeLeft > 0) g.decreeLeft -= 1;
  g.phase = 'prep';
  applyFloors(g);
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
