import type { Fx } from './fx';
import type { Comm, Game } from '../game';

// 화면끼리 나눠 쓰는 형식과 열차 칸 배치.

export type Screen = 'home' | 'overview' | 'council' | 'end';
export type Panel = null | 'unrest' | 'support' | 'journal' | 'menu' | 'debug' | 'settle' | 'dom';

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
  /** 이름을 눌러 연 사람 정보(전체 이름) */
  person: string | null;
  /** 정차 직전 브레이크 연출 중 */
  braking: boolean;
  /** 방금 고른 선택이 바꾼 수치(위 막대 연출, fx.ts) */
  fx?: Fx | null;
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

export function fmt(n: number): string {
  return String(Math.round(n));
}
export function signed(n: number): string {
  const r = Math.round(n);
  return r > 0 ? `+${r}` : r < 0 ? `−${Math.abs(r)}` : '0';
}
