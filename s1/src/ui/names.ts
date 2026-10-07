import { COMMS, COMM_NAME, PROFILES, REP_ROLE, TRAIT_NAME, currentAgenda, relationLine, stance } from '../game';
import type { Comm, Game } from '../game';
import { cx, h } from './dom';
import { portrait } from './widgets';

// 이름 표시: 화면에는 성을 빼고 이름만 쓴다. 이름을 누르면 전체 이름과 간단한 정보가 뜬다
// (2026-10-07 사용자 결정). 프로필 이름은 모두 '이름 성' 두 낱말이다.

interface ProfileInfo { name: string; name_original?: string; age: number; community: Comm; hometown: string; like: string; dislike: string }

const BY_NAME = new Map((PROFILES as unknown as ProfileInfo[]).map(p => [p.name, p]));
const FULL_NAMES = [...BY_NAME.keys()].sort((a, b) => b.length - a.length);
const NAME_RE = new RegExp(FULL_NAMES.map(n => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'), 'g');

export function given(name: string): string {
  return name.trim().split(/\s+/)[0] ?? name;
}

/** 문장 안의 전체 이름을 이름만으로 줄인다(일지, 카드 본문, 알림). */
export function shortText(text: string): string {
  return FULL_NAMES.length ? text.replace(NAME_RE, m => given(m)) : text;
}

/** 누르면 그 사람 정보가 뜨는 이름. */
export function nameBtn(name: string, cls?: string): HTMLElement {
  return h('button', { class: cx('name', cls), type: 'button', 'data-action': 'person', 'data-name': name, 'aria-label': `${name} 정보` }, given(name));
}

/** 이름 목록을 쉼표로 이어 단추로 늘어놓는다. */
export function nameList(names: string[]): (Node | string)[] {
  const out: (Node | string)[] = [];
  names.forEach((n, i) => {
    if (i > 0) out.push(', ');
    out.push(nameBtn(n));
  });
  return out;
}

/** 회기 중이면 이 대표가 지금 안건에 어느 쪽인지. 비밀 투표 법이 서 있어도 대표의 말은 들린다. */
export function agendaLine(g: Game, c: Comm, tag: 'li' | 'span' = 'li'): HTMLElement | null {
  const agenda = g.phase === 'council' && g.council && !g.council.result ? currentAgenda(g) : null;
  if (!agenda) return null;
  const score = stance(g, c, agenda).score;
  const text = score >= 2 ? '이 안건에 찬성한다.' : score >= 1 ? '이 안건에 찬성 쪽으로 기운다.' : score <= -2 ? '이 안건에 반대한다.' : score <= -1 ? '이 안건에 반대 쪽으로 기운다.' : '이 안건을 두고 망설인다.';
  return h(tag, { class: score >= 1 ? 'is-blue' : score <= -1 ? 'is-red' : '' }, text);
}

function leaderOf(g: Game, name: string): Comm | null {
  return COMMS.find(c => g.comms[c].leader.name === name) ?? null;
}

export function personCard(g: Game, name: string): HTMLElement {
  const p = BY_NAME.get(name);
  const lead = leaderOf(g, name);
  const comm = lead ?? p?.community;
  const dead = g.deaths.includes(name);
  const facts: (HTMLElement | null)[] = [
    h('li', null, `${comm ? COMM_NAME[comm] : '소속 모름'}${p ? ` · ${p.age}세` : ''}`),
    lead ? h('li', null, `${REP_ROLE[lead]} · ${(() => {
      const l = g.comms[lead].leader;
      return l.traitShown === 0 ? '성향 가려짐' : l.traitShown === 1 ? `아마 ${TRAIT_NAME[l.trait]}` : TRAIT_NAME[l.trait];
    })()}`) : null,
    comm ? h('li', { class: cx('person__rel', g.comms[comm].rel >= 15 && 'is-blue', g.comms[comm].rel <= -15 && 'is-red') },
      lead ? relationLine(g.comms[comm].rel) : `${COMM_NAME[comm]} 분위기: ${relationLine(g.comms[comm].rel)}`) : null,
    lead ? agendaLine(g, lead) : null,
    p?.hometown ? h('li', null, `고향 ${p.hometown}`) : null,
    p?.like ? h('li', null, `좋아함: ${p.like}`) : null,
    p?.dislike ? h('li', null, `싫어함: ${p.dislike}`) : null,
    dead ? h('li', { class: 'is-red' }, '죽었다') : null,
  ];
  return h('div', { class: 'person', role: 'dialog', 'aria-label': `${name} 정보` },
    h('div', { class: 'drop__head' },
      portrait(name, comm ?? undefined),
      h('div', null,
        h('b', null, name),
        p?.name_original ? h('div', { class: 'sub' }, p.name_original) : null),
      h('button', { class: 'x', 'data-action': 'person', 'data-name': '', 'aria-label': '닫기' }, '×')),
    h('ul', { class: 'person__facts' }, facts));
}
