import {
  COMMS, COMM_NAME, LAWS, P, REP_ROLE, TRAIT_NAME, agendaTitle, blocs, dealHolds, bribePrice, currentAgenda, expected, lawActive,
  openConditions, preVote, promiseWhen, relStage, relationLine, toolStatus,
  needOf, canDecree, agendaNeed, isLawAgenda, lawTechLines, MOTIONS, calmRepealLines, calmStateLine,
} from '../game';
import type { Bloc, Comm, DealTool, Game, LawId, VoteResult } from '../game';
import { cx, h, s } from './dom';
import { icon } from './icons';
import type { IconName } from './icons';
import { WEDGE_ORDER, fmt } from './common';
import type { View } from './common';
import { DEFAULT_HEMICYCLE, hemicycleBounds, layoutHemicycle, wedgeBoundaries } from './seats';
import { bar, portrait } from './widgets';
import { agendaLine, nameBtn } from './names';
import { darkBillFoot, darkClosedNote, darkCloseButton, darkDecreeNote, darkNoDeals } from './dark'; // S1b 계엄 회기 훅

/** 법 미리보기 줄 끝에 기술이 바꾼 것(7.3)을 붙인다. 다섯 줄 안에 들도록 법 줄을 줄인다(셋까지는 남긴다). */
function withTech(changes: string[], tech: string[]): string[] {
  return [...changes.slice(0, Math.max(3, 5 - tech.length)), ...tech];
}

// 의회: 식당칸 안 반원 100석을 공동체 쐐기로 나누고 쐐기 끝에 명판을 단다. 가운데 전령기 바늘과 51·67 눈금,
// '예상 찬성 / 필요' 큰 숫자. 왼쪽은 법안 창, 오른쪽은 고른 공동체의 창(지도자, 의석, 결속도, 거래 단추 다섯).
// 고른 쐐기와 창은 선으로 잇는다. 표결 단추는 레버 모양이다(decisions.md 의회 화면, image_prompts.md ② 평가).

const SEATS = layoutHemicycle(DEFAULT_HEMICYCLE);
const BOUNDS = hemicycleBounds(DEFAULT_HEMICYCLE);

type SeatState = 'yes' | 'no' | 'hard' | 'und' | 'pool' | 'absent' | 'hidden' | 'promised';

const TOOLS: { tool: DealTool; name: string; icon: IconName }[] = [
  { tool: 'open', name: '공개 협상', icon: 'open' },
  { tool: 'favor', name: '사적 부탁', icon: 'favor' },
  { tool: 'fetch', name: '현장 조달', icon: 'fetch' },
  { tool: 'bribe', name: '뇌물', icon: 'bribe' },
  { tool: 'blackmail', name: '협박', icon: 'blackmail' },
];

/** 쐐기마다 좌석 상태를 각도 순서로 늘어놓는다. 개표 중이면 미정이 하나씩 갈린다. */
export function seatStates(g: Game, map: Record<Comm, Bloc>, result: VoteResult | null, revealed: number, secret: boolean): Record<Comm, SeatState[]> {
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
      const promised = g.council?.deals.some(d => d.comm === c && dealHolds(d)) ? b.yes + b.pool : 0;
      for (let i = 0; i < promised; i += 1) list.push('promised');
      for (let i = 0; i < b.seats - b.absent - promised; i += 1) list.push('hidden');
    } else {
      for (let i = 0; i < b.yes; i += 1) list.push('yes');
      for (let i = 0; i < b.pool; i += 1) list.push('pool');
      for (let i = 0; i < b.und; i += 1) list.push('und');
      for (let i = 0; i < b.no - b.hard; i += 1) list.push('no');
      for (let i = 0; i < b.hard; i += 1) list.push('hard');
    }
    for (let i = 0; i < b.absent; i += 1) list.push('absent');
    out[c] = list;
  }
  return out;
}

