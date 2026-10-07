import {
  BRANCH_NAME, CAR_COMM, CAR_NAME, COMM_NAME, D, FIELDS, FIELD_NAME, HOT_WATER_NAMES, HYGIENE_NAME, PENDING_TECHS, SKILL_NAME, TECHS, TECH_IDS,
  applyMove, buryOpen, cancelRestore, coldCap, createGame, createS1cGame, delegateStatus, delegateTier, escortOptions, finishCheck,
  freeTeacher, hotWaterCoal, hotWaterFloor, hygiene, irreplaceable, jobCheck, jobTitle, knowers, lawActive, living, manualWriter,
  materials, moveOpen, moveTask, movedThisStop, previewMove, requestApprentice, requestManual, restartTech, restoreCheck, restoreCost,
  setBury, setDelegate, setEscort, setFullRule, setHotWater, setTarget, startFinish, startJob, startRestore, storeCap, techMult,
  techPending, techRelSides, techTitle, techUsable, upkeepOf, workPower, workshopChief, workshopState, zoneAt,
} from '../game';
import type { Comm, DomPerson, Field, Game, ModKind, Task, TechId, Upkeep, Variant } from '../game';
import { cx, h, s } from './dom';
import { CARS, fmt, signed } from './common';
import type { CarDef, DomUi, Ui, View } from './common';
import { bar, portrait } from './widgets';
import { nameBtn, shownName } from './names';
import './domestic.css';

// S1c 내정 화면(s1c_domestic 11장). S1a 화면 파일에는 한 줄짜리 훅만 두고 내정 화면은 모두 여기서 그린다.
// g.dom이 없는 판(S1a)에서는 모든 함수가 null이나 S1a 값을 돌려준다.
// 공방칸 창(11.2), 설계도(11.3), 지식 현황판(11.4), 창고·냉동 창(11.5), 칸 순서 바꾸기(4.5), 정차 카드 줄(8.8, 4.1), H6 재기(12장).

// ---- 판 만들기 ----

/** 주소에 ?s1c=1이 있으면 내정을 켠 판으로 시작한다. */
export function urlWantsS1c(): boolean {
  const v = new URLSearchParams(globalThis.location?.search ?? '').get('s1c');
  return v === '1' || v === 'on';
}

export function newGame(seed: string, s1c: boolean): Game {
  return s1c ? createS1cGame(seed) : createGame(seed);
}

function domUi(ui: Ui): DomUi {
  ui.dom ??= { tab: 'workshop', node: null, order: null, mats: false };
  return ui.dom;
}

const close = (action: string, attrs: Record<string, string> = {}) =>
  h('button', { class: 'x', 'data-action': action, ...attrs, 'aria-label': '닫기' }, '×');

const UPKEEP_NAME: Record<keyof Upkeep, string> = { parts: '부품', coal: '석탄', wood: '목재', scrap: '고철' };
function upkeepText(u: Upkeep): string {
  const parts = (Object.keys(u) as (keyof Upkeep)[]).filter(k => (u[k] ?? 0) > 0).map(k => `${UPKEEP_NAME[k]} ${u[k]}`);
  return parts.length ? `유지 ${parts.join(' · ')}/구간` : '유지비 없음';
}

/** 톱니(공방 상태). 일하면 꽉 찬 톱니, 쉬면 빈 톱니, 재료가 모자라면 경고. */
function gear(mode: 'work' | 'idle' | 'short'): SVGSVGElement {
  if (mode === 'short') {
    return s('svg', { class: 'dom-gear is-short', viewBox: '0 0 16 16', 'aria-hidden': 'true' },
      s('path', { d: 'M8 2l6.5 12h-13z', fill: 'none', stroke: 'currentColor', 'stroke-width': 1.6, 'stroke-linejoin': 'round' }),
      s('path', { d: 'M8 6.5v3.5 M8 12v.5', stroke: 'currentColor', 'stroke-width': 1.6, 'stroke-linecap': 'round' }));
  }
  const teeth = Array.from({ length: 8 }, (_, i) => {
    const a = (i * Math.PI) / 4;
    return `M${8 + 5 * Math.cos(a)} ${8 + 5 * Math.sin(a)} L${8 + 7 * Math.cos(a)} ${8 + 7 * Math.sin(a)}`;
  }).join(' ');
  return s('svg', { class: cx('dom-gear', mode === 'work' && 'is-work'), viewBox: '0 0 16 16', 'aria-hidden': 'true' },
    s('path', { d: teeth, stroke: 'currentColor', 'stroke-width': 2, 'stroke-linecap': 'round' }),
    s('circle', { cx: 8, cy: 8, r: 4.6, fill: mode === 'work' ? 'currentColor' : 'none', stroke: 'currentColor', 'stroke-width': 1.6 }),
    s('circle', { cx: 8, cy: 8, r: 1.6, fill: 'var(--surface-1)' }));
}

// ---- 홈: 편성 순서와 칸 명판 ----

/** 홈에 그릴 칸(왼쪽 꼬리 → 오른쪽 기관차). S1c 판이면 dom.cars 순서와 덧붙인 칸을 따른다(4.2, 4.4, 4.5). */
export function trainCars(g: Game): CarDef[] {
  const d = g.dom;
  if (!d) return CARS;
  const byId = new Map(CARS.map(c => [c.id, c]));
  const extras: CarDef[] = d.extraCars.map((k, i) => k === 'store'
    ? { id: `extra${i}`, name: '덧붙인 창고칸', plate: '창고', kind: 'freight' }
    : { id: `extra${i}`, comm: 'tail', name: '덧붙인 객차', plate: '객차', kind: 'comm' });
  const body = [...d.cars].reverse().map(id => byId.get(id)).filter((c): c is CarDef => !!c);
  const head = ['engine', 'loco'].map(id => byId.get(id)).filter((c): c is CarDef => !!c);
  return [...extras.reverse(), ...body, ...head];
}

/** 명판(S1c): 공방칸에만 상태 톱니를 단다(11.1). 온실이 된 칸은 명판이 '온실'로 바뀐다. null이면 S1a 명판. */
export function domPlate(g: Game, car: CarDef): HTMLElement | null {
  const d = g.dom;
  if (!d) return null;
  if (d.greenhouse === car.id) return h('span', { class: 'car__plate dom-plate--green' }, '온실');
  if (car.id !== 'workshop') return null;
  const st = workshopState(g);
  return h('span', { class: cx('car__plate', 'dom-plate', `is-${st.mode}`), title: st.now }, car.plate, gear(st.mode));
}

