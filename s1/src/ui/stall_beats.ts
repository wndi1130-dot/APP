import type { Game } from '../game';

// 멈춘 열차로 들어가는 연출의 박자(결정 101). 화면 꼴과 떼어 둔다: 때만 셈하고 그리지 않는다.
// 달림 → 느려짐 → 급제동 → 고요 → 판이 열림. 뒤의 네 박은 길이가 굳어 있고, 전체 길이를 바꾸면 달림만 늘고 준다.

/** 전체 길이(초). 이 값 하나만 바꾸면 된다: 처음 멈출 때와 한 판에서 두 번째부터. */
export const STALL_SECS = { first: 6.5, again: 4.5 };

export const STALL_BEATS = ['run', 'slow', 'brake', 'hush', 'open'] as const;
export type StallBeat = typeof STALL_BEATS[number];

/** 달림 뒤 네 박의 길이(ms). 급제동 1100은 지금 정차의 급제동과 같다. */
const TAIL_MS: Record<Exclude<StallBeat, 'run'>, number> = { slow: 1000, brake: 1100, hush: 800, open: 600 };
const TAIL_SUM = TAIL_MS.slow + TAIL_MS.brake + TAIL_MS.hush + TAIL_MS.open;

export interface BeatSpan { beat: StallBeat; at: number; ms: number }

/** 전체 길이(초)에서 박마다 시작 때와 길이(ms)를 낸다. 꼬리 네 박보다 짧으면 달림이 빠진다. */
export function stallBeats(totalSecs: number): BeatSpan[] {
  const run = Math.max(0, Math.round(totalSecs * 1000) - TAIL_SUM);
  const spans: BeatSpan[] = [];
  let at = 0;
  if (run > 0) { spans.push({ beat: 'run', at, ms: run }); at += run; }
  for (const beat of ['slow', 'brake', 'hush', 'open'] as const) {
    spans.push({ beat, at, ms: TAIL_MS[beat] });
    at += TAIL_MS[beat];
  }
  return spans;
}

/** 지난 때(ms)가 어느 박인가. 다 지났으면 null. */
export function beatAt(spans: BeatSpan[], ms: number): StallBeat | null {
  for (const s of spans) if (ms < s.at + s.ms) return s.beat;
  return null;
}

/** 다시 달릴 때의 짧은 떠남(ms): 불을 넣는 박(fire) 뒤에 기적이 우는 박(whistle). 멈춘 판이 내려가고 굴뚝에 연기가 돈다. */
export const RESUME_MS = { fire: 800, whistle: 1200 };
export type ResumeBeat = keyof typeof RESUME_MS;

/** 이 판에서 열차가 선 횟수. 설 때마다 일지에 남는 줄을 센다(저장에 남아 새로 열어도 같다). */
export function stallCount(g: Game): number {
  return g.journal.filter(j => j.text.startsWith('불이 꺼졌다. 열차가 ')).length;
}

/** 이번 멈춤의 연출 길이(초). count는 방금 선 것까지 센 횟수. */
export function stallSecs(count: number): number {
  return count >= 2 ? STALL_SECS.again : STALL_SECS.first;
}
