import { describe, expect, it } from 'vitest';
import { createGame, PLACES, resolveStop, riskLines, STAY, stopRisk } from '../../src/game';
import type { StayId } from '../../src/game';

// 정차 위험 줄은 약속이다(2026-10-07 사용자 결정): 줄이 뜨면 그 피해가 반드시 1명 이상, 최악을 넘지 않는다.
// 줄이 없으면 죽음과 중상은 없다.

function setups() {
  const out: { seed: string; place: string; stay: StayId; size: number; thrown: number; refuse: boolean }[] = [];
  let i = 0;
  for (const place of PLACES) for (const stay of Object.keys(STAY) as StayId[]) for (const size of [2, 4, 6, 8])
    for (const [thrown, refuse] of [[0, false], [10, true]] as const) out.push({ seed: `risk-${i++}`, place: place.id, stay, size, thrown, refuse });
  return out;
}

function stopGame(s: ReturnType<typeof setups>[number], k: number) {
  const g = createGame(`${s.seed}-${k}`);
  g.thrown = s.thrown;
  if (s.refuse) { g.comms.guard.fervor = 2; g.comms.guard.rel = -60; }
  g.phase = 'stop';
  g.stop = { place: s.place, target: 'food', stay: s.stay, crewComm: 'tail', crewSize: s.size, scout: true, threat: [0.8, 1, 1.4][k % 3], done: false, result: null };
  return g;
}

describe('정차 위험 줄(정찰한 곳)', () => {
  it('줄이 뜨면 1명 이상, 최악 이하로 일어나고, 줄이 없으면 일어나지 않는다', () => {
    let lines = 0;
    for (const s of setups()) for (let k = 0; k < 6; k += 1) {
      const g = stopGame(s, k);
      const risk = stopRisk(g);
      const r = resolveStop(g, true)!;
      const label = `${s.place}/${s.stay}/${s.size}/${s.thrown}`;
      if (risk.maxDead > 0) { expect(r.dead.length, label).toBeGreaterThanOrEqual(1); expect(r.dead.length, label).toBeLessThanOrEqual(risk.maxDead); }
      else expect(r.dead, label).toEqual([]);
      if (risk.maxHurt > 0) { expect(r.injured.length, label).toBeGreaterThanOrEqual(1); expect(r.injured.length, label).toBeLessThanOrEqual(risk.maxHurt); }
      else expect(r.injured, label).toEqual([]);
      for (const n of r.dead) expect(r.injured).not.toContain(n);
      lines += riskLines(risk).lines.length;
    }
    expect(lines).toBeGreaterThan(0);
  });

  it('준비를 바꾸면 줄이 사라질 수 있다', () => {
    const g = stopGame({ seed: 'risk-prep', place: 'freight', stay: 'long', size: 6, thrown: 0, refuse: false }, 1);
    expect(riskLines(stopRisk(g)).lines.length).toBeGreaterThan(0);
    g.stop!.stay = 'short'; g.stop!.crewSize = 2;
    expect(riskLines(stopRisk(g)).lines).toEqual([]);
    expect(riskLines(stopRisk(g)).calm).not.toBeNull();
  });

  it('줄의 숫자는 약속한 최악과 맞는다', () => {
    for (const s of setups()) {
      const risk = stopRisk(stopGame(s, 0));
      const text = riskLines(risk).lines.join(' ');
      expect(text.includes('죽는다'), s.seed).toBe(risk.maxDead > 0);
      expect(text.includes('크게 다친다'), s.seed).toBe(risk.maxHurt > 0);
      expect(text.includes('최악 '), s.seed).toBe(risk.maxDead > 1 || risk.maxHurt > 1);
      expect(risk.maxDead + risk.maxHurt).toBeLessThanOrEqual(s.size);
    }
  });
});

describe('정찰하지 않은 곳', () => {
  it('줄 대신 위험 모름이 뜨고, 경고 없이도 다치거나 죽을 수 있다', () => {
    let hurt = 0;
    let dead = 0;
    for (const s of setups()) for (let k = 0; k < 4; k += 1) {
      const g = stopGame(s, k);
      g.stop!.scout = false;
      const view = riskLines(stopRisk(g));
      expect(view.lines).toEqual([]);
      expect(view.unknown).not.toBeNull();
      const r = resolveStop(g, true)!;
      hurt += r.injured.length;
      dead += r.dead.length;
    }
    expect(hurt).toBeGreaterThan(0);
    expect(dead).toBeGreaterThan(0);
  });

  it('정찰하면 산출이 줄고 정찰조도 표결에서 빠진다', () => {
    const base = { seed: 'scout-cost', place: 'factory', stay: 'normal' as const, size: 4, thrown: 0, refuse: false };
    let withScout = 0;
    let without = 0;
    for (let k = 0; k < 40; k += 1) {
      const a = stopGame(base, k);
      a.stop!.scout = true;
      const ra = resolveStop(a, true)!;
      withScout += Object.values(ra.gains).reduce((x, y) => x + (y ?? 0), 0);
      expect(a.comms.tail.away).toBe(4 + 2 - ra.dead.length);
      const b = stopGame(base, k);
      b.stop!.scout = false;
      without += Object.values(resolveStop(b, true)!.gains).reduce((x, y) => x + (y ?? 0), 0);
    }
    expect(withScout).toBeLessThan(without);
  });
});
