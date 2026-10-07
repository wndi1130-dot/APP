import {
  COMMS, COMM_NAME, COMM_SHORT, CREW_COMMS, FETCH_WANT, LOOT_KEYS, LOOT_NAME, P, PLACES, SCOUT_DEEP, STAY, costLines, crewNames, crewPreview, politicsLines, riskView, stopScene, viewCard,
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
      CREW_COMMS.map(c => h('button', { class: cx('chip', `c-${c}`, stop.crewComm === c && 'is-on'), 'data-action': 'stop-set', 'data-key': 'crewComm', 'data-value': c }, COMM_NAME[c].slice(0, 2))),
      h('span', { class: 'stepper' },
        h('button', { class: 'nav', 'data-action': 'stop-set', 'data-key': 'crewSize', 'data-value': stop.crewSize - 1, 'aria-label': '한 명 덜' }, '−'),
        h('b', { class: 'num' }, `${stop.crewSize}명`),
        h('button', { class: 'nav', 'data-action': 'stop-set', 'data-key': 'crewSize', 'data-value': stop.crewSize + 1, 'aria-label': '한 명 더' }, '+'))),
    crewCost(view),
    h('p', { class: 'crew' }, icon('people'), h('span', null, nameList(names), h('small', null, ' · 돌아오면 지쳐 쓰러져서 이번 회기 표결에 빠진다'))),
    domesticStopRows(view),
    stopPromises.length ? h('ul', { class: 'promises' }, stopPromises.map(x => h('li', null,
      icon(x.p.kind === 'fetch' ? 'fetch' : 'open'), `${COMM_NAME[x.c]}: ${x.p.kind === 'fetch' ? `${FETCH_WANT[x.c].label} 가져오기` : x.p.label}`))) : null,
    h('div', { class: 'sheet__actions' },
      // 정찰조가 본 조짐과 해석. 해석은 준비를 바꿀 때마다 다시 계산되고, 불길하다고 하면 반드시 일어난다.
      h('div', { class: cx('danger', (risk.level === 'dead' || risk.level === 'hurt') && 'is-on'), 'aria-live': 'polite' },
        scoutReport(view),
        risk.omen ? h('p', { class: 'danger__omen' }, risk.omen, ' ', h('b', { class: cx('danger__verdict', risk.level && `is-${risk.level}`) }, risk.verdict)) : null,
        risk.unknown ? h('p', { class: 'danger__calm' }, risk.unknown) : null,
        risk.why.length ? h('p', { class: 'danger__why' }, risk.why.join(' · ')) : null),
      // 정찰은 먼저 보내는 일이다(2026-10-07 사용자). 정찰조도 다치거나 못 돌아올 수 있고, 돌아오면 바깥 기척을 보고한다.
      // 늘 보이게 결정 단추 줄에 둔다(가로 화면에서 본문은 스크롤된다).
      scoutSend(view),
      h('button', { class: 'btn btn--ghost', 'data-action': 'stop-go', 'data-go': '0' }, '지나친다'),
      h('button', { class: 'btn', 'data-action': 'stop-go', 'data-go': '1' }, '보낸다', icon('arrow'))));
}

/** 작업조 값(6.4): 낸 칸 노출이 오르고, 늘 하던 일이 아니면 관계가 깎이고, 안 나간 칸은 쉰다. 보내기 전에 숫자로 보인다. */
function crewCost(view: View): HTMLElement {
  const { g } = view;
  const c = g.stop!.crewComm;
  const pv = crewPreview(g, c);
  return h('p', { class: 'crew-cost' },
    h('span', null, `${COMM_SHORT[c]} 노출 `, h('b', { class: 'num' }, `${pv.from} → ${pv.to}`)),
    pv.rel ? h('span', null, ` · 관계 −${-pv.rel}`) : null,
    pv.haul < 1 ? h('span', null, ` · 손에 안 익어 산출 −${Math.round((1 - pv.haul) * 100)}%`) : null,
    pv.rest.length ? h('small', null, ` · 쉬는 칸 ${pv.rest.map(o => COMM_SHORT[o]).join('·')} 노출 −${P.crewRest}`) : null);
}

/** 정찰 보내기 단추. 다녀온 뒤엔 없다. */
function scoutSend(view: View): HTMLElement | null {
  const stop = view.g.stop!;
  if (stop.scoutReport) return null;
  return h('button', { class: 'btn btn--ghost scout__send', 'data-action': 'stop-set', 'data-key': 'scout', 'data-value': '1',
    title: `${COMM_NAME[stop.crewComm].slice(0, 2)} ${P.scoutSize}명이 먼저 들어간다. 다치거나 못 돌아올 수 있고, 작업조 산출이 ${Math.round((1 - P.scoutHaul) * 100)}% 준다.` },
  icon('eye'), '정찰 먼저');
}

/** 정찰 보고. 한 번 미끄러져 들어온다(data-anim). 보내기 전엔 무엇을 거는지 적는다. */
function scoutReport(view: View): HTMLElement {
  const { g } = view;
  const stop = g.stop!;
  const rep = stop.scoutReport;
  if (!rep) {
    return h('p', { class: 'scout-cost' }, `정찰: ${COMM_NAME[stop.crewComm].slice(0, 2)} ${P.scoutSize}명 · 다치거나 못 돌아올 수 있다 · 산출 −${Math.round((1 - P.scoutHaul) * 100)}%`);
  }
  const back = rep.names.filter(n => !rep.dead.includes(n));
  return h('p', { class: cx('scout-report', (rep.dead.length > 0 || rep.hurt.length > 0) && 'is-hurt'), 'data-anim': `scout-${g.seg}` },
    h('b', null, back.length ? '정찰조가 돌아왔다' : '정찰조가 돌아오지 않았다'), ' ',
    back.length ? nameList(back) : null,
    rep.hurt.length ? h('span', { class: 'is-red' }, ' · 크게 다침 ', nameList(rep.hurt)) : null,
    rep.dead.length ? h('span', { class: 'is-red' }, ' · 못 돌아옴 ', nameList(rep.dead)) : null,
    // 어디서 당했는지: 위험은 그 자리에 있고, 짧게 적게 보내면 비켜 갈 수 있다고 읽힌다.
    rep.hurt.length || rep.dead.length ? h('small', { class: 'scout-report__where' },
      ` ${SCOUT_DEEP[stop.place] ?? '안쪽 깊숙이'}까지 들어갔다가 ${rep.hurt.length ? '당했다' : '소식이 끊겼다'}.`) : null);
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
    v.faces?.length ? h('div', { class: 'faces' }, v.faces.map(n => h('span', { class: 'face' }, portrait(n, card.comm), nameBtn(n)))) : null,
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
