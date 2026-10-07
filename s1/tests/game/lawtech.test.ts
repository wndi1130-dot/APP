import { describe, expect, it } from 'vitest';
import {
  agendaOptions, agendaTitle, createGame, createS1cGame, D, domesticForecast, enactLaw, lawOpen, lawTechLines, lawTechRes, refreshSit, repealLaw, situation, techMult, variantMult,
} from '../../src/game';
import type { Game, TechId, Variant } from '../../src/game';

// 기술은 자원을 아끼지 않고 법을 바꾼다(s1c_domestic 7.3). 숫자는 제안이라 규칙의 모양을 본다.

function done(g: Game, id: TechId, variant?: Variant): number {
  g.dom!.techs[id] = { stage: 'done', defect: false, variant, progress: 0, need: 0 } as NonNullable<Game['dom']>['techs'][TechId];
  return variant ? variantMult(g, id, variant) : techMult(g, id);
}
const warm = (g: Game, c: Parameters<typeof situation>[1]) => situation(g, c)[0];
const expo = (g: Game, c: Parameters<typeof situation>[1]) => situation(g, c)[3];

describe('가혹한 법의 벌을 줄인다', () => {
  it('E2 압력 조절: 난방 배당이 서 있을 때만 꼬리칸·경비대 온기 벌을 덜어 준다', () => {
    const g = createS1cGame('lt-e2');
    const m = done(g, 'e2');
    enactLaw(g, 'heat_quota', []);
    const [tail, guard] = [warm(g, 'tail'), warm(g, 'guard')];
    const g2 = createS1cGame('lt-e2');
    enactLaw(g2, 'heat_quota', []);
    expect(tail - warm(g2, 'tail')).toBeCloseTo(5 * m);
    expect(guard - warm(g2, 'guard')).toBeCloseTo(5 * m);
    // 법이 없으면 아무것도 안 준다(공짜 온기가 아니다).
    const g3 = createS1cGame('lt-e2');
    const before = warm(g3, 'tail');
    done(g3, 'e2');
    enactLaw(g3, 'snow_duty', []);
    repealLaw(g3, 'snow_duty');
    expect(warm(g3, 'tail')).toBeCloseTo(before);
  });

  it('E1과 E4를 같이 써도 눈 녹이기 당번의 노출 벌보다 더 덜어 주지 않는다', () => {
    const g = createS1cGame('lt-e14');
    const base = expo(g, 'front');
    enactLaw(g, 'snow_duty', []);
    expect(expo(g, 'front')).toBeCloseTo(base + 15);
    const m1 = done(g, 'e1');
    const m4 = done(g, 'e4');
    refreshSit(g);
    expect(m4).toBeGreaterThan(0);
    expect(expo(g, 'front')).toBeCloseTo(base + 15 - Math.min(15, 7 * m1 + 15 * m4));
    expect(warm(g, 'front')).toBeCloseTo(warm(createS1cGame('lt-e14'), 'front') - 5 + 5 * m1);
  });

  it('E3 나: 난방 배당 아래 앞칸 온기 +5', () => {
    const g = createS1cGame('lt-e3b');
    const m = done(g, 'e3', 'b');
    const before = warm(g, 'front');
    enactLaw(g, 'heat_quota', []);
    expect(warm(g, 'front') - before).toBeCloseTo(5 * m);
  });

  it('E5: 단열한 객차의 몫만큼 난방 배당 온기 벌을 막는다', () => {
    const g = createS1cGame('lt-e5');
    enactLaw(g, 'heat_quota', []);
    const cold = warm(g, 'medtech');
    g.dom!.insulated.push('medtech');
    refreshSit(g);
    expect(warm(g, 'medtech') - cold).toBeCloseTo(10);
  });
});

