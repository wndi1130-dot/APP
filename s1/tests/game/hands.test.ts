import { describe, expect, it } from 'vitest';
import {
  COMMS, createGame, forecast, HANDS, handsCoal, handsNow, handsOffered, handsSettle, handsTrackBoost, handsWatchMult, handsWorkMult, situation,
} from '../../src/game';
import type { Game, HandJob } from '../../src/game';

// 손 몫(2026-10-25 사용자 결정 카드 1 가, carry_people.md 3.1): 일 다섯에 칸이 내는 손, 모자라면 뒤에서부터 빈다.

const JOBS = HANDS.order;
const noShort = (): Record<HandJob, number> => Object.fromEntries(JOBS.map(j => [j, 0])) as Record<HandJob, number>;
const sumShort = (g: Game) => JOBS.reduce((s, j) => s + handsNow(g).short[j], 0);

/** 모든 칸 인구를 같은 비율로 줄인다 */
function scalePop(g: Game, k: number): void {
  for (const c of COMMS) g.comms[c].pop = Math.round(g.comms[c].pop * k);
}

describe('손 몫', () => {
  it('일 다섯의 드는 손은 기획서 제안대로 74명이다', () => {
    expect(JOBS.reduce((s, j) => s + HANDS.need[j], 0)).toBe(74);
  });

  it('시작 열차는 아무 일도 비지 않는다(사람을 잃지 않으면 모자람이 없다)', () => {
    const g = createGame('hands-full');
    const h = handsNow(g);
    expect(h.have).toBeGreaterThan(74);
    for (const j of JOBS) expect(h.short[j]).toBe(0);
  });

  it('모자라면 화실부터 채우고 뒤의 일부터 빈다', () => {
    const g = createGame('hands-order');
    scalePop(g, 0.4);
    const h = handsNow(g);
    expect(h.have).toBeLessThan(74);
    expect(h.short.stoker).toBe(0);
    expect(h.short.repair).toBe(1);
    for (let i = 1; i < JOBS.length; i += 1) expect(h.short[JOBS[i]]).toBeGreaterThanOrEqual(h.short[JOBS[i - 1]]);
  });

  it('사람이 줄면 빈 몫이 줄지 않는다(줄수록 이득인 길이 없다)', () => {
    let prev = -1;
    for (let k = 1; k >= 0.2; k -= 0.05) {
      const g = createGame('hands-mono');
      scalePop(g, k);
      const s = sumShort(g);
      expect(s).toBeGreaterThanOrEqual(prev - 1e-9);
      prev = s;
    }
  });

  it('관계가 나쁘거나 작업을 거부하는 칸, 몫을 끊긴 칸은 손을 덜 낸다', () => {
    const g = createGame('hands-will');
    Object.assign(g.comms.tail, { rel: 0, fervor: 0, heat: 2, ration: 2 });
    const full = handsOffered(g, 'tail');
    g.comms.tail.rel = -20;
    expect(handsOffered(g, 'tail')).toBeCloseTo(full * HANDS.willCold);
    g.comms.tail.rel = -45;
    expect(handsOffered(g, 'tail')).toBeCloseTo(full * HANDS.willHostile);
    g.comms.tail.fervor = 1;
    expect(handsOffered(g, 'tail')).toBeCloseTo(full * HANDS.willRefuse);
    Object.assign(g.comms.tail, { rel: 0, fervor: 0, ration: 0 });
    expect(handsOffered(g, 'tail')).toBeCloseTo(full * HANDS.leverCut);
  });

  it('자리를 비운 사람과 다친 사람은 손을 못 낸다', () => {
    const g = createGame('hands-away');
    const have = handsNow(g).have;
    g.comms.tail.away = 4;
    const awayDrop = have - handsNow(g).have;
    expect(awayDrop).toBeGreaterThan(0);
    g.comms.tail.away = 0;
    g.injured = 5;
    expect(handsNow(g).have).toBeCloseTo(have - 5);
  });

  it('빈 몫이 없으면 다른 셈에 아무것도 더하지 않는다', () => {
    const g = createGame('hands-none');
    const f0 = forecast(g).coal;
    const w0 = situation(g, 'tail')[0];
    g.hands = { have: 150, short: noShort() };
    expect(handsCoal(g)).toBe(0);
    expect(handsWatchMult(g)).toBe(1);
    expect(handsWorkMult(g)).toBe(1);
    expect(forecast(g).coal).toBe(f0);
    expect(situation(g, 'tail')[0]).toBe(w0);
  });

  it('빈 일마다 그 일이 덜 된다: 석탄·온기·정차 기척·공방·선로 사건', () => {
    const g = createGame('hands-effects');
    const f0 = forecast(g).coal;
    g.comms.tail.base[0] = 50;
    const w0 = situation(g, 'tail')[0];
    g.hands = { have: 0, short: { stoker: 1, stove: 1, watch: 1, roof: 1, repair: 1 } };
    expect(forecast(g).coal).toBeCloseTo(f0 + HANDS.stokerCoal);
    expect(situation(g, 'tail')[0]).toBeCloseTo(w0 - HANDS.stoveWarm);
    expect(handsWatchMult(g)).toBeCloseTo(1 + HANDS.watchRisk);
    expect(handsWorkMult(g)).toBeCloseTo(1 - HANDS.repairWork);
    const pool = ['water_tower', 'snow_drift', 'other'];
    const boosted = handsTrackBoost(g, pool);
    expect(boosted.filter(id => id === 'water_tower')).toHaveLength(HANDS.roofTrack);
    expect(boosted.filter(id => id === 'other')).toHaveLength(1);
    g.hands.short.roof = HANDS.roofOver;
    expect(handsTrackBoost(g, pool)).toEqual(pool);
  });

  it('정산 끝 셈은 다음 구간 몫을 두고, 빈 일이 있을 때만 결과 줄 하나를 남긴다', () => {
    const g = createGame('hands-settle');
    const notes: string[] = [];
    handsSettle(g, notes);
    expect(g.hands?.short.stoker).toBe(0);
    expect(notes).toHaveLength(0);
    scalePop(g, 0.4);
    handsSettle(g, notes);
    expect(notes).toHaveLength(1);
    expect(g.hands?.short.repair).toBe(1);
  });
});
