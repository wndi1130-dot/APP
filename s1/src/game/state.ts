import { createRng, nextRandom } from '../core/rng';
import type { NeedId, NeedState } from './needs';
import type { RngState } from '../core/rng';
import {
  COH0, COMMS, IDEO, P, POP0, REL0, REP_AGE, SECRET_POOL, START, STAGES, TRAIT_BAN, TRAITS,
} from './data';
import type { Comm, ConditionDef, LawId, LootKey, StayId, Trait } from './data';
import profilesJson from '../../data/profiles.json';

// S1a 한 판의 상태. 저장할 수 있게 함수 없는 평범한 값만 담는다.

export type Phase = 'prep' | 'travel' | 'stop' | 'council' | 'settle' | 'end';
export type EndKind = 'complete' | 'stranded' | 'ousted' | 'revolt';

export interface Profile { id: string; name: string; age: number; community: Comm; like: string; dislike: string; hometown: string }
export const PROFILES = profilesJson as unknown as Profile[];

export interface Leader {
  personId: string;
  name: string;
  age: number;
  trait: Trait;
  /** 0 가려짐, 1 '아마 ○○', 2 드러남(브리프 3.3) */
  traitShown: 0 | 1 | 2;
}

export interface PromiseState {
  kind: 'open' | 'fetch';
  cond: ConditionDef;
  label: string;
  /** 이 구간의 정산에서 확인한다. 정차 조건은 다음 정차에서 확인한다. */
  due: number;
  /** 레버 조건의 기준값 */
  baseline?: number;
  madeSession: number;
  /** 약속으로 통과시키려던 안건 */
  law?: LawId;
}

export interface CommState {
  base: [number, number, number, number];
  heat: number;
  ration: number;
  rel: number;
  coh: number;
  fervor: number;
  badStreak: number;
  grudge: number;
  lastOffense: number;
  demandCool: number;
  favorCool: number;
  agitateCool: number;
  pop: number;
  away: number;
  debt: boolean;
  leader: Leader;
  promise: PromiseState | null;
  /** 지지·칼질한 구간(번복과 거듭된 칼질을 잡는다) */
  supportedAt: number;
  cutAt: number[];
  /** 한 번 들킨 대표 */
  disgraced: boolean;
}

export interface Secret { id: number; text: string; weight: number; about: Comm; uses: number }
export interface Leash { comm: Comm; since: number; weight: number }

export interface Card { uid: number; kind: string; comm?: Comm; n?: number; who?: string; text?: string }
/** 한 사건을 마지막으로 겪은 때와 고른 것. 같은 사건이 다시 나오면 이걸 보고 본문과 대가를 바꾼다. */
export interface EventMemo { n: number; seg: number; pick: string }

export interface StopState {
  place: string;
  target: LootKey | null;
  stay: StayId;
  crewComm: Comm;
  crewSize: number;
  /** 이번 정차의 바깥 기척(0.8 조용함, 1 보통, 1.4 무리 흔적). 정차 장면 글과 위험 줄에 같이 들어간다. */
  threat?: number;
  done: boolean;
  result: StopResult | null;
}
export interface StopResult {
  passed: boolean;
  gains: Partial<Record<LootKey, number>>;
  injured: string[];
  dead: string[];
  notes: string[];
}

export type DealTool = 'open' | 'favor' | 'fetch' | 'bribe' | 'blackmail';
export interface Deal { comm: Comm; tool: DealTool; label: string }
export interface Agenda { law: LawId; repeal: boolean; by?: Comm; forced?: boolean }

export interface VoteFlip { comm: Comm; yes: boolean }
export interface VoteResult {
  yes: number;
  no: number;
  absent: number;
  need: number;
  passed: boolean;
  byComm: Record<Comm, { yes: number; no: number; absent: number }>;
  /** 개표 연출: 확정표가 먼저 앉고, 미정이 하나씩 갈린다. */
  flips: VoteFlip[];
  decree: boolean;
}

export interface CouncilState {
  options: Agenda[];
  idx: number;
  locked: boolean;
  deals: Deal[];
  result: VoteResult | null;
  /** 회기가 아닌 구간에 열차장이 부른 비상 소집 */
  emergency?: boolean;
}

export interface JournalEntry { seg: number; text: string; tone?: 'good' | 'bad' | 'deal' | 'dark' }

export interface Settlement { coal: number; food: number; med: number; rel: Record<Comm, number>; trust: number; tension: number; notes: string[] }

