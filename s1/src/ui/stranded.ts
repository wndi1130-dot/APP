import { COMM_NAME, P, crewAllowed, forecast, predictStall, supportShare } from '../game';
import type { Game, StrandedState, TripState } from '../game';
import { cx, h } from './dom';
import { icon } from './icons';
import { fmt } from './common';
import type { View } from './common';
import { portrait } from './widgets';
import { nameBtn } from './names';
import './stranded.css';

// 멈춘 열차 화면(결정 094, 구현명세 가 5.10): 석탄 0으로 선 동안 홈 화면이 이 판으로 바뀐다.
// 위에 선 도면(떠난 역, 열차, 수동차, 다음 역), 아래에 「이번 턴에 드는 것」과 「수동차」 두 덩이.
// 규칙은 game/stranded.ts에 있고 여기는 값을 읽기만 한다. 「목재를 땐다」 덩이는 그 규칙이 온 뒤에 붙인다.

/** 화면 글의 낱말을 한 곳에 둔다. 원정 문턱은 위 띠의 「지지」(의석으로 무게 준 평균)와 다른 셈이라 낱말을 가른다. */
export const STR_WORD = {
  follow: '따르는 사람',
  crewOk: '수색대를 보낼 수 있다',
  crewNo: '절반이 안 된다. 대신 갈 사람이 없어 열차장이 직접 간다',
  from: '떠난 역',
  next: '다음 역',
  noCoalRun: '다시 달리려면 수동차가 석탄을 가져와야 한다',
} as const;

/** 이번 턴에 드는 것: 식량은 평소대로, 긴장은 선 값, 온기는 난로에 석탄 한 덩이가 있으면 안 내려간다. */
export function turnCost(g: Game): { food: number; tension: number; warm: number } {
  return { food: Math.round(forecast(g).food), tension: P.strandedTension, warm: g.coal >= 1 ? 0 : P.strandedWarmDrop };
}

/** 원정 문턱 줄: 관계 15 이상인 칸의 사람 몫과 문턱, 넘었는가. */
export function followLine(g: Game): { pct: number; line: number; ok: boolean; why: string } {
  const ok = crewAllowed(g);
  return { pct: Math.round(supportShare(g) * 100), line: Math.round(P.supportLine * 100), ok, why: ok ? STR_WORD.crewOk : STR_WORD.crewNo };
}

export type TripPhase = 'go' | 'search' | 'back' | 'late' | 'lost';
export interface TripView { phase: TripPhase; posKm: number | null; distKm: number; turn: number; total: number; left: number }

/**
 * 열차가 아는 만큼만 그린 원정. 결과를 모르는 동안(known 거짓)에는 떠날 때의 예정(plannedTurns, 처음 거리)만으로 자리를 셈한다.
 * 그래야 이어 감이나 못 돌아옴이 도면에서 먼저 새지 않는다. 예정 턴이 지나면 수동차를 그리지 않는다('late').
 */
export function tripView(st: StrandedState, trip: TripState): TripView {
  if (trip.known) {
    const total = trip.goTurns + trip.searchTurns + trip.backTurns;
    if (trip.outcome === 'lost') return { phase: 'lost', posKm: trip.posKm, distKm: trip.distKm, turn: trip.turn, total, left: 0 };
    return { phase: trip.phase, posKm: trip.posKm, distKm: trip.distKm, turn: trip.turn, total, left: Math.max(0, total - trip.turn) };
  }
  const dist = st.toNextKm;
  const go = Math.ceil(dist / P.tripGoKm);
  const search = P.tripSearchTurns;
  const total = trip.plannedTurns;
  const t = trip.turn;
  if (t > total) return { phase: 'late', posKm: null, distKm: dist, turn: t, total, left: 0 };
  const left = Math.max(0, total - t);
  if (t <= go) return { phase: 'go', posKm: Math.min(dist, t * P.tripGoKm), distKm: dist, turn: t, total, left };
  if (t <= go + search) return { phase: 'search', posKm: dist, distKm: dist, turn: t, total, left };
  return { phase: 'back', posKm: Math.max(0, dist - (t - go - search) * P.tripBackKm), distKm: dist, turn: t, total, left };
}

/** 선 도면의 자리(0~100): 열차와 수동차. 이어 간 것을 알면 선이 그만큼 길어져 열차가 왼쪽으로 밀린다. */
export function trackPos(st: StrandedState, tv: TripView | null): { train: number; cart: number | null; station: number | null } {
  const far = Math.max(st.toNextKm, tv?.distKm ?? 0);
  const total = Math.max(1, st.atKm + far);
  const at = (km: number) => Math.round((km / total) * 1000) / 10;
  return {
    train: at(st.atKm),
    cart: tv && tv.posKm !== null ? at(st.atKm + tv.posKm) : null,
    // 이어 갔으면 석탄이 없던 첫 역이 선 가운데에 남는다.
    station: far > st.toNextKm ? at(st.atKm + st.toNextKm) : null,
  };
}

