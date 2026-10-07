import { createRng, nextRandom } from '../core/rng';
import type { NeedId, NeedState } from './needs';
import type { DomState } from './domestic/state';
import type { SignTier, Weather } from './omens';
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
  /** 대표가 앓는 동안 원래 대표(leader는 대신 나온 측근이다, 사람의 무게 A2) */
  sick?: { since: number; rep: Leader };
  /** 온기나 배급이 30 아래로 이어진 구간 수 */
  lowStreak?: number;
}

export interface Secret { id: number; text: string; weight: number; about: Comm; uses: number }
export interface Leash { comm: Comm; since: number; weight: number }

export interface HiddenBite { who: string; comm: Comm; at: number; due: number; found?: boolean; isolated?: boolean }
export interface Card { uid: number; kind: string; comm?: Comm; n?: number; who?: string; text?: string; /** 콘텐츠 사건의 {person}·{person2}(content.ts) */ names?: string[] }
/** 한 사건을 마지막으로 겪은 때와 고른 것. 같은 사건이 다시 나오면 이걸 보고 본문과 대가를 바꾼다. */
/** st: 그때의 상태 키(eventStateKey). 상태가 그대로면 같은 사건을 다시 열지 않는다. */
export interface EventMemo { n: number; seg: number; pick: string; st?: string }

export interface StopState {
  place: string;
  target: LootKey | null;
  stay: StayId;
  crewComm: Comm;
  crewSize: number;
  /** 이번 정차의 바깥 기척(0.8 조용함, 1 보통, 1.4 무리 흔적). 정차 장면 글과 위험 줄에 같이 들어간다. */
  threat?: number;
  /** 정찰을 보내면 바깥 기척을 알고 위험 줄이 약속이 된다. 안 보내면 위험을 모른다(2026-10-07 사용자 카드 '정찰 따라'). */
  scout?: boolean;
  /** 정차 날씨, 창밖 겉모습, 정찰조가 본 조짐과 그 기척 단계(omens.ts). 도착할 때 정해진다. */
  weather?: Weather;
  look?: string;
  omen?: string;
  sign?: SignTier;
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
/** 의회 안건. 법(제정·폐지·추인)이거나 법이 아닌 안건(motion)이다(s1b_dark_path 12.3).
 * kind가 없는 안건은 법으로 읽는다(옛 저장 데이터와 테스트). */
export type Agenda = LawAgenda | MotionAgenda;
/** ratify: 비상대권 포고를 의회가 추인하는 표결(통과하면 남고, 안 되면 사라진다) */
export interface LawAgenda { kind?: 'law'; law: LawId; repeal: boolean; by?: Comm; forced?: boolean; ratify?: boolean }
/** 법이 아닌 안건. 통과하면 바로 일이 일어나고 끝난다. 폐지·추인·재상정 쿨다운이 없다. */
export type MotionId = 'share';
export interface MotionAgenda { kind: 'motion'; motion: MotionId; subject?: Comm; person?: string; by?: Comm; forced?: boolean }

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
  /** 이번 대권에서 포고한 법과 마지막으로 포고한 구간 */
  decreed?: LawId[];
  decreeSeg?: number;
  /** 대권이 끝나 다음 회기 추인을 기다리는 포고 */
  ratify?: LawId[];
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
  /** 법 요구마다 예고가 몇 번 왔나(예고 글 변주) */
  needAsked?: Partial<Record<NeedId, number>>;
  /** 비상 소집을 부른 구간들 */
  emergencyCalls: number[];
  /** 식량 0으로 버틴 구간 수 */
  hunger: number;
  // ---- 사람의 무게(people.ts) ----
  /** 사람 카드가 마지막으로 온 구간(그다음 이동 사건을 쉰다) */
  peopleSeg?: number;
  /** 죽음 기록(원인 태그). 하차 장면이 죄책감과 애도를 가른다 */
  deathLog?: { seg: number; name: string; cause: 'chosen' | 'warned' | 'other'; witness?: boolean }[];
  /** 장작불 법: 다음 정차에 태우려고 지키는 시신 */
  pyre?: number;
  /** 냉동칸이 차서 살던 칸에 둔 시신(장작불 법). 그 칸 과밀이 시신마다 오른다. */
  pyreKin?: Partial<Record<Comm, number>>;
  /** 상중인 사람 */
  mourning?: { name: string; comm: Comm; until: number }[];
  /** 잠깐 오른 처지 */
  tempBase?: { c: Comm; i: 0 | 1 | 2 | 3; v: number; until: number }[];
  sickCount?: number;
  elderAsked?: boolean;
  /** 스스로 열차에서 내린 사람 */
  left?: string[];
  born?: { comm: Comm; mother: string; weak: boolean; left: number; lost?: boolean };
  /** 부모를 잃은 아이를 맡은 칸 */
  raised?: Record<string, Comm>;
  /** 이번 판에 이미 본 정차 글(조짐, 창밖 겉모습). 같은 문장이 되도록 다시 안 나오게 한다. */
  linesSeen: string[];
  /** 붕대로 감아 숨긴 물림. 2구간 안에 들키거나 칸 안에서 일어난다(body_injury 4.4). */
  hiddenBites: HiddenBite[];
  nextCardUid: number;
  stop: StopState | null;
  council: CouncilState | null;
  lastSettle: Settlement | null;
  journal: JournalEntry[];
  usedProfiles: string[];
  end: EndKind | null;
  stats: { dealsMade: number; promisesKept: number; promisesBroken: number; lawsPassed: number; lawsFailed: number; repeals: number; bribes: number; blackmails: number };
  /** S1c 내정(공방, 기술, 전문가, 위생). 없으면 S1a 판이다(domestic/state.ts). */
  dom?: DomState;
  /** 이야기 진행도(first_leg_story 9장). S1a는 표식 몇 개만 쓴다. */
  story?: StoryState;
  /** 라이프치히 이탈(first_leg_story 7.7, hub.ts) */
  hub?: HubState;
  // ---- 콘텐츠 JSON 사건(content.ts) ----
  contentFlags?: Record<string, boolean | number | string>;
  /** 미뤄 둔 후속 사건 */
  contentQueue?: { id: string; at: number }[];
  /** 자리를 비운 프로필 id → 돌아오는 구간 */
  contentAway?: Record<string, number>;
  contentInjured?: string[];
  /** 아직 게임이 읽지 않는 효과(비밀·표·거래·연대기). 화면엔 안 보인다 */
  contentPending?: string[];
}

