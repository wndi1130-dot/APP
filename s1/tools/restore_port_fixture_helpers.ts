// 생성기 전용: S1 실행 경로의 갈고리와 S2에 없는 내정 키를 한곳에서 관리한다.
import assert from 'node:assert/strict';
import type { Game } from '../src/game';
import { COMMS } from '../src/game';
import { SUPPLIES_BOT, SUPPLIES_PROBE, enableSupplies } from '../src/game/supplies';
import { FIELDS, prereqs, TECHS } from '../src/game/domestic/data';
import type { TechId } from '../src/game/domestic/data';
import { createS1cGame, techUsable } from '../src/game/domestic/state';
import { runWorkshop, startRestore } from '../src/game/domestic/workshop';

export function assertNoSuppliesHooks(g?: Game): void {
  for (const [name, callback] of Object.entries(SUPPLIES_PROBE))
    assert.equal(callback, undefined, `SUPPLIES_PROBE.${name} 등록됨`);
  if (g) assert.equal(SUPPLIES_BOT.get(g), undefined, 'SUPPLIES_BOT 등록됨');
}

// log·stats·pipeFlip·pipeMoved는 2c-1 비교 대상이다.
export const s2DomOmit = ['finds', 'manuals', 'offered', 'armored',
  'greenhouse', 'extraCars', 'people', 'nextPersonId', 'countdown', 'hotWater', 'pot',
  'lice', 'liceFree', 'pressureStage', 'typhus', 'bedding', 'penalties', 'sabotage',
  'grants', 'stoker', 'stalled', 'flags', 'hung', 'escort', 'altPlace', 'reroutes',
  'delegate', 'workDebt', 'researchPick', 'enginePick', 'sit', 'movedAt', 'stokingAt',
  'bedOrder', 'fullRule', 'bury', 'cars', 'captainInBed', 'elder', 'h6'];

export function projectDom(g: Game): Record<string, unknown> {
  assertNoSuppliesHooks(g);
  const d = structuredClone(g.dom!) as unknown as Record<string, unknown>;
  const experts = g.dom!.people.filter(p => p.alive && !p.gone)
    .map(({ name, comm, field, skill }) => ({ name, comm, field, skill }));
  for (const key of s2DomOmit) delete d[key];
  d.experts = experts;
  return d;
}

/** 자재·숙련만 준비하고 선행 기술은 실제 시작·공방 실행으로 완성한다. */
export function restorationBoard(seed: string, targets: TechId[]): Game {
  const g = createS1cGame(seed);
  assertNoSuppliesHooks(g);
  enableSupplies(g); g.gearOn = true;
  const d = g.dom!;
  d.parts = 100; d.wood = 100; d.scrap = 100; d.cores = 10;
  for (const field of FIELDS) d.frags[field] = 100;
  for (const p of d.people) {
    p.skill = 3;
    delete p.pupil; delete p.learn; delete p.writing; delete p.resting;
  }
  delete d.elder;
  d.order = ['restore']; d.target = 0; d.workDebt = 0;
  const prepare = (id: TechId): void => {
    const pre = prereqs(id);
    if (!pre.length || pre.some(p => techUsable(g, p))) return;
    const first = pre[0];
    prepare(first);
    assert.equal(startRestore(g, first, 'full', TECHS[first].variants ? 'a' : undefined), true, `선행 기술 ${first}`);
    for (let step = 0; d.restoring && step < 32; step++) runWorkshop(g);
    assert.equal(d.restoring, null, `선행 기술 미완성 ${first}`);
    assert.equal(techUsable(g, first), true);
  };
  for (const id of targets) prepare(id);
  d.order = ['restore'];
  for (const c of COMMS) g.comms[c].rel = 0;
  assertNoSuppliesHooks(g);
  return g;
}

export const relations = (g: Game) => Object.fromEntries(COMMS.map(c => [c, g.comms[c].rel]));
export const restoreStats = (g: Game) => {
  const { restored, tier3, defective } = g.dom!.stats;
  return { restored, tier3, defective };
};
