import type { PersonStatus } from '../../core';
import { PHASE_LABELS } from '../model/flow';
import { DUMMY_CHARACTERS } from '../model/dummy';
import { GROUP_META } from '../model/groups';
import { cx, h } from '../dom';
import { chip, screenTitle, segmented, stub } from './common';
import type { View } from './common';

// 열차장실 = 일지와 인물(기획서 15장). 일지는 지난 사건을 다시 본다(14장, S1a).

const STATE_LABELS: Readonly<Record<PersonStatus, string>> = Object.freeze({
  alive: '열차에 있음',
  injured: '다침',
  dead: '죽음',
  away: '파견 중',
});

function journalList(view: View): HTMLElement {
  const entries = [...view.app.journal].reverse();
  return h('ol', { class: 'journal', 'data-test': 'journal' },
    entries.map(entry => h('li', { class: 'journal__item' },
      h('span', { class: 'journal__tag' }, `${entry.segment}구간 · ${PHASE_LABELS[entry.phase]}`),
      h('span', { class: 'journal__text' }, entry.text))));
}

function peopleGrid(view: View): HTMLElement {
  const { game } = view.app;
  const characters = DUMMY_CHARACTERS.filter(character => !character.factionOnly || view.app.dummyFaction);
  const captain = h('li', { class: 'person person--captain' },
    h('div', { class: 'person__head' },
      h('span', { class: 'person__name' }, '열차장'),
      h('span', { class: 'person__role' }, '당신')),
    h('p', { class: 'person__line' }, '이름과 탄 경위는 시작할 때 고른다(설계 예정).'));
  return h('ul', { class: 'people', 'data-test': 'people' },
    captain,
    characters.map(character => {
      const person = game.persons[character.personId];
      const status: PersonStatus = person?.state ?? 'alive';
      const group = character.role === 'faction_leader' ? 'faction_restore' : character.community;
      return h('li', { class: 'person' },
        h('div', { class: 'person__head' },
          chip(group),
          h('span', { class: 'person__name' }, character.name),
          h('span', { class: 'person__role' }, `${character.roleLabel} · ${character.age}세`),
          h('span', { class: cx('person__state', `is-${status}`) }, STATE_LABELS[status])),
        h('p', { class: 'person__line' }, character.line),
        h('p', { class: 'person__meta' },
          `${GROUP_META[character.community].name} · ${character.hometown} · 탄 경위 ${character.boarding}`));
    }));
}

export function captainScreen(view: View): HTMLElement {
  const tab = view.ui.captainTab;
  return h('section', { class: 'captain', 'aria-label': '열차장실', 'data-test': 'captain' },
    screenTitle('열차장실', tab === 'journal' ? `일지 ${view.app.journal.length}건 · 새 기록이 위` : '이름 있는 인물(더미)',
      segmented('보기', 'captain-tab', 'tab', [
        { value: 'journal', label: '일지', test: 'tab-journal' },
        { value: 'people', label: '인물', test: 'tab-people' },
      ], tab, 'captain__tabs')),
    h('div', { class: 'captain__body' },
      tab === 'journal' ? journalList(view) : peopleGrid(view),
      stub(view, 'S1b', tab === 'journal' ? '일대기 완성판 · 추모의 벽' : '열차장의 가족', 'captain__stub')));
}
