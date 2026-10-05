import { COMMUNITY_METRICS } from '../../core';
import type { CommunityId } from '../../core';
import { representativeOf } from '../model/dummy';
import { GROUP_META, METRIC_LABELS, STANCE_LABELS, metricLevel } from '../model/groups';
import { groupStandings } from '../model/standings';
import { cx, h } from '../dom';
import { chip, meter, screenTitle, stub } from './common';
import type { View } from './common';
import { communityHeadcount } from './home';
import { relationBar } from './overlays';

// 공동체 칸: 인구, 처지 넷(온기·배급·과밀·위험 노출), 대표.

export function communityScreen(view: View, id: CommunityId): HTMLElement {
  const { game } = view.app;
  const meta = GROUP_META[id];
  const state = game.communities[id];
  const count = communityHeadcount(game, id);
  const standing = groupStandings(game).find(candidate => candidate.id === id);
  const rep = representativeOf(id);
  const repPerson = game.persons[rep.personId];
  const away = Object.values(game.persons).filter(person => person.community === id && person.state === 'away');
  const awayNames = away.slice(0, 4).map(person => view.profiles[person.id]?.name ?? person.id);
  const returnIn = away.length > 0 ? Math.min(...away.map(person => person.awaySegments)) : 0;
  const seatsText = standing ? `의석 ${standing.seats}` : '의석 없음';

  const conditions = h('div', { class: 'panel cond', 'data-test': 'conditions' },
    h('h2', { class: 'panel__title' }, '처지'),
    h('ul', { class: 'cond__list' },
      COMMUNITY_METRICS.map(metric => {
        const value = state[metric];
        const level = metricLevel(metric, value);
        return h('li', { class: cx('cond__row', `is-${level.severity}`) },
          h('span', { class: 'cond__label' }, METRIC_LABELS[metric]),
          h('b', { class: 'cond__value' }, String(Math.round(value))),
          h('span', { class: 'cond__word' }, level.word),
          meter(value, level.severity === 'normal' ? 'plain' : level.severity));
      })),
    h('p', { class: 'cond__people' },
      `${count.total}명 · 아이 ${count.children} · 노인 ${count.elders}${count.injured ? ` · 다침 ${count.injured}` : ''}`),
    away.length > 0
      ? h('p', { class: 'cond__away' }, `파견 중 ${away.length}명: ${awayNames.join(', ')}${away.length > awayNames.length ? ' 외' : ''} · ${returnIn}구간 뒤 귀환`)
      : null);

  const representative = h('div', { class: 'panel rep', 'data-test': 'representative' },
    h('h2', { class: 'panel__title' }, '대표'),
    h('div', { class: 'rep__head' },
      h('span', { class: 'rep__name' }, rep.name),
      h('span', { class: 'rep__role' }, `${rep.roleLabel} · ${rep.age}세`),
      repPerson && repPerson.state !== 'alive' ? h('span', { class: 'rep__state' }, repPerson.state === 'away' ? '파견 중' : '다침') : null),
    h('p', { class: 'rep__line' }, rep.line),
    h('dl', { class: 'rep__facts' },
      h('dt', null, '출신'), h('dd', null, rep.hometown),
      h('dt', null, '탄 경위'), h('dd', null, rep.boarding),
      h('dt', null, '좋아함'), h('dd', null, rep.like),
      h('dt', null, '싫어함'), h('dd', null, rep.dislike)),
    standing ? h('div', { class: 'rep__relation' },
      h('span', { class: 'rep__relation-label' }, '열차장과의 관계'),
      relationBar(standing.relation),
      h('span', { class: 'rep__relation-value' }, `${STANCE_LABELS[standing.stance]} ${Math.abs(standing.relation)}`)) : null,
    standing?.need ? h('p', { class: 'rep__need' }, '요구: ', h('b', null, METRIC_LABELS[standing.need])) : null);

  return h('section', { class: 'community', 'aria-label': `${meta.name} 칸`, 'data-test': `community-${id}` },
    screenTitle([chip(id, 'chip--title'), meta.name], `${meta.fullName} · ${count.total}명 · ${seatsText}`,
      stub(view, 'S1a', id === 'engine' ? '운영 레버 · 파업 경고' : '운영 레버: 배급·난방·공간', 'stub--inline'),
      id === 'engine' ? stub(view, 'S1c', '지식 현황판', 'stub--inline') : null),
    h('div', { class: 'community__body' }, conditions, representative));
}
