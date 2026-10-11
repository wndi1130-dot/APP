import type { Cue, Shot } from './cues';
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
  /** 지금 시각(ms). 시험에서 바꿔 넣는다 */
  now?: () => number;
}

export interface Engine {
  /** 파일을 받아 둔다. 손짓 전에도 된다(소리 장치는 열지 않는다) */
  preload(): Promise<void>;
  /** 손짓 안에서 부른다: 소리 장치를 열고(처음 한 번) 깨운다 */
  unlock(): void;
  /** 소리를 냈으면 true */
  play(shot: Shot): boolean;
}

function decode(ctx: AudioContext, data: ArrayBuffer): Promise<AudioBuffer> {
  return new Promise((resolve, reject) => {
    // 옛 사파리는 약속을 돌려주지 않고 콜백만 부른다. 둘 다 받는다.
    const p = ctx.decodeAudioData(data, resolve, reject) as Promise<AudioBuffer> | undefined;
    p?.then(resolve, reject);
  });
}

export function createEngine(deps: EngineDeps): Engine {
  const urls = [...new Set(Object.values(deps.clips).flat())];
  const raw = new Map<string, ArrayBuffer>();
  const buffers = new Map<string, AudioBuffer>();
  const voices = new Map<Cue, { src: AudioBufferSourceNode; gain: GainNode }>();
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
      decode(c, data).then(buffer => { buffers.set(url, buffer); flush(); }, () => {});
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
    if (ctx.state !== 'running') ctx.resume().then(flush, () => {});
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

  return { preload, unlock, play };
}
