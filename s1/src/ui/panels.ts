import {
  COMMS, COMM_NAME, P, PROTEST, REP_ROLE, TRAIT_NAME, UNIQUE_ACTION, forecast, promiseWhen, relStage, relationLine, seats, situation,
} from '../game';
import type { Comm, Game } from '../game';
import { cx, h, raw } from './dom';
import { icon } from './icons';
import { TIP, fmt, signed } from './common';
import { bar, tip } from './widgets';
import { sharePcts } from './share';
import { runway } from './hud';
import type { View } from './common';
import { grudgeText } from './council';
import { nameBtn, shortText } from './names';
import { domesticEnd, domesticMenu, domesticPanel, eventsMenu, prologueDone } from './domestic'; // S1c 내정 훅
import { darkEndSection, darkMenu, darkSupportWhy } from './dark'; // S1b 어두운 길 훅
import { reproError, reproText } from './repro';
import { vibrateOn } from './fx';
import { departTapOn } from './depart';

// 겹쳐 뜨는 창: 불만·지지 집단 창, 일지, 메뉴, 정산 요약, 디버그, 끝.

function factionRow(g: Game, c: Comm): HTMLElement {
  const s = g.comms[c];
  const map = seats(g);
  const seatN = map[c];
  const total = COMMS.reduce((sum, x) => sum + map[x], 0);
  const share = sharePcts(COMMS.map(x => map[x]))[COMMS.indexOf(c)];
  const acted = g.actedSeg === g.seg;
  const grudge = grudgeText(s.grudge);
  const supportWhy = darkSupportWhy(g, c); // S1b 계엄 중 경비대 지지
  return h('li', { class: cx('frow', `c-${c}`) },
    h('div', { class: 'frow__head' },
      h('i', { class: 'dot' }), h('b', null, COMM_NAME[c]),
      // 의석은 비율로, 막대와 함께. 석수는 누르면 뜬다(사용자 2026-10-11).
      h('span', { class: 'frow__share' }, bar(share, '--ink-3'), tip(`${share}%`, `${COMM_NAME[c]}: 의회 ${seatN}석(전체 ${total}석).`)),
      h('span', { class: cx('stage', `stage--${s.rel >= 15 ? 'up' : s.rel <= -15 ? 'down' : 'mid'}`) }, relStage(g, c))),
    h('div', { class: 'frow__facts' },
      h('span', null, `${REP_ROLE[c]} `, nameBtn(s.leader.name)),
      h('span', { class: s.rel >= 15 ? 'is-blue' : s.rel <= -15 ? 'is-red' : '' }, relationLine(s.rel)),
      s.fervor > 0 ? h('span', { class: 'is-red' }, `열기 ${s.fervor}${s.rel <= -40 || c === 'engine' ? ` · ${PROTEST[c]}` : ''}`) : null,
      grudge ? h('span', { class: 'is-red' }, grudge) : null,
      s.promise ? h('span', null, `약속: ${s.promise.label} (${promiseWhen(g, s.promise)})`) : null),
    h('div', { class: 'frow__actions' },
      h('button', { class: 'chip', 'data-action': 'comm-act', 'data-act': 'support', 'data-comm': c, disabled: acted || g.lux < 2 || !!supportWhy, title: supportWhy }, '지지', h('small', null, ' 사치품 −2')),
      h('button', { class: 'chip', 'data-action': 'comm-act', 'data-act': 'cut', 'data-comm': c, disabled: acted }, '칼질', h('small', null, ' 식량 +4')),
      s.rel >= 15 ? h('button', { class: 'chip', 'data-action': 'comm-act', 'data-act': 'unique', 'data-comm': c, disabled: acted }, UNIQUE_ACTION[c]) : null));
}

