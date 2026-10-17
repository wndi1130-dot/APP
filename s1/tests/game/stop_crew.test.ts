import { afterEach, describe, expect, it } from 'vitest';
import {
  CHORE_COMMS, CREW, CREW_COST, CREW_LINE, createGame, crewAwayOf, crewBand, crewEnoughCount, crewGainOf, crewHaulMult, crewLineText, crewMult, crewNames, crewPreview, crewWhyText,
  P, PLACES, resolveStop, riskLevel, onDeath, riskView, sendScouts, setStop, situation, STAY, stopRisk,
} from '../../src/game';
import type { Comm, CrewCost, CrewCurve, CrewHaul, Game, StayId } from '../../src/game';

// 정차 작업조 인원과 위험(결정 341, 구현 명세 6장 1~10). 곡선 A·B는 가안이라 둘 다 본다.
// 시험 안에서 CREW.curve·CREW.cost·CREW.haul을 바꾸면 끝날 때 기본값으로 되돌린다.
const COST0 = CREW.cost;
const HAUL0 = CREW.haul;
afterEach(() => { CREW.curve = 'A'; CREW.cost = COST0; CREW.haul = HAUL0; });

const STAY_RISK: Record<StayId, number> = { short: 0.6, normal: 1, long: 1.5 };
const place = (id: string) => PLACES.find(p => p.id === id)!;

interface Opt { place?: string; stay?: StayId; size?: number; threat?: number; scout?: boolean; thrown?: number; refuse?: boolean; escort?: boolean; comm?: Comm }
function mk(seed: string, o: Opt = {}): Game {
  const g = createGame(seed);
  g.thrown = o.thrown ?? 0;
  if (o.refuse) { g.comms.guard.fervor = 2; g.comms.guard.rel = -60; }
  if (o.escort) g.guardEscort = true;
  g.phase = 'stop';
  g.stop = {
    place: o.place ?? 'freight', target: 'food', stay: o.stay ?? 'normal', crewComm: o.comm ?? 'tail', crewSize: o.size ?? 4,
    scout: o.scout ?? true, threat: o.threat ?? 1, done: false, result: null,
  };
  return g;
}

const harmed = (g: Game, names: string[]) => {
  const f = stopRisk(g).fate;
  return names.filter(n => f.dead.includes(n) || f.hurt.includes(n));
};

