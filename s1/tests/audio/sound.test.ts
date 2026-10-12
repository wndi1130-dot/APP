import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CUES, CUE_GAP, PITCH, clipTable, createPlanner, cueForAction } from '../../src/audio/cues';
import type { Cue } from '../../src/audio/cues';
import { LATE_MS, createEngine } from '../../src/audio/engine';
import { SOUND_VOL_GAIN, cycleSound, setSound, setSoundVol, soundLabel, soundOn, soundVol } from '../../src/audio/settings';

// 손끝 소리(sound_music 8b.1): 어느 단추가 어느 박자인지, 연타로 쌓지 않는지, 끄면 안 나는지, 첫 손짓 전에 안 나는지.
// 소리가 어떻게 들리는지는 시험하지 못한다. 파일은 꼴(모노 16비트 44100Hz)과 길이, 첫머리만 잰다.

const CLIPS_DIR = fileURLToPath(new URL('../../src/audio/clips/', import.meta.url));
const THREE = Object.fromEntries(CUES.map(c => [c, 3])) as Record<Cue, number>;

/** rand를 정해진 차례로 돌려준다 */
function seq(...values: number[]): () => number {
  let i = 0;
  return () => values[i++ % values.length];
}

beforeEach(() => {
  setSound(true);
  setSoundVol(1);
});

describe('소리 설정', () => {
  it('기본은 켬이고 크기는 보통이다. 메뉴 단추 하나가 끔 → 작게 → 보통 → 크게 → 끔으로 돈다', () => {
    expect(soundOn()).toBe(true);
    expect(soundVol()).toBe(1);
    expect(soundLabel()).toBe('소리: 보통');
    const seen: string[] = [];
    for (let i = 0; i < 4; i += 1) {
      cycleSound();
      seen.push(soundLabel());
    }
    expect(seen).toEqual(['소리: 크게', '소리 끔', '소리: 작게', '소리: 보통']);
    expect(soundOn()).toBe(true);
    expect(SOUND_VOL_GAIN[0]).toBeLessThan(SOUND_VOL_GAIN[1]);
    expect(SOUND_VOL_GAIN[1]).toBeLessThan(SOUND_VOL_GAIN[2]);
  });

  it('끈 것과 크기는 브라우저에 남아 다음에 열 때도 그대로다', async () => {
    const store = new Map<string, string>();
    vi.stubGlobal('localStorage', { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => { store.set(k, v); } });
    try {
      setSound(false);
      setSoundVol(2);
      expect(store.get('s1a.sound')).toBe('0');
      expect(store.get('s1a.soundvol')).toBe('2');
      vi.resetModules();
      const fresh = await import('../../src/audio/settings');
      expect(fresh.soundOn()).toBe(false);
      expect(fresh.soundVol()).toBe(2);
    } finally {
      vi.unstubAllGlobals();
    }
  });
});

describe('단추와 박자', () => {
  it('서류에 긋는 선택은 종이 확정, 사람을 보내는 확정은 놋쇠 확정, 나머지는 가벼운 누름이다', () => {
    expect(cueForAction('choose')).toBe('paper.confirm');
    expect(cueForAction('vote')).toBe('paper.confirm');
    expect(cueForAction('agenda')).toBe('paper.press');
    expect(cueForAction('stop-go')).toBe('enamel.confirm');
    expect(cueForAction('dom-hot')).toBe('lever.notch');
    expect(cueForAction('panel')).toBe('enamel.press');
  });

  it('표에 없는 단추는 놋쇠 누름이다: 화면에 단추가 늘어도 조용하거나 무겁지 않다', () => {
    expect(cueForAction('dom-tab')).toBe('enamel.press');
    expect(cueForAction('아직-없는-단추')).toBe('enamel.press');
    expect(cueForAction('')).toBe('enamel.press');
  });
});

describe('소리 고르기', () => {
  it('같은 박자가 틈 안에 또 오면 버린다(연타로 쌓지 않는다). 다른 박자는 막지 않는다', () => {
    const plan = createPlanner(THREE, seq(0.5));
    expect(plan('enamel.press', 1000)).not.toBeNull();
    expect(plan('enamel.press', 1000 + CUE_GAP['enamel.press'] - 1)).toBeNull();
    expect(plan('paper.press', 1000 + 1)).not.toBeNull();
    expect(plan('enamel.press', 1000 + CUE_GAP['enamel.press'])).not.toBeNull();
  });

  it('확정과 막힘은 누름보다 틈이 길다: 무거운 소리가 겹치지 않는다', () => {
    expect(CUE_GAP['enamel.confirm']).toBeGreaterThan(CUE_GAP['enamel.press']);
    expect(CUE_GAP['paper.confirm']).toBeGreaterThan(CUE_GAP['paper.press']);
    expect(CUE_GAP.denied).toBeGreaterThan(CUE_GAP['enamel.press']);
  });

  it('변형은 바로 앞의 것을 피해 돌리고, 높이는 ±5% 안에서 흔든다', () => {
    const plan = createPlanner(THREE);
    let prev = -1;
    for (let i = 0; i < 200; i += 1) {
      const shot = plan('enamel.press', i * 1000)!;
      expect(shot.variant).toBeGreaterThanOrEqual(0);
      expect(shot.variant).toBeLessThan(3);
      expect(shot.variant).not.toBe(prev);
      expect(Math.abs(shot.rate - 1)).toBeLessThanOrEqual(PITCH + 1e-9);
      prev = shot.variant;
    }
  });

  it('소리를 끄면 아무것도 고르지 않고, 다시 켜면 고른다', () => {
    const plan = createPlanner(THREE, seq(0.5));
    setSound(false);
    for (const cue of CUES) expect(plan(cue, 5000)).toBeNull();
    setSound(true);
    for (const cue of CUES) expect(plan(cue, 5000)).not.toBeNull();
  });

  it('변형 파일이 없는 박자는 조용하다', () => {
    const plan = createPlanner({ ...THREE, denied: 0 }, seq(0.5));
    expect(plan('denied', 0)).toBeNull();
  });
});

