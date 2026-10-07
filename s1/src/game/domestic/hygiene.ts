import { COMMS, COMM_NAME, P } from '../data';
import type { Comm } from '../data';
import { onDeath } from '../death';
import { clamp, drawPerson, journal, lawActive, rnd, situation, totalPop } from '../state';
import type { Game } from '../state';
import { CARS0, CAR_COMM, D, ZONE0 } from './data';
import type { Hygiene } from './data';
import { domCard, techMult, zoneAt } from './state';
import type { DomState } from './state';

// 열차 위생(16장). 2장 4번의 가안 '가'(열차 전체 더운물 레버 하나, 법 21가·21나가 배분을 정한다)로 만든다. 제안이다.
// 사람마다 관리하지 않는다. 공동체 단위로 정산 때 다시 계산하고, 결정은 이·발진티푸스 카드로만 온다.

function dom(g: Game): DomState {
  if (!g.dom) throw new Error('S1c 내정이 꺼진 판이다');
  return g.dom;
}

/** 이웃 칸(발진티푸스가 번지는 길). 칸 순서: 꼬리칸 → 기술·의무진 → 경비대 → 앞칸 → 기관실. */
const NEIGHBORS: Record<Comm, Comm[]> = {
  tail: ['medtech'], medtech: ['tail', 'guard'], guard: ['medtech', 'front'], front: ['guard', 'engine'], engine: ['front'],
};

/** 레버는 드물게(1)·보통(2)·넉넉(3). 21가가 있어도 '드물게'까지 내릴 수 있다(16.4, 16.9). */
export function hotWaterFloor(_g: Game): number {
  return 1;
}

export function setHotWater(g: Game, v: number): void {
  dom(g).hotWater = clamp(Math.round(v), hotWaterFloor(g), 3);
}

/** 더운물 석탄/구간 = max(0, 레버 − 1) × 인구/40 × 0.1 × 법, 21가면 +0.25 고정(16.2, 16.4, 16.6, 16.9). '드물게'는 공짜다. */
export function hotWaterCoal(g: Game): number {
  const d = g.dom;
  if (!d) return 0;
  let m = 1;
  if (lawActive(g, 'bath_rota')) m *= D.bathRotaCoal;
  if (lawActive(g, 'hands_first')) m *= D.handsFirstCoal;
  const rota = lawActive(g, 'bath_rota') ? D.bathRotaFlat : 0;
  return Math.max(0, Math.max(d.hotWater, hotWaterFloor(g)) - 1) * (totalPop(g) / 40) * D.hotWaterCoal * m + rota;
}

/** 그 공동체가 사는 칸 가운데 뒤 구역에 있는 비율(0~1). 뒤 구역의 −1은 공동체가 아니라 자리에 붙는다(16.2, 4.3). */
export function backShare(g: Game, c: Comm): number {
  const cars = g.dom?.cars ?? CARS0;
  let n = 0;
  let back = 0;
  cars.forEach((id, i) => {
    if (CAR_COMM[id] !== c) return;
    n += 1;
    if ((g.dom ? zoneAt(i) : ZONE0[id]) === 'back') back += 1;
  });
  return n > 0 ? back / n : 0;
}

/** 공동체의 더운물 몫(0~3). 법이 없으면 '보일러에서 가까운 순서'(16.2): 앞칸 +1(제 난로), 뒤 구역에 있는 칸 비율만큼 −1. */
export function hotWaterShare(g: Game, c: Comm): number {
  const lever = Math.max(g.dom?.hotWater ?? 1, hotWaterFloor(g));
  if (lawActive(g, 'bath_rota')) return lever;
  if (lawActive(g, 'hands_first')) {
    const crew = g.stop?.crewComm;
    const up = c === 'engine' || c === 'guard' || c === crew;
    const down = c === 'tail' || c === 'front';
    return clamp(lever + (up ? 1 : 0) - (down && !up ? 1 : 0), 0, 3);
  }
  if (c === 'front') return Math.min(3, lever + 1);
  return clamp(lever - backShare(g, c), 0, 3);
}

