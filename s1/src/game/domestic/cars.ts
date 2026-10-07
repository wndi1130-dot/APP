import { COMMS } from '../data';
import type { Comm } from '../data';
import { clamp, journal, lawActive, rnd } from '../state';
import type { Game } from '../state';
import { offend } from '../politics';
import { CAR_COMM, COMM_CARS, D, ZONE_WARM } from './data';
import type { Zone } from './data';
import { CAR_NAME, startJob } from './workshop';
import { domCard, refreshSit, zoneAt } from './state';
import type { DomState } from './state';

// 칸(4장): 칸 순서 바꾸기(4.5), 쓸 만한 칸(4.4, 10장 7번), 칸을 내줄 곳(10장 8번), 냉동칸 '묻고 간다'(4.1).

function dom(g: Game): DomState {
  if (!g.dom) throw new Error('S1c 내정이 꺼진 판이다');
  return g.dom;
}

const ZONE_RANK: Record<Zone, number> = { front: 2, middle: 1, back: 0 };

/** 칸 순서를 바꿀 수 있나: 측선이 있는 화물역 정차, 결정 전. */
export function moveOpen(g: Game): { ok: boolean; why?: string } {
  if (!g.dom) return { ok: false, why: 'S1c가 꺼진 판' };
  if (g.phase !== 'stop' || !g.stop || g.stop.done) return { ok: false, why: '정차 중에만' };
  if (g.stop.place !== 'freight') return { ok: false, why: '측선이 있는 화물역에서만' };
  return { ok: true };
}

export interface MovePreview {
  moved: string[];
  coal: number;
  /** 공동체마다 온기 시작값 변화와 관계 변화 */
  warm: Partial<Record<Comm, number>>;
  rel: Partial<Record<Comm, number>>;
  /** 앞칸을 앞 구역에서 밀어냈다(적의 +1) */
  frontPushed: boolean;
  workshopZone: Zone;
  why?: string;
}

/** 새 순서의 값과 정치(4.5). 확정 전에 화면이 보여 준다. */
export function previewMove(g: Game, order: string[]): MovePreview {
  const d = dom(g);
  const out: MovePreview = { moved: [], coal: 0, warm: {}, rel: {}, frontPushed: false, workshopZone: zoneAt(order.indexOf('workshop')) };
  if (order.length !== d.cars.length || [...order].sort().join() !== [...d.cars].sort().join()) return { ...out, why: '칸이 맞지 않는다' };
  for (const car of d.cars) {
    const from = zoneAt(d.cars.indexOf(car));
    const to = zoneAt(order.indexOf(car));
    if (d.cars.indexOf(car) !== order.indexOf(car)) out.moved.push(car);
    if (from === to) continue;
    const c = CAR_COMM[car];
    if (!c || d.greenhouse === car) continue;
    out.warm[c] = (out.warm[c] ?? 0) + (ZONE_WARM[to] - ZONE_WARM[from]) / COMM_CARS[c];
    const steps = ZONE_RANK[to] - ZONE_RANK[from];
    out.rel[c] = (out.rel[c] ?? 0) + (steps > 0 ? D.moveUpRel * steps : D.moveDownRel * -steps);
    if (c === 'front' && from === 'front') out.frontPushed = true;
  }
  // 사람이 사는 칸이 아니어도 자리는 바뀐다. 실제로 끌어 옮긴 칸 수는 자리가 바뀐 칸의 반쯤이지만, 단순하게 자리가 바뀐 칸을 센다.
  const shunted = Math.ceil(out.moved.length / 2);
  out.coal = shunted * D.moveCoal;
  if (shunted > D.moveMax) out.why = `한 번에 ${D.moveMax}칸까지`;
  return out;
}

export function applyMove(g: Game, order: string[]): boolean {
  if (!moveOpen(g).ok) return false;
  const pv = previewMove(g, order);
  if (pv.why || pv.moved.length === 0) return false;
  const d = dom(g);
  g.coal -= pv.coal;
  for (const c of COMMS) {
    if (pv.warm[c]) g.comms[c].base[0] += pv.warm[c]!;
    if (pv.rel[c]) g.comms[c].rel = clamp(g.comms[c].rel + pv.rel[c]!, -100, 100);
  }
  if (pv.frontPushed) offend(g, 'front');
  d.cars = [...order];
  d.stats.moves += 1;
  // 입환하는 동안 머물러야 해서 '짧게'는 못 고른다.
  if (g.stop && g.stop.stay === 'short') g.stop.stay = 'normal';
  d.movedAt = g.seg;
  journal(g, `측선에서 칸 순서를 바꿨다(${pv.moved.map(c => CAR_NAME[c] ?? c).join(', ')}). 석탄 ${pv.coal}.`, 'deal');
  refreshSit(g);
  return true;
}

