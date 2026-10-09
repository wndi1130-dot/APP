import { openConditions, autoLeverStatus, cloneGame, currentAgenda, platformNote, viewCard } from '../game';
import type { Comm, Game } from '../game';
import { cx, h, s } from './dom';
import { FX_MS, buzz, fxDiff, fxSnap, setVibrate, vibrateOn } from './fx';
import { fxPlay } from './fxplay';
import { departInput, platformSheet, setDepartTap, departTapOn } from './depart';
import type { Fx } from './fx';
import { GROUPS, type Panel, type Screen, type Ui, type View } from './common';
import { bottomBar, topBar } from './hud';
import { homeScreen, stackCount } from './home';
import { overviewScreen } from './overview';
import { councilScreen, voteLever } from './council';
import { countSchedule, noiseStage } from './count_pace';
import { cardSheet } from './card';
import { debugOverlay, endScreen, overlay } from './panels';
import { beginNames, endNames, personCard, shortText } from './names';
// S1c 내정 훅(ui/domestic.ts): ?s1c=1로 켠 판, 내정 단추와 레버, H6 재기.
import { changeDomestic, h6Input, h6Render, h6Visibility, handleDomestic, newGame, urlWantsS1c } from './domestic';
import type { DomCtx, H6Clock } from './domestic';
// S1b 어두운 길 훅(ui/dark.ts): ?s1b=1로 켠 판, 메뉴 단추, H7 고르기 시간.
import { darkPickMs, darkPickReset, darkVisibility, urlWantsS1b } from './dark';
import { showCrash } from './crash';
import { CONFIRM_MS, confirmed, replacesToast, toastMs } from './notice';
import type { ToastKind } from './notice';
import { TRAIL_MAX, applyStep, makeBundle, plainData, readSave, reviveSave, reproText, setReproSource } from './repro';
import type { ReproError, SaveRead, Step, TrailEntry } from './repro';

// 화면 조립과 입력. 상태가 바뀌면 통째로 다시 그리고, 스크롤 위치와 연결선은 그린 뒤에 되살린다.
// 저장은 한 칸이고 행동마다 저절로 한다(되돌리기 없음, S1 기획서 2장).

const SAVE_KEY = 's1a.game.v2';
// 오류 재현 묶음(repro.ts): 최근 행동, 직전 저장, 마지막 오류. 다시 열어도 남게 따로 저장한다.
const REPRO_KEY = 's1a.repro.v1';

// 못 읽은 저장은 지우지 않고 이 칸에 옮겨 둔다(새 판이 덮어쓰기 전에). 오류 재현 때 꺼내 본다.
const BROKEN_KEY = 's1a.game.broken';

/** 저장한 판을 읽는다. 못 읽었으면 옛 저장을 따로 남기고 까닭을 돌려준다(시작 화면 알림). */
function load(): { g: Game | null; why: string | null } {
  let raw: string | null | undefined;
  try {
    raw = globalThis.localStorage?.getItem(SAVE_KEY);
  } catch {
    return { g: null, why: '이 창에선 저장 칸을 읽을 수 없다' };
  }
  if (!raw) return { g: null, why: null };
  let r: SaveRead;
  try {
    r = readSave(JSON.parse(raw));
  } catch {
    r = { ok: false, why: '저장 글이 깨졌다' };
  }
  if (r.ok) return { g: r.g, why: null };
  try {
    globalThis.localStorage?.setItem(BROKEN_KEY, raw);
    return { g: null, why: `${r.why}. 옛 저장은 따로 남겨 두었다` };
  } catch {
    // 옮겨 둘 자리가 없으면 그냥 둔다. 새 판이 저장할 때 덮인다.
    return { g: null, why: r.why };
  }
}

/** 저장한다. 실패하면 false(저장 칸이 찼거나 막힌 창). 판은 그래도 이어진다. */
function save(g: Game): boolean {
  try {
    globalThis.localStorage?.setItem(SAVE_KEY, JSON.stringify(g));
    return true;
  } catch {
    return false;
  }
}

interface Repro { seed: string; trail: TrailEntry[]; prev: Game | null; error: ReproError | null }

function loadRepro(seed: string): Repro {
  try {
    const raw = globalThis.localStorage?.getItem(REPRO_KEY);
    const r = raw ? JSON.parse(raw) as Repro : null;
    if (r && r.seed === seed && Array.isArray(r.trail)) return { seed, trail: r.trail, prev: reviveSave(r.prev), error: r.error ?? null };
  } catch {
    // 못 읽으면 새로 모은다.
  }
  return { seed, trail: [], prev: null, error: null };
}

