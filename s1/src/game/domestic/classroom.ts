import { bumpRel } from '../ledger';
import type { LawId } from '../data';
import { journal, lawActive } from '../state';
import type { Game } from '../state';
import { domCard } from './state';

// 수업과 아동 노동(결정 205·207·208·209·214·223·224). 교육 법 셋(글과 셈, 일 배우기, 엔진의 가르침)은 무엇을 가르치나를 정하고,
// 법이 서면 열차장이 「어디 곁에서 배우나」(공방 곁 / 의무칸 곁)를 한 번 고른다. 아이를 가르치는 시간만큼 승강장의 손이 준다:
// 교육 법과 아동 노동이 같이 서면 둘 다 반이다(반반). 다른 파일은 여기의 물음 함수만 부른다.

export const EDU_LAWS: LawId[] = ['edu_letters', 'edu_trade', 'edu_engine'];
export type EduSide = 'workshop' | 'med';

/** 판에 쌓는 수업 기록. 곁(side)만 규칙이 읽고 나머지 셋은 끝 장면의 수 줄(lookback.ts)과 상처 줄만 읽는다. 옛 저장엔 없다. */
export interface EduState {
  side?: EduSide;
  /** 수업이 선 구간 수 */
  segs: number;
  /** 수업 덕에 하루 먼저 일어난 사람 수 */
  early: number;
  /** 아이들이 승강장에 선 정차 수 */
  hands: number;
  /** 상처 줄을 마지막으로 적은 구간(구간마다 한 줄) */
  lineSeg?: number;
  /** 수업이 서 있는 채로 세운 아동 노동: 한 번짜리 벌을 반만 치렀으니 폐지할 때도 반만 거둔다 */
  halfMat?: Partial<Record<LawId, boolean>>;
}

export const eduOf = (g: Game): EduState => (g.edu ??= { segs: 0, early: 0, hands: 0 });

export const eduLaw = (g: Game): LawId | null => EDU_LAWS.find(l => lawActive(g, l)) ?? null;
/** 서 있는 아동 노동(짐 꾸리기만 포함) */
export const childLaw = (g: Game): 'child_labor' | 'child_pack' | null => (lawActive(g, 'child_labor') ? 'child_labor' : lawActive(g, 'child_pack') ? 'child_pack' : null);
/** 반반: 수업과 아동 노동이 같이 서 있다(결정 205, 짐 꾸리기만과도 반이다) */
export const halved = (g: Game): boolean => !!eduLaw(g) && !!childLaw(g);
/** 지금 서 있는 수업이 받는 곁. 법이 없거나 아직 안 골랐으면 null */
export const eduSide = (g: Game): EduSide | null => (g.dom && eduLaw(g) ? g.edu?.side ?? null : null);
/** 곁의 이득이 온전하면 1, 반반이면 0.5 */
const share = (g: Game): number => (halved(g) ? 0.5 : 1);

/** 결정 205: 승강장의 손. 아동 노동만 +15%, 수업만 +0%, 반반이면 절반. 짐 꾸리기만은 +10%의 절반. */
export function handsPct(g: Game): number {
  const c = childLaw(g);
  if (!c) return 0;
  return (c === 'child_labor' ? 15 : 10) * share(g);
}

/** 법 하나의 산출 배수. 반반이면 덤(1을 넘는 몫)을 반으로 센다. */
export function childHaul(g: Game, law: LawId, v: number): number {
  return (law === 'child_labor' || law === 'child_pack') && halved(g) ? 1 + (v - 1) / 2 : v;
}

// ---- 곁의 이득 ----
/** 공방의 일에 더하는 몫: 공방 곁이면 +1, 반반이면 +0.5 */
export const workBonus = (g: Game): number => (eduSide(g) === 'workshop' ? share(g) : 0);

