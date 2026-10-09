import { COMMS, TRAITS } from '../data';
import type { Comm, Trait } from '../data';
import { addCard, createGame, drawPerson, lawActive, pick, situation } from '../state';
import { hash } from '../omens';
import type { Card, Game } from '../state';
import { CARS0, D, FIELDS, SPECIALISTS, TECHS, ZONE0 } from './data';
import type { Field, TechId, Variant, Zone } from './data';

// S1c 내정 상태. S1a 판(Game)에 dom 하나를 더해 켠다(S1 기획서 19장의 기능 플래그). dom이 없으면 S1a 그대로다.
// 저장할 수 있게 함수 없는 평범한 값만 담는다.

export interface DomPerson {
  id: string;
  name: string;
  age: number;
  comm: Comm;
  field: Field;
  /** 0 없음, 1 견습, 2 숙련, 3 장인 */
  skill: number;
  role: string;
  trait?: Trait;
  alive: boolean;
  /** 열차를 떠났다(거절 뒤 정차에서) */
  gone?: boolean;
  /** 가르치는 견습생 id */
  pupil?: string;
  /** 매뉴얼을 쓰는 중: 남은 구간 */
  writing?: number;
  /** 배우는 중: 가르치는 사람 id 또는 'manual', 남은 구간, 오를 수 있는 끝 */
  learn?: { by: string; left: number; cap: number };
  /** 대체 불가 요구로 받은 '위험 업무 면제' */
  exempt?: boolean;
  /** 요구를 거절당해 다음 정차에서 떠날 수 있다 */
  leaveRisk?: boolean;
  lastDemand?: number;
  /** 늙은 장인 아크에서 쉬는 중(8.9): 가르치지도 쓰이지도 않는다 */
  resting?: boolean;
}

/** 늙은 장인의 마지막(8.9). 판에 한 번뿐이고 enableDomestic이 씨앗으로 정한다(난수 흐름을 건드리지 않는다).
 * stage: 0 조짐 전, 1 첫 조짐, 2 짙은 조짐, 3 끝(쓰러졌거나 그 전에 다른 까닭으로 죽었다). */
export interface ElderArc {
  /** 뽑힌 전문가 id */
  who: string;
  /** 첫 조짐이 뜨는 구간(정산) */
  first: number;
  /** 첫 조짐에서 짙은 조짐까지 구간 수(2~3) */
  gap: number;
  stage: 0 | 1 | 2 | 3;
  /** 짙은 조짐 구간, 쓰러지는 구간(첫 조짐이 뜬 뒤에 정해진다) */
  strong?: number;
  fall?: number;
  /** 첫 조짐 카드에서 고른 것 */
  choice?: 'pupil' | 'manual' | 'rest';
}

export interface TechState {
  stage: 'restoring' | 'defective' | 'done';
  /** 복원을 마치면 결함판이 된다 */
  defect: boolean;
  /** 결함판을 완성판으로 고치는 중 */
  finishing?: boolean;
  variant?: Variant;
  progress: number;
  need: number;
  /** 이번 구간 유지비를 못 냈다(결함판 효과로 돈다, 7.4) */
  starved?: boolean;
  /** 돌릴 수 없어 세워 뒀다(카드 4) */
  off?: boolean;
  /** E3 난방 배관: 의회 추인을 기다린다. 추인 전엔 복원을 마쳐도 완성되지 않는다(7.3) */
  pending?: boolean;
}

export type ModKind = 'insulate' | 'armor' | 'convert';
export interface ModJob { kind: ModKind; car: string; progress: number; need: number }
export type Task = 'parts' | 'restore' | 'modify';
export type Penalty = { kind: 'coal' | 'haul'; until: number };

/** ms: 내정 화면이 열려 있던 시간. all: 화면과 상관없이 그 구간에 앱을 보고 있던 시간(12.1 구간 전체, 참고 값).
 * crisis: 그 구간에 위기(석탄·식량 바닥 등)가 걸려 있었다. 옛 저장 판에는 all·crisis가 없다. */
export interface H6Seg { ms: number; ops: number; cards: number; all?: number; crisis?: boolean }

