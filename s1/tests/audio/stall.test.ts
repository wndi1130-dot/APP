import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { beforeEach, describe, expect, it } from 'vitest';
import { createEngine } from '../../src/audio/engine';
import { setSound, setSoundVol } from '../../src/audio/settings';
import { EDGE_MS, SKIP_MS, SLOW_TO, STALL_GAIN, STALL_TRACKS, createStallPlan, trackTable } from '../../src/audio/stall';
import type { StallAct } from '../../src/audio/stall';
import { RESUME_MS, STALL_BEATS, stallBeats } from '../../src/ui/stall_beats';

// 멈춘 열차의 소리(결정 101). 화면이 붙이는 data-beat와 data-stranded만 보고 무엇을 켜고 끌지 정하는 층과,
// 긴 소리를 내는 장치(가짜 소리 장치로)를 시험한다. 어떻게 들리는지는 시험하지 못한다: 파일은 꼴과 길이만 잰다.

const STALL_DIR = fileURLToPath(new URL('../../src/audio/stall/', import.meta.url));

beforeEach(() => {
  setSound(true);
  setSoundVol(1);
});

/** 박 하나, 또는 [박, 홈에 data-stranded가 있는가(홈이 안 보이면 null)] */
type Step = string | null | [string | null, boolean | null];

/** 박을 차례대로 넣고 박마다 나온 일을 '무엇 소리' 꼴로 적는다 */
function run(steps: Step[], on = true): string[][] {
  const plan = createStallPlan();
  return steps.map(s => {
    const [beat, stranded] = Array.isArray(s) ? s : [s, null];
    return plan(beat, on, stranded).map(a => `${a.do} ${a.track}`);
  });
}

describe('박자와 소리', () => {
  it('달림에서 켜고, 느려지며 잦아들고, 급제동에서 끄고 끼익, 고요에서 김이 빠지며 바람이 든다', () => {
    expect(run(['run', 'slow', 'brake', 'hush', 'open', null])).toEqual([
      ['hold run'],
      ['bend run'],
      ['release run', 'hold brake'],
      ['hold steam', 'hold wind'],
      [],
      [],
    ]);
  });

  it('달림과 바람은 되풀이로 켜고 나머지는 한 번만 낸다. 크기는 표대로다', () => {
    const plan = createStallPlan();
    const acts = ['run', 'slow', 'brake', 'hush', 'open', null, 'fire', 'whistle'].flatMap(b => plan(b, true));
    const holds = acts.filter((a): a is Extract<StallAct, { do: 'hold' }> => a.do === 'hold');
    expect(holds.map(a => [a.track, a.loop, a.gain])).toEqual([
      ['run', true, STALL_GAIN.run],
      ['brake', false, STALL_GAIN.brake],
      ['steam', false, STALL_GAIN.steam],
      ['wind', true, STALL_GAIN.wind],
      ['whistle', false, STALL_GAIN.whistle],
    ]);
    expect(holds[0].fadeMs).toBeGreaterThan(0); // 되풀이는 딱 소리 없이 열린다
    expect(holds[3].fadeMs).toBe(EDGE_MS.wind);
    expect(STALL_GAIN.wind).toBeLessThan(Math.min(STALL_GAIN.run, STALL_GAIN.brake, STALL_GAIN.steam, STALL_GAIN.whistle)); // 오래 깔리는 소리가 가장 작다
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
      { do: 'hold', track: 'wind', loop: true, gain: STALL_GAIN.wind, fadeMs: EDGE_MS.wind },
    ]);
  });

  it('급제동 중에 건너뛰면 끼익도 짧게 줄인다. 고요를 거쳐 왔으면 끼익의 끝을 자르지 않는다', () => {
    expect(run(['run', 'slow', 'brake', 'open'])[3]).toEqual(['release brake', 'hold steam', 'hold wind']);
    expect(run(['run', 'slow', 'brake', 'hush', 'open'])[4]).toEqual([]);
  });

  it('달림 박이 빠진 짧은 연출은 느려지는 박에서 달림을 켠다', () => {
    expect(run(['slow', 'brake'])).toEqual([['hold run', 'bend run'], ['release run', 'hold brake']]);
  });

  it('다시 달린 뒤 또 서면 처음부터 다시 낸다', () => {
    const all = run(['run', 'slow', 'brake', 'hush', 'open', [null, true], 'fire', 'whistle', [null, false], 'run', 'slow', 'brake', 'hush']);
    expect(all.slice(9)).toEqual([['hold run'], ['bend run'], ['release run', 'hold brake'], ['hold steam', 'hold wind']]);
  });

  it('소리를 꺼 두면 아무것도 내지 않는다. 달리는 도중에 끄면 돌던 것만 줄인다', () => {
    expect(run(['run', 'slow', 'brake', 'hush', 'open', [null, true], 'fire', 'whistle', [null, false]], false).flat()).toEqual([]);
    const plan = createStallPlan();
    plan('run', true);
    expect(plan('slow', false)).toEqual([{ do: 'release', track: 'run', ms: SKIP_MS }]);
    expect(plan('brake', false)).toEqual([]);
  });

  it('모르는 값은 연출이 없는 것으로 친다. 박 이름은 화면의 것과 같다', () => {
    expect(run(['wave', 'run'])).toEqual([[], ['hold run']]);
    expect([...STALL_BEATS]).toEqual(['run', 'slow', 'brake', 'hush', 'open']);
    expect(Object.keys(RESUME_MS)).toEqual(['fire', 'whistle']);
  });
});