function factionPanel(view: View): HTMLElement {
  const { g, ui } = view;
  const side = ui.panel === 'unrest' ? -1 : 1;
  const list = [...COMMS]
    .filter(c => (side < 0 ? g.comms[c].rel < 15 : g.comms[c].rel > -15))
    .sort((a, b) => (side < 0 ? g.comms[a].rel - g.comms[b].rel : g.comms[b].rel - g.comms[a].rel));
  return h('div', { class: cx('drop', side < 0 ? 'drop--unrest' : 'drop--support'), role: 'dialog' },
    h('div', { class: 'drop__head' },
      icon(side < 0 ? 'fist' : 'hand'), h('b', null, side < 0 ? '불만 쪽' : '지지 쪽'),
      h('span', { class: 'sub' }, g.actedSeg === g.seg ? '이번 구간 행동을 했다' : '구간마다 행동 하나'),
      h('button', { class: 'x', 'data-action': 'panel', 'data-panel': '', 'aria-label': '닫기' }, '×')),
    list.length ? h('ul', { class: 'frows' }, list.map(c => factionRow(g, c))) : h('p', { class: 'sub' }, '이쪽엔 아무도 없다.'));
}

function journalPanel(view: View): HTMLElement {
  const { g } = view;
  const entries = [...g.journal].reverse().slice(0, 80);
  return h('div', { class: 'side', role: 'dialog' },
    h('div', { class: 'drop__head' }, icon('book'), h('b', null, '일지'),
      h('button', { class: 'x', 'data-action': 'panel', 'data-panel': '', 'aria-label': '닫기' }, '×')),
    entries.length === 0 ? h('p', { class: 'empty' }, '아직 적힌 일이 없다.')
      : h('ol', { class: 'log' }, entries.map(e => h('li', { class: cx('log__item', e.tone && `is-${e.tone}`) },
        h('span', { class: 'log__seg num' }, `${e.seg}`), h('span', null, shortText(e.text))))));
}

function menuPanel(view: View): HTMLElement {
  const { g, ui } = view;
  return h('div', { class: 'side side--menu', role: 'dialog' },
    h('div', { class: 'drop__head' }, icon('menu'), h('b', null, '메뉴'),
      h('button', { class: 'x', 'data-action': 'panel', 'data-panel': '', 'aria-label': '닫기' }, '×')),
    h('p', { class: 'sub' }, `시드 ${g.seed} · 저장은 자동(한 칸)`),
    h('div', { class: 'menu' },
      h('button', { class: 'btn', 'data-action': 'fullscreen' }, document.fullscreenElement ? '전체 화면 끄기' : '전체 화면'),
      h('button', { class: 'btn btn--ghost', 'data-action': 'restart' }, '같은 시드로 처음부터'),
      h('button', { class: 'btn btn--ghost', 'data-action': 'new-seed' }, '새 판(새 시드)'),
      // 서막을 한 번 끝낸 브라우저에만 보인다(first_leg_story 5장 '서막 건너뛰기', 제안).
      prologueDone() ? h('button', { class: 'btn btn--ghost', 'data-action': 'new-skip' }, '차고 장면 건너뛰기') : null,
      domesticMenu(view),
      eventsMenu(view),
      // 진동(5b.6): 나쁜 쪽 선 넘음과 죽음에만 40ms. 동작 감소 설정과 따로 끈다. 아이폰 브라우저는 원래 안 떤다.
      h('button', { class: cx('btn btn--ghost', vibrateOn() && 'is-on'), 'data-action': 'toggle-vibrate', 'aria-pressed': vibrateOn() ? 'true' : 'false' }, vibrateOn() ? '진동 켬' : '진동 끔'),
      // 출발 레버(5b.5)를 끌기 어려우면 두 번 눌러 출발한다.
      h('button', { class: cx('btn btn--ghost', departTapOn() && 'is-on'), 'data-action': 'toggle-depart-tap', 'aria-pressed': departTapOn() ? 'true' : 'false' }, departTapOn() ? '출발: 두 번 눌러' : '출발: 레버 당겨'),
      darkMenu(view),
      h('button', { class: cx('btn btn--ghost', ui.debug && 'is-on'), 'data-action': 'toggle-debug' }, ui.debug ? '숨은 수치 끄기' : '숨은 수치 보기(테스트용)'),
      h('button', { class: 'btn btn--ghost', 'data-action': 'repro-copy' }, '오류 재현 묶음 복사')),
    reproSection());
}

/** 오류 재현 묶음(repro.ts): 복사 단추 아래 안내와, 복사가 막힌 창을 위한 펼치는 칸. */
function reproSection(): HTMLElement {
  const err = reproError();
  return h('div', { class: 'repro' },
    h('p', { class: 'sub' }, err ? `마지막 오류: ${shortText(err.msg)}` : '이상한 일이 생기면 위 묶음을 복사해 보내 줘. 시드, 최근 행동, 직전 저장이 들어 있다.'),
    h('details', { class: 'dom-export' },
      h('summary', null, '복사가 안 되면 펼쳐서 길게 눌러 복사'),
      h('textarea', { class: 'dom-export__text', readonly: true, rows: 5 }, raw(reproText()))));
}

