import {
  COMMS, COMM_NAME, LAWS, P, REP_ROLE, TRAIT_NAME, agendaTitle, blocs, bribePrice, currentAgenda, expected, lawActive,
  lawNeed, openConditions, relStage, toolStatus,
} from '../game';
import type { Bloc, Comm, DealTool, Game, VoteResult } from '../game';
import { cx, h, s } from './dom';
import { icon } from './icons';
import type { IconName } from './icons';
import { WEDGE_ORDER, fmt } from './common';
import type { View } from './common';
import { DEFAULT_HEMICYCLE, hemicycleBounds, layoutHemicycle } from './seats';
import { bar, portrait } from './widgets';

// 의회: 식당칸 안 반원 100석을 공동체 쐐기로 나누고 쐐기 끝에 명판을 단다. 가운데 전령기 바늘과 51·67 눈금,
// '예상 찬성 / 필요' 큰 숫자. 왼쪽은 법안 창, 오른쪽은 고른 공동체의 창(지도자, 의석, 결속도, 거래 단추 다섯).
// 고른 쐐기와 창은 선으로 잇는다. 표결 단추는 레버 모양이다(decisions.md 의회 화면, image_prompts.md ② 평가).

const SEATS = layoutHemicycle(DEFAULT_HEMICYCLE);
const BOUNDS = hemicycleBounds(DEFAULT_HEMICYCLE);

type SeatState = 'yes' | 'no' | 'und' | 'pool' | 'absent' | 'hidden' | 'promised';

const TOOLS: { tool: DealTool; name: string; icon: IconName }[] = [
  { tool: 'open', name: '공개 협상', icon: 'open' },
  { tool: 'favor', name: '사적 부탁', icon: 'favor' },
  { tool: 'fetch', name: '현장 조달', icon: 'fetch' },
  { tool: 'bribe', name: '뇌물', icon: 'bribe' },
  { tool: 'blackmail', name: '협박', icon: 'blackmail' },
];

/** 쐐기마다 좌석 상태를 각도 순서로 늘어놓는다. 개표 중이면 미정이 하나씩 갈린다. */
function seatStates(g: Game, map: Record<Comm, Bloc>, result: VoteResult | null, revealed: number, secret: boolean): Record<Comm, SeatState[]> {
  const out = {} as Record<Comm, SeatState[]>;
  const flipsByComm: Record<string, boolean[]> = {};
  if (result) {
    result.flips.slice(0, revealed).forEach(f => { (flipsByComm[f.comm] ??= []).push(f.yes); });
  }
  for (const c of COMMS) {
    const b = map[c];
    const list: SeatState[] = [];
    if (result) {
      const flips = flipsByComm[c] ?? [];
      const fy = flips.filter(Boolean).length;
      const fn = flips.length - fy;
      const pending = b.und + b.pool - flips.length;
      for (let i = 0; i < b.yes + fy; i += 1) list.push('yes');
      for (let i = 0; i < pending; i += 1) list.push('und');
      for (let i = 0; i < b.no + fn; i += 1) list.push('no');
    } else if (secret) {
      const promised = g.council?.deals.some(d => d.comm === c) ? b.yes + b.pool : 0;
      for (let i = 0; i < promised; i += 1) list.push('promised');
      for (let i = 0; i < b.seats - b.absent - promised; i += 1) list.push('hidden');
    } else {
      for (let i = 0; i < b.yes; i += 1) list.push('yes');
      for (let i = 0; i < b.pool; i += 1) list.push('pool');
      for (let i = 0; i < b.und; i += 1) list.push('und');
      for (let i = 0; i < b.no; i += 1) list.push('no');
    }
    for (let i = 0; i < b.absent; i += 1) list.push('absent');
    out[c] = list;
  }
  return out;
}

function polarAngle(a: number, r: number): [number, number] {
  return [r * Math.cos(a), -r * Math.sin(a)];
}

/** 표 수(0~100)를 반원 위 각도로: 계기 바늘과 눈금용. */
function polar(v: number, r: number): [number, number] {
  return polarAngle(Math.PI * (1 - v / 100), r);
}