export type HubFate = 'stayed' | 'left' | 'persuaded' | 'forced';
export interface StoryState {
  /** 9.1 진행 단계. S1a는 출발 1(leg1_river), 라이프치히 6(leg1_hub)만 쓴다. */
  stage: number;
  flags: {
    /** 우리 쪽 첫 죽음(S1a 규칙으로만) */
    first_death?: boolean;
    /** 첫 시신 안건이 무엇으로 열렸나 */
    first_corpse_agenda?: 'none' | 'own' | 'stranger';
    signal_heard?: boolean;
    hub_split?: Partial<Record<Comm, HubFate>>;
  };
}
export interface HubState {
  /** 짐 싸는 징후를 받은 칸 */
  warned: Comm[];
  /** 미리 빠진 물자(장부 불일치). 남으면 돌아오고, 떠나면 들고 간 셈이다. */
  stash: Partial<Record<Comm, { food: number; med: number }>>;
  /** '우리 몫을 내놔라'가 통과한 칸. 올라왔는데 통과 못 한 칸은 허브에서 몰래 더 가져가려 한다. */
  agreed: Comm[];
  /** 도착 때 정한 떠나려는 사람(칸마다) */
  plan?: Partial<Record<Comm, HubPlan>>;
  /** 허브 결과 줄 */
  lines?: string[];
}
export interface HubPlan { share: number; n: number; names: string[]; leaderGoes: boolean }

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
/** 죽었거나 열차에서 내린 사람 */
export function isGone(g: Game, name: string): boolean {
  return g.deaths.includes(name) || (g.left ?? []).includes(name);
}

export function stageOf(rel: number): { name: string; band: number; index: number } {
  const index = STAGES.findIndex(stage => rel >= stage.min);
  const stage = STAGES[index === -1 ? STAGES.length - 1 : index];
  return { name: stage.name, band: stage.band, index: index === -1 ? STAGES.length - 1 : index };
}

/** 처지 = 기준 + 레버 차이. [온기, 배급, 과밀, 노출] */
export function situation(g: Game, c: Comm): [number, number, number, number] {
  const s = g.comms[c];
  // S1c: 기술·침구·장갑이 더하는 처지 보정(domestic/state.ts refreshSit). S1a 판엔 없다.
  const d = g.dom?.sit[c];
  return [
    clamp(s.base[0] + P.leverStep * (s.heat - 2) + (d?.[0] ?? 0), 0, 100),
    clamp(s.base[1] + P.leverStep * (s.ration - 2) + (d?.[1] ?? 0), 0, 100),
    clamp(s.base[2] + (d?.[2] ?? 0), 0, 100),
    clamp(s.base[3] + (d?.[3] ?? 0), 0, 100),
  ];
}

/** 이야기 진행도. 옛 저장 데이터엔 없으니 처음 읽을 때 만든다. */
export function storyOf(g: Game): StoryState {
  return (g.story ??= { stage: 1, flags: { first_death: false, first_corpse_agenda: 'none' } });
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
  const pool = PROFILES.filter(p => p.community === c && !g.usedProfiles.includes(p.id) && !isGone(g, p.name)
    && (!ages || (p.age >= ages[0] && p.age <= ages[1])));
  const fallback = PROFILES.filter(p => p.community === c && !isGone(g, p.name));
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
    autoLevers: false, actedSeg: 0, proposals: [], agendaHolder: null, cards: [], recentEvents: [], eventLog: {}, needs: {}, emergencyCalls: [], hunger: 0, linesSeen: [], hiddenBites: [], nextCardUid: 1, stop: null,
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
  storyOf(g);
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