// ---- 홈: 칸 창 ----

function popHead(car: CarDef, ...rest: (Node | null)[]): HTMLElement {
  return h('div', { class: 'carpop__head' }, h('b', null, car.name), ...rest, close('car', { 'data-car': car.id }));
}

function matRow(label: string, value: number, cap?: number): HTMLElement {
  return h('span', { class: 'dom-mat' }, label, ' ', h('b', { class: 'num' }, fmt(value)),
    cap !== undefined ? bar(value, value > cap ? '--discontent' : '--warm', Math.max(1, cap)) : null);
}

function workshopPop(view: View, car: CarDef): HTMLElement {
  const g = view.g;
  const d = g.dom!;
  const st = workshopState(g);
  const chief = workshopChief(g);
  const ds = delegateStatus(g);
  const tier = delegateTier(g);
  const restoring = d.restoring ? d.techs[d.restoring] : null;
  const taskName = (t: Task) => t === 'parts' ? '부품'
    : t === 'restore' ? `복원: ${d.restoring ? techTitle(g, d.restoring) : '비어 있음'}`
      : `개조: ${d.job ? jobTitle(d.job.kind, d.job.car) : '비어 있음'}`;
  const lockTarget = d.delegate.on;
  const lockOrder = d.delegate.on && tier >= 2;
  const off = TECH_IDS.filter(id => d.techs[id]?.off);
  return h('div', { class: 'carpop dom-pop', role: 'dialog', 'aria-label': '공방칸 창' },
    popHead(car,
      chief ? h('span', { class: 'dom-chief' }, portrait(chief.name, chief.comm), nameBtn(chief.name)) : null,
      d.delegate.on || !ds.ok ? h('button', {
        class: cx('chip', d.delegate.on && 'is-on'), 'data-action': 'dom-delegate', 'data-on': '0', disabled: !d.delegate.on, title: ds.why ?? '',
      }, d.delegate.on ? '맡김 · 거둔다' : '맡기기') : null,
      h('button', { class: 'btn btn--dark btn--small', 'data-action': 'dom-tab', 'data-tab': 'plan' }, '설계도 →')),
    !d.delegate.on && ds.ok ? h('div', { class: 'dom-row' },
      h('button', { class: 'chip', 'data-action': 'dom-delegate', 'data-on': '1', 'data-policy': 'neutral' }, '중립으로', h('small', null, ' 가장 추운 칸부터')),
      h('button', { class: 'chip', 'data-action': 'dom-delegate', 'data-on': '1', 'data-policy': 'ours' }, '우리 편 먼저', h('small', null, ' 호의 +1 · 나머지 −1/구간'))) : null,
    h('div', { class: 'dom-ws' },
      h('div', { class: 'dom-ws__left' },
        h('div', { class: 'dom-now' },
          gear(st.mode), h('span', null, '지금: ', h('b', null, st.now)),
          restoring ? bar(restoring.progress, '--warm', restoring.need) : null),
        h('div', { class: 'dom-target' },
          h('span', null, '부품 유지 ', h('b', { class: 'num' }, d.target), h('small', { class: 'sub' }, ` 있음 ${d.parts} · 작업 ${workPower(g).toFixed(1)}/구간`)),
          h('input', {
            class: 'lever__input', type: 'range', min: 0, max: D.targetMax, step: 1, value: d.target, disabled: lockTarget,
            'data-input': 'dom', 'data-which': 'target', 'aria-label': '부품 유지 목표치',
          }),
          !d.delegate.on && ds.why ? h('small', { class: 'dom-why' }, ds.why) : null,
          d.delegate.on ? h('small', { class: 'dom-why' }, `공방장이 ${['', '목표치만', '목표치와 순서를', '복원 대상까지'][tier]} 정한다(${d.delegate.policy === 'ours' ? '우리 편 먼저' : '중립'}).`) : null)),
      h('ol', { class: 'dom-order' }, d.order.map((t, i) => h('li', null,
        h('span', { class: 'num' }, i + 1), h('span', { class: 'dom-order__name' }, taskName(t)),
        h('button', { class: 'nav', 'data-action': 'dom-order', 'data-task': t, 'data-step': '-1', disabled: lockOrder || i === 0, 'aria-label': '앞으로' }, '↑'))))),
    off.length ? h('div', { class: 'dom-row' }, off.map(id => h('button', { class: 'chip', 'data-action': 'dom-restart', 'data-id': id }, `${TECHS[id].name} 다시 돌린다`))) : null,
    jobRow(g));
}

/** 공방에 올릴 수 있는 개조(장갑). 단열은 사용자 결정 대기, 온실은 '칸을 내줄 곳' 카드로 간다. */
function jobRow(g: Game): HTMLElement | null {
  const d = g.dom!;
  if (d.job) return null;
  const kinds: ModKind[] = ['armor'];
  const items = kinds.flatMap(k => Object.keys(CAR_COMM).filter(c => c !== 'engine' && jobCheck(g, k, c).ok).map(c => ({ k, c })));
  if (items.length === 0) return null;
  return h('div', { class: 'dom-row' }, h('span', { class: 'sub' }, '개조'),
    items.map(x => h('button', { class: 'chip', 'data-action': 'dom-job', 'data-kind': x.k, 'data-car': x.c }, jobTitle(x.k, x.c))));
}

function storePop(view: View, car: CarDef): HTMLElement {
  const g = view.g;
  const d = g.dom!;
  const cap = storeCap(g);
  const rules: { id: 'parts' | 'dump' | 'aisle'; label: string }[] = [
    { id: 'parts', label: '부품감만 남긴다' }, { id: 'dump', label: '넘치면 버린다' }, { id: 'aisle', label: '통로에도 쌓는다' },
  ];
  return h('div', { class: 'carpop carpop--small dom-pop', role: 'dialog', 'aria-label': `${car.name} 창` },
    popHead(car),
    h('div', { class: 'dom-mats' },
      matRow('자재', materials(g), cap), matRow('고철', d.scrap), matRow('목재', d.wood), matRow('부품', d.parts)),
    h('p', { class: 'carpop__text' }, `식량 ${fmt(g.food)} · 의약품 ${fmt(g.med)} · 사치품 ${fmt(g.lux)}.`),
    d.fullRule ? h('div', { class: 'dom-row' }, rules.map(r => h('button', {
      class: cx('chip', d.fullRule === r.id && 'is-on'), 'data-action': 'dom-full', 'data-rule': r.id,
    }, r.label))) : null);
}

