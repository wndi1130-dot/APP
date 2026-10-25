import { createRng, nextRandom } from '../core/rng';
import type { NeedId, NeedState } from './needs';
import type { CouncilLogRow } from './council_log';
import type { DomState } from './domestic/state';
import type { ScoutGearUsed } from './domestic/scout_gear';
import type { EduState } from './domestic/classroom';
import type { DarkState } from './dark/state';
import type { DisasterKind, DisasterState } from './disaster';
import type { SignTier, Weather } from './omens';
import type { RngState } from '../core/rng';
import type { FieldReturns } from './field_receipt';
import type { MemoryBook, PersonEvent } from './memory';
import type { RationCutState } from './ration_cut';
import type { HandsState } from './hands';
import {
  COH0, COMMS, HANDS, IDEO, P, POP0, REL0, REP_AGE, SECRET_POOL, START, STAGES, TRAIT_BAN, TRAITS,
} from './data';
import type { Comm, ConditionDef, LawId, LocoId, LootKey, StayId, Trait } from './data';
import profilesJson from '../../data/profiles.json';

// S1a 한 판의 상태. 저장할 수 있게 함수 없는 평범한 값만 담는다.

export type Phase = 'prep' | 'travel' | 'stop' | 'council' | 'settle' | 'end';
/** 노선 한 구간. 길이만 안다. 없으면 P.segKmDefault */
export interface RouteSeg { seg: number; km: number }

/** 석탄 0으로 선 열차. 화면은 이 값을 읽어 선 도면·예고·띠를 그린다. */
export interface StrandedState {
  since: number;            // 멈춘 구간(g.seg)
  turns: number;            // 멈춘 뒤 지난 정산 수
  segKm: number;            // 이 구간 길이(km)
  atKm: number;             // 출발역에서 멈춘 지점까지(km)
  toNextKm: number;         // 다음 역까지 남은 길 = segKm - atKm
  seen: string[];           // 이미 뜬 멈춘 열차 사건 id
  trip: TripState | null;   // 나가 있는 수동차 원정. 없으면 아직 안 보냈거나 끝났다
  captainAway: boolean;     // 열차장이 원정에 탔다(회기·거래가 닫힌다)
  deputy: Comm | null;      // 열차장 대신 맡은 칸
  lostTrips: number;        // 못 돌아온 원정 수
  snow: 'all' | 'guard' | 'none' | null; // 「선로의 눈」 선택
  lamp: boolean;            // 「기다리는 밤」 등불을 걸었다
  burned?: number;          // 서기까지 길에서 태운 석탄(서는 순간의 석탄). 서는 구간의 정산 보고가 이만큼 줄었다고 적는다
}

/** 수동차 원정 하나. 화면은 phase·turn·posKm으로 선 도면을 그린다. */
export interface TripState {
  leaderGoes: boolean;      // 열차장이 탔나
  forced: boolean;          // 지지가 낮아 떠밀려 나갔나(돌아오면 신임 +5)
  comm: Comm;               // 지원자를 낸 칸
  names: string[];          // 지원자 이름(열차장 제외)
  size: number;             // 탄 사람 수(열차장 포함)
  distKm: number;           // 지금 목표 역까지 거리(이어 가면 +15씩)
  extends: number;          // 이어 간 횟수
  goTurns: number; searchTurns: number; backTurns: number;
  plannedTurns: number;     // 떠날 때 열차가 아는 총 턴(이어 감을 모르는 동안 「때가 됐다」의 기준)
  turn: number;             // 떠난 뒤 지난 정산 수
  phase: 'go' | 'search' | 'back';
  posKm: number;            // 도면용. 멈춘 열차에서 잰 수동차 자리
  baseFood: number;         // 떠날 때 가져간 식량(이어 갈 때 곱절 몫의 기준)
  foodShort: number;        // 모자라서 못 가져간 식량
  foodOwed: number;         // 이어 간 몫으로 열차가 아직 내지 않은 식량
  outcome: 'coal' | 'lost' | null; // 역에서 정해진다. 열차는 돌아올 때 알고, 무전이 있으면 바로 안다
  known: boolean;           // 열차가 결과(이어 감·못 돌아옴)를 아는가
  promise: 'yes' | 'no' | null; // 「돌아올 사람의 몫」
}

