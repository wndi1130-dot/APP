import { describe, expect, it } from 'vitest';
import {
  attachApprentice, chooseCard, COMMS, createGame, createS1cGame, enableArrivals, handsNow, handsOffered, handsSettle, HANDS, isGone, newcomerComm,
  PROFILES, situation, startPrologue, storyOf, takeIn, trailAfterStop, TRAIL, viewCard,
} from '../../src/game';
import type { Game } from '../../src/game';

// 사람을 내려놓았을 때와 받아들이는 사람(결정 425 카드 3·4, carry_people.md 3.3·3.4):
// 남은 칸이 일을 나눠 지면 노출이 오르고, 두고 떠난 사람의 흔적이 뒤 정차에 한 번 보이며 다시 태울 길이 한 번 열리고,
// 늦게 탄 사람이 손 몫에 들고 견습 후보가 된다.

function scalePop(g: Game, k: number): void {
  for (const c of COMMS) g.comms[c].pop = Math.round(g.comms[c].pop * k);
}

function pick(g: Game, label: string): void {
  const card = g.cards[0];
  const i = viewCard(g, card).choices.findIndex(c => c.label === label);
  expect(i, `${card.kind}: ${label}`).toBeGreaterThanOrEqual(0);
  expect(chooseCard(g, card.uid, i)).toBe(true);
}

/** 서막에서 약속하지 않고 바로 돌아서서 다섯을 두고 떠난 판 */
function leftFive(seed: string): Game {
  const g = createGame(seed);
  startPrologue(g);
  pick(g, '약속하지 않는다');
  pick(g, '바로 돌아선다');
  return g;
}

describe('남은 칸이 일을 나눠 진다', () => {
  it('시작 열차는 아무 칸도 더 지치지 않는다', () => {
    const g = createGame('drop-start');
    const h = handsNow(g);
    for (const c of COMMS) expect(h.expose?.[c]).toBe(0);
  });

  it('사람이 줄수록 남은 칸의 노출이 오르고, 일이 비기 시작하면 더 오르지 않는다', () => {
    let prev = -1;
    for (let k = 1; k >= 0.2; k -= 0.05) {
      const g = createGame('drop-mono');
      scalePop(g, k);
      const e = handsNow(g).expose?.engine ?? 0;
      expect(e).toBeGreaterThanOrEqual(prev - 1e-9);
      expect(e).toBeLessThanOrEqual(HANDS.loadExpose * (1 - HANDS.loadFree) + 1e-9);
      prev = e;
    }
    expect(prev).toBeCloseTo(HANDS.loadExpose * (1 - HANDS.loadFree));
  });

  it('손을 거둔 칸은 거둔 만큼 덜 지친다', () => {
    const g = createGame('drop-will');
    scalePop(g, 0.6);
    g.comms.guard.rel = 30;
    g.comms.tail.rel = -45;
    const e = handsNow(g).expose!;
    expect(e.tail).toBeCloseTo(e.guard * HANDS.willHostile);
  });

  it('정산 끝에 둔 노출을 칸 처지가 읽는다', () => {
    const g = createGame('drop-sit');
    const ex0 = situation(g, 'engine')[3];
    scalePop(g, 0.6);
    handsSettle(g, []);
    expect(situation(g, 'engine')[3]).toBeCloseTo(Math.min(100, ex0 + (g.hands?.expose?.engine ?? 0)));
    expect(g.hands?.expose?.engine).toBeGreaterThan(0);
  });
});

