import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import SEASON from '../../src/game/season_table.json';
import { CL, P, segTemp, stageAt } from '../../src/game';

// 계절표 한 벌(코디네이터 10-25): S1 기후, S2 열차, S2 필드·이동 그림이 같은 파일을 읽는다.

describe('season table', () => {
  it('S2의 복사본이 정본과 한 글자도 다르지 않다(tools/season_table_sync.ts)', () => {
    const own = readFileSync(new URL('../../src/game/season_table.json', import.meta.url), 'utf8');
    const s2 = readFileSync(new URL('../../../s2/game/season_table.json', import.meta.url), 'utf8');
    expect(s2).toBe(own);
  });

  it('서막은 판의 구간마다 한 줄이고, 단계와 계절 이름이 표 안에 있다', () => {
    expect(SEASON.first_leg_segments).toBe(P.segments);
    expect(SEASON.prologue.map(r => r.seg)).toEqual(Array.from({ length: P.segments }, (_, i) => i + 1));
    for (const r of SEASON.prologue) {
      expect(r.stage, `seg ${r.seg}`).toBeGreaterThanOrEqual(0);
      expect(r.stage, `seg ${r.seg}`).toBeLessThan(SEASON.stages.length);
      expect(Object.keys(SEASON.seasons), `seg ${r.seg}`).toContain(r.season);
      expect(segTemp(r.seg)).toBe(r.temp);
      expect(stageAt(r.seg)).toBe(r.stage);
    }
    for (const a of Object.values(SEASON.acts)) for (const [, name] of a.season) expect(Object.keys(SEASON.seasons)).toContain(name);
    // 단계는 따뜻한 것부터 차례로 춥고, 난방 석탄 곱도 따라 오른다
    for (let i = 1; i < CL.temp.length; i += 1) {
      expect(CL.temp[i]).toBeLessThan(CL.temp[i - 1]);
      expect(CL.mult[i]).toBeGreaterThan(CL.mult[i - 1]);
    }
  });

  it('서막 (나): 출발 무렵 이른 한파, 늦가을 비, 첫 구간 끝 밤 결빙과 첫눈, 눈보라 없음', () => {
    const rows = SEASON.prologue;
    expect(rows[0].temp).toBeLessThan(0);
    expect(rows[0].night_freeze).toBe(true);
    const autumn = rows.filter(r => r.stage === 0);
    expect(autumn.length).toBeGreaterThan(10);
    for (const r of autumn) {
      expect(r.temp).toBeGreaterThan(0);
      expect(r.night_freeze).toBe(false);
    }
    const end = rows[rows.length - 1];
    expect(end.night_freeze && end.snow).toBe(true);
    expect(rows.some(r => r.blizzard)).toBe(false);
    // 날씨 가중치는 계절 문서 2.2의 여섯 갈래, 늦가을엔 눈보라가 없다
    for (const s of Object.values(SEASON.seasons)) expect(Object.keys(s.weather).sort()).toEqual(['blizzard', 'clear', 'fog', 'overcast', 'sleet', 'snow']);
    expect(SEASON.seasons.late_autumn.weather.blizzard).toBe(0);
    expect(SEASON.seasons.deep_winter.weather.sleet).toBe(0);
  });
});
