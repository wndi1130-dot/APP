import { crowdSepticP } from './crowd';
import { DEATH_HOOKS, onDeath } from './death';
import { COMMS } from './data';
import type { Comm, LawId } from './data';
import { lawTechRes } from './domestic/lawtech';
import { D } from './domestic/data';
import { typhusInBeds } from './domestic/beds';
import { eduOf, healCut, healNote } from './domestic/classroom';
import { living, techMult } from './domestic/state';
import { pickVictims } from './people';
import { bump, put } from './ledger';
import { CREW_BUSY, isGone, journal, PROFILES, rnd } from './state';
import type { Game } from './state';

// 부상 명부(정치_열차_명세_1_부상.md 1~3절). 사람에 붙은 Wound 기록이 g.wounds에 쌓이고, g.injured는 거기서 다시 센 파생값이다.
// 공유 파일(state.ts·turn.ts·dark/)을 고치기 전의 준비 단계라서 꼴과 규칙을 이 파일에 둔다. 아직 어느 규칙도 부르지 않는다.
// state.ts에 들어갈 때 이 꼴을 옮기고 여기서 다시 내보낸다.

export type WoundGrade = 'light' | 'deep' | 'fracture' | 'amputation';
export type WoundPart = 'head' | 'torso' | 'armL' | 'armR' | 'legL' | 'legR';
export type WoundFrom =
  | 'stop' | 'order' | 'rescue' | 'bite_cut' | 'tender' | 'brawl' | 'guard_post' | 'rise' | 'thaw' | 'duel' | 'assault' | 'poison';
export type WoundState = 'bed' | 'home' | 'light' | 'healed' | 'permanent';

export interface Wound {
  id: number;
  /** 이름(S1a 사람 키). 프로필 id는 S1a에 없다 */
  who: string;
  /** 대표·측근처럼 Leader.personId가 있는 사람만 */
  personId?: string;
  comm: Comm;
  grade: WoundGrade;
  part: WoundPart;
  from: WoundFrom;
  where: string;
  why?: string;
  septic: boolean;
  /** 남은 날(구간). 0에 닿으면 healed 또는 permanent */
  daysLeft: number;
  /** 생길 때의 daysLeft(곪음 상한과 일대기의 「가장 오래 누운 사람」이 읽는다). 명세 꼴에 더한 칸 */
  days0: number;
  /** 침상을 쓰는 남은 날 */
  bedDays: number;
  state: WoundState;
  /** 생긴 구간(g.seg) */
  at: number;
  prosthesis?: 'hook' | 'joint' | 'custom';
  reSent?: number;
  /** 수업 덕에 낫는 날이 하루 줄었다(domestic/classroom.ts). 나으면 끝 장면의 수에 센다 */
  edu?: true;
  /** 필드에서 직접 뛴 정차의 상처 줄 그대로(영수증 people.wounds: 부위·종류·곪음·처치). 등급·부위는 이 줄에서 왔다 */
  field?: { part: string; kind: string; festering?: boolean; treat?: Record<string, true> }[];
}

/** Game에 붙을 두 칸. state.ts에 들어가기 전까지는 이 꼴로 읽는다. */
export interface WoundBook { wounds?: Wound[]; nextWoundId?: number }
type G = Game & WoundBook;

const LIMBS: readonly WoundPart[] = ['armL', 'armR', 'legL', 'legR'];

/** 정차 수색의 등급·부위 뽑기(3.1)와 곪음. 다른 자리는 표의 값을 grade·part·septic으로 직접 준다. */
export const WOUND_ROLL = {
  grade: { light: 0.3, deep: 0.45, fracture: 0.2, amputation: 0.05 } as Record<WoundGrade, number>,
  part: { armL: 0.2, armR: 0.2, legL: 0.2, legR: 0.2, torso: 0.15, head: 0.05 } as Record<WoundPart, number>,
  septicP: 0.2,
  septicM1: 0.1,
  septicLongStay: 0.1,
  septicGrow: 0.1,
};

