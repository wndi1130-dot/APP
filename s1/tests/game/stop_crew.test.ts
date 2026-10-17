import { afterEach, describe, expect, it } from 'vitest';
import {
  CREW, CREW_LINE, createGame, crewBand, crewEnoughCount, crewLineText, crewMult, crewNames, crewPreview, crewWhyText,
  P, PLACES, resolveStop, riskLevel, riskView, sendScouts, setStop, situation, STAY, stopRisk,
} from '../../src/game';
import type { CrewCurve, Game, StayId } from '../../src/game';

// 정차 작업조 인원과 위험(결정 341, 구현 명세 6장 1~10). 곡선 A·B는 가안이라 둘 다 본다.
// 시험 안에서 CREW.curve를 바꾸면 끝날 때 A로 되돌린다.
afterEach(() => { CREW.curve = 'A'; });

const STAY_RISK: Record<StayId, number> = { short: 0.6, normal: 1, long: 1.5 };
const place = (id: string) => PLACES.find(p => p.id === id)!;

interface Opt { place?: string; stay?: StayId; size?: number; threat?: number; scout?: boolean; thrown?: number; refuse?: boolean; escort?: boolean }
function mk(seed: string, o: Opt = {}): Game {
  const g = createGame(seed);
  g.thrown = o.thrown ?? 0;
  if (o.refuse) { g.comms.guard.fervor = 2; g.comms.guard.rel = -60; }
  if (o.escort) g.guardEscort = true;
  g.phase = 'stop';
  g.stop = {
    place: o.place ?? 'freight', target: 'food', stay: o.stay ?? 'normal', crewComm: 'tail', crewSize: o.size ?? 4,
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

  it('3 existing_crew_never_worse: 4명에서 8명으로 늘려도 기존 4명은 새로 죽거나 다치지 않는다', () => {
    let compared = 0;
    for (const curve of ['A', 'B'] as const) {
      CREW.curve = curve;
      for (let k = 0; k < 60; k += 1) for (const id of ['freight', 'houses', 'factory']) for (const stay of ['short', 'normal', 'long'] as const) {
        const seed = `never-worse-${k}`;
        const opt = { place: id, stay, threat: [0.8, 1, 1.4][k % 3], thrown: k % 2 ? 10 : 0, refuse: k % 4 === 3 };
        const a = mk(seed, { ...opt, size: 4 });
        const b = mk(seed, { ...opt, size: 8 });
        const first4 = crewNames(a, 'tail', 4);
        expect(crewNames(b, 'tail', 8).slice(0, first4.length)).toEqual(first4); // 명단 앞 4명이 같아야 비교가 된다
        const fa = stopRisk(a).fate;
        const fb = stopRisk(b).fate;
        for (const n of first4) {
          if (fb.dead.includes(n)) expect(fa.dead, `${curve}/${seed}/${id}/${stay} 죽음 ${n}`).toContain(n);
          if (fb.hurt.includes(n)) expect(harmed(a, [n]), `${curve}/${seed}/${id}/${stay} 부상 ${n}`).toEqual([n]);
        }
        compared += fa.dead.length + fa.hurt.length;
      }
    }
    expect(compared).toBeGreaterThan(0);
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
    let rises = 0;
    let clean = 0;
    for (let k = 0; k < 30; k += 1) {
      const ref: { preview: unknown; gains: unknown; rise: number | null }[] = [];
      for (const curve of ['off', 'A', 'B'] as CrewCurve[]) {
        CREW.curve = curve;
        // 사람이 죽지 않는 설정(짧게·호위·고요한 기척)에서 비교한다. 곡선이 달라도 노출·관계·산출·빠진 사람 수가 같아야 한다.
        const g = mk(`cost-${k}`, { place: 'houses', stay: 'short', size: 2 + (k % 7), threat: 0.8, escort: true, scout: false });
        const size = g.stop!.crewSize;
        const preview = crewPreview(g, 'tail');
        expect(preview.to - preview.from).toBeLessThanOrEqual(P.crewGain);
        const exposeBefore = situation(g, 'tail')[3];
        const awayBefore = g.comms.tail.away;
        const names = crewNames(g, 'tail', size);
        const r = resolveStop(g, true)!;
        // 표결 빠짐: 살아 돌아온 작업조만큼 away가 는다(곡선이 사람을 더 죽이든 덜 죽이든 이 식은 같다)
        expect(g.comms.tail.away - awayBefore, `${curve} away`).toBe(names.length - r.dead.length);
        const rise = situation(g, 'tail')[3] - exposeBefore;
        rises += rise;
        ref.push({ preview, gains: r.gains, rise: r.dead.length === 0 ? rise : null });
        if (r.dead.length === 0) clean += 1;
      }
      // 곡선이 달라도 미리보기와 산출은 같다. 노출 상승은 아무도 안 죽은 판에서만 맞춘다(죽음은 관계·노출을 따로 바꾼다).
      for (const i of [1, 2]) {
        expect(ref[i].preview, `curve ${i} preview #${k}`).toEqual(ref[0].preview);
        expect(ref[i].gains, `curve ${i} gains #${k}`).toEqual(ref[0].gains);
        if (ref[i].rise !== null && ref[0].rise !== null) expect(ref[i].rise, `curve ${i} rise #${k}`).toBe(ref[0].rise);
      }
    }
    expect(clean).toBeGreaterThan(10);
    expect(rises).toBeGreaterThan(0);
    // 산출 계수 (0.7+0.075×인원)은 인원이 키운다: 같은 판에서 인원만 바꿔 산출을 비교한다
    const haul = (size: number) => {
      const g = mk('cost-haul', { place: 'houses', stay: 'short', size, threat: 0.8, escort: true, scout: false });
      return Object.values(resolveStop(g, true)!.gains).reduce((x, y) => x + (y ?? 0), 0);
    };
    expect(haul(8)).toBeGreaterThan(haul(2));
    expect(P.crewGain).toBe(5);
    expect(P.haulTotal).toBeGreaterThan(0);
  });
});
