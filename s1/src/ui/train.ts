import { COMM_NAME, D, P, bedNeed, isSessionSeg, jobTitle, relStage, situation, workshopState } from '../game';
import { unnamedInjured, woundView } from '../game/wounds';
import type { WoundRow } from '../game/wounds';
import type { Comm, Game } from '../game';
import { cx, h } from './dom';
import { icon } from './icons';
import type { IconName } from './icons';
import { TIP, fmt } from './common';
import type { CarDef, View } from './common';
import { bar, lever, tip } from './widgets';
import { nameBtn } from './names';
import { carPopover, spaceLever, spaceTab, stackCount, warmthTone } from './home';
import { carMods, domesticCarTag, domesticEngineCol, domesticWhyLine, gear, hungMark, potDot, trainCars, wallPeg, wallRow, workshopBoard } from './domestic';

// 열차 관리 화면(S1c, 사용자 2026-10-11): 칸을 누르면 작은 창이 아니라 화면 전체가 바뀐다.
// 위에 열차 전체 띠, 가운데에 누른 칸의 판(상태·조절·공방 세 덩이), 아래에 단추 여섯.
// 칸 창에 있던 수치와 레버는 옮겨 심기만 했다. 규칙과 숫자는 그대로다.

/** 띠에 적는 칸 이름(네 글자까지). 꼬리칸 셋은 번호로 가른다. */
export function stripName(car: CarDef): string {
  const tail = /^tail(\d)$/.exec(car.id);
  if (tail) return `꼬리${tail[1]}`;
  if (car.kind === 'loco') return '기관차';
  return car.plate === '의회' ? '식당' : car.plate === '일지' ? '열차장' : car.plate;
}

/** 지금 화면이 보일 칸. 기관차나 없는 칸이면 기관실, 그것도 없으면 맨 앞 칸. */
export function trainSel(g: Game, id: string | null): CarDef {
  const cars = trainCars(g);
  return cars.find(c => c.id === id && c.kind !== 'loco') ?? cars.find(c => c.id === 'engine') ?? cars[0];
}

function relTone(g: Game, c: Comm): 'up' | 'down' | 'mid' {
  const rel = g.comms[c].rel;
  return rel >= 15 ? 'up' : rel <= -15 ? 'down' : 'mid';
}

function jobPct(g: Game, carId: string): number | null {
  const job = g.dom?.job;
  return job && job.car === carId ? Math.round((job.progress / Math.max(1, job.need)) * 100) : null;
}

function restorePct(g: Game): number | null {
  const d = g.dom;
  const st = d?.restoring ? d.techs[d.restoring] : null;
  return st ? Math.round((st.progress / Math.max(1, st.need)) * 100) : null;
}

function stripCar(g: Game, car: CarDef, sel: CarDef): HTMLElement {
  const name = h('span', { class: 'tcar__name' }, stripName(car));
  if (car.kind === 'loco') return h('span', { class: 'tcar tcar--loco', 'aria-hidden': 'true' }, name);
  const sit = car.comm ? situation(g, car.comm) : null;
  const pct = jobPct(g, car.id) ?? (car.id === 'workshop' ? restorePct(g) : null);
  return h('button', {
    class: cx('tcar', sit && warmthTone(sit[0]), car.id === sel.id && 'is-open'),
    'data-action': 'car', 'data-car': car.id, 'aria-label': car.name, 'aria-pressed': car.id === sel.id ? 'true' : 'false',
  },
    name,
    h('span', { class: 'tcar__marks' },
      car.comm ? h('i', { class: `tcar__dot is-${relTone(g, car.comm)}` }) : null,
      hungMark(g, car),
      car.id === 'workshop' ? gear(workshopState(g).mode) : null,
      pct !== null ? h('small', { class: 'num' }, `${pct}%`) : null));
}

function blk(title: string, ...kids: (Node | null)[]): HTMLElement {
  return h('div', { class: 'tblk' }, h('span', { class: 'tblk__title' }, title), ...kids);
}