export const PART_NAME: Record<WoundPart, string> = { head: '머리', torso: '몸통', armL: '왼팔', armR: '오른팔', legL: '왼다리', legR: '오른다리' };

export const isArm = (p: WoundPart): boolean => p === 'armL' || p === 'armR';
export const isLeg = (p: WoundPart): boolean => p === 'legL' || p === 'legR';

/** 열차장도 같은 부상 기록에 오른다(결정 072 다). 열차장은 앞칸에서 지내는 것으로 적고, 침상은 다른 부상자와 다툰다. */
export const CAPTAIN = '열차장';
const CAPTAIN_COMM: Comm = 'front';

const book = (g: Game): Wound[] => ((g as G).wounds ??= []);

/** 활성 기록: 침상, 제 칸, 가벼운 상처. healed·permanent는 세지 않는다. */
export function isActive(w: Wound): boolean {
  return w.state === 'bed' || w.state === 'home' || w.state === 'light';
}

export function activeWounds(g: Game, comm?: Comm): Wound[] {
  return book(g).filter(w => isActive(w) && (comm === undefined || w.comm === comm));
}

// 깊은 상처·골절·절단이 낫는 동안에는 정차 작업조와 정찰조에 들지 않는다. 가벼운 상처는 그대로 나간다(다친 사람 명세 4절).
CREW_BUSY.push(g => activeWounds(g).filter(w => w.grade !== 'light').map(w => w.who));

/** 열차에 있는 사람의 활성 기록(죽었거나 내린 사람의 기록은 뺀다). 화면과 noteRelief가 읽는다. */
export function liveWounds(g: Game, comm?: Comm): Wound[] {
  return activeWounds(g, comm).filter(w => !isGone(g, w.who));
}

/** 이 이름이 지금 활성 부상이 있나(전문가·대표 셈이 이름으로 읽는다). */
export function isWounded(g: Game, who: string): boolean {
  return book(g).some(w => w.who === who && isActive(w));
}

export function bedCount(g: Game): number {
  return book(g).filter(w => w.state === 'bed').length;
}

/** g.injured는 명부에서 다시 센 값이다. addWound·woundTick·의수 완성·사망 처리 뒤에 부른다. */
export function syncInjured(g: Game): void {
  g.injured = liveWounds(g).length;
}

// ---- 화면에 넘기는 읽기 전용 값 ----
export const GRADE_NAME: Record<WoundGrade, string> = { light: '가벼운 상처', deep: '깊은 상처', fracture: '골절', amputation: '절단' };

/** 치료 자리: 침상에서 치료 중(bed), 침상이 모자라 제 칸에서 버팀(home), 일어났지만 아직 낫지 않음(up). */
export type WoundCare = 'bed' | 'home' | 'up';

export interface WoundRow {
  id: number;
  who: string;
  personId?: string;
  comm: Comm;
  part: WoundPart;
  partName: string;
  grade: WoundGrade;
  gradeName: string;
  /** 어디서 다쳤나(정차한 곳, 칸 이름 등). 명부 밖에서 오른 몫을 맞춘 기록은 빈 글 */
  where: string;
  /** 낫기까지 남은 구간 */
  daysLeft: number;
  care: WoundCare;
  septic: boolean;
  /** 하루 의약품(곪음 포함) */
  medPerDay: number;
  /** 수업 덕에 하루 줄어든 상처 */
  edu?: true;
}

/**
 * 의료 화면용 한 줄 묶음. 활성 기록만, 생긴 순서(구간, id)로 준다. 상태·난수·장부를 건드리지 않는다.
 * 누구를 먼저 볼지의 순서는 규칙이라 여기서 정하지 않는다.
 */
