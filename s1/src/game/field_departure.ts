import { createRng, nextRandom } from '../core/rng';
import { COMMS } from './data';
import type { Comm } from './data';
import { living } from './domestic/state';
import { PROFILES } from './state';
import type { Game, LootDeck } from './state';
import { crewNames, stopCrew } from './turn';
import { CAPTAIN, isActive } from './wounds';
import type { Wound, WoundBook, WoundGrade, WoundPart, WoundState } from './wounds';
import { CAPTAIN_ID } from './field_receipt';
import type { FieldPromiseSpec, FieldReturnRecord } from './field_receipt';
import { departureMemory } from './memory';
import { arrivalMin } from './stop_time';
import { pickWeather } from './omens';
import type { Weather } from './omens';
import { routeWeather } from './route_weather';
import { rainAt } from './season';

// S3 출발 계약 판 2(docs/design/briefs/s3_departure_receipt_contract.md 2절). 열차가 정차 고르기에서 「내리기」를 누를 때
// 판 상태에서 한 장 만든다. 판 1(field_receipt.ts FieldDeparture)의 칸은 그대로 두고 사람 칸을 넓힌다.
// 판을 바꾸지 않고 판 난수도 쓰지 않는다(몸 능력의 흔들림은 사람 id로 정해진 값). Godot은 politics/field_departure.gd가 같은 값을 낸다.

export { CAPTAIN_ID };
const CAPTAIN_COMM: Comm = 'front';

export const BODY_SKILLS = ['strength', 'melee', 'shooting', 'stealth', 'search'] as const;
export type BodySkill = typeof BODY_SKILLS[number];
export type Body = Record<BodySkill, number>;
export type Level = 0 | 1 | 2;
export type DepartureRole = 'chief' | 'companion' | 'carrier' | 'escort';

export interface DepartureWound { woundId: number; part: WoundPart; grade: WoundGrade; state: WoundState; daysLeft: number; septic: boolean }
/** 무기 [id, 질, 상태], 가방 속 {id: 개수}, 옷(필드 wear.gd 자리 이름 → 옷 id, 비면 다들 입는 것), 가방 종류. */
export interface DepartureGear { hands: [string, string, number][]; items: Record<string, number>; wear: Record<string, string>; bag: string }
export interface DeparturePerson {
  id: string;
  comm: Comm;
  name: string;
  role: DepartureRole;
  /** 몸 능력 0~10(결정 카드 A, 2026-10-25 사용자 답) */
  body: Body;
  /** 지식 층: 내정 명부의 분야와 등급(0~3). 내정을 끈 판이나 명부에 없는 사람은 null */
  know: { field: string; skill: number } | null;
  /** 열차 명부의 활성 상처(다친 채 나가는 사람) */
  wounds: DepartureWound[];
  /** 허기·근육통·휴식 0~2(결정 카드 B) */
  hunger: Level;
  sore: Level;
  rest: Level;
  gear: DepartureGear;
  /** 그 칸과 열차장의 관계 */
  rel: number;
  /** 열차장에 대한 그 사람의 기억(사람 기억 줄기가 채운다) */
  stance?: 'good' | 'bad';
  cues?: string[];
}
export interface FieldDepartureV2 {
  version: 2;
  departureId: string;
  stopId: string;
  placeId: string;
  segment: number;
  /** 이 정차에 열차가 닿는 시각(0시부터 분, 결정 471 B0 stop_time.ts). 없던 계약은 10:30 */
  arriveMin?: number;
  /** 갈래별 보장 몫(덱)의 자리(결정 474 S1). 판 상태에 있을 때만, 필드가 이어서 뽑는다 */
  lootDeck?: LootDeck;
  /** 결정 474 N2: 기온 켠 판의 현재 정차와 지난 최대 세 정차(S2 날씨 id). */
  stopWeather?: StopWeather;
  pastWeather?: { seg: number; weather: StopWeather }[];
  /** 생필품(결정 490)을 켠 판인가. 이 칸이 없는 옛 계약이면 필드는 지금처럼 늘 차린다 */
  supplies?: boolean;
  /** 처음부터 나가는 수색대: 열차장과 동료 */
  roster: DeparturePerson[];
  /** 작업조 부르기로 내려올 수 있는 사람: 운송조(S1 정차의 작업조)와 호위조(경비대 둘) */
  workCrew: DeparturePerson[];
  promises: FieldPromiseSpec[];
  domestic: boolean;
  /** 정차 전체에 걸리는 열차 사정 */
  train: { food: number; hungerSegs: number; /** 열차가 둔 썰매(S2 열차만, 계약 글 2절). S1은 싣지 않는다 */ sleds?: number };
}

export type StopWeather = Exclude<Weather, 'cold' | 'cold_front'> | 'rain';

function stopWeatherId(weather: Weather, seg: number): StopWeather {
  if (weather === 'sleet' && rainAt(seg)) return 'rain';
  if (weather === 'cold' || weather === 'cold_front') return 'clear';
  return weather;
}

