import { afterEach, describe, expect, it } from 'vitest';
import {
  CAR_COMM, createS1cGame, D, enactLaw, forecast, heatCost, hygieneWhy, insulateCarNote, insulateNumbers, insulatePickLine, insulatedShare, liceChance, P, refreshSit, situation,
} from '../../src/game';
import type { Comm, Game } from '../../src/game';

// 한 칸 개조(단열)의 이득과 치르는 값(결정 217·225). 숫자는 제안이라 값 줄(D.insulate*)에서 파생한 식으로 본다.
// 이득: 온기와 난방 석탄(몫만큼). 값: 단열한 칸마다 과밀, 이가 돌 확률의 배수. 법이 없어도 듣고, 「난방 배당」과는 겹쳐 쌓는다.

const OLD = { warm: D.insulateWarm, heat: D.insulateHeat, crowd: D.insulateCrowd, lice: D.insulateLice, half: D.insulateQuotaHalf };
afterEach(() => {
  D.insulateWarm = OLD.warm; D.insulateHeat = OLD.heat; D.insulateCrowd = OLD.crowd; D.insulateLice = OLD.lice; D.insulateQuotaHalf = OLD.half;
});

const fresh = (): Game => createS1cGame('ins-gain');
function insulate(g: Game, ...cars: string[]): void {
  g.dom!.insulated.push(...cars);
  refreshSit(g);
}
const sit = (g: Game, c: Comm, i: 0 | 1 | 2 | 3): number => situation(g, c)[i];
/** 그 공동체 난방 석탄 한 항(heatCost의 한 칸 몫, 배수 앞). */
const heatTerm = (g: Game, c: Comm): number => (g.comms[c].heat * g.comms[c].pop / 40) * P.coalHeatPerLever;

describe('법이 없어도 단열은 처지를 바꾼다', () => {
  it('값 줄이 켜져 있다(꼬리칸 칸이 셋, 의무칸은 하나)', () => {
    expect(D.insulateWarm).toBeGreaterThan(0);
    expect(D.insulateHeat).toBeGreaterThan(0);
    expect(D.insulateCrowd).toBeGreaterThan(0);
    expect(D.insulateLice).toBeGreaterThan(0);
    expect(D.insulateQuotaHalf).toBe(false);
  });

  it('꼬리칸 한 칸이면 온기가 6 × 1/3 = +2 오른다(법이 없다)', () => {
    const g = fresh();
    const before = sit(g, 'tail', 0);
    insulate(g, 'tail1');
    expect(insulatedShare(g, 'tail')).toBeCloseTo(1 / 3);
    expect(sit(g, 'tail', 0) - before).toBeCloseTo(D.insulateWarm / 3);
    expect(sit(g, 'tail', 0) - before).toBeCloseTo(2);
  });

  it('꼬리칸 세 칸이면 온기가 +6 오른다. 다른 공동체의 온기는 안 움직인다', () => {
    const g = fresh();
    const before = sit(g, 'tail', 0);
    const medBefore = sit(g, 'medtech', 0);
    insulate(g, 'tail1', 'tail2', 'tail3');
    expect(sit(g, 'tail', 0) - before).toBeCloseTo(D.insulateWarm);
    expect(sit(g, 'medtech', 0)).toBeCloseTo(medBefore);
  });

  it('난방 석탄이 단열한 몫만큼 준다(한 칸은 1/3 × 3할 = 1할, 예고와 같은 셈)', () => {
    const g = fresh();
    const base = heatCost(g);
    const baseForecast = forecast(g).coal;
    insulate(g, 'tail1');
    expect(heatCost(g)).toBeCloseTo(base - heatTerm(g, 'tail') * D.insulateHeat / 3);
    expect(forecast(g).coal).toBeCloseTo(baseForecast - heatTerm(g, 'tail') * D.insulateHeat / 3);
    insulate(g, 'tail2', 'tail3');
    expect(heatCost(g)).toBeCloseTo(base - heatTerm(g, 'tail') * D.insulateHeat);
  });

  it('난방 석탄의 줆은 그 공동체 몫에만 걸린다(의무칸 한 칸이면 의무진 몫의 3할)', () => {
    const g = fresh();
    const base = heatCost(g);
    insulate(g, 'medtech');
    expect(heatCost(g)).toBeCloseTo(base - heatTerm(g, 'medtech') * D.insulateHeat);
  });

  it('과밀이 단열한 칸마다 +2 오른다(몫이 아니라 칸 수)', () => {
    const g = fresh();
    const [tail, med] = [sit(g, 'tail', 2), sit(g, 'medtech', 2)];
    insulate(g, 'tail1');
    expect(sit(g, 'tail', 2) - tail).toBeCloseTo(D.insulateCrowd);
    insulate(g, 'tail2');
    expect(sit(g, 'tail', 2) - tail).toBeCloseTo(D.insulateCrowd * 2);
    insulate(g, 'tail3');
    expect(sit(g, 'tail', 2) - tail).toBeCloseTo(D.insulateCrowd * 3);
    insulate(g, 'medtech');
    expect(sit(g, 'medtech', 2) - med).toBeCloseTo(D.insulateCrowd);
  });

  it('이가 돌 확률은 의무칸 한 칸이면 2배, 꼬리칸 한 칸이면 1.33배', () => {
    const g = fresh();
    for (const h of ['normal', 'dirty'] as const) {
      const [tail, med] = [liceChance(g, 'tail', h), liceChance(g, 'medtech', h)];
      expect(tail).toBeGreaterThan(0);
      const g2 = fresh();
      insulate(g2, 'tail1', 'medtech');
      expect(liceChance(g2, 'tail', h) / tail).toBeCloseTo(1 + D.insulateLice / 3);
      expect(liceChance(g2, 'tail', h) / tail).toBeCloseTo(1.33, 2);
      expect(liceChance(g2, 'medtech', h) / med).toBeCloseTo(1 + D.insulateLice);
      expect(liceChance(g2, 'medtech', h) / med).toBeCloseTo(2);
      // 단열하지 않은 공동체는 그대로다.
      expect(liceChance(g2, 'guard', h)).toBeCloseTo(liceChance(g, 'guard', h));
    }
  });

  it('단열한 칸이 있으면 이 카드와 일지의 까닭에 한 마디가 붙는다', () => {
    const g = fresh();
    const plain = hygieneWhy(g, 'tail');
    insulate(g, 'tail1');
    const why = hygieneWhy(g, 'tail');
    expect(why.startsWith(plain.split(' · 과밀')[0]!)).toBe(true);
    expect(why.length).toBeGreaterThan(plain.length);
    expect(why).toMatch(/김이 서려|눅눅/);
    expect(hygieneWhy(g, 'guard')).toBe(hygieneWhy(fresh(), 'guard'));
  });
});