export interface DomState {
  scrap: number;
  wood: number;
  parts: number;
  /** 다음 부품까지 쌓인 작업 */
  partWork: number;
  cores: number;
  frags: Record<Field, number>;
  manuals: Record<Field, boolean>;
  /** 부품 유지 목표치(6.3) */
  target: number;
  order: Task[];
  techs: Partial<Record<TechId, TechState>>;
  restoring: TechId | null;
  /** '조각이 맞았다' 카드를 이미 띄운 기술 */
  offered: TechId[];
  job: ModJob | null;
  insulated: string[];
  armored: string[];
  greenhouse: string | null;
  /** 꼬리 끝에 붙인 칸 */
  extraCars: ('store' | 'coach')[];
  people: DomPerson[];
  nextPersonId: number;
  /** 마지막 사람을 잃은 분야의 남은 구간. 0이면 고장(8.5) */
  countdown: Partial<Record<Field, number>>;
  hotWater: number;
  lice: Partial<Record<Comm, { at: number; endureDue?: number }>>;
  /** 이가 사라진 칸: 이 구간 전까지 이 판정을 건너뛴다(16.9). */
  liceFree?: Partial<Record<Comm, number>>;
  /** 압력 경고 단계(8.7): 0 처음, 1이면 다음이 마지막 경고. */
  pressureStage?: number;
  typhus: { comm: Comm; patients: string[]; apart: boolean; bay: boolean; at: number }[];
  /** 침구를 태운 공동체: 이 구간까지 온기 −10 */
  bedding: Partial<Record<Comm, number>>;
  penalties: Penalty[];
  /** 대체 불가 요구를 거절해 태업 중인 분야: 이 구간까지 */
  sabotage: Partial<Record<Field, number>>;
  /** 가족 특혜: 이 구간까지 식량 +0.5 */
  grants: number[];
  /** 파업 때 삽을 쥔 공동체(8.7) */
  stoker: Comm | null;
  /** 기관 숙련자가 없어 선 열차 */
  stalled: boolean;
  flags: { otherApprentice: boolean; irreplaceable: boolean; lice: boolean };
  /** 이번 정차에 데려간 전문가 id */
  escort: string | null;
  /** 핸드카 정찰(X2)의 두 번째 후보 */
  altPlace: string | null;
  /** 장거리 무전(R3)으로 바꿀 수 있는 남은 횟수 */
  reroutes: number;
  /** 공방장 맡기기(6.4) */
  /** dropped: 지지가 떨어져 꺼진 적이 있다. 다시 켜려면 관계 +20 이상(6.4 조건 2, 켜는 선과 끄는 선이 다르다) */
  delegate: { on: boolean; policy: 'ours' | 'neutral'; dropped?: boolean };
  /** 수리에 쓴 작업(다음 공방 작업에서 뺀다) */
  workDebt: number;
  /** 기술·의무진의 연구 우선권으로 고른 복원 대상(9.2) */
  researchPick: TechId | null;
  /** 기관실의 견습생 선발권(9.2) */
  enginePick: boolean;
  /** 처지에 더하는 값(난방 배관, 침구 태우기, 장갑). situation()이 읽는다. */
  sit: Record<Comm, [number, number, number, number]>;
  /** 칸 순서를 바꾼 구간(그 정차는 '짧게'를 못 고른다, 4.5) */
  movedAt?: number;
  /** 파업 중 대체 화부가 삽을 쥔 구간(8.7) */
  stokingAt?: number;
  /** 의무칸 침상 순서(10장 11번). null이면 아직 안 정했다(침상이 처음 넘칠 때 카드) */
  bedOrder: 'workers' | 'sick' | 'rota' | null;
  /** 창고가 처음 넘칠 때 고른 답이 그 뒤 규칙이 된다(10장 10번) */
  fullRule: 'parts' | 'dump' | 'aisle' | null;
  /** 이번 정차에 냉동칸 시신을 묻고 간다(4.1, 길게 머물 때만) */
  bury: boolean;
  /** 칸 순서(앞 → 뒤, 기관차·탄수차 빼고). 4.3 구역은 자리로 정한다(4.5) */
  cars: string[];
  /** 열차장이 의무칸 침상에 있다. S1a 판엔 열차장 부상이 아직 없어서 아무도 켜지 않는다(6.4, 10장 12번 훅) */
  captainInBed: boolean;
  /** 늙은 장인의 마지막(8.9). 옛 저장 판엔 없다 */
  elder?: ElderArc;
  /** E3 추인이 부결돼 정해진 변형: 이 판에선 그 변형으로 고정된다(취소하고 다시 시작해도 못 바꾼다, 7.3) */
  pipeFlip?: Variant;
  /** 복원을 시작한 기록과 견습생을 붙인 기록(협상 조건 이행을 본다, 9.2) */
  log: { restores: { seg: number; id: TechId }[]; apprentices: { seg: number; field: Field; other: boolean }[] };
  /** H6 재기(12장): 구간별 내정 시간과 조작 수, 내정 카드 선택 기록 */
  h6: { segs: Record<string, H6Seg>; picks: { seg: number; title: string; label: string }[] };
  stats: {
    restored: number; tier3: number; defective: number; breakdowns: number; lice: number; typhus: number;
    hotCoal: number; techCoal: number; apprentices: number; manuals: number; demands: number; partsMade: number;
    repairs: number; buried: number; moves: number;
    /** 판에 쌓인 내정 카드 수(종류별) */
    cards: Record<string, number>;
  };
}