const PHASE_TEXT: Record<TripPhase, string> = { go: '가는 중', search: '역을 뒤지는 중', back: '돌아오는 중', late: '돌아올 때가 지났다', lost: '돌아오지 않았다' };

function glyph(tv: TripView, captain: boolean): string {
  if (tv.phase === 'lost') return '▪';
  if (tv.phase === 'search') return '◉';
  if (tv.phase === 'back') return '◂';
  return captain ? '▶' : '▸';
}

/** 선 도면 한 줄. 열차 네모를 누르면 열차 단면으로 간다(칸의 레버는 거기 있다). */
function track(st: StrandedState, tv: TripView | null, captain: boolean, small = false): HTMLElement {
  const pos = trackPos(st, tv);
  return h('div', { class: cx('strk', small && 'strk--small') },
    h('i', { class: 'strk__done', style: `width:${pos.train}%` }),
    h('i', { class: 'strk__dot strk__dot--from' }),
    pos.station !== null ? h('i', { class: 'strk__dot strk__dot--empty', style: `left:${pos.station}%`, title: '석탄이 없던 역' }) : null,
    h('i', { class: 'strk__dot strk__dot--next' }),
    small ? h('i', { class: 'strk__train', style: `left:${pos.train}%` })
      : h('button', { class: 'strk__train', style: `left:${pos.train}%`, 'data-action': 'str-train', 'aria-label': '열차 단면 보기' }),
    h('span', { class: 'strk__km num', style: `left:${pos.train}%` }, `${fmt(st.atKm)}km`),
    pos.cart !== null && tv ? h('b', { class: cx('strk__cart', `is-${tv.phase}`), style: `left:${pos.cart}%`, 'aria-hidden': 'true' }, glyph(tv, captain)) : null,
    h('span', { class: 'strk__label strk__label--from' }, STR_WORD.from),
    h('span', { class: 'strk__label strk__label--next' }, STR_WORD.next));
}

function row(label: string, value: string, tone?: 'bad' | 'good'): HTMLElement {
  return h('div', { class: 'strb__row' }, h('span', null, label), h('b', { class: cx('num', tone && `is-${tone}`) }, value));
}

function costBlock(g: Game): HTMLElement {
  const c = turnCost(g);
  return h('div', { class: 'tblk strb' },
    h('span', { class: 'tblk__title' }, '이번 턴에 드는 것'),
    row('식량', `−${fmt(c.food)}`),
    row('긴장', `+${c.tension}`, 'bad'),
    row('모든 칸 온기', c.warm ? `−${c.warm}` : '0', c.warm ? 'bad' : 'good'),
    h('small', { class: 'sub' }, c.warm ? '난로에 석탄 한 덩이가 있으면 온기는 안 내려간다' : '난로에 석탄 한 덩이가 탄다'),
    h('small', { class: 'sub' }, STR_WORD.noCoalRun));
}

function followBar(g: Game): HTMLElement {
  const f = followLine(g);
  return h('div', { class: 'strf' },
    h('div', { class: 'strb__row' }, h('span', null, STR_WORD.follow), h('b', { class: cx('num', !f.ok && 'is-bad') }, `${f.pct}% / ${f.line}%`)),
    h('div', { class: 'strf__bar', 'aria-hidden': 'true' },
      h('i', { class: cx(f.ok && 'is-ok'), style: `width:${Math.min(100, f.pct)}%` }), h('i', { class: 'strf__line', style: `left:${f.line}%` })),
    h('small', { class: 'sub' }, f.why));
}

function cartBlock(g: Game, st: StrandedState, tv: TripView | null): HTMLElement {
  const trip = st.trip;
  if (!trip || !tv) {
    return h('div', { class: 'tblk strb' },
      h('span', { class: 'tblk__title' }, '수동차'),
      h('div', { class: 'tblk__row' }, '아직 안 보냈다', st.lostTrips ? h('small', { class: 'sub num' }, `못 돌아온 원정 ${st.lostTrips}`) : null),
      row(`${STR_WORD.next}까지`, `${fmt(st.toNextKm)}km`),
      followBar(g));
  }
  const crew = trip.leaderGoes ? `열차장과 ${trip.names.length}` : `${trip.names.length}`;
  return h('div', { class: 'tblk strb' },
    h('span', { class: 'tblk__title' }, '수동차'),
    h('div', { class: 'tblk__row' },
      h('b', null, PHASE_TEXT[tv.phase]),
      tv.phase === 'late' || tv.phase === 'lost' ? null : h('span', { class: 'num sub' }, `${tv.turn} / ${tv.total}턴 · 돌아올 때 ${tv.left}턴 뒤`)),
    h('div', { class: 'strb__crew' },
      h('span', { class: 'sub' }, `${COMM_NAME[trip.comm]}에서 ${crew}`),
      trip.names.map(n => h('span', { class: 'strb__who' }, portrait(n, trip.comm), nameBtn(n)))),
    row('가져간 식량', fmt(trip.baseFood)),
    trip.foodShort > 0 ? row('모자란 식량', fmt(trip.foodShort), 'bad') : null,
    row('돌아오면', `석탄 +${P.tripCoal}`, 'good'),
    st.captainAway ? h('small', { class: 'sub' }, `열차장이 없다. ${st.deputy ? `${COMM_NAME[st.deputy]}이 맡았다. ` : ''}회기는 돌아온 뒤에 연다`) : null);
}

