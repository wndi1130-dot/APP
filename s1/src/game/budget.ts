import { BUDGET_HOOK, isGone, journal, situation } from './state';
import type { Card, Game } from './state';
import { familyOf } from './people';
import { personById } from './domestic/state';

// 카드 구간 예산(docs/design/briefs/events_disasters.md 3.1, 제안). 기본 꺼짐: enableBudget(g)를 부른 판에서만 돈다.
// 한 구간에 플레이어가 고르는 카드는 BUDGET.perSeg(3)장까지. 이미 고른 수 + 대기 중 카드가 넘치면 등급이 낮은(숫자가 큰) 것부터 g.deferred로 뺀다.
//  - 등급 1·2: 미루지 않는다(넘겨도 둔다).
//  - 등급 3·4: 미루기만 한다. 사라지지 않고 다음 구간 처음에 맨 앞으로 돌아온다.
//  - 등급 5~7: 한 번 밀리면 다음 구간으로, 두 번째 밀리면 일지 한 줄로 바뀌고 사라진다.
// 돌아올 때 카드가 가리키는 사람·일이 이미 없으면 조용히 버린다(gone).
// 꺼진 판은 이 파일의 어떤 함수도 상태를 만들거나 난수를 쓰지 않는다. 난수는 이 파일 어디에서도 쓰지 않는다.

/** 시뮬의 --set=perSeg:4 로 바꾼다(tools/s1c_sim.ts). returnMax는 구간 처음에 돌아오는 카드의 최대 장수(기본 99 = 제한 없음. 2로 두면 4장+ 비율은 거의 그대로고 dom:fit 제안이 판당 1.6장 흐지부지돼서 껐다)(나머지는 한 구간 더 미룬다, 5~7등급은 두 번 밀림에 센다). askExempt 1이면 단추로 청한 서류(card.ask)는 미루지 않는다. 0이면 다른 등급 6 카드처럼 미룬다(측정용) */
export const BUDGET = { perSeg: 3, askExempt: 1, returnMax: 99 };

export type Grade = 1 | 2 | 3 | 4 | 5 | 6 | 7;

export interface KindRule {
  /** 실제로 적용하는 등급. 미뤄도 안전하지 않은 카드는 브리프 등급이 3~7이어도 2로 둔다 */
  grade: Grade;
  /** 브리프(3.1)의 등급. 안전하지 않아 2로 올린 카드만 적는다 */
  brief?: Grade;
  /** 미뤄도 말이 되는가. 등급 1·2는 미루지 않으니 false다 */
  safe: boolean;
  why: string;
}
const R = (grade: Grade, safe: boolean, why: string, brief?: Grade): KindRule => ({ grade, safe, why, ...(brief ? { brief } : {}) });