/** coup: S1b 계엄 중 경비대 충성이 무너져 경비대장이 열차를 잡았다(s1b_dark_path 5.3, 둘째 묶음). lost_captain: 수동차에 탄 열차장이 돌아오지 않았다. */
export type EndKind = 'complete' | 'stranded' | 'ousted' | 'revolt' | 'coup' | 'lost_captain' | 'slice';
/** 판을 끝내는 길(turn.ts finish가 채운다). 의회 안건처럼 turn.ts를 부를 수 없는 곳(import 순환)이 이걸로 끝낸다. */
/** 정차 작업조 명단에 더 붙는 사람(이름). S1b 정차 암살의 실행자와 대상이 여기서 붙는다(dark/order.ts). */
export const CREW_EXTRAS: ((g: Game) => string[])[] = [];
/** 정차 작업조에 못 나가는 사람의 이름(S1b 근신·경비 근무, K02 5). */
export const CREW_BUSY: ((g: Game) => string[])[] = [];
export const END_LINK: { finish: (g: Game, end: EndKind) => void } = { finish: (g, end) => { g.end = end; g.phase = 'end'; } };
/** 특별 회기를 닫는 길(field_council.ts가 채운다). turn.ts가 field_council을 바로 부르면 import 순환이 생겨 이 자리로 잇는다. */
export const COUNCIL_LINK: { leaveSpecial: (g: Game) => boolean } = { leaveSpecial: () => false };

export interface Profile { id: string; name: string; name_lang?: string; gender: 'male' | 'female'; age: number; community: Comm; like: string; dislike: string; hometown: string }
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
  /** 관계가 바닥인데 레버를 돌려준 연속 구간 수(결정 080: 돌려주면 관계가 빨리 오른다) */
  backStreak: number;
  grudge: number;
  /** 이 칸과 지킨 약속·어긴 약속 수(판 전체 누계). 설득(결정 433)과 정치 흐름의 결과 아크가 같은 키를 읽는다. 옛 저장 판에는 없어서 0이다 */
  kept?: number;
  broken?: number;
  /** 약속을 세 번 어겨 이 칸과 공개 협상·현장 조달이 판 끝까지 닫혔다(결과 아크, council_log.ts) */
  openClosed?: boolean;
  /** 이 칸에 넘긴 안건이 이어 부결된 수(결과 아크) */
  heldFails?: number;
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

/** cid: 콘텐츠 비밀(data/secrets)에서 온 것이면 그 id(content.ts) */
export interface Secret { id: number; text: string; weight: number; about: Comm; uses: number; cid?: string; /** 콘텐츠 비밀의 단계(1 소문, 2 증거). 무게와 따로 센다 */ proof?: 1 | 2 }
export interface Leash { comm: Comm; since: number; weight: number }

export interface HiddenBite { who: string; comm: Comm; at: number; due: number; found?: boolean; isolated?: boolean }
/** 폭동(riot.ts)의 상태. prev는 직전 정산의 긴장, stage는 0 평온·1 항의·2 난장판, fire는 지금 불붙은 칸(오래된 순),
 *  scorched는 한 정산이라도 불이 붙었던 칸(그을음·부서진 선반), spilled는 엎어진 물건(치우면 0으로 돌아간다). 나머지는 재기용 셈이다. */
export interface RiotState {
  prev: number; stage: 0 | 1 | 2; fire: string[]; scorched: string[]; spilled: number;
  riots: number; protests: number; riotCards: number; fell: number; died: number;
}
export function riotStart(): RiotState {
  return { prev: P.tension0, stage: 0, fire: [], scorched: [], spilled: 0, riots: 0, protests: 0, riotCards: 0, fell: 0, died: 0 };
}
export interface Card {
  uid: number; kind: string; comm?: Comm; n?: number; who?: string; text?: string;
  /** 콘텐츠 사건의 자리표시자 값. 올릴 때 정해 얼려 둔다(content.ts). '@aide'는 말하는 측근 */
  vals?: Record<string, string>;
  /** 구간 예산(budget.ts)이 이 카드를 미룬 횟수. 미룬 적 없으면 없다 */
  pushed?: number;
  /** 플레이어가 단추로 직접 청한 서류(견습생·매뉴얼). 예산이 미루지 않는다. 예산을 켠 판에서만 붙는다 */
  ask?: boolean;
}
/** 카드 구간 예산 통계: 등급(문자열 '1'~'7')별 횟수. deferred 미룬 횟수, faded 두 번 밀려 일지 한 줄로 사라진 수, dropped 돌아올 때 대상이 없어 버린 수 */
export interface BudgetStats { deferred: Record<string, number>; faded: Record<string, number>; dropped: Record<string, number> }
/** 구간 예산을 켠 판의 장부(budget.ts). seg 구간에 플레이어가 고른 카드 수 */
export interface BudgetState { seg: number; picked: number; stats: BudgetStats }
/** 한 사건을 마지막으로 겪은 때와 고른 것. 같은 사건이 다시 나오면 이걸 보고 본문과 대가를 바꾼다. */
/** st: 그때의 상태 키(eventStateKey). 상태가 그대로면 같은 사건을 다시 열지 않는다. */
export interface EventMemo { n: number; seg: number; pick: string; st?: string }