describe('서 있는 동안과 다시 달릴 때', () => {
  it('선 순간부터 바람이 깔려 서 있는 동안 이어지고, 불을 넣는 박 동안 잦아든 뒤 기적이 한 번 운다', () => {
    // 화면이 붙이는 대로: 들어가는 연출의 run~hush에는 data-stranded가 없고 open부터 붙는다. 불을 넣는 때에는 이미 없다.
    expect(run([
      ['run', false], ['slow', false], ['brake', false], ['hush', false], ['open', true], [null, true], [null, true],
      ['fire', false], ['whistle', false], ['whistle', false], [null, false],
    ])).toEqual([
      ['hold run'], ['bend run'], ['release run', 'hold brake'], ['hold steam', 'hold wind'], [], [], [],
      ['release wind'], ['hold whistle'], [], [],
    ]);
  });

  it('바람은 불을 넣는 박의 길이에 걸쳐 줄인다', () => {
    const plan = createStallPlan();
    plan(null, true, true);
    expect(plan('fire', true, false)).toEqual([{ do: 'release', track: 'wind', ms: RESUME_MS.fire }]);
  });

  it('연출 없이 서 있는 화면이 열려도(새로 열기, 움직임 줄이기) 바람을 켠다. 연출 없이 다시 달리면 끈다', () => {
    const plan = createStallPlan();
    expect(plan(null, true, true)).toEqual([{ do: 'hold', track: 'wind', loop: true, gain: STALL_GAIN.wind, fadeMs: EDGE_MS.wind }]);
    expect(plan(null, true, true)).toEqual([]);
    expect(plan(null, true, false)).toEqual([{ do: 'release', track: 'wind', ms: SKIP_MS }]);
  });

  it('홈이 안 보이는 화면(열차 관리, 의회)에 가 있는 동안은 바람을 끄지 않는다. 홈이 다시 보였는데 표식이 없으면 끈다', () => {
    expect(run([[null, true], [null, null], [null, null], [null, true], [null, null], [null, false]])).toEqual([
      ['hold wind'], [], [], [], [], ['release wind'],
    ]);
  });

  it('홈이 안 보이는 화면에서 시작하면 서 있는지 모르니 바람을 켜지 않는다', () => {
    expect(run([[null, null], [null, null]])).toEqual([[], []]);
  });

  it('서 있는 동안 소리를 끄면 바람도 줄이고, 다시 켜면 다시 깐다', () => {
    const plan = createStallPlan();
    plan(null, true, true);
    expect(plan(null, false, true)).toEqual([{ do: 'release', track: 'wind', ms: SKIP_MS }]);
    expect(plan(null, false, true)).toEqual([]);
    expect(plan(null, true, true).map(a => `${a.do} ${a.track}`)).toEqual(['hold wind']);
  });

  it('장치가 못 켠 바람은 다음에 부를 때 다시 켠다. 때가 정해진 소리는 다시 내지 않는다', () => {
    const plan = createStallPlan();
    expect(plan('run', true, false).map(a => a.track)).toEqual(['run']);
    plan.missed('run');
    expect(plan('run', true, false)).toEqual([]);
    plan('slow', true, false);
    plan('brake', true, false);
    plan('hush', true, false);
    plan.missed('wind');
    plan.missed('steam');
    expect(plan('hush', true, false).map(a => `${a.do} ${a.track}`)).toEqual(['hold wind']);
    expect(plan('hush', true, false)).toEqual([]);
  });

  it('달리는 박에는 바람이 없다(표식을 놓쳐 바람이 남아 있어도 끈다)', () => {
    expect(run([[null, true], ['run', false]])).toEqual([['hold wind'], ['hold run', 'release wind']]);
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

async function ready(tracks: Record<string, string> = { run: 'stall/run', brake: 'stall/brake', steam: 'stall/steam' }, onReady?: () => void) {
  const fake = fakeAudio();
  const engine = createEngine({
    makeContext: () => fake.ctx as unknown as AudioContext,
    clips: { 'enamel.press': [], 'enamel.confirm': [], 'paper.press': [], 'paper.confirm': [], 'lever.notch': [], denied: [] },
    tracks,
    load: async url => new ArrayBuffer(url.length),
    onReady,
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

  it('장치가 깨고 파일이 풀리면 알린다: 그때 못 켠 되풀이를 다시 켤 수 있다', async () => {
    const calls: boolean[] = [];
    const { engine } = await ready({ wind: 'stall/wind' }, () => {
      calls.push(engine.hold('wind', { loop: true, gain: 0.3, fadeMs: 600 }));
    });
    expect(engine.hold('wind', { loop: true, gain: 0.3, fadeMs: 600 })).toBe(false); // 첫 손짓 전
    expect(calls).toEqual([]);
    engine.unlock();
    await Promise.resolve();
    expect(calls.length).toBeGreaterThan(0);
    expect(calls[calls.length - 1]).toBe(true);
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

  it('소리 다섯에 파일이 하나씩 있고, 이름이 안 맞아 버려지는 파일이 없다', () => {
    const table = trackTable(Object.fromEntries(names.map(n => [`./stall/${n}`, n])));
    expect(Object.keys(table).sort()).toEqual([...STALL_TRACKS].sort());
    expect(names).toHaveLength(STALL_TRACKS.length);
  });

  it('모두 모노 16비트 22050Hz이고, 합쳐 520KB를 넘지 않는다(폰 용량)', () => {
    let total = 0;
    for (const n of names) {
      const w = wav(n);
      expect([n, w.channels, w.bits, w.rate]).toEqual([n, 1, 16, 22050]);
      total += w.bytes;
    }
    expect(total).toBeLessThan(520 * 1024);
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

  it('바람은 몇 초짜리 되풀이이고 처음과 끝이 이어진다. 기적은 바로 시작하고 3초 안에 끝난다', () => {
    const wind = wav('wind.wav');
    expect(wind.seconds).toBeGreaterThan(3);
    expect(wind.seconds).toBeLessThan(6);
    expect(Math.abs(wind.first - wind.last)).toBeLessThan(0.02);
    const whistle = wav('whistle.wav');
    expect(whistle.leadMs).toBeLessThan(30);
    expect(whistle.seconds).toBeGreaterThan(RESUME_MS.whistle / 1000 - 0.2);
    expect(whistle.seconds).toBeLessThan(3);
  });
});