/** 카드 kind → 등급. 한 곳의 표다. 새 카드 종류를 만들면 여기 먼저 넣는다(tests/game/budget.test.ts가 소스를 훑어 막는다). */
export const CARD_GRADE: Record<string, KindRule> = {
  // 1 재난
  disaster_prep: R(1, false, '예고 구간에만 뜻이 있다. 출발하면 disaster.ts가 카드를 지운다'),
  // 2 시계 달린 위기
  tension_crisis: R(2, false, '긴장 100, 마지막 기회'),
  trust_crisis: R(2, false, '신임 바닥, 3구간 기한'),
  need_warn: R(2, false, '법 요구 기한(needs.ts)'),
  strike_warn: R(2, false, '다음 역까지의 파업 경고'),
  strike: R(2, false, '열차가 서 있는 지금의 일'),
  bite_found: R(2, false, '숨긴 물림 기한(biteTick)·시신에게 물림, 감염 창'),
  'dark:mob': R(2, false, 'S1b 군중 시계'),
  // 정차 뒤 도덕: 그 정차 이야기라 미루면 말이 안 된다
  rescue: R(2, false, '지금 선 역 이야기("역사 안에")이고 witness 효과가 g.stop을 읽는다', 3),
  bitten: R(2, false, '감염 창이 닫히기 전에 자르는 카드이고 witness 효과가 g.stop을 읽는다', 3),
  // 3 사람 사건(미루기만, 사라지지 않음)
  orphan: R(3, true, '아이가 남아 있는 동안 뜻이 있다. 아이가 없어지면 버린다'),
  keepsake: R(3, true, '죽은 사람의 칸 이야기. 칸은 그대로 있다'),
  rep_sick: R(3, true, '대표가 앓는 동안만. 일어났으면 버린다'),
  elder: R(3, true, '노인이 열차에 있는 동안. 내렸거나 죽었으면 버린다'),
  birth: R(3, true, '어머니가 살아 있는 동안. 죽었으면 버린다'),
  naming: R(3, true, '어머니가 살아 있고 아이가 살았을 때. 아니면 버린다'),
  // 4 내정의 필수 카드, 어두운 길의 미룰 수 있는 카드
  'dom:fork': R(4, true, '복원 갈래 선택. 안 고르면 복원이 시작되지 않을 뿐이다. 이미 시작했으면 버린다'),
  'dom:short': R(4, true, '부품이 모자란 상태 그 자체. 고르기 전엔 벌도 없다'),
  'dom:demand': R(4, true, '대체 불가 인력의 요구. 그 사람이 없으면 버린다'),
  'dom:box': R(4, true, '기관 매뉴얼이 사라진 사실. 고르기 전엔 변화가 없다'),
  'dom:full': R(4, true, '창고 넘침 규칙. 넘침이 이어지면 같은 서류를 새로 만들지 않고 합친다'),
  'dom:bed': R(4, true, '침상 순서 규칙. 정하기 전엔 기본 규칙이다'),
  'dom:officer': R(4, true, '간부가 대신 정한 일. 그 간부가 없으면 버린다'),
  'dom:lice': R(4, true, '이가 도는 칸 이야기. 정하기 전엔 endureDue가 안 흐른다'),
  'dark:armory': R(4, true, 'S1b가 스스로 미룰 수 있다고 한 카드(armoryDue)'),
  // 4지만 미루면 말이 안 되는 어두운 길·내정 카드: 2로 둔다
  'dom:typhus': R(2, false, '열병이 구간마다 흐른다. 환자 처리를 정하기 전에 죽고 번진다', 4),
  'dom:pressure': R(2, false, '지금 달리는 열차의 압력 경고(출발 때)', 4),
  'dom:stoker': R(2, false, '지금의 파업 이야기. 파업이 끝났으면 말이 안 된다', 4),
  'dom:elder': R(2, false, '쓰러지는 때가 s0~s1구간으로 정해져 있다. 미루면 조짐이 쓰러진 뒤에 온다', 4),
  'dark:sign': R(2, false, '기척·임박 쪽지. 사건은 출발 직후(darkTravel) 일어나서 미루면 일이 난 뒤에 온다', 4),
  'dark:act': R(2, false, '일이 난 뒤의 보고이고 수사 시계가 같이 흐른다', 4),
  'dark:theft': R(2, false, '도둑질 보고와 수사 시계', 4),
  'dark:case': R(2, false, '수사 시계(clock). 미루면 시계만 흐른다', 4),
  'dark:punish': R(2, false, '수사·재판에 묶인 벌 결정', 4),
  'dark:truth': R(2, false, '진실이 드러나기 직전의 기한', 4),
  'dark:hostile': R(2, false, '다음 회기 불신임 동의. 회기가 지나면 말이 안 된다', 4),
  'dark:exec_threat': R(2, false, '협박이 오는 그 순간의 대응', 4),
  'dark:order_exe': R(2, false, '명령 사슬의 한 단계(startOrder 직후)', 4),
  'dark:order_method': R(2, false, '명령 사슬의 한 단계(setExe 직후)', 4),
  'dark:order_done': R(2, false, '명령 결과 보고와 수사 시작', 4),
  'dark:order_fail': R(2, false, '명령 실패 보고와 수사 시작', 4),
  'dark:corpse_rule': R(2, false, '갓 생긴 시신의 확인 규칙(d.fresh)', 4),
  'dark:vigil': R(2, false, '그 정차·그 시신의 밤샘', 4),
  // 5 정산의 요구·부탁
  demand: R(5, true, '처지가 나쁜 칸의 요구. 돌아왔을 때 요구가 사라졌으면 버린다'),
  favor: R(5, true, '사적인 부탁. 미뤄도 말이 된다'),
  // 6 내정의 선택 카드
  'dom:fit': R(6, true, '"설계도가 맞았다" 제안. d.offered에 적혀 한 번뿐이라 흐지부지되면 \'나중에\'와 같다. 이미 복원 중이면 버린다'),
  'dom:pupil': R(6, true, '견습생 후보. 단추로 청한 서류(card.ask)는 미루지 않는다'),
  'dom:give': R(6, true, '온실 칸을 내줄 곳. 한 번뿐이고 \'아직 아니다\'와 같다'),
  // 6이지만 미루면 말이 안 되는 내정 카드
  'dom:manual': R(2, false, '현황판 단추로 청한 서류뿐이다. 누른 순간 뜨지 않으면 단추가 먹통이 된다', 6),
  'dom:car': R(2, false, '측선에서 지금 본 칸. 정차를 떠나면 그 칸은 없다', 6),
  // 7 이동 사건
  travel: R(7, true, '이동 사건. 문안은 일반적이라 한 구간 늦어도 말이 된다'),
  content: R(7, true, 'JSON 이동 사건. 자리표시자 사람이 없어졌으면 버린다'),
  // 등급 2: 표에 없던 종류(이 스레드가 정함). 단서가 한 번 알리는 일이거나 흐름의 한 토막이다
  info: R(2, false, '알림 한 장(식량 바닥, 긴장 경고, 기한 지남, 배급장 사임). 지금 상태를 알린다'),
  leash: R(2, false, '목줄이 끊긴 그 순간의 알림'),
  pro_promise: R(2, false, '서막 흐름(1구간 앞)'),
  pro_search: R(2, false, '서막 흐름(약속 바로 뒤)'),
  pro_deal: R(2, false, '서막 흐름(1구간 출발)'),
  hub_omen: R(2, false, '라이프치히 두 구간 전의 징후(시계)'),
  hub_split: R(2, false, '라이프치히 도착 결정'),
  hub_few: R(2, false, '라이프치히 도착 결정'),
  hub_end: R(2, false, '라이프치히 도착 끝 카드'),
  'content-deal': R(2, false, '방금 고른 JSON 사건 선택의 이어지는 제안(unshift로 맨 앞에 붙는다)'),
};

