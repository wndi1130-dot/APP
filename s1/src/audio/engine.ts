import type { Cue, Shot } from './cues';
import { BED, HOWL, bedStep, gustGap, planGust, planHowl } from './gusts';
import type { Gust } from './gusts';
import { SOUND_VOL_GAIN, soundVol } from './settings';

// 소리 장치(Web Audio). 폰 브라우저는 손짓 안에서 연 장치만 소리를 낸다. 그래서 파일은 미리 받아 두기만 하고
// (preload), 장치는 첫 손짓에 연다(unlock). 장치가 막 깨어나는 중이거나 파일이 막 풀리는 중에 온 소리는 잠깐만
// 기다렸다 내고(LATE_MS), 그보다 늦으면 버린다: 한참 뒤에 따라 나오는 소리는 내지 않는다.

/** 준비가 덜 됐을 때 온 소리를 기다려 주는 시간(ms). 첫 누름이 조용하지 않게 하려는 것이다 */
export const LATE_MS = 150;

export interface EngineDeps {
  /** 첫 손짓에 한 번 부른다. 소리를 못 내는 브라우저면 null */
  makeContext: () => AudioContext | null;
  /** 박자마다 변형 파일 주소 */
  clips: Record<Cue, string[]>;
  load: (url: string) => Promise<ArrayBuffer>;
  /** 긴 소리(되풀이하거나 한 번 길게 나는 것)의 이름 → 파일 주소. 없으면 긴 소리는 쓰지 않는다 */
  tracks?: Record<string, string | undefined>;
  /** 장치가 깨었거나 파일이 하나 풀릴 때마다 부른다. 그때까지 못 켠 되풀이를 다시 켤 기회다 */
  onReady?: () => void;
  /** 지금 시각(ms). 시험에서 바꿔 넣는다 */
  now?: () => number;
  /** 되풀이 대신 깔개와 돌풍으로 내는 긴 소리 이름(바람, gusts.ts). 없으면 모두 그냥 되풀이한다 */
  gusty?: string[];
  /** 0~1 무작위. 시험에서 바꿔 넣는다 */
  random?: () => number;
  /** ms 뒤에 부른다. 돌려준 것을 부르면 취소한다. 시험에서 바꿔 넣는다 */
  later?: (fn: () => void, ms: number) => () => void;
}

export interface HoldOpts { loop: boolean; gain: number; fadeMs?: number }

export interface Engine {
  /** 파일을 받아 둔다. 손짓 전에도 된다(소리 장치는 열지 않는다) */
  preload(): Promise<void>;
  /** 손짓 안에서 부른다: 소리 장치를 열고(처음 한 번) 깨운다 */
  unlock(): void;
  /** 소리를 냈으면 true */
  play(shot: Shot): boolean;
  /** 이름 붙은 긴 소리를 켠다. 되풀이하는 것이 이미 돌고 있으면 그대로 둔다. 냈거나 돌고 있으면 true */
  hold(name: string, opts: HoldOpts): boolean;
  /** 돌고 있는 긴 소리의 빠르기와 크기를 ms에 걸쳐 바꾼다(느려지며 잦아든다) */
  bend(name: string, rate: number, gain: number, ms: number): void;
  /** 긴 소리를 ms에 걸쳐 줄이고 끈다 */
  release(name: string, ms: number): void;
}

function decode(ctx: AudioContext, data: ArrayBuffer): Promise<AudioBuffer> {
  return new Promise((resolve, reject) => {
    // 옛 사파리는 약속을 돌려주지 않고 콜백만 부른다. 둘 다 받는다.
    const p = ctx.decodeAudioData(data, resolve, reject) as Promise<AudioBuffer> | undefined;
    p?.then(resolve, reject);
  });
}

interface Windy {
  bed: { src: AudioBufferSourceNode; gain: GainNode };
  filter: BiquadFilterNode;
  gusts: Set<{ src: AudioBufferSourceNode; gain: GainNode }>;
  gain: number;
  buffer: AudioBuffer;
  last: Gust | null;
  stopDrift: (() => void) | null;
  stopNext: (() => void) | null;
}

