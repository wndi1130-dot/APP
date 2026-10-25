import { describe, expect, it } from 'vitest';
import {
  createGame, disasterSettle, DZ, enableClimate, enableDisasters, FALLS, FROST_SWAP, markSeen, PLACE_LOOK, PLACE_OMENS, PLACES,
  pickWeather, RAIN_SWAP, rollStopView, rowAt, SEASON_ROWS, SNOW_SWAP, WEATHER_LOOK, WEATHER_OMENS, weatherWeights,
} from '../../src/game';
import type { StopState, Weather } from '../../src/game';

// 기온 켠 판이 계절표의 날씨 칸을 읽는다(코디네이터 10-25, 결정 423·서막 (나)): 정차 날씨 비율, 내리는 것은 기온으로,
// 서막엔 눈보라 재난이 없고, 쌓인 눈·밤 결빙이 없는 구간의 창밖·조짐 글엔 눈밭·얼음이 없다. 꺼진 판은 옛 그대로(골든).

const SWAPS = [SNOW_SWAP, FROST_SWAP, RAIN_SWAP];
const lookLines = [...Object.values(PLACE_LOOK).flat(), ...Object.values(WEATHER_LOOK).flat()];
const omenLines = [...Object.values(PLACE_OMENS).flatMap(t => Object.values(t).flat()), ...Object.values(WEATHER_OMENS).flatMap(t => Object.values(t).flat())];
const fewLines = [...Object.values(PLACE_OMENS), ...Object.values(WEATHER_OMENS)].flatMap(t => t.few);
/** 눈이 쌓였거나 얼었다고 말하는 글(내리는 눈 날씨 글은 따로 본다) */
const SNOW_WORDS = /눈밭|눈 더미|눈 덮|눈이 (무릎|두껍|고르|들이|발밑|붉게)|눈을 이고|눈 위|앞마당 눈|담 밑 눈|골목 눈|정문 눈|플랫폼 눈/;
const FROST_WORDS = /성에|얼어|언 |얼 만큼|살을 벤|쨍한 추위|쨍하게 춥/;

function stop(seg: number, seed: string): StopState {
  const place = PLACES[(seg * 7 + seed.length) % PLACES.length].id;
  return { place, target: 'food', stay: 'normal', crewComm: 'tail', crewSize: 4, threat: [0.8, 1, 1, 1.4][(seg * 3 + seed.length) % 4], scout: true, done: false, result: null };
}

function playClimate(seed: string): { seg: number; s: StopState }[] {
  const g = createGame(seed);
  enableClimate(g);
  const out: { seg: number; s: StopState }[] = [];
  for (let seg = 1; seg <= 24; seg += 1) {
    g.seg = seg;
    const s = stop(seg, seed);
    rollStopView(g, s, false);
    markSeen(g, s.omen!);
    out.push({ seg, s });
  }
  return out;
}

