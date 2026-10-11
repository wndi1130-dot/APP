import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { beforeEach, describe, expect, it } from 'vitest';
import { createEngine } from '../../src/audio/engine';
import { setSound, setSoundVol } from '../../src/audio/settings';
import { SKIP_MS, SLOW_TO, STALL_GAIN, STALL_TRACKS, createStallPlan, trackTable } from '../../src/audio/stall';
import type { StallAct } from '../../src/audio/stall';
import { STALL_BEATS, stallBeats } from '../../src/ui/stall_beats';

// 멈춘 열차로 들어가는 연출의 소리(결정 101). 화면이 붙이는 data-beat만 보고 무엇을 켜고 끌지 정하는 층과,
// 긴 소리를 내는 장치(가짜 소리 장치로)를 시험한다. 어떻게 들리는지는 시험하지 못한다: 파일은 꼴과 길이만 잰다.

const STALL_DIR = fileURLToPath(new URL('../../src/audio/stall/', import.meta.url));

beforeEach(() => {
  setSound(true);
  setSoundVol(1);
});

/** 박을 차례대로 넣고 박마다 나온 일을 '무엇 소리' 꼴로 적는다 */
function run(beats: (string | null)[], on = true): string[][] {
  const plan = createStallPlan();
  return beats.map(b => plan(b, on).map(a => `${a.do} ${a.track}`));
}

describe('박자와 소리', () => {
  it('달림에서 켜고, 느려지며 잦아들고, 급제동에서 끄고 끼익, 고요에서 김이 빠진다', () => {
    expect(run(['run', 'slow', 'brake', 'hush', 'open', null])).toEqual([
      ['hold run'],
      ['bend run'],
      ['release run', 'hold brake'],
      ['hold steam'],
      [],
      [],
    ]);
  });

  it('달림은 되풀이로 켜고 나머지 둘은 한 번만 낸다. 크기는 표대로다', () => {
    const plan = createStallPlan();
    const acts = ['run', 'slow', 'brake', 'hush'].flatMap(b => plan(b, true));
    const holds = acts.filter((a): a is Extract<StallAct, { do: 'hold' }> => a.do === 'hold');
    expect(holds.map(a => [a.track, a.loop, a.gain])).toEqual([
      ['run', true, STALL_GAIN.run],
      ['brake', false, STALL_GAIN.brake],
      ['steam', false, STALL_GAIN.steam],
    ]);
    expect(holds[0].fadeMs).toBeGreaterThan(0); // 되풀이는 딱 소리 없이 열린다
  });

  it('느려지는 박의 길이는 화면의 박자 표와 같고, 그동안 빠르기와 크기가 같이 내려간다', () => {
    const plan = createStallPlan();
    plan('run', true);
    const bend = plan('slow', true).find(a => a.do === 'bend');
    const slow = stallBeats(6.5).find(s => s.beat === 'slow');
    expect(bend).toMatchObject({ track: 'run', rate: SLOW_TO.rate, ms: slow?.ms });
    expect(SLOW_TO.rate).toBeLessThan(1);
    expect(bend && bend.do === 'bend' ? bend.gain : 1).toBeLessThan(STALL_GAIN.run);
  });

  it('화면이 다시 그려져 같은 박이 또 와도 소리를 다시 켜지 않는다', () => {
    expect(run(['run', 'run', 'slow', 'slow'])).toEqual([['hold run'], [], ['bend run'], []]);
  });

  it('달리는 중에 눌러 건너뛰면 달림을 짧게 줄이고 김 빠지는 소리를 낸다', () => {
    const plan = createStallPlan();
    plan('run', true);
    expect(plan('open', true)).toEqual([
      { do: 'release', track: 'run', ms: SKIP_MS },
      { do: 'hold', track: 'steam', loop: false, gain: STALL_GAIN.steam, fadeMs: 0 },
    ]);
  });

  it('급제동 중에 건너뛰면 끼익도 짧게 줄인다. 고요를 거쳐 왔으면 끼익의 끝을 자르지 않는다', () => {
    expect(run(['run', 'slow', 'brake', 'open'])[3]).toEqual(['release brake', 'hold steam']);
    expect(run(['run', 'slow', 'brake', 'hush', 'open'])[4]).toEqual([]);
  });

  it('달림 박이 빠진 짧은 연출은 느려지는 박에서 달림을 켠다', () => {
    expect(run(['slow', 'brake'])).toEqual([['hold run', 'bend run'], ['release run', 'hold brake']]);
  });

  it('연출이 끝난 뒤 다음에 또 서면 처음부터 다시 낸다', () => {
    const all = run(['run', 'slow', 'brake', 'hush', 'open', null, 'run', 'slow', 'brake', 'hush']);
    expect(all.slice(6)).toEqual([['hold run'], ['bend run'], ['release run', 'hold brake'], ['hold steam']]);
  });

  it('소리를 꺼 두면 아무것도 내지 않는다. 달리는 도중에 끄면 돌던 것만 줄인다', () => {
    expect(run(['run', 'slow', 'brake', 'hush', 'open', null], false).flat()).toEqual([]);
    const plan = createStallPlan();
    plan('run', true);
    expect(plan('slow', false)).toEqual([{ do: 'release', track: 'run', ms: SKIP_MS }]);
    expect(plan('brake', false)).toEqual([]);
  });

  it('모르는 값은 연출이 없는 것으로 친다. 박 이름은 화면의 것과 같다', () => {
    expect(run(['wave', 'run'])).toEqual([[], ['hold run']]);
    expect([...STALL_BEATS]).toEqual(['run', 'slow', 'brake', 'hush', 'open']);
  });
});

