import { afterEach, describe, expect, it } from 'vitest';
import {
  COMMS, createS1cGame, chiefPick, completeRestore, delegateTick, migrateDomestic, moveTask,
  offerRestores, prereqs, restoreCheck, restoreCost, runWorkshop, startRestore, techShown,
  TECHS, usefulVariant, workPower, workshopChief, workshopState,
} from '../../src/game';
import type { Game, TechId, Variant } from '../../src/game';
import { enableSupplies, SUPPLIES_BOT, SUPPLIES_PROBE, suppliesNeed, suppliesUse } from '../../src/game/supplies';
import { playGame, suppliesFirst } from '../../tools/s1c_bot';
import { applyStep } from '../../src/ui/repro';

afterEach(() => {
  delete SUPPLIES_PROBE.onMake;
  delete SUPPLIES_PROBE.onRestore;
  delete SUPPLIES_PROBE.onGain;
});

function fresh(pop = 200): Game {
  const g = createS1cGame('sup-make-unit');
  enableSupplies(g);
  g.sup = 0;
  g.ledger = [];
  const d = g.dom!;
  d.scrap = d.wood = 100;
  d.parts = d.target = 0;
  d.frags.craft = 10;
  for (const c of COMMS) g.comms[c].pop *= pop / 200;
  return g;
}

function done(g: Game, id: TechId, variant?: Variant): void {
  g.dom!.techs[id] = { stage: 'done', defect: false, progress: 0, need: 0, ...(variant ? { variant } : {}) };
}

function ready(pop = 200, variant?: Variant): Game {
  const g = fresh(pop);
  done(g, 'w6');
  if (variant) done(g, 'w7', variant);
  g.dom!.order = ['sup'];
  return g;
}

function work(g: Game, amount: number) {
  g.dom!.workDebt = workPower(g) - amount;
  return runWorkshop(g);
}

describe('생필품 공방: 켬과 연구', () => {
  it('꺼진 판에는 일·쓸모·복원 제안·새 상태가 생기지 않는다', () => {
    const g = createS1cGame('sup-make-off');
    const order = [...g.dom!.order];
    g.dom!.frags.craft = 10;
    for (const id of ['w6', 'w7', 'w8'] as const) {
      expect(usefulVariant(g, id)).toBeNull();
      expect(techShown(g, id)).toBe(false);
      expect(restoreCheck(g, id).offer).toBe(false);
    }
    offerRestores(g);
    runWorkshop(g);
    expect(g.dom!.order).toEqual(order);
    expect(g.dom!.offered).not.toContain('w6');
    expect(g.dom).not.toHaveProperty('supWork');
    expect(g.dom).not.toHaveProperty('supFineOn');
    expect(g).not.toHaveProperty('sup');
    expect(g).not.toHaveProperty('supFine');
  });

  it('w6 전·옛 저장의 order는 그대로이고 복원을 마치면 맨 뒤에 한 번 붙는다', () => {
    const g = fresh();
    const d = g.dom!;
    d.order = ['modify', 'parts', 'restore'];
    migrateDomestic(g);
    expect(d.order).toEqual(['modify', 'parts', 'restore']);
    expect(startRestore(g, 'w6', 'full')).toBe(true);
    expect(d.order).not.toContain('sup');
    work(g, restoreCost('w6').work);
    expect(d.order).toEqual(['modify', 'parts', 'restore', 'sup']);
    moveTask(g, 'sup', -1);
    completeRestore(g, 'w6');
    expect(d.order).toEqual(['modify', 'parts', 'sup', 'restore']);
  });

  it('선행은 w6→w7→w8이며 기존 공작 선행과 같은 단 복원 값은 그대로다', () => {
    expect(prereqs('w6')).toEqual([]);
    expect(prereqs('w7')).toEqual(['w6']);
    expect(prereqs('w8')).toEqual(['w7']);
    expect(prereqs('w2')).toEqual(['w1']);
    expect(prereqs('w3')).toEqual(['w2']);
    expect(restoreCost('w6')).toEqual(restoreCost('w1'));
    expect(restoreCost('w7')).toEqual(restoreCost('w2'));
    expect(restoreCost('w8')).toEqual(restoreCost('w3'));
    expect(TECHS.w8.upkeep).toEqual({ parts: 0.25 });
    const g = fresh();
    expect(usefulVariant(g, 'w6')).toBeUndefined();
    expect(usefulVariant(g, 'w7')).toBe('a');
    expect(usefulVariant(g, 'w8')).toBeNull();
    for (const v of Object.values(TECHS.w7.variants!)) {
      expect([...v.label].length).toBeLessThanOrEqual(15);
      expect([...v.say].length).toBeLessThanOrEqual(40);
    }
  });

  it('맡긴 공방도 새 일과 사용자가 옮긴 자리를 보존한다', () => {
    const g = fresh();
    const d = g.dom!;
    g.seg = 20;
    for (const c of COMMS) { g.comms[c].rel = 50; g.comms[c].grudge = 0; }
    const chief = workshopChief(g)!;
    chief.trait = 'fear';
    d.delegate.on = true;
    done(g, 'w6');
    d.order.push('sup');
    delegateTick(g);
    expect(d.order.at(-1)).toBe('sup');
    moveTask(g, 'sup', -1); moveTask(g, 'sup', -1);
    delegateTick(g);
    expect(d.order.indexOf('sup')).toBe(1);
    expect(d.order.filter(t => t === 'sup')).toHaveLength(1);
  });
});

