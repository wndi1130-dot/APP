import { describe, expect, it } from 'vitest';
import { chooseCard, COMMS, createGame, createS1cGame, P, PROFILES, viewCard } from '../../src/game';
import type { Game } from '../../src/game';
import { refreshSit } from '../../src/game/domestic/sit';
import { RIOT_TUNE, riotOf, riotTick } from '../../src/game/riot';
import { activeWounds } from '../../src/game/wounds';

// 폭동(난장판) 규칙(결정 276): 상향 교차에만 켜짐, 항의 카드, 번짐 한 칸, 일손, 자리 잃음, 끄는 틈.

const fresh = (seed: string, s1c = true): Game => { const g = s1c ? createS1cGame(seed) : createGame(seed); g.cards = []; return g; };
const tick = (g: Game, tension: number): string[] => { g.tension = tension; const notes: string[] = []; riotTick(g, notes); return notes; };
const protests = (g: Game) => g.cards.filter(c => c.kind === 'protest');
const answer = (g: Game, label: string): void => {
  const card = protests(g)[0];
  const idx = viewCard(g, card).choices.findIndex(c => c.label === label);
  expect(idx, label).toBeGreaterThanOrEqual(0);
  expect(chooseCard(g, card.uid, idx)).toBe(true);
};
const ageOf = (name: string): number => PROFILES.find(p => p.name === name)!.age;

describe('켜지는 조건', () => {
  it('난장판은 긴장이 문턱을 위로 넘는 정산에만 켜지고 되돌림 직후엔 켜지지 않는다', () => {
    const g = fresh('rt-1');
    riotOf(g).prev = 69;
    tick(g, 70);
    expect(riotOf(g).stage).toBe(2);
    expect(riotOf(g).riots).toBe(1);
    expect(protests(g).map(c => c.text)).toEqual(['riot']);
    const h = fresh('rt-2');
    riotOf(h).prev = 100;
    tick(h, 80);
    expect(riotOf(h).stage).not.toBe(2);
    expect(riotOf(h).riots).toBe(0);
    expect(protests(h)).toHaveLength(0);
  });

  it('항의 카드는 긴장이 50을 위로 넘는 정산마다 한 장 뜬다', () => {
    const g = fresh('rt-3');
    riotOf(g).prev = 49;
    tick(g, 50);
    expect(protests(g).map(c => c.text)).toEqual(['protest']);
    expect(riotOf(g).stage).toBe(1);
    expect(riotOf(g).riots).toBe(0);
    g.cards = [];
    tick(g, 55);
    expect(protests(g)).toHaveLength(0);
    tick(g, 40);
    expect(riotOf(g).stage).toBe(0);
    tick(g, 52);
    expect(protests(g)).toHaveLength(1);
    expect(riotOf(g).protests).toBe(2);
  });
});

describe('불과 일손', () => {
  it('난장판이 이어지는 동안 정산마다 이웃 한 칸씩 번지고 일손은 끄지 못하며 칸 수는 그대로다', () => {
    const g = fresh('rt-4');
    const r = riotOf(g);
    r.prev = 69;
    tick(g, 70);
    g.cards = [];
    expect(r.fire).toHaveLength(1);
    for (let k = 2; k <= 11; k += 1) {
      const before = [...r.fire];
      tick(g, 72);
      g.cards = [];
      expect(r.fire).toHaveLength(before.length + 1);
      const added = r.fire.find(c => !before.includes(c))!;
      const cars = g.dom!.cars;
      expect(before.some(b => Math.abs(cars.indexOf(b) - cars.indexOf(added)) === 1)).toBe(true);
      expect(r.scorched.length).toBeLessThanOrEqual(k);
    }
    expect(r.fire).toHaveLength(11);
    expect(g.dom!.cars).toHaveLength(11);
  });

  it('난장판이 끊기면 새 불 없이 번짐 뒤 일손 둘이 끄고 엎어진 물건은 치운다', () => {
    const g = fresh('rt-5');
    const r = riotOf(g);
    r.prev = 69;
    tick(g, 70);
    tick(g, 72);
    tick(g, 72);
    expect(r.fire).toHaveLength(3);
    answer(g, '들어준다');
    expect(r.stage).not.toBe(2);
    const fell = r.fell;
    tick(g, 60);
    expect(r.fire).toHaveLength(2);
    tick(g, 60);
    expect(r.fire).toHaveLength(1);
    const notes = tick(g, 60);
    expect(r.fire).toHaveLength(0);
    expect(notes.join(' ')).toContain('엎어진 물건');
    expect(r.scorched.length).toBeGreaterThanOrEqual(3);
    expect(r.riots).toBe(1);
    expect(r.fell).toBe(fell);
    expect(protests(g)).toHaveLength(0);
    expect(r.spilled).toBe(0);
  });

  it('쓰러지는 사람은 어른이고 죽는 사람은 불이 아니라 싸움에서 나오며 일지에 이름이 없다', () => {
    const g = fresh('rt-6');
    const r = riotOf(g);
    r.prev = 69;
    tick(g, 70);
    for (let k = 0; k < 4; k += 1) { g.cards = []; tick(g, 72); }
    expect(r.fell).toBeGreaterThan(0);
    expect(r.fell).toBeLessThanOrEqual(10);
    expect(g.deaths).toHaveLength(r.died);
    for (const n of g.deaths) { expect(ageOf(n)).toBeGreaterThanOrEqual(16); expect(ageOf(n)).toBeLessThanOrEqual(64); }
    for (const w of activeWounds(g)) { expect(ageOf(w.who)).toBeGreaterThanOrEqual(16); expect(ageOf(w.who)).toBeLessThanOrEqual(64); }
    const text = g.journal.map(e => e.text).join(' ');
    for (const n of g.deaths) expect(text).not.toContain(n);
    expect(text).not.toMatch(/tail[123]|workshop|captain|dining|store|cold/);
  });

  it('내정이 없는 판에서도 틱이 돌고 불만 없다', () => {
    const g = fresh('rt-10', false);
    riotOf(g).prev = 69;
    tick(g, 70);
    expect(riotOf(g).fire).toHaveLength(0);
    expect(riotOf(g).fell).toBeGreaterThan(0);
  });
});

