import { COMM_NAME, P, PLACES } from './data';
import type { Comm } from './data';
import { crowdLevel } from './crowd';
import { onDeath } from './death';
import { bump } from './ledger';
import { hash } from './omens';
import { addCard, arrivedIn, ARRIVAL_SIT, CREW_BUSY, isGone, journal, situation } from './state';
import type { ArrivalKind, ArrivalsState, Game } from './state';
import { noteInjury } from './wounds';

// 사람이 들어오는 사건(fun/구현명세_사람_들어오는_사건_v1, 결정 352·369). 기본은 꺼져 있다.
// 켜는 길: enableArrivals(g). 꺼진 판은 이 파일의 어떤 함수도 상태를 만들거나 난수를 쓰지 않는다.
// 굴림(뜰지, 무리 크기, 다친 수, 수색대의 운)은 재난처럼 판 씨앗 해시라 난수 흐름(g.rng)을 건드리지 않는다.
// 들어온 사람은 이름 명부(PROFILES)에 넣지 않고 칸 인원(pop)으로만 센다. 몸 상태로 사람을 가르는 갈래는 없다(금지선).
// 받은 사람이 처지에 주는 몫(과밀 +1.5, 배급 −0.8, 온기 −0.5)은 state.ts situation이 arrivedIn으로 읽는다.
// 숫자는 시제품 값(제안)이고 500판으로 다시 잰다. tools/s1c_sim.ts의 --ar=키:값으로 바꿀 수 있다.

export const AR = {
  /** ① 피난민 무리: 정차 결과 뒤 확률, 출발 때 이동 사건 자리 확률 */
  stopP: 0.12, travelP: 0.06,
  /** 이 구간부터 굴린다. 앞의 ①과 이만큼 떨어져야 하고, 한 판에 많아야 cap번 */
  fromSeg: 3, gap: 4, cap: 3,
  /** 무리 크기, 이 구간 뒤로는 lateBonus까지 더 크다 */
  sizeMin: 6, sizeMax: 12, lateSeg: 12, lateBonus: 2,
  /** 가족 묶음 크기, 무리 안의 다친 사람 수 상한 */
  groupMin: 2, groupMax: 4, hurtMax: 2,
  /** ② 수색대가 데려온 가족: 정차 결과 뒤 확률, 그 정차에 정찰을 보냈으면 곱하는 값, 간격, 판 상한 */
  familyP: 0.1, familyScoutMult: 1.5, familyGap: 6, familyCap: 2,
  /** 가족 크기, 가족 안의 다친 사람 수 상한 */
  familyMin: 3, familyMax: 5, familyHurtMax: 1,
  /** 데리러 가는 수색대 인원(②, ①), 못 돌아옴 확률에 곱하는 값(밤길) */
  fetchSize: 3, escortSize: 2, fetchDeathMult: 2,
  /** 꼬리칸 과밀이 이 값 이상이면 남는 가족은 의무진 칸으로 간다 */
  overflowAt: 95,
  /** 받은 구간 정산에 한 명당 한 번 더 빼는 식량(빈속) */
  hunger: 0.3,
  /** 받은 뒤 이 구간 범위 안에 그 칸이 「비좁음」 이상이면 잠자리 다툼 카드가 한 번 온다 */
  quarrelFrom: 2, quarrelTo: 3,
  /** 돌려보냄(법대로 보냄 포함) 갈래의 신임·관계·긴장 값에 곱하는 값, 1이 명세 값(재기에서 줄여 본다) */
  turnCost: 1,
  /** 1이면 돌려보냄·못 감 갈래가 목격자 벌(파견 칸 관계 −5)을 받는다. 0이면 이 사건 카드만 끈다(재기용) */
  witness: 1,
};

/** 이 파일이 올리는 카드 종류(닿음 검사와 예산 등급표가 읽는다) */
export const ARRIVAL_CARD_KINDS = ['arrival', 'family', 'bed_quarrel'] as const;

/** 판에 사람이 들어오는 사건을 켠다. S1a·S1b·S1c 어느 판에든 얹을 수 있다. */
export function enableArrivals(g: Game): void {
  g.arrivals = { n: { arrival: 0, family: 0 }, last: { arrival: -99, family: -99 }, byComm: {}, taken: 0, turned: 0 };
}

export function arrivalsOn(g: Game): boolean {
  return !!g.arrivals;
}

// 데리러 나간 수색대는 돌아올 때까지 작업조와 정찰조에 다시 뽑히지 않는다.
CREW_BUSY.push(g => g.arrivals?.pending?.names ?? []);

/** 판 씨앗으로 만든 0~1 값. salt마다 따로 */
function roll(g: Game, salt: string): number {
  return hash(`${g.seed}|${g.seg}|ar-${salt}`) / 4294967296;
}
function pickInt(g: Game, salt: string, lo: number, hi: number): number {
  return lo + (hash(`${g.seed}|${g.seg}|ar-${salt}`) % (hi - lo + 1));
}

