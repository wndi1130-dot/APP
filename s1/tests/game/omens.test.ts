import { describe, expect, it } from 'vitest';
import {
  createGame, markSeen, PLACE_LOOK, PLACE_OMENS, PLACES, rollStopView, verdictText, WEATHER_LOOK, WEATHER_OMENS,
} from '../../src/game';
import type { StopState } from '../../src/game';

// 정차 조짐(2026-10-07 11:51 사용자): 꼬리표 대신 조짐과 해석. 장소·날씨마다 다르고 같은 문장은 되도록 다시 안 나온다.

const omenLines = [
  ...Object.values(PLACE_OMENS).flatMap(t => Object.values(t).flat()),
  ...Object.values(WEATHER_OMENS).flatMap(t => Object.values(t).flat()),
];
const lookLines = [...Object.values(PLACE_LOOK).flat(), ...Object.values(WEATHER_LOOK).flat()];

function playStops(seed: string, n: number) {
  const g = createGame(seed);
  const out: StopState[] = [];
  for (let seg = 1; seg <= n; seg += 1) {
    g.seg = seg;
    const place = PLACES[(seg * 7 + seed.length) % PLACES.length].id;
    const stop: StopState = { place, target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, threat: [0.8, 1, 1, 1.4][(seg * 3 + seed.length) % 4], scout: true, done: false, result: null };
    rollStopView(g, stop, false);
    markSeen(g, stop.omen!);
    out.push(stop);
  }
  return out;
}

describe('정차 조짐 글', () => {
  it('모든 장소에 세 기척 단계의 조짐이 있고, 글은 짧다', () => {
    for (const p of PLACES) for (const tier of ['many', 'some', 'few'] as const) expect(PLACE_OMENS[p.id][tier].length, `${p.id}/${tier}`).toBeGreaterThanOrEqual(3);
    for (const t of [...omenLines, ...lookLines]) {
      expect(t.length, t).toBeLessThanOrEqual(40);
      expect((t.match(/\./g) ?? []).length, t).toBeLessThanOrEqual(2);
    }
  });

  it('조짐 글은 해석 말을 쓰지 않는다(해석 말만 약속이다)', () => {
    for (const t of omenLines) expect(/불길|괜찮/.test(t), t).toBe(false);
  });

  it('조짐 글과 창밖 글은 서로 겹치지 않는다', () => {
    expect(new Set(omenLines).size).toBe(omenLines.length);
    expect(new Set(lookLines).size).toBe(lookLines.length);
  });

  it('한 판(24구간) 안에서 같은 조짐이 다시 안 나온다', () => {
    for (let i = 0; i < 40; i += 1) {
      const omens = playStops(`omen-${i}`, 24).map(s => s.omen);
      expect(new Set(omens).size, `omen-${i}`).toBe(omens.length);
    }
  });

  it('같은 장소라도 날씨와 기척에 따라 다른 글이 나온다', () => {
    const looks = new Set<string>();
    for (let i = 0; i < 20; i += 1) for (const s of playStops(`look-${i}`, 16)) looks.add(s.look!);
    expect(looks.size).toBeGreaterThan(60);
  });

  it('준비가 조짐의 범위를 벗어나면 해석에 그 까닭을 붙인다', () => {
    expect(verdictText('dead', 'many')).toBe('매우 불길하다.');
    expect(verdictText('dead', 'few')).toBe('이 준비로는 매우 불길하다.');
    expect(verdictText('calm', 'many')).toBe('이 준비라면 괜찮을 것 같다.');
    expect(verdictText('light', 'some')).toBe('긁히는 정도로 끝날 것 같다.');
  });
});