export function createEngine(deps: EngineDeps): Engine {
  const trackUrls = Object.values(deps.tracks ?? {}).filter((u): u is string => !!u);
  const urls = [...new Set([...Object.values(deps.clips).flat(), ...trackUrls])];
  const raw = new Map<string, ArrayBuffer>();
  const buffers = new Map<string, AudioBuffer>();
  const voices = new Map<Cue, { src: AudioBufferSourceNode; gain: GainNode }>();
  const held = new Map<string, { src: AudioBufferSourceNode; gain: GainNode }>();
  const windy = new Map<string, Windy>();
  const rand = deps.random ?? Math.random;
  const later = deps.later ?? ((fn: () => void, ms: number) => { const id = setTimeout(fn, ms); return () => clearTimeout(id); });
  let ctx: AudioContext | null = null;
  let master: GainNode | null = null;
  let loading: Promise<void> | null = null;
  let dead = false;
  let late: { shot: Shot; at: number } | null = null;
  const now = deps.now ?? (() => performance.now());

  function decodeAll(): void {
    if (!ctx) return;
    const c = ctx;
    for (const [url, data] of raw) {
      raw.delete(url);
      // 못 푼 파일은 그 소리만 안 난다.
      decode(c, data).then(buffer => { buffers.set(url, buffer); ready(); }, () => {});
    }
  }

  function preload(): Promise<void> {
    loading ??= Promise.all(urls.map(url => deps.load(url).then(data => { raw.set(url, data); }, () => {}))).then(decodeAll);
    return loading;
  }

  function unlock(): void {
    if (dead) return;
    if (!ctx) {
      ctx = deps.makeContext();
      if (!ctx) { dead = true; return; }
      master = ctx.createGain();
      master.connect(ctx.destination);
      decodeAll();
    }
    if (ctx.state !== 'running') ctx.resume().then(ready, () => {});
  }

  /** 장치가 깨었거나 파일이 하나 풀렸다 */
  function ready(): void {
    flush();
    deps.onReady?.();
  }

  /** 기다리던 소리가 있으면 낸다. 너무 늦었으면 버린다 */
  function flush(): void {
    if (!late) return;
    if (now() - late.at > LATE_MS || start(late.shot)) late = null;
  }

  function play(shot: Shot): boolean {
    if (start(shot)) {
      late = null;
      return true;
    }
    // 손짓으로 장치를 연 뒤에만 기다린다. 첫 손짓 전의 소리는 그냥 버린다.
    if (ctx) late = { shot, at: now() };
    return false;
  }

  function start(shot: Shot): boolean {
    if (!ctx || !master || ctx.state !== 'running') return false;
    const buffer = buffers.get(deps.clips[shot.cue][shot.variant]);
    if (!buffer) return false;
    const t = ctx.currentTime;
    // 같은 박자의 앞 소리는 짧게 눌러 끈다: 쌓지 않는다.
    const prev = voices.get(shot.cue);
    if (prev) {
      prev.gain.gain.setTargetAtTime(0, t, 0.005);
      prev.src.stop(t + 0.04);
    }
    master.gain.value = SOUND_VOL_GAIN[soundVol()];
    const src = ctx.createBufferSource();
    const gain = ctx.createGain();
    src.buffer = buffer;
    src.playbackRate.value = shot.rate;
    src.connect(gain);
    gain.connect(master);
    src.onended = () => {
      if (voices.get(shot.cue)?.src === src) voices.delete(shot.cue);
      src.disconnect();
      gain.disconnect();
    };
    src.start(t);
    voices.set(shot.cue, { src, gain });
    return true;
  }

  // 긴 소리는 기다렸다 내지 않는다: 준비가 덜 됐으면 그 한 번은 조용하다(늦게 따라 나오는 되풀이가 더 나쁘다).
  function hold(name: string, opts: HoldOpts): boolean {
    if (!ctx || !master || ctx.state !== 'running') return false;
    const url = deps.tracks?.[name];
    const buffer = url ? buffers.get(url) : undefined;
    if (!buffer) return false;
    if (opts.loop && deps.gusty?.includes(name)) return holdWind(name, buffer, opts);
    if (held.has(name)) {
      if (opts.loop) return true;
      release(name, 40);
    }
    const t = ctx.currentTime;
    master.gain.value = SOUND_VOL_GAIN[soundVol()];
    const src = ctx.createBufferSource();
    const gain = ctx.createGain();
    src.buffer = buffer;
    src.loop = opts.loop;
    const fade = (opts.fadeMs ?? 0) / 1000;
    if (fade > 0) {
      gain.gain.setValueAtTime(0, t);
      gain.gain.linearRampToValueAtTime(opts.gain, t + fade);
    } else {
      gain.gain.value = opts.gain;
    }
    src.connect(gain);
    gain.connect(master);
    src.onended = () => {
      if (held.get(name)?.src === src) held.delete(name);
      src.disconnect();
      gain.disconnect();
    };
    src.start(t);
    held.set(name, { src, gain });
    return true;
  }

  function bend(name: string, rate: number, gain: number, ms: number): void {
    const v = held.get(name);
    if (!ctx || !v) return;
    const t = ctx.currentTime;
    const end = t + ms / 1000;
    v.src.playbackRate.setValueAtTime(v.src.playbackRate.value, t);
    v.src.playbackRate.linearRampToValueAtTime(rate, end);
    v.gain.gain.cancelScheduledValues(t);
    v.gain.gain.setValueAtTime(v.gain.gain.value, t);
    v.gain.gain.linearRampToValueAtTime(gain, end);
  }

  /** 바람: 낮게 거른 잡음 깔개가 무작위로 천천히 움직이고, 그 위에 돌풍이 고르지 않은 사이로 분다(gusts.ts) */
  function holdWind(name: string, buffer: AudioBuffer, opts: HoldOpts): boolean {
    if (windy.has(name)) return true;
    const c = ctx as AudioContext;
    const out = master as GainNode;
    const t = c.currentTime;
    out.gain.value = SOUND_VOL_GAIN[soundVol()];
    const noise = c.createBuffer(1, Math.round(c.sampleRate * BED.noiseSecs), c.sampleRate);
    const data = noise.getChannelData(0);
    for (let i = 0; i < data.length; i += 1) data[i] = rand() * 2 - 1;
    const src = c.createBufferSource();
    src.buffer = noise;
    src.loop = true;
    const filter = c.createBiquadFilter();
    filter.type = 'lowpass';
    filter.Q.value = 0.7;
    filter.frequency.value = BED.freq[0];
    const gain = c.createGain();
    const fade = Math.max((opts.fadeMs ?? 0) / 1000, 0.05);
    gain.gain.setValueAtTime(0, t);
    gain.gain.linearRampToValueAtTime(opts.gain * BED.start, t + fade);
    src.connect(filter);
    filter.connect(gain);
    gain.connect(out);
    src.start(t);
    const w: Windy = { bed: { src, gain }, filter, gusts: new Set(), gain: opts.gain, buffer, last: null, stopDrift: null, stopNext: null };
    windy.set(name, w);
    const drift = () => {
      if (windy.get(name) !== w) return;
      const step = bedStep(rand);
      const now = c.currentTime;
      glide(filter.frequency, step.freq, now, step.secs);
      glide(gain.gain, w.gain * step.gain, now, step.secs);
      w.stopDrift = later(drift, step.secs * 1000);
    };
    w.stopDrift = later(drift, fade * 1000);
    for (const g of planHowl(rand)) gust(w, g);
    const next = () => {
      if (windy.get(name) !== w) return;
      gust(w, planGust(rand, w.last));
      w.stopNext = later(next, gustGap(rand) * 1000);
    };
    w.stopNext = later(next, (HOWL.len[0] + gustGap(rand)) * 1000);
    return true;
  }

  function glide(p: AudioParam, v: number, t: number, secs: number): void {
    p.setValueAtTime(p.value, t);
    p.linearRampToValueAtTime(v, t + secs);
  }

  /** 돌풍 하나: 파일의 g.offset부터, 빠르기가 휘고, 꼭대기까지 올랐다가 g.len에 잦아든다 */
  function gust(w: Windy, g: Gust): void {
    const c = ctx as AudioContext;
    const t = c.currentTime + g.delay;
    const src = c.createBufferSource();
    const gain = c.createGain();
    src.buffer = w.buffer;
    src.playbackRate.setValueAtTime(g.rate0, t);
    src.playbackRate.linearRampToValueAtTime(g.rate1, t + g.len);
    gain.gain.setValueAtTime(0, t);
    gain.gain.linearRampToValueAtTime(w.gain * g.peak, t + g.len * g.top);
    gain.gain.linearRampToValueAtTime(0, t + g.len);
    src.connect(gain);
    gain.connect(master as GainNode);
    const v = { src, gain };
    w.gusts.add(v);
    src.onended = () => {
      w.gusts.delete(v);
      src.disconnect();
      gain.disconnect();
    };
    src.start(t, g.offset);
    src.stop(t + g.len + 0.05);
    w.last = g;
  }

  function release(name: string, ms: number): void {
    const w = windy.get(name);
    if (ctx && w) {
      windy.delete(name);
      w.stopDrift?.();
      w.stopNext?.();
      const t = ctx.currentTime;
      const end = t + ms / 1000;
      for (const v of [w.bed, ...w.gusts]) {
        v.gain.gain.cancelScheduledValues(t);
        v.gain.gain.setValueAtTime(v.gain.gain.value, t);
        v.gain.gain.linearRampToValueAtTime(0, end);
        v.src.stop(end + 0.02);
      }
      return;
    }
    const v = held.get(name);
    if (!ctx || !v) return;
    held.delete(name);
    const t = ctx.currentTime;
    const end = t + ms / 1000;
    v.gain.gain.cancelScheduledValues(t);
    v.gain.gain.setValueAtTime(v.gain.gain.value, t);
    v.gain.gain.linearRampToValueAtTime(0, end);
    v.src.stop(end + 0.02);
  }

  return { preload, unlock, play, hold, bend, release };
}