/** 복원의 목재와 고철이 덜 드는 몫(결정 223): 공방 곁이면 넷에 하나, 반반이면 여덟에 하나 */
export const restoreSave = (g: Game): number => (eduSide(g) === 'workshop' ? 0.25 * share(g) : 0);
/** 복원에 드는 목재나 고철 n에 덜 드는 몫을 센다. 올림이고 0은 0이며 1 아래로는 안 내려간다. */
export function saveRestore(g: Game, n: number): number {
  const s = restoreSave(g);
  return s > 0 && n > 0 ? Math.max(1, Math.ceil(n * (1 - s))) : n;
}
export const restoreSaved = (g: Game, n: number): number => n - saveRestore(g, n);

/** 새 상처가 낫는 날에서 더 빼는 몫(깊은 상처와 골절만). 반반이면 둘에 하나(상처 번호가 짝수일 때) */
export function healCut(g: Game, grade: string, woundId: number): number {
  if (eduSide(g) !== 'med' || (grade !== 'deep' && grade !== 'fracture')) return 0;
  return halved(g) && woundId % 2 === 1 ? 0 : 1;
}

/** 기관 견습이 한 단계 오르는 구간(결정 209): 엔진의 가르침이 서 있으면 −1, 바닥 2구간. 반반이면 둘에 하나만. key는 사람과 단계에서 뽑은 수. */
export function engineLearn(g: Game, field: string, base: number, key: number): number {
  if (field !== 'engine' || !lawActive(g, 'edu_engine')) return base;
  const cut = halved(g) && key % 2 === 1 ? 0 : 1;
  return Math.max(Math.min(base, 2), base - cut);
}

/** 낮 난방 석탄(구간마다): 글과 셈만, 반반이면 절반 */
export const dayCoal = (g: Game): number => (lawActive(g, 'edu_letters') ? 0.25 * share(g) : 0);

// ---- 아동 노동 ----
/** 법이 서 있는 동안 정산마다의 벌: 의무진 관계 −1(반반이면 −0.5). 세운 그 정산부터. 폐지하면 멈추고 이미 깎인 것은 돌려주지 않는다. */
export function childSettle(g: Game, notes: string[]): void {
  if (!lawActive(g, 'child_labor')) return;
  const d = halved(g) ? 0.5 : 1;
  bumpRel(g, 'medtech', -d, 'child');
  notes.push(CHILD_NOTE[g.seg % CHILD_NOTE.length].replace('{d}', String(d)));
}
const CHILD_NOTE = [
  '의무진이 승강장 일을 적어 두었다. 의무진 관계 −{d}.',
  '의무진은 이번 구간에도 말이 없었다. 의무진 관계 −{d}.',
  '의무칸 문에 동상 걸린 손의 수가 적혔다. 의무진 관계 −{d}.',
];

/** 수업이 서 있는 구간을 센다(정산마다) */
export function eduSettle(g: Game, notes: string[]): void {
  if (!eduLaw(g)) return;
  eduOf(g).segs += 1;
  const c = dayCoal(g);
  if (c > 0) notes.push(`식당칸 난로를 낮에도 땠다. 석탄 −${c}.`);
}

const pctText = (p: number): string => `+${Number.isInteger(p) ? p : p.toFixed(1)}%`;

/** 정차 결과의 산출 줄: 아이 손이 보탠 몫을 한 줄로(수업만이면 +0%). 법이 둘 다 없으면 빈 글. */
export function handsNote(g: Game): string | null {
  const c = childLaw(g);
  const e = eduLaw(g);
  if (!c && !e) return null;
  if (c && e) return c === 'child_labor' ? `아이들은 반나절만 짐을 받았다. 산출 ${pctText(handsPct(g))}.` : `아이들은 반나절만 짐을 꾸렸다. 산출 ${pctText(handsPct(g))}.`;
  if (c === 'child_labor') return `${g.seg % 2 === 0 ? '아이들이 승강장에서 짐을 받았다.' : '승강장에 작은 손이 섰다.'} 산출 ${pctText(handsPct(g))}.`;
  if (c) return null;
  return g.seg % 2 === 0 ? '아이들은 열차에 남아 배웠다. 승강장의 손 +0%.' : '오늘 승강장에는 어른만 섰다.';
}

/** 아이들이 승강장에 선 정차를 센다(짐 꾸리기만은 아이들이 내리지 않으니 세지 않는다). */
export function countHands(g: Game): void {
  if (lawActive(g, 'child_labor')) eduOf(g).hands += 1;
}

