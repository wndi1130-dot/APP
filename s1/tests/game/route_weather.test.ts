import { afterEach, describe, expect, it } from 'vitest';
import { createGame, cloneGame } from '../../src/game/state';
import { hash, pickWeather } from '../../src/game/omens';
import type { Weather } from '../../src/game/omens';
import { routeWeather, STAY } from '../../src/game/route_weather';
import { FALLS, SEASON_ROWS, fallsAt, rainAt, setSeasonRows } from '../../src/game/season';
import { buildDeparture } from '../../src/game/field_departure';
import { nextStopForecast } from '../../src/game/stop_time';
import { independentWeather, SAMPLE_SEEDS, weatherMetrics } from '../../tools/route_weather_fixtures';

afterEach(() => setSeasonRows('prologue'));

const s2Id = (weather: Weather, seg: number) => weather === 'sleet' && rainAt(seg) ? 'rain' : weather === 'cold' || weather === 'cold_front' ? 'clear' : weather;

describe('결정 474 N2 노선 날씨', () => {
  it('정차 20 × 씨앗 50에서 같은 날씨의 이어짐 길이 평균은 2 이상이다', () => {
    const metrics = weatherMetrics(0);
    expect(STAY).toBe(50);
    expect(metrics.meanRun).toBeGreaterThanOrEqual(2);
    expect(metrics.meanRun).toBeGreaterThan(metrics.oldMeanRun);
  });

  it('계절별 날씨 몫은 옛 독립 뽑기와 3%p 이내다', () => {
    const metrics = weatherMetrics();
    expect(new Set(metrics.shares.map(row => row.season)).size).toBe(4);
    for (const row of metrics.shares) {
      expect(Math.abs(row.deltaPp), `${row.season}/${row.weather}: ${row.deltaPp}%p`).toBeLessThanOrEqual(3);
    }
  }, 60000);

  it('같은 씨앗·구간은 조회 순서와 판 상태에 관계없이 같고, 노선표도 이 값을 읽는다', () => {
    for (const seed of SAMPLE_SEEDS) {
      const g = createGame(seed);
      g.climate = true;
      const route = Array.from({ length: 24 }, (_, i) => routeWeather(seed, i + 1));
      for (let seg = 24; seg >= 1; seg -= 1) {
        g.seg = seg;
        const before = cloneGame(g);
        expect(routeWeather(seed, seg)).toBe(route[seg - 1]);
        expect(pickWeather(g)).toBe(route[seg - 1]);
        expect(nextStopForecast(g)?.weather).toBe(route[seg - 1]);
        expect(g).toEqual(before);
      }
      expect(route[0]).toBe(independentWeather(seed, 1));
    }
  });

  it('기온 꺼진 판은 모든 구간에서 옛 고정 비율 뽑기 그대로다', () => {
    const weights: [Weather, number][] = [['snow', 30], ['fog', 20], ['sleet', 15], ['overcast', 20], ['clear', 15]];
    for (let i = 0; i < 50; i += 1) {
      const g = createGame(`route-off-${i}`);
      for (let seg = 1; seg <= 24; seg += 1) {
        g.seg = seg;
        let x = hash(`${g.seed}:w:${seg}`) % 100;
        let old: Weather = 'snow';
        for (const [weather, n] of weights) {
          if (x < n) { old = weather; break; }
          x -= n;
        }
        expect(pickWeather(g)).toBe(old);
        const d = buildDeparture(g, { placeId: 'sulechow_station' });
        expect(d).not.toHaveProperty('stopWeather');
        expect(d).not.toHaveProperty('pastWeather');
      }
    }
  });

  it('계약은 현재 날씨와 지난 최대 세 구간을 오래된 순서의 S2 id로 싣는다', () => {
    for (const seed of SAMPLE_SEEDS) {
      // 기존 상처 명부의 첫 조회는 빈 wounds를 만든다. 그 초기화 뒤의 순수성을 비교한다.
      const g = Object.assign(createGame(seed), { wounds: [] });
      g.climate = true;
      for (let seg = 1; seg <= 24; seg += 1) {
        g.seg = seg;
        const before = cloneGame(g);
        const d = buildDeparture(g, { placeId: 'sulechow_station' });
        expect(d.stopWeather).toBe(s2Id(pickWeather(g), seg));
        const previous = Array.from({ length: Math.min(3, seg - 1) }, (_, i) => Math.max(1, seg - 3) + i);
        expect(d.pastWeather).toEqual(previous.map(past => ({ seg: past, weather: s2Id(routeWeather(seed, past), past) })));
        expect(g).toEqual(before);
      }
    }
  });

  it('내리는 날씨는 이어져도 지금 기온을 읽고, 비율이 0인 지난 날씨는 다시 뽑는다', () => {
    SEASON_ROWS[0] = { ...SEASON_ROWS[0], temp: 3, season: 'late_autumn' };
    SEASON_ROWS[1] = { ...SEASON_ROWS[1], temp: FALLS.snow_below, season: 'deep_winter' };
    let zeroCases = 0;
    for (let i = 0; i < 200; i += 1) {
      const seed = `route-zero-${i}`;
      if (hash(`${seed}:ws:2`) % 100 >= STAY || routeWeather(seed, 1) !== 'sleet') continue;
      expect(routeWeather(seed, 2)).toBe(independentWeather(seed, 2));
      zeroCases += 1;
    }
    expect(zeroCases).toBeGreaterThan(0);
    setSeasonRows('prologue');
    let carriedFalls = 0;
    for (let i = 0; i < 200; i += 1) {
      const seed = `route-falls-${i}`;
      if (hash(`${seed}:ws:2`) % 100 >= STAY || routeWeather(seed, 1) !== 'snow') continue;
      expect(routeWeather(seed, 2)).toBe(fallsAt(2, 'snow'));
      expect(routeWeather(seed, 2)).toBe('sleet');
      carriedFalls += 1;
    }
    expect(carriedFalls).toBeGreaterThan(0);
  });

  it('재난 active·brewing은 흐름 위에 덮고 과거 날씨는 바꾸지 않는다', () => {
    const g = createGame('route-disaster');
    g.climate = true;
    g.disasters = true;
    g.seg = 20;
    const plain = buildDeparture(g, { placeId: 'sulechow_station' });
    for (const kind of ['blizzard', 'cold'] as const) for (const stage of ['active', 'brewing'] as const) {
      g.disaster = { kind, stage, left: stage === 'active' ? 2 : 0 };
      const expected = stage === 'active' ? kind : kind === 'blizzard' ? 'overcast' : 'cold_front';
      expect(pickWeather(g)).toBe(expected);
      const d = buildDeparture(g, { placeId: 'sulechow_station' });
      expect(d.stopWeather).toBe(s2Id(expected, g.seg));
      expect(d.pastWeather).toEqual(plain.pastWeather);
    }
  });

  it('정차에 이미 정한 날씨의 rain·sleet·cold·cold_front·blizzard id를 보존한다', () => {
    const g = createGame('route-stored');
    g.climate = true;
    g.stop = { place: 'freight', target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, threat: 1, scout: true, done: false, result: null };
    for (const seg of [3, 15, 20]) for (const weather of ['snow', 'fog', 'sleet', 'overcast', 'clear', 'blizzard', 'cold', 'cold_front'] as Weather[]) {
      g.seg = seg;
      g.stop.weather = weather;
      expect(buildDeparture(g, { placeId: 'sulechow_station' }).stopWeather).toBe(s2Id(weather, seg));
    }
  });
});