describe('「난방 배당」과 겹쳐 쌓는다', () => {
  it('법이 서 있으면 벌이 걷힌 위에 새 온기가 더해진다(의무칸: 벌 10 + 6)', () => {
    const g = fresh();
    enactLaw(g, 'heat_quota', []);
    const cold = sit(g, 'medtech', 0);
    insulate(g, 'medtech');
    expect(sit(g, 'medtech', 0) - cold).toBeCloseTo(10 + D.insulateWarm);
  });

  it('꼬리칸 세 칸이면 벌 10이 걷히고 +6이 더해져 법 앞보다 온기가 높다', () => {
    const g = fresh();
    const open = sit(g, 'tail', 0);
    enactLaw(g, 'heat_quota', []);
    const cold = sit(g, 'tail', 0);
    expect(cold).toBeCloseTo(open - 10);
    insulate(g, 'tail1', 'tail2', 'tail3');
    expect(sit(g, 'tail', 0)).toBeCloseTo(open + D.insulateWarm);
  });

  it('난방 석탄은 곱한다: 법의 절반 × (1 − 3할 × 몫)', () => {
    const g = fresh();
    enactLaw(g, 'heat_quota', []);
    const base = forecast(g).coal;
    insulate(g, 'tail1', 'tail2', 'tail3');
    const heatMult = 0.5;
    // 꼬리칸 몫만 줄고, 줄어든 만큼에도 법의 절반이 걸린다.
    expect(forecast(g).coal).toBeCloseTo(base - heatTerm(g, 'tail') * D.insulateHeat * heatMult);
  });

  it('과밀과 이는 법과 상관없이 붙는다', () => {
    const g = fresh();
    enactLaw(g, 'heat_quota', []);
    const crowd = sit(g, 'tail', 2);
    const chance = liceChance(g, 'tail', 'normal');
    insulate(g, 'tail1');
    expect(sit(g, 'tail', 2) - crowd).toBeCloseTo(D.insulateCrowd);
    expect(liceChance(g, 'tail', 'normal') / chance).toBeCloseTo(1 + D.insulateLice / 3);
  });

  it('손잡이 insulateQuotaHalf를 켜면 법이 서 있는 동안만 새 온기 이득이 반이다(벌 걷힘은 그대로)', () => {
    D.insulateQuotaHalf = true;
    const g = fresh();
    const open = sit(g, 'medtech', 0);
    insulate(g, 'medtech');
    expect(sit(g, 'medtech', 0) - open).toBeCloseTo(D.insulateWarm); // 법이 없으면 반이 아니다
    const g2 = fresh();
    enactLaw(g2, 'heat_quota', []);
    const cold = sit(g2, 'medtech', 0);
    insulate(g2, 'medtech');
    expect(sit(g2, 'medtech', 0) - cold).toBeCloseTo(10 + D.insulateWarm / 2);
  });
});

