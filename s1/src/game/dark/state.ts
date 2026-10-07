import { createRng, nextRandom } from '../../core/rng';
import type { RngState } from '../../core/rng';
import { COMM_NAME, COMMS, OPPOSITE, REP_AGE, TRAIT_BAN, TRAITS } from '../data';
import type { Comm } from '../data';
import { addCard, drawPerson, isGone, journal, PROFILES } from '../state';
import type { Card, Game, Profile } from '../state';
import { B, TRAIN_ORDER } from './data';
import type { MeansKey } from './data';
import type { H7Pick } from './chronicle';

// S1b 어두운 길의 판 상태(s1b_dark_path.md). g.dark가 없으면 S1a·S1c 판이고, 이 묶음의 훅은 아무 일도 안 한다.
// 난수는 S1b 전용 흐름(dark.rng)을 쓴다. S1a 쪽 주사위 순서를 건드리지 않아, 같은 시드의 S1a 부분이 S1b 판에서도 덜 흔들린다.

/** 불씨의 원인(4.1 표) */
export type EmberCause = 'fervor' | 'grudge' | 'leash' | 'bribe' | 'rival' | 'lack' | 'misjudged' | 'scapegoat' | 'floor' | 'executor';
/** 불씨의 '누구에게': 칸, 열차장, 열차장 쪽 인물(경비대장·부관·배급장), 창고(배급장) */
export type Target = Comm | 'chief' | 'aide' | 'store';
export type SabKind = 'boiler' | 'coupling' | 'poison' | 'heating';
/** 사다리 단계: 0 기척만, 1 위협, 2 사보타주, 3 폭행, 4 암살 시도 */
export type Stage = 0 | 1 | 2 | 3 | 4;

export interface Ember {
  id: number;
  who: Comm;
  /** 실제로 할 사람(프로필 id). 원인이 대표면 대표다(수사에선 측근이 대신 오를 수 있다) */
  actor: string;
  target: Target;
  /** 노리는 사람(프로필 id, 열차장이면 'chief'). 4단계와 징후 글에 쓴다 */
  mark: string;
  cause: EmberCause;
  stage: Stage;
  /** 임박한 단계. 0이면 없다 */
  imm: Stage;
  quiet: number;
  guardUntil: number;
  sab: SabKind;
  /** 수석 기관사에게 맡겨 막힌 보일러 */
  blocked: boolean;
  born: number;
}

/** 단서 종류(4.4): 발자국, 남은 물건, 목격, 밀고, 장부의 숫자, 공개된 증거물(의회에 내놓은 일지 같은 것) */
export type ClueKind = 'foot' | 'item' | 'witness' | 'informant' | 'ledger' | 'public';
export interface Clue { kind: ClueKind; truth: boolean; line: string; seg: number }
/** 의심 점수의 사실(4.5 표). joined·rescued·punished는 처지라 혼자서 희생양 표시를 켜지 않는다(1.4). */
export type Fact = 'access' | 'car' | 'rival' | 'joined' | 'rescued' | 'punished';
export const FACT_SCORE: Record<Fact, number> = { joined: 2, access: 2, rescued: 1, car: 1, rival: 1, punished: 1 };
/** 사건에 닿은 사실(표시를 켜는 쪽) */
export const TIE_FACTS: Fact[] = ['access', 'car', 'rival'];

export interface Suspect {
  id: string;
  culprit: boolean;
  /** 이 사람이 대신 오른 진범(대표 같은 이름 있는 인물) */
  proxyFor?: string;
  facts: Fact[];
  clues: Clue[];
  acq: boolean;
  /** 이 사건으로 이미 벌받았다(측근이 시킨 사람을 대서 수사가 다시 열려도 다시 피고가 되지 않는다) */
  served?: boolean;
}

export type CaseKind = 'assault' | 'assn' | 'order' | SabKind | 'theft';
export interface Case {
  id: number;
  kind: CaseKind;
  victimComm: Comm;
  /** 피해자 프로필 id('chief'는 열차장). 없으면 칸 전체의 손해(사보타주) */
  victim?: string;
  dead: boolean;
  /** 군중 시계(구간). null이면 군중이 없다 */
  clock: number | null;
  status: 'open' | 'trial' | 'closed';
  protects: number;
  promiseUsed: boolean;
  /** 재판을 약속한 회기 번호 */
  promised?: number;
  trialExt: boolean;
  /** 위기 법에 밀려 시계를 한 번 멈췄다 */
  paused: boolean;
  opened: number;
  ember?: number;
  /** 열차장이 시킨 암살의 수사 */
  own: boolean;
  sus: Suspect[];
  /** 일이 난 자리(징후와 단서 글) */
  where: string;
  /** 군중 조짐을 마지막으로 보인 구간 */
  crowdSeen?: number;
  /** 재판이 열린 회기 */
  triedAt?: number;
  /** 열차장이 시킨 일이 이 사건으로 이미 드러났다(두 번 드러나지 않는다) */
  exposed?: boolean;
}