const sum = (xs: readonly number[]): number => xs.reduce((a, b) => a + b, 0);

function ready(g: Game, kind: ArrivalKind): boolean {
  const a = g.arrivals;
  if (!a || a.pending || g.seg < AR.fromSeg) return false;
  if (g.cards.some(c => c.kind === 'arrival' || c.kind === 'family')) return false;
  const gap = kind === 'arrival' ? AR.gap : AR.familyGap;
  const cap = kind === 'arrival' ? AR.cap : AR.familyCap;
  return a.n[kind] < cap && g.seg - a.last[kind] >= gap;
}

/** 「일부」로 태우는 가족 묶음 수: 먼저 닿은 가족부터 무리의 절반 이상이 될 때까지. 무리 전부가 되면 마지막 가족은 남긴다. 기준은 자리 수뿐이다 */
export function someOf(groups: readonly number[]): number {
  const n = sum(groups);
  let s = 0;
  for (let i = 0; i < groups.length; i += 1) {
    s += groups[i];
    if (s * 2 >= n) return s < n ? i + 1 : i;
  }
  return groups.length;
}

/** 무리를 가족 묶음으로 뽑는다(2~4명, 한 명짜리 묶음 없음). 「일부」가 절반 이상 n 미만이 되게 가장 큰 가족을 앞에 세울 때가 있다 */
export function drawGroups(g: Game, salt: string, total: number): number[] {
  const groups: number[] = [];
  let left = total;
  for (let i = 0; left > 0; i += 1) {
    let k = Math.min(left, pickInt(g, `${salt}|g${i}`, AR.groupMin, AR.groupMax));
    if (left - k === 1) k = k < AR.groupMax ? k + 1 : k - 1;
    groups.push(k);
    left -= k;
  }
  const take = sum(groups.slice(0, someOf(groups)));
  if (groups.length > 1 && take * 2 < total) {
    const big = groups.indexOf(Math.max(...groups));
    groups.unshift(...groups.splice(big, 1));
  }
  return groups;
}

/** 다친 사람이 든 가족 묶음 번호(한 사람당 하나) */
function hurtGroups(g: Game, salt: string, groups: readonly number[], max: number): number[] {
  const n = pickInt(g, `${salt}|hurt`, 0, max);
  return Array.from({ length: n }, (_, i) => hash(`${g.seed}|${g.seg}|ar-${salt}|h${i}`) % groups.length);
}

/** 정찰 위험 식(turn.ts sendScouts와 같은 꼴): 장소 위험 × 바깥 기척 × 무리 × 경비대 거부. 바깥이 고요하면 0. 정차가 없으면(선로 위) 장소 위험 1 */
function dangerNow(g: Game, atStop: boolean): number {
  const stop = atStop ? g.stop : undefined;
  if (stop && (stop.threat ?? 1) <= 0.8) return 0;
  const risk = stop ? (PLACES.find(p => p.id === stop.place) ?? PLACES[0]).risk : 1;
  const guard = g.comms.guard;
  return risk * (stop?.threat ?? 1) * Math.min(1.5, 1 + P.thrownHorde * g.thrown) * (guard.fervor >= 1 && guard.rel <= -40 ? 1.5 : 1);
}

/** 한 사람당 못 돌아옴·크게 다침 확률 */
export function fetchOdds(danger: number): { qd: number; qh: number } {
  return danger <= 0 ? { qd: 0, qh: 0 } : { qd: P.scoutDeath * AR.fetchDeathMult * danger, qh: Math.min(0.5, P.scoutHurt * danger) };
}

/** ① 무리를 굴려 카드를 올린다. where: 정차 결과 뒤인지 이동 중인지. cands: 수색대로 붙일 수 있는 사람(turn.ts가 crewNames로 뽑아 준다) */
function rollArrival(g: Game, where: 'stop' | 'travel', cands: readonly string[], who?: string): boolean {
  const a = g.arrivals!;
  if (!ready(g, 'arrival') || roll(g, `${where}`) >= (where === 'stop' ? AR.stopP : AR.travelP)) return false;
  const total = pickInt(g, 'n', AR.sizeMin, AR.sizeMax) + (g.seg > AR.lateSeg ? pickInt(g, 'late', 0, AR.lateBonus) : 0);
  const groups = drawGroups(g, 'arr', total);
  const hurt = hurtGroups(g, 'arr', groups, AR.hurtMax);
  const known = where === 'stop' && !!g.stop?.scout;
  a.n.arrival += 1;
  a.last.arrival = g.seg;
  addCard(g, {
    kind: 'arrival', n: total, text: where, who,
    vals: { groups: groups.join(','), hurt: hurt.join(','), crew: cands.slice(0, AR.escortSize).join('|'), comm: where === 'stop' ? g.stop?.crewComm ?? 'tail' : 'tail', danger: String(dangerNow(g, where === 'stop')), known: known ? '1' : '0' },
  });
  return true;
}

