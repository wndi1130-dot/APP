import type { Fx } from './fx';
import type { Comm, Game } from '../game';
import type { ToastKind } from './notice';

// 화면끼리 나눠 쓰는 형식과 열차 칸 배치.

export type Screen = 'home' | 'overview' | 'council' | 'end';
export type Panel = null | 'unrest' | 'support' | 'journal' | 'menu' | 'debug' | 'settle' | 'dom' | 'why-trust' | 'why-tension' | 'why-coal' | 'why-food' | 'why-med' | 'why-lux';

/** S1c 내정 창의 화면 상태(ui/domestic.ts). S1a 판에선 쓰지 않는다. */
export interface DomUi { tab: 'workshop' | 'plan' | 'board' | 'move'; node: string | null; order: string[] | null; mats: boolean }

export interface Ui {
  screen: Screen;
  panel: Panel;
  /** 홈에서 누른 칸의 작은 창 */
  carPop: string | null;
  /** 꼬리칸 창에서 레버 대신 공간 레버(6.4)를 펼쳤나 */
  spaceOpen?: boolean;
  /** 서류(결정 카드)가 펼쳐졌나 */
  cardOpen: boolean;
  /** 정차 결과를 읽고 덮었나 */
  stopSeen: boolean;
  /** 출발 레버가 걸렸는데 승강장에 사람이 남아 묻는 중(ask), '떠난다'를 골라 이름을 긋는 중(leaving). depart.ts */
  departAsk?: 'ask' | 'leaving' | null;
  overviewSel: string;
  numbersOnly: boolean;
  /** 의회에서 고른 쐐기 */
  selComm: Comm | null;
  /** 공개 협상 조건을 펼친 집단 */
  dealOpen: Comm | null;
  /** 칼질 대상 고르기 중인 조건 순번 */
  cutPick: number | null;
  /** 개표 연출: 갈린 미정 수. null이면 연출 없음 */
  count: number | null;
  toast: string | null;
  /** 알림 종류. 경고(warn)는 호박색에 6초, 눌러 닫는다(notice.ts) */
  toastKind?: ToastKind | null;
  /** 두 번 눌러 확정: 첫 탭의 동작과 시각(notice.ts) */
  confirm?: { action: string; t: number } | null;
  /** 이름을 눌러 연 사람 정보(전체 이름) */
  person: string | null;
  /** 정차 직전 브레이크 연출 중 */
  braking: boolean;
  /** 방금 고른 선택이 바꾼 수치(위 막대 연출, fx.ts) */
  fx?: Fx | null;
  /** 눌러서 닫은 바뀐 것 쪽지의 fx.id */
  slipOff?: number;
  debug: boolean;
  /** S1c 내정 창(없으면 domestic.ts가 채운다) */
  dom?: DomUi;
}

export interface View { g: Game; ui: Ui }

export interface CarDef { id: string; comm?: Comm; name: string; plate: string; kind: 'comm' | 'dining' | 'captain' | 'engine' | 'loco' | 'freight' | 'cold' }

// 왼쪽이 꼬리, 오른쪽이 기관차(2026-10-06 홈 시안).
// 13칸 편성(s1c_domestic 4.2): 사람이 자는 칸은 낡은 객차, 닫힌 화차는 짐·석탄·기계만 싣는다(2026-10-07 사용자 결정).
export const CARS: CarDef[] = [
  { id: 'tail3', comm: 'tail', name: '꼬리칸 3', plate: '꼬리', kind: 'comm' },
  { id: 'tail2', comm: 'tail', name: '꼬리칸 2', plate: '꼬리', kind: 'comm' },
  { id: 'tail1', comm: 'tail', name: '꼬리칸 1', plate: '꼬리', kind: 'comm' },
  // 냉동칸은 화차가 아니라 난방을 끊은 낡은 객차다(사용자 카드 '찬 객차로', s1c_domestic 4.1).
  { id: 'cold', name: '냉동칸', plate: '냉동', kind: 'cold' },
  { id: 'store', name: '창고칸', plate: '창고', kind: 'freight' },
  { id: 'medtech', comm: 'medtech', name: '의무칸', plate: '의무', kind: 'comm' },
  { id: 'dining', name: '식당칸', plate: '의회', kind: 'dining' },
  { id: 'guard', comm: 'guard', name: '경비대칸', plate: '경비', kind: 'comm' },
  { id: 'captain', name: '열차장실', plate: '일지', kind: 'captain' },
  { id: 'front', comm: 'front', name: '앞칸', plate: '앞칸', kind: 'comm' },
  { id: 'workshop', name: '공방칸', plate: '공방', kind: 'freight' },
  { id: 'engine', comm: 'engine', name: '기관실·탄수차', plate: '기관', kind: 'engine' },
  { id: 'loco', name: '기관차', plate: '', kind: 'loco' },
];

