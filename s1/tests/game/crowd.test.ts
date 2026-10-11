import { describe, expect, it } from 'vitest';
import { crowdFeverP, crowdLevel, crowdLevelOf, crowdLine, crowdSepticP, createGame, createS1cGame, D, hygieneTick, P, sickMult } from '../../src/game';
import { addWound } from '../../src/game/wounds';

// 과밀이 병으로 이어지는 고리(결정 060 덧붙임): 과밀 문턱 60·80·95의 병 위험 계단이 열병 시작과 곪음을 같이 정한다.

describe('병 위험 계단', () => {
  it('과밀 값이 60·80·95에 닿으면 낱말이 한 단씩 오르고 배수는 0, 1, 1.25, 1.5다', () => {
    expect([0, 59, 60, 79, 80, 94, 95, 100].map(crowdLevelOf)).toEqual([0, 0, 1, 1, 2, 2, 3, 3]);
    const g = createGame('crowd-steps');
    const mults: number[] = [];
    for (const v of [30, 65, 85, 98]) {
      g.comms.tail.base[2] = v; // 처지 보정이 없는 S1a 판이라 기준이 곧 과밀이다
      mults.push(sickMult(g, 'tail'));
    }
    expect(mults).toEqual([0, 1, 1.25, 1.5]);
  });

  it('화면 줄은 「비좁음 · 병 위험 높음」처럼 낱말 두 개다', () => {
    const g = createGame('crowd-line');
    g.comms.tail.base[2] = 85;
    expect(crowdLevel(g, 'tail')).toBe(2);
    expect(crowdLine(g, 'tail')).toBe('비좁음 · 병 위험 높음');
    g.comms.tail.base[2] = 30;
    expect(crowdLine(g, 'tail')).toBe('넉넉 · 병 위험 낮음');
  });

  it('열병 확률과 곪음 몫은 같은 배수를 읽는다', () => {
    const g = createGame('crowd-same');
    g.comms.tail.base[2] = 98;
    expect(crowdFeverP(g, 'tail')).toBeCloseTo(P.crowdFever * 1.5, 9);
    expect(crowdSepticP(g, 'tail')).toBeCloseTo(P.crowdSeptic * 1.5, 9);
    g.comms.tail.base[2] = 20;
    expect(crowdFeverP(g, 'tail')).toBe(0);
    expect(crowdSepticP(g, 'tail')).toBe(0);
  });
});

describe('과밀이 열병을 부른다', () => {
  function ticks(crowd: number, n: number): number {
    const g = createS1cGame('crowd-fever');
    g.dom!.lice = {};
    g.seg = Math.max(g.seg, D.liceFromSeg);
    for (const c of Object.keys(g.comms) as (keyof typeof g.comms)[]) g.comms[c].base[2] = crowd;
    let started = 0;
    for (let i = 0; i < n; i += 1) {
      g.dom!.liceFree = { tail: 999, front: 999, medtech: 999, guard: 999, engine: 999 } as never;
      g.dom!.typhus = [];
      const before = g.dom!.stats.typhus;
      hygieneTick(g, []);
      started += g.dom!.stats.typhus - before;
    }
    return started;
  }

  it('넉넉하면 이가 없을 때 열병이 시작되지 않는다', () => {
    expect(ticks(30, 200)).toBe(0);
  });

  it('붐비면 이가 없어도 열병이 시작되고, 더 붐비면 더 자주 시작된다', () => {
    const tight = ticks(70, 300);
    const stacked = ticks(98, 300);
    expect(tight).toBeGreaterThan(0);
    expect(stacked).toBeGreaterThan(tight);
  });
});

describe('과밀이 상처를 곪게 한다', () => {
  function septicRate(crowd: number): number {
    let septic = 0; const n = 400;
    for (let i = 0; i < n; i += 1) {
      const g = createGame(`crowd-septic-${i}`);
      g.comms.tail.base[2] = crowd;
      if (addWound(g, { who: `사람${i}`, comm: 'tail', from: 'stop', where: '시험' }).septic) septic += 1;
    }
    return septic / n;
  }

  it('붐비는 칸의 상처가 더 자주 곪는다(기본 20%에 몫이 더해진다)', () => {
    const roomy = septicRate(30);
    const stacked = septicRate(98);
    expect(stacked).toBeGreaterThan(roomy + 0.1);
  });
});
