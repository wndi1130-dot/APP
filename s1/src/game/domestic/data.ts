import type { Comm } from '../data';

// S1c 내정의 수치와 데이터. 출처는 docs/design/briefs/s1c_domestic.md(장 번호를 줄마다 단다).
// 숫자는 모두 제안이다. S1c 시뮬레이션(tools/s1c_sim.ts) 뒤 고친 값은 줄 끝에 '시뮬 뒤'로 적고,
// 고친 까닭은 docs/design/briefs/s1c_build_notes.md에 있다. 문장은 자리표시다(나중에 Gemini 문장으로 바꾼다).

/** 지식 분야 다섯(8.1). 기술 가지와 하나씩 짝이 된다. */
export const FIELDS = ['engine', 'med', 'craft', 'radio', 'expedition'] as const;
export type Field = typeof FIELDS[number];
export const FIELD_NAME: Record<Field, string> = { engine: '기관', med: '의료', craft: '공작', radio: '통신', expedition: '원정' };
export const BRANCH_NAME: Record<Field, string> = {
  engine: '증기·기관', med: '생존·의료', craft: '공작·무기', radio: '통신·정보', expedition: '원정·파견',
};
export const SKILL_NAME = ['없음', '견습', '숙련', '장인'] as const;

/** 시뮬레이터가 값을 바꿔 볼 수 있게 얼리지 않는다. 게임 코드는 읽기만 한다. */
export const D = {
  // 6.1 공방 작업량
  work: 4, workSkill: [0.5, 0.75, 1, 1.25], w1Work: 1.25, teachWork: 0.85,
  // 6.2 일 목록
  partWork: 1, partScrap: 2, partWood: 1,
  restoreWork: [3, 3, 6, 12], restoreParts: [0, 2, 4, 8], restoreFrags: [0, 1, 2, 3], defectFrags: [0, 1, 1, 2],
  adaptWork: 3, finishWork: 2,
  insulateWork: 3, insulateWood: 8, insulateWarm: 10,
  armorWork: 4, armorScrap: 12, armorExposure: 10,
  convertWork: 6, convertMaterials: 20,
  repairWork: 1, repairParts: 2,
  // 6.3 목표치
  target0: 5, targetMax: 10,
  // 5.3 시작값
  scrap0: 10, wood0: 10, parts0: 4,
  // 4.1 창고·냉동칸
  storeCap: 40, coldCap: 6, coldCapM3b: 3,
  // 4.2 14번째 칸부터
  extraCarCoal: 0.4,
  // 4.4 쓸 만한 칸(화물역 정차)
  wagonChance: 0.12, coachChance: 0.08, coachCrowd: 15,
  // 6.5 고장
  breakChance: 0.1, breakPerDefect: 0.03, breakSegs: 3,
  // 7.2 결함판
  defectMult: 0.5, defectBreak: 0.03,
  // 7.5 복원을 마치면(싫어하는 쪽이 없는 기술은 관계를 주지 않는다, 기획 점검 03)
  techRel: 5,
  // 6.5 고장: 부품이 이만큼 있으면 저절로 고친다
  autoRepairParts: 2,
  // 4.1 의무칸 침상, 넘치면 한 명마다 기술·의무진 과밀 +5. 10장 11번 '누가 침상에 눕나'
  beds: 6, bedCrowd: 5, bedWorkersRel: 2, bedSickHeal: 0.4, bedRotaCrowd: 5,
  // 4.1 냉동칸 '묻고 간다'(길게 머무는 정차): 산출 ×0.85, 한 번에 3구, 의무진·앞칸·꼬리칸 +1
  buryHaul: 0.85, buryMax: 3, buryRel: 1,
  // 4.5 칸 순서 바꾸기: 칸마다 석탄 0.5, 한 번에 셋, 앞으로 한 구역 +5, 뒤로 −8
  moveCoal: 0.5, moveMax: 3, moveUpRel: 5, moveDownRel: -8,
  // 10장 10번 창고가 넘친다: 목표치 +3, 통로에 쌓으면 꼬리칸 과밀 +5
  fullTarget: 3, fullCrowd: 5,
  // 8.2 지식
  knowledgeLow: 0.7, countdown: 4,
  // 8.3 견습: 없음→견습 2, 견습→숙련 4, 숙련→장인 6
  learnSegs: [2, 4, 6], teachMult: 0.85, distributeRel: -10, guildRel: 3,
  // 8.4 매뉴얼: 쓰는 데 3구간, 읽기 없음→견습 3, 견습→숙련 4
  writeSegs: 3, writeMult: 0.85, readSegs: [3, 4], manualLoss: 0.05, engineManualRel: -10,
  // 8.6 대체 불가 요구
  demandEvery: 6, demandRel: 3, demandFair: -3, sabotageMult: 0.8, sabotageSegs: 3, leaveChance: 0.1, grantFood: 0.5, grantSegs: 6,
  // 8.7 파업과의 연결
  stokerExposure: 5, stokerCoal: 2, stokerEngineRel: -5, slowCoal: 3, pressureChance: 0.3, ventCoal: 1,
  strikeRelManual: -30,
  // 8.8 전문가 데려가기
  escortCore: 2, escortInjury: 0.8, escortMaterials: 1.5, escortFrag: 0.2, escortRisk: 0.8,
  // 9.1 법 20
  dutyMult: 0.9,
  // 16.2 더운물(16.9): 레버 1~3(드물게·보통·넉넉), 석탄 = max(0, 레버 − 1) × 인구/40 × 0.1. '드물게'는 공짜
  hotWater0: 1, hotWaterCoal: 0.1, bathRotaCoal: 1.2, handsFirstCoal: 0.8, e2HotWater: 0.8,
  // 16.3 이 확률
  // 불결 관계 벌은 이가 도는 칸만, 이가 사라진 칸은 3구간 면역(16.9)
  liceNormal: 0.03, liceDirty: 0.1, liceWinter: 1.5, dirtyRel: 1, liceImmune: 3,
  // 16.5 이와 발진티푸스
  boilCoal: 2, beddingWarm: 10, beddingSegs: 2, endureSegs: 3, typhusFromLice: 0.4, typhusFromLiceM5: 0.25,
  typhusPatients: 4, typhusMed: 0.5, typhusDeath: 0.15, typhusDeathM1: 0.1, typhusSpread: 0.2, typhusSpreadCrowd: 70,
  typhusRecover: 0.4, quarantineRel: -15, quarantineFear: 5,
  // 6.4 맡기기(S1c 시험판 인구 기준은 시작 인구 + 5)
  delegatePop: 5, delegateAfter: 6,
};

