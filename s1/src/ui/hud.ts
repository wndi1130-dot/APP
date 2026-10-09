import { COMM_NAME, P, PHASES, PHASE_NAME, emergencyStatus, forecast, isSessionSeg, primaryAction, standings } from '../game';
import { cx, h, pct } from './dom';
import { icon } from './icons';
import { fmt, signed } from './common';
import type { View } from './common';
import { fxText, fxTone } from './fx';
import { departLever } from './depart';
import type { Fx, FxKey } from './fx';
import type { Comm } from '../game';
import { domesticResource } from './domestic'; // S1c 내정 훅: 자재

// 위 막대: 왼쪽 신임·긴장, 가운데 불만·중립·지지 띠(양 끝 아이콘이 단추), 오른쪽 자원.
// 아래 막대: 왼쪽 메뉴와 일지, 가운데 단계 표시줄과 한눈에 보기, 오른쪽 주 단추.

/** 방금 바뀐 칸(fx.ts, 5b.6): 재질 빛, 머무는 꼬리표, 선 넘음 글자. data-anim에 연출 번호를 넣어 다시 그려도 한 번만 돈다.
 *  꼬리표가 결과 줄에서 날아오는 것과 숫자 굴림은 그린 뒤에 fxplay.ts가 한다. */
function fxBits(fx: Fx | null | undefined, key: FxKey): (HTMLElement | null)[] | null {
  const cell = fx?.d[key];
  if (!fx || !cell) return null;
  const tone = fxTone(cell);
  const flies = fx.fly.includes(key);
  return [
    h('span', { class: cx('fx fx-glow', tone, cell.big && 'is-big'), 'data-anim': `fx-${fx.id}-${key}-glow`, 'aria-hidden': 'true' }),
    h('span', { class: cx('fx fx-tag num', tone, cell.big && 'is-big', flies && 'is-late'), 'data-anim': `fx-${fx.id}-${key}`, 'data-fx-key': key, 'aria-hidden': 'true' }, fxText(cell.v)),
    cell.word ? h('span', { class: cx('fx fx-word', cell.word === '위험' && 'is-danger'), 'data-anim': `fx-${fx.id}-${key}-word`, 'aria-hidden': 'true' }, cell.word) : null,
    !cell.word && cell.peel ? h('span', { class: 'fx fx-word is-peel', 'data-anim': `fx-${fx.id}-${key}-peel`, 'aria-hidden': 'true' }, cell.peel) : null,
  ];
}
function fxCls(fx: Fx | null | undefined, key: FxKey): (string | false)[] {
  const cell = fx?.d[key];
  if (!fx || !cell) return [false];
  return ['fx-hit', fxTone(cell), cell.big && 'is-big', fx.heavy === key && 'fx-cross'];
}
/** 굴릴 숫자: 그린 뒤에 옛 값에서 새 값으로 센다(fxplay.ts) */
function rollAttr(fx: Fx | null | undefined, key: FxKey): Record<string, string> {
  const cell = fx?.d[key];
  return fx && cell ? { 'data-roll': `${fx.id}:${cell.from}:${cell.to}` } : {};
}

function meter(name: 'trust' | 'tension', label: string, value: number, tone: string, fx?: Fx | null) {
  return h('div', { class: cx('meter', value >= 99.5 && 'is-full', ...fxCls(fx, name)), 'data-fx-cell': name, ...(fx?.heavy === name ? { 'data-anim': `fx-${fx.id}-${name}-cross` } : {}), 'aria-label': `${label} ${fmt(value)}` },
    fxBits(fx, name),
    icon(name, 'meter__icon'),
    h('div', { class: 'meter__body' },
      h('div', { class: 'meter__row' }, h('b', { class: 'num', ...rollAttr(fx, name) }, fmt(value)), h('span', { class: 'meter__label' }, label)),
      h('div', { class: 'meter__bar' }, h('i', { style: `width:${pct(value)};background:var(${tone})` }))));
}

function resource(name: 'coal' | 'food' | 'med' | 'lux', label: string, value: number, delta?: number, fx?: Fx | null) {
  return h('div', { class: cx('res', ...fxCls(fx, name)), 'data-fx-cell': name, ...(fx?.heavy === name ? { 'data-anim': `fx-${fx.id}-${name}-cross` } : {}), 'aria-label': `${label} ${fmt(value)}` },
    fxBits(fx, name),
    icon(name, `res__icon res__icon--${name}`),
    h('div', { class: 'res__body' },
      h('b', { class: cx('num', value < P.crisisLine && name !== 'lux' && name !== 'med' && 'is-low'), ...rollAttr(fx, name) }, fmt(value)),
      delta !== undefined ? deltaLine(value, delta) : h('span', { class: 'res__delta' }, label)));
}

/** 이번 구간 증감과, 줄어드는 중이면 정차에서 못 채울 때 몇 구간 뒤 바닥나는지(사용자 2026-10-09). */
export function runway(value: number, delta: number): number | null {
  const use = -Math.round(delta);
  if (use <= 0) return null;
  return Math.max(0, Math.floor(value / use));
}

function deltaLine(value: number, delta: number): HTMLElement {
  const n = runway(value, delta);
  if (n === null) return h('span', { class: 'res__delta num' }, signed(delta));
  const why = n === 0 ? '이번 구간에 바닥난다' : `정차에서 못 채우면 ${n}구간 뒤 바닥난다`;
  return h('span', { class: cx('res__delta num', n <= 3 && 'is-low'), title: why, 'aria-label': why },
    `${signed(delta)}·${n === 0 ? '바닥' : `${n}구간`}`);
}

