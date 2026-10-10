import { describe, expect, it } from 'vitest';
import { createGame, PLACES, resolveStop, riskLevel, riskView, sendScouts, STAY, stopRisk } from '../../src/game';
import type { StayId } from '../../src/game';

// 정찰조의 해석은 약속이다(2026-10-07 사용자 결정): '불길하다'가 뜨면 그 피해가 반드시 1명 이상, 최악을 넘지 않는다.
// 결과는 사람마다 정해 둔 난수로 먼저 정하고 정찰은 드러내기만 한다(07_outside_eye_triage N2).
// '괜찮을 것 같다' 쪽이면 죽음과 중상은 없다. 꼬리표 대신 조짐 글로 보인다(11:51 사용자).

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
      if (riskLevel(risk) === 'dead' || riskLevel(risk) === 'hurt') lines += 1;
    }
    expect(lines).toBeGreaterThan(0);
  });

  it('준비를 바꾸면 해석이 바뀌고 조짐은 그대로다', () => {
    const g = stopGame({ seed: 'risk-prep-1', place: 'freight', stay: 'long', size: 6, thrown: 0, refuse: false }, 1);
    const before = riskView(g);
    expect(before.verdict).toContain('불길하다');
    g.stop!.stay = 'short'; g.stop!.crewSize = 2;
    const after = riskView(g);
    expect(after.verdict).not.toContain('불길');
    expect(after.omen).toBe(before.omen);
  });

  it('해석 말은 약속한 피해와 맞는다', () => {
    for (const s of setups()) for (let k = 0; k < 3; k += 1) {
      const g = stopGame(s, k);
      const risk = stopRisk(g);
      const view = riskView(g);
      expect(view.omen, s.seed).toBeTruthy();
      expect(view.verdict!.includes('매우 불길하다'), s.seed).toBe(risk.maxDead > 0);
      expect(view.verdict!.includes('불길하다'), s.seed).toBe(risk.maxDead > 0 || risk.maxHurt > 0);
      expect(risk.maxDead + risk.maxHurt).toBeLessThanOrEqual(s.size);
    }
  });
});

describe('정찰하지 않은 곳', () => {
  it('조짐 대신 모른다고 뜨고, 경고 없이도 다치거나 죽을 수 있다', () => {
    let hurt = 0;
    let dead = 0;
    for (const s of setups()) for (let k = 0; k < 4; k += 1) {
      const g = stopGame(s, k);
      g.stop!.scout = false;
      const view = riskView(g);
      expect(view.omen).toBeNull();
      expect(view.verdict).toBeNull();
      expect(view.unknown).not.toBeNull();
      const r = resolveStop(g, true)!;
      hurt += r.injured.length;
      dead += r.dead.length;
    }
    expect(hurt).toBeGreaterThan(0);
    expect(dead).toBeGreaterThan(0);
  });

  it('정찰은 결과를 드러내기만 한다: 같은 준비면 정찰하든 안 하든 같은 사람이 죽고 다친다', () => {
    let seen = 0;
    for (const s of setups()) for (let k = 0; k < 3; k += 1) {
      const a = stopGame(s, k);
      const b = stopGame(s, k);
      b.stop!.scout = false;
      const ra = resolveStop(a, true)!;
      const rb = resolveStop(b, true)!;
      expect(rb.dead, s.seed).toEqual(ra.dead);
      expect(rb.injured, s.seed).toEqual(ra.injured);
      seen += ra.dead.length;
    }
    expect(seen).toBeGreaterThan(0);
  });

  it('준비를 바꿔 다시 봐도 같은 사람의 운은 그대로다(줄여서 살릴 수는 있어도 다시 굴릴 수는 없다)', () => {
    for (const s of setups().filter(x => x.size === 8)) {
      const g = stopGame(s, 2);
      const big = stopRisk(g).fate;
      g.stop!.stay = 'short';
      const small = stopRisk(g).fate;
      for (const n of small.dead) expect(big.dead, s.seed).toContain(n);
    }
  });

  it('정찰하면 산출이 줄고 정찰조도 표결에서 빠진다', () => {
    const base = { seed: 'scout-cost', place: 'factory', stay: 'normal' as const, size: 4, thrown: 0, refuse: false };
    let withScout = 0;
    let without = 0;
    for (let k = 0; k < 40; k += 1) {
      const a = stopGame(base, k);
      const rep = sendScouts(a)!;
      const ra = resolveStop(a, true)!;
      withScout += Object.values(ra.gains).reduce((x, y) => x + (y ?? 0), 0);
      expect(a.comms.tail.away).toBe(4 + rep.names.length - rep.dead.length - ra.dead.length);
      for (const n of rep.names) expect(ra.dead).not.toContain(n); // 정찰조는 작업조에 다시 안 든다
      const b = stopGame(base, k);
      b.stop!.scout = false;
      without += Object.values(resolveStop(b, true)!.gains).reduce((x, y) => x + (y ?? 0), 0);
    }
    expect(withScout).toBeLessThan(without);
  });
});

