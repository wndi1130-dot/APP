import { COMM_NAME, darkEnd, wallDetail, wallLine } from '../game';
import type { Game } from '../game';
import { h } from './dom';
import type { View } from './common';
import { shortText } from './names';

// S1b 어두운 길 화면(s1b_dark_path 14장). S1a 화면 파일에는 한 줄짜리 훅만 두고 S1b 화면은 여기서 그린다.
// g.dark가 없는 판에서는 모든 함수가 null을 돌려준다. 카드는 S1a 서류 화면을 그대로 쓰고(1.3), 선을 넘는 선택지의 검은 띠만 card.ts가 그린다.

/** 주소에 ?s1b=1이 있으면 어두운 길을 켠 판으로 시작한다. */
export function urlWantsS1b(): boolean {
  const v = new URLSearchParams(globalThis.location?.search ?? '').get('s1b');
  return v === '1' || v === 'on';
}

/** 메뉴의 단추: 어두운 길을 켠(끈) 새 판. 내정 켬/끔은 그대로 둔다. */
export function darkMenu(view: View): HTMLElement {
  const on = !!view.g.dark;
  return h('button', { class: 'btn btn--ghost', 'data-action': 'dark-new', 'data-on': on ? '0' : '1' }, on ? '어두운 길 끈 새 판' : '어두운 길 켠 새 판(S1b)');
}

// ---- H7: 카드를 고르기까지 걸린 시간(15.1) ----
let shown = { uid: -1, at: 0 };

/** 서류 화면이 맨 위 카드를 그릴 때 부른다. 같은 카드를 다시 그려도 처음 본 시각을 지킨다. */
export function darkCardShown(g: Game, uid: number): void {
  if (!g.dark || shown.uid === uid) return;
  shown = { uid, at: performance.now() };
}

/** 고르기 행동에 실을 ms(못 쟀으면 빈 값). */
export function darkPickMs(g: Game, uid: number): string | undefined {
  if (!g.dark || shown.uid !== uid) return undefined;
  return String(Math.round(performance.now() - shown.at));
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
      h('textarea', { readonly: true, rows: 5 }, JSON.stringify({ seed: g.seed, ...e.h7, picks: g.dark.h7 }))));
}
