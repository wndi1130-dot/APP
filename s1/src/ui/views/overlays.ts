import { cardById, characterFor, dispatchCandidates, representativeOf } from '../model/dummy';
import type { DummyCard } from '../model/dummy';
import { PHASE_LABELS } from '../model/flow';
import { GROUP_META, METRIC_LABELS, STANCE_LABELS } from '../model/groups';
import type { GroupId } from '../model/groups';
import { effectSummary } from '../model/format';
import { groupStandings, stanceSeats } from '../model/standings';
import { cx, h, pct } from '../dom';
import { button, chip, stub } from './common';
import type { View } from './common';

// 겹쳐 뜨는 것들: 불만·지지 패널(가운데 맨 위에서 펼침), 결정 카드(아래에서 올라옴), 메뉴, 알림.

/** 관계(−100~100)를 가운데 0에서 왼쪽(불만) 또는 오른쪽(지지)으로 채우는 막대. */
export function relationBar(relation: number): HTMLElement {
  const width = pct(Math.abs(relation));
  const side = relation < 0 ? 'is-neg' : 'is-pos';
  return h('span', { class: 'rel', role: 'img', 'aria-label': `관계 ${relation}` },
    h('span', { class: 'rel__half rel__half--neg' }, relation < 0 ? h('span', { class: cx('rel__fill', side), style: `width:${width}` }) : null),
    h('span', { class: 'rel__axis', 'aria-hidden': 'true' }),
    h('span', { class: 'rel__half rel__half--pos' }, relation > 0 ? h('span', { class: cx('rel__fill', side), style: `width:${width}` }) : null));
}

export function factionPanel(view: View): HTMLElement | null {
  if (view.ui.panel !== 'factions') return null;
  const standings = groupStandings(view.app.game);
  const totals = stanceSeats(standings);
  return h('div', { class: cx('sheet-panel', view.ui.enter === 'panel' && 'enter-drop'), role: 'dialog', 'aria-label': '집단별 불만·지지', 'data-test': 'faction-panel', 'data-anim': '' },
    h('div', { class: 'sheet-panel__head' },
      h('h2', { class: 'sheet-panel__title' }, '집단별 불만·지지'),
      h('span', { class: 'sheet-panel__meta' },
        `불만 ${totals.discontent}석 · 중립 ${totals.neutral}석 · 지지 ${totals.support}석`)),
    h('table', { class: 'standings' },
      h('thead', null, h('tr', null,
        h('th', { scope: 'col', class: 'name' }, '집단'),
        h('th', { scope: 'col', class: 'num' }, '인구'),
        h('th', { scope: 'col', class: 'num' }, '의석'),
        h('th', { scope: 'col', class: 'bar' }, h('span', { class: 'standings__axis' }, h('span', null, '불만'), h('span', null, '지지'))),
        h('th', { scope: 'col', class: 'val' }, '관계'),
        h('th', { scope: 'col', class: 'who' }, '지도자'),
        h('th', { scope: 'col', class: 'need' }, '요구'))),
      h('tbody', null, standings.map(standing => {
        const meta = GROUP_META[standing.id as GroupId];
        const leader = standing.leaderId ? characterFor(standing.leaderId) : undefined;
        return h('tr', { class: `is-${standing.stance}` },
          h('th', { scope: 'row', class: 'name' }, chip(standing.id), h('span', null, meta.name),
            meta.kind === 'faction' ? h('span', { class: 'tag' }, '세력') : null),
          h('td', { class: 'num' }, `${standing.population}`),
          h('td', { class: 'num' }, `${standing.seats}`),
          h('td', { class: 'bar' }, relationBar(standing.relation)),
          h('td', { class: 'val' }, `${STANCE_LABELS[standing.stance]} `, h('b', null, String(Math.abs(standing.relation)))),
          h('td', { class: 'who' }, leader?.name ?? '—'),
          h('td', { class: 'need' }, standing.need ? METRIC_LABELS[standing.need] : '이념'));
      }))),
    h('div', { class: 'sheet-panel__foot' },
      h('p', { class: 'sheet-panel__note' }, '막대는 열차장과의 관계(−100~+100). 요구는 가장 나쁜 처지에서 나온다.'),
      stub(view, 'S1a', '정치 행동: 거래 수단 다섯', 'stub--inline')));
}

