import type { CommunityId, GameState } from '../../core';
import { recentJournal } from '../model/app-state';
import { PHASE_LABELS, segmentsUntilCouncil } from '../model/flow';
import type { Phase } from '../model/flow';
import { GROUP_META, METRIC_LABELS, metricLevel } from '../model/groups';
import type { MetricLevel } from '../model/groups';
import { cx, h } from '../dom';
import { chip, meter, stub, worldTime } from './common';
import type { CarId, View } from './common';

// 홈: 달리는 열차의 가로 단면도(2D 칸 상자). 칸이 곧 메뉴다.

/** 열차의 뒤(왼쪽) → 앞(오른쪽). 기관실이 오른쪽 끝에서 열차를 끈다. */
export const TRAIN_ORDER: readonly CarId[] = Object.freeze(['tail', 'medtech', 'dining', 'guard', 'captain', 'front', 'engine']);

const PHASE_HINTS: Readonly<Record<Phase, string>> = Object.freeze({
  prep: '칸마다 배급·난방·공간을 정한다. 기본은 지난 구간 그대로다.',
  travel: '사건 카드가 올라온다. 열차 안 처지, 정치, 사고.',
  stop: '필드 결정 카드. 서지 않고 지나갈 수도 있다.',
  council: '회기다. 식당칸에서 안건을 표결한다.',
  settle: '자원이 들고, 처지와 관계가 바뀐다.',
});

export function communityHeadcount(game: GameState, community: CommunityId) {
  const people = Object.values(game.persons).filter(person => person.community === community);
  const living = people.filter(person => person.state !== 'dead');
  return {
    total: living.length,
    away: living.filter(person => person.state === 'away').length,
    injured: living.filter(person => person.state === 'injured').length,
    children: living.filter(person => (person.age ?? 30) <= 15).length,
    elders: living.filter(person => (person.age ?? 30) >= 65).length,
  };
}

function metricRow(label: string, value: number, level: MetricLevel): HTMLElement {
  return h('span', { class: cx('car__metric', `is-${level.severity}`) },
    h('span', { class: 'car__metric-text' },
      h('span', { class: 'car__metric-label' }, label, ' ', h('b', null, String(Math.round(value)))),
      h('span', { class: 'car__metric-word' }, level.word)),
    meter(value, level.severity === 'normal' ? 'plain' : level.severity));
}

function communityCar(view: View, id: CommunityId): HTMLElement[] {
  const { game } = view.app;
  const state = game.communities[id];
  const warmth = metricLevel('warmth', state.warmth);
  const crowding = metricLevel('crowding', state.crowding);
  const count = communityHeadcount(game, id);
  const name = GROUP_META[id].name;
  const warmthClass = warmth.severity === 'serious' ? 'cold' : warmth.severity === 'good' ? 'warm' : 'mild';
  const car = h('button', {
    type: 'button',
    class: cx('car', 'car--community', `car--${id}`, `is-${warmthClass}`, `crowd-${crowding.severity}`),
    'data-action': 'open-car',
    'data-car': id,
    'data-test': `car-${id}`,
    'aria-label': `${name} 칸. ${count.total}명${count.away ? `, 파견 ${count.away}명` : ''}. ${METRIC_LABELS.warmth} ${state.warmth} ${warmth.word}. ${METRIC_LABELS.crowding} ${state.crowding} ${crowding.word}.`,
  },
  id === 'engine' ? h('span', { class: 'car__stack', 'aria-hidden': 'true' }) : null,
  h('span', { class: 'car__head' }, chip(id), h('span', { class: 'car__name' }, name)),
  h('span', { class: 'car__sub' }, `${count.total}명`, count.away ? ` · 파견 ${count.away}` : ''),
  metricRow(METRIC_LABELS.warmth, state.warmth, warmth),
  metricRow(METRIC_LABELS.crowding, state.crowding, crowding));
  return id === 'engine' ? [car, h('span', { class: 'plow', 'aria-hidden': 'true' })] : [car];
}