function coldPop(view: View, car: CarDef): HTMLElement {
  const g = view.g;
  const d = g.dom!;
  const store = lawActive(g, 'corpse_store');
  return h('div', { class: 'carpop carpop--small dom-pop', role: 'dialog', 'aria-label': `${car.name} 창` },
    popHead(car),
    h('p', { class: 'carpop__text' }, store || g.stored + (g.pyre ?? 0) > 0
      ? `천에 싸인 시신 ${g.stored + (g.pyre ?? 0)}/${coldCap(g)}구.${g.pyre ? ` ${g.pyre}구는 다음 정차 장작불을 기다린다.` : ''} 넘으면 녹는 사고가 두 배다.`
      : '비어 있다. 창마다 성에가 두껍다.'),
    d.techs.m3?.variant === 'b' ? h('p', { class: 'carpop__text' }, '식량을 먼저 채운다(식량 보존).') : null,
    g.stored > 0 ? h('p', { class: 'sub' }, '길게 머무는 정차에서 묻고 갈 수 있다.') : null);
}

function extraPop(view: View, car: CarDef): HTMLElement {
  return h('div', { class: 'carpop carpop--small dom-pop', role: 'dialog' },
    popHead(car),
    h('p', { class: 'carpop__text' }, car.kind === 'freight'
      ? `화물역에서 달았다. 자재 상한 +${D.storeCap}. 석탄 ${D.extraCarCoal}/구간.`
      : `화물역에서 달았다. 꼬리칸 과밀이 준다. 석탄 ${D.extraCarCoal}/구간.`));
}

/** 내정 칸의 창(공방, 창고, 냉동, 덧붙인 칸). null이면 S1a 창을 그린다. */
export function domesticPopover(view: View, car: CarDef): HTMLElement | null {
  if (!view.g.dom) return null;
  if (car.id === 'workshop') return workshopPop(view, car);
  if (car.id === 'store') return storePop(view, car);
  if (car.id === 'cold') return coldPop(view, car);
  if (car.id.startsWith('extra')) return extraPop(view, car);
  return null;
}

/** 사람이 사는 칸 창 머리의 작은 표(S1c): 위생, 이·병, 의무칸 침상(16.3, 4.1). 칸 창 높이를 늘리지 않는다. */
export function domesticCarTag(view: View, car: CarDef): HTMLElement | null {
  const g = view.g;
  const d = g.dom;
  const c = car.comm;
  if (!d || !c) return null;
  const hy = hygiene(g, c);
  const lice = d.lice[c];
  const sick = d.typhus.filter(t => t.comm === c).reduce((n, t) => n + t.patients.length, 0);
  const beds = Math.max(0, g.injured) + d.typhus.reduce((n, t) => n + t.patients.length, 0);
  return h('span', { class: 'dom-tag' },
    h('span', { class: cx('dom-hy', `is-${hy}`) }, `위생 ${HYGIENE_NAME[hy]}`),
    lice ? h('span', { class: 'is-red' }, '이') : null,
    sick ? h('span', { class: 'is-red' }, `티푸스 ${sick}`) : null,
    c === 'medtech' ? h('span', { class: beds > D.beds ? 'is-red' : '' }, `침상 ${beds}/${D.beds}`) : null);
}

/** 기관실 칸 창의 셋째 줄: 더운물 레버(16.2, 열차 전체 하나)와 지식 현황판 단추(11.4). */
export function domesticEngineCol(view: View, car: CarDef): HTMLElement | null {
  const g = view.g;
  const d = g.dom;
  if (!d || car.comm !== 'engine') return null;
  const floor = hotWaterFloor(g);
  return h('div', { class: 'dom-engine' },
    h('span', { class: 'dom-hot__name' }, '더운물'),
    h('span', { class: 'dom-hot' },
      h('button', { class: 'nav', 'data-action': 'dom-hot', 'data-value': d.hotWater - 1, disabled: d.hotWater <= floor, 'aria-label': '더운물 덜' }, '−'),
      h('b', { 'aria-live': 'polite' }, HOT_WATER_NAMES[d.hotWater]),
      h('button', { class: 'nav', 'data-action': 'dom-hot', 'data-value': d.hotWater + 1, disabled: d.hotWater >= 3, 'aria-label': '더운물 더' }, '+')),
    h('small', { class: 'sub num' }, `석탄 ${hotWaterCoal(g).toFixed(1)}/구간`),
    floor > 0 ? h('small', { class: 'sub' }, '법으로 드물게 이상') : null,
    h('button', { class: 'chip', 'data-action': 'dom-tab', 'data-tab': 'board' }, '현황판'));
}

// ---- 위 자원 줄: 자재 ----

export function domesticResource(view: View): HTMLElement | null {
  const { g, ui } = view;
  const d = g.dom;
  if (!d) return null;
  const m = materials(g);
  const cap = storeCap(g);
  const open = domUi(ui).mats;
  return h('div', { class: 'dom-res' },
    h('button', { class: cx('res', 'dom-res__btn', open && 'is-on'), 'data-action': 'dom-mats', 'aria-label': `자재 ${fmt(m)}/${cap}, 부품 ${d.parts}` },
      h('span', { class: 'dom-res__gauge' }, h('i', { style: `height:${Math.min(100, (m / Math.max(1, cap)) * 100).toFixed(0)}%` })),
      h('div', { class: 'res__body' }, h('b', { class: cx('num', m > cap && 'is-low') }, fmt(m)), h('span', { class: 'res__delta' }, '자재'))),
    open ? h('div', { class: 'dom-res__drop', role: 'status' },
      h('span', null, '고철 ', h('b', { class: 'num' }, fmt(d.scrap))),
      h('span', null, '목재 ', h('b', { class: 'num' }, fmt(d.wood))),
      h('span', null, '부품 ', h('b', { class: 'num' }, fmt(d.parts))),
      h('span', { class: 'sub num' }, `상한 ${cap}`)) : null);
}

// ---- 정차 카드의 내정 줄 ----