/** 죽은 사람의 자리(death_weight.ts). heat는 난방 배당 밤사이 죽음 */
export type DeathSlot = 'rep' | 'parent' | 'child' | 'hand' | 'heat';
/** 사건 줄 하나. step 0 원인 카드 → 1 반발 → 2 고칠 길. last는 마지막으로 단계가 움직인 구간 */
export interface DeathChain { comm: Comm; slot: DeathSlot; step: 0 | 1 | 2; seg: number; refused: boolean; rel0: number; heat0: number; last: number; bumped?: boolean }

export interface StopState {
  place: string;
  /** 출발을 미룬 날 같은 정차를 한 번 더 뒤지는 중(결정 332). 위험을 따로 굴린다 */
  again?: boolean;
  target: LootKey | null;
  stay: StayId;
  crewComm: Comm;
  crewSize: number;
  /** 이번 정차의 바깥 기척(0.8 조용함, 1 보통, 1.4 무리 흔적). 정차 장면 글과 위험 줄에 같이 들어간다. */
  threat?: number;
  /** 정찰을 보내면 바깥 기척을 알고 위험 줄이 약속이 된다. 안 보내면 위험을 모른다(2026-10-07 사용자 카드 '정찰 따라'). */
  scout?: boolean;
  /** 먼저 보낸 정찰조(2026-10-07 사용자): 누가 갔고, 누가 다치고 누가 못 돌아왔나. 한 정차에 한 번 */
  scoutReport?: { comm: Comm; names: string[]; hurt: string[]; dead: string[] };
  /** 정찰 장비가 옮긴 기척 단계(domestic/scout_gear.ts, 결정 371). threat는 그대로 두고 effThreat로 읽는다. 정차가 끝나면 사라진다 */
  noise?: number;
  /** 두고 간 정찰 장비(false면 두고 감). 없으면 가진 장비를 다 가져간다 */
  gear?: { glass?: boolean; signal?: boolean; cart?: boolean };
  /** 정찰을 보낼 때 쓴 장비와 그 값(산출 곱 haul은 정산에서 쓴다) */
  scoutGear?: ScoutGearUsed;
  /** 태엽 소리 미끼를 걸었다 */
  lured?: boolean;
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
  /** 수색대가 내리는 문장. 보냈을 때만, 결과를 적용하기 전 처지로 담는다. 지나쳤거나 옛 저장이면 없다. */
  disembark?: string;
}

export type DealTool = 'open' | 'favor' | 'fetch' | 'bribe' | 'blackmail' | 'persuade';
/** refused: 이상주의 대표가 뇌물을 거절했다. 거래 자리는 썼지만 표는 움직이지 않는다(K01 1). */
export interface Deal { comm: Comm; tool: DealTool; label: string; refused?: boolean }
/** 의회 안건. 법(제정·폐지·추인)이거나 법이 아닌 안건(motion)이다(s1b_dark_path 12.3).
 * kind가 없는 안건은 법으로 읽는다(옛 저장 데이터와 테스트). */
export type Agenda = LawAgenda | MotionAgenda;
/** ratify: 비상대권 포고를 의회가 추인하는 표결(통과하면 남고, 안 되면 사라진다) */
/** amend: 변형 법(7.3)을 올리는데 원래 법이 서 있으면 개정 표결이다. 통과하면 원래 법이 내려가고 변형이 선다 */
/** promise: 열차장이 카드에서 다음 회기에 올리겠다고 한 안건(죽음의 무게 「식은 난로」). AI 발의가 와도 지우지 않고, 폐지 냉각을 기다리지 않는다 */
export interface LawAgenda { kind?: 'law'; law: LawId; repeal: boolean; by?: Comm; forced?: boolean; ratify?: boolean; amend?: LawId; promise?: boolean }
/** 판 난이도(결정 376). 없으면 보통이다(옛 저장 포함). 고르는 화면은 아직 없다 */
export type Difficulty = 'easy' | 'normal' | 'hard';
/** 법이 아닌 안건. 통과하면 바로 일이 일어나고 끝난다. 폐지·추인·재상정 쿨다운이 없다. */
export type MotionId = 'share' | 'trial' | 'no_confidence' | 'confidence' | 'pipe' | 'extend_powers' | 'ratify_decrees' | 'field_symbol' | 'field_promise';
/** ref: 안건이 가리키는 기록(재판이면 사건 번호, S1b) */
export interface MotionAgenda { kind: 'motion'; motion: MotionId; subject?: Comm; person?: string; by?: Comm; forced?: boolean; ref?: number; verdict?: 'kept' | 'broken' }

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
  /** 표결한 그때 비밀 투표였나. 비밀 투표 법을 통과·폐지한 표결이어도 화면은 표결 때 방식을 따른다(K01 2) */
  secret?: boolean;
  /** 개표 설명 한 줄: 미정·대표 몫 가운데 기대와 가장 크게 다르게 갈린 칸(정치 흐름 3.3). 고정 조건(꿈쩍 않는 반대·부재)은 표결 전 셈에 이미 있다 */
  why?: string;
}