const warned = new Set<string>();
/** 모르는 kind는 등급 2로 보고 한 번 경고한다(미루지 않는다). */
export function gradeOf(kind: string): Grade {
  const r = CARD_GRADE[kind];
  if (r) return r.grade;
  if (!warned.has(kind)) {
    warned.add(kind);
    console.warn(`[budget] 등급표에 없는 카드 종류: ${kind} (등급 2로 본다, src/game/budget.ts CARD_GRADE에 넣는다)`);
  }
  return 2;
}

/** card.ask를 빼고 미룰 수 있는 카드인가 */
function deferrable(c: Card): boolean {
  return !(c.ask && BUDGET.askExempt) && gradeOf(c.kind) >= 3;
}

/** 일지에 쓸 카드 이름. cards.ts가 viewCard 제목으로 채운다(import 순환을 피한다). */
export const BUDGET_TITLE: { fn: ((g: Game, card: Card) => string) | null } = { fn: null };
function titleOf(g: Game, c: Card): string {
  try { return BUDGET_TITLE.fn?.(g, c) || c.kind; } catch { return c.kind; }
}

export function enableBudget(g: Game): void {
  g.budget = { seg: g.seg, picked: 0, stats: { deferred: {}, faded: {}, dropped: {} } };
  g.deferred = [];
}

export function budgetOn(g: Game): boolean {
  return !!g.budget;
}

function sync(g: Game): void {
  const b = g.budget!;
  if (b.seg !== g.seg) { b.seg = g.seg; b.picked = 0; }
}

const bump = (r: Record<string, number>, grade: number) => { r[grade] = (r[grade] ?? 0) + 1; };

/** 이번 구간에 카드를 하나 골랐다(chooseCard가 카드를 뺀 직후 부른다). */
export function budgetPick(g: Game): void {
  if (!g.budget) return;
  sync(g);
  g.budget.picked += 1;
}

/** 한 카드를 미룬다. 5~7등급이 두 번째 밀리면 일지 한 줄로 바꿔 없앤다. */
function retire(g: Game, card: Card): void {
  const b = g.budget!;
  const grade = gradeOf(card.kind);
  card.pushed = (card.pushed ?? 0) + 1;
  if (grade >= 5 && card.pushed >= 2) {
    bump(b.stats.faded, grade);
    journal(g, `${titleOf(g, card)} 얘기는 흐지부지됐다.`);
    return;
  }
  bump(b.stats.deferred, grade);
  (g.deferred ??= []).push(card);
}

/** 한 카드를 대기에서 뺀다. */
function push(g: Game, at: number): void {
  const [card] = g.cards.splice(at, 1);
  retire(g, card);
}