function settlePanel(view: View): HTMLElement | null {
  const { g } = view;
  const s = g.lastSettle;
  if (!s) return null;
  const rel = COMMS.filter(c => Math.round(s.rel[c]) !== 0);
  return h('div', { class: 'settle', role: 'dialog' },
    h('div', { class: 'drop__head' }, h('b', null, `${g.seg}구간 정산`),
      h('button', { class: 'x', 'data-action': 'panel', 'data-panel': '', 'aria-label': '닫기' }, '×')),
    h('div', { class: 'settle__res num' },
      h('span', null, icon('coal'), signed(s.coal)), h('span', null, icon('food'), signed(s.food)), h('span', null, icon('med'), signed(s.med)),
      h('span', null, icon('trust'), `신임 ${signed(s.trust)}`), h('span', null, icon('tension'), `긴장 ${signed(s.tension)}`)),
    rel.length ? h('ul', { class: 'settle__rel' }, rel.map(c => h('li', { class: s.rel[c] > 0 ? 'is-blue' : 'is-red' },
      `${COMM_NAME[c]} ${s.rel[c] > 0 ? '지지' : '불만'} ${'↑'} (${signed(s.rel[c])})`))) : null,
    s.notes.length ? h('ul', { class: 'settle__notes' }, s.notes.map(n => h('li', null, shortText(n)))) : null,
    g.cards.length ? h('p', { class: 'sub' }, `새 서류 ${g.cards.length}장이 쌓였다.`) : null);
}

function debugPanel(view: View): HTMLElement {
  const { g } = view;
  return h('div', { class: 'side side--debug', role: 'dialog' },
    h('div', { class: 'drop__head' }, h('b', null, '숨은 수치'),
      h('button', { class: 'x', 'data-action': 'toggle-debug', 'aria-label': '닫기' }, '×')),
    h('p', { class: 'sub num' }, `공포 ${fmt(g.fear)} · 부상자 ${g.injured} · 비밀 ${g.secrets.length} · 목줄 ${g.leashes.length} · 협박 ${g.blackmails} · 던진 시신 ${g.thrown} · 냉동칸 ${g.stored} · 파업 ${g.strikes}`),
    h('table', { class: 'dbg num' },
      h('tr', null, ['', '관계', '결속', '열기', '적의', '온기', '배급', '과밀', '노출', '성향'].map(x => h('th', null, x === '노출' ? tip(x, TIP.exposure) : x))),
      COMMS.map(c => {
        const s = g.comms[c];
        const [w, r, cr, ex] = situation(g, c);
        return h('tr', null, [COMM_NAME[c], fmt(s.rel), s.coh.toFixed(2), s.fervor, s.grudge, fmt(w), fmt(r), fmt(cr), fmt(ex), TRAIT_NAME[s.leader.trait]].map(x => h('td', null, x)));
      })),
    h('ul', { class: 'log' }, g.secrets.map(x => h('li', null, `${COMM_NAME[x.about]} 대표: ${shortText(x.text)} (무게 ${x.weight}${x.proof ? `, ${x.proof === 2 ? '증거' : '소문'}` : ''})`))));
}

/** 까닭 목록에 보일 줄 수 */
export const METER_ROWS = 6;

/** 신임(또는 긴장)이 최근에 바뀐 까닭: 그 수치가 움직인 줄만, 최근 것부터 METER_ROWS줄. */
export function meterRows(g: Game, which: 'trust' | 'tension'): { seg: number; label: string; v: number }[] {
  return (g.meterLog ?? []).filter(r => r[which] !== 0).map(r => ({ seg: r.seg, label: r.label, v: r[which] })).reverse().slice(0, METER_ROWS);
}