function saveRepro(r: Repro): void {
  try {
    globalThis.localStorage?.setItem(REPRO_KEY, JSON.stringify(r));
  } catch {
    // 저장 칸이 모자라도 판은 이어진다.
  }
}

function errorOf(e: unknown, step?: Step): ReproError {
  const err = e instanceof Error ? e : new Error(String(e));
  return { msg: err.message, stack: err.stack?.split('\n').slice(0, 12).join('\n'), step, t: Date.now() };
}

function randomSeed(): string {
  try {
    const bytes = new Uint32Array(1);
    globalThis.crypto.getRandomValues(bytes);
    return `s${bytes[0].toString(36)}`;
  } catch {
    return `s${Date.now().toString(36)}`;
  }
}

function freshUi(): Ui {
  return {
    screen: 'home', panel: null, carPop: null, cardOpen: false, stopSeen: false, overviewSel: 'tail', numbersOnly: false,
    selComm: null, dealOpen: null, cutPick: null, count: null, toast: null, debug: false, person: null, braking: false,
  };
}

const ANIMATED = '.sheet, .side, .drop, .person, .verdict, .toast, .fx, .scout-report';

function animKey(el: HTMLElement): string {
  return el.dataset.anim || `${el.className.replace(/\bis-still\b/, '').trim()}|${el.getAttribute('aria-label') ?? ''}|${el.classList.contains('toast') ? el.textContent : ''}`;
}

/** 칸 창이 위 막대 밑으로 들어가지 않게 그만큼 아래로 민다(키 작은 폰, 까닭 줄이 붙은 칸 창). */
function keepPopInside(root: HTMLElement): void {
  const pop = root.querySelector<HTMLElement>('.carpop');
  const top = root.querySelector<HTMLElement>('header.top');
  if (!pop || !top) return;
  const over = top.getBoundingClientRect().bottom + 4 - pop.getBoundingClientRect().top;
  if (over > 0) pop.style.setProperty('--pop-dy', `${Math.ceil(over)}px`);
}

export function renderApp(view: View): HTMLElement {
  const { g, ui } = view;
  const screen = g.phase === 'end' ? 'end' : ui.screen;
  let main: HTMLElement;
  if (screen === 'end') main = endScreen(view);
  else if (screen === 'council') main = councilScreen(view);
  else if (screen === 'overview') main = overviewScreen(view);
  else main = homeScreen(view);
  const sheet = (screen === 'home' || screen === 'overview') && !ui.braking ? cardSheet(view) : null;
  const panel = overlay(view);
  return h('div', { class: cx('app', `app--${screen}`, sheet && 'has-sheet') },
    topBar(view),
    h('main', { class: 'main' }, main, sheet),
    screen === 'end' ? null : bottomBar(view),
    screen === 'council' ? voteLever(view) : null,
    panel ? h('div', { class: 'scrim', 'data-action': 'panel', 'data-panel': '' }) : null,
    panel,
    ui.person ? h('div', { class: 'scrim scrim--person', 'data-action': 'person', 'data-name': '' }) : null,
    ui.person ? personCard(g, ui.person) : null,
    debugOverlay(view),
    platformSheet(view),
    ui.toast ? toastEl(ui.toast, ui.toastKind ?? 'info') : null,
    s('svg', { class: 'links', 'aria-hidden': 'true' }));
}

/** 알림 쪽지. 경고는 호박색이고 눌러 닫는다(notice.ts). */
function toastEl(text: string, kind: ToastKind): HTMLElement {
  return kind === 'warn'
    ? h('div', { class: 'toast toast--warn', role: 'alert', 'data-action': 'toast-close' }, shortText(text))
    : h('div', { class: 'toast', role: 'status' }, shortText(text));
}