/** 정차 준비 카드에 더하는 줄: 전문가 데려가기(8.8), 냉동칸 묻고 가기(4.1), 화물역 칸 순서(4.5). */
export function domesticStopRows(view: View): HTMLElement | null {
  const g = view.g;
  const d = g.dom;
  if (!d || !g.stop || g.stop.done) return null;
  const rows: HTMLElement[] = [];
  // 분야마다 한 명(가장 숙련된, 지금 갈 수 있는 사람)만 단추로 둔다. 고른 사람은 늘 보인다. 정차 카드가 길어지지 않게 하려는 화면 쪽 줄임(제안).
  const all = escortOptions(g);
  const fieldOf = (id: string) => d.people.find(p => p.id === id);
  const opts = all.filter(o => {
    if (o.id === d.escort) return true;
    if (o.why) return false;
    const p = fieldOf(o.id);
    const best = all.filter(x => !x.why && fieldOf(x.id)?.field === p?.field).sort((x, y) => (fieldOf(y.id)?.skill ?? 0) - (fieldOf(x.id)?.skill ?? 0))[0];
    return best?.id === o.id;
  });
  if (opts.length) {
    rows.push(h('div', { class: 'field field--row' },
      h('span', { class: 'field__label' }, '전문가'),
      h('button', { class: cx('chip', !d.escort && 'is-on'), 'data-action': 'dom-escort', 'data-id': '' }, '안 데려간다'),
      opts.map(o => h('button', {
        class: cx('chip', d.escort === o.id && 'is-on', o.last && 'dom-last'), 'data-action': 'dom-escort', 'data-id': o.id, disabled: !!o.why, title: o.why ?? '',
      }, escortLabel(g, o.id, o.label), o.last ? h('small', { class: 'is-red' }, ' 마지막') : null))));
  }
  if (g.stored > 0) {
    const b = buryOpen(g);
    rows.push(h('div', { class: 'field field--row' },
      h('span', { class: 'field__label' }, '냉동칸'),
      h('button', { class: cx('chip', d.bury && 'is-on'), 'data-action': 'dom-bury', 'data-on': d.bury ? '0' : '1', disabled: !b.ok && !d.bury, title: b.why ?? '' },
        `묻고 간다(${Math.min(D.buryMax, g.stored)}구)`, h('small', null, ` 산출 ×${D.buryHaul}`)),
      !b.ok ? h('small', { class: 'sub' }, b.why) : null));
  }
  const mv = moveOpen(g);
  if (mv.ok) {
    rows.push(h('div', { class: 'field field--row' },
      h('span', { class: 'field__label' }, '측선'),
      h('button', { class: 'chip', 'data-action': 'dom-tab', 'data-tab': 'move' }, movedThisStop(g) ? '칸 순서를 바꿨다' : '칸 순서 바꾸기'),
      h('small', { class: 'sub' }, movedThisStop(g) ? '이번엔 짧게 못 머문다' : `칸마다 석탄 ${D.moveCoal}, 짧게 못 머문다`)));
  }
  return rows.length ? h('div', { class: 'dom-stoprows' }, rows) : null;
}

/** 데려갈 전문가 단추 글: 이름(겹치면 성 첫 글자)과 분야·숙련 점. */
function escortLabel(g: Game, id: string, fallback: string): string {
  const p = g.dom?.people.find(x => x.id === id);
  return p ? `${shownName(p.name)} ${FIELD_NAME[p.field]}${dots(p.skill)}` : fallback;
}

/** 칸 순서를 바꾼 정차는 '짧게'를 못 고른다(4.5). */
export function stayLocked(g: Game, stay: string): boolean {
  return stay === 'short' && movedThisStop(g);
}

// ---- 내정 창(공방 설계도, 지식 현황판, 칸 순서) ----

type NodeState = 'pending' | 'unknown' | 'collect' | 'defect' | 'ready' | 'restoring' | 'done' | 'faded' | 'rust' | 'off';

function nodeState(g: Game, id: TechId): NodeState {
  const st = g.dom!.techs[id];
  if (!st) {
    if (techPending(id)) return 'pending';
    const c = restoreCheck(g, id);
    if (!c.full || c.full === '부품이 모자라다' || c.full === '공방이 다른 복원 중' || c.full === '목재가 모자라다') return 'ready';
    if (!c.defect || c.defect === '부품이 모자라다' || c.defect === '공방이 다른 복원 중') return 'defect';
    return g.dom!.frags[TECHS[id].branch] > 0 ? 'collect' : 'unknown';
  }
  if (st.stage === 'restoring' || st.finishing) return 'restoring';
  if (st.off) return 'off';
  const m = techMult(g, id);
  if (m <= 0) return 'rust';
  if (st.stage === 'defective' || m < 0.99) return 'faded';
  return 'done';
}

const NODE_TAG: Record<NodeState, string> = {
  pending: '보류', unknown: '', collect: '', defect: '결함판 가능', ready: '복원 가능', restoring: '복원 중', done: '', faded: '×0.7', rust: '고장', off: '세움',
};

function techNode(g: Game, id: TechId, sel: boolean): HTMLElement {
  const d = g.dom!;
  const def = TECHS[id];
  const ns = nodeState(g, id);
  const st = d.techs[id];
  const cost = restoreCost(id);
  const tag = ns === 'faded' && st?.stage === 'defective' ? '결함판' : NODE_TAG[ns];
  return h('button', {
    class: cx('dom-node', `is-${ns}`, def.tier === 0 && 'is-adapt', sel && 'is-sel'), 'data-action': 'dom-node', 'data-id': id,
    'aria-label': `${def.name} ${tag}`,
  },
    h('span', { class: 'dom-node__name' }, techTitle(g, id), def.variants && !st?.variant ? ' ◇' : ''),
    ns === 'collect' || ns === 'unknown' ? h('span', { class: 'dom-node__frag num' }, `${d.frags[def.branch]}/${cost.frags}`) : null,
    ns === 'restoring' && st ? bar(st.progress, '--warm', st.need) : null,
    tag ? h('small', { class: 'dom-node__tag' }, tag) : null);
}

function sideLine(sides: { like: Comm[]; dislike: Comm[] }): string {
  return [...sides.like.map(c => `${COMM_NAME[c]} +${D.techRel}`), ...sides.dislike.map(c => `${COMM_NAME[c]} −${D.techRel}`)].join(' · ');
}