// ---- 긴 소리를 내는 장치 ----
interface Ramp { kind: 'set' | 'ramp' | 'cancel'; v: number; t: number }
interface FakeNode { loop: boolean; started: boolean; stopAt: number | null; rate: Ramp[]; gain: Ramp[] }

function param(log: Ramp[], box: { value: number }) {
  return Object.assign(box, {
    setValueAtTime(v: number, t: number) { box.value = v; log.push({ kind: 'set', v, t }); },
    linearRampToValueAtTime(v: number, t: number) { box.value = v; log.push({ kind: 'ramp', v, t }); },
    cancelScheduledValues(t: number) { log.push({ kind: 'cancel', v: box.value, t }); },
    setTargetAtTime(v: number) { box.value = v; },
  });
}

function fakeAudio() {
  const nodes: FakeNode[] = [];
  const ctx = {
    state: 'suspended' as string,
    currentTime: 10,
    destination: {},
    resume() { ctx.state = 'running'; return Promise.resolve(); },
    createGain() {
      // 처음 만든 것은 전체 크기(master)다. 그 뒤는 소리마다 하나씩이고, 장치는 소리를 만든 바로 다음에 만든다.
      const log: Ramp[] = [];
      const node = nodes[nodes.length - 1];
      if (node) node.gain = log;
      return { gain: param(log, { value: 1 }), connect() {}, disconnect() {} };
    },
    createBufferSource() {
      const node: FakeNode = { loop: false, started: false, stopAt: null, rate: [], gain: [] };
      const rate = param(node.rate, { value: 1 });
      nodes.push(node);
      return Object.assign(node, { buffer: null, playbackRate: rate, onended: null, connect() {}, disconnect() {}, start() { node.started = true; }, stop(t: number) { node.stopAt = t; } });
    },
    decodeAudioData(data: ArrayBuffer, ok: (b: unknown) => void) { ok({ bytes: data.byteLength }); },
  };
  return { ctx, nodes };
}

async function ready(tracks: Record<string, string> = { run: 'stall/run', brake: 'stall/brake', steam: 'stall/steam' }) {
  const fake = fakeAudio();
  const engine = createEngine({
    makeContext: () => fake.ctx as unknown as AudioContext,
    clips: { 'enamel.press': [], 'enamel.confirm': [], 'paper.press': [], 'paper.confirm': [], 'lever.notch': [], denied: [] },
    tracks,
    load: async url => new ArrayBuffer(url.length),
  });
  await engine.preload();
  return { fake, engine };
}