function meterPanel(view: View, which: 'trust' | 'tension'): HTMLElement {
  const { g } = view;
  const rows = meterRows(g, which);
  const name = which === 'trust' ? '신임' : '긴장';
  // 신임은 내리면 나쁘고 긴장은 오르면 나쁘다. 나쁜 쪽만 붉게 한다.
  const bad = (v: number) => (which === 'trust' ? v < 0 : v > 0);
  return h('div', { class: 'drop drop--why', role: 'dialog', 'aria-label': `${name}이 바뀐 까닭` },
    h('div', { class: 'drop__head' },
      icon(which), h('b', null, `${name} ${fmt(g[which])}`), h('span', { class: 'sub' }, '최근에 바뀐 까닭'),
      h('button', { class: 'x', 'data-action': 'panel', 'data-panel': '', 'aria-label': '닫기' }, '×')),
    rows.length
      ? h('ol', { class: 'why' }, rows.map(r => h('li', { class: 'why__row' },
        h('span', { class: 'why__seg num' }, `${r.seg}구간`),
        h('span', { class: 'why__label' }, r.label),
        h('b', { class: cx('num', bad(r.v) && 'is-red') }, signed(r.v)))))
      : h('p', { class: 'sub' }, `아직 ${name}이 바뀐 일이 없다.`));
}

export type ResKey = 'coal' | 'food' | 'med' | 'lux';
const RES_NAME: Record<ResKey, string> = { coal: '석탄', food: '식량', med: '의약품', lux: '사치품' };
/** 자원 까닭 창의 묶음마다 보일 줄 수 */
export const RES_ROWS = 4;

/** 이번 구간에 그 자원이 어디에 얼마 드나(정차 제외). 칸마다의 난방·배급과 운행은 판에서 바로 읽고,
 *  법·기술·재난·내정이 더하고 빼는 몫은 예고 합계와의 차이로 '그 밖'에 모은다. 큰 것부터. */
export function resUse(g: Game, key: 'coal' | 'food'): { total: number; rows: { label: string; v: number }[] } {
  const total = forecast(g)[key];
  const rows = COMMS.map(c => ({
    label: `${COMM_NAME[c]} ${key === 'coal' ? '난방' : '배급'}`,
    v: key === 'coal' ? ((g.comms[c].heat * g.comms[c].pop) / 40) * P.coalHeatPerLever : g.comms[c].pop * g.comms[c].ration * P.foodPerPersonLever,
  }));
  if (key === 'coal') rows.push({ label: g.inStrike ? '서 있는 기관' : '기관 운행', v: g.inStrike ? P.coalStrike : P.coalRun });
  const rest = total - rows.reduce((sum, r) => sum + r.v, 0);
  const shown = rows.filter(r => Math.round(r.v * 10) !== 0).sort((a, b) => b.v - a.v);
  if (Math.round(rest * 10) !== 0) shown.push({ label: '그 밖(법, 기술, 재난, 내정)', v: rest });
  return { total, rows: shown };
}

/** 그 자원이 최근에 준 일과 는 일: 최근 것부터 RES_ROWS줄씩. */
export function resRows(g: Game, key: ResKey): { out: { seg: number; label: string; v: number }[]; into: { seg: number; label: string; v: number }[] } {
  const all = (g.resLog ?? []).filter(r => r[key] !== 0).map(r => ({ seg: r.seg, label: r.label, v: r[key] })).reverse();
  return { out: all.filter(r => r.v < 0).slice(0, RES_ROWS), into: all.filter(r => r.v > 0).slice(0, RES_ROWS) };
}