export function hasDom(g: Game): g is Game & { dom: DomState } {
  return !!g.dom;
}

export function zeroSit(): Record<Comm, [number, number, number, number]> {
  return Object.fromEntries(COMMS.map(c => [c, [0, 0, 0, 0]])) as unknown as Record<Comm, [number, number, number, number]>;
}

/** S1a 판에 S1c 내정을 켠다. 전문가 8명을 프로필에서 뽑고, 시작 자재와 조각을 둔다(5.3, 8.1). */
export function enableDomestic(g: Game): void {
  const people: DomPerson[] = [];
  SPECIALISTS.forEach((def, i) => {
    const leader = def.leader ? g.comms[def.comm].leader : null;
    const person = leader ? { name: leader.name, age: leader.age } : drawPerson(g, def.comm, def.ages);
    people.push({
      id: `sp${i + 1}`, name: person.name, age: person.age, comm: def.comm, field: def.field, skill: def.skill, role: def.role,
      trait: leader ? leader.trait : pick(g, TRAITS), alive: true,
    });
  });
  // 용접공은 공방장의 견습으로 시작한다(8.1): 견습 → 숙련 4구간, 숙련 → 장인 6구간. 그동안 공방은 가르치느라 느리다(J10 7번).
  const chief = people.find(p => p.role === '공방장');
  const welder = people.find(p => p.role === '용접공');
  if (chief && welder) {
    welder.learn = { by: chief.id, left: D.learnSegs[welder.skill], cap: chief.skill };
    chief.pupil = welder.id;
  }
  g.dom = {
    scrap: D.scrap0, wood: D.wood0, parts: D.parts0, partWork: 0, cores: 0,
    frags: { engine: 1, med: 1, craft: 0, radio: 0, expedition: 0 },
    manuals: { engine: false, med: false, craft: false, radio: false, expedition: false },
    target: D.target0, order: ['parts', 'restore', 'modify'], techs: {}, restoring: null, offered: [], job: null,
    insulated: [], armored: [], greenhouse: null, extraCars: [],
    people, nextPersonId: people.length + 1, countdown: {}, hotWater: D.hotWater0, lice: {}, typhus: [], bedding: {},
    penalties: [], sabotage: {}, grants: [], stoker: null, stalled: false,
    flags: { otherApprentice: false, irreplaceable: false, lice: false },
    escort: null, altPlace: null, reroutes: 3, delegate: { on: false, policy: 'neutral' }, workDebt: 0,
    researchPick: null, enginePick: false, sit: zeroSit(), h6: { segs: {}, picks: [] },
    bedOrder: null, fullRule: null, bury: false, cars: [...CARS0], captainInBed: false, log: { restores: [], apprentices: [] },
    stats: {
      restored: 0, tier3: 0, defective: 0, breakdowns: 0, lice: 0, typhus: 0, hotCoal: 0, techCoal: 0, apprentices: 0, manuals: 0, demands: 0,
      partsMade: 0, repairs: 0, buried: 0, moves: 0, cards: {},
    },
  };
  g.dom.elder = pickElder(g, people);
}

