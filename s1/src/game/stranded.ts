// 멈춘 열차(구현명세 가, 결정 034·035·037). 석탄이 0이 되면 판이 끝나지 않고 선다. 정산은 turn.ts가 부르고, 이 파일은 상태와 셈만 쥔다.
// 수동차 원정(startTrip~returnTrip)도 여기서 돈다. 카드 보기는 stranded_cards.ts가 그린다(turn.ts를 못 부르는 자리라 import 순환을 피한다).
import { COMMS, COMM_NAME, P } from './data';
import type { Comm } from './data';
import { onDeath } from './death';
import { techUsable } from './domestic/state';
import { bump, bumpRel, put } from './ledger';
import { addCard, clamp, END_LINK, isGone, journal, PROFILES, rnd, supportShare } from './state';
import type { Game, StrandedState, TripState } from './state';
import { addContentCard } from './content';
import { josa } from './josa';

/** 멈춘 열차 사건. 서는 턴마다 하나씩, 이 순서로 뜬다(조건이 안 맞으면 건너뛰고 나중에). */
export const STRANDED_EVENTS = ['ev_str_lamp', 'ev_str_snow', 'ev_str_promise', 'ev_str_half_bowl'] as const;
/** 멈춘 열차가 직접 그리는 카드 종류(stranded_cards.ts). 닿음 검사와 예산표가 읽는다. */
export const STRANDED_CARD_KINDS = ['trip_depart', 'trip_return', 'trip_lost', 'trip_extend'] as const;

const flagsOf = (g: Game) => (g.contentFlags ??= {});

/** 이 구간의 길이(km). 노선 자료에 없으면 기본값. */
export function segKmOf(g: Game, seg = g.seg): number {
  return g.route?.find(r => r.seg === seg)?.km ?? P.segKmDefault;
}

/** 출발역에서 석탄이 다하는 지점(km). 구간 길이 × 남은 석탄 / 드는 석탄, 1km 이상 구간 끝 전까지로 자른다. */
export function stallKm(segKm: number, coalBefore: number, need: number): number {
  if (need <= 0) return Math.max(1, segKm - 1);
  return Math.min(Math.max(1, segKm - 1), Math.max(1, Math.floor(segKm * Math.max(0, coalBefore) / need)));
}

/** 처음 석탄이 0이 된 정산에서 부른다. coalBefore는 이 정산 전 석탄, need는 이 구간에 든 석탄이다. */
export function enterStranded(g: Game, coalBefore: number, need: number): void {
  put(g, 'coal', 0, 'short');
  const segKm = segKmOf(g);
  const atKm = stallKm(segKm, coalBefore, need);
  const st: StrandedState = {
    since: g.seg, turns: 0, segKm, atKm, toNextKm: segKm - atKm, seen: [],
    trip: null, captainAway: false, deputy: null, lostTrips: 0, snow: null, lamp: false, burned: Math.max(0, coalBefore),
  };
  g.stranded = st;
  flagsOf(g).stranded = true;
  journal(g, `불이 꺼졌다. 열차가 ${atKm}km 지점에서 섰다. 다음 역까지 ${st.toNextKm}km. 창마다 입김이 서린다.`, 'dark');
}

// ---- 수동차 원정 ----
const goTurnsOf = (distKm: number) => Math.max(1, Math.ceil(distKm / P.tripGoKm));
const backTurnsOf = (distKm: number, lamp: boolean) => Math.max(1, Math.ceil(distKm / P.tripBackKm) - (lamp ? 1 : 0));
const totalOf = (t: Pick<TripState, 'goTurns' | 'searchTurns' | 'backTurns'>) => t.goTurns + t.searchTurns + t.backTurns;

/** JSON 사건이 남긴 표식(등불·눈)을 상태로 옮긴다. 등불은 오는 길을 한 턴 줄인다. 여러 번 불러도 같다. */
function syncFlags(g: Game, st: StrandedState): void {
  const flags = flagsOf(g);
  if (flags.stranded_lamp === true) {
    flags.stranded_lamp = false;
    st.lamp = true;
    const t = st.trip;
    if (t && t.phase !== 'back') {
      t.backTurns = backTurnsOf(t.distKm, true);
      if (t.extends === 0) t.plannedTurns = totalOf(t);
    }
  }
  const snow = flags.stranded_snow;
  if (snow === 'all' || snow === 'guard' || snow === 'none') {
    flags.stranded_snow = false;
    st.snow = snow;
  }
}