function speakerLine(card: DummyCard): string {
  const speaker = card.event.speaker;
  if (Object.hasOwn(GROUP_META, speaker)) {
    const rep = representativeOf(speaker as Parameters<typeof representativeOf>[0]);
    return `${GROUP_META[speaker as GroupId].name} · ${rep.name}(${rep.roleLabel})`;
  }
  return speaker;
}

const CARD_KIND: Readonly<Record<string, string>> = Object.freeze({
  travel: '사건', stop: '필드 결정', council: '회기', settle: '정산',
});

export function decisionCard(view: View): HTMLElement | null {
  const pending = view.app.card;
  if (!pending || pending.collapsed) return null;
  const card = cardById(pending.id);
  const choices = card.event.choices;
  const dispatchLines: string[] = [];
  const previews = choices.map((choice, index) => {
    const parts = effectSummary(choice.effects);
    const order = card.dispatch?.[index];
    if (order) {
      const picked = dispatchCandidates(view.app.game, order);
      parts.unshift(`${picked.length}명 ${order.segments}구간 파견`);
      dispatchLines.push(`보낼 사람(추천): ${picked.map(id => view.profiles[id]?.name ?? id).join(', ')}`);
    }
    return parts.length > 0 ? parts.join(' · ') : '변화 없음';
  });
  return h('div', {
    class: cx('card', view.ui.enter === 'card' && 'enter-rise'),
    role: 'dialog', 'aria-label': '결정 카드', 'data-test': 'decision-card', 'data-anim': '',
  },
  h('div', { class: 'card__head' },
    h('span', { class: 'card__kind' }, `${PHASE_LABELS[card.event.phase as keyof typeof PHASE_LABELS]} · ${CARD_KIND[card.event.phase]}`),
    h('span', { class: 'card__speaker' }, speakerLine(card)),
    h('span', { class: 'card__spacer' }),
    button('접기', 'card-collapse', { variant: 'quiet', test: 'card-collapse', ariaLabel: '카드를 접고 열차 보기' })),
  h('p', { class: 'card__body' }, card.event.body),
  dispatchLines.length > 0 ? h('p', { class: 'card__people' }, dispatchLines[0]) : null,
  h('div', { class: cx('card__choices', `has-${choices.length}`) },
    choices.map((choice, index) => h('button', {
      type: 'button', class: 'choice', 'data-action': 'choose', 'data-index': String(index), 'data-test': `choice-${index}`,
    },
    h('span', { class: 'choice__label' }, choice.label),
    h('span', { class: 'choice__effects' }, previews[index])))));
}

function formatTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

export function menuPopover(view: View): HTMLElement | null {
  if (view.ui.panel !== 'menu') return null;
  const slot = view.ui.slot;
  const slotText = slot
    ? `${slot.segment}구간 ${PHASE_LABELS[slot.phase]} · ${formatTime(slot.savedAt)}`
    : '저장 없음';
  return h('div', { class: cx('menu', view.ui.enter === 'menu' && 'enter-rise'), role: 'menu', 'aria-label': '메뉴', 'data-test': 'menu-popover', 'data-anim': '' },
    h('p', { class: 'menu__slot' }, h('span', { class: 'menu__slot-label' }, '저장 슬롯'), h('span', null, slotText)),
    button('저장하기', 'save', { test: 'save' }),
    button('불러오기', 'load', { test: 'load', disabled: !slot }),
    button(view.ui.confirmReset ? '한 번 더 누르면 처음부터' : '처음부터(같은 시드)', 'reset', {
      test: 'reset', extra: view.ui.confirmReset ? 'is-confirm' : undefined,
    }),
    button('디버그 화면', 'open-debug', { test: 'debug' }));
}

export function toast(view: View): HTMLElement | null {
  if (!view.ui.toast) return null;
  return h('div', { class: 'toast', role: 'status', 'aria-live': 'polite', 'data-test': 'toast' }, view.ui.toast);
}

export function scrim(view: View): HTMLElement | null {
  if (view.ui.panel === null) return null;
  return h('div', { class: 'scrim', 'data-action': 'close-panel', 'aria-hidden': 'true' });
}
