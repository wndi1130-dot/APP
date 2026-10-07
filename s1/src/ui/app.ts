import {
  openConditions,
  COMMS, advance, castVote, chooseCard, cloneGame, createGame, currentAgenda, cutComm, makeDeal, resolveStop,
  setAgenda, setAutoLevers, setLever, setStop, supportComm, uniqueAction, viewCard,
} from '../game';
import type { Comm, Game, StayId } from '../game';
import { cx, h, s } from './dom';
import { GROUPS, type Panel, type Screen, type Ui, type View } from './common';
import { bottomBar, topBar } from './hud';
import { homeScreen, stackCount } from './home';
import { overviewScreen } from './overview';
import { councilScreen, voteLever } from './council';
import { cardSheet, isLoot } from './card';
import { debugOverlay, endScreen, overlay } from './panels';

// 화면 조립과 입력. 상태가 바뀌면 통째로 다시 그리고, 스크롤 위치와 연결선은 그린 뒤에 되살린다.
// 저장은 한 칸이고 행동마다 저절로 한다(되돌리기 없음, S1 기획서 2장).

const SAVE_KEY = 's1a.game.v2';
const COUNT_MS = 45;

function load(): Game | null {
  try {
    const raw = globalThis.localStorage?.getItem(SAVE_KEY);
    if (!raw) return null;
    const g = JSON.parse(raw) as Game;
    return g && g.version === 1 && typeof g.seg === 'number' ? g : null;
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
    selComm: null, dealOpen: null, cutPick: null, count: null, toast: null, debug: false,
  };
}