/** 한눈에 보기의 칸 묶음(같은 종류의 칸을 묶는다). */
export interface GroupDef { id: string; comm?: Comm; name: string; cars: string[] }
export const GROUPS: GroupDef[] = [
  { id: 'engine', comm: 'engine', name: '기관실', cars: ['loco', 'engine'] },
  { id: 'front', comm: 'front', name: '앞칸', cars: ['front'] },
  { id: 'captain', name: '열차장실', cars: ['captain'] },
  { id: 'guard', comm: 'guard', name: '경비대', cars: ['guard'] },
  { id: 'dining', name: '식당칸', cars: ['dining'] },
  { id: 'medtech', comm: 'medtech', name: '기술·의무진', cars: ['medtech'] },
  { id: 'tail', comm: 'tail', name: '꼬리칸', cars: ['tail1', 'tail2', 'tail3'] },
];

// 의회 반원의 쐐기 순서: 균등(왼쪽)에서 기여·규율(오른쪽)으로.
export const WEDGE_ORDER: Comm[] = ['tail', 'medtech', 'front', 'engine', 'guard'];

/** 탭하면 쪽지로 뜨는 설명 글(ui/widgets.ts tip). 폰엔 title 툴팁이 없다. 기준은 game/turn.ts drift()와 작업조 crewGain·crewRest. */
export const TIP = {
  exposure: '위험 노출: 바깥 일과 궂은일에 얼마나 내몰리나. 50을 넘으면 그 칸 관계가 구간마다 깎인다. 작업조로 내보내면 오르고, 안 내보낸 칸은 쉬면서 내려간다.',
  warmth: '온기: 그 칸이 얼마나 따뜻한가. 45 아래면 관계가 구간마다 깎인다. 난방 레버로 올린다.',
  ration: '배급: 그 칸이 얼마나 먹는가. 45 아래면 관계가 구간마다 깎인다. 배급 레버로 올린다.',
  crowding: '과밀: 그 칸이 얼마나 빽빽한가. 60을 넘으면 관계가 구간마다 깎인다.',
  secrets: '쥔 비밀: 문서에서 찾은 대표의 약점. 의회에서 그 칸을 협박하는 데 쓰고, 쓰면 사라진다.',
  unrest: '불만: 관계가 −15 아래로 내려간 칸이 의회에서 차지하는 비율. 칸이 그 선을 넘을 때만 바뀐다. 그 전의 움직임은 띠 조각 안의 붉은 채움과 띠 아래 쪽지(꼬리 −5 같은 것)로 보인다.',
  neutral: '중립: 관계가 −15와 +15 사이인 칸이 의회에서 차지하는 비율. 조각 안의 채움이 왼쪽에서 붉게 차면 불만으로, 오른쪽에서 푸르게 차면 지지로 넘어가는 중이다.',
  support: '지지: 관계가 +15 위로 올라간 칸이 의회에서 차지하는 비율. 칸이 그 선을 넘을 때만 바뀐다.',
  symbols: '상징물: 출발 종 같은 이름 있는 물건. 경비대가 가져오길 바라고, 사건에서 내놓을 수 있다. 내정을 켠 판에선 칸에 걸어 두면 그 칸 결속이 구간마다 조금 오르고, 내리거나 잃으면 크게 깎인다.',
} as const;

/** 정차 서류에서 고른 목표의 한 줄 설명. 산출 환산은 game/turn.ts resolveStop. */
export const TARGET_NOTE: Record<'coal' | 'food' | 'medicine' | 'luxury' | 'symbol' | 'secret', string> = {
  coal: '열차를 달리게 하는 연료. 구한 만큼 그대로 쌓인다.',
  food: '모두의 끼니. 바닥나면 모든 칸 관계가 깎인다.',
  medicine: '다친 이와 아픈 이에게 쓴다. 의무진이 바라는 물건이다.',
  luxury: '앞칸이 바라고 뇌물에 쓴다. 산출이 3분의 1로 줄어 얻기 어렵다.',
  symbol: '출발 종 같은 이름 있는 물건. 경비대가 바라고 사건에서 내놓을 수 있다. 10에 하나꼴, 한 번에 최대 2.',
  secret: '문서에서 대표의 약점을 찾아 \'쥔 비밀\'로 쥔다. 의회에서 협박에 쓴다. 10에 하나꼴, 한 번에 최대 2.',
};

export function fmt(n: number): string {
  return String(Math.round(n));
}
export function signed(n: number): string {
  const r = Math.round(n);
  return r > 0 ? `+${r}` : r < 0 ? `−${Math.abs(r)}` : '0';
}
