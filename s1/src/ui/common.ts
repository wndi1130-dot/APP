import type { Comm, Game } from '../game';

// 화면끼리 나눠 쓰는 형식과 열차 칸 배치.

export type Screen = 'home' | 'overview' | 'council' | 'end';
export type Panel = null | 'unrest' | 'support' | 'journal' | 'menu' | 'debug' | 'settle';

export interface Ui {
  screen: Screen;
  panel: Panel;
  /** 홈에서 누른 칸의 작은 창 */
  carPop: string | null;
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
  debug: boolean;
}

export interface View { g: Game; ui: Ui }

export interface CarDef { id: string; comm?: Comm; name: string; plate: string; kind: 'comm' | 'dining' | 'captain' | 'engine' | 'loco' }

// 왼쪽이 꼬리, 오른쪽이 기관차(2026-10-06 홈 시안).
export const CARS: CarDef[] = [
  { id: 'tail3', comm: 'tail', name: '꼬리칸 3', plate: '꼬리', kind: 'comm' },
  { id: 'tail2', comm: 'tail', name: '꼬리칸 2', plate: '꼬리', kind: 'comm' },
  { id: 'tail1', comm: 'tail', name: '꼬리칸 1', plate: '꼬리', kind: 'comm' },
  { id: 'medtech', comm: 'medtech', name: '의무칸', plate: '의무', kind: 'comm' },
  { id: 'dining', name: '식당칸', plate: '의회', kind: 'dining' },
  { id: 'guard', comm: 'guard', name: '경비대칸', plate: '경비', kind: 'comm' },
  { id: 'captain', name: '열차장실', plate: '일지', kind: 'captain' },
  { id: 'front', comm: 'front', name: '앞칸', plate: '앞칸', kind: 'comm' },
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
