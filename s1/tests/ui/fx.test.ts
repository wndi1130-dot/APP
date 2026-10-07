import { describe, expect, it } from 'vitest';
import { createGame } from '../../src/game';
import { fxDiff, fxLevel, fxSnap, fxText, fxTone } from '../../src/ui/fx';

// 위 띠 숫자 변화(presentation_motion 5b.6): 보이는 값의 차이, 선 넘음, 재질, 진동할 일.
describe('위 띠 변화', () => {
  it('변화량은 반올림한 새 값 − 반올림한 옛 값이다: 91.4 → 90.6은 화면이 91 그대로라 꼬리표가 없다', () => {
    const g = createGame('fx-1');
    g.coal = 91.4;
    const before = fxSnap(g);
    g.coal = 90.6;
    expect(fxDiff(before, g)).toBeNull();
    g.coal = 90.4;
    expect(fxDiff(before, g)?.d.coal).toMatchObject({ v: -1, from: 91, to: 90 });
  });

  it('선을 나쁜 쪽으로 넘으면 가장 무거운 칸 하나만 글자를 찍고, 진동할 일이 된다', () => {
    const g = createGame('fx-2');
    g.trust = 50;
    g.tension = 40;
    const before = fxSnap(g);
    g.trust = 40;
    g.tension = 75;
    const fx = fxDiff(before, g)!;
    expect(fx.heavy).toBe('tension');
    expect(fx.d.tension?.word).toBe('위험');
    expect(fx.d.trust?.word).toBeNull();
    expect(fx.buzz).toBe(true);
    expect(fx.fly[0]).toBe('tension');
  });

  it('좋은 쪽으로 돌아오면 흔들림·진동 없이 글자만 벗겨진다', () => {
    const g = createGame('fx-3');
    g.trust = 28;
    const before = fxSnap(g);
    g.trust = 33;
    const fx = fxDiff(before, g)!;
    expect(fx.heavy).toBeNull();
    expect(fx.buzz).toBe(false);
    expect(fx.d.trust).toMatchObject({ word: null, peel: '위험', big: true });
  });

  it('빨강은 자원이 부족 선 아래로 갈 때만, 나머지는 늘면 호박색·줄면 그을음', () => {
    const g = createGame('fx-4');
    g.coal = 35;
    g.food = 80;
    g.trust = 60;
    const before = fxSnap(g);
    g.coal = 25;
    g.food = 79;
    g.trust = 63;
    const fx = fxDiff(before, g)!;
    expect(fxTone(fx.d.coal!)).toBe('fx-red');
    expect(fxTone(fx.d.food!)).toBe('fx-down');
    expect(fxTone(fx.d.trust!)).toBe('fx-up');
    expect(fx.d.food!.big).toBe(false);
    expect(fx.d.coal!.big).toBe(true);
  });

  it('죽음만 있어도 진동할 일이다', () => {
    const g = createGame('fx-5');
    const before = fxSnap(g);
    g.deaths.push('누군가');
    expect(fxDiff(before, g)?.buzz).toBe(true);
  });

  it('단계와 꼬리표 글', () => {
    expect([fxLevel('trust', 45), fxLevel('trust', 44), fxLevel('trust', 29)]).toEqual([0, 1, 2]);
    expect([fxLevel('tension', 50), fxLevel('tension', 51), fxLevel('tension', 71)]).toEqual([0, 1, 2]);
    expect([fxLevel('coal', 30), fxLevel('coal', 29), fxLevel('coal', 0)]).toEqual([0, 1, 2]);
    expect([fxText(3), fxText(-3)]).toEqual(['+3', '−3']);
  });
});