describe('생필품 공방: 일·고철·상한', () => {
  it('w6이 없거나 깃발을 끄면 남아 있는 sup 일도 돈다거나 상태를 만들지 않는다', () => {
    const g = fresh();
    g.dom!.order = ['sup'];
    expect(work(g, 1).used).toBe(0);
    done(g, 'w6');
    g.supOn = false;
    expect(work(g, 1).used).toBe(0);
    expect(g.dom).not.toHaveProperty('supWork');
    expect(g.sup).toBe(0);
  });

  it('일 0.5와 고철 1로 하나를 만들며 진행을 이월하고 장부에 적는다', () => {
    const g = ready();
    const d = g.dom!;
    work(g, 0.2);
    expect(d.supWork).toBeCloseTo(0.2);
    expect(g.sup).toBe(0);
    expect(d.scrap).toBe(100);
    work(g, 0.3);
    expect(g.sup).toBe(1);
    expect(d.scrap).toBe(99);
    expect(d.supWork).toBeCloseTo(0);
    expect(g.ledger?.filter(r => r.why === 'sup.make')).toEqual([{ k: 'sup', d: 1, why: 'sup.make' }]);
    expect(workshopState(g)).toEqual({ now: '생필품 만들기', mode: 'work' });
  });

  it.each([
    ['a', 0.35, 1.25, 1], ['b', 0.65, 1.5, 1.5],
  ] as const)('w7%s의 일·고철·생산 배수를 그대로 쓴다', (v, labor, scrap, yieldAmount) => {
    const g = ready(400, v);
    expect(work(g, labor).used).toBeCloseTo(labor);
    expect(g.sup).toBeCloseTo(yieldAmount);
    expect(g.dom!.scrap).toBeCloseTo(100 - scrap);
  });

  it('인구 200이면 한 정산에 1까지 만들고 남은 일은 개조로 간다', () => {
    const g = ready();
    const d = g.dom!;
    d.order = ['sup', 'modify'];
    d.job = { kind: 'insulate', car: 'tail1', progress: 0, need: 3 };
    expect(suppliesNeed(g)).toBe(4);
    expect(work(g, 2).used).toBeCloseTo(2);
    expect(g.sup).toBe(1);
    expect(d.job.progress).toBeCloseTo(1.5);
    expect(d.scrap).toBe(99);
  });

  it('인구 200의 w7b는 상한 1.0만 만들며 일 0.433333과 고철 1.0만 쓴다', () => {
    const g = ready(200, 'b');
    const labor = 0.65 / 1.5;
    expect(work(g, 2).used).toBeCloseTo(labor);
    expect(g.sup).toBeCloseTo(1);
    expect(g.dom!.scrap).toBeCloseTo(99);
    expect(g.dom!.supWork).toBeCloseTo(0);
    g.dom!.order.push('modify');
    g.dom!.job = { kind: 'insulate', car: 'tail1', progress: 0, need: 3 };
    expect(work(g, 2).used).toBeCloseTo(2);
    expect(g.dom!.job.progress).toBeCloseTo(2 - labor);
    expect(g.sup).toBeCloseTo(2);
  });

  it('좋은 물건 켬은 w8 뒤에만 기록·재현되며 소수 상한도 일·고철에 비례한다', () => {
    const g = ready(100);
    const on = { a: 'dom-sup-fine', d: { on: '1' } };
    expect(applyStep(g, on)).toBeTruthy();
    expect(g.dom).not.toHaveProperty('supFineOn');
    done(g, 'w8');
    const replay = structuredClone(g);
    expect(applyStep(g, on)).toBeNull();
    expect(applyStep(replay, on)).toBeNull();
    expect(replay).toEqual(g);
    expect(work(g, 1).used).toBeCloseTo(0.25);
    expect(g.supFine).toBeCloseTo(0.5);
    expect(g.sup).toBe(0);
    expect(g.dom!.scrap).toBeCloseTo(99);
    expect(applyStep(g, { a: on.a, d: { on: '0' } })).toBeNull();
    work(g, 1);
    expect(g.sup).toBeCloseTo(0.5);
    expect(g.supFine).toBeCloseTo(0.5);
    const off = createS1cGame('sup-fine-off');
    done(off, 'w8');
    expect(applyStep(off, on)).toBeTruthy();
    expect(off.dom).not.toHaveProperty('supFineOn');
    expect(off).not.toHaveProperty('supFine');
  });

  it('w7b 좋은 물건은 한 몫 1과 고철 두 배를 쓰고 생필품 상한을 함께 쓴다', () => {
    const g = ready(200, 'b');
    done(g, 'w8');
    applyStep(g, { a: 'dom-sup-fine', d: { on: '1' } });
    const made: [number, boolean][] = [];
    SUPPLIES_PROBE.onMake = (_g, amount, fine) => { made.push([amount, fine]); };
    expect(work(g, 2).used).toBeCloseTo(0.65);
    expect(g.supFine).toBeCloseTo(1);
    expect(g.sup).toBe(0);
    expect(g.dom!.scrap).toBeCloseTo(97);
    expect(made).toEqual([[1, true]]);
  });

  it('세운 연구는 효과를 멈춘다: w8을 세우면 좋은 물건 대신 생필품, w6을 세우면 만들지 않는다', () => {
    const g = ready(200);
    done(g, 'w8');
    applyStep(g, { a: 'dom-sup-fine', d: { on: '1' } });
    g.dom!.techs.w8!.off = true;
    work(g, 2);
    expect(g.supFine ?? 0).toBe(0);
    expect(g.sup).toBeCloseTo(1);
    const h = ready(200);
    h.dom!.techs.w6!.off = true;
    work(h, 2);
    expect(h.sup).toBe(0);
    expect(h.dom!.supWork ?? 0).toBe(0);
  });

  it('앞으로 옮긴 생필품 일이 그 정산의 개조 진행을 늦춘다', () => {
    const last = ready();
    last.dom!.order = ['modify', 'restore', 'sup'];
    last.dom!.job = { kind: 'insulate', car: 'tail1', progress: 0, need: 3 };
    const first = structuredClone(last);
    moveTask(first, 'sup', -1); moveTask(first, 'sup', -1);
    work(last, 1); work(first, 1);
    expect(last.dom!.job!.progress).toBeCloseTo(1);
    expect(first.dom!.job!.progress).toBeCloseTo(0.5);
    expect(first.sup).toBe(1);
  });

  it('이번에 만든 생필품은 앞서 끝난 배급을 바꾸지 않고 다음 배급에 들어간다', () => {
    const g = ready();
    suppliesUse(g);
    work(g, 1);
    expect(Object.values(g.supCover!)).toEqual(COMMS.map(() => 0));
    expect(suppliesUse(g)!.use).toBe(1);
  });
});