export function renderApp(view: View): HTMLElement {
  const { g, ui } = view;
  const screen = g.phase === 'end' ? 'end' : ui.screen;
  let main: HTMLElement;
  if (screen === 'end') main = endScreen(view);
  else if (screen === 'council') main = councilScreen(view);
  else if (screen === 'overview') main = overviewScreen(view);
  else main = homeScreen(view);
  const sheet = screen === 'home' || screen === 'overview' ? cardSheet(view) : null;
  const panel = overlay(view);
  return h('div', { class: cx('app', `app--${screen}`, sheet && 'has-sheet') },
    topBar(view),
    h('main', { class: 'main' }, main, sheet),
    screen === 'end' ? null : bottomBar(view),
    screen === 'council' ? voteLever(view) : null,
    panel ? h('div', { class: 'scrim', 'data-action': 'panel', 'data-panel': '' }) : null,
    panel,
    debugOverlay(view),
    ui.toast ? h('div', { class: 'toast', role: 'status' }, ui.toast) : null,
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
  const x1 = a.right - base.left;
  const y1 = a.top + a.height / 2 - base.top;
  const x2 = b.left - base.left;
  const y2 = Math.min(Math.max(y1, b.top - base.top + 16), b.bottom - base.top - 16);
  svg.setAttribute('viewBox', `0 0 ${base.width} ${base.height}`);
  const mx = (x1 + x2) / 2;
  svg.append(
    s('path', { d: `M${x1} ${y1} L${mx} ${y1} L${mx} ${y2} L${x2} ${y2}`, class: 'links__path' }),
    s('circle', { cx: x1, cy: y1, r: 3, class: 'links__dot' }),
    s('circle', { cx: x2, cy: y2, r: 3, class: 'links__dot' }));
}

export function startApp(root: HTMLElement): void {
  // 주소에 ?seed=가 있으면 그 시드로 시작한다(같은 판을 다시 볼 때, 스크린샷).
  const urlSeed = new URLSearchParams(globalThis.location?.search ?? '').get('seed');
  const saved = load();
  let g: Game = saved && (!urlSeed || saved.seed === urlSeed) ? saved : createGame(urlSeed || randomSeed());
  let ui: Ui = freshUi();
  if (g.phase === 'council') ui.screen = 'council';
  const scroll: Record<string, number> = {};
  let toastTimer: ReturnType<typeof setTimeout> | undefined;
  let countTimer: ReturnType<typeof setInterval> | undefined;
  let focusCar: string | null = null;

  function render(): void {
    for (const el of root.querySelectorAll<HTMLElement>('[data-keep-scroll]')) scroll[el.dataset.keepScroll ?? ''] = el.scrollLeft || el.scrollTop;
    root.replaceChildren(renderApp({ g, ui }));
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
    requestAnimationFrame(() => drawLinks(root));
  }

  function toast(text: string): void {
    ui.toast = text;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { ui.toast = null; render(); }, 2600);
  }

  /** 판을 바꾸는 행동. 사본에 하고, 저장하고, 다시 그린다. */
  function act(fn: (next: Game) => void): void {
    const next = cloneGame(g);
    fn(next);
    g = next;
    save(g);
    afterChange();
    render();
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
    clearInterval(countTimer);
    if (!result || result.flips.length === 0 || matchMedia('(prefers-reduced-motion: reduce)').matches) { ui.count = null; return; }
    ui.count = 0;
    // 찬성·반대가 먼저 앉고 미정이 하나씩 갈린다. 마지막 몇 표는 느리게(숨죽이는 개표).
    countTimer = setInterval(() => {
      if (ui.count === null) { clearInterval(countTimer); return; }
      ui.count += 1;
      if (ui.count >= result.flips.length) { ui.count = null; clearInterval(countTimer); }
      render();
    }, COUNT_MS);
  }

  function handle(action: string, data: DOMStringMap): void {
    switch (action) {
      case 'advance': {
        const wasSettle = g.phase === 'settle';
        act(next => advance(next));
        if (g.phase === 'settle' && !wasSettle) { ui.panel = 'settle'; ui.screen = 'home'; ui.selComm = null; ui.dealOpen = null; }
        if (g.phase === 'travel' || g.phase === 'stop') { ui.stopSeen = false; if (stackCount(g, ui) > 0) openStack(); }
        if (g.phase === 'prep') ui.panel = null;
        if (g.phase === 'council') { ui.screen = 'council'; ui.selComm = null; }
        return render();
      }
      case 'open-stack':
        openStack();
        return render();
      case 'fold':
        ui.cardOpen = false;
        return render();
      case 'choose':
        act(next => { chooseCard(next, Number(data.uid), Number(data.index)); });
        if (stackCount(g, ui) > 0) focusForTopCard();
        return render();
      case 'stop-set': {
        const key = data.key;
        const value = data.value ?? '';
        act(next => {
          if (key === 'target' && isLoot(value)) setStop(next, { target: value });
          else if (key === 'stay') setStop(next, { stay: value as StayId });
          else if (key === 'crewComm' && (COMMS as readonly string[]).includes(value)) setStop(next, { crewComm: value as Comm });
          else if (key === 'crewSize') setStop(next, { crewSize: Number(value) });
        });
        return;
      }
      case 'stop-go':
        act(next => { resolveStop(next, data.go === '1'); });
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
        act(next => setAutoLevers(next, !next.autoLevers));
        toast(g.autoLevers ? '배급장에게 맡겼다. 출발 전마다 레버를 움직인다.' : '레버를 직접 잡는다.');
        return render();
      case 'sel-comm':
        ui.selComm = (data.comm || null) as Comm | null;
        ui.dealOpen = null;
        ui.cutPick = null;
        return render();
      case 'agenda': {
        const council = g.council;
        if (!council) return;
        const n = council.options.length;
        act(next => setAgenda(next, (council.idx + Number(data.step) + n) % n));
        return;
      }
      case 'deal': {
        const c = data.comm as Comm;
        const tool = data.tool as Parameters<typeof makeDeal>[2];
        if (tool === 'open') { ui.dealOpen = c; ui.cutPick = null; return render(); }
        let text = '';
        act(next => { text = makeDeal(next, c, tool).text; });
        toast(text);
        return render();
      }
      case 'deal-cond': {
        const c = data.comm as Comm;
        const index = Number(data.index);
        const cut = data.cut as Comm | undefined;
        const isCut = !cut && openConditions(g, c)[index]?.kind === 'cut';
        if (isCut) { ui.cutPick = index; return render(); }
        let text = '';
        act(next => { text = makeDeal(next, c, 'open', index, cut).text; });
        ui.dealOpen = null;
        ui.cutPick = null;
        toast(text);
        return render();
      }
      case 'deal-close':
        ui.dealOpen = null;
        ui.cutPick = null;
        return render();
      case 'vote':
      case 'decree':
        if (!currentAgenda(g)) return;
        act(next => { castVote(next, action === 'decree'); });
        ui.selComm = null;
        ui.dealOpen = null;
        startCount();
        return render();
      case 'skip-count':
        ui.count = null;
        clearInterval(countTimer);
        return render();
      case 'comm-act': {
        const c = data.comm as Comm;
        let why: string | null = null;
        act(next => {
          why = data.act === 'support' ? supportComm(next, c) : data.act === 'cut' ? cutComm(next, c) : uniqueAction(next, c);
        });
        if (why) toast(why);
        return render();
      }
      case 'restart':
        g = createGame(g.seed);
        ui = freshUi();
        save(g);
        toast(`같은 시드(${g.seed})로 처음부터.`);
        return render();
      case 'new-seed':
        g = createGame(randomSeed());
        ui = freshUi();
        save(g);
        toast(`새 판: 시드 ${g.seed}.`);
        return render();
      case 'toggle-debug':
        ui.debug = !ui.debug;
        ui.panel = null;
        return render();
      default:
        return;
    }
  }

  root.addEventListener('click', event => {
    const target = (event.target as Element | null)?.closest<HTMLElement | SVGElement>('[data-action]');
    if (!target || !root.contains(target)) return;
    if ((target as HTMLButtonElement).disabled) return;
    handle(target.dataset.action ?? '', target.dataset);
  });

  // 끌던 중에 다시 그리면 손잡이를 놓치므로 손을 뗐을 때(change) 반영한다.
  root.addEventListener('change', event => {
    const el = event.target as HTMLInputElement;
    if (el.dataset.input !== 'lever') return;
    const c = el.dataset.comm as Comm;
    const which = el.dataset.which as 'heat' | 'ration';
    const value = Number(el.value);
    if (g.comms[c][which] === value) return;
    act(next => setLever(next, c, which, value));
  });

  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (ui.panel) ui.panel = null;
    else if (ui.cardOpen) ui.cardOpen = false;
    else if (ui.carPop) ui.carPop = null;
    else if (ui.screen !== 'home' && g.phase !== 'council') ui.screen = 'home';
    render();
  });

  window.addEventListener('resize', () => drawLinks(root));
  render();
}