describe('stop_crew', () => {
  it('1 need_follows_risk_and_stay: 위험 2·3 × 체류 × 기척의 알맞은 인원이 명세 값과 같다', () => {
    for (const [id, risk] of [['houses', 2], ['freight', 3]] as const) {
      expect(place(id).risk).toBe(risk);
      for (const stay of ['short', 'normal', 'long'] as const) {
        expect(STAY[stay].risk).toBe(STAY_RISK[stay]);
        for (const threat of [0.8, 1, 1.4]) {
          const want = Math.max(1.6, 1.5 * risk * STAY_RISK[stay] * threat);
          const r = stopRisk(mk('need-a', { place: id, stay, threat }));
          expect(r.need, `${id}/${stay}/${threat}`).toBeCloseTo(want, 9);
        }
      }
    }
    // 명세 2-1 예(기척 보통)
    const need = (id: string, stay: StayId) => stopRisk(mk('need-b', { place: id, stay })).need;
    expect(need('freight', 'normal')).toBeCloseTo(4.5, 9);
    expect(need('freight', 'short')).toBeCloseTo(2.7, 9);
    expect(need('freight', 'long')).toBeCloseTo(6.75, 9);
    expect(need('houses', 'normal')).toBeCloseTo(3, 9);
    expect(need('houses', 'short')).toBeCloseTo(1.8, 9);
    expect(need('houses', 'long')).toBeCloseTo(4.5, 9);
    // 바닥 1.6
    expect(stopRisk(mk('need-c', { place: 'houses', stay: 'short', threat: 0.8 })).need).toBeCloseTo(1.6, 9);
  });

  it('1b need는 경계 거부·무리·호위가 키우고 줄이며, 인원·정찰·장작불은 읽지 않는다', () => {
    const base = stopRisk(mk('need-d')).need;
    expect(stopRisk(mk('need-d', { refuse: true })).need).toBeCloseTo(base * 1.5, 9);
    expect(stopRisk(mk('need-d', { thrown: 10 })).need).toBeCloseTo(base * 1.5, 9); // 무리 배수 상한 1.5
    expect(stopRisk(mk('need-d', { escort: true })).need).toBeCloseTo(base * 0.5, 9);
    for (const size of [2, 5, 8]) expect(stopRisk(mk('need-d', { size })).need).toBeCloseTo(base, 9);
    expect(stopRisk(mk('need-d', { scout: false })).need).toBeCloseTo(base, 9);
    const g = mk('need-d');
    g.pyre = 2; // 장작불은 한 사람당 확률에만 곱하고 need에는 넣지 않는다
    const lit = stopRisk(g);
    expect(lit.pyre).toBe(true);
    expect(lit.need).toBeCloseTo(base, 9);
    expect(lit.ratio).toBeCloseTo(4 / base, 9);
  });

  it('2 mult_curve_shape: m(1)=1, 아주 작은 r은 천장, 아주 큰 r은 바닥, r에 비증가(A·B)', () => {
    const ceil: Record<'A' | 'B', number> = { A: P.crewACeil, B: P.crewBCeil };
    const floor: Record<'A' | 'B', number> = { A: P.crewAFloor, B: P.crewBFloor };
    for (const curve of ['A', 'B'] as const) {
      expect(crewMult(1, curve), curve).toBeCloseTo(1, 12);
      expect(crewMult(1e-4, curve), curve).toBe(ceil[curve]);
      expect(crewMult(1000, curve), curve).toBe(floor[curve]);
      let prev = Infinity;
      for (let r = 0.05; r <= 8; r += 0.01) {
        const m = crewMult(r, curve);
        expect(m, `${curve} r=${r.toFixed(2)}`).toBeLessThanOrEqual(prev + 1e-12);
        expect(m).toBeGreaterThanOrEqual(floor[curve]);
        expect(m).toBeLessThanOrEqual(ceil[curve]);
        prev = m;
      }
    }
    expect(crewMult(0.5, 'B')).toBeCloseTo(P.crewBCeil, 12);
    expect(crewMult(2, 'B')).toBeCloseTo(P.crewBFloor, 12);
    expect(crewMult(2.5, 'A')).toBeCloseTo(Math.pow(2.5, -1.5), 12);
    expect(crewMult(0.123, 'off')).toBe(1);
  });

  it('2b stopRisk의 lam·pDeath는 off 값에 m(ratio)를 곱한 값이다', () => {
    for (const curve of ['A', 'B'] as const) for (const [id, stay] of [['freight', 'normal'], ['houses', 'long'], ['factory', 'short']] as const) for (const size of [2, 4, 6, 8]) {
      const g = mk(`mult-link-${curve}-${id}`, { place: id, stay, size });
      CREW.curve = 'off';
      const off = stopRisk(g);
      CREW.curve = curve;
      const on = stopRisk(g);
      const m = crewMult(on.ratio, curve);
      expect(on.lam, `${curve}/${id}/${stay}/${size}`).toBeCloseTo(off.lam * m, 9);
      expect(on.pDeath, `${curve}/${id}/${stay}/${size}`).toBeCloseTo(off.pDeath * m, 9);
      expect(on.need).toBeCloseTo(off.need, 12);
    }
  });

  it('3 existing_crew_never_worse: 4명에서 8명으로 늘려도 한 명당 위험은 오르지 않고, 생존 보정이 안 걸린 판에서는 기존 4명이 새로 죽거나 다치지 않는다', () => {
    // 「한 명은 반드시 살아 돌아온다」(stopRisk의 slice)는 인원이 늘면 상한도 함께 는다. 그래서 4명 판에서 셋이 죽어 넷째가
    // 보호된 판은 8명 판과 마지막 생존이 다를 수 있다(시험 3b). 그런 판은 사람별 비교에서 빼고, 위험 배수 비교는 모든 판에서 한다.
    let compared = 0;
    let capped = 0;
    for (const curve of ['A', 'B'] as const) {
      CREW.curve = curve;
      for (let k = 0; k < 60; k += 1) for (const id of ['freight', 'houses', 'factory']) for (const stay of ['short', 'normal', 'long'] as const) {
        const seed = `never-worse-${k}`;
        const opt = { place: id, stay, threat: [0.8, 1, 1.4][k % 3], thrown: k % 2 ? 10 : 0, refuse: k % 4 === 3 };
        const a = mk(seed, { ...opt, size: 4 });
        const b = mk(seed, { ...opt, size: 8 });
        const first4 = crewNames(a, 'tail', 4);
        expect(crewNames(b, 'tail', 8).slice(0, first4.length)).toEqual(first4); // 명단 앞 4명이 같아야 비교가 된다
        const ra = stopRisk(a);
        const rb = stopRisk(b);
        // 한 명당 죽을 확률(pDeath/4)과 크게 다칠 확률(lam/인원)은 인원을 늘려도 오르지 않는다.
        const at = `${curve}/${seed}/${id}/${stay}`;
        expect(crewMult(rb.ratio), at).toBeLessThanOrEqual(crewMult(ra.ratio));
        expect(rb.pDeath, at).toBeLessThanOrEqual(ra.pDeath + 1e-12);
        expect(rb.lam / 8, at).toBeLessThanOrEqual(ra.lam / 4 + 1e-12);
        const fa = ra.fate;
        const fb = rb.fate;
        if (fa.dead.length === first4.length - 1) { capped += 1; continue; }
        for (const n of first4) {
          if (fb.dead.includes(n)) expect(fa.dead, `${at} 죽음 ${n}`).toContain(n);
          if (fb.hurt.includes(n)) expect(harmed(a, [n]), `${at} 부상 ${n}`).toEqual([n]);
        }
        compared += fa.dead.length + fa.hurt.length;
      }
    }
    expect(compared).toBeGreaterThan(0);
    // 생존 보정이 걸린 판이 대부분이면 사람별 비교가 빈 시험이 된다.
    expect(capped).toBeLessThan(compared);
  });

  it('3b 생존 보정 예외: 4명 판에서 보호된 넷째가 8명 판에서는 죽을 수 있다(지금 규칙, 검수 PR 395 보통 5)', () => {
    // 위험 3·길게·기척 1.4·경계 거부·무리 상한이면 알맞은 인원이 21을 넘어 4명과 8명 모두 개인 배수 상한에 닿는다.
    // 그래도 「한 명은 산다」의 상한이 4명은 3, 8명은 7이라, 앞 넷이 모두 죽음 후보면 넷째의 운명이 갈린다. 규칙을 그대로 적어 둔다.
    const opt = { place: 'freight', stay: 'long' as const, threat: 1.4, thrown: 10, refuse: true };
    let found = 0;
    for (let k = 0; k < 300 && found === 0; k += 1) {
      const a = mk(`survivor-cap-${k}`, { ...opt, size: 4 });
      const b = mk(`survivor-cap-${k}`, { ...opt, size: 8 });
      const ra = stopRisk(a);
      const rb = stopRisk(b);
      if (k === 0) {
        expect(ra.need).toBeGreaterThan(21);
        expect(crewMult(rb.ratio)).toBe(crewMult(ra.ratio)); // 둘 다 배수 상한
      }
      const first4 = crewNames(a, 'tail', 4);
      if (ra.fate.dead.length !== 3) continue;
      const saved = first4.find(n => !ra.fate.dead.includes(n))!;
      if (rb.fate.dead.includes(saved)) found += 1;
    }
    expect(found, '300개 시드 안에서 반례를 찾지 못했다').toBeGreaterThan(0);
  });

  it('4 total_loss_falls_to_enough: 보통 체류에서 모자람→충분으로 가며 기대 중상이 줄어든다', () => {
    const crews = [2, 4, 6, 8];
    for (const curve of ['A', 'B'] as const) {
      CREW.curve = curve;
      for (const id of ['houses', 'freight']) {
        const lam = crews.map(size => stopRisk(mk('loss-fall', { place: id, size })).lam);
        const band = crews.map(size => stopRisk(mk('loss-fall', { place: id, size })).band);
        expect(band[0]).toBe('short');
        expect(band[band.length - 1]).toBe('enough');
        const ratio = crews.map(size => stopRisk(mk('loss-fall', { place: id, size })).ratio);
        const floorStart = curve === 'A' ? Math.pow(P.crewAFloor, -1 / P.crewAPow) : 2; // 이 r부터 m이 바닥이라 인원만큼 다시 천천히 오른다(명세 2-2)
        for (let i = 1; i < crews.length; i += 1) {
          if (ratio[i - 1] >= floorStart - 1e-9) continue;
          // 명세 4번: 위험3의 2→4명은 허용 오차 10%. 후보 B는 이 구간에서 명세 2-3 표대로 .68→.88로 오른다(아래 5b에서 따로 못 박는다).
          if (curve === 'B' && id === 'freight' && crews[i] === 4) continue;
          const tol = crews[i] === 4 ? 1.1 : 1 + 1e-9; // 후보 B 위험2의 2→4명도 .38→.39로 조금 오른다(명세 표)
          expect(lam[i], `${curve}/${id}/${crews[i]}`).toBeLessThanOrEqual(lam[i - 1] * tol);
        }
        // 모자람에서 충분까지 가면 총 손실이 줄어든다
        // (후보 B 위험3은 명세 표에서도 2명 .68, 8명 .74라 처음보다 낮아지지 않는다. 4b에 따로 적었다)
        if (!(curve === 'B' && id === 'freight')) expect(lam[lam.length - 1], `${curve}/${id}`).toBeLessThan(lam[0]);
      }
    }
  });

  it('4b 후보 B에서 위험3 2→4명은 명세 표대로 오른다(남는 약점을 기록)', () => {
    CREW.curve = 'B';
    const l2 = stopRisk(mk('loss-fall', { place: 'freight', size: 2 })).lam;
    const l4 = stopRisk(mk('loss-fall', { place: 'freight', size: 4 })).lam;
    expect(l2).toBeCloseTo(0.68, 1);
    expect(l4).toBeCloseTo(0.88, 1);
    expect(stopRisk(mk('loss-fall', { place: 'freight', size: 8 })).lam).toBeCloseTo(0.74, 1); // 8명도 2명(.68)보다 높다
    // 바닥에 닿은 뒤(위험2, 6→8명)에는 다시 오른다: .26→.35
    expect(stopRisk(mk('loss-fall', { place: 'houses', size: 6 })).lam).toBeCloseTo(0.26, 1);
    expect(stopRisk(mk('loss-fall', { place: 'houses', size: 8 })).lam).toBeCloseTo(0.35, 1);
    CREW.curve = 'A';
    expect(stopRisk(mk('loss-fall', { place: 'freight', size: 2 })).lam).toBeCloseTo(0.94, 1);
    expect(stopRisk(mk('loss-fall', { place: 'freight', size: 4 })).lam).toBeCloseTo(0.89, 1);
  });

  it('5 scout_keeps_fate: 정찰 전후 결과와 알맞은 인원·밴드가 같다', () => {
    let seen = 0;
    for (const curve of ['A', 'B'] as const) {
      CREW.curve = curve;
      for (let k = 0; k < 30; k += 1) for (const id of ['freight', 'houses']) for (const size of [2, 4, 8]) {
        const opt = { place: id, size, threat: [0.8, 1, 1.4][k % 3], thrown: k % 2 ? 10 : 0 };
        const a = mk(`scout-fate-${k}`, opt);
        const b = mk(`scout-fate-${k}`, { ...opt, scout: false });
        const ra = stopRisk(a);
        const rb = stopRisk(b);
        expect(rb.known).toBe(false);
        expect(rb.fate).toEqual(ra.fate);
        expect([rb.lam, rb.pDeath, rb.need, rb.ratio, rb.band]).toEqual([ra.lam, ra.pDeath, ra.need, ra.ratio, ra.band]);
        seen += ra.fate.dead.length + ra.fate.hurt.length;
      }
    }
    expect(seen).toBeGreaterThan(0);
  });

  it('5b 정찰조를 실제로 보내도 위험 식 값(lam·pDeath·need·ratio·band)은 그대로다', () => {
    let checked = 0;
    for (let k = 0; k < 40; k += 1) {
      const g = mk(`scout-send-${k}`, { place: 'factory', size: 4, threat: 1, scout: undefined });
      delete g.stop!.scout;
      const before = stopRisk(g);
      expect(before.known).toBe(false);
      const rep = sendScouts(g)!;
      if (rep.dead.length > 0) continue; // 죽은 정찰조가 던져져 무리를 키우는 건 정찰이 드러내는 일이 아니라 따로 생기는 일이다
      checked += 1;
      const after = stopRisk(g);
      expect([after.lam, after.pDeath, after.need, after.ratio, after.band]).toEqual([before.lam, before.pDeath, before.need, before.ratio, before.band]);
    }
    expect(checked).toBeGreaterThan(10);
  });

  it('5c 정찰을 보내면 남은 사람 가운데서 작업조를 다시 고른다(지금 규칙, 검수 PR 395 보통 3)', () => {
    // 위 두 시험은 위험 식 값만 본다. 실제로 나가는 명단은 정찰조를 뺀 줄어든 명단에서 회전 시작점((구간×7) % 남은 수)을
    // 다시 잡으므로, 회전이 명단 끝을 감아 도는 구간에서는 정찰조가 무사히 돌아와도 작업조가 바뀐다. 그 규칙을 그대로 적어 둔다.
    let changed = 0;
    for (let seg = 1; seg <= 40; seg += 1) {
      const g = mk(`scout-names-${seg}`, { place: 'houses', size: 4, threat: 0.8, scout: false });
      delete g.stop!.scout;
      g.seg = seg;
      // 정찰 전 후보 순서: 회전 시작점부터 다 뽑은 뒤 시작점만큼 되돌리면 원래 순서가 된다.
      const rotated = crewNames(g, 'tail', 999);
      const n = rotated.length;
      expect(n).toBeGreaterThan(6);
      const s0 = (seg * 7) % n;
      const base = rotated.map((_, i) => rotated[(i - s0 + n) % n]);
      const before = crewNames(g, 'tail', 4);
      expect(before).toEqual(Array.from({ length: 4 }, (_, i) => base[(s0 + i) % n]));
      const rep = sendScouts(g)!;
      // 고요한 기척(0.8)이면 정찰조는 다치지 않는다: 명단이 바뀌는 까닭이 피해가 아니라 회전임을 분명히 한다.
      expect(rep.dead).toEqual([]);
      expect(rep.hurt).toEqual([]);
      // 정찰조는 작업조 바로 뒤 두 사람이다.
      expect(rep.names).toEqual([base[(s0 + 4) % n], base[(s0 + 5) % n]]);
      const after = crewNames(g, 'tail', 4);
      for (const s of rep.names) expect(after, `구간 ${seg}: 정찰조는 작업조에 다시 들지 않는다`).not.toContain(s);
      const left = base.filter(p => !rep.names.includes(p));
      const s1 = (seg * 7) % left.length;
      expect(after, `구간 ${seg}`).toEqual(Array.from({ length: 4 }, (_, i) => left[(s1 + i) % left.length]));
      if (after.join() !== before.join()) changed += 1;
    }
    // 바뀌는 구간이 실제로 있어야 이 시험이 규칙을 붙잡는다.
    expect(changed).toBeGreaterThan(0);
  });

  it('6 one_survivor: 인원 2, 위험3·길게·경계 거부·기척 1.4에서도 죽은 사람은 한 명 이하다', () => {
    let oneDead = 0;
    for (const curve of ['A', 'B'] as const) {
      CREW.curve = curve;
      for (let k = 0; k < 600; k += 1) {
        const g = mk(`one-survivor-${k}`, { place: 'freight', stay: 'long', size: 2, threat: 1.4, refuse: true, thrown: 10 });
        const risk = stopRisk(g);
        expect(risk.band).toBe('short');
        expect(risk.fate.dead.length, `${curve}/${k}`).toBeLessThanOrEqual(1);
        const r = resolveStop(g, true)!;
        expect(r.dead.length, `${curve}/${k}`).toBeLessThanOrEqual(1);
        oneDead += r.dead.length;
      }
    }
    expect(oneDead).toBeGreaterThan(0);
    // 어느 인원이든 명단에서 한 명은 산다
    for (let k = 0; k < 100; k += 1) for (const size of [2, 3, 5, 8]) {
      const g = mk(`one-survivor-b-${k}`, { place: 'freight', stay: 'long', size, threat: 1.4, refuse: true, thrown: 10 });
      expect(stopRisk(g).fate.dead.length).toBeLessThanOrEqual(Math.max(0, crewNames(g, 'tail', size).length - 1));
    }
  });

  it('7 replay_after_change: 인원을 바꿨다 되돌려도, 저장 불러오기 뒤에도 결과가 같다', () => {
    let seen = 0;
    for (const curve of ['A', 'B'] as const) {
      CREW.curve = curve;
      for (let k = 0; k < 40; k += 1) for (const size of [2, 4, 6]) {
        const g = mk(`replay-${k}`, { place: 'factory', stay: 'long', size, threat: 1.4, scout: false });
        const before = stopRisk(g);
        setStop(g, { crewSize: 8 });
        const changed = stopRisk(g);
        expect(changed.need).toBeCloseTo(before.need, 12);
        setStop(g, { crewSize: size });
        const back = stopRisk(g);
        expect(back.fate, `${curve}/${k}/${size}`).toEqual(before.fate);
        expect([back.lam, back.pDeath, back.need, back.ratio, back.band]).toEqual([before.lam, before.pDeath, before.need, before.ratio, before.band]);
        const loaded = JSON.parse(JSON.stringify(g)) as Game;
        const after = stopRisk(loaded);
        expect(after.fate).toEqual(before.fate);
        expect([after.lam, after.pDeath, after.need, after.ratio, after.band]).toEqual([before.lam, before.pDeath, before.need, before.ratio, before.band]);
        const ra = resolveStop(g, true);
        const rb = resolveStop(loaded, true);
        expect(rb?.dead).toEqual(ra?.dead);
        expect(rb?.injured).toEqual(ra?.injured);
        seen += before.fate.dead.length + before.fate.hurt.length;
      }
    }
    expect(seen).toBeGreaterThan(0);
  });

  it('8 band_line_cuts: 밴드 경계, N=ceil(1.5×need), N>8 문구', () => {
    expect(crewBand(0.79)).toBe('short');
    expect(crewBand(0.8)).toBe('tight');
    expect(crewBand(1.49)).toBe('tight');
    expect(crewBand(1.5)).toBe('enough');
    expect(P.crewBandShort).toBe(0.8);
    expect(P.crewBandEnough).toBe(1.5);
    // stopRisk가 돌려주는 band도 같은 경계를 쓴다: 위험3 보통 need=4.5라 r=0.8은 3.6명, 1.5는 6.75명이다
    const band = (size: number) => stopRisk(mk('band-cut', { size })).band;
    expect(band(3)).toBe('short');
    expect(band(4)).toBe('tight');
    expect(band(6)).toBe('tight');
    expect(band(7)).toBe('enough');

    expect(crewEnoughCount(4.5)).toBe(7);
    expect(crewEnoughCount(1.6)).toBe(3);
    expect(crewEnoughCount(3)).toBe(5);
    expect(crewEnoughCount(16 / 3)).toBe(8);
    expect(crewEnoughCount(5.4)).toBe(9);
    // 문구는 omens.ts 상수와 비교한다
    expect(crewLineText('tight', 3, 'calm')).toBe(CREW_LINE.tight(5));
    expect(crewLineText('short', 4.5, 'dead')).toBe(CREW_LINE.short(7));
    expect(crewLineText('tight', 16 / 3, 'calm')).toBe(CREW_LINE.tight(8));
    expect(crewLineText('tight', 5.4, 'calm')).toBe(CREW_LINE.over);
    expect(crewLineText('short', 6.75, 'hurt')).toBe(CREW_LINE.over);
    expect(CREW_LINE.over).toContain('8명으로도');
    expect(CREW_LINE.tight(5)).toContain('5명쯤');
    expect(CREW_LINE.short(7)).toContain('7명쯤');
    expect(crewLineText('enough', 4.5, 'calm')).toBe(CREW_LINE.enough);
    expect(crewLineText('enough', 4.5, 'light')).toBe(CREW_LINE.enough);
    expect(crewLineText('enough', 4.5, 'hurt')).toBe(CREW_LINE.enoughUnlucky);
    expect(crewLineText('enough', 4.5, 'dead')).toBe(CREW_LINE.enoughUnlucky);

    // 화면 값(riskView)이 같은 글을 쓴다: 위험3 보통(need 4.5, N=7), 길게(need 6.75, N=11)
    const shortView = riskView(mk('band-view', { size: 3 }));
    expect(shortView.crew!.band).toBe('short');
    expect(shortView.crew!.text).toBe(CREW_LINE.short(7));
    expect(shortView.crew!.need).toBeCloseTo(4.5, 9);
    const overView = riskView(mk('band-view', { size: 4, stay: 'long' }));
    expect(overView.crew!.band).toBe('short');
    expect(overView.crew!.text).toBe(CREW_LINE.over);
  });

  it('8c N이 8을 넘으면 8명을 다 보냈을 때의 밴드로 말한다(검수 PR 395 보통 2)', () => {
    // 8 < need ≤ 10: 8명이면 빠듯하다. 위험3 길게, 기척 짙음(need 4.5 × 1.5 × 1.4 = 9.45, 8/9.45 ≈ 0.85)
    const tight = mk('over-tight', { size: 8, stay: 'long', threat: 1.4 });
    expect(tight.guardEscort).toBeFalsy(); // 호위가 붙으면 need가 반으로 준다
    const tv = riskView(tight);
    expect(tv.crew!.need).toBeCloseTo(9.45, 9);
    expect(tv.crew!.band).toBe('tight');
    expect(tv.crew!.text).toBe(CREW_LINE.over);
    expect(crewLineText('short', 9.45, 'hurt')).toBe(CREW_LINE.over);
    // need > 10: 8명으로도 모자란다. 위에 경계 거부 1.5를 더하면 need 14.175, 8/14.175 ≈ 0.56
    const short = mk('over-short', { size: 8, stay: 'long', threat: 1.4, refuse: true });
    expect(short.guardEscort).toBeFalsy();
    const sv = riskView(short);
    expect(sv.crew!.need).toBeCloseTo(14.175, 9);
    expect(sv.crew!.band).toBe('short');
    expect(sv.crew!.text).toBe(CREW_LINE.overShort);
    expect(CREW_LINE.overShort).toContain('8명으로도 모자란다');
    expect(crewLineText('tight', 14.175, 'calm')).toBe(CREW_LINE.overShort);
    // 까닭 줄(crewWhy)과 인원 줄이 같은 말을 한다
    expect(crewWhyText({ place: '화물역', risk: 3, stay: '길게', need: 14.175, crew: 8, band: 'short' })).toContain('모자란다');
  });

  it('8b 충분 밴드에서 해석이 불길하면 운이 나쁘다는 줄로 바뀌고 해석 말은 그대로다', () => {
    let unlucky = 0;
    for (let k = 0; k < 400 && unlucky < 3; k += 1) {
      const g = mk(`unlucky-${k}`, { place: 'houses', size: 8, threat: 1.4 });
      const r = stopRisk(g);
      if (r.band !== 'enough') continue;
      const level = riskLevel(r);
      const v = riskView(g);
      if (level === 'hurt' || level === 'dead') {
        unlucky += 1;
        expect(v.crew!.text).toBe(CREW_LINE.enoughUnlucky);
        expect(v.verdict).toContain('불길하다');
      } else expect(v.crew!.text).toBe(CREW_LINE.enough);
    }
    expect(unlucky).toBeGreaterThan(0);
  });

  it('9 line_only_when_known: 정찰 전·정찰조 전멸·눈보라에는 crew가 null이고, 정찰 뒤에만 세 문구가 뜬다', () => {
    // 정찰 전
    const pre = mk('known-a', { size: 4, scout: undefined });
    delete pre.stop!.scout;
    const v0 = riskView(pre);
    expect(v0.crew).toBeNull();
    expect(v0.unknown).toContain('정찰을 보내지 않으면');
    expect(v0.crewWhy).toBe(crewWhyText(null));
    expect(v0.crewWhy, '정찰 전에는 알맞은 인원 숫자를 쓰지 않는다').not.toMatch(/\d/);

    // 정찰조 전멸: 기척은 모른 채 남는다
    let wiped = 0;
    for (let k = 0; k < 3000 && wiped === 0; k += 1) {
      const g = mk(`known-wipe-${k}`, { place: 'factory', size: 4, threat: 1.4, scout: undefined });
      delete g.stop!.scout;
      const rep = sendScouts(g)!;
      if (rep.dead.length !== rep.names.length) continue;
      wiped += 1;
      const v = riskView(g);
      expect(v.crew).toBeNull();
      expect(v.unknown).toContain('돌아오지 않아');
      expect(v.crewWhy).not.toMatch(/\d/);
    }
    expect(wiped).toBe(1);

    // 눈보라: 정찰이 돌아왔어도 안쪽은 못 본다
    const snow = mk('known-snow', { size: 4 });
    snow.disaster = { kind: 'blizzard', stage: 'active', left: 2 };
    const vs = riskView(snow);
    expect(vs.crew).toBeNull();
    expect(vs.unknown).toContain('눈');
    expect(vs.crewWhy).not.toMatch(/\d/);
    // 눈보라에는 「정찰로 알 수 있다」는 미정찰 안내 대신, 정찰해도 못 읽는다고 말한다(검수 PR 395 낮음 11).
    expect(vs.crewWhy).toBe(crewWhyText(null, true));
    expect(vs.crewWhy).toContain('정찰을 보내도');
    expect(vs.crewWhy).not.toBe(crewWhyText(null));

    // 정찰 뒤: 세 밴드 문구 (위험3 보통 기척 0.8이라 정찰조가 안 다친다, need 3.6, N=6)
    for (const [size, band, text] of [[2, 'short', CREW_LINE.short(6)], [3, 'tight', CREW_LINE.tight(6)], [6, 'enough', null]] as const) {
      let checked = false;
      for (let k = 0; k < 60 && !checked; k += 1) {
        const g = mk(`known-after-${k}`, { place: 'freight', size, threat: 0.8, scout: undefined });
        delete g.stop!.scout;
        sendScouts(g);
        if (!stopRisk(g).known) continue;
        const v = riskView(g);
        expect(v.crew, `${band}`).not.toBeNull();
        expect(v.crew!.band).toBe(band);
        expect(v.unknown).toBeNull();
        expect(v.crew!.text).toBe(text ?? crewLineText('enough', v.crew!.need, v.level!));
        if (text === null) expect([CREW_LINE.enough, CREW_LINE.enoughUnlucky]).toContain(v.crew!.text);
        else expect(v.crew!.text).toBe(text);
        // 까닭 줄은 정찰 뒤에 숫자를 쓴다
        expect(v.crewWhy).toContain('3.6명쯤이 알맞다');
        expect(v.crewWhy).toContain(`지금 ${size}명이면`);
        expect(v.crewWhy).toContain('화물역 위험 3에 보통 체류');
        checked = true;
      }
      expect(checked, band).toBe(true);
    }
    // 문서(정황)로 기척을 아는 길은 코드에 없다: info_documents·stop_receipt는 Game을 읽거나 쓰지 않고,
    // stop.scout은 sendScouts만 켠다. 그래서 이 줄은 시험하지 않는다.
  });

  it('10 crew_cost_unchanged: 노출·관계·산출·표결 빠짐이 곡선과 무관하게 식 전과 같다', () => {
    CREW.cost = 'off'; // 옛 대가 식에서 곡선만 바꿔 본다(결정 359의 새 대가는 시험 11)
    let rises = 0;
    let clean = 0;
    const relChecked: Partial<Record<Comm, number>> = {};
    // 꼬리칸만 보면 궂은일 관계 깎임(의무·기술진, 앞칸)을 한 번도 지나지 않는다. 세 칸을 돌려 가며 낸다.
    const comms: Comm[] = ['tail', ...CHORE_COMMS];
    for (let k = 0; k < 30; k += 1) {
      const comm = comms[k % comms.length];
      const ref: { preview: unknown; gains: unknown; rise: number | null; rel: number | null }[] = [];
      for (const curve of ['off', 'A', 'B'] as CrewCurve[]) {
        CREW.curve = curve;
        // 사람이 죽지 않는 설정(짧게·호위·고요한 기척)에서 비교한다. 곡선이 달라도 노출·관계·산출·빠진 사람 수가 같아야 한다.
        const g = mk(`cost-${k}`, { place: 'houses', stay: 'short', size: 2 + (k % 7), threat: 0.8, escort: true, scout: false, comm });
        const size = g.stop!.crewSize;
        const preview = crewPreview(g, comm);
        expect(preview.to - preview.from).toBeLessThanOrEqual(P.crewGain);
        const exposeBefore = situation(g, comm)[3];
        const awayBefore = g.comms[comm].away;
        const relBefore = g.comms[comm].rel;
        const names = crewNames(g, comm, size);
        const r = resolveStop(g, true)!;
        // 표결 빠짐: 살아 돌아온 작업조만큼 away가 는다(곡선이 사람을 더 죽이든 덜 죽이든 이 식은 같다)
        expect(g.comms[comm].away - awayBefore, `${curve} away`).toBe(names.length - r.dead.length);
        const rise = situation(g, comm)[3] - exposeBefore;
        rises += rise;
        // 관계는 죽음뿐 아니라 부상으로도 따로 움직이니, 아무도 안 죽고 안 다친 판에서만 맞춘다.
        const unharmed = r.dead.length === 0 && r.injured.length === 0;
        const rel = unharmed ? g.comms[comm].rel - relBefore : null;
        if (rel !== null && CHORE_COMMS.includes(comm)) {
          // 궂은일 칸은 실제로 관계가 깎였어야 한다(깎임이 빠지면 같은 값끼리 비교해 통과해 버린다).
          expect(rel, `${comm}/${curve} 궂은일 관계 #${k}`).toBe(preview.rel);
          expect(rel).toBeLessThan(0);
          relChecked[comm] = (relChecked[comm] ?? 0) + 1;
        }
        ref.push({ preview, gains: r.gains, rise: r.dead.length === 0 ? rise : null, rel });
        if (r.dead.length === 0) clean += 1;
      }
      // 곡선이 달라도 미리보기와 산출은 같다. 노출 상승은 아무도 안 죽은 판에서만, 관계는 아무도 안 다친 판에서만 맞춘다.
      for (const i of [1, 2]) {
        expect(ref[i].preview, `curve ${i} preview #${k}`).toEqual(ref[0].preview);
        expect(ref[i].gains, `curve ${i} gains #${k}`).toEqual(ref[0].gains);
        if (ref[i].rise !== null && ref[0].rise !== null) expect(ref[i].rise, `curve ${i} rise #${k}`).toBe(ref[0].rise);
        if (ref[i].rel !== null && ref[0].rel !== null) expect(ref[i].rel, `curve ${i} rel #${k}`).toBe(ref[0].rel);
      }
    }
    expect(clean).toBeGreaterThan(10);
    expect(rises).toBeGreaterThan(0);
    for (const c of CHORE_COMMS) expect(relChecked[c] ?? 0, `${c} 관계를 실제로 맞춰 본 판`).toBeGreaterThan(0);
    // 산출 계수는 알맞은 인원까지 인원이 키운다(결정 375): 알맞은 인원이 8을 넘는 곳(화물역·길게·불길, 9.45)에서 인원만 바꿔 비교한다.
    // 호위를 붙이면 알맞은 인원이 반(4.725)이 되어 8명 전에 포화하므로 호위 없이 잰다.
    const haulGame = (size: number) => mk('cost-haul', { place: 'freight', stay: 'long', size, threat: 1.4, scout: false });
    expect(stopRisk(haulGame(8)).need).toBeGreaterThan(8);
    const haul = (size: number) => Object.values(resolveStop(haulGame(size), true)!.gains).reduce((x, y) => x + (y ?? 0), 0);
    // 알맞은 인원 아래에서는 인원을 늘릴수록 산출이 는다(2 → 4 → 8).
    expect(haul(4)).toBeGreaterThan(haul(2));
    expect(haul(8)).toBeGreaterThan(haul(4));
    expect(P.crewGain).toBe(5);
    expect(P.haulTotal).toBeGreaterThan(0);
  });

  it('11 crew_cost_scales (결정 359): 노출 상승과 표결 빠짐이 인원에 비례하고, 4명은 노출이 옛 식과 같다', () => {
    // 옛 식: 인원과 무관하게 +5, 상한 70, 돌아온 사람 수만큼 빠짐
    CREW.cost = 'off';
    for (const n of [2, 4, 8]) expect(crewGainOf(n)).toEqual({ gain: P.crewGain, cap: P.crewCap });
    expect(crewAwayOf(8)).toBe(8);
    // 후보 X: 인원 비례, 8명이면 +10에 상한 75. 4명은 +5, 상한 70.
    CREW.cost = 'X';
    expect(crewGainOf(4)).toEqual({ gain: 5, cap: 70 });
    expect(crewGainOf(8)).toEqual({ gain: 10, cap: 75 });
    expect(crewGainOf(2)).toEqual({ gain: 2.5, cap: 70 });
    expect(crewAwayOf(8)).toBe(12);
    expect(Object.keys(CREW_COST)).toEqual(['off', 'X']);
    for (const cost of ['X'] as CrewCost[]) {
      CREW.cost = cost;
      let checked = 0;
      for (let k = 0; k < 20; k += 1) {
        const rise: Record<number, number> = {};
        for (const size of [2, 4, 8]) {
          // 사람이 죽지 않는 설정에서 잰다. 미리보기가 실제 상승과 같아야 한다(카드가 거짓말하지 않는다).
          const g = mk(`scale-${cost}-${k}`, { place: 'houses', stay: 'short', size, threat: 0.8, escort: true, scout: false });
          g.comms.tail.base[3] = 40;
          const preview = crewPreview(g, 'tail');
          const before = situation(g, 'tail')[3];
          const awayBefore = g.comms.tail.away;
          const names = crewNames(g, 'tail', size);
          const r = resolveStop(g, true)!;
          if (r.dead.length) break;
          rise[size] = situation(g, 'tail')[3] - before;
          expect(Math.round(before + rise[size]), `${cost} preview ${size} #${k}`).toBe(preview.to);
          expect(g.comms.tail.away - awayBefore, `${cost} away ${size}`).toBe(Math.round(names.length * CREW_COST[cost].away));
        }
        if (Object.keys(rise).length < 3) continue;
        expect(rise[4]).toBeCloseTo(P.crewGain, 9);
        expect(rise[8]).toBeGreaterThan(rise[4]);
        expect(rise[2]).toBeLessThan(rise[4]);
        checked += 1;
      }
      expect(checked, cost).toBeGreaterThan(10);
    }
    // 정찰조의 표결 빠짐은 그대로다(결정 360): 정찰조는 돌아온 사람 수만, 작업조는 새 무게로 빠진다.
    CREW.cost = 'X';
    let scouted = 0;
    for (let k = 0; k < 20 && scouted < 5; k += 1) {
      const g = mk(`scout-away-${k}`, { place: 'houses', stay: 'short', size: 4, threat: 0.8, escort: true });
      const sr = sendScouts(g);
      if (!sr || sr.comm !== 'tail') continue;
      const before = g.comms.tail.away;
      const names = crewNames(g, 'tail', 4);
      const r = resolveStop(g, true)!;
      if (r.dead.length || sr.dead.length) continue;
      expect(g.comms.tail.away - before).toBe(sr.names.length + crewAwayOf(names.length));
      scouted += 1;
    }
    expect(scouted).toBeGreaterThan(0);
  });

  it('12 crew_haul_need (결정 372): 산출 인원 항은 알맞은 인원까지 온전히, 넘는 사람은 절반만(half)·안(none) 보탠다', () => {
    CREW.haul = 'flat';
    for (const n of [2, 4, 8]) expect(crewHaulMult(n, 3)).toBeCloseTo(0.7 + 0.075 * n, 12);
    CREW.haul = 'half';
    // 알맞은 인원 안쪽은 옛 식과 같고, 알맞은 인원이 8이면 어떤 인원이든 옛 식과 같다
    for (const n of [2, 3, 4]) expect(crewHaulMult(n, 4.5)).toBeCloseTo(0.7 + 0.075 * n, 12);
    for (const n of [2, 4, 6, 8]) expect(crewHaulMult(n, 8)).toBeCloseTo(0.7 + 0.075 * n, 12);
    // 알맞은 인원 4에 8명: 0.7 + 0.075×4 + 0.0375×4
    expect(crewHaulMult(8, 4)).toBeCloseTo(1.15, 12);
    expect(crewHaulMult(8, 1.6)).toBeCloseTo(0.7 + 0.075 * 1.6 + 0.0375 * 6.4, 12);
    // none: 넘는 사람은 안 보탠다. 알맞은 인원 안쪽과 8 이상은 옛 식과 같다.
    CREW.haul = 'none';
    expect(crewHaulMult(8, 4)).toBeCloseTo(1.0, 12);
    expect(crewHaulMult(3, 4.5)).toBeCloseTo(0.7 + 0.075 * 3, 12);
    expect(crewHaulMult(6, 8)).toBeCloseTo(0.7 + 0.075 * 6, 12);
    // 실제 정차: 같은 판에서 인원이 알맞은 인원 이하면 산출이 같고, 넘으면 줄거나 같다(반올림)
    const total = (haul: CrewHaul, size: number, k: number) => {
      CREW.haul = haul;
      const g = mk(`haul-${k}`, { place: 'houses', stay: 'short', size, threat: 0.8, escort: true, scout: false });
      return Object.values(resolveStop(g, true)!.gains).reduce((x, y) => x + (y ?? 0), 0);
    };
    // houses·짧게·고요: 알맞은 인원 max(1.6, 1.5×2×0.6×0.8)=1.6
    expect(stopRisk(mk('haul-need', { place: 'houses', stay: 'short', threat: 0.8, escort: true })).need).toBeCloseTo(1.6, 9);
    let less = 0;
    for (let k = 0; k < 20; k += 1) {
      const a = total('flat', 8, k);
      const b = total('half', 8, k);
      const c = total('none', 8, k);
      expect(b, `#${k}`).toBeLessThanOrEqual(a);
      expect(c, `#${k} none`).toBeLessThanOrEqual(b);
      if (b < a) less += 1;
    }
    expect(less).toBeGreaterThan(10);
    // 알맞은 인원이 큰 곳(화물역·길게·불길): 4명은 옛 식과 같다
    expect(stopRisk(mk('haul-big', { place: 'freight', stay: 'long', threat: 1.4 })).need).toBeGreaterThan(8);
    for (let k = 0; k < 5; k += 1) {
      const one = (haul: CrewHaul) => {
        CREW.haul = haul;
        const g = mk(`haul-big-${k}`, { place: 'freight', stay: 'long', size: 4, threat: 1.4, scout: false });
        return resolveStop(g, true)!.gains;
      };
      expect(one('half')).toEqual(one('flat'));
      expect(one('none')).toEqual(one('flat'));
    }
  });

  it('13 crew_real_count (검수 PR 395 보통 1): 고른 인원보다 나갈 사람이 적으면 실제 명단 수로 위험·대가·일지를 세고, 0명이면 지나친다', () => {
    const g = mk('real-count', { place: 'freight', size: 8, threat: 0.8, comm: 'front' });
    // 앞칸에서 두 사람만 남기고 나머지를 떠나보낸다.
    const all = crewNames(g, 'front', 999);
    expect(all.length).toBeGreaterThan(2);
    onDeath(g, 'front', all.slice(2), 'other', false, true);
    const left = crewNames(g, 'front', 8);
    expect(left).toHaveLength(2);
    expect(g.stop!.crewSize).toBe(8);
    const r = stopRisk(g);
    expect(r.ratio).toBeCloseTo(2 / r.need, 12);
    expect(r.band).toBe(crewBand(2 / r.need));
    expect(crewPreview(g, 'front').to - crewPreview(g, 'front').from).toBeLessThanOrEqual(crewGainOf(2).gain);
    const res = resolveStop(g, true)!;
    expect(res.passed).toBe(false);
    expect(g.journal.find(j => j.text.includes('머물렀다'))?.text).toContain('앞칸 2명');

    // 아무도 못 나가면 산출 없이 지나친다.
    const z = mk('real-zero', { place: 'freight', size: 4, threat: 0.8, comm: 'front' });
    onDeath(z, 'front', crewNames(z, 'front', 999), 'other', false, true);
    expect(crewNames(z, 'front', 4)).toHaveLength(0);
    const rz = resolveStop(z, true)!;
    expect(rz.passed).toBe(true);
    expect(rz.gains).toEqual({});
    expect(rz.notes[0]).toContain('나갈 수 있는 사람이 없어');
  });
});
