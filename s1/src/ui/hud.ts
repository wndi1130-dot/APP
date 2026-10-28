import { COMM_NAME, P, PHASES, PHASE_NAME, emergencyStatus, forecast, isSessionSeg, nextStopLine, primaryAction, standings } from '../game';
import { cx, h, pct } from './dom';
import { icon } from './icons';
import { TIP, fmt, signed } from './common';
import type { View } from './common';
import { fxText, fxTone } from './fx';
import { departLever } from './depart';
import { tip } from './widgets';
import { moodMean, scalePos } from './share';
import type { Fx, FxKey } from './fx';
import type { Comm } from '../game';
import { domesticResource } from './domestic'; // S1c 내정 훅: 자재
import { darkTrustMeter } from './dark'; // S1b 훅: 계엄 중 신임 자리의 경비대 충성

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
  // 누르면 최근에 무엇 때문에 바뀌었는지 뜬다(panels.ts meterPanel, 사용자 2026-10-11).
  return h('div', { class: cx('meter', value >= 99.5 && 'is-full', ...fxCls(fx, name)), 'data-fx-cell': name, ...(fx?.heavy === name ? { 'data-anim': `fx-${fx.id}-${name}-cross` } : {}),
    role: 'button', tabindex: 0, 'data-action': 'panel', 'data-panel': `why-${name}`, 'aria-label': `${label} ${fmt(value)}, 최근에 바뀐 까닭 보기` },
    fxBits(fx, name),
    icon(name, 'meter__icon'),
    h('div', { class: 'meter__body' },
      h('div', { class: 'meter__row' }, h('b', { class: 'num', ...rollAttr(fx, name) }, fmt(value)), h('span', { class: 'meter__label' }, label)),
      h('div', { class: 'meter__bar' }, h('i', { style: `width:${pct(value)};background:var(${tone})` }))));
}

function resource(name: 'coal' | 'food' | 'med' | 'lux', label: string, value: number, delta?: number, fx?: Fx | null, halt?: string) {
  // 누르면 어디에 얼마 드는지와 최근에 늘고 준 까닭이 뜬다(panels.ts resPanel, 사용자 2026-10-11).
  return h('div', { class: cx('res', ...fxCls(fx, name)), 'data-fx-cell': name, ...(fx?.heavy === name ? { 'data-anim': `fx-${fx.id}-${name}-cross` } : {}),
    role: 'button', tabindex: 0, 'data-action': 'panel', 'data-panel': `why-${name}`, 'aria-label': `${label} ${fmt(value)}, 드는 곳과 바뀐 까닭 보기` },
    fxBits(fx, name),
    icon(name, `res__icon res__icon--${name}`),
    h('div', { class: 'res__body' },
      h('b', { class: cx('num', value < P.crisisLine && name !== 'lux' && name !== 'med' && 'is-low'), ...rollAttr(fx, name) }, fmt(value)),
      halt ? h('span', { class: 'res__delta res__halt num' }, halt)
        : delta !== undefined ? deltaLine(value, delta) : h('span', { class: 'res__delta' }, label)));
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
  // 탭하면 쪽지로 뜬다(폰엔 title이 없다). 윗 띠 자원 칸 자체엔 data-action이 없어 다른 동작을 가리지 않는다.
  return h('button', { type: 'button', class: cx('res__delta num tip', n <= 3 && 'is-low'), 'data-action': 'tip', 'data-tip': why, 'aria-label': why },
    `${signed(delta)}·${n === 0 ? '바닥' : `${n}구간`}`);
}

/** 띠에서 칸이 불만·지지로 넘어가는 관계 선. game/turn.ts standings()와 같은 값이어야 한다(tests/ui/band.test.ts가 견준다). */
export const SIDE_LINE = 15;

/** 중립 칸의 띠 조각 안 채움: 관계가 불만 선(−15)이나 지지 선(+15)까지 얼마나 갔나(0~1). 이미 넘어간 칸은 조각 색이 말하니 채움이 없다(side 0, ratio 0).
 *  석수는 선을 넘을 때만 바뀌므로, 그 사이의 움직임은 이 채움으로 보인다(사용자 2026-10-10 '불만이 반영이 안 된다'). */
