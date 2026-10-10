import { describe, expect, it } from 'vitest';
import { chooseCard, COMMS, createGame, migrateEventPicks, TRAVEL_EVENTS, viewCard } from '../../src/game';
import type { Card, CardView, Game } from '../../src/game';

// 시스템 통합 보고서(PR 137) A03: 사건 기억(지난번에 뭘 골랐나)이 선택지 라벨 글을 열쇠로 쓰면
// 라벨을 고치는 순간 기억이 끊긴다. 선택지에 고정 id를 두고 옛 저장은 읽을 때 id로 잇는다.

function setup(seed: string): Game {
  const g = createGame(seed);
  g.med = 20;
  g.coal = 60;
  return g;
}

function play(g: Game, card: Omit<Card, 'uid'>, index: number): CardView {
  const uid = g.nextCardUid++;
  g.cards.push({ uid, ...card });
  const view = viewCard(g, g.cards[g.cards.length - 1]);
  expect(chooseCard(g, uid, index)).toBe(true);
  return view;
}

/** fn을 도는 동안 모든 이동 사건의 선택지 라벨 글을 고친 것처럼 만든다(사람이 라벨 문장을 손본 상황). */
function withEditedLabels<T>(fn: () => T): T {
  const saved = TRAVEL_EVENTS.map(e => e.view);
  TRAVEL_EVENTS.forEach((e, i) => {
    e.view = (g, past) => {
      const v = saved[i](g, past);
      return { ...v, choices: v.choices.map(c => ({ ...c, label: `${c.label} (고친 글)` })) };
    };
  });
  try { return fn(); } finally { TRAVEL_EVENTS.forEach((e, i) => { e.view = saved[i]; }); }
}

const secondBody = (id: string, index: number): string => {
  const g = setup(`ids-${id}`);
  play(g, { kind: 'travel', text: id }, index);
  return viewCard(g, { uid: 9999, kind: 'travel', text: id }).body;
};

describe('A03 사건 기억은 라벨 글이 아니라 선택지 id로 잇는다', () => {
  it('선택지 라벨 글을 고쳐도 지난번 고른 것에 따른 본문이 그대로다', () => {
    for (const ev of TRAVEL_EVENTS) {
      const n = viewCard(setup(`ids-${ev.id}`), { uid: 1, kind: 'travel', text: ev.id }).choices.length;
      for (let k = 0; k < n; k += 1) {
        const plain = secondBody(ev.id, k);
        const edited = withEditedLabels(() => secondBody(ev.id, k));
        expect(edited, `${ev.id} 선택지 ${k}`).toBe(plain);
      }
    }
  });

  it('고르면 사건 기억에는 라벨이 아니라 id가 남는다', () => {
    const g = setup('ids-pick');
    const first = play(g, { kind: 'travel', text: 'tail_cold' }, 0);
    expect(first.choices[0].id).toBe('fuel_front');
    expect(g.eventLog.tail_cold.pick).toBe('fuel_front');
  });

  it('기억을 읽는 사건(이동 사건·요구·부탁·구조·물림)의 선택지는 모두 id가 있고 한 카드 안에서 겹치지 않는다', () => {
    const g = setup('ids-all');
    const views: [string, CardView][] = [];
    for (const ev of TRAVEL_EVENTS) views.push([ev.id, viewCard(g, { uid: 1, kind: 'travel', text: ev.id })]);
    for (const c of COMMS) {
      views.push([`demand:${c}`, viewCard(g, { uid: 1, kind: 'demand', text: '', comm: c })]);
      views.push([`favor:${c}`, viewCard(g, { uid: 1, kind: 'favor', text: '', comm: c })]);
    }
    views.push(['rescue', viewCard(g, { uid: 1, kind: 'rescue', text: '' })]);
    views.push(['bitten', viewCard(g, { uid: 1, kind: 'bitten', text: '', who: '대원' })]);
    expect(views.length).toBeGreaterThan(10);
    for (const [name, v] of views) {
      const ids = v.choices.map(c => c.id);
      expect(ids.every(Boolean), `${name} id 빠진 선택지`).toBe(true);
      expect(new Set(ids).size, `${name} id 겹침`).toBe(ids.length);
    }
  });

  it('옛 저장(라벨이 pick으로 남은 판)은 읽을 때 id로 이어져 같은 본문이 나온다', () => {
    const fresh = setup('ids-old');
    play(fresh, { kind: 'travel', text: 'tail_cold' }, 0);
    const want = viewCard(fresh, { uid: 9999, kind: 'travel', text: 'tail_cold' }).body;

    const old = setup('ids-old');
    old.eventLog.tail_cold = { n: 1, seg: old.seg, pick: '앞칸 연료를 덜어 온다' };
    migrateEventPicks(old);
    expect(old.eventLog.tail_cold.pick).toBe('fuel_front');
    expect(viewCard(old, { uid: 9999, kind: 'travel', text: 'tail_cold' }).body).toBe(want);
  });

  it('예전 급수탑 라벨 "꼬리칸이 눈을 녹인다"와 요구의 "거절한다"도 잇는다', () => {
    const g = setup('ids-old2');
    g.eventLog.water_tower = { n: 1, seg: 1, pick: '꼬리칸이 눈을 녹인다' };
    g.eventLog['demand:tail'] = { n: 1, seg: 1, pick: '거절한다' };
    migrateEventPicks(g);
    expect(g.eventLog.water_tower.pick).toBe('snow_melt');
    expect(g.eventLog['demand:tail'].pick).toBe('refuse');
  });

  it('콘텐츠 사건과 이미 id인 기억은 건드리지 않고 되풀이해도 같다', () => {
    const g = setup('ids-idem');
    g.eventLog['content:ev_x'] = { n: 1, seg: 1, pick: '거절한다' };
    g.eventLog.tail_cold = { n: 1, seg: 1, pick: 'fuel_front' };
    migrateEventPicks(g);
    migrateEventPicks(g);
    expect(g.eventLog['content:ev_x'].pick).toBe('거절한다');
    expect(g.eventLog.tail_cold.pick).toBe('fuel_front');
  });
});
