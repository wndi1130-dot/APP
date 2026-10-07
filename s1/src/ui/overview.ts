import { COMM_NAME, REP_ROLE, forecast, relStage, relationLine, situation } from '../game';
import type { Comm } from '../game';
import { cx, h } from './dom';
import { icon } from './icons';
import { GROUPS, fmt, signed } from './common';
import type { GroupDef, View } from './common';
import { bar, gauge, gaugeValue, lever, portrait } from './widgets';
import { nameBtn } from './names';

// 한눈에 보기: 카메라가 위로 올라간 열차. 열차는 왼쪽에 세로로 세우고 칸 종류별 색으로 구분한다.
// 같은 종류의 칸은 묶는다. 칸을 누르면 오른쪽에 수치와 정책이 펼쳐지고, 고른 칸과 창을 선으로 잇는다.
// '수치만 보기'는 칸 묶음마다 수치만 크게 보여 준다(프로스트펑크의 온기 화면처럼).

function trainColumn(view: View): HTMLElement {
  const { ui } = view;
  return h('div', { class: 'ov-train', 'data-keep-scroll': 'ov' },
    GROUPS.map(gr => h('button', {
      class: cx('ov-group', gr.comm && `c-${gr.comm}`, `ov-group--${gr.id}`, ui.overviewSel === gr.id && 'is-sel'),
      'data-action': 'ov-sel', 'data-group': gr.id, ...(ui.overviewSel === gr.id ? { 'data-link': 'from' } : {}),
    },
      gr.cars.map(id => h('i', { class: cx('ov-car', id === 'loco' && 'ov-car--loco') })),
      h('span', { class: 'ov-group__name' }, gr.name, gr.cars.length > 1 && gr.id === 'tail' ? h('small', null, ` ×${gr.cars.length}`) : null))));
}

function commPanel(view: View, c: Comm): HTMLElement {
  const { g } = view;
  const s = g.comms[c];
  const [w, r, cr, ex] = situation(g, c);
  return h('div', { class: 'ov-panel', 'data-link': 'to' },
    h('div', { class: 'ov-panel__head' },
      portrait(s.leader.name, c),
      h('div', null,
        h('b', null, COMM_NAME[c]),
        h('div', { class: 'sub' }, `${REP_ROLE[c]} `, nameBtn(s.leader.name)),
        h('div', { class: 'sub num' }, `${s.pop}명 · ${relStage(g, c)}`),
        h('div', { class: cx('sub', s.rel >= 15 && 'is-blue', s.rel <= -15 && 'is-red') }, relationLine(s.rel)))),
    h('div', { class: 'ov-panel__stats' },
      h('span', null, '온기 ', h('b', { class: 'num' }, fmt(w)), bar(w, w < 45 ? '--discontent' : '--warm')),
      h('span', null, '배급 ', h('b', { class: 'num' }, fmt(r)), bar(r, r < 45 ? '--discontent' : '--ink-3')),
      h('span', null, '과밀 ', h('b', { class: 'num' }, fmt(cr)), bar(cr, cr > 60 ? '--discontent' : '--ink-3')),
      h('span', null, '노출 ', h('b', { class: 'num' }, fmt(ex)), bar(ex, ex > 50 ? '--discontent' : '--ink-3'))),
    h('div', { class: 'ov-panel__levers' }, lever(g, c, 'heat'), lever(g, c, 'ration')));
}

function otherPanel(view: View, gr: GroupDef): HTMLElement {
  const { g } = view;
  const text = gr.id === 'dining'
    ? (g.phase === 'council' ? '회기가 열렸다.' : '회기 날 의회가 열리는 칸이다.')
    : `일지 ${g.journal.length}줄. 쥔 비밀 ${g.secrets.length}. 상징물 ${g.symbols}.`;
  return h('div', { class: 'ov-panel', 'data-link': 'to' },
    h('div', { class: 'ov-panel__head' }, h('div', null, h('b', null, gr.name), h('div', { class: 'sub' }, text))),
    gr.id === 'dining' && g.phase === 'council' ? h('button', { class: 'btn', 'data-action': 'go', 'data-screen': 'council' }, '의회로') : null,
    gr.id === 'captain' ? h('button', { class: 'btn', 'data-action': 'panel', 'data-panel': 'journal' }, '일지 펼치기') : null);
}

function numbersOnly(view: View): HTMLElement {
  const { g } = view;
  const comms = GROUPS.filter(gr => gr.comm);
  return h('div', { class: 'ov-numbers' }, comms.map(gr => {
    const c = gr.comm as Comm;
    const [w, r, cr] = situation(g, c);
    return h('button', { class: cx('ov-num', `c-${c}`), 'data-action': 'ov-sel', 'data-group': gr.id, 'data-numbers-off': '1' },
      h('b', { class: 'ov-num__name' }, gr.name),
      h('div', { class: 'ov-num__row' },
        h('span', { class: 'ov-num__cell' }, icon('heat'), h('strong', { class: cx('num', w < 45 && 'is-low') }, fmt(w)), gauge(gaugeValue(g, c, 'heat'), true)),
        h('span', { class: 'ov-num__cell' }, icon('ration'), h('strong', { class: cx('num', r < 45 && 'is-low') }, fmt(r)), gauge(gaugeValue(g, c, 'ration'), true)),
        h('span', { class: 'ov-num__cell' }, icon('people'), h('strong', { class: cx('num', cr > 60 && 'is-low') }, fmt(cr)))));
  }));
}

export function overviewScreen(view: View): HTMLElement {
  const { g, ui } = view;
  const gr = GROUPS.find(x => x.id === ui.overviewSel) ?? GROUPS[GROUPS.length - 1];
  const f = forecast(g);
  return h('section', { class: 'overview' },
    h('div', { class: 'ov-tools' },
      h('button', { class: cx('chip', ui.numbersOnly && 'is-on'), 'data-action': 'numbers' }, icon('numbers'), '수치만 보기'),
      h('button', { class: cx('chip', g.autoLevers && 'is-on'), 'data-action': 'auto-levers' }, icon('lever'), '배급장에게 맡기기'),
      h('span', { class: 'ov-forecast num' }, icon('coal'), `${signed(-f.coal)}/구간`, icon('food'), `${signed(-f.food)}/구간`)),
    ui.numbersOnly ? numbersOnly(view) : h('div', { class: 'ov-body' },
      trainColumn(view),
      gr.comm ? commPanel(view, gr.comm) : otherPanel(view, gr)));
}