function faces(cs: Comm[], g: Game): HTMLElement[] {
  return cs.map(c => h('span', { class: 'dom-face' }, portrait(g.comms[c].leader.name, c), COMM_NAME[c]));
}

function nodeDetail(g: Game, id: TechId): HTMLElement {
  const d = g.dom!;
  const def = TECHS[id];
  const st = d.techs[id];
  const check = restoreCheck(g, id);
  const cost = restoreCost(id);
  const frags = d.frags[def.branch];
  const variants: (Variant | undefined)[] = def.variants && !st ? ['a', 'b'] : [undefined];
  const buttons: HTMLElement[] = [];
  if (!st && !techPending(id)) {
    for (const v of variants) {
      const vName = v && def.variants ? `${def.variants[v].name}: ` : '';
      const rel = sideLine(techRelSides(id, v));
      buttons.push(h('button', {
        class: 'choice', 'data-action': 'dom-restore', 'data-id': id, 'data-mode': 'full', 'data-variant': v ?? '', disabled: !!check.full,
      }, h('span', { class: 'choice__label' }, `${vName}복원 시작`),
      h('span', { class: 'choice__meta' },
        h('span', { class: 'cost num' }, `부품 −${cost.parts}`), cost.wood ? h('span', { class: 'cost num' }, `목재 −${cost.wood}`) : null,
        rel ? h('span', { class: 'pol pol--gray' }, rel) : null,
        check.full ? h('span', { class: 'pol pol--gray' }, check.full) : null)));
      if (check.defect !== '없다' && check.defect !== '완성판으로 된다') {
        buttons.push(h('button', {
          class: 'choice', 'data-action': 'dom-restore', 'data-id': id, 'data-mode': 'defect', 'data-variant': v ?? '', disabled: !!check.defect,
        }, h('span', { class: 'choice__label' }, `${vName}결함판으로`),
        h('span', { class: 'choice__meta' },
          h('span', { class: 'cost num' }, `부품 −${cost.parts}`), h('span', { class: 'cost' }, `효과 절반, 고장 +${Math.round(D.defectBreak * 100)}%p`),
          rel ? h('span', { class: 'pol pol--gray' }, rel) : null,
          check.defect ? h('span', { class: 'pol pol--gray' }, check.defect) : null)));
      }
    }
  }
  if (st && d.restoring === id) buttons.push(h('button', { class: 'btn btn--ghost', 'data-action': 'dom-cancel' }, '복원을 멈춘다(부품은 안 돌아온다)'));
  if (st?.stage === 'defective' && !st.finishing) {
    const why = finishCheck(g, id);
    buttons.push(h('button', { class: 'btn btn--dark', 'data-action': 'dom-finish', 'data-id': id, disabled: !!why, title: why ?? '' },
      `완성판으로 고친다(조각 ${cost.frags - cost.defectFrags})`));
  }
  if (st?.off) buttons.push(h('button', { class: 'btn btn--dark', 'data-action': 'dom-restart', 'data-id': id }, '다시 돌린다'));
  const sides = { like: def.variants && st?.variant ? def.variants[st.variant].like : def.like, dislike: def.variants && st?.variant ? def.variants[st.variant].dislike : def.dislike };
  return h('div', { class: 'dom-detail' },
    h('div', { class: 'dom-detail__head' },
      h('span', { class: 'kicker' }, `${BRANCH_NAME[def.branch]} · ${def.tier === 0 ? '적응' : ['', '응급 복원', '구시대 표준', '잃어버린 기술'][def.tier]}`),
      h('b', null, techTitle(g, id)),
      close('dom-node', { 'data-id': id })),
    techPending(id) ? h('p', { class: 'dom-why' }, '아끼기만 하는 기술이라 사용자 결정 전까지 열지 않는다(기획 점검 03).') : null,
    def.variants && !st?.variant
      ? h('ul', { class: 'dom-variants' }, (['a', 'b'] as Variant[]).map(v => h('li', null,
        h('b', null, `${v === 'a' ? '가' : '나'}. ${def.variants![v].name}`), ` ${def.variants![v].effect} · ${upkeepText(def.variants![v].upkeep)}`)))
      : h('p', null, def.variants && st?.variant ? def.variants[st.variant].effect : def.effect, h('span', { class: 'sub' }, ` · ${upkeepText(upkeepOf(g, id))}`)),
    !st ? h('ul', { class: 'dom-checks' },
      h('li', { class: frags >= cost.frags ? 'is-ok' : '' }, `설계도 조각 ${frags}/${cost.frags}${cost.defectFrags < cost.frags ? ` (결함판 ${cost.defectFrags})` : ''}`),
      cost.core ? h('li', { class: d.cores >= cost.core ? 'is-ok' : '' }, `코어 ${d.cores}/${cost.core}`) : null,
      h('li', { class: check.full === `${['', '견습', '숙련', '장인'][def.tier]} 이상이 없다` ? '' : 'is-ok' },
        def.tier === 0 ? '사람 조건 없음' : `${FIELD_NAME[def.branch]} ${SKILL_NAME[def.tier]} 이상`)) : null,
    sides.like.length || sides.dislike.length ? h('div', { class: 'dom-sides' },
      sides.like.length ? h('span', { class: 'is-blue' }, '반김 ', faces(sides.like, g)) : null,
      sides.dislike.length ? h('span', { class: 'is-red' }, '못마땅 ', faces(sides.dislike, g)) : null) : null,
    buttons.length ? h('div', { class: 'dom-buttons' }, buttons) : null);
}

function planView(view: View): HTMLElement {
  const g = view.g;
  const sel = domUi(view.ui).node as TechId | null;
  const tiers = [1, 2, 3, 0] as const;
  return h('div', { class: 'dom-plan' },
    h('div', { class: 'dom-plan__grid' },
      h('span', null), ['응급 복원', '구시대 표준', '잃어버린 기술', '적응'].map(t => h('span', { class: 'dom-plan__col sub' }, t)),
      FIELDS.map(f => [
        h('span', { class: 'dom-plan__row' }, BRANCH_NAME[f]),
        tiers.map(t => h('div', { class: 'dom-plan__cell' },
          TECH_IDS.filter(id => TECHS[id].branch === f && TECHS[id].tier === t).map(id => techNode(g, id, sel === id)))),
      ])),
    h('p', { class: 'sub' }, `◇ 변형 둘 중 하나 · 보류: ${PENDING_TECHS.map(id => TECHS[id].name).join(', ')}(사용자 결정 대기)`),
    sel && TECHS[sel] ? nodeDetail(g, sel) : null);
}