export type OrderWhy = 'hostile' | 'silence' | 'truth';
export type OrderExe = 'guard' | 'rival' | 'bound';
export type OrderMethod = 'accident' | 'stop' | 'night';
/** ref: 진실을 막으려는 명령이면 그 진실의 주인(죄 없이 벌받은 사람). 명령이 실패하거나 거둬지면 그 진실이 드러날 수 있다 */
export interface Order { target: string; why: OrderWhy; exe?: OrderExe; exeId?: string; method?: OrderMethod; at?: number; ref?: string }

/** 일대기 장면 후보(10.3). 무게 순으로 고른다. */
export interface Scene { seg: number; key: string; weight: number; text: string; who: string[]; witnesses: string[] }

export interface DarkStats {
  signs: number; imminent: number; acts: number; violent: number; violentDeaths: number; blocked: number;
  cases: number; solved: number; misjudged: number; trials: number; guilty: number; acquitted: number;
  scapegoats: number; lynches: number; protected: number; orders: number; ordersOk: number; revealed: number;
  corpses: number; risen: number; theft: number; cardsDeferred: number;
}

export interface DarkState {
  rng: RngState;
  nextId: number;
  embers: Ember[];
  cases: Case[];
  /** 죄 없이 벌받은 사람(진실이 드러날 수 있는 창) */
  /** asked: 드러나려는 일 카드가 떠 있다. held: 입을 막으려는 명령이 걸려 있어 그 명령이 끝날 때까지 드러나지 않는다.
   *  둘 다 창(seg부터 6구간)을 다시 열지 않는다. 명령이 성공하면 묻히고, 실패하거나 거둬지면 바로 드러난다. */
  innocents: { id: string; comm: Comm; seg: number; caseId: number; how: 'punish' | 'scapegoat' | 'lynch'; asked?: boolean; held?: boolean }[];
  /** 전에 벌받은 사람(의심 +1) */
  punished: string[];
  violentUsed: number;
  chiefAttacked: boolean;
  /** 4단계를 이미 한 번 받은 장인(첫 시도는 부상) */
  craftHit: string[];
  prevFervor: Record<Comm, number>;
  prevGrudge: Record<Comm, number>;
  lackStreak: Record<Comm, number>;
  rationStreak: Record<Comm, number>;
  /** 피해 사건 수(1.2): 사람이 다치거나 죽은 사건. 누가 일으켰든 센다 */
  harm: number;
  /** 무기고 통제(관행). null이면 아직 안 물었다 */
  armory: boolean | null;
  /** 머리 확인 관행(9.1). null이면 아직 안 정했다 */
  practice: 'guard' | 'medtech' | 'car' | null;
  /** 관행 카드를 고른 횟수(9.1: 두 번째부터 '지난번처럼'으로 묻는다) */
  practiceAsked: number;
  /** 이번 구간 칸 안에서 죽은 사람(정산에 확인한다) */
  fresh: { comm: Comm; name: string }[];
  /** 확인하지 않은 시신(밤샘): 다음 정산에 이 확률로 한 번 굴린다. cold면 S1a 냉동칸 수(stored, burn이면 pyre)에도 들어 있다 */
  unchecked: { comm: Comm; name: string; p: number; cold?: boolean; burn?: boolean }[];
  order: Order | null;
  ordersUsed: number;
  /** 실행자: 평생 약점을 쥔다(4.6) */
  executors: { id: string; comm: Comm; seg: number }[];
  /** 근신(4구간)과 하차 명령(다음 정차) */
  confined: { id: string; until: number }[];
  exile: { id: string; comm: Comm }[];
  /** 열차장 쪽 인물(부관, 배급장). 경비대장은 경비대 대표다 */
  staff: { deputy: string; ration: string };
  /** 판 중 합류한 사람(데려온 생존자, 길잡이). 지금 S1a엔 넣는 곳이 없다 */
  joined: string[];
  /** 칸마다 지킨 약속·어긴 약속(불신임 동의 입장) */
  kept: Record<Comm, number>;
  broken: Record<Comm, number>;
  lowTrust: number;
  /** 수단 점수와 선을 넘은 기록 */
  means: Partial<Record<MeansKey, number>>;
  crossed: { key: MeansKey; seg: number }[];
  nightmareUntil: number;
  numb: boolean;
  /** 같은 종류 사건의 지난 판결(선례) */
  precedent: Partial<Record<CaseKind, { level: number; guilty: boolean; comm: Comm }>>;
  /** 이번 구간에 올린 꼭 고를 S1b 카드 수(구간당 필수 결정 셋, 1.2) */
  seg: { at: number; n: number };
  scenes: Scene[];
  /** 이번 구간 정차 산출 배수(연결기 풀기, 보일러 고장) */
  haul: number;
  /** 악몽이 남은 카드 수(10.5) */
  nightmareCards: number;
  /** 냉동칸·찬 객차에 둔 시신 가운데 확인을 마친 수(9.1: 확인한 시신은 일어나지 않는다) */
  checkedStored: number;
  checkedPyre: number;
  /** 마지막으로 의회를 연 회기 */
  councilAt: number;
  /** 불신임을 올리려는 적의 3 지도자(칸과 그 사람). 대표가 바뀌면 사라진다 */
  confBy: Comm | null;
  confLeader: string | null;
  /** 지난 정산의 대표 상태(목줄·들킨 뇌물을 새로 알아본다) */
  prevLeash: Comm[];
  prevDisgraced: Comm[];
  /** H7 자동 기록(15.1) */
  h7: H7Pick[];
  closed: boolean;
  stats: DarkStats;
}

