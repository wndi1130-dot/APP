import { describe, expect, it } from 'vitest';
import { createGame, enableDisasters, pickWeather, rollStopView, WEATHER_LOOK } from '../../src/game';
import type { Game, StopState } from '../../src/game';
import { backdrop } from '../../src/ui/backdrop';

// 정차 날씨와 재난 맞추기(날씨 명세 1.2의 첫 조각): 눈보라·한파가 닥친 구간의 정차는 창밖 글·조짐도 그 날씨다.
// 꺼진 판과 재난이 없는 구간은 지금까지의 해시 뽑기 그대로다.

const stopAt = (place = 'freight'): StopState => ({ place, target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, threat: 1, scout: true, done: false, result: null });

function withDisaster(seed: string, seg: number, kind: 'blizzard' | 'cold', stage: 'brewing' | 'warn' | 'active', on = true): Game {
  const g = createGame(seed);
  if (on) enableDisasters(g);
  g.seg = seg;
  g.disaster = { kind, stage, left: stage === 'active' ? 2 : 0 };
  return g;
}

describe('정차 날씨와 재난', () => {
  it('재난이 닥친 구간의 정차는 그 재난 날씨이고 창밖 글도 그 날씨 글이다', () => {
    for (const kind of ['blizzard', 'cold'] as const) {
      for (let i = 0; i < 20; i += 1) {
        const g = withDisaster(`dzw-${kind}-${i}`, 4 + (i % 9), kind, 'active');
        const stop = stopAt();
        rollStopView(g, stop, false);
        expect(stop.weather).toBe(kind);
        expect(WEATHER_LOOK[kind].some(t => stop.look!.startsWith(t)), stop.look).toBe(true);
      }
    }
  });

  it('예고 중, 재난이 없는 구간, 꺼진 판은 지금까지의 해시 뽑기 그대로다', () => {
    for (let i = 0; i < 40; i += 1) {
      const seed = `dzw-same-${i}`;
      const seg = 1 + (i % 24);
      const plain = createGame(seed);
      plain.seg = seg;
      const want = pickWeather(plain);
      expect(['blizzard', 'cold']).not.toContain(want);
      expect(pickWeather(withDisaster(seed, seg, 'blizzard', 'warn'))).toBe(want);
      expect(pickWeather(withDisaster(seed, seg, 'cold', 'active', false))).toBe(want);
    }
  });

  it('달리는 배경: 재난이 끝난 뒤 남은 눈보라·한파 정차 날씨는 갠 하늘로 본다', () => {
    const g = createGame('dzw-bg');
    g.stop = null;
    enableDisasters(g);
    expect(backdrop(g, 'blizzard').sky).toBe('clear');
    expect(backdrop(g, 'cold').sky).toBe('clear');
    g.disaster = { kind: 'blizzard', stage: 'active', left: 1 };
    expect(backdrop(g, 'blizzard')).toEqual({ sky: 'storm', omen: false, pace: 2.2 });
  });
});