export interface CouncilState {
  options: Agenda[];
  idx: number;
  locked: boolean;
  /** 안건 선택권을 넘겨받아 안건을 고른 칸(결과 아크) */
  holder?: Comm;
  deals: Deal[];
  result: VoteResult | null;
  /** 회기가 아닌 구간에 열차장이 부른 비상 소집 */
  emergency?: boolean;
  /** S1b 계엄 회기(s1b_martial_impl 3장): 법 안건만, 거래·정기 신임·재판 없음, 표결 대신 포고 하나 */
  martial?: boolean;
  /** 안건 자리를 먹지 않고 법 안건 앞에 따로 여는 표결(S1b 정기 신임, s1b_dark_path 5.3). result가 서면 끝났다 */
  pre?: { agenda: MotionAgenda; result?: VoteResult };
  /** 첫 귀환 뒤의 특별 회기(field_council.ts). 비상 소집처럼 열리고, 닫히면 정산 대신 연 단계로 돌아간다 */
  special?: boolean;
}

/** 저녁 솥불·벽 장부·떠난 사람의 밤이 구간마다 쌓는 값(calm.ts). 모두 선택 칸이라 옛 저장도 그대로 읽힌다. */
export interface CalmState {
  /** 솥불이 켜져 있는가. 없으면 석탄으로 정한다 */
  potOn?: boolean;
  /** 솥불이 켜진 채 지난 구간 수(일지 간격) */
  potSegs?: number;
  /** 벽 장부의 지난 처지('rich' 넉넉, 'mid' 사이, 'poor' 모자람) */
  ledger?: 'rich' | 'mid' | 'poor';
  ledgerSegs?: number;
  /** 지금까지 연 밤의 수 */
  nights?: number;
  /** 이 구간까지의 죽음은 이미 밤으로 셌다 */
  nightSeg?: number;
}

export interface JournalEntry { seg: number; text: string; tone?: 'good' | 'bad' | 'deal' | 'dark' }