const zero = (): Record<Comm, number> => Object.fromEntries(COMMS.map(c => [c, 0])) as Record<Comm, number>;

export function hasDark(g: Game): g is Game & { dark: DarkState } {
  return !!g.dark;
}

/** 열차장 쪽 인물 둘을 앞칸에서 뽑는다(부관, 배급장). S1b 난수로 뽑아 S1a 주사위 순서를 건드리지 않는다. */
function staffPick(g: Game): { deputy: string; ration: string } {
  const draw = (ages: [number, number]): string => {
    const pool = PROFILES.filter(p => p.community === 'front' && !g.usedProfiles.includes(p.id) && !isGone(g, p.name) && p.age >= ages[0] && p.age <= ages[1]);
    const p = dpick(g, pool.length ? pool : PROFILES.filter(x => x.community === 'front'));
    g.usedProfiles.push(p.id);
    return p.id;
  };
  return { deputy: draw([32, 58]), ration: draw([30, 60]) };
}

/** 판에 S1b를 켠다. S1a·S1c 판 어느 쪽에도 얹을 수 있다. */
export function enableDark(g: Game): void {
  g.dark = {
    rng: createRng(`${g.seed}:s1b`), nextId: 1, embers: [], cases: [], innocents: [], punished: [], violentUsed: 0, chiefAttacked: false,
    craftHit: [], prevFervor: zero(), prevGrudge: zero(), lackStreak: zero(), rationStreak: zero(), harm: 0, armory: null, practice: null, practiceAsked: 0,
    fresh: [], unchecked: [], order: null, ordersUsed: 0, executors: [], confined: [], exile: [], staff: { deputy: '', ration: '' }, joined: [],
    kept: zero(), broken: zero(), lowTrust: 0, means: {}, crossed: [], nightmareUntil: -1, numb: false, precedent: {}, seg: { at: 0, n: 0 },
    scenes: [], haul: 1, nightmareCards: 0, checkedStored: 0, checkedPyre: 0, councilAt: -1, confBy: null, confLeader: null,
    prevLeash: g.leashes.map(l => l.comm), prevDisgraced: COMMS.filter(c => g.comms[c].disgraced), h7: [], closed: false,
    stats: {
      signs: 0, imminent: 0, acts: 0, violent: 0, violentDeaths: 0, blocked: 0, cases: 0, solved: 0, misjudged: 0, trials: 0, guilty: 0,
      acquitted: 0, scapegoats: 0, lynches: 0, protected: 0, orders: 0, ordersOk: 0, revealed: 0, corpses: 0, risen: 0, theft: 0, cardsDeferred: 0,
    },
  };
  g.dark.staff = staffPick(g);
}

// ---- 난수(S1b 전용) ----
export function dr(g: Game): number {
  const d = g.dark!;
  const next = nextRandom(d.rng);
  d.rng = next.rng;
  return next.value;
}
export function dpick<T>(g: Game, items: readonly T[]): T {
  return items[Math.floor(dr(g) * items.length)];
}
export function newId(g: Game): number {
  const d = g.dark!;
  d.nextId += 1;
  return d.nextId - 1;
}