function hemicycle(view: View, map: Record<Comm, Bloc>, need: number, est: { mean: number; min: number; max: number }, shownYes: number | null): SVGSVGElement {
  const { g, ui } = view;
  const council = g.council!;
  const result = council.result;
  const secret = lawActive(g, 'secret_ballot');
  const revealed = ui.count ?? (result ? result.flips.length : 0);
  const states = seatStates(g, map, result, revealed, secret && !result);
  const order: Comm[] = [];
  for (const c of WEDGE_ORDER) for (let i = 0; i < map[c].seats; i += 1) order.push(c);
  const used: Record<string, number> = {};
  const pad = 30;
  const vb = `${BOUNDS.minX - pad} ${-BOUNDS.maxY - pad} ${BOUNDS.maxX - BOUNDS.minX + pad * 2} ${BOUNDS.maxY - BOUNDS.minY + pad * 1.2}`;
  const outer = DEFAULT_HEMICYCLE.outerRadius + 16;
  const plates: SVGElement[] = [];
  // 쐐기의 경계와 명판은 실제 의석 각도에서 잡는다(줄마다 의석 수가 달라 의석 순번과 각도가 비례하지 않는다).
  let start = 0;
  for (const c of WEDGE_ORDER) {
    const n = map[c].seats;
    if (n === 0) continue;
    const first = SEATS[start];
    const last = SEATS[start + n - 1];
    const [px, py] = polarAngle((first.angle + last.angle) / 2, outer + 10);
    const sel = ui.selComm === c;
    plates.push(s('g', {
      class: cx('plate', `c-${c}`, sel && 'is-sel'), 'data-action': 'sel-comm', 'data-comm': c,
      role: 'button', tabindex: 0, 'aria-label': `${COMM_NAME[c]} ${n}석`, ...(sel ? { 'data-link': 'from' } : {}),
    },
      s('rect', { x: px - 24, y: py - 10, width: 48, height: 20, rx: 4 }),
      s('text', { x: px, y: py + 4.5, 'text-anchor': 'middle' }, `${COMM_NAME[c].slice(0, 2)} ${n}`)));
    if (start > 0) {
      const edge = (SEATS[start - 1].angle + first.angle) / 2;
      const [x1, y1] = polarAngle(edge, DEFAULT_HEMICYCLE.innerRadius - 8);
      const [x2, y2] = polarAngle(edge, DEFAULT_HEMICYCLE.outerRadius + 8);
      plates.push(s('line', { x1, y1, x2, y2, class: 'wedge-line' }));
    }
    start += n;
  }
  const seatEls = SEATS.map((seat, i) => {
    const c = order[i];
    const k = used[c] ?? 0;
    used[c] = k + 1;
    const st = states[c]?.[k] ?? 'und';
    return s('circle', {
      cx: seat.x, cy: -seat.y, r: DEFAULT_HEMICYCLE.seatRadius - 0.5,
      class: cx('seat', `seat--${st}`, ui.selComm === c && 'is-sel'), 'data-action': 'sel-comm', 'data-comm': c,
    });
  });
  // 바늘과 폭(최소~최대), 51·67 눈금
  const r0 = DEFAULT_HEMICYCLE.innerRadius - 16;
  const value = shownYes ?? est.mean;
  const [nx, ny] = polar(value, r0);
  const [ax, ay] = polar(est.min, r0);
  const [bx, by] = polar(est.max, r0);
  const fan = !result && !secret ? s('path', { class: 'fan', d: `M0 0 L${ax} ${ay} A${r0} ${r0} 0 0 1 ${bx} ${by} Z` }) : null;
  // 51·67 눈금은 바늘이 도는 안쪽 원에 단다.
  const tick = (v: number) => {
    const [x1, y1] = polar(v, r0 - 8);
    const [x2, y2] = polar(v, r0 + 6);
    const [tx, ty] = polar(v, r0 - 20);
    return s('g', { class: cx('tick', v !== need && 'is-dim') },
      s('line', { x1, y1, x2, y2 }), s('text', { x: tx, y: ty + 4, 'text-anchor': 'middle' }, String(v)));
  };
  return s('svg', { class: 'hemi', viewBox: vb, role: 'img', 'aria-label': '의석' },
    seatEls, plates, tick(51), tick(67), fan,
    secret && !result ? null : s('line', { class: 'needle', x1: 0, y1: 0, x2: nx, y2: ny }),
    s('circle', { class: 'needle__hub', cx: 0, cy: 0, r: 6 }));
}