/** 이미 고른 수 + 대기 카드가 상한을 넘으면 등급 숫자가 큰 카드부터(같으면 나중에 온 카드부터) 뺀다. 미룰 수 없는 카드만 남으면 넘긴 채 둔다. */
export function budgetPass(g: Game): void {
  if (!g.budget) return;
  sync(g);
  const b = g.budget;
  while (b.picked + g.cards.length > BUDGET.perSeg) {
    let at = -1;
    let worst = 2;
    g.cards.forEach((c, i) => {
      if (!deferrable(c)) return;
      const gr = gradeOf(c.kind);
      if (gr >= worst) { worst = gr; at = i; }
    });
    if (at < 0) return;
    push(g, at);
  }
}

/** 카드가 가리키는 사람·일이 이미 없다(돌아온 카드를 조용히 버린다). */
export function gone(g: Game, c: Card): boolean {
  const comm = c.comm ?? 'tail';
  switch (c.kind) {
    case 'orphan': return (familyOf(g, c.who ?? '')?.kids.length ?? 0) === 0;
    case 'rep_sick': return !g.comms[comm].sick;
    case 'elder': return !c.who || isGone(g, c.who);
    case 'birth': return !c.who || isGone(g, c.who) || !g.born;
    case 'naming': return !c.who || isGone(g, c.who) || !!g.born?.lost;
    case 'demand': {
      // 요구가 풀렸으면(turn.ts aiLeaders의 gap과 같은 식) 말이 안 된다.
      const s = g.comms[comm];
      const [w, r, , ex] = situation(g, comm);
      return !(comm === 'engine' && ex > 50) && !((s.heat < 4 && w < 45) || (s.ration < 4 && r < 45));
    }
    case 'content': {
      const v = c.vals ?? {};
      return [v.person, v.person2, v['@aide']].some(n => !!n && isGone(g, n));
    }
    case 'dom:demand': case 'dom:officer': {
      const p = personById(g, c.who);
      return !p || !p.alive || !!p.gone;
    }
    case 'dom:fit': case 'dom:fork': return !!(g.dom?.techs as Record<string, unknown> | undefined)?.[c.text ?? ''];
    default: return false;
  }
}

/** 둘이 같은 자리(같은 종류·같은 칸·같은 사람, 일부는 같은 글)의 카드인가. 미뤄 둔 카드와 같은 자리의 새 카드는 합친다. */
const KEYED_TEXT = new Set(['travel', 'content', 'dom:fit', 'dom:fork', 'dom:pupil', 'dom:manual', 'disaster_prep']);
function slot(c: Card): string {
  const t = c.kind === 'dom:short' ? (c.text === 'break' ? `break${c.n}` : 'starved') : KEYED_TEXT.has(c.kind) ? c.text ?? '' : '';
  return `${c.kind}|${c.comm ?? ''}|${c.who ?? ''}|${t}`;
}

/** addCard가 불렀다: 방금 올린 카드가 미뤄 둔 카드와 같은 자리면 새 카드를 버리고 미룬 카드를 새 값으로 고친다. 아니면 예산을 본다. */
function onAdd(g: Game): void {
  const card = g.cards[g.cards.length - 1];
  const old = card && (g.deferred ?? []).find(d => slot(d) === slot(card));
  if (card && old) {
    g.cards.pop();
    if (card.n !== undefined) old.n = card.n;
    if (card.kind === 'dom:short' && card.text !== undefined) old.text = card.text;
    return;
  }
  budgetPass(g);
}
BUDGET_HOOK.onAdd = onAdd;

/** 구간이 바뀌었다(nextSegment가 g.seg를 올린 직후): 미뤄 둔 카드를 맨 앞으로 되돌린다. 대상이 없어진 카드는 버린다. 등급이 높은(숫자가 작은) 카드가 앞이다. */
export function budgetNextSeg(g: Game): void {
  const b = g.budget;
  if (!b) return;
  sync(g);
  const back: Card[] = [];
  for (const c of g.deferred ?? []) {
    if (gone(g, c)) { bump(b.stats.dropped, gradeOf(c.kind)); continue; }
    back.push(c);
  }
  g.deferred = [];
  // 안정 정렬: 등급이 같으면 미룬 차례대로
  back.sort((a, c) => gradeOf(a.kind) - gradeOf(c.kind));
  // 한 번에 돌아오는 건 returnMax장까지. 나머지는 한 구간 더 미룬다(밀린 횟수에 센다)
  g.cards.unshift(...back.slice(0, BUDGET.returnMax));
  for (const c of back.slice(BUDGET.returnMax)) retire(g, c);
  budgetPass(g);
}
