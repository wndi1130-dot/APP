import { describe, expect, it } from 'vitest';
import { ARRIVALS, WEATHER_NAME, advance, arrivalMin, clockText, createGame, nextStopForecast, nextStopLine } from '../../src/game';

// 결정 471 B0: 정차마다 도착 시각을 굴리고, 노선표(아래 띠)에 다음 정차의 도착 시각과 날씨를 미리 보인다.

describe('정차 도착 시각', () => {
  it('네 띠 안 10분 단위이고, 같은 씨앗·구간이면 같다', () => {
    for (let i = 0; i < 400; i += 1) {
      const m = arrivalMin(`arr-${i}`, 1 + (i % 24));
      expect(m % 10).toBe(0);
      expect(ARRIVALS.some(([, from, to]) => m >= from && m <= to)).toBe(true);
      expect(arrivalMin(`arr-${i}`, 1 + (i % 24))).toBe(m);
    }
  });

  it('몫이 아침 40·한낮 35·늦은 오후 20·해 질 녘 5%에 가깝다(2,000판)', () => {
    const counts = ARRIVALS.map(() => 0);
    const n = 2000;
    for (let i = 0; i < n; i += 1) {
      const m = arrivalMin(`share-${i}`, 3);
      counts[ARRIVALS.findIndex(([, from, to]) => m >= from && m <= to)] += 1;
    }
    ARRIVALS.forEach(([share], k) => expect(Math.abs(counts[k] / n * 100 - share)).toBeLessThan(3.5));
  });

  it('시각 글은 HH:MM', () => {
    expect(clockText(540)).toBe('09:00');
    expect(clockText(890)).toBe('14:50');
  });
});

describe('노선표의 다음 정차', () => {
  it('서기 전(운영·이동)에만 보이고, 날씨는 도착해서 굴린 것과 같다', () => {
    let reached = 0;
    for (let i = 0; i < 12; i += 1) {
      const g = createGame(`next-${i}`);
      const before = nextStopForecast(g);
      expect(before).not.toBeNull();
      expect(before!.seg).toBe(g.seg);
      let guard = 0;
      // 서류는 비우고 넘긴다(field_council.test.ts toStopDone과 같은 꼴).
      while (g.phase !== 'stop' && guard < 6) { g.cards = []; advance(g); guard += 1; }
      if (g.phase !== 'stop') continue;  // 길에서 선 판(석탄)은 정차가 없다
      expect(g.stop!.weather).toBe(before!.weather);
      expect(nextStopForecast(g)).toBeNull();
      reached += 1;
    }
    expect(reached).toBeGreaterThan(6);
  });

  it('아래 띠에 적는 글은 그 정차의 HH:MM과 날씨 이름', () => {
    const g = createGame('next-bar');
    const line = nextStopLine(g)!;
    expect(line.time).toBe(clockText(arrivalMin(g.seed, g.seg)));
    expect(line.weather).toBe(WEATHER_NAME[nextStopForecast(g)!.weather]);
  });
});