/** 늙은 장인의 마지막(8.9): 수석 기관사, 의무장, 공방장 가운데 하나를 같은 확률로 고른다. 판 씨앗으로 정해 난수 흐름은 건드리지 않는다(hub.ts와 같다).
 * 의무장이 뽑히면 나이를 60 이상으로 뽑는다(대표 나이도 같이 맞춘다). */
function pickElder(g: Game, people: DomPerson[]): ElderArc {
  const h = (k: string): number => hash(`${g.seed}|elder|${k}`);
  const pool = ['수석 기관사', '의무장', '공방장'].map(role => people.find(p => p.role === role)).filter((p): p is DomPerson => !!p);
  const who = pool[h('who') % pool.length];
  if (who.role === '의무장' && who.age < D.elderMedAge[0]) {
    who.age = D.elderMedAge[0] + (h('age') % (D.elderMedAge[1] - D.elderMedAge[0] + 1));
    g.comms[who.comm].leader.age = who.age;
  }
  const [f0, f1] = D.elderFirst;
  const [g0, g1] = D.elderGap;
  return { who: who.id, first: f0 + (h('first') % (f1 - f0 + 1)), gap: g0 + (h('gap') % (g1 - g0 + 1)), stage: 0 };
}

/** S1c를 켠 새 판. */
export function createS1cGame(seed = 's1c'): Game {
  const g = createGame(seed);
  enableDomestic(g);
  g.journal.push({ seg: g.seg, text: '공방칸, 창고칸, 냉동칸을 달았다. 전문가 여덟이 탔다.' });
  return g;
}

/** 예전 저장 판에 없던 칸을 채운다(app.ts load에서 부른다). */
export function migrateDomestic(g: Game): void {
  const d = g.dom;
  if (!d) return;
  d.h6 ??= { segs: {}, picks: [] };
  d.sit ??= zeroSit();
  d.penalties ??= [];
  d.grants ??= [];
  d.extraCars ??= [];
  d.bedOrder ??= null;
  d.fullRule ??= null;
  d.bury ??= false;
  d.cars ??= [...CARS0];
  d.captainInBed ??= false;
  d.log ??= { restores: [], apprentices: [] };
  d.stats.cards ??= {};
  d.stats.repairs ??= 0;
  d.stats.buried ??= 0;
  d.stats.moves ??= 0;
  // 옛 '그 칸을 닫는다'(격리)는 뺐다(16.5). 그 판의 환자는 '따로 눕힌다'로 이어 간다.
  for (const t of d.typhus as (DomState['typhus'][number] & { quarantined?: boolean })[]) {
    t.apart ??= t.quarantined ?? false;
    delete t.quarantined;
  }
}

/** 내정 카드를 서류 뭉치에 쌓고 판당 장 수를 센다. */
export function domCard(g: Game, card: Omit<Card, 'uid'>): void {
  const d = g.dom;
  if (d) d.stats.cards[card.kind] = (d.stats.cards[card.kind] ?? 0) + 1;
  addCard(g, card);
}

// ---- 사람 ----
export function living(g: Game): DomPerson[] {
  return (g.dom?.people ?? []).filter(p => p.alive && !p.gone);
}

/** 그 분야를 아는 사람(견습 이상). */
export function knowers(g: Game, f: Field): DomPerson[] {
  return living(g).filter(p => p.field === f && p.skill >= 1);
}

export function topSkill(g: Game, f: Field): number {
  return knowers(g, f).reduce((m, p) => Math.max(m, p.skill), 0);
}

export function personById(g: Game, id: string | null | undefined): DomPerson | undefined {
  return id ? g.dom?.people.find(p => p.id === id) : undefined;
}

// ---- 기술 효과 ----
export function techUsable(g: Game, id: TechId): boolean {
  const st = g.dom?.techs[id];
  return !!st && (st.stage === 'done' || st.stage === 'defective');
}

/** 분야의 지식이 그 단계 기술을 받치는 정도(8.2). 화면엔 숫자 대신 줄 색과 '×0.7'로만 보인다. */
/** 3단계의 둘째 길(7.1): 그 분야 숙련 + 살아 있는 공작 장인(공방장). 공작 가지는 자기 장인이 있어야 한다. */
export function secondPath(g: Game, id: TechId): boolean {
  const def = TECHS[id];
  return def.tier === 3 && def.branch !== 'craft' && topSkill(g, def.branch) >= 2 && topSkill(g, 'craft') >= 3;
}