// ---- 장소 부산물(5.2) ----
export interface Byproduct { scrap: number; wood: number; frag: number; branches: Field[] | 'any'; core: number }
export const BYPRODUCT: Record<string, Byproduct> = {
  freight: { scrap: 4, wood: 2, frag: 0.3, branches: ['engine', 'expedition'], core: 0.15 },
  houses: { scrap: 1, wood: 5, frag: 0.15, branches: ['med', 'expedition'], core: 0 },
  hospital: { scrap: 2, wood: 1, frag: 0.4, branches: ['med'], core: 0 },
  factory: { scrap: 6, wood: 1, frag: 0.4, branches: ['craft', 'engine'], core: 0.15 },
  church: { scrap: 1, wood: 3, frag: 0.05, branches: 'any', core: 0 },
  office: { scrap: 1, wood: 3, frag: 0.4, branches: ['radio'], core: 0 },
};

// ---- 기술 19개(7.3) ----
export type TechId =
  | 'e1' | 'e2' | 'e3' | 'e4' | 'e5' | 'm1' | 'm2' | 'm3' | 'm4' | 'm5'
  | 'w1' | 'w2' | 'w3' | 'r1' | 'r2' | 'r3' | 'x1' | 'x2' | 'x3';
export type Variant = 'a' | 'b';
export interface Upkeep { parts?: number; coal?: number; wood?: number; scrap?: number }
export interface VariantDef {
  name: string;
  effect: string;
  upkeep: Upkeep;
  like: Comm[];
  dislike: Comm[];
  /** 두 갈래 카드의 열차장 말(15자 이름, 40자 말) */
  label: string;
  say: string;
}
export interface TechDef {
  id: TechId;
  branch: Field;
  /** 1 응급 복원, 2 구시대 표준, 3 잃어버린 기술, 0 적응 */
  tier: 0 | 1 | 2 | 3;
  name: string;
  effect: string;
  upkeep: Upkeep;
  like: Comm[];
  dislike: Comm[];
  variants?: Record<Variant, VariantDef>;
  /** 적응 기술의 값(문서 대신 목재·처지) */
  adapt?: { parts: number; wood: number };
}