/** 고른 것(data-link="from")과 창(data-link="to")을 선으로 잇는다. */
function drawLinks(root: HTMLElement): void {
  const svg = root.querySelector<SVGSVGElement>('svg.links');
  const app = root.querySelector<HTMLElement>('.app');
  if (!svg || !app) return;
  svg.replaceChildren();
  const from = app.querySelector('[data-link="from"]');
  const to = app.querySelector('[data-link="to"]');
  if (!from || !to) return;
  const base = app.getBoundingClientRect();
  const a = from.getBoundingClientRect();
  const b = to.getBoundingClientRect();
  if (a.width === 0 || b.width === 0) return;
  svg.setAttribute('viewBox', `0 0 ${base.width} ${base.height}`);
  let x1 = a.right - base.left;
  let y1 = a.top + a.height / 2 - base.top;
  let d: string;
  const hemi = from.closest('svg.hemi');
  if (hemi) {
    // 의회 명판에서는 의석을 가로지르지 않게 반원 위쪽 길로 돌아 창에 닿는다.
    const main = app.querySelector('.main')?.getBoundingClientRect();
    const lane = Math.max((main ? main.top : a.top) - base.top + 3, Math.min(a.top, hemi.getBoundingClientRect().top) - base.top - 2);
    x1 = a.left + a.width / 2 - base.left;
    y1 = a.top - base.top;
    const x2 = b.left - base.left;
    const y2 = Math.max(lane, b.top - base.top + 20);
    d = `M${x1} ${y1} L${x1} ${lane} L${x2 - 10} ${lane} L${x2 - 10} ${y2} L${x2} ${y2}`;
    svg.append(s('path', { d, class: 'links__path' }), s('circle', { cx: x2, cy: y2, r: 3, class: 'links__dot' }), s('circle', { cx: x1, cy: y1, r: 3, class: 'links__dot' }));
    return;
  }
  const x2 = b.left - base.left;
  const y2 = Math.min(Math.max(y1, b.top - base.top + 16), b.bottom - base.top - 16);
  const mx = (x1 + x2) / 2;
  d = `M${x1} ${y1} L${mx} ${y1} L${mx} ${y2} L${x2} ${y2}`;
  svg.append(
    s('path', { d, class: 'links__path' }),
    s('circle', { cx: x1, cy: y1, r: 3, class: 'links__dot' }),
    s('circle', { cx: x2, cy: y2, r: 3, class: 'links__dot' }));
}

/** 다시 그린 뒤 같은 단추를 찾는 열쇠: 동작과 data 값들(못 누름 흔들기용) */
function deniedKey(el: HTMLElement): string {
  return el.dataset.action ? JSON.stringify(Object.entries(el.dataset).sort()) : '';
}