export function woundView(g: Game, comm?: Comm): WoundRow[] {
  return [...liveWounds(g, comm)].sort((a, b) => a.at - b.at || a.id - b.id).map(w => ({
    id: w.id, who: w.who, ...(w.personId ? { personId: w.personId } : {}), comm: w.comm,
    part: w.part, partName: PART_NAME[w.part], grade: w.grade, gradeName: GRADE_NAME[w.grade], where: w.where,
    daysLeft: w.daysLeft, care: w.state === 'bed' ? 'bed' : w.state === 'home' ? 'home' : 'up',
    septic: w.septic, medPerDay: medPerDay(w), ...(w.edu ? { edu: true as const } : {}),
  }));
}

/** 수만 세어 둔 부상자(명부에 이름이 없는 몫). 규칙이 명부를 채우기 전에는 g.injured 전부가 여기 든다. */
export function unnamedInjured(g: Game): number {
  return Math.max(0, Math.floor(g.injured) - liveWounds(g).length);
}

// ---- 값 ----
function baseDays(grade: WoundGrade, part: WoundPart, coin: number): number {
  if (grade === 'light') return 1;
  if (grade === 'deep') return coin < 0.5 ? 3 : 4;
  if (grade === 'fracture') return isArm(part) ? 6 : 8;
  return 4;
}

function floorDays(grade: WoundGrade, part: WoundPart): number {
  if (grade === 'light') return 1;
  if (grade === 'deep') return 2;
  if (grade === 'fracture') return isArm(part) ? 3 : 4;
  return 2;
}

function bedDaysOf(grade: WoundGrade): number {
  return grade === 'light' ? 0 : grade === 'amputation' ? 4 : 2;
}

/** 새 기록의 날 수를 줄이는 몫(2절·4절): 선 법들의 healDays 합(모두를 치료 −1), M1 응급 처치 −1, 둘째 의무칸 의료 견습 −1(증축 명세 2가 열기 전엔 0). */
export function healCuts(g: Game): number {
  const laws = (Object.keys(g.passed) as LawId[]).reduce((s, law) => s - (lawTechRes(g, law).healDays ?? 0), 0);
  return laws + (techMult(g, 'm1') > 0 ? 1 : 0);
}

/** 하루 의약품. fracture는 침상에 있는 동안만, 곪음은 +0.5. */
export function medPerDay(w: Wound): number {
  let m = 0;
  if (w.grade === 'deep' || w.grade === 'amputation') m = 0.5;
  else if (w.grade === 'fracture' && w.bedDays > 0) m = 0.5;
  if (w.septic) m += 0.5;
  return m;
}

/** 의약품이 모자랄 때 하루 사망 확률. */
export function deathPerDay(w: Wound): number {
  if (w.grade === 'deep') return w.septic ? 0.2 : 0.1;
  if (w.grade === 'fracture') return 0.03;
  if (w.grade === 'amputation') return 0.15;
  return 0;
}

/** 정차 곪음 확률(3.1): 20%, M1이 있으면 10%, 오래 머물렀으면 +10%p. */
export function stopSepticP(g: Game, longStay: boolean): number {
  return (techMult(g, 'm1') > 0 ? WOUND_ROLL.septicM1 : WOUND_ROLL.septicP) + (longStay ? WOUND_ROLL.septicLongStay : 0);
}

function weightedPick<K extends string>(rand: () => number, table: Record<K, number>): K {
  const keys = Object.keys(table) as K[];
  const total = keys.reduce((s, k) => s + table[k], 0);
  let r = rand() * total;
  for (const k of keys) {
    if (r < table[k]) return k;
    r -= table[k];
  }
  return keys[keys.length - 1];
}

// ---- 진입점 ----
export interface WoundInput {
  who: string;
  comm: Comm;
  from: WoundFrom;
  where: string;
  why?: string;
  /** 안 주면 WOUND_ROLL.grade로 뽑는다 */
  grade?: WoundGrade;
  /** 안 주면 WOUND_ROLL.part로 뽑는다. fracture인데 머리·몸통이면 팔다리 넷 가운데서 다시 뽑는다 */
  part?: WoundPart;
  /** 정해 주면 굴리지 않는다 */
  septic?: boolean;
  /** septic을 안 줬을 때 곪을 확률(기본 WOUND_ROLL.septicP) */
  septicP?: number;
  /** 기본 healCuts(g) */
  cuts?: number;
}