/** 위생 점수 = 몫 − 과밀 보정(16.3). 앞칸은 제 난로가 있어 레버가 없음이어도 씻는다(문서의 'S1a 법 5'는 이 빌드에 없는 법이라 늘 그렇게 둔다). */
export function hygieneScore(g: Game, c: Comm): number {
  const crowd = situation(g, c)[2];
  const share = c === 'front' ? Math.max(1, hotWaterShare(g, c)) : hotWaterShare(g, c);
  return share - (crowd >= 80 ? 2 : crowd >= 60 ? 1 : 0);
}

/** 대야를 누르면 나오는 까닭 한 줄(16.3 '보이는 법'). 늘 조건(자리·과밀·몫)만 적는다(16.1 가). 소수점은 안 띄운다. */
export function hygieneWhy(g: Game, c: Comm): string {
  const crowd = Math.round(situation(g, c)[2]);
  const b = backShare(g, c);
  const place = c === 'front' ? '보일러에서 가까움 · 제 난로'
    : c === 'engine' ? '보일러 옆'
    : b >= 1 ? '보일러에서 가장 멂'
    : b > 0 ? '보일러에서 먼 칸이 있음'
    : '보일러에서 중간';
  const share = c === 'front' ? Math.max(1, hotWaterShare(g, c)) : hotWaterShare(g, c);
  return `${place} · 과밀 ${crowd} · 몫 ${Math.round(share)}`;
}

export function hygiene(g: Game, c: Comm): Hygiene {
  const s = hygieneScore(g, c);
  return s >= 2 ? 'clean' : s >= 0 ? 'normal' : 'dirty';
}

/** 정산 때 위생 한 구간: 불결한 칸 관계 −1, 이 판정, '버틴다'의 기한, 발진티푸스. */
export function hygieneTick(g: Game, notes: string[]): void {
  const d = dom(g);
  const winter = g.seg % P.winterEvery === 0;
  for (const c of COMMS) {
    const h = hygiene(g, c);
    const lice = d.lice[c];
    // 불결한 칸은 이가 돌 때만 관계를 깎는다(16.9).
    if (h === 'dirty' && lice) g.comms[c].rel = clamp(g.comms[c].rel - D.dirtyRel, -100, 100);
    if (lice) {
      if (lice.endureDue !== undefined && g.seg >= lice.endureDue) {
        delete d.lice[c];
        (d.liceFree ??= {})[c] = g.seg + D.liceImmune;
        const p = techMult(g, 'm5') > 0 ? D.typhusFromLice + (D.typhusFromLiceM5 - D.typhusFromLice) * techMult(g, 'm5') : D.typhusFromLice;
        if (rnd(g) < p) startTyphus(g, c, D.typhusPatients);
        else journal(g, `${COMM_NAME[c]}의 이가 겨울을 못 넘기고 줄었다.`);
      }
      continue;
    }
    // 이 카드는 4구간부터 온다(16.3). 물 사정을 먼저 보고 막을 시간을 준다.
    if (g.seg < D.liceFromSeg) continue;
    if (h === 'clean' || g.cards.some(x => x.kind === 'dom:lice' && x.comm === c)) continue;
    if (d.typhus.some(t => t.comm === c)) continue;
    if (g.seg < (d.liceFree?.[c] ?? 0)) continue;
    const chance = (h === 'dirty' ? D.liceDirty : D.liceNormal) * (winter ? D.liceWinter : 1);
    if (rnd(g) < chance) {
      d.lice[c] = { at: g.seg };
      d.flags.lice = true;
      d.stats.lice += 1;
      domCard(g, { kind: 'dom:lice', comm: c });
    }
  }
  typhusTick(g, notes);
}

