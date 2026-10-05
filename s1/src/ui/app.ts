import { COMMUNITY_IDS } from '../core';
import type { CommunityId, VoteMode } from '../core';
import {
  advance, castSessionVote, chooseCard, createApp, restartApp, setBill, setCardCollapsed, setDummyFaction, setFlags,
  setVoteMode,
} from './model/app-state';
import type { AppState } from './model/app-state';
import { createDummyRoster } from './model/dummy';
import { isFlagKey, toggleFlag } from './model/flags';
import { browserStorage, clearSave, loadApp, peekSave, saveApp } from './model/save';
import { cx, h } from './dom';
import type { Screen, UiState, View } from './views/common';
import { bottomBar, topBar } from './views/hud';
import { homeScreen } from './views/home';
import { councilControls, councilScreen } from './views/council';
import { captainScreen } from './views/captain';
import { communityScreen } from './views/community';
import { debugScreen } from './views/debug';
import { decisionCard, factionPanel, menuPopover, scrim, toast } from './views/overlays';

// 화면 뼈대의 조립과 입력 처리. 상태가 바뀌면 통째로 다시 그린다(요소 수가 적어 충분히 빠르다).

const TOAST_MS = 2400;

function screenContent(view: View): HTMLElement {
  const screen = view.ui.screen;
  if (screen === 'council') return councilScreen(view);
  if (screen === 'captain') return captainScreen(view);
  if (screen === 'debug') return debugScreen(view);
  if (screen.startsWith('community:')) return communityScreen(view, screen.slice('community:'.length) as CommunityId);
  return homeScreen(view);
}

export function renderApp(view: View): HTMLElement {
  const { ui } = view;
  const screenKey = ui.screen.split(':')[0];
  const leftExtra = ui.screen === 'council' && ui.panel !== 'factions' ? councilControls(view) : [];
  return h('div', { class: cx('app', `app--${screenKey}`, view.app.card && !view.app.card.collapsed && 'has-card'), 'data-screen': ui.screen },
    topBar(view),
    h('main', { class: cx('main', ui.enter === 'screen' && 'enter-fade'), id: 'main', 'data-anim': '' }, screenContent(view)),
    bottomBar(view, leftExtra),
    scrim(view),
    factionPanel(view),
    decisionCard(view),
    menuPopover(view),
    toast(view));
}

function isCommunity(value: string | undefined): value is CommunityId {
  return value !== undefined && (COMMUNITY_IDS as readonly string[]).includes(value);
}

function randomSeed(): string {
  try {
    const bytes = new Uint32Array(1);
    globalThis.crypto.getRandomValues(bytes);
    return `seed-${bytes[0].toString(36)}`;
  } catch {
    return `seed-${Date.now().toString(36)}`;
  }
}

/** 진행 중인 들어오기 움직임이 있으면 끝까지 넘긴다. 넘겼으면 true. */
function skipAnimations(): boolean {
  if (typeof document.getAnimations !== 'function') return false;
  const running = document.getAnimations().filter(animation => {
    const target = (animation.effect as KeyframeEffect | null)?.target;
    return animation.playState === 'running' && target instanceof Element && target.closest('[data-anim]') !== null;
  });
  for (const animation of running) animation.finish();
  return running.length > 0;
}