// ---- 소리 장치: 가짜 Web Audio로 본다 ----
interface FakeSource { rate: number; started: boolean; stopped: boolean; buffer: unknown }

function fakeAudio() {
  const sources: FakeSource[] = [];
  const master = { value: 1 };
  let gains = 0;
  const ctx = {
    state: 'suspended' as string,
    currentTime: 0,
    destination: {},
    resume() { ctx.state = 'running'; return Promise.resolve(); },
    createGain() {
      const param = gains++ === 0 ? master : { value: 1 };
      return { gain: Object.assign(param, { setTargetAtTime(v: number) { param.value = v; } }), connect() {}, disconnect() {} };
    },
    createBufferSource() {
      const s: FakeSource & Record<string, unknown> = { rate: 1, started: false, stopped: false, buffer: null };
      const playbackRate = { get value() { return s.rate; }, set value(v: number) { s.rate = v; } };
      sources.push(s);
      return Object.assign(s, { playbackRate, onended: null, connect() {}, disconnect() {}, start() { s.started = true; }, stop() { s.stopped = true; } });
    },
    decodeAudioData(data: ArrayBuffer, ok: (b: unknown) => void) { ok({ bytes: data.byteLength }); },
  };
  return { ctx, sources, master };
}

function engineWith(fake: ReturnType<typeof fakeAudio>, clock = { t: 0 }) {
  const made = { n: 0 };
  const clips = Object.fromEntries(CUES.map(c => [c, [1, 2, 3].map(i => `${c}/${i}`)])) as Record<Cue, string[]>;
  const engine = createEngine({
    makeContext: () => { made.n += 1; return fake.ctx as unknown as AudioContext; },
    clips,
    load: async url => new ArrayBuffer(url.length),
    now: () => clock.t,
  });
  return { engine, made };
}

describe('소리 장치', () => {
  it('첫 손짓 전에는 파일을 받아 두기만 하고 장치를 열지 않으며 소리도 내지 않는다', async () => {
    const fake = fakeAudio();
    const { engine, made } = engineWith(fake);
    await engine.preload();
    expect(made.n).toBe(0);
    expect(engine.play({ cue: 'enamel.press', variant: 0, rate: 1 })).toBe(false);
    expect(fake.sources).toHaveLength(0);
  });

  it('손짓 뒤에는 장치를 한 번만 열고, 고른 변형을 그 높이와 크기로 낸다', async () => {
    const fake = fakeAudio();
    const { engine, made } = engineWith(fake);
    await engine.preload();
    engine.unlock();
    engine.unlock();
    await Promise.resolve();
    expect(made.n).toBe(1);
    setSoundVol(2); // 크게
    expect(engine.play({ cue: 'paper.confirm', variant: 2, rate: 1.03 })).toBe(true);
    expect(fake.sources).toHaveLength(1);
    expect(fake.sources[0]).toMatchObject({ started: true, stopped: false, rate: 1.03 });
    expect(fake.master.value).toBe(SOUND_VOL_GAIN[2]);
  });

  it('첫 누름이 파일보다 조금 먼저 오면 잠깐 기다렸다 낸다(첫 누름이 조용하지 않게)', async () => {
    const fake = fakeAudio();
    const clock = { t: 0 };
    const { engine } = engineWith(fake, clock);
    engine.unlock();
    expect(engine.play({ cue: 'denied', variant: 0, rate: 1 })).toBe(false);
    expect(fake.sources).toHaveLength(0);
    clock.t = LATE_MS - 1;
    await engine.preload();
    await Promise.resolve();
    expect(fake.sources).toHaveLength(1);
    expect(fake.sources[0].started).toBe(true);
  });

  it('너무 늦게 준비되면 기다리던 소리는 버린다: 한참 뒤에 따라 나오지 않는다', async () => {
    const fake = fakeAudio();
    const clock = { t: 0 };
    const { engine } = engineWith(fake, clock);
    engine.unlock();
    expect(engine.play({ cue: 'denied', variant: 0, rate: 1 })).toBe(false);
    clock.t = LATE_MS + 1;
    await engine.preload();
    await Promise.resolve();
    expect(fake.sources).toHaveLength(0);
    expect(engine.play({ cue: 'denied', variant: 0, rate: 1 })).toBe(true);
  });

  it('같은 박자가 다시 나면 앞 소리를 끈다(쌓지 않는다). 다른 박자는 그대로 둔다', async () => {
    const fake = fakeAudio();
    const { engine } = engineWith(fake);
    await engine.preload();
    engine.unlock();
    await Promise.resolve();
    engine.play({ cue: 'enamel.press', variant: 0, rate: 1 });
    engine.play({ cue: 'paper.press', variant: 0, rate: 1 });
    engine.play({ cue: 'enamel.press', variant: 1, rate: 1 });
    expect(fake.sources.map(s => s.stopped)).toEqual([true, false, false]);
  });

  it('장치가 잠들어 있으면(다른 앱에 다녀옴) 내지 않고, 다음 손짓에 깨운다', async () => {
    const fake = fakeAudio();
    const { engine } = engineWith(fake);
    await engine.preload();
    engine.unlock();
    await Promise.resolve();
    fake.ctx.state = 'suspended';
    expect(engine.play({ cue: 'enamel.press', variant: 0, rate: 1 })).toBe(false);
    engine.unlock();
    expect(engine.play({ cue: 'enamel.press', variant: 0, rate: 1 })).toBe(true);
  });

  it('소리를 못 내는 브라우저에서는 조용히 넘어간다', async () => {
    const clips = Object.fromEntries(CUES.map(c => [c, [`${c}/1`]])) as Record<Cue, string[]>;
    const engine = createEngine({ makeContext: () => null, clips, load: async () => { throw new Error('없음'); } });
    await engine.preload();
    engine.unlock();
    expect(engine.play({ cue: 'enamel.press', variant: 0, rate: 1 })).toBe(false);
  });
});

