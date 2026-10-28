import { describe, expect, it } from 'vitest';
import { advance, chooseCard, createGame, enableClimate, forecast, resolveStop, viewCard } from '../../src/game';
import type { Game, LootKey, PromiseState } from '../../src/game';
import { ROTATE_GUARD, noteTarget, rotateTo, suggestTarget, targetCandidates } from '../../src/game/turn';
import { stageAt } from '../../src/game/climate';
import { buildDeparture } from '../../src/game/field_departure';
import type { FieldDepartureV2 } from '../../src/game/field_departure';
import { applyFieldReturn } from '../../src/game/field_receipt';
import { readSave } from '../../src/ui/repro';

// 결정 482·484(469 V1): 정차마다 노리는 갈래를 열차 상태·계절·이야기로 돌린다.
const LOOT: Record<LootKey, number> = { coal: 40, food: 40, medicine: 30, luxury: 5, symbol: 5, secret: 5 };

/** 식량이 석탄보다 모자라되, ROTATE_GUARD 구간 치보다는 많이 남은 판. */
function hungry(): Game {
  const g = createGame('target-rotation');
  g.coal = 1000;
  g.med = 20;
  g.food = ROTATE_GUARD * forecast(g).food + 10;
  return g;
}

describe('노리는 갈래 돌리기(결정 482·484)', () => {
  it('같은 갈래가 세 번째 연속이 되면 그 장소에 가장 많은 다른 것으로 넘긴다', () => {
    const g = hungry();
    expect(suggestTarget(g, LOOT)).toBe('food');
    noteTarget(g, 'food');
    expect(suggestTarget(g, LOOT)).toBe('food'); // 두 번째 연속까지는 그대로
    noteTarget(g, 'food');
    expect(g.targetRun).toEqual({ target: 'food', n: 2 });
    expect(suggestTarget(g, LOOT)).toBe('coal'); // 세 번째가 될 자리
    noteTarget(g, 'coal');
    expect(g.targetRun).toEqual({ target: 'coal', n: 1 });
    expect(suggestTarget(g, LOOT)).toBe('food');
  });

  it('처음 갈래가 8구간 치 밑이면 넘기지 않고, 딱 8구간 치부터 넘긴다', () => {
    expect(ROTATE_GUARD).toBe(8);
    const g = hungry();
    const edge = ROTATE_GUARD * forecast(g).food;
    g.targetRun = { target: 'food', n: 2 };
    g.food = Math.max(0, edge - 1);
    expect(suggestTarget(g, LOOT)).toBe('food');
    g.food = edge;
    expect(suggestTarget(g, LOOT)).toBe('coal');
    g.food = edge + 1;
    expect(suggestTarget(g, LOOT)).toBe('coal');
  });

  it('넘길 것들이 같은 양이면 갈래 차례(LOOT_KEYS)의 앞의 것으로 넘긴다', () => {
    expect(rotateTo({ coal: 30, food: 40, medicine: 30, luxury: 30, symbol: 0, secret: 0 }, 'food')).toBe('coal');
    expect(rotateTo({ coal: 0, food: 40, medicine: 30, luxury: 30, symbol: 30, secret: 30 }, 'food')).toBe('medicine');
    expect(rotateTo({ coal: 0, food: 40, medicine: 0, luxury: 0, symbol: 30, secret: 30 }, 'food')).toBe('symbol');
  });

  it('모자란 정도가 같으면 석탄·식량·의약품 차례로 둔다', () => {
    const g = hungry();
    g.coal = 63; // 63 / 252, 60 / 240, 5 / 20 모두 0.25
    g.food = 60;
    g.med = 5;
    expect(targetCandidates(g, LOOT).slice(0, 3)).toEqual(['coal', 'food', 'medicine']);
  });

  it('병원에서 세 번째 식량은 의약품으로, 교회에선 상징물로 넘어간다', () => {
    const g = hungry();
    g.targetRun = { target: 'food', n: 2 };
    expect(suggestTarget(g, { coal: 0, food: 10, medicine: 55, luxury: 0, symbol: 10, secret: 25 })).toBe('medicine');
    expect(suggestTarget(g, { coal: 0, food: 10, medicine: 0, luxury: 10, symbol: 60, secret: 20 })).toBe('symbol');
  });

  it('넘길 것이 그 장소에 없으면 그대로 둔다(주택가)', () => {
    const g = hungry();
    g.targetRun = { target: 'food', n: 2 };
    expect(suggestTarget(g, { coal: 5, food: 35, medicine: 10, luxury: 20, symbol: 20, secret: 10 })).toBe('food');
  });

  it('지나친 정차는 줄을 끊지도 늘리지도 않는다', () => {
    const g = hungry();
    noteTarget(g, 'food');
    noteTarget(g, null);
    expect(g.targetRun).toEqual({ target: 'food', n: 1 });
  });

  it('앞 구간에서 계절 추위가 오르면 석탄이 후보 앞에 온다(기온 켠 판)', () => {
    const g = hungry();
    enableClimate(g);
    let seg = 1;
    while (seg < 24 && !(stageAt(seg + 1) > stageAt(seg))) seg += 1;
    expect(stageAt(seg + 1)).toBeGreaterThan(stageAt(seg));
    g.seg = seg;
    expect(targetCandidates(g, LOOT)[0]).toBe('coal');
    g.seg = seg + 1;
    expect(targetCandidates(g, LOOT)[0]).toBe('food');
  });

  it('약속 장부에 걸린 갈래가 후보 앞에 온다', () => {
    const g = hungry();
    g.comms.medtech.promise = { kind: 'fetch', cond: { kind: 'target', target: 'medicine' }, label: '의약품 6', due: g.seg + 1 } as unknown as PromiseState;
    expect(targetCandidates(g, LOOT)[0]).toBe('medicine');
    expect(suggestTarget(g, LOOT)).toBe('medicine');
    g.comms.medtech.promise!.due = g.seg - 1; // 지난 약속은 보태지 않는다
    expect(targetCandidates(g, LOOT)[0]).toBe('food');
  });
});

