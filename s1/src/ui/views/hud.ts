import { advanceBlocker, hasSessionVote } from '../model/app-state';
import type { AppState } from '../model/app-state';
import {
  PHASES, PHASE_LABELS, RUN_SEGMENTS, isCouncilSegment, segmentsUntilCouncil, stepStatuses,
} from '../model/flow';
import { RESOURCE_LABELS, RESOURCE_ORDER, STANCE_LABELS } from '../model/groups';
import type { Severity } from '../model/groups';
import { groupStandings, stanceSeats } from '../model/standings';
import { cx, h } from '../dom';
import { button, meter } from './common';
import type { UiState, View } from './common';

// 늘 같은 자리에 있는 계기: 위 한 줄(신임·긴장, 불만·지지, 자원)과 아래 한 줄(엄지 자리 단추, 단계 표시줄).

function trustSeverity(value: number): Severity {
  if (value < 30) return 'serious';
  if (value < 45) return 'warning';
  return 'normal';
}

function tensionSeverity(value: number): Severity {
  if (value >= 70) return 'serious';
  if (value >= 50) return 'warning';
  return 'normal';
}

const SEVERITY_WORD: Partial<Record<Severity, string>> = { warning: '주의', serious: '위험' };

function gauge(label: string, value: number, severity: Severity, test: string): HTMLElement {
  const word = SEVERITY_WORD[severity];
  return h('div', { class: cx('stat', 'stat--gauge', `is-${severity}`), 'data-test': test },
    h('span', { class: 'stat__label' }, label),
    h('span', { class: 'stat__value' }, String(Math.round(value)), word ? h('span', { class: 'stat__word' }, word) : null),
    meter(value, severity === 'normal' ? 'plain' : severity));
}

function resource(label: string, value: number): HTMLElement {
  return h('div', { class: 'stat stat--resource' },
    h('span', { class: 'stat__label' }, label),
    h('span', { class: 'stat__value' }, String(Math.round(value))));
}

function supportBar(view: View): HTMLElement {
  const standings = groupStandings(view.app.game);
  const totals = stanceSeats(standings);
  const sorted = [...standings].sort((a, b) => a.relation - b.relation);
  const open = view.ui.panel === 'factions';
  return h('button', {
    type: 'button',
    class: cx('support', open && 'is-open'),
    'data-action': 'toggle-factions',
    'data-test': 'support-bar',
    'aria-expanded': String(open),
    'aria-label': `불만 ${totals.discontent}석, 중립 ${totals.neutral}석, 지지 ${totals.support}석. 누르면 집단별로 펼친다.`,
  },
  h('span', { class: 'support__labels' },
    h('span', { class: 'support__side' }, `${STANCE_LABELS.discontent} `, h('b', null, String(totals.discontent)), '석'),
    h('span', { class: 'support__mid' }, `중립 ${totals.neutral}석`),
    h('span', { class: 'support__side support__side--end' }, `${STANCE_LABELS.support} `, h('b', null, String(totals.support)), '석',
      h('span', { class: 'support__caret', 'aria-hidden': 'true' }, open ? '▴' : '▾'))),
  h('span', { class: 'support__bar', 'aria-hidden': 'true' },
    sorted.map(standing => h('span', {
      class: cx('support__seg', `is-${standing.stance}`),
      style: `flex-grow:${standing.seats}`,
    }))));
}

export function topBar(view: View): HTMLElement {
  const { game } = view.app;
  return h('header', { class: 'hud-top' },
    h('div', { class: 'hud-top__side hud-top__side--start' },
      gauge('신임', game.trust, trustSeverity(game.trust), 'trust'),
      gauge('긴장', game.tension, tensionSeverity(game.tension), 'tension')),
    supportBar(view),
    h('div', { class: 'hud-top__side hud-top__side--end' },
      RESOURCE_ORDER.map(type => resource(RESOURCE_LABELS[type], game.resources[type]))));
}

export interface PrimaryAction {
  label: string;
  action: string;
  data?: Record<string, string>;
}