export function movedThisStop(g: Game): boolean {
  return g.dom?.movedAt === g.seg;
}

// ---- 쓸 만한 칸(4.4, 10장 7번) ----
export function rollUsefulCar(g: Game): void {
  if (!g.dom || g.stop?.place !== 'freight') return;
  const r = rnd(g);
  if (r < D.wagonChance) domCard(g, { kind: 'dom:car', n: 0 });
  else if (r < D.wagonChance + D.coachChance) domCard(g, { kind: 'dom:car', n: 1 });
}

/** 꼬리 끝에 칸을 붙인다. 14번째 칸부터 달리기 석탄 +0.4/구간(4.2). */
export function attachCar(g: Game, kind: 'store' | 'coach'): void {
  const d = dom(g);
  d.extraCars.push(kind);
  const id = `${kind}${d.extraCars.length}`;
  d.cars.push(id);
  if (kind === 'coach') {
    g.comms.tail.base[2] -= D.coachCrowd;
    journal(g, '측선의 낡은 객차를 꼬리 끝에 달았다. 꼬리칸이 조금 넓어졌다.', 'good');
  } else {
    journal(g, '측선의 화차를 꼬리 끝에 달았다. 자재를 더 쌓을 수 있다.', 'good');
  }
}

export function extraCarCoal(g: Game): number {
  return (g.dom?.extraCars.length ?? 0) * D.extraCarCoal;
}

// ---- 칸을 내줄 곳(10장 8번) ----
/** 온실(또는 칸 기능 바꾸기)로 내줄 수 있는 칸. 화차는 거주칸이 될 수 없지만 온실은 된다(4.4). */
export function giveCandidates(g: Game): string[] {
  const d = dom(g);
  const base = ['front', 'store', 'cold', 'tail3'];
  return base.filter(c => d.cars.includes(c) && d.greenhouse !== c);
}

export function giveCar(g: Game, car: string): boolean {
  return startJob(g, 'convert', car);
}

// ---- 냉동칸 '묻고 간다'(4.1, 제안. S1a 법 9를 건드려 S1a 쪽에 넘긴다) ----
export function buryOpen(g: Game): { ok: boolean; why?: string } {
  if (!g.dom) return { ok: false, why: 'S1c가 꺼진 판' };
  if (!g.stop || g.stop.done) return { ok: false, why: '정차 준비 때만' };
  if (g.stored <= 0) return { ok: false, why: '냉동칸이 비었다' };
  if (g.stop.stay !== 'long') return { ok: false, why: '길게 머물 때만' };
  return { ok: true };
}

export function setBury(g: Game, on: boolean): void {
  const d = dom(g);
  d.bury = on && buryOpen(g).ok;
}

/** 정차를 마칠 때: 묻었으면 시신을 빼고 법 9를 지킨 것으로 친다. */
export function doBury(g: Game): void {
  const d = dom(g);
  if (!d.bury) return;
  d.bury = false;
  const n = Math.min(D.buryMax, g.stored);
  if (n <= 0) return;
  g.stored -= n;
  d.stats.buried += n;
  if (lawActive(g, 'corpse_store')) {
    for (const c of ['medtech', 'front', 'tail'] as Comm[]) g.comms[c].rel = clamp(g.comms[c].rel + D.buryRel, -100, 100);
  }
  journal(g, `언 땅을 파 냉동칸의 시신 ${n}구를 묻었다.`, 'good');
}

/** 냉동칸 안치 상한(4.1): 6, 냉동 보관(M3 나)이면 3. 넘으면 녹는 사고 확률 ×2. */
export function coldCap(g: Game): number {
  return g.dom?.techs.m3?.variant === 'b' ? D.coldCapM3b : D.coldCap;
}
export function thawMult(g: Game): number {
  return g.dom && g.stored > coldCap(g) ? 2 : 1;
}