/** 신임·긴장이 바뀐 까닭 한 줄(ui/repro.ts applyStep이 행동마다 남긴다). 값은 보이는 정수의 차이다. */
export interface MeterWhy { seg: number; label: string; trust: number; tension: number; sys?: WhySys }
/** 내가 한 일이 아니라 열차가 굴러가며 생긴 줄. 'settle'은 구간 정산 때, 'auto'는 그 밖의 진행 때. */
export type WhySys = 'settle' | 'auto';
/** 자원이 바뀐 까닭 한 줄(ui/repro.ts applyStep). 값은 보이는 정수의 차이다. */
export interface ResWhy { seg: number; label: string; coal: number; food: number; med: number; lux: number; sys?: WhySys }

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
  /** 석탄 0으로 선 열차(멈춘 열차). null·없음이면 달리는 중 */
  stranded?: StrandedState | null;
  /** 열차장이 나가 있어 미뤄 둔 회기(돌아온 뒤 다음 정차 뒤에 한 번 연다) */
  councilOwed?: boolean;
  /** 노선 구간 길이(km). 없는 구간은 P.segKmDefault */
  route?: RouteSeg[];
  strikeWarned: number;
  lostSegments: number;
  trustCrisis: number | null;
  tensionWarned: boolean;
  tensionCrisisUsed: number;
  /** 폭동(난장판) 상태 */
  riot: RiotState;
  emergencyUsed: boolean;
  guidedLeft: number;
  decreeLeft: number;
  /** 이번 대권에서 포고한 법과 마지막으로 포고한 구간 */
  decreed?: LawId[];
  decreeSeg?: number;
  /** 대권이 끝나 다음 회기 추인을 기다리는 포고 */
  ratify?: LawId[];
  /** 이번 대권에서 포고로 폐지한 법과, 대권이 끝나 추인을 기다리는 폐지(R3 카드 2, 2026-10-07) */
  decreedRepeals?: LawId[];
  ratifyRepeal?: LawId[];
  /** 1회 효과(신임·공포·식량)를 이미 받은 법. 다시 통과해도 또 받지 않는다(R3 카드 1) */
  onceTaken?: LawId[];
  /** 비상식량감축법이 선 뒤 꼬리칸 요구에 준 답과 그 답이 칸 처지에 더한 값(ration_cut.ts). 법을 폐지하면 되돌리고 지운다 */
  rationCut?: RationCutState;
  /** 손 몫(hands.ts): 정산 끝에 셈한 다음 구간의 손과 일마다 빈 몫. 판 시작·옛 저장 판에는 없어서 아무 일도 안 빈다 */
  hands?: HandsState;
  guardEscort: boolean;
  forcedRun: boolean;
  autoLevers: boolean;
  /** 배급장이 지지가 떨어져 장부를 내려놓은 적이 있다(다시 켜는 선 +20, 6.4) */
  autoDropped?: boolean;
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
  /** 회기 기록부: 표결마다 한 줄, 최근 줄만(council_log.ts). 옛 저장에는 없다 */
  councilLog?: CouncilLogRow[];
  /** 비상 소집을 부른 구간들 */
  emergencyCalls: number[];
  /** 식량 0으로 버틴 구간 수 */
  hunger: number;
  // ---- 사람의 무게(people.ts) ----
  /** 사람 카드가 마지막으로 온 구간(그다음 이동 사건을 쉰다) */
  peopleSeg?: number;
  /** 죽음 기록(원인 태그). 하차 장면이 죄책감과 애도를 가른다 */
  deathLog?: { seg: number; name: string; cause: 'chosen' | 'warned' | 'other'; witness?: boolean; comm?: Comm }[];
  /** 불만을 낮추는 법 셋(calm.ts)의 진행 값. 법이 선 적이 없으면 없다. */
  calm?: CalmState;
  /** 장작불 법: 다음 정차에 태우려고 지키는 시신 */
  pyre?: number;
  /** 냉동칸이 차서 살던 칸에 둔 시신(장작불 법). 그 칸 과밀이 시신마다 오른다. */
  pyreKin?: Partial<Record<Comm, number>>;
  /** 상중인 사람 */
  mourning?: { name: string; comm: Comm; until: number }[];
  /** 잠깐 오른 처지 */
  tempBase?: { c: Comm; i: 0 | 1 | 2 | 3; v: number; until: number }[];
  // ---- 죽음의 무게(death_weight.ts, 결정 353~355·367). 켜지 않은 판엔 모두 없다 ----
  /** enableDeathWeight를 부른 판 */
  deathWeight?: boolean;
  /** 칸마다 하나, 판에 둘까지 이어지는 사건 줄(원인 → 반발 → 고칠 길) */
  deathChains?: DeathChain[];
  /** 한 구간의 죽음 신임 깎임 합(상한을 셈). raw는 내림 전 합이라 한 명씩 와도 한꺼번에 와도 같은 값을 깎는다 */
  deathTrustAt?: { seg: number; sum: number; raw?: number };
  /** 판 난이도(결정 376). 없으면 보통 */
  difficulty?: Difficulty;
  /** 난방 배당 밤사이 죽음(같은 정산의 뒷사건 카드 하나) */
  heatAfter?: { seg: number; lost: Partial<Record<Comm, number>> };
  /** 다음 정차 작업조에서 빠지는 사람 수(음수면 더해지는 수) */
  crewShort?: number;
  /** 시뮬 재기용 셈 */
  deathStats?: { opened: number; fixed: number; unfixed: number; broken: number; maxOpen: number; cards: number };
  sickCount?: number;
  elderAsked?: boolean;
  /** 붙잡은 노인(사람의 무게 A3). 붙잡은 뒤 2구간 동안 식량이 바닥이면 밤에 혼자 내릴 수 있다. 내렸거나 기한이 지나면 지운다. */
  elderHeld?: { who: string; comm: Comm; at: number; until: number } | null;
  /** 스스로 열차에서 내린 사람 */
  left?: string[];
  /** 승강장에 남은 사람(출발 확인 쪽지, presentation_motion 5b.5). near면 쪽지 첫 줄에 '무리가 가깝다'. 출발하면 비운다 */
  platform?: { names: string[]; near: boolean };
  /** 두고 떠난 사람의 흔적(결정 425 카드 3, prologue.ts): 뒤 정차에 한 번 보이고 다시 태울 길이 한 번 열린다. shown이면 다시 안 뜬다 */
  trail?: { names: string[]; comm: Comm; seg: number; shown?: boolean };
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
  /** 칸마다 이 판에서 지킨 약속 수(약속 지킴의 말 한 줄을 고르는 데만 쓴다, promise_voice.ts). 옛 저장엔 없다. */
  keptVoice?: Partial<Record<Comm, number>>;
  /** 수업 기록(domestic/classroom.ts): 고른 곁과 끝 장면의 수 줄. 옛 저장엔 없다. */
  edu?: EduState;
  /** 끝 화면 「돌이켜 보면」 줄을 위한 기록(lookback.ts). 정산에서 읽어 적기만 하고 규칙은 읽지 않는다. 옛 저장엔 없다. */
  look?: {
    low: Partial<Record<'coal' | 'food' | 'wood' | 'scrap', number>>;
    skip: Partial<Record<'tailHeat' | 'heatQuota' | 'noInsulate' | 'tailRation' | 'contribution' | 'noOutsiders' | 'breakdown', number>>;
    coalStops: number;
  };
  /** 까닭 장부(ledger.ts). 규칙이 쌓고 화면이 행동마다 비운다. 저장에는 남지 않는다. */
  ledger?: { k: string; d: number; why: string }[];
  /** 신임·긴장이 최근 무엇 때문에 바뀌었나(사용자 2026-10-11). 화면에서 한 행동만 남는다(봇·시뮬 판엔 없다). 최근 것이 뒤. */
  meterLog?: MeterWhy[];
  /** 석탄·식량·의약품·사치품이 최근 무엇 때문에 바뀌었나. meterLog와 같은 길로 남는다. */
  resLog?: ResWhy[];
  /** 사치품 이름표(결정 071). 화면이 붙이고 떼며 규칙은 읽지 않는다(봇·시뮬 판엔 없다). 앞이 먼저 나간다. 없으면 「그 밖」으로 읽는다. */
  luxTags?: string[];
  /** 집단 관계가 최근 무엇 때문에 바뀌었나(바뀐 집단만). meterLog와 같은 길로 남는다. */
  relLog?: { seg: number; label: string; rel: Partial<Record<Comm, number>>; sys?: WhySys }[];
  journal: JournalEntry[];
  usedProfiles: string[];
  end: EndKind | null;
  stats: { dealsMade: number; promisesKept: number; promisesBroken: number; lawsPassed: number; lawsFailed: number; repeals: number; bribes: number; blackmails: number };
  /** 공간 레버(first_leg_story 6.4): 꼬리칸에 내준 단(0~2)과 내주는 칸. 옛 저장엔 없다. */
  space?: { step: number; giver: Comm | null };
  /** 마지막으로 작업조를 낸 칸(급수탑 눈 녹이기의 기본 칸) */
  lastCrew?: Comm;
  /** 지난 구간의 정차. 출발을 미룬 날 이번 정차가 없으면 이걸 한 번 더 뒤진다(결정 332) */
  lastStop?: StopState | null;
  /** 필드(S2)에서 직접 뛰고 돌아온 귀환 기록(field_receipt.ts). 직접 영수증이 들어온 판에만 있고, 주사위 정차만 도는 판엔 없다 */
  fieldReturns?: FieldReturns;
  /** S1c 내정(공방, 기술, 전문가, 위생). 없으면 S1a 판이다(domestic/state.ts). */
  dom?: DomState;
  /** 고른 기관차(결정 125). 없으면 c3(옛 저장과 안 고른 판). 게임 시작 때 setLoco(loco.ts)로 정한다. */
  loco?: LocoId;
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
  /** 콘텐츠 비밀: id → 단계(1 소문, 2 증거), 쥔 사람, 그 칸 */
  contentSecrets?: Record<string, { level: 1 | 2; who: string; comm: Comm }>;
  /** 받은 거래 조건과 치를 구간 */
  contentDeals?: { id: string; comm: Comm; due: number }[];
  /** 일대기 기록(틀 id, 누가, 어디서(정차 id, 이동 중이면 빈칸), 언제, 목격자 id). S3 일대기 화면이 읽는다 */
  chronicle?: { template: string; who: string; where: string; when: number; witnesses: string[]; from: string }[];
  /** 사람 기억(memory.ts): 사람 한 명이 겪거나 들은 일. 그 사람의 말·출발 화면·회고만 바꾸고 칸 관계·긴장·신임은 안 쓴다 */
  memory?: MemoryBook;
  /** 열차 안 사건이 사람 기억에 남기는 줄(사건 키 + 사람 id). 정산 때 memory.ts가 읽고 비운다 */
  personEvents?: PersonEvent[];
  /** 다음 표결 한 번에만 옮기는 표: 칸, 석 수, 쪽(captain은 열차장이 밝힌 편, 열차장이 올린 안건이면 찬성). 표결이 끝나면 지운다 */
  voteShift?: { comm: Comm; n: number; side: 'captain' | 'yes' | 'no' }[];
  /** 열차장 이름(열차장 만들기). S1a는 없어서 '열차장'으로 부른다 */
  captainName?: string;
  /** 희생양으로 이름이 불릴 수 있는 사람(프로필 id). 맡은 일·그 자리에 있었는지 같은 처지로만 켠다(칸·출신·이름 풀로 켜지 않는다). S1a엔 켜는 곳이 없다 */
  scapegoatOk?: string[];
  /** S1b 어두운 길(dark/state.ts). 없으면 S1a·S1c 판이다 */
  dark?: DarkState;
  /** 재난 시제품(disaster.ts)이 켜진 판. 없으면 꺼진 판이고 아래 세 칸도 없다 */
  disasters?: boolean;
  disaster?: DisasterState;
  /** 판 통계: 종류별로 예고가 뜬 횟수 */
  disasterStats?: Record<DisasterKind, number>;
  /** 마지막 재난이 끝난 구간 */
  disasterEnd?: number;
  /** 판 전체 재난 사망 수(상한 DZ.deathCap) */
  disasterDeaths?: number;
  /** 바깥 기온(climate.ts)이 켜진 판. 없으면 꺼진 판이고 아래 칸들도 없다 */
  climate?: boolean;
  /** 정찰 장비(domestic/scout_gear.ts, 결정 371)를 켠 판. 켜지 않은 판에는 r4·w4가 없고 핸드카에 갈래가 없다 */
  gearOn?: boolean;
  /** 적용된 기온 단계 0~4(출발 때만 계절표를 따라 바뀐다) */
  outside?: number;
  /** 남은 결빙 구간 */
  freeze?: number;
  /** 마지막으로 단계가 바뀐 출발(구간, 떠난 단계, 새 단계) */
  climateChange?: { seg: number; from: number; to: number };
  /** 날씨 글의 마지막 인칭(0 1인칭, 1 3인칭) */
  climateVoice?: number;
  /** 판 통계: 단계가 내려간 횟수, 결빙 횟수 */
  climateStats?: { drops: number; freezes: number };
  /** 카드 구간 예산(budget.ts)이 켜진 판. 없으면 꺼진 판이고 아래 deferred도 없다 */
  budget?: BudgetState;
  /** 예산 때문에 미뤄 둔 카드. 다음 구간 처음에 맨 앞으로 돌아온다 */
  deferred?: Card[];
  /** 새 이동 사건 묶음과 가중 뽑기(event_pack.ts)가 켜진 판. 없으면 꺼진 판 */
  eventPack?: true;
  /** 사람이 들어오는 사건(arrivals.ts)이 켜진 판. 없으면 꺼진 판이다 */
  arrivals?: ArrivalsState;
}