/** 의석 꼬리표: 불만 의석이 늘면 빨강(이때만), 나머지는 재질대로 */
function seatTag(fx: Fx | null | undefined, which: 'unrest' | 'support'): HTMLElement | null {
  const v = fx?.seats[which];
  if (!fx || !v) return null;
  const tone = which === 'unrest' && v > 0 ? 'fx-red' : v > 0 ? 'fx-up' : 'fx-down';
  return h('span', { class: cx('fx fx-seat num', tone), 'data-anim': `fx-${fx.id}-seat-${which}`, 'aria-hidden': 'true' }, fxText(v));
}

export function topBar(view: View): HTMLElement {
  const { g, ui } = view;
  const st = standings(g);
  const order = [...st.byComm].sort((a, b) => a.side - b.side || g.comms[a.c].rel - g.comms[b.c].rel);
  const f = forecast(g);
  const fx = ui.fx;
  const rels = fx ? (Object.keys(fx.rel) as Comm[]) : [];
  return h('header', { class: cx('top', fx?.band && 'fx-band'), ...(fx?.band ? { 'data-anim': `fx-${fx.id}-band` } : {}) },
    h('div', { class: 'top__meters' },
      meter('trust', '신임', g.trust, '--support', fx),
      meter('tension', '긴장', g.tension, '--discontent', fx)),
    h('div', { class: 'band' },
      h('button', { class: cx('band__btn band__btn--unrest', ui.panel === 'unrest' && 'is-on'), 'data-action': 'panel', 'data-panel': 'unrest', 'aria-label': '불만 쪽 집단 펼치기' }, icon('fist')),
      h('div', { class: 'band__track' },
        h('div', { class: 'band__nums' },
          h('span', { class: 'is-unrest' }, `불만 ${st.unrest}`, seatTag(fx, 'unrest')),
          h('span', null, `중립 ${st.neutral}`),
          h('span', { class: 'is-support' }, `지지 ${st.support}`, seatTag(fx, 'support'))),
        h('div', { class: 'band__bar' }, order.map(x => h('i', {
          class: cx('band__seg', x.side < 0 && 'is-unrest', x.side > 0 && 'is-support'),
          style: `flex:${x.seats}`, title: `${COMM_NAME[x.c]} ${x.seats}석`,
        })))),
      h('button', { class: cx('band__btn band__btn--support', ui.panel === 'support' && 'is-on'), 'data-action': 'panel', 'data-panel': 'support', 'aria-label': '지지 쪽 집단 펼치기' }, icon('hand')),
      // 관계가 바뀐 칸: 띠 밑에 칸 이름과 숫자가 떠오른다.
      rels.length && fx ? h('div', { class: 'fx fx-rels', 'data-anim': `fx-${fx.id}-rel`, 'aria-hidden': 'true' }, rels.map(c => {
        const v = fx.rel[c]!;
        return h('span', { class: cx('fx-rel num', v > 0 ? 'fx-up' : 'fx-down') }, `${COMM_NAME[c].slice(0, 2)} ${fxText(v)}`);
      })) : null),
    h('div', { class: 'top__res' },
      resource('coal', '석탄', g.coal, -f.coal, fx),
      resource('food', '식량', g.food, -f.food, fx),
      resource('med', '의약품', g.med, undefined, fx),
      resource('lux', '사치품', g.lux, undefined, fx),
      domesticResource(view)));
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
    : g.phase === 'prep' && primary.ok ? departLever() // 출발은 당겨 내리는 놋쇠 레버(5b.5)
    : h('button', {
      class: cx('primary', !primary.ok && 'is-blocked'),
      'data-action': primary.ok ? 'advance' : 'open-stack',
      'aria-label': primary.why ?? primary.label,
    }, h('span', null, primary.label), icon(primary.ok ? 'arrow' : 'papers'));
  // 비상 소집: 회기가 아닌 구간에 정차를 마치면 신임을 써서 의회를 부를 수 있다.
  const em = emergencyStatus(g);
  const emergencyBtn = em.show && ui.screen === 'home' ? h('button', {
    class: cx('secondary', !em.ok && 'is-off'), 'data-action': 'emergency', disabled: !em.ok,
    'aria-label': em.why ? `비상 소집: ${em.why}` : `비상 소집, 신임 −${em.cost}`,
  }, h('span', null, '비상 소집'), h('small', { class: 'num' }, em.why ?? `신임 −${em.cost}`)) : null;
  return h('footer', { class: 'bottom' },
    h('div', { class: 'bottom__left' }, left),
    h('div', { class: 'bottom__mid' },
      h('div', { class: 'seg num' }, h('b', null, fmt(g.seg)), `/${P.segments}`),
      h('ol', { class: 'steps' }, steps),
      showOverview ? h('button', {
        class: cx('round round--wide', ui.screen === 'overview' && 'is-on'), 'data-action': 'go',
        'data-screen': ui.screen === 'overview' ? 'home' : 'overview', 'aria-label': '한눈에 보기',
      }, icon('overview')) : null),
    h('div', { class: 'bottom__right' }, emergencyBtn, primaryBtn));
}