/** 정차 결과 뒤(turn.ts resolveStop, rescue 굴림 앞). ①이 뜨면 true를 돌려주고 그 정차의 부상자 카드는 건너뛴다. ①이 안 뜨면 ②를 굴린다. 꺼진 판은 아무 일도 안 한다 */
export function arrivalsAfterStop(g: Game, crewComm: Comm, cands: readonly string[], reporter?: string): boolean {
  if (!g.arrivals) return false;
  if (rollArrival(g, 'stop', cands, reporter)) return true;
  const a = g.arrivals;
  if (!reporter || !ready(g, 'family')) return false;
  const p = AR.familyP * (g.stop?.scoutReport ? AR.familyScoutMult : 1);
  if (roll(g, 'family') >= p) return false;
  const size = pickInt(g, 'fam', AR.familyMin, AR.familyMax);
  a.n.family += 1;
  a.last.family = g.seg;
  addCard(g, {
    kind: 'family', comm: crewComm, who: reporter, n: size,
    vals: { hurt: String(pickInt(g, 'famhurt', 0, AR.familyHurtMax)), crew: cands.slice(0, AR.fetchSize).join('|'), danger: String(dangerNow(g, true)), known: g.stop?.scout ? '1' : '0' },
  });
  return false;
}

/** 출발 때 이동 사건 자리(turn.ts depart). ①이 뜨면 true: 그 구간의 이동 사건 하나를 대신한다. 꺼진 판은 아무 일도 안 한다 */
export function arrivalsTravel(g: Game, cands: readonly string[]): boolean {
  if (!g.arrivals) return false;
  return rollArrival(g, 'travel', cands);
}

/** 들어갈 칸: 기본 칸, 꼬리칸 과밀이 문턱 이상이면 의무진 칸. 가족 묶음 하나씩 들어가며 본다 */
function homeFor(g: Game, home: Comm, pop: Record<string, number>, a: ArrivalsState): Comm {
  if (home !== 'tail') return home;
  const crowd = crowdAfter(g, 'tail', pop.tail ?? 0, a);
  return crowd >= AR.overflowAt ? 'medtech' : 'tail';
}

/** 칸에 k명을 더 받으면 늘어나는 h(arrivedIn과 같은 식) */
function hGain(g: Game, c: Comm, added: number, a: ArrivalsState): number {
  const rec = a.byComm[c];
  const pop = g.comms[c].pop;
  const before = rec ? Math.max(0, Math.min(rec.got, pop - rec.popBefore)) : 0;
  const after = rec ? Math.max(0, Math.min(rec.got + added, pop + added - rec.popBefore)) : added;
  return after - before;
}

/** 이미 들어간 added명을 친 뒤의 과밀 */
function crowdAfter(g: Game, c: Comm, added: number, a: ArrivalsState): number {
  return Math.min(100, situation(g, c)[2] + ARRIVAL_SIT[2] * hGain(g, c, added, a));
}

/** 받을 사람 배치를 미리 본다(상태를 바꾸지 않는다) */
export function planPlace(g: Game, home: Comm, groups: readonly number[]): Partial<Record<Comm, number>> {
  const a = g.arrivals!;
  const pop: Partial<Record<Comm, number>> = {};
  for (const k of groups) {
    const c = homeFor(g, home, pop as Record<string, number>, a);
    pop[c] = (pop[c] ?? 0) + k;
  }
  return pop;
}

/** 비용 줄: 「꼬리칸 +10명 · 과밀 +15 · 배급 −8 · 온기 −5」, 빈속 몫 한 줄 */
export function placeLines(g: Game, home: Comm, groups: readonly number[]): string[] {
  const a = g.arrivals!;
  const plan = planPlace(g, home, groups);
  const out = (Object.keys(plan) as Comm[]).map(c => {
    const k = plan[c] ?? 0;
    const h = hGain(g, c, k, a);
    return `${COMM_NAME[c]} +${k}명 · 과밀 +${Math.round(ARRIVAL_SIT[2] * h)} · 배급 −${Math.round(ARRIVAL_SIT[1] * h)} · 온기 −${Math.round(ARRIVAL_SIT[0] * h)}`;
  });
  const n = sum(groups);
  out.push(`이번 정산 식량 −${round1(n * AR.hunger)}(빈속)`);
  return out;
}

const round1 = (v: number): number => Math.round(v * 10) / 10;