/** 사람이 사는 칸의 판: 칸 창의 수치 넷과 레버를 세 덩이로 옮겨 심었다. */
function commBoard(view: View, car: CarDef): HTMLElement {
  const { g } = view;
  const c = car.comm as Comm;
  const [w, r, cr, ex] = situation(g, c);
  const s = g.comms[c];
  const pct = jobPct(g, car.id);
  const job = g.dom?.job;
  return h('div', { class: 'carpop tpop', role: 'region', 'aria-label': `${car.name} 판` },
    h('div', { class: 'tpop__head' },
      h('b', { class: 'tpop__name' }, car.name),
      wallPeg(view, car),
      h('button', { class: 'x', 'data-action': 'car', 'data-car': car.id, 'aria-label': '닫기' }, '×')),
    wallRow(view, car),
    h('div', { class: 'tpop__body' },
      blk('상태',
        h('div', { class: 'tblk__row' },
          icon('people'), h('b', { class: 'num' }, `${s.pop}명`),
          h('span', { class: cx('stage', `stage--${relTone(g, c)}`) }, relStage(g, c)),
          COMM_NAME[c] !== car.name ? h('span', { class: 'sub' }, COMM_NAME[c]) : null),
        h('div', { class: 'carpop__stats' },
          h('span', null, tip('온기', TIP.warmth), h('b', { class: 'num' }, fmt(w)), bar(w, w < 45 ? '--discontent' : '--warm')),
          h('span', null, tip('배급', TIP.ration), h('b', { class: 'num' }, fmt(r)), bar(r, r < 45 ? '--discontent' : '--ink-3')),
          h('span', null, tip('과밀', TIP.crowding), h('b', { class: 'num' }, fmt(cr)), bar(cr, cr > 60 ? '--discontent' : '--ink-3')),
          h('span', null, tip('노출', TIP.exposure), h('b', { class: 'num' }, fmt(ex)), bar(ex, ex > 50 ? '--discontent' : '--ink-3'))),
        domesticCarTag(view, car, true),
        domesticWhyLine(view, car)),
      blk('조절',
        c === 'tail' ? h('div', { class: 'tblk__row' }, h('span', { class: 'sub' }, '꼬리칸 셋 공통'), spaceTab(view)) : null,
        c === 'tail' && view.ui.spaceOpen ? spaceLever(g)
          : h('div', { class: 'carpop__levers' }, lever(g, c, 'heat'), lever(g, c, 'ration'), domesticEngineCol(view, car, true)),
        potDot(view)),
      blk('공방',
        pct !== null && job
          ? h('div', { class: 'tblk__row' }, gear('work'), h('span', null, jobTitle(job.kind, job.car).replace(`${car.name} `, '')), h('b', { class: 'num' }, `${pct}%`))
          : h('div', { class: 'tblk__row' },
            carMods(g, car.id).map(m => h('span', { class: 'stage' }, icon('check'), m)),
            // 공방의 개조 화면으로 바로 간다(사용자 2026-10-11).
            h('button', { class: 'chip', 'data-action': 'dom-tab', 'data-tab': 'modify' }, '공방에서 개조하기')))));
}

const CARE_NAME: Record<WoundRow['care'], string> = { bed: '침상', home: '제 칸', up: '일어남' };

/** 명부에 적을 줄: 누른 칸 사람을 위로 올리고, 나머지는 받은 순서(생긴 순) 그대로 둔다. 화면이 따로 셈하지 않는다. */
export function woundRows(view: View, car: CarDef): WoundRow[] {
  const rows = woundView(view.g);
  if (!car.comm || car.comm === 'medtech') return rows;
  return [...rows.filter(r => r.comm === car.comm), ...rows.filter(r => r.comm !== car.comm)];
}

/** 의료 단추의 판(결정 042): 다친 사람 한 줄에 이름, 다친 곳, 등급, 남은 구간, 누운 자리. 이름이 없는 몫은 수만 적는다. */
function medBoard(view: View, car: CarDef): HTMLElement {
  const { g } = view;
  const rows = woundRows(view, car);
  const unnamed = unnamedInjured(g);
  const beds = bedNeed(g);
  return h('div', { class: 'carpop tpop tmed', role: 'region', 'aria-label': '부상 명부' },
    h('div', { class: 'tpop__head' },
      h('span', { class: 'tblk__row tmed__foot' }, icon('bed'), h('span', { class: cx('num', beds > D.beds && 'is-red') }, `침상 ${beds}/${D.beds}`)),
      h('b', { class: 'tpop__name' }, '부상 명부'),
      h('button', { class: 'x', 'data-action': 'dom-med', 'aria-label': '닫기' }, '×')),
    h('ul', { class: 'tmed__list' },
      rows.map(r => h('li', { class: cx('tmed__row', r.comm === car.comm && 'is-here') },
        h('b', { class: 'tmed__who' }, nameBtn(r.who)),
        h('span', { class: 'sub' }, COMM_NAME[r.comm]),
        h('span', null, r.partName),
        h('span', { class: cx(r.grade === 'fracture' || r.grade === 'amputation' ? 'is-red' : '') }, r.gradeName, r.septic ? ' · 곪음' : ''),
        h('span', { class: 'num' }, `${fmt(r.daysLeft)}구간`),
        h('span', { class: cx('tmed__care', r.care === 'home' && 'is-red') }, r.care === 'bed' ? icon('bed') : null, CARE_NAME[r.care]))),
      unnamed > 0 ? h('li', { class: 'tmed__row tmed__row--unnamed' }, `누군지 모르는 ${fmt(unnamed)}명`) : null,
      rows.length === 0 && unnamed === 0 ? h('li', { class: 'tmed__row sub' }, '다친 사람 없음') : null));
}