/** 아래 오른쪽 엄지 자리의 주 단추. 지금 할 일 하나만 보여준다. */
export function primaryAction(app: AppState, ui: UiState): PrimaryAction | null {
  const { flow } = app;
  if (flow.ended) return { label: '처음부터', action: 'reset' };
  if (app.card) return app.card.collapsed ? { label: '결정 카드', action: 'card-expand' } : null;
  if (flow.phase === 'council') {
    if (hasSessionVote(app)) return { label: '정산으로', action: 'advance' };
    if (ui.screen !== 'council') return { label: '식당칸으로', action: 'open-car', data: { car: 'dining' } };
    return { label: '표결', action: 'vote' };
  }
  // 회기가 아닐 때 의회 화면에선 모의 표결. 이번 구간 회기의 결과를 보는 중이면 흐름을 이어 간다.
  if (ui.screen === 'council' && !hasSessionVote(app)) {
    return ui.mockVote ? { label: '예상 보기', action: 'mock-clear' } : { label: '모의 표결', action: 'vote' };
  }
  if (advanceBlocker(app) !== null) return null;
  switch (flow.phase) {
    case 'prep': return { label: '출발', action: 'advance' };
    case 'travel': return { label: '정차로', action: 'advance' };
    case 'stop': return { label: isCouncilSegment(flow.segment) ? '의회로' : '정산으로', action: 'advance' };
    case 'settle': return { label: flow.segment >= RUN_SEGMENTS ? '판 마치기' : '다음 구간으로', action: 'advance' };
  }
}

/** 좁은 화면에서만 쓰는 짧은 이름. */
const PHASE_SHORT: Readonly<Record<(typeof PHASES)[number], string>> = Object.freeze({
  prep: '출발 전', travel: '이동', stop: '정차', council: '의회', settle: '정산',
});

function stepper(view: View): HTMLElement {
  const { flow } = view.app;
  const statuses = stepStatuses(flow);
  const until = segmentsUntilCouncil(flow);
  const councilNote = until === null ? '회기 없음' : `${until}구간 뒤`;
  const label = flow.ended
    ? `${RUN_SEGMENTS}구간을 마쳤다`
    : `${flow.segment}구간, ${PHASE_LABELS[flow.phase]} 단계. ${until === null ? '남은 회기 없음' : until === 0 ? '이번 구간에 회기' : `다음 회기까지 ${until}구간`}`;
  return h('div', { class: 'stepper', role: 'group', 'aria-label': label, 'data-test': 'stepper' },
    h('span', { class: 'stepper__segment' },
      h('span', { class: 'stepper__segment-label' }, '구간'),
      h('span', { class: 'stepper__segment-value' }, h('b', null, String(flow.segment)), `/${RUN_SEGMENTS}`)),
    h('ol', { class: 'stepper__list' },
      PHASES.map(phase => h('li', { class: cx('step', `is-${statuses[phase]}`), 'data-phase': phase },
        h('span', { class: 'step__dot', 'aria-hidden': 'true' }),
        h('span', { class: 'step__text' },
          h('span', { class: 'step__label' },
            h('span', { class: 'label-full' }, PHASE_LABELS[phase]),
            h('span', { class: 'label-short', 'aria-hidden': 'true' }, PHASE_SHORT[phase])),
          statuses[phase] === 'skipped' ? h('span', { class: 'step__note' }, councilNote) : null)))));
}

export function bottomBar(view: View, leftExtra: (HTMLElement | null)[] = []): HTMLElement {
  const { ui } = view;
  let left: HTMLElement;
  if (ui.panel === 'factions') left = button('닫기', 'close-panel', { test: 'close-panel' });
  else if (ui.screen === 'home') left = button('메뉴', 'toggle-menu', { test: 'menu', pressed: ui.panel === 'menu' });
  else left = button('← 열차', 'back', { test: 'back', ariaLabel: '열차로 돌아가기' });
  const primary = primaryAction(view.app, ui);
  return h('footer', { class: 'hud-bottom' },
    h('div', { class: 'hud-bottom__corner hud-bottom__corner--start' }, left, leftExtra),
    stepper(view),
    h('div', { class: 'hud-bottom__corner hud-bottom__corner--end' },
      primary ? button(primary.label, primary.action, { variant: 'primary', data: primary.data, test: 'primary' }) : null));
}