/** 이 카드의 셋(16.5). */
export function resolveLice(g: Game, c: Comm, pick: 'boil' | 'burn' | 'endure'): void {
  const d = dom(g);
  if (pick === 'boil') {
    g.coal -= D.boilCoal;
    delete d.lice[c];
    (d.liceFree ??= {})[c] = g.seg + D.liceImmune;
    journal(g, `${COMM_NAME[c]} 옷을 솥에 넣어 삶았다.`);
  } else if (pick === 'burn') {
    d.bedding[c] = g.seg + D.beddingSegs - 1;
    delete d.lice[c];
    (d.liceFree ??= {})[c] = g.seg + D.liceImmune;
    journal(g, `${COMM_NAME[c]} 침구를 태웠다. 오늘 밤은 춥다.`, 'bad');
  } else {
    d.lice[c] = { at: d.lice[c]?.at ?? g.seg, endureDue: g.seg + D.endureSegs };
  }
}

export function startTyphus(g: Game, c: Comm, n: number): void {
  const d = dom(g);
  const patients = Array.from({ length: n }, () => drawPerson(g, c).name);
  d.typhus.push({ comm: c, patients, apart: false, bay: false, at: g.seg });
  d.stats.typhus += 1;
  domCard(g, { kind: 'dom:typhus', comm: c, n: patients.length });
  journal(g, `${COMM_NAME[c]}에 열병이 돌았다. ${patients.length}명이 누웠다.`, 'bad');
}

/** 열병 카드의 둘(16.5). 둘 다 강압이 아니라 관계·공포 벌이 없다. 고르는 것은 '부상자냐 열병 환자냐'다. */
export function resolveTyphus(g: Game, c: Comm, pick: 'bay' | 'apart'): void {
  const d = dom(g);
  const t = d.typhus.find(x => x.comm === c);
  if (!t) return;
  if (pick === 'bay') t.bay = true;
  else t.apart = true;
}

/** 의무칸을 비웠나(부상자 회복이 멈춘다). */
export function bayTaken(g: Game): boolean {
  return (g.dom?.typhus ?? []).some(t => t.bay && t.patients.length > 0);
}

/** 발진티푸스 환자가 먹는 의약품(medicineTick 앞에서 뺀다). */
export function typhusMedNeed(g: Game): number {
  return (g.dom?.typhus ?? []).reduce((s, t) => s + t.patients.length * D.typhusMed, 0);
}

function typhusTick(g: Game, notes: string[]): void {
  const d = dom(g);
  const m1 = techMult(g, 'm1');
  const death = D.typhusDeath + (D.typhusDeathM1 - D.typhusDeath) * m1;
  for (const t of d.typhus) {
    if (t.at === g.seg) continue;
    const need = t.patients.length * D.typhusMed;
    const dead: string[] = [];
    const kept: string[] = [];
    const hasMed = g.med >= need;
    if (hasMed) g.med -= need; else g.med = 0;
    // 의약품을 받으면 구간마다 40%(따로 눕혔으면 25%)로 낫는다. 없으면 낫지 않고 15%(응급 처치면 10%)로 죽는다(16.5, triage N12).
    const recover = t.apart ? D.typhusRecoverApart : D.typhusRecover;
    for (const who of t.patients) {
      if (hasMed ? rnd(g) < recover : false) continue;
      if (!hasMed && rnd(g) < death) dead.push(who);
      else kept.push(who);
    }
    t.patients = kept;
    if (dead.length > 0) {
      onDeath(g, t.comm, dead);
      notes.push(`열병으로 ${dead.length}명이 죽었다.`);
    }
    // 의무칸으로 옮겼으면 번지지 않는다. 따로 눕혔으면 절반. 받는 칸의 과밀만 본다(16.1 나).
    if (!t.bay && kept.length > 0) {
      const spread = t.apart ? D.typhusSpreadApart : D.typhusSpread;
      for (const n of NEIGHBORS[t.comm]) {
        if (d.typhus.some(x => x.comm === n)) continue;
        if (situation(g, n)[2] >= D.typhusSpreadCrowd && rnd(g) < spread) startTyphus(g, n, 2);
      }
    }
  }
  const ended = d.typhus.filter(t => t.patients.length === 0 && t.at !== g.seg);
  for (const t of ended) journal(g, `${COMM_NAME[t.comm]}의 열병이 지나갔다.`, 'good');
  d.typhus = d.typhus.filter(t => t.patients.length > 0 || t.at === g.seg);
}