export type ArrivalKind = 'arrival' | 'family';
/** 수색대가 나가 있는 동안의 일(arrivals.ts). 다음 정차에 닿을 때 끝난다 */
export interface ArrivalPending {
  kind: ArrivalKind;
  /** 수색대가 나간 칸과 사람 */
  comm: Comm; names: string[];
  /** 위험 배수(정찰 식). 바깥이 고요했으면 0 */
  danger: number;
  /** 데려올 가족 묶음과 그 가운데 다친 사람 수 */
  groups: number[]; hurt: number;
  /** 아직 이번 정산 전이라 자리비움(away)에 이미 더해져 있다 */
  awayLive: boolean;
}
export interface ArrivalsState {
  /** 종류별로 뜬 횟수와 마지막으로 뜬 구간 */
  n: Record<ArrivalKind, number>;
  last: Record<ArrivalKind, number>;
  /** 칸마다 받은 사람 수 합과 처음 받기 전 인원 */
  byComm: Partial<Record<Comm, { got: number; popBefore: number }>>;
  pending?: ArrivalPending;
  /** 이번 구간 정산에 한 번 더 뺄 빈속 몫의 사람 수 */
  hungry?: number;
  /** 잠자리 다툼을 볼 칸과 구간 범위 */
  quarrel?: { comm: Comm; from: number; to: number };
  /** 판 통계: 받은 사람 수, 돌려보낸 사람 수 */
  taken: number; turned: number;
}