describe('긴 소리 장치', () => {
  it('첫 손짓 전에는 긴 소리도 내지 않는다', async () => {
    const { fake, engine } = await ready();
    expect(engine.hold('run', { loop: true, gain: 0.5, fadeMs: 150 })).toBe(false);
    expect(fake.nodes).toHaveLength(0);
  });

  it('되풀이는 한 번만 켜지고(다시 불러도 하나), 크기를 서서히 올린다', async () => {
    const { fake, engine } = await ready();
    engine.unlock();
    await Promise.resolve();
    expect(engine.hold('run', { loop: true, gain: 0.5, fadeMs: 150 })).toBe(true);
    expect(engine.hold('run', { loop: true, gain: 0.5, fadeMs: 150 })).toBe(true);
    expect(fake.nodes).toHaveLength(1);
    expect(fake.nodes[0]).toMatchObject({ loop: true, started: true, stopAt: null });
    expect(fake.nodes[0].gain).toEqual([{ kind: 'set', v: 0, t: 10 }, { kind: 'ramp', v: 0.5, t: 10.15 }]);
  });

  it('느려질 때 빠르기와 크기를 같은 길이에 걸쳐 내린다', async () => {
    const { fake, engine } = await ready();
    engine.unlock();
    await Promise.resolve();
    engine.hold('run', { loop: true, gain: 0.5, fadeMs: 150 });
    fake.ctx.currentTime = 13;
    engine.bend('run', 0.6, 0.1, 1000);
    expect(fake.nodes[0].rate).toEqual([{ kind: 'set', v: 1, t: 13 }, { kind: 'ramp', v: 0.6, t: 14 }]);
    expect(fake.nodes[0].gain.slice(-1)).toEqual([{ kind: 'ramp', v: 0.1, t: 14 }]);
  });

  it('끌 때는 줄인 다음에 멈춘다. 끈 뒤에는 같은 이름을 다시 켤 수 있다', async () => {
    const { fake, engine } = await ready();
    engine.unlock();
    await Promise.resolve();
    engine.hold('run', { loop: true, gain: 0.5, fadeMs: 150 });
    fake.ctx.currentTime = 14;
    engine.release('run', 300);
    expect(fake.nodes[0].gain.slice(-1)).toEqual([{ kind: 'ramp', v: 0, t: 14.3 }]);
    expect(fake.nodes[0].stopAt).toBeCloseTo(14.32, 5);
    engine.release('run', 300); // 이미 끈 것은 그냥 넘어간다
    expect(engine.hold('run', { loop: true, gain: 0.5, fadeMs: 150 })).toBe(true);
    expect(fake.nodes).toHaveLength(2);
  });

  it('한 번 나는 소리는 되풀이하지 않고, 다시 내면 앞의 것을 끄고 새로 낸다', async () => {
    const { fake, engine } = await ready();
    engine.unlock();
    await Promise.resolve();
    expect(engine.hold('brake', { loop: false, gain: 0.8 })).toBe(true);
    expect(engine.hold('brake', { loop: false, gain: 0.8 })).toBe(true);
    expect(fake.nodes).toHaveLength(2);
    expect(fake.nodes[0].loop).toBe(false);
    expect(fake.nodes[0].stopAt).not.toBeNull();
    expect(fake.nodes[1].stopAt).toBeNull();
  });

  it('파일이 없는 이름이나 돌지 않는 소리는 조용히 넘어간다', async () => {
    const { fake, engine } = await ready({ run: 'stall/run' });
    engine.unlock();
    await Promise.resolve();
    expect(engine.hold('steam', { loop: false, gain: 0.5 })).toBe(false);
    engine.bend('steam', 0.6, 0.1, 1000);
    engine.release('steam', 300);
    expect(fake.nodes).toHaveLength(0);
  });
});

// ---- 저장소에 든 파일 ----
interface Wav { channels: number; rate: number; bits: number; seconds: number; leadMs: number; bytes: number; first: number; last: number }

function readWav(file: string): Wav {
  const b = readFileSync(file);
  expect(b.toString('latin1', 0, 4)).toBe('RIFF');
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
  const rate = b.readUInt32LE(fmt + 4);
  const n = Math.floor(size / 2);
  let lead = n;
  for (let i = 0; i < n; i += 1) {
    if (Math.abs(b.readInt16LE(data + i * 2)) > 327) { lead = i; break; } // 전체 눈금의 1%(−40dB)
  }
  return {
    channels: b.readUInt16LE(fmt + 2), rate, bits: b.readUInt16LE(fmt + 14), seconds: n / rate, leadMs: (lead / rate) * 1000, bytes: b.length,
    first: b.readInt16LE(data) / 32768, last: b.readInt16LE(data + (n - 1) * 2) / 32768,
  };
}

describe('든 긴 소리 파일', () => {
  const names = readdirSync(STALL_DIR).filter(n => n.endsWith('.wav'));
  const wav = (name: string) => readWav(STALL_DIR + name);

  it('소리 셋에 파일이 하나씩 있고, 이름이 안 맞아 버려지는 파일이 없다', () => {
    const table = trackTable(Object.fromEntries(names.map(n => [`./stall/${n}`, n])));
    expect(Object.keys(table).sort()).toEqual([...STALL_TRACKS].sort());
    expect(names).toHaveLength(STALL_TRACKS.length);
  });

  it('모두 모노 16비트 22050Hz이고, 합쳐 260KB를 넘지 않는다(폰 용량)', () => {
    let total = 0;
    for (const n of names) {
      const w = wav(n);
      expect([n, w.channels, w.bits, w.rate]).toEqual([n, 1, 16, 22050]);
      total += w.bytes;
    }
    expect(total).toBeLessThan(260 * 1024);
  });

  it('달림은 2초 안팎의 되풀이이고 처음과 끝이 이어진다(이음매에서 딱 소리가 나지 않는다)', () => {
    const w = wav('run.wav');
    expect(w.seconds).toBeGreaterThan(1.5);
    expect(w.seconds).toBeLessThan(3);
    expect(Math.abs(w.first - w.last)).toBeLessThan(0.02);
  });

  it('급제동은 바로 시작하고 급제동 박(1.1초)보다 조금만 길다. 김 빠짐은 2초 안이다', () => {
    const brakeBeat = (stallBeats(6.5).find(s => s.beat === 'brake')?.ms ?? 0) / 1000;
    const brake = wav('brake.wav');
    expect(brake.leadMs).toBeLessThan(30);
    expect(brake.seconds).toBeGreaterThan(brakeBeat - 0.2);
    expect(brake.seconds).toBeLessThan(brakeBeat + 0.4);
    expect(wav('steam.wav').seconds).toBeLessThan(2);
  });
});