export function segFill(rel: number): { side: -1 | 0 | 1; ratio: number } {
  if (rel <= -SIDE_LINE || rel >= SIDE_LINE || Math.round(rel) === 0) return { side: 0, ratio: 0 };
  return { side: rel < 0 ? -1 : 1, ratio: Math.min(1, Math.abs(rel) / SIDE_LINE) };
}

/** 눈금 위의 집단 금 하나: 그 집단의 관계 값 자리에 선다. */
function bandTick(g: View['g'], x: { c: Comm; seats: number; side: -1 | 0 | 1 }, fx: Fx | null | undefined): HTMLElement {
  const rel = g.comms[x.c].rel;
  const moved = fx?.rel[x.c];
  return h('i', {
    class: cx('band__tick', x.side < 0 && 'is-unrest', x.side > 0 && 'is-support', !!moved && 'fx-seg'),
    style: `left:${pct(scalePos(rel))}`, title: `${COMM_NAME[x.c]} · 관계 ${fmt(rel)}`,
    ...(fx && moved ? { 'data-anim': `fx-${fx.id}-seg-${x.c}` } : {}),
  });
}

export function topBar(view: View): HTMLElement {
  const { g, ui } = view;
  const st = standings(g);
  const order = [...st.byComm].sort((a, b) => a.side - b.side || g.comms[a.c].rel - g.comms[b.c].rel);
  const f = forecast(g);
  const fx = ui.fx;
  const rels = fx ? (Object.keys(fx.rel) as Comm[]) : [];
  // 위 띠는 「정도」를 보인다(결정 058): 의석으로 무게를 준 관계 평균 하나와, 눈금 위 집단 금 다섯. 의석 판세는 집단 창과 의회에 있다.
  const mood = moodMean(st.byComm.map(x => ({ seats: x.seats, rel: g.comms[x.c].rel })));
  const lean = Math.abs(scalePos(mood) - 50);
  return h('header', { class: cx('top', fx?.band && 'fx-band'), ...(fx?.band ? { 'data-anim': `fx-${fx.id}-band` } : {}) },
    h('div', { class: 'top__meters' },
      darkTrustMeter(view) ?? meter('trust', '신임', g.trust, '--support', fx),
      meter('tension', '긴장', g.tension, '--discontent', fx)),
    h('div', { class: 'band' },
      h('button', { class: cx('band__btn band__btn--unrest', ui.panel === 'unrest' && 'is-on'), 'data-action': 'panel', 'data-panel': 'unrest', 'aria-label': '불만 쪽 집단 펼치기' }, icon('fist')),
      h('div', { class: 'band__track' },
        h('div', { class: 'band__nums' },
          h('span', { class: 'is-unrest' }, '불만'),
          h('span', { class: cx('band__mood', mood < 0 && 'is-unrest', mood > 0 && 'is-support') }, tip('여론', TIP.mood), h('b', { class: 'num' }, ` ${signed(mood)}`)),
          h('span', { class: 'is-support' }, '지지')),
        h('div', { class: 'band__scale' },
          mood !== 0 ? h('b', { class: cx('band__lean', mood < 0 ? 'is-neg' : 'is-pos'), style: `width:${pct(lean)}` }) : null,
          h('i', { class: 'band__mid' }),
          order.map(x => bandTick(g, x, fx)))),
      h('button', { class: cx('band__btn band__btn--support', ui.panel === 'support' && 'is-on'), 'data-action': 'panel', 'data-panel': 'support', 'aria-label': '지지 쪽 집단 펼치기' }, icon('hand')),
      // 관계가 바뀐 칸: 띠 밑에 칸 이름과 숫자가 떠오른다.
      rels.length && fx ? h('div', { class: 'fx fx-rels', 'data-anim': `fx-${fx.id}-rel`, 'aria-hidden': 'true' }, rels.map(c => {
        const v = fx.rel[c]!;
        return h('span', { class: cx('fx-rel num', v > 0 ? 'fx-up' : 'fx-down') }, `${COMM_NAME[c].slice(0, 2)} ${fxText(v)}`);
      })) : null),
    h('div', { class: 'top__res' },
      // 석탄 0으로 선 동안에는 「몇 구간 버틴다」 자리에 멈춘 턴을 적는다(결정 094).
      resource('coal', '석탄', g.coal, -f.coal, fx, g.stranded ? `멈춤 ${g.stranded.turns + 1}턴째` : undefined),
      resource('food', '식량', g.food, -f.food, fx),
      resource('med', '의약품', g.med, undefined, fx),
      resource('lux', '사치품', g.lux, undefined, fx),
      g.supOn ? h('div', { class: 'res', 'data-resource': 'sup', 'aria-label': `생필품 ${fmt(g.sup ?? 0)}` },
        icon('sup', 'res__icon res__icon--sup'),
        h('div', { class: 'res__body' }, h('b', { class: 'num' }, fmt(g.sup ?? 0)), h('span', { class: 'res__delta' }, '생필품'))) : null,
      domesticResource(view)));
}