function billPanel(view: View): HTMLElement {
  const { g } = view;
  const council = g.council!;
  const agenda = currentAgenda(g);
  if (!agenda) {
    return h('div', { class: 'bill' }, h('b', { class: 'bill__title' }, '안건 없음'), h('p', { class: 'sub' }, '올릴 수 있는 법이 없다.'));
  }
  const law = LAWS[agenda.law];
  const canSwitch = !council.locked && council.deals.length === 0 && !council.result && council.options.length > 1;
  const secret = lawActive(g, 'secret_ballot');
  return h('div', { class: 'bill' },
    h('div', { class: 'bill__nav' },
      h('button', { class: 'nav', 'data-action': 'agenda', 'data-step': -1, disabled: !canSwitch, 'aria-label': '이전 안건' }, '‹'),
      h('b', { class: 'bill__title' }, agendaTitle(agenda)),
      h('button', { class: 'nav', 'data-action': 'agenda', 'data-step': 1, disabled: !canSwitch, 'aria-label': '다음 안건' }, '›')),
    h('div', { class: 'bill__tags' },
      h('span', { class: 'tag' }, `${law.kind === 'rule' ? '통치' : '일반'} ${lawNeed(agenda.law)}`),
      h('span', { class: 'tag' }, icon(secret ? 'eyeOff' : 'eye'), secret ? '비밀' : '공개'),
      h('span', { class: cx('tag', law.tag === '가혹' && 'tag--harsh', law.tag === '이상' && 'tag--ideal') }, law.tag),
      agenda.forced ? h('span', { class: 'tag tag--crisis' }, '위기') : null,
      agenda.by ? h('span', { class: 'tag' }, `${COMM_NAME[agenda.by]} 발의`) : null,
      council.options.length > 1 ? h('span', { class: 'tag tag--plain num' }, `${council.idx + 1}/${council.options.length}`) : null),
    h('ul', { class: 'bill__changes' }, (agenda.repeal ? ['통과 때 바뀐 것을 되돌린다', ...law.changes.map(x => `되돌림: ${x}`)] : law.changes)
      .slice(0, 5).map(x => h('li', null, x))),
    h('div', { class: 'bill__foot num' }, `거래 ${council.deals.length}/${P.maxDealsPerSession}`,
      council.locked && !council.result ? ' · 안건을 넘겼다' : ''));
}

function traitText(g: Game, c: Comm): string {
  const l = g.comms[c].leader;
  if (l.traitShown === 0) return '성향 가려짐';
  if (l.traitShown === 1) return `아마 ${TRAIT_NAME[l.trait]}`;
  return TRAIT_NAME[l.trait];
}

export function grudgeText(grudge: number): string | null {
  if (grudge >= 3) return '열차장을 끌어내리려 한다';
  if (grudge >= 2) return '열차장이 무슨 안을 내든 반대한다';
  if (grudge >= 1) return '열차장 말을 반만 믿는다';
  return null;
}

