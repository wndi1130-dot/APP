import { describe, expect, it } from 'vitest';
import { chooseCard, createGame, P, viewCard } from '../../src/game';
import { LADDER, protestLine, riotOf, riotTick } from '../../src/game/riot';
import type { Game } from '../../src/game';

// 고조 사다리(정치 흐름 4장, 결정 439): 항의·난장판·마지막 기회의 대응(방치·양보·경비)이 서로 다른 흔적을 남긴다.

/** 정산 한 번: 긴장을 now로 두고 폭동 틱을 돌린다. */
function tick(g: Game, now: number): void {
  g.tension = now;
  riotTick(g, []);
}

function protestCard(g: Game) {
  return g.cards.find(c => c.kind === 'protest');
}

describe('고조 사다리', () => {
  it('항의 없이 한 정산에 난장판 문턱을 넘으면 이번엔 항의만 오고 다음 정산에 난장판이 된다', () => {
    const g = createGame('ladder-skip');
    tick(g, 40);
    tick(g, P.riotFrom + 5);
    expect(riotOf(g).stage).not.toBe(2);
    expect(protestCard(g)?.text).toBe('protest');
    g.cards = [];
    tick(g, P.riotFrom + 5);
    expect(riotOf(g).stage).toBe(2);
  });

  it('미룬 난장판은 그 사이 긴장이 내려가면 오지 않는다', () => {
    const g = createGame('ladder-skip-calm');
    tick(g, 40);
    tick(g, P.riotFrom + 5);
    g.cards = [];
    tick(g, P.protestFrom - 5);
    expect(riotOf(g).pending).toBeUndefined();
    tick(g, P.protestFrom - 5);
    expect(riotOf(g).stage).toBe(0);
  });

  it('항의 카드는 양보·경비·방치 셋이고, 경비대가 반대 이하면 경비가 회색이다', () => {
    const g = createGame('ladder-card');
    tick(g, 40);
    tick(g, P.protestFrom + 2);
    const card = protestCard(g)!;
    const view = viewCard(g, card);
    expect(view.choices.map(c => c.label)).toEqual(['들어준다', '경비대를 세운다', '물리친다']);
    expect(view.choices[1].disabled).toBeUndefined();
    g.comms.guard.rel = -50;
    expect(viewCard(g, card).choices[1].disabled).toBe('경비대가 따르지 않는다');
  });

  it('물리친 항의는 풀리지 않으면 다시 오고, 풀렸으면 오지 않는다', () => {
    const g = createGame('ladder-ignore');
    tick(g, 40);
    tick(g, P.protestFrom + 2);
    expect(chooseCard(g, protestCard(g)!.uid, 2)).toBe(true);
    const at = g.seg;
    for (let i = 1; i < LADDER.ignoreAgain; i += 1) { g.seg = at + i; tick(g, P.protestFrom + 2); }
    expect(protestCard(g)).toBeUndefined();
    g.seg = at + LADDER.ignoreAgain;
    tick(g, P.protestFrom + 2);
    expect(protestCard(g)).toBeTruthy();

    const h = createGame('ladder-ignore-calm');
    tick(h, 40);
    tick(h, P.protestFrom + 2);
    chooseCard(h, protestCard(h)!.uid, 2);
    h.seg += LADDER.ignoreAgain;
    tick(h, P.protestFrom - 10);
    h.seg += 1;
    tick(h, P.protestFrom - 10);
    expect(protestCard(h)).toBeUndefined();
  });

  it('들어주면 잠깐 항의 문턱이 낮아지고 반대편 칸이 서운해한다', () => {
    const g = createGame('ladder-yield');
    tick(g, 40);
    tick(g, P.protestFrom + 2);
    const other = g.comms.front.rel;
    expect(chooseCard(g, protestCard(g)!.uid, 0)).toBe(true);
    expect(protestLine(g)).toBe(P.protestFrom - LADDER.yieldDrop);
    expect(g.comms.front.rel).toBeLessThan(other);
    g.seg += LADDER.yieldSegs;
    expect(protestLine(g)).toBe(P.protestFrom);
  });

  it('경비로 누르면 그 칸 적의·공포가 오르고 경비대 관계가 깎이며, 걸린 약속이 있으면 적의가 하나 더 오른다', () => {
    const g = createGame('ladder-guard');
    tick(g, 40);
    tick(g, P.protestFrom + 2);
    const grudge = g.comms.tail.grudge;
    const fear = g.fear;
    const guardRel = g.comms.guard.rel;
    expect(chooseCard(g, protestCard(g)!.uid, 1)).toBe(true);
    expect(g.comms.tail.grudge).toBe(Math.min(3, grudge + 1));
    expect(g.fear).toBeGreaterThan(fear);
    expect(g.comms.guard.rel).toBeLessThan(guardRel);
    expect(riotOf(g).guardComm).toBe('tail');

    const h = createGame('ladder-guard-promise');
    tick(h, 40);
    tick(h, P.protestFrom + 2);
    h.comms.tail.promise = { kind: 'open', cond: { kind: 'ration', label: '배급', now: false }, label: '배급', due: h.seg + 3, madeSession: 1 } as never;
    const g0 = h.comms.tail.grudge;
    chooseCard(h, protestCard(h)!.uid, 1);
    expect(h.comms.tail.grudge).toBe(Math.min(3, g0 + 2));
  });
});
