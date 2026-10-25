import { afterEach, describe, expect, it } from 'vitest';
import { actRows, CL, climateDepart, createGame, enableClimate, enableDisasters, rowAt, SEASON_ROWS, segTemp, stageAt, useSeasonAct } from '../../src/game';
import type { DisasterState } from '../../src/game';

// 시험 판 스위치(결정 447 카드 3): S1 24구간을 막의 계절표 곡선으로 돌린다. 봇 --act와 시험 판만 쓰고 플레이어의 판은 그대로다.

afterEach(() => useSeasonAct('prologue'));

describe('막 곡선', () => {
  it('막 곡선은 서막과 같은 24구간이고, 한낮 기온이 막의 처음에서 끝으로 간다', () => {
    for (const [act, first, last] of [['act1', -4, -15], ['act2', -15, -24], ['act3', -3, 2]] as const) {
      const rows = actRows(act);
      expect(rows.length, act).toBe(SEASON_ROWS.length);
      expect(rows[0].temp, act).toBe(first);
      expect(rows[rows.length - 1].temp, act).toBe(last);
      expect(rows.map(r => r.seg)).toEqual(SEASON_ROWS.map(r => r.seg));
    }
  });

  it('2막 끝은 혹한(−24°) 단계, 1막 끝은 한겨울, 3막은 해빙 초입이다', () => {
    const a2 = actRows('act2');
    expect(a2[a2.length - 1].stage).toBe(3);
    expect(a2.every(r => r.night_freeze && r.snow && r.blizzard)).toBe(true);
    expect(actRows('act1').at(-1)!.season).toBe('deep_winter');
    expect(actRows('act3').every(r => r.season === 'early_thaw')).toBe(true);
  });
});

describe('스위치', () => {
  it('켜면 구간 줄·단계표·기온이 막 곡선을 따르고, 서막으로 되돌리면 본래 줄이다', () => {
    const before = SEASON_ROWS.map(r => ({ ...r }));
    const table = CL.table.map(x => [...x]);
    useSeasonAct('act2');
    expect(rowAt(1).temp).toBe(-15);
    expect(segTemp(24)).toBe(-24);
    expect(CL.table).toEqual([[1, 2], [13, 3]]);
    const g = createGame('act2');
    enableClimate(g);
    expect(g.outside).toBe(2);
    useSeasonAct('prologue');
    expect(SEASON_ROWS).toEqual(before);
    expect(CL.table).toEqual(table);
  });
});

describe('한파의 단계 내림(결정 447 덧붙임, 분위기 카드 4 가)', () => {
  const cold = (g: ReturnType<typeof createGame>) => { g.disaster = { kind: 'cold', stage: 'warn', left: 2 } as DisasterState; };

  it('추위 이상에서 한파가 닥치면 한 단계 더 춥고(혹한 → 된추위), 끝나면 계절표 단계로 돌아온다', () => {
    useSeasonAct('act2');
    const g = createGame('cold-step');
    enableClimate(g);
    enableDisasters(g);
    g.seg = 20;
    g.outside = stageAt(19);
    expect(g.outside).toBe(3);
    cold(g);
    expect(climateDepart(g)).toEqual({ from: 3, to: 3 + CL.coldStep });
    // 글의 기온은 한파가 닥친 동안 보이는 기온과 같다(혹한 구간 + 한파 보정이 된추위 기온 가까이).
    expect(g.journal.at(-1)!.text).toContain(`바깥 ${String(segTemp(20) - 12).replace('-', '−')}°`);
    expect(Math.abs(segTemp(20) - 12 - -33)).toBeLessThanOrEqual(3);
    expect(CL.mult[g.outside!]).toBeGreaterThan(CL.mult[3]);
    delete g.disaster;
    expect(climateDepart(g)).toEqual({ from: 3 + CL.coldStep, to: 3 });
  });

  it('서막(첫 추위 이하)의 한파는 단계를 바꾸지 않는다', () => {
    const p = createGame('cold-pro');
    enableClimate(p);
    enableDisasters(p);
    p.seg = 18;
    p.outside = stageAt(17);
    cold(p);
    expect(climateDepart(p)!.to).toBe(stageAt(18));
    expect(Math.max(...SEASON_ROWS.map(r => r.stage))).toBeLessThan(CL.coldFrom);
  });
});