/** 노선표의 다음 정차 예보(결정 471 B0·474 N2): 도착 시각과 날씨. 서기 전(운영·이동)에만 */
function nextStop(view: View): HTMLElement | null {
  const next = nextStopLine(view.g);
  if (!next) return null;
  return h('div', { class: 'next-stop', 'aria-label': `다음 정차 ${next.time} 도착, ${next.weather}` },
    h('span', null, '다음 정차'), h('b', { class: 'num' }, next.time), h('span', null, `· ${next.weather}`));
}

export function bottomBar(view: View): HTMLElement {
  const { g, ui } = view;
  const primary = primaryAction(g);
  const inCouncil = ui.screen === 'council';
  const left = inCouncil || ui.screen === 'overview' || ui.screen === 'train'
    ? [h('button', { class: 'round', 'data-action': 'go', 'data-screen': 'home', 'aria-label': '열차로' }, icon('back'))]
    : [
      h('button', { class: cx('round', ui.panel === 'menu' && 'is-on'), 'data-action': 'panel', 'data-panel': 'menu', 'aria-label': '메뉴' }, icon('menu')),
      h('button', { class: cx('round', ui.panel === 'journal' && 'is-on'), 'data-action': 'panel', 'data-panel': 'journal', 'aria-label': '일지' }, icon('book')),
    ];
  const phaseIndex = PHASES.indexOf(g.phase as typeof PHASES[number]);
  const session = isSessionSeg(g.seg);
  // 선 열차는 정차하지 않는다. 단계 줄에서 정차를 빼고 이름을 멈춘 턴의 것으로 바꾼다.
  const halted = !!g.stranded;
  const stepName = (p: typeof PHASES[number]) => (halted && p === 'prep' ? '멈춤' : halted && p === 'travel' ? '사건' : PHASE_NAME[p]);
  const steps = PHASES.map((p, i) => halted && p === 'stop' ? null : h('li', {
    class: cx('steps__item', i < phaseIndex && 'is-done', i === phaseIndex && 'is-now', p === 'council' && !session && 'is-skip'),
  }, h('i', { class: 'steps__dot' }), h('span', null, p === 'council' && !session ? `${3 - (g.seg % 3)}구간 뒤` : stepName(p))));
  const showOverview = ui.screen === 'home' || ui.screen === 'overview';
  const primaryBtn = inCouncil && g.council && !g.council.result && g.council.options.length > 0
    ? null
    : g.phase === 'prep' && primary.ok && !halted ? departLever() // 출발은 당겨 내리는 놋쇠 레버(5b.5). 선 열차는 레버 대신 「턴 넘김」
    : h('button', {
      class: cx('primary', !primary.ok && 'is-blocked'),
      'data-action': primary.ok ? 'advance' : 'open-stack',
      'aria-label': primary.why ?? primary.label,
    }, h('span', null, halted && g.phase === 'prep' && primary.ok ? '턴 넘김' : primary.label), icon(primary.ok ? 'arrow' : 'papers'));
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
      nextStop(view),
      showOverview ? h('button', {
        class: cx('round round--wide', ui.screen === 'overview' && 'is-on'), 'data-action': 'go',
        'data-screen': ui.screen === 'overview' ? 'home' : 'overview', 'aria-label': '한눈에 보기',
      }, icon('overview')) : null),
    h('div', { class: 'bottom__right' }, emergencyBtn, primaryBtn));
}