/** 이 칸에 남은 들어온 사람 수 h(결정 369, 명세 4장). 받은 수 합과 「지금 인원 − 처음 받기 전 인원」 가운데 작은 쪽, 0 아래 없음. 꺼진 판은 0 */
export function arrivedIn(g: Game, c: Comm): number {
  const a = g.arrivals?.byComm[c];
  return a ? Math.max(0, Math.min(a.got, g.comms[c].pop - a.popBefore)) : 0;
}

export type HubFate = 'stayed' | 'left' | 'persuaded' | 'forced';
export interface StoryState {
  /** 9.1 진행 단계. S1a는 출발 1(leg1_river), 라이프치히 6(leg1_hub)만 쓴다. */
  stage: number;
  flags: {
    /** 우리 쪽 첫 죽음(S1a 규칙으로만) */
    first_death?: boolean;
    /** 서막에서 운반조를 두고 떠났나(9.2) */
    depot_left_behind?: boolean;
    /** 서막 꼬리칸 대표의 약속(9.2). 없으면 서막을 거치지 않은 판이다 */
    depot_promise?: 'kept' | 'broken' | 'refused' | 'unknown';
    /** 두고 떠난 사람의 흔적에서 무엇을 했나(결정 425 카드 3): 다시 태움 / 쪽지만(걸어서 뒤따름, campaign_story 3.9) */
    trail?: 'back' | 'note';
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
/** 들어온 한 명이 처지에 주는 몫: 온기 −0.25, 배급 −0.4, 과밀 +0.75(명세 4장 값의 절반, 결정 385). tools/arrivals_sim.ts의 --sit로 바꿀 수 있게 값 칸을 둔다 */
export const ARRIVAL_SIT: [number, number, number] = [0.25, 0.4, 0.75];

export function situation(g: Game, c: Comm): [number, number, number, number] {
  const s = g.comms[c];
  // S1c: 기술·침구·장갑이 더하는 처지 보정(domestic/state.ts refreshSit). S1a 판엔 없다.
  const d = g.dom?.sit[c];
  // 공간 레버: 꼬리칸 과밀을 내주는 칸으로 옮긴다(6.4).
  const sp = g.space;
  const room = sp && sp.giver && sp.step > 0 ? (c === 'tail' ? -1 : c === sp.giver ? 1 : 0) * P.spaceStep * sp.step : 0;
  // 들어온 사람(arrivals.ts): 같은 난로·같은 솥·같은 바닥을 더 나눈다. 꺼진 판은 h가 0이라 값이 그대로다.
  const h = g.arrivals ? arrivedIn(g, c) : 0;
  return [
    // 난로와 물을 볼 손이 빈 만큼 모든 칸이 식는다(손 몫, hands.ts). 서로 불러오지 않게 g.hands를 바로 읽는다.
    clamp(s.base[0] + P.leverStep * (s.heat - 2) + (d?.[0] ?? 0) - ARRIVAL_SIT[0] * h - HANDS.stoveWarm * (g.hands?.short.stove ?? 0), 0, 100),
    clamp(s.base[1] + P.leverStep * (s.ration - 2) + (d?.[1] ?? 0) - ARRIVAL_SIT[1] * h, 0, 100),
    clamp(s.base[2] + (d?.[2] ?? 0) + room + ARRIVAL_SIT[2] * h, 0, 100),
    // 사람이 줄거나 손을 거둔 칸이 있어 남은 칸이 일을 나눠 지면 그 칸이 지친다(손 몫, hands.ts handsNow)
    clamp(s.base[3] + (d?.[3] ?? 0) + (g.hands?.expose?.[c] ?? 0), 0, 100),
  ];
}

/** 이야기 진행도. 옛 저장 데이터엔 없으니 처음 읽을 때 만든다. */
export function storyOf(g: Game): StoryState {
  return (g.story ??= { stage: 1, flags: { first_death: false, first_corpse_agenda: 'none' } });
}

export function totalPop(g: Game): number {
  return COMMS.reduce((sum, c) => sum + g.comms[c].pop, 0);
}

/** 관계 15 이상인 칸이 인구의 몇 할인가(하차 장면의 「크게 지지」, 멈춘 열차의 원정 문턱). */
export function supportShare(g: Game): number {
  const pop = totalPop(g) || 1;
  return COMMS.reduce((sum, c) => sum + (g.comms[c].rel >= 15 ? g.comms[c].pop : 0), 0) / pop;
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

/** 위로 카드를 여는 열쇠(결정 016 '이룬 뒤에만'). 일을 제때 이룬 자리마다 세운다: 배관 추인, 새 카드의 제값 치른 선택(법 통과·다친 사람 없는 정차·지킨 약속은 거의 매 판 서서 뺐다). */
export function achieve(g: Game): void {
  (g.contentFlags ??= {}).ev_achieved = true;
}

export function journal(g: Game, text: string, tone?: JournalEntry['tone']): void {
  g.journal.push({ seg: g.seg, text, ...(tone ? { tone } : {}) });
}

/** 카드 구간 예산(budget.ts)이 걸어 두는 자리. import 순환을 피하려고 여기 둔다. g.budget이 있는 판에서만 불린다. */
export const BUDGET_HOOK: { onAdd: ((g: Game) => void) | null } = { onAdd: null };

export function addCard(g: Game, card: Omit<Card, 'uid'>): void {
  g.cards.push({ uid: g.nextCardUid, ...card });
  g.nextCardUid += 1;
  if (g.budget) BUDGET_HOOK.onAdd?.(g);
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
    tensionCrisisUsed: 0, riot: riotStart(), emergencyUsed: false, guidedLeft: 0, decreeLeft: 0, guardEscort: false, forcedRun: false,
    autoLevers: false, actedSeg: 0, proposals: [], agendaHolder: null, cards: [], recentEvents: [], eventLog: {}, needs: {}, emergencyCalls: [], hunger: 0, linesSeen: [], hiddenBites: [], nextCardUid: 1, stop: null,
    council: null, lastSettle: null, journal: [], usedProfiles: [], end: null,
    stats: { dealsMade: 0, promisesKept: 0, promisesBroken: 0, lawsPassed: 0, lawsFailed: 0, repeals: 0, bribes: 0, blackmails: 0 },
  } as Game;
  for (const c of COMMS) {
    const person = drawPerson(g, c, REP_AGE[c]);
    const banned = TRAIT_BAN[c];
    const traits = TRAITS.filter(t => t !== banned);
    g.comms[c] = {
      base: [...START[c]], heat: 2, ration: 2, rel: REL0[c], coh: COH0[c], fervor: 0, badStreak: 0, backStreak: 0, grudge: 0,
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