export interface Game {
  version: 1;
  seed: string;
  rng: RngState;
  seg: number;
  phase: Phase;
  session: number;
  coal: number;
  food: number;
  med: number;
  lux: number;
  trust: number;
  tension: number;
  fear: number;
  injured: number;
  symbols: number;
  comms: Record<Comm, CommState>;
  passed: Partial<Record<LawId, number>>;
  repealedAt: Partial<Record<LawId, number>>;
  boughtBy: Partial<Record<LawId, { comms: Comm[]; session: number }>>;
  secrets: Secret[];
  nextSecretId: number;
  leashes: Leash[];
  blackmails: number;
  corpseIssue: boolean;
  thrown: number;
  stored: number;
  deaths: string[];
  strikes: number;
  inStrike: boolean;
  strikeWarned: number;
  lostSegments: number;
  trustCrisis: number | null;
  tensionWarned: boolean;
  tensionCrisisUsed: number;
  emergencyUsed: boolean;
  guidedLeft: number;
  decreeLeft: number;
  guardEscort: boolean;
  forcedRun: boolean;
  autoLevers: boolean;
  actedSeg: number;
  /** AI가 다음 회기에 올린 안건 */
  proposals: Agenda[];
  /** 안건 선택권을 넘긴 집단 */
  agendaHolder: Comm | null;
  cards: Card[];
  recentEvents: string[];
  /** 사건별 기억(키: 이동 사건 id, 'demand:engine', 'favor:tail', 'rescue', 'bitten' 등) */
  eventLog: Record<string, EventMemo>;
  /** 법 요구: 문제는 있는데 그 문제를 다루는 법이 없다(needs.ts) */
  needs: Partial<Record<NeedId, NeedState>>;
  /** 비상 소집을 부른 구간들 */
  emergencyCalls: number[];
  /** 식량 0으로 버틴 구간 수 */
  hunger: number;
  nextCardUid: number;
  stop: StopState | null;
  council: CouncilState | null;
  lastSettle: Settlement | null;
  journal: JournalEntry[];
  usedProfiles: string[];
  end: EndKind | null;
  stats: { dealsMade: number; promisesKept: number; promisesBroken: number; lawsPassed: number; lawsFailed: number; repeals: number; bribes: number; blackmails: number };
}

// ---- 난수 ----
export function rnd(g: Game): number {
  const next = nextRandom(g.rng);
  g.rng = next.rng;
  return next.value;
}
export function pick<T>(g: Game, items: readonly T[]): T {
  return items[Math.floor(rnd(g) * items.length)];
}
export function clamp(value: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, value));
}

// ---- 읽기 ----
export function stageOf(rel: number): { name: string; band: number; index: number } {
  const index = STAGES.findIndex(stage => rel >= stage.min);
  const stage = STAGES[index === -1 ? STAGES.length - 1 : index];
  return { name: stage.name, band: stage.band, index: index === -1 ? STAGES.length - 1 : index };
}

/** 처지 = 기준 + 레버 차이. [온기, 배급, 과밀, 노출] */
export function situation(g: Game, c: Comm): [number, number, number, number] {
  const s = g.comms[c];
  return [
    clamp(s.base[0] + P.leverStep * (s.heat - 2), 0, 100),
    clamp(s.base[1] + P.leverStep * (s.ration - 2), 0, 100),
    clamp(s.base[2], 0, 100),
    clamp(s.base[3], 0, 100),
  ];
}

export function totalPop(g: Game): number {
  return COMMS.reduce((sum, c) => sum + g.comms[c].pop, 0);
}

/** 최대 잔여 방식으로 100석을 인원 비례로 나눈다(아이도 인구로 센다). */
export function seats(g: Game): Record<Comm, number> {
  const total = totalPop(g);
  const quotas = COMMS.map(c => ({ c, q: total > 0 ? (100 * g.comms[c].pop) / total : 20 }));
  const out = Object.fromEntries(quotas.map(({ c, q }) => [c, Math.floor(q)])) as Record<Comm, number>;
  let left = 100 - COMMS.reduce((sum, c) => sum + out[c], 0);
  const ranked = [...quotas].sort((a, b) => (b.q - Math.floor(b.q)) - (a.q - Math.floor(a.q)) || COMMS.indexOf(a.c) - COMMS.indexOf(b.c));
  for (let i = 0; left > 0; i = (i + 1) % ranked.length, left -= 1) out[ranked[i].c] += 1;
  return out;
}

export function isSessionSeg(seg: number): boolean {
  return seg > 0 && seg % P.sessionEvery === 0;
}

