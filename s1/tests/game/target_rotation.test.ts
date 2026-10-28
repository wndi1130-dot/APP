import { describe, expect, it } from 'vitest';
import { createGame, enableClimate, forecast } from '../../src/game';
import type { Game, LootKey, PromiseState } from '../../src/game';
import { ROTATE_BY_PLACE, ROTATE_GUARD, noteTarget, suggestTarget, targetCandidates } from '../../src/game/turn';
import { stageAt } from '../../src/game/climate';

// 결정 482(469 V1): 정차마다 노리는 갈래를 열차 상태·계절·이야기로 돌린다.
const LOOT: Record<LootKey, number> = { coal: 40, food: 40, medicine: 30, luxury: 5, symbol: 5, secret: 5 };

/** 식량이 석탄보다 모자라되, ROTATE_GUARD 구간 치보다는 많이 남은 판. */
function hungry(): Game {
  const g = createGame('target-rotation');
  g.coal = 1000;
  g.med = 20;
  g.food = ROTATE_GUARD * forecast(g).food + 10;
  return g;
}

describe('노리는 갈래 돌리기(결정 482)', () => {
  it('같은 갈래가 세 번째 연속이 되면 다음 갈래로 넘긴다', () => {
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

  it('처음 갈래가 모자라면(ROTATE_GUARD 구간 치 아래) 넘기지 않는다', () => {
    const g = hungry();
    g.food = Math.max(0, ROTATE_GUARD * forecast(g).food - 1);
    g.targetRun = { target: 'food', n: 2 };
    expect(suggestTarget(g, LOOT)).toBe('food');
  });

  it('병원에서 세 번째 식량은 장소 몫으로만 넘어간다', () => {
    const g = hungry();
    const hospital: Record<LootKey, number> = { coal: 0, food: 10, medicine: 55, luxury: 0, symbol: 10, secret: 25 };
    g.targetRun = { target: 'food', n: 2 };
    expect(suggestTarget(g, hospital)).toBe(ROTATE_BY_PLACE ? 'medicine' : 'food');
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
