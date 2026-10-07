import { openConditions, autoLeverStatus, cloneGame, currentAgenda, viewCard } from '../game';
import type { Comm, Game } from '../game';
import { cx, h, s } from './dom';
import { FX_MS, fxDiff, fxSnap } from './fx';
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
import { changeDomestic, h6Input, h6Render, handleDomestic, newGame, urlWantsS1c } from './domestic';
import type { DomCtx, H6Clock } from './domestic';
import { TRAIL_MAX, applyStep, makeBundle, plainData, reviveSave, reproText, setReproSource } from './repro';
import type { ReproError, Step, TrailEntry } from './repro';

// 화면 조립과 입력. 상태가 바뀌면 통째로 다시 그리고, 스크롤 위치와 연결선은 그린 뒤에 되살린다.
// 저장은 한 칸이고 행동마다 저절로 한다(되돌리기 없음, S1 기획서 2장).

const SAVE_KEY = 's1a.game.v2';
// 오류 재현 묶음(repro.ts): 최근 행동, 직전 저장, 마지막 오류. 다시 열어도 남게 따로 저장한다.
const REPRO_KEY = 's1a.repro.v1';

function load(): Game | null {
  try {
    const raw = globalThis.localStorage?.getItem(SAVE_KEY);
    if (!raw) return null;
    // 예전 판에 없던 칸을 채워 저장한 판을 이어 한다.
    return reviveSave(JSON.parse(raw));
  } catch {
    return null;
  }
}

function save(g: Game): void {
  try {
    globalThis.localStorage?.setItem(SAVE_KEY, JSON.stringify(g));
  } catch {
    // 저장할 수 없어도 판은 이어진다.
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
    ui.toast ? h('div', { class: 'toast', role: 'status' }, shortText(ui.toast)) : null,
    s('svg', { class: 'links', 'aria-hidden': 'true' }));
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

export function startApp(root: HTMLElement): void {
  // 주소에 ?seed=가 있으면 그 시드로 시작한다(같은 판을 다시 볼 때, 스크린샷).
  const urlSeed = new URLSearchParams(globalThis.location?.search ?? '').get('seed');
  const saved = load();
  const wantS1c = urlWantsS1c(); // S1c 내정 훅
  let g: Game = saved && (!urlSeed || saved.seed === urlSeed) && (!wantS1c || saved.dom) ? saved : newGame(urlSeed || randomSeed(), wantS1c);
  let ui: Ui = freshUi();
  if (g.phase === 'council') ui.screen = 'council';
  const scroll: Record<string, number> = {};
  let toastTimer: ReturnType<typeof setTimeout> | undefined;
  let countTimer: ReturnType<typeof setTimeout> | undefined;
  let focusCar: string | null = null;
  const h6: H6Clock = { since: 0, seg: null }; // S1c 내정 훅: 내정 시간 재기
  let repro = loadRepro(g.seed);
  setReproSource(() => makeBundle(g, repro.prev, repro.trail, repro.error, ui.screen), () => repro.error);

  function render(): void {
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
    h6Render(g, ui, h6, Date.now()); // S1c 내정 훅
    requestAnimationFrame(() => drawLinks(root));
  }

  let fxTimer: ReturnType<typeof setTimeout> | undefined;
  /** 선택이 바꾼 수치를 위 막대에 띄운다(fx.ts). 크게 나쁘면 폰이 한 번 떨린다. */
  function showFx(fx: Fx | null): void {
    ui.fx = fx;
    clearTimeout(fxTimer);
    if (!fx) return;
    if (fx.hard && !matchMedia('(prefers-reduced-motion: reduce)').matches) navigator.vibrate?.(40);
    fxTimer = setTimeout(() => { ui.fx = null; render(); }, FX_MS);
  }

  function toast(text: string): void {
    ui.toast = text;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { ui.toast = null; render(); }, 2600);
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
      toast('오류가 났다. 메뉴에서 오류 재현 묶음을 복사해 보내 줘.');
      render();
      return null;
    }
    g = next;
    save(g);
    saveRepro(repro);
    afterChange();
    render();
    return text;
  }

  function resetRepro(): void {
    repro = { seed: g.seed, trail: [], prev: null, error: null };
    saveRepro(repro);
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
        step({ a: 'choose', d: plainData(data) });
        showFx(fxDiff(before, g));
        if (stackCount(g, ui) > 0) focusForTopCard();
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
        return render();
      }
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
      case 'comm-act': {
        const why = step({ a: 'comm-act', d: plainData(data) });
        if (why) toast(why);
        return render();
      }
      case 'restart':
        g = newGame(g.seed, !!g.dom);
        ui = freshUi();
        save(g);
        resetRepro();
        toast(`같은 시드(${g.seed})로 처음부터.`);
        return render();
      case 'new-seed':
        g = newGame(randomSeed(), !!g.dom);
        ui = freshUi();
        save(g);
        resetRepro();
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
      case 'toggle-debug':
        ui.debug = !ui.debug;
        ui.panel = null;
        return render();
      default:
        handleDomestic(action, data, domCtx); // S1c 내정 훅
        return;
    }
  }

  const domCtx: DomCtx = {
    game: () => g, ui: () => ui, step, toast, render,
    reset(next) { g = next; ui = freshUi(); save(g); resetRepro(); },
  };

  root.addEventListener('click', event => {
    const target = (event.target as Element | null)?.closest<HTMLElement | SVGElement>('[data-action]');
    if (!target || !root.contains(target)) return;
    if ((target as HTMLButtonElement).disabled) return;
    h6Input(g, h6, Date.now(), target.dataset.action ?? ''); // S1c 내정 훅
    handle(target.dataset.action ?? '', target.dataset);
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
    if (ui.person) ui.person = null;
    else if (ui.panel) ui.panel = null;
    else if (ui.cardOpen) ui.cardOpen = false;
    else if (ui.carPop) ui.carPop = null;
    else if (ui.screen !== 'home' && g.phase !== 'council') ui.screen = 'home';
    render();
  });

  // 행동 밖에서 난 오류(그리기, 타이머)도 재현 묶음에 남긴다. 그리기가 깨졌을 수 있으니 여기서 다시 그리지는 않는다.
  const noteError = (e: unknown) => {
    repro.error = errorOf(e, repro.trail[repro.trail.length - 1]);
    saveRepro(repro);
  };
  window.addEventListener('error', event => noteError(event.error ?? event.message));
  window.addEventListener('unhandledrejection', event => noteError(event.reason));
  window.addEventListener('resize', () => drawLinks(root));
  render();
}