// ---- 상처 줄 ----
const HEAL_LINE = ['붕대를 미리 삶아 둔 손이 있었다. 하루 먼저 일어난다.', '의무칸에 물과 천이 떨어지지 않았다. 하루 먼저.'];
export const healLine = (woundId: number): string => HEAL_LINE[woundId % 2];
/** 수업 덕에 날이 줄어든 상처가 생겼다: 구간마다 일지 한 줄 */
export function healNote(g: Game, woundId: number): void {
  const e = eduOf(g);
  if (e.lineSeg === g.seg) return;
  e.lineSeg = g.seg;
  journal(g, healLine(woundId));
}

// ---- 곁 고르기 ----
export const SIDE_NAME: Record<EduSide, string> = { workshop: '공방 곁', med: '의무칸 곁' };

/** 곁을 고른다. 교육 법이 서 있을 때만 받는다. */
export function chooseSide(g: Game, side: EduSide): boolean {
  if (!g.dom || !eduLaw(g)) return false;
  eduOf(g).side = side;
  return true;
}

// ---- 화면 글 ----
/** 식당칸 창의 교실 줄: 서 있는 답, 고른 곁, 「반나절만」 */
export function classroomLine(g: Game): string | null {
  const law = eduLaw(g);
  if (!law) return null;
  const side = eduSide(g);
  return `${ANSWER_NAME[law]}${side ? ` · ${SIDE_NAME[side]}` : ' · 곁을 아직 안 골랐다'}${halved(g) ? ' · 반나절만' : ''}`;
}
const ANSWER_NAME: Partial<Record<LawId, string>> = { edu_letters: '글과 셈', edu_trade: '일 배우기', edu_engine: '엔진의 가르침' };

/** 끝 장면(「돌이켜 보면」 곁)에 붙는 수 줄. 수업이 선 적이 없고 승강장에 선 적도 없으면 없다. 꾸짖지 않는 보통 줄이다. */
export function eduLookLines(g: Game): string[] {
  const e = g.edu;
  if (!e) return [];
  const out: string[] = [];
  if (e.segs > 0) out.push(`수업은 ${e.segs}구간 섰다. 하루 먼저 일어난 사람 ${e.early}.`);
  if (e.hands > 0) out.push(`아이들이 승강장에 선 정차 ${e.hands}.`);
  return out;
}

// ---- 법을 세우고 내릴 때 ----
const isChild = (law: LawId): boolean => law === 'child_labor' || law === 'child_pack';

/** 아동 노동을 세울 때 한 번짜리 벌(노출·꼬리칸 관계·공포)에 곱할 몫. 수업이 이미 서 있으면 반이다. 교육 법을 뒤에 세우면 이미 치른 벌은 돌려주지 않는다. */
export function enactScale(g: Game, law: LawId): number {
  if (!isChild(law) || !eduLaw(g)) return 1;
  (eduOf(g).halfMat ??= {})[law] = true;
  return 0.5;
}

/** 아동 노동을 내릴 때(또는 변형으로 고칠 때) 되돌릴 노출의 몫. 반만 치렀으면 반만 거둔다. */
export function repealScale(g: Game, law: LawId): number {
  const half = g.edu?.halfMat;
  if (!half?.[law]) return 1;
  delete half[law];
  return 0.5;
}

/** 교육 법이 섰다: 곁을 아직 안 골랐으면 열차장에게 묻는 서류를 올린다(교사를 고르는 자리가 아직 없어 곁만 묻는다). */
export function eduEnacted(g: Game, law: LawId): void {
  if (!g.dom || !EDU_LAWS.includes(law)) return;
  journal(g, `${LAW_TITLE[law]}을(를) 가르치기로 했다. 아이들은 열차에 남는다.`);
  if (!g.edu?.side && !g.cards.some(c => c.kind === 'dom:side')) domCard(g, { kind: 'dom:side' });
}
const LAW_TITLE: Partial<Record<LawId, string>> = { edu_letters: '글과 셈', edu_trade: '일 배우기', edu_engine: '엔진의 가르침' };