describe('값 줄을 0으로 두면 옛 동작과 같다', () => {
  function zeroed(): void {
    D.insulateWarm = 0; D.insulateHeat = 0; D.insulateCrowd = 0; D.insulateLice = 0;
  }
  const COMM_LIST: Comm[] = ['front', 'tail', 'medtech', 'guard', 'engine'];

  it('법이 없으면 효과가 0이다(처지 넷, 난방 석탄, 이 확률 모두)', () => {
    zeroed();
    const base = fresh();
    const g = fresh();
    insulate(g, 'tail1', 'tail2', 'tail3', 'medtech');
    for (const c of COMM_LIST) for (const i of [0, 1, 2, 3] as const) expect(sit(g, c, i), `${c}[${i}]`).toBeCloseTo(sit(base, c, i));
    expect(heatCost(g)).toBeCloseTo(heatCost(base));
    expect(forecast(g).coal).toBeCloseTo(forecast(base).coal);
    for (const c of COMM_LIST) expect(liceChance(g, c, 'normal')).toBeCloseTo(liceChance(base, c, 'normal'));
  });

  it('법이 서 있으면 옛 규칙대로 벌만 걷힌다(의무칸 +10, 꼬리칸 한 칸 +10/3)', () => {
    zeroed();
    const g = fresh();
    enactLaw(g, 'heat_quota', []);
    const [med, tail] = [sit(g, 'medtech', 0), sit(g, 'tail', 0)];
    insulate(g, 'medtech', 'tail1');
    expect(sit(g, 'medtech', 0) - med).toBeCloseTo(10);
    expect(sit(g, 'tail', 0) - tail).toBeCloseTo(10 / 3);
  });

  it('모든 공동체가 단열 없는 판과 같은 난방 예고를 낸다', () => {
    zeroed();
    const g = fresh();
    const base = forecast(g).coal;
    insulate(g, ...Object.keys(CAR_COMM).filter(c => c !== 'engine'));
    expect(forecast(g).coal).toBeCloseTo(base);
  });
});

describe('글귀', () => {
  const BANNED = ['닫았다', '닫힌', '막았다', '잠갔다', '잠긴', '가뒀다', '소독'];
  const BANNED_LICE = ['씻기', '줄을 세', '머리를 깎', '가루', '분무', '소독'];

  it('단열 글귀에 닫았다·막았다·잠갔다·가뒀다·소독이 없고, 까닭을 그 칸 사람 탓으로 적지 않는다', () => {
    const g = fresh();
    insulate(g, 'tail1', 'medtech');
    const lines = [
      insulatePickLine(),
      ...Object.keys(CAR_COMM).filter(c => c !== 'engine').flatMap(c => [insulateNumbers(c), insulateCarNote(g, c)]),
      hygieneWhy(g, 'tail'), hygieneWhy(g, 'medtech'),
    ];
    for (const line of lines) {
      for (const w of [...BANNED, ...BANNED_LICE]) expect(line, `「${w}」`).not.toContain(w);
      expect(line).not.toMatch(/탓/);
    }
    expect(lines.join(' ')).toContain('틈');
  });

  it('고르기 전 글에 얻는 것과 치르는 것의 숫자가 다 보인다(온기, 난방, 과밀)', () => {
    const line = insulatePickLine();
    expect(line).toContain('온기 +2');
    expect(line).toContain('난방 −1할');
    expect(line).toContain('과밀 +2');
    expect(line).toContain('온기 +6');
    expect(line).toContain('난방 −3할');
    expect(insulateNumbers('tail1')).toBe('온기 +2, 난방 −1할, 과밀 +2');
    expect(insulateNumbers('medtech')).toBe('온기 +6, 난방 −3할, 과밀 +2');
  });

  it('칸 창 글은 지금 듣는 값을 적고, 단열하지 않은 칸은 빈 글이다', () => {
    const g = fresh();
    expect(insulateCarNote(g, 'tail1')).toBe('');
    insulate(g, 'tail1');
    const note = insulateCarNote(g, 'tail1');
    expect(note).toContain('온기 +2');
    expect(note).toContain('난방 −1할');
    expect(note).toContain('과밀 +2');
  });

  it('값 줄이 0이면 얻는다는 글을 달지 않는다', () => {
    D.insulateWarm = 0; D.insulateHeat = 0; D.insulateCrowd = 0; D.insulateLice = 0;
    const g = fresh();
    insulate(g, 'tail1');
    expect(insulateCarNote(g, 'tail1')).toBe('');
    expect(insulateNumbers('tail1')).toBe('');
  });
});