function dots(skill: number): string {
  return [1, 2, 3].map(i => (i <= skill ? '●' : '○')).join('');
}

function personChip(g: Game, p: DomPerson): HTMLElement {
  const teacher = p.learn ? (p.learn.by === 'manual' ? '매뉴얼' : g.dom!.people.find(x => x.id === p.learn!.by)?.name ?? '') : '';
  return h('span', { class: cx('dom-person', `c-${p.comm}`) },
    nameBtn(p.name), h('span', { class: 'dom-dots' }, dots(p.skill)),
    p.learn ? h('small', { class: 'sub' }, ` →${SKILL_NAME[p.skill + 1] ?? ''} ${p.learn.left}구간${teacher ? `(${teacher.split(' ')[0]})` : ''}`) : null,
    p.writing ? h('small', { class: 'sub' }, ` 매뉴얼 쓰는 중 ${p.writing}`) : null,
    p.leaveRisk ? h('small', { class: 'is-red' }, ' 떠날 수 있다') : null);
}

function boardView(view: View): HTMLElement {
  const g = view.g;
  const d = g.dom!;
  return h('div', { class: 'dom-board' },
    h('ul', { class: 'dom-board__rows' }, FIELDS.map((f: Field) => {
      const people = living(g).filter(p => p.field === f);
      const k = knowers(g, f);
      const only = irreplaceable(g, f);
      const cd = d.countdown[f];
      const relies = TECH_IDS.filter(id => TECHS[id].branch === f && TECHS[id].tier > 0 && techUsable(g, id)).map(id => TECHS[id].name);
      const teacher = freeTeacher(g, f);
      const writer = manualWriter(g, f);
      return h('li', { class: cx('dom-board__row', only && 'is-only', k.length === 0 && 'is-empty') },
        h('b', { class: 'dom-board__field' }, FIELD_NAME[f]),
        h('div', { class: 'dom-board__people' },
          people.length ? people.map(p => personChip(g, p)) : h('span', { class: 'is-red' }, '아무도 없다'),
          cd !== undefined ? h('span', { class: 'dom-count num', title: '남은 구간' }, cd) : null,
          only ? h('span', { class: 'dom-only' }, '대체 불가') : null),
        h('span', { class: cx('dom-manual', d.manuals[f] && 'is-on') }, `매뉴얼 ${d.manuals[f] ? '✓' : '✕'}`),
        h('span', { class: 'dom-relies sub' }, relies.length ? relies.join('·') : '(기대는 기술 없음)'),
        h('span', { class: 'dom-board__acts' },
          h('button', { class: 'chip', 'data-action': 'dom-apprentice', 'data-field': f, disabled: !teacher, title: teacher ? '' : '가르칠 사람이 없다' }, '견습생 붙이기'),
          h('button', { class: 'chip', 'data-action': 'dom-manual', 'data-field': f, disabled: !writer.who || !!writer.why, title: writer.why ?? '' }, '매뉴얼 쓰게 하기')));
    })),
    h('p', { class: 'sub' }, '단추는 서류를 만든다. 결정은 서류에서 한다.'));
}

function moveView(view: View): HTMLElement {
  const g = view.g;
  const d = g.dom!;
  const du = domUi(view.ui);
  const order = du.order && du.order.length === d.cars.length ? du.order : [...d.cars];
  const pv = previewMove(g, order);
  const open = moveOpen(g);
  const zoneName = { front: '앞', middle: '가운데', back: '뒤' } as const;
  const changes = [
    ...(Object.keys(pv.warm) as Comm[]).filter(c => pv.warm[c]).map(c => h('span', { class: pv.warm[c]! > 0 ? 'is-blue' : 'is-red' }, `${COMM_NAME[c]} 온기 ${signed(pv.warm[c]!)}`)),
    ...(Object.keys(pv.rel) as Comm[]).filter(c => pv.rel[c]).map(c => h('span', { class: pv.rel[c]! > 0 ? 'is-blue' : 'is-red' }, `${COMM_NAME[c]} ${pv.rel[c]! > 0 ? '지지' : '불만'} ${signed(pv.rel[c]!)}`)),
    pv.frontPushed ? h('span', { class: 'is-red' }, '앞칸 대표 적의 +1') : null,
    pv.workshopZone !== 'front' ? h('span', { class: 'is-red' }, '공방 작업 ×0.8') : null,
  ];
  return h('div', { class: 'dom-move' },
    h('p', { class: 'sub' }, '기관차 쪽이 위다. 칸 셋까지, 칸마다 석탄 0.5. 바꾸면 이번 정차는 짧게 못 머문다.'),
    h('ol', { class: 'dom-move__list' }, order.map((car, i) => {
      const moved = d.cars.indexOf(car) !== i;
      return h('li', { class: cx(moved && 'is-moved', CAR_COMM[car] && `c-${CAR_COMM[car]}`) },
        h('span', { class: 'dom-zone sub' }, zoneName[zoneAt(i)]),
        h('span', { class: 'dom-move__name' }, CAR_NAME[car] ?? car, d.greenhouse === car ? ' (온실)' : ''),
        h('button', { class: 'nav', 'data-action': 'dom-move', 'data-car': car, 'data-step': '-1', disabled: i === 0, 'aria-label': '앞으로' }, '↑'),
        h('button', { class: 'nav', 'data-action': 'dom-move', 'data-car': car, 'data-step': '1', disabled: i === order.length - 1, 'aria-label': '뒤로' }, '↓'));
    })),
    h('div', { class: 'dom-move__preview', 'aria-live': 'polite' },
      pv.moved.length ? h('span', { class: 'num' }, `석탄 −${pv.coal}`) : h('span', { class: 'sub' }, '바뀐 칸이 없다'),
      changes, pv.why ? h('span', { class: 'is-red' }, pv.why) : null),
    h('div', { class: 'dom-row' },
      h('button', { class: 'btn btn--ghost', 'data-action': 'dom-move-reset' }, '처음대로'),
      h('button', { class: 'btn', 'data-action': 'dom-move-apply', disabled: !open.ok || !!pv.why || pv.moved.length === 0, title: open.why ?? '' }, '이대로 입환한다')));
}