/** 지원자로 나설 수 있는 사람: 일할 나이의 산 사람, 앓는 대표와 지금 대표는 빼고. */
function volunteerPool(g: Game, c: Comm): string[] {
  const sickRep = g.comms[c].sick?.rep.name;
  const rep = g.comms[c].leader.name;
  const alive = PROFILES.filter(p => p.community === c && !isGone(g, p.name) && p.age >= 16 && p.age <= 65 && p.name !== sickRep && p.name !== rep).map(p => p.name);
  if (alive.length === 0) return [];
  const start = (g.seg * 7) % alive.length;
  return alive.map((_, i) => alive[(start + i) % alive.length]);
}

const byRel = (g: Game): Comm[] => [...COMMS].sort((a, b) => g.comms[b].rel - g.comms[a].rel);

/** 열차장이 없는 동안 열차를 맡을 칸: 관계가 가장 높은 칸. */
export function deputyOf(g: Game): Comm {
  return byRel(g)[0];
}

export interface TripPlan {
  comm: Comm; names: string[]; size: number; leaderGoes: boolean; forced: boolean;
  distKm: number; goTurns: number; searchTurns: number; backTurns: number; total: number; food: number;
}

/** 수동차 원정을 짠다. crew는 지지 문턱(P.supportLine)을 넘고 관계 15 이상인 칸이 넷을 내야 하고, captain은 열차장이 타고 가장 가까운 칸이 셋을 낸다. */
export function tripPlan(g: Game, mode: 'crew' | 'captain'): TripPlan | null {
  const st = g.stranded;
  if (!st) return null;
  syncFlags(g, st);
  const leaderGoes = mode === 'captain';
  const forced = leaderGoes && supportShare(g) < P.supportLine;
  const need = leaderGoes ? P.tripSize - 1 : P.tripSize;
  const pools = byRel(g).filter(c => leaderGoes || g.comms[c].rel >= 15).map(c => ({ c, pool: volunteerPool(g, c) })).filter(x => x.pool.length > 0);
  if (pools.length === 0) return null;
  const pick = pools.find(x => x.pool.length >= need) ?? pools.reduce((a, b) => (b.pool.length > a.pool.length ? b : a));
  if (!leaderGoes && pick.pool.length < need) return null;
  const names = pick.pool.slice(0, need);
  const size = names.length + (leaderGoes ? 1 : 0);
  const distKm = st.toNextKm;
  const goTurns = goTurnsOf(distKm);
  const backTurns = backTurnsOf(distKm, st.lamp);
  const total = goTurns + P.tripSearchTurns + backTurns;
  return {
    comm: pick.c, names, size, leaderGoes, forced, distKm, goTurns, searchTurns: P.tripSearchTurns, backTurns, total,
    food: Math.ceil(size * total * P.tripFoodPer),
  };
}

/** 지지가 문턱을 넘었나(수색대를 보낼 수 있나). */
export const crewAllowed = (g: Game): boolean => supportShare(g) >= P.supportLine;

/** 원정을 고르는 자리에 보이는 문턱 글(결정 037). 위 띠의 여론 ±N과 다른 셈이라 숫자와 까닭을 따로 보인다. */
export function supportLineText(g: Game): string {
  const pct = Math.round(supportShare(g) * 100);
  const line = Math.round(P.supportLine * 100);
  return crewAllowed(g)
    ? `지지하는 칸의 사람 ${pct}%. ${line}%를 넘어 수색대를 보낼 수 있다.`
    : `지지하는 칸의 사람 ${pct}%. ${line}%가 안 돼 열차장이 직접 간다.`;
}

/** 원정을 보낸다. 식량은 있는 만큼만 가져가고 모자란 몫은 foodShort에 남긴다. */
export function startTrip(g: Game, mode: 'crew' | 'captain'): boolean {
  const st = g.stranded;
  if (!st || st.trip) return false;
  const plan = tripPlan(g, mode);
  if (!plan) return false;
  const take = Math.max(0, Math.min(plan.food, Math.floor(g.food)));
  bump(g, 'food', -take, 'cart');
  st.trip = {
    leaderGoes: plan.leaderGoes, forced: plan.forced, comm: plan.comm, names: plan.names, size: plan.size,
    distKm: plan.distKm, extends: 0, goTurns: plan.goTurns, searchTurns: plan.searchTurns, backTurns: plan.backTurns,
    plannedTurns: plan.total, turn: 0, phase: 'go', posKm: 0, baseFood: take, foodShort: plan.food - take, foodOwed: 0,
    outcome: null, known: false, promise: null,
  };
  flagsOf(g).trip_out = true;
  if (plan.leaderGoes) {
    st.captainAway = true;
    st.deputy = deputyOf(g);
    g.councilOwed = false;
    journal(g, `열차장이 수동차에 올랐다. ${COMM_NAME[st.deputy]}${josa(COMM_NAME[st.deputy], '이/가')} 열차를 맡는다.`, 'dark');
  } else {
    journal(g, `${COMM_NAME[plan.comm]}에서 ${plan.names.length}명이 수동차에 올랐다. 자루 둘과 나무 상자 하나를 싣는다.`, 'dark');
  }
  return true;
}