const T = (def: Omit<TechDef, 'upkeep' | 'like' | 'dislike'> & Partial<TechDef>): TechDef => ({ upkeep: {}, like: [], dislike: [], ...def });

export const TECHS: Record<TechId, TechDef> = {
  e1: T({ id: 'e1', branch: 'engine', tier: 1, name: '누설 막기', effect: '달리기 석탄 −0.5', like: ['engine'] }),
  e2: T({ id: 'e2', branch: 'engine', tier: 2, name: '압력 조절', effect: '달리기 석탄 −1, 더운물 석탄 ×0.8', upkeep: { parts: 0.25 }, like: ['engine', 'front'] }),
  e3: T({
    id: 'e3', branch: 'engine', tier: 2, name: '난방 배관', effect: '변형 둘 중 하나', upkeep: { parts: 0.25 },
    variants: {
      a: { name: '꼬리칸까지', effect: '꼬리칸 온기 +10', upkeep: { parts: 0.25 }, like: ['tail'], dislike: ['front'], label: '꼬리칸까지 놓는다', say: '열은 맨 끝 칸까지 간다!' },
      b: { name: '앞칸 직결', effect: '앞칸 온기 +10, 난방 석탄 −0.3', upkeep: { parts: 0.25 }, like: ['front'], dislike: ['tail'], label: '앞칸에 잇는다', say: '앞이 얼면 열차가 멈춘다. 앞부터 데워라!' },
    },
  }),
  e4: T({ id: 'e4', branch: 'engine', tier: 3, name: '과열 증기', effect: '달리기 석탄 −1.5, 대체 화부의 석탄 벌 없음', upkeep: { parts: 0.5 }, like: ['engine'] }),
  e5: T({ id: 'e5', branch: 'engine', tier: 0, name: '단열 개조', effect: '칸마다 목재 8로 온기 +10', like: ['tail'], dislike: ['engine'], adapt: { parts: 1, wood: 4 } }),
  m1: T({ id: 'm1', branch: 'med', tier: 1, name: '응급 처치', effect: '부상 회복 40% → 50%, 발진티푸스 사망 15% → 10%', like: ['medtech'] }),
  m2: T({ id: 'm2', branch: 'med', tier: 2, name: '환자 분류 기준', effect: '중환자 분류(기준) 법이 열린다', like: ['medtech'], dislike: ['tail'] }),
  m3: T({
    id: 'm3', branch: 'med', tier: 2, name: '식량 보존', effect: '변형 둘 중 하나',
    variants: {
      a: { name: '훈제·염장', effect: '식량 소모 ×0.9, 목재 0.5/구간', upkeep: { wood: 0.5 }, like: ['tail'], dislike: [], label: '훈제로 간다', say: '연기에 걸어라. 나무는 또 주우면 된다!' },
      b: { name: '냉동 보관', effect: '식량 소모 ×0.9, 냉동칸 안치 6 → 3', upkeep: { coal: 0.3 }, like: ['medtech'], dislike: [], label: '냉동칸에 쌓는다', say: '냉동칸은 먹을 것부터 채운다!' },
    },
  }),
  m4: T({ id: 'm4', branch: 'med', tier: 3, name: '온실칸', effect: '칸 하나를 온실로(식량 +1.5~3/구간)', upkeep: { coal: 1, parts: 0.5 }, like: ['tail'] }),
  m5: T({ id: 'm5', branch: 'med', tier: 0, name: '약초와 민간요법', effect: '의약품 소모 ×0.85, 이가 병으로 번질 확률 40% → 25%', like: ['tail'], dislike: ['medtech'], adapt: { parts: 0, wood: 2 } }),
  w1: T({ id: 'w1', branch: 'craft', tier: 1, name: '공구 수리', effect: '공방 작업량 ×1.25', like: ['medtech'] }),
  w2: T({
    id: 'w2', branch: 'craft', tier: 2, name: '사냥과 방어', effect: '변형 둘 중 하나',
    variants: {
      a: { name: '탄약 재장전', effect: '정차 부상·사망 ×0.85, 고철 0.5/구간', upkeep: { scrap: 0.5 }, like: ['guard'], dislike: [], label: '탄약을 다시 만든다', say: '빈 탄피도 줍는다. 한 발도 버리지 마라!' },
      b: { name: '활·석궁', effect: '정차 부상·사망 ×0.9, 길게 머물 때 위험 −10%', upkeep: { wood: 0.3 }, like: ['tail'], dislike: ['guard'], label: '활을 깎는다', say: '조용히 쏘는 게 오래 산다. 활을 깎아라!' },
    },
  }),
  w3: T({ id: 'w3', branch: 'craft', tier: 3, name: '장갑 객차', effect: '장갑 개조가 열린다(칸마다 고철 12). 경비대칸이면 노출 −10', upkeep: { parts: 0.5 }, like: ['guard'], dislike: ['tail'] }),
  r1: T({ id: 'r1', branch: 'radio', tier: 1, name: '단거리 무전', effect: '정차 사망 ×0.85', like: ['guard'] }),
  r2: T({
    id: 'r2', branch: 'radio', tier: 2, name: '무전의 쓰임', effect: '변형 둘 중 하나', upkeep: { parts: 0.25 },
    variants: {
      a: { name: '감청', effect: '회기마다 비밀 확률 +25%', upkeep: { parts: 0.25 }, like: ['guard'], dislike: ['tail'], label: '감청한다', say: '모든 칸의 말을 듣는다. 열차장은 알아야 한다!' },
      b: { name: '열차 방송', effect: '긴장 증가 −1/구간, 공포 +1/구간', upkeep: { parts: 0.25 }, like: ['guard', 'engine'], dislike: ['tail', 'medtech'], label: '방송을 튼다', say: '매일 아침 열차장의 목소리를 듣게 해라!' },
    },
  }),
  r3: T({ id: 'r3', branch: 'radio', tier: 3, name: '장거리 무전', effect: '다음 정차를 미리 알고, 판에 세 번 다른 곳으로 바꾼다', upkeep: { parts: 0.5 }, like: ['medtech'] }),
  x1: T({ id: 'x1', branch: 'expedition', tier: 1, name: '짐 꾸리기·방한 장비', effect: '정차 산출 +10%', like: ['tail'] }),
  x2: T({ id: 'x2', branch: 'expedition', tier: 2, name: '핸드카 정찰', effect: '정차마다 장소 후보가 둘', upkeep: { parts: 0.25 }, like: ['guard'] }),
  x3: T({ id: 'x3', branch: 'expedition', tier: 3, name: '궤도 모터카', effect: '지나쳐도 짧게의 절반을 얻는다(석탄 1)', upkeep: { parts: 0.5 }, like: ['guard'], dislike: ['engine'] }),
};
export const TECH_IDS = Object.keys(TECHS) as TechId[];