function board(view: View, car: CarDef): HTMLElement {
  if (view.ui.dom?.med) return medBoard(view, car);
  if (car.kind === 'comm' || car.kind === 'engine') return commBoard(view, car);
  if (car.id === 'workshop' && view.g.dom) return workshopBoard(view, car);
  return carPopover(view, car) ?? h('div', { class: 'carpop tpop' }, h('div', { class: 'tpop__head' }, h('b', { class: 'tpop__name' }, car.name)));
}

interface Btn { id: string; label: string; icon: IconName | 'gear'; data: Record<string, string>; on?: boolean; off?: boolean; badge?: string | null }

/** 아래 단추 여섯: 연구, 개조, 공방, 사람·매뉴얼, 정치, 의료. 개조·의료의 안쪽 판은 뒤 묶음에서 채운다. */
export function trainButtons(view: View, sel: CarDef): Btn[] {
  const { g, ui } = view;
  const rp = restorePct(g);
  const inCouncil = g.phase === 'council';
  const left = isSessionSeg(g.seg) ? 0 : P.sessionEvery - (g.seg % P.sessionEvery);
  const tab = ui.panel === 'dom' ? ui.dom?.tab : null;
  return [
    { id: 'research', label: '연구', icon: 'papers', data: { 'data-action': 'dom-tab', 'data-tab': 'plan' }, on: tab === 'plan', badge: rp !== null ? `${rp}%` : null },
    { id: 'modify', label: '개조', icon: 'lever', data: { 'data-action': 'dom-tab', 'data-tab': 'modify' }, on: tab === 'modify', badge: g.dom?.job ? `${jobPct(g, g.dom.job.car)}%` : null },
    { id: 'workshop', label: '공방', icon: 'gear', data: { 'data-action': 'car', 'data-car': 'workshop', 'data-keep': '1' }, on: !tab && !ui.dom?.med && sel.id === 'workshop' },
    { id: 'people', label: '사람·매뉴얼', icon: 'people', data: { 'data-action': 'dom-tab', 'data-tab': 'board' }, on: tab === 'board' },
    { id: 'politics', label: '정치', icon: 'scale', data: { 'data-action': 'go', 'data-screen': 'council' }, off: !inCouncil, badge: inCouncil ? null : left === 0 ? '이번 구간' : `${left}구간 뒤` },
    { id: 'medical', label: '의료', icon: 'bed', data: { 'data-action': 'dom-med' }, on: !tab && !!ui.dom?.med, badge: g.injured > 0 ? fmt(g.injured) : null },
  ];
}

export function trainScreen(view: View): HTMLElement {
  const { g, ui } = view;
  const cars = trainCars(g);
  const sel = trainSel(g, ui.carPop);
  return h('section', { class: 'tscreen' },
    // 띠 바깥 빈 곳을 누르면 홈으로 돌아간다.
    h('div', { class: 'tstrip', 'data-action': 'go', 'data-screen': 'home' }, cars.map(car => stripCar(g, car, sel))),
    h('div', { class: 'tboard', 'data-keep-scroll': 'tboard' }, board(view, sel)),
    h('div', { class: 'tbtns' }, trainButtons(view, sel).map(b => h('button', {
      class: cx('tbtn', b.on && 'is-on'), ...b.data, disabled: !!b.off, 'data-tbtn': b.id,
    },
      b.icon === 'gear' ? gear('idle') : icon(b.icon),
      h('span', { class: 'tbtn__label' }, b.label),
      b.badge ? h('small', { class: 'tbtn__badge num' }, b.badge) : null))),
    stackChip(view));
}

/** 서류 더미는 판을 가리지 않게 작은 꼬리표로 줄여 판 머리 왼쪽에 둔다. 누르면 홈에서처럼 서류가 펼쳐진다. */
function stackChip(view: View): HTMLElement | null {
  const n = stackCount(view.g, view.ui);
  if (n === 0 || view.ui.cardOpen) return null;
  return h('button', { class: 'chip tstack', 'data-action': 'open-stack', 'aria-label': `서류 ${n}장` }, icon('papers'), h('b', { class: 'num' }, n));
}
