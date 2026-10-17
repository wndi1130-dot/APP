import { describe, expect, it } from 'vitest';
import {
  createS1cGame, D, effThreat, enableScoutGear, gearOwned, hangLure, lureBlock, P, restoreBlock, restoreCost, riskView, scoutHaulNow, scoutPlan,
  sendScouts, startRestore, stopRisk, techMult, techShown, techVariants, toggleGear,
} from '../../src/game';
import type { Game, TechId, Variant, Weather } from '../../src/game';

// 정찰 장비와 소음(결정 360·371·373, coord fun/구현명세_정찰_연구_v2 6장). 값은 가안이라 D의 값에서 셈한다.

interface Opt { place?: string; size?: number; threat?: number; weather?: Weather; thrown?: number; on?: boolean }
type Tech = [TechId, Variant | undefined, ('done' | 'defective')?];

/** 내정 판에 정차를 세우고 기술을 박는다. on이 false면 정찰 장비를 켜지 않는다 */
function mk(seed: string, techs: Tech[] = [], o: Opt = {}): Game {
  const g = createS1cGame(seed);
  if (o.on !== false) enableScoutGear(g);
  for (const [id, variant, stage = 'done'] of techs) g.dom!.techs[id] = { stage, defect: stage === 'defective', progress: 3, need: 3, ...(variant ? { variant } : {}) };
  g.thrown = o.thrown ?? 0;
  g.phase = 'stop';
  g.stop = { place: o.place ?? 'freight', target: 'food', stay: 'normal', crewComm: 'tail', crewSize: o.size ?? 4, threat: o.threat ?? 1, weather: o.weather ?? 'snow', done: false, result: null };
  return g;
}

const fateOf = (g: Game) => { const f = stopRisk(g).fate; return { dead: [...f.dead], hurt: [...f.hurt] }; };

