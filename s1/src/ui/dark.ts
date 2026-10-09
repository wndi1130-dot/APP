import { COMM_NAME, canLift, cloneGame, darkEnd, liftMartial, stageOf, supportComm, wallDetail, wallLine } from '../game';
import type { Comm, Game } from '../game';
import { cx, h, pct, raw } from './dom';
import { icon } from './icons';
import type { View } from './common';
import { confirmed } from './notice';
import { shortText } from './names';

// S1b 어두운 길 화면(s1b_dark_path 14장). S1a 화면 파일에는 한 줄짜리 훅만 두고 S1b 화면은 여기서 그린다.
// g.dark가 없는 판에서는 모든 함수가 null을 돌려준다. 카드는 S1a 서류 화면을 그대로 쓰고(1.3), 선을 넘는 선택지의 검은 띠만 card.ts가 그린다.

/** 주소에 ?s1b=1이 있으면 어두운 길을 켠 판으로 시작한다. */
export function urlWantsS1b(): boolean {
  const v = new URLSearchParams(globalThis.location?.search ?? '').get('s1b');
  return v === '1' || v === 'on';
}

/** 주소에 ?s1b=1&scene=powers|martial이 있으면 그 시험 시작 상태(game/dark/martial.ts devScene)의 이름. 없으면 null.
 * 메뉴엔 없고 주소로만 연다. S1b가 꺼진 주소에선 쓰지 않는다. */
export function urlScene(): 'powers' | 'martial' | null {
  if (!urlWantsS1b()) return null;
  const v = new URLSearchParams(globalThis.location?.search ?? '').get('scene');
  return v === 'powers' || v === 'martial' ? v : null;
}

// 시험 시작 상태로 연 판은 새로 고침해도 이어 가게, 어느 장면의 어느 시드인지 적어 둔다(적은 것과 같으면 저장한 판을 쓴다).
const SCENE_KEY = 's1b.scene';

/** 주소의 장면으로 연 판이 이 저장 판이면 true(그러면 새로 만들지 않고 이어 간다). 장면이 없는 주소면 늘 true. */
export function sceneResumes(scene: string | null, saved: Game): boolean {
  if (!scene) return true;
  try {
    return globalThis.localStorage?.getItem(SCENE_KEY) === `${scene}:${saved.seed}`;
  } catch {
    return false;
  }
}

/** 장면으로 시작한 판임을 적어 둔다. */
export function noteScene(scene: string, g: Game): void {
  try {
    globalThis.localStorage?.setItem(SCENE_KEY, `${scene}:${g.seed}`);
  } catch {
    // 적을 자리가 없으면 새로 고칠 때 장면이 처음부터 다시 선다.
  }
}

/** 메뉴의 단추: 어두운 길을 켠(끈) 새 판. 내정 켬/끔은 그대로 둔다. */
export function darkMenu(view: View): HTMLElement {
  const on = !!view.g.dark;
  return h('button', { class: 'btn btn--ghost', 'data-action': 'dark-new', 'data-on': on ? '0' : '1' }, on ? '어두운 길 끈 새 판' : '어두운 길 켠 새 판(S1b)');
}

// ---- H7: 카드를 고르기까지 걸린 시간(15.1) ----
/** 맨 위 카드를 처음 본 시각(at)과, 그 뒤 앱이 뒤로 가 있던 시간(away). hiddenSince: 지금 뒤로 가 있으면 그 시작 시각. */
let shown = { uid: -1, at: 0, away: 0 };
let hiddenSince: number | null = null;

/** 서류 화면이 맨 위 카드를 그릴 때 부른다. 같은 카드를 다시 그려도 처음 본 시각을 지킨다. */
export function darkCardShown(g: Game, uid: number, now = performance.now()): void {
  if (!g.dark || shown.uid === uid) return;
  shown = { uid, at: now, away: 0 };
}

/** 앱이 뒤로 가거나(hidden) 돌아왔다. 뒤에 있던 시간은 망설임에서 뺀다(K02 9, h6Visibility와 같은 모양). */
export function darkVisibility(now: number, hidden: boolean): void {
  if (hidden) {
    hiddenSince ??= now;
    return;
  }
  if (hiddenSince === null) return;
  shown.away += Math.max(0, now - Math.max(hiddenSince, shown.at));
  hiddenSince = null;
}