describe('생필품 공방: 봇 정책', () => {
  it('none은 봇·공방장 모두 w6을 고르지 않는다', () => {
    const g = fresh();
    SUPPLIES_BOT.set(g, { make: 'none' });
    expect(usefulVariant(g, 'w6')).toBeNull();
    expect(chiefPick(g)).not.toBe('w6');
    const result = playGame('sp-0', { s1c: true, policy: 'caretaker', dom: 'engaged', sup: true, supMake: 'none' });
    expect(result.g.dom!.techs.w6).toBeUndefined();
  });

  it('first는 w6을 먼저 고르며 완성한 바로 그 정산에 개조 앞에서 만든다', () => {
    const g = fresh();
    SUPPLIES_BOT.set(g, { make: 'first', beforeWork: suppliesFirst });
    expect(chiefPick(g)).toBe('w6');
    expect(startRestore(g, 'w6', 'full')).toBe(true);
    g.dom!.job = { kind: 'insulate', car: 'tail1', progress: 0, need: 3 };
    work(g, restoreCost('w6').work + 0.75);
    expect(g.dom!.order.indexOf('sup')).toBeLessThan(g.dom!.order.indexOf('restore'));
    expect(g.dom!.order.indexOf('sup')).toBeLessThan(g.dom!.order.indexOf('modify'));
    expect(g.sup).toBe(1);
    expect(g.dom!.job!.progress).toBeCloseTo(0.25);
  });
});
