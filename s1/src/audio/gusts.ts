// 서 있는 열차 둘레의 바람(사용자 2026-10-24: 「지금 규칙적이니까 귀가피곤함」).
// 4초짜리 바람 파일을 그대로 되풀이하면 4초마다 같은 「후오옹」이 난다. 그래서 둘로 나눈다.
// - 깔개: 직접 만든 잡음을 낮게 거른 것. 크기와 거르는 높이가 잠깐씩 무작위 목표로 천천히 옮겨 가 박자가 없다.
// - 돌풍: 바람 파일 한 번을 낱소리로. 사이·길이·크기·높낮이 휨이 매번 다르고 바로 앞 것과 같은 꼴은 없다.
// 열차가 서는 순간(바람이 처음 들 때)은 돌풍 한~세 겹을 겹쳐 「후오오옹」을 낸다. 이것도 들을 때마다 모양이 다르다.
// 여기는 무엇을 언제 얼마나 낼지만 정한다(소리 장치를 모른다). 소리만 내고 규칙에는 닿지 않는다.

export type Rand = () => number;

/** 돌풍 하나: 언제(초, 지금부터), 파일의 어디서부터(초), 얼마 동안(초), 꼭대기 크기(깔개 크기에 곱함), 빠르기의 처음과 끝(휨), 꼭대기에 닿는 때(길이의 몫) */
export interface Gust { delay: number; offset: number; len: number; peak: number; rate0: number; rate1: number; top: number }

/** 깔개가 다음에 옮겨 갈 곳: 크기(바람 크기에 곱함), 거르는 높이(Hz), 거기까지 걸리는 시간(초) */
export interface BedStep { gain: number; freq: number; secs: number }

export const GUST = {
  /** 돌풍 사이(초). 이 안에서 고르게 고른다 */
  gap: [3, 10] as const,
  len: [1.6, 4.0] as const,
  peak: [0.55, 1.0] as const,
  rate: [0.78, 1.22] as const,
  /** 파일의 어디서 시작하나(초). 바람 파일은 처음 1초 안에 몰려 분다 */
  offset: [0, 0.35] as const,
  top: [0.25, 0.5] as const,
  /** 바로 앞 돌풍과 이만큼은 달라야 한다(시작 빠르기) */
  apart: 0.06,
};

export const HOWL = { layers: [1, 3] as const, len: [3.0, 6.0] as const, spread: 0.45 };

export const BED = {
  gain: [0.45, 1.0] as const,
  freq: [260, 760] as const,
  secs: [0.7, 2.2] as const,
  /** 처음 들 때의 크기 */
  start: 0.7,
  /** 깔개 잡음 길이(초). 되풀이 이음매가 들리지 않을 만큼 길게 */
  noiseSecs: 6,
};

const pick = (rand: Rand, [lo, hi]: readonly [number, number]) => lo + (hi - lo) * rand();

/** 다음 돌풍까지(초) */
export function gustGap(rand: Rand): number {
  return pick(rand, GUST.gap);
}

/** 돌풍 하나. 바로 앞 것(prev)과 시작 빠르기가 apart 넘게 다르게 다시 뽑는다 */
export function planGust(rand: Rand, prev: Gust | null = null, delay = 0): Gust {
  let rate0 = pick(rand, GUST.rate);
  for (let i = 0; i < 8 && prev && Math.abs(rate0 - prev.rate0) <= GUST.apart; i += 1) rate0 = pick(rand, GUST.rate);
  if (prev && Math.abs(rate0 - prev.rate0) <= GUST.apart) {
    // 운이 나빠도 같은 꼴은 내지 않는다: 반대쪽 끝으로 민다.
    rate0 = prev.rate0 > (GUST.rate[0] + GUST.rate[1]) / 2 ? GUST.rate[0] : GUST.rate[1];
  }
  return {
    delay,
    offset: pick(rand, GUST.offset),
    len: pick(rand, GUST.len),
    peak: pick(rand, GUST.peak),
    rate0,
    rate1: pick(rand, GUST.rate),
    top: pick(rand, GUST.top),
  };
}

/** 바람이 처음 들 때의 「후오오옹」: 한~세 겹, 길게, 겹마다 조금씩 늦게 */
export function planHowl(rand: Rand): Gust[] {
  const layers = Math.min(HOWL.layers[1], HOWL.layers[0] + Math.floor(rand() * (HOWL.layers[1] - HOWL.layers[0] + 1)));
  const out: Gust[] = [];
  for (let i = 0; i < layers; i += 1) {
    const g = planGust(rand, out[out.length - 1] ?? null, i === 0 ? 0 : rand() * HOWL.spread);
    out.push({ ...g, len: pick(rand, HOWL.len) });
  }
  return out;
}

export function bedStep(rand: Rand): BedStep {
  return { gain: pick(rand, BED.gain), freq: pick(rand, BED.freq), secs: pick(rand, BED.secs) };
}