/** 아끼기만 하는 기술 다섯: 사용자 답을 기다리는 동안 복원을 막는다(2026-10-07 기획 점검 03, s1c_domestic 1.1 시뮬레이션에서
 * 완주 +10~22%p). 효과 계산(hooks.ts의 SAVING_EFFECTS)과 데이터는 남겨 두어, 답이 오면 이 목록에서 빼기만 하면 켜진다. */
export const PENDING_TECHS: TechId[] = ['e1', 'e2', 'x1', 'm3', 'e5'];
export function techPending(id: TechId): boolean {
  return PENDING_TECHS.includes(id);
}

/** 같은 가지 안의 선행조건(7.1): 2단계는 1단계, 3단계는 2단계 하나. */
export function prereqs(id: TechId): TechId[] {
  const def = TECHS[id];
  if (def.tier <= 1) return [];
  return TECH_IDS.filter(t => TECHS[t].branch === def.branch && TECHS[t].tier === def.tier - 1);
}

/** 그 기술을 새로 복원하는 데 드는 사람의 숙련(7.1). 적응은 없어도 된다. */
export function skillNeed(id: TechId): number {
  return TECHS[id].tier;
}

// ---- 전문가 8명(8.1) ----
export interface SpecialistDef { role: string; field: Field; comm: Comm; skill: number; /** S1a 대표를 겸한다 */ leader?: boolean; ages?: [number, number] }
export const SPECIALISTS: SpecialistDef[] = [
  { role: '수석 기관사', field: 'engine', comm: 'engine', skill: 3, leader: true },
  { role: '견습 화부', field: 'engine', comm: 'engine', skill: 1, ages: [18, 30] },
  { role: '의무장', field: 'med', comm: 'medtech', skill: 3, leader: true },
  { role: '약사', field: 'med', comm: 'front', skill: 1, ages: [25, 50] },
  { role: '공방장', field: 'craft', comm: 'medtech', skill: 2, ages: [30, 60] },
  { role: '용접공', field: 'craft', comm: 'tail', skill: 1, ages: [20, 45] },
  { role: '무전병', field: 'radio', comm: 'guard', skill: 2, ages: [20, 40] },
  { role: '경비대장', field: 'expedition', comm: 'guard', skill: 2, leader: true },
];