function commPanel(view: View, map: Record<Comm, Bloc>): HTMLElement {
  const { g, ui } = view;
  const c = ui.selComm;
  const council = g.council!;
  if (!c) {
    const secret = lawActive(g, 'secret_ballot');
    const result = council.result;
    const nums = (x: Comm) => {
      if (result && !result.decree && !secret) {
        return h('span', { class: 'num clist__nums' }, h('b', { class: 'is-yes' }, result.byComm[x].yes), h('span', null, '·'), h('b', { class: 'is-no' }, result.byComm[x].no));
      }
      if (secret) return h('span', { class: 'num' }, council.deals.some(d => d.comm === x) ? '약속' : '?');
      return h('span', { class: 'num clist__nums' },
        h('b', { class: 'is-yes' }, map[x].yes + map[x].pool), h('span', null, map[x].und), h('b', { class: 'is-no' }, map[x].no));
    };
    return h('div', { class: 'cpanel cpanel--list' },
      h('div', { class: 'clist__head sub' },
        h('span', null, result ? '표결 결과' : '쐐기를 눌러 집단을 고른다.'),
        secret ? null : h('span', { class: 'num clist__nums' }, result ? [h('span', null, '찬'), h('span', null, ''), h('span', null, '반')] : [h('span', null, '찬'), h('span', null, '미정'), h('span', null, '반')])),
      h('ul', { class: 'clist' }, WEDGE_ORDER.map(x => h('li', null,
        h('button', { class: cx('clist__row', `c-${x}`), 'data-action': 'sel-comm', 'data-comm': x },
          h('i', { class: 'dot' }), h('span', null, COMM_NAME[x]), nums(x))))));
  }
  const st = g.comms[c];
  const b = map[c];
  const deal = council.deals.find(d => d.comm === c);
  const grudge = grudgeText(st.grudge);
  const head = h('div', { class: 'cpanel__head' },
    portrait(st.leader.name, c),
    h('div', null,
      h('b', null, st.leader.name),
      h('div', { class: 'sub' }, `${REP_ROLE[c]} · ${traitText(g, c)}`),
      h('div', { class: 'sub num' }, `${b.seats}석${b.absent ? ` (부재 ${b.absent})` : ''} · ${relStage(g, c)}`)),
    h('button', { class: 'x', 'data-action': 'sel-comm', 'data-comm': '', 'aria-label': '닫기' }, '×'));
  const facts = h('div', { class: 'cpanel__facts' },
    h('span', null, '결속도 ', bar(st.coh * 100, '--ink-2')),
    st.fervor > 0 ? h('span', { class: 'is-red' }, `열기 ${st.fervor}`) : null,
    grudge ? h('span', { class: 'is-red' }, grudge) : null,
    st.promise ? h('span', null, `약속: ${st.promise.label} (${st.promise.due}구간까지)`) : null,
    st.debt ? h('span', { class: 'is-blue' }, '받을 빚 1') : null,
    deal ? h('span', { class: 'is-blue' }, `이번 회기: ${deal.label}`) : null);
  if (ui.dealOpen === c) {
    const conds = openConditions(g, c);
    return h('div', { class: 'cpanel', 'data-link': 'to' }, head,
      h('p', { class: 'sub' }, '조건 하나를 고른다. 약속하면 미정 전부와 반대 일부가 찬성으로 돈다.'),
      h('ul', { class: 'conds' }, conds.map((cond, i) => h('li', null,
        ui.cutPick === i
          ? h('div', { class: 'cut-pick' }, h('span', { class: 'sub' }, '칼질할 칸:'),
            COMMS.filter(o => o !== c).map(o => h('button', { class: cx('chip', `c-${o}`), 'data-action': 'deal-cond', 'data-comm': c, 'data-index': i, 'data-cut': o }, COMM_NAME[o])))
          : h('button', { class: 'cond', 'data-action': 'deal-cond', 'data-comm': c, 'data-index': i },
            h('b', { class: 'num' }, i + 1), h('span', null, cond.label), h('small', null, cond.now ? '지금 치른다' : cond.kind === 'target' || cond.kind === 'skip_dispatch' ? '다음 정차' : '다음 회기까지'))))),
      h('button', { class: 'btn btn--ghost', 'data-action': 'deal-close' }, '돌아가기'));
  }
  return h('div', { class: 'cpanel', 'data-link': 'to' }, head, facts,
    h('div', { class: 'tools' }, TOOLS.map(t => {
      const status = toolStatus(g, c, t.tool);
      const cost = t.tool === 'bribe' ? `사치품 ${bribePrice(g, c)}` : status.cost ?? '';
      return h('button', { class: cx('tool', !status.ok && 'is-off'), 'data-action': 'deal', 'data-comm': c, 'data-tool': t.tool, disabled: !status.ok },
        icon(t.icon, 'tool__icon'), h('span', { class: 'tool__name' }, t.name),
        h('small', { class: 'tool__cost' }, status.ok ? cost : status.why ?? cost));
    })));
}

