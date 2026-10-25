import { afterEach, describe, expect, it } from 'vitest';
import { actRows, CL, createGame, enableClimate, rowAt, SEASON_ROWS, segTemp, useSeasonAct } from '../../src/game';

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