// ---- 칸(4.1~4.3) ----
export type Zone = 'front' | 'middle' | 'back';
/** 기본 편성의 구역(4.3). S1c 판에선 dom.cars의 자리로 정한다(zoneOf). */
export const ZONE0: Record<string, Zone> = {
  workshop: 'front', front: 'front', captain: 'front', guard: 'middle', dining: 'middle', medtech: 'middle',
  store: 'back', cold: 'back', tail1: 'back', tail2: 'back', tail3: 'back',
};
/** 시작 편성(4.2, 앞 → 뒤, 기관차·탄수차 빼고). 화면 CARS와 같은 칸 id를 쓴다. */
export const CARS0 = ['workshop', 'front', 'captain', 'guard', 'dining', 'medtech', 'store', 'cold', 'tail1', 'tail2', 'tail3'];
export const ZONE_WARM: Record<Zone, number> = { front: 10, middle: 0, back: -10 };
export const ZONE_WORK: Record<Zone, number> = { front: 1, middle: 0.8, back: 0.8 };
export const CAR_COMM: Record<string, Comm> = { tail1: 'tail', tail2: 'tail', tail3: 'tail', medtech: 'medtech', guard: 'guard', front: 'front', engine: 'engine' };
/** 공동체가 사는 칸 수(온기 효과를 칸 수로 나눈다, 4.5) */
export const COMM_CARS: Record<Comm, number> = { tail: 3, medtech: 1, guard: 1, front: 1, engine: 1 };

/** 온실을 들일 때 내줄 수 있는 칸과 산출(4.4 표 그대로). */
export const GREENHOUSE_SLOTS: { car: string; food: number }[] = [
  { car: 'front', food: 3 }, { car: 'store', food: 2.25 }, { car: 'cold', food: 1.5 }, { car: 'tail3', food: 1.5 },
];

// ---- 더운물(16.2) ----
export const HOT_WATER_NAMES = ['없음', '드물게', '보통', '넉넉'] as const;
export const HYGIENE_NAME = { clean: '깨끗', normal: '보통', dirty: '불결' } as const;
export type Hygiene = keyof typeof HYGIENE_NAME;