/** 새 판이나 불러오기: 지난 판 카드의 시각이 새 판에 붙지 않게 지운다. */
export function darkPickReset(): void {
  shown = { uid: -1, at: 0, away: 0 };
  hiddenSince = null;
}

/** 고르기 행동에 실을 ms(못 쟀으면 빈 값). 뒤로 가 있던 시간은 뺀다. */
export function darkPickMs(g: Game, uid: number, now = performance.now()): string | undefined {
  if (!g.dark || shown.uid !== uid) return undefined;
  const away = shown.away + (hiddenSince === null ? 0 : Math.max(0, now - Math.max(hiddenSince, shown.at)));
  return String(Math.max(0, Math.round(now - shown.at - away)));
}

// ---- 끝 화면(10.3, 10.4) ----

/** 판 끝: 톤 한 문장, 일대기 장면, 증언, 추모의 벽. 죽은 까닭은 쓰지 않는다(10.4). */
export function darkEndSection(view: View): HTMLElement | null {
  const g = view.g;
  if (!g.dark) return null;
  const e = darkEnd(g);
  return h('div', { class: 'dark-end' },
    h('p', { class: 'dark-end__tone' }, e.toneLine),
    e.scenes.length ? h('div', null,
      h('b', { class: 'kicker' }, '일대기'),
      h('ol', { class: 'dark-end__scenes' }, e.scenes.map(sc => h('li', null, shortText(sc.text))))) : null,
    e.testimonies.length ? h('div', null,
      h('b', { class: 'kicker' }, '남은 사람들의 말'),
      h('ul', { class: 'dark-end__said' }, e.testimonies.map(t => h('li', null,
        h('q', null, t.line), h('small', null, ` ${shortText(t.name)} · ${COMM_NAME[t.comm]}`))))) : null,
    h('div', null,
      h('b', { class: 'kicker' }, '추모의 벽'),
      e.wall.length
        ? h('ul', { class: 'dark-end__wall' }, e.wall.map(w => h('li', null,
          h('details', null, h('summary', { class: 'num' }, shortText(wallLine(w))), wallDetail(w) ? h('small', null, wallDetail(w)) : null))))
        : h('p', { class: 'sub' }, '벽에 새긴 이름이 없다.')),
    h('details', { class: 'dark-end__h7' },
      h('summary', null, 'H7 기록(JSON) 펼치기'),
      h('textarea', { readonly: true, rows: 5 }, raw(JSON.stringify({ seed: g.seed, ...e.h7, picks: g.dark.h7 })))));
}

// ---- 계엄(s1b_martial_impl 3장) ----
/** 쿠데타 경고의 남은 구간(오늘 포함). 경고가 없으면 null. martialSettle이 coupWarnAt 구간의 정산에서 판을 끝낸다. */
export function coupLeft(g: Game): number | null {
  const m = g.dark?.martial;
  if (!m || m.coupWarnAt === null) return null;
  return Math.max(1, m.coupWarnAt - g.seg + 1);
}

/** 계엄 중 위 막대의 신임 자리: '경비대의 충성'. 경비대 관계(−100~100)를 0~100 칸에 옮겨 그리고, 쿠데타가 나는 문턱(회의 이하, 경비대장의 계엄이면 중립 이하)을
 * 눈금으로 보인다. 계엄 중이 아니거나 S1a 판이면 null(신임 계기가 그대로 선다). */
export function darkTrustMeter(view: View): HTMLElement | null {
  const g = view.g;
  const m = g.dark?.martial;
  if (!m) return null;
  const rel = g.comms.guard.rel;
  const stage = stageOf(rel);
  const line = m.door === 'captain' ? 0 : -1;
  const below = stage.band <= line;
  // 경고가 풀리는 선: 문이 무엇이든 호의(15) 이상으로 되돌아와야 한다(martialSettle). 문턱(경고가 서는 선)은 회의·중립으로 문마다 다르다.
  const need = 15;
  const left = coupLeft(g);
  const needName = '호의';
  const label = left !== null ? `쿠데타 ${left}구간` : '충성';
  const text = left !== null ? `경비대의 충성 ${stage.name}. 쿠데타 경고: ${left}구간 안에 ${needName} 이상으로` : `경비대의 충성 ${stage.name}`;
  return h('div', { class: cx('meter meter--loyal', below && 'is-below', left !== null && 'is-coup'), 'data-fx-cell': 'loyal', 'aria-label': text, title: text },
    icon('trust', 'meter__icon'),
    h('div', { class: 'meter__body' },
      h('div', { class: 'meter__row' }, h('b', { class: 'num' }, stage.name), h('span', { class: 'meter__label' }, label)),
      h('div', { class: 'meter__bar' },
        h('i', { style: `width:${pct((rel + 100) / 2)}` }),
        h('u', { class: 'meter__mark', style: `left:${pct((need + 100) / 2)}`, 'aria-hidden': 'true' }))));
}

