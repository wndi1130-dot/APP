import { describe, expect, it } from 'vitest';
import { createEngine } from '../../src/audio/engine';
import { BED, GUST, HOWL, bedStep, gustGap, planGust, planHowl } from '../../src/audio/gusts';
import type { Gust } from '../../src/audio/gusts';

// 서 있는 열차 둘레의 바람(사용자 2026-10-24: 「지금 규칙적이니까 귀가피곤함」): 같은 꼴로 되풀이하지 않는다.

/** 씨앗으로 늘 같은 0~1 수열(시험이 매번 같게) */
function seeded(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

describe('바람의 꼴', () => {
  it('돌풍은 정한 범위 안에서 사이·길이·크기·휨이 저마다 다르고, 바로 앞 것과 같은 꼴은 없다', () => {
    const rand = seeded(7);
    let prev: Gust | null = null;
    const gaps = new Set<number>();
    const lens = new Set<number>();
    for (let i = 0; i < 200; i += 1) {
      const g = planGust(rand, prev);
      expect(g.len).toBeGreaterThanOrEqual(GUST.len[0]);
      expect(g.len).toBeLessThanOrEqual(GUST.len[1]);
      expect(g.rate0).toBeGreaterThanOrEqual(GUST.rate[0]);
      expect(g.rate0).toBeLessThanOrEqual(GUST.rate[1]);
      expect(g.offset).toBeLessThanOrEqual(GUST.offset[1]);
      if (prev) expect(Math.abs(g.rate0 - prev.rate0)).toBeGreaterThan(GUST.apart);
      const gap = gustGap(rand);
      expect(gap).toBeGreaterThanOrEqual(GUST.gap[0]);
      expect(gap).toBeLessThanOrEqual(GUST.gap[1]);
      gaps.add(Math.round(gap * 10));
      lens.add(Math.round(g.len * 10));
      prev = g;
    }
    expect(gaps.size).toBeGreaterThan(30); // 사이가 고르지 않다: 박자가 없다
    expect(lens.size).toBeGreaterThan(10);
  });

  it('처음 드는 「후오오옹」은 한~세 겹이고 길며, 들을 때마다 모양이 다르다', () => {
    const rand = seeded(11);
    const shapes = new Set<string>();
    const layers = new Set<number>();
    for (let i = 0; i < 40; i += 1) {
      const howl = planHowl(rand);
      expect(howl.length).toBeGreaterThanOrEqual(HOWL.layers[0]);
      expect(howl.length).toBeLessThanOrEqual(HOWL.layers[1]);
      expect(howl[0].delay).toBe(0);
      for (const g of howl) {
        expect(g.len).toBeGreaterThanOrEqual(HOWL.len[0]);
        expect(g.len).toBeLessThanOrEqual(HOWL.len[1]);
        expect(g.delay).toBeLessThanOrEqual(HOWL.spread);
      }
      layers.add(howl.length);
      shapes.add(JSON.stringify(howl));
    }
    expect(layers.size).toBe(3); // 겹 수도 바뀐다
    expect(shapes.size).toBe(40);
  });

  it('깔개는 크기와 거르는 높이가 범위 안에서 옮겨 다닌다', () => {
    const rand = seeded(3);
    const gains = new Set<number>();
    for (let i = 0; i < 50; i += 1) {
      const s = bedStep(rand);
      expect(s.gain).toBeGreaterThanOrEqual(BED.gain[0]);
      expect(s.gain).toBeLessThanOrEqual(BED.gain[1]);
      expect(s.freq).toBeGreaterThanOrEqual(BED.freq[0]);
      expect(s.freq).toBeLessThanOrEqual(BED.freq[1]);
      gains.add(Math.round(s.gain * 100));
    }
    expect(gains.size).toBeGreaterThan(20);
  });
});

// ---- 장치: 깔개 하나와 돌풍들 ----
interface Ramp { kind: 'set' | 'ramp' | 'cancel'; v: number; t: number }
interface Src { loop: boolean; buffer: unknown; startAt: number | null; offset: number; stopAt: number | null; rate: Ramp[]; gain: Ramp[] }

function param(log: Ramp[], box: { value: number }) {
  return Object.assign(box, {
    setValueAtTime(v: number, t: number) { box.value = v; log.push({ kind: 'set', v, t }); },
    linearRampToValueAtTime(v: number, t: number) { box.value = v; log.push({ kind: 'ramp', v, t }); },
    cancelScheduledValues(t: number) { log.push({ kind: 'cancel', v: box.value, t }); },
    setTargetAtTime(v: number) { box.value = v; },
  });
}

function fakeAudio() {
  const sources: Src[] = [];
  const filters: Ramp[][] = [];
  const ctx = {
    state: 'suspended' as string,
    currentTime: 10,
    sampleRate: 8000,
    destination: {},
    resume() { ctx.state = 'running'; return Promise.resolve(); },
    createGain() {
      // 처음 만든 것은 전체 크기다. 그 뒤는 바로 앞에 만든 소리의 크기다.
      const log: Ramp[] = [];
      const src = sources[sources.length - 1];
      if (src) src.gain = log;
      return { gain: param(log, { value: 1 }), connect() {}, disconnect() {} };
    },
    createBiquadFilter() {
      const log: Ramp[] = [];
      filters.push(log);
      return { type: '', Q: { value: 1 }, frequency: param(log, { value: 350 }), connect() {}, disconnect() {} };
    },
    createBuffer(_ch: number, length: number) {
      const data = new Float32Array(length);
      return { length, getChannelData: () => data, noise: true };
    },
    createBufferSource() {
      const node: Src = { loop: false, buffer: null, startAt: null, offset: 0, stopAt: null, rate: [], gain: [] };
      sources.push(node);
      return Object.assign(node, {
        playbackRate: param(node.rate, { value: 1 }), onended: null, connect() {}, disconnect() {},
        start(t: number, offset = 0) { node.startAt = t; node.offset = offset; },
        stop(t: number) { node.stopAt = t; },
      });
    },
    decodeAudioData(data: ArrayBuffer, ok: (b: unknown) => void) { ok({ bytes: data.byteLength }); },
  };
  return { ctx, sources, filters };
}

async function windy(seed = 5) {
  const fake = fakeAudio();
  const timers: { fn: () => void; ms: number; live: boolean }[] = [];
  const engine = createEngine({
    makeContext: () => fake.ctx as unknown as AudioContext,
    clips: { 'enamel.press': [], 'enamel.confirm': [], 'paper.press': [], 'paper.confirm': [], 'lever.notch': [], denied: [] },
    tracks: { wind: 'stall/wind', run: 'stall/run' },
    gusty: ['wind'],
    random: seeded(seed),
    later: (fn, ms) => { const t = { fn, ms, live: true }; timers.push(t); return () => { t.live = false; }; },
    load: async url => new ArrayBuffer(url.length),
  });
  await engine.preload();
  engine.unlock();
  await Promise.resolve();
  /** 걸어 둔 것 가운데 아직 살아 있는 것을 차례로 부른다(한 바퀴) */
  const run = () => {
    for (const t of timers.splice(0)) if (t.live) t.fn();
  };
  return { fake, engine, timers, run };
}

const gusts = (fake: ReturnType<typeof fakeAudio>) => fake.sources.filter(s => !s.loop);

describe('바람 장치', () => {
  it('바람은 파일을 되풀이하지 않는다: 낮게 거른 잡음 깔개 하나와 「후오오옹」 한~세 겹으로 든다', async () => {
    const { fake, engine } = await windy();
    expect(engine.hold('wind', { loop: true, gain: 0.3, fadeMs: 600 })).toBe(true);
    const bed = fake.sources.filter(s => s.loop);
    expect(bed).toHaveLength(1);
    expect(bed[0].buffer).toMatchObject({ noise: true });
    expect(bed[0].gain).toEqual([{ kind: 'set', v: 0, t: 10 }, { kind: 'ramp', v: 0.3 * BED.start, t: 10.6 }]);
    const howl = gusts(fake);
    expect(howl.length).toBeGreaterThanOrEqual(1);
    expect(howl.length).toBeLessThanOrEqual(3);
    for (const g of howl) {
      expect(g.buffer).toMatchObject({ bytes: 'stall/wind'.length }); // 바람 파일 한 번
      expect(g.stopAt).not.toBeNull();
      expect(g.rate[0].kind).toBe('set');
      expect(g.rate[1].kind).toBe('ramp'); // 높낮이가 휜다
    }
    // 다시 불러도 하나다.
    expect(engine.hold('wind', { loop: true, gain: 0.3, fadeMs: 600 })).toBe(true);
    expect(fake.sources.filter(s => s.loop)).toHaveLength(1);
  });

  it('그 뒤 돌풍은 고르지 않은 사이로 오고, 깔개는 무작위 목표로 옮겨 간다', async () => {
    const { fake, engine, timers, run } = await windy();
    engine.hold('wind', { loop: true, gain: 0.3, fadeMs: 600 });
    const first = gusts(fake).length;
    const waits: number[] = [];
    for (let i = 0; i < 12; i += 1) {
      waits.push(...timers.filter(t => t.live).map(t => t.ms));
      fake.ctx.currentTime += 3;
      run();
    }
    const later = gusts(fake).slice(first);
    expect(later.length).toBeGreaterThanOrEqual(10);
    for (let i = 1; i < later.length; i += 1) {
      expect(Math.abs(later[i].rate[0].v - later[i - 1].rate[0].v)).toBeGreaterThan(GUST.apart); // 바로 앞 것과 다른 꼴
    }
    expect(new Set(waits.map(ms => Math.round(ms / 100))).size).toBeGreaterThan(8); // 사이가 매번 다르다
    expect(fake.filters[0].filter(r => r.kind === 'ramp').length).toBeGreaterThan(5);
  });

  it('바람을 끄면 깔개와 부는 돌풍을 줄여 멈추고, 걸어 둔 다음 돌풍은 오지 않는다', async () => {
    const { fake, engine, timers, run } = await windy();
    engine.hold('wind', { loop: true, gain: 0.3, fadeMs: 600 });
    fake.ctx.currentTime = 12;
    engine.release('wind', 300);
    for (const s of fake.sources) {
      expect(s.gain.slice(-1)).toEqual([{ kind: 'ramp', v: 0, t: 12.3 }]);
      expect(s.stopAt).not.toBeNull();
    }
    const n = fake.sources.length;
    expect(timers.every(t => !t.live)).toBe(true);
    run();
    expect(fake.sources).toHaveLength(n);
    // 다시 서면 다시 든다(또 다른 모양으로).
    expect(engine.hold('wind', { loop: true, gain: 0.3, fadeMs: 600 })).toBe(true);
    expect(fake.sources.length).toBeGreaterThan(n + 1);
  });

  it('바람이 아닌 되풀이는 그대로 파일을 되풀이한다', async () => {
    const { fake, engine } = await windy();
    engine.hold('run', { loop: true, gain: 0.5, fadeMs: 150 });
    expect(fake.sources).toHaveLength(1);
    expect(fake.sources[0]).toMatchObject({ loop: true, offset: 0 });
  });
});
