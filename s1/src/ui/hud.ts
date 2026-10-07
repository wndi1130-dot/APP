import { COMM_NAME, P, PHASES, PHASE_NAME, forecast, isSessionSeg, primaryAction, standings } from '../game';
import { cx, h, pct } from './dom';
import { icon } from './icons';
import { fmt, signed } from './common';
import type { View } from './common';

// 위 막대: 왼쪽 신임·긴장, 가운데 불만·중립·지지 띠(양 끝 아이콘이 단추), 오른쪽 자원.
// 아래 막대: 왼쪽 메뉴와 일지, 가운데 단계 표시줄과 한눈에 보기, 오른쪽 주 단추.

function meter(name: 'trust' | 'tension', label: string, value: number, tone: string) {
  return h('div', { class: 'meter', 'aria-label': `${label} ${fmt(value)}` },
    icon(name, 'meter__icon'),
    h('div', { class: 'meter__body' },
      h('div', { class: 'meter__row' }, h('b', { class: 'num' }, fmt(value)), h('span', { class: 'meter__label' }, label)),
      h('div', { class: 'meter__bar' }, h('i', { style: `width:${pct(value)};background:var(${tone})` }))));
}

function resource(name: 'coal' | 'food' | 'med' | 'lux', label: string, value: number, delta?: number) {
  return h('div', { class: 'res', 'aria-label': `${label} ${fmt(value)}` },
    icon(name, `res__icon res__icon--${name}`),
    h('div', { class: 'res__body' },
      h('b', { class: cx('num', value < P.crisisLine && name !== 'lux' && name !== 'med' && 'is-low') }, fmt(value)),
      delta !== undefined ? h('span', { class: 'res__delta num' }, signed(delta)) : h('span', { class: 'res__delta' }, label)));
}

export function topBar(view: View): HTMLElement {
  const { g, ui } = view;
  const st = standings(g);
  const order = [...st.byComm].sort((a, b) => a.side - b.side || g.comms[a.c].rel - g.comms[b.c].rel);
  const f = forecast(g);
  return h('header', { class: 'top' },
    h('div', { class: 'top__meters' },
      meter('trust', '신임', g.trust, '--support'),
      meter('tension', '긴장', g.tension, '--discontent')),
    h('div', { class: 'band' },
      h('button', { class: cx('band__btn band__btn--unrest', ui.panel === 'unrest' && 'is-on'), 'data-action': 'panel', 'data-panel': 'unrest', 'aria-label': '불만 쪽 집단 펼치기' }, icon('fist')),
      h('div', { class: 'band__track' },
        h('div', { class: 'band__nums' },
          h('span', { class: 'is-unrest' }, `불만 ${st.unrest}`),
          h('span', null, `중립 ${st.neutral}`),
          h('span', { class: 'is-support' }, `지지 ${st.support}`)),
        h('div', { class: 'band__bar' }, order.map(x => h('i', {
          class: cx('band__seg', x.side < 0 && 'is-unrest', x.side > 0 && 'is-support'),
          style: `flex:${x.seats}`, title: `${COMM_NAME[x.c]} ${x.seats}석`,
        })))),
      h('button', { class: cx('band__btn band__btn--support', ui.panel === 'support' && 'is-on'), 'data-action': 'panel', 'data-panel': 'support', 'aria-label': '지지 쪽 집단 펼치기' }, icon('hand'))),
    h('div', { class: 'top__res' },
      resource('coal', '석탄', g.coal, -f.coal),
      resource('food', '식량', g.food, -f.food),
      resource('med', '의약품', g.med),
      resource('lux', '사치품', g.lux)));
}

export function bottomBar(view: View): HTMLElement {
  const { g, ui } = view;
  const primary = primaryAction(g);
  const inCouncil = ui.screen === 'council';
  const left = inCouncil || ui.screen === 'overview'
    ? [h('button', { class: 'round', 'data-action': 'go', 'data-screen': 'home', 'aria-label': '열차로' }, icon('back'))]
    : [
      h('button', { class: cx('round', ui.panel === 'menu' && 'is-on'), 'data-action': 'panel', 'data-panel': 'menu', 'aria-label': '메뉴' }, icon('menu')),
      h('button', { class: cx('round', ui.panel === 'journal' && 'is-on'), 'data-action': 'panel', 'data-panel': 'journal', 'aria-label': '일지' }, icon('book')),
    ];
  const phaseIndex = PHASES.indexOf(g.phase as typeof PHASES[number]);
  const session = isSessionSeg(g.seg);
  const steps = PHASES.map((p, i) => h('li', {
    class: cx('steps__item', i < phaseIndex && 'is-done', i === phaseIndex && 'is-now', p === 'council' && !session && 'is-skip'),
  }, h('i', { class: 'steps__dot' }), h('span', null, p === 'council' && !session ? `${3 - (g.seg % 3)}구간 뒤` : PHASE_NAME[p])));
  const showOverview = ui.screen === 'home' || ui.screen === 'overview';
  const primaryBtn = inCouncil && g.council && !g.council.result && g.council.options.length > 0
    ? null
    : h('button', {
      class: cx('primary', !primary.ok && 'is-blocked'),
      'data-action': primary.ok ? 'advance' : 'open-stack',
      'aria-label': primary.why ?? primary.label,
    }, h('span', null, primary.label), icon(primary.ok ? 'arrow' : 'papers'));
  return h('footer', { class: 'bottom' },
    h('div', { class: 'bottom__left' }, left),
    h('div', { class: 'bottom__mid' },
      h('div', { class: 'seg num' }, h('b', null, fmt(g.seg)), `/${P.segments}`),
      h('ol', { class: 'steps' }, steps),
      showOverview ? h('button', {
        class: cx('round round--wide', ui.screen === 'overview' && 'is-on'), 'data-action': 'go',
        'data-screen': ui.screen === 'overview' ? 'home' : 'overview', 'aria-label': '한눈에 보기',
      }, icon('overview')) : null),
    h('div', { class: 'bottom__right' }, primaryBtn));
}