export function startApp(root: HTMLElement): void {
  const storage = browserStorage();
  let app: AppState = createApp();
  let profiles = createDummyRoster(app.seed).profiles;
  const peek = peekSave(storage);
  let ui: UiState = {
    screen: 'home', panel: null, captainTab: 'journal', mockVote: null, confirmReset: false, toast: null, enter: null,
    slot: peek.ok ? peek.value : null,
  };
  let toastTimer: ReturnType<typeof setTimeout> | undefined;
  let swallowClick = false;

  function render(): void {
    root.replaceChildren(renderApp({ app, ui, profiles }));
    // 들어오기 움직임은 그 순간 한 번만 준다.
    ui = { ...ui, enter: null };
  }

  function update(nextApp: AppState, patch: Partial<UiState> = {}): void {
    if (nextApp.seed !== app.seed) profiles = createDummyRoster(nextApp.seed).profiles;
    const openedCard = nextApp.card !== null && !nextApp.card.collapsed && (app.card === null || app.card.collapsed);
    app = nextApp;
    ui = { ...ui, ...(openedCard ? { enter: 'card' as const } : {}), ...patch };
    if (patch.toast) {
      clearTimeout(toastTimer);
      toastTimer = setTimeout(() => {
        ui = { ...ui, toast: null };
        render();
      }, TOAST_MS);
    }
    render();
  }

  function go(screen: Screen): void {
    update(app, { screen, panel: null, confirmReset: false, mockVote: null, enter: 'screen' });
  }

  function handle(action: string, data: DOMStringMap): void {
    switch (action) {
      case 'open-car': {
        const car = data.car;
        if (car === 'dining') go('council');
        else if (car === 'captain') go('captain');
        else if (isCommunity(car)) go(`community:${car}`);
        return;
      }
      case 'back': return go('home');
      case 'open-debug': return go('debug');
      case 'toggle-factions':
        return update(app, { panel: ui.panel === 'factions' ? null : 'factions', enter: 'panel', confirmReset: false });
      case 'toggle-menu':
        return update(app, { panel: ui.panel === 'menu' ? null : 'menu', enter: 'menu', confirmReset: false });
      case 'close-panel':
        return update(app, { panel: null, confirmReset: false });
      case 'advance':
        return update(advance(app), { mockVote: null, panel: null });
      case 'choose':
        return update(chooseCard(app, Number(data.index)));
      case 'card-collapse':
        return update(setCardCollapsed(app, true));
      case 'card-expand':
        return update(setCardCollapsed(app, false), { enter: 'card' });
      case 'vote':
        if (app.flow.phase === 'council' && !app.flow.ended) return update(castSessionVote(app));
        return update(app, { mockVote: { rng: { ...app.game.rng }, billId: app.billId } });
      case 'mock-clear':
        return update(app, { mockVote: null });
      case 'vote-mode':
        return update(setVoteMode(app, data.mode as VoteMode));
      case 'bill':
        if (data.bill) update(setBill(app, data.bill), { mockVote: null });
        return;
      case 'captain-tab':
        return update(app, { captainTab: data.tab === 'people' ? 'people' : 'journal' });
      case 'save': {
        const result = saveApp(storage, app);
        return update(app, result.ok
          ? { slot: result.value, toast: `저장했다. ${app.flow.segment}구간, 시드 ${app.seed}.`, panel: null }
          : { toast: result.message });
      }
      case 'load': {
        const result = loadApp(storage);
        if (!result.ok) return update(app, { toast: result.message, slot: result.error === 'empty' ? null : ui.slot });
        return update(result.value.app, {
          slot: result.value.summary, toast: `불러왔다. ${result.value.app.flow.segment}구간.`, panel: null,
          screen: 'home', mockVote: null, enter: 'screen',
        });
      }
      case 'reset':
        if (!ui.confirmReset && !app.flow.ended) return update(app, { confirmReset: true });
        return update(restartApp(app), {
          confirmReset: false, panel: null, screen: 'home', mockVote: null, toast: '같은 시드로 처음부터 다시 시작했다.', enter: 'screen',
        });
      case 'clear-save': {
        const result = clearSave(storage);
        return update(app, result.ok ? { slot: null, toast: '저장을 지웠다.' } : { toast: result.message });
      }
      case 'new-seed': {
        const seed = randomSeed();
        return update(createApp(seed, app.flags, app.dummyFaction), { mockVote: null, toast: `새 시드 ${seed}로 시작했다.` });
      }
      case 'flag':
        if (isFlagKey(data.flag)) update(setFlags(app, toggleFlag(app.flags, data.flag)));
        return;
      case 'faction':
        return update(setDummyFaction(app, !app.dummyFaction), { mockVote: null });
      default:
        return;
    }
  }

  // 들어오기 움직임 중의 첫 탭은 움직임만 끝낸다(연출은 언제든 탭으로 건너뛴다).
  root.addEventListener('pointerdown', () => {
    if (skipAnimations()) {
      swallowClick = true;
      setTimeout(() => { swallowClick = false; }, 400);
    }
  }, { capture: true });

  root.addEventListener('click', event => {
    if (swallowClick) {
      swallowClick = false;
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    const target = (event.target as Element | null)?.closest<HTMLElement>('[data-action]');
    if (!target || !root.contains(target) || (target as HTMLButtonElement).disabled) return;
    handle(target.dataset.action ?? '', target.dataset);
  });

  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (ui.panel !== null) update(app, { panel: null, confirmReset: false });
    else if (ui.screen !== 'home') go('home');
  });

  render();
}