// ---- 사람 ----
export const byId = (id: string): Profile | undefined => PROFILES.find(p => p.id === id);
export const byName = (name: string): Profile | undefined => PROFILES.find(p => p.name === name);
export function nameOf(g: Game, id: string): string {
  if (id === 'chief') return g.captainName ?? '열차장';
  return byId(id)?.name ?? id;
}
export function alive(g: Game, id: string): boolean {
  if (id === 'chief') return true;
  const p = byId(id);
  return !!p && !isGone(g, p.name);
}
export function isRep(g: Game, id: string): boolean {
  return COMMS.some(c => g.comms[c].leader.personId === id);
}
/** 그 칸의 산 어른(16~70). 대표·근신 중인 사람을 뺄 수 있다. */
export function adults(g: Game, c: Comm, opts: { noRep?: boolean; except?: string[] } = {}): Profile[] {
  return PROFILES.filter(p => p.community === c && p.age >= 16 && p.age <= 70 && !isGone(g, p.name)
    && (!opts.noRep || !isRep(g, p.id)) && !(opts.except ?? []).includes(p.id));
}
export function commOf(g: Game, id: string): Comm {
  return byId(id)?.community ?? 'tail';
}

/** 칸 순서에서 옆 칸 */
export function neighbors(c: Comm): Comm[] {
  const i = TRAIN_ORDER.indexOf(c);
  return [TRAIN_ORDER[i - 1], TRAIN_ORDER[i + 1]].filter((x): x is Comm => !!x);
}
export function rivals(a: Comm, b: Comm): boolean {
  return OPPOSITE[a] === b || OPPOSITE[b] === a;
}
export function rivalOf(c: Comm): Comm | null {
  if (OPPOSITE[c]) return OPPOSITE[c];
  return COMMS.find(o => OPPOSITE[o] === c) ?? null;
}

/** 대표가 죽거나 내렸으면 잇고 일지에 남긴다. 죽음은 죽음 훅(hooks.ts)이, 하차는 정차 훅이 부른다. 대표가 아니면 아무 일도 없다. */
export function repGone(g: Game, c: Comm, id: string): void {
  if (g.comms[c].leader.personId !== id) return;
  const next = succeedRep(g, c);
  journal(g, `${next}이(가) ${COMM_NAME[c]} 대표 자리를 이었다.`, 'dark');
}

/** 대표가 죽거나 내리면 그 칸의 다른 사람이 잇는다(S1a 수치 4.2, hub.ts succeed와 같은 모양). */
export function succeedRep(g: Game, c: Comm): string {
  const s = g.comms[c];
  const p = drawPerson(g, c, REP_AGE[c]);
  const ban = TRAIT_BAN[c];
  const traits = TRAITS.filter(t => t !== ban && t !== s.leader.trait);
  s.leader = { personId: p.id, name: p.name, age: p.age, trait: dpick(g, traits), traitShown: 0 };
  s.sick = undefined;
  s.debt = false;
  s.promise = null;
  return p.name;
}

// ---- 카드 ----
/** S1b 카드를 올린다. required면 이번 구간 필수 결정 수에 센다. */
export function darkCard(g: Game, card: Omit<Card, 'uid'>, required = true): void {
  const d = g.dark!;
  if (d.seg.at !== g.seg) d.seg = { at: g.seg, n: 0 };
  if (required) d.seg.n += 1;
  addCard(g, card);
}
/** 이번 구간에 필수 결정이 이미 셋이면 미룰 수 있는 카드는 미룬다(1.2). */
export function segFull(g: Game): boolean {
  const d = g.dark!;
  return d.seg.at === g.seg && d.seg.n >= 3;
}
export function darkCardsPending(g: Game): boolean {
  return g.cards.some(c => c.kind.startsWith('dark:'));
}

// ---- 조사 ----
export function iga(word: string): string {
  const ch = word.charCodeAt(word.length - 1);
  if (ch < 0xac00 || ch > 0xd7a3) return '이(가)';
  return (ch - 0xac00) % 28 ? '이' : '가';
}
export function eul(word: string): string {
  const ch = word.charCodeAt(word.length - 1);
  if (ch < 0xac00 || ch > 0xd7a3) return '을(를)';
  return (ch - 0xac00) % 28 ? '을' : '를';
}
export function eun(word: string): string {
  const ch = word.charCodeAt(word.length - 1);
  if (ch < 0xac00 || ch > 0xd7a3) return '은(는)';
  return (ch - 0xac00) % 28 ? '은' : '는';
}
export function wa(word: string): string {
  const ch = word.charCodeAt(word.length - 1);
  if (ch < 0xac00 || ch > 0xd7a3) return '와(과)';
  return (ch - 0xac00) % 28 ? '과' : '와';
}

export { B };

/** 불씨 하나를 끈다(embers.ts가 다시 내보낸다. cases.ts도 쓰려고 여기 둔다). */
export function killEmber(g: Game, e: Ember | undefined): void {
  if (!e) return;
  const d = g.dark!;
  d.embers = d.embers.filter(x => x.id !== e.id);
}