/** ui.panel === 'dom'일 때 겹쳐 뜨는 내정 창. */
export function domesticPanel(view: View): HTMLElement | null {
  const g = view.g;
  if (!g.dom) return null;
  const du = domUi(view.ui);
  const tabs: { id: DomUi['tab']; label: string; show: boolean }[] = [
    { id: 'workshop', label: '공방', show: true },
    { id: 'plan', label: '설계도', show: true },
    { id: 'board', label: '지식 현황판', show: true },
    { id: 'move', label: '칸 순서', show: moveOpen(g).ok },
  ];
  const tab = tabs.find(t => t.id === du.tab && t.show) ? du.tab : 'plan';
  const body = tab === 'plan' ? planView(view) : tab === 'board' ? boardView(view) : tab === 'move' ? moveView(view)
    : workshopPop(view, CARS.find(c => c.id === 'workshop')!);
  return h('div', { class: 'side dom-side', role: 'dialog', 'aria-label': '내정 창', 'data-keep-scroll': 'dom-side' },
    h('div', { class: 'drop__head' },
      h('b', null, '내정'),
      h('span', { class: 'dom-tabs' }, tabs.filter(t => t.show).map(t => h('button', {
        class: cx('chip', t.id === tab && 'is-on'), 'data-action': 'dom-tab', 'data-tab': t.id,
      }, t.label))),
      close('panel', { 'data-panel': '' })),
    body);
}

/** 메뉴의 단추: 내정을 켠(끈) 새 판. */
export function domesticMenu(view: View): HTMLElement {
  const on = !!view.g.dom;
  return h('button', { class: 'btn btn--ghost', 'data-action': 'dom-new', 'data-on': on ? '0' : '1' }, on ? '내정 끈 새 판(S1a)' : '내정 켠 새 판(S1c)');
}

// ---- H6 재기(12장) ----

/** 이만큼 입력이 없으면 그 뒤는 세지 않는다(자리를 비운 시간). */
export const H6_IDLE_MS = 30_000;

export interface H6Clock {
  /** 지난 입력 시각 */
  since: number;
  /** 내정 화면이 열려 있던 구간. null이면 열려 있지 않았다 */
  seg: number | null;
}

/** 내정 시간으로 세는 화면이 열려 있나(12.1): 칸 창, 한눈에 보기, 내정 창, 내정 카드. 의회·정차 카드·정치 카드는 빼다. */
export function domesticActive(g: Game, ui: Ui): boolean {
  if (!g.dom || g.phase === 'end') return false;
  if (ui.screen === 'council') return false;
  if (ui.panel === 'dom') return true;
  if (ui.cardOpen) {
    if (g.phase === 'stop' && g.stop && (!g.stop.done || !ui.stopSeen)) return false;
    return !!g.cards[0]?.kind.startsWith('dom:');
  }
  return ui.carPop !== null || ui.screen === 'overview';
}

/** 내정 조작인가(12.1): 레버 한 칸, 순서 바꾸기, 내정 카드 선택, 내정 단추. */
export function domesticOp(g: Game, action: string): boolean {
  if (action.startsWith('dom-') && action !== 'dom-tab' && action !== 'dom-node' && action !== 'dom-mats') return true;
  if (action === 'lever') return true;
  return action === 'choose' && !!g.cards[0]?.kind.startsWith('dom:');
}

function h6Seg(g: Game, seg: number) {
  return (g.dom!.h6.segs[String(seg)] ??= { ms: 0, ops: 0, cards: 0 });
}

/** 입력 하나가 오기 전: 지난 입력부터 지금까지 내정 화면이 열려 있었으면 그 구간에 더하고, 조작이면 센다. */
export function h6Input(g: Game, clock: H6Clock, now: number, action: string): void {
  if (!g.dom) return;
  if (clock.seg !== null && clock.since > 0) h6Seg(g, clock.seg).ms += Math.max(0, Math.min(now - clock.since, H6_IDLE_MS));
  if (domesticOp(g, action)) {
    h6Seg(g, g.seg).ops += 1;
    if (action === 'choose') h6Seg(g, g.seg).cards += 1;
  }
  clock.since = now;
  clock.seg = null;
}

/** 그린 뒤: 지금 내정 화면이 열려 있으면 이 구간으로 재기 시작한다. */
export function h6Render(g: Game, ui: Ui, clock: H6Clock, now: number): void {
  if (!g.dom) return;
  const active = domesticActive(g, ui);
  if (active && clock.seg === null) clock.since = now;
  clock.seg = active ? g.seg : null;
}

export interface H6Summary { segs: number; medianS: number; p90S: number; maxS: number; medianOps: number; picks: number }

export function h6Summary(g: Game): H6Summary | null {
  const d = g.dom;
  if (!d) return null;
  const all = Array.from({ length: Math.max(1, g.seg) }, (_, i) => d.h6.segs[String(i + 1)] ?? { ms: 0, ops: 0, cards: 0 });
  const q = (xs: number[], p: number) => { const s2 = [...xs].sort((a, b) => a - b); return s2[Math.min(s2.length - 1, Math.floor(p * s2.length))] ?? 0; };
  const ms = all.map(x => x.ms);
  return {
    segs: all.length, medianS: Math.round(q(ms, 0.5) / 1000), p90S: Math.round(q(ms, 0.9) / 1000), maxS: Math.round(Math.max(0, ...ms) / 1000),
    medianOps: q(all.map(x => x.ops), 0.5), picks: d.h6.picks.length,
  };
}

/** 판 뒤 JSON(12.1: 구간별 표와 내정 카드 선택). */
export function h6Export(g: Game): string {
  const d = g.dom;
  return JSON.stringify({ seed: g.seed, end: g.end, seg: g.seg, h6: d?.h6 ?? null, summary: h6Summary(g), stats: d?.stats ?? null }, null, 2);
}