export function knowledgeMult(g: Game, f: Field, tier: number): number {
  if (tier === 0) return 1;
  const top = topSkill(g, f);
  if (top >= 3) return 1;
  // 둘째 길: 공작 장인이 살아 있는 동안 ×1.0, 잃으면 8.2대로 ×0.7.
  if (top === 2) return tier === 3 && topSkill(g, 'craft') < 3 ? D.knowledgeLow : 1;
  if (top === 1) return tier >= 2 ? D.knowledgeLow : 1;
  if (g.dom?.manuals[f]) return D.knowledgeLow;
  const cd = g.dom?.countdown[f];
  return cd !== undefined && cd > 0 ? D.knowledgeLow : 0;
}

/** 늙은 장인이 견습을 서두르거나(×0.7) 쉬는(×0.85) 동안 그 사람의 분야 기술에 걸리는 곱(8.9). 조짐이 뜬 뒤 쓰러질 때까지. */
export function elderMult(g: Game, f: Field): number {
  const a = g.dom?.elder;
  if (!a || (a.stage !== 1 && a.stage !== 2) || !a.choice) return 1;
  const p = personById(g, a.who);
  if (!p || !p.alive || p.gone || p.field !== f) return 1;
  return a.choice === 'pupil' ? D.elderPupilMult : a.choice === 'rest' ? D.elderRestMult : 1;
}

/** 그 분야 기술 전체에 걸리는 곱(가르치기, 매뉴얼 쓰기, 견습 의무법, 태업). */
export function fieldMult(g: Game, f: Field): number {
  const d = g.dom;
  if (!d) return 0;
  let m = 1;
  // 늙은 장인이 견습을 서두르거나 쉬는 동안은 그 곱이 가르치기·쓰기 곱을 대신한다(8.9).
  const elder = elderMult(g, f);
  const skip = elder !== 1 ? d.elder?.who : undefined;
  if (living(g).some(p => p.field === f && p.pupil && !p.resting && p.id !== skip)) m *= D.teachMult;
  if (living(g).some(p => p.field === f && (p.writing ?? 0) > 0 && p.id !== skip)) m *= D.writeMult;
  m *= elder;
  if (lawActive(g, 'apprentice_duty')) m *= D.dutyMult;
  if ((d.sabotage[f] ?? -1) >= g.seg) m *= D.sabotageMult;
  return m;
}

/** 기술 효과의 세기(0~1). 완성판 1, 결함판 0.5, 유지비를 못 내면 0.5까지, 지식과 분야 곱을 받는다. */
export function techMult(g: Game, id: TechId): number {
  const st = g.dom?.techs[id];
  if (!st || st.off || !(st.stage === 'done' || st.stage === 'defective')) return 0;
  const def = TECHS[id];
  let m = st.stage === 'defective' ? D.defectMult : 1;
  if (st.starved) m = Math.min(m, D.defectMult);
  return m * knowledgeMult(g, def.branch, def.tier) * fieldMult(g, def.branch);
}

export function variantOf(g: Game, id: TechId): Variant | undefined {
  return g.dom?.techs[id]?.variant;
}

/** 변형 기술의 그 변형 세기. */
export function variantMult(g: Game, id: TechId, v: Variant): number {
  return variantOf(g, id) === v ? techMult(g, id) : 0;
}

/** 공방이 선 구역(칸 순서가 바뀌면 달라진다, 4.3). */
export function zoneOf(g: Game, car: string): Zone {
  const cars = g.dom?.cars;
  if (!cars) return ZONE0[car] ?? 'front';
  const i = cars.indexOf(car);
  return i < 0 ? 'back' : zoneAt(i);
}

/** 앞에서 몇 번째 칸이 어느 구역인가(4.3: 공방칸~열차장실 앞, 경비대칸~의무칸 가운데, 그 뒤는 뒤). */
export function zoneAt(i: number): Zone {
  return i < 3 ? 'front' : i < 6 ? 'middle' : 'back';
}

/** 지금 처지의 온기(S1a situation 그대로, 보정 포함). */
export function warmth(g: Game, c: Comm): number {
  return situation(g, c)[0];
}

export const ALL_FIELDS = FIELDS;