/** 돌아올 사람에게 약속한 사치품은 JSON 사건이 표식으로 남긴다. 다음 정산에서 읽어 칸 관계에 건다. */
function takePromise(g: Game, t: TripState): void {
  const flags = flagsOf(g);
  const pr = flags.stranded_promise;
  if (pr !== 'yes' && pr !== 'no') return;
  flags.stranded_promise = false;
  t.promise = pr;
  bumpRel(g, t.comm, pr === 'yes' ? P.promiseRel : P.promiseSkipRel, 'cart');
}

/** 어느 역에서 무슨 일이 났는지. 열차는 무전이 있을 때만 바로 안다. */
function rollStation(g: Game, t: TripState): void {
  const short = Math.min(P.tripShortMax, Math.floor(t.foodShort / 2) * P.tripShortLost);
  const lost = Math.min(0.9, P.tripLostFirst + P.tripLostStep * t.extends + short);
  const ext = t.extends === 0 ? P.tripExtendFirst : t.extends === 1 ? P.tripExtendNext : 0;
  const r = rnd(g);
  if (r < lost) { t.outcome = 'lost'; return; }
  if (r < lost + ext) {
    t.extends += 1;
    t.distKm += P.extendKm;
    t.goTurns = goTurnsOf(t.distKm);
    t.backTurns = backTurnsOf(t.distKm, !!g.stranded?.lamp);
    t.foodOwed += Math.ceil(t.baseFood * (P.tripFoodMult ** t.extends - P.tripFoodMult ** (t.extends - 1)));
    return;
  }
  t.outcome = 'coal';
}

/** 열차가 이어 감을 알았다(무전이 바로, 아니면 돌아온 턴에). 곱절 몫의 식량을 낸다. */
function learnExtend(g: Game, t: TripState): number {
  const owed = t.foodOwed;
  if (owed > 0) { bump(g, 'food', -Math.min(owed, Math.max(0, g.food)), 'cart'); t.foodOwed = 0; }
  t.known = true;
  return owed;
}

const posOf = (t: TripState): number => {
  if (t.turn <= t.goTurns) return Math.min(t.distKm, t.turn * P.tripGoKm);
  if (t.turn <= t.goTurns + t.searchTurns) return t.distKm;
  return Math.max(0, t.distKm - (t.turn - t.goTurns - t.searchTurns) * P.tripBackKm);
};

/** 못 돌아온 원정을 열차가 알았다. 사람이 죽고, 열차장이 탔으면 판이 끝난다. */
function resolveLost(g: Game, st: StrandedState, t: TripState): void {
  onDeath(g, t.comm, t.names, 'other');
  bumpRel(g, t.comm, P.tripLostRel, 'cart');
  bump(g, 'tension', P.tripLostTension, 'cart');
  g.fear = clamp(g.fear + P.tripLostFear, 0, 100);
  st.lostTrips += 1;
  st.trip = null;
  flagsOf(g).trip_out = false;
  g.councilOwed = false;
  journal(g, `수동차는 돌아오지 않았다. ${t.names.length > 0 ? `${t.names.join(', ')}의 이름을 일지에 옮겼다.` : ''}`.trim(), 'bad');
  if (t.leaderGoes) {
    st.captainAway = false;
    END_LINK.finish(g, 'lost_captain');
    return;
  }
  addCard(g, { kind: 'trip_lost', comm: t.comm, who: t.names.join(','), n: t.turn });
}

/** 선 채로 지난 정산마다 원정을 한 턴 굴린다. settle이 다른 죽음 틱이 끝난 뒤에 부른다(열차장이 못 돌아와 판이 끝나도 그 뒤 틱이 끝난 판 위에서 돌지 않게). */
export function tripTick(g: Game): void {
  const st = g.stranded;
  const t = st?.trip;
  if (!st || !t) return;
  takePromise(g, t);
  t.turn += 1;
  if (t.turn === t.goTurns && t.outcome === null) {
    rollStation(g, t);
    if (techUsable(g, 'r3')) {
      if (t.outcome === 'lost') { resolveLost(g, st, t); return; }
      if (t.extends > 0 && !t.known) {
        const owed = learnExtend(g, t);
        journal(g, '무전이 짧게 왔다. 역에 석탄이 없다. 15km를 더 간다.', 'dark');
        addCard(g, { kind: 'trip_extend', comm: t.comm, n: owed });
      }
    }
  }
  t.phase = t.turn <= t.goTurns ? 'go' : t.turn <= t.goTurns + t.searchTurns ? 'search' : 'back';
  t.posKm = posOf(t);
  const total = totalOf(t);
  if (t.outcome === 'coal' && t.turn >= total) {
    if (t.extends > 0 && !t.known) learnExtend(g, t);
    addCard(g, { kind: 'trip_return', comm: t.comm, n: t.turn });
    return;
  }
  if (t.outcome === 'lost' && t.turn > total) { resolveLost(g, st, t); return; }
  if (t.turn === 1) journal(g, '수동차가 선로 끝으로 사라졌다. 열차는 조용하다.', 'dark');
  else if (t.turn < t.plannedTurns) journal(g, `수동차가 보이지 않는다. ${t.turn}턴째. 식량 ${Math.round(g.food)}.`);
  else if (t.turn === t.plannedTurns) journal(g, '오늘쯤 돌아올 때가 됐다. 꼬리칸이 창에 붙어 있다.', 'dark');
  else journal(g, '돌아올 때가 지났다. 아무도 먼저 말을 꺼내지 않는다.', 'bad');
}

