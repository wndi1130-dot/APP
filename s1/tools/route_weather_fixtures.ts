import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { hash } from '../src/game/omens';
import type { Weather } from '../src/game/omens';
import { routeWeather, STAY } from '../src/game/route_weather';
import { FALLS, SEASON_ROWS, fallsAt, seasonAct, setSeasonRows, weatherWeights } from '../src/game/season';
import type { SeasonAct } from '../src/game/season';
import { createGame, cloneGame } from '../src/game/state';
import type { Game } from '../src/game/state';
import { buildDeparture } from '../src/game/field_departure';

// 결정 474 N2. 실행: cd s1 && npx tsx tools/route_weather_fixtures.ts
export const WEATHER_KINDS: Weather[] = ['snow', 'fog', 'sleet', 'overcast', 'clear'];
export const SAMPLE_SEEDS = ['route-0', 'route-17', '474-N2', '기차-날씨', 'snow-🚂'];

/** 바꾸기 전 기온 켠 판의 독립 뽑기. 통계의 비교 기준으로만 쓴다. */
export function independentWeather(seed: string, seg: number): Weather {
  const weights = weatherWeights(seg);
  let x = hash(`${seed}:w:${seg}`) % weights.reduce((sum, [, n]) => sum + n, 0);
  for (const [weather, n] of weights) {
    if (x < n) return fallsAt(seg, weather);
    x -= n;
  }
  return 'snow';
}

export function weatherMetrics(shareSeeds = 5000) {
  const original = seasonAct();
  try {
    setSeasonRows('prologue');
    let runs = 0;
    let oldRuns = 0;
    for (let i = 0; i < 50; i += 1) {
      const seed = `route-flow-${i}`;
      let previous: Weather | undefined;
      let oldPrevious: Weather | undefined;
      for (let seg = 1; seg <= 20; seg += 1) {
        const weather = routeWeather(seed, seg);
        const old = independentWeather(seed, seg);
        if (weather !== previous) runs += 1;
        if (old !== oldPrevious) oldRuns += 1;
        previous = weather;
        oldPrevious = old;
      }
    }
    const counts: Record<string, { n: number; flow: Record<string, number>; independent: Record<string, number> }> = {};
    for (const act of ['prologue', 'act1', 'act2', 'act3'] as SeasonAct[]) {
      setSeasonRows(act);
      for (let i = 0; i < shareSeeds; i += 1) {
        const seed = `route-share-${i}`;
        for (const row of SEASON_ROWS) {
          const count = counts[row.season] ??= { n: 0, flow: {}, independent: {} };
          const flow = routeWeather(seed, row.seg);
          const old = independentWeather(seed, row.seg);
          count.n += 1;
          count.flow[flow] = (count.flow[flow] ?? 0) + 1;
          count.independent[old] = (count.independent[old] ?? 0) + 1;
        }
      }
    }
    const shares = Object.entries(counts).flatMap(([season, count]) => WEATHER_KINDS.map(weather => {
      const flow = (count.flow[weather] ?? 0) / count.n * 100;
      const independent = (count.independent[weather] ?? 0) / count.n * 100;
      return { season, weather, samples: count.n, flow, independent, deltaPp: flow - independent };
    }));
    return { stay: STAY, runSeeds: 50, stopsPerSeed: 20, runs, oldRuns, meanRun: 1000 / runs, oldMeanRun: 1000 / oldRuns, shareSeeds, shares };
  } finally {
    setSeasonRows(original);
  }
}

export function routeWeatherVectors() {
  const original = seasonAct();
  try {
    setSeasonRows('prologue');
    const baseState = Object.assign(createGame('route-contract'), { wounds: [] });
    baseState.phase = 'stop';
    baseState.stop = { place: 'freight', target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, threat: 1, scout: true, done: false, result: null };
    const opts = { placeId: 'sulechow_station' };
    type Case = { name: string; seed: string; seg: number; climate: boolean; storedWeather?: Weather; disasters?: boolean; disaster?: Game['disaster'] };
    const inputs: Case[] = SAMPLE_SEEDS.flatMap(seed => Array.from({ length: 24 }, (_, i) => ({ name: `${seed}/${i + 1}`, seed, seg: i + 1, climate: true })));
    inputs.push(...[1, 2, 4, 15, 20, 24].map(seg => ({ name: `off/${seg}`, seed: 'climate-off', seg, climate: false })));
    for (const storedWeather of ['snow', 'fog', 'sleet', 'overcast', 'clear', 'blizzard', 'cold', 'cold_front'] as Weather[]) {
      for (const seg of [3, 15, 20]) inputs.push({ name: `stored/${storedWeather}/${seg}`, seed: 'route-stored', seg, climate: true, storedWeather });
    }
    for (const kind of ['blizzard', 'cold'] as const) for (const stage of ['active', 'brewing', 'warn'] as const) for (const disasters of [true, false]) {
      inputs.push({ name: `${kind}/${stage}/${disasters}`, seed: 'route-disaster', seg: 20, climate: true, disasters, disaster: { kind, stage, left: stage === 'active' ? 2 : 0 } });
    }
    const contracts = inputs.map(input => {
      const g = cloneGame(baseState);
      g.seed = input.seed;
      g.seg = input.seg;
      g.climate = input.climate;
      if (input.storedWeather) g.stop!.weather = input.storedWeather;
      if (input.disasters !== undefined) g.disasters = input.disasters;
      if (input.disaster) g.disaster = input.disaster;
      const d = buildDeparture(g, opts);
      return { ...input, expected: g.climate ? { stopWeather: d.stopWeather, pastWeather: d.pastWeather } : {} };
    });
    const routes = SAMPLE_SEEDS.map(seed => ({ seed, weather: Array.from({ length: 24 }, (_, i) => routeWeather(seed, i + 1)) }));
    return { format: 'route-weather-v1', stay: STAY, tables: { SEASON_ROWS: [...SEASON_ROWS], FALLS }, routes, baseState, opts, contracts };
  } finally {
    setSeasonRows(original);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) {
  const out = resolve(import.meta.dirname, '../../s2/tests/fixtures/train/route_weather.json');
  const data = { ...routeWeatherVectors(), metrics: weatherMetrics() };
  mkdirSync(dirname(out), { recursive: true });
  const bytes = `${JSON.stringify(data)}\n`;
  writeFileSync(out, bytes);
  console.log(JSON.stringify({ out, bytes: Buffer.byteLength(bytes), routes: data.routes.length, contracts: data.contracts.length, stay: STAY, meanRun: data.metrics.meanRun, maxDeltaPp: Math.max(...data.metrics.shares.map(row => Math.abs(row.deltaPp))) }));
}
