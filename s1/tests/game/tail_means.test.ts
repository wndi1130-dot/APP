import { describe, expect, it } from 'vitest';
import { createGame, crewPreview, crewRest, crewWork, P, resolveStop, setSpace, setStop, situation, supportComm, TRAVEL_EVENTS } from '../../src/game';
import type { Comm, Game } from '../../src/game';
import { readSave } from '../../src/ui/repro';

// 꼬리칸 수단(first_leg_story 6.4, 숫자는 제안): 작업조 칸 고르기, 쉼, 공간 레버, 눈 녹이는 칸, 되풀이 지지.

function atStop(seed: string, crew: Comm): Game {
  const g = createGame(seed);
  g.phase = 'stop';
  g.stop = { place: 'factory', target: 'coal', stay: 'short', crewComm: crew, crewSize: 4, threat: 0.8, done: false, result: null };
  return g;
}

describe('작업조 칸', () => {
  it('낸 칸은 노출 +5, 안 낸 칸은 −10이되 쉼 바닥 아래로는 안 내려간다', () => {
    const g = createGame('tm-1');
    g.comms.tail.base[3] = 50;
    g.comms.medtech.base[3] = 30;
    g.comms.front.base[3] = 15;
    g.comms.guard.base[3] = 70;
    crewWork(g, 'tail', P.crewGain);
    crewRest(g, 'tail');
    expect(g.comms.tail.base[3]).toBe(55);
    expect(g.comms.medtech.base[3]).toBe(25); // 30 − 10 이지만 바닥 25
    expect(g.comms.front.base[3]).toBe(10);
    expect(g.comms.guard.base[3]).toBe(70); // 경비대는 쉼 표에 없다
  });

  it('작업조 노동만으로는 노출이 한계(꼬리칸 시작값 60) 위로 안 오르고, 이미 위면 그대로다', () => {
    const g = createGame('tm-cap');
    expect(P.crewCap).toBe(g.comms.tail.base[3]);
    g.comms.tail.base[3] = P.crewCap - 2;
    crewWork(g, 'tail', P.crewGain);
    expect(g.comms.tail.base[3]).toBe(P.crewCap);
    g.comms.tail.base[3] = 85;
    crewWork(g, 'tail', P.crewGain);
    expect(g.comms.tail.base[3]).toBe(85);
  });

  it('바닥보다 이미 낮은 칸은 쉬어도 올라가지 않는다', () => {
    const g = createGame('tm-2');
    g.comms.front.base[3] = 5;
    crewRest(g, null);
    expect(g.comms.front.base[3]).toBe(5);
  });

  it('의무진·앞칸을 내면 궂은일 반감 −3과 그 줄이 남는다. 꼬리칸·경비대는 없다', () => {
    const g = createGame('tm-3');
    const before = { m: g.comms.medtech.rel, t: g.comms.tail.rel };
    expect(crewWork(g, 'medtech', P.crewGain)).toMatch(/^기술·의무진은 /);
    expect(g.comms.medtech.rel).toBe(before.m + P.choreRel);
    expect(crewWork(g, 'tail', P.crewGain)).toBeNull();
    expect(g.comms.tail.rel).toBe(before.t);
  });

  it('기관실은 작업조로 고를 수 없다', () => {
    const g = atStop('tm-4', 'tail');
    setStop(g, { crewComm: 'engine' });
    expect(g.stop!.crewComm).toBe('tail');
    setStop(g, { crewComm: 'front' });
    expect(g.stop!.crewComm).toBe('front');
  });

  it('정차를 보내면 낸 칸이 지치고 나머지는 쉬며, 마지막 작업조 칸을 기억한다', () => {
    const g = atStop('tm-5', 'medtech');
    const tail0 = g.comms.tail.base[3];
    const med0 = g.comms.medtech.base[3];
    resolveStop(g, true);
    expect(g.comms.medtech.base[3]).toBe(Math.min(100, med0 + P.crewGain));
    expect(g.comms.tail.base[3]).toBe(Math.max(Math.min(35, tail0), tail0 - P.crewRest));
    expect(g.lastCrew).toBe('medtech');
  });

  it('지나치면 모두 쉰다', () => {
    const g = atStop('tm-6', 'tail');
    const tail0 = g.comms.tail.base[3];
    resolveStop(g, false);
    expect(g.comms.tail.base[3]).toBe(Math.max(Math.min(35, tail0), tail0 - P.crewRest));
  });

  it('미리보기는 노출 전후, 반감, 쉬는 칸을 준다', () => {
    const g = atStop('tm-7', 'front');
    const pv = crewPreview(g, 'front');
    expect(pv.to - pv.from).toBe(P.crewGain);
    expect(pv.rel).toBe(P.choreRel);
    expect(pv.haul).toBeLessThan(1);
    expect(pv.rest).toContain('tail');
    expect(pv.rest).not.toContain('front');
  });

  it('옛 저장의 열린 정차가 기관실을 골라 뒀으면 경비대로 읽는다', () => {
    const g = atStop('tm-8', 'tail');
    g.stop!.crewComm = 'engine';
    const r = readSave(JSON.parse(JSON.stringify(g)));
    expect(r.ok && r.g.stop?.crewComm).toBe('guard');
  });
});