describe('scout_gear', () => {
  it('1 no_gear_same: 장비가 없거나 끈 판이면 정찰 값이 지금과 같고, 켠 판도 장비가 없으면 결과가 같다', () => {
    const off = mk('sg-1', [['x2', undefined]], { on: false });
    expect(gearOwned(off)).toEqual({ glass: 0, signal: 0, pedal: 0, motor: 0, lure: 0 });
    expect(scoutPlan(off, off.stop!)).toMatchObject({ size: P.scoutSize, risk: 1, noise: 0, haul: P.scoutHaul, blind: false });
    expect(techVariants(off, 'x2')).toBeUndefined();
    expect(restoreBlock(off, 'r4')).toBe('아직 이 열차에서 못 쓴다');
    expect(restoreBlock(off, 'w4')).toBe('아직 이 열차에서 못 쓴다');
    expect(techShown(off, 'r4')).toBe(false);
    const a = mk('sg-1b', [], { on: false });
    const b = mk('sg-1b', []);
    sendScouts(a);
    sendScouts(b);
    expect(b.stop!.scoutReport).toEqual(a.stop!.scoutReport);
    expect(fateOf(b)).toEqual(fateOf(a));
    expect([b.stop!.noise, b.stop!.scoutGear]).toEqual([undefined, undefined]);
    expect(scoutHaulNow(b.stop!)).toBe(P.scoutHaul);
    // 켠 판에는 r4·w4와 핸드카 갈래가 있다
    expect(techVariants(b, 'x2')).toBeDefined();
    expect(techShown(b, 'w4')).toBe(true);
  });

  it('2 quiet_scout_keeps_fate: 장비 없음·망원경·수신호로 정찰하면 정찰 전후 결과가 같다', () => {
    // 정찰조가 죽으면 시신이 생겨 장작불 불빛이 붙는다(기존 규칙). 그 판은 빼고 본다.
    let seen = 0;
    for (const techs of [[], [['r4', 'a']], [['r4', 'b']]] as Tech[][]) {
      for (let i = 0; i < 30; i += 1) {
        const g = mk(`sg-2-${i}`, techs, { threat: 1.4, thrown: 2 });
        const before = fateOf(g);
        sendScouts(g);
        expect(g.stop!.noise ?? 0).toBe(0);
        if (g.stop!.scoutReport!.dead.length) continue;
        seen += 1;
        expect(fateOf(g), `${JSON.stringify(techs)} ${i}`).toEqual(before);
      }
    }
    expect(seen).toBeGreaterThan(60);
  });

  it('3 glass_cuts_scout_risk: 망원경은 정찰조 위험 ×(1 − 0.6m), 결함판은 m이 절반', () => {
    const full = mk('sg-3', [['r4', 'a']]);
    const m = techMult(full, 'r4');
    expect(m).toBeGreaterThan(0);
    expect(scoutPlan(full, full.stop!).risk).toBeCloseTo(1 - D.glassRisk * m, 9);
    const half = mk('sg-3', [['r4', 'a', 'defective']]);
    const mh = techMult(half, 'r4');
    expect(mh).toBeCloseTo(m * D.defectMult, 9);
    expect(scoutPlan(half, half.stop!).risk).toBeCloseTo(1 - D.glassRisk * mh, 9);
    // 정찰 산출 깎임과 정찰조 수는 그대로
    expect(scoutPlan(full, full.stop!)).toMatchObject({ size: P.scoutSize, haul: P.scoutHaul, noise: 0 });
  });

  it('4 glass_blind_weather: 안개·눈보라·진눈깨비엔 효과 없음, 소리는 어느 날씨에도 없다', () => {
    for (const w of ['fog', 'blizzard', 'sleet', 'snow', 'overcast', 'clear', 'cold', 'cold_front'] as Weather[]) {
      const g = mk(`sg-4-${w}`, [['r4', 'a']], { weather: w });
      const p = scoutPlan(g, g.stop!);
      const blind = ['fog', 'blizzard', 'sleet'].includes(w);
      expect(p.blind, w).toBe(blind);
      expect(p.risk < 1, w).toBe(!blind);
      sendScouts(g);
      expect(g.stop!.noise ?? 0, w).toBe(0);
      expect(g.journal.some(j => j.text.includes('망원경으로 멀리 보지 못했다')), w).toBe(blind);
    }
  });

  it('5 glass_parts: 망원경 갈래는 만들 때 부품 2가 더 들고, 수신호는 안 든다', () => {
    const prep = (seed: string, extra: number) => {
      const g = mk(seed);
      const d = g.dom!;
      d.frags.radio = 5;
      d.wood = 50;
      d.scrap = 50;
      d.restoring = null;
      d.parts = restoreCost('r4', g).parts + extra;
      return g;
    };
    expect(startRestore(prep('sg-5a', 0), 'r4', 'full', 'a')).toBe(false);
    const ok = prep('sg-5b', D.glassParts);
    expect(startRestore(ok, 'r4', 'full', 'a')).toBe(true);
    expect(ok.dom!.parts).toBe(0);
    expect(startRestore(prep('sg-5c', 0), 'r4', 'full', 'b')).toBe(true);
  });

  it('6 pedal_quiet_place_only: 페달은 산출 곱 0.8 + 0.1m, 원래 고요한 곳에서만 기척 +1', () => {
    for (const threat of [0.8, 1, 1.4]) {
      const g = mk(`sg-6-${threat}`, [['x2', 'a']], { threat });
      const m = techMult(g, 'x2');
      const p = scoutPlan(g, g.stop!);
      expect(p.haul).toBeCloseTo(P.scoutHaul + D.pedalHaul * m, 9);
      expect(p.noise, String(threat)).toBe(threat === 0.8 ? 1 : 0);
      expect(p.risk).toBe(1);
    }
    // 변형이 없는 옛 저장의 핸드카는 페달로 읽는다
    const old = mk('sg-6-old', [['x2', undefined]]);
    expect(gearOwned(old).pedal).toBeGreaterThan(0);
  });

  it('7 motor_always_noise: 발동기는 정찰조 위험 ×(1 − 0.6m)(결정 394), 산출 곱 0.8 + 0.2m, 늘 기척 +1, 짙음 위로는 안 간다', () => {
    for (const threat of [0.8, 1, 1.4]) {
      const g = mk(`sg-7-${threat}`, [['x2', 'b']], { threat });
      const m = techMult(g, 'x2');
      const p = scoutPlan(g, g.stop!);
      expect(p.risk).toBeCloseTo(1 - D.motorRisk * m, 9);
      expect(p.haul).toBeCloseTo(Math.min(1, P.scoutHaul + D.motorHaul * m), 9);
      expect(p.noise).toBe(1);
      sendScouts(g);
      expect(g.stop!.noise).toBe(1);
      expect(effThreat(g.stop)).toBe(threat === 0.8 ? 1 : 1.4);
      expect(g.stop!.threat).toBe(threat);
      expect(scoutHaulNow(g.stop!)).toBeCloseTo(p.haul, 9);
    }
  });

  it('8 signal_one_scout: 수신호면 정찰조 한 명, 위험 ×2, 그 한 명이 못 돌아오면 기척을 모른다', () => {
    const g = mk('sg-8', [['r4', 'b']]);
    expect(scoutPlan(g, g.stop!)).toMatchObject({ size: D.signalSize, risk: D.signalRisk });
    sendScouts(g);
    expect(g.stop!.scoutReport!.names).toHaveLength(1);
    // 위험한 곳에서 씨앗을 돌려 한 명이 못 돌아온 판을 찾는다
    let lost: Game | null = null;
    for (let i = 0; i < 400 && !lost; i += 1) {
      const x = mk(`sg-8-${i}`, [['r4', 'b']], { threat: 1.4, thrown: 3 });
      sendScouts(x);
      if (x.stop!.scoutReport!.dead.length === 1) lost = x;
    }
    expect(lost).not.toBeNull();
    expect(lost!.stop!.scout).toBe(false);
    expect(stopRisk(lost!).known).toBe(false);
  });

  it('9 lure_lowers_and_costs: 정찰조가 돌아온 정차에서만 걸고, 기척 −1·부품 −1, 고요 아래로는 안 간다', () => {
    const g = mk('sg-9', [['w4', undefined]], { threat: 1 });
    expect(lureBlock(g)).toBe('정찰 뒤에 건다');
    sendScouts(g);
    expect(g.stop!.scout).toBe(true);
    g.dom!.parts = 3;
    expect(lureBlock(g)).toBeUndefined();
    expect(hangLure(g)).toBe(true);
    expect([g.stop!.noise, g.dom!.parts, effThreat(g.stop)]).toEqual([-1, 3 - D.lureParts, 0.8]);
    expect(lureBlock(g)).toBe('이미 걸었다');
    expect(hangLure(g)).toBe(false);
    const calm = mk('sg-9b', [['w4', undefined]], { threat: 0.8 });
    sendScouts(calm);
    expect(lureBlock(calm)).toBe('이미 고요하다');
    const poor = mk('sg-9c', [['w4', undefined]], { threat: 1.4 });
    sendScouts(poor);
    poor.dom!.parts = 0;
    expect(lureBlock(poor)).toBe('부품이 모자라다');
    expect(lureBlock(mk('sg-9d', [], { threat: 1 }))).toBe('미끼가 없다');
  });

  it('10 noise_step_exact: 고요+1 보통, 보통+1 짙음, 짙음+1 짙음, 고요+2 짙음, 소음이 없으면 원래 값', () => {
    const at = (threat: number, noise: number) => effThreat({ place: 'freight', target: null, stay: 'normal', crewComm: 'tail', crewSize: 4, threat, noise, done: false, result: null });
    expect(at(0.8, 1)).toBe(1);
    expect(at(1, 1)).toBe(1.4);
    expect(at(1.4, 1)).toBe(1.4);
    expect(at(0.8, 2)).toBe(1.4);
    expect(at(1, -1)).toBe(0.8);
    expect(at(0.8, -1)).toBe(0.8);
    expect(at(1.2, 0)).toBe(1.2);
  });

  it('11 noise_only_raises_fate: 소리로 기척이 오르면 원래 다칠 사람은 그대로이고 새로 더 다칠 수만 있다. 2명이어도 한 명은 산다', () => {
    for (let i = 0; i < 40; i += 1) {
      const quiet = mk(`sg-11-${i}`, [], { threat: 0.8, size: 6 });
      const loud = mk(`sg-11-${i}`, [['x2', 'b']], { threat: 0.8, size: 6 });
      sendScouts(quiet);
      sendScouts(loud);
      expect(loud.stop!.noise).toBe(1);
      const a = fateOf(quiet);
      const b = fateOf(loud);
      const harmedA = [...a.dead, ...a.hurt];
      const harmedB = [...b.dead, ...b.hurt];
      for (const n of harmedA) expect(harmedB, `${i} ${n}`).toContain(n);
      for (const n of a.dead) expect(b.dead).toContain(n);
    }
    for (let i = 0; i < 40; i += 1) {
      const g = mk(`sg-11b-${i}`, [['x2', 'b']], { threat: 1.4, size: 2, thrown: 3 });
      sendScouts(g);
      expect(fateOf(g).dead.length).toBeLessThanOrEqual(1);
    }
  });

  it('12 view_now_only: 정찰 전엔 소음 글이 없고, 정찰 뒤 「지금」 줄과 본 것이 함께 뜬다. 까닭줄에 소리 한 줄', () => {
    const g = mk('sg-12', [['x2', 'b']], { threat: 0.8 });
    expect(riskView(g).now).toBeNull();
    expect(riskView(g).why.join(' ')).not.toContain('소리');
    sendScouts(g);
    const v = riskView(g);
    expect(v.now).toBe('발동기 소리에 안쪽이 술렁인다. 지금 기척: 보통(정찰조가 본 것: 고요).');
    expect(v.omen).toBeTruthy();
    expect(v.why).toContain('정찰 장비 소리가 망자를 끌었다');
    expect(g.journal.at(-1)!.text).toBe(v.now);
    // 미끼 뒤
    const l = mk('sg-12b', [['w4', undefined]], { threat: 1 });
    sendScouts(l);
    l.dom!.parts = 2;
    hangLure(l);
    expect(riskView(l).now).toBe('태엽 소리가 망자를 반대편으로 끌었다. 지금 기척: 고요(정찰조가 본 것: 보통).');
    // 눈보라가 닥친 정차는 정찰해도 모른다
    const b = mk('sg-12c', [['x2', 'b']], { threat: 0.8 });
    b.disasters = true;
    b.disaster = { kind: 'blizzard', stage: 'active', left: 1 } as Game['disaster'];
    sendScouts(b);
    expect(riskView(b).now).toBeNull();
    expect(riskView(b).level).toBeNull();
  });

  it('13 save_and_toggle: 장비를 두고 가면 얻는 것도 대가도 없고, 저장 불러오기 뒤 칸이 남는다', () => {
    const g = mk('sg-13', [['x2', 'b'], ['r4', 'a']], { threat: 0.8 });
    toggleGear(g, 'cart');
    expect(scoutPlan(g, g.stop!)).toMatchObject({ noise: 0, haul: P.scoutHaul });
    toggleGear(g, 'cart');
    expect(scoutPlan(g, g.stop!).noise).toBe(1);
    toggleGear(g, 'glass');
    expect(scoutPlan(g, g.stop!).risk).toBeCloseTo(1 - D.motorRisk * techMult(g, 'x2'), 9);
    sendScouts(g);
    toggleGear(g, 'glass'); // 보낸 뒤엔 못 바꾼다
    expect(g.stop!.gear).toEqual({ cart: true, glass: false });
    expect(g.stop!.scoutGear).toMatchObject({ glass: 0, motor: techMult(g, 'x2'), noise: 1 });
    const back = JSON.parse(JSON.stringify(g)) as Game;
    expect([back.gearOn, back.stop!.noise, back.stop!.gear, back.stop!.scoutGear]).toEqual([true, 1, { cart: true, glass: false }, g.stop!.scoutGear]);
    expect(effThreat(back.stop)).toBe(effThreat(g.stop));
    expect(scoutHaulNow(back.stop!)).toBe(scoutHaulNow(g.stop!));
  });
});
