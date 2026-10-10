import type { VoteResult } from '../game';

// 개표 박자(presentation_motion.md 5b절 4, main f424afd). 미정 표를 하나씩 여는 시간표만 정한다.
// - count: 미정 표 전체를 소란 단계 0·1은 2.5초, 2·3은 3초, 4는 3.5초 안에. 처음엔 느리고 점점 빠르게, 한 돌 0.05~0.35초.
// - last: 결과가 아직 뒤집힐 수 있고 남은 돌이 5개 이하면 한 돌에 0.6초.
// - settled: 결과가 정해지면 남은 돌을 0.6초 안에 빠르게 쓸어 연다. 한 번에 다 켜면 하나씩 오르던 표가 건너뛰는 것처럼 보여서
//   (사용자 2026-10-11) 돌 하나씩, 많으면 한 박자에 여럿씩 이어서 연다.
// - 반복: 회기 1~3은 긴 판, 4~12는 미정 2초, 13부터는 1초(last 없음).
// S1a엔 소란 점수가 아직 없어 긴장(0~100)을 20씩 끊어 소란 단계로 대신 쓴다(어림).

export const PACE = { slow: 0.35, fast: 0.05, last: 0.6, settle: 0.6, lastStones: 5, sweepMin: 0.03, sweepMax: 0.12 } as const;

export function noiseStage(tension: number): number {
  return Math.max(0, Math.min(4, Math.floor(tension / 20)));
}

/** 미정 표 전체에 쓰는 초. */
export function countSeconds(stage: number, session: number): number {
  if (session >= 13) return 1;
  if (session >= 4) return 2;
  return stage <= 1 ? 2.5 : stage <= 3 ? 3 : 3.5;
}

/** 정해진 뒤 남은 돌 쓸기: from개가 열린 데서 n개까지 settle 초 안에 고르게 잇는다. 한 박자는 sweepMin~sweepMax 초이고, 돌이 많으면 한 박자에 여럿을 연다. */
function sweep(from: number, n: number): [number, number][] {
  const left = n - from;
  const beats = Math.max(1, Math.min(left, Math.floor(PACE.settle / PACE.sweepMin)));
  const ms = Math.round(Math.min(PACE.sweepMax, PACE.settle / beats) * 1000);
  return Array.from({ length: beats }, (_, k) => [ms, from + Math.round(((k + 1) * left) / beats)] as [number, number]);
}

/** 개표 단계: [기다릴 ms, 그 뒤 열린 돌 수]의 줄. 마지막 항목의 수는 flips.length다. */
export function countSchedule(result: VoteResult, stage: number, session: number): [number, number][] {
  const n = result.flips.length;
  if (n === 0) return [];
  const total = countSeconds(stage, session);
  const long = session < 4;
  // 처음엔 느리고 점점 빨라진다: 무게 n, n-1, …, 1을 total에 맞춰 나누고 0.05~0.35초로 자른다.
  const sum = (n * (n + 1)) / 2;
  const floor = Math.min(PACE.fast, total / n);
  const gap = (i: number) => Math.min(PACE.slow, Math.max(floor, (total * (n - i)) / sum));
  let yes = result.yes - result.flips.filter(f => f.yes).length;
  const out: [number, number][] = [];
  for (let i = 0; i < n; i += 1) {
    const left = n - i;
    const settled = result.decree || yes >= result.need || yes + left < result.need;
    if (settled) return [...out, ...sweep(i, n)];
    const s = long && left <= PACE.lastStones ? PACE.last : gap(i);
    out.push([Math.round(s * 1000), i + 1]);
    if (result.flips[i].yes) yes += 1;
  }
  return out;
}