/** 비밀 투표 개표(presentation_motion 5b, K01 2): 의석은 쐐기가 아니라 전체 수만 켜진다. 켜지는 자리는 회기마다 섞어
 * 어느 쐐기 자리가 찬성으로 켜졌는지가 칸의 표를 흘리지 않게 한다(난수 상태는 쓰지 않는다). 부재는 공개라 칸 자리에 남는다. */
export function secretStates(g: Game, map: Record<Comm, Bloc>, result: VoteResult, revealed: number): Record<Comm, SeatState[]> {
  const shown = result.flips.slice(0, revealed);
  const fy = shown.filter(f => f.yes).length;
  let yes = COMMS.reduce((n, c) => n + map[c].yes, 0) + fy;
  let no = COMMS.reduce((n, c) => n + map[c].no, 0) + shown.length - fy;
  const slots: [Comm, number][] = [];
  for (const c of COMMS) for (let k = 0; k < map[c].seats - map[c].absent; k += 1) slots.push([c, k]);
  let x = (g.session * 7919 + g.seg * 104729) >>> 0 || 1;
  for (let i = slots.length - 1; i > 0; i -= 1) {
    x = (Math.imul(x, 1103515245) + 12345) >>> 0;
    const j = x % (i + 1);
    [slots[i], slots[j]] = [slots[j], slots[i]];
  }
  const out = {} as Record<Comm, SeatState[]>;
  for (const c of COMMS) out[c] = [];
  for (const [c, k] of slots) {
    out[c][k] = yes > 0 ? 'yes' : no > 0 ? 'no' : 'und';
    if (yes > 0) yes -= 1; else if (no > 0) no -= 1;
  }
  for (const c of COMMS) for (let i = 0; i < map[c].absent; i += 1) out[c].push('absent');
  return out;
}

/** 이 회기 화면의 투표 방식. 표결이 끝났으면 그 표결 때 방식을 따른다(K01 2: 비밀 투표 법 자체를 표결해도 뒤집히지 않는다). */
export function ballotSecret(g: Game): boolean {
  return g.council?.result?.secret ?? lawActive(g, 'secret_ballot');
}

/** 표결이 끝났으면 쐐기를 결과에서 되살린다(K01 3): 확정표 = 칸의 결과 − 갈린 표. 표결 뒤 바뀐 관계·옮긴 표·유도 투표로
 * 다시 셈하지 않는다. 표결 전이면 지금 셈 그대로. */
