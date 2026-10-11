import { RESUME_MS, STALL_BEATS, stallBeats } from '../ui/stall_beats';
import type { ResumeBeat, StallBeat } from '../ui/stall_beats';

// 멈춘 열차의 소리(결정 101): 달리던 열차가 느려지고, 끼익 하고 서고, 김이 빠지고, 서 있는 동안 바람이 분다.
// 다시 달릴 때는 바람이 잦아들고 기적이 운다.
// 화면이 홈 뿌리에 붙이는 표식만 보고 정한다. 화면은 소리를 부르지 않는다.
// - data-beat: 서는 연출 run → slow → brake → hush → open, 다시 달리는 연출 fire → whistle
// - data-stranded: 열차가 서 있는 동안 붙어 있다
// 여기는 무엇을 언제 켜고 끌지만 정한다(소리 장치를 모른다). 소리만 내고 규칙에는 닿지 않는다.

/** 긴 소리 다섯: 달림(되풀이), 급제동(한 번), 김 빠짐(한 번), 바람(되풀이), 기적(한 번). 파일 이름과 같다(stall/run.wav) */
export const STALL_TRACKS = ['run', 'brake', 'steam', 'wind', 'whistle'] as const;
export type StallTrack = typeof STALL_TRACKS[number];

export type StallAct =
  | { do: 'hold'; track: StallTrack; loop: boolean; gain: number; fadeMs: number }
  | { do: 'bend'; track: StallTrack; rate: number; gain: number; ms: number }
  | { do: 'release'; track: StallTrack; ms: number };

/** 소리마다 크기(0~1). 손끝 소리보다 뒤에 깔리게 낮춘다. 바람은 오래 깔리므로 가장 작다 */
export const STALL_GAIN: Record<StallTrack, number> = { run: 0.5, brake: 0.8, steam: 0.5, wind: 0.3, whistle: 0.7 };
/** 느려지는 박이 끝날 때 달림 소리의 빠르기와 크기: 박자가 벌어지며 잦아든다 */
export const SLOW_TO = { rate: 0.6, gain: 0.2 };
/** 눌러서 건너뛰면 돌던 소리를 이만큼(ms)에 줄인다 */
export const SKIP_MS = 300;
/** 되풀이 소리가 켜지고 꺼질 때 딱 소리가 나지 않게 여닫는 길이(ms). 바람은 천천히 든다 */
const EDGE_MS = { on: 150, off: 80, wind: 600 };
/** 느려지는 박의 길이(ms). 화면의 박자 표에서 읽는다 */
const SLOW_MS = stallBeats(60).find(s => s.beat === 'slow')?.ms ?? 1000;
const RESUME_BEATS = Object.keys(RESUME_MS) as ResumeBeat[];

/** 파일 주소 표('./stall/run.wav' → 주소)를 이름 → 주소로 바꾼다. 이름이 안 맞는 파일은 버린다 */
export function trackTable(files: Record<string, string>): Partial<Record<StallTrack, string>> {
  const out: Partial<Record<StallTrack, string>> = {};
  for (const [path, url] of Object.entries(files)) {
    const name = /([a-z]+)\.wav$/.exec(path)?.[1];
    const track = STALL_TRACKS.find(t => t === name);
    if (track) out[track] = url;
  }
  return out;
}

/**
 * 표식이 바뀔 때마다 부른다. 할 일을 차례대로 돌려준다.
 * beat는 지금 data-beat 값(없으면 null), stranded는 홈에 data-stranded가 있는가(홈이 안 보이는 화면이면 null).
 */
export function createStallPlan(): (beat: string | null, on: boolean, stranded?: boolean | null) => StallAct[] {
  let prev: StallBeat | ResumeBeat | null = null;
  let running = false; // 달림 소리가 돌고 있다
  let braked = false; // 급제동 소리를 냈다(아직 울리고 있을 수 있다)
  let steamed = false; // 김 빠지는 소리를 냈다
  let windy = false; // 바람이 깔려 있다
  const hold = (track: StallTrack, loop: boolean, fadeMs = loop ? EDGE_MS.on : 0): StallAct => ({ do: 'hold', track, loop, gain: STALL_GAIN[track], fadeMs });
  return (raw, on, stranded = null) => {
    const stall = STALL_BEATS.find(b => b === raw) ?? null;
    const resume = RESUME_BEATS.find(b => b === raw) ?? null;
    const beat = stall ?? resume;
    const from = prev;
    prev = beat;
    const acts: StallAct[] = [];
    const stopRun = (ms: number) => {
      if (running) acts.push({ do: 'release', track: 'run', ms });
      running = false;
    };
    const wind = (want: boolean, ms: number) => {
      if (want && !windy) acts.push(hold('wind', true, EDGE_MS.wind));
      if (!want && windy) acts.push({ do: 'release', track: 'wind', ms });
      windy = want;
    };
    if (!on) {
      // 꺼 두었으면 새로 내지 않는다. 도중에 껐으면 돌던 것만 줄인다.
      stopRun(SKIP_MS);
      wind(false, SKIP_MS);
      return acts;
    }
    if (beat !== from) {
      if (beat === null || from === null) {
        braked = false;
        steamed = false;
      }
      const startRun = () => {
        if (!running) acts.push(hold('run', true));
        running = true;
      };
      const steam = () => {
        if (!steamed) acts.push(hold('steam', false));
        steamed = true;
      };
      switch (beat) {
        case null:
          stopRun(SKIP_MS);
          break;
        case 'run':
          startRun();
          break;
        case 'slow':
          startRun(); // 달림 박이 빠진 짧은 연출에서는 여기서 켠다
          acts.push({ do: 'bend', track: 'run', rate: SLOW_TO.rate, gain: STALL_GAIN.run * SLOW_TO.gain, ms: SLOW_MS });
          break;
        case 'brake':
          stopRun(EDGE_MS.off);
          acts.push(hold('brake', false));
          braked = true;
          break;
        case 'hush':
          stopRun(EDGE_MS.off);
          steam();
          break;
        case 'open':
          // 고요를 거치지 않고 왔으면 눌러서 건너뛴 것이다: 돌던 소리를 짧게 줄이고 선 뒤 소리를 낸다.
          stopRun(SKIP_MS);
          if (from !== 'hush' && braked) acts.push({ do: 'release', track: 'brake', ms: SKIP_MS });
          steam();
          break;
        case 'fire':
          break;
        case 'whistle':
          acts.push(hold('whistle', false));
          break;
      }
    }
    // 바람: 선 순간(고요)부터 서 있는 동안 깔리고, 다시 달리려고 불을 넣는 박 동안 잦아든다.
    // 다른 화면에 가 있어 홈이 안 보이면(stranded가 null) 그대로 둔다.
    if (stall === 'hush' || stall === 'open') wind(true, 0);
    else if (resume) wind(false, RESUME_MS.fire);
    else if (beat === null && stranded !== null) wind(stranded, SKIP_MS);
    return acts;
  };
}