const GRADE_LINE: Record<WoundGrade, string> = { light: '에 가벼운 상처가 났다.', deep: '에 깊은 상처가 났다.', fracture: '이(가) 부러졌다.', amputation: '을(를) 잃었다.' };

/** 기록 하나를 만들어 명부에 넣는다(저널·부상자 수는 부르는 쪽 몫). 굴리는 순서는 등급, 부위(, 골절이 머리·몸통이면 팔다리), 깊은 상처의 3일/4일, 곪음이다. */
function pushWound(g: Game, input: WoundInput, rand: () => number): Wound {
  const grade = input.grade ?? weightedPick(rand, WOUND_ROLL.grade);
  let part = input.part ?? weightedPick(rand, WOUND_ROLL.part);
  if (grade === 'fracture' && !LIMBS.includes(part)) part = LIMBS[Math.floor(rand() * LIMBS.length)];
  const coin = grade === 'deep' ? rand() : 0;
  const septic = input.septic ?? rand() < (input.septicP ?? WOUND_ROLL.septicP) + crowdSepticP(g, input.comm);
  const cuts = input.cuts ?? healCuts(g);
  const id = (g as G).nextWoundId ?? 1;
  const edu = healCut(g, grade, id); // 의무칸 곁 수업: 깊은 상처와 골절만 하루 더. 바닥 아래로는 안 내려간다(결정 208)
  let days = baseDays(grade, part, coin);
  const without = cuts > 0 ? Math.max(floorDays(grade, part), days - cuts) : days;
  if (cuts + edu > 0) days = Math.max(floorDays(grade, part), days - cuts - edu);
  const quick = days < without;
  if (septic) days = Math.ceil(days * 1.5);
  const state: WoundState = grade === 'light' ? 'light' : 'bed';
  // 간호 손: 의무진에 활성 기록이 있으면 다른 칸의 침상 기록이 한 번 하루 늦게 낫는다(5절).
  if (state === 'bed' && input.comm !== 'medtech' && activeWounds(g, 'medtech').length > 0) days += 1;
  const leader = g.comms[input.comm].leader;
  const w: Wound = {
    id, who: input.who, ...(leader.name === input.who ? { personId: leader.personId } : {}),
    comm: input.comm, grade, part, from: input.from, where: input.where, ...(input.why ? { why: input.why } : {}),
    septic, daysLeft: days, days0: days, bedDays: bedDaysOf(grade), state, at: g.seg, ...(quick ? { edu: true as const } : {}),
  };
  (g as G).nextWoundId = w.id + 1;
  book(g).push(w);
  if (quick) healNote(g, w.id);
  return w;
}

/**
 * 부상을 명부에 올리는 진입점. 값을 정해 준 칸은 굴리지 않는다(난수를 쓰지 않는다). g.injured는 명부에서 다시 센다.
 * 옛 규칙이 g.injured를 직접 올리는 자리는 아직 noteInjury로 곁에 기록만 남긴다(정산을 명세 표로 바꾸는 PR에서 이 함수로 합친다).
 */
export function addWound(g: Game, input: WoundInput): Wound {
  const w = pushWound(g, input, () => rnd(g));
  journal(g, `${w.who}의 ${PART_NAME[w.part]}${GRADE_LINE[w.grade]}${w.septic ? ' 상처가 곪기 시작했다.' : ''}`, w.grade === 'light' ? undefined : 'bad');
  syncInjured(g);
  return w;
}