/** 자원 까닭 창: 합계 → 어디에 얼마(이번 구간) → 최근에 준 일(붉게) → 최근에 는 일. */
function resPanel(view: View, key: ResKey): HTMLElement {
  const { g } = view;
  const name = RES_NAME[key];
  const use = key === 'coal' || key === 'food' ? resUse(g, key) : null;
  const left = use ? runway(g[key], -use.total) : null;
  const { out, into } = resRows(g, key);
  const one = (n: number) => (Math.round(n * 10) / 10).toString().replace('-', '−');
  const list = (title: string, rows: { seg: number; label: string; v: number }[], red: boolean) => (rows.length ? [
    h('p', { class: 'why__title sub' }, title),
    h('ol', { class: 'why' }, rows.map(r => h('li', { class: 'why__row' },
      h('span', { class: 'why__seg num' }, `${r.seg}구간`), h('span', { class: 'why__label' }, r.label),
      h('b', { class: cx('num', red && 'is-red') }, signed(r.v))))),
  ] : []);
  return h('div', { class: 'drop drop--why', role: 'dialog', 'aria-label': `${name}이 드는 곳과 바뀐 까닭` },
    h('div', { class: 'drop__head' },
      icon(key), h('b', null, `${name} ${fmt(g[key])}`),
      use ? h('span', { class: 'sub num' }, `이번 구간 −${one(use.total)}${left === null ? '' : left === 0 ? ' · 이번 구간에 바닥' : ` · ${left}구간 뒤 바닥`}`) : null,
      h('button', { class: 'x', 'data-action': 'panel', 'data-panel': '', 'aria-label': '닫기' }, '×')),
    use ? h('p', { class: 'why__title sub' }, '이번 구간에 드는 곳') : null,
    use ? h('ol', { class: 'why why--use' }, use.rows.map(r => h('li', { class: 'why__row' },
      h('span', { class: 'why__label' }, r.label), bar(Math.max(0, (r.v / Math.max(1, use.total)) * 100), '--ink-3'),
      h('b', { class: 'num' }, r.v < 0 ? `+${one(-r.v)}` : `−${one(r.v)}`)))) : null,
    list('최근에 준 일', out, true),
    list('최근에 는 일', into, false),
    !use && out.length + into.length === 0 ? h('p', { class: 'sub' }, `아직 ${name}이 바뀐 일이 없다.`) : null);
}

export function overlay(view: View): HTMLElement | null {
  const { ui } = view;
  if (ui.panel === 'why-trust' || ui.panel === 'why-tension') return meterPanel(view, ui.panel === 'why-trust' ? 'trust' : 'tension');
  if (ui.panel === 'why-coal' || ui.panel === 'why-food' || ui.panel === 'why-med' || ui.panel === 'why-lux') return resPanel(view, ui.panel.slice(4) as ResKey);
  if (ui.panel === 'unrest' || ui.panel === 'support') return factionPanel(view);
  if (ui.panel === 'journal') return journalPanel(view);
  if (ui.panel === 'menu') return menuPanel(view);
  if (ui.panel === 'settle') return settlePanel(view);
  if (ui.panel === 'dom') return domesticPanel(view);
  return null;
}

export function debugOverlay(view: View): HTMLElement | null {
  return view.ui.debug ? debugPanel(view) : null;
}

const END_TITLE: Record<string, string> = {
  complete: '라이프치히 중앙역', stranded: '좌초', ousted: '축출', revolt: '반란', coup: '쿠데타',
};

export function endScreen(view: View): HTMLElement {
  const { g } = view;
  const st = g.stats;
  const highlights = g.journal.filter(e => e.tone === 'deal' || e.tone === 'dark' || e.tone === 'bad').slice(-10);
  return h('section', { class: 'end' },
    h('div', { class: 'end__head' },
      h('span', { class: 'kicker' }, `${g.seg}구간`),
      h('b', { class: 'end__title' }, END_TITLE[g.end ?? 'complete']),
      h('p', { class: 'sub num' }, `거래 ${st.dealsMade} · 약속 지킴 ${st.promisesKept} · 어김 ${st.promisesBroken} · 가결 ${st.lawsPassed} · 부결 ${st.lawsFailed} · 폐지 ${st.repeals} · 뇌물 ${st.bribes} · 협박 ${st.blackmails} · 죽음 ${g.deaths.length}`)),
    // S1b 판이면 오른쪽 칸 위에 일대기·증언·추모의 벽을 두고, 일지 하이라이트는 그 밑에 둔다.
    h('div', { class: 'end__right' },
      darkEndSection(view),
      highlights.length === 0 ? h('p', { class: 'empty' }, '남길 만한 일이 없었다.')
        : h('ol', { class: 'log' }, highlights.map(e => h('li', { class: cx('log__item', e.tone && `is-${e.tone}`) }, h('span', { class: 'log__seg num' }, `${e.seg}`), h('span', null, shortText(e.text)))))),
    domesticEnd(view),
    h('div', { class: 'end__actions' },
      h('button', { class: 'btn btn--ghost', 'data-action': 'restart' }, '같은 시드로 다시'),
      h('button', { class: 'btn', 'data-action': 'new-seed' }, '새 판')));
}