/** 첫 정차에 선 판(field_wounds_return.test.ts와 같은 길). */
function atStop(seed = 'slice-seed-a'): Game {
  const g = createGame(seed);
  for (let i = 0; i < 80 && !(g.phase === 'stop' && g.stop && !g.stop.done); i += 1) {
    if (g.cards.length) { const c = g.cards[0]; chooseCard(g, c.uid, viewCard(g, c).choices.findIndex(x => !x.disabled)); continue; }
    advance(g);
  }
  return g;
}

/** 그 출발로 나간 사람이 모두 다치지 않고 돌아온 영수증. */
function receiptFor(d: FieldDepartureV2, receiptId: string, stock: Record<string, number> = {}) {
  return {
    version: 5, receiptId, departureId: d.departureId, stopId: d.stopId, source: 'direct', endReason: 'departed',
    place: { id: d.placeId, type: 'freight', variant: 's2_graybox' }, time: { arrive: 'D1 10:30', depart: 'D1 12:00', stayGameMinutes: 90 },
    stock, items: { gained: [], lost: [] },
    people: { sent: d.roster.map(p => p.id), injured: [], bitten: [], dead: [], missing: [], leftBehind: [], rescued: [] },
    witnessed: [], placeState: { looted: 0, remainingRisk: 1 }, promises: [],
    goal: { kind: null, required: 0, earned: 0, status: 'retreat' }, extras: { documents: [], symbolCount: 0, fragments: [], coreCount: 0 },
    symbol: null, fieldPromises: d.promises.map(p => ({ id: p.id, kind: p.kind, witnesses: [] })), crew: [], defense: null,
  };
}

describe('노리는 갈래 줄은 실제 정차를 따라 센다(결정 482·484)', () => {
  it('필드 귀환이 정차를 닫으면 한 번 세고, 같은 영수증이 다시 와도 더 세지 않는다', () => {
    const g = atStop();
    const target = g.stop!.target!;
    g.targetRun = { target, n: 1 };
    const d = buildDeparture(g, { placeId: 'sulechow_station' });
    const r = receiptFor(d, 'ret_rotation');
    expect(applyFieldReturn(g, d, r).status).toBe('applied');
    expect(g.stop!.done).toBe(true);
    expect(g.targetRun).toEqual({ target, n: 2 });
    expect(applyFieldReturn(g, d, r).status).toBe('duplicate');
    expect(g.targetRun).toEqual({ target, n: 2 });
  });

  it('지난 구간 출발의 늦은 영수증은 물자만 들이고 지금 정차를 닫거나 줄에 세지 않는다', () => {
    const g = atStop();
    const target = g.stop!.target!;
    g.targetRun = { target, n: 1 };
    const now = buildDeparture(g, { placeId: 'sulechow_station' });
    const seg = now.segment - 1;
    const old: FieldDepartureV2 = { ...now, segment: seg, departureId: `dep_${now.placeId}_${seg}`, stopId: `stop_${now.placeId}_${seg}` };
    const coal = g.coal;
    expect(applyFieldReturn(g, old, receiptFor(old, 'ret_late', { coal: 5 })).status).toBe('applied');
    expect(g.coal).toBe(coal + 5);
    expect(g.stop!.done).toBe(false);
    expect(g.targetRun).toEqual({ target, n: 1 });
  });

  it('지나치거나 나갈 사람이 없어 지나친 정차는 줄을 끊지도 늘리지도 않는다', () => {
    const g = atStop();
    const target = g.stop!.target!;
    g.targetRun = { target, n: 2 };
    expect(resolveStop(g, false)!.passed).toBe(true);
    expect(g.targetRun).toEqual({ target, n: 2 });
    const empty = atStop();
    empty.targetRun = { target, n: 2 };
    empty.stop!.crewSize = 0;
    expect(resolveStop(empty, true)!.passed).toBe(true);
    expect(empty.targetRun).toEqual({ target, n: 2 });
  });

  it('파견한 정차는 한 번 세고, 저장했다 읽어도 줄과 다음 추천이 같다', () => {
    const g = atStop();
    const target = g.stop!.target!;
    g.targetRun = { target, n: 1 };
    expect(resolveStop(g, true)!.passed).toBe(false);
    expect(g.targetRun).toEqual({ target, n: 2 });
    const back = readSave(JSON.parse(JSON.stringify(g)));
    if (!back.ok) throw new Error(back.why);
    expect(back.g.targetRun).toEqual({ target, n: 2 });
    expect(suggestTarget(back.g, LOOT)).toBe(suggestTarget(g, LOOT));
  });
});