// ---- 몸 능력(카드 A: 나이·칸 바탕 + 사람마다 정해진 ±1) ----
const CAPTAIN_BODY: Body = { strength: 5, melee: 3, shooting: 2, stealth: 2, search: 2 };
const COMM_BODY: Record<Comm, Partial<Body>> = {
  guard: { melee: 1, shooting: 1 }, engine: { strength: 1 }, tail: { search: 1 }, medtech: { stealth: 1 }, front: {},
};

function ageStrength(age: number): number {
  return age <= 25 ? 6 : age <= 45 ? 5 : 4;
}

/** 그 사람 id와 능력 이름으로 정해진 −1·0·+1. */
function jitter(id: string, skill: BodySkill): number {
  return Math.floor(nextRandom(createRng(`${id}:body:${skill}`)).value * 3) - 1;
}

export function bodyOf(id: string, age: number, comm: Comm): Body {
  if (id === CAPTAIN_ID) return { ...CAPTAIN_BODY };
  const base: Body = { strength: ageStrength(age), melee: 1, shooting: 1, stealth: 1, search: 1 };
  const out = {} as Body;
  for (const k of BODY_SKILLS) out[k] = Math.max(0, Math.min(10, base[k] + (COMM_BODY[comm][k] ?? 0) + jitter(id, k)));
  return out;
}

// ---- 허기·근육통·휴식(카드 B) ----
/** 허기: 그 칸 배급 레버가 보통(2)보다 한 칸 아래면 1, 두 칸이면 2. 열차가 굶은 구간이 1 이상이면 최소 1, 3 이상이면 2. */
export function hungerOf(g: Game, comm: Comm): Level {
  const lever = g.comms[comm].ration - 2;
  const byRation = lever <= -2 ? 2 : lever <= -1 ? 1 : 0;
  const segs = g.hunger ?? 0;
  const byFood = segs >= 3 ? 2 : segs >= 1 ? 1 : 0;
  return Math.max(byRation, byFood) as Level;
}

/** 근육통: 바로 앞 귀환에 나갔으면 1, 앞 두 귀환에 잇달아 나갔으면 2. */
export function soreOf(g: Game, id: string): Level {
  const recs = g.fieldReturns?.records ?? [];
  const went = (r: FieldReturnRecord | undefined) => !!r?.sent?.includes(id);
  if (!went(recs[recs.length - 1])) return 0;
  return went(recs[recs.length - 2]) ? 2 : 1;
}

/** 휴식: 근육통과 같되, 바로 앞 귀환에서 지쳐 돌아왔으면 그 탈진 단계까지. */
export function restOf(g: Game, id: string): Level {
  const last = g.fieldReturns?.records.at(-1);
  const tired = last?.crew?.find(x => x.person === id)?.exhaustion ?? 0;
  return Math.max(soreOf(g, id), tired) as Level;
}

// ---- 장비(장부 한 곳: 출발 때 열차 재고에서 빼지 않는다. 고르는 화면은 파밍 손맛 줄기 몫, 그 전엔 역할별 기본) ----
const CHIEF_GEAR: DepartureGear = { hands: [['axe', 'factory', 0.9], ['pistol', 'factory', 0.8]], items: { bandage: 2, cloth: 1 }, wear: {}, bag: 'pack' };
const COMPANION_GEAR: Record<Comm, DepartureGear> = {
  guard: { hands: [['pipe_shotgun', 'crude', 0.9], ['knife', 'factory', 0.8]], items: { bandage: 1 }, wear: {}, bag: 'pack' },
  medtech: { hands: [['bow', 'factory', 0.9], ['crowbar', 'factory', 0.9]], items: { bandage: 3, medkit: 1, tweezers: 1, needle_thread: 3 }, wear: {}, bag: 'pack' },
  tail: { hands: [['crowbar', 'factory', 0.8], ['knife', 'factory', 0.7]], items: { bandage: 1 }, wear: {}, bag: 'big_pack' },
  engine: { hands: [['crowbar', 'factory', 0.8], ['knife', 'factory', 0.7]], items: { bandage: 1 }, wear: {}, bag: 'pack' },
  front: { hands: [['crowbar', 'factory', 0.8], ['knife', 'factory', 0.7]], items: { bandage: 1 }, wear: {}, bag: 'pack' },
};
const CARRIER_GEAR: DepartureGear = { hands: [], items: {}, wear: {}, bag: 'pack' };
const ESCORT_GEAR: DepartureGear[] = [
  { hands: [['shotgun', 'factory', 0.8], ['crowbar', 'factory', 0.9]], items: {}, wear: {}, bag: 'pack' },
  { hands: [['axe', 'factory', 0.9]], items: {}, wear: {}, bag: 'pack' },
];
const copyGear = (x: DepartureGear): DepartureGear => ({ hands: x.hands.map(h => [...h] as [string, string, number]), items: { ...x.items }, wear: { ...x.wear }, bag: x.bag });

// ---- 사람 한 명 ----
function woundsOf(g: Game, name: string): DepartureWound[] {
  // 명부를 읽기만 한다(activeWounds는 빈 명부를 만든다).
  return ((g as Game & WoundBook).wounds ?? []).filter((w: Wound) => w.who === name && isActive(w)).map(w => ({ woundId: w.id, part: w.part, grade: w.grade, state: w.state, daysLeft: w.daysLeft, septic: w.septic }));
}