/** 홈 화면 자리에 서는 멈춘 열차 판. */
/** 들어가는 연출(결정 101) 동안 평소 홈 위에 얹는 것: 하늘 자리의 선 도면과 박마다 뜨는 글. 어느 것이 보일지는 홈 뿌리의 data-beat가 가른다.
 *  글은 설 때 일지에 남는 한 줄을 세 박에 나눈 것이다. goMs는 열차 표식이 떠난 역에서 선 자리까지 가는 길이. */
export function stallScene(g: Game, goMs: number): HTMLElement | null {
  const st = g.stranded;
  if (!st) return null;
  return h('div', { class: 'stallrun', role: 'status', style: `--go:${Math.round(goMs)}ms` },
    h('div', { class: 'stallrun__track' }, track(st, null, false, true)),
    h('p', { class: 'stallcap stallcap--slow' }, '불이 꺼졌다.'),
    h('p', { class: 'stallcap stallcap--brake' }, h('b', null, '끼이이익'), h('span', { class: 'num' }, `열차가 ${fmt(st.atKm)}km 지점에서 섰다.`)),
    h('p', { class: 'stallcap stallcap--hush num' }, `${STR_WORD.next}까지 ${fmt(st.toNextKm)}km. 창마다 입김이 서린다.`));
}

export function strandedBoard(view: View): HTMLElement | null {
  const { g } = view;
  const st = g.stranded;
  if (!st) return null;
  const tv = st.trip ? tripView(st, st.trip) : null;
  const last = g.journal[g.journal.length - 1];
  return h('div', { class: 'strs' },
    h('div', { class: 'strs__top' },
      h('div', { class: 'strs__head' },
        h('b', { class: 'strs__tag num' }, `멈춤 · ${st.turns + 1}턴째`),
        h('span', { class: 'num sub' }, `${STR_WORD.next}까지 ${fmt(st.toNextKm)}km`),
        st.captainAway ? h('span', { class: 'strs__away' }, '열차장이 없다') : null,
        h('button', { class: 'chip strs__see', 'data-action': 'str-train' }, icon('people'), '열차 단면')),
      track(st, tv, !!st.trip?.leaderGoes),
      last ? h('p', { class: 'strs__log' }, last.text) : null),
    h('div', { class: 'strs__body' }, costBlock(g), cartBlock(g, st, tv)));
}

/** 열차 단면을 보는 동안 멈춘 판으로 돌아가는 단추. */
export function strandedBack(g: Game): HTMLElement | null {
  const st = g.stranded;
  return st ? h('button', { class: 'chip strs__back', 'data-action': 'str-train' }, `멈춤 · ${st.turns + 1}턴째`, h('small', null, ' 멈춘 판으로')) : null;
}

/** 떠나기 전 예고(명세 5.1): 이대로 가면 어디서 서는지와, 서면 턴마다 무엇이 드는지. 석탄이 넉넉하면 없다. */
export function stallWarn(g: Game): HTMLElement | null {
  if (g.phase !== 'prep') return null;
  const p = predictStall(g);
  if (!p) return null;
  const fake: StrandedState = { since: g.seg, turns: 0, segKm: p.segKm, atKm: p.atKm, toNextKm: p.toNextKm, seen: [], trip: null, captainAway: false, deputy: null, lostTrips: 0, snow: null, lamp: false };
  return h('div', { class: 'stall', role: 'status' },
    h('b', null, `석탄이 모자라다. 이대로 가면 ${fmt(p.atKm)}km 지점에서 멈춘다. ${STR_WORD.next}까지 ${fmt(p.toNextKm)}km.`),
    track(fake, null, false, true),
    h('small', { class: 'sub num' }, `멈추면 턴마다: 식량은 그대로 줄고 · 긴장 +${P.strandedTension} · 모든 칸 온기 −${P.strandedWarmDrop}`));
}