function specialCar(view: View, id: 'dining' | 'captain'): HTMLElement {
  const { flow, journal } = view.app;
  if (id === 'dining') {
    const inSession = flow.phase === 'council' && !flow.ended;
    const until = segmentsUntilCouncil(flow);
    // 좁은 칸이라 두 줄로 쓴다: 무엇(회기)과 언제.
    const [what, when] = inSession ? ['회기', '진행 중']
      : until === null ? ['회기', '남은 것 없음']
        : until === 0 ? ['회기', '이번 구간'] : ['다음 회기', `${until}구간 뒤`];
    return h('button', {
      type: 'button', class: cx('car', 'car--special', 'car--dining', inSession && 'is-active'),
      'data-action': 'open-car', 'data-car': 'dining', 'data-test': 'car-dining',
      'aria-label': `식당칸. 의회. ${what} ${when}.`,
    },
    h('span', { class: 'car__head' }, h('span', { class: 'car__name' }, '식당칸')),
    h('span', { class: 'car__sub' }, '의회'),
    h('span', { class: 'car__status car__status--stack' },
      h('span', { class: 'car__status-what' }, what),
      h('span', { class: 'car__status-when' }, inSession ? h('span', { class: 'car__status-dot', 'aria-hidden': 'true' }) : null, when)));
  }
  return h('button', {
    type: 'button', class: cx('car', 'car--special', 'car--captain'),
    'data-action': 'open-car', 'data-car': 'captain', 'data-test': 'car-captain',
    'aria-label': `열차장실. 일지와 인물. 일지 ${journal.length}건.`,
  },
  h('span', { class: 'car__head' }, h('span', { class: 'car__name' }, '열차장실')),
  h('span', { class: 'car__sub' }, '일지·인물'),
  h('span', { class: 'car__status' }, `일지 ${journal.length}건`));
}

function workshopCar(view: View): HTMLElement | null {
  if (!view.app.flags.S1c) return null;
  return h('div', { class: 'car car--stub', 'data-flag': 'S1c', 'aria-label': '공방칸. S1c 자리.' },
    h('span', { class: 'car__head' }, h('span', { class: 'car__name' }, '공방칸')),
    h('span', { class: 'car__sub' }, 'S1c 자리'),
    h('span', { class: 'car__status' }, '생산·기술'));
}

export function trainStrip(view: View): HTMLElement {
  const cars: (HTMLElement | null)[] = [];
  for (const id of TRAIN_ORDER) {
    if (id === 'dining' || id === 'captain') cars.push(specialCar(view, id));
    else if (id !== 'workshop') cars.push(...communityCar(view, id));
    if (id === 'medtech') cars.push(workshopCar(view));
  }
  return h('div', { class: 'train', role: 'group', 'aria-label': '열차. 왼쪽이 꼬리, 오른쪽이 기관차다.' },
    h('div', { class: 'train__cars' }, cars),
    h('div', { class: 'train__rail', 'aria-hidden': 'true' }));
}

export function homeScreen(view: View): HTMLElement {
  const { flow } = view.app;
  const until = segmentsUntilCouncil(flow);
  const council = flow.ended ? '판이 끝났다'
    : until === null ? '남은 회기 없음'
      : until === 0 ? (flow.phase === 'council' ? '지금 회기 중' : '이번 구간에 회기')
        : `다음 회기까지 ${until}구간`;
  const title = flow.ended ? '판 끝' : PHASE_LABELS[flow.phase];
  const hint = flow.ended ? '24구간을 모두 지났다. 결말 화면은 아직 없다.' : PHASE_HINTS[flow.phase];
  const recent = recentJournal(view.app, 2);
  return h('section', { class: 'home', 'aria-label': '홈' },
    h('div', { class: 'home__head' },
      h('div', { class: 'home__phase' },
        h('h1', { class: 'home__title' }, h('span', { class: 'home__segment' }, `${flow.segment}구간`), title),
        h('p', { class: 'home__hint' }, hint)),
      h('div', { class: 'home__time' },
        h('span', null, worldTime(flow.segment)),
        h('span', { class: cx('home__council', until === 0 && 'is-now') }, council))),
    trainStrip(view),
    h('div', { class: 'home__foot' },
      h('button', { type: 'button', class: 'journal-peek', 'data-action': 'open-car', 'data-car': 'captain', 'aria-label': '최근 일지. 누르면 열차장실 일지로.' },
        h('span', { class: 'journal-peek__label' }, '최근 일지'),
        h('span', { class: 'journal-peek__list' },
          recent.map(entry => h('span', { class: 'journal-peek__item' },
            h('span', { class: 'journal-peek__tag' }, `${entry.segment}구간 ${PHASE_LABELS[entry.phase]}`),
            h('span', { class: 'journal-peek__text' }, entry.text))))),
      flow.phase === 'prep' && !flow.ended ? stub(view, 'S1a', '운영 레버 · 배급장에게 맡기기', 'home__stub') : null));
}