export function lawActive(g: Game, law: LawId): boolean {
  return g.passed[law] !== undefined;
}

export function journal(g: Game, text: string, tone?: JournalEntry['tone']): void {
  g.journal.push({ seg: g.seg, text, ...(tone ? { tone } : {}) });
}

export function addCard(g: Game, card: Omit<Card, 'uid'>): void {
  g.cards.push({ uid: g.nextCardUid, ...card });
  g.nextCardUid += 1;
}

/** 아직 이름이 불리지 않은 사람을 프로필 풀에서 뽑는다. */
export function drawPerson(g: Game, c: Comm, ages?: [number, number]): Profile {
  const pool = PROFILES.filter(p => p.community === c && !g.usedProfiles.includes(p.id) && !g.deaths.includes(p.name)
    && (!ages || (p.age >= ages[0] && p.age <= ages[1])));
  const fallback = PROFILES.filter(p => p.community === c && !g.deaths.includes(p.name));
  const person = pick(g, pool.length > 0 ? pool : fallback);
  if (!g.usedProfiles.includes(person.id)) g.usedProfiles.push(person.id);
  return person;
}

export function addSecret(g: Game, about?: Comm): Secret {
  const comm = about ?? pick(g, COMMS);
  const owned = new Set(g.secrets.map(s => s.text));
  const pool = SECRET_POOL.filter(s => !owned.has(s.text));
  const base = pick(g, pool.length > 0 ? pool : SECRET_POOL);
  const secret: Secret = { id: g.nextSecretId, text: base.text, weight: base.weight, about: comm, uses: 0 };
  g.nextSecretId += 1;
  g.secrets.push(secret);
  return secret;
}

// ---- 시작 ----
export function createGame(seed = 's1a'): Game {
  const g = {
    version: 1, seed, rng: createRng(seed), seg: 1, phase: 'prep', session: 0,
    coal: P.coal0, food: P.food0, med: P.med0, lux: P.lux0, trust: P.trust0, tension: P.tension0, fear: 0,
    injured: 0, symbols: 0, comms: {} as Record<Comm, CommState>, passed: {}, repealedAt: {}, boughtBy: {},
    secrets: [], nextSecretId: 1, leashes: [], blackmails: 0, corpseIssue: false, thrown: 0, stored: 0, deaths: [],
    strikes: 0, inStrike: false, strikeWarned: -99, lostSegments: 0, trustCrisis: null, tensionWarned: false,
    tensionCrisisUsed: 0, emergencyUsed: false, guidedLeft: 0, decreeLeft: 0, guardEscort: false, forcedRun: false,
    autoLevers: false, actedSeg: 0, proposals: [], agendaHolder: null, cards: [], recentEvents: [], eventLog: {}, needs: {}, emergencyCalls: [], hunger: 0, nextCardUid: 1, stop: null,
    council: null, lastSettle: null, journal: [], usedProfiles: [], end: null,
    stats: { dealsMade: 0, promisesKept: 0, promisesBroken: 0, lawsPassed: 0, lawsFailed: 0, repeals: 0, bribes: 0, blackmails: 0 },
  } as Game;
  for (const c of COMMS) {
    const person = drawPerson(g, c, REP_AGE[c]);
    const banned = TRAIT_BAN[c];
    const traits = TRAITS.filter(t => t !== banned);
    g.comms[c] = {
      base: [...START[c]], heat: 2, ration: 2, rel: REL0[c], coh: COH0[c], fervor: 0, badStreak: 0, grudge: 0,
      lastOffense: 0, demandCool: 1, favorCool: 2, agitateCool: 2, pop: POP0[c], away: 0, debt: false,
      leader: { personId: person.id, name: person.name, age: person.age, trait: pick(g, traits), traitShown: 0 },
      promise: null, supportedAt: -99, cutAt: [], disgraced: false,
    };
  }
  addSecret(g);
  journal(g, '볼슈틴 차고를 떠났다. 여섯 번째 겨울, 200명이 탔다. 라이프치히 중앙역까지 24구간.');
  return g;
}

export function cloneGame(g: Game): Game {
  return structuredClone(g);
}

export function ideologyText(c: Comm): string {
  const [r, a, t] = IDEO[c];
  const parts = [r > 0 ? '균등' : r < 0 ? '기여' : '', a > 0 ? '규율' : a < 0 ? '실용' : '', t > 0 ? '복원' : t < 0 ? '적응' : ''];
  return parts.filter(Boolean).join('·');
}