/** 개표가 끝나면 가운데 큰 숫자 자리에 결과를 낸다. 집단별 찬반은 오른쪽 목록이 보여 준다. */
function verdict(result: VoteResult, need: number): HTMLElement {
  return h('div', { class: cx('big verdict num', result.passed ? 'is-pass' : 'is-fail') },
    h('span', { class: 'verdict__word' }, result.decree ? '포고' : result.passed ? '가결' : '부결'),
    h('b', null, result.yes), h('span', null, ` / ${need}`),
    h('small', null, `반대 ${result.no}${result.absent ? ` · 부재 ${result.absent}` : ''}`));
}

export function councilScreen(view: View): HTMLElement {
  const { g, ui } = view;
  const council = g.council;
  const agenda = currentAgenda(g);
  if (!council) {
    return h('section', { class: 'council' }, h('p', { class: 'empty' }, '회기가 아니다.'));
  }
  if (!agenda) {
    return h('section', { class: 'council' }, billPanel(view), h('p', { class: 'empty' }, '올릴 안건이 없다. 정산으로 간다.'));
  }
  const map = blocs(g, agenda, council.deals);
  const need = lawNeed(agenda.law);
  const est = expected(map);
  const result = council.result;
  const counting = result && ui.count !== null && ui.count < result.flips.length;
  let shownYes: number | null = null;
  if (result) {
    const k = ui.count ?? result.flips.length;
    shownYes = COMMS.reduce((sum, c) => sum + map[c].yes, 0) + result.flips.slice(0, k).filter(f => f.yes).length;
  }
  const secret = lawActive(g, 'secret_ballot');
  const big = result
    ? h('div', { class: 'big num' }, h('b', null, fmt(shownYes ?? 0)), h('span', null, ` / ${need}`))
    : secret
      ? h('div', { class: 'big num' }, h('span', null, '약속 '), h('b', null, fmt(est.min)), h('span', null, ` / ${need}`))
      : h('div', { class: 'big num' }, h('span', { class: 'big__label' }, '예상 찬성'), h('b', { class: cx(est.mean >= need ? 'is-yes' : 'is-no') }, fmt(est.mean)), h('span', null, ` / ${need}`), h('small', null, `${est.min}~${est.max}`));
  return h('section', { class: 'council' },
    billPanel(view),
    h('div', { class: 'hemi-wrap' },
      hemicycle(view, map, need, est, shownYes),
      result && !counting ? verdict(result, need) : big,
      counting ? h('button', { class: 'skip', 'data-action': 'skip-count' }, '건너뛰기') : null,
      h('ul', { class: 'legend' },
        h('li', null, h('i', { class: 'seat-key seat--yes' }), '찬성'),
        h('li', null, h('i', { class: 'seat-key seat--und' }), '미정'),
        h('li', null, h('i', { class: 'seat-key seat--no' }), '반대'),
        h('li', null, h('i', { class: 'seat-key seat--pool' }), '대표 몫'),
        h('li', null, h('i', { class: 'seat-key seat--absent' }), '부재'))),
    commPanel(view, map));
}

/** 아래 오른쪽의 표결 레버(회기 중, 표결 전). */
export function voteLever(view: View): HTMLElement | null {
  const { g } = view;
  const council = g.council;
  if (!council || council.result || !currentAgenda(g)) return null;
  return h('div', { class: 'vote-actions' },
    g.decreeLeft > 0 ? h('button', { class: 'btn btn--dark', 'data-action': 'decree' }, '포고') : null,
    h('button', { class: 'primary primary--lever', 'data-action': 'vote' }, icon('lever'), h('span', null, '표결')));
}