describe('이상 법을 사는 값을 깎는다', () => {
  it('M5: 모두를 치료의 의약품 소모 ×1.6 → ×1.3', () => {
    const g = createS1cGame('lt-m5');
    expect(lawTechRes(g, 'treat_all').medMult).toBe(1.6);
    const m = done(g, 'm5');
    expect(lawTechRes(g, 'treat_all').medMult).toBeCloseTo(1.6 - 0.3 * m);
    expect(lawTechRes(createGame('lt-s1a'), 'treat_all').medMult).toBe(1.6);
  });

  it('E3 가: 공동 난방이 서 있으면 석탄이 덜 든다', () => {
    const g = createS1cGame('lt-e3a');
    const before = domesticForecast(g).coal;
    const m = done(g, 'e3', 'a');
    expect(domesticForecast(g).coal).toBeCloseTo(before);
    enactLaw(g, 'common_heating', []);
    expect(domesticForecast(g).coal).toBeCloseTo(before - D.e3aHeatCoal * m);
    expect(lawTechLines(g, 'common_heating')[0]).toContain('+1.25 → +0.6');
  });
});

describe('가혹한 법에 덜 잔혹한 변형을 연다', () => {
  it('M3 가면 종자곡 반만 풀기가 나란히 열리고 하나가 서면 다른 하나는 닫힌다. 1회 식량은 묶어서 한 번', () => {
    const g = createS1cGame('lt-seed');
    g.food = 40;
    expect([lawOpen(g, 'seed_grain'), lawOpen(g, 'seed_half')]).toEqual([true, false]);
    done(g, 'm3', 'a');
    expect([lawOpen(g, 'seed_grain'), lawOpen(g, 'seed_half')]).toEqual([true, true]);
    const food = g.food;
    enactLaw(g, 'seed_half', []);
    expect(g.food).toBe(food + 15);
    expect(lawOpen(g, 'seed_grain')).toBe(false);
    repealLaw(g, 'seed_half');
    enactLaw(g, 'seed_grain', []);
    expect(g.food).toBe(food + 15);
  });

  it('X1이면 아동 노동 짐 꾸리기만이 열린다: 산출 +10%, 꼬리칸 노출 벌 없음', () => {
    const g = createS1cGame('lt-child');
    g.coal = 30;
    expect(lawOpen(g, 'child_pack')).toBe(false);
    done(g, 'x1');
    expect(lawOpen(g, 'child_pack')).toBe(true);
    const ex = expo(g, 'tail');
    enactLaw(g, 'child_pack', []);
    expect(expo(g, 'tail')).toBe(ex);
    expect(lawTechRes(g, 'child_pack').haulMult).toBe(1.1);
    expect(lawOpen(g, 'child_labor')).toBe(false);
  });

  it('원래 법이 서 있으면 변형은 개정 안건이 되고, 통과하면 원래 법이 내려간다(반발·1회 효과 없음)', () => {
    const g = createS1cGame('lt-amend');
    g.food = 40;
    enactLaw(g, 'seed_grain', []);
    done(g, 'm3', 'a');
    g.food = 200;
    const opt = agendaOptions(g).options.find(o => 'law' in o && o.law === 'seed_half');
    expect(opt).toMatchObject({ law: 'seed_half', amend: 'seed_grain' });
    expect(agendaTitle(opt!)).toBe('종자곡 풀기 개정: 종자곡 반만 풀기');
    const [food, front] = [g.food, g.comms.front.rel];
    enactLaw(g, 'seed_half', []);
    expect(g.passed.seed_grain).toBeUndefined();
    expect(g.passed.seed_half).toBeDefined();
    expect(g.food).toBe(food);
    expect(g.comms.front.rel).toBe(front - 10);
  });

    it('S1a 판에선 변형 법이 안 열린다', () => {
    const g = createGame('lt-s1a-v');
    g.food = 10;
    g.coal = 10;
    expect([lawOpen(g, 'seed_half'), lawOpen(g, 'child_pack')]).toEqual([false, false]);
  });
});