export function startApp(root: HTMLElement): void {
  // 주소에 ?seed=가 있으면 그 시드로 시작한다(같은 판을 다시 볼 때, 스크린샷).
  const urlSeed = new URLSearchParams(globalThis.location?.search ?? '').get('seed');
  const { g: saved, why: loadWhy } = load();
  const wantS1c = urlWantsS1c(); // S1c 내정 훅
  const wantS1b = urlWantsS1b(); // S1b 어두운 길 훅
  let g: Game = saved && (!urlSeed || saved.seed === urlSeed) && (!wantS1c || saved.dom) && (!wantS1b || saved.dark)
    ? saved : newGame(urlSeed || randomSeed(), wantS1c, wantS1b);
  let ui: Ui = freshUi();
  if (g.phase === 'council') ui.screen = 'council';
  const scroll: Record<string, number> = {};
  let toastTimer: ReturnType<typeof setTimeout> | undefined;
  let countTimer: ReturnType<typeof setTimeout> | undefined;
  let focusCar: string | null = null;
  const h6: H6Clock = { since: 0, seg: null }; // S1c 내정 훅: 내정 시간 재기
  document.addEventListener('visibilitychange', () => {
    h6Visibility(g, h6, Date.now(), document.hidden); // 뒤로 간 시간은 빼고 잰다
    darkVisibility(performance.now(), document.hidden); // S1b H7 망설임도 같다
  });
  let repro = loadRepro(g.seed);
  setReproSource(() => makeBundle(g, repro.prev, repro.trail, repro.error, ui.screen), () => repro.error);

  // 행동 밖에서 난 오류(그리기, 타이머)도 재현 묶음에 남긴다. 그리기가 깨졌을 수 있으니 여기서 다시 그리지는 않는다.
  function noteError(e: unknown): void {
    repro.error = errorOf(e, repro.trail[repro.trail.length - 1]);
    saveRepro(repro);
  }

  function render(): void {
    try {
      draw();
    } catch (e) {
      // 화면을 못 그렸다. 판은 그대로 두고 오류를 남긴 뒤 전체 화면 안내(다시 그리다 또 던져도 안내만 다시 뜬다).
      noteError(e);
      showCrash(root, 'render', { onRetry: render, onNew: () => { newSeedGame(); render(); } });
    }
  }

  function draw(): void {
    for (const el of root.querySelectorAll<HTMLElement>('[data-keep-scroll]')) scroll[el.dataset.keepScroll ?? ''] = el.scrollLeft || el.scrollTop;
    beginNames();
    let view = renderApp({ g, ui });
    if (endNames()) {
      // 같은 이름이 새로 겹치거나 풀렸다. 성 첫 글자를 붙이거나 떼서 다시 그린다.
      beginNames();
      view = renderApp({ g, ui });
      endNames();
    }
    // 이미 떠 있던 창(서류, 옆 창, 알림)은 다시 그려도 미끄러져 들어오지 않는다. 누를 때마다 튀는 것을 막는다.
    const shown = new Set([...root.querySelectorAll<HTMLElement>(ANIMATED)].map(animKey));
    for (const el of view.querySelectorAll<HTMLElement>(ANIMATED)) if (shown.has(animKey(el))) el.classList.add('is-still');
    root.replaceChildren(view);
    keepPopInside(root);
    for (const el of root.querySelectorAll<HTMLElement>('[data-keep-scroll]')) {
      const key = el.dataset.keepScroll ?? '';
      if (scroll[key] === undefined) continue;
      if (el.scrollWidth > el.clientWidth) el.scrollLeft = scroll[key];
      else el.scrollTop = scroll[key];
    }
    if (focusCar) {
      const scroller = root.querySelector<HTMLElement>('.scroller');
      const car = root.querySelector<HTMLElement>(`[data-slot="${focusCar}"]`);
      if (scroller && car) {
        // 카드가 왼쪽 절반을 덮으니 관련 칸을 오른쪽 절반 가운데로 보낸다.
        const target = car.offsetLeft - scroller.clientWidth * 0.62 + car.offsetWidth / 2;
        scroller.scrollTo({ left: Math.max(0, target), behavior: 'smooth' });
      }
      focusCar = null;
    }
    fxPlay(root, ui.fx, fxOrigin); // 꼬리표가 고른 선택지에서 위 막대 칸으로 날아가고 숫자가 센다(5b.6)
    h6Render(g, ui, h6, Date.now()); // S1c 내정 훅
    requestAnimationFrame(() => drawLinks(root));
  }

  let fxTimer: ReturnType<typeof setTimeout> | undefined;
  /** 방금 누른 선택지의 자리: 꼬리표가 여기서 날아간다 */
  let fxOrigin: DOMRect | null = null;
  /** 선택이 바꾼 수치를 위 막대에 띄운다(fx.ts). 크게 나쁘면 폰이 한 번 떨린다. */
  function showFx(fx: Fx | null): void {
    ui.fx = fx;
    clearTimeout(fxTimer);
    if (!fx) return;
    // 진동은 나쁜 쪽 선 넘음과 죽음에만(5b.6). 동작 감소 설정이 아니라 메뉴의 '진동'을 따른다.
    if (fx.buzz) buzz(Date.now());
    fxTimer = setTimeout(() => { ui.fx = null; render(); }, FX_MS);
  }

  function toast(text: string, kind: ToastKind = 'info', ms = toastMs(kind)): void {
    // 떠 있는 경고는 보통 알림이 덮지 않는다.
    if (!replacesToast(ui.toast ? ui.toastKind ?? 'info' : null, kind)) return;
    ui.toast = text;
    ui.toastKind = kind;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { ui.toast = null; ui.toastKind = null; render(); }, ms);
  }

  /** 판을 버리는 메뉴 동작은 판이 끝나기 전엔 두 번 눌러야 한다(3초 안). 실행해도 되면 true. */
  function confirmDiscard(action: string): boolean {
    if (g.phase === 'end') return true;
    const now = Date.now();
    if (confirmed(ui.confirm, action, now)) { ui.confirm = null; ui.toast = null; ui.toastKind = null; return true; }
    ui.confirm = { action, t: now };
    // 경고 쪽지로 띄워 다른 경고에 묻히지 않게 하고, 확정 시간만큼만 둔다.
    toast('한 번 더 누르면 지금 판을 버린다.', 'warn', CONFIRM_MS);
    render();
    return false;
  }

  /** 새 시드로 새 판을 연다(저장, 재현 묶음 초기화 포함). 그리지는 않는다. */
  function newSeedGame(): void {
    g = newGame(randomSeed(), !!g.dom, !!g.dark);
    ui = freshUi();
    persist(g);
    resetRepro();
  }

  let saveFailing = false;
  /** 저장하고, 막 실패하기 시작했으면 한 번 알린다(다시 되면 조용히 풀린다). */
  function persist(next: Game): void {
    const ok = save(next);
    if (!ok && !saveFailing) toast('저장하지 못했다. 판은 이어지지만 창을 닫으면 여기까지 잃는다.', 'warn');
    saveFailing = !ok;
  }

  /** 판을 바꾸는 행동(repro.ts applyStep). 사본에 하고, 저장하고, 다시 그린다. 알림 글이 있으면 돌려준다.
   *  행동과 직전 판을 재현 묶음에 남긴다. 행동이 던지면 판은 그대로 두고 오류를 남긴다. */
  function step(st: Step): string | null {
    const before = g;
    const next = cloneGame(g);
    const entry: TrailEntry = { ...st, seg: before.seg, phase: before.phase, t: Date.now() };
    repro.trail = [...repro.trail, entry].slice(-TRAIL_MAX);
    repro.prev = before;
    let text: string | null;
    try {
      text = applyStep(next, st);
    } catch (e) {
      repro.error = errorOf(e, st);
      saveRepro(repro);
      toast('이 행동은 먹히지 않았다. 판은 그 앞에서 멈춰 있다. 메뉴에서 오류 묶음을 복사해 보내 줘.', 'warn');
      render();
      return null;
    }
    g = next;
    persist(g);
    saveRepro(repro);
    afterChange();
    render();
    return text;
  }

  function resetRepro(): void {
    repro = { seed: g.seed, trail: [], prev: null, error: null };
    saveRepro(repro);
    // 새 판이면 내정 시간도 처음부터 잰다(지난 판의 시간이 새 판 구간에 붙지 않게).
    Object.assign(h6, { since: 0, seg: null, allSince: 0, allSeg: undefined });
    darkPickReset(); // S1b H7: 지난 판 카드의 처음 본 시각도 지운다
  }

  function afterChange(): void {
    if (g.phase === 'council' && ui.screen !== 'council' && g.council && !g.council.result) ui.screen = 'council';
    if (g.phase === 'end') { ui.panel = null; ui.cardOpen = false; }
    if (stackCount(g, ui) === 0) ui.cardOpen = false;
  }

  function focusForTopCard(): void {
    const card = g.cards[0];
    if (!card) return;
    const focus = viewCard(g, card).focus;
    if (focus) focusCar = focus === 'tail' ? 'tail1' : focus;
  }

  function openStack(): void {
    if (stackCount(g, ui) === 0) return;
    ui.cardOpen = true;
    ui.panel = null;
    ui.carPop = null;
    if (ui.screen !== 'home' && ui.screen !== 'overview') ui.screen = 'home';
    focusForTopCard();
  }

  function startCount(): void {
    const result = g.council?.result;
    clearTimeout(countTimer);
    if (!result || result.flips.length === 0 || matchMedia('(prefers-reduced-motion: reduce)').matches) { ui.count = null; return; }
    // 찬성·반대가 먼저 앉고 미정이 하나씩 갈린다. 아직 뒤집힐 수 있는 마지막 몇 표는 느리게, 정해지면 남은 돌을 한꺼번에(count_pace.ts).
    const plan = countSchedule(result, noiseStage(g.tension), g.session);
    ui.count = 0;
    const next = (i: number) => {
      if (i >= plan.length) return;
      countTimer = setTimeout(() => {
        if (ui.count === null) return;
        const shown = plan[i][1];
        ui.count = shown >= result.flips.length ? null : shown;
        render();
        next(i + 1);
      }, plan[i][0]);
    };
    next(0);
  }

  function handle(action: string, data: DOMStringMap): void {
    switch (action) {
      case 'advance': {
        const wasSettle = g.phase === 'settle';
        // 정기 신임 표결 뒤 '다음 안건': 개표 중이었으면 멈추고 이번 회기 안건으로 넘어간다.
        if (g.phase === 'council') { ui.count = null; clearTimeout(countTimer); }
        step({ a: 'advance', d: {} });
        if (g.phase === 'settle' && !wasSettle) { ui.panel = 'settle'; ui.screen = 'home'; ui.selComm = null; ui.dealOpen = null; }
        if (g.phase === 'stop' && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
          // 정차: 브레이크 소리와 함께 열차가 서고 나서 정차 서류가 펼쳐진다(나중엔 정차 장면으로 넘어가는 자리).
          ui.stopSeen = false;
          ui.screen = 'home';
          ui.cardOpen = false;
          ui.braking = true;
          setTimeout(() => { ui.braking = false; if (stackCount(g, ui) > 0) openStack(); render(); }, 1100);
          return render();
        }
        if (g.phase === 'travel' || g.phase === 'stop') { ui.stopSeen = false; if (stackCount(g, ui) > 0) openStack(); }
        if (g.phase === 'prep') ui.panel = null;
        if (g.phase === 'council') { ui.screen = 'council'; ui.selComm = null; }
        return render();
      }
      case 'depart-pull':
        // 레버가 걸렸다. 승강장에 사람이 남았으면 기적 전에 쪽지로 한 번 더 묻는다(5b.5).
        if (platformNote(g)) { ui.departAsk = 'ask'; ui.panel = null; ui.cardOpen = false; return render(); }
        return handle('advance', {});
      case 'depart-wait':
        ui.departAsk = null;
        toast('기다린다. 기적은 울리지 않았다.');
        return render();
      case 'depart-leave': {
        if (ui.departAsk !== 'ask') return;
        // 낮은 타격(쪽지가 한 번 눌림), 굵은 펜 획으로 이름을 긋고, 진동 한 번. 그다음에 기적.
        ui.departAsk = 'leaving';
        buzz(Date.now());
        render();
        const ms = matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 900;
        setTimeout(() => {
          ui.departAsk = null;
          handle('advance', {});
          toast('기적이 운다.');
          render();
        }, ms);
        return;
      }
      case 'toggle-depart-tap':
        setDepartTap(!departTapOn());
        toast(departTapOn() ? '출발 레버를 두 번 눌러 출발한다.' : '출발 레버를 아래로 당겨 내려 출발한다.');
        return render();
      case 'emergency':
        step({ a: 'emergency', d: {} });
        if (g.phase === 'council') { ui.screen = 'council'; ui.selComm = null; ui.panel = null; }
        return render();
      case 'person':
        ui.person = data.name || null;
        return render();
      case 'open-stack':
        openStack();
        return render();
      case 'fold':
        ui.cardOpen = false;
        return render();
      case 'choose': {
        const before = fxSnap(g);
        const kind = g.cards.find(x => x.uid === Number(data.uid))?.kind;
        const ms = darkPickMs(g, Number(data.uid)); // S1b H7: 고르기까지 걸린 시간
        step({ a: 'choose', d: { ...plainData(data), ...(ms ? { ms } : {}) } });
        showFx(fxDiff(before, g));
        if (stackCount(g, ui) > 0) focusForTopCard();
        // 서막 첫 거래를 들어주면 꼬리칸 창을 열어 막 당긴 레버를 보인다(first_leg_story 5장 6번 '레버를 처음 당긴다').
        else if (kind === 'pro_deal' && data.index === '0') { ui.carPop = 'tail1'; ui.spaceOpen = false; focusCar = 'tail1'; }
        return render();
      }
      case 'stop-set':
      case 'stop-go':
        step({ a: action, d: plainData(data) });
        return;
      case 'stop-seen':
        ui.stopSeen = true;
        if (stackCount(g, ui) === 0) ui.cardOpen = false; else focusForTopCard();
        return render();
      case 'car': {
        const id = data.car ?? null;
        ui.carPop = ui.carPop === id ? null : id;
        ui.panel = null;
        ui.spaceOpen = false;
        return render();
      }
      case 'space-tab':
        ui.spaceOpen = !ui.spaceOpen;
        return render();
      case 'go': {
        const screen = (data.screen ?? 'home') as Screen;
        ui.screen = screen;
        ui.carPop = null;
        ui.panel = null;
        if (screen === 'overview' && !GROUPS.some(x => x.id === ui.overviewSel)) ui.overviewSel = 'tail';
        return render();
      }
      case 'panel': {
        const panel = (data.panel || null) as Panel;
        ui.panel = ui.panel === panel ? null : panel;
        ui.carPop = null;
        return render();
      }
      case 'ov-sel':
        ui.overviewSel = data.group ?? 'tail';
        if (data.numbersOff) ui.numbersOnly = false;
        return render();
      case 'numbers':
        ui.numbersOnly = !ui.numbersOnly;
        return render();
      case 'auto-levers':
        step({ a: 'auto-levers', d: {} });
        if (!g.autoLevers && autoLeverStatus(g).why) { toast(autoLeverStatus(g).why!); return render(); }
        toast(g.autoLevers ? '배급장에게 맡겼다. 출발 전마다 레버를 움직인다.' : '레버를 직접 잡는다.');
        return render();
      case 'sel-comm':
        ui.selComm = (data.comm || null) as Comm | null;
        ui.dealOpen = null;
        ui.cutPick = null;
        return render();
      case 'agenda':
        if (!g.council) return;
        step({ a: 'agenda', d: plainData(data) });
        return;
      case 'deal': {
        const c = data.comm as Comm;
        const tool = data.tool;
        if (tool === 'open') { ui.dealOpen = c; ui.cutPick = null; return render(); }
        const text = step({ a: 'deal', d: plainData(data) });
        if (text) toast(text);
        return render();
      }
      case 'deal-cond': {
        const c = data.comm as Comm;
        const index = Number(data.index);
        const isCut = !data.cut && openConditions(g, c)[index]?.kind === 'cut';
        if (isCut) { ui.cutPick = index; return render(); }
        const text = step({ a: 'deal-cond', d: plainData(data) });
        ui.dealOpen = null;
        ui.cutPick = null;
        if (text) toast(text);
        return render();
      }
      case 'deal-close':
        ui.dealOpen = null;
        ui.cutPick = null;
        return render();
      case 'vote':
      case 'decree':
        if (!currentAgenda(g)) return;
        step({ a: action, d: {} });
        ui.selComm = null;
        ui.dealOpen = null;
        startCount();
        return render();
      case 'skip-count':
        ui.count = null;
        clearTimeout(countTimer);
        return render();
      case 'space': {
        const before = fxSnap(g);
        const why = step({ a: 'space', d: plainData(data) });
        if (why) toast(why); else showFx(fxDiff(before, g));
        return render();
      }
      case 'comm-act': {
        const why = step({ a: 'comm-act', d: plainData(data) });
        if (why) toast(why);
        return render();
      }
      case 'toast-close':
        clearTimeout(toastTimer);
        ui.toast = null;
        ui.toastKind = null;
        return render();
      case 'restart':
        if (!confirmDiscard(action)) return;
        g = newGame(g.seed, !!g.dom, !!g.dark);
        ui = freshUi();
        persist(g);
        resetRepro();
        toast(`같은 시드(${g.seed})로 처음부터.`);
        return render();
      case 'new-seed':
        if (!confirmDiscard(action)) return;
        newSeedGame();
        toast(`새 판: 시드 ${g.seed}.`);
        return render();
      case 'fullscreen': {
        // 폰 가로에서 아티팩트 창 테두리 때문에 화면이 덜 차는 것을 막는다. 창이 막으면 알려 준다.
        ui.panel = null;
        const blocked = () => { toast('이 창에선 전체 화면이 막혀 있다.'); render(); };
        const el = document.documentElement;
        if (document.fullscreenElement) document.exitFullscreen().then(render, render);
        else if (typeof el.requestFullscreen === 'function') el.requestFullscreen({ navigationUI: 'hide' }).then(render, blocked);
        else blocked();
        return render();
      }
      case 'repro-copy': {
        // 아티팩트 창이 클립보드를 막을 수 있다. 막히면 펼치는 칸으로 안내한다.
        const text = reproText();
        const blocked = () => { toast('복사가 막혔다. 아래 칸을 펼쳐 길게 눌러 복사해 줘.'); render(); };
        const clip = globalThis.navigator?.clipboard;
        if (clip?.writeText) clip.writeText(text).then(() => { toast(`복사했다(${Math.round(text.length / 1000)}KB). 채팅에 붙여 보내 줘.`); render(); }, blocked);
        else blocked();
        return;
      }
      case 'toggle-vibrate':
        setVibrate(!vibrateOn());
        toast(vibrateOn() ? '진동을 켰다. 나쁜 쪽으로 선을 넘거나 사람이 죽을 때만 짧게 떤다.' : '진동을 껐다.');
        return render();
      case 'toggle-debug':
        ui.debug = !ui.debug;
        ui.panel = null;
        return render();
      case 'dark-new': // S1b 어두운 길 훅: 켠(끈) 새 판, 내정 켬/끔은 그대로
        g = newGame(g.seed, !!g.dom, data.on === '1');
        ui = freshUi();
        persist(g);
        resetRepro();
        toast(data.on === '1' ? `어두운 길 켠 새 판: 시드 ${g.seed}.` : `어두운 길 끈 새 판: 시드 ${g.seed}.`);
        return render();
      default:
        handleDomestic(action, data, domCtx); // S1c 내정 훅
        return;
    }
  }

  const domCtx: DomCtx = {
    game: () => g, ui: () => ui, step, toast, render,
    reset(next) { g = next; ui = freshUi(); persist(g); resetRepro(); },
  };

  const lever = departInput(root, () => handle('depart-pull', {}), text => { toast(text); render(); });
  root.addEventListener('click', event => {
    const target = (event.target as Element | null)?.closest<HTMLElement | SVGElement>('[data-action]');
    if (!target || !root.contains(target)) return;
    if (ui.braking) return; // 브레이크 연출(1.1초)이 도는 동안은 받지 않는다(타이머가 풀어 준다)
    if ((target as HTMLButtonElement).disabled) return;
    if (target.dataset.action === 'depart') return lever.click(event);
    if (target.dataset.action === 'choose') fxOrigin = target.getBoundingClientRect();
    h6Input(g, h6, Date.now(), target.dataset.action ?? ''); // S1c 내정 훅
    handle(target.dataset.action ?? '', target.dataset);
  });

  // 못 누름(ui_states.md P3): 막힌 단추는 click이 오지 않아 손을 뗄 때(pointerup) 받는다. 이유(title)를 쪽지로 띄우고
  // 단추를 한 번 흔든다. 끌다 뗀 것(스크롤)은 무시한다. pointerup을 막힌 단추에 보내지 않는 브라우저에선 지금처럼 조용하다.
  let downAt: { x: number; y: number } | null = null;
  root.addEventListener('pointerdown', event => { downAt = { x: event.clientX, y: event.clientY }; });
  root.addEventListener('pointerup', event => {
    const btn = (event.target as Element | null)?.closest<HTMLButtonElement>('button:disabled');
    const moved = !downAt || Math.hypot(event.clientX - downAt.x, event.clientY - downAt.y) > 10;
    downAt = null;
    if (!btn || !root.contains(btn) || moved || ui.braking) return;
    const why = btn.title.trim();
    const key = deniedKey(btn);
    if (why) toast(why);
    render();
    const again = key ? [...root.querySelectorAll<HTMLButtonElement>('button:disabled')].find(b => deniedKey(b) === key) : null;
    again?.classList.add('is-denied');
  });

  // 끌던 중에 다시 그리면 손잡이를 놓치므로 손을 뗐을 때(change) 반영한다.
  root.addEventListener('change', event => {
    const el = event.target as HTMLInputElement;
    if (el.dataset.input) h6Input(g, h6, Date.now(), 'lever'); // S1c 내정 훅
    if (changeDomestic(el, domCtx)) return;
    if (el.dataset.input !== 'lever') return;
    const c = el.dataset.comm as Comm;
    const which = el.dataset.which as 'heat' | 'ration';
    const value = Number(el.value);
    if (g.comms[c][which] === value) return;
    step({ a: 'lever', d: { comm: c, which, value: String(value) } });
  });

  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (ui.departAsk === 'ask') ui.departAsk = null; // 출발 확인 쪽지: 닫으면 기다린다
    else if (ui.person) ui.person = null;
    else if (ui.panel) ui.panel = null;
    else if (ui.cardOpen) ui.cardOpen = false;
    else if (ui.carPop) ui.carPop = null;
    else if (ui.screen !== 'home' && g.phase !== 'council') ui.screen = 'home';
    render();
  });

  window.addEventListener('error', event => noteError(event.error ?? event.message));
  window.addEventListener('unhandledrejection', event => noteError(event.reason));
  window.addEventListener('resize', () => drawLinks(root));
  if (loadWhy) toast(`저장한 판을 못 읽어 새 판을 열었다: ${loadWhy}.`, 'warn');
  render();
}