export function shownBlocs(g: Game, live: Record<Comm, Bloc>): Record<Comm, Bloc> {
  const result = g.council?.result;
  if (!result) return live;
  const out = {} as Record<Comm, Bloc>;
  for (const c of COMMS) {
    const r = result.byComm[c];
    const fl = result.flips.filter(f => f.comm === c);
    const fy = fl.filter(f => f.yes).length;
    out[c] = { ...live[c], seats: r.yes + r.no + r.absent, absent: r.absent, yes: r.yes - fy, no: r.no - (fl.length - fy), und: fl.length, pool: 0 };
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
  const secret = ballotSecret(g);
  const revealed = ui.count ?? (result ? result.flips.length : 0);
  const states = secret && result ? secretStates(g, map, result, revealed) : seatStates(g, map, result, revealed, secret && !result);
  const order: Comm[] = [];
  for (const c of WEDGE_ORDER) for (let i = 0; i < map[c].seats; i += 1) order.push(c);
  const used: Record<string, number> = {};
  const pad = 30;
  const vb = `${BOUNDS.minX - pad} ${-BOUNDS.maxY - pad} ${BOUNDS.maxX - BOUNDS.minX + pad * 2} ${BOUNDS.maxY - BOUNDS.minY + pad * 1.2}`;
  const outer = DEFAULT_HEMICYCLE.outerRadius + 16;
  const plates: SVGElement[] = [];
  const arcs: SVGElement[] = [];
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
    // 쐐기 경계는 의석을 가로지르는 선 대신 바깥 테두리에 공동체 색 띠로 보인다.
    const a0 = start > 0 ? (SEATS[start - 1].angle + first.angle) / 2 : Math.PI;
    const a1 = start + n < SEATS.length ? (last.angle + SEATS[start + n].angle) / 2 : 0;
    const band = DEFAULT_HEMICYCLE.outerRadius + DEFAULT_HEMICYCLE.seatRadius + 3;
    const [bx0, by0] = polarAngle(a0 - 0.012, band);
    const [bx1, by1] = polarAngle(a1 + 0.012, band);
    arcs.push(s('path', { class: cx('wedge-band', `c-${c}`), d: `M${bx0} ${by0} A${band} ${band} 0 0 1 ${bx1} ${by1}` }));
    start += n;
  }
  // 쐐기 사이 경계: 의석 틈을 따라 굽는 선(의석 수가 바뀌면 같이 움직인다).
  const borders = wedgeBoundaries(DEFAULT_HEMICYCLE, SEATS, order).map(b => s('polyline', {
    class: 'wedge-line', points: b.points.map(([x, y]) => `${x.toFixed(1)},${(-y).toFixed(1)}`).join(' '),
  }));
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
  const martial = !!council.martial; // S1b 계엄 회기: 표결이 없어 바늘과 51·67 눈금을 그리지 않는다
  const fan = !result && !secret && !martial ? s('path', { class: 'fan', d: `M0 0 L${ax} ${ay} A${r0} ${r0} 0 0 1 ${bx} ${by} Z` }) : null;
  // 51·67 눈금은 바늘이 도는 안쪽 원에 단다.
  const tick = (v: number) => {
    const [x1, y1] = polar(v, r0 - 8);
    const [x2, y2] = polar(v, r0 + 6);
    const [tx, ty] = polar(v, r0 - 20);
    return s('g', { class: cx('tick', v !== need && 'is-dim') },
      s('line', { x1, y1, x2, y2 }), s('text', { x: tx, y: ty + 4, 'text-anchor': 'middle' }, String(v)));
  };
  return s('svg', { class: 'hemi', viewBox: vb, role: 'img', 'aria-label': '의석' },
    arcs, borders, seatEls, plates, martial ? null : tick(51), martial ? null : tick(67), fan,
    (secret || martial) && !result ? null : s('line', { class: 'needle', x1: 0, y1: 0, x2: nx, y2: ny }),
    martial && !result ? null : s('circle', { class: 'needle__hub', cx: 0, cy: 0, r: 6 }));
}