// ---- 저장소에 든 파일 ----
interface Wav { channels: number; rate: number; bits: number; seconds: number; leadMs: number; bytes: number }

function readWav(file: string): Wav {
  const b = readFileSync(file);
  expect(b.toString('latin1', 0, 4)).toBe('RIFF');
  expect(b.toString('latin1', 8, 12)).toBe('WAVE');
  let at = 12;
  let fmt = -1;
  let data = -1;
  let size = 0;
  while (at + 8 <= b.length) {
    const id = b.toString('latin1', at, at + 4);
    const len = b.readUInt32LE(at + 4);
    if (id === 'fmt ') fmt = at + 8;
    if (id === 'data') { data = at + 8; size = Math.min(len, b.length - data); break; }
    at += 8 + len + (len % 2);
  }
  expect(fmt).toBeGreaterThan(0);
  expect(data).toBeGreaterThan(0);
  const channels = b.readUInt16LE(fmt + 2);
  const rate = b.readUInt32LE(fmt + 4);
  const bits = b.readUInt16LE(fmt + 14);
  const n = Math.floor(size / 2);
  let first = n;
  for (let i = 0; i < n; i += 1) {
    if (Math.abs(b.readInt16LE(data + i * 2)) > 327) { first = i; break; } // 전체 눈금의 1%(−40dB)
  }
  return { channels, rate, bits, seconds: n / rate, leadMs: (first / rate) * 1000, bytes: b.length };
}

describe('든 소리 파일', () => {
  const names = readdirSync(CLIPS_DIR).filter(n => n.endsWith('.wav'));
  const table = clipTable(Object.fromEntries(names.map(n => [`./clips/${n}`, n])));

  it('박자 다섯에 변형이 셋씩 있고 막힘은 사용자가 고른 하나이며, 이름이 안 맞아 버려지는 파일이 없다', () => {
    for (const cue of CUES) expect(table[cue], cue).toHaveLength(cue === 'denied' ? 1 : 3);
    expect(names).toHaveLength(16);
  });

  it('모두 모노 16비트 44100Hz이고, 합쳐 300KB를 넘지 않는다(폰 용량)', () => {
    let total = 0;
    for (const n of names) {
      const w = readWav(CLIPS_DIR + n);
      expect([n, w.channels, w.bits, w.rate]).toEqual([n, 1, 16, 44100]);
      total += w.bytes;
    }
    expect(total).toBeLessThan(300 * 1024);
  });

  it('소리가 30ms 안에 시작한다(누르고 80ms 안에 들려야 한다)', () => {
    for (const n of names) expect(readWav(CLIPS_DIR + n).leadMs, n).toBeLessThan(30);
  });

  it('길이가 박자표를 넘지 않는다: 누름 90ms, 확정 450ms, 막힘 250ms', () => {
    const limit: Record<Cue, number> = {
      'enamel.press': 0.09, 'paper.press': 0.09, 'lever.notch': 0.09, 'enamel.confirm': 0.45, 'paper.confirm': 0.45, denied: 0.25,
    };
    for (const cue of CUES) {
      for (const n of table[cue]) expect(readWav(CLIPS_DIR + n).seconds, n).toBeLessThanOrEqual(limit[cue] + 0.001);
    }
  });
});
