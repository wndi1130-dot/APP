import {
  COMMS, COMM_NAME, FETCH_WANT, LOOT_KEYS, LOOT_NAME, P, PLACES, STAY, costLines, crewNames, politicsLines, riskView, stopScene, viewCard,
} from '../game';
import type { Comm, LootKey, StayId } from '../game';
import { cx, h } from './dom';
import { icon } from './icons';
import type { View } from './common';
import { portrait } from './widgets';
import { nameBtn, nameList, shortText } from './names';
import { domesticStopRows, stayLocked } from './domestic'; // S1c 내정 훅

// 결정 카드: 홈 왼쪽의 서류 뭉치에서 꺼내 화면 왼쪽 절반에 펼친다. 오른쪽엔 열차가 그대로 보인다.
// 형식은 수저린식(초상, 짧은 대사, 번호 붙은 선택지). 정차의 필드 결정 카드도 같은 자리에 펼친다.

/** key가 같은 서류는 다시 그려도 미끄러져 들어오지 않고 스크롤도 그대로다. */
function sheet(cls: string, key: string, ...children: (Node | null)[]): HTMLElement {
  return h('aside', { class: cx('sheet', cls), role: 'dialog', 'data-anim': key, 'data-keep-scroll': `sheet-${key}` },
    h('button', { class: 'sheet__fold', 'data-action': 'fold', 'aria-label': '서류 접기' }, '접기'),
    children);
}

function stopCard(view: View): HTMLElement | null {
  const { g } = view;
  const stop = g.stop;
  if (!stop) return null;
  const place = PLACES.find(p => p.id === stop.place) ?? PLACES[0];
  if (stop.done && stop.result) {
    const r = stop.result;
    const gains = LOOT_KEYS.filter(k => r.gains[k]).map(k => `${LOOT_NAME[k]} +${r.gains[k]}`);
    return sheet('sheet--stop', `stop-${g.seg}-result`,
      h('div', { class: 'sheet__head' }, h('div', null, h('span', { class: 'kicker' }, `정차 · ${place.name}`), h('b', { class: 'sheet__title' }, r.passed ? '지나쳤다' : '돌아왔다'))),
      h('ul', { class: 'result' },
        r.passed ? h('li', null, '얻은 것 없음. 석탄을 아꼈다.') : h('li', null, gains.length ? gains.join(' · ') : '빈손'),
        r.injured.length ? h('li', { class: 'is-red' }, '부상: ', nameList(r.injured)) : null,
        r.dead.length ? h('li', { class: 'is-red' }, '죽음: ', nameList(r.dead)) : null,
        r.notes.map(n => h('li', { class: 'sub' }, shortText(n)))),
      h('button', { class: 'btn', 'data-action': 'stop-seen' }, g.cards.length ? `덮는다 (서류 ${g.cards.length}장 더)` : '덮는다'));
  }
  const names = crewNames(g, stop.crewComm, stop.crewSize);
  const promises = COMMS.map(c => g.comms[c].promise ? { c, p: g.comms[c].promise! } : null).filter(Boolean) as { c: Comm; p: NonNullable<typeof g.comms.tail.promise> }[];
  const stopPromises = promises.filter(x => x.p.kind === 'fetch' || x.p.cond.kind === 'target' || x.p.cond.kind === 'skip_dispatch');
  const maxW = Math.max(...LOOT_KEYS.map(k => place.loot[k]));
  const scene = stopScene(g);
  const risk = riskView(g);
  return sheet('sheet--stop', `stop-${g.seg}`,
    h('div', { class: 'sheet__head' },
      h('div', null,
        h('span', { class: 'kicker' }, `${g.seg}구간 정차`),
        h('div', { class: 'sheet__titleline' },
          h('b', { class: 'sheet__title' }, place.name),
          h('span', { class: 'risk', 'aria-label': `위험 ${place.risk}` }, '위험 ', Array.from({ length: 3 }, (_, i) => h('i', { class: cx(i < place.risk && 'is-on') })))))),
    scene ? h('p', { class: 'scene' }, scene.outside, ' ', scene.disembark) : null,
    h('div', { class: 'field field--row' },
      h('span', { class: 'field__label' }, '무엇을'),
      h('div', { class: 'targets' }, LOOT_KEYS.map(k => h('button', {
        class: cx('target', stop.target === k && 'is-on'), 'data-action': 'stop-set', 'data-key': 'target', 'data-value': k,
      }, h('span', null, LOOT_NAME[k]), h('i', { class: 'target__bar', style: `width:${Math.round((place.loot[k] / maxW) * 100)}%` }))))),
    h('div', { class: 'field field--row' },
      h('span', { class: 'field__label' }, '얼마나'),
      (Object.keys(STAY) as StayId[]).map(k => h('button', {
        class: cx('chip', stop.stay === k && 'is-on'), 'data-action': 'stop-set', 'data-key': 'stay', 'data-value': k, disabled: stayLocked(g, k),
      }, STAY[k].name, h('small', null, ` 석탄 −${STAY[k].coal}`)))),
    h('div', { class: 'field field--row' },
      h('span', { class: 'field__label' }, '누구를'),
      COMMS.map(c => h('button', { class: cx('chip', `c-${c}`, stop.crewComm === c && 'is-on'), 'data-action': 'stop-set', 'data-key': 'crewComm', 'data-value': c }, COMM_NAME[c].slice(0, 2))),
      h('span', { class: 'stepper' },
        h('button', { class: 'nav', 'data-action': 'stop-set', 'data-key': 'crewSize', 'data-value': stop.crewSize - 1, 'aria-label': '한 명 덜' }, '−'),
        h('b', { class: 'num' }, `${stop.crewSize}명`),
        h('button', { class: 'nav', 'data-action': 'stop-set', 'data-key': 'crewSize', 'data-value': stop.crewSize + 1, 'aria-label': '한 명 더' }, '+'))),
    h('p', { class: 'crew' }, icon('people'), h('span', null, nameList(names), h('small', null, stop.scout ? ` · 정찰 ${P.scoutSize}명까지 이번 회기 표결에서 빠진다` : ' · 이번 회기 표결에서 빠진다'))),
    // 정찰: 바깥 기척을 알아 위험 줄이 약속이 된다. 대가는 산출과 표.
    h('div', { class: 'field field--row' },
      h('span', { class: 'field__label' }, '정찰'),
      h('button', { class: cx('chip', !stop.scout && 'is-on'), 'data-action': 'stop-set', 'data-key': 'scout', 'data-value': '0' }, '안 한다', h('small', null, ' 위험 모름')),
      h('button', { class: cx('chip', stop.scout && 'is-on'), 'data-action': 'stop-set', 'data-key': 'scout', 'data-value': '1' }, '한다', h('small', null, ` 산출 −${Math.round((1 - P.scoutHaul) * 100)}%, ${P.scoutSize}명 더`))),
    domesticStopRows(view),
    stopPromises.length ? h('ul', { class: 'promises' }, stopPromises.map(x => h('li', null,
      icon(x.p.kind === 'fetch' ? 'fetch' : 'open'), `${COMM_NAME[x.c]}: ${x.p.kind === 'fetch' ? `${FETCH_WANT[x.c].label} 가져오기` : x.p.label}`))) : null,
    h('div', { class: 'sheet__actions' },
      // 정찰조가 본 조짐과 해석. 해석은 준비를 바꿀 때마다 다시 계산되고, 불길하다고 하면 반드시 일어난다.
      h('div', { class: cx('danger', (risk.level === 'dead' || risk.level === 'hurt') && 'is-on'), 'aria-live': 'polite' },
        risk.omen ? h('p', { class: 'danger__omen' }, risk.omen, ' ', h('b', { class: cx('danger__verdict', risk.level && `is-${risk.level}`) }, risk.verdict)) : null,
        risk.unknown ? h('p', { class: 'danger__calm' }, risk.unknown) : null,
        risk.why.length ? h('p', { class: 'danger__why' }, risk.why.join(' · ')) : null),
      h('button', { class: 'btn btn--ghost', 'data-action': 'stop-go', 'data-go': '0' }, '지나친다'),
      h('button', { class: 'btn', 'data-action': 'stop-go', 'data-go': '1' }, '보낸다', icon('arrow'))));
}