describe('두고 떠난 사람의 흔적', () => {
  it('두고 떠나면 흔적이 생기고, 떠난 뒤 두 구간이 지난 첫 정차에 한 번만 뜬다', () => {
    const g = leftFive('trail-once');
    expect(g.trail?.names).toHaveLength(5);
    expect(trailAfterStop(g)).toBe(false);
    g.seg += TRAIL.after;
    g.cards = [];
    expect(trailAfterStop(g)).toBe(true);
    expect(g.cards.map(c => c.kind)).toEqual(['pro_trail']);
    expect(trailAfterStop(g)).toBe(false);
  });

  it('기다렸다 태우면 다섯이 돌아오고 석탄을 쓰며 꼬리칸 관계가 조금 오른다', () => {
    const g = leftFive('trail-wait');
    const names = [...g.trail!.names];
    g.seg += TRAIL.after;
    g.cards = [];
    trailAfterStop(g);
    const pop0 = g.comms.tail.pop;
    const coal0 = g.coal;
    const rel0 = g.comms.tail.rel;
    pick(g, '기다렸다 태운다');
    expect(g.comms.tail.pop).toBe(pop0 + 5);
    expect(g.coal).toBe(coal0 - TRAIL.coal);
    expect(g.comms.tail.rel).toBe(rel0 + TRAIL.rel);
    for (const n of names) expect(isGone(g, n)).toBe(false);
    expect(storyOf(g).flags.trail).toBe('back');
  });

  it('쪽지만 남기면 그들은 걸어서 뒤를 따르고 다시 뜨지 않는다', () => {
    const g = leftFive('trail-note');
    const names = [...g.trail!.names];
    g.seg += TRAIL.after;
    g.cards = [];
    trailAfterStop(g);
    pick(g, '쪽지를 남긴다');
    for (const n of names) expect(isGone(g, n)).toBe(true);
    expect(storyOf(g).flags.trail).toBe('note');
    g.seg += 3;
    expect(trailAfterStop(g)).toBe(false);
  });

  it('석탄이 모자라면 기다렸다 태울 수 없고 쪽지만 남길 수 있다', () => {
    const g = leftFive('trail-poor');
    g.seg += TRAIL.after;
    g.cards = [];
    trailAfterStop(g);
    g.coal = TRAIL.coal - 1;
    const v = viewCard(g, g.cards[0]);
    expect(v.choices.find(c => c.label === '기다렸다 태운다')?.disabled).toBeTruthy();
    expect(v.choices.find(c => c.label === '쪽지를 남긴다')?.disabled).toBeFalsy();
  });

  it('아무도 두고 오지 않았거나 선 열차에서는 뜨지 않는다', () => {
    const g = createGame('trail-none');
    g.seg += 5;
    expect(trailAfterStop(g)).toBe(false);
    const h = leftFive('trail-stranded');
    h.seg += TRAIL.after;
    h.stranded = { since: h.seg } as Game['stranded'];
    expect(trailAfterStop(h)).toBe(false);
  });
});

describe('받아들이는 사람', () => {
  it('받은 사람은 그 칸이 내는 손에 든다', () => {
    const g = createGame('take-hands');
    enableArrivals(g);
    const before = handsOffered(g, 'tail');
    takeIn(g, 'tail', [4]);
    expect(handsOffered(g, 'tail')).toBeGreaterThan(before);
  });

  it('늦게 탄 사람이 있으면 견습생 후보 넷째 줄이 열리고, 명부에 없는 이름의 견습생이 된다', () => {
    const g = createS1cGame('take-pupil');
    const card = { uid: 9001, kind: 'dom:pupil', text: 'engine' } as Game['cards'][number];
    expect(newcomerComm(g)).toBeNull();
    expect(viewCard(g, card).choices.some(c => c.label === '늦게 탄 사람에게')).toBe(false);
    enableArrivals(g);
    takeIn(g, 'tail', [3]);
    expect(newcomerComm(g)).toBe('tail');
    expect(viewCard(g, card).choices.some(c => c.label === '늦게 탄 사람에게')).toBe(true);
    const p = attachApprentice(g, 'engine', 'new', true);
    expect(p?.comm).toBe('tail');
    expect(PROFILES.some(x => x.name === p?.name)).toBe(false);
    expect(g.dom?.people.filter(x => x.name === p?.name)).toHaveLength(1);
  });
});