describe('자리 잃음', () => {
  it('불이 지나간 칸이 이어진 집단의 처지만 바뀌고 집단이 없는 칸은 그을음만 남는다', () => {
    const g = fresh('rt-7');
    refreshSit(g);
    const base = JSON.parse(JSON.stringify(g.dom!.sit)) as Record<string, number[]>;
    const r = riotOf(g);
    r.scorched = ['workshop', 'captain', 'dining', 'store', 'cold'];
    refreshSit(g);
    expect(g.dom!.sit).toEqual(base);
    r.scorched = ['tail1'];
    refreshSit(g);
    const sit = g.dom!.sit;
    expect(sit.tail[0]).toBe(base.tail[0] - P.seatWarm);
    expect(sit.tail[1]).toBe(base.tail[1] - P.seatFood);
    expect(sit.tail[2]).toBe(base.tail[2] + P.seatCrowd);
    for (const c of COMMS) if (c !== 'tail') expect(sit[c]).toEqual(base[c]);
  });
});

describe('끄는 틈과 카드 답', () => {
  it('riotFrom 이 0 이면 옛 동작이다: 카드도 단계도 난수도 일지도 안 바뀐다', () => {
    const g = fresh('rt-8');
    riotOf(g).prev = 40;
    const rng = g.rng.state;
    const lines = g.journal.length;
    RIOT_TUNE.from = 0;
    try { tick(g, 95); } finally { delete RIOT_TUNE.from; }
    expect(protests(g)).toHaveLength(0);
    expect(riotOf(g).stage).toBe(0);
    expect(riotOf(g).prev).toBe(40);
    expect(g.rng.state).toBe(rng);
    expect(g.journal).toHaveLength(lines);
  });

  it('난장판 카드: 들어준다와 경비대를 푼다는 끊고 아무것도 안 한다는 끊지 않는다', () => {
    const open = (seed: string): Game => { const g = fresh(seed); riotOf(g).prev = 69; tick(g, 70); return g; };
    const a = open('rt-9a');
    answer(a, '아무것도 안 한다');
    expect(riotOf(a).stage).toBe(2);
    tick(a, 70);
    expect(protests(a)).toHaveLength(1);
    const b = open('rt-9b');
    const fell = riotOf(b).fell;
    answer(b, '경비대를 푼다');
    expect(riotOf(b).stage).not.toBe(2);
    expect(riotOf(b).fell).toBe(fell + P.riotFall);
    const c = open('rt-9c');
    answer(c, '들어준다');
    expect(riotOf(c).stage).not.toBe(2);
    expect(c.tension).toBeLessThan(70);
  });

  it('항의 카드: 들어준다는 긴장을 낮추고 물리친다는 꼬리칸 관계를 깎는다', () => {
    const g = fresh('rt-11');
    riotOf(g).prev = 49;
    tick(g, 50);
    answer(g, '들어준다');
    expect(g.tension).toBe(40);
    const h = fresh('rt-12');
    riotOf(h).prev = 49;
    tick(h, 50);
    const rel = h.comms.tail.rel;
    answer(h, '물리친다');
    expect(h.tension).toBe(50);
    expect(h.comms.tail.rel).toBeLessThan(rel);
  });
});