/** 계엄 회기: 표결 숫자 대신 놓는 안내(의회가 닫혀 있다) */
export function darkDecreeNote(view: View): HTMLElement | null {
  const council = view.g.council;
  if (!council?.martial || council.result) return null;
  return h('div', { class: 'martial-note' },
    h('b', null, '의회가 닫혀 있다'),
    h('span', null, '표결 없이 열차장이 법 하나를 포고한다. 포고마다 경비대의 충성이 깎인다.'));
}

/** 계엄 회기: 거래 단추 자리 */
export function darkNoDeals(): HTMLElement {
  return h('p', { class: 'sub martial-nodeal' }, '계엄 중엔 거래가 없다.');
}

/** 계엄 회기: 안건이 없을 때(거둔 뒤나 법이 없을 때)의 글 */
export function darkClosedNote(g: Game): string | null {
  if (!g.council?.martial) return null;
  return g.dark?.martial ? '포고할 법이 없다. 정산으로 간다.' : '계엄을 거두었다. 의회는 다음 정기 회기부터 다시 열린다.';
}

/** 첫 탭 뒤 3초 동안 '한 번 더' 상태인가(notice.ts의 두 번 누르기와 같은 시계) */
function armed(view: View, action: string): boolean {
  return confirmed(view.ui.confirm, action, Date.now());
}

/** 거두면 신임이 얼마로 돌아오는지(판 사본에서 거둬 본다). 거둘 수 없으면 null. */
export function liftPreview(g: Game): { trust: number; decrees: number } | null {
  if (canLift(g) !== null) return null;
  const copy = cloneGame(g);
  liftMartial(copy, 'self');
  const lifted = copy.dark?.martialLifted;
  return { trust: copy.trust, decrees: (lifted?.decreed.length ?? 0) + (lifted?.repealed.length ?? 0) };
}

/** 두 번 눌러야 하는 '거둔다'를 첫 탭에 띄울 글 */
export function liftAsk(g: Game): string {
  const p = liftPreview(g);
  return p ? `한 번 더 누르면 계엄을 거둔다. 신임 ${Math.round(g.trust)} → ${Math.round(p.trust)}${p.decrees ? `. 포고 ${p.decrees}건은 다음 정기 회기에 추인 표결을 받는다` : ''}.` : '지금은 거둘 수 없다.';
}

/** 계엄 회기의 의회 화면에 선 '계엄을 거둔다' 단추. 계엄 회기가 아니면 null. */
export function darkLiftButton(view: View): HTMLElement | null {
  const g = view.g;
  if (canLift(g) !== null) return null;
  const on = armed(view, 'dark-lift');
  return h('button', { class: cx('btn btn--dark martial-lift', on && 'is-armed'), 'data-action': 'dark-lift' }, on ? '한 번 더 눌러 거둔다' : '계엄을 거둔다');
}

/** 계엄 회기 안건 창의 아래 줄: 거래 수 대신 거둔다 단추 */
export function darkBillFoot(view: View): HTMLElement | null {
  const lift = darkLiftButton(view);
  return lift ? h('div', { class: 'bill__foot martial-foot' }, lift) : null;
}

/** 계엄 회기의 아래 오른쪽 단추: 포고 없이 회기를 닫는다(표결 단추 자리). */
export function darkCloseButton(): HTMLElement {
  return h('button', { class: 'primary primary--lever', 'data-action': 'advance' }, icon('arrow'), h('span', null, '포고 없이 닫는다'));
}

// ---- 못 누르는 이유(P3): 막힌 단추의 title이 쪽지로 뜬다 ----
/** 계엄 중 경비대 '지지' 단추가 막힌 이유(게임의 거절 글을 판 사본에 해 보고 그대로 쓴다). 안 막혔으면 null. */
export function darkSupportWhy(g: Game, c: Comm): string | null {
  if (c !== 'guard' || !g.dark?.martial) return null;
  return supportComm(cloneGame(g), c);
}