/** 정산이 칸마다 자리비움을 0으로 되돌린 뒤, 나가 있는 지원자를 다시 센다. */
export function reapplyAway(g: Game): void {
  const t = g.stranded?.trip;
  if (t) g.comms[t.comm].away += t.names.length;
}

/** 석탄을 들고 돌아와 불을 넣었다. 열차가 다시 달린다. */
export function returnTrip(g: Game): void {
  const st = g.stranded;
  const t = st?.trip;
  if (!st || !t) return;
  if (t.leaderGoes && !t.forced) journal(g, '열차장이 석탄을 가져왔다. 아무도 박수를 치지 않았다.', 'dark');
  else journal(g, `수동차가 돌아왔다. 석탄 ${P.tripCoal}을 부었다.`, 'good');
  resumeRun(g);
}

/** 다시 달린다. 원정이 석탄을 들고 돌아온 때만 부른다(목재·가구로 버티는 것은 달리는 것이 아니다). */
export function resumeRun(g: Game): void {
  const st = g.stranded;
  if (!st) return;
  const flags = flagsOf(g);
  g.stranded = null;
  flags.stranded = false;
  flags.trip_out = false;
  if (st.snow === 'none') {
    bump(g, 'coal', -2, 'stranded');
    journal(g, '선로에 쌓인 눈을 치우지 않았다. 쟁기가 눈을 밀며 석탄 2를 더 먹는다.', 'bad');
  }
  if (g.seg > P.segments) g.seg = P.segments;
}

/** 선 열차의 출발 단계. 이동 사건 대신 멈춘 열차 사건 하나를 올린다. 원정이 안 나가 있으면 출발 카드도 올린다. */
export function strandedDepart(g: Game): void {
  const st = g.stranded;
  if (!st) return;
  g.lostSegments += 1;
  // 식량이 30 아래면 「반 그릇」을 앞당긴다.
  const order = g.food <= 30 ? ['ev_str_half_bowl', ...STRANDED_EVENTS.filter(id => id !== 'ev_str_half_bowl')] : [...STRANDED_EVENTS];
  for (const id of order) {
    if (st.seen.includes(id)) continue;
    if (addContentCard(g, id, false, true)) { st.seen.push(id); break; }
  }
  if (!st.trip) addCard(g, { kind: 'trip_depart', comm: 'tail' });
  g.phase = 'travel';
}

/** 선 채로 한 정산을 마칠 때(settle). 이미 서 있던 열차에만 부른다. */
export function strandedSettle(g: Game): void {
  const st = g.stranded;
  if (!st) return;
  st.turns += 1;
  const flags = flagsOf(g);
  syncFlags(g, st);
  // 「레버만 내린다」: 표식을 읽어 모든 칸 배급 레버를 1로 내린다(JSON은 레버를 못 만진다).
  if (flags.ration_down_asked) {
    flags.ration_down_asked = false;
    for (const c of COMMS) g.comms[c].ration = Math.min(g.comms[c].ration, 1);
    journal(g, '솥 앞 줄이 짧아졌다. 배급 레버를 1로 내렸다.', 'bad');
  }
  // 온기는 난로가 지킨다. 석탄이 1 이상이면 한 덩이를 태우고 이번 턴 하락을 건너뛴다(석탄 1로는 달리지 못한다, P.coalRun 6).
  if (g.coal >= 1) {
    put(g, 'coal', g.coal - 1, 'stranded');
  } else {
    for (const c of COMMS as readonly Comm[]) {
      const base = g.comms[c].base;
      base[0] = Math.min(base[0], Math.max(P.strandedWarmFloor, base[0] - P.strandedWarmDrop));
    }
  }
}