describe('계절표 날씨 칸(기온 켠 판)', () => {
  it('바꿔 끼우는 글은 모두 쓰이는 글을 바꾸고, 서로·원래 글과 겹치지 않는다', () => {
    const all = new Set([...lookLines, ...omenLines]);
    const values: string[] = [];
    for (const m of SWAPS) for (const [from, to] of Object.entries(m)) {
      expect(all.has(from), from).toBe(true);
      expect(all.has(to), to).toBe(false);
      values.push(to);
    }
    expect(new Set(values).size).toBe(values.length);
  });

  it('바꾼 글도 원래 글의 규칙을 지킨다(길이, 해석 말 없음, 화차 금지선, 쌓인 눈·얼음 없음)', () => {
    for (const m of SWAPS) for (const [from, to] of Object.entries(m)) {
      expect(to.length, to).toBeLessThanOrEqual(40);
      expect((to.match(/\./g) ?? []).length, to).toBeLessThanOrEqual(2);
      expect(/불길|괜찮|화물칸/.test(to), to).toBe(false);
      if (to.includes('화차')) expect(/안|갇|두드|신음|피/.test(to), to).toBe(false);
      if (m !== RAIN_SWAP) expect(SNOW_WORDS.test(to), to).toBe(false);
      // 한파·한파 전조 날씨 글은 얼어 있는 것이 맞다
      const cold = [...WEATHER_LOOK.cold, ...WEATHER_LOOK.cold_front, ...Object.values(WEATHER_OMENS.cold).flat(), ...Object.values(WEATHER_OMENS.cold_front).flat()].includes(from);
      if (!cold && m !== RAIN_SWAP) expect(FROST_WORDS.test(to), to).toBe(false);
    }
    const life = /새|참새|까마귀|까치|비둘기|고양이|쥐|개/;
    for (const t of fewLines) for (const m of SWAPS) {
      const to = m[t];
      if (to && /고요|기척|소리/.test(to)) expect(life.test(to), to).toBe(true);
    }
  });

  it('정차 날씨는 그 구간 계절 비율로 뽑고, 내리는 것은 그 구간 기온이 정한다', () => {
    const count = new Map<string, number>();
    for (let i = 0; i < 400; i += 1) {
      const g = createGame(`sw-${i}`);
      enableClimate(g);
      for (const r of SEASON_ROWS) {
        g.seg = r.seg;
        const w = pickWeather(g);
        if (r.temp > FALLS.snow_below) expect(w, `${r.seg}`).not.toBe('snow');
        else expect(w, `${r.seg}`).not.toBe('sleet');
        expect(['blizzard', 'cold', 'cold_front']).not.toContain(w);
        count.set(w, (count.get(w) ?? 0) + 1);
      }
    }
    // 늦가을 비율(흐림 30, 안개 25, 맑음 15, 내리는 것 30)에서 크게 벗어나지 않는다
    const n = 400 * SEASON_ROWS.length;
    const share = (w: Weather) => (count.get(w) ?? 0) / n;
    const lw = Object.fromEntries(weatherWeights(5));
    expect(lw.overcast).toBe(30);
    expect(share('overcast')).toBeGreaterThan(0.25);
    expect(share('overcast')).toBeLessThan(0.35);
    expect(share('snow') + share('sleet')).toBeGreaterThan(0.25);
    expect(share('snow') + share('sleet')).toBeLessThan(0.35);
  });

  it('꺼진 판은 옛 고정 비율 그대로다(진눈깨비·눈이 기온과 상관없이 나온다)', () => {
    const seen = new Set<Weather>();
    for (let i = 0; i < 200; i += 1) {
      const g = createGame(`off-${i}`);
      g.seg = 5;
      seen.add(pickWeather(g));
    }
    expect(seen.has('snow')).toBe(true);
  });

  it('서막(24구간)엔 눈보라 재난이 없고, 한파는 꺼진 판과 같은 구간에 온다', () => {
    const save = { ...DZ };
    try {
      DZ.blizzardP = 0.5; DZ.coldP = 0.2;
      for (let i = 0; i < 60; i += 1) {
        const on = createGame(`dz-${i}`); enableDisasters(on); enableClimate(on);
        const off = createGame(`dz-${i}`); enableDisasters(off);
        for (let seg = 1; seg <= 24; seg += 1) {
          on.seg = seg; off.seg = seg;
          if (!on.disaster) disasterSettle(on);
          if (!off.disaster) disasterSettle(off);
          expect(on.disaster?.kind, `dz-${i}/${seg}`).not.toBe('blizzard');
          if (off.disaster?.kind === 'cold') expect(on.disaster?.kind, `dz-${i}/${seg}`).toBe('cold');
          delete on.disaster; delete off.disaster;
        }
        expect(on.disasterStats?.blizzard ?? 0).toBe(0);
      }
      for (const r of SEASON_ROWS) expect(rowAt(r.seg).blizzard).toBe(false);
    } finally {
      Object.assign(DZ, save);
    }
  });

  it('쌓인 눈·밤 결빙이 없는 구간의 창밖·조짐 글엔 눈밭·얼음이 없고, 비 구간엔 진눈깨비 글이 없다', () => {
    for (let i = 0; i < 60; i += 1) {
      for (const { seg, s } of playClimate(`look-${i}`)) {
        const row = rowAt(seg);
        const text = `${s.look} ${s.omen}`;
        // 내리는 눈·진눈깨비 날씨는 땅에 조금 앉는 글이 맞다
        if (!row.snow && s.weather !== 'snow' && s.weather !== 'sleet') expect(SNOW_WORDS.test(text), `${seg} ${s.weather}: ${text}`).toBe(false);
        if (!row.night_freeze) expect(FROST_WORDS.test(text), `${seg} ${s.weather}: ${text}`).toBe(false);
        if (s.weather === 'sleet' && row.temp > FALLS.rain_above) expect(text.includes('진눈깨비'), `${seg}: ${text}`).toBe(false);
      }
    }
  });

  it('기온 켠 판에서도 한 판(24구간) 안에서 같은 조짐이 다시 안 나온다', () => {
    for (let i = 0; i < 40; i += 1) {
      const omens = playClimate(`omen-${i}`).map(x => x.s.omen);
      expect(new Set(omens).size, `omen-${i}`).toBe(omens.length);
    }
  });
});