function billPanel(view: View): HTMLElement {
  const { g } = view;
  const council = g.council!;
  const agenda = currentAgenda(g);
  if (!agenda) {
    return h('div', { class: 'bill' },
      h('b', { class: 'bill__title' }, council.martial ? '계엄' : '안건 없음'),
      council.martial ? null : h('p', { class: 'sub' }, '올릴 수 있는 법이 없다.'),
      darkBillFoot(view));
  }
  // 법 안건 앞의 정기 신임 표결(S1b 5.3)은 바꿀 수도 거래할 수도 없다. 표결 뒤 주 단추가 이번 회기 안건으로 넘긴다.
  const pre = preVote(g);
  const canSwitch = !pre && !council.locked && council.deals.length === 0 && !council.result && council.options.length > 1;
  const secret = ballotSecret(g);
  if (!isLawAgenda(agenda)) {
    // 법이 아닌 안건(몫 나누기 등): 통과와 부결이 무엇을 하는지만 보인다.
    return h('div', { class: 'bill' },
      h('div', { class: 'bill__nav' },
        h('button', { class: 'nav', 'data-action': 'agenda', 'data-step': -1, disabled: !canSwitch, 'aria-label': '이전 안건' }, '‹'),
        h('b', { class: 'bill__title' }, agendaTitle(agenda)),
        h('button', { class: 'nav', 'data-action': 'agenda', 'data-step': 1, disabled: !canSwitch, 'aria-label': '다음 안건' }, '›')),
      h('div', { class: 'bill__tags' },
        h('span', { class: 'tag' }, `안건 ${agendaNeed(agenda)}`),
        h('span', { class: 'tag' }, icon(secret ? 'eyeOff' : 'eye'), secret ? '비밀' : '공개'),
        agenda.forced ? h('span', { class: 'tag tag--crisis' }, '마지막 회기') : null,
        agenda.by ? h('span', { class: 'tag' }, `${COMM_NAME[agenda.by]} 발의`) : null,
        pre ? h('span', { class: 'tag' }, '정기') : null,
        !pre && council.options.length > 1 ? h('span', { class: 'tag tag--plain num' }, `${council.idx + 1}/${council.options.length}`) : null),
      h('ul', { class: 'bill__changes' }, MOTIONS[agenda.motion].changes(g, agenda).map(x => h('li', null, x))),
      h('div', { class: 'bill__foot num' }, pre ? '거래 없음' : `거래 ${council.deals.length}/${P.maxDealsPerSession}`,
        !pre && council.locked && !council.result ? ' · 안건을 넘겼다' : ''));
  }
  const law = LAWS[agenda.law];
  const need = needOf(g, agenda.law);
  return h('div', { class: 'bill' },
    h('div', { class: 'bill__nav' },
      h('button', { class: 'nav', 'data-action': 'agenda', 'data-step': -1, disabled: !canSwitch, 'aria-label': '이전 안건' }, '‹'),
      h('b', { class: 'bill__title' }, agendaTitle(agenda)),
      h('button', { class: 'nav', 'data-action': 'agenda', 'data-step': 1, disabled: !canSwitch, 'aria-label': '다음 안건' }, '›')),
    h('div', { class: 'bill__tags' },
      council.martial ? null : h('span', { class: 'tag' }, `${law.kind === 'rule' ? '통치' : '일반'} ${agendaNeed(agenda)}`),
      h('span', { class: 'tag' }, icon(secret ? 'eyeOff' : 'eye'), secret ? '비밀' : '공개'),
      h('span', { class: cx('tag', law.tag === '가혹' && 'tag--harsh', law.tag === '이상' && 'tag--ideal') }, law.tag),
      agenda.forced ? h('span', { class: 'tag tag--crisis' }, '위기') : null,
      need && !agenda.repeal ? h('span', { class: 'tag tag--crisis' }, need.state.due > g.seg ? `요구 · ${need.state.due - g.seg}구간 남음` : '요구 · 기한 지남') : null,
      council.emergency ? h('span', { class: 'tag' }, '비상 소집') : null,
      council.martial ? h('span', { class: 'tag tag--crisis' }, '계엄') : null,
      agenda.by ? h('span', { class: 'tag' }, `${COMM_NAME[agenda.by]} 발의`) : null,
      council.options.length > 1 ? h('span', { class: 'tag tag--plain num' }, `${council.idx + 1}/${council.options.length}`) : null),
    law.why ? h('p', { class: 'bill__why' }, law.why) : null,
    law.whyNot ? h('p', { class: 'bill__why bill__why--not' }, law.whyNot) : null,
    h('ul', { class: 'bill__changes' }, (agenda.repeal ? repealLines(g, agenda.law)
      : withTech([...(agenda.amend ? [`${LAWS[agenda.amend].title} 대신 선다`] : []), ...law.changes], lawTechLines(g, agenda.law)))
      .slice(0, 5).map(x => h('li', null, x))),
    darkBillFoot(view) ?? h('div', { class: 'bill__foot num' }, `거래 ${council.deals.length}/${P.maxDealsPerSession}`,
      council.locked && !council.result ? ' · 안건을 넘겼다' : ''));
}