// ---- 옛 규칙 곁의 기록(잇기 ①: 숫자를 바꾸지 않는다) ----
/** 판 난수를 건드리지 않는 로컬 난수(시드·자리·구간으로 정해진다). */
function hashRng(key: string): () => number {
  let h = 2166136261;
  for (const ch of key) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return () => { h = (h + 0x6d2b79f5) | 0; let t = Math.imul(h ^ (h >>> 15), 1 | h); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

export interface NoteOpt {
  /** 다친 사람의 이름. 모자라거나 없으면 판 난수 없이 사람을 골라 채운다 */
  names?: readonly string[];
  /** 다친 사람이 속한 칸. 이름이 없으면 이 칸 사람 가운데서 고르고(없으면 전체), 이름이 프로필에 없을 때는 이 칸으로 적는다 */
  comm?: Comm;
  why?: string;
}

const commOfName = (g: Game, name: string): Comm | undefined =>
  name === CAPTAIN ? CAPTAIN_COMM : PROFILES.find(p => p.name === name)?.community ?? COMMS.find(c => g.comms[c].leader.name === name);

/** 열차장이 다쳤다. 침상 여섯을 다른 부상자와 다투고, 나을 때까지 부상 기록에 남는다. 등급·부위를 안 주면 명세 표로 뽑는다. */
export function hurtCaptain(g: Game, from: WoundFrom, where: string, opt: Partial<Pick<WoundInput, 'grade' | 'part' | 'septic' | 'why'>> = {}): Wound {
  return addWound(g, { who: CAPTAIN, comm: CAPTAIN_COMM, from, where, ...opt });
}

/**
 * 옛 규칙이 방금 g.injured를 n만큼 올렸을 때, 그 곁에 명부 기록 n개를 남긴다. 저널·g.injured·판 난수·정산은 건드리지 않는다.
 * 등급·부위·곪음은 명세 표의 확률로 로컬 난수가 뽑지만 아직 아무 규칙도 읽지 않는다(옛 정산이 그대로 돈다).
 */
export function noteInjury(g: Game, n: number, from: WoundFrom, where: string, opt: NoteOpt = {}): void {
  if (n <= 0) return;
  const names = [...(opt.names ?? [])].slice(0, n);
  if (names.length < n) {
    const seed = hashRng(`${g.seed}:note:${g.seg}:${(g as G).nextWoundId ?? 1}:${from}:${n}`);
    const known = new Set(names);
    const all = pickVictims(g, PROFILES.length, 'wound', seed).filter(p => !known.has(p.name) && !isWounded(g, p.name));
    const mine = opt.comm ? all.filter(p => p.community === opt.comm) : [];
    const pool = mine.length >= n - names.length ? mine : all;
    for (const p of pool) { if (names.length >= n) break; names.push(p.name); }
  }
  for (const who of names) {
    const comm = commOfName(g, who) ?? opt.comm ?? 'tail';
    pushWound(g, { who, comm, from, where, ...(opt.why ? { why: opt.why } : {}) }, hashRng(`${g.seed}:wound:${g.seg}:${(g as G).nextWoundId ?? 1}:${who}`));
  }
}

/**
 * 필드에서 정해진 상처 하나를 명부에 올린다(S3 직접 정차, 다시 뽑지 않음). 등급·부위·곪음은 받은 그대로이고, 깊은 상처의
 * 3일/4일만 noteInjury와 같은 로컬 난수(시드·구간·기록 id·이름)가 고른다. 저널·g.injured는 부르는 쪽 몫이다.
 */
export function recordFieldWound(g: Game, input: WoundInput & { grade: WoundGrade; part: WoundPart; septic: boolean }, field: Wound['field']): Wound {
  const w = pushWound(g, input, hashRng(`${g.seed}:wound:${g.seg}:${(g as G).nextWoundId ?? 1}:${input.who}`));
  if (field && field.length > 0) w.field = structuredClone(field);
  return w;
}

/** 옛 규칙이 g.injured를 n만큼 내렸을 때(나음·죽음·의무진 고유 행동) 가장 오래된 활성 기록 n개를 거둔다. 누가 나았는지는 정하지 않는다(먼저 볼 사람 고르기는 사용자 답을 기다린다). */
export function noteRelief(g: Game, n: number): void {
  for (const w of liveWounds(g).slice(0, Math.max(0, n))) w.state = 'healed';
}

/** 옛 규칙이 이름 붙은 한 사람의 부상을 되돌릴 때(명령에 다친 대상이 죽음): 그 사람의 가장 새 활성 기록을 지운다. */
export function noteDrop(g: Game, who: string): void {
  const wounds = book(g);
  for (let i = wounds.length - 1; i >= 0; i -= 1) {
    if (wounds[i].who === who && isActive(wounds[i])) { wounds.splice(i, 1); return; }
  }
}

// 다쳐 있던 사람이 죽으면 부상자 수에서도 뺀다. 명부는 죽은 사람의 기록을 세지 않으니, 안 빼면 g.injured만 남아 다음 정산(reconcileRoster)이 엉뚱한 산 사람을 다치게 채운다.
DEATH_HOOKS.push((g, _c, names) => {
  const lost = activeWounds(g).filter(w => names.includes(w.who)).length;
  if (lost > 0) g.injured = Math.max(0, g.injured - lost);
});

// ---- 정산 ----
function bayBusy(g: Game): boolean {
  return (g.dom?.typhus ?? []).some(t => t.bay && t.patients.length > 0);
}

/**
 * 하루 정산(2.1). medicineTick을 바꿀 자리. 이번 구간에 생긴 기록은 의약품은 들어도 날은 안 깎는다. medMult는 lawMult(g,'medMult')를 부르는 쪽이 넘긴다(turn.ts 비공개 함수).
 * 의약품이 모자랄 때 기록마다 하루 한 번 굴린다(활성 기록이 없으면 난수도 의약품도 쓰지 않는다).
 */
export function woundTick(g: Game, notes: string[], medMult = 1): void {
  for (const w of activeWounds(g)) if (isGone(g, w.who)) w.state = 'healed';
  const act = liveWounds(g);
  if (act.length === 0) { syncInjured(g); return; }
  const need = act.reduce((s, w) => s + medPerDay(w), 0) * medMult;
  const med = g.comms.medtech;
  if (med.fervor >= 1 && med.rel <= -40) {
    bump(g, 'med', -Math.min(need, g.med), 'sick');
    notes.push('의무진이 진료를 거부했다.');
    syncInjured(g);
    return;
  }
  if (g.med < need) {
    put(g, 'med', 0, 'sick');
    notes.push('의약품이 떨어졌다.');
    for (const w of act) {
      const p = deathPerDay(w);
      // 열차장이 약이 없어 죽는 길은 S1에 없다(죽으면 판이 끝나는 자리는 따로 정한다).
      if (w.who !== CAPTAIN && p > 0 && rnd(g) < p) {
        const wounds = book(g);
        wounds.splice(wounds.indexOf(w), 1);
        onDeath(g, w.comm, [w.who]);
      }
    }
    syncInjured(g);
    return;
  }
  bump(g, 'med', -need, 'sick');
  const frozen = bayBusy(g);
  for (const w of act) {
    // 생긴 구간의 정산에서는 날을 깎지 않는다(코디네이터 10-11): 가벼운 상처도 다음 정차 한 번은 못 나간다는 뜻이 닿게 한다.
    if (w.at === g.seg) continue;
    if (w.state === 'bed' && frozen) continue;
    w.daysLeft -= 1;
    if (w.state === 'bed' || w.state === 'home') w.bedDays -= 1;
  }
  for (const w of act) {
    if (w.grade === 'amputation' && w.bedDays <= 0) {
      w.state = 'permanent';
      journal(g, `${w.who}의 ${PART_NAME[w.part]}은(는) 돌아오지 않는다.`);
    } else if (w.daysLeft <= 0) {
      w.state = 'healed';
      if (w.edu) eduOf(g).early += 1;
      journal(g, `${w.who}의 ${PART_NAME[w.part]}이(가) 다 나았다.`, 'good');
    } else if (w.bedDays <= 0 && (w.state === 'bed' || w.state === 'home')) {
      w.state = 'light';
      journal(g, `${w.who}이(가) 침상에서 내려왔다. ${PART_NAME[w.part]}은(는) 아직 낫지 않았다.`);
    }
  }
  for (const w of act) {
    if (isActive(w) && w.septic && w.daysLeft < w.days0 * 2 && rnd(g) < WOUND_ROLL.septicGrow) w.daysLeft += 1;
  }
  syncInjured(g);
}

/** 옛 칸(명부 밖에서 오른 g.injured, 예: hub.ts)과 명부를 맞춘다. 모자란 만큼 기록을 만들고(로컬 난수), 남는 만큼 거둔다. */
export function reconcileRoster(g: Game): void {
  const live = liveWounds(g).length;
  const n = Math.floor(g.injured);
  if (n > live) noteInjury(g, n - live, 'stop', '');
  else if (n < live) noteRelief(g, live - n);
}

// ---- 침상 넘침(2.2) ----
/** 일할 손 값: 전문가 2, 어른 1, 그 밖 0. 높을수록 침상에 남는다('workers'). */
function workerRank(g: Game, w: Wound): number {
  if (w.who === CAPTAIN) return 2;
  if (living(g).some(p => p.name === w.who && p.skill >= 1)) return 2;
  const pr = PROFILES.find(p => p.name === w.who);
  return pr && pr.age >= 16 ? 1 : 0;
}

/**
 * 침상보다 누울 사람이 많으면 넘친 만큼 bed 기록을 home으로 내린다(내려가는 순간 한 번 daysLeft +1). 침상이 비면 home을 bed로 되돌린다(날 수는 안 돌려준다).
 * 누가 남나: workers는 일할 손이 높은 사람, sick은 낫는 날이 많이 남은 사람, rota·null은 먼저 생긴 기록.
 * 옮긴 기록 수를 돌려준다. beds.ts가 g.injured를 읽는 자리를 명부로 바꾸기 전까지는 부르는 곳이 없다.
 */
export function rebalanceBeds(g: Game): number {
  const sick = g.dom?.bedOrder === 'workers' ? 0 : typhusInBeds(g);
  const room = Math.max(0, D.beds - sick);
  const order = g.dom?.bedOrder ?? null;
  const cand = book(g).filter(w => w.state === 'bed' || w.state === 'home');
  const stay = [...cand].sort((a, b) => {
    if (order === 'workers') return workerRank(g, b) - workerRank(g, a) || a.at - b.at || a.id - b.id;
    if (order === 'sick') return b.daysLeft - a.daysLeft || a.at - b.at || a.id - b.id;
    return a.at - b.at || a.id - b.id;
  }).slice(0, room);
  let moved = 0;
  for (const w of cand) {
    const goesBed = stay.includes(w);
    if (goesBed && w.state === 'home') { w.state = 'bed'; moved += 1; }
    else if (!goesBed && w.state === 'bed') { w.state = 'home'; w.daysLeft += 1; moved += 1; }
  }
  syncInjured(g);
  return moved;
}

// ---- 옛 저장 ----
/** 옛 저장(wounds 칸 없음)을 g.injured만큼의 deep 기록으로 옮긴다(1.3). 판 난수는 쓰지 않는다. 이미 있으면 아무 일도 안 한다. */
export function migrateWounds(g: Game): void {
  if ((g as G).wounds) return;
  (g as G).wounds = [];
  (g as G).nextWoundId = 1;
  const n = Math.max(0, Math.floor(g.injured));
  const local = hashRng(`${g.seed}:wounds:${g.seg}`);
  for (const p of pickVictims(g, n, 'wound', local)) {
    const w: Wound = {
      id: (g as G).nextWoundId!, who: p.name, comm: p.community, grade: 'deep', part: 'torso', from: 'stop', where: '옛 기록',
      septic: false, daysLeft: 3, days0: 3, bedDays: 2, state: 'bed', at: g.seg,
    };
    (g as G).nextWoundId = w.id + 1;
    (g as G).wounds!.push(w);
  }
  syncInjured(g);
}