/** 끝 화면에 붙이는 H6 요약과 판 뒤 질문(12.2, 12.3). */
export function domesticEnd(view: View): HTMLElement | null {
  const g = view.g;
  const sm = h6Summary(g);
  if (!sm) return null;
  const pass = (ok: boolean) => h('b', { class: ok ? 'dom-pass' : 'is-red' }, ok ? '통과' : '넘침');
  return h('div', { class: 'dom-end' },
    h('b', null, '내정 시간(H6)'),
    h('ul', { class: 'dom-end__list num' },
      h('li', null, `구간당 중앙값 ${sm.medianS}초 `, pass(sm.medianS <= 120)),
      h('li', null, `상위 10% ${sm.p90S}초 `, pass(sm.p90S <= 300)),
      h('li', null, `가장 긴 구간 ${sm.maxS}초 `, pass(sm.maxS <= 600)),
      h('li', null, `조작 수 중앙값 ${sm.medianOps} `, pass(sm.medianOps <= 6)),
      h('li', null, `내정 카드 ${sm.picks}장 골랐다`)),
    h('p', { class: 'sub' }, '판 뒤 질문: 공방·현황판엔 확인하려고 들어갔나 바꾸려고 들어갔나? 견습생을 고를 때 기관실 반응을 생각했나? 결함판을 썼나? 맡기기를 켰다면 공방장이 뭘 했는지 알아챘나?'),
    // 아티팩트 창은 내려받기를 막는다. 기록은 펼쳐서 복사한다.
    h('details', { class: 'dom-export' },
      h('summary', null, '내정 기록(JSON) 펼치기'),
      h('textarea', { class: 'dom-export__text', readonly: true, rows: 6 }, h6Export(g))));
}

// ---- 입력 ----

export interface DomCtx {
  game(): Game;
  ui(): Ui;
  act(fn: (next: Game) => void): void;
  toast(text: string): void;
  render(): void;
  /** 새 판으로 바꾼다 */
  reset(next: Game): void;
}

/** 내정 단추(data-action="dom-…"). 처리했으면 true. */
export function handleDomestic(action: string, data: DOMStringMap, ctx: DomCtx): boolean {
  if (!action.startsWith('dom-')) return false;
  const ui = ctx.ui();
  const du = domUi(ui);
  const g0 = ctx.game();
  if (action === 'dom-new') {
    ctx.reset(newGame(g0.seed, data.on === '1'));
    ctx.toast(data.on === '1' ? `내정 켠 새 판: 시드 ${g0.seed}.` : `내정 끈 새 판: 시드 ${g0.seed}.`);
    return true;
  }
  if (!g0.dom) return true;
  const d0 = g0.dom;
  let why: string | null = null;
  switch (action) {
    case 'dom-tab':
      ui.panel = 'dom';
      ui.carPop = null;
      du.tab = (data.tab as DomUi['tab']) ?? 'plan';
      if (du.tab === 'move') du.order = [...d0.cars];
      break;
    case 'dom-node':
      du.node = du.node === data.id ? null : data.id ?? null;
      break;
    case 'dom-mats':
      du.mats = !du.mats;
      break;
    case 'dom-restore': {
      const id = data.id as TechId;
      ctx.act(next => { if (!startRestore(next, id, data.mode === 'defect' ? 'defect' : 'full', (data.variant || undefined) as Variant | undefined)) why = '지금은 시작할 수 없다'; });
      break;
    }
    case 'dom-cancel':
      ctx.act(next => cancelRestore(next));
      break;
    case 'dom-finish':
      ctx.act(next => { if (!startFinish(next, data.id as TechId)) why = '지금은 고칠 수 없다'; });
      break;
    case 'dom-restart':
      ctx.act(next => restartTech(next, data.id as TechId));
      break;
    case 'dom-order':
      ctx.act(next => moveTask(next, data.task as Task, data.step === '-1' ? -1 : 1));
      break;
    case 'dom-delegate':
      ctx.act(next => { if (!setDelegate(next, data.on === '1', data.policy as 'ours' | 'neutral' | undefined)) why = delegateStatus(next).why ?? '맡길 수 없다'; });
      break;
    case 'dom-apprentice':
      ctx.act(next => { why = requestApprentice(next, data.field as Field) ? '견습생 후보 서류가 쌓였다.' : '가르칠 사람이 없거나 서류가 이미 있다.'; });
      break;
    case 'dom-manual':
      ctx.act(next => { why = requestManual(next, data.field as Field) ? '매뉴얼 요청 서류가 쌓였다.' : '써 줄 사람이 없거나 서류가 이미 있다.'; });
      break;
    case 'dom-hot':
      ctx.act(next => setHotWater(next, Number(data.value)));
      break;
    case 'dom-full':
      ctx.act(next => setFullRule(next, data.rule as 'parts' | 'dump' | 'aisle'));
      break;
    case 'dom-job':
      ctx.act(next => { if (!startJob(next, data.kind as ModKind, data.car ?? '')) why = '개조를 올릴 수 없다'; });
      break;
    case 'dom-escort':
      ctx.act(next => setEscort(next, data.id || null));
      break;
    case 'dom-bury':
      ctx.act(next => setBury(next, data.on === '1'));
      break;
    case 'dom-move': {
      const order = du.order && du.order.length === d0.cars.length ? [...du.order] : [...d0.cars];
      const i = order.indexOf(data.car ?? '');
      const j = i + (data.step === '-1' ? -1 : 1);
      if (i >= 0 && j >= 0 && j < order.length) [order[i], order[j]] = [order[j], order[i]];
      du.order = order;
      break;
    }
    case 'dom-move-reset':
      du.order = [...d0.cars];
      break;
    case 'dom-move-apply': {
      const order = du.order ?? [...d0.cars];
      ctx.act(next => { if (!applyMove(next, order)) why = '입환할 수 없다'; });
      if (!why) { ui.panel = null; du.order = null; ui.cardOpen = true; }
      break;
    }
    default:
      return true;
  }
  if (why) ctx.toast(why);
  ctx.render();
  return true;
}

/** 내정 레버(data-input="dom"). */
export function changeDomestic(el: HTMLInputElement, ctx: DomCtx): boolean {
  if (el.dataset.input !== 'dom') return false;
  const g = ctx.game();
  if (!g.dom) return true;
  const v = Number(el.value);
  if (el.dataset.which === 'target' && g.dom.target !== v) ctx.act(next => setTarget(next, v));
  else if (el.dataset.which === 'hot' && g.dom.hotWater !== v) {
    ctx.act(next => setHotWater(next, v));
    if (v < hotWaterFloor(g)) ctx.toast('법으로 드물게 아래로 못 내린다.');
  }
  return true;
}