/** 받는다: 칸 인원에 더하고 받은 수와 받기 전 인원을 적는다. 다친 사람은 카드 효과(injured)가 이미 셌다 */
export function takeIn(g: Game, home: Comm, groups: readonly number[]): Partial<Record<Comm, number>> {
  const a = g.arrivals!;
  const plan = planPlace(g, home, groups);
  let most: Comm = home;
  for (const c of Object.keys(plan) as Comm[]) {
    const k = plan[c] ?? 0;
    const rec = (a.byComm[c] ??= { got: 0, popBefore: g.comms[c].pop });
    rec.got += k;
    g.comms[c].pop += k;
    if (k > (plan[most] ?? 0)) most = c;
  }
  const n = sum(groups);
  a.taken += n;
  a.hungry = (a.hungry ?? 0) + n;
  a.quarrel = { comm: most, from: g.seg + AR.quarrelFrom, to: g.seg + AR.quarrelTo };
  return plan;
}

export function placeText(plan: Partial<Record<Comm, number>>): string {
  return (Object.keys(plan) as Comm[]).map(c => `${COMM_NAME[c]} ${plan[c]}명`).join(', ');
}

/** 수색대를 내보낸다(① 데려옴, ② 가족). 다음 정차에 닿을 때 돌아온다 */
export function sendFetch(g: Game, kind: ArrivalKind, comm: Comm, names: string[], danger: number, groups: number[], hurt: number): void {
  const a = g.arrivals!;
  a.pending = { kind, comm, names, danger, groups, hurt, awayLive: true };
  g.comms[comm].away += names.length;
}

/** 다음 정차에 닿을 때(turn.ts arriveStop): 나갔던 수색대가 돌아오고, 하나라도 돌아오면 데려온 사람이 탄다. 꺼진 판은 아무 일도 안 한다 */
export function arrivalsArrive(g: Game): void {
  const a = g.arrivals;
  const p = a?.pending;
  if (!a || !p) return;
  delete a.pending;
  const alive = p.names.filter(n => !isGone(g, n));
  if (p.awayLive) g.comms[p.comm].away = Math.max(0, g.comms[p.comm].away - alive.length);
  const { qd, qh } = fetchOdds(p.danger);
  const dead = alive.filter(n => roll(g, `fd|${n}`) < qd);
  const hurt = alive.filter(n => !dead.includes(n) && roll(g, `fh|${n}`) < qh);
  if (hurt.length) {
    g.injured += hurt.length;
    noteInjury(g, hurt.length, 'stop', '수색', { names: hurt, comm: p.comm });
  }
  if (dead.length) onDeath(g, p.comm, dead, 'other');
  const n = sum(p.groups);
  if (alive.length - dead.length <= 0) {
    a.turned += n;
    journal(g, `수색대 ${p.names.length}명이 돌아오지 않았다.`, 'bad');
    return;
  }
  const plan = takeIn(g, p.kind === 'family' ? p.comm : 'tail', p.groups);
  if (p.hurt > 0) {
    g.injured += p.hurt;
    noteInjury(g, p.hurt, 'rescue', '수색', { comm: p.comm });
  }
  const tail = `${hurt.length ? ` 수색대 ${hurt.length}명이 크게 다쳤다.` : ''}${dead.length ? ` 수색대 ${dead.length}명은 돌아오지 못했다.` : ''}`;
  journal(g, `수색대가 돌아왔다. ${n}명이 함께 탔다(${placeText(plan)}).${tail}`, dead.length || hurt.length ? 'bad' : 'good');
}

/** 정산(turn.ts settle, hungerTick 앞): 받은 구간의 빈속 몫을 한 번 빼고, 잠자리 다툼을 본다. 꺼진 판은 아무 일도 안 한다 */
export function arrivalsSettle(g: Game, notes: string[]): void {
  const a = g.arrivals;
  if (!a) return;
  if (a.hungry) {
    const v = round1(a.hungry * AR.hunger);
    bump(g, 'food', -Math.min(Math.max(0, g.food), v), 'arrival');
    notes.push(`늦게 탄 ${a.hungry}명이 빈속이라 식량 −${v}.`);
    delete a.hungry;
  }
  const q = a.quarrel;
  if (q) {
    if (g.seg > q.to) delete a.quarrel;
    else if (g.seg >= q.from && crowdLevel(g, q.comm) >= 2 && arrivedIn(g, q.comm) > 0) {
      delete a.quarrel;
      addCard(g, { kind: 'bed_quarrel', comm: q.comm });
    }
  }
}

/** 정산 끝(turn.ts settle, 자리비움을 비운 뒤): 아직 나가 있는 수색대를 다시 자리비움으로 센다 */
export function arrivalsAway(g: Game): void {
  const p = g.arrivals?.pending;
  if (!p) return;
  p.awayLive = true;
  g.comms[p.comm].away += p.names.filter(n => !isGone(g, n)).length;
}
