import { COMMUNITY_METRICS } from '../../core';
import { PHASE_LABELS } from '../model/flow';
import { FLAG_KEYS, FLAG_LABELS } from '../model/flags';
import { GROUP_META, METRIC_LABELS } from '../model/groups';
import type { GroupId } from '../model/groups';
import { characterFor } from '../model/dummy';
import { percent } from '../model/format';
import { groupStandings } from '../model/standings';
import { cx, h } from '../dom';
import { button, chip, screenTitle } from './common';
import type { View } from './common';
import { communityHeadcount } from './home';

// 디버그 화면: 숨은 수치(공포, 결속도, 원래 수), 시드, 기능 플래그. 플레이 테스트 땐 끈다(기획서 2장).

function fact(label: string, value: string | number, hidden = false): HTMLElement {
  return h('div', { class: 'fact' },
    h('dt', null, label, hidden ? h('span', { class: 'tag tag--hidden' }, '숨음') : null),
    h('dd', null, String(value)));
}

function toggle(label: string, detail: string, on: boolean, action: string, data: Record<string, string>, test: string): HTMLElement {
  const attrs: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) attrs[`data-${key}`] = value;
  return h('button', {
    type: 'button', class: cx('switch', on && 'is-on'), 'data-action': action, 'aria-pressed': String(on), 'data-test': test,
    'aria-label': `${label} ${detail}: ${on ? '켜짐' : '꺼짐'}`, ...attrs,
  },
  h('span', { class: 'switch__label' }, label),
  h('span', { class: 'switch__state' }, on ? '켜짐' : '꺼짐'),
  h('span', { class: 'switch__detail' }, detail));
}

export function debugScreen(view: View): HTMLElement {
  const { app, ui } = view;
  const { game, flow } = app;
  const slot = ui.slot;
  const standings = groupStandings(game);

  const facts = h('dl', { class: 'facts-strip', 'data-test': 'debug-facts' },
    fact('시드', app.seed),
    fact('흐름', flow.ended ? '끝' : `${flow.segment}구간 ${PHASE_LABELS[flow.phase]}`),
    fact('난수 상태', game.rng.state),
    fact('저장 슬롯', slot ? `${slot.segment}구간 ${PHASE_LABELS[slot.phase]} · ${slot.seed}` : '없음'),
    fact('공포', game.fear, true),
    fact('신임', game.trust),
    fact('긴장', game.tension),
    fact('상징물', game.symbols.length),
    fact('비밀', game.secrets.length));

  const flags = h('div', { class: 'debug__flags' },
    h('h2', { class: 'panel__title' }, '기능 플래그 · 지금은 자리표시만 켜고 끈다'),
    h('div', { class: 'switches' },
      FLAG_KEYS.map(key => toggle(key, FLAG_LABELS[key], app.flags[key], 'flag', { flag: key }, `flag-${key}`)),
      toggle('세력', '복원파(더미)', app.dummyFaction, 'faction', {}, 'flag-faction')),
    h('div', { class: 'panel__actions' },
      button('저장 지우기', 'clear-save', { test: 'clear-save', disabled: !slot }),
      button('새 시드로 새 판', 'new-seed', { test: 'new-seed' })));

  const headers = ['인구', '의석', '파견', '관계', '결속도', '약속표', ...COMMUNITY_METRICS.map(metric => METRIC_LABELS[metric])];
  const table = h('table', { class: 'debug-table', 'data-test': 'debug-groups' },
    h('caption', null, '집단별 원래 수 · 결속도와 약속표는 숨은 값'),
    h('thead', null, h('tr', null,
      h('th', { scope: 'col', class: 'name' }, '집단'),
      headers.map(label => h('th', { scope: 'col', class: 'num' }, label)))),
    h('tbody', null, standings.map(standing => {
      const group = game.groups[standing.id];
      const community = Object.hasOwn(game.communities, standing.id)
        ? game.communities[standing.id as keyof typeof game.communities]
        : null;
      const away = community ? communityHeadcount(game, standing.id as keyof typeof game.communities).away : standing.population - standing.present;
      const leader = standing.leaderId ? characterFor(standing.leaderId)?.name : undefined;
      return h('tr', { title: leader ? `지도자 ${leader}` : null },
        h('th', { scope: 'row', class: 'name' }, chip(standing.id), GROUP_META[standing.id as GroupId].name),
        h('td', { class: 'num' }, String(standing.population)),
        h('td', { class: 'num' }, String(standing.seats)),
        h('td', { class: 'num' }, String(away)),
        h('td', { class: 'num' }, String(group.relation)),
        h('td', { class: 'num' }, percent(group.cohesion)),
        h('td', { class: 'num' }, String(group.votes)),
        COMMUNITY_METRICS.map(metric => h('td', { class: 'num' }, community ? String(community[metric]) : '—')));
    })));

  return h('section', { class: 'debug', 'aria-label': '디버그', 'data-test': 'debug' },
    screenTitle('디버그 · 숨은 수치', '밸런싱용. 플레이 테스트 땐 끈다.'),
    h('div', { class: 'debug__body' },
      facts,
      h('div', { class: 'debug__grid' }, flags, table)));
}