function knowOf(g: Game, name: string): DeparturePerson['know'] {
  const p = living(g).find(x => x.name === name);
  return p ? { field: p.field, skill: p.skill } : null;
}

export function departurePerson(g: Game, id: string, role: DepartureRole, gear: DepartureGear): DeparturePerson {
  const prof = PROFILES.find(p => p.id === id);
  const name = id === CAPTAIN_ID ? CAPTAIN : prof?.name ?? id;
  const comm = id === CAPTAIN_ID ? CAPTAIN_COMM : prof?.community ?? 'tail';
  return {
    id, comm, name, role, body: bodyOf(id, prof?.age ?? 40, comm), know: knowOf(g, name), wounds: woundsOf(g, name),
    hunger: hungerOf(g, comm), sore: soreOf(g, id), rest: restOf(g, id), gear: copyGear(gear), rel: id === CAPTAIN_ID ? 0 : g.comms[comm].rel,
    ...departureMemory(g, id),
  };
}

const idOfName = (name: string): string | undefined => PROFILES.find(p => p.name === name)?.id;

/** 동료 기본: 칸마다 한 사람(지금 기본 분대의 칸 구성), S1 작업조와 같은 거름을 지난 사람 가운데 그 구간의 차례대로. */
export const COMPANION_COMMS: readonly Comm[] = ['guard', 'medtech', 'tail'];

/** 그 구간에 동료로 나갈 수 있는 사람(프로필 id): S1 crewNames 거름(16~65세, 정찰조·앓는 대표·근신·경비·깊은 상처 이상 제외). */
export function companionCandidates(g: Game, comm: Comm): string[] {
  return crewNames(g, comm, PROFILES.length).map(idOfName).filter((x): x is string => !!x);
}

export interface DepartureOpts {
  /** 필드 지도의 장소 id(영수증 place.id와 같아야 한다) */
  placeId: string;
  /** 고른 동료(프로필 id). 없으면 COMPANION_COMMS 차례로 한 사람씩 */
  companions?: string[];
}

/** 출발 약속: 그 칸에 걸린 교대 약속(다음 파견에서 제외). 서막 약속은 필드에 데려올 사람이 서야 판정되므로 지금은 싣지 않는다. */
export function departurePromises(g: Game): FieldPromiseSpec[] {
  const out: FieldPromiseSpec[] = [];
  for (const c of COMMS) {
    const p = g.comms[c].promise;
    if (p && p.kind !== 'fetch' && p.cond.kind === 'skip_dispatch') out.push({ id: `promise_skip_${c}`, kind: 'skip_dispatch', madeTo: c, label: '다음 파견에서 제외', subjects: [] });
  }
  return out;
}

export function buildDeparture(g: Game, opts: DepartureOpts): FieldDepartureV2 {
  const seg = g.seg;
  const taken = new Set<string>();
  const carriers = stopCrew(g).map(idOfName).filter((x): x is string => !!x);
  for (const id of carriers) taken.add(id);
  const companions: string[] = [];
  if (opts.companions) {
    for (const id of opts.companions) if (!taken.has(id)) { companions.push(id); taken.add(id); }
  } else {
    for (const c of COMPANION_COMMS) {
      const id = companionCandidates(g, c).find(x => !taken.has(x));
      if (id) { companions.push(id); taken.add(id); }
    }
  }
  const escorts = companionCandidates(g, 'guard').filter(x => !taken.has(x)).slice(0, ESCORT_GEAR.length);
  const roster = [
    departurePerson(g, CAPTAIN_ID, 'chief', CHIEF_GEAR),
    ...companions.map(id => departurePerson(g, id, 'companion', COMPANION_GEAR[PROFILES.find(p => p.id === id)?.community ?? 'tail'])),
  ];
  const workCrew = [
    ...carriers.map(id => departurePerson(g, id, 'carrier', CARRIER_GEAR)),
    ...escorts.map((id, i) => departurePerson(g, id, 'escort', ESCORT_GEAR[i])),
  ];
  return {
    version: 2, departureId: `dep_${opts.placeId}_${seg}`, stopId: `stop_${opts.placeId}_${seg}`, placeId: opts.placeId, segment: seg,
    arriveMin: arrivalMin(g.seed, seg), ...(g.lootDeck ? { lootDeck: structuredClone(g.lootDeck) } : {}), roster, workCrew, promises: departurePromises(g), domestic: !!g.dom, train: { food: g.food, hungerSegs: g.hunger ?? 0 },
    supplies: !!g.supOn,
    ...(g.climate ? {
      stopWeather: stopWeatherId(g.stop?.weather ?? pickWeather(g), seg),
      pastWeather: Array.from({ length: Math.min(3, seg - 1) }, (_, i) => {
        const past = Math.max(1, seg - 3) + i;
        return { seg: past, weather: stopWeatherId(routeWeather(g.seed, past), past) };
      }),
    } : {}),
  };
}