describe('예약한 결과는 저장하고 다시 켜도 그대로다(r8)', () => {
  it('정찰한 위험 줄과 정차 결과가 JSON 저장·불러오기 뒤에도 같다', () => {
    for (let k = 0; k < 20; k += 1) {
      const g = createGame(`reload-${k}`);
      g.phase = 'stop';
      g.stop = { place: 'factory', target: 'coal', stay: 'long', crewComm: 'tail', crewSize: 6, scout: true, threat: 1.4, done: false, result: null };
      const before = stopRisk(g);
      const loaded = JSON.parse(JSON.stringify(g)) as typeof g;
      expect(stopRisk(loaded).fate).toEqual(before.fate);
      const a = resolveStop(g, true);
      const b = resolveStop(loaded, true);
      expect(b?.dead).toEqual(a?.dead);
      expect(b?.injured).toEqual(a?.injured);
    }
  });
});

describe('정찰은 먼저 보내는 일이다(2026-10-07 사용자)', () => {
  function fresh(k: number, place = 'factory', threat = 1.4) {
    const g = createGame(`scout-send-${k}`);
    g.phase = 'stop';
    g.stop = { place, target: 'coal', stay: 'normal', crewComm: 'tail', crewSize: 4, threat, done: false, result: null };
    return g;
  }

  it('보내기 전엔 기척을 모르고, 돌아오면 안다', () => {
    const g = fresh(0);
    expect(stopRisk(g).known).toBe(false);
    const rep = sendScouts(g)!;
    expect(rep.names).toHaveLength(2);
    if (rep.dead.length < rep.names.length) expect(stopRisk(g).known).toBe(true);
  });

  it('두 번 보낼 수 없고, 정찰조는 작업조와 겹치지 않는다', () => {
    const g = fresh(1);
    const rep = sendScouts(g)!;
    expect(sendScouts(g)).toBeNull();
    const crew = stopRisk(g).fate;
    for (const n of rep.names) { expect(crew.dead).not.toContain(n); expect(crew.hurt).not.toContain(n); }
  });

  it('정찰조도 다치거나 못 돌아온다. 위험한 곳일수록 잦고, 결과는 다시 굴려도 같다', () => {
    let hurtHi = 0, deadHi = 0, hurtLo = 0;
    for (let k = 0; k < 400; k += 1) {
      const hi = sendScouts(fresh(k, 'factory', 1.4))!;
      hurtHi += hi.hurt.length; deadHi += hi.dead.length;
      hurtLo += sendScouts(fresh(k, 'church', 1))!.hurt.length;
      expect(sendScouts(fresh(k, 'factory', 1.4))).toEqual(hi);
    }
    expect(deadHi).toBeGreaterThan(0);
    expect(hurtHi).toBeGreaterThan(hurtLo);
  });

  it('바깥이 고요한 정차에선 정찰조가 다치지도 죽지도 않는다', () => {
    for (let k = 0; k < 400; k += 1) {
      const rep = sendScouts(fresh(k, 'factory', 0.8))!;
      expect(rep.hurt).toEqual([]);
      expect(rep.dead).toEqual([]);
    }
  });

  it('아무도 못 돌아오면 기척은 모른 채 남는다', () => {
    for (let k = 0; k < 2000; k += 1) {
      const g = fresh(k);
      const rep = sendScouts(g)!;
      if (rep.dead.length === rep.names.length) { expect(stopRisk(g).known).toBe(false); return; }
    }
  });
});