describe('공간 레버', () => {
  it('한 단에 꼬리칸 과밀 −10, 내주는 칸 +10. 당길 때 관계 −3', () => {
    const g = createGame('tm-s1');
    const tail0 = situation(g, 'tail')[2];
    const front0 = situation(g, 'front')[2];
    const rel0 = g.comms.front.rel;
    expect(setSpace(g, 2, 'front')).toBeNull();
    expect(situation(g, 'tail')[2]).toBe(Math.max(0, tail0 - 20));
    expect(situation(g, 'front')[2]).toBe(Math.min(100, front0 + 20));
    expect(g.comms.front.rel).toBe(rel0 + 2 * P.spacePullRel);
    // 줄일 때는 관계가 다시 깎이지 않는다.
    setSpace(g, 1);
    expect(g.comms.front.rel).toBe(rel0 + 2 * P.spacePullRel);
  });

  it('꼬리칸은 내줄 수 없고, 칸 없이 당길 수 없고, 당긴 채로 칸을 바꿀 수 없다', () => {
    const g = createGame('tm-s2');
    expect(setSpace(g, 1, 'tail')).not.toBeNull();
    expect(setSpace(g, 1)).not.toBeNull();
    expect(setSpace(g, 1, 'guard')).toBeNull();
    expect(setSpace(g, 1, 'front')).not.toBeNull();
    expect(g.space).toEqual({ step: 1, giver: 'guard' });
    setSpace(g, 0);
    expect(setSpace(g, 1, 'front')).toBeNull();
    expect(g.space?.giver).toBe('front');
  });

  it('단은 0~2로 묶인다', () => {
    const g = createGame('tm-s3');
    setSpace(g, 5, 'engine');
    expect(g.space?.step).toBe(P.spaceMax);
  });
});

describe('되풀이 지지', () => {
  it('같은 칸을 3구간 안에 또 지지하면 +5만 오른다', () => {
    const g = createGame('tm-u1');
    g.lux = 10;
    g.comms.front.rel = 0;
    supportComm(g, 'front');
    expect(g.comms.front.rel).toBe(P.supportRel);
    g.seg += 2;
    g.actedSeg = -1;
    supportComm(g, 'front');
    expect(g.comms.front.rel).toBe(P.supportRel + P.supportRepeatRel);
    g.seg += P.supportGap;
    g.actedSeg = -1;
    supportComm(g, 'front');
    expect(g.comms.front.rel).toBe(2 * P.supportRel + P.supportRepeatRel);
  });
});

describe('급수탑 눈 녹이기', () => {
  it('마지막 작업조 칸이 눈을 녹이고 노출 +10을 진다', () => {
    const ev = TRAVEL_EVENTS.find(e => e.id === 'water_tower')!;
    const g = createGame('tm-w1');
    g.lastCrew = 'front';
    const v = ev.view(g, undefined);
    const snow = v.choices.find(c => c.label === '눈을 녹인다')!;
    expect(snow.say).toMatch(/^앞칸은 /);
    expect(snow.effs).toContainEqual({ t: 'base', c: 'front', i: 3, v: P.snowExposure });
    expect(snow.effs).toContainEqual({ t: 'rel', c: 'front', v: -4 + P.choreRel });
  });

  it('작업조를 낸 적이 없으면 꼬리칸이다', () => {
    const ev = TRAVEL_EVENTS.find(e => e.id === 'water_tower')!;
    const g = createGame('tm-w2');
    const snow = ev.view(g, undefined).choices.find(c => c.label === '눈을 녹인다')!;
    expect(snow.effs).toContainEqual({ t: 'base', c: 'tail', i: 3, v: P.snowExposure });
  });
});