/** 폐지 때 실제로 일어나는 것(politics.ts repealLaw). 통과 때 한 번 받은 것과 관계 변화는 되돌리지 않는다. */
function repealLines(g: Game, law: LawId): string[] {
  const def = LAWS[law];
  const bought = g.boughtBy[law];
  return [
    Object.keys(def.mats).length ? '칸 처지에 준 변화를 되돌린다' : null,
    '통과 때 한 번 받은 것과 관계 변화는 그대로 남는다',
    `이 법을 지지하는 칸은 관계 −${P.repealRel}`,
    bought && g.session - bought.session <= 3 ? `약속으로 산 칸(${bought.comms.map(c => COMM_NAME[c]).join(', ')})이 배신으로 기억한다` : null,
    law === 'guided_voting' || law === 'emergency_powers' ? '남은 기간이 바로 끝난다' : null,
    ...calmRepealLines(law),
    calmStateLine(g, law),
  ].filter((x): x is string => !!x);
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
    const secret = ballotSecret(g);
    const result = council.result;
    const nums = (x: Comm) => {
      if (result && !result.decree && !secret) {
        return h('span', { class: 'num clist__nums' }, h('b', { class: 'is-yes' }, result.byComm[x].yes), h('span', null, '·'), h('b', { class: 'is-no' }, result.byComm[x].no));
      }
      if (secret) return h('span', { class: 'num' }, council.deals.some(d => d.comm === x && dealHolds(d)) ? '약속' : '?');
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
      nameBtn(st.leader.name, 'name--title'),
      h('div', { class: 'sub' }, st.sick ? `${REP_ROLE[c]} 대리(${st.sick.rep.name} 앓음) · ${traitText(g, c)}` : `${REP_ROLE[c]} · ${traitText(g, c)}`),
      h('div', { class: 'sub num' }, `${b.seats}석${b.absent ? ` (부재 ${b.absent})` : ''} · ${relStage(g, c)}`)),
    h('button', { class: 'x', 'data-action': 'sel-comm', 'data-comm': '', 'aria-label': '닫기' }, '×'));
  const facts = h('div', { class: 'cpanel__facts' },
    h('span', { class: st.rel >= 15 ? 'is-blue' : st.rel <= -15 ? 'is-red' : '' }, relationLine(st.rel)),
    agendaLine(g, c, 'span'),
    h('span', null, '결속도 ', bar(st.coh * 100, '--ink-2')),
    st.fervor > 0 ? h('span', { class: 'is-red' }, `열기 ${st.fervor}`) : null,
    grudge ? h('span', { class: 'is-red' }, grudge) : null,
    // 꿈쩍 않는 반대(사용자 2026-10-09): 어떤 거래로도 안 넘어온다. 비밀 투표면 칸의 표를 흘리지 않게 숨긴다.
    b.hard > 0 && !council.result && !ballotSecret(g) ? h('span', { class: 'is-red' }, `꿈쩍 않는 반대 ${b.hard}석`) : null,
    st.promise ? h('span', null, `약속: ${st.promise.label} (${promiseWhen(g, st.promise)})`) : null,
    st.debt && !st.sick ? h('span', { class: 'is-blue' }, '받을 빚 1') : null,
    st.sick ? h('span', null, '측근과는 빚도 뇌물도 안 통한다') : null,
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
    council.martial ? darkNoDeals() : h('div', { class: 'tools' }, TOOLS.map(t => {
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

/** 표결 전 셈(presentation_motion '확보·예상·필요 표', 18:19 교차 확인 반영): 같은 크기 명판 셋이 주인이고 막대는 거든다.
 * 확보 = 이미 찬성과 거래로 약속받은 표(expected의 min), 예상 = 미정이 갈릴 몫까지 넣은 기댓값, 필요 = 이번 안건 기준.
 * 막대: 확보는 꽉 찬 칸, 예상 범위(min~max)는 옅은 구간, 예상은 점, 눈금은 기준 하나. 비밀 투표면 약속만 안다. */
function tally(est: { mean: number; min: number; max: number }, need: number, secret: boolean): HTMLElement {
  const got = Math.round(est.min);
  const mean = Math.round(est.mean);
  const max = Math.round(est.max);
  const sure = got >= need;
  const plate = (label: string, v: number, cls?: string) => h('span', { class: cx('tally__plate', cls) }, h('span', null, label), ' ', h('b', { class: 'num' }, v));
  return h('div', { class: cx('tally', sure && 'is-sure'), 'aria-label': secret ? `약속 ${got}, 필요 ${need}` : `확보 ${got}, 예상 ${mean}, 필요 ${need}` },
    h('div', { class: 'tally__plates' },
      plate(secret ? '약속' : '확보', got, 'is-got'),
      secret ? null : plate('예상', mean, mean >= need ? 'is-yes' : 'is-no'),
      plate('필요', need, 'is-need'),
      sure ? h('span', { class: 'tally__sure' }, '필요 표 확보') : null),
    h('div', { class: 'tally__bar', 'aria-hidden': 'true' },
      secret ? null : h('i', { class: 'tally__range', style: `left:${got}%;width:${Math.max(0, max - got)}%` }),
      h('i', { class: 'tally__got', style: `width:${got}%` }),
      secret ? null : h('i', { class: 'tally__dot', style: `left:${mean}%` }),
      h('i', { class: 'tally__need', style: `left:${need}%` })));
}

export function councilScreen(view: View): HTMLElement {
  const { g, ui } = view;
  const council = g.council;
  const agenda = currentAgenda(g);
  if (!council) {
    return h('section', { class: 'council' }, h('p', { class: 'empty' }, '회기가 아니다.'));
  }
  if (!agenda) {
    return h('section', { class: 'council' }, billPanel(view), h('p', { class: 'empty' }, darkClosedNote(g) ?? '올릴 안건이 없다. 정산으로 간다.'));
  }
  const map = shownBlocs(g, blocs(g, agenda, council.deals));
  const need = agendaNeed(agenda);
  const est = expected(map);
  const result = council.result;
  const counting = result && ui.count !== null && ui.count < result.flips.length;
  let shownYes: number | null = null;
  if (result) {
    const k = ui.count ?? result.flips.length;
    shownYes = COMMS.reduce((sum, c) => sum + map[c].yes, 0) + result.flips.slice(0, k).filter(f => f.yes).length;
  }
  const secret = ballotSecret(g);
  const big = result
    ? h('div', { class: 'big num' }, h('b', null, fmt(shownYes ?? 0)), h('span', null, ` / ${need}`))
    : darkDecreeNote(view) ?? tally(est, need, secret);
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
        h('li', null, h('i', { class: 'seat-key seat--hard' }), '꿈쩍 않음'),
        h('li', null, h('i', { class: 'seat-key seat--pool' }), '대표 몫'),
        h('li', null, h('i', { class: 'seat-key seat--absent' }), '부재'))),
    commPanel(view, map));
}

function isDecreeable(a: ReturnType<typeof currentAgenda>): boolean {
  return !!a && isLawAgenda(a) && !a.ratify;
}

/** 아래 오른쪽의 표결 레버(회기 중, 표결 전). */
export function voteLever(view: View): HTMLElement | null {
  const { g } = view;
  const council = g.council;
  if (!council || council.result || !currentAgenda(g)) return null;
  // S1b 계엄 회기: 표결 단추 대신 포고와 '포고 없이 닫는다'
  if (council.martial) return h('div', { class: 'vote-actions' }, canDecree(g) && isDecreeable(currentAgenda(g)) ? h('button', { class: 'btn btn--dark', 'data-action': 'decree' }, '포고') : null, darkCloseButton());
  return h('div', { class: 'vote-actions' },
    canDecree(g) && isDecreeable(currentAgenda(g)) ? h('button', { class: 'btn btn--dark', 'data-action': 'decree' }, '포고') : null,
    h('button', { class: 'primary primary--lever', 'data-action': 'vote' }, icon('lever'), h('span', null, '표결')));
}