export function cardSheet(view: View): HTMLElement | null {
  const { g, ui } = view;
  if (!ui.cardOpen) return null;
  if (g.phase === 'stop' && g.stop && (!g.stop.done || !ui.stopSeen)) return stopCard(view);
  const card = g.cards[0];
  if (!card) return null;
  const v = viewCard(g, card);
  return sheet(card.kind.startsWith('dom:') ? 'sheet--dom' : '', `card-${card.uid}`, // S1c 내정 카드는 놋쇠 클립
    h('div', { class: 'sheet__head' },
      v.speaker ? portrait(v.speaker.name, v.speaker.comm) : h('div', { class: 'portrait portrait--none' }, icon('papers')),
      h('div', null,
        v.speaker ? h('span', { class: 'kicker' }, `${v.speaker.role} · `, nameBtn(v.speaker.name)) : h('span', { class: 'kicker' }, '보고'),
        h('b', { class: 'sheet__title' }, v.title)),
      g.cards.length > 1 ? h('span', { class: 'sheet__more num' }, `+${g.cards.length - 1}`) : null),
    h('p', { class: 'sheet__body' }, shortText(v.body)),
    h('ol', { class: 'choices' }, v.choices.map((ch, i) => {
      const costs = costLines(ch);
      const pol = politicsLines(ch);
      return h('li', null, h('button', {
        class: cx('choice', ch.disabled && 'is-off'), 'data-action': 'choose', 'data-uid': card.uid, 'data-index': i, disabled: !!ch.disabled,
      },
        h('b', { class: 'choice__n num' }, i + 1),
        h('span', { class: 'choice__label' }, shortText(ch.say ?? ch.label), ch.witness ? icon('witness', 'icon icon--witness') : null),
        h('span', { class: 'choice__meta' },
          costs.map(x => h('span', { class: 'cost num' }, x)),
          pol.map(p => h('span', { class: `pol pol--${p.tone}` }, p.text)),
          ch.disabled ? h('span', { class: 'pol pol--gray' }, ch.disabled) : null)));
    })));
}

export function isLoot(value: string): value is LootKey {
  return (LOOT_KEYS as readonly string[]).includes(value);
}
